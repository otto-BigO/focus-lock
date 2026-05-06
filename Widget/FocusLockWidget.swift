import WidgetKit
import SwiftUI

private let widgetSuiteName = "group.focuslock"

// MARK: - Entry

struct FocusLockEntry: TimelineEntry {
    let date: Date
    let minutesToday: Int
    let streak: Int
    let sessionsToday: Int
    let isSessionActive: Bool
    let last7Days: [Int]
}

// MARK: - Provider

struct FocusLockProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusLockEntry {
        FocusLockEntry(date: Date(), minutesToday: 0, streak: 0, sessionsToday: 0,
                       isSessionActive: false, last7Days: Array(repeating: 0, count: 7))
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusLockEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusLockEntry>) -> Void) {
        let entry = loadEntry()
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> FocusLockEntry {
        let suite = UserDefaults(suiteName: widgetSuiteName)
        let chart: [Int] = (suite?.data(forKey: "widget.last7DaysMinutes")
                            .flatMap { try? JSONDecoder().decode([Int].self, from: $0) })
                            ?? Array(repeating: 0, count: 7)
        return FocusLockEntry(
            date: Date(),
            minutesToday: suite?.integer(forKey: "widget.totalMinutesToday") ?? 0,
            streak: suite?.integer(forKey: "widget.currentStreak") ?? 0,
            sessionsToday: suite?.integer(forKey: "widget.sessionsToday") ?? 0,
            isSessionActive: suite?.bool(forKey: "widget.isSessionActive") ?? false,
            last7Days: chart
        )
    }
}

// MARK: - Background gradient

private let bgTop    = Color(red: 0x1a/255.0, green: 0x1f/255.0, blue: 0x3c/255.0)
private let bgBottom = Color(red: 0x2d/255.0, green: 0x5b/255.0, blue: 0xe3/255.0)

private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [bgTop, bgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Small widget

struct SmallWidgetView: View {
    let entry: FocusLockEntry

    var body: some View {
        ZStack(alignment: .leading) {
            WidgetBackground()
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text("\(entry.minutesToday)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                Text("min today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(entry.streak) day\(entry.streak == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Medium widget

struct MediumWidgetView: View {
    let entry: FocusLockEntry

    var body: some View {
        ZStack {
            WidgetBackground()
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.minutesToday)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    Text("min today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Text("\(entry.sessionsToday) session\(entry.sessionsToday == 1 ? "" : "s") today")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    HStack(spacing: 4) {
                        Text("🔥")
                        Text("\(entry.streak) day\(entry.streak == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("This week")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                    MiniChart(values: entry.last7Days)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
    }
}

private struct MiniChart: View {
    let values: [Int]

    var body: some View {
        let maxV = max(1, values.max() ?? 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { idx, v in
                let h = max(3, CGFloat(v) / CGFloat(maxV) * 50)
                let isToday = idx == values.count - 1
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(isToday ? 0.95 : 0.55))
                    .frame(width: 8, height: h)
            }
        }
    }
}

// MARK: - Widget definition

struct FocusLockWidget: Widget {
    let kind: String = "FocusLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusLockProvider()) { entry in
            FocusLockWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FocusLock")
        .description("Today's focus minutes and streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FocusLockWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FocusLockEntry

    var body: some View {
        switch family {
        case .systemMedium: MediumWidgetView(entry: entry)
        default:            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Bundle entry point

@main
struct FocusLockWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusLockWidget()
    }
}
