import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { MAX_FOLDERS } from "./chatFolders";

/** Folders are the user's own: capped, validated, ordered, private. */
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

const base = {
  dms: true,
  groups: false,
  excludeMuted: false,
  excludeRead: false,
  excludeArchived: true,
  include: [],
  exclude: [],
};

test("save, list, rename, reorder, remove; mine only", async () => {
  const t = makeT();
  const a = await signUp(t, "murat");
  const z = await signUp(t, "zeynep");
  const one = await t.mutation(api.chatFolders.save, { ...as(a), ...base, name: "  Friends ", color: 2 });
  const two = await t.mutation(api.chatFolders.save, { ...as(a), ...base, name: "Work", groups: true });
  let mine = await t.query(api.chatFolders.list, as(a));
  expect(mine.map((f: any) => f.name)).toEqual(["Friends", "Work"]);
  expect(mine[0].color).toBe(2);
  expect(await t.query(api.chatFolders.list, as(z))).toEqual([]);

  await t.mutation(api.chatFolders.save, { ...as(a), ...base, id: one, name: "Pals" });
  await t.mutation(api.chatFolders.reorder, { ...as(a), ids: [two, one] });
  mine = await t.query(api.chatFolders.list, as(a));
  expect(mine.map((f: any) => f.name)).toEqual(["Work", "Pals"]);
  expect(mine[1].color).toBeUndefined();

  // Someone else's folder can be neither edited nor deleted.
  await expect(
    t.mutation(api.chatFolders.save, { ...as(z), ...base, id: one, name: "Mine now" }),
  ).rejects.toThrow("FOLDER_NOT_FOUND");
  await t.mutation(api.chatFolders.remove, { ...as(z), id: one });
  expect((await t.query(api.chatFolders.list, as(a))).length).toBe(2);

  await t.mutation(api.chatFolders.remove, { ...as(a), id: one });
  mine = await t.query(api.chatFolders.list, as(a));
  expect(mine.map((f: any) => f.name)).toEqual(["Work"]);
});

test("refuses empty, nameless and past-the-cap folders", async () => {
  const t = makeT();
  const a = await signUp(t, "murat");
  await expect(
    t.mutation(api.chatFolders.save, { ...as(a), ...base, dms: false, name: "Nothing" }),
  ).rejects.toThrow("FOLDER_EMPTY");
  await expect(t.mutation(api.chatFolders.save, { ...as(a), ...base, name: "   " })).rejects.toThrow(
    "FOLDER_NAME_REQUIRED",
  );
  await expect(
    t.mutation(api.chatFolders.save, { ...as(a), ...base, name: "x", color: 9 }),
  ).rejects.toThrow("FOLDER_COLOR_INVALID");
  for (let i = 0; i < MAX_FOLDERS; i++) {
    await t.mutation(api.chatFolders.save, { ...as(a), ...base, name: `F${i}` });
  }
  await expect(t.mutation(api.chatFolders.save, { ...as(a), ...base, name: "One more" })).rejects.toThrow(
    "TOO_MANY_FOLDERS",
  );
});
