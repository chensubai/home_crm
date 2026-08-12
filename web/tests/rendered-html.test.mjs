import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const templateRoot = new URL("../", import.meta.url);

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  return worker.fetch(new Request("http://localhost/", { headers: { accept: "text/html" } }), {
    ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
  }, { waitUntil() {}, passThroughOnException() {} });
}

test("server-renders the 方寸 landing page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>方寸｜把家，装进秩序里<\/title>/i);
  assert.match(html, /把家，装进/);
  assert.match(html, /家庭提醒/);
  assert.match(html, /NFC 标签/);
  assert.match(html, /前往 App Store/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|SkeletonPreview/i);
});

test("removes starter preview infrastructure", async () => {
  const [page, layout, packageJson] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
  ]);
  assert.match(page, /APP_STORE_URL/);
  assert.match(layout, /lang="zh-CN"/);
  assert.match(layout, /方寸是为家庭而生/);
  assert.doesNotMatch(page, /SkeletonPreview|_sites-preview/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  await assert.rejects(access(new URL("app/_sites-preview", templateRoot)));
});
