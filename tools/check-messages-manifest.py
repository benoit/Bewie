"""Validate all nine source videos before packaging or publishing asset packs."""
import hashlib
import json
from pathlib import Path
import sys

directory = Path(sys.argv[1])
try:
    manifest = json.loads((directory / 'manifest.json').read_text())
    tracks = manifest['tracks']
    assert manifest['schemaVersion'] == 1
    assert sorted(t['id'] for t in tracks) == list(range(1, 10))
    for track in tracks:
        assert track['filename'] == f"track-{track['id']:02}.mp4"
        path = directory / track['filename']
        assert track['width'] == track['height'] == 2160
        assert track['audioDecoded'] and track['decodedVideoFrames'] == 3
        assert path.stat().st_size == track['bytes']
        digest = hashlib.sha256()
        with path.open('rb') as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b''):
                digest.update(chunk)
        assert digest.hexdigest() == track['sha256']
except (OSError, ValueError, KeyError, AssertionError) as error:
    raise SystemExit(f'error: Messages videos are missing or incomplete in {directory}. Render and verify all nine videos before publishing. {error}')
print('Verified nine complete 2160 × 2160 Messages videos.')
