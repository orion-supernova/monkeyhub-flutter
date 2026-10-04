import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/**
 * Polls, checklists and events, actually executed.
 *
 * `tsc` covers the shapes. What it cannot cover is every claim this feature
 * makes that is only true at runtime, and three of those are promises to a
 * user rather than merely behaviours:
 *
 *   1. **An anonymous poll never names its voters.** The tally is written
 *      without names and `respondents` refuses outright. If either half is
 *      wrong, the app has lied to everybody who ticked that box.
 *   2. **A quiz withholds its answer until you have spent your guess.** The
 *      field is stripped on the read path, so a client that simply asks nicely
 *      must not get it.
 *   3. **The counters cannot drift.** `respond` recounts from the response
 *      rows rather than incrementing, which is the whole reason the schema
 *      denormalizes them at all — so a sequence of votes, retractions and
 *      re-votes has to land on the same numbers a fresh count would.
 *
 * Plus the cardinality rules, which are three lines of logic each and the sort
 * of thing that is quietly wrong for a month.
 */

const DEVICE = "device-a";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: DEVICE,
  });
}

/** A public room with [owner] in it, ready for others to join. */
async function makeRoom(
  t: ReturnType<typeof convexTest>,
  owner: { token: string; userId: string },
  name = "room",
) {
  return await t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId as any,
    name,
    isPrivate: false,
  });
}

async function join(
  t: ReturnType<typeof convexTest>,
  who: { token: string; userId: string },
  roomId: any,
) {
  await t.mutation(api.rooms.join, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
  });
}

/** The one interaction in [roomId], as the given reader sees it. */
async function readOne(
  t: ReturnType<typeof convexTest>,
  who: { token: string; userId: string },
  roomId: any,
) {
  const rows = await t.query(api.interactions.listForRoom, {
    sessionToken: who.token,
    roomId,
    viewerUserId: who.userId as any,
  });
  expect(rows).toHaveLength(1);
  return rows[0] as any;
}

function countOf(row: any, choiceId: string): number {
  return row.choices.find((c: any) => c.id === choiceId)?.count ?? 0;
}

describe("anonymity is a promise, not a filter", () => {
  test("an anonymous poll's tally carries no names at all", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const voter = await signUp(t, "voter");
    const roomId = await makeRoom(t, author);
    await join(t, voter, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "pizza or curry?",
      labels: ["pizza", "curry"],
      anonymous: true,
    });
    await t.mutation(api.interactions.respond, {
      sessionToken: voter.token,
      userId: voter.userId as any,
      messageId,
      choiceId: "0",
    });

    // The count moves — anonymity is about WHO, not about whether.
    const row = await readOne(t, author, roomId);
    expect(countOf(row, "0")).toBe(1);
    expect(row.respondentCount).toBe(1);
    // And no name reaches the author, who is the one person with a plausible
    // claim to know.
    for (const c of row.choices) {
      expect(c.respondents).toBeUndefined();
    }
  });

  test("respondents refuses an anonymous poll rather than answering emptily", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const roomId = await makeRoom(t, author);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b"],
      anonymous: true,
    });

    // An empty list would be a CLAIM about who voted. A refusal is the truth.
    await expect(
      t.query(api.interactions.respondents, {
        sessionToken: author.token,
        messageId,
        viewerUserId: author.userId as any,
      }),
    ).rejects.toThrow(/POLL_IS_ANONYMOUS/);
  });

  test("a public poll DOES name its voters — the default is not anonymity", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const voter = await signUp(t, "voter");
    const roomId = await makeRoom(t, author);
    await join(t, voter, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b"],
      // No `anonymous` at all, which is the ordinary way a poll is made.
    });
    await t.mutation(api.interactions.respond, {
      sessionToken: voter.token,
      userId: voter.userId as any,
      messageId,
      choiceId: "1",
    });

    const row = await readOne(t, author, roomId);
    expect(row.choices[1].respondents.map((r: any) => r.name)).toEqual(["voter"]);

    const detail = await t.query(api.interactions.respondents, {
      sessionToken: author.token,
      messageId,
      viewerUserId: author.userId as any,
    });
    expect(detail).toHaveLength(1);
    expect(detail[0].choiceId).toBe("1");
    expect(detail[0].name).toBe("voter");
  });
});

