// Lift luminance for Icon Composer's Mono appearance while retaining source texture.
// Original logo RGB/alpha remains the source for Default and Dark.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let input = root.appendingPathComponent("Design/Logo/Bewie-original.png")
let output = root.appendingPathComponent("Bewie/AppIcon.icon/Assets/Bewie-Mono.png")
let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(input as CFURL, nil)!, 0, nil)!
let width = image.width, height = image.height
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
for index in stride(from: 0, to: width * height * 4, by: 4) {
    let alpha = Double(pixels[index + 3]) / 255
    guard alpha > 0 else { continue }
    let r = Double(pixels[index]) / (255 * alpha)
    let g = Double(pixels[index + 1]) / (255 * alpha)
    let b = Double(pixels[index + 2]) / (255 * alpha)
    let luminance = min(1, max(0, 0.2126 * r + 0.7152 * g + 0.0722 * b))
    let lifted = 0.55 + 0.45 * sqrt(luminance)
    let value = UInt8(min(255, max(0, (lifted * alpha * 255).rounded())))
    pixels[index] = value; pixels[index + 1] = value; pixels[index + 2] = value
}
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
print("Created texture-preserving Mono source; original color source unchanged.")
