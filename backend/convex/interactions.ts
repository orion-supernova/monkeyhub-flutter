import { mutation, query } from "./functions";
import { v } from "convex/values";
import { sendCore, throttleSend } from "./messages";
import { isAdminRole, roleOf } from "./roomAdmin";
import { assertRoomAllowsById } from "./roomPolicy";
import { canReadRoom } from "./roomAccess";
import { ERR_FILTER_BLOCKED, hasHit } from "./contentFilter";

// `purgeInteraction` and `forkInteraction` deliberately live in
// `interactionCore.ts` and not here — see that file's header for the cycle
// they would otherwise close between this module and `messages.ts`.

/**
 * Polls, checklists and events — the messages a room ANSWERS.
 *
 * Three kinds over one table and one mutation each way, because they are the
 * same object wearing different words: a prompt, a fixed set of choices, and a
 * record of who picked what. See `schema.ts:messageInteractions` for why the
 * definition lives beside the message rather than on it, and why the tally is
 * recounted rather than incremented.
 *
 * ## The shape of every mutation here
 *
 * All of them resolve the interaction from a `messageId` the client holds,
 * re-check room membership against the CURRENT roster, apply the kind's own
 * rule, write to `interactionResponses`, and then recount. None of them trusts
 * a count, a name, or a choice id it was handed: `respond` matches the choice
 * against the stored definition, `recount` derives every number from the
 * response rows, and the respondent names come from the row the server wrote
 * at response time.
 *
 * Membership is re-checked on every call rather than at creation, for the
 * reason `updateLiveLocation` re-runs `guardOutgoing` on every fix: a poll can
 * outlive somebody's membership by months, and a vote is a write into a room.
 */

// ── Limits ──────────────────────────────────────────────────────────────────
//
// Every one of these is enforced here and not merely in the compose sheet.
// A client is a thing anybody can write.

/** Longest question, checklist title or event name. Matches nothing else in
 * the schema on purpose — this becomes `messages.content`, which is already
 * unbounded, but a 40kb "question" would be a room card nobody can read and a
 * push body nothing can render. */
const MAX_PROMPT = 300;
/** Longest single option, item or place. */
const MAX_LABEL = 100;
/** Longest quiz explanation. */
const MAX_EXPLANATION = 200;

const MIN_POLL_OPTIONS = 2;
const MAX_POLL_OPTIONS = 12;
/** A checklist may be created with one item and grown to this. */
const MAX_CHECKLIST_ITEMS = 30;

/**
 * How many respondents a choice carries inline.
 *
 * The card shows this many faces and then a "+N"; the rest come from
 * [respondents] when somebody taps through. A cap rather than the whole list
 * because this array is rewritten on every single response, and an unbounded
 * one would make a poll in a large room a document that grows without limit
 * and is patched on every vote.
 *
 * Twelve rather than three (which is what a reaction bubble shows) because an
 * RSVP card's entire job is to say who is coming, and a list that elides at
 * three answers that question for almost nobody.
 */
const RESPONDENT_PREVIEW_CAP = 12;

/**
 * How many interactions the room's live subscription carries.
 *
 * Matched to `messages:list`'s own `limit` of 100 deliberately: that query is
 * the live window on a room, and this is the live window on the state of what
 * is inside it. An interaction older than that is reached the same way the
 * message carrying it is — by paging — and its state arrives the same way too,
 * through the one-shot [stateForMessages] rather than a subscription. The two
 * halves of an old page are then consistent: neither is live, and neither
 * pretends to be.
 */
const ROOM_STATE_LIMIT = 100;

/** RSVP statuses. Server-owned, not client-supplied: an event's three buttons
 * are the feature, and a client naming its own would be a client inventing a
 * fourth answer nobody else's app can render. */
const RSVP_CHOICES = [
  { id: "going", label: "going" },
  { id: "maybe", label: "maybe" },
  { id: "no", label: "no" },
] as const;

export const ERR_NOT_FOUND = "INTERACTION_NOT_FOUND";
export const ERR_CLOSED = "INTERACTION_CLOSED";
export const ERR_NOT_A_MEMBER = "NOT_A_MEMBER";
export const ERR_NOT_ALLOWED = "NOT_ALLOWED";
export const ERR_BAD_CHOICE = "BAD_CHOICE";
export const ERR_BAD_DEFINITION = "BAD_DEFINITION";
export const ERR_ANONYMOUS = "POLL_IS_ANONYMOUS";
export const ERR_TOO_MANY_ITEMS = "TOO_MANY_ITEMS";

