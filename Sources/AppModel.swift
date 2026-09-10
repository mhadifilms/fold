import AppKit
import SwiftUI
import Carbon

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppModel: ObservableObject {
    @Published var angle: Double = 58 { didSet { updateAppearance() } }
    private var lidReference = LidReference()
    private var clearAngle: Double { lidReference.clearAngle }
    let diagnostic = CommandLine.arguments.contains("--integration-test") || CommandLine.arguments.contains("--experience-test")
    @Published var automatic = UserDefaults.standard.object(forKey: "automatic") as? Bool ?? true
    @Published var showMenuBar = UserDefaults.standard.bool(forKey: "showMenuBar") { didSet {
        if !diagnostic { UserDefaults.standard.set(showMenuBar, forKey: "showMenuBar") }; setupMenu()
    } }
    @Published var launchAtLogin = LoginService.enabled
    @Published var loginMessage = ""
    @Published var waitingForMotion = true
    private var safety = FoldSafety()
    private var effectAllowed = false
    private var suspended = false
    private var lastSensorAt: Double?
    private var lastSensorAngle: Double?
    private var warmCaptureUntil: Double = 0
    private var revealAfter: Double?
    private var recoveryTimer: Timer?
    private var retryAfter: Double = 0
    private var automaticStarted = false
    var testSensorAngle: Double?
    var testUsesSensor = false
    @Published var enabled = false
    @Published var demo = false
    @Published var sensorAngle: Double?
    @Published var message = "Drag the angle to try the fold."
    @Published var permissionNeeded = false
    @Published var reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    @Published var emergencyShortcutAvailable = false
    var showSettings: (() -> Void)?
    private(set) var receivedFrames = 0
    private(set) var presentedFrames = 0
    private(set) var captureStarts = 0
    var overlayIsVisible: Bool { panel?.isVisible == true && (panel?.alphaValue ?? 0) > 0.01 }
    var captureIsRunning: Bool { capture != nil || starting }
    private let sensor = LidSensor()
    private var sensorQueue = DispatchQueue(label: "Fold.sensor", qos: .userInteractive)
    private var sensorTimer: DispatchSourceTimer?
    private var displayLink: CADisplayLink?
    private var authorization = CaptureAuthorization()
    private var requestedCaptureRate = 60
    private var changingCaptureRate = false
    private var captureFPS = 60
    private var capture: DesktopCapture?
    private var panel: OverlayPanel?
    private var metal: FoldMetalView?
    private var token = UUID()
    private var starting = false
    private var demoDeadline: Date?
    private var lastFrameAt: Date?
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var observers: [NSObjectProtocol] = []
    private var localMonitor: Any?
    private var statusItem: NSStatusItem?

    var settings: FoldSettings {
        FoldSettings(angle: enabled ? (effectAllowed ? (sensorAngle ?? clearAngle) : clearAngle) : angle, clearAngle: enabled ? clearAngle : 100, reducedMotion: reducedMotion)
    }

    func setup(requestScreenPermission: Bool = true) {
        setupMenu(); setupHotKey()
        permissionNeeded = !authorization.startup(preflight: { CGPreflightScreenCaptureAccess() }, request: { requestScreenPermission ? CGRequestScreenCaptureAccess() : false })
        if permissionNeeded { message = "Allow screen access in System Settings, then reopen the app. Preview below needs no permission." }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.permissionNeeded = !CGPreflightScreenCaptureAccess()
        })
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.pause(); return nil }
            return event
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.suspendForSystem() })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.suspendForSystem() })
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.resumeAfterSystem() })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.resumeAfterSystem()
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            self?.updateAppearance()
        })
        let t = DispatchSource.makeTimerSource(queue: sensorQueue)
        t.schedule(deadline: .now(), repeating: 1.0 / 60.0, leeway: .milliseconds(2))
        var connected = false
        var retryTicks = 0
        t.setEventHandler { [weak self] in
            guard let self else { return }
            if !connected {
                retryTicks += 1
                guard retryTicks == 1 || retryTicks % 300 == 0 else { return }
                connected = self.sensor.connect()
            }
            let value = connected ? self.sensor.read() : nil
            if value == nil { connected = false }
            DispatchQueue.main.async { [weak self] in self?.receiveSensor(value) }
        }
        sensorTimer = t; t.resume()
        recoveryTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.evaluateSafety() }
        RunLoop.main.add(recoveryTimer!, forMode: .common)
        if let screen=NSScreen.main {
            let link=screen.displayLink(target:self,selector:#selector(tick))
            let maxFPS=Float(min(120,screen.maximumFramesPerSecond))
            link.preferredFrameRateRange=CAFrameRateRange(minimum:30,maximum:maxFPS,preferred:maxFPS)
            link.add(to:.main,forMode:.common)
            displayLink=link
        }
    }

    private func receiveSensor(_ reading: Double?) {
        let value = diagnostic && testUsesSensor ? testSensorAngle : reading
        let now = CACurrentMediaTime()
        if let value, let previous = lastSensorAngle, value < previous - 0.25 {
            warmCaptureUntil = now + 0.6
        }
        lidReference.observe(value)
        lastSensorAngle = value
        lastSensorAt = now
        if let value {
            if sensorAngle != value { sensorAngle = value }
        } else {
            sensorAngle = nil
            lidReference.rebase(nil)
            if enabled { safety.suspend(); stopEffect(); message = "Waiting for the lid sensor to reconnect." }
        }
        // React on the sensor sample, not the slower stale-sensor watchdog.
        evaluateSafety()
    }

    func setAutomatic(_ value: Bool) {
        automatic = value
        if !diagnostic { UserDefaults.standard.set(value, forKey: "automatic") }
        if value { automaticStarted = false; evaluateSafety() } else { pause() }
    }
    func setLaunchAtLogin(_ value: Bool) {
        guard !diagnostic else { return }
        do {
            try LoginService.setEnabled(value)
            launchAtLogin = LoginService.enabled
            loginMessage = LoginService.needsApproval ? "Approve Fold in System Settings → Login Items." : ""
        } catch { launchAtLogin = LoginService.enabled; loginMessage = error.localizedDescription }
    }
    func suspendForSystem() {
        suspended = true; safety.suspend(); lidReference.rebase(nil); effectAllowed = false; stopEffect()
    }
    func resumeAfterSystem() {
        safety.suspend(); effectAllowed = false; suspended = false
        lastSensorAt = nil
        // Recreate the display clock after display changes or wake.
        displayLink?.invalidate()
        if let screen = NSScreen.screens.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) ?? NSScreen.main {
            let link = screen.displayLink(target: self, selector: #selector(tick))
            let fps = Float(min(120, screen.maximumFramesPerSecond))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: fps, preferred: fps)
            link.add(to: .main, forMode: .common); displayLink = link
        }
    }
    private func evaluateSafety() {
        let now = CACurrentMediaTime()
        if !diagnostic && automatic && !automaticStarted && !suspended && sensorAngle != nil && !permissionNeeded && emergencyShortcutAvailable {
            automaticStarted = true; activate()
        }
        guard enabled, !suspended else { return }
        let fresh = lastSensorAt.map { now - $0 < 0.75 } ?? false
        let wasWaiting = safety.waitingForMotion
        effectAllowed = safety.permitsEffect(angle: fresh ? sensorAngle : nil, clearAngle: clearAngle, now: now)
        if safety.waitingForMotion && !wasWaiting {
            // The held-lid reset establishes a new resting posture. Keep this
            // endpoint through the next fold instead of retaining an older maximum.
            lidReference.rebase(fresh ? sensorAngle : nil)
        }
        if waitingForMotion != safety.waitingForMotion { waitingForMotion = safety.waitingForMotion }
        if waitingForMotion {
            if captureIsRunning || overlayIsVisible { stopEffect() }
            message = "Ready for your next lid movement. The desktop is clear."
        } else {
            message = "Automatic folding is on. You can close Settings."
        }
    }
    func activate() {
        guard sensorAngle != nil else { message = "No readable lid sensor. You can still use the preview."; return }
        guard emergencyShortcutAvailable else { message = "The stop shortcut is unavailable. Close any app using Command-Shift-Escape, then reopen Fold."; return }
        guard hasPermission() else { return }
        stopEffect()
        demo = false; enabled = true; safety = FoldSafety(); lidReference.rebase(sensorAngle); effectAllowed = false
        message = "Following your lid. Start closing it to fold."
        refreshMenu()
    }
    func previewDesktop() {
        guard hasPermission() else { return }
        pause()
        demo = true; demoDeadline = Date().addingTimeInterval(8)
        message = "Desktop preview ends in 8 seconds. Command-Shift-Escape stops it now."
        startEffect()
        refreshMenu()
    }
    private func hasPermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { permissionNeeded = false; return true }
        permissionNeeded = true
        message = "Allow Fold in Screen Recording, then quit and reopen it. The built-in preview works without permission."
        return false
    }
    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    func pause() {
        enabled = false; demo = false; demoDeadline = nil; effectAllowed = false; safety.suspend()
        stopEffect()
        message = "Paused. Your desktop is back to normal."
        refreshMenu()
    }
    @objc private func tick() {
        if let deadline = demoDeadline, Date() >= deadline { pause(); return }
        guard (enabled || demo) && !suspended else { return }
        if permissionNeeded { return }
        if enabled && safety.waitingForMotion { return }
        if CACurrentMediaTime() < retryAfter { return }
        let effectVisible = settings.progress > 0.0001
        requestedCaptureRate = effectVisible || demo || CACurrentMediaTime() < warmCaptureUntil ? captureFPS : 1
        if !effectVisible, metal?.settled == true, panel?.isVisible == true {
            panel?.orderOut(nil); panel?.alphaValue = 0; revealAfter = nil
        }
        adjustCaptureRate()
        if let frame = capture?.takeFrame() {
            receivedFrames += 1
            lastFrameAt = Date()
            metal?.source = frame
        }
        if let lastFrameAt, Date().timeIntervalSince(capture?.lastActivity ?? lastFrameAt) > 6 {
            recoverCapture("Screen capture paused. Move the lid to retry."); return
        }
        if effectVisible, metal?.source != nil, panel?.isVisible == false {
            // Prepare a flat, current frame invisibly before replacing the live desktop.
            revealAfter = CACurrentMediaTime()
            metal?.resetMotion()
            panel?.alphaValue = 0
            panel?.orderFrontRegardless()
        }
        if revealAfter != nil {
            var flat = settings; flat.angle = flat.clearAngle
            metal?.settings = flat
            metal?.isPaused = false
        } else { metal?.settings = settings }
        if capture == nil && !starting { startEffect() }
    }
    private func startEffect() {
        guard let screen = (enabled ? NSScreen.screens.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) : NSScreen.main) else {
            pause(); message = "No available display for the effect."; return
        }
        guard MTLCreateSystemDefaultDevice() != nil else { pause(); message = "A Metal-capable GPU is required."; return }
        starting = true
        captureStarts += 1
        captureFPS=min(120,screen.maximumFramesPerSecond)
        requestedCaptureRate=settings.progress > 0.0001 || demo ? captureFPS : 1
        let id = UUID(); token = id
        let cap = DesktopCapture()
        cap.onFailure = { [weak self] error in
            guard let self, self.token == id else { return }
            self.recoverCapture("Screen capture stopped: \(error)")
        }
        let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        panel.backgroundColor = .clear; panel.isOpaque = true; panel.alphaValue = 0
        panel.ignoresMouseEvents = true; panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        let metal = FoldMetalView(); metal.settings = settings
        if let error=metal.initializationError { pause(); message=error; return }
        metal.onPresented = { [weak self] in
            guard let self, self.token == id else { return }
            self.presentedFrames += 1
            guard let requested = self.revealAfter, self.panel?.isVisible == true,
                  let activity = self.capture?.lastActivity,
                  activity.timeIntervalSince1970 >= self.revealWallTime(requested) else { return }
            // An idle acknowledgement is also valid: SCK confirmed that its last
            // desktop image has not changed. Never flash a stale paused frame.
            self.revealAfter = nil
            self.metal?.resetMotion()
            self.metal?.settings = self.settings
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.panel?.animator().alphaValue = 1
            }
        }
        panel.contentView = metal
        self.panel = panel; self.metal = metal
        let initialRate=requestedCaptureRate
        Task { @MainActor [weak self] in
            do {
                try await cap.start(displayID: screen.displayID, framesPerSecond: initialRate)
                guard let self, self.token == id, self.enabled || self.demo else { await cap.stop(); return }
                self.capture = cap; self.starting = false; self.lastFrameAt = Date()
            } catch {
                await cap.stop()
                guard let self, self.token == id else { return }
                self.recoverCapture("Could not capture the desktop: \(error.localizedDescription)")
                self.permissionNeeded = !CGPreflightScreenCaptureAccess()
            }
        }
    }
    private func revealWallTime(_ monotonic: Double) -> Double {
        Date().timeIntervalSince1970 - (CACurrentMediaTime() - monotonic)
    }
    private var appliedCaptureRate = 0
    private func adjustCaptureRate() {
        guard let capture, !changingCaptureRate, appliedCaptureRate != requestedCaptureRate else { return }
        changingCaptureRate=true
        let rate=requestedCaptureRate, id=token
        Task { @MainActor [weak self] in
            do {
                try await capture.setFrameRate(rate)
                guard let self, self.token == id else { return }
                self.appliedCaptureRate=rate; self.changingCaptureRate=false
            } catch {
                guard let self, self.token == id else { return }
                self.recoverCapture("Screen capture stopped: \(error.localizedDescription)")
            }
        }
    }
    private func recoverCapture(_ reason: String) {
        stopEffect(); safety.suspend(); effectAllowed = false
        permissionNeeded = !CGPreflightScreenCaptureAccess()
        retryAfter = CACurrentMediaTime() + 3
        if demo { pause() }
        message = reason
    }
    private func stopEffect() {
        token = UUID(); starting = false; changingCaptureRate=false; appliedCaptureRate=0; revealAfter = nil
        panel?.orderOut(nil); panel?.close(); panel = nil; metal = nil
        lastFrameAt = nil
        let old = capture; capture = nil
        if let old { Task { await old.stop() } }
    }
    private func updateAppearance() { metal?.settings = settings }
    var menuBarIsVisible: Bool { statusItem != nil }
    private func setupMenu() {
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem); self.statusItem = nil }
        guard showMenuBar else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: "Fold")
        statusItem?.button?.toolTip = "Fold"
        refreshMenu()
    }
    private func refreshMenu() {
        let menu = NSMenu()
        let state = NSMenuItem(title: enabled ? "Fold · Following lid" : demo ? "Fold · Previewing" : "Fold · Paused", action: nil, keyEquivalent: "")
        menu.addItem(state); menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsAction), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        let toggle = NSMenuItem(title: enabled || demo ? "Pause effect" : "Follow lid", action: #selector(toggleAction), keyEquivalent: "p"); toggle.target = self; menu.addItem(toggle)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Fold", action: #selector(quitAction), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        statusItem?.menu = menu
    }
    @objc private func settingsAction() { showSettings?() }
    @objc private func toggleAction() { if enabled || demo { pause() } else { activate() } }
    @objc private func quitAction() { pause(); NSApp.terminate(nil) }
    private func setupHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerResult = InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer -> OSStatus in
            guard let pointer else { return noErr }
            Unmanaged<AppModel>.fromOpaque(pointer).takeUnretainedValue().pause()
            return noErr
        }, 1, &spec, context, &hotKeyHandler)
        let keyResult = RegisterEventHotKey(UInt32(kVK_Escape), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x46464C44, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        emergencyShortcutAvailable = handlerResult == noErr && keyResult == noErr
    }
    func shutdown() {
        pause(); sensorTimer?.cancel(); displayLink?.invalidate(); recoveryTimer?.invalidate()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID { (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID() }
}
