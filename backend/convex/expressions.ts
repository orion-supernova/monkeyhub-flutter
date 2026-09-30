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
 * Every pack the caller can pick from: the official ones in order, then their
 * own personal pack if they have made any stickers.
 *
 * URLs are resolved here so the panel can draw a whole pack from one
 * subscription. ~120 official stickers is ~120 `getUrl` calls — cheap, and the
 * query is cached until a pack changes.
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

/** The caller's recents and favourites, newest first. */
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
    };
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