// ── Helpers ─────────────────────────────────────────────────────────────────

/** Trims and clamps one piece of user text, and refuses an empty one.
 *
 * Clamps rather than throws on length for the same reason `sanitizeFormatting`
 * does: a question one character over a limit the user was never shown is not
 * a failed send, it is a question with a character missing. Emptiness IS
 * refused, because a poll option with no words is a button nobody can read. */
function text(raw: unknown, max: number, required: boolean): string {
  const s = typeof raw === "string" ? raw.trim() : "";
  if (s.length === 0) {
    if (required) throw new Error(ERR_BAD_DEFINITION);
    return "";
  }
  return s.slice(0, max);
}

/**
 * The interaction for a message, plus the message itself.
 *
 * Resolved together on every call because neither is enough alone: the
 * interaction holds the rules, and the message holds the room the caller has
 * to be in. Returns the pair or throws — no caller here has a sensible "it
 * wasn't there" branch, unlike `updateLiveLocation` where a finished share is
 * an expected answer.
 */
async function resolve(ctx: any, messageId: any) {
  const msg = await ctx.db.get(messageId);
  if (!msg) throw new Error(ERR_NOT_FOUND);
  const interaction = await ctx.db
    .query("messageInteractions")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .first();
  if (!interaction) throw new Error(ERR_NOT_FOUND);
  return { msg, interaction };
}

/**
 * The caller's membership row, or a refusal.
 *
 * Deliberately NOT `guardOutgoing`: answering a poll is not sending a message.
 * The child media and location gates have nothing to say about a tick box, and
 * a DM block cannot apply — you cannot be in a room with someone you blocked
 * and be able to see their poll but not answer it. What DOES apply is
 * membership, and it is checked against the roster as it is now.
 */
async function assertMember(ctx: any, roomId: any, userId: any) {
  const membership = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId)
    )
    .first();
  if (!membership) throw new Error(ERR_NOT_A_MEMBER);
  return membership;
}

/** The display name to snapshot onto a response row. Read from `users` here
 * and NEVER inside a reactive query — see the note on
 * `interactionResponses.userName`. */
async function nameOf(ctx: any, userId: any): Promise<string> {
  const user = await ctx.db.get(userId);
  return (user?.displayName ?? user?.username ?? "unknown") as string;
}

/**
 * Whether [userId] may end this interaction or edit its definition.
 *
 * The author, or a room admin. Admins are included because an interaction is
 * room furniture once it is posted — a poll left open by someone who has gone
 * quiet, or a checklist nobody can close, is exactly the kind of thing the
 * people who run a room are for. It is deliberately NOT extended to deleting
 * the message, which stays sender-only (see `messages.deleteMessage`): ending
 * a poll settles it, removing it erases what people said.
 */
async function mayAdminister(
  ctx: any,
  interaction: any,
  roomId: any,
  userId: any
): Promise<boolean> {
  if (interaction.createdBy.toString() === userId.toString()) return true;
  return isAdminRole(await roleOf(ctx, roomId, userId));
}

/**
 * Rebuilds this interaction's whole tally from its response rows.
 *
 * THE reason the stored counts cannot drift. Nothing anywhere increments: every
 * write path ends here, and this derives each number from the rows that justify
 * it, inside the same transaction that changed them. A counter that is a pure
 * function of the set it summarises has the same relationship to that set as
 * `galleryBucket` has to the message it describes — it cannot be stale, only
 * wrong in a way that a re-run fixes.
 *
 * Cost is one prefix scan of `by_message_user` per response, which is bounded by
 * the room's roster times the number of options. That is the trade named in the
 * schema header: the writer pays, once, instead of every reader paying on every
 * refire.
 *
 * [anonymous] is read off the row rather than passed, so there is exactly one
 * place that decides whether names are written — a caller that forgot the flag
 * would be a caller that de-anonymised a poll.
 */
