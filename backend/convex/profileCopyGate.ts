// Display-name resolution for the readers of rows that used to carry a
// denormalised name copy (Phase 6). The copies are gone from every table, so a
// name always comes from the live profile (`nameOf`).
//
// A deleted account resolves to "" everywhere. There is no server-side label
// for it, so the client localizes the empty name.
import { nameOf } from "./profilesCore";

/** [userId]'s current display name ("" for a deleted or unknown account). */
export async function displayName(ctx: any, userId: any): Promise<string> {
  return await nameOf(ctx, userId);
}

/** `displayName` memoised per distinct user, for a handler that renders many rows. */
export function nameResolver(ctx: any) {
  const seen = new Map<string, Promise<string>>();
  return (userId: any): Promise<string> => {
    const key = String(userId);
    let hit = seen.get(key);
    if (!hit) {
      hit = displayName(ctx, userId);
      seen.set(key, hit);
    }
    return hit;
  };
}
