# Bewie 1.0 (1) — 18 November 2026

All three platform builds completed App Store Connect processing (`VALID`) and
are `IN_BETA_TESTING` in the Owner internal group: iOS/iPadOS, Mac Catalyst and tvOS.
The only tester is Benoit. Public links are disabled; no external beta or public
App Store review was submitted.

The iOS archive includes the background downloader, Messages extension and
Watch app. The Watch bundle contains all nine AAC tracks and occupies
63,439,329 uncompressed bytes, below the 75 MB limit. The Messages embed phase
was restored during archive verification. Apple TV now uses the original-color
Bewie logo on layered chalk artwork.

All nine Apple-hosted lossless music packs support iOS, Mac and TV. All nine
Messages video packs support iOS. All 18 versions are complete, selected for
internal testing and ready for testing. Local audio/video hashes and manifest
hashes match their publication ledgers.

Validation: all three archives compiled successfully; exact bundle sets,
versions and encryption declarations passed verification. All three uploads
reported export success, upload success and package processing. Their staged
distribution bundles passed deep, strict code-signature verification with Apple
Distribution certificates and the Bewie music App Group. App Store Connect
reports exempt encryption and verified English/French What to Test notes for
every build. Device playback testing remains the next manual validation.

Local private release outputs are on the external SSD under
`Bewie-Releases/2026-11-18`; credentials and binaries are excluded from Git.
The user's original keychain search order was restored after export.

Release helpers: `release-bewie.py` signs/uploads a verified archive;
`verify-bewie-assets.py` checks all 18 hosted packs;
`finish-bewie-release.py` saves notes and assigns processed builds to the existing
single-owner group. Run the asset verifier before the finalizer. The helpers use
credentials outside the checkout and never create external tester groups.
