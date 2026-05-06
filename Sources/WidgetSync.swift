import Foundation
import Combine
import WidgetKit

/// Mirrors session stats into a shared UserDefaults suite so the widget can
/// read them. Observes SessionStore + FocusManager via Combine — no changes
/// required to those classes' logic.
final class WidgetSync {
    static let shared = WidgetSync()
    static let suiteName = "group.focuslock"

    private let suite: UserDefaults?
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        suite = UserDefaults(suiteName: WidgetSync.suiteName)
        observe()
        sync()
    }

    private func observe() {
        SessionStore.shared.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &cancellables)

        FocusManager.shared.$isSessionActive
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &cancellables)
    }

    func sync() {
        guard let suite = suite else { return }
        let store = SessionStore.shared
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let todaySessions = store.sessions.filter { cal.isDate($0.startedAt, inSameDayAs: today) }
        let totalMinutesToday = todaySessions.reduce(0) { $0 + $1.actualDuration / 60 }
        let sessionsToday = todaySessions.count

        suite.set(totalMinutesToday, forKey: "widget.totalMinutesToday")
        suite.set(store.currentStreak, forKey: "widget.currentStreak")
        suite.set(sessionsToday, forKey: "widget.sessionsToday")
        suite.set(FocusManager.shared.isSessionActive, forKey: "widget.isSessionActive")

        // Last 7 days minutes for the medium widget chart.
        let chartData: [Int] = store.focusMinutesByDay.map { $0.minutes }
        if let data = try? JSONEncoder().encode(chartData) {
            suite.set(data, forKey: "widget.last7DaysMinutes")
        }

        if #available(macOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
