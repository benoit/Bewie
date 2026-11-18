import XCTest
@testable import Bewie

final class SynchronizedLyricsTests: XCTestCase {
    func testAudioClockHandlesBoundariesPausesAndBackwardSeeks() {
        let lyrics = SynchronizedLyrics(lrc: "[ti:Example]\n[00:01.20]First\n[00:03.40]Second\n[00:05.00]\n[00:10.00]Return")
        XCTAssertNil(lyrics.cueIndex(at: 0))
        XCTAssertEqual(lyrics.cueIndex(at: 1.20), 0)
        XCTAssertEqual(lyrics.cueIndex(at: 3.40), 1)
        XCTAssertEqual(lyrics.cueIndex(at: 4.90), 1)
        XCTAssertEqual(lyrics.cueIndex(at: 4.90), 1)
        XCTAssertEqual(lyrics.cueIndex(at: 1.21), 0)
        XCTAssertEqual(lyrics.cues[lyrics.cueIndex(at: 8)!].text, "")
        XCTAssertEqual(lyrics.cueIndex(at: 10), 3)
        XCTAssertNil(lyrics.cueIndex(at: .nan))
    }

    func testMetadataOffsetsRepeatedTimestampsAndUnicode() {
        let lyrics = SynchronizedLyrics(lrc: "[ar:Bewie]\n[00:12.25][00:02.25]We’re still here\n[bad]Ignore\n[offset:250]")
        XCTAssertEqual(lyrics.cues.count, 2)
        XCTAssertEqual(lyrics.cues.map(\.time), [2, 12])
        XCTAssertEqual(lyrics.cues.map(\.text), ["We’re still here", "We’re still here"])
        XCTAssertEqual(lyrics.cueIndex(at: 12), 1)
        XCTAssertNil(SynchronizedLyrics(lrc: "[ti:Empty]").cueIndex(at: 1))
    }

    func testAllNineBundledSongsContainTimedLyricsAndInstrumentalClears() {
        XCTAssertEqual(SynchronizedLyrics.album.count, 9)
        let counts = [36, 61, 57, 54, 82, 61, 39, 70, 68]
        for id in 1...9 {
            guard let lyrics = SynchronizedLyrics.album[id] else { return XCTFail("Missing bundled lyrics for track \(id)") }
            XCTAssertEqual(lyrics.cues.filter { !$0.text.isEmpty }.count, counts[id - 1])
            XCTAssertTrue(lyrics.cues.first?.text.isEmpty == true)
            XCTAssertTrue(lyrics.cues.contains { $0.text.isEmpty })
            for pair in zip(lyrics.cues, lyrics.cues.dropFirst()) {
                XCTAssertLessThan(pair.0.time, pair.1.time)
            }
            let ending = lyrics.cueIndex(at: 10_000)!
            XCTAssertEqual(ending, lyrics.cues.count - 1)
        }
    }
}
