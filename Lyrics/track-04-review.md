# Glass Walls — timing review

Status: **automatically aligned draft; listening review still required**.

- Track: 4 — Glass Walls
- ISRC supplied: QTA2S2661550
- Master: `/Users/bolos/Music/Masters/Every Room Is Borrowed/Glass Walls.wav`
- Master duration: 265.67998 seconds
- Master SHA-256: `0e1c43cca162045f275d579f1fb19581b447cdefbdccf5665826c1fd4a1f70a9`
- Source: `Source/track-04.txt`
- Output: `track-04.lrc`
- All 54 supplied lyric lines are preserved in order, including each chorus’s different wording, “Reflected next to mine” and the two outro repetitions of “We’ve got time”. Section labels, ISRC and Suno prompt are excluded from the displayed lyrics. Long instrumental gaps clear the current lyric using empty timestamp entries.

## Alignment and listening checks

The recording was processed locally using Demucs vocal separation, Whisper sequence recognition and torchaudio MMS phonetic forced alignment. Each section and each outro repetition was aligned separately. The original master was not changed, and no audio was sent to an external transcription service.

Timestamps indicate estimated line starts, not manually verified musical cues. Before production, listen through the whole file and prioritise:

- Short “Glass walls” and “Your face” cues across the choruses, particularly the first “Glass walls” of the final chorus (around 03:28.42), which has lower alignment confidence.
- The final “Berlin outside” at approximately 03:53.01: recognition omitted this phrase in one pass and the aligned duration was unusually long, so verify its wording and onset.
- The two quiet outro repetitions of “We’ve got time”, around 04:09.71 and 04:18.17, whose phonetic alignment confidence is lower than the verses.

All supplied wording is retained even where recognition suggested alternatives. No app source, build number, bundled resources, GitHub or TestFlight release was changed. The LRC is saved outside the app target for later inclusion after timing review.
