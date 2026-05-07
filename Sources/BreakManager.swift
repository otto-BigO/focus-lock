import Foundation
import AppKit
import UserNotifications

final class BreakManager: ObservableObject {
    static let shared = BreakManager()

    @Published var isBreakActive: Bool = false
    @Published var breakSecondsRemaining: Int = 0
    @Published var suggestedBreakMinutes: Int = 0
    @Published var breakSecondsTotal: Int = 0

    private(set) var lastFocusedMinutes: Int = 0
    private var timer: Timer?

    private init() {}

    static func suggestedBreak(forFocusMinutes minutes: Int) -> Int {
        switch minutes {
        case ..<20:    return 0
        case 20...35:  return 5
        case 36...60:  return 10
        case 61...90:  return 15
        default:       return 20
        }
    }

    func startBreak(focusMinutes: Int) {
        let enabled = (UserDefaults.standard.object(forKey: "focuslock.breakRemindersEnabled") as? Bool) ?? true
        guard enabled else { return }

        let suggested = Self.suggestedBreak(forFocusMinutes: focusMinutes)
        guard suggested > 0 else { return }

        lastFocusedMinutes = focusMinutes
        suggestedBreakMinutes = suggested
        breakSecondsRemaining = suggested * 60
        breakSecondsTotal = suggested * 60
        isBreakActive = true

        if SettingsStore.shared.soundsEnabled { NSSound(named: "Blow")?.play() }

        timer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.breakSecondsRemaining -= 1
            if self.breakSecondsRemaining <= 0 {
                self.endBreak()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        print("[BreakManager] Started \(suggested)-min break (focused \(focusMinutes) min)")
    }

    func skipBreak() {
        timer?.invalidate()
        timer = nil
        if SettingsStore.shared.soundsEnabled { NSSound(named: "Basso")?.play() }
        isBreakActive = false
        breakSecondsRemaining = 0
        SessionStore.shared.updateLastSession(breakTaken: false, breakDuration: 0)
        print("[BreakManager] Break skipped")
    }

    func endBreak() {
        timer?.invalidate()
        timer = nil
        if SettingsStore.shared.soundsEnabled { NSSound(named: "Hero")?.play() }
        isBreakActive = false
        breakSecondsRemaining = 0
        BreakCompleteOverlay.shared.show()
        postBreakCompleteNotification()
        SessionStore.shared.updateLastSession(breakTaken: true, breakDuration: suggestedBreakMinutes)
        print("[BreakManager] Break ended naturally")
    }

    func formattedBreakTime() -> String {
        let m = breakSecondsRemaining / 60
        let s = breakSecondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func postBreakCompleteNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = "Break's over 💪"
            content.body  = "Ready to focus again? Start your next session."
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(req) { error in
                if let error = error { print("[BreakManager] notif error: \(error)") }
            }
        }
    }
}
