#!/usr/bin/env python3
"""Distribution-sign and upload one verified Bewie platform archive with ASC API auth."""
from pathlib import Path
import argparse
import os
import plistlib
import subprocess
from appstore_connect import Client

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('platform', choices=['iOS', 'Mac', 'TV'])
parser.add_argument('--build', default='1')
parser.add_argument('--release-root', type=Path, required=True)
parser.add_argument('--destination', choices=['export', 'upload'], default='upload')
args = parser.parse_args()
archive = args.release_root / f'Bewie-{args.platform}-{args.build}.xcarchive'
subprocess.run(['python3', str(ROOT/'tools/verify-release-archive.py'), str(archive),
                '--platform', args.platform, '--build', args.build], check=True)
app = archive/'Products/Applications/Bewie.app'
# Preserve each target's declared capabilities for Xcode's distribution-signing step.
if args.platform == 'iOS':
    targets = [(app/'Extensions/MusicDownloader.appex', 'MusicDownloader.entitlements'),
               (app/'PlugIns/BewieMessages.appex', 'Messages.entitlements'),
               (app/'Watch/BewieWatch.app', None), (app, 'Bewie.entitlements')]
elif args.platform == 'Mac':
    targets = [(app/'Contents/Extensions/MusicDownloaderMac.appex', 'Mac-MusicDownloader.entitlements'),
               (app, 'Mac.entitlements')]
else:
    targets = [(app/'Extensions/MusicDownloaderTV.appex', 'MusicDownloader.entitlements'),
               (app, 'TV.entitlements')]
for bundle, entitlement in targets:
    assert bundle.is_dir(), bundle.name
    command = ['codesign', '--force', '--sign', '-', '--generate-entitlement-der']
    if entitlement: command += ['--entitlements', str(ROOT/'Configuration'/entitlement)]
    subprocess.run(command+[str(bundle)], check=True, capture_output=True)
options = plistlib.loads((ROOT/'Configuration/ExportOptions-TestFlight.plist').read_bytes())
options['destination'] = args.destination
options['testFlightInternalTestingOnly'] = False
optionsPath = args.release_root / f'Export-{args.platform}-{args.destination}.plist'
optionsPath.write_bytes(plistlib.dumps(options))
client = Client()
command = ['xcodebuild', '-exportArchive', '-archivePath', str(archive),
           '-exportOptionsPlist', str(optionsPath), '-exportPath',
           str(args.release_root/f'{args.platform}-{args.build}-{args.destination}'),
           '-allowProvisioningUpdates', '-authenticationKeyPath', client.values['ASC_KEY_PATH'],
           '-authenticationKeyID', client.values['ASC_KEY_ID'],
           '-authenticationKeyIssuerID', client.values['ASC_ISSUER_ID']]
logPath = args.release_root / f'{args.platform}-{args.destination}-{args.build}.log'
with os.fdopen(os.open(logPath, os.O_WRONLY|os.O_CREAT|os.O_TRUNC, 0o600), 'w') as log:
    result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, cwd=ROOT)
text = logPath.read_text()
markers = ['** EXPORT SUCCEEDED **']
if args.destination == 'upload': markers += ['Uploaded package is processing', 'Upload succeeded']
if result.returncode or not all(marker in text for marker in markers):
    secrets = list(client.values.values()) + [options.get('teamID', '')]
    for line in text.splitlines():
        if any(word in line.lower() for word in ['error:', 'error ', 'failed', 'no profiles']):
            for secret in secrets:
                if secret: line = line.replace(secret, '[redacted]')
            print(line[:700])
    raise SystemExit(f'{args.platform} {args.destination} failed; see the private release log.')
print(f'{args.platform} {args.destination} verified for version 1.0 ({args.build}).')
