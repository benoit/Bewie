# Noon Without End — timing review

Status: **automatically aligned draft; listening review still required**.

- Track: 6 — Noon Without End
- ISRC supplied: QTA2S2661552
- Master: `/Users/bolos/Music/Masters/Every Room Is Borrowed/Noon Without End.wav`
- Master duration: 374.07998 seconds (6:14.08)
- Master SHA-256: `c4fae523f259b9950c17eb740bd353fd70c0435f9469519bddfc821c6063912a`
- Source: `Source/track-06.txt`
- Output: `track-06.lrc`
- All 61 supplied lyric lines are preserved in order, including the two intro repetitions, both full refrains, both Sea/Salt/Heat/Breath cycles, the changed final refrain and the three outro repetitions. Section headings, ISRC and Suno prompt are excluded from displayed lyrics.

## Alignment and listening checks

The recording was processed locally with Demucs vocal separation, Whisper sequence recognition and torchaudio MMS phonetic forced alignment. Long refrains were split into smaller regions, and intro/outro repetitions were aligned separately. The second “Noon without end” in the first refrain was re-aligned in a narrower window after the first pass placed it too early. The original master was not changed and no audio was sent to an external transcription service.

Timestamps indicate estimated line starts, not manually verified musical cues. The detached, reverberant vocal is challenging for recognition; before production listen through the whole file and prioritise:

- “Noon without end” entrances throughout the refrains, especially the revised cue at 01:32.69.
- The short “Sea / Salt / Heat / Breath” breakdown around 03:32–03:47. The Heat cues in particular have low phonetic alignment confidence; the supplied word Breath is preserved rather than the recogniser’s Breathe.
- The three closing “Noon again” cues, around 04:50.20, 04:58.06 and 05:05.93. Recognition fragmented the final phrase; the supplied three repetitions are retained.
- “Under one sun”: recognition suggested a different final word, while the supplied text remains unchanged.

The master continues instrumentally well after the last vocal. Empty timestamp entries clear the displayed text during long gaps, including after the final outro line; the LRC’s last timestamp therefore precedes the 6:14 end of the master. This is intentional, not a truncated track.

No app source, build number, bundled resources, GitHub or TestFlight release was changed. The LRC is saved outside the app target for later inclusion after timing review.
