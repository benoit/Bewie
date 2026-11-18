# Bewie preparation — 18 November 2026

## Source boundary

Copied the Apple music projects, album/player/map sources, public localizations,
lyrics, album artwork, fonts and licenses, lossless masters encodes, Watch AAC,
Messages videos and metadata, pack configurations, relevant tests and development
scripts from Perle. Excluded build output, private travel packs, guide/push source,
notification extension, historical release notes, old store metadata, publication
ledgers, old screenshots, design PDFs and credentials.

Renamed project folders, targets, schemes, app types, shared symbols, local
namespaces, bundle identifiers, App Group, link scheme and pack identifiers.
External support/music URLs and author credits retain their original destinations.
All platforms start at 1.0 (1). Store record ID is unset. No Perle user credentials,
keychain entries, containers, guide cache or installation identity are migrated.

AlbumMapView now contains only album navigation and player sheets. BewieApp keeps
the existing opening sleeve, map readiness, foreground music/video preparation
and song links. There is no guide download or enrollment on app startup.

## Validation

Local unsigned compilation does
not verify Apple Developer registration, physical-device delivery or provisioning.

- iOS Simulator: Debug build passed, including Messages, downloader and embedded Watch.
- Catalyst: Debug build passed for the Mac music app and downloader.
- tvOS Simulator: Debug build passed for the TV music app and downloader.
- iOS XCTest: 104 tests passed, zero failures, including Bewie identity, song links,
  playback, downloads, lyrics, localization, opening sleeve and map geometry.
- Asset publisher fixture suite: 2 tests passed; no network or Apple credentials used.
- Missing-store-ID upload guard rejected publication before credential loading.
- All 9 lossless audio packs and all 9 Messages video packs packaged locally.
- All 9 source video checksums, sizes and 2160 × 2160 metadata verified.
- All 18 copied lossless/Watch audio files match Perle SHA-256 values. See
  AudioCopyVerification.json for the retained fingerprints.
- Embedded Watch bundle: 64,711,454 bytes with exactly 9 AAC tracks; below the
  verifier's 70,000,000-byte budget and Apple's 75 MB limit.
- Configuration plists, entitlements and all three Xcode project graphs parse.

Build logs and the XCTest result bundle are retained under the workspace's
ignored local build output. Mac/TV runtime UI, physical-device playback, signed
archives and App Store asset delivery were not validated in this preparation.
