# Bewie 1.0 (2) — 20 November 2026

Trial release using the original album sleeve as the app icon. The native icon
is shared by iPhone/iPad, Mac Catalyst and Watch; Messages and Apple TV use
matching rectangular assets. Default and dark retain the original photograph’s
colors. Clear and tinted appearances use native Icon Composer rendering.
The previous logo icon is retained at `Design/Icons/Logo.icon` for rollback.

All three archives compiled successfully and passed bundle/version/encryption
validation. The iOS archive embeds Watch, Messages and the background downloader.
The Watch bundle retains all nine offline AAC tracks and remains below 70 MB.
All three distribution bundles passed deep, strict signature verification with
Apple Distribution certificates and the Bewie music App Group.

All uploads reported export success, upload success and package processing.
The original keychain search order was restored after export. Existing hosted
music and video packs were not republished; all 18 versions passed API state,
internal selection and local source/manifest hash verification.

All three builds are `VALID` and `IN_BETA_TESTING`, assigned exclusively to the
Owner internal group with its single tester, Benoit. The new builds are not
assigned to any external group. No external beta review or public App Store
submission was made. Verified at 2026-11-20T07:15:03.562385+00:00.
English and French What to Test notes describe the album-icon trial and playback
regression checks. Physical-device appearance and playback testing is left to
the owner; no new on-device test is claimed by this release.

Local archives and private logs: external SSD `Bewie-Releases/2026-11-20`.
Compiled icon metadata is summarized in `Documentation/IconVerification.json`.
