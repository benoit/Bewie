import apps from "../apps.json" with { type: "json" };
if (!apps.length || apps.some(app => new URL(app.linksBaseURL).hostname.endsWith("example.com")
    || app.appID.startsWith("be.example.") || app.appleAppID.startsWith("ABCDE12345."))) {
  throw new Error("Replace the example app profiles with real app identities and domains before deployment.");
}
