import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { MAX_REACTIONS_PER_PERSON } from "./reactions";
import { REACTION_COPY_TABLE, reactionCopyFor, reactionLine } from "./notifications";

/**
 * The per-person reaction cap, executed. The client checks first only so its
 * alert can open early; this is the one that has to hold.
 */

const DEVICE = "device-a";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    // One device per person: a deviceId is one handset, and signing in
    // on it signs out whoever was there before.
    deviceId: `device-${username}`,
  });
}

const EMOJI = ["👍", "❤️", "😂", "😮", "😢", "🔥", "👏", "🎉", "🙏", "💯", "🤯"];

describe("reaction cap", () => {
  test("one person stops at the cap; re-adding and others are unaffected", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const other = await signUp(t, "other");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: me.token,
      userId: me.userId as any,
      name: "room",
      isPrivate: false,
    });
    await t.mutation(api.rooms.join, {
      sessionToken: other.token,
      userId: other.userId as any,
      roomId,
    } as any);
    const sent: any = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "hi",
    });
    const messageId = typeof sent === "string" ? sent : sent._id ?? sent.id;
    const react = (who: any, emoji: string) =>
      t.mutation(api.reactions.addReaction, {
        sessionToken: who.token,
        userId: who.userId as any,
        messageId,
        emoji,
      } as any);

    for (const e of EMOJI.slice(0, MAX_REACTIONS_PER_PERSON)) await react(me, e);
    await expect(react(me, EMOJI[MAX_REACTIONS_PER_PERSON])).rejects.toThrow(
      "REACTION_LIMIT",
    );
    // Re-adding one already held is still the idempotent no-op.
    await react(me, EMOJI[0]);
    // The cap is per person: someone else can still react.
    await react(other, EMOJI[MAX_REACTIONS_PER_PERSON]);

    const rows = await t.run(async (ctx) =>
      ctx.db.query("reactions").collect(),
    );
    expect(rows.filter((r) => r.userId === me.userId)).toHaveLength(
      MAX_REACTIONS_PER_PERSON,
    );
    expect(rows).toHaveLength(MAX_REACTIONS_PER_PERSON + 1);
  });

  test("the reaction push goes to the message's author, deep-linked to it", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const other = await signUp(t, "other");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: me.token,
      userId: me.userId as any,
      name: "room",
      isPrivate: false,
    });
    await t.mutation(api.rooms.join, {
      sessionToken: other.token,
      userId: other.userId as any,
      roomId,
    } as any);
    const sent: any = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "see you at 8",
    });
    const messageId = typeof sent === "string" ? sent : sent._id ?? sent.id;
    const react = (who: any, emoji: string) =>
      t.mutation(api.reactions.addReaction, {
        sessionToken: who.token,
        userId: who.userId as any,
        messageId,
        emoji,
      } as any);

    const theirs: any = await react(other, "❤️");
    const plan: any = await t.query(internal.notifications._reactionPushPlan, {
      reactionId: theirs,
    });
    expect(plan.recipientId).toBe(me.userId);
    expect(plan.messageId).toBe(messageId);
    expect(plan.quote.text).toBe("see you at 8");
    expect(reactionLine(reactionCopyFor("tr-TR"), "❤️", plan.quote)).toBe(
      "“see you at 8” mesajına ❤️ tepkisi verdi",
    );
    expect(reactionLine(reactionCopyFor("pt_BR"), "👍", { text: "", kind: "image" })).toBe(
      "Reagiu com 👍 a “📷 Foto”",
    );
    // Every shipped language has a full row.
    for (const [lang, row] of Object.entries(REACTION_COPY_TABLE)) {
      expect(row.quoted, lang).toContain("{emoji}");
      expect(row.quoted, lang).toContain("{quote}");
      expect(row.bare, lang).toContain("{emoji}");
      expect(Object.keys(row.kinds), lang).toHaveLength(8);
    }
    expect(Object.keys(REACTION_COPY_TABLE)).toHaveLength(12);

    // Reacting to your own message tells nobody.
    const mine: any = await react(me, "👍");
    expect(
      await t.query(internal.notifications._reactionPushPlan, { reactionId: mine }),
    ).toBeNull();
  });
});
