# Bewie blessing links

App-specific deployment of BlessingKit revision `8f0af803ac5a4b11f61c551f862b8a8b941c78ea`,
whose source tree is identical to local commit `77cebba`.
The vendored `src` and service scripts come from that revision. This worker stores
no blessings or private keys. The iOS client validates signatures and recipient
binding; the worker supplies previews, handoff pages and AASA only.

Domain: https://blessing.bewie.atelierindustriel.be

Run `npm ci`, `npm run typecheck`, `npm test`, and `npm run deploy` in this directory.
The Cloudflare custom domain manages DNS and TLS. Public app identifiers in
`apps.json` must match the signed iOS app and the bundled public authority profile.
