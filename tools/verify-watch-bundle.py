#!/usr/bin/env python3
"""Reject oversized or duplicate-filled Watch bundles before TestFlight upload.

Checks full, uncompressed contents conservatively before Apple's app thinning.
Use an .xcarchive, an exported .ipa, or the Watch .app directory.
"""
import argparse
from pathlib import Path
import zipfile

WATCH_BUDGET = 70_000_000  # Leave 5 MB below Apple's 75 MB maximum.
EXPECTED_TRACKS = {f'track-{number:02}.m4a' for number in range(1, 10)}


def verify(label, files):
    total = sum(size for name, size in files)
    audio = [name for name, size in files if name.endswith('.m4a')]
    if set(audio) != {f'Audio/{name}' for name in EXPECTED_TRACKS} or len(audio) != 9:
        raise SystemExit(f'{label}: expected each of the nine songs exactly once in Audio/')
    if total >= WATCH_BUDGET:
        raise SystemExit(f'{label}: {total:,} uncompressed bytes exceeds the '
                         f'{WATCH_BUDGET:,}-byte Watch release budget (Apple limit: 75 MB)')
    print(f'{label}: {total:,} uncompressed bytes; nine AAC songs; '
          f'{75_000_000 - total:,} bytes below the 75 MB limit')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact', type=Path)
    artifact = parser.parse_args().artifact
    if artifact.suffix == '.ipa':
        with zipfile.ZipFile(artifact) as ipa:
            entries = [info for info in ipa.infolist() if not info.is_dir()]
            roots = {info.filename.split('/Watch/', 1)[0] + '/Watch/' +
                     info.filename.split('/Watch/', 1)[1].split('/', 1)[0] + '/'
                     for info in entries if '/Watch/' in info.filename}
            if not roots:
                raise SystemExit('No embedded Watch app found in IPA')
            for root in sorted(roots):
                verify(root, [(info.filename[len(root):], info.file_size)
                              for info in entries if info.filename.startswith(root)])
    else:
        roots = list(artifact.glob('Products/Applications/*.app/Watch/*.app')) \
            if artifact.suffix == '.xcarchive' else [artifact]
        if not roots or not all(root.is_dir() for root in roots):
            raise SystemExit('No Watch app found')
        for root in roots:
            verify(root.name, [(str(file.relative_to(root)), file.stat().st_size)
                               for file in root.rglob('*') if file.is_file()])


if __name__ == '__main__':
    main()
