import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import apps from "../apps.json" with { type: "json" };
import { createHandler } from "./handler.ts";

const handle = createHandler(apps);
const port = Number(process.env.PORT ?? 8787);
const host = process.env.HOST ?? "127.0.0.1";
const server = createServer(async (incoming, outgoing) => {
  incoming.resume();
  try {
    const authority = incoming.headers.host;
    const path = incoming.url ?? "/";
    if (!authority || /[\s/\\@?#]/.test(authority) || !path.startsWith("/") || path.startsWith("//")) {
      outgoing.writeHead(400, { "Content-Type": "text/plain" }); outgoing.end("Bad request"); return;
    }
    const url = new URL(path, `http://${authority}`);
    if (url.pathname === "/assets/preview.png" && ["GET", "HEAD"].includes(incoming.method ?? "")) {
      const image = await readFile(new URL("../public/assets/preview.png", import.meta.url));
      outgoing.writeHead(200, { "Content-Type": "image/png", "Cache-Control": "public, max-age=86400" });
      outgoing.end(incoming.method === "HEAD" ? undefined : image);
      return;
    }
    const response = await handle(new Request(url, { method: incoming.method }));
    outgoing.writeHead(response.status, Object.fromEntries(response.headers));
    outgoing.end(Buffer.from(await response.arrayBuffer()));
  } catch {
    outgoing.writeHead(500, { "Content-Type": "text/plain", "Cache-Control": "no-store" });
    outgoing.end("Internal error");
  }
});
server.listen(port, host, () => {
  const address = server.address();
  const boundPort = address && typeof address !== "string" ? address.port : port;
  console.log(`BlessingKit links: http://${host}:${boundPort}`);
});
