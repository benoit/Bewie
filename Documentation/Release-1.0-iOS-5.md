# Bewie iOS 1.0 (5) — 21 November 2026

The private pearl now matches Perle's artwork rendering exactly: a 34-point image,
black shadow opacity 0.12 with radius 3 and vertical offset 2, and the same
48-point circular tap area. Position remains the identical bottom-centre formula:
x = half the screen width; y = screen height minus bottom safe area minus 36.
Source comparison verified the image modifiers and placement function against
Perle before release.

BlessingKit revision, authority profile, installation identity and keychain access
remain unchanged from iOS build 4. No new blessing is intentionally required by
this update. Perle opening/fallback, start/stop behaviour and blessing visibility
rules are unchanged. This task releases iOS only, with embedded Watch and Messages.

The archive compiled successfully and passed bundle, version, encryption and
Watch-size validation. Export and upload succeeded. The staged distribution app
passed strict, deep signature verification, with the expected music App Group,
Associated Domains and unchanged public authority profile. The original keychain
search order was restored and verified. All 18 hosted media packs remain ready
with source and manifest hashes checked.

App Store Connect reports iOS build 5 as `VALID` and `IN_BETA_TESTING`, assigned
exclusively to the single-tester Owner internal group. English/French What to Test
notes and exempt encryption were read back successfully. Verified at 2026-11-21T22:20:39.648407+00:00.
The existing functional blessing checks from build 4 remain the regression
baseline for this visual adjustment.

Private outputs: external SSD `Bewie-Releases/2026-11-21-iOS-5`.
Pre-existing checkout edits are preserved separately from this release's changes.
