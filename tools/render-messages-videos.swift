import AppKit
import MapKit
import AVFoundation
import CoreImage

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let destination = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true) : root.appendingPathComponent("MusicAssets/Messages", isDirectory: true)

let edge = 2160
let side = CGFloat(edge)
let scale = side / 346
let startTime = 0.0
var clipDuration = 0.0
var currentTrack = AlbumTrack.all[0]
let fps = 30
let orange = NSColor(srgbRed: 1, green: 121/255, blue: 0, alpha: 1)
let ink = NSColor(srgbRed: 11/255, green: 12/255, blue: 11/255, alpha: 1)
let paper = NSColor(srgbRed: 217/255, green: 211/255, blue: 199/255, alpha: 1)


struct Cue { let time: Double; let text: String }
var cues = [Cue]()

func coordinateLabel(_ track: AlbumTrack) -> String {
    String(format: "%.6f° %@  %.6f° %@", locale: Locale(identifier: "en_US_POSIX"),
           abs(track.latitude), track.latitude < 0 ? "S" : "N",
           abs(track.longitude), track.longitude < 0 ? "W" : "E")
}

func font(_ name: String, _ size: CGFloat) -> NSFont { NSFont(name: name, size: size)! }
func text(_ string: String, _ rect: CGRect, _ font: NSFont, _ color: NSColor) {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    (string as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
}

// SwiftUI's easeInOut curve, rather than a polynomial approximation.
func appEaseInOut(_ progress: Double) -> Double {
    let x = min(1, max(0, progress))
    func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
        3 * (1-t) * (1-t) * t * a + 3 * (1-t) * t * t * b + t * t * t
    }
    var low = 0.0, high = 1.0
    for _ in 0..<24 {
        let mid = (low + high) / 2
        if bezier(mid, 0.42, 0.58) < x { low = mid } else { high = mid }
    }
    return bezier((low + high) / 2, 0, 1)
}

var lyricCache = [String: CGImage]()
func lyricLayer(_ line: String, active: Bool, width: CGFloat, height: CGFloat) -> CGImage {
    let key = (active ? "grey:" : "white:") + line
    if let cached = lyricCache[key] { return cached }
    let pad = CGFloat(12)
    let cg = CGContext(data: nil, width: Int(ceil(width + 2 * pad)), height: Int(ceil(height + 2 * pad)),
                       bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    cg.translateBy(x: 0, y: CGFloat(cg.height))
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    let color = active ? NSColor(srgbRed: 128/255, green: 128/255, blue: 128/255, alpha: 1) : NSColor.white
    let baseFont = font("HelveticaNeue-Bold", 28 * scale)
    let measured = (line as NSString).size(withAttributes: [.font: baseFont]).width
    let fittedFont = font("HelveticaNeue-Bold", 28 * scale * min(1, width / max(1, measured)))
    text(line, CGRect(x: pad, y: pad, width: width, height: height), fittedFont, color)
    NSGraphicsContext.restoreGraphicsState()
    var result = cg.makeImage()!
    if !active {
        let image = CIImage(cgImage: result)
        let softened = image.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.2 * scale])
        result = CIContext().createCGImage(softened, from: image.extent)!
    }
    lyricCache[key] = result
    return result
}

