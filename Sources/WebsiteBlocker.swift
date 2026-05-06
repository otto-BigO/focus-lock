import Foundation
import AppKit

struct WebsiteEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var displayName: String
    var domains: [String]
    var isSelected: Bool = false
    var isCustom: Bool = false
}

final class WebsiteBlocker: ObservableObject {
    static let shared = WebsiteBlocker()

    @Published var blockedWebsites: [WebsiteEntry] = []
    @Published var isBlocking: Bool = false
    @Published var needsExplanation: Bool = false

    private let storageKey = "FocusLock.blockedWebsites.v1"
    private let explainerShownKey = "FocusLock.adminExplainerShown"
    private let hostsMarkerStart = "# FocusLock-start"
    private let hostsMarkerEnd = "# FocusLock-end"
    private var pendingBlock: (() -> Void)?

    private static let presets: [WebsiteEntry] = [
        WebsiteEntry(displayName: "YouTube",   domains: ["youtube.com", "www.youtube.com", "m.youtube.com"]),
        WebsiteEntry(displayName: "Twitter / X", domains: ["twitter.com", "www.twitter.com", "x.com", "www.x.com"]),
        WebsiteEntry(displayName: "Instagram", domains: ["instagram.com", "www.instagram.com"]),
        WebsiteEntry(displayName: "Reddit",    domains: ["reddit.com", "www.reddit.com", "old.reddit.com"]),
        WebsiteEntry(displayName: "TikTok",    domains: ["tiktok.com", "www.tiktok.com"]),
        WebsiteEntry(displayName: "LinkedIn",  domains: ["linkedin.com", "www.linkedin.com"]),
        WebsiteEntry(displayName: "Facebook",  domains: ["facebook.com", "www.facebook.com", "m.facebook.com"])
    ]

    private init() {
        loadFromDisk()
        if blockedWebsites.isEmpty {
            blockedWebsites = Self.presets
            saveSelectedSites()
        } else {
            mergeMissingPresets()
        }
    }

    // MARK: - Persistence

