// Shared by the writers and readers of the denormalised name copies (Phase 6).
//
// `copyFlags.copies` is the mutable view of `PROFILE_COPIES`, read at call
// time, so a test can force the stripped world (`copyFlags.copies = false`)
// without a rebuild; the same trick `sessionFlags` plays in sessionCore.
//
// A writer asks `copiesOn()` before it stamps a name or avatar onto a row. A
// reader asks `displayName` / `nameResolver`, which prefer the live profile
// (`nameOf`) and only fall back to the row's own copy when the profile gives
// nothing for an account that has NOT been deleted.
//
// A deleted account resolves to "" everywhere. There is no server-side label
// for it, so the client localizes the empty name.
import { PROFILE_COPIES, nameOf } from "./profilesCore";

export const copyFlags = { copies: PROFILE_COPIES };

export const copiesOn = (): boolean => copyFlags.copies;

/** True when the account is deleted (tombstoned or marked) or its row is gone. */
async function accountGone(ctx: any, userId: any): Promise<boolean> {
  const row = await ctx.db
    .query("profiles")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
  if (row?.deleted) return true;
  const user = await ctx.db.get(userId);
  return !user || user.deletingAt !== undefined;
}

/**
 * [userId]'s current display name. [copy] is the name stored on the row being
 * rendered, used only when the profile has no name and the account is alive.
 */
export async function displayName(
  ctx: any,
  userId: any,
  copy?: string | null,
): Promise<string> {
  const name = await nameOf(ctx, userId);
  if (name !== "") return name;
  if (!copy) return "";
  return (await accountGone(ctx, userId)) ? "" : copy;
}

/** `displayName` memoised per distinct user, for a handler that renders many rows. */
export function nameResolver(ctx: any) {
  const seen = new Map<string, Promise<string>>();
  return (userId: any, copy?: string | null): Promise<string> => {
    const key = `${userId}\u0000${copy ?? ""}`;
    let hit = seen.get(key);
    if (!hit) {
      hit = displayName(ctx, userId, copy);
      seen.set(key, hit);
    }
    return hit;
  };
}
