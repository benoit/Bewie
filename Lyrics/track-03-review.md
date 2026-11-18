# Next — timing review

Status: **automatically aligned draft; listening review still required**.

- Track: 3 — Next
- ISRC supplied: QTA2S2661549
- Master: `/Users/bolos/Music/Masters/Every Room Is Borrowed/Next.wav`
- Master duration: 243.83998 seconds
- Master SHA-256: `4fc9ff9bf00f6415abac63de66a534883414df324f845d6750ff0fe88531b206`
- Source: `Source/track-03.txt`
- Output: `track-03.lrc`
- All 57 supplied lyric lines are preserved in order, including the intro, both main choruses, the changed “Another morning” in the final chorus, and all three outro repetitions of “Where next?”. Section headings, ISRC and Suno prompt are excluded from lyric display. Instrumental gaps clear the displayed line with empty timestamp entries; “Instrumental Build” is not displayed as a lyric.

## Alignment and listening checks

The recording was processed locally with Demucs vocal separation, Whisper sequence recognition and torchaudio MMS phonetic forced alignment. The short chorus lines and final chorus received narrower alignment windows, and each outro repetition was aligned separately. The original master was not changed and no audio was sent to an external transcription service.

The verses generally gave stronger alignment than the processed choruses. All cues remain estimated line starts rather than manually verified musical cues. Before production, listen through the whole LRC and prioritise:

- The short “Next” hooks in all three choruses, especially about 02:17, 02:21 and 03:23. Recognition/alignment confidence is low for these processed words; the supplied text is retained unchanged.
- “We need to get right” and “Worth writing down”: recognition disagrees with parts of the supplied wording, which remains authoritative in the LRC.
- The tight breakdown “Not if / When? / Now.” around 02:56–02:59: “When?” and “Now.” have the lowest alignment confidence and need confirmation that the words and timings match the performance.
- “I’ll follow” in the second chorus (about 02:32), and “Another morning / Another road” in the final chorus (about 03:28–03:30).
- The three outro cues (03:44.17, 03:52.43 and 04:00.67).

No app source, build number, bundled resources, GitHub or TestFlight release was changed. The LRC is saved outside the app target for later inclusion after timing review.
