import SwiftUI

struct HistoryView: View {
    @ObservedObject var store = SessionStore.shared

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    StatsRow()
                    WeeklyChart()
                    SessionLogSection()
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Stats row

private struct StatsRow: View {
    @ObservedObject var store = SessionStore.shared

    var body: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(store.totalSessionsCompleted)", label: "sessions")
            StatCard(value: formatDuration(store.totalFocusMinutes), label: "total focus")
            StatCard(value: "\(store.currentStreak) days 🔥", label: "current streak")
            StatCard(value: "\(store.averageSessionMinutes) min", label: "avg session")
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h) hrs" : "\(h)h \(m)m"
        }
        return "\(minutes) min"
    }
}

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Glass.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: value)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Glass.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .glassPanel(cornerRadius: 14)
    }
}

// MARK: - Weekly bar chart

private struct WeeklyChart: View {
    @ObservedObject var store = SessionStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Glass.textPrimary)
                .padding(.leading, 4)

            let data = store.focusMinutesByDay
            let maxMinutes = max(1, data.map { $0.minutes }.max() ?? 1)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, day in
                    DayBar(day: day, maxMinutes: maxMinutes)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
    }
}

private struct DayBar: View {
    let day: (day: String, minutes: Int, isToday: Bool)
    let maxMinutes: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(day.minutes > 0 ? "\(day.minutes)" : " ")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(Glass.textTertiary)
                .frame(height: 12)

            ZStack(alignment: .bottom) {
                Color.clear.frame(width: 1, height: 80)
                if day.minutes == 0 {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 22, height: 4)
                } else {
                    let h = max(4, CGFloat(day.minutes) / CGFloat(maxMinutes) * 80)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: day.isToday
                                    ? [Color.blue.opacity(0.85), Color.blue.opacity(0.5)]
                                    : [Color.blue.opacity(0.6), Color.blue.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 22, height: h)
                }
            }
            .frame(height: 80)

            Text(day.day)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(day.isToday ? Glass.textPrimary : Glass.textSecondary)

            Circle()
                .fill(day.isToday ? Glass.accent : Color.clear)
                .frame(width: 4, height: 4)
        }
    }
}

// MARK: - Session log

private struct SessionLogSection: View {
    @ObservedObject var store = SessionStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Glass.textPrimary)
                .padding(.leading, 4)

            if store.sessions.isEmpty {
                EmptyStateView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(store.sessions.prefix(50))) { session in
                        SessionRow(session: session)
                    }
                }
            }
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 44, weight: .regular))
                .foregroundColor(Color.white.opacity(0.30))
            Text("No sessions yet.\nStart your first focus block.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Glass.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .glassPanel(cornerRadius: 14)
    }
}

private struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.completedNaturally ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(session.completedNaturally
                                 ? Color.green.opacity(0.85)
                                 : Color.orange.opacity(0.85))

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Glass.textPrimary)
                Text(blockedSummary)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Glass.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Text("\(max(1, session.actualDuration / 60)) min")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(session.completedNaturally
                                 ? Glass.accent
                                 : Glass.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 12, strokeOpacity: 0.10, shadowRadius: 12, shadowY: 4, shadowOpacity: 0.10)
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: session.startedAt)
        if calendar.isDate(session.startedAt, inSameDayAs: now) {
            return "Today, \(timeStr)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(session.startedAt, inSameDayAs: yesterday) {
            return "Yesterday, \(timeStr)"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, HH:mm"
        return dateFormatter.string(from: session.startedAt)
    }

    private var blockedSummary: String {
        let all = session.blockedApps + session.blockedWebsites
        guard !all.isEmpty else { return "Nothing blocked" }
        let firstTwo = all.prefix(2).joined(separator: ", ")
        let remaining = all.count - 2
        if remaining > 0 {
            return "\(firstTwo) and \(remaining) more"
        }
        return firstTwo
    }
}
