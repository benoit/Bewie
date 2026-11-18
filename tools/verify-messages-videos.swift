import AppKit
import AVFoundation
import CryptoKit
import Foundation

@main
enum VerifyMessagesVideos {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("Usage: verify-messages-videos VIDEO_DIRECTORY EVIDENCE_DIRECTORY")
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let evidence = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        var records = [[String: Any]]()
        for track in AlbumTrack.all {
            try autoreleasepool {
                let name = String(format: "track-%02d.mp4", track.id)
                let url = directory.appendingPathComponent(name)
                let asset = AVURLAsset(url: url)
                let source = AVURLAsset(url: root.appendingPathComponent("MusicAssets/Audio/" + track.filename))
                let video = asset.tracks(withMediaType: .video)
                let audio = asset.tracks(withMediaType: .audio)
                guard video.count == 1, audio.count == 1,
                      video[0].naturalSize == CGSize(width: 2160, height: 2160),
                      abs(asset.duration.seconds - source.duration.seconds) < 0.1,
                      abs(audio[0].timeRange.duration.seconds - source.duration.seconds) < 0.1 else {
                    throw NSError(domain: "BewieMessages", code: track.id, userInfo: [NSLocalizedDescriptionKey: "Invalid dimensions, tracks or full-song duration for \(name)"])
                }
                // Decode real frames near the beginning, middle and end;
                // metadata alone would not catch a truncated final file.
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                let lrc = try String(contentsOf: root.appendingPathComponent(String(format: "Lyrics/track-%02d.lrc", track.id)), encoding: .utf8)
                let firstLyric = SynchronizedLyrics(lrc: lrc).cues.first(where: { !$0.text.isEmpty })!.time
                for (label, seconds) in [("first", firstLyric + 0.7), ("middle", asset.duration.seconds / 2), ("last", asset.duration.seconds - 0.1)] {
                    let image = try generator.copyCGImage(at: CMTime(seconds: seconds, preferredTimescale: 60_000), actualTime: nil)
                    guard image.width == 2160 && image.height == 2160 else { fatalError("Decoded frame size mismatch") }
                    if label != "last" {
                        let jpeg = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.75])!
                        try jpeg.write(to: evidence.appendingPathComponent(String(format: "track-%02d-\(label).jpg", track.id)))
                    }
                }
                let reader = try AVAssetReader(asset: asset)
                reader.timeRange = CMTimeRange(start: CMTime(seconds: asset.duration.seconds / 2, preferredTimescale: 600), duration: CMTime(seconds: 1, preferredTimescale: 600))
                let output = AVAssetReaderTrackOutput(track: audio[0], outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
                reader.add(output)
                guard reader.startReading(), output.copyNextSampleBuffer() != nil else { fatalError("Audio decode failed for \(name)") }
                reader.cancelReading()
                var digest = SHA256()
                let handle = try FileHandle(forReadingFrom: url)
                while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { digest.update(data: data) }
                try handle.close()
                let hash = digest.finalize().map { String(format: "%02x", $0) }.joined()
                let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize!
                records.append(["id": track.id, "title": track.title, "filename": name,
                                "width": 2160, "height": 2160, "duration": asset.duration.seconds,
                                "latitude": track.latitude, "longitude": track.longitude,
                                "bytes": bytes, "sha256": hash, "decodedVideoFrames": 3, "audioDecoded": true])
                print("Verified \(track.id): \(track.title), \(asset.duration.seconds)s, \(bytes) bytes")
            }
        }
        let manifest: [String: Any] = ["schemaVersion": 1, "tracks": records]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
        print("PASS: all nine full-length 2160 × 2160 videos decode with audio.")
    }
}