async function recount(ctx: any, interaction: any) {
  const rows = await ctx.db
    .query("interactionResponses")
    .withIndex("by_message_user", (q: any) =>
      q.eq("messageId", interaction.messageId)
    )
    .collect();

  const anonymous = interaction.anonymous === true;
  const byChoice = new Map<string, any[]>();
  const people = new Set<string>();
  for (const r of rows) {
    people.add(r.userId.toString());
    const bucket = byChoice.get(r.choiceId);
    if (bucket) bucket.push(r);
    else byChoice.set(r.choiceId, [r]);
  }

  const choices = interaction.choices.map((choice: any) => {
    const bucket = (byChoice.get(choice.id) ?? []).sort(
      (a: any, b: any) => a.createdAt - b.createdAt
    );
    return {
      id: choice.id,
      label: choice.label,
      count: bucket.length,
      // Absent, not empty, when anonymous — see the schema comment. Also
      // absent when nobody has picked it, so the field stays sparse and a
      // fresh poll's row carries no empty arrays.
      ...(anonymous || bucket.length === 0
        ? {}
        : {
            respondents: bucket
              .slice(0, RESPONDENT_PREVIEW_CAP)
              .map((r: any) => ({
                userId: r.userId,
                name: r.userName,
                at: r.createdAt,
              })),
          }),
    };
  });

  await ctx.db.patch(interaction._id, {
    choices,
    respondentCount: people.size,
  });
}

/**
 * What a given viewer is allowed to see of an interaction.
 *
 * One field is withheld and it is the quiz answer. Everything else on the row
 * is already safe by construction — an anonymous poll's names were never
 * written — which is why this is short and why the schema prefers not writing
 * over stripping wherever it can. Here it cannot: the server has to know the
 * correct option to mark anyone right.
 *
 * Written as "add the answer when it is due" rather than "delete it when it
 * isn't", so a field added to this table later is withheld by accident rather
 * than disclosed by accident.
 *
 * The answer becomes due when the viewer has answered — they can now see the result — or when the quiz is closed, which is what closing means.
 */
function sanitizeInteraction(
  interaction: any,
  viewerAnswered: boolean
): any {
  if (interaction.kind !== "poll" || interaction.quiz !== true) {
    return interaction;
  }
  const { correctChoiceId, explanation, ...rest } = interaction;
  const revealed = viewerAnswered || interaction.closedAt !== undefined;
  return revealed
    ? { ...rest, correctChoiceId, explanation }
    : rest;
}

// ── Creation ────────────────────────────────────────────────────────────────

/**
 * Posts an interactive message: the `messages` row and its body, atomically.
 *
 * Routed through `sendCore` rather than inserting a message here, so a poll
 * takes the identical path a typed sentence takes — the membership check, the
 * child guard, the DM-block check, the reply tether, the Chamber-of-Secrets
 * `expiresAt` schedule, the `rooms.lastMessage` patch and the push. That is the
 * precedent `scheduledMessages:release` sets and the reason it exists: a second
 * way into a room is a second place for the guard to be forgotten.
 *
 * `content` is the prompt, and the whole reason nothing else in the codebase
 * had to learn about polls. See the schema header.
 *
 * ## Idempotency
 *
 * `sendCore` dedupes on `clientId` and returns the EXISTING message id on a
 * retry, so the interaction row has to be probed rather than assumed absent —
 * otherwise the retry of a send that actually landed writes a second body for
 * the same message and `resolve` starts picking whichever `.first()` returns.
 * Probing is what makes a retry indistinguishable from success, which is what
 * the caller already believes.
 */
