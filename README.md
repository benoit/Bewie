# Bewie

The album app for **Every Room Is Borrowed** by Bewie: nine songs, their places,
synchronized lyrics, album artwork, playback and music-service links.

Prepared from `/Users/bolos/Apps/Perle` on 18 November 2026, following
[Plan Perle and Bewie split](codex://threads/01a1edb8-3580-7262-ba42-0a1b75ca8406?hostId=remote-control%3Aenv_e_6ac56c4ccb8c8332b78de5e197fafabb).
The Perle source project is unchanged.

Open **Bewie.xcodeproj** for iPhone/iPad, Apple Watch and Messages. The separate
**BewieMac.xcodeproj** and **BewieTV.xcodeproj** contain the Catalyst and Apple TV
music apps. Version 1.0 starts at build 1 for this new app.

| Component | Identifier |
| --- | --- |
| Main app (iOS, Mac, TV) | `bewie.atelierindustriel.be` |
| Background music downloader | `bewie.atelierindustriel.be.musicdownloader` |
| Watch | `bewie.atelierindustriel.be.watchkitapp` |
| Messages | `bewie.atelierindustriel.be.messages` |
| Music App Group | `group.bewie.atelierindustriel.be.music` |
| Song links | `bewie://1` through `bewie://9` |
| Audio packs | `bewie-track-01` through `bewie-track-09` |
| Messages video packs | `bewie-video-01` through `bewie-video-09` |

## Local development

```sh
xcodebuild -project Bewie.xcodeproj -scheme Bewie \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
bash tools/music-packs.sh package
bash tools/video-packs.sh package
python3 tools/check-messages-manifest.py MusicAssets/Messages
python3 tools/test-music-packs.py
```

Shared schemes resolve locally packaged audio from `build/AssetPacks`. Package
before testing actual playback. Watch audio is bundled separately. The copied
lossless audio, Watch AAC, videos, lyrics, font and artwork are local files;
no symlink to Perle is required. Regeneration tools retain the music master
provenance, and the existing support address and music-service URLs remain valid.

## Split status

Bewie contains the album experience. Guide screens, place data, Florence routes,
enrollment, Wi-Fi access, push services and their tests remain in Perle.
Bewie does not register the `perle://` scheme or access Perle's shared containers.

The planned private pearl is **not enabled yet**. Its artwork is retained, but
visibility needs an owner identity/recovery contract for Benoit and Lætitia.
It must open Perle, be independent of guide downloads and ordinary invitations,
and never grant access just because a device is near a configured network.
The reusable proximity invitation system and guide contributions belong to
subsequent work; they are not implemented in this preparation.

The iOS, Mac and Watch app icon preserves the original Bewie logo colors and
texture on chalk in light and dark mode, with native clear/tinted variants. Messages has all
12 matching flat icon sizes. Apple TV still uses the inherited pearl artwork.
The album launch artwork remains unchanged. See [Design/AppIcon.md](Design/AppIcon.md).

## Before distribution

Register the new bundle IDs and music App Group with the existing signing team,
and create Bewie's own App Store record. Enter that record's numeric ID in
`Configuration/AppStore.json`; its value is deliberately empty here. Publication
ledgers start empty, and upload helpers reject an unconfigured destination.
Publish Bewie's newly named audio/video packs to its own record before device
playback testing. Nothing has been registered, uploaded or released by this task.

Once the store record exists, set `BewieAppStoreURL` in
`Configuration/Messages-Info.plist` to its HTTPS App Store URL to enable the
Messages app-link row. It stays hidden while no destination exists. Song/video
sharing remains separate. Do not reuse Perle's store URL or publication versions.

See [Documentation/Preparation.md](Documentation/Preparation.md) for verification.

## Repositories and support

App source: https://github.com/benoit/Bewie

Privacy/support source: https://github.com/benoit/bewieappsite

Website: https://bewie.atelierindustriel.be · contact: bewie.app@cazenave.fr

Support: https://bewie.atelierindustriel.be/support

Privacy: https://bewie.atelierindustriel.be/privacy

The website provides ten language variants independently of the app localizations.
