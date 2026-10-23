import { convexTest } from "convex-test";
import { describe, expect, onTestFinished, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { sessionFlags } from "./sessionCore";
/**
 * The session boundary, actually executed.
 *
 * Everything else about this migration was checked by `tsc` and by a Dart test
 * that reads the source. Neither of those runs a single Convex function, and
 * the two things most likely to be wrong can only fail at runtime:
 *
 *   1. `crypto.subtle.digest` inside a MUTATION. Every other use of
 *      `crypto.subtle` in this backend is in an action; `sessionCore.hashToken`
 *      is the first from a mutation, and it sits on the login path. If the
 *      runtime refuses it, nobody can sign in at all.
 *   2. The wrapper's identity injection. `functions.ts` overwrites the
 *      caller-supplied `userId` with the one the token resolves to. That is the
 *      entire security claim of the change, and until this file existed it was
 *      an argument rather than a fact.
 *
 * `convex-test` runs the real function bodies against an in-memory database in
 * an isolate that mimics the Convex V8 runtime, so both are exercised for real.
 */

const DEVICE = "device-a";
const OTHER_DEVICE = "device-b";

async function signUp(
  t: ReturnType<typeof convexTest>,
  username: string,
  deviceId = DEVICE,
) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId,
  });
}

describe("minting", () => {
  test("signup returns a usable token — crypto.subtle works in a mutation", async () => {
    const t = convexTest(schema);
    const res = await signUp(t, "murat");

    // If `hashToken` had thrown, we would never get here.
    expect(res.token).toMatch(/^[0-9a-f]{64}$/);
    expect(res.userId).toBeDefined();
  });

  test("login returns a token that actually authenticates", async () => {
    const t = convexTest(schema);
    await signUp(t, "murat");

    const res = await t.mutation(api.auth.login as any, {
      username: "murat",
      passwordHash: "hash-murat",
      deviceId: DEVICE,
    });
    expect(res.token).toMatch(/^[0-9a-f]{64}$/);

    // And the token opens an authenticated function.
    const devices = await t.query(api.voipTokens.listDevices, {
      sessionToken: res.token,
      userId: res.userId,
      deviceId: DEVICE,
    });
    expect(Array.isArray(devices)).toBe(true);
  });

  test("signing in again on the same device revokes the old token", async () => {
    const t = convexTest(schema);
    const first = await signUp(t, "murat");
    const second = await t.mutation(api.auth.login as any, {
      username: "murat",
      passwordHash: "hash-murat",
      deviceId: DEVICE,
    });

    expect(second.token).not.toBe(first.token);
    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: first.token,
        userId: first.userId,
        deviceId: DEVICE,
      }),
    ).rejects.toThrow(/SESSION_REVOKED/);
  });
});

describe("the boundary", () => {
  test("no token is refused", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");

    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: "",
        userId: me.userId,
        deviceId: DEVICE,
      }),
    ).rejects.toThrow(/SESSION_UNKNOWN/);
  });

  test("a made-up token is refused", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");

    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: "f".repeat(64),
        userId: me.userId,
        deviceId: DEVICE,
      }),
    ).rejects.toThrow(/SESSION_UNKNOWN/);
  });

  /**
   * THE test. This is the hole the whole migration exists to shut: before it,
   * passing somebody else's userId WAS authenticating as them.
   */
  test("a lied-about userId is overruled, not believed", async () => {
    const t = convexTest(schema);
    const victim = await signUp(t, "victim");
    const attacker = await t.mutation(api.auth.signup, {
      username: "attacker",
      name: "attacker",
      passwordHash: "hash-attacker",
      recoveryKeyHash: "recovery-attacker",
      deviceId: OTHER_DEVICE,
    });

    // The victim registers a device, so there is something to steal.
    await t.mutation(api.voipTokens.registerDevice, {
      sessionToken: victim.token,
      userId: victim.userId,
      deviceId: DEVICE,
      platform: "ios",
      deviceName: "Victim's iPhone",
    });
    const asVictim = await t.query(api.voipTokens.listDevices, {
      sessionToken: victim.token,
      userId: victim.userId,
      deviceId: DEVICE,
    });
    expect(asVictim.length).toBeGreaterThan(0);

    // The attacker presents their OWN token but claims the victim's userId —
    // the exact shape that used to work.
    const stolen = await t.query(api.voipTokens.listDevices, {
      sessionToken: attacker.token,
      userId: victim.userId,
      deviceId: DEVICE,
    });

    // They get their own (empty) device list, not the victim's.
    expect(stolen).toEqual([]);
    expect(stolen).not.toEqual(asVictim);
  });

  test("a public function still works with no token at all", async () => {
    const t = convexTest(schema);
    // `isUsernameAvailable` is on the login screen, before any session exists.
    const free = await t.query(api.users.isUsernameAvailable, {
      username: "nobody",
    });
    expect(free).toBeDefined();
  });
});