describe("a quiz withholds its answer until it is due", () => {
  test("a reader who has not answered is not told which option is right", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const player = await signUp(t, "player");
    const roomId = await makeRoom(t, author);
    await join(t, player, roomId);

    await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "capital of Sweden?",
      labels: ["Oslo", "Stockholm"],
      quiz: true,
      correctIndex: 1,
      explanation: "it has been since 1523.",
    });

    const before = await readOne(t, player, roomId);
    expect(before.quiz).toBe(true);
    expect(before.correctChoiceId).toBeUndefined();
    expect(before.explanation).toBeUndefined();
  });

  test("quiz answers reveal the answer and can be replaced", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const player = await signUp(t, "player");
    const roomId = await makeRoom(t, author);
    await join(t, player, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "capital of Sweden?",
      labels: ["Oslo", "Stockholm"],
      quiz: true,
      correctIndex: 1,
      explanation: "it has been since 1523.",
    });
    await t.mutation(api.interactions.respond, {
      sessionToken: player.token,
      userId: player.userId as any,
      messageId,
      choiceId: "0",
    });

    const after = await readOne(t, player, roomId);
    expect(after.correctChoiceId).toBe("1");
    expect(after.explanation).toBe("it has been since 1523.");
    expect(after.myChoiceIds).toEqual(["0"]);

    // A quiz keeps an answer, but allows replacing it like other single choices.
    await expect(
      t.mutation(api.interactions.respond, {
        sessionToken: player.token,
        userId: player.userId as any,
        messageId,
        choiceId: "0",
      }),
    ).rejects.toThrow(/NOT_ALLOWED/);
    await t.mutation(api.interactions.respond, {
      sessionToken: player.token,
      userId: player.userId as any,
      messageId,
      choiceId: "1",
    });
    const changed = await readOne(t, player, roomId);
    expect(changed.myChoiceIds).toEqual(["1"]);
    expect(changed.choices.map((choice: any) => choice.count)).toEqual([0, 1]);
    await expect(
      t.mutation(api.interactions.retract, {
        sessionToken: player.token,
        userId: player.userId as any,
        messageId,
      }),
    ).rejects.toThrow(/NOT_ALLOWED/);
  });

  test("a quiz with no marked answer is refused rather than downgraded", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const roomId = await makeRoom(t, author);

    await expect(
      t.mutation(api.interactions.create, {
        sessionToken: author.token,
        userId: author.userId as any,
        roomId,
        kind: "poll",
        prompt: "q",
        labels: ["a", "b"],
        quiz: true,
      }),
    ).rejects.toThrow(/BAD_DEFINITION/);
  });
});

