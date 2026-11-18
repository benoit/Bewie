# Party Warriors — timing review

Status: **automatically aligned draft, listening review still required**.

- Track: 1 — Party Warriors
- ISRC supplied: QTA2S2661547
- Master: `/Users/bolos/Music/Masters/Every Room Is Borrowed/Party Warriors.wav`
- Master duration: 268.83998 seconds
- Master SHA-256: `d9ec2a8a79340f415fb150dad271a7ac02ba03bdb4bbc4b300aa3e157686173a`
- Text: the user’s Lyrics section only; all 36 lyric lines and the repeated final chorus are preserved verbatim. Section headings, ISRC and Suno prompt are excluded from the LRC lyric display.
- Timing: local vocal separation with Demucs, cross-checks with Whisper, and phonetic forced alignment with torchaudio MMS. No audio was sent to an external transcription service. Instrumental gaps clear the displayed line with empty timestamp entries.
- Source: `Source/track-01.txt`
- Output: `track-01.lrc`

## Listening checks before app inclusion

The instrumental mix and sung phrasing make automatic word recognition unreliable in several places. Timestamps are estimates of line starts, not manually verified musical cues. Prioritise:

- The opening “Midnight came” and “Two a.m.” entrances (around 00:31 and 00:39).
- The first “Party warriors” chorus entrance (around 01:01).
- Both questions in the spoken break (around 01:48 and 01:55).
- “One track more” at the end of the first final chorus (around 02:30): recognisers disagree on the sung words; the LRC retains the supplied wording.
- The return after the long instrumental passage (around 03:20).

The entire file should receive one listening pass before being considered production-ready. No app source, build number, bundle resources or TestFlight build was changed for this lyric preparation.
