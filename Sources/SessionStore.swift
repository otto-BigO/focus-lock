import Foundation

struct FocusSession: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let plannedDuration: Int    // minutes
    let actualDuration: Int     // seconds
    let completedNaturally: Bool
    let blockedApps: [String]
    let blockedWebsites: [String]
}

final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published var sessions: [FocusSession] = []

    private let storageKey = "focuslock.sessions"

    private init() {
        loadFromDisk()
    }

    func recordSession(_ session: FocusSession) {
        sessions.insert(session, at: 0)
        saveToDisk()
        print("[SessionStore] Recorded session — completed=\(session.completedNaturally) elapsed=\(session.actualDuration)s apps=\(session.blockedApps.count) sites=\(session.blockedWebsites.count)")
    }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            return
        }
        sessions = decoded
    }

    // MARK: - Stats

    var totalSessionsCompleted: Int {
        sessions.filter { $0.completedNaturally }.count
    }

    var totalFocusMinutes: Int {
        sessions.reduce(0) { $0 + $1.actualDuration / 60 }
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let completedDays: Set<Date> = Set(
            sessions
                .filter { $0.completedNaturally }
                .map { calendar.startOfDay(for: $0.startedAt) }
        )
        guard !completedDays.isEmpty else { return 0 }
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while completedDays.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    var longestStreak: Int {
        let calendar = Calendar.current
        let completedDays = Set(
            sessions
                .filter { $0.completedNaturally }
                .map { calendar.startOfDay(for: $0.startedAt) }
        ).sorted()
        guard !completedDays.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<completedDays.count {
            let prev = completedDays[i - 1]
            let curr = completedDays[i]
            if let next = calendar.date(byAdding: .day, value: 1, to: prev), next == curr {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    var averageSessionMinutes: Int {
        let completed = sessions.filter { $0.completedNaturally }
        guard !completed.isEmpty else { return 0 }
        let total = completed.reduce(0) { $0 + $1.actualDuration / 60 }
        return total / completed.count
    }

    var sessionsThisWeek: [FocusSession] {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        return sessions.filter { $0.startedAt >= weekAgo }
    }

    /// Last 7 days, oldest → newest. The last entry is always today.
    var focusMinutesByDay: [(day: String, minutes: Int, isToday: Bool)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let today = calendar.startOfDay(for: Date())
        var result: [(day: String, minutes: Int, isToday: Bool)] = []
        for offset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let label = formatter.string(from: day)
            let minutes = sessions
                .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.actualDuration / 60 }
            result.append((day: label, minutes: minutes, isToday: calendar.isDate(day, inSameDayAs: today)))
        }
        return result
    }
}
