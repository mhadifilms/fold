import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        // An update must not leave competing overlays or hotkeys behind.
        let previous = NSWorkspace.shared.runningApplications.filter {
            ($0.bundleIdentifier == Bundle.main.bundleIdentifier || $0.bundleIdentifier == "app.freefold.local") && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        previous.forEach { _ = $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + (previous.isEmpty ? 0 : 1.0)) { [weak self] in self?.finishLaunching() }
    }
    private func finishLaunching() {
        model.showSettings = { [weak self] in self?.showSettings() }
        model.setup(requestScreenPermission: !CommandLine.arguments.contains("--integration-test"))
        let main = NSMenu()
        let app = NSMenuItem(); main.addItem(app)
        let menu = NSMenu(); app.submenu = menu
        let settings = NSMenuItem(title: "Fold Settings…", action: #selector(openSettings), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        let pause = NSMenuItem(title: "Pause effect", action: #selector(pauseEffect), keyEquivalent: "p"); pause.target = self; menu.addItem(pause)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Fold", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
        showSettings()
        if CommandLine.arguments.contains("--integration-test") { IntegrationTest.start(model) }
    }
    func showSettings() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 950), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            w.title = "Fold"
            w.contentView = NSHostingView(rootView: SettingsView(model: model))
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.setFrameAutosaveName("FoldSettings")
            if let screen = NSScreen.main {
                let available = screen.visibleFrame
                let height = min(950, available.height - 70)
                w.setContentSize(NSSize(width: 620, height: height))
            }
            w.center(); window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    @objc func openSettings() { showSettings() }
    @objc func pauseEffect() { model.pause() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
}

let app = NSApplication.shared
if CommandLine.arguments.contains("--self-test") {
    do { try SelfTests.run() } catch { print("FAIL: \(error)"); exit(1) }
    exit(0)
}
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