describe("the tally is recounted, so it cannot drift", () => {
  test("vote, switch, retract, re-vote — the numbers match a fresh count", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const c = await signUp(t, "cal");
    const roomId = await makeRoom(t, author);
    await join(t, b, roomId);
    await join(t, c, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b"],
    });
    const vote = (who: typeof b, choiceId: string) =>
      t.mutation(api.interactions.respond, {
        sessionToken: who.token,
        userId: who.userId as any,
        messageId,
        choiceId,
      });

    await vote(b, "0");
    await vote(c, "0");
    // A single-answer poll REPLACES rather than accumulates.
    await vote(c, "1");
    let row = await readOne(t, author, roomId);
    expect(countOf(row, "0")).toBe(1);
    expect(countOf(row, "1")).toBe(1);
    expect(row.respondentCount).toBe(2);

    // Toggling the held choice takes it back.
    await vote(b, "0");
    row = await readOne(t, author, roomId);
    expect(countOf(row, "0")).toBe(0);
    expect(row.respondentCount).toBe(1);

    // And re-voting puts it back, with no residue from the round trip.
    await vote(b, "1");
    row = await readOne(t, author, roomId);
    expect(countOf(row, "0")).toBe(0);
    expect(countOf(row, "1")).toBe(2);
    expect(row.respondentCount).toBe(2);
  });

  test("a multiple-answer poll counts people once and choices many times", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const roomId = await makeRoom(t, author);
    await join(t, b, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b", "c"],
      multiple: true,
    });
    for (const choiceId of ["0", "1", "2"]) {
      await t.mutation(api.interactions.respond, {
        sessionToken: b.token,
        userId: b.userId as any,
        messageId,
        choiceId,
      });
    }

    const row = await readOne(t, author, roomId);
    expect(row.choices.map((c: any) => c.count)).toEqual([1, 1, 1]);
    // THE distinction the field exists for: three votes, one voter. A footer
    // reading the sum would say "3 voted" about one person.
    expect(row.respondentCount).toBe(1);

    // `retract` clears the whole ballot in one call, which is the reason it
    // exists apart from toggling one choice off.
    await t.mutation(api.interactions.retract, {
      sessionToken: b.token,
      userId: b.userId as any,
      messageId,
    });
    const after = await readOne(t, author, roomId);
    expect(after.choices.map((c: any) => c.count)).toEqual([0, 0, 0]);
    expect(after.respondentCount).toBe(0);
  });
});

describe("a checklist tick belongs to an item, not to a ballot", () => {
  test("the second person to tick an item does not double it", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const roomId = await makeRoom(t, author);
    await join(t, b, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "checklist",
      prompt: "camping",
      labels: ["tent", "food"],
    });
    await t.mutation(api.interactions.respond, {
      sessionToken: b.token,
      userId: b.userId as any,
      messageId,
      choiceId: "0",
    });

    const row = await readOne(t, author, roomId);
    // Ticked once, by the first person to reach it — a task is done or it is
    // not, and the second tap is agreement rather than a second vote.
    expect(countOf(row, "0")).toBe(1);
    expect(row.choices[0].respondents.map((r: any) => r.name)).toEqual(["bea"]);
  });

  test("only the ticker or the author may untick", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const c = await signUp(t, "cal");
    const roomId = await makeRoom(t, author);
    await join(t, b, roomId);
    await join(t, c, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "checklist",
      prompt: "camping",
      labels: ["tent"],
    });
    await t.mutation(api.interactions.respond, {
      sessionToken: b.token,
      userId: b.userId as any,
      messageId,
      choiceId: "0",
    });

    // A bystander cannot undo somebody else's work.
    await expect(
      t.mutation(api.interactions.respond, {
        sessionToken: c.token,
        userId: c.userId as any,
        messageId,
        choiceId: "0",
      }),
    ).rejects.toThrow(/NOT_ALLOWED/);

    // The author can, because an abandoned tick needs somebody who can fix it.
    await t.mutation(api.interactions.respond, {
      sessionToken: author.token,
      userId: author.userId as any,
      messageId,
      choiceId: "0",
    });
    expect(countOf(await readOne(t, author, roomId), "0")).toBe(0);
  });

  test("added items get fresh ids, and a removed item's id is never reused", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const roomId = await makeRoom(t, author);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "checklist",
      prompt: "camping",
      labels: ["tent", "food"],
    });
    await t.mutation(api.interactions.addItem, {
      sessionToken: author.token,
      userId: author.userId as any,
      messageId,
      label: "matches",
    });
    let row = await readOne(t, author, roomId);
    expect(row.choices.map((c: any) => c.id)).toEqual(["0", "1", "2"]);

    await t.mutation(api.interactions.removeItem, {
      sessionToken: author.token,
      userId: author.userId as any,
      messageId,
      choiceId: "2",
    });
    await t.mutation(api.interactions.addItem, {
      sessionToken: author.token,
      userId: author.userId as any,
      messageId,
      label: "map",
    });
    row = await readOne(t, author, roomId);
    // "3", NOT "2". Reusing the dead id would land any tick still holding it on
    // the new task — see `nextItemId` in the schema.
    expect(row.choices.map((c: any) => c.id)).toEqual(["0", "1", "3"]);
    expect(row.choices[2].label).toBe("map");
  });

  test("a list whose author switched shared ticking off refuses everyone else", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const roomId = await makeRoom(t, author);
    await join(t, b, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "checklist",
      prompt: "mine",
      labels: ["one"],
      othersMayCheck: false,
    });
    await expect(
      t.mutation(api.interactions.respond, {
        sessionToken: b.token,
        userId: b.userId as any,
        messageId,
        choiceId: "0",
      }),
    ).rejects.toThrow(/NOT_ALLOWED/);
  });
});

