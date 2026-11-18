#!/usr/bin/env python3
"""Import authored WAV masters as ALAC, verifying decoded PCM byte-for-byte."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

TITLES = ['Party Warriors', 'Every Room Is Borrowed', 'Next', 'Glass Walls',
          'Local Time', 'Noon Without End', 'Zero', 'Last Ones Home', 'I Stayed']
ROOT = Path(__file__).resolve().parent.parent

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest() if hasattr(hashlib, 'file_digest') else hashlib.sha256(stream.read()).hexdigest()

def pcm(path):
    with path.open('rb') as stream:
        assert stream.read(4) == b'RIFF', f'Not RIFF: {path}'
        stream.read(4)
        assert stream.read(4) == b'WAVE', f'Not WAV: {path}'
        metadata, audio = None, None
        while header := stream.read(8):
            assert len(header) == 8
            kind, count = struct.unpack('<4sI', header)
            if kind == b'fmt ':
                payload = stream.read(count)
                tag, channels, rate, _, block, bits = struct.unpack('<HHIIHH', payload[:16])
                assert tag in (1, 65534), 'Only integer PCM masters supported'
                if tag == 65534:
                    assert payload[24:40] == bytes.fromhex('0100000000001000800000aa00389b71')
                metadata = dict(channels=channels, sampleRate=rate, bits=bits, block=block)
            elif kind == b'data':
                remaining, hasher = count, hashlib.sha256()
                while remaining:
                    chunk = stream.read(min(1024 * 1024, remaining))
                    assert chunk, 'Truncated PCM'
                    hasher.update(chunk)
                    remaining -= len(chunk)
                audio = dict(pcmBytes=count, pcmSHA256=hasher.hexdigest())
            else:
                stream.seek(count, 1)
            if count % 2:
                stream.seek(1, 1)
        assert metadata and audio
        return {**metadata, **audio}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('masters', type=Path)
    args = parser.parse_args()
    target = ROOT / 'MusicAssets/Audio'
    records = []
    with tempfile.TemporaryDirectory(prefix='bewie-lossless-') as temporary:
        staging = Path(temporary)
        for index, title in enumerate(TITLES, 1):
            source = args.masters / (title + '.wav')
            original = pcm(source)
            assert (original['channels'], original['sampleRate'], original['bits']) == (2, 48000, 24), original
            name = f'track-{index:02}.m4a'
            encoded, decoded = staging / name, staging / 'decoded.wav'
            subprocess.run(['afconvert', '-f', 'm4af', '-d', 'alac', str(source), str(encoded)], check=True)
            subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI24', str(encoded), str(decoded)], check=True)
            assert pcm(decoded) == original, f'Lossless verification failed: {title}'
            decoded.unlink()
            records.append(dict(track=index, title=title, source=source.name,
                sourceSHA256=digest(source), filename=name, codec='alac',
                encodedSHA256=digest(encoded), encodedBytes=encoded.stat().st_size,
                frames=original['pcmBytes'] // original['block'], **original))
            print(f'{index}: {title} — PCM verified', flush=True)
        # Replace resources only after every track has passed the round trip.
        for record in records:
            shutil.copyfile(staging / record['filename'], target / record['filename'])
        (ROOT / 'MusicAssets/masters-manifest.json').write_text(json.dumps(dict(schemaVersion=1,
            sourceDirectory=str(args.masters.resolve()), tracks=records), indent=2) + '\n')
    print(f'Imported {len(records)} lossless masters, {sum(r["encodedBytes"] for r in records):,} bytes')

if __name__ == '__main__':
    main()
