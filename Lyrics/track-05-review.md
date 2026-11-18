# Local Time — timing review

Status: **automatically aligned draft; listening review still required**.

- Track: 5 — Local Time
- ISRC supplied: QTA2S2661551
- Master: `/Users/bolos/Music/Masters/Every Room Is Borrowed/Local Time.wav`
- Master duration: 233.31998 seconds
- Master SHA-256: `a0766d653e55400132ac4771e7d09c679de9cec41dfe9740b4f46bfd738664d1`
- Source: `Source/track-05.txt`
- Output: `track-05.lrc`
- Source contains 80 lyric lines. The LRC has 82 timed lyric lines: all supplied wording, plus one additional performed “Tap in / Tap out” pair in the outro. This repeat was independently detected in recognition passes on both the full master mix and the isolated vocal reference; it is flagged for listening confirmation below. No new words were introduced.
- Section headings, ISRC and Suno prompt are excluded from lyric display. The separate “Miss the stop / Stay out all night” and “No list / No line” lines remain separate cues. The final chorus keeps “Just follow where it leads” and “At city speed”.

## Alignment and listening checks

The recording was processed locally with Demucs vocal separation, Whisper sequence recognition and torchaudio MMS phonetic forced alignment. Each section and each outro line was aligned separately. The original master was not changed and no audio was sent to an external transcription service.

Timestamps indicate estimated line starts, not manually verified musical cues. Before production, listen through the whole file and prioritise:

- “Old card” and “Plastic chairs”: recognition suggested alternative words, while the LRC preserves the supplied text.
- Both “Put it away” cues and the short split chorus lines (“Miss the stop”, “No list”, “No line”), which have less reliable boundaries than the main verses.
- The fast seven-line breakdown, with separate “Tap in”, “Tap out”, “Turn left”, “Find out”, “One train”, “Two streets” and “No hurry” cues.
- The extra outro pair: “Tap in / Tap out” at about 03:36.47 / 03:37.48 and again at 03:44.59 / 03:45.89, before “Local time” at 03:47.16. Both recognition passes detect two pairs, but vary between “out” and “off”; the supplied word “out” is retained.

The original source text is unchanged, so the added timing repeat is explicit and reversible after listening review. No app source, build number, bundled resources, GitHub or TestFlight release was changed.
