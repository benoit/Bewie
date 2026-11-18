# Every Room Is Borrowed — prepared lyric drafts

All nine tracks have a UTF-8 line-timed LRC draft, original source text and timing review notes. These are automatically aligned preparation files; **none has had a complete manual listening review and none is production-approved**.

The LRC files are in this folder, original supplied lyrics in Source/, and uncertainties/editorial decisions in track-XX-review.md. Only the user’s Lyrics sections were retained; prompts, ISRC lines and section labels do not appear as displayed lyric lines. Source wording is preserved, with the explicit repeat-count decisions listed below.

| Track | Title | Source lines | Timed lyric cues | Notes |
| --- | --- | ---: | ---: | --- |
| 1 | [Party Warriors](track-01.lrc) | 36 | 36 | [Review](track-01-review.md) — Source text retained without repeat-count changes. |
| 2 | [Every Room Is Borrowed](track-02.lrc) | 61 | 61 | [Review](track-02-review.md) — Source text retained without repeat-count changes. |
| 3 | [Next](track-03.lrc) | 57 | 57 | [Review](track-03-review.md) — Source text retained without repeat-count changes. |
| 4 | [Glass Walls](track-04.lrc) | 54 | 54 | [Review](track-04-review.md) — Source text retained without repeat-count changes. |
| 5 | [Local Time](track-05.lrc) | 80 | 82 | [Review](track-05-review.md) — One extra Tap in / Tap out outro pair included. |
| 6 | [Noon Without End](track-06.lrc) | 61 | 61 | [Review](track-06-review.md) — Source text retained without repeat-count changes. |
| 7 | [Zero](track-07.lrc) | 41 | 40 | [Review](track-07-review.md) — Adjacent verse/chorus Zero lines share one provisional cue. |
| 8 | [Last Ones Home](track-08.lrc) | 71 | 70 | [Review](track-08-review.md) — Build uses three clearly detected One more calls rather than four source lines. |
| 9 | [I Stayed](track-09.lrc) | 66 | 68 | [Review](track-09-review.md) — Two Again ad-libs after the main choruses included. |

LRC timestamps are minutes:seconds.centiseconds relative to the original WAV master, with offset 0. Empty timestamp entries clear the displayed lyric during sufficiently long instrumental gaps. They are not missing lyric lines. Headers carry the track, artist and album names.

Preparation ran locally using temporary vocal separation, speech recognition cross-checks and phonetic forced alignment. No master was modified or uploaded to a transcription service. Review notes record the master SHA-256 for each file. Structural validation checks all nine files for expected text/order, strictly increasing timestamps, master-duration bounds and matching master hashes. Machine-generated timestamp precision is not proof of musical timing accuracy.

These files sit outside the Bewie app target. No lyrics UI/parser or app integration has been implemented, and this lyric preparation has not changed the app version, GitHub or TestFlight. Temporary processing files are in build/lyrics; reusable local models/tools are outside the app bundle.