func drawFrame(map: CGImage, time: Double, in context: CGContext) {
    context.saveGState()
    context.translateBy(x: 0, y: side)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    NSImage(cgImage: map, size: NSSize(width: side, height: side))
        .draw(in: CGRect(x: 0, y: 0, width: side, height: side), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)

    // Helvetica Neue, grey current line and white surrounding lines match MapLyricsView.
    let lines = cues
    let current = lines.lastIndex(where: { $0.time <= time }) ?? 0
    let previous = max(0, current - 1)
    // First update the two colors with the stack stationary. On the next
    // display frame, move that same stack upwards over the app's 0.45 seconds.
    let elapsedSinceCue = time - lines[current].time
    let transition = min(1, max(0, (elapsedSinceCue - 1.0 / Double(fps)) / 0.45))
    let eased = appEaseInOut(transition)
    let row = side * 0.103
    let currentCenter = side * 0.205
    context.saveGState()
    context.clip(to: CGRect(x: side * 0.11, y: side * 0.035, width: side * 0.78, height: side * 0.32))
    for i in max(0, previous - 1)...min(lines.count - 1, current + 2) {
        let center = currentCenter + (CGFloat(i - previous) - CGFloat(eased)) * row
        let line = lines[i].text.isEmpty ? "…" : lines[i].text
        let layer = lyricLayer(line, active: i == current && !lines[i].text.isEmpty, width: side * 0.78, height: row)
        NSImage(cgImage: layer, size: NSSize(width: layer.width, height: layer.height))
            .draw(in: CGRect(x: side * 0.11 - 12, y: center - 18 * scale - 12,
                             width: CGFloat(layer.width), height: CGFloat(layer.height)),
                  from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    context.restoreGState()

    let pin = CGPoint(x: side / 2, y: side * 3 / 7)
    let stem = side * 0.06
    context.setStrokeColor(orange.cgColor)
    context.setLineWidth(1.5 * scale)
    context.move(to: pin)
    context.addLine(to: CGPoint(x: pin.x, y: pin.y + stem))
    context.strokePath()
    orange.setFill()
    NSBezierPath(ovalIn: CGRect(x: pin.x - 2 * scale, y: pin.y + stem - 2 * scale, width: 4 * scale, height: 4 * scale)).fill()
    let diameter = 34 * scale
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 2 * scale), blur: 5 * scale, color: NSColor.black.withAlphaComponent(0.12).cgColor)
    NSBezierPath(ovalIn: CGRect(x: pin.x - diameter / 2, y: pin.y - diameter / 2, width: diameter, height: diameter)).fill()
    context.restoreGState()
    let number = String(currentTrack.id) as NSString
    let attributes: [NSAttributedString.Key: Any] = [.font: font("HelveticaNeue-Medium", 17 * scale), .foregroundColor: ink]
    let nsize = number.size(withAttributes: attributes)
    number.draw(at: CGPoint(x: pin.x - nsize.width / 2, y: pin.y - nsize.height / 2), withAttributes: attributes)

    // The rounded title panel is 64% of the video width.
    let box = CGRect(x: side * 0.18, y: side - 88 * scale, width: side * 0.64, height: 75 * scale)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 4 * scale), blur: 16 * scale, color: NSColor.black.withAlphaComponent(0.15).cgColor)
    paper.setFill()
    NSBezierPath(roundedRect: box, xRadius: 20 * scale, yRadius: 20 * scale).fill()
    context.restoreGState()
    let titleY = box.minY + 15 * scale
    text(String(currentTrack.id), CGRect(x: box.minX + 16 * scale, y: titleY, width: 15 * scale, height: 21 * scale), font("HelveticaNeue-Bold", 16 * scale), orange)
    let titleWidth = box.width - 50 * scale
    let titleBaseFont = font("HelveticaNeue-Medium", 16 * scale)
    let titleMeasured = (currentTrack.title as NSString).size(withAttributes: [.font: titleBaseFont]).width
    let titleFont = font("HelveticaNeue-Medium", 16 * scale * min(1, titleWidth / max(1, titleMeasured)))
    text(currentTrack.title, CGRect(x: box.minX + 37 * scale, y: titleY, width: titleWidth, height: 23 * scale), titleFont, ink)
    text(coordinateLabel(currentTrack), CGRect(x: box.minX + 16 * scale, y: titleY + 28 * scale, width: box.width - 26 * scale, height: 15 * scale), font("PTMono-Regular", 8 * scale), ink)
    text(" Maps", CGRect(x: 8 * scale, y: side - 12 * scale, width: 100 * scale, height: 10 * scale), NSFont.systemFont(ofSize: 7 * scale), .darkGray)
    NSGraphicsContext.restoreGraphicsState()
    context.restoreGState()
}

func render(map: CGImage) throws {
    let silentURL = destination.appendingPathComponent(String(format: "track-%02d.mp4", currentTrack.id))
    try? FileManager.default.removeItem(at: silentURL)
    let writer = try AVAssetWriter(outputURL: silentURL, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.hevc,
        AVVideoWidthKey: edge, AVVideoHeightKey: edge,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000, AVVideoExpectedSourceFrameRateKey: fps]
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: edge, kCVPixelBufferHeightKey as String: edge,
        kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ])
    writer.add(input)
    let audioAsset = AVURLAsset(url: root.appendingPathComponent("MusicAssets/Audio/" + currentTrack.filename))
    let audioReader = try AVAssetReader(asset: audioAsset)
    let audioOutput = AVAssetReaderTrackOutput(track: audioAsset.tracks(withMediaType: .audio)[0], outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
    audioReader.add(audioOutput)
    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 256_000
    ])
    writer.add(audioInput)
    guard writer.startWriting() else { throw writer.error! }
    writer.startSession(atSourceTime: .zero)
    guard audioReader.startReading() else { throw audioReader.error! }
    let audioDone = DispatchGroup()
    audioDone.enter()
    audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "bewie.messages.audio")) {
        while audioInput.isReadyForMoreMediaData {
            guard let sample = audioOutput.copyNextSampleBuffer() else {
                audioInput.markAsFinished()
                audioDone.leave()
                return
            }
            if !audioInput.append(sample) {
                audioInput.markAsFinished()
                audioDone.leave()
                return
            }
        }
    }
    // Still frames hold their presentation timestamp; only lyric transitions
    // need new frames at 30 fps. This preserves the exact movement without
    // encoding thousands of duplicate map images.
    var times = Set<Double>([0, max(0, clipDuration - 1.0 / Double(fps))])
    for cue in cues where cue.time > 0 && cue.time < clipDuration {
        times.insert(cue.time)
        for frame in 1...16 {
            let time = cue.time + Double(frame) / Double(fps)
            if time < clipDuration { times.insert(time) }
        }
    }
    let timeline = times.sorted()
    print("Rendering track \(currentTrack.id): \(timeline.count) frames, \(clipDuration)s")
    fflush(stdout)
    for (frame, presentationTime) in timeline.enumerated() {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
        try autoreleasepool {
            var buffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer) == kCVReturnSuccess, let buffer else { fatalError("Pixel buffer allocation") }
            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: edge, height: edge, bitsPerComponent: 8,
                                    bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
            drawFrame(map: map, time: presentationTime, in: context)
            if frame == 30 {
                let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
                try png.write(to: destination.appendingPathComponent(String(format: "track-%02d.png", currentTrack.id)))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            if !adaptor.append(buffer, withPresentationTime: CMTime(seconds: presentationTime, preferredTimescale: 60_000)) { throw writer.error! }
        }
    }
    input.markAsFinished()
    audioDone.wait()
    guard audioReader.status == .completed else { throw audioReader.error! }
    writer.endSession(atSourceTime: CMTime(seconds: clipDuration, preferredTimescale: 60_000))
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    finished.wait()
    guard writer.status == .completed else { throw writer.error! }
    let check = AVURLAsset(url: silentURL)
    let size = check.tracks(withMediaType: .video)[0].naturalSize
    guard size.width == 2160, size.height == 2160,
          check.tracks(withMediaType: .audio).count == 1,
          abs(check.duration.seconds - clipDuration) < 0.2 else {
        throw NSError(domain: "BewieMessagesRender", code: 1, userInfo: [NSLocalizedDescriptionKey: "Output validation failed"])
    }
    print("COMPLETE track \(currentTrack.id): \(size), \(check.duration.seconds)s — \(silentURL.path)")
    fflush(stdout)
}

