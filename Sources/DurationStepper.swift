import SwiftUI

/// Glass pill stepper: minus + value + plus.
/// Tap = single step. Hold = step every 0.15s after a 0.35s delay.
struct DurationStepper: View {
    @Binding var value: Int
    var minValue: Int = 5
    var maxValue: Int = 180
    var step: Int = 5

    var body: some View {
        HStack(spacing: 0) {
            StepperButton(symbol: "minus") {
                value = max(minValue, value - step)
            }

            Spacer(minLength: 0)

            Text("\(value) min")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Glass.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.18), value: value)

            Spacer(minLength: 0)

            StepperButton(symbol: "plus") {
                value = min(maxValue, value + step)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct StepperButton: View {
    let symbol: String
    let action: () -> Void

    @State private var holdTimer: Timer?
    @State private var isPressed: Bool = false

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.10))
            Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Glass.textPrimary)
        }
        .frame(width: 28, height: 28)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.65), value: isPressed)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    action()
                    let symbolCopy = symbol
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        // After delay: if still pressed, start auto-repeat.
                        if isPressed {
                            let t = Timer(timeInterval: 0.15, repeats: true) { _ in
                                action()
                            }
                            RunLoop.main.add(t, forMode: .common)
                            holdTimer = t
                        }
                        _ = symbolCopy
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    holdTimer?.invalidate()
                    holdTimer = nil
                }
        )
    }
}
