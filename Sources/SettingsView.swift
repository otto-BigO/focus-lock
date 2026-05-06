import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Glass.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Glass.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)
                .padding(.horizontal, 18)

                VStack(spacing: 10) {
                    ToggleRow(
                        title: "Launch at Login",
                        subtitle: "Open FocusLock automatically when you log in",
                        isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { settings.setLaunchAtLogin($0) }
                        )
                    )

                    ToggleRow(
                        title: "Play sounds",
                        subtitle: "Sound effects on session start, end, and cancel",
                        isOn: $settings.soundsEnabled
                    )

                    ToggleRow(
                        title: "Show completion overlay",
                        subtitle: "Floating panel when a session finishes",
                        isOn: $settings.overlayEnabled
                    )
                }
                .padding(.horizontal, 18)

                Spacer()

                HStack {
                    Spacer()
                    Text("FocusLock 1.0")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Glass.textTertiary)
                    Spacer()
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 420, height: 360)
        .preferredColorScheme(.dark)
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Glass.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Glass.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Glass.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(cornerRadius: 12, strokeOpacity: 0.10, shadowRadius: 10, shadowY: 3, shadowOpacity: 0.10)
    }
}
