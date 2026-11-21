# Bewie private Perle pearl

The iOS main app uses BlessingKit's validated installation state. The pearl appears
at bottom centre on the map after the opening sleeve closes, and is hidden while
the player is presented. Its frame is excluded from song-pin layout. Unblessed
installations reserve no pearl space. Mac Catalyst, Watch and TV do not integrate
the kit. Music, Messages and ordinary song links remain independent.

## Authority and approval

The root private key lives only in this Mac mini's Keychain. The app bundles only
`Bewie/Blessing.public.json`. Each installation must create a request by opening
`bewie://start`; the native share sheet supplies an HTTPS request link. On the Mac:

```sh
swift run --package-path ../BlessingKit blessing-admin issue \
  --config Bewie/Blessing.public.json \
  --request '<recipient-request-URL>' --rights 000 --copy
```

Return the resulting grant link to the same installation. Keep request/grant links
out of Git, logs and public pages. The direct root grant enables personal access
without transmission rights. Existing kit validation is used, with no additional
opt-in direct-root acceptance policy. A blessing belongs to one installation,
not to an Apple ID or every device belonging to a person.

`bewie://start` is a no-op when already blessed. `bewie://stop` removes local
blessing state and pending requests; the pearl disappears immediately. Reopening
an old grant cannot restore it after stop. Reactivation needs a fresh request and
Mac approval. Blessings persist offline without expiry or remote revocation.
Device replacement requires another approval; reinstall recovery is not guaranteed.

## Perle destination

The pearl first attempts `perle://`, opening or foregrounding Perle without
selecting a place or granting Perle access. A failed open falls back to
https://apps.apple.com/app/id6834117140. If both opens fail, the app reports it.

## Routing and review

HTTPS links use https://blessing.bewie.atelierindustriel.be, with AASA scoped to
Bewie's `/v1/request/*` and `/v1/grant/*` routes. `bewie://grant?token=...` and the
kit's request/ask routes are handled by the SDK. The main app owns `start`/`stop`
behaviour. Associated Domains is enabled only for the iOS main app.

App Review notes must disclose the conditional pearl and explain the request and
manual approval process. A reviewer must receive an actual recipient-bound grant;
a pre-created grant for another installation will not work. Public review access
must be arranged before submitting the app for App Store review.

## Mac-grant integration test

Normal unit tests skip the real-authority test. After installing the simulator
test host with the normal unit suite, run `tools/test-blessing-integration.py`
with `--simulator`, `--derived-data`, `--results-dir` and `--admin-binary`.
This opt-in harness issues exactly two personal `000` grants on the Mac, never
prints their tokens, and removes the temporary Simulator exchange files. It
requires the existing Bewie authority in the Mac Keychain and does not generate
or export an authority key. The test checks restoration, start/stop semantics,
old-grant rejection and fresh approval.
