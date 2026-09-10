import AppKit
import SwiftUI
import Carbon

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppModel: ObservableObject {
    @Published var angle: Double = 58 { didSet { updateAppearance() } }
    @Published var clearAngle: Double = UserDefaults.standard.object(forKey: "clearAngle") as? Double ?? 100 { didSet { save(); updateAppearance() } }
    @Published var perspective: Double = UserDefaults.standard.object(forKey: "perspective") as? Double ?? 0.55 { didSet { save(); updateAppearance() } }
    @Published var blur: Double = UserDefaults.standard.object(forKey: "blur") as? Double ?? 0.72 { didSet { save(); updateAppearance() } }
    @Published var shadow: Double = UserDefaults.standard.object(forKey: "shadow") as? Double ?? 0.18 { didSet { save(); updateAppearance() } }
    @Published var style: Int = UserDefaults.standard.integer(forKey: "style") { didSet { save(); updateAppearance() } }
    @Published var sound: Bool = UserDefaults.standard.bool(forKey: "sound") { didSet { save() } }
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
    var overlayIsVisible: Bool { panel?.isVisible == true }
    var captureIsRunning: Bool { capture != nil || starting }
    private let sensor = LidSensor()
    private var sensorQueue = DispatchQueue(label: "Macfold.sensor", qos: .userInteractive)
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
        FoldSettings(angle: enabled ? (sensorAngle ?? clearAngle) : angle, clearAngle: clearAngle,
                     perspective: perspective, blur: blur, shadow: shadow, style: style, reducedMotion: reducedMotion)
    }

    func setup(requestScreenPermission: Bool = true) {
        if !UserDefaults.standard.bool(forKey: "duoDefaultsV2") {
            resetAppearance(); UserDefaults.standard.set(true, forKey: "duoDefaultsV2")
        }
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
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.pause() })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.pause() })
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
        if let screen=NSScreen.main {
            let link=screen.displayLink(target:self,selector:#selector(tick))
            let maxFPS=Float(min(120,screen.maximumFramesPerSecond))
            link.preferredFrameRateRange=CAFrameRateRange(minimum:30,maximum:maxFPS,preferred:maxFPS)
            link.add(to:.main,forMode:.common)
            displayLink=link
        }
    }

    private func receiveSensor(_ value: Double?) {
        if let value {
            if sensorAngle != value { sensorAngle = value }
        } else {
            sensorAngle = nil
            if enabled { pause(); message = "Lid sensor disconnected. The desktop effect has stopped." }
        }
    }

    func activate() {
        guard sensorAngle != nil else { message = "No readable lid sensor. You can still use the preview."; return }
        guard emergencyShortcutAvailable else { message = "The stop shortcut is unavailable. Close any app using Command-Shift-Escape, then reopen Macfold."; return }
        guard hasPermission() else { return }
        stopEffect()
        demo = false; enabled = true
        message = "Following your lid. Close it below \(Int(clearAngle))° to fold."
        startEffect()
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
        message = "Allow Macfold in Screen Recording, then quit and reopen it. The built-in preview works without permission."
        return false
    }
    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    func pause() {
        enabled = false; demo = false; demoDeadline = nil
        stopEffect()
        message = "Paused. Your desktop is back to normal."
        refreshMenu()
    }
    @objc private func tick() {
        if let deadline = demoDeadline, Date() >= deadline { pause(); return }
        guard enabled || demo else { return }
        let effectVisible = settings.progress > 0.0001
        requestedCaptureRate = effectVisible || demo ? captureFPS : 1
        if !effectVisible, metal?.settled == true, panel?.isVisible == true {
            panel?.orderOut(nil)
            if sound && enabled { NSSound(named: "Tink")?.play() }
        }
        adjustCaptureRate()
        if let frame = capture?.takeFrame() {
            receivedFrames += 1
            lastFrameAt = Date()
            metal?.source = frame
        }
        if let lastFrameAt, Date().timeIntervalSince(capture?.lastActivity ?? lastFrameAt) > 6 {
            pause(); message = "Screen capture stopped delivering frames. Start again to retry."; return
        }
        metal?.settings = settings
        if effectVisible, metal?.source != nil, panel?.isVisible == false { panel?.orderFrontRegardless() }
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
            self.pause(); self.message = "Screen capture stopped: \(error)"
        }
        let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        panel.backgroundColor = .clear; panel.isOpaque = true
        panel.ignoresMouseEvents = true; panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        let metal = FoldMetalView(); metal.settings = settings
        if let error=metal.initializationError { pause(); message=error; return }
        metal.onPresented = { [weak self] in self?.presentedFrames += 1 }
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
                self.pause(); self.message = "Could not capture the desktop: \(error.localizedDescription)"
                self.permissionNeeded = !CGPreflightScreenCaptureAccess()
            }
        }
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
                self.pause(); self.message="Screen capture stopped: \(error.localizedDescription)"
            }
        }
    }
    private func stopEffect() {
        token = UUID(); starting = false; changingCaptureRate=false; appliedCaptureRate=0
        panel?.orderOut(nil); panel?.close(); panel = nil; metal = nil
        lastFrameAt = nil
        let old = capture; capture = nil
        if let old { Task { await old.stop() } }
    }
    private func updateAppearance() { metal?.settings = settings }
    private func save() {
        let d = UserDefaults.standard
        d.set(clearAngle, forKey: "clearAngle"); d.set(perspective, forKey: "perspective")
        d.set(blur, forKey: "blur"); d.set(shadow, forKey: "shadow")
        d.set(style, forKey: "style"); d.set(sound, forKey: "sound")
    }
    func resetAppearance() {
        clearAngle = 100; perspective = 0.55; blur = 0.72; shadow = 0.18; style = 0; angle = 58; sound = false
    }
    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: "Macfold")
        statusItem?.button?.toolTip = "Macfold"
        refreshMenu()
    }
    private func refreshMenu() {
        let menu = NSMenu()
        let state = NSMenuItem(title: enabled ? "Macfold · Following lid" : demo ? "Macfold · Previewing" : "Macfold · Paused", action: nil, keyEquivalent: "")
        menu.addItem(state); menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(settingsAction), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        let toggle = NSMenuItem(title: enabled || demo ? "Pause effect" : "Follow lid", action: #selector(toggleAction), keyEquivalent: "p"); toggle.target = self; menu.addItem(toggle)
        let preview = NSMenuItem(title: "Preview desktop for 8 seconds", action: #selector(previewAction), keyEquivalent: "d"); preview.target = self; menu.addItem(preview)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Macfold", action: #selector(quitAction), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        statusItem?.menu = menu
    }
    @objc private func settingsAction() { showSettings?() }
    @objc private func toggleAction() { if enabled || demo { pause() } else { activate() } }
    @objc private func previewAction() { previewDesktop() }
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
        pause(); sensorTimer?.cancel(); displayLink?.invalidate()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID { (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID() }
}