export const create = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    kind: v.string(), // "poll" | "checklist" | "event"
    // The question, the checklist title, or the event name.
    prompt: v.string(),
    // Poll options or checklist items, in order. Ignored — and refused if
    // present — for an event, whose three choices are server-owned.
    labels: v.optional(v.array(v.string())),
    // Poll
    multiple: v.optional(v.boolean()),
    anonymous: v.optional(v.boolean()),
    quiz: v.optional(v.boolean()),
    // Index into [labels], not a choice id: the client is naming one of the
    // options it just sent, and it has no ids yet. Resolved to an id below.
    correctIndex: v.optional(v.number()),
    explanation: v.optional(v.string()),
    // Checklist
    othersMayCheck: v.optional(v.boolean()),
    othersMayAdd: v.optional(v.boolean()),
    // Event
    startsAt: v.optional(v.number()),
    endsAt: v.optional(v.number()),
    place: v.optional(v.string()),
    // Carried straight through to `sendCore`.
    replyToId: v.optional(v.id("messages")),
    senderName: v.optional(v.string()),
    clientId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const {
      roomId,
      userId,
      kind,
      prompt,
      labels,
      multiple,
      anonymous,
      quiz,
      correctIndex,
      explanation,
      othersMayCheck,
      othersMayAdd,
      startsAt,
      endsAt,
      place,
      replyToId,
      senderName,
      clientId,
    } = args;

    await throttleSend(ctx, userId, 1);
    if (kind !== "poll" && kind !== "checklist" && kind !== "event") {
      throw new Error(ERR_BAD_DEFINITION);
    }
    const promptText = text(prompt, MAX_PROMPT, true);

    // Build the choices before writing anything, so a malformed definition
    // fails before a message exists. The alternative — post, then validate —
    // leaves a `poll`-typed message with no body, which renders as a prompt
    // with no buttons and can only be deleted.
    let choices: { id: string; label: string; count: number }[];
    let extra: Record<string, any> = {};

    if (kind === "event") {
      // Server-owned, and the client's `labels` are refused rather than
      // ignored: silently dropping them would let a client believe it had
      // customised the buttons.
      if (labels !== undefined) throw new Error(ERR_BAD_DEFINITION);
      if (
        typeof startsAt !== "number" ||
        !Number.isFinite(startsAt) ||
        startsAt <= 0
      ) {
        throw new Error(ERR_BAD_DEFINITION);
      }
      // An end before its start is the one combination that cannot be
      // rendered as anything. Dropped rather than refused, matching how
      // `sendCore` treats a nonsense `locationAccuracyM`: the event the user
      // meant still gets posted, it just doesn't claim to end.
      const cleanEnd =
        typeof endsAt === "number" && Number.isFinite(endsAt) && endsAt > startsAt
          ? endsAt
          : undefined;
      choices = RSVP_CHOICES.map((c) => ({ id: c.id, label: c.label, count: 0 }));
      extra = {
        startsAt,
        ...(cleanEnd !== undefined ? { endsAt: cleanEnd } : {}),
        ...(place !== undefined
          ? { place: text(place, MAX_LABEL * 2, false) || undefined }
          : {}),
      };
    } else {
      const raw = (labels ?? [])
        .map((l) => text(l, MAX_LABEL, false))
        .filter((l) => l.length > 0);
      // Option labels are text every member reads, and skipped the filter.
      if (raw.some((l) => hasHit(l))) throw new Error(ERR_FILTER_BLOCKED);
      const min = kind === "poll" ? MIN_POLL_OPTIONS : 1;
      const max = kind === "poll" ? MAX_POLL_OPTIONS : MAX_CHECKLIST_ITEMS;
      if (raw.length < min || raw.length > max) {
        throw new Error(ERR_BAD_DEFINITION);
      }
      // Ids are ordinals at creation and stay put forever. A checklist's later
      // items continue the sequence from `nextItemId` rather than from
      // `choices.length`, so a removed item never lets an id be reused — see
      // `addItem`.
      choices = raw.map((label, i) => ({ id: String(i), label, count: 0 }));

      if (kind === "poll") {
        const isQuiz = quiz === true;
        extra = {
          ...(multiple === true && !isQuiz ? { multiple: true } : {}),
          ...(anonymous === true ? { anonymous: true } : {}),
          ...(isQuiz ? { quiz: true } : {}),
        };
        if (isQuiz) {
          // A quiz without an answer is not a quiz. Refused rather than
          // downgraded to a plain poll, because the sender explicitly asked
          // for the mode where being wrong means something.
          if (
            typeof correctIndex !== "number" ||
            !Number.isInteger(correctIndex) ||
            correctIndex < 0 ||
            correctIndex >= choices.length
          ) {
            throw new Error(ERR_BAD_DEFINITION);
          }
          extra.correctChoiceId = choices[correctIndex].id;
          const note = text(explanation, MAX_EXPLANATION, false);
          if (note.length > 0) extra.explanation = note;
        }
      } else {
        // Both default ON, so the stored fields are written only when the
        // author turned one OFF. That keeps the row sparse and makes the read
        // side `!== false` rather than `=== true` — which is what lets a row
        // written before either flag existed keep the shared behaviour.
        extra = {
          ...(othersMayCheck === false ? { othersMayCheck: false } : {}),
          ...(othersMayAdd === false ? { othersMayAdd: false } : {}),
          nextItemId: choices.length,
        };
      }
    }

    // Everything a typed message does, including refusing the send outright if
    // the room, the guardian policy or a block says no.
    const messageId = await sendCore(ctx, {
      roomId,
      userId,
      content: promptText,
      type: kind,
      senderName,
      replyToId,
      clientId,
    });

    // The retry case — see the header. `sendCore` handed back a message that
    // already exists, so its body does too.
    const existing = await ctx.db
      .query("messageInteractions")
      .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
      .first();
    if (existing) return messageId;

    await ctx.db.insert("messageInteractions", {
      messageId,
      // From the argument the guard above validated, not from a client field
      // that could name a different room.
      roomId,
      kind,
      createdBy: userId,
      createdAt: Date.now(),
      choices,
      respondentCount: 0,
      ...extra,
    });

    return messageId;
  },
});