@main
enum RenderMessagesVideos {
    static func main() throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        CTFontManagerRegisterFontsForURL(root.appendingPathComponent("Bewie/Resources/Fonts/PTMono-Regular.ttf") as CFURL, .process, nil)
        let selected = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) : nil
        let tracks = AlbumTrack.all.filter { selected == nil || $0.id == selected }
        var nextIndex = 0
        func next() {
            guard nextIndex < tracks.count else { print("ALL RENDERS COMPLETE"); exit(0) }
            let track = tracks[nextIndex]
            nextIndex += 1
            let existing = destination.appendingPathComponent(String(format: "track-%02d.mp4", track.id))
            if FileManager.default.fileExists(atPath: existing.path) {
                let asset = AVURLAsset(url: existing)
                let original = AVURLAsset(url: root.appendingPathComponent("MusicAssets/Audio/" + track.filename))
                if let video = asset.tracks(withMediaType: .video).first,
                   video.naturalSize == CGSize(width: 2160, height: 2160),
                   asset.tracks(withMediaType: .audio).count == 1,
                   abs(asset.duration.seconds - original.duration.seconds) < 0.1 {
                    print("Keeping completed track \(track.id)")
                    next()
                    return
                }
            }
            currentTrack = track
            lyricCache.removeAll()
            let audio = AVURLAsset(url: root.appendingPathComponent("MusicAssets/Audio/" + track.filename))
            clipDuration = audio.duration.seconds
            let lrc = try! String(contentsOf: root.appendingPathComponent(String(format: "Lyrics/track-%02d.lrc", track.id)), encoding: .utf8)
            cues = SynchronizedLyrics(lrc: lrc).cues.map { Cue(time: $0.time, text: $0.text) }
            let options = MKMapSnapshotter.Options()
            options.size = NSSize(width: side, height: side * 1.5)
            options.camera = MKMapCamera(lookingAtCenter: track.coordinate, fromDistance: 2_000, pitch: 0, heading: 0)
            let config = MKStandardMapConfiguration(emphasisStyle: .muted)
            config.pointOfInterestFilter = .excludingAll
            options.preferredConfiguration = config
            options.appearance = NSAppearance(named: .aqua)
            MKMapSnapshotter(options: options).start { snapshot, error in
                guard let snapshot, let tiff = snapshot.image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff), let cg = bitmap.cgImage else {
                    print("Map failed for \(track.id): \(String(describing: error))"); exit(1)
                }
                let point = snapshot.point(for: track.coordinate)
                let anchorY = side * (3.0 / 7.0 + 0.06)
                let pixelScale = CGFloat(cg.width) / side
                let crop = CGRect(x: ((point.x - side/2) * pixelScale).rounded(),
                                  y: ((point.y - anchorY) * pixelScale).rounded(),
                                  width: side * pixelScale, height: side * pixelScale)
                guard let cropped = cg.cropping(to: crop) else { print("Map crop failed"); exit(1) }
                let ci = CIImage(cgImage: cropped).applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                let gray = CIContext().createCGImage(ci, from: ci.extent)!
                DispatchQueue.global(qos: .userInitiated).async {
                    do { try render(map: gray); DispatchQueue.main.async { next() } }
                    catch { print("Render failed for \(track.id): \(error)"); exit(1) }
                }
            }
        }
        next()
        RunLoop.main.run()
    }
}
