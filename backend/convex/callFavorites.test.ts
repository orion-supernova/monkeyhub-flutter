import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/** Favourites are the user's own pins: add/remove/list, capped, self refused. */
const makeT = () => convexTest(schema);
type T = ReturnType<typeof makeT>;

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}
const as = (u: { token: string }) => ({ sessionToken: u.token }) as any;

test("add is idempotent, remove unpins, list is mine only", async () => {
  const t = makeT();
  const a = await signUp(t, "murat");
  const z = await signUp(t, "zeynep");
  const b = await signUp(t, "ben");
  await t.mutation(api.callFavorites.add, { ...as(a), peerId: z.userId as any });
  await t.mutation(api.callFavorites.add, { ...as(a), peerId: z.userId as any });
  await t.mutation(api.callFavorites.add, { ...as(a), peerId: b.userId as any });
  let mine = await t.query(api.callFavorites.list, as(a));
  expect(mine.map((r: any) => r.peerId)).toEqual([z.userId, b.userId]);
  expect(await t.query(api.callFavorites.list, as(z))).toEqual([]);

  await t.mutation(api.callFavorites.remove, { ...as(a), peerId: b.userId as any });
  mine = await t.query(api.callFavorites.list, as(a));
  expect(mine.map((r: any) => r.peerId)).toEqual([z.userId]);

  await expect(
    t.mutation(api.callFavorites.add, { ...as(a), peerId: a.userId as any }),
  ).rejects.toThrow(/CANNOT_FAVORITE_SELF/);
});