// ── Responding ──────────────────────────────────────────────────────────────

/**
 * Records one answer: a vote, a tick, or an RSVP.
 *
 * One mutation for all three kinds, because the differences are three rules
 * about cardinality and one about permission, not three implementations:
 *
 *   poll        many rows per voter when `multiple`, otherwise one
 *   event       exactly one row per member — an RSVP replaces, never adds
 *   checklist   at most one row per ITEM, from anybody
 *
 * The checklist case is the one that is not per-user, and that is what a
 * checklist means: a task is done or it isn't, and the second person to tick it
 * is agreeing rather than voting. Their tick is dropped and the first ticker
 * keeps the credit — which also makes a double-tap from two devices harmless.
 *
 * Toggling is deliberate on every kind: re-sending a choice you already hold
 * takes it back. It is what makes one control do "vote" and "retract", and the
 * exception is a quiz: its answer can be replaced but never removed.
 */
export const respond = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    choiceId: v.string(),
  },
  handler: async (ctx, { messageId, userId, choiceId }) => {
    const { msg, interaction } = await resolve(ctx, messageId);
    await assertMember(ctx, msg.roomId, userId);
    // Answering is visible to the room, so the posting policy decides whether
    // members may do it here. Retracting stays open. See `roomPolicy.ts`.
    await assertRoomAllowsById(ctx, msg.roomId, userId, {
      actions: ["interact"],
    });
    if (interaction.closedAt !== undefined) throw new Error(ERR_CLOSED);

    // Matched against the STORED definition, never taken on faith. A choice id
    // the client made up would otherwise create a response bucket that no
    // option displays — invisible votes that still move `respondentCount`.
    const choice = interaction.choices.find((c: any) => c.id === choiceId);
    if (!choice) throw new Error(ERR_BAD_CHOICE);

    const isAuthor = interaction.createdBy.toString() === userId.toString();
    if (
      interaction.kind === "checklist" &&
      interaction.othersMayCheck === false &&
      !isAuthor
    ) {
      throw new Error(ERR_NOT_ALLOWED);
    }

    // This user's whole ballot on this message, in one prefix scan.
    const mine = await ctx.db
      .query("interactionResponses")
      .withIndex("by_message_user", (q: any) =>
        q.eq("messageId", messageId).eq("userId", userId)
      )
      .collect();
    const held = mine.find((r: any) => r.choiceId === choiceId);

    if (interaction.kind === "checklist") {
      // Per-item, not per-user: find whoever holds this item, if anyone.
      const holders = await ctx.db
        .query("interactionResponses")
        .withIndex("by_message_user", (q: any) => q.eq("messageId", messageId))
        .collect();
      const holder = holders.find((r: any) => r.choiceId === choiceId);
      if (holder) {
        // Untick — but only by the person who ticked it, or by someone who
        // could administer the list. A shared checklist where anybody may undo
        // anybody's tick is a list two people can fight over silently; this way
        // undoing somebody else's work is an admin act, and doing your own is
        // just a second tap.
        const ownTick = holder.userId.toString() === userId.toString();
        if (!ownTick && !(await mayAdminister(ctx, interaction, msg.roomId, userId))) {
          throw new Error(ERR_NOT_ALLOWED);
        }
        await ctx.db.delete(holder._id);
      } else {
        await ctx.db.insert("interactionResponses", {
          messageId,
          roomId: msg.roomId,
          userId,
          choiceId,
          userName: await nameOf(ctx, userId),
          createdAt: Date.now(),
        });
      }
      await recount(ctx, interaction);
      return { ok: true };
    }

    if (held) {
      // A quiz answer can be replaced, but cannot be toggled off.
      if (interaction.quiz === true) throw new Error(ERR_NOT_ALLOWED);
      await ctx.db.delete(held._id);
      await recount(ctx, interaction);
      return { ok: true };
    }

    // Single-answer kinds replace rather than accumulate: an event RSVP is one
    // answer by definition, and so is a poll that isn't `multiple`. Done as
    // delete-then-insert in one transaction rather than a patch, so the new
    // answer gets a fresh `createdAt` and sorts into the respondents preview
    // where the person actually answered.
    const singleAnswer =
      interaction.kind === "event" || interaction.multiple !== true;
    if (singleAnswer) {
      for (const r of mine) await ctx.db.delete(r._id);
    }

    await ctx.db.insert("interactionResponses", {
      messageId,
      roomId: msg.roomId,
      userId,
      choiceId,
      userName: await nameOf(ctx, userId),
      createdAt: Date.now(),
    });
    await recount(ctx, interaction);
    return { ok: true };
  },
});

