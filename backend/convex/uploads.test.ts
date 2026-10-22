import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { drainDeletions } from "./deletionTestUtils";
import { MAX_FILE_BYTES, MAX_UPLOAD_URLS_PER_HOUR } from "./files";
import schema from "./schema";

/**
 * The server, not the client, decides what may be stored.
 *
 * Before the upload ledger there was no size check, no quota and no limit on
 * upload URLs, and any storage id a user could see could be attached to their
 * own avatar and then deleted by changing it.
 */

afterEach(() => {
  vi.useRealTimers();
});

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

const store = (t: ReturnType<typeof convexTest>, bytes: number, type = "image/jpeg") =>
  t.run((ctx) => ctx.storage.store(new Blob([new Uint8Array(bytes)], { type })));

describe("file ownership", () => {
  test("someone else's file cannot become my avatar, so I cannot delete it", async () => {
    const t = convexTest(schema);
    const victim = await signUp(t, "victim");
    const attacker = await signUp(t, "attacker");
    const photo = await store(t, 1000);
    await t.mutation(api.users.updateAvatar, {
      sessionToken: victim.token,
      userId: victim.userId as any,
      storageId: photo,
    });

    await expect(
      t.mutation(api.users.updateAvatar, {
        sessionToken: attacker.token,
        userId: attacker.userId as any,
        storageId: photo,
      }),
    ).rejects.toThrow("NOT_YOUR_FILE");
    expect(await t.run((ctx) => ctx.db.system.get(photo))).not.toBeNull();
  });

  test("changing my avatar moves its copies on my posts and reactions", async () => {
    // The copies move, and the old file goes, in an `avatar` job.
    vi.useFakeTimers();
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const set = (storageId: any) =>
      t.mutation(api.users.updateAvatar, {
        sessionToken: me.token,
        userId: me.userId as any,
        storageId,
      });
    const first = await store(t, 1000);
    await set(first);

    const ids = await t.run(async (ctx) => {
      const moment = (author: any) =>
        ctx.db.insert("moments", {
          userId: me.userId as any,
          dayKey: "2026-10-22",
          createdAt: 0,
          expiresAt: 1,
          authorName: "me",
          authorUsername: "me",
          ...(author ? { authorAvatarStorageId: author } : {}),
        });
      const withFace = await moment(first);
      // Posted before there was any avatar: stays on initials.
      const bare = await moment(undefined);
      const reaction = await ctx.db.insert("momentReactions", {
        momentId: withFace,
        userId: me.userId as any,
        emoji: "🔥",
        createdAt: 0,
        userAvatarStorageId: first,
      });
      return { withFace, bare, reaction };
    });

    const second = await store(t, 1000);
    await set(second);
    await drainDeletions(t, vi.runAllTimers);

    const after = await t.run(async (ctx) => ({
      withFace: await ctx.db.get(ids.withFace),
      bare: await ctx.db.get(ids.bare),
      reaction: await ctx.db.get(ids.reaction),
      old: await ctx.db.system.get(first),
    }));
    expect(after.withFace?.authorAvatarStorageId).toBe(second);
    expect(after.bare?.authorAvatarStorageId).toBeUndefined();
    expect(after.reaction?.userAvatarStorageId).toBe(second);
    expect(after.old).toBeNull();
  });

  test("a file over the cap is refused", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const huge = await store(t, MAX_FILE_BYTES.avatar + 1);
    await expect(
      t.mutation(api.users.updateAvatar, {
        sessionToken: me.token,
        userId: me.userId as any,
        storageId: huge,
      }),
    ).rejects.toThrow("FILE_TOO_LARGE");
  });
});

describe("upload URLs", () => {
  test("are rate limited per account", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    for (let i = 0; i < MAX_UPLOAD_URLS_PER_HOUR; i++) {
      await t.mutation(api.files.generateUploadUrl, { sessionToken: me.token });
    }
    await expect(
      t.mutation(api.files.generateUploadUrl, { sessionToken: me.token }),
    ).rejects.toThrow("RATE_LIMITED");
  });
});

describe("unclaimed uploads", () => {
  test("are swept after the grace period; claimed ones stay", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const orphan = await store(t, 500);
    const kept = await store(t, 500);
    await t.mutation(api.users.updateAvatar, {
      sessionToken: me.token,
      userId: me.userId as any,
      storageId: kept,
    });

    vi.advanceTimersByTime(7 * 60 * 60 * 1000);
    await t.mutation(internal.files.sweepUnclaimed, {});

    expect(await t.run((ctx) => ctx.db.system.get(orphan))).toBeNull();
    expect(await t.run((ctx) => ctx.db.system.get(kept))).not.toBeNull();
  });
});
