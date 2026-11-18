# Last Ones Home — timing review

Status: **automatically aligned draft; listening review still required**.

- Track: 8 — Last Ones Home
- ISRC supplied: QTA2S2661554
- Master: `/Users/bolos/Music/Masters/Every Room Is Borrowed/Last Ones Home.wav`
- Master duration: 266.63998 seconds
- Master SHA-256: `559590486a590769d9ccb7415f970aeae7a138ae054733a6d97a7dc8a59b6b92`
- Original source: `Source/track-08.txt` (71 lines, unchanged)
- LRC: `track-08.lrc` (70 timed lyric cues)
- Section headings, ISRC and Suno prompt are excluded from lyric display. Supplied wording, punctuation and the emphatic NOT US / ONE MORE are preserved.

## Build repetition count

The source has four One more lines in the Build. Focused recognition on the full mix detects three clear calls around 02:49, 02:56–02:57 and 03:04; vocal-only recognition detects only the last. Forcing all four lines into a broad window assigned multiple cues between the first two clear calls and missed the last call. The draft instead has three separately aligned build cues, keeping ONE MORE on the last. This is a provisional editorial timing decision: listen for a fourth quieter call or echo and restore its cue if appropriate. All four original lines remain in the source text.

## Alignment and listening checks

Processing was local: Demucs vocal separation, Whisper sequence recognition and torchaudio MMS phonetic forced alignment. The intro, build and outro were checked against the original full mix because vocal separation weakens these sampled/shouted calls. No master was modified and no audio was sent to an external transcription service.

Timestamps indicate estimated line starts, not manually verified musical cues. Before production listen through the entire file and prioritise:

- All intro/build One more calls, including the count difference above. The three intro cues are retained as supplied.
- The second Not yet in the post-chorus (about 01:36.59): recognition suggested One more in one pass, so confirm supplied wording and timing.
- One more track in the second chorus: recognition suggested another final word, but supplied text is retained.
- The fast call-and-response breakdown, especially the shouted NOT US.
- The first eight lines of the final chorus, including Lights come up, which have lower alignment confidence than the verses.
- Thirty years / And still going strong and the four outro lines; all supplied wording is retained. An apparent extra One more for you at the end of verse 2 had nearly zero-duration recognition tokens and was not treated as an additional lyric.

Empty timestamp entries clear the displayed lyric during long gaps and after the final outro where sufficient audio remains. No app source, build number, bundled resources, GitHub or TestFlight release was changed.
