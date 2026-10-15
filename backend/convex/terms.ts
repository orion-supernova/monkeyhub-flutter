import { mutation, query } from "./functions";
import { v } from "convex/values";

/**
 * Acceptance of the Terms of Use (EULA), which App Store Guideline 1.2 asks a
 * user-generated-content app to obtain before anyone can post: the user must
 * agree, explicitly, that there is no tolerance for objectionable content or
 * abusive users. The EULA page itself carries that clause; this file records
 * who agreed to which version, and when.
 *
 * ── Where acceptance is collected ───────────────────────────────────────────
 *
 *  * Sign-up, password or Apple/Google: a checkbox the account cannot be
 *    created without. The client sends `termsVersion`, and `auth.signup` /
 *    `socialAuth.createWithIdentity` stamp it via [termsStamp].
 *  * Everyone else: a blocking sheet after sign-in, driven by [status] and
 *    closed by [accept].
 *
 * ── Compatibility ───────────────────────────────────────────────────────────
 *
 * An old build that never shows the checkbox sends no `termsVersion`. Its
 * sign-up is NOT refused — that would break sign-up outright for every tester
 * still on it — but the account is created unaccepted, and the next build it
 * runs stops it at the acceptance sheet before anything else. A client that
 * DOES send the field must send the current version or newer; an explicit
 * `0`/stale version is refused with TERMS_NOT_ACCEPTED. Once old builds have
 * aged out this becomes a required argument.
 */

/**
 * The EULA revision users are asked to accept. Bump it when the document
 * changes in a way people must agree to again; every account below it gets
 * the acceptance sheet once more.
 */
export const TERMS_VERSION = 1;

export const ERR_TERMS_NOT_ACCEPTED = "TERMS_NOT_ACCEPTED";

/**
 * The fields a sign-up writes for [version], or none for an old client.
 * Throws for a version that is present but stale.
 */
export function termsStamp(version: number | undefined): {
  termsAcceptedAt?: number;
  termsVersion?: number;
} {
  if (version === undefined) return {};
  if (!(version >= TERMS_VERSION)) throw new Error(ERR_TERMS_NOT_ACCEPTED);
  return { termsAcceptedAt: Date.now(), termsVersion: TERMS_VERSION };
}

/** Whether the caller has accepted the current terms. One `get` by id. */
export const status = query({
  args: { userId: v.id("users") },
  returns: v.object({
    accepted: v.boolean(),
    currentVersion: v.number(),
  }),
  handler: async (ctx, { userId }) => {
    const me = await ctx.db.get(userId);
    return {
      accepted: (me?.termsVersion ?? 0) >= TERMS_VERSION,
      currentVersion: TERMS_VERSION,
    };
  },
});

/** Records the caller's acceptance of [version]. Idempotent. */
export const accept = mutation({
  args: { userId: v.id("users"), version: v.number() },
  returns: v.null(),
  handler: async (ctx, { userId, version }) => {
    if (!(version >= TERMS_VERSION)) throw new Error(ERR_TERMS_NOT_ACCEPTED);
    const me = await ctx.db.get(userId);
    if (!me) return null;
    if ((me.termsVersion ?? 0) >= TERMS_VERSION) return null;
    await ctx.db.patch(userId, {
      termsAcceptedAt: Date.now(),
      termsVersion: TERMS_VERSION,
    });
    return null;
  },
});
