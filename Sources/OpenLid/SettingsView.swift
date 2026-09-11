import SwiftUI
import FoldCore

private let ink = Color(red: 0.18, green: 0.22, blue: 0.20)
private let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
private let accent = Color(red: 0.76, green: 0.34, blue: 0.22)

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var page = "Appearance"

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 20) {
                header
                if page == "Appearance" { appearance }
                else if page == "General" { general }
                else { about }
                Spacer(minLength: 0)
                footer
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(paper)
        }
        .frame(width: 920, height: 680)
        .foregroundStyle(ink)
        .tint(accent)
        .preferredColorScheme(.light)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: "macbook.gen2").font(.system(size: 24, weight: .light))
                Text("OpenLid").font(.system(size: 21, weight: .semibold, design: .rounded))
            }.padding(.bottom, 4)
            Text("A little more alive.").font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.bottom, 32)
            nav("Appearance", icon: "slider.horizontal.3")
            nav("General", icon: "switch.2")
            nav("About", icon: "info.circle")
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(model.enabled ? .green : Color.gray.opacity(0.5)).frame(width: 6, height: 6)
                Text(model.enabled ? "Following your lid" : "Live effect paused").font(.system(size: 11))
            }
            Text("LOCAL BY DESIGN").font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1.4).foregroundStyle(.secondary).padding(.top, 8)
        }
        .padding(22)
        .frame(width: 192)
        .frame(maxHeight: .infinity)
        .background(Color(red: 0.91, green: 0.92, blue: 0.88))
    }

    private func nav(_ name: String, icon: String) -> some View {
        Button { page = name } label: {
            Label(name, systemImage: icon)
                .font(.system(size: 12, weight: page == name ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 11).padding(.vertical, 10)
                .background(page == name ? Color.white.opacity(0.65) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(page == "Appearance" ? "One continuous motion." : page == "General" ? "Make yourself at home." : "Small app. Open possibilities.")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                Text(page == "Appearance" ? "A softer landing for every close." : page == "General" ? "Your Mac, your controls." : "A freely available experiment in everyday delight.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Text("v0.1 · ALPHA").font(.system(size: 9, weight: .medium, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(ink.opacity(0.05), in: Capsule())
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                EffectPreview(angle: model.previewAngle, settings: model.settings)
                    .aspectRatio(16.0 / 10, contentMode: .fit)
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.90))
                HStack(spacing: 14) {
                    Text("TRY THE EFFECT").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
                    Slider(value: $model.previewAngle, in: 5...140, step: 1)
                        .accessibilityLabel("Preview lid angle")
                    Text("\(Int(model.previewAngle))°").font(.system(size: 12, design: .monospaced))
                        .monospacedDigit().frame(width: 34)
                }.padding(.horizontal, 20).padding(.vertical, 13).background(.white.opacity(0.65))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ink.opacity(0.07)))

            HStack(spacing: 10) {
                ForEach(FoldStyle.allCases) { style in
                    styleButton(style)
                }
            }

            HStack(spacing: 22) {
                control("Perspective", value: $model.settings.perspective)
                control("Softness", value: $model.settings.blur)
                control("Shadow", value: $model.settings.shade)
            }.padding(.top, 2)
            HStack {
                Image(systemName: "hand.draw").foregroundStyle(accent)
                Text("Preview uses the live renderer with generated artwork. No capture needed.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }

    private func styleButton(_ style: FoldStyle) -> some View {
        let selected = model.settings.style == style
        return Button { model.settings.style = style } label: {
            HStack(spacing: 10) {
                Image(systemName: style == .paper ? "square.stack.3d.up" : style == .dusk ? "moon" : "cloud.fog")
                    .font(.system(size: 18, weight: .light)).foregroundStyle(selected ? accent : ink.opacity(0.6))
                VStack(alignment: .leading, spacing: 3) {
                    Text(style.rawValue).font(.system(size: 12, weight: .semibold))
                    Text(style == .paper ? "Warm paper fold" : style == .dusk ? "Fade into night" : "Softer focus")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12)).foregroundStyle(selected ? accent : ink.opacity(0.18))
            }
            .padding(12).frame(maxWidth: .infinity)
            .background(selected ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? accent.opacity(0.5) : ink.opacity(0.1)))
        }.buttonStyle(.plain).accessibilityLabel("\(style.rawValue) style")
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func control(_ label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...1).accessibilityLabel(label)
        }.frame(maxWidth: .infinity)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 22) {
            infoRow("lid / sensor", title: "Hardware", detail: model.sensorStatus, icon: "laptopcomputer")
            Button("Recheck hardware") { model.checkSensor() }.disabled(model.enabled || model.busy)
            Divider()
            infoRow("privacy", title: "Local screen capture", detail: "Live mode needs Screen Recording access. Frames are processed on this Mac, never saved or uploaded. The preview uses generated artwork.", icon: "lock.shield")
            Button("Open Screen Recording settings") { model.openPermissionSettings() }
            Divider()
            HStack {
                Text("Clear the effect above").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(Int(model.settings.clearAngle))°").monospacedDigit()
            }
            Slider(value: $model.settings.clearAngle, in: 45...140, step: 1).accessibilityLabel("Clear angle")
            Text("A fully open lid restores the normal desktop. The effect pauses on sleep, lock, display changes, sensor errors, or after 15 seconds continuously active.")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
            Button("Use neutral baseline") { model.settings = FoldSettings() }
        }
        .padding(22).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }

    private func infoRow(_ eyebrow: String, title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 22, weight: .light)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "macbook.gen2").font(.system(size: 62, weight: .ultraLight)).foregroundStyle(accent)
            Text("Built to be opened.")
                .font(.system(size: 32, weight: .regular, design: .serif))
            Text("OpenLid is an independent, open-source macOS utility inspired by the idea of a desktop that moves with your MacBook lid. Native Swift. ScreenCaptureKit and Metal rendering. No accounts, subscriptions, or telemetry.")
                .font(.system(size: 13)).lineSpacing(6)
            Divider()
            HStack(spacing: 30) {
                Label("MIT licensed", systemImage: "curlybraces")
                Label("On-device only", systemImage: "lock")
                Label("macOS 14+", systemImage: "apple.logo")
            }.font(.system(size: 11))
            Text("Early local build · Hardware support varies.\nNot affiliated with Bendy. No Bendy code or assets are included.")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(5)
        }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }

    private var footer: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.enabled ? "A little movement. A little magic." : "Ready when you are.")
                    .font(.system(size: 12, weight: .semibold))
                Text(model.status).font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                if model.enabled { model.pause() } else { model.enable() }
            } label: {
                HStack(spacing: 8) {
                    Text(model.busy ? "Please wait…" : model.enabled ? "Pause effect" : "Enable live effect")
                    Image(systemName: model.enabled ? "pause" : "arrow.up.right")
                }.font(.system(size: 11, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 11)
                    .foregroundStyle(.white).background(ink, in: Capsule())
            }.buttonStyle(.plain).disabled(model.busy)
        }.padding(.top, 14).overlay(alignment: .top) { Divider() }
    }
}
