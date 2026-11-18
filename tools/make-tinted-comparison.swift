import AppKit
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1000, pixelsHigh: 570,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(srgbRed: 0.92, green: 0.92, blue: 0.90, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 1000, height: 570).fill()
for (index, item) in [("Design/Icons/TintedDark-before.png", "Before"),
                      ("Design/Icons/iOS-27/TintedDark.png", "Brighter, with original texture")].enumerated() {
    let x = CGFloat(index * 490 + 40)
    NSImage(contentsOf: root.appendingPathComponent(item.0))!.draw(in: NSRect(x: x, y: 75, width: 430, height: 430))
    (item.1 as NSString).draw(at: NSPoint(x: x, y: 32), withAttributes: [.font: NSFont.systemFont(ofSize: 20, weight: .medium), .foregroundColor: NSColor.black])
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Design/Icons/TintedDark-comparison.png"))
