import test from 'node:test';
import assert from 'node:assert/strict';
import apps from '../apps.json' with { type: 'json' };
import { createHandler } from '../src/handler.ts';
const handle = createHandler(apps);
const host = 'https://blessing.bewie.atelierindustriel.be';
test('production association belongs only to Bewie and blessing paths', async () => {
  const response = await handle(new Request(host+'/.well-known/apple-app-site-association'));
  assert.equal(response.status, 200);
  const text = await response.text();
  assert.ok(text.includes(apps[0].appleAppID));
  assert.ok(text.includes('/v1/request/'));
  assert.ok(text.includes('/v1/grant/'));
  assert.ok(!text.includes('laetitia'));
});
test('unknown tokens and hosts cannot grant access', async () => {
  for (const url of [host+'/v1/grant/invalid',host+'/v1/request/invalid','https://example.com/v1/grant/invalid']) {
    assert.equal((await handle(new Request(url))).status,404);
  }
});
test('service is live and does not accept mutations', async () => {
  assert.equal((await handle(new Request(host+'/health'))).status,200);
  assert.equal((await handle(new Request(host+'/health',{method:'POST'}))).status,405);
});
