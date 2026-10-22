import type { Step } from "../deletionCore";

/**
 * Custom teardown steps for the `moment` deletion kind: what
 * `momentCleanup.deleteMomentCore` left when a moment had more reactions,
 * views, comment reactions or comments than fit inline.
 *
 * None needed: every reference to a moment is a plain cascade, so the plan is
 * the generic steps alone. Their order matters and is alphabetical by id:
 * `momentCommentReactions.momentId` sorts before `momentComments.momentId`, so
 * a half-done sweep never leaves a reaction whose comment is gone.
 */
export const momentSteps: Step[] = [];
