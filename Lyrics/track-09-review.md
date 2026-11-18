# I Stayed — timing review

Status: **automatically aligned draft; listening review still required**.

- Track: 9 — I Stayed
- ISRC supplied: QTA2S2661555
- Master: `/Users/bolos/Music/Masters/Every Room Is Borrowed/I Stayed.wav`
- Master duration: 316.23998 seconds
- Master SHA-256: `0709608983e78a794791a3b30052abdebbca424f06c29c41949c244982cc813d`
- Original source: `Source/track-09.txt` (66 supplied lines; unchanged)
- LRC: `track-09.lrc` (68 timed lyric lines)
- All supplied wording and order are preserved, plus two performed Again ad-libs after the main choruses. Section headings, ISRC and Suno prompt are excluded from displayed lyrics.

## Recorded Again repetitions

Recognition on both the isolated vocal and focused full-mix clips identifies Again after each That’s how we made it. These two ad-libs are included at approximately 01:38.03 and 03:04.65. Their word is already present in the supplied bridge lyrics; no new wording was invented. The original text remains unchanged. Focused full-mix recognition also confirms all three Again repetitions at the bridge’s end, which are retained.

## Alignment and listening checks

Processing was local: Demucs vocal separation, Whisper sequence recognition and torchaudio MMS phonetic forced alignment. Chorus endings, ad-libs and the final line received separate narrower alignment windows. No master was modified and no audio was sent to an external transcription service.

All timestamps remain estimated line starts, not manually verified musical cues. Before production, listen through the entire file and prioritise:

- The two added Again ad-libs and the three supplied Again bridge repetitions (about 03:34–03:42).
- The bridge opening Love isn’t perfect words and the second pre-chorus/chorus phrasing, where segmentation was less certain than the main verses.
- Never because I knew: recognition suggested another last word; supplied wording is preserved.
- I’ll meet you there / Still here around 04:26–04:29: recognition did not consistently resolve there as a separate word.
- The final We still do cue at approximately **04:34.37**, which is particularly uncertain: separate recognition passes suggested Still waiting or Still here. The LRC keeps the supplied We still do, but the performed wording and exact onset need listening confirmation. Narrow-window alignment improved the timestamp from an implausibly early first-pass cue; it does not establish the words as correct.

The instrumental tail after the last vocal is handled by an empty timestamp clearing cue. No app source, build number, bundled resources, GitHub or TestFlight release was changed. These files are saved outside the app target for later inclusion after review.
