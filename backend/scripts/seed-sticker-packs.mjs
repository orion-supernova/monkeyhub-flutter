#!/usr/bin/env node
// Uploads prebuilt sticker packs (a manifest plus its files) into a backend's
// storage as official packs. The Noto packs seed themselves from inside the
// backend (`expressions:seedOfficialPacks`); these are the ones built on this
// machine instead — the Fluent 3D packs (tool/stickers/fluent_packs.py) and
// the MonkeyHub monkeys (tool/stickers/monkey_pack.py).
//
//   node scripts/seed-sticker-packs.mjs <manifest.json> [backend-url]
//
// The backend URL defaults to CONVEX_SELF_HOSTED_URL from .env.local, and the
// admin key comes from there too (both boxes share it). Idempotent: a sticker
// already present at its position is skipped, so a re-run only fills gaps.
// Run it against BOTH backends.
//
// Manifest: [{ slug, title, order?, author, license, sourceUrl, format,
//   contentType, width, height, stickers: [{ file, order, emoji }] }], with
// `file` relative to the manifest. A pack without `order` goes after the Noto
// packs at 100 + its index.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { ConvexHttpClient } from "convex/browser";
import { makeFunctionReference } from "convex/server";

const here = dirname(fileURLToPath(import.meta.url));
const env = Object.fromEntries(
  readFileSync(join(here, "..", ".env.local"), "utf8")
    .split("\n")
    .filter((l) => l.includes("=") && !l.startsWith("#"))
    .map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1).trim()])
);

const [manifestPath, urlArg] = process.argv.slice(2);
if (!manifestPath) {
  console.error("usage: seed-sticker-packs.mjs <manifest.json> [backend-url]");
  process.exit(2);
}
const url = urlArg ?? env.CONVEX_SELF_HOSTED_URL;
const client = new ConvexHttpClient(url);
client.setAdminAuth(env.CONVEX_SELF_HOSTED_ADMIN_KEY);

const ensurePack = makeFunctionReference("expressions:ensureOfficialPack");
const uploadUrl = makeFunctionReference("expressions:seedUploadUrl");
const insertSticker = makeFunctionReference("expressions:insertOfficialSticker");

const root = dirname(manifestPath);
const packs = JSON.parse(readFileSync(manifestPath, "utf8"));
console.log(`${url}: ${packs.length} packs`);

for (let p = 0; p < packs.length; p++) {
  const pack = packs[p];
  const { packId, haveOrders } = await client.mutation(ensurePack, {
    slug: pack.slug,
    title: pack.title,
    order: pack.order ?? 100 + p,
    author: pack.author,
    license: pack.license,
    sourceUrl: pack.sourceUrl,
  });
  const done = new Set(haveOrders);
  let added = 0;
  for (const s of pack.stickers) {
    if (done.has(s.order)) continue;
    const body = readFileSync(join(root, s.file));
    const target = await client.mutation(uploadUrl, {});
    const res = await fetch(target, {
      method: "POST",
      headers: { "Content-Type": pack.contentType },
      body,
    });
    if (!res.ok) throw new Error(`upload ${s.file}: HTTP ${res.status}`);
    const { storageId } = await res.json();
    await client.mutation(insertSticker, {
      packId,
      storageId,
      emoji: s.emoji,
      width: s.width ?? pack.width,
      height: s.height ?? pack.height,
      order: s.order,
      format: pack.format,
    });
    added++;
  }
  console.log(`  ${pack.slug}: +${added} (${pack.stickers.length} total)`);
}
