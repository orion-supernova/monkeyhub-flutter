import { v } from "convex/values";
import { mutation, query } from "./functions";
import {
  internalAction,
  internalMutation,
  internalQuery,
} from "./_generated/server";
import { internal } from "./_generated/api";
import { expressionRef } from "./schema";
import { deleteStored } from "./files";
import { isKlipyUrl } from "./messages";

/**
 * GIFs and stickers — everything the composer's expression panel reads and
 * writes that is not a message.
 *
 * ## What lives where
 *
 *  - **KLIPY** (GIF and sticker search) is called straight from the client.
 *    Its API terms require API calls and media loads to come from the user's
 *    app and forbid routing them through our servers or keeping copies of the
 *    files. So the only KLIPY thing this backend holds is the app key, served
 *    by [config] so it can be rotated or switched off without a release —
 *    the key is not a secret (KLIPY designs for it to ship in clients).
 *  - **Sticker packs** are ours: rows in `stickerPacks`/`stickers`, art in
 *    storage. Official packs are seeded by [seedOfficialPacks]; personal
 *    packs hold stickers people cut out of their own photos.
 *  - **Recents and favourites** are one `userExpressions` row per user, so
 *    they follow the account across devices.
 */

/** How many recently sent GIFs/stickers are remembered. */
const MAX_RECENTS = 40;

/** How many starred GIFs/stickers a user may keep. */
const MAX_FAVORITES = 200;

/** How many stickers one person may make. */
const MAX_PERSONAL_STICKERS = 120;

/**
 * What the client needs to talk to KLIPY, or nulls to hide the GIF tab.
 *
 * `KLIPY_API_KEY` unset (a fresh deployment, a third-party server from the
 * directory) is the normal "no GIFs here" state, not an error. Ads — the tiles
 * KLIPY interleaves with results, which is how the partnership pays — are on
 * whenever there is a key; `KLIPY_ADS=0` is the server switch that kills them
 * everywhere at once without a release.
 */
export const config = query({
  args: {},
  handler: async () => {
    const key = (process.env.KLIPY_API_KEY ?? "").trim();
    return {
      klipyAppKey: key.length > 0 ? key : null,
      klipyAds: key.length > 0 && process.env.KLIPY_ADS !== "0",
    };
  },
});

/**
 * The whole catalog: every official pack in order, then the caller's own
 * personal pack if they have made any stickers.
 *
 * The catalog, not the caller's strip — which packs they have ADDED lives in
 * [state], deliberately. This query resolves a URL for every sticker (~400
 * `getUrl` calls), and reading the per-user row here would re-run all of that
 * on every recents update, i.e. on every sticker anybody sends. Kept apart,
 * it re-runs only when a pack itself changes.
 */
export const packs = query({
  args: {},
  handler: async (ctx, { userId }) => {
    const official = await ctx.db
      .query("stickerPacks")
      .withIndex("by_kind_order", (q) => q.eq("kind", "official"))
      .collect();
    const personal = await ctx.db
      .query("stickerPacks")
      .withIndex("by_owner", (q) => q.eq("ownerId", userId))
      .collect();

    const out = [];
    for (const pack of [...official, ...personal]) {
      const rows = await ctx.db
        .query("stickers")
        .withIndex("by_pack_order", (q) => q.eq("packId", pack._id))
        .collect();
      const stickers = [];
      for (const s of rows) {
        if (s.deletedAt !== undefined) continue;
        const url = await ctx.storage.getUrl(s.storageId);
        if (!url) continue;
        stickers.push({
          _id: s._id,
          storageId: s.storageId,
          url,
          format: s.format,
          emoji: s.emoji,
          width: s.width,
          height: s.height,
        });
      }
      // An official pack whose seed failed half-way is not worth a tab; the
      // personal pack is always shown so its owner can see it is empty.
      if (stickers.length === 0 && pack.kind === "official") continue;
      out.push({
        _id: pack._id,
        slug: pack.slug,
        title: pack.title,
        kind: pack.kind,
        author: pack.author,
        license: pack.license,
        sourceUrl: pack.sourceUrl,
        stickers,
      });
    }
    return out;
  },
});

/**
 * The packs a user starts with before they have chosen any — the ones that
 * cover the most everyday feelings. Slugs rather than ids so they survive a
 * reseed.
 */
