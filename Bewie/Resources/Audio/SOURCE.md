# Album audio

The nine Apple-hosted tracks are Apple Lossless (ALAC) encodes of the authored WAV
masters in `/Users/bolos/Music/Masters/Every Room Is Borrowed`, imported on
23 October 2026. All masters are stereo, 48,000 Hz, 24-bit integer PCM.

`tools/import-lossless-masters.py` maps the named masters to album tracks 1–9,
encodes with Apple's afconvert, decodes each result to 24-bit WAV and verifies
that its PCM bytes, frame count, sample rate, channels and bit depth match the
source exactly before replacing any asset source. There is no resampling,
normalisation, gain change or lossy compression. The `.m4a` extension is a
container; these files contain ALAC, not AAC.

See `MusicAssets/masters-manifest.json` for source/encoded SHA-256 hashes and verified PCM
hashes, frame counts and format details. To reproduce the import:

```sh
python3 tools/import-lossless-masters.py '/Users/bolos/Music/Masters/Every Room Is Borrowed'
```

The separately downloaded audio totals 531,102,969 bytes (about 531 MB / 507 MiB), enabling
full offline playback once downloaded. Apple hosts the nine independently
versioned packs. The app bundle contains no music files. This replaces the
previous lossy web-published AAC copies. Lossless files preserve the masters;
the output route (for example Bluetooth) determines transmission quality.

This note is development provenance, not part of the app interface.
