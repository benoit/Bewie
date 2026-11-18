#!/usr/bin/env python3
"""Encode/verify the offline Watch album using Apple's AAC encoder (192 kb/s)."""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
output = root / 'BewieWatch/Resources/Audio'
manifest = root / 'MusicAssets/WatchAudioManifest.json'
encoder = dict(codec='aac', bitRate=192000, strategy=2, quality=127)
audio_budget = 64_000_000
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--verify', action='store_true', help='Verify existing files without changing them')
args = parser.parse_args()

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inspect(path):
    info = subprocess.check_output(['/usr/bin/afinfo', str(path)], text=True)
    match = re.search(r'Data format:\s+(\d+) ch,\s+(\d+) Hz, (\w+)', info)
    frames = re.search(r'audio (\d+) valid frames', info)
    if not match or not frames:
        raise SystemExit(f'Cannot inspect audio format/frame count: {path}')
    return dict(channels=int(match[1]), sampleRate=int(match[2]), codec=match[3], frames=int(frames[1]))

previous = json.loads(manifest.read_text()) if manifest.exists() else {}
records = {}
output.mkdir(parents=True, exist_ok=True)
for number in range(1, 10):
    name = f'track-{number:02}.m4a'
    source = root / 'MusicAssets/Audio' / name
    destination = output / name
    if not source.is_file():
        raise SystemExit(f'Missing {source}. Import the lossless masters first.')
    source_hash = digest(source)
    record = previous.get(name, {})
    current = (record.get('encoder') == encoder and destination.is_file() and record.get('sourceSHA256') == source_hash
               and record.get('aacSHA256') == digest(destination))
    if not current and not args.verify:
        temporary = destination.with_suffix('.tmp.m4a')
        subprocess.run(['/usr/bin/afconvert', str(source), str(temporary), '-f', 'm4af',
                        '-d', encoder['codec'], '-b', str(encoder['bitRate']),
                        '-q', str(encoder['quality']), '-s', str(encoder['strategy'])], check=True)
        temporary.replace(destination)
    if not destination.is_file():
        raise SystemExit(f'Missing {destination}. Run this script without --verify first.')
    original, encoded = inspect(source), inspect(destination)
    if original['codec'] != 'alac' or encoded['codec'] != 'aac':
        raise SystemExit(f'Unexpected codec for {name}: {original} / {encoded}')
    for field in ('channels', 'sampleRate', 'frames'):
        if original[field] != encoded[field]:
            raise SystemExit(f'{field} mismatch for {name}: {original} / {encoded}')
    records[name] = dict(sourceSHA256=source_hash, aacSHA256=digest(destination),
                         bytes=destination.stat().st_size, encoder=encoder, **encoded)
    if args.verify and records[name] != record:
        raise SystemExit(f'Manifest mismatch for {name}. Rebuild Watch AAC audio.')
    print(f'Verified {name}: AAC, {encoded["frames"]} frames, {destination.stat().st_size:,} bytes', flush=True)
total_bytes = sum(record['bytes'] for record in records.values())
if total_bytes >= audio_budget:
    raise SystemExit(f'Watch AAC album exceeds the {audio_budget:,}-byte budget: {total_bytes:,}')
if not args.verify:
    manifest.write_text(json.dumps(records, indent=2) + '\n')
print(f'Album: {sum(record["bytes"] for record in records.values()):,} bytes')
