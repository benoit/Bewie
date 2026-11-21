/** Provider-independent link presentation. Cryptographic authority stays in the SDK. */
export interface AppProfile {
  appID: string;
  name: string;
  scheme: string;
  linksBaseURL: string;
  appleAppID: string;
}

const commonHeaders = {
  "Cache-Control": "no-store",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
  "X-Robots-Tag": "noindex, nofollow, noarchive",
};

function escapeHTML(value: string): string {
  return value.replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

/** Checks only framing, size, app routing, and rights bits; this is not signature validation. */
export function parseToken(token: string, kind: "request" | "grant", appID: string): boolean {
  if (token.length === 0 || token.length > 2048 || !/^[A-Za-z0-9_-]+$/.test(token) || token.length % 4 === 1) return false;
  let bytes: Uint8Array;
  try {
    const base = token.replace(/-/g, "+").replace(/_/g, "/");
    const decoded = atob(base + "=".repeat((4 - base.length % 4) % 4));
    const canonical = btoa(decoded).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    if (canonical !== token) return false;
    bytes = Uint8Array.from(decoded, c => c.charCodeAt(0));
  } catch { return false; }
  if (bytes.length < 7 || bytes[0] !== 0x42 || bytes[1] !== 0x4b || bytes[3] !== 1) return false;
  if (bytes[2] !== (kind === "request" ? 0x51 : 0x47)) return false;
  const length = bytes[4] * 256 + bytes[5];
  if (length < 1 || length > 255 || bytes.length < 6 + length) return false;
  let identifier: string;
  try { identifier = new TextDecoder("utf-8", { fatal: true }).decode(bytes.subarray(6, 6 + length)); }
  catch { return false; }
  if (identifier !== appID) return false;
  let offset = 6 + length;
  if (kind === "request") {
    return bytes.length === offset + 33 + 16 + 64 && [2, 3].includes(bytes[offset]);
  }
  const depth = bytes[offset++];
  if (depth < 1 || depth > 5 || bytes.length !== offset + depth * 114) return false;
  for (let i = 0; i < depth; i++, offset += 114) {
    if (![2, 3].includes(bytes[offset]) || bytes[offset + 49] > 7) return false;
  }
  return true;
}

function validateProfiles(apps: readonly AppProfile[]): void {
  const paths = new Set<string>();
  for (const app of apps) {
    const url = new URL(app.linksBaseURL);
    const path = url.pathname.replace(/\/$/, "");
    if (url.protocol !== "https:" || url.search || url.hash || url.username || url.password
        || !/^[a-z][a-z0-9+.-]*$/.test(app.scheme) || !/^[\x21-\x7e]{1,255}$/.test(app.appID)
        || !/^[A-Z0-9]{10}\.[A-Za-z0-9.-]+$/.test(app.appleAppID)
        || !app.appleAppID.endsWith(`.${app.appID}`) || paths.has(`${url.host}${path}`)
        || !/^[a-zA-Z0-9/_-]*$/.test(path) || path.includes("//") || !app.name) throw new Error("Invalid or ambiguous app profile");
    paths.add(`${url.host}${path}`);
  }
}

export function createHandler(apps: readonly AppProfile[]): (request: Request) => Promise<Response> {
  validateProfiles(apps);
  return async function handle(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const local = ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
    const routedApps = apps.filter(app => local || new URL(app.linksBaseURL).host === url.host);
    const respond = (body: string, status = 200, headers: Record<string, string> = {}) =>
      new Response(request.method === "HEAD" ? null : body, { status, headers: { ...commonHeaders, ...headers } });
    if (request.method !== "GET" && request.method !== "HEAD") return respond("Method not allowed", 405, { Allow: "GET, HEAD" });
    if (url.pathname === "/.well-known/apple-app-site-association" || url.pathname === "/apple-app-site-association") {
      const details = routedApps.map(app => ({
        appIDs: [app.appleAppID],
        components: [
          { "/": `${new URL(app.linksBaseURL).pathname.replace(/\/$/, "")}/v1/request/*` },
          { "/": `${new URL(app.linksBaseURL).pathname.replace(/\/$/, "")}/v1/grant/*` },
        ],
      }));
      return respond(JSON.stringify({ applinks: { details } }), 200, { "Content-Type": "application/json" });
    }
    if (url.pathname === "/health") return respond("ok", 200, { "Content-Type": "text/plain; charset=utf-8" });
    if (url.search || url.hash || url.pathname.includes("%")) return respond("Not found", 404);
    for (const app of routedApps) {
      const base = new URL(app.linksBaseURL);
      const prefix = `${base.pathname.replace(/\/$/, "")}/v1/`;
      if (!url.pathname.startsWith(prefix)) continue;
      const parts = url.pathname.slice(prefix.length).split("/");
      const [kind, token] = parts;
      if (parts.length !== 2 || (kind !== "request" && kind !== "grant")) return respond("Not found", 404);
      let framed = false;
      try { framed = parseToken(token, kind, app.appID); } catch { /* Invalid UTF-8 or framing. */ }
      if (!framed) return respond("Not found", 404);
      const canonical = `${app.linksBaseURL.replace(/\/$/, "")}/v1/${kind}/${token}`;
      const deepLink = `${app.scheme}://${kind === "request" ? "ask" : "grant"}?token=${token}`;
      const title = kind === "request" ? "Demande de bénédiction" : "Bénédiction";
      const image = `${base.origin}/assets/preview.png`;
      // Link-preview crawlers read metadata. The app alone validates signatures and activates rights.
      const html = `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer"><meta name="robots" content="noindex,nofollow">
<title>${escapeHTML(title)} — ${escapeHTML(app.name)}</title>
<meta property="og:title" content="${escapeHTML(title)}">
<meta property="og:site_name" content="${escapeHTML(app.name)}">
<meta property="og:type" content="website"><meta property="og:url" content="${escapeHTML(canonical)}">
<meta property="og:image" content="${escapeHTML(image)}">
<meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
</head><body><p>Ce lien s’ouvre dans ${escapeHTML(app.name)}.</p>
<script src="/open.js" data-link="${escapeHTML(deepLink)}" defer></script></body></html>`;
      return respond(html, 200, {
        "Content-Type": "text/html; charset=utf-8",
        "Content-Security-Policy": "default-src 'none'; script-src 'self'; img-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",
      });
    }
    if (url.pathname === "/open.js") {
      return respond("const link = document.currentScript?.dataset.link; if (link) window.location.replace(link);", 200,
        { "Content-Type": "text/javascript; charset=utf-8" });
    }
    return respond("Not found", 404, { "Content-Type": "text/plain; charset=utf-8" });
  };
}
