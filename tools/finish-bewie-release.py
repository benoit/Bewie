#!/usr/bin/env python3
"""Finish first Bewie TestFlight releases for the single explicitly authorized owner."""
from pathlib import Path
import argparse
import datetime
import json
from appstore_connect import Client

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--build', default='1')
args = parser.parse_args()
client = Client()
app = json.loads((ROOT/'Configuration/AppStore.json').read_text())['appleAppID']
groups = client.request('GET',f'/v1/apps/{app}/betaGroups?limit=100')['data']
assert len(groups)==1 and groups[0]['attributes']['name']=='Owner' and groups[0]['attributes']['isInternalGroup']
group = groups[0]
assert not group['attributes'].get('publicLinkEnabled')
members = client.request('GET',f"/v1/betaGroups/{group['id']}/betaTesters?limit=100")['data']
assert len(members)==1 and members[0]['attributes']['email'].lower()=='benoit@cazenave.fr'
response = client.request('GET',f'/v1/builds?filter[app]={app}&filter[version]={args.build}&include=preReleaseVersion&limit=100')
versions = {v['id']:v['attributes'] for v in response.get('included',[]) if v['type']=='preReleaseVersions'}
rows = []
for platform,label in [('IOS','iOS'),('MAC_OS','Mac'),('TV_OS','TV')]:
    matches = [b for b in response['data'] if versions[b['relationships']['preReleaseVersion']['data']['id']]['platform']==platform]
    assert len(matches)<=1
    if not matches:
        rows.append({'platform':platform,'processing':'AWAITING_BUILD'});continue
    build = matches[0];bid = build['id'];processing = build['attributes']['processingState']
    row = {'platform':platform,'buildID':bid,'build':args.build,'processing':processing}
    assert processing not in ['INVALID','FAILED'],row
    if processing=='VALID':
        if build['attributes'].get('usesNonExemptEncryption') is not False:
            client.request('PATCH',f'/v1/builds/{bid}',{'data':{'type':'builds','id':bid,'attributes':{'usesNonExemptEncryption':False}}})
        localizations = client.request('GET',f'/v1/builds/{bid}/betaBuildLocalizations?limit=100')['data']
        expected = {}
        for locale,suffix in [('en-US','en'),('fr-FR','fr')]:
            notes = (ROOT/f'Configuration/ReleaseNotes/{label}-{suffix}.txt').read_text().strip();expected[locale]=notes
            current = next((l for l in localizations if l['attributes']['locale']==locale),None)
            if current:
                if current['attributes'].get('whatsNew')!=notes:
                    client.request('PATCH',f"/v1/betaBuildLocalizations/{current['id']}",{'data':{'type':'betaBuildLocalizations','id':current['id'],'attributes':{'whatsNew':notes}}})
            else:
                client.request('POST','/v1/betaBuildLocalizations',{'data':{'type':'betaBuildLocalizations','attributes':{'locale':locale,'whatsNew':notes},'relationships':{'build':{'data':{'type':'builds','id':bid}}}}})
        readback = client.request('GET',f'/v1/builds/{bid}/betaBuildLocalizations?limit=100')['data']
        assert all(any(l['attributes']['locale']==locale and l['attributes'].get('whatsNew')==text for l in readback) for locale,text in expected.items())
        builds = client.request('GET',f"/v1/betaGroups/{group['id']}/builds?limit=200")['data']
        if not any(b['id']==bid for b in builds):
            client.request('POST',f"/v1/betaGroups/{group['id']}/relationships/builds",{'data':[{'type':'builds','id':bid}]})
        builds = client.request('GET',f"/v1/betaGroups/{group['id']}/builds?limit=200")['data']
        assert any(b['id']==bid for b in builds)
        detail = client.request('GET',f'/v1/builds/{bid}/buildBetaDetail')['data']['attributes']
        row.update(internalState=detail['internalBuildState'],ownerGroupAssigned=True,whatToTestVerified=True,usesNonExemptEncryption=False)
    rows.append(row)
assetsPath = ROOT/'build/hosted-assets-verification.json'
assetsReady = assetsPath.exists() and json.loads(assetsPath.read_text()).get('ready',False)
complete = assetsReady and len(rows)==3 and all(r.get('internalState')=='IN_BETA_TESTING' and r.get('ownerGroupAssigned') and r.get('whatToTestVerified') for r in rows)
result = {'appID':app,'version':'1.0','build':args.build,'ownerOnly':True,'testerCount':1,'allHostedAssetsReady':assetsReady,'complete':complete,'platforms':rows,'verifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(ROOT/'build/bewie-release-status.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
