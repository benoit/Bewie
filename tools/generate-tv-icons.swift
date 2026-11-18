// Native tvOS layered artwork, retaining the original Bewie RGB and alpha.
import AppKit
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let brand = root.appendingPathComponent("BewieTV/Assets.xcassets/AppIcon.brandassets")
let logo = NSImage(contentsOf: root.appendingPathComponent("Design/Logo/Bewie-original.png"))!
for (name, width, height, scales) in [("Small", 400, 240, [1, 2]), ("Store", 1280, 768, [1])] {
    for layer in ["Foreground", "Background"] {
        for scale in scales {
            let w = width * scale, h = height * scale
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            if layer == "Background" {
                NSColor(srgbRed: 242/255, green: 241/255, blue: 236/255, alpha: 1).setFill()
                NSRect(x: 0, y: 0, width: w, height: h).fill()
            } else {
                let ratio = min(CGFloat(w)*0.76/logo.size.width, CGFloat(h)*0.80/logo.size.height)
                let size = CGSize(width: logo.size.width*ratio, height: logo.size.height*ratio)
                logo.draw(in: CGRect(x: (CGFloat(w)-size.width)/2, y: (CGFloat(h)-size.height)/2,
                                     width: size.width, height: size.height))
            }
            NSGraphicsContext.restoreGraphicsState()
            let path = "\(name).imagestack/\(layer).imagestacklayer/Content.imageset/\(scale)x.png"
            try bitmap.representation(using: .png, properties: [:])!.write(to: brand.appendingPathComponent(path))
        }
    }
}
print("Generated original-color Bewie layered TV icons on chalk.")
