import { v, type ObjectType, type PropertyValidators } from "convex/values";
import {
  action as rawAction,
  mutation as rawMutation,
  query as rawQuery,
  internalQuery,
  type ActionCtx,
  type MutationCtx,
  type QueryCtx,
} from "./_generated/server";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { requireSession } from "./sessionCore";

/**
 * Authenticated function builders — the single place identity enters the
 * backend.
 *
 * ## The problem these exist to end
 *
 * Every public function used to take `userId: v.id("users")` as an ordinary
 * argument and trust it. Passing a userId *was* authentication: anyone who
 * learned one could read that person's chats, post as them, and remove their
 * friends. There was no session to revoke either, so "sign out my other
 * devices" could not be built at all.
 *
 * ## How the swap stays small
 *
 * The wrapper **injects the resolved identity back into the handler's args
 * under the same name the handler already used**. Migrating a function is
 * therefore three mechanical edits and no change to its body:
 *
 * ```ts
 * -export const send = mutation({
 * -  args: { userId: v.id("users"), roomId: v.id("rooms"), text: v.string() },
 * +export const send = authedMutation({
 * +  args: { roomId: v.id("rooms"), text: v.string() },
 *     handler: async (ctx, { userId, roomId, text }) => { ...unchanged... },
 *  });
 * ```
 *
 * The handler still destructures `userId`; it just can no longer be told what
 * it is. That property is what made a 162-function migration reviewable: the
 * diff is the argument list, never the logic.
 *
 * [identityArg] renames the injected key for the handlers that call the caller
 * something else — `callerId` in `calls.initiate`, `viewerUserId` in
 * `users.getProfile`, where a separate `userId` means the person being looked
 * AT and must keep coming from the client.
 *
 * ## What must NOT use these
 *
 * Anything that runs before a session exists: `auth.login`, `auth.signup`,
 * `auth.resetPasswordWithRecoveryKey`, `users.isUsernameAvailable`, the
 * `deviceLogin` request/exchange pair, `socialAuth.signIn`, and the public
 * server-directory and release reads. Those keep the plain builders. A session
 * cannot be required by the thing that mints it.
 */

/// The handler receives the context **untouched**.
///
/// An earlier draft spread it — `{ ...ctx, userId }` — so handlers could read
/// `ctx.userId`. That is the sanctioned convex-helpers shape and it very
/// probably works, but "very probably" is the wrong standard when every
/// function in the app would break at once if a `ctx` property turned out not
/// to be own-enumerable. No handler here reads `ctx.userId` anyway — they all
/// take the identity from their args, because that is what let the migration
/// leave 162 handler bodies alone. So the spread was pure risk for no benefit,
/// and the context is passed straight through instead.
type AuthedCtx<C> = C;

/// The handler sees its own declared args PLUS the injected identity, under
/// whichever key [identityArg] named. Typed rather than `any` on purpose: it is
/// what makes `tsc` catch a migration that removed `userId` from the arg list
/// but destructures a name the wrapper never injects — across 162 functions,
/// that check is the difference between a mechanical change and a gamble.
type HandlerArgs<A extends PropertyValidators, K extends string> =
  ObjectType<A> & Record<K, Id<"users">>;

/** Resolve-or-throw for actions, which have no `ctx.db` of their own. */
export const resolveSessionInternal = internalQuery({
  args: { token: v.string() },
  returns: v.id("users"),
  handler: async (ctx, { token }) => requireSession(ctx, token),
});

/**
 * The injected argument's name.
 *
 * NOT `token`. `voipTokens.setVoipToken`, `setApnsToken` and `setFcmToken`
 * each already had an argument called `token` — the PUSH token — and the first
 * version of this wrapper injected the session token under that same name. The
 * client's own injection overwrote the push token with the session token, the
 * handler stored the session token as the device's push credential, and the
 * call still SUCCEEDED because the value it resolved was a real session. Push
 * died silently on every device, and every client call site swallows its error
 * with a debugPrint, so nothing said a word.
 *
 * Hence a name no domain object would ever want, and the assertion below.
 */
const IDENTITY_ARG = "sessionToken";

function withToken(args?: PropertyValidators): PropertyValidators {
  const declared = args ?? {};
  // Thrown at MODULE LOAD, so a collision breaks the deploy immediately
  // instead of quietly corrupting whatever field it shadowed. There is no
  // version of this that should be a warning.
  if (IDENTITY_ARG in declared) {
    throw new Error(
      `A function declares an argument named \`${IDENTITY_ARG}\`, which the ` +
        `auth wrapper injects. Rename the argument — see functions.ts.`,
    );
  }
  return { ...declared, [IDENTITY_ARG]: v.string() };
}

/**
 * A query that requires a live session.
 *
 * The token costs one indexed read per call, on `sessions.by_token_hash`. That
 * is the price of being able to revoke anything at all, and it is the same
 * read Convex's own auth would do.
 */
export function authedQuery<
  A extends PropertyValidators,
  K extends string = "userId",
>(def: {
  // Optional: a handler can legitimately take nothing but its identity —
  // `files.generateUploadUrl` is exactly that shape.
  args?: A;
  // The return validator stays loose: pinning it against Convex's
  // ValidatorTypeToReturnType through three layers of generics buys nothing
  // the per-function validator does not already enforce at runtime.
  returns?: any;
  identityArg?: K;
  handler: (ctx: AuthedCtx<QueryCtx>, args: HandlerArgs<A, K>) => any;
}) {
  const key = (def.identityArg ?? "userId") as string;
  return rawQuery({
    args: withToken(def.args),
    ...(def.returns ? { returns: def.returns } : {}),
    handler: async (ctx: QueryCtx, args: any) => {
      const { [IDENTITY_ARG]: sessionToken, ...rest } = args;
      const userId = await requireSession(ctx, sessionToken);
      return def.handler(ctx, { ...rest, [key]: userId });
    },
  });
}

