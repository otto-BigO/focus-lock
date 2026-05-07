import SwiftUI
import AppKit

final class BreakCompleteOverlay {
    static let shared = BreakCompleteOverlay()
    private var panel: NSPanel?

    func show() {
        DispatchQueue.main.async { self.showOnMain() }
    }

    private func showOnMain() {
        if let existing = panel {
            existing.orderOut(nil)
            panel = nil
        }

        let size = NSSize(width: 360, height: 190)
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
        p.contentView = NSHostingView(rootView: BreakCompleteOverlayView())
        p.alphaValue = 0
        p.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            p.animator().alphaValue = 1
        }
        self.panel = p

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self, weak p] in
            guard let p = p else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.45
                p.animator().alphaValue = 0
            }, completionHandler: {
                p.orderOut(nil)
                if self?.panel === p { self?.panel = nil }
            })
        }
    }
}

private struct BreakCompleteOverlayView: View {
    @State private var scale: CGFloat = 0.7

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.95), Color.orange.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.yellow.opacity(0.40), radius: 14, x: 0, y: 4)
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.55)) {
                        scale = 1.10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.70)) {
                            scale = 1.0
                        }
                    }
                }

            Text("Break Complete")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))

            Text("Time to focus again!")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(width: 320, height: 190)
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
    }
}
