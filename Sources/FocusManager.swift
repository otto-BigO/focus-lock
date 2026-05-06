import Foundation
import AppKit
import SwiftUI
import ApplicationServices
import UserNotifications

struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: NSImage?

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// Isolated so only SessionActiveView subscribes to per-second ticks.
final class SessionClock: ObservableObject {
    static let shared = SessionClock()
    @Published var secondsRemaining: Int = 0
    private init() {}

    func formattedTime() -> String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }
}

final class FocusManager: ObservableObject {
    static let shared = FocusManager()

    @Published var isSessionActive: Bool = false
    @Published var selectedAppBundleIDs: Set<String> = []
    @Published var installedApps: [AppInfo] = []

    var secondsRemaining: Int {
        get { SessionClock.shared.secondsRemaining }
        set { SessionClock.shared.secondsRemaining = newValue }
    }

    private var timer: Timer?
    private var tickCount: Int = 0
    private var launchObserver: NSObjectProtocol?
    private var sessionStartTime: Date?
    private var sessionDuration: Int = 0   // minutes

    private init() {
        loadInstalledApps()
        requestNotificationPermissionIfNeeded()
    }

    private static let notifPermissionRequestedKey = "FocusLock.notifPermissionRequested"

    private func requestNotificationPermissionIfNeeded() {
        let defaults = UserDefaults.standard
        let alreadyRequested = defaults.bool(forKey: Self.notifPermissionRequestedKey)
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined && !alreadyRequested {
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    defaults.set(true, forKey: Self.notifPermissionRequestedKey)
                    if let error = error {
                        print("[FocusLock] Notification auth error: \(error)")
                    } else {
                        print("[FocusLock] Notification permission granted: \(granted)")
                    }
                }
            } else {
                print("[FocusLock] Notification status: \(settings.authorizationStatus.rawValue)")
            }
        }
    }

    private func postSessionCompleteNotification() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                print("[FocusLock] Skipping notification — not authorized (status=\(settings.authorizationStatus.rawValue))")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Session Complete 🎉"
            content.body = "Great work. Your apps are unlocked."
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(req) { error in
                if let error = error {
                    print("[FocusLock] Notification post error: \(error)")
                } else {
                    print("[FocusLock] Notification posted")
                }
            }
        }
    }

    func loadInstalledApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let dirs = ["/Applications", "/System/Applications"]
            var found: [AppInfo] = []
            var seenIDs = Set<String>()

            for dir in dirs {
                self.scanDirectory(dir, fm: fm, into: &found, seenIDs: &seenIDs, depth: 0)
            }

            let filtered = found.filter { app in
                if app.id == "com.focuslock.FocusLock" { return false }
                if app.id == "com.apple.finder" { return false }
                if app.id.hasPrefix("com.apple.systempreferences") { return false }
                return true
            }

            let sorted = filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self.installedApps = sorted
                print("[FocusLock] Loaded \(sorted.count) installed apps")
            }
        }
    }

    private func scanDirectory(_ path: String, fm: FileManager, into found: inout [AppInfo], seenIDs: inout Set<String>, depth: Int) {
        guard depth <= 1 else { return }
        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return }
        for entry in contents {
            let fullPath = (path as NSString).appendingPathComponent(entry)
            if entry.hasSuffix(".app") {
                if let info = appInfo(at: fullPath), !seenIDs.contains(info.id) {
                    seenIDs.insert(info.id)
                    found.append(info)
                }
            } else {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    self.scanDirectory(fullPath, fm: fm, into: &found, seenIDs: &seenIDs, depth: depth + 1)
                }
            }
        }
    }

    private func appInfo(at path: String) -> AppInfo? {
        let bundle = Bundle(path: path)
        guard let bundleID = bundle?.bundleIdentifier else { return nil }
        let name: String = (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 32, height: 32)
        return AppInfo(id: bundleID, name: name, icon: icon)
    }

    func requestAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        print("[FocusLock] Accessibility trusted: \(trusted)")
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility access required"
            alert.informativeText = "FocusLock needs Accessibility access to quit blocked apps. Click OK to open System Settings, then enable FocusLock under Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Later")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    func startSession(duration: Int) {
        guard !isSessionActive else { return }
        print("[FocusLock] Starting session for \(duration) minute(s) — blocking \(selectedAppBundleIDs.count) app(s): \(selectedAppBundleIDs)")
        sessionStartTime = Date()
        sessionDuration = duration
        isSessionActive = true
        secondsRemaining = duration * 60
        tickCount = 0
        quitBlockedApps()
        WebsiteBlocker.shared.blockAll()
        if SettingsStore.shared.soundsEnabled { NSSound(named: "Purr")?.play() }

        installLaunchObserver()

        timer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.secondsRemaining -= 1
            self.tickCount += 1
            if self.tickCount % 2 == 0 {
                self.quitBlockedApps()
            }
            if self.secondsRemaining <= 0 {
                self.endSession()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    func quitBlockedApps() {
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            if let bid = app.bundleIdentifier, selectedAppBundleIDs.contains(bid) {
                print("[FocusLock] Quitting \(bid) (pid \(app.processIdentifier))")
                app.forceTerminate()
            }
        }
    }

    private func installLaunchObserver() {
        if let obs = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self, self.isSessionActive else { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard let bid = app.bundleIdentifier else { return }
            if self.selectedAppBundleIDs.contains(bid) {
                print("[FocusLock] Launch detected: \(bid) — terminating immediately")
                app.forceTerminate()
            }
        }
    }

    private func removeLaunchObserver() {
        if let obs = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            launchObserver = nil
        }
    }

    func endSession() {
        print("[FocusLock] Session ended")
        recordSession(completedNaturally: true)
        timer?.invalidate()
        timer = nil
        removeLaunchObserver()
        WebsiteBlocker.shared.unblockAll()
        isSessionActive = false
        secondsRemaining = 0
        if SettingsStore.shared.soundsEnabled { NSSound(named: "Glass")?.play() }
        if SettingsStore.shared.overlayEnabled { CompletionOverlay.shared.show() }
        postSessionCompleteNotification()
    }

    func cancelSession() {
        print("[FocusLock] Session cancelled")
        recordSession(completedNaturally: false)
        timer?.invalidate()
        timer = nil
        removeLaunchObserver()
        WebsiteBlocker.shared.unblockAll()
        isSessionActive = false
        secondsRemaining = 0
        if SettingsStore.shared.soundsEnabled { NSSound(named: "Basso")?.play() }
    }

    private func recordSession(completedNaturally: Bool) {
        let elapsed = max(0, sessionDuration * 60 - secondsRemaining)
        let appNames = selectedAppBundleIDs.compactMap { id in
            installedApps.first(where: { $0.id == id })?.name
        }.sorted()
        let siteNames = WebsiteBlocker.shared.blockedWebsites
            .filter { $0.isSelected }
            .map { $0.displayName }
            .sorted()
        SessionStore.shared.recordSession(FocusSession(
            id: UUID(),
            startedAt: sessionStartTime ?? Date(),
            plannedDuration: sessionDuration,
            actualDuration: elapsed,
            completedNaturally: completedNaturally,
            blockedApps: appNames,
            blockedWebsites: siteNames
        ))
    }

    func toggleApp(_ bundleID: String) {
        if selectedAppBundleIDs.contains(bundleID) {
            selectedAppBundleIDs.remove(bundleID)
        } else {
            selectedAppBundleIDs.insert(bundleID)
        }
    }

    func formattedTime() -> String { SessionClock.shared.formattedTime() }
}

