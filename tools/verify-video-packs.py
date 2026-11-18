#!/usr/bin/env python3
"""Verify the nine first-install video packs locally and in App Store Connect."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import subprocess
import tempfile
import time
from appstore_connect import APIError, Client

ROOT = Path(__file__).resolve().parent.parent


def check(client, submit):
    app = json.loads((ROOT/'Configuration/AppStore.json').read_text())['appleAppID']
    ledger = json.loads((ROOT/'MusicAssets/PublishedVideoPacks.json').read_text())
    assert ledger['appleAppID'] == app
    assets = client.request('GET', f'/v1/apps/{app}/backgroundAssets?include=internalBetaVersion,externalBetaVersion&limit=100')['data']
    rows = []
    for number in range(1, 10):
        identifier = f'bewie-video-{number:02}'
        record = next(x for x in ledger['packs'] if x['track'] == number)
        configured = json.loads((ROOT/f'Configuration/VideoAssetPacks/track-{number:02}.json').read_text())
        assert configured['assetPackID'] == identifier
        assert configured['downloadPolicy'] == {'essential': {'installationEventTypes': ['firstInstallation']}}
        assert configured['platforms'] == ['iOS']
        assert hashlib.sha256(json.dumps(configured, sort_keys=True, separators=(',', ':')).encode()).hexdigest() == record['manifestSHA256']
        with tempfile.TemporaryDirectory(prefix='video-pack-', dir=ROOT/'build/VideoAssetPacks') as temp:
            subprocess.run(['xcrun', 'aa', 'extract', '-i', str(ROOT/f'build/VideoAssetPacks/track-{number:02}.aar'), '-d', temp], check=True, capture_output=True)
            actual = json.loads((Path(temp)/'Manifest.json').read_text())
            assert actual['downloadPolicy'] == configured['downloadPolicy']
            video = Path(temp)/f'Contents/MessagesVideos/track-{number:02}.mp4'
            metadata = json.loads((Path(temp)/f'Contents/MessagesVideos/track-{number:02}.json').read_text())
            digest = hashlib.sha256(video.read_bytes()).hexdigest()
            assert digest == record['videoSHA256'] == metadata['sha256']
            assert metadata['trackID'] == number and metadata['bytes'] == video.stat().st_size
        asset = next((x for x in assets if x['attributes']['assetPackIdentifier'] == identifier), None)
        if not asset:
            rows.append({'pack': identifier, 'processing': 'NOT_VISIBLE'})
            continue
        response = client.request('GET', f'/v1/backgroundAssets/{asset["id"]}/versions?include=internalBetaRelease,externalBetaRelease&limit=20')
        version = next(x for x in response['data'] if x['attributes']['version'] == record['appleVersion'])
        def release_state(key):
            relationship = version['relationships'][key].get('data')
            return next((x['attributes']['state'] for x in response.get('included', []) if relationship and x['id'] == relationship['id']), None)
        external = release_state('externalBetaRelease')
        deferred = None
        if submit and version['attributes']['state'] == 'COMPLETE' and external == 'READY_FOR_BETA_SUBMISSION':
            try:
                client.request('POST', '/v1/betaBackgroundAssetReviewSubmissions', {'data': {'type': 'betaBackgroundAssetReviewSubmissions', 'relationships': {'backgroundAssetVersion': {'data': {'type': 'backgroundAssetVersions', 'id': version['id']}}}}})
            except APIError as error:
                if error.status == 409 and any(x.get('code') == 'STATE_ERROR.NO_COMPATIBLE_BUILD' for x in error.errors):
                    deferred = 'requires_compatible_external_build'
                elif error.status != 409 or not any('EXISTS' in x.get('code', '') or 'ALREADY' in x.get('code', '') for x in error.errors):
                    raise
            response = client.request('GET', f'/v1/backgroundAssets/{asset["id"]}/versions?include=internalBetaRelease,externalBetaRelease&limit=20')
            external = release_state('externalBetaRelease')
        selected = lambda key: (asset['relationships'][key].get('data') or {}).get('id') == version['id']
        rows.append({'pack': identifier, 'version': record['appleVersion'], 'processing': version['attributes']['state'],
                     'internal': release_state('internalBetaRelease'), 'internalSelected': selected('internalBetaVersion'),
                     'external': external, 'externalSelected': selected('externalBetaVersion'),
                     'policy': 'essential', 'installationEvents': ['firstInstallation'], 'localContentsVerified': True,
                     'externalReviewDeferred': deferred})
    result = {'appID': app, 'verifiedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'packs': rows,
              'allNineInternalReady': len(rows) == 9 and all(x.get('processing') == 'COMPLETE' and x.get('internal') == 'READY_FOR_TESTING' and x.get('internalSelected') for x in rows)}
    (ROOT/'build/video-pack-delivery-verification.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result), flush=True)
    return result['allNineInternalReady']


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--submit-beta-review', action='store_true')
    parser.add_argument('--wait', action='store_true')
    args = parser.parse_args()
    client = Client()
    while True:
        if check(client, args.submit_beta_review) or not args.wait:
            break
        time.sleep(45)