/**
 * Takes back every answer this user holds on one interaction.
 *
 * Distinct from re-sending a choice to [respond], which toggles exactly one:
 * a `multiple` poll needs a way to clear a ballot without tapping each option
 * back off, and "retract vote" is one control rather than six.
 *
 * A no-op — not an error — when there is nothing to retract. The client offers
 * this off state it may have held for a while, and "you already had no vote" is
 * the outcome the user wanted either way.
 */
export const retract = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const { msg, interaction } = await resolve(ctx, messageId);
    await assertMember(ctx, msg.roomId, userId);
    if (interaction.closedAt !== undefined) throw new Error(ERR_CLOSED);
    // Same rule as the toggle path, and stated here as well rather than left
    // implicit: there is no way to un-answer a quiz.
    if (interaction.quiz === true) throw new Error(ERR_NOT_ALLOWED);
    // A checklist tick belongs to an item, not to a ballot — "retract all my
    // answers" has no meaning on one, and letting it through would let a
    // member clear every tick they had contributed in one call.
    if (interaction.kind === "checklist") throw new Error(ERR_NOT_ALLOWED);

    const mine = await ctx.db
      .query("interactionResponses")
      .withIndex("by_message_user", (q: any) =>
        q.eq("messageId", messageId).eq("userId", userId)
      )
      .collect();
    if (mine.length === 0) return { ok: true };
    for (const r of mine) await ctx.db.delete(r._id);
    await recount(ctx, interaction);
    return { ok: true };
  },
});

// ── Editing the definition ──────────────────────────────────────────────────

/**
 * Adds one item to a checklist.
 *
 * The only definition edit any kind allows, and only this kind: a poll that
 * grew an option after people had voted would redistribute percentages under a
 * result somebody has already read, and an event that moved its own date would
 * be a message that changed what it said after it was sent. A checklist is the
 * one shape where "and one more thing" is the ordinary case.
 *
 * The new id comes from `nextItemId`, a monotone counter, and never from
 * `choices.length`. Deriving it from the length would reuse the id of an item
 * that had been removed, and the removed item's ticks — which
 * `interactionResponses` still holds if the delete raced a tick — would land on
 * the new one.
 */
export const addItem = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    label: v.string(),
  },
  handler: async (ctx, { messageId, userId, label }) => {
    const { msg, interaction } = await resolve(ctx, messageId);
    await assertMember(ctx, msg.roomId, userId);
    // Adding an item is writing words into the room. See `respond`.
    await assertRoomAllowsById(ctx, msg.roomId, userId, {
      actions: ["interact"],
    });
    if (interaction.kind !== "checklist") throw new Error(ERR_NOT_ALLOWED);
    if (interaction.closedAt !== undefined) throw new Error(ERR_CLOSED);

    const isAuthor = interaction.createdBy.toString() === userId.toString();
    if (interaction.othersMayAdd === false && !isAuthor) {
      throw new Error(ERR_NOT_ALLOWED);
    }
    if (interaction.choices.length >= MAX_CHECKLIST_ITEMS) {
      throw new Error(ERR_TOO_MANY_ITEMS);
    }

    const clean = text(label, MAX_LABEL, true);
    if (hasHit(clean)) throw new Error(ERR_FILTER_BLOCKED);
    // `?? choices.length` covers rows written before the counter existed. It is
    // the one case where reusing the length is safe: such a list has never had
    // an item removed, because nothing could remove one.
    const nextId = (interaction.nextItemId ?? interaction.choices.length) as number;

    await ctx.db.patch(interaction._id, {
      choices: [
        ...interaction.choices,
        { id: String(nextId), label: clean, count: 0 },
      ],
      nextItemId: nextId + 1,
    });
    return { ok: true };
  },
});

