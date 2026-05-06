import SwiftUI
import AppKit

@main
struct FocusLockApp: App {
    init() {
        Self.installAppIcon()
        _ = WidgetSync.shared
        _ = ScheduleStore.shared
        DispatchQueue.main.async {
            FocusManager.shared.requestAccessibilityPermission()
        }
    }

    var body: some Scene {
        WindowGroup("FocusLock") {
            MainTabView()
                .frame(width: 720, height: 520)
                .background(
                    WindowAccessor { window in
                        configureGlassWindow(window)
                    }
                )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

    private func configureGlassWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.resizable)
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }

    private static func installAppIcon() {
        let size: CGFloat = 512
        let icon = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let bg = NSBezierPath(roundedRect: rect.insetBy(dx: 24, dy: 24),
                                  xRadius: 96, yRadius: 96)
            NSColor.systemIndigo.setFill()
            bg.fill()

            let cfg = NSImage.SymbolConfiguration(pointSize: 280, weight: .bold)
            guard let symbol = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?
                    .withSymbolConfiguration(cfg) else {
                return true
            }
            let symbolSize: CGFloat = 280
            let symbolRect = NSRect(
                x: (rect.width - symbolSize) / 2,
                y: (rect.height - symbolSize) / 2,
                width: symbolSize,
                height: symbolSize
            )
            NSColor.white.set()
            if let tinted = symbol.tinted(with: .white) {
                tinted.draw(in: symbolRect,
                            from: .zero,
                            operation: .sourceOver,
                            fraction: 1.0,
                            respectFlipped: false,
                            hints: [.interpolation: NSImageInterpolation.high])
            } else {
                symbol.draw(in: symbolRect)
            }
            return true
        }
        NSApplication.shared.applicationIconImage = icon
    }
}

private extension NSImage {
    func tinted(with color: NSColor) -> NSImage? {
        guard let copy = self.copy() as? NSImage else { return nil }
        copy.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: copy.size)
        rect.fill(using: .sourceAtop)
        copy.unlockFocus()
        copy.isTemplate = false
        return copy
    }
}
