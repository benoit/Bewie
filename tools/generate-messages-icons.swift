// Composite the unchanged original Bewie colors and alpha onto chalk.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let icons = root.appendingPathComponent("BewieMessages/Assets.xcassets/MessageIcon.stickersiconset")
let source = NSImage(contentsOf: root.appendingPathComponent("Design/Logo/Bewie-original.png"))!
var sourceRect = CGRect(origin: .zero, size: source.size)
let mark = source.cgImage(forProposedRect: &sourceRect, context: nil, hints: nil)!
let slots: [(String, String, Int, Int, String)] = [
    ("iphone", "29x29", 58, 58, "2x"), ("iphone", "29x29", 87, 87, "3x"),
    ("iphone", "60x45", 120, 90, "2x"), ("iphone", "60x45", 180, 135, "3x"),
    ("ipad", "29x29", 58, 58, "2x"), ("ipad", "67x50", 134, 100, "2x"),
    ("ipad", "74x55", 148, 110, "2x"), ("ios-marketing", "1024x768", 1024, 768, "1x"),
    ("universal", "27x20", 54, 40, "2x"), ("universal", "27x20", 81, 60, "3x"),
    ("universal", "32x24", 64, 48, "2x"), ("universal", "32x24", 96, 72, "3x")
]
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
var images = [[String: String]]()
for (index, slot) in slots.enumerated() {
    let cg = CGContext(data: nil, width: slot.2, height: slot.3, bitsPerComponent: 8,
                       bytesPerRow: 0, space: colorSpace,
                       bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    cg.setFillColor(CGColor(colorSpace: colorSpace, components: [242/255, 241/255, 236/255, 1])!)
    cg.fill(CGRect(x: 0, y: 0, width: slot.2, height: slot.3))
    let width = CGFloat(slot.2) * 0.76
    let height = width * CGFloat(mark.height) / CGFloat(mark.width)
    cg.interpolationQuality = .high
    cg.draw(mark, in: CGRect(x: (CGFloat(slot.2)-width)/2, y: (CGFloat(slot.3)-height)/2,
                             width: width, height: height))
    let name = "bewie-\(index).png"
    try NSBitmapImageRep(cgImage: cg.makeImage()!).representation(using: .png, properties: [:])!
        .write(to: icons.appendingPathComponent(name))
    var item = ["idiom": slot.0, "size": slot.1, "scale": slot.4, "filename": name]
    if slot.0 == "universal" || slot.0 == "ios-marketing" { item["platform"] = "ios" }
    images.append(item)
}
try JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]],
                           options: [.prettyPrinted, .sortedKeys]).write(to: icons.appendingPathComponent("Contents.json"))
print("Generated all 12 Bewie Messages icon slots.")
