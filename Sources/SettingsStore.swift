import Foundation
import ServiceManagement

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let soundsKey = "focuslock.soundsEnabled"
    private let overlayKey = "focuslock.overlayEnabled"

    @Published var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: soundsKey) }
    }

    @Published var overlayEnabled: Bool {
        didSet { UserDefaults.standard.set(overlayEnabled, forKey: overlayKey) }
    }

    @Published var launchAtLogin: Bool

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: soundsKey) == nil { defaults.set(true, forKey: soundsKey) }
        if defaults.object(forKey: overlayKey) == nil { defaults.set(true, forKey: overlayKey) }
        self.soundsEnabled = defaults.bool(forKey: soundsKey)
        self.overlayEnabled = defaults.bool(forKey: overlayKey)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Launch at Login (SMAppService, macOS 13+)

    func enableLaunchAtLogin() {
        do {
            try SMAppService.mainApp.register()
            launchAtLogin = SMAppService.mainApp.status == .enabled
            print("[Settings] Launch-at-login registered (status=\(SMAppService.mainApp.status.rawValue))")
        } catch {
            print("[Settings] Launch-at-login register failed: \(error)")
            launchAtLogin = false
        }
    }

    func disableLaunchAtLogin() {
        do {
            try SMAppService.mainApp.unregister()
            launchAtLogin = SMAppService.mainApp.status == .enabled
            print("[Settings] Launch-at-login unregistered (status=\(SMAppService.mainApp.status.rawValue))")
        } catch {
            print("[Settings] Launch-at-login unregister failed: \(error)")
        }
    }

    func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ on: Bool) {
        if on { enableLaunchAtLogin() } else { disableLaunchAtLogin() }
    }
}
