import Foundation
import UserNotifications

struct ScheduledSession: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var weekdays: Set<Int>          // 0 = Sunday ... 6 = Saturday
    var startHour: Int              // 0-23
    var startMinute: Int            // 0-59
    var durationMinutes: Int
    var blockedAppIDs: Set<String>
    var blockedWebsiteIDs: Set<String>
    var isEnabled: Bool = true
}

final class ScheduleStore: ObservableObject {
    static let shared = ScheduleStore()

    @Published var schedules: [ScheduledSession] = [] {
        didSet { reschedule() }
    }

    private let storageKey = "focuslock.schedules"
    private var pollTimer: Timer?
    private var lastFiredIDs: [UUID: Date] = [:]

    private init() {
        loadFromDisk()
        startPollingTimer()
        Task { @MainActor in self.reschedule() }
    }

    // MARK: - CRUD

    func add(_ s: ScheduledSession) {
        schedules.append(s)
        saveToDisk()
    }

    func update(_ s: ScheduledSession) {
        if let idx = schedules.firstIndex(where: { $0.id == s.id }) {
            schedules[idx] = s
            saveToDisk()
        }
    }

    func remove(id: UUID) {
        schedules.removeAll { $0.id == id }
        saveToDisk()
    }

    func toggleEnabled(id: UUID) {
        if let idx = schedules.firstIndex(where: { $0.id == id }) {
            schedules[idx].isEnabled.toggle()
            saveToDisk()
        }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ScheduledSession].self, from: data) else {
            return
        }
        schedules = decoded
    }

    // MARK: - Notification scheduling

    private func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for s in schedules where s.isEnabled {
            for weekday in s.weekdays {
                var comps = DateComponents()
                comps.weekday = weekday + 1   // Calendar uses 1 = Sunday
                comps.hour = s.startHour
                comps.minute = s.startMinute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let content = UNMutableNotificationContent()
                content.title = "FocusLock Starting"
                content.body = "Your '\(s.label)' session is beginning"
                content.sound = .default
                let id = "\(s.id.uuidString)-\(weekday)"
                let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                center.add(req) { error in
                    if let error = error {
                        print("[ScheduleStore] notif add failed: \(error)")
                    }
                }
            }
        }
        saveToDisk()
    }

    // MARK: - In-app firing (Timer-based, runs while app is open)

    private func startPollingTimer() {
        pollTimer?.invalidate()
        let t = Timer(timeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func tick() {
        guard !FocusManager.shared.isSessionActive else { return }
        let now = Date()
        for s in schedules where s.isEnabled {
            if scheduleMatches(s, at: now), shouldFire(s, at: now) {
                fire(s)
                lastFiredIDs[s.id] = now
            }
        }
    }

    func scheduleMatches(_ schedule: ScheduledSession, at date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date) - 1   // 0..6
        guard schedule.weekdays.contains(weekday) else { return false }
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        // 1-minute window
        let nowTotal = hour * 60 + minute
        let schedTotal = schedule.startHour * 60 + schedule.startMinute
        return abs(nowTotal - schedTotal) <= 1
    }

    private func shouldFire(_ s: ScheduledSession, at now: Date) -> Bool {
        guard let last = lastFiredIDs[s.id] else { return true }
        return now.timeIntervalSince(last) > 120
    }

    private func fire(_ s: ScheduledSession) {
        print("[ScheduleStore] Firing schedule '\(s.label)' (\(s.durationMinutes) min)")
        // Apply this schedule's selections to FocusManager and the website blocker.
        FocusManager.shared.selectedAppBundleIDs = s.blockedAppIDs
        let blocker = WebsiteBlocker.shared
        for i in 0..<blocker.blockedWebsites.count {
            blocker.blockedWebsites[i].isSelected = s.blockedWebsiteIDs.contains(blocker.blockedWebsites[i].id.uuidString)
        }
        FocusManager.shared.startSession(duration: s.durationMinutes)
    }
}