    func saveSelectedSites() {
        if let data = try? JSONEncoder().encode(blockedWebsites) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WebsiteEntry].self, from: data) else {
            return
        }
        blockedWebsites = decoded
    }

    private func mergeMissingPresets() {
        // Add any preset by displayName that's missing (older saved state).
        let existingNames = Set(blockedWebsites.map { $0.displayName })
        let missing = Self.presets.filter { !existingNames.contains($0.displayName) }
        if !missing.isEmpty {
            blockedWebsites.append(contentsOf: missing)
            saveSelectedSites()
        }
    }

    // MARK: - Mutators

    func toggleSite(_ id: UUID) {
        if let idx = blockedWebsites.firstIndex(where: { $0.id == id }) {
            blockedWebsites[idx].isSelected.toggle()
            saveSelectedSites()
        }
    }

    func addCustomDomain(_ raw: String) {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .split(separator: "/").first.map(String.init) ?? ""
        guard !cleaned.isEmpty,
              cleaned.contains("."),
              !cleaned.contains(" ") else { return }

        // Avoid dupes by domain
        if blockedWebsites.contains(where: { $0.domains.contains(cleaned) }) { return }

        let entry = WebsiteEntry(
            displayName: cleaned,
            domains: cleaned.hasPrefix("www.") ? [cleaned] : [cleaned, "www.\(cleaned)"],
            isSelected: true,
            isCustom: true
        )
        blockedWebsites.append(entry)
        saveSelectedSites()
    }

    func removeWebsite(_ id: UUID) {
        blockedWebsites.removeAll { $0.id == id && $0.isCustom }
        saveSelectedSites()
    }

    var selectedCount: Int { blockedWebsites.filter { $0.isSelected }.count }

    // MARK: - Block / unblock

    /// Called from FocusManager.startSession.
    func blockAll() {
        let selected = blockedWebsites.filter { $0.isSelected }
        guard !selected.isEmpty else {
            print("[WebsiteBlocker] No sites selected — nothing to block")
            return
        }
        let domains = selected.flatMap { $0.domains }

        let task: () -> Void = { [weak self] in
            self?.performBlock(domains: domains)
        }

        let alreadyShown = UserDefaults.standard.bool(forKey: explainerShownKey)
        if !alreadyShown {
            self.pendingBlock = task
            DispatchQueue.main.async { self.needsExplanation = true }
        } else {
            task()
        }
    }

    func confirmExplainerAndBlock() {
        UserDefaults.standard.set(true, forKey: explainerShownKey)
        DispatchQueue.main.async { self.needsExplanation = false }
        let pending = pendingBlock
        pendingBlock = nil
        pending?()
    }

    func cancelExplainer() {
        DispatchQueue.main.async { self.needsExplanation = false }
        pendingBlock = nil
    }

    private func performBlock(domains: [String]) {
        // Build hosts file fragment to a temp file, then concatenate via sudo.
        var fragment = "\n\(hostsMarkerStart)\n"
        for d in domains where isReasonableDomain(d) {
            fragment += "127.0.0.1 \(d)\n"
            fragment += "::1 \(d)\n"
        }
        fragment += "\(hostsMarkerEnd)\n"

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("focuslock-hosts-\(UUID().uuidString).txt")
        do {
            try fragment.write(to: tmpURL, atomically: true, encoding: .utf8)
        } catch {
            print("[WebsiteBlocker] Failed to write temp fragment: \(error)")
            return
        }

        // Remove any stale block first, then append new fragment, then flush.
        let shell = "/usr/bin/sed -i '' '/\(hostsMarkerStart)/,/\(hostsMarkerEnd)/d' /etc/hosts; /bin/cat '\(tmpURL.path)' >> /etc/hosts; /usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder; /bin/rm -f '\(tmpURL.path)'"
        let appleScript = "do shell script \"\(shell.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

        runOsascript(appleScript) { [weak self] success in
            DispatchQueue.main.async {
                self?.isBlocking = success
                if success {
                    print("[WebsiteBlocker] Blocked \(domains.count) domain(s)")
                } else {
                    print("[WebsiteBlocker] Block failed (admin denied or error)")
                }
            }
        }
    }

    /// Called from FocusManager.endSession / cancelSession.
    func unblockAll() {
        // Always run — idempotent. Skip the admin prompt cost when no markers exist.
        guard hostsContainsMarkers() else {
            DispatchQueue.main.async { self.isBlocking = false }
            return
        }
        let shell = "/usr/bin/sed -i '' '/\(hostsMarkerStart)/,/\(hostsMarkerEnd)/d' /etc/hosts; /usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder"
        let appleScript = "do shell script \"\(shell.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        runOsascript(appleScript) { [weak self] success in
            DispatchQueue.main.async {
                self?.isBlocking = false
                if success {
                    print("[WebsiteBlocker] Unblocked")
                } else {
                    print("[WebsiteBlocker] Unblock failed")
                }
            }
        }
    }

    private func hostsContainsMarkers() -> Bool {
        guard let data = try? String(contentsOfFile: "/etc/hosts", encoding: .utf8) else {
            return false
        }
        return data.contains(hostsMarkerStart)
    }

    private func isReasonableDomain(_ d: String) -> Bool {
        // Block any obvious shell metacharacter or whitespace.
        let invalid = CharacterSet(charactersIn: " \t\n\"'`;|&<>$()")
        return !d.isEmpty
            && d.rangeOfCharacter(from: invalid) == nil
            && d.contains(".")
    }

    private func runOsascript(_ script: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe
            do {
                try task.run()
                task.waitUntilExit()
                let success = (task.terminationStatus == 0)
                if !success {
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    print("[WebsiteBlocker] osascript exit \(task.terminationStatus): \(err)")
                }
                completion(success)
            } catch {
                print("[WebsiteBlocker] osascript spawn error: \(error)")
                completion(false)
            }
        }
    }
}
