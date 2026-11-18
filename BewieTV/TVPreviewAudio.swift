#if DEBUG
import Foundation

/// Simulator-only fixture. Production always uses the shared Apple-hosted album.
enum TVPreviewAudio {
    static func makeURL() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bewie-tv-test.wav")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let rate: UInt32 = 8_000
        let sampleCount = Int(rate) * 60
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func u32(_ value: UInt32) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
        func u16(_ value: UInt16) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36 + sampleCount * 2)); text("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(rate); u32(rate * 2); u16(2); u16(16); text("data"); u32(UInt32(sampleCount * 2))
        for sample in 0..<sampleCount {
            let value = Int16(sin(Double(sample) * 2 * .pi * 220 / Double(rate)) * 1_000)
            u16(UInt16(bitPattern: value))
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}
#endif