/**
 * Removes one item from a checklist, and the tick it may be carrying.
 *
 * Author or room admin only, unlike ticking: adding to a shared list is
 * collaboration, and deleting from one is editing what somebody else wrote.
 *
 * The last item cannot be removed — an empty checklist is a message that shows
 * a title and nothing at all, which reads as broken rather than as empty.
 */
export const removeItem = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    choiceId: v.string(),
  },
  handler: async (ctx, { messageId, userId, choiceId }) => {
    const { msg, interaction } = await resolve(ctx, messageId);
    await assertMember(ctx, msg.roomId, userId);
    if (interaction.kind !== "checklist") throw new Error(ERR_NOT_ALLOWED);
    if (interaction.closedAt !== undefined) throw new Error(ERR_CLOSED);
    if (!(await mayAdminister(ctx, interaction, msg.roomId, userId))) {
      throw new Error(ERR_NOT_ALLOWED);
    }
    if (interaction.choices.length <= 1) throw new Error(ERR_NOT_ALLOWED);
    if (!interaction.choices.some((c: any) => c.id === choiceId)) {
      throw new Error(ERR_BAD_CHOICE);
    }

    // The tick first, then the item. The other order leaves a response row
    // pointing at a choice the definition no longer has, which `recount` would
    // then count into nothing — a `respondentCount` including somebody whose
    // answer is invisible.
    const rows = await ctx.db
      .query("interactionResponses")
      .withIndex("by_message_user", (q: any) => q.eq("messageId", messageId))
      .collect();
    for (const r of rows) {
      if (r.choiceId === choiceId) await ctx.db.delete(r._id);
    }

    const remaining = interaction.choices.filter((c: any) => c.id !== choiceId);
    await ctx.db.patch(interaction._id, { choices: remaining });
    // Re-derived from the surviving rows rather than decremented, so a person
    // whose only tick was on the removed item stops counting as a respondent.
    await recount(ctx, { ...interaction, choices: remaining });
    return { ok: true };
  },
});

/**
 * Ends an interaction: no more answers, and a quiz's answer becomes public.
 *
 * One-way. There is no reopen, because "final" is the only thing this
 * communicates and a reopen would make it a lie — a reader who screenshotted a
 * closed poll would have a picture of a result that later changed.
 *
 * Idempotent: closing an already-closed one returns without writing, so the two
 * people who both reach for it after a meeting do not race.
 */
export const close = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const { msg, interaction } = await resolve(ctx, messageId);
    await assertMember(ctx, msg.roomId, userId);
    if (interaction.closedAt !== undefined) return { ok: true };
    if (!(await mayAdminister(ctx, interaction, msg.roomId, userId))) {
      throw new Error(ERR_NOT_ALLOWED);
    }
    await ctx.db.patch(interaction._id, {
      closedAt: Date.now(),
      closedBy: userId,
    });
    return { ok: true };
  },
});

// ── Reading ─────────────────────────────────────────────────────────────────

/**
 * The live state of everything answerable in a room, plus this reader's own
 * answers.
 *
 * ## Why this is a separate subscription and not part of `messages:list`
 *
 * Because a vote must not rebuild the transcript. `messages:list` reads
 * reactions inline and therefore refires whenever one changes — a cost that
 * file accepts for a feature where the payload IS the message list. Folding
 * poll state in would put a second, much busier write stream through the same
 * subscription: every vote, every tick and every RSVP in the room would
 * re-deliver a hundred messages to every member. Here, a vote re-delivers a
 * handful of small rows and nothing else.
 *
 * ## Why it is windowed
 *
 * `ROOM_STATE_LIMIT` matches `messages:list`'s own limit for the reason given
 * there: this is the live window on a room, and that is the live window on a
 * room. Older interactions arrive through [stateForMessages] alongside the
 * `listBefore` page that carries their messages, so both halves of an old page
 * are one-shot reads and neither pretends to be live.
 *
 * ## What widens the read set
 *
 * The reader's own responses, and nothing else — `by_room_user` is scoped to
 * one person's rows. So voting refires this query for the voter (their `mine`
 * changed) and for everyone else only via the tally patch, which is the update
 * they are actually waiting for. Same shape as `messages:list`'s
 * `viewerUserId`.
 */
