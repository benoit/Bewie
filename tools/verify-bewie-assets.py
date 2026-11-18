#!/usr/bin/env python3
"""Check every published Bewie music/video pack and its internal TestFlight selection."""
from pathlib import Path
import json
import hashlib
import datetime
from appstore_connect import Client

ROOT = Path(__file__).resolve().parents[1]
app = json.loads((ROOT/'Configuration/AppStore.json').read_text())['appleAppID']
assert app
client = Client()
assets = client.request('GET', f'/v1/apps/{app}/backgroundAssets?include=internalBetaVersion&limit=100')['data']
rows = []
for kind, ledgerName, configuration in [('music','PublishedPacks.json','AssetPacks'), ('video','PublishedVideoPacks.json','VideoAssetPacks')]:
    ledger = json.loads((ROOT/'MusicAssets'/ledgerName).read_text())
    assert ledger['appleAppID'] == app
    assert sorted(p['track'] for p in ledger['packs']) == list(range(1,10))
    for record in ledger['packs']:
        number = record['track'];identifier = record['assetPackID']
        manifest = json.loads((ROOT/f'Configuration/{configuration}/track-{number:02}.json').read_text())
        assert manifest['assetPackID'] == identifier
        digest = hashlib.sha256(json.dumps(manifest, sort_keys=True, separators=(',',':')).encode()).hexdigest()
        assert record['manifestSHA256'] == digest
        if kind == 'music':
            assert hashlib.sha256((ROOT/f'MusicAssets/Audio/track-{number:02}.m4a').read_bytes()).hexdigest() == record['encodedSHA256']
        else:
            assert hashlib.sha256((ROOT/f'MusicAssets/Messages/track-{number:02}.mp4').read_bytes()).hexdigest() == record['videoSHA256']
        asset = next(a for a in assets if a['attributes']['assetPackIdentifier'] == identifier)
        response = client.request('GET', f"/v1/backgroundAssets/{asset['id']}/versions?include=internalBetaRelease&limit=100")
        version = next(v for v in response['data'] if v['attributes']['version'] == record['appleVersion'])
        release = version['relationships']['internalBetaRelease'].get('data')
        state = next((v['attributes']['state'] for v in response.get('included',[]) if release and v['id'] == release['id']), None)
        selected = asset['relationships']['internalBetaVersion'].get('data')
        expected = {'IOS','MAC_OS','TV_OS'} if kind == 'music' else {'IOS'}
        assert set(version['attributes']['platforms']) == expected
        ready = version['attributes']['state'] == 'COMPLETE' and state == 'READY_FOR_TESTING' and selected and selected['id'] == version['id']
        rows.append({'pack':identifier, 'version':record['appleVersion'], 'platforms':sorted(expected),
                     'processing':version['attributes']['state'], 'internalState':state,
                     'selectedForInternalTesting':bool(ready),'sourceHashesVerified':True})
result = {'appID':app,'verifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'ready':len(rows)==18 and all(row['selectedForInternalTesting'] for row in rows),'packs':rows}
(ROOT/'build/hosted-assets-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'packs':len(rows),'ready':sum(row['selectedForInternalTesting'] for row in rows),'allInternalReady':result['ready']}))
