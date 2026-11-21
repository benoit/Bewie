# Bewie iOS 1.0 (4) — 21 November 2026

The iOS main app integrates BlessingKit and a private pearl linking to Perle.
Only blessed installations display the pearl, at bottom centre after the sleeve
closes and while the map is unobstructed. Song-pin layout excludes the pearl's
frame. No space is reserved when the pearl is absent. Mac Catalyst, Watch and
TV receive no blessing integration.

Entry points are `bewie://start`, `bewie://stop` and the kit's signed grant links.
An already-blessed start does nothing. Stop persistently removes the blessing and
pending requests; old grants cannot reactivate it. Fresh Mac approval is required.
The pearl opens `perle://`, falling back to App Store ID 6834117140 only when
opening fails. It never grants access within Perle.

The public authority profile is bundled in the main app; its private key remains
in the Mac mini Keychain. Operators issue personal rights `000`. Existing kit
validation is used, without an additional opt-in direct-root acceptance policy.
BlessingKit is pinned to published revision `8f0af803ac5a4b11f61c551f862b8a8b941c78ea`,
whose source tree is identical to local commit `77cebba`.

The Cloudflare link service is deployed at
https://blessing.bewie.atelierindustriel.be. HTTPS health, preview, scoped AASA and
invalid-token responses passed verification, and Apple's association CDN returned
the correct AASA. The service contains no signing key or blessing database.

Validation: 106 iOS unit tests passed. A separate integration test used two real
Mac-mini-signed `000` grants to verify acceptance, restoration from Keychain,
already-blessed start, stop, old-grant rejection and fresh approval. Three link
service tests and TypeScript checking passed. The iOS archive compiled and passed
bundle/version/encryption/Watch-size checks. Watch retains all nine offline tracks.
All 18 hosted music/video packs remain ready with source/manifest hashes verified.
The distributed app passed strict, deep signature verification, with the expected
music App Group, Associated Domains entitlement and bundled public profile.
The original signing keychain search order was restored and verified.

Final TestFlight status is recorded after Apple processing.

Private release outputs: external SSD `Bewie-Releases/2026-11-21-iOS-4`.
The checkout contained pre-existing iOS/media/submission work; this task preserves
those edits and stages its integration separately. The release archive was built
from the complete current working tree. No new physical-device validation is claimed.

See [Blessing operations and review access](Blessing.md) for the manual approval
workflow and App Review requirements. No public App Store submission is made here.
