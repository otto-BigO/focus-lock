import SwiftUI

enum AppTab: Int, CaseIterable, Hashable {
    case focus = 0
    case history = 1
    case schedule = 2

    var label: String {
        switch self {
        case .focus:    return "Focus"
        case .history:  return "History"
        case .schedule: return "Schedule"
        }
    }

    var icon: String {
        switch self {
        case .focus:    return "target"
        case .history:  return "chart.bar.fill"
        case .schedule: return "calendar"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var previousTab: Int = 0

    var body: some View {
        ZStack {
            if selectedTab == 0 {
                ContentView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: selectedTab > previousTab ? 40 : -40, y: 0)),
                        removal: .opacity.combined(with: .offset(x: selectedTab > previousTab ? -40 : 40, y: 0))
                    ))
                    .id("focus")
            } else if selectedTab == 1 {
                HistoryView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: selectedTab > previousTab ? 40 : -40, y: 0)),
                        removal: .opacity.combined(with: .offset(x: selectedTab > previousTab ? -40 : 40, y: 0))
                    ))
                    .id("history")
            } else {
                ScheduleView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: 40, y: 0)),
                        removal: .opacity.combined(with: .offset(x: -40, y: 0))
                    ))
                    .id("schedule")
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedTab)
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selectedTab: $selectedTab, previousTab: $previousTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var previousTab: Int
    @Namespace private var indicatorNS

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                Button(action: {
                    if selectedTab != tab.rawValue {
                        previousTab = selectedTab
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            selectedTab = tab.rawValue
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(tab.label)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == tab.rawValue ? .white : Glass.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        ZStack {
                            if selectedTab == tab.rawValue {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.blue.opacity(0.25))
                                    .matchedGeometryEffect(id: "tabIndicator", in: indicatorNS)
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                                    .matchedGeometryEffect(id: "tabIndicatorBorder", in: indicatorNS)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .glassPanel(cornerRadius: 18, strokeOpacity: 0.18, shadowRadius: 16, shadowY: 6, shadowOpacity: 0.22)
    }
}
