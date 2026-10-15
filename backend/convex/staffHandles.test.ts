import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import { REPORT_INBOX_USERNAME } from "./systemAccount";
import schema from "./schema";

/**
 * Moderator rights follow the handle, so a staff handle must never pass to
 * somebody else: not by the moderator renaming away from it, and not by
 * re-registering it after the moderator's account is deleted.
 */

const signUp = (t: ReturnType<typeof convexTest>, username: string) =>
  t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });

describe("staff handles", () => {
  test("a deleted staff account's handle can't be registered again", async () => {
    const t = convexTest(schema);
    const staff = await signUp(t, REPORT_INBOX_USERNAME);
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: staff.token,
      userId: staff.userId as any,
    });
    await expect(signUp(t, REPORT_INBOX_USERNAME)).rejects.toThrow(
      "USERNAME_RESERVED",
    );
  });

  test("an ordinary deleted account's handle is free again", async () => {
    const t = convexTest(schema);
    const someone = await signUp(t, "someone");
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: someone.token,
      userId: someone.userId as any,
    });
    await expect(signUp(t, "someone")).resolves.toBeTruthy();
  });
});
