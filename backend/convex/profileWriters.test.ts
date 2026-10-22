import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { startUserDeletion } from "./deletionCore";
import { drainDeletions } from "./deletionTestUtils";
import schema from "./schema";

/**
 * Phase 6 (6B): the `profiles` row is only as good as its writers, so every
 * code path that changes `users.name`, `username`, `avatarStorageId` or
 * `visibility` must call `syncProfile` in the same transaction. The first
 * describe is a static guard; the second proves the behaviour.
 */

// ---------------------------------------------------------------- the guard

/**
 * The rule. Source is cut into chunks at every column-0 declaration
 * (`export const x`, `async function x`, ...). A chunk "writes a profile
 * field" when it contains
 *   - `db.insert("users"`, or
 *   - `db.patch(` / `db.replace(` whose object literal (balanced braces)
 *     has a top-level key `name`, `username`, `avatarStorageId` or `visibility`.
 * Such a chunk must also contain `syncProfile(` (or `tombstoneProfile(`).
 *
 * It is a text scan, not a type check: a patch on another table that happens
 * to have a `name` key is a false positive and goes in ALLOWED with a reason.
 * A new users writer that lives in a chunk with a `syncProfile` call for some
 * other write passes, so keep one writer per function.
 */
const FIELDS = ["name", "username", "avatarStorageId", "visibility"];

/** key -> reason; key is `file:chunkName`. */
const ALLOWED: Record<string, string> = {
  // Patches on the rooms table, which has its own name/avatarStorageId.
  "deletionCore.ts:startRoomDeletion": "patches rooms, not users",
  "roomChangeRequests.ts:applyChange": "patches rooms, not users",
  "rooms.ts:updateRoom": "patches rooms, not users",
  "rooms.ts:updateRoomAvatar": "patches rooms, not users",
  // REAL GAP, outside 6B's file list: patches a system account's
  // users.avatarStorageId when kind === "account". Needs
  // `if (kind === "account") await syncProfile(ctx, account._id)` after the
  // patch. Remove this entry when that lands.
};

function chunks(src: string): { name: string; text: string }[] {
  const lines = src.split("\n");
  const out: { name: string; text: string }[] = [];
  let cur = { name: "(top)", text: "" };
  for (const line of lines) {
    const m = /^(?:export\s+)?(?:default\s+)?(?:async\s+)?(?:const|let|function)\s+(\w+)/.exec(line);
    if (m) {
      out.push(cur);
      cur = { name: m[1], text: "" };
    }
    cur.text += line + "\n";
  }
  out.push(cur);
  return out;
}

/** Text of the first object literal after `from`, or "" when there is none. */
function objectAfter(text: string, from: number): string {
  const open = text.indexOf("{", from);
  if (open < 0) return "";
  let depth = 0;
  for (let i = open; i < text.length; i++) {
    if (text[i] === "{") depth++;
    else if (text[i] === "}" && --depth === 0) return text.slice(open, i + 1);
  }
  return "";
}

/** Keys at depth 1 of an object literal. */
function topKeys(obj: string): string[] {
  const keys: string[] = [];
  let depth = 0;
  let seg = "";
  for (const ch of obj) {
    if (ch === "{" || ch === "(" || ch === "[") depth++;
    if (ch === "}" || ch === ")" || ch === "]") depth--;
    if (depth === 1 && (ch === "," || ch === "{")) {
      seg = "";
      continue;
    }
    if (depth === 1) seg += ch;
    const m = /^\s*(?:\.\.\.)?(\w+)\s*(?::|$|,)/.exec(seg);
    if (m && depth === 1 && ch === ":") keys.push(m[1]);
  }
  return keys;
}

export function profileWrites(text: string): boolean {
  if (/db\.insert\(\s*"users"/.test(text)) return true;
  const re = /db\.(?:patch|replace)\(/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text))) {
    const keys = topKeys(objectAfter(text, m.index));
    if (keys.some((k) => FIELDS.includes(k))) return true;
  }
  return false;
}

