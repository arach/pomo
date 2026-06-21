#!/usr/bin/env swift
import AppKit
import Foundation

// Renders Pomo's app icon at every required size and packs them into
// Resources/AppIcon.icns. A dark HUD tile with an emerald progress ring and a
// white hourglass glyph — echoing the menu-bar icon and the HUD aesthetic.

let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let repoRoot = scriptPath.deletingLastPathComponent().deletingLastPathComponent()
let resourcesDir = repoRoot.appendingPathComponent("Resources")
try? FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let copy = image.copy() as! NSImage
    copy.lockFocus()
    color.set()
    NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
    copy.unlockFocus()
    copy.isTemplate = false
    return copy
}

func makeIcon(px: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Rounded tile background (Apple icon grid: ~80% with ~22.37% corner radius)
    let margin = px * 0.0977
    let rect = CGRect(x: margin, y: margin, width: px - 2 * margin, height: px - 2 * margin)
    let radius = rect.width * 0.2237
    let tile = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1),
        NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1),
    ])!
    gradient.draw(in: tile, angle: -90)

    // Subtle top inner highlight
    NSColor.white.withAlphaComponent(0.06).setStroke()
    tile.lineWidth = px * 0.004
    tile.stroke()

    // Progress ring
    let center = CGPoint(x: px / 2, y: px / 2)
    let ringRadius = rect.width * 0.34
    let lineWidth = rect.width * 0.058

    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: ringRadius, startAngle: 0, endAngle: 360)
    track.lineWidth = lineWidth
    NSColor.white.withAlphaComponent(0.10).setStroke()
    track.stroke()

    let emerald = NSColor(red: 0.06, green: 0.72, blue: 0.51, alpha: 1)
    let shadow = NSShadow()
    shadow.shadowColor = emerald.withAlphaComponent(0.7)
    shadow.shadowBlurRadius = px * 0.03
    shadow.set()

    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: ringRadius, startAngle: 90, endAngle: 90 - 252, clockwise: true)
    arc.lineWidth = lineWidth
    arc.lineCapStyle = .round
    emerald.setStroke()
    arc.stroke()

    NSShadow().set() // clear shadow

    // Hourglass glyph
    let config = NSImage.SymbolConfiguration(pointSize: px * 0.34, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "hourglass", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let white = tinted(symbol, .white)
        let s = white.size
        let drawRect = CGRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height)
        white.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

let iconsetDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Pomo.iconset")
try? FileManager.default.removeItem(at: iconsetDir)
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

for (name, px) in sizes {
    let rep = makeIcon(px: px)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    try! data.write(to: iconsetDir.appendingPathComponent(name))
}

let icnsPath = resourcesDir.appendingPathComponent("AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", icnsPath.path, iconsetDir.path]
try! process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconsetDir)

if process.terminationStatus == 0 {
    print("▸ Wrote \(icnsPath.path)")
} else {
    FileHandle.standardError.write("iconutil failed (\(process.terminationStatus))\n".data(using: .utf8)!)
    exit(1)
}
