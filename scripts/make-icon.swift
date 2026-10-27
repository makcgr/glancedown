// Draws the app icon and writes Support/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = size / 1024

    // macOS icon grid: 824pt body centered in a 1024pt canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824).applying(.init(scaleX: scale, y: scale))
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * scale, yRadius: 185 * scale)
    NSGradient(colors: [
        NSColor(srgbRed: 0.18, green: 0.51, blue: 0.97, alpha: 1),
        NSColor(srgbRed: 0.35, green: 0.25, blue: 0.85, alpha: 1),
    ])!.draw(in: shape, angle: -60)

    // A page with a folded corner.
    let page = NSRect(x: 290, y: 210, width: 444, height: 584).applying(.init(scaleX: scale, y: scale))
    let fold = 120 * scale
    let pagePath = NSBezierPath()
    pagePath.move(to: NSPoint(x: page.minX, y: page.minY))
    pagePath.line(to: NSPoint(x: page.maxX, y: page.minY))
    pagePath.line(to: NSPoint(x: page.maxX, y: page.maxY - fold))
    pagePath.line(to: NSPoint(x: page.maxX - fold, y: page.maxY))
    pagePath.line(to: NSPoint(x: page.minX, y: page.maxY))
    pagePath.close()
    NSColor.white.withAlphaComponent(0.96).setFill()
    pagePath.fill()

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 230 * scale, weight: .heavy),
        .foregroundColor: NSColor(srgbRed: 0.27, green: 0.33, blue: 0.92, alpha: 1),
    ]
    let mark = NSAttributedString(string: "M↓", attributes: attributes)
    let markSize = mark.size()
    mark.draw(at: NSPoint(x: page.midX - markSize.width / 2, y: page.midY - markSize.height / 2 - 20 * scale))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = CGFloat(points * factor)
        let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = drawIcon(size: pixels).representation(using: .png, properties: [:])!
        try png.write(to: iconset.appendingPathComponent(name))
    }
}

let output = root.appendingPathComponent("Support/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
print("wrote \(output.path)")
