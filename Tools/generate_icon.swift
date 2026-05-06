import AppKit
import Foundation

// Renders the FocusLock app icon: deep navy → soft blue gradient with a white
// SF Symbol "lock.fill" centered and a subtle inner glow. Outputs an iconset
// directory ready for `iconutil`.

let outputDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "/tmp/AppIcon.iconset")

try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let topColor   = NSColor(red: 0x1a/255.0, green: 0x1f/255.0, blue: 0x3c/255.0, alpha: 1.0)
let bottomColor = NSColor(red: 0x2d/255.0, green: 0x5b/255.0, blue: 0xe3/255.0, alpha: 1.0)

func renderIcon(size: Int) -> Data? {
    let dim = CGFloat(size)
    let rect = NSRect(x: 0, y: 0, width: dim, height: dim)

    let img = NSImage(size: rect.size, flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

        // Rounded square mask (App Store icon style: ~22% radius)
        let radius = dim * 0.225
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.addPath(path)
        ctx.clip()

        // Gradient background (top → bottom)
        let colors = [topColor.cgColor, bottomColor.cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray,
                                  locations: [0.0, 1.0])!
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: dim),
                               end:   CGPoint(x: 0, y: 0),
                               options: [])

        // Lock symbol — 55% of icon size
        let lockSize = dim * 0.55
        let cfg = NSImage.SymbolConfiguration(pointSize: lockSize, weight: .bold)
        guard let symbol = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) else { return true }

        // Tint white
        let tinted = NSImage(size: NSSize(width: lockSize, height: lockSize), flipped: false) { srect in
            symbol.draw(in: srect, from: .zero, operation: .sourceOver, fraction: 1.0)
            NSColor.white.set()
            srect.fill(using: .sourceAtop)
            return true
        }

        // Subtle inner glow: draw the symbol once with a soft white shadow
        let lockRect = NSRect(x: (dim - lockSize) / 2,
                              y: (dim - lockSize) / 2,
                              width: lockSize,
                              height: lockSize)

        ctx.saveGState()
        ctx.setShadow(offset: .zero,
                      blur: dim * 0.025,
                      color: NSColor.white.withAlphaComponent(0.30).cgColor)
        tinted.draw(in: lockRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        ctx.restoreGState()

        // Crisp white lock on top
        tinted.draw(in: lockRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        return true
    }

    guard let tiff = img.tiffRepresentation,
          let rep  = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

// Apple's iconset naming: icon_<size>x<size>.png and icon_<size>x<size>@2x.png
let pairs: [(name: String, pixels: Int)] = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]

for pair in pairs {
    guard let data = renderIcon(size: pair.pixels) else {
        FileHandle.standardError.write("failed to render \(pair.name)\n".data(using: .utf8)!)
        exit(1)
    }
    let url = outputDir.appendingPathComponent(pair.name)
    try data.write(to: url)
    print("wrote \(pair.name) (\(pair.pixels)px)")
}
