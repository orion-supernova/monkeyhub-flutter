/**
 * The two things `messages.ts` has to do to a poll, and nothing else.
 *
 * ## Why this is not in `interactions.ts`
 *
 * Because that file imports `sendCore` from `messages.ts`, and `messages.ts`
 * needs these two — so putting them there would close a cycle between the two
 * biggest modules in the backend. ES modules would very probably tolerate it
 * (both sides are hoisted function declarations, resolved at call time rather
 * than at module init), but "very probably" is not a good enough reason to be
 * the first import cycle in a backend that has none, in a bundler nobody here
 * has tested one against.
 *
 * So the dependency stays a DAG the way the rest of the file graph does:
 *
 *   interactionCore  ←  messages  ←  interactions
 *                    ←──────────────────┘
 *
 * The split is along a real seam rather than an arbitrary one. Everything here
 * is about a message ENDING or being COPIED — the message lifecycle, which is
 * `messages.ts`'s subject — while `interactions.ts` is about a poll being
 * answered. Nothing in this file reads a caller's identity or enforces a rule;
 * both helpers are called from paths that have already decided.
 *
 * The same precedent `sessionCore.ts` sets, and for the same reason: the piece
 * that two layers both need lives under both of them.
 */

/**
 * Removes an interaction and every answer to it.
 *
 * Called from `removeMessageAndFanout`, so it runs on all four ways a message
 * can go: the sender deleting it, a batch delete, a Chamber-of-Secrets expiry,
 * and the room being wiped. One cascade rather than one per path, for the
 * reason that function's own header gives — the paths cannot then disagree
 * about what a dead message leaves behind.
 *
 * Responses first, then the definition. The other order would leave answer rows
 * pointing at an interaction that no longer exists if the transaction were ever
 * split; it is not, but the order costs nothing and means the intermediate
 * state is never the nonsensical one.
 *
 * A no-op on the overwhelming majority of messages, where both lookups are a
 * single empty index range. Same posture as `purgeViewOnceViews`, which also
 * runs for every message and finds nothing for nearly all of them.
 */
export async function purgeInteraction(ctx: any, messageId: any) {
  const rows = await ctx.db
    .query("interactionResponses")
    .withIndex("by_message_user", (q: any) => q.eq("messageId", messageId))
    .collect();
  for (const r of rows) await ctx.db.delete(r._id);

  const interaction = await ctx.db
    .query("messageInteractions")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .first();
  if (interaction) await ctx.db.delete(interaction._id);
}

/**
 * Copies an interaction's DEFINITION onto a freshly forwarded message.
 *
 * Forwarding a poll posts a NEW poll, not a picture of an old one: the question
 * and options travel, every tally starts at zero, and the copy is open even if
 * the original was closed. That is the only coherent reading of the act —
 * carrying the votes would attribute this room's members' answers to people who
 * are not in it, and carrying `closedAt` would forward something nobody could
 * ever answer.
 *
 * A quiz keeps its answer, which is most of the point of forwarding one. An
 * anonymous poll keeps its anonymity, because the flag is a promise made to
 * whoever answers the copy rather than a property of the original's data — a
 * forward that quietly de-anonymised would be the worst possible direction for
 * that bit to flip.
 *
 * A no-op when the source has no interaction row, which is what makes the call
 * site in `forwardToRoom` unconditional: every forwarded message asks, and only
 * the three interactive kinds find anything.
 */
export async function forkInteraction(
  ctx: any,
  sourceMessageId: any,
  newMessageId: any,
  roomId: any,
  userId: any
) {
  const src = await ctx.db
    .query("messageInteractions")
    .withIndex("by_message", (q: any) => q.eq("messageId", sourceMessageId))
    .first();
  if (!src) return;

  await ctx.db.insert("messageInteractions", {
    messageId: newMessageId,
    // The TARGET room, and the forwarder as the author. They own the copy: it
    // is their message, in their room, and they are the one who can close it.
    roomId,
    kind: src.kind,
    createdBy: userId,
    createdAt: Date.now(),
    // Labels only. Rebuilt by naming the two fields that travel rather than by
    // spreading the source and overwriting the state, so a field added to a
    // choice later cannot ride along by accident — the same whitelist-not-
    // blacklist reasoning `sanitizeInteraction` uses on the read side.
    choices: src.choices.map((c: any) => ({
      id: c.id,
      label: c.label,
      count: 0,
    })),
    respondentCount: 0,
    ...(src.multiple === true ? { multiple: true } : {}),
    ...(src.anonymous === true ? { anonymous: true } : {}),
    ...(src.quiz === true ? { quiz: true } : {}),
    ...(src.correctChoiceId !== undefined
      ? { correctChoiceId: src.correctChoiceId }
      : {}),
    ...(src.explanation !== undefined ? { explanation: src.explanation } : {}),
    ...(src.othersMayCheck === false ? { othersMayCheck: false } : {}),
    ...(src.othersMayAdd === false ? { othersMayAdd: false } : {}),
    ...(src.nextItemId !== undefined ? { nextItemId: src.nextItemId } : {}),
    ...(src.startsAt !== undefined ? { startsAt: src.startsAt } : {}),
    ...(src.endsAt !== undefined ? { endsAt: src.endsAt } : {}),
    ...(src.place !== undefined ? { place: src.place } : {}),
  });
}
