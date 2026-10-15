import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import schema from "./schema";
import { ensureSystemAccount } from "./systemRooms";
import { SYSTEM_PASSWORD_PREFIX } from "./systemAccount";

const SPEC = {
  username: "monkeyhub_logger",
  formerUsernames: ["monkeyhub_logs"],
  displayName: "Monkey Logger",
  roomName: "MonkeyHub Logs",
  slug: "logs",
};

test("a system account on a former handle is renamed in place", async () => {
  const t = convexTest(schema);
  const oldId = await t.run((ctx) =>
    ctx.db.insert("users", {
      username: "monkeyhub_logs",
      name: "MonkeyHub Logs",
      passwordHash: SYSTEM_PASSWORD_PREFIX + "00",
      createdAt: 0,
    } as any),
  );
  const id = await t.run((ctx) => ensureSystemAccount(ctx, SPEC));
  // The same row, so its room (found through its membership) comes with it.
  expect(id).toBe(oldId);
  const row: any = await t.run((ctx) => ctx.db.get(oldId));
  expect(row.username).toBe("monkeyhub_logger");
  expect(row.name).toBe("Monkey Logger");
  expect(await t.run((ctx) => ctx.db.query("users").collect())).toHaveLength(1);
});

test("a real account on a former handle is never adopted", async () => {
  const t = convexTest(schema);
  const realId = await t.run((ctx) =>
    ctx.db.insert("users", {
      username: "monkeyhub_logs",
      name: "Someone",
      passwordHash: "hash",
      createdAt: 0,
    } as any),
  );
  const id = await t.run((ctx) => ensureSystemAccount(ctx, SPEC));
  expect(id).not.toBe(realId);
  const real: any = await t.run((ctx) => ctx.db.get(realId));
  expect(real.username).toBe("monkeyhub_logs");
});
