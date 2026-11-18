#!/usr/bin/env python3
"""Verify published essential music on TV and optionally queue pack beta review."""
from pathlib import Path
import argparse,datetime,hashlib,json,subprocess,tempfile,time
ROOT=Path(__file__).resolve().parent.parent
from appstore_connect import Client, APIError
APP=json.loads((ROOT/'Configuration/AppStore.json').read_text())['appleAppID']
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--submit-beta-review',action='store_true');parser.add_argument('--wait',action='store_true');args=parser.parse_args()
 masters={x['track']:x for x in json.loads((ROOT/'MusicAssets/masters-manifest.json').read_text())['tracks']}
 client=Client()
 while True:
  if check(client,args):return
  if not args.wait:return
  time.sleep(60)

def check(client,args):
 masters={x['track']:x for x in json.loads((ROOT/'MusicAssets/masters-manifest.json').read_text())['tracks']}
 published=json.loads((ROOT/'MusicAssets/PublishedPacks.json').read_text())
 assets=client.request('GET',f'/v1/apps/{APP}/backgroundAssets?include=internalBetaVersion,externalBetaVersion&limit=100')['data']
 rows=[]
 for number in range(1,10):
  identifier=f'bewie-track-{number:02}'
  manifest=json.loads((ROOT/f'Configuration/AssetPacks/track-{number:02}.json').read_text())
  digest=hashlib.sha256(json.dumps(manifest,sort_keys=True,separators=(',',':')).encode()).hexdigest()
  record=next(x for x in published['packs'] if x['track']==number)
  assert record['encodedSHA256']==masters[number]['encodedSHA256']
  assert hashlib.sha256((ROOT/f'MusicAssets/Audio/track-{number:02}.m4a').read_bytes()).hexdigest()==record['encodedSHA256']
  assert record['manifestSHA256']==digest, f'{identifier}: updated manifest not yet published'
  assert {'iOS','tvOS'}.issubset(manifest['platforms'])
  assert set(manifest['downloadPolicy']['essential']['installationEventTypes'])=={'firstInstallation','subsequentUpdate'}
  archive=ROOT/f'build/AssetPacks/track-{number:02}.aar'
  with tempfile.TemporaryDirectory(prefix='bewie-pack-manifest-') as tmp:
   subprocess.run(['xcrun','aa','extract','-i',str(archive),'-d',tmp,'-include-path','Manifest.json'],check=True,capture_output=True)
   actual=json.loads((Path(tmp)/'Manifest.json').read_text())
   assert set(actual['platforms'])==set(manifest['platforms'])
   assert actual['downloadPolicy']==manifest['downloadPolicy']
  asset=next(x for x in assets if x['attributes']['assetPackIdentifier']==identifier)
  response=client.request('GET',f"/v1/backgroundAssets/{asset['id']}/versions?include=internalBetaRelease,externalBetaRelease&limit=20")
  version=next(x for x in response['data'] if x['attributes']['version']==record['appleVersion'])
  getstate=lambda key:next((x['attributes']['state'] for x in response.get('included',[]) if x['id']==version['relationships'][key]['data']['id']),None)
  assert set(version['attributes']['platforms'])=={ {'iOS':'IOS','tvOS':'TV_OS','macOS':'MAC_OS','visionOS':'VISION_OS'}[p] for p in manifest['platforms'] }
  assert version['attributes']['state']=='COMPLETE'
  assert getstate('internalBetaRelease')=='READY_FOR_TESTING'
  assert asset['relationships']['internalBetaVersion']['data']['id']==version['id']
  external=getstate('externalBetaRelease');deferred=None
  if args.submit_beta_review and external=='READY_FOR_BETA_SUBMISSION':
   try:client.request('POST','/v1/betaBackgroundAssetReviewSubmissions',{'data':{'type':'betaBackgroundAssetReviewSubmissions','relationships':{'backgroundAssetVersion':{'data':{'type':'backgroundAssetVersions','id':version['id']}}}}})
   except APIError as error:
    codes=[x.get('code','') for x in error.errors]
    if error.status==409 and 'STATE_ERROR.NO_COMPATIBLE_BUILD' in codes:deferred='waiting_for_compatible_external_build'
    elif error.status==409 and any('EXISTS' in code or 'ALREADY' in code for code in codes):pass
    else:raise
   response=client.request('GET',f"/v1/backgroundAssets/{asset['id']}/versions?include=internalBetaRelease,externalBetaRelease&limit=20")
   external=getstate('externalBetaRelease')
  rows.append({'pack':identifier,'version':record['appleVersion'],'platforms':version['attributes']['platforms'],'processing':'COMPLETE','internal':'READY_FOR_TESTING','internalSelected':True,'policy':'essential','installationEvents':manifest['downloadPolicy']['essential']['installationEventTypes'],'external':external,'externalSelected':asset['relationships']['externalBetaVersion'].get('data',{}).get('id')==version['id'] if asset['relationships']['externalBetaVersion'].get('data') else False,'externalReviewDeferred':deferred,'archiveManifestVerified':True,'losslessAudioUnchanged':True})
  print(json.dumps(rows[-1]),flush=True)
 result={'appID':APP,'verifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'allNineReadyOnTV':len(rows)==9,'allNineExternalReadyOnTV':len(rows)==9 and all(x['external']=='READY_FOR_TESTING' and x['externalSelected'] for x in rows),'packs':rows}
 path=ROOT/'build/tvos-music-delivery-verification.json';temp=path.with_suffix('.json.tmp');temp.write_text(json.dumps(result,indent=2)+'\n');temp.replace(path)
 return result['allNineExternalReadyOnTV']
if __name__=='__main__':main()