describe("revocation", () => {
  test("removing a device signs that device out", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");

    // A second device signs in.
    const other = await t.mutation(api.auth.login as any, {
      username: "murat",
      passwordHash: "hash-murat",
      deviceId: OTHER_DEVICE,
    });
    await t.mutation(api.voipTokens.registerDevice, {
      sessionToken: other.token,
      userId: other.userId,
      deviceId: OTHER_DEVICE,
      platform: "macos",
    });

    // ...and is removed from the first.
    await t.mutation(api.voipTokens.clearDeviceToken, {
      sessionToken: me.token,
      userId: me.userId,
      deviceId: OTHER_DEVICE,
    });

    // The removed device's token is dead — this is what "Remove" now promises.
    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: other.token,
        userId: other.userId,
        deviceId: OTHER_DEVICE,
      }),
    ).rejects.toThrow(/SESSION_REVOKED/);

    // And the device doing the removing is untouched.
    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: me.token,
        userId: me.userId,
        deviceId: DEVICE,
      }),
    ).resolves.toBeDefined();
  });

  test("remove-all sweeps the others and keeps this one", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");
    const other = await t.mutation(api.auth.login as any, {
      username: "murat",
      passwordHash: "hash-murat",
      deviceId: OTHER_DEVICE,
    });

    await t.mutation(api.voipTokens.removeOtherDevices, {
      sessionToken: me.token,
      userId: me.userId,
      deviceId: DEVICE,
    });

    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: other.token,
        userId: other.userId,
        deviceId: OTHER_DEVICE,
      }),
    ).rejects.toThrow(/SESSION_REVOKED/);
    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: me.token,
        userId: me.userId,
        deviceId: DEVICE,
      }),
    ).resolves.toBeDefined();
  });

  test("signing out revokes this device's own session", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");

    await t.mutation(api.auth.logout, { sessionToken: me.token, deviceId: DEVICE });

    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: me.token,
        userId: me.userId,
        deviceId: DEVICE,
      }),
    ).rejects.toThrow(/SESSION_REVOKED/);
  });
});

describe("getProfile — the one function where userId is the subject", () => {
  test("you can still look at somebody else", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");
    const them = await t.mutation(api.auth.signup, {
      username: "zeynep",
      name: "Zeynep",
      passwordHash: "hash-zeynep",
      recoveryKeyHash: "recovery-zeynep",
      deviceId: OTHER_DEVICE,
    });

    // If the wrapper had overwritten `userId` here, this would come back as
    // the caller's own profile — the trap that made this function special.
    const profile = await t.query(api.users.getProfile, {
      sessionToken: me.token,
      userId: them.userId,
    });
    expect(profile).not.toBeNull();
    expect((profile as { username: string }).username).toBe("zeynep");
  });
});

