import apps from "../apps.json" with { type: "json" };
import { createHandler } from "./handler.ts";

interface Environment { ASSETS: { fetch(request: Request): Promise<Response> } }
const handle = createHandler(apps);

export default {
  async fetch(request: Request, env: Environment): Promise<Response> {
    if (new URL(request.url).pathname === "/assets/preview.png" && ["GET", "HEAD"].includes(request.method)) {
      return env.ASSETS.fetch(request);
    }
    return handle(request);
  },
};
