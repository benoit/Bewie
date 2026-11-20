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

The iOS, Mac and Watch icon now uses the album photograph with its title and logo removed.
Messages and Apple TV use matching album artwork. Light/dark preserve its source
colors; clear and tinted variants use Apple's native rendering.
See [Design/AppIcon.md](Design/AppIcon.md).

## TestFlight distribution

Bewie has its own App Store Connect record (`6836332427`), registered bundle IDs
and assigned music App Group. Version **1.0 (3)** is available in the **Owner**
internal TestFlight group for iOS/iPadOS (including Watch and Messages), Mac
Catalyst and Apple TV. The group contains only Benoit; public links are disabled.
All nine lossless music packs and nine Messages video packs are published under
Bewie's record and ready for internal testing. English and French What to Test
notes are saved for every platform. See [the release record](Documentation/Release-1.0-3.md).

When a public store listing is available, set `BewieAppStoreURL` in
`Configuration/Messages-Info.plist` to its HTTPS App Store URL to enable the
Messages app-link row. Song/video sharing works independently.

See [Documentation/Preparation.md](Documentation/Preparation.md) for verification.

## Repositories and support

App source: https://github.com/benoit/Bewie

Privacy/support source: https://github.com/benoit/bewieappsite

Website: https://bewie.atelierindustriel.be · contact: bewie.app@cazenave.fr

Support: https://bewie.atelierindustriel.be/support

Privacy: https://bewie.atelierindustriel.be/privacy

The website provides ten language variants independently of the app localizations.

The first device archives are version 1.0 (1). Use
`tools/verify-release-archive.py` before signing/uploading to verify the exact
platform bundle set, build versions, exempt encryption and Watch size. The iOS
archive must embed Messages, Watch and the background downloader. Distribution
uses Bewie’s own App Store record and assigned music App Group.
