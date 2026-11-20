// Render existing album artwork into platform-native icon assets without recoloring it.
import AppKit
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let source = NSImage(contentsOf: root.appendingPathComponent("Bewie/Assets.xcassets/LaunchAlbumCover.imageset/front-laetitia.png"))!
var rect = CGRect(origin: .zero, size: source.size)
let cover = source.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func render(_ width: Int, _ height: Int, _ path: String, contain: Bool = false) throws {
    let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    cg.setFillColor(CGColor(red: 242/255, green: 241/255, blue: 236/255, alpha: 1))
    cg.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let sx = CGFloat(width)/CGFloat(cover.width), sy = CGFloat(height)/CGFloat(cover.height)
    let ratio = contain ? min(sx, sy) : max(sx, sy)
    let w = CGFloat(cover.width)*ratio, h = CGFloat(cover.height)*ratio
    cg.interpolationQuality = .high
    cg.draw(cover, in: CGRect(x: (CGFloat(width)-w)/2, y: (CGFloat(height)-h)/2, width: w, height: h))
    try NSBitmapImageRep(cgImage: cg.makeImage()!).representation(using: .png, properties: [:])!
        .write(to: root.appendingPathComponent(path))
}
try render(1024, 1024, "Bewie/AppIcon.icon/Assets/AlbumCover.png")
// Rectangular platforms retain the whole sleeve on the matching chalk surround.
let icons = "BewieMessages/Assets.xcassets/MessageIcon.stickersiconset"
let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(icons+"/Contents.json"))) as! [String: Any]
for item in contents["images"] as! [[String: String]] {
    let size = item["size"]!.split(separator: "x").map { Double($0)! }
    let scale = Double(item["scale"]!.dropLast())!
    try render(Int(size[0]*scale), Int(size[1]*scale), icons+"/"+item["filename"]!, contain: true)
}
let brand = "BewieTV/Assets.xcassets/AppIcon.brandassets"
for (name, width, height, scales) in [("Small", 400, 240, [1, 2]), ("Store", 1280, 768, [1])] {
    for scale in scales {
        try render(width*scale, height*scale, "\(brand)/\(name).imagestack/Background.imagestacklayer/Content.imageset/\(scale)x.png", contain: true)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width*scale, pixelsHigh: height*scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("\(brand)/\(name).imagestack/Foreground.imagestacklayer/Content.imageset/\(scale)x.png"))
    }
}
print("Rendered album sleeve for native Apple, Messages and TV icons.")