export const listForRoom = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, viewerUserId }) => {
    if (!(await canReadRoom(ctx, roomId, viewerUserId))) return [];
    const rows = await ctx.db
      .query("messageInteractions")
      .withIndex("by_room_time", (q) => q.eq("roomId", roomId))
      .order("desc")
      .take(ROOM_STATE_LIMIT);
    if (rows.length === 0) return [];

    // This reader's answers across the whole room, in one range read. Bucketed
    // by message below rather than queried per interaction, which would be one
    // index read per poll on every refire.
    const mine = viewerUserId
      ? await ctx.db
          .query("interactionResponses")
          .withIndex("by_room_user", (q) =>
            q.eq("roomId", roomId).eq("userId", viewerUserId)
          )
          .collect()
      : [];
    const mineByMessage = new Map<string, string[]>();
    for (const r of mine) {
      const key = r.messageId.toString();
      const bucket = mineByMessage.get(key);
      if (bucket) bucket.push(r.choiceId);
      else mineByMessage.set(key, [r.choiceId]);
    }

    return rows.map((row) => {
      const answers = mineByMessage.get(row.messageId.toString()) ?? [];
      return {
        ...sanitizeInteraction(row, answers.length > 0),
        // What this reader picked. Their own answers, so no anonymity question
        // arises — a poll that hid your vote from you would just be broken.
        myChoiceIds: answers,
      };
    });
  },
});

/**
 * The same state, for a named set of messages, as a one-shot.
 *
 * The paging counterpart to [listForRoom] — see its header. Called with the ids
 * of whatever `listBefore` just handed the transcript, so an interaction older
 * than the live window still renders its tally the moment its message appears.
 *
 * Capped, because the client controls the id list. The cap is the same shape as
 * `MAX_FORWARD_MESSAGES` in messages.ts: a bound on the read set, not an
 * expectation about the caller.
 */
export const stateForMessages = query({
  identityArg: "viewerUserId" as const,
  args: {
    messageIds: v.array(v.id("messages")),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { messageIds, viewerUserId }) => {
    const ids = messageIds.slice(0, ROOM_STATE_LIMIT);
    const out: any[] = [];
    for (const messageId of ids) {
      const row = await ctx.db
        .query("messageInteractions")
        .withIndex("by_message", (q) => q.eq("messageId", messageId))
        .first();
      if (!row) continue;
      // Membership is checked per row rather than once, because the caller
      // names messages rather than a room and a batch could legitimately span
      // two. A message the caller is not entitled to is skipped, not refused:
      // the id may simply be stale, and one bad id must not cost the page its
      // other twenty.
      if (viewerUserId) {
        const membership = await ctx.db
          .query("roomMembers")
          .withIndex("by_room_user", (q) =>
            q.eq("roomId", row.roomId).eq("userId", viewerUserId)
          )
          .first();
        if (!membership) continue;
      }
      const mine = viewerUserId
        ? await ctx.db
            .query("interactionResponses")
            .withIndex("by_message_user", (q) =>
              q.eq("messageId", messageId).eq("userId", viewerUserId)
            )
            .collect()
        : [];
      out.push({
        ...sanitizeInteraction(row, mine.length > 0),
        myChoiceIds: mine.map((r) => r.choiceId),
      });
    }
    return out;
  },
});

/**
 * Who answered what, in full — the sheet behind the faces on a card.
 *
 * Refuses an anonymous poll outright rather than returning an empty list. An
 * empty list is a claim ("nobody voted"); a refusal is the truth ("this poll
 * does not say"). The client never opens this on an anonymous poll, so reaching
 * the refusal means a stale screen or a hand-written call, and both should be
 * told the same thing.
 *
 * Names come from the snapshot on each response row, never from a `users` read
 * — see the note on `interactionResponses.userName`. Ids come with them so the
 * sheet can open a profile.
 */
export const respondents = query({
  identityArg: "viewerUserId" as const,
  args: {
    messageId: v.id("messages"),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { messageId, viewerUserId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) throw new Error(ERR_NOT_FOUND);
    const interaction = await ctx.db
      .query("messageInteractions")
      .withIndex("by_message", (q) => q.eq("messageId", messageId))
      .first();
    if (!interaction) throw new Error(ERR_NOT_FOUND);
    if (viewerUserId) await assertMember(ctx, msg.roomId, viewerUserId);
    if (interaction.anonymous === true) throw new Error(ERR_ANONYMOUS);

    const rows = await ctx.db
      .query("interactionResponses")
      .withIndex("by_message_user", (q) => q.eq("messageId", messageId))
      .collect();
    rows.sort((a, b) => a.createdAt - b.createdAt);
    return rows.map((r) => ({
      userId: r.userId,
      name: r.userName,
      choiceId: r.choiceId,
      at: r.createdAt,
    }));
  },
});
