#!/usr/bin/env python3
"""Reject incomplete Bewie archives before signing, upload or distribution."""
from pathlib import Path
import argparse
import json
import plistlib
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('archive', type=Path)
parser.add_argument('--platform', choices=['iOS', 'Mac', 'TV'], required=True)
parser.add_argument('--build', default='1')
args = parser.parse_args()
app = args.archive / 'Products/Applications/Bewie.app'
expected = {'iOS': {'bewie.atelierindustriel.be', 'bewie.atelierindustriel.be.watchkitapp',
                    'bewie.atelierindustriel.be.musicdownloader', 'bewie.atelierindustriel.be.messages'},
            'Mac': {'bewie.atelierindustriel.be', 'bewie.atelierindustriel.be.musicdownloader'},
            'TV': {'bewie.atelierindustriel.be', 'bewie.atelierindustriel.be.musicdownloader'}}[args.platform]
actual = set()
for bundle in [app] + [p for p in app.rglob('*') if p.suffix in ['.app', '.appex']]:
    info = next((p for p in [bundle/'Contents/Info.plist', bundle/'Info.plist'] if p.is_file()), None)
    assert info, f'Missing Info.plist in {bundle.name}'
    data = plistlib.loads(info.read_bytes())
    actual.add(data['CFBundleIdentifier'])
    assert data['CFBundleVersion'] == args.build, (bundle.name, data['CFBundleVersion'])
    assert data['CFBundleShortVersionString'] == '1.0'
    if bundle == app: assert data.get('ITSAppUsesNonExemptEncryption') is False, bundle.name
    else: assert data.get('ITSAppUsesNonExemptEncryption') is not True, bundle.name
assert actual == expected, {'expected': sorted(expected), 'actual': sorted(actual)}
if args.platform == 'iOS':
    subprocess.run(['python3', str(Path(__file__).with_name('verify-watch-bundle.py')),
                    str(app/'Watch/BewieWatch.app')], check=True)
print(json.dumps({'platform': args.platform, 'version': '1.0', 'build': args.build,
                  'bundles': sorted(actual), 'archiveContents': 'verified'}))
