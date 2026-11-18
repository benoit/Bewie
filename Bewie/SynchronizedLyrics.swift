import Foundation

struct SynchronizedLyrics: Sendable {
    struct Cue: Identifiable, Sendable {
        let id: Int
        let time: TimeInterval
        let text: String
    }

    let cues: [Cue]

    init(lrc: String) {
        var entries: [(TimeInterval, String)] = []
        var offset: TimeInterval = 0
        for line in lrc.components(separatedBy: .newlines) {
            if line.hasPrefix("[offset:"), let end = line.firstIndex(of: "]"),
               let milliseconds = Double(line[line.index(line.startIndex, offsetBy: 8)..<end]) {
                offset = milliseconds / 1_000
                continue
            }
            var remaining = line[...]
            var times: [TimeInterval] = []
            while remaining.first == "[", let end = remaining.firstIndex(of: "]") {
                let parts = remaining[remaining.index(after: remaining.startIndex)..<end].split(separator: ":")
                guard parts.count == 2, let minutes = Double(parts[0]),
                      let seconds = Double(parts[1]), minutes >= 0, seconds >= 0, seconds < 60 else { break }
                times.append(minutes * 60 + seconds)
                remaining = remaining[remaining.index(after: end)...]
            }
            let text = remaining.trimmingCharacters(in: .whitespaces)
            for time in times { entries.append((time, text)) }
        }
        // LRC offsets are milliseconds: positive values advance the displayed lyrics.
        cues = entries.enumerated().sorted {
            $0.element.0 == $1.element.0 ? $0.offset < $1.offset : $0.element.0 < $1.element.0
        }.enumerated().map { index, entry in
            Cue(id: index, time: entry.element.0 - offset, text: entry.element.1)
        }
    }

    func cueIndex(at time: TimeInterval) -> Int? {
        guard time.isFinite else { return nil }
        // Always derive from the audio clock: seeking backwards and pausing need no reset.
        var low = 0
        var high = cues.count
        while low < high {
            let mid = (low + high) / 2
            if cues[mid].time <= time { low = mid + 1 } else { high = mid }
        }
        return low == 0 ? nil : low - 1
    }

    static let album: [Int: SynchronizedLyrics] = Dictionary(uniqueKeysWithValues: (1...9).compactMap { id in
        let name = String(format: "track-%02d", id)
        guard let url = Bundle.main.url(forResource: name, withExtension: "lrc"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return (id, SynchronizedLyrics(lrc: text))
    })
}