describe("device login — the desktop QR flow, end to end", () => {
  test("create, approve from the phone, exchange for a working session", async () => {
    const t = convexTest(schema);
    const phone = await signUp(t, "murat");

    // The signed-OUT desktop opens the login screen.
    const req = await t.mutation(api.deviceLogin.createLoginRequest, {
      deviceInfo: "MacBook Air",
      codeHash: "hash-123456",
    });
    expect(req.requestId).toMatch(/^[0-9a-f]{32}$/);

    // The phone scans it and approves.
    await t.mutation(api.deviceLogin.respondToDeviceLoginRequest, {
      sessionToken: phone.token,
      callerId: phone.userId,
      approve: true,
      requestId: req.requestId,
    });

    // The desktop trades it for a session of its own.
    const desktop = await t.mutation(api.deviceLogin.exchangeDeviceLoginRequest, {
      requestId: req.requestId,
      deviceId: OTHER_DEVICE,
    });
    expect(desktop.userId).toBe(phone.userId);
    expect(desktop.token).toMatch(/^[0-9a-f]{64}$/);
    expect(desktop.token).not.toBe(phone.token);

    // ...and that session works, on its own device row.
    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: desktop.token,
        userId: desktop.userId,
        deviceId: OTHER_DEVICE,
      }),
    ).resolves.toBeDefined();
  });

  test("you cannot approve a sign-in as somebody else", async () => {
    // `respondToDeviceLoginRequest` takes the caller as `callerId`, which the
    // wrapper does not inject by default — so until `identityArg` was set here
    // the arg stayed client-supplied and this attack worked.
    const t = convexTest(schema);
    const victim = await signUp(t, "victim");
    const attacker = await t.mutation(api.auth.signup, {
      username: "attacker",
      name: "attacker",
      passwordHash: "hash-attacker",
      recoveryKeyHash: "recovery-attacker",
      deviceId: OTHER_DEVICE,
    });

    const req = await t.mutation(api.deviceLogin.createLoginRequest, {
      deviceInfo: "Attacker's laptop",
      codeHash: "hash-654321",
    });

    // The attacker approves it while claiming to be the victim.
    await t.mutation(api.deviceLogin.respondToDeviceLoginRequest, {
      sessionToken: attacker.token,
      callerId: victim.userId,
      approve: true,
      requestId: req.requestId,
    });

    const claimed = await t.mutation(
      api.deviceLogin.exchangeDeviceLoginRequest,
      { requestId: req.requestId, deviceId: "device-c" },
    );

    // The session belongs to the ATTACKER, not the account they named.
    expect(claimed.userId).toBe(attacker.userId);
    expect(claimed.userId).not.toBe(victim.userId);
  });
});

/**
 * Deleting an account has to end its sessions.
 *
 * The gap these cover shipped silently and stayed live for four days: the
 * `sessions` table arrived after `purgeUser` was written, `purgeUser` never
 * learned about it, and `requireSession` never checked that the account behind
 * a token still existed. The result was a bearer token for a hard-deleted user
 * that authenticated forever and resolved to a dangling id — which a phone
 * then rendered as a signed-in account nobody could sign out of.
 */
describe("deleting an account ends its sessions", () => {
  test("a token minted before deletion stops working after it", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "goksu");

    // Works while the account exists.
    await expect(
      t.query(api.auth.whoami, { sessionToken: me.token }),
    ).resolves.toMatchObject({ username: "goksu" });

    await t.mutation(api.auth.deleteAccount, {
      sessionToken: me.token,
      userId: me.userId,
    });

    // Asserted through `listDevices` rather than `whoami`: `whoami` re-checks
    // the account itself, so it would reject here even if `purgeUser` had
    // revoked nothing. `listDevices` only knows what `requireSession` tells it.
    //
    // REVOKED, not UNKNOWN: the row is still there, deliberately, so the
    // client can say "you were signed out" rather than reporting a bug.
    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: me.token,
        userId: me.userId,
        deviceId: DEVICE,
      }),
    ).rejects.toThrow(/SESSION_REVOKED/);
  });

  test("every device is signed out, not just the one that asked", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "goksu");
    const second = await t.mutation(api.auth.login as any, {
      username: "goksu",
      passwordHash: "hash-goksu",
      deviceId: OTHER_DEVICE,
    });

    await t.mutation(api.auth.deleteAccount, {
      sessionToken: me.token,
      userId: me.userId,
    });

    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: second.token,
        userId: me.userId,
        deviceId: OTHER_DEVICE,
      }),
    ).rejects.toThrow(/SESSION_REVOKED/);
  });

  test("purgeUser leaves no live session row behind", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "goksu");
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: me.token,
      userId: me.userId,
    });

    const live = await t.run(async (ctx) =>
      ctx.db
        .query("sessions")
        .withIndex("by_revoked_at", (q) => q.eq("revokedAt", undefined))
        .collect(),
    );
    expect(live).toHaveLength(0);
  });

  /**
   * The pre-existing-orphan case: rows written before `purgeUser` learned to
   * revoke. Nothing stamps `revokedAt` on these, so only the existence check
   * inside `requireSession` can stop them. That check is skipped once
   * `SESSION_TRUSTS_ROW` is on, which is why the flag is flipped only after
   * `sessions.auditLiveVsAccounts` reports no such row (done 2026-10-23); this
   * pins the non-trusting path the audit relies on.
   */
  test("a session orphaned by an older purge is refused too", async () => {
    const trusted = sessionFlags.trustsRow;
    sessionFlags.trustsRow = false;
    onTestFinished(() => {
      sessionFlags.trustsRow = trusted;
    });
    const t = convexTest(schema);
    const me = await signUp(t, "goksu");

    // Delete the user row directly, the way a purge from before the fix did:
    // no `revokedAt` is ever stamped, so the row still reads as live.
    await t.run(async (ctx) => ctx.db.delete(me.userId));

    // Deliberately NOT `whoami` — that one re-checks the account itself, so it
    // would reject here even with `requireSession` unfixed and prove nothing.
    // `listDevices` has no such check: before the fix it answered `[]` quite
    // happily for a deleted account, which is precisely how a purged user kept
    // a working session.
    await expect(
      t.query(api.voipTokens.listDevices, {
        sessionToken: me.token,
        userId: me.userId,
        deviceId: DEVICE,
      }),
    ).rejects.toThrow(/SESSION_REVOKED/);
  });
});

