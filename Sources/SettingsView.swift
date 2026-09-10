import SwiftUI

struct PreviewSurface: NSViewRepresentable {
    var settings: FoldSettings
    func makeNSView(context: Context) -> FoldMetalView {
        let view = FoldMetalView(); view.source = SampleArtwork.sample(); view.settings = settings
        return view
    }
    func updateNSView(_ view: FoldMetalView, context: Context) { view.settings = settings }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var previewAngle: Double = 100
    @State private var previewTask: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48).accessibilityHidden(true)
                Text("Fold").font(.system(size: 26, weight: .semibold))
                Spacer()
            }
            VStack(spacing: 10) {
                PreviewSurface(settings: FoldSettings(angle: previewAngle, reducedMotion: model.reducedMotion))
                    .aspectRatio(1.6, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Preview of the fold effect on a sample desktop")
                HStack {
                    Text("Your desktop follows the lid.").font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button(previewTask == nil ? "Preview" : "Stop preview", systemImage: previewTask == nil ? "play" : "stop") { togglePreview() }
                        .accessibilityHint("Plays the effect inside this window")
                }
            }
            GroupBox {
                VStack(spacing: 12) {
                    settingToggle("Automatic folding", isOn: Binding(get: { model.automatic }, set: { model.setAutomatic($0) }))
                    Divider()
                    settingToggle("Start at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    settingToggle("Show menu bar icon", isOn: $model.showMenuBar)
                }.toggleStyle(.switch).padding(10)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label(status, systemImage: model.permissionNeeded || model.sensorAngle == nil ? "exclamationmark.circle" : model.enabled ? "checkmark.circle" : "pause.circle")
                        .font(.callout.weight(.medium))
                    Spacer()
                    if model.enabled {
                        Button("Pause for now") { model.pause() }.buttonStyle(.link)
                    } else if model.automatic && !model.permissionNeeded && model.sensorAngle != nil && model.emergencyShortcutAvailable {
                        Button("Resume") { model.activate() }.buttonStyle(.link)
                    }
                }
                if model.permissionNeeded {
                    Button("Allow screen access…") { model.openPrivacySettings() }
                    Text("Allow Fold in Screen Recording, then reopen it.").font(.caption).foregroundStyle(.secondary)
                } else if !model.emergencyShortcutAvailable {
                    Text("The stop shortcut is unavailable. Close any app using Command-Shift-Escape, then reopen Fold.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Close Settings and Fold keeps working. Holding the lid still clears the effect.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if !model.loginMessage.isEmpty { Text(model.loginMessage).font(.caption).foregroundStyle(.secondary) }
                if model.reducedMotion { Text("Respects Reduce Motion.").font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                Text("On your Mac. Nothing uploaded.")
                Spacer()
                Text("⌘⇧Esc to pause")
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear { previewTask?.cancel(); previewTask = nil; previewAngle = 100 }
    }
    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch)
        }
    }
    private var status: String {
        if model.permissionNeeded { return "Screen access needed" }
        if model.sensorAngle == nil { return "Lid sensor unavailable" }
        if !model.emergencyShortcutAvailable { return "Stop shortcut unavailable" }
        return model.enabled ? "Ready when you move" : "Paused"
    }
    private func togglePreview() {
        if let task = previewTask { task.cancel(); previewTask = nil; previewAngle = 100; return }
        previewTask = Task { @MainActor in
            for frame in 0...240 {
                guard !Task.isCancelled else { return }
                previewAngle = 100-88*(0.5-0.5*cos(Double(frame)/240*2*Double.pi))
                do { try await Task.sleep(nanoseconds: 16_666_667) } catch { return }
            }
            previewAngle = 100; previewTask = nil
        }
    }
}
