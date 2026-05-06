import SwiftUI
import AppKit

enum LeftPanelTab: String, CaseIterable, Hashable {
    case apps = "Apps"
    case websites = "Websites"
}

struct ContentView: View {
    @ObservedObject var manager = FocusManager.shared
    @ObservedObject var blocker = WebsiteBlocker.shared
    @State private var leftTab: LeftPanelTab = .apps
    @State private var showSettings: Bool = false

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { geo in
                let totalWidth = geo.size.width - 32 - 12  // padding 16+16, gap 12
                let leftWidth = floor(totalWidth * 0.55)
                let rightWidth = totalWidth - leftWidth

                HStack(spacing: 12) {
                    LeftPanel(tab: $leftTab)
                        .frame(width: leftWidth, height: geo.size.height - 24 - 16)
                        .glassPanel()

                    ZStack {
                        if manager.isSessionActive {
                            SessionActiveView()
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                        removal: .opacity.combined(with: .scale(scale: 1.04))
                                    )
                                )
                        } else {
                            TimerPickerView()
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                        removal: .opacity.combined(with: .scale(scale: 1.04))
                                    )
                                )
                        }
                    }
                    .frame(width: rightWidth, height: geo.size.height - 24 - 16)
                    .glassPanel()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.isSessionActive)
            }

            // Gear button — top-right, above panels.
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Glass.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(PressableScaleStyle())
                    .help("Settings")
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
                Spacer()
            }

            // First-run admin explainer for /etc/hosts blocking
            if blocker.needsExplanation {
                AdminExplainerSheet()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: blocker.needsExplanation)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Left panel (segmented Apps/Websites)

private struct LeftPanel: View {
    @Binding var tab: LeftPanelTab
    @ObservedObject var manager = FocusManager.shared

    var body: some View {
        VStack(spacing: 0) {
            GlassSegmentedPicker(selection: $tab, options: LeftPanelTab.allCases.map { ($0, $0.rawValue) })
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .disabled(manager.isSessionActive)
                .opacity(manager.isSessionActive ? 0.4 : 1.0)

            ZStack {
                switch tab {
                case .apps:
                    AppListView()
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity.combined(with: .move(edge: .trailing))
                            )
                        )
                case .websites:
                    WebsiteListView()
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            )
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: tab)
        }
    }
}

// MARK: - Custom glass segmented picker

private struct GlassSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { (value, label) in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = value
                    }
                }) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(selection == value ? Glass.textPrimary : Glass.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(
                            ZStack {
                                if selection == value {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - First-run admin explainer

private struct AdminExplainerSheet: View {
    @ObservedObject var blocker = WebsiteBlocker.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { blocker.cancelExplainer() }

            VStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundColor(Glass.accent)

                Text("Admin access required")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Glass.textPrimary)

                Text("FocusLock needs admin access once to block websites via /etc/hosts. Your password is only used by macOS and is never stored.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Glass.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                HStack(spacing: 10) {
                    Button(action: { blocker.cancelExplainer() }) {
                        Text("Skip")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Glass.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableScaleStyle())

                    Button(action: { blocker.confirmExplainerAndBlock() }) {
                        Text("Continue")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.75), Color.blue.opacity(0.55)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableScaleStyle())
                }
            }
            .padding(20)
            .frame(width: 320)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 22, x: 0, y: 8)
        }
    }
}

// MARK: - Session active view (right panel during session)

struct SessionActiveView: View {
    @ObservedObject var manager = FocusManager.shared
    @ObservedObject var clock = SessionClock.shared

    private var progress: Double {
        let initialEstimate = ((clock.secondsRemaining + 59) / 60) * 60
        let denom = max(initialEstimate, 1)
        return 1.0 - (Double(clock.secondsRemaining) / Double(denom))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Focus Session")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Glass.textPrimary)

            Spacer().frame(height: 4)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 3)
                        .frame(width: 200, height: 200)

                    Circle()
                        .trim(from: 0, to: max(0.001, progress))
                        .stroke(
                            Glass.accent,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 200, height: 200)
                        .animation(.easeInOut(duration: 0.5), value: progress)

                    VStack(spacing: 6) {
                        Text(clock.formattedTime())
                            .font(.system(size: 56, weight: .thin, design: .default))
                            .foregroundColor(Glass.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.25), value: clock.secondsRemaining)
                        Text("Stay focused 💪")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Glass.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Text("\(manager.selectedAppBundleIDs.count) app\(manager.selectedAppBundleIDs.count == 1 ? "" : "s") blocked")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Glass.textTertiary)
            }
            .frame(maxWidth: .infinity)

            Spacer()

            Button(action: { manager.cancelSession() }) {
                HStack {
                    Spacer()
                    Text("Cancel Session")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                    Spacer()
                }
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.55), Color.red.opacity(0.40)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .allowsHitTesting(false)
                )
            }
            .buttonStyle(PressableScaleStyle())
        }
        .padding(20)
    }
}
