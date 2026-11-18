import AppKit
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let width = 1200, height = 870
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(srgbRed: 0.92, green: 0.92, blue: 0.90, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 28, weight: .semibold), .foregroundColor: NSColor.black]
("Bewie · iOS Liquid Glass" as NSString).draw(at: NSPoint(x: 40, y: 817), withAttributes: title)
let modes = [("Default", "Original · light"), ("Dark", "Original · dark"),
             ("ClearLight", "Clear · light"), ("ClearDark", "Clear · dark"),
             ("TintedLight", "Tinted · light"), ("TintedDark", "Tinted · dark")]
for (index, mode) in modes.enumerated() {
    let col = index % 3, row = index / 3
    let x = CGFloat(col * 390 + 50), y = CGFloat(445 - row * 390)
    let image = NSImage(contentsOf: root.appendingPathComponent("Design/Icons/iOS-27/\(mode.0).png"))!
    image.draw(in: NSRect(x: x, y: y, width: 320, height: 320))
    let style: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 19, weight: .medium), .foregroundColor: NSColor.black]
    (mode.1 as NSString).draw(at: NSPoint(x: x, y: y - 32), withAttributes: style)
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Design/Icons/Bewie-iOS-appearances.png"))