// MARK: - In-app session-complete overlay

final class CompletionOverlay {
    static let shared = CompletionOverlay()
    private var panel: NSPanel?

    func show() {
        DispatchQueue.main.async { self.showOnMain() }
    }

    private func showOnMain() {
        if let existing = panel {
            existing.orderOut(nil)
            panel = nil
        }

        let size = NSSize(width: 380, height: 200)
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        let frame = NSRect(origin: origin, size: size)

        let p = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isFloatingPanel = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.contentView = NSHostingView(rootView: SessionCompleteOverlayView())
        p.alphaValue = 0
        p.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            p.animator().alphaValue = 1
        }

        self.panel = p

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self, weak p] in
            guard let p = p else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                p.animator().alphaValue = 0
            }, completionHandler: {
                p.orderOut(nil)
                if self?.panel === p { self?.panel = nil }
            })
        }
    }
}

private struct SessionCompleteOverlayView: View {
    @State private var appeared: Bool = false
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(Color.green.opacity(0.85))
                .shadow(color: Color.green.opacity(0.30), radius: 12, x: 0, y: 4)
                .scaleEffect(pulse ? 1.06 : 1.0)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)

            Text("Session Complete")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))

            Text("Great work — apps unlocked.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(width: 320, height: 200)
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
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.30), radius: 26, x: 0, y: 10)
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                appeared = true
            }
            pulse = true
        }
    }
}