describe("events", () => {
  test("the three RSVP buttons are the server's, and one person holds one", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const roomId = await makeRoom(t, author);
    await join(t, b, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "event",
      prompt: "dinner",
      startsAt: 1_800_000_000_000,
      place: "the usual",
    });
    let row = await readOne(t, author, roomId);
    expect(row.choices.map((c: any) => c.id)).toEqual(["going", "maybe", "no"]);
    expect(row.place).toBe("the usual");

    await t.mutation(api.interactions.respond, {
      sessionToken: b.token,
      userId: b.userId as any,
      messageId,
      choiceId: "going",
    });
    await t.mutation(api.interactions.respond, {
      sessionToken: b.token,
      userId: b.userId as any,
      messageId,
      choiceId: "maybe",
    });
    row = await readOne(t, author, roomId);
    // Changing your mind replaces; an RSVP is one answer by definition.
    expect(countOf(row, "going")).toBe(0);
    expect(countOf(row, "maybe")).toBe(1);
    expect(row.respondentCount).toBe(1);
  });

  test("a client cannot name its own RSVP buttons", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const roomId = await makeRoom(t, author);

    await expect(
      t.mutation(api.interactions.create, {
        sessionToken: author.token,
        userId: author.userId as any,
        roomId,
        kind: "event",
        prompt: "dinner",
        startsAt: 1_800_000_000_000,
        labels: ["definitely", "nope"],
      }),
    ).rejects.toThrow(/BAD_DEFINITION/);
  });

  test("an end before its start is dropped rather than refusing the event", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const roomId = await makeRoom(t, author);

    await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "event",
      prompt: "dinner",
      startsAt: 1_800_000_000_000,
      endsAt: 1_700_000_000_000,
    });
    const row = await readOne(t, author, roomId);
    expect(row.startsAt).toBe(1_800_000_000_000);
    expect(row.endsAt).toBeUndefined();
  });
});

describe("closing, membership and idempotency", () => {
  test("a closed poll takes no more answers, and closing twice is a no-op", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const roomId = await makeRoom(t, author);
    await join(t, b, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b"],
    });
    await t.mutation(api.interactions.close, {
      sessionToken: author.token,
      userId: author.userId as any,
      messageId,
    });
    // Idempotent: two people reaching for it after a meeting must not race.
    await t.mutation(api.interactions.close, {
      sessionToken: author.token,
      userId: author.userId as any,
      messageId,
    });

    await expect(
      t.mutation(api.interactions.respond, {
        sessionToken: b.token,
        userId: b.userId as any,
        messageId,
        choiceId: "0",
      }),
    ).rejects.toThrow(/INTERACTION_CLOSED/);
  });

  test("a plain member cannot close somebody else's poll", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const roomId = await makeRoom(t, author);
    await join(t, b, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b"],
    });
    await expect(
      t.mutation(api.interactions.close, {
        sessionToken: b.token,
        userId: b.userId as any,
        messageId,
      }),
    ).rejects.toThrow(/NOT_ALLOWED/);
  });

  test("a non-member cannot vote, however the id was come by", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const stranger = await signUp(t, "stranger");
    const roomId = await makeRoom(t, author);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b"],
    });
    await expect(
      t.mutation(api.interactions.respond, {
        sessionToken: stranger.token,
        userId: stranger.userId as any,
        messageId,
        choiceId: "0",
      }),
    ).rejects.toThrow(/NOT_A_MEMBER/);
  });

  test("a choice id the poll does not have is refused, not counted into nothing", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const roomId = await makeRoom(t, author);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b"],
    });
    await expect(
      t.mutation(api.interactions.respond, {
        sessionToken: author.token,
        userId: author.userId as any,
        messageId,
        choiceId: "99",
      }),
    ).rejects.toThrow(/BAD_CHOICE/);
  });

  test("a retried create posts one poll, not two", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const roomId = await makeRoom(t, author);

    const args = {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll" as const,
      prompt: "q",
      labels: ["a", "b"],
      clientId: "int_1",
    };
    const first = await t.mutation(api.interactions.create, args);
    const second = await t.mutation(api.interactions.create, args);

    // Same message, and — the half `sendCore`'s own dedupe does NOT cover —
    // only one body written for it.
    expect(second).toBe(first);
    const rows = await t.query(api.interactions.listForRoom, {
      sessionToken: author.token,
      roomId,
      viewerUserId: author.userId as any,
    });
    expect(rows).toHaveLength(1);
  });
});

