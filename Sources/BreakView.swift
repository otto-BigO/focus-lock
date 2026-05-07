import SwiftUI

struct BreakView: View {
    @ObservedObject var manager = BreakManager.shared
    @State private var rotation: Double = 0

    private var progress: Double {
        guard manager.breakSecondsTotal > 0 else { return 0 }
        return 1.0 - (Double(manager.breakSecondsRemaining) / Double(manager.breakSecondsTotal))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(Color.green.opacity(0.85))
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    rotation = 0
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            VStack(spacing: 4) {
                Text("Break Time")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Glass.textPrimary)
                Text("You focused for \(manager.lastFocusedMinutes) minute\(manager.lastFocusedMinutes == 1 ? "" : "s"). Rest up.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Glass.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 3)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: max(0.001, 1.0 - progress))
                    .stroke(
                        Color.green.opacity(0.70),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                    .animation(.easeInOut(duration: 0.5), value: progress)

                VStack(spacing: 4) {
                    Text(manager.formattedBreakTime())
                        .font(.system(size: 48, weight: .thin))
                        .foregroundColor(Glass.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.25), value: manager.breakSecondsRemaining)
                    Text("remaining")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Glass.textTertiary)
                }
            }
            .padding(.vertical, 4)

            HStack(spacing: 10) {
                Button(action: { manager.skipBreak() }) {
                    Text("Skip Break")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Glass.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(PressableScaleStyle())

                Button(action: { manager.skipBreak() }) {
                    Text("Start Focus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.65), Color.blue.opacity(0.45)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                        )
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