describe("whoami", () => {
  test("answers with the token's account", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "lulu");

    expect(await t.query(api.auth.whoami, { sessionToken: me.token })).toEqual({
      userId: me.userId,
      username: "lulu",
      name: "lulu",
      accountType: "adult",
    });
  });

  /**
   * The reason this function takes no arguments. A device whose keychain holds
   * one account's token beside another account's name is exactly the state
   * being fixed, and `whoami` is what lets it notice — so it must answer for
   * the token and nothing else.
   */
  test("two accounts get two different answers from the same call", async () => {
    const t = convexTest(schema);
    const goksu = await signUp(t, "goksu");
    const lulu = await t.mutation(api.auth.signup, {
      username: "lulu",
      name: "lulu",
      passwordHash: "hash-lulu",
      recoveryKeyHash: "recovery-lulu",
      deviceId: OTHER_DEVICE,
    });

    const a = await t.query(api.auth.whoami, { sessionToken: goksu.token });
    const b = await t.query(api.auth.whoami, { sessionToken: lulu.token });
    expect(a.username).toBe("goksu");
    expect(b.username).toBe("lulu");
    expect(a.userId).not.toBe(b.userId);
  });
});

/**
 * The backfill for sessions orphaned before `purgeUser` learned to revoke.
 *
 * Run by hand against production, so the thing that matters is that a second
 * run is harmless and the count means what it says.
 */
describe("orphaned session sweep", () => {
  async function orphan(t: ReturnType<typeof convexTest>, username: string) {
    const me = await signUp(t, username, `device-${username}`);
    // A purge from before the fix: the user row goes, the session stays live.
    await t.run(async (ctx) => ctx.db.delete(me.userId));
    return me;
  }

  test("counts the orphans and leaves healthy sessions alone", async () => {
    const t = convexTest(schema);
    await signUp(t, "lulu", "device-lulu");
    await orphan(t, "goksu");

    expect(await t.query(internal.sessions.countOrphaned, {})).toEqual({
      live: 2,
      orphaned: 1,
    });
  });

  test("revoking clears the count, and running again is a no-op", async () => {
    const t = convexTest(schema);
    const healthy = await signUp(t, "lulu", "device-lulu");
    await orphan(t, "goksu");

    expect(await t.mutation(internal.sessions.revokeOrphaned, {})).toEqual({
      revoked: 1,
      done: true,
    });
    expect(await t.mutation(internal.sessions.revokeOrphaned, {})).toEqual({
      revoked: 0,
      done: true,
    });
    expect(await t.query(internal.sessions.countOrphaned, {})).toEqual({
      live: 1,
      orphaned: 0,
    });

    // The account that still exists is untouched — a sweep that signed
    // everybody out would "fix" the count and break the app.
    await expect(
      t.query(api.auth.whoami, { sessionToken: healthy.token }),
    ).resolves.toMatchObject({ username: "lulu" });
  });
});
