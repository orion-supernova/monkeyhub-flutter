/**
 * Chat folders (docs/design/chat-folders.md): the user's own named views of
 * the chat list, Telegram style. A folder is a rule, not a copy: chat types it
 * takes in (DMs, groups), rooms added by hand, rooms kept out by hand, and
 * three "leave out" switches (muted, read, archived). The app applies the rule
 * to the room list it already has, so nothing here reads rooms or messages.
 *
 * Cost (handbook R17): `list` reads at most MAX_FOLDERS rows and re-runs only
 * when this user edits a folder. Saves are one read of the user's folders and
 * one write. No fan-out, no jobs, nothing for users without folders.
 */
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { mutation, query } from "./functions";
import { consume } from "./rateLimit";

/** Folders per user. Telegram's free tier is 10 as well. */
export const MAX_FOLDERS = 10;
/** Rooms added by hand to one folder, and kept out by hand, each. */
export const MAX_FOLDER_ROOMS = 100;
/** Folder name length, in UTF-16 units after trimming. */
export const MAX_FOLDER_NAME = 24;
/** Tag colours the app's palette has (0..TAG_COLORS-1). */
export const TAG_COLORS = 7;

const folderFields = {
  name: v.string(),
  emoji: v.optional(v.string()),
  color: v.optional(v.number()),
  dms: v.boolean(),
  groups: v.boolean(),
  excludeMuted: v.boolean(),
  excludeRead: v.boolean(),
  excludeArchived: v.boolean(),
  include: v.array(v.id("rooms")),
  exclude: v.array(v.id("rooms")),
};

const folderOut = v.object({
  id: v.id("chatFolders"),
  order: v.number(),
  ...folderFields,
});

function out(r: Doc<"chatFolders">) {
  return {
    id: r._id,
    order: r.order,
    name: r.name,
    ...(r.emoji !== undefined ? { emoji: r.emoji } : {}),
    ...(r.color !== undefined ? { color: r.color } : {}),
    dms: r.dms,
    groups: r.groups,
    excludeMuted: r.excludeMuted,
    excludeRead: r.excludeRead,
    excludeArchived: r.excludeArchived,
    include: r.include,
    exclude: r.exclude,
  };
}

/** Same id in both lists: the hand-picked "keep out" wins, as in Telegram. */
function clean(f: {
  name: string;
  emoji?: string;
  color?: number;
  dms: boolean;
  groups: boolean;
  include: Id<"rooms">[];
  exclude: Id<"rooms">[];
}) {
  const name = f.name.trim();
  if (name.length === 0) throw new Error("FOLDER_NAME_REQUIRED");
  if (name.length > MAX_FOLDER_NAME) throw new Error("FOLDER_NAME_TOO_LONG");
  const emoji = f.emoji?.trim() || undefined;
  if (emoji !== undefined && emoji.length > 16) throw new Error("FOLDER_EMOJI_INVALID");
  const color = f.color;
  if (color !== undefined && (!Number.isInteger(color) || color < 0 || color >= TAG_COLORS)) {
    throw new Error("FOLDER_COLOR_INVALID");
  }
  const exclude = [...new Set(f.exclude.map(String))] as Id<"rooms">[];
  const out = new Set(exclude.map(String));
  const include = [...new Set(f.include.map(String))].filter((id) => !out.has(id)) as Id<"rooms">[];
  if (include.length > MAX_FOLDER_ROOMS || exclude.length > MAX_FOLDER_ROOMS) {
    throw new Error("TOO_MANY_FOLDER_ROOMS");
  }
  // A folder that takes in nothing would always be empty.
  if (!f.dms && !f.groups && include.length === 0) throw new Error("FOLDER_EMPTY");
  return { name, emoji, color, include, exclude };
}

async function mine(ctx: { db: any }, userId: Id<"users">): Promise<Doc<"chatFolders">[]> {
  return await ctx.db
    .query("chatFolders")
    .withIndex("by_user_order", (q: any) => q.eq("userId", userId))
    .take(MAX_FOLDERS + 1);
}

/** My folders, in tab order. */
export const list = query({
  args: {},
  returns: v.array(folderOut),
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("chatFolders")
      .withIndex("by_user_order", (q) => q.eq("userId", userId))
      .take(MAX_FOLDERS);
    return rows.map(out);
  },
});

/**
 * Creates a folder (no [id]) at the end of my tabs, or rewrites one of mine.
 * Refuses an 11th folder. Returns the folder's id.
 */
export const save = mutation({
  args: { id: v.optional(v.id("chatFolders")), ...folderFields },
  returns: v.id("chatFolders"),
  handler: async (ctx, args) => {
    const { userId, id } = args;
    await consume(ctx, `chatfolder:${userId}`, 60, 60 * 1000);
    const c = clean(args);
    const fields = {
      name: c.name,
      emoji: c.emoji,
      color: c.color,
      dms: args.dms,
      groups: args.groups,
      excludeMuted: args.excludeMuted,
      excludeRead: args.excludeRead,
      excludeArchived: args.excludeArchived,
      include: c.include,
      exclude: c.exclude,
      updatedAt: Date.now(),
    };
    if (id) {
      const row = await ctx.db.get(id);
      if (!row || row.userId.toString() !== userId.toString()) throw new Error("FOLDER_NOT_FOUND");
      await ctx.db.replace(id, { userId, order: row.order, ...fields });
      return id;
    }
    const rows = await mine(ctx, userId);
    if (rows.length >= MAX_FOLDERS) throw new Error("TOO_MANY_FOLDERS");
    const order = rows.length === 0 ? 0 : rows[rows.length - 1].order + 1;
    return await ctx.db.insert("chatFolders", { userId, order, ...fields });
  },
});

/** Deletes one of my folders. Missing is a no-op. */
export const remove = mutation({
  args: { id: v.id("chatFolders") },
  returns: v.null(),
  handler: async (ctx, { userId, id }) => {
    const row = await ctx.db.get(id);
    if (row && row.userId.toString() === userId.toString()) await ctx.db.delete(id);
    return null;
  },
});

/**
 * Puts my folders in [ids] order. Ids that are not mine are ignored; folders
 * left out keep their place after the listed ones. Writes only rows whose
 * position changes.
 */
export const reorder = mutation({
  args: { ids: v.array(v.id("chatFolders")) },
  returns: v.null(),
  handler: async (ctx, { userId, ids }) => {
    await consume(ctx, `chatfolder:${userId}`, 60, 60 * 1000);
    if (ids.length > MAX_FOLDERS) throw new Error("TOO_MANY_FOLDERS");
    const rows = await mine(ctx, userId);
    const rank = new Map(ids.map((id, i) => [id.toString(), i]));
    const sorted = [...rows].sort((a, b) => {
      const ra = rank.get(a._id.toString()) ?? ids.length + a.order;
      const rb = rank.get(b._id.toString()) ?? ids.length + b.order;
      return ra - rb;
    });
    for (let i = 0; i < sorted.length; i++) {
      if (sorted[i].order !== i) await ctx.db.patch(sorted[i]._id, { order: i });
    }
    return null;
  },
});