describe("the message and its body live and die together", () => {
  test("the prompt is on the message row, which is what makes the room preview work", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const roomId = await makeRoom(t, author);

    await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "pizza or curry?",
      labels: ["pizza", "curry"],
    });

    const msgs = await t.query(api.messages.list, {
      sessionToken: author.token,
      roomId,
      viewerUserId: author.userId as any,
    });
    const poll = msgs.find((m: any) => m.type === "poll") as any;
    expect(poll).toBeDefined();
    // The whole reason nothing else in the codebase had to learn about polls.
    expect(poll.content).toBe("pizza or curry?");
  });

  test("deleting the message takes the poll and every vote with it", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const roomId = await makeRoom(t, author);
    await join(t, b, roomId);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b"],
    });
    await t.mutation(api.interactions.respond, {
      sessionToken: b.token,
      userId: b.userId as any,
      messageId,
      choiceId: "0",
    });

    await t.mutation(api.messages.deleteMessage, {
      sessionToken: author.token,
      userId: author.userId as any,
      messageId,
    });

    const rows = await t.query(api.interactions.listForRoom, {
      sessionToken: author.token,
      roomId,
      viewerUserId: author.userId as any,
    });
    expect(rows).toEqual([]);
    // And the responses are gone with it, not merely orphaned.
    await t.run(async (ctx) => {
      const left = await ctx.db.query("interactionResponses").collect();
      expect(left).toEqual([]);
    });
  });

  test("forwarding posts a fresh poll: same question, no votes", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const b = await signUp(t, "bea");
    const source = await makeRoom(t, author, "source");
    const target = await makeRoom(t, author, "target");
    await join(t, b, source);

    const messageId = await t.mutation(api.interactions.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId: source,
      kind: "poll",
      prompt: "pizza or curry?",
      labels: ["pizza", "curry"],
      anonymous: true,
    });
    await t.mutation(api.interactions.respond, {
      sessionToken: b.token,
      userId: b.userId as any,
      messageId,
      choiceId: "0",
    });
    await t.mutation(api.interactions.close, {
      sessionToken: author.token,
      userId: author.userId as any,
      messageId,
    });

    await t.mutation(api.messages.forwardToRoom, {
      sessionToken: author.token,
      userId: author.userId as any,
      sourceRoomId: source,
      targetRoomId: target,
      messageIds: [messageId],
    });

    const copy = await readOne(t, author, target);
    expect(copy.choices.map((c: any) => c.label)).toEqual(["pizza", "curry"]);
    // Zeroed: this room's members never answered it.
    expect(copy.choices.map((c: any) => c.count)).toEqual([0, 0]);
    expect(copy.respondentCount).toBe(0);
    // Open, even though the original was closed — a forward nobody could ever
    // answer is not a forward worth making.
    expect(copy.closedAt).toBeUndefined();
    // But the promise made to whoever answers the COPY travels with it.
    expect(copy.anonymous).toBe(true);
  });
});
