#!/usr/bin/env bash
# The nine video packs are independent of the nine lossless music packs.
set -euo pipefail
cd "$(dirname "$0")/.."
ACTION="${1:-package}"
APPLE_APP_ID=$(python3 -c 'import json; v=json.load(open("Configuration/AppStore.json"))["appleAppID"]; print(v or "")')
if [[ "$ACTION" == upload && ! "$APPLE_APP_ID" =~ ^[0-9]+$ ]]; then
  echo "Set Bewie appleAppID in Configuration/AppStore.json before uploading." >&2
  exit 1
fi
export BEWIE_ASSET_APP_ID="$APPLE_APP_ID"
mkdir -p build/VideoAssetPacks
python3 tools/check-messages-manifest.py MusicAssets/Messages
package_one() {
  local number="$1"
  local archive="build/VideoAssetPacks/track-${number}.aar"
  if [[ -f "$archive" ]]; then python3 -c 'from pathlib import Path; import sys; Path(sys.argv[1]).unlink()' "$archive"; fi
  xcrun ba-package "Configuration/VideoAssetPacks/track-${number}.json" \
    -o "$archive" > "build/VideoAssetPacks/package-${number}.log" 2>&1
}
if [[ "$ACTION" == package ]]; then
  for NUMBER in 01 02 03 04 05 06 07 08 09; do
    package_one "$NUMBER"
    echo "Packaged video ${NUMBER}."
  done
elif [[ "$ACTION" == upload ]]; then
  source "${ASC_ENV_FILE:-$HOME/.private_keys/appstoreconnect.env}"
  export API_PRIVATE_KEYS_DIR
  API_PRIVATE_KEYS_DIR="$(dirname "$ASC_KEY_PATH")"
  for NUMBER in 01 02 03 04 05 06 07 08 09; do
    if python3 - "$NUMBER" <<'CHECK'
import hashlib,json,os,sys
from pathlib import Path
n=int(sys.argv[1]);ledger=Path('MusicAssets/PublishedVideoPacks.json')
published=json.loads(ledger.read_text()) if ledger.exists() else {}
records=published.get('packs',[]) if published.get('appleAppID')==os.environ['BEWIE_ASSET_APP_ID'] else []
config=json.loads(Path(f'Configuration/VideoAssetPacks/track-{n:02}.json').read_text())
manifest_hash=hashlib.sha256(json.dumps(config,sort_keys=True,separators=(',',':')).encode()).hexdigest()
video_hash=hashlib.sha256(Path(f'MusicAssets/Messages/track-{n:02}.mp4').read_bytes()).hexdigest()
metadata_hash=hashlib.sha256(Path(f'MusicAssets/MessageVideoMetadata/track-{n:02}.json').read_bytes()).hexdigest()
sys.exit(0 if any(p['track']==n and p['videoSHA256']==video_hash and p['metadataSHA256']==metadata_hash and p['manifestSHA256']==manifest_hash for p in records) else 1)
CHECK
    then
      echo "Video pack ${NUMBER} unchanged; keeping the existing Apple version."
      continue
    fi
    package_one "$NUMBER"
    xcrun altool --upload-asset-pack "build/VideoAssetPacks/track-${NUMBER}.aar" \
      --apple-id "$APPLE_APP_ID" --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" \
      --output-format json > "build/VideoAssetPacks/upload-${NUMBER}.json" 2>&1
    python3 - "$NUMBER" <<'RECORD'
import hashlib,json,os,sys
from pathlib import Path
n=int(sys.argv[1]);ledger=Path('MusicAssets/PublishedVideoPacks.json')
published=json.loads(ledger.read_text()) if ledger.exists() else {}
records=published.get('packs',[]) if published.get('appleAppID')==os.environ['BEWIE_ASSET_APP_ID'] else []
raw=Path(f'build/VideoAssetPacks/upload-{n:02}.json').read_text()
result=json.loads(raw[raw.index('{'):])
if result.get('asset-pack-identifier')!=f'bewie-video-{n:02}' or not result.get('asset-pack-version'):
    raise SystemExit('Video upload response has an unexpected asset ID or version')
config=json.loads(Path(f'Configuration/VideoAssetPacks/track-{n:02}.json').read_text())
entry=dict(track=n,assetPackID=f'bewie-video-{n:02}',appleVersion=result['asset-pack-version'],
           videoSHA256=hashlib.sha256(Path(f'MusicAssets/Messages/track-{n:02}.mp4').read_bytes()).hexdigest(),
           metadataSHA256=hashlib.sha256(Path(f'MusicAssets/MessageVideoMetadata/track-{n:02}.json').read_bytes()).hexdigest(),
           manifestSHA256=hashlib.sha256(json.dumps(config,sort_keys=True,separators=(',',':')).encode()).hexdigest())
records=[p for p in records if p['track']!=n]+[entry]
ledger.write_text(json.dumps(dict(schemaVersion=1,appleAppID=os.environ['BEWIE_ASSET_APP_ID'],packs=sorted(records,key=lambda p:p['track'])),indent=2)+'\n')
RECORD
    echo "Uploaded video pack ${NUMBER}."
  done
else
  echo 'Usage: tools/video-packs.sh package|upload' >&2
  exit 2
fi
