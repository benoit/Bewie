#!/usr/bin/env python3
"""Exercise pack publishing without Apple credentials or network access."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class MusicPackUploadTests(unittest.TestCase):
    def test_policy_changes_republish_but_unchanged_audio_and_manifest_skip(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ['tools', 'bin', 'MusicAssets/Audio', 'Configuration/AssetPacks']:
                (root / name).mkdir(parents=True)
            shutil.copy(Path(__file__).with_name('music-packs.sh'), root / 'tools/music-packs.sh')
            (root / 'Configuration/AppStore.json').write_text(json.dumps({'appleAppID': '1234567890'}))
            records = []
            for number in range(1, 10):
                audio = f'lossless fixture {number}'.encode()
                (root / f'MusicAssets/Audio/track-{number:02}.m4a').write_bytes(audio)
                manifest = dict(assetPackID=f'bewie-track-{number:02}', platforms=['iOS'],
                                downloadPolicy={'essential': {'installationEventTypes': ['firstInstallation', 'subsequentUpdate']}})
                (root / f'Configuration/AssetPacks/track-{number:02}.json').write_text(json.dumps(manifest))
                records.append(dict(track=number, assetPackID=manifest['assetPackID'], appleVersion='1',
                                    encodedSHA256=hashlib.sha256(audio).hexdigest()))
            record = root / 'MusicAssets/PublishedPacks.json'
            record.write_text(json.dumps(dict(schemaVersion=1, packs=records)))
            (root / 'credentials.env').write_text('ASC_KEY_ID=fixture\nASC_ISSUER_ID=fixture\nASC_KEY_PATH=/tmp/fixture.p8\n')
            mock = root / 'bin/xcrun'
            mock.write_text('''#!/usr/bin/env python3
import json,sys
from pathlib import Path
args=sys.argv[1:]
if args[0]=='ba-package':
 manifest=json.loads(Path(args[1]).read_text())
 assert list(manifest['downloadPolicy'])==['essential']
 Path(args[args.index('-o')+1]).write_text(json.dumps(manifest))
elif args[0]=='altool':
 assert args[args.index('--apple-id')+1]=='1234567890'
 manifest=json.loads(Path(args[args.index('--upload-asset-pack')+1]).read_text())
 calls=Path('calls.json')
 history=json.loads(calls.read_text()) if calls.exists() else []
 identifier=manifest['assetPackID']
 version=2+history.count(identifier)
 history.append(identifier)
 calls.write_text(json.dumps(history))
 print(json.dumps({'asset-pack-identifier':identifier,'asset-pack-version':str(version)}))
else:raise SystemExit('Unexpected command')
''')
            mock.chmod(0o755)
            env = dict(os.environ, PATH=str(root / 'bin') + os.pathsep + os.environ['PATH'],
                       ASC_ENV_FILE=str(root / 'credentials.env'))

            def publish():
                subprocess.run(['bash', 'tools/music-packs.sh', 'upload'], cwd=root, env=env,
                               check=True, capture_output=True, text=True)

            publish()  # Legacy audio-only fingerprints must not suppress policy updates.
            saved = json.loads(record.read_text())
            self.assertEqual(saved['schemaVersion'], 3)
            self.assertEqual(saved['appleAppID'], '1234567890')
            self.assertEqual(len(json.loads((root / 'calls.json').read_text())), 9)
            self.assertTrue(all(p['appleVersion'] == '2' and len(p['manifestSHA256']) == 64 for p in saved['packs']))
            publish()
            self.assertEqual(len(json.loads((root / 'calls.json').read_text())), 9)
            manifest_path = root / 'Configuration/AssetPacks/track-01.json'
            manifest = json.loads(manifest_path.read_text())
            manifest['downloadPolicy']['essential']['installationEventTypes'] = ['firstInstallation']
            manifest_path.write_text(json.dumps(manifest))
            publish()  # Policy-only change with identical audio must upload once.
            history = json.loads((root / 'calls.json').read_text())
            self.assertEqual(len(history), 10)
            self.assertEqual(history[-1], 'bewie-track-01')
            manifest_path.write_text(json.dumps(manifest, indent=4))
            publish()  # Formatting-only edits must not upload again.
            self.assertEqual(len(json.loads((root / 'calls.json').read_text())), 10)
            (root / 'MusicAssets/Audio/track-02.m4a').write_bytes(b'changed lossless fixture')
            publish()
            history = json.loads((root / 'calls.json').read_text())
            self.assertEqual(len(history), 11)
            self.assertEqual(history[-1], 'bewie-track-02')
            # Adding Mac availability must publish a new version even though audio is unchanged.
            platform_path = root / 'Configuration/AssetPacks/track-03.json'
            manifest = json.loads(platform_path.read_text())
            manifest['platforms'] = ['iOS', 'tvOS', 'macOS']
            platform_path.write_text(json.dumps(manifest))
            publish()
            history = json.loads((root / 'calls.json').read_text())
            self.assertEqual(len(history), 12)
            self.assertEqual(history[-1], 'bewie-track-03')
            publish()
            self.assertEqual(len(json.loads((root / 'calls.json').read_text())), 12)
            # Identical packs recorded for a different app must never suppress
            # uploads required by a new App Store record.
            wrong_app = json.loads(record.read_text())
            wrong_app['appleAppID'] = '0987654321'
            record.write_text(json.dumps(wrong_app))
            publish()
            self.assertEqual(len(json.loads((root / 'calls.json').read_text())), 21)
            self.assertEqual(json.loads(record.read_text())['appleAppID'], '1234567890')


    def test_all_album_packs_are_essential_on_ios_tvos_and_macos(self):
        root = Path(__file__).resolve().parent.parent
        manifests = sorted((root / 'Configuration/AssetPacks').glob('track-*.json'))
        self.assertEqual(len(manifests), 9)
        for index, path in enumerate(manifests, 1):
            manifest = json.loads(path.read_text())
            self.assertEqual(manifest['assetPackID'], f'bewie-track-{index:02}')
            self.assertEqual(set(manifest['platforms']), {'iOS', 'tvOS', 'macOS'})
            self.assertEqual(set(manifest['downloadPolicy']['essential']['installationEventTypes']),
                             {'firstInstallation', 'subsequentUpdate'})


if __name__ == '__main__':
    unittest.main()
