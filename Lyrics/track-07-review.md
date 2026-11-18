# Zero — timing review

Status: **automatically aligned draft; listening review still required**.

- Track: 7 — Zero
- ISRC supplied: QTA2S2661553
- Master: `/Users/bolos/Music/Masters/Every Room Is Borrowed/Zero.wav`
- Master duration: 256.23998 seconds
- Master SHA-256: `be2cb8e9959f5cd0e8519d7f4ca80038ee34ddab14d41788f63bd7902e475ea1`
- Original source: `Source/track-07.txt` (41 lines; unchanged)
- LRC output: `track-07.lrc` (40 timed lyric cues)
- The duplicated prompt, section headings and ISRC are excluded from lyric display. All wording follows the supplied lyrics.

## Shared cue at the second verse/chorus boundary

The source ends verse 2 with Zero and immediately opens chorus 2 with another Zero. Vocal forced alignment maps both lines to the same utterance (02:18.40 and 02:18.38), creating overlapping/non-monotonic timestamps. Full-mix recognition likewise finds a single Zero at this boundary before Nothing in the way. The LRC therefore uses one shared cue at **02:18.40**, representing both source lines, instead of flashing Zero twice over the same performance. The original 41-line source is retained. This is an editorial timing decision based on automatic checks and needs listening confirmation; restore a separate cue if a second utterance is audible.

## Alignment and listening checks

Processing was local: Demucs vocal separation, Whisper sequence recognition and torchaudio MMS phonetic forced alignment. The second verse/chorus boundary and sparse ending were cross-checked against the original full mix. Several ending phrases and Zero cues use narrower full-mix alignment windows because vocal separation weakens these sounds. The original master was not modified and no audio was sent to an external transcription service.

Timestamps are estimated line starts, not manually verified musical cues. Before app inclusion, listen through the whole file and prioritise:

- The verse-1 ending Zero around 00:58.79 and the first chorus’s opening Zero around 01:07.06; these have low alignment confidence.
- The shared second-verse/chorus Zero described above.
- Bridge lines The better version / The edited me and Nothing added / Nothing borrowed: recognition suggested alternatives, but supplied wording is retained. Check phrase boundaries as well as line starts.
- The bridge-ending Zero around 03:32.25 and the two isolated outro Zero cues around 03:50.71 and 04:09.17. These are faint/processed and were not consistently recognised as Zero.
- Both Nothing missing cues in the outro; recognition disagreed on the final word in one pass.

Empty timestamp entries clear the displayed lyric during long gaps and after the final word where the remaining audio is long enough. No app source, build number, bundled resources, GitHub or TestFlight release was changed. The draft is saved outside the app target.
