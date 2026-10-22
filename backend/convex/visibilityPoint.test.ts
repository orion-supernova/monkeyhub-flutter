import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import schema from "./schema";
import { canSeeAs } from "./visibilityPoint";

const mkUser = (ctx: any, username: string) =>
  ctx.db.insert("users", {
    username,
    name: username,
    passwordHash: "x",
    recoveryKeyHash: "x",
    createdAt: 1,
  } as any);

async function world() {
  const t = convexTest(schema);
  const ids = await t.run(async (ctx) => {
    const subject = await mkUser(ctx, "subject");
    const friend = await mkUser(ctx, "friend");
    const reverse = await mkUser(ctx, "reverse");
    const pending = await mkUser(ctx, "pending");
    const guardian = await mkUser(ctx, "guardian");
    const stranger = await mkUser(ctx, "stranger");
    const fs = (userId: any, friendId: any, status: string) =>
      ctx.db.insert("friendships", { userId, friendId, status, createdAt: 1 } as any);
    await fs(subject, friend, "accepted");
    await fs(reverse, subject, "accepted");
    await fs(pending, subject, "pending");
    await ctx.db.insert("guardianships", {
      guardianId: guardian,
      childId: subject,
      role: "primary",
      createdAt: 1,
    });
    return { subject, friend, reverse, pending, guardian, stranger };
  });
  const can = (viewer: any, level: string | undefined, field: any) =>
    t.run((ctx) => canSeeAs(ctx, viewer, ids.subject, level, field));
  return { ids, can };
}

describe("canSeeAs", () => {
  test("self always sees, even nobody", async () => {
    const { ids, can } = await world();
    expect(await can(ids.subject, "nobody", "status")).toBe(true);
  });

  test("public is visible to anyone, including anonymous", async () => {
    const { ids, can } = await world();
    expect(await can(ids.stranger, "public", "status")).toBe(true);
    expect(await can(null, "public", "lastSeen")).toBe(true);
  });

  test("friends: accepted in either direction only", async () => {
    const { ids, can } = await world();
    expect(await can(ids.friend, "friends", "status")).toBe(true);
    expect(await can(ids.reverse, "friends", "status")).toBe(true);
    expect(await can(ids.pending, "friends", "status")).toBe(false);
    expect(await can(ids.stranger, "friends", "status")).toBe(false);
    expect(await can(null, "friends", "status")).toBe(false);
  });

  test("nobody hides from friends", async () => {
    const { ids, can } = await world();
    expect(await can(ids.friend, "nobody", "status")).toBe(false);
  });

  test("absent level means the field default (friends)", async () => {
    const { ids, can } = await world();
    expect(await can(ids.friend, undefined, "status")).toBe(true);
    expect(await can(ids.stranger, undefined, "lastSeen")).toBe(false);
  });

  test("guardian bypasses nobody for status/lastSeen/avatar, not seen", async () => {
    const { ids, can } = await world();
    expect(await can(ids.guardian, "nobody", "status")).toBe(true);
    expect(await can(ids.guardian, "nobody", "lastSeen")).toBe(true);
    expect(await can(ids.guardian, "nobody", "avatar")).toBe(true);
    expect(await can(ids.guardian, "nobody", "seen")).toBe(false);
  });

  test("the bypass is one way: the child is not the guardian's guardian", async () => {
    const t = convexTest(schema);
    const r = await t.run(async (ctx) => {
      const a = await mkUser(ctx, "a");
      const b = await mkUser(ctx, "b");
      await ctx.db.insert("guardianships", { guardianId: a, childId: b, role: "primary", createdAt: 1 });
      return await canSeeAs(ctx, b, a, "nobody", "status");
    });
    expect(r).toBe(false);
  });
});
