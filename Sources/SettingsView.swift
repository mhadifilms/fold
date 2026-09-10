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
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Macfold").font(.system(size: 27, weight: .semibold, design: .rounded))
                            Text("Close the lid. Let the desktop follow.").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Open source").font(.caption).foregroundStyle(.secondary).padding(.top, 10)
                    }
                    VStack(spacing: 12) {
                        PreviewSurface(settings: model.settings)
                            .aspectRatio(1.6, contentMode: .fit)
                            .frame(maxWidth: 440)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.12)))
                            .accessibilityLabel("Generated desktop preview at \(Int(model.settings.angle)) degrees")
                        HStack {
                            Text(model.enabled ? "Lid angle" : "Preview angle")
                            Slider(value: $model.angle, in: 5...130, step: 1).disabled(model.enabled).accessibilityLabel("Preview angle")
                            Text("\(Int(model.settings.angle))°").monospacedDigit().frame(width: 44, alignment: .trailing)
                        }
                    }.frame(maxWidth: .infinity)
                    GroupBox("Works on its own") {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Automatic folding", isOn: Binding(get: { model.automatic }, set: { model.setAutomatic($0) }))
                            Toggle("Start at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                            Toggle("Show menu bar icon", isOn: $model.showMenuBar)
                            Text("Close this window and Macfold keeps working. Open Macfold from Applications whenever you want to change settings.").font(.caption).foregroundStyle(.secondary)
                            if !model.loginMessage.isEmpty { Text(model.loginMessage).font(.caption).foregroundStyle(.orange) }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    }
                    GroupBox("Appearance") {
                        VStack(spacing: 13) {
                            Picker("Style", selection: $model.style) {
                                Text("Original").tag(0); Text("Dusk").tag(1); Text("Mist").tag(2)
                            }.pickerStyle(.segmented)
                            control("Stretch", value: $model.perspective)
                            control("Blur", value: $model.blur)
                            control("Shade", value: $model.shadow)
                            HStack {
                                Text("Clear above").frame(width: 90, alignment: .leading)
                                Slider(value: $model.clearAngle, in: 45...120, step: 1).accessibilityLabel("Clear above angle")
                                Text("\(Int(model.clearAngle))°").monospacedDigit().frame(width: 44, alignment: .trailing)
                            }
                            Toggle("Soft sound when the desktop clears", isOn: $model.sound).frame(maxWidth: .infinity, alignment: .leading)
                            if model.reducedMotion {
                                Label("Reduce Motion is on. Perspective is disabled.", systemImage: "accessibility").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(10)
                    }
                    HStack {
                        Text("Lid sensor")
                        Spacer()
                        if let angle = model.sensorAngle {
                            Label("Connected · \(Int(angle))°", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Text("Not available on this Mac").foregroundStyle(.secondary)
                        }
                    }
                    Text("Holding the lid still clears the effect after 2.5 seconds. The next lid movement starts it again.").font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button(model.enabled || model.demo ? "Pause for now" : "Resume folding", systemImage: model.enabled || model.demo ? "pause.fill" : "play.fill") {
                        if model.enabled || model.demo { model.pause() } else { model.activate() }
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(!(model.enabled || model.demo) && (model.sensorAngle == nil || !model.emergencyShortcutAvailable))
                    Button("Preview desktop · 8 sec") { model.previewDesktop() }.controlSize(.large)
                    Spacer()
                    Button("Restore original") { model.resetAppearance() }.buttonStyle(.borderless)
                }
                Text(model.message).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if model.permissionNeeded {
                    Button("Open Screen Recording settings…") { model.openPrivacySettings() }
                }
                if !model.emergencyShortcutAvailable {
                    Label("Global stop shortcut unavailable. Automatic folding is disabled.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Label("On your Mac. Nothing saved or uploaded.", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("⌘⇧Esc to stop").font(.caption).foregroundStyle(.secondary)
                }
                Text("The effect clears automatically if the lid is held still or nearly closed.").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.frame(minWidth: 540, idealWidth: 620, maxWidth: .infinity, minHeight: 600, idealHeight: 940)
            .background(Color(nsColor: .windowBackgroundColor))
    }
    private func control(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title).frame(width: 90, alignment: .leading)
            Slider(value: value, in: 0...1).accessibilityLabel(title)
            Text("\(Int(value.wrappedValue * 100))%").monospacedDigit().frame(width: 44, alignment: .trailing)
        }
    }
}