/** A mutation that requires a live session. See [authedQuery]. */
export function authedMutation<
  A extends PropertyValidators,
  K extends string = "userId",
>(def: {
  // Optional: a handler can legitimately take nothing but its identity —
  // `files.generateUploadUrl` is exactly that shape.
  args?: A;
  // The return validator stays loose: pinning it against Convex's
  // ValidatorTypeToReturnType through three layers of generics buys nothing
  // the per-function validator does not already enforce at runtime.
  returns?: any;
  identityArg?: K;
  handler: (ctx: AuthedCtx<MutationCtx>, args: HandlerArgs<A, K>) => any;
}) {
  const key = (def.identityArg ?? "userId") as string;
  return rawMutation({
    args: withToken(def.args),
    ...(def.returns ? { returns: def.returns } : {}),
    handler: async (ctx: MutationCtx, args: any) => {
      const { [IDENTITY_ARG]: sessionToken, ...rest } = args;
      const userId = await requireSession(ctx, sessionToken);
      return def.handler(ctx, { ...rest, [key]: userId });
    },
  });
}

/**
 * An action that requires a live session.
 *
 * Actions have no `ctx.db`, so the lookup goes through an internal query
 * rather than calling [requireSession] directly — the one place the shape
 * differs from the two above.
 */
export function authedAction<
  A extends PropertyValidators,
  K extends string = "userId",
>(def: {
  // Optional: a handler can legitimately take nothing but its identity —
  // `files.generateUploadUrl` is exactly that shape.
  args?: A;
  // The return validator stays loose: pinning it against Convex's
  // ValidatorTypeToReturnType through three layers of generics buys nothing
  // the per-function validator does not already enforce at runtime.
  returns?: any;
  identityArg?: K;
  handler: (ctx: AuthedCtx<ActionCtx>, args: HandlerArgs<A, K>) => any;
}) {
  const key = (def.identityArg ?? "userId") as string;
  return rawAction({
    args: withToken(def.args),
    ...(def.returns ? { returns: def.returns } : {}),
    handler: async (ctx: ActionCtx, args: any) => {
      const { [IDENTITY_ARG]: sessionToken, ...rest } = args;
      const userId: Id<"users"> = await ctx.runQuery(
        internal.functions.resolveSessionInternal,
        { token: sessionToken },
      );
      return def.handler(ctx, { ...rest, [key]: userId });
    },
  });
}


// ─────────────────────────────────────────────────────────────────────────────
// The names files actually import.
//
// `query`/`mutation`/`action` here SHADOW the generated builders, so a file
// opts its whole contents into authentication by changing one import line:
//
//     -import { mutation, query } from "./_generated/server";
//     +import { mutation, query } from "./functions";
//
// Nothing else in the file moves — not the args, not the handler bodies. The
// identity is injected over the top of whatever the client sent, so a caller
// who lies about `userId` is simply overruled rather than believed. That is
// what makes this a 26-line change instead of a 162-function rewrite, and it
// is why the arg lists can be tidied later, at leisure, as cosmetics rather
// than as security work.
//
// The default is SAFE and the opt-out is LOUD. A function that must run before
// a session exists says so in its own builder name — `publicMutation`, not a
// flag buried in an options object — so "what can an unauthenticated caller
// reach?" is one grep, forever:
//
//     grep -rn "public\(Query\|Mutation\|Action\)" backend/convex
// ─────────────────────────────────────────────────────────────────────────────

export const query = authedQuery;
export const mutation = authedMutation;
export const action = authedAction;

/**
 * Deliberately unauthenticated — and it costs you a sentence to say so.
 *
 * Enforcement is a TEST, not a type. Convex's builders are generic in a way
 * that `Parameters<>` collapses, so wrapping them to demand a justification
 * field costs the args and handler their inference — a bad trade, since that
 * inference is what catches every other mistake in this file.
 *
 * So `session_boundary_test.dart` owns the rule instead: it parses this
 * directory and asserts the unauthenticated surface matches an explicit
 * allowlist, each entry carrying its reason. Adding a `public*` function fails
 * the suite until someone writes down why it must be reachable with no
 * session. That is a louder review signal than an `authRequired: false` flag
 * buried in a forty-line options object, and it cannot be skimmed past.
 *
 * There are only a few legitimate reasons, and they all reduce to "a session
 * cannot be a precondition for the thing that creates one":
 *
 *   * minting     — `auth.login`, `auth.signup`, `socialAuth.signIn`
 *   * recovering  — `auth.resetPasswordWithRecoveryKey`, for an account that
 *                   by definition cannot sign in
 *   * the login screen's own questions — `users.isUsernameAvailable`, the
 *                   server directory, the release feed
 *   * the device-login handshake, whose entire purpose is getting a session
 *                   onto a device that has none
 *
 * The whole unauthenticated surface of this backend, in one command:
 *
 *     grep -rn "public: " backend/convex
 */
export const publicQuery = rawQuery;
export const publicMutation = rawMutation;
export const publicAction = rawAction;
