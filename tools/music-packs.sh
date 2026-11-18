#!/usr/bin/env bash
# Apple-hosted asset packs are versioned independently from app builds.
set -euo pipefail
cd "$(dirname "$0")/.."
ACTION="${1:-package}"
APPLE_APP_ID=$(python3 -c 'import json; v=json.load(open("Configuration/AppStore.json"))["appleAppID"]; print(v or "")')
if [[ "$ACTION" == upload && ! "$APPLE_APP_ID" =~ ^[0-9]+$ ]]; then
  echo "Set Bewie appleAppID in Configuration/AppStore.json before uploading." >&2
  exit 1
fi
export BEWIE_ASSET_APP_ID="$APPLE_APP_ID"
mkdir -p build/AssetPacks
package_one() {
  local number="$1"
  rm -f "build/AssetPacks/track-${number}.aar"
  xcrun ba-package "Configuration/AssetPacks/track-${number}.json" \
    -o "build/AssetPacks/track-${number}.aar" > "build/AssetPacks/package-${number}.log" 2>&1
}
if [[ "$ACTION" == package ]]; then
  for NUMBER in 01 02 03 04 05 06 07 08 09; do
    package_one "$NUMBER"
  done
elif [[ "$ACTION" == upload ]]; then
  source "${ASC_ENV_FILE:-$HOME/.private_keys/appstoreconnect.env}"
  export API_PRIVATE_KEYS_DIR
  API_PRIVATE_KEYS_DIR="$(dirname "$ASC_KEY_PATH")"
  for NUMBER in 01 02 03 04 05 06 07 08 09; do
    if python3 - "$NUMBER" <<'CHECK'
import hashlib, json, os, sys
from pathlib import Path
record = Path('MusicAssets/PublishedPacks.json')
number = int(sys.argv[1])
checksum = hashlib.sha256(Path(f'MusicAssets/Audio/track-{number:02}.m4a').read_bytes()).hexdigest()
published = json.loads(record.read_text()) if record.exists() else {}
records = published.get('packs', []) if published.get('appleAppID') == os.environ['BEWIE_ASSET_APP_ID'] else []
manifest = json.loads(Path(f'Configuration/AssetPacks/track-{number:02}.json').read_text())
manifest_checksum = hashlib.sha256(json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
sys.exit(0 if any(p['track'] == number and p['encodedSHA256'] == checksum and p.get('manifestSHA256') == manifest_checksum for p in records) else 1)
CHECK
    then
      echo "Pack ${NUMBER} is unchanged; keeping its published Apple version."
      continue
    fi
    # Rebuild changed packs here so upload cannot reuse a stale archive with
    # an old policy, even when the lossless audio bytes have not changed.
    package_one "$NUMBER"
    xcrun altool --upload-asset-pack "build/AssetPacks/track-${NUMBER}.aar" \
      --apple-id "$APPLE_APP_ID" --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" \
      --output-format json > "build/AssetPacks/upload-${NUMBER}.json" 2>&1
    python3 - "$NUMBER" <<'RECORD'
import hashlib, json, os, sys
from pathlib import Path
number = int(sys.argv[1])
record = Path('MusicAssets/PublishedPacks.json')
published = json.loads(record.read_text()) if record.exists() else {}
records = published.get('packs', []) if published.get('appleAppID') == os.environ['BEWIE_ASSET_APP_ID'] else []
raw = Path(f'build/AssetPacks/upload-{number:02}.json').read_text()
result = json.loads(raw[raw.index('{'):])
checksum = hashlib.sha256(Path(f'MusicAssets/Audio/track-{number:02}.m4a').read_bytes()).hexdigest()
records = [p for p in records if p['track'] != number]
manifest = json.loads(Path(f'Configuration/AssetPacks/track-{number:02}.json').read_text())
manifest_checksum = hashlib.sha256(json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
expected_id = f'bewie-track-{number:02}'
if result.get('asset-pack-identifier') != expected_id or not result.get('asset-pack-version'):
    raise SystemExit('Asset upload response does not match the expected pack')
records.append(dict(track=number,assetPackID=expected_id,appleVersion=result['asset-pack-version'],encodedSHA256=checksum,manifestSHA256=manifest_checksum))
record.write_text(json.dumps(dict(schemaVersion=3,appleAppID=os.environ['BEWIE_ASSET_APP_ID'],packs=sorted(records,key=lambda p:p['track'])),indent=2)+'\n')
RECORD
    echo "Uploaded music pack ${NUMBER}."
  done
else
  echo 'Usage: tools/music-packs.sh package|upload' >&2
  exit 2
fi
