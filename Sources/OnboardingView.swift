import SwiftUI
import AppKit
import ApplicationServices

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage: Int = 0
    @State private var previousPage: Int = 0
    @State private var appeared: Bool = false

    private let pageCount = 3

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                ZStack {
                    if currentPage == 0 {
                        WelcomePage()
                            .transition(pageTransition)
                            .id("welcome")
                    } else if currentPage == 1 {
                        HowItWorksPage()
                            .transition(pageTransition)
                            .id("how")
                    } else {
                        PermissionsPage(onGetStarted: complete)
                            .transition(pageTransition)
                            .id("permissions")
                    }
                }
                .animation(.spring(response: 0.40, dampingFraction: 0.85), value: currentPage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                PageDots(count: pageCount, current: currentPage)
                    .padding(.bottom, 18)
            }

            // Top-right Next button on pages 0 and 1
            VStack {
                HStack {
                    Spacer()
                    if currentPage < 2 {
                        Button(action: goNext) {
                            HStack(spacing: 4) {
                                Text("Next")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(Glass.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(Color.white.opacity(0.10))
                            )
                            .overlay(
                                Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(PressableScaleStyle())
                        .transition(.opacity)
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 18)
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -60, currentPage < pageCount - 1 {
                        previousPage = currentPage
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.85)) { currentPage += 1 }
                    } else if value.translation.width > 60, currentPage > 0 {
                        previousPage = currentPage
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.85)) { currentPage -= 1 }
                    }
                }
        )
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }

    private var pageTransition: AnyTransition {
        let goingForward = currentPage > previousPage
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: goingForward ? 60 : -60, y: 0)),
            removal: .opacity.combined(with: .offset(x: goingForward ? -60 : 60, y: 0))
        )
    }

    private func goNext() {
        guard currentPage < pageCount - 1 else { return }
        previousPage = currentPage
        withAnimation(.spring(response: 0.40, dampingFraction: 0.85)) { currentPage += 1 }
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "focuslock.onboardingComplete")
        withAnimation(.easeOut(duration: 0.30)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            isPresented = false
        }
    }
}

// MARK: - Page 1 — Welcome

private struct WelcomePage: View {
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.95), Color.blue.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.blue.opacity(0.30), radius: 18, x: 0, y: 6)
                .scaleEffect(pulse ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

            Text("Welcome to FocusLock")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Block distracting apps and websites so you can do your best work.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}

// MARK: - Page 2 — How it works

private struct HowItWorksPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer().frame(height: 4)
            Text("How it works")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 10) {
                StepCard(icon: "checkmark.square", title: "Choose apps and websites to block")
                StepCard(icon: "timer",            title: "Set a focus duration")
                StepCard(icon: "bolt.shield",      title: "Start — we handle the rest")
            }
            Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StepCard: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.18))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.blue.opacity(0.95))
            }
            .frame(width: 36, height: 36)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Glass.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .glassPanel(cornerRadius: 12, strokeOpacity: 0.10, shadowRadius: 10, shadowY: 3, shadowOpacity: 0.10)
    }
}

// MARK: - Page 3 — Permissions

private struct PermissionsPage: View {
    let onGetStarted: () -> Void

    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer().frame(height: 4)
            Text("Two permissions needed")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 10) {
                PermissionCard(
                    title: "Accessibility Access",
                    subtitle: "Required to quit blocked apps",
                    granted: accessibilityGranted,
                    action: openAccessibilitySettings
                )
                PermissionCard(
                    title: "Admin Access",
                    subtitle: "Required to block websites via /etc/hosts",
                    granted: nil,
                    sideLabel: "Asked when needed",
                    action: nil
                )
            }

            Spacer()

            Button(action: onGetStarted) {
                HStack {
                    Spacer()
                    Text("Get Started")
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
                                    colors: [Color.blue.opacity(0.75), Color.blue.opacity(0.55)],
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
                .shadow(color: Color.blue.opacity(0.30), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(PressableScaleStyle())
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct PermissionCard: View {
    let title: String
    let subtitle: String
    let granted: Bool?       // nil = N/A indicator
    var sideLabel: String? = nil
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Glass.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Glass.textTertiary)
            }

            Spacer()

            if let label = sideLabel {
                Text(label)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Glass.textTertiary)
            } else if let action = action, granted != true {
                Button(action: action) {
                    Text("Grant Access")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.blue.opacity(0.55)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
                }
                .buttonStyle(PressableScaleStyle())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 60)
        .glassPanel(cornerRadius: 12, strokeOpacity: 0.10, shadowRadius: 10, shadowY: 3, shadowOpacity: 0.10)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if granted == true {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color.green.opacity(0.85))
        } else if granted == false {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color.orange.opacity(0.85))
        } else {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Color.white.opacity(0.45))
        }
    }
}

// MARK: - Page dots

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.white.opacity(0.85) : Color.white.opacity(0.20))
                    .frame(width: 7, height: 7)
                    .scaleEffect(i == current ? 1.0 : 0.85)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: current)
            }
        }
    }
}