export function violations(files: Record<string, string>): string[] {
  const bad: string[] = [];
  for (const [file, src] of Object.entries(files)) {
    for (const c of chunks(src)) {
      if (!profileWrites(c.text)) continue;
      if (/\b(?:syncProfile|tombstoneProfile)\(/.test(c.text)) continue;
      const key = `${file}:${c.name}`;
      if (ALLOWED[key]) continue;
      bad.push(key);
    }
  }
  return bad;
}

// Vite inlines every module's text at transform time, so no node:fs is needed.
const RAW: Record<string, string> = (import.meta as any).glob("./*.ts", {
  query: "?raw",
  import: "default",
  eager: true,
});

function sources(): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [path, text] of Object.entries(RAW)) {
    const f = path.replace("./", "");
    if (f.endsWith(".test.ts") || f.endsWith(".d.ts")) continue;
    // The profile logic itself, and migrations that backfill it.
    if (f === "profilesCore.ts" || f === "profileMigrations.ts") continue;
    out[f] = text;
  }
  return out;
}

describe("static guard: users writers sync the profile", () => {
  test("no function writes a profile field without syncProfile", () => {
    expect(Object.keys(sources()).length).toBeGreaterThan(50);
    expect(violations(sources())).toEqual([]);
  });

  test("the scanner catches an unsynced writer and accepts a synced one", () => {
    const bad = `export const a = mutation({ handler: async (ctx) => {\n await ctx.db.patch(id, { name: "x", other: 1 });\n}});`;
    const good = bad.replace("}});", " await syncProfile(ctx, id);\n}});");
    const unrelated = `export const b = async (ctx) => { await ctx.db.patch(id, { status: "online", lastSeen: 1 }); };`;
    const nested = `export const c = async (ctx) => { await ctx.db.patch(id, { settings: { name: "x" } }); };`;
    const insert = `export const d = async (ctx) => { await ctx.db.insert("users", { username: "u" }); };`;
    expect(violations({ "a.ts": bad })).toEqual(["a.ts:a"]);
    expect(violations({ "a.ts": good })).toEqual([]);
    expect(violations({ "a.ts": unrelated })).toEqual([]);
    expect(violations({ "a.ts": nested })).toEqual([]);
    expect(violations({ "a.ts": insert })).toEqual(["a.ts:d"]);
  });
});

// ------------------------------------------------------------- behaviour

type T = ReturnType<typeof convexTest>;

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

async function signUp(t: T, username: string) {
  const u = await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
  return { ...u, username };
}
const as = (w: { token: string; userId: any }) => ({ sessionToken: w.token, userId: w.userId });
const profileOf = (t: T, userId: any) =>
  t.run((ctx: any) =>
    ctx.db.query("profiles").withIndex("by_user", (q: any) => q.eq("userId", userId)).collect(),
  ) as Promise<any[]>;

describe("profile writers", () => {
  test("signup creates the profile", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "alice");
    const rows = await profileOf(t, me.userId);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ name: "alice", username: "alice" });
    expect(rows[0].deleted).toBeUndefined();
  });

  test("a rename updates the profile and moves updatedAt forward", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "alice");
    const before = (await profileOf(t, me.userId))[0];
    await t.mutation(api.users.updateProfile, { ...as(me), name: "Alice B" } as any);
    const after = (await profileOf(t, me.userId))[0];
    expect(after.name).toBe("Alice B");
    expect(after.updatedAt).toBeGreaterThan(before.updatedAt);
  });

  test("a username change updates the profile", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "alice");
    await t.mutation(internal.users.applyUsernameChange, { userId: me.userId, username: "alicia" } as any);
    const [row] = await profileOf(t, me.userId);
    expect(row.username).toBe("alicia");
  });

  test("an avatar change updates the profile", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "alice");
    const file = await t.run((ctx: any) =>
      ctx.storage.store(new Blob([new Uint8Array(32)], { type: "image/jpeg" })),
    );
    await t.mutation(api.users.updateAvatar, { ...as(me), storageId: file } as any);
    const [row] = await profileOf(t, me.userId);
    expect(row.avatarStorageId).toBe(file);
  });

  test("tightening avatar visibility updates avatarLevel", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "alice");
    await t.mutation(api.users.updateVisibility, { ...as(me), avatar: "nobody" } as any);
    const [row] = await profileOf(t, me.userId);
    expect(row.avatarLevel).toBe("nobody");
  });

  test("account deletion tombstones the profile", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "alice");
    await t.mutation(api.users.updateProfile, { ...as(me), name: "Alice" } as any);
    await t.run((ctx: any) => startUserDeletion(ctx, me.userId));
    await drainDeletions(t, vi.runAllTimers);
    const [row] = await profileOf(t, me.userId);
    expect(row).toMatchObject({ deleted: true, name: "", username: "" });
    expect(row.avatarStorageId).toBeUndefined();
  });
});
