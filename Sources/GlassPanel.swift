import SwiftUI
import AppKit

// MARK: - Reusable glass panel modifier

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 16
    var strokeOpacity: Double = 0.15
    var shadowRadius: CGFloat = 24
    var shadowY: CGFloat = 8
    var shadowOpacity: Double = 0.18

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 16,
                    strokeOpacity: Double = 0.15,
                    shadowRadius: CGFloat = 24,
                    shadowY: CGFloat = 8,
                    shadowOpacity: Double = 0.18) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius,
                            strokeOpacity: strokeOpacity,
                            shadowRadius: shadowRadius,
                            shadowY: shadowY,
                            shadowOpacity: shadowOpacity))
    }
}

// MARK: - NSVisualEffectView wrapper for window-behind blur

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var isEmphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.isEmphasized = isEmphasized
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = isEmphasized
    }
}

// MARK: - Window styling helper

struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Window config is static — nothing to update on re-renders.
    }
}

// MARK: - Pressable button style with subtle scale

struct PressableScaleStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Color tokens

enum Glass {
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.50)
    static let textTertiary = Color.white.opacity(0.35)
    static let accent = Color.blue.opacity(0.85)
    static let separator = Color.white.opacity(0.08)
}
