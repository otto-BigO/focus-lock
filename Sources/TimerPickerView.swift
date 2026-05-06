import SwiftUI

struct TimerPickerView: View {
    @ObservedObject var manager = FocusManager.shared
    @State private var selectedDuration: Int = 25

    private let presets = [1, 15, 25, 45, 60, 90]
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Focus Duration")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Glass.textPrimary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(presets, id: \.self) { minutes in
                    DurationTile(
                        minutes: minutes,
                        selected: selectedDuration == minutes,
                        action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedDuration = minutes
                            }
                        }
                    )
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    manager.startSession(duration: selectedDuration)
                }) {
                    HStack {
                        Spacer()
                        Text("Start Session")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 44)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: canStart
                                            ? [Color.blue.opacity(0.75), Color.blue.opacity(0.55)]
                                            : [Color.gray.opacity(0.35), Color.gray.opacity(0.25)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                                .allowsHitTesting(false)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                    )
                    .opacity(canStart ? 1.0 : 0.4)
                    .shadow(color: Color.blue.opacity(canStart ? 0.30 : 0), radius: 14, x: 0, y: 6)
                }
                .buttonStyle(PressableScaleStyle())
                .disabled(!canStart)

                Text(footerText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Glass.textTertiary)
                    .padding(.leading, 4)
            }
        }
        .padding(20)
        .padding(.top, 4)
    }

    private var canStart: Bool {
        !manager.selectedAppBundleIDs.isEmpty && !manager.isSessionActive
    }

    private var footerText: String {
        if manager.selectedAppBundleIDs.isEmpty {
            return "Select at least one app to block"
        }
        let n = manager.selectedAppBundleIDs.count
        return "\(n) app\(n == 1 ? "" : "s") will be blocked"
    }
}

private struct DurationTile: View {
    let minutes: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(minutes)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Glass.textPrimary)
                    .monospacedDigit()
                Text("min")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Glass.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)

                    if selected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue.opacity(0.15))
                    }

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .allowsHitTesting(false)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selected ? Color.blue.opacity(0.40) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .scaleEffect(selected ? 1.02 : 1.0)
        }
        .buttonStyle(PressableScaleStyle(pressedScale: 0.95))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selected)
    }
}