export const DEFAULT_PACK_SLUGS = [
  "noto-moods",
  "noto-love",
  "noto-feelings",
  "noto-party",
];

/** Most packs one user may add, to keep the strip and the row bounded. */
const MAX_INSTALLED_PACKS = 60;

/**
 * The official packs [row] has added, in order — or the default set when it
 * has never chosen. Ids of packs that no longer exist are dropped.
 */
async function installedPackIdsFor(ctx: any, row: any): Promise<any[]> {
  if (row?.installedPackIds !== undefined) {
    const out = [];
    for (const id of row.installedPackIds) {
      const pack = await ctx.db.get(id);
      if (pack && pack.kind === "official") out.push(id);
    }
    return out;
  }
  const out = [];
  for (const slug of DEFAULT_PACK_SLUGS) {
    const pack = await ctx.db
      .query("stickerPacks")
      .withIndex("by_slug", (q: any) => q.eq("slug", slug))
      .first();
    if (pack) out.push(pack._id);
  }
  return out;
}

/**
 * The caller's recents and favourites (newest first) and the official packs
 * they have added to their strip, in their order.
 */
export const state = query({
  args: {},
  handler: async (ctx, { userId }) => {
    const row = await ctx.db
      .query("userExpressions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .first();
    return {
      recents: row?.recents ?? [],
      favorites: row?.favorites ?? [],
      installedPackIds: await installedPackIdsFor(ctx, row),
    };
  },
});

/**
 * Adds an official pack to the caller's strip (at the end) or removes it.
 * The first change materialises the default set, so removing one default
 * pack keeps the other three.
 */
export const setPackInstalled = mutation({
  args: { packId: v.id("stickerPacks"), installed: v.boolean() },
  handler: async (ctx, { userId, packId, installed }) => {
    const pack = await ctx.db.get(packId);
    // Only the shared catalog can be added. A personal pack is its owner's
    // alone and is shown to them regardless.
    if (!pack || pack.kind !== "official") throw new Error("NOT_A_PACK");
    const row = await stateRow(ctx, userId);
    const current = await installedPackIdsFor(ctx, row);
    const without = current.filter((id: any) => id !== packId);
    const next = installed ? [...without, packId] : without;
    if (next.length > MAX_INSTALLED_PACKS) throw new Error("TOO_MANY_PACKS");
    await ctx.db.patch(row._id, { installedPackIds: next, updatedAt: Date.now() });
    return null;
  },
});

/**
 * Reorders the caller's added packs to [packIds]. Anything not currently
 * added is ignored and anything added but missing keeps its place at the end,
 * so a stale client can reorder but never add or drop a pack by accident.
 */
export const reorderPacks = mutation({
  args: { packIds: v.array(v.id("stickerPacks")) },
  handler: async (ctx, { userId, packIds }) => {
    const row = await stateRow(ctx, userId);
    const current = await installedPackIdsFor(ctx, row);
    const have = new Set(current.map(String));
    const ordered = [];
    const seen = new Set<string>();
    for (const id of packIds) {
      const key = String(id);
      if (have.has(key) && !seen.has(key)) {
        ordered.push(id);
        seen.add(key);
      }
    }
    for (const id of current) {
      if (!seen.has(String(id))) ordered.push(id);
    }
    await ctx.db.patch(row._id, { installedPackIds: ordered, updatedAt: Date.now() });
    return null;
  },
});

/**
 * Two refs are the same GIF/sticker when they name the same thing — the pack
 * sticker's id, or KLIPY's URL. Titles and sizes are cosmetic.
 */
function sameRef(a: any, b: any): boolean {
  if (a.source !== b.source || a.kind !== b.kind) return false;
  if (a.stickerId !== undefined || b.stickerId !== undefined) {
    return a.stickerId === b.stickerId;
  }
  return a.url === b.url;
}

/**
 * Whether [ref] is well-formed enough to keep: a pack sticker names its id and
 * blob, a KLIPY one names a KLIPY URL. Anything else is refused, for the same
 * reason `messages:send` refuses a foreign host — these rows are drawn later,
 * and a stored URL is a URL the app will load.
 */
function validRef(ref: any): boolean {
  if (ref.kind !== "gif" && ref.kind !== "sticker") return false;
  if (ref.source === "klipy") {
    return (
      isKlipyUrl(ref.url) &&
      (ref.previewUrl === undefined || isKlipyUrl(ref.previewUrl))
    );
  }
  if (ref.source === "pack" || ref.source === "personal") {
    return (
      ref.kind === "sticker" &&
      ref.stickerId !== undefined &&
      ref.storageId !== undefined
    );
  }
  return false;
}

/** Clips free text on a ref so a row can't be padded out. */
function tidyRef(ref: any) {
  return {
    ...ref,
    title: typeof ref.title === "string" ? ref.title.slice(0, 120) : undefined,
    ref: typeof ref.ref === "string" ? ref.ref.slice(0, 200) : undefined,
  };
}

async function stateRow(ctx: any, userId: any) {
  const row = await ctx.db
    .query("userExpressions")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
  if (row) return row;
  const id = await ctx.db.insert("userExpressions", {
    userId,
    recents: [],
    favorites: [],
    updatedAt: Date.now(),
  });
  return await ctx.db.get(id);
}

/**
 * Moves [ref] to the front of the caller's recents.
 *
 * Called by the client after a GIF or sticker send lands, rather than by
 * `messages:send` itself, so a send never pays for a second document write in
 * its own transaction — recents are a convenience, and losing one to a flaky
 * network costs nothing.
 */
export const recordUse = mutation({
  args: { ref: expressionRef },
  handler: async (ctx, { userId, ref }) => {
    if (!validRef(ref)) return null;
    const clean = tidyRef(ref);
    const row = await stateRow(ctx, userId);
    const recents = [
      clean,
      ...row.recents.filter((r: any) => !sameRef(r, clean)),
    ].slice(0, MAX_RECENTS);
    await ctx.db.patch(row._id, { recents, updatedAt: Date.now() });
    return null;
  },
});

/** Stars or un-stars [ref]. Returns whether it is now a favourite. */
export const toggleFavorite = mutation({
  args: { ref: expressionRef },
  handler: async (ctx, { userId, ref }) => {
    if (!validRef(ref)) return false;
    const clean = tidyRef(ref);
    const row = await stateRow(ctx, userId);
    const had = row.favorites.some((r: any) => sameRef(r, clean));
    const favorites = had
      ? row.favorites.filter((r: any) => !sameRef(r, clean))
      : [clean, ...row.favorites].slice(0, MAX_FAVORITES);
    await ctx.db.patch(row._id, { favorites, updatedAt: Date.now() });
    return !had;
  },
});

/** Drops [ref] from the caller's recents. */
export const forgetRecent = mutation({
  args: { ref: expressionRef },
  handler: async (ctx, { userId, ref }) => {
    const row = await stateRow(ctx, userId);
    await ctx.db.patch(row._id, {
      recents: row.recents.filter((r: any) => !sameRef(r, ref)),
      updatedAt: Date.now(),
    });
    return null;
  },
});

/**
 * Adds a sticker the caller made to their personal pack, creating the pack on
 * their first one.
 *
 * The blob arrives the usual way (`files:generateUploadUrl` + PUT). Its size
 * and format are the client's word, which is fine: they only size a tile, and
 * the file is the caller's own photo.
 */
export const createPersonalSticker = mutation({
  args: {
    storageId: v.id("_storage"),
    emoji: v.string(),
    width: v.number(),
    height: v.number(),
  },
  handler: async (ctx, { userId, storageId, emoji, width, height }) => {
    // Refusals below throw WITHOUT deleting the upload: a throw rolls back
    // every write in the mutation, the delete included, so the blob is left
    // for `files:gcOrphanedFiles`, which reclaims unreferenced files after a
    // day either way.
    const meta = await ctx.db.system.get(storageId);
    if (!meta) throw new Error("FILE_NOT_FOUND");
    // A sticker is a picture. Anything else uploaded under this name would be
    // served to whoever receives it as though it were one. Checked only when
    // the upload declared a type — the client always sends one, and an
    // undeclared blob renders as nothing rather than as something else.
    const type = meta.contentType;
    if (type !== undefined && !/^image\/(png|webp|gif)$/.test(type)) {
      throw new Error("NOT_AN_IMAGE");
    }
    if ((meta.size ?? 0) > 1024 * 1024) throw new Error("TOO_LARGE");

    const slug = `personal:${userId}`;
    let pack = await ctx.db
      .query("stickerPacks")
      .withIndex("by_slug", (q) => q.eq("slug", slug))
      .first();
    if (!pack) {
      const id = await ctx.db.insert("stickerPacks", {
        slug,
        title: "My stickers",
        kind: "personal",
        ownerId: userId,
        order: 0,
        createdAt: Date.now(),
      });
      pack = (await ctx.db.get(id))!;
    }

    const existing = await ctx.db
      .query("stickers")
      .withIndex("by_pack_order", (q) => q.eq("packId", pack._id))
      .collect();
    const live = existing.filter((s) => s.deletedAt === undefined);
    if (live.length >= MAX_PERSONAL_STICKERS) {
      throw new Error("TOO_MANY_STICKERS");
    }
    const order =
      existing.reduce((m, s) => Math.max(m, s.order), -1) + 1;
    const clamp = (n: number) =>
      Number.isFinite(n) && n > 0 ? Math.min(Math.round(n), 2048) : 512;
    return await ctx.db.insert("stickers", {
      packId: pack._id,
      storageId,
      format: "image",
      emoji: [...emoji.trim()].slice(0, 8).join("") || "🙂",
      width: clamp(width),
      height: clamp(height),
      order,
      createdAt: Date.now(),
    });
  },
});

/**
 * Removes one of the caller's stickers from their pack.
 *
 * Soft: the row and blob stay, because messages already sent name them and
 * must keep rendering. The same sticker can no longer be sent (see
 * `expressionFieldsFor`) or picked.
 */
export const deletePersonalSticker = mutation({
  args: { stickerId: v.id("stickers") },
  handler: async (ctx, { userId, stickerId }) => {
    const sticker = await ctx.db.get(stickerId);
    if (!sticker) return null;
    const pack = await ctx.db.get(sticker.packId);
    if (!pack || pack.kind !== "personal" || pack.ownerId !== userId) {
      throw new Error("NOT_AUTHORIZED");
    }
    await ctx.db.patch(stickerId, { deletedAt: Date.now() });
    // Scrubbed from the owner's own lists too, or the tile would sit in
    // RECENT and fail to send.
    const row = await ctx.db
      .query("userExpressions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .first();
    if (row) {
      const keep = (r: any) => r.stickerId !== stickerId;
      await ctx.db.patch(row._id, {
        recents: row.recents.filter(keep),
        favorites: row.favorites.filter(keep),
        updatedAt: Date.now(),
      });
    }
    return null;
  },
});

/**
 * Account teardown: the user's personal pack (rows AND blobs — these are their
 * photos) and their recents row. Called from `auth.ts`'s purge.
 */
export async function purgeUserExpressions(ctx: any, userId: any) {
  const packs = await ctx.db
    .query("stickerPacks")
    .withIndex("by_owner", (q: any) => q.eq("ownerId", userId))
    .collect();
  for (const pack of packs) {
    const rows = await ctx.db
      .query("stickers")
      .withIndex("by_pack_order", (q: any) => q.eq("packId", pack._id))
      .collect();
    for (const s of rows) {
      await deleteStored(ctx, s.storageId);
      await ctx.db.delete(s._id);
    }
    await ctx.db.delete(pack._id);
  }
  const state = await ctx.db
    .query("userExpressions")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect();
  for (const row of state) await ctx.db.delete(row._id);
}

// ─── Official packs ─────────────────────────────────────────────────────────
//
// Google's Noto Animated Emoji, as Lottie. CC BY 4.0: free to use and
// redistribute with credit, which the pack's `author`/`license` fields carry
// into the panel's pack info. Lottie rather than the animated WebP Google also
// publishes because it is about a tenth of the size (a 40 KB JSON against a
// 400 KB WebP) and draws crisp at any size.

const NOTO_AUTHOR = "Google — Noto Emoji Animation";
const NOTO_LICENSE = "CC BY 4.0";
const NOTO_SOURCE = "https://googlefonts.github.io/noto-emoji-animation/";
const notoUrl = (code: string) =>
  `https://fonts.gstatic.com/s/e/notoemoji/latest/${code}/lottie.json`;

/**
 * The seeded packs. Codepoints are Noto's file names; the emoji itself is
 * derived from them. Order within a pack is the order here.
 */
export const OFFICIAL_PACKS: {
  slug: string;
  title: string;
  codes: string[];
}[] = [
  {
    slug: "noto-moods",
    title: "Moods",
    codes: [
      "1f602", "1f923", "1f60d", "1f970", "1f618", "1f929", "1f973", "1f60e",
      "1f609", "1f60a", "1f607", "1f914", "1f644", "1f60f", "1f97a", "1f62d",
      "1f631", "1f621", "1f92f", "1f634", "1f92a", "1f972", "1fae0", "1f92d",
      "1fae3", "1f971", "1f922", "1f976", "1f975", "1f4a9", "1f47b", "1f921",
    ],
  },
  {
    slug: "noto-love",
    title: "Hearts & hands",
    codes: [
      "2764_fe0f", "1f9e1", "1f49b", "1f49a", "1f499", "1f49c", "1f5a4",
      "1fa77", "1f496", "1f495", "1f49e", "1f494", "2764_fe0f_200d_1f525",
      "1f48b", "1faf6", "1f44d", "1f44e", "1f44f", "1f64c", "1f4aa", "1f44a",
      "1f64f", "1f44b", "270c_fe0f", "1f91d", "1fac2",
    ],
  },
  {
    slug: "noto-critters",
    title: "Critters",
    codes: [
      "1f648", "1f649", "1f64a", "1f63b", "1f639", "1f640", "1f981", "1f98a",
      "1f43c", "1f43b", "1f984", "1f996", "1f422", "1f438", "1f407", "1f415",
      "1f416", "1f412", "1f994", "1f9a6", "1f989", "1f427", "1f42c", "1f433",
      "1f419", "1f980", "1f41d", "1f98b",
    ],
  },
  {
    slug: "noto-party",
    title: "Party",
    codes: [
      "1f389", "1f38a", "1f388", "1f382", "1f381", "1f386", "1faa9", "1f525",
      "2728", "1f4af", "26a1", "1f4a5", "1f3c6", "1f947", "1f355", "1f354",
      "1f37f", "1f369", "1f37e", "1f942", "1f37b", "2615", "1f680", "1f308",
      "2705", "274c", "1f440", "1f451", "1f48e", "1f4b8",
    ],
  },
  // Added 2026-09-30. Nothing here repeats a sticker from the packs above, and
  // a few codes Noto ships are left out on purpose for a family app (🖕, 🎰).
  {
    slug: "noto-feelings",
    title: "Feelings",
    codes: [
      "1f600", "1f603", "1f604", "1f601", "1f606", "1f605", "1f643", "1f642",
      "1f979", "1f60c", "1f60b", "1f61b", "1f61c", "1f61d", "1f614", "1f62c",
      "1f910", "1fae1", "1f92b", "1fae2", "1f917", "1f928", "1f9d0", "1f612",
      "1f62e_200d_1f4a8", "1f624", "1f620", "1f92c", "1f622", "1f628",
      "1f633", "1f629",
    ],
  },
  {
    slug: "noto-oddballs",
    title: "Oddballs",
    codes: [
      "1f635_200d_1f4ab", "1fae8", "1f974", "1fae9", "1f62a", "1f927",
      "1f637", "1f912", "1f915", "1f925", "1f920", "1f911", "1f913", "1f978",
      "1f608", "1f480", "1f916", "1f47d", "1f47e", "1f479", "1f31a", "1f31d",
      "1f31e", "26c4",
    ],
  },
  {
    slug: "noto-hands",
    title: "Hands",
    codes: [
      "1f44c", "1f918", "1f919", "1f91e", "1f91f", "1faf0", "1f90c", "1f90f",
      "270b", "1f590_fe0f", "1f596", "1f91a", "1faf1", "1faf2", "1faf8",
      "1faf7", "1f450", "1f932", "1f91c", "1f91b", "270a", "1faf3", "1faf4",
      "1faf5", "1f449", "1f448", "261d_fe0f", "1f446", "1f447", "270d_fe0f",
      "1f933", "1f485",
    ],
  },
  {
    slug: "noto-sweet",
    title: "Sweet",
    codes: [
      "1fa75", "1f90e", "1fa76", "1f90d", "1f498", "1f49d", "1f497", "1f493",
      "1f48c", "1f49f", "2763_fe0f", "2764_fe0f_200d_1fa79", "1f63a", "1f638",
      "1f63c", "1f63d", "1f63f", "1f63e", "2b50", "1f31f",
    ],
  },
  {
    slug: "noto-wild",
    title: "Wild",
    codes: [
      "1f43a", "1f42e", "1f98e", "1f409", "1f995", "1f40a", "1f40d", "1f429",
      "1f40e", "1f410", "1f9a5", "1f998", "1f405", "1f98d", "1f43f_fe0f",
      "1f99d", "1f987", "1f426", "1f413", "1f423", "1f425", "1f985", "1f9a9",
      "1f99a", "1f426_200d_1f525", "1f9ad", "1f988", "1facd", "1f421",
      "1fabc", "1f40c", "1f41e",
    ],
  },
  {
    slug: "noto-nature",
    title: "Nature & weather",
    codes: [
      "1f490", "1f339", "1f337", "1f338", "1f33c", "1f342", "1f341", "1f344",
      "1f331", "1f340", "1f335", "1f332", "1f30b", "1f305", "1f30a",
      "2744_fe0f", "1f300", "1f32a_fe0f", "1f4a7", "1f327_fe0f",
      "1f329_fe0f", "26c5", "1fa90", "1f30d", "1f30c", "2604_fe0f", "1f307",
      "1f3d5_fe0f",
    ],
  },
  {
    slug: "noto-food",
    title: "Food & drink",
    codes: [
      "1f353", "1f352", "1f349", "1f34d", "1f34b", "1f951", "1f966", "1f347",
      "1f35e", "1f95e", "1f373", "1f9c0", "1f953", "1f357", "1f32d", "1f968",
      "1f32e", "1f32f", "1f35d", "1f957", "1f35c", "1f361", "1f368", "1f366",
      "1f967", "1f36a", "1f9cb", "1f375", "1fad6", "1f377", "1fad7", "1f379",
    ],
  },
  {
    slug: "noto-play",
    title: "Sports & play",
    codes: [
      "26bd", "26be", "1f3c0", "1f3c9", "1f3be", "1f3f8", "1f3d3", "1f3d2",
      "1f3bf", "26f8_fe0f", "1f6fc", "1f6f9", "26f3", "1f3af", "1f94f",
      "1fa81", "1f3a3", "1f3b1", "1f3b3", "265f_fe0f", "1f3b2", "1fa84",
      "1f3b8", "1f3b7", "1f3ba", "1f3bb", "1f941", "1fa87", "1f3ac", "1f3ad",
      "1f948", "1fa85",
    ],
  },
  {
    slug: "noto-travel",
    title: "Travel & things",
    codes: [
      "1f697", "1f695", "1f68c", "1f682", "1f6b2", "1f3cd_fe0f", "1f3ce_fe0f",
      "1f69c", "26f5", "1f6f6", "2708_fe0f", "1f6eb", "1f6f8", "1f3a2",
      "1f3a1", "1f3a0", "1f5ff", "1f3e0", "1f4bb", "1f4a1", "1f4da", "1f4e6",
      "23f0", "23f3", "1f514", "1f4e3", "1f52e", "1f48d", "2602_fe0f",
      "1f393", "1f4f8",
    ],
  },
  {
    slug: "noto-reactions",
    title: "Reactions",
    codes: [
      "2757", "2753", "2049_fe0f", "203c_fe0f", "1f4ac", "1f5ef_fe0f",
      "26a0_fe0f", "1f6a8", "1f6d1", "1f198", "1f195", "1f193", "1f199",
      "1f197", "1f192", "1f3b6", "267e_fe0f", "262e_fe0f", "262f_fe0f",
      "1f3c1", "1f6a9", "1f3f3_fe0f", "1f4c8", "1f4c9", "1f5d1_fe0f",
      "1f4a3", "2795",
    ],
  },
  {
    slug: "noto-zodiac",
    title: "Zodiac",
    codes: [
      "2648", "2649", "264a", "264b", "264c", "264d", "264e", "264f", "2650",
      "2651", "2652", "2653", "26ce",
    ],
  },
];

/** "2764_fe0f" → "❤️". */
export function emojiForCode(code: string): string {
  return String.fromCodePoint(
    ...code.split("_").map((part) => parseInt(part, 16))
  );
}

/** Creates (or finds) a pack and reports which stickers it already has. */
export const ensureOfficialPack = internalMutation({
  args: { slug: v.string(), title: v.string(), order: v.number() },
  handler: async (ctx, { slug, title, order }) => {
    let pack = await ctx.db
      .query("stickerPacks")
      .withIndex("by_slug", (q) => q.eq("slug", slug))
      .first();
    if (!pack) {
      const id = await ctx.db.insert("stickerPacks", {
        slug,
        title,
        kind: "official",
        author: NOTO_AUTHOR,
        license: NOTO_LICENSE,
        sourceUrl: NOTO_SOURCE,
        order,
        createdAt: Date.now(),
      });
      pack = (await ctx.db.get(id))!;
    } else if (pack.title !== title || pack.order !== order) {
      await ctx.db.patch(pack._id, { title, order });
    }
    const rows = await ctx.db
      .query("stickers")
      .withIndex("by_pack_order", (q) => q.eq("packId", pack._id))
      .collect();
    return { packId: pack._id, have: rows.map((r) => r.emoji) };
  },
});

export const insertOfficialSticker = internalMutation({
  args: {
    packId: v.id("stickerPacks"),
    storageId: v.id("_storage"),
    emoji: v.string(),
    width: v.number(),
    height: v.number(),
    order: v.number(),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("stickers", {
      ...args,
      format: "lottie",
      createdAt: Date.now(),
    });
  },
});

/**
 * Downloads the official packs into storage. Idempotent: a sticker a pack
 * already has is skipped, so a run that failed half-way is finished by running
 * it again. Run once per deployment (both backends):
 *
 *   npx convex run expressions:seedOfficialPacks '{}'
 */
export const seedOfficialPacks = internalAction({
  args: {},
  handler: async (ctx) => {
    const report: Record<string, { added: number; skipped: string[] }> = {};
    for (let p = 0; p < OFFICIAL_PACKS.length; p++) {
      const spec = OFFICIAL_PACKS[p];
      const { packId, have } = await ctx.runMutation(
        internal.expressions.ensureOfficialPack,
        { slug: spec.slug, title: spec.title, order: p }
      );
      const done = new Set(have);
      const skipped: string[] = [];
      let added = 0;
      for (let i = 0; i < spec.codes.length; i++) {
        const code = spec.codes[i];
        const emoji = emojiForCode(code);
        if (done.has(emoji)) continue;
        try {
          const res = await fetch(notoUrl(code));
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          const text = await res.text();
          // A handful of Noto's Lottie files are known to be broken. Parse it
          // here so a bad one is skipped instead of shipped as a sticker that
          // draws nothing.
          const json = JSON.parse(text);
          if (!Array.isArray(json.layers) || json.layers.length === 0) {
            throw new Error("no layers");
          }
          const storageId = await ctx.storage.store(
            new Blob([text], { type: "application/json" })
          );
          await ctx.runMutation(internal.expressions.insertOfficialSticker, {
            packId,
            storageId,
            emoji,
            width: typeof json.w === "number" ? json.w : 512,
            height: typeof json.h === "number" ? json.h : 512,
            order: i,
          });
          added++;
        } catch (e) {
          skipped.push(`${code}: ${(e as Error).message}`);
        }
      }
      report[spec.slug] = { added, skipped };
    }
    return report;
  },
});

/** For an operator: what is seeded. `npx convex run expressions:seedStatus`. */
export const seedStatus = internalQuery({
  args: {},
  handler: async (ctx) => {
    const packs = await ctx.db
      .query("stickerPacks")
      .withIndex("by_kind_order", (q) => q.eq("kind", "official"))
      .collect();
    const out = [];
    for (const pack of packs) {
      const n = (
        await ctx.db
          .query("stickers")
          .withIndex("by_pack_order", (q) => q.eq("packId", pack._id))
          .collect()
      ).length;
      out.push({ slug: pack.slug, stickers: n });
    }
    return out;
  },
});
