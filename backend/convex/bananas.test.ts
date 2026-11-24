import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import {
  BUNDLES,
  LAUNCH_AT,
  LIST_PRICES,
  PACKS,
  SINGLES,
  fighterItem,
  firstPickEligible,
  isFreeGame,
  isOwnedItem,
  itemPrice,
  ownsGame,
  stageItem,
} from "./catalog";

/**
 * Bananas & unlocks: the catalog math, buying, the launch gift and weekly
 * allowance, kids asking guardians, the RevenueCat webhook, and the match
 * gates. docs/design/bananas-and-unlocks.html.
 */

type T = ReturnType<typeof convexTest>;
type Who = { token: string; userId: any };

async function signUp(t: T, username: string): Promise<Who> {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  })) as Who;
}

const as = (w: Who) => ({ sessionToken: w.token, userId: w.userId });
const asG = (w: Who) => ({ sessionToken: w.token, guardianId: w.userId });

/** Sets a wallet directly (the way a pack or the ledger would have). */
async function fund(t: T, w: Who, balance: number, extra: Record<string, unknown> = {}) {
  await t.run(async (ctx) => {
    const row = await (ctx.db.query("lifelines") as any)
      .withIndex("by_user", (q: any) => q.eq("userId", w.userId))
      .first();
    if (row) await ctx.db.patch(row._id, { balance, ...extra });
    else await ctx.db.insert("lifelines", { userId: w.userId, balance, updatedAt: 0, ...extra });
  });
}

const wallet = (t: T, w: Who) => t.query(api.lifelines.mine, as(w)) as Promise<any>;
const buy = (t: T, w: Who, item: string, firstPick?: boolean) =>
  t.mutation(api.unlocks.buy, { ...as(w), item, firstPick }) as Promise<any>;

async function family(t: T) {
  const parent = await signUp(t, "parent");
  const kid = await t.mutation(api.family.createChildAccount, {
    ...asG(parent),
    username: "lena",
    name: "lena",
  });
  await t.mutation(api.family.createPairingCode, {
    ...asG(parent),
    childId: kid.userId,
    codeHash: "pair-lena",
  });
  const r = await t.mutation(api.family.redeemPairingCode as any, {
    codeHash: "pair-lena",
    deviceId: "child-device",
    platform: "ios",
  });
  const child: Who = { token: r.token, userId: kid.userId };
  return { parent, child };
}

const rules = (t: T, parent: Who, child: Who, r: any) =>
  t.mutation(api.family.setBananaRules, { ...asG(parent), childId: child.userId, ...r }) as Promise<any>;
const ask = (t: T, child: Who, item: string, extra: any = {}) =>
  t.mutation(api.bananaRequests.ask, { ...as(child), item, ...extra }) as Promise<any>;
const answer = (t: T, g: Who, requestId: any, action: any, amount?: number) =>
  t.mutation(api.bananaRequests.answer, { ...as(g), requestId, action, amount }) as Promise<any>;

describe("the catalog", () => {
  test("ids and list prices", () => {
    expect(SINGLES["fighter.mojo"]).toBe(60);
    expect(SINGLES["fighter.nyx"]).toBe(90);
    expect(SINGLES["fighter.golem"]).toBe(90);
    expect(SINGLES["stage.deck"]).toBe(40);
    expect(SINGLES["look.pixel"]).toBe(120);
    expect(SINGLES["game.chess"]).toBe(150);
    expect(SINGLES["fighter.kai"]).toBeUndefined();
    expect(Object.keys(SINGLES).filter((k) => k.startsWith("fighter."))).toHaveLength(15);
    expect(BUNDLES["bundle.animals"].members).toHaveLength(10);
    expect(BUNDLES["bundle.legends"].members).toHaveLength(5);
    expect(BUNDLES["bundle.fist"].members).toHaveLength(15 + 5 + 2);
    expect(BUNDLES["bundle.gamenight"].members).toHaveLength(6);
    expect(LIST_PRICES["bundle.fist"]).toBe(990);
    expect(PACKS["monkeyhub.bananas.jungle"]).toBe(6000);
    expect(LAUNCH_AT).toBe(Date.parse("2026-12-01"));
  });

  test("free things are free", () => {
    for (const g of ["tictactoe", "connectfour", "dots", "fight"]) expect(isFreeGame(g)).toBe(true);
    for (const g of ["chess", "checkers", "reversi", "imposter", "liarsdice", "race"]) {
      expect(isFreeGame(g)).toBe(false);
    }
    expect(ownsGame([], "dots")).toBe(true);
    expect(ownsGame([], "chess")).toBe(false);
    expect(ownsGame(["game.chess"], "chess")).toBe(true);
    expect(fighterItem(0)).toBeNull();
    expect(fighterItem(12)).toBeNull();
    expect(fighterItem(3)).toBe("fighter.nyx");
    expect(fighterItem(19)).toBe("fighter.golem");
    expect(stageItem(0)).toBeNull();
    expect(stageItem(5)).toBe("stage.deck");
  });

  test("complete-the-set pricing", () => {
    expect(itemPrice("bundle.animals", [])).toBe(450);
    // 540 of 600 left: ceil(450 * 540 / 600) = 405.
    expect(itemPrice("bundle.animals", ["fighter.mojo"])).toBe(405);
    expect(itemPrice("bundle.stages", ["stage.neon", "stage.deck"])).toBe(Math.ceil((150 * 120) / 200));
    expect(itemPrice("fighter.mojo", ["fighter.mojo"])).toBe(0);
    expect(itemPrice("nope")).toBeNull();
    const all = [...BUNDLES["bundle.animals"].members];
    expect(itemPrice("bundle.animals", all)).toBe(0);
    expect(isOwnedItem(all, "bundle.animals")).toBe(true);
    expect(isOwnedItem(all.slice(1), "bundle.animals")).toBe(false);
  });

  test("first pick is a single fighter or stage worth at most 90", () => {
    expect(firstPickEligible("fighter.golem")).toBe(true);
    expect(firstPickEligible("stage.neon")).toBe(true);
    expect(firstPickEligible("look.painted")).toBe(false);
    expect(firstPickEligible("game.chess")).toBe(false);
    expect(firstPickEligible("bundle.animals")).toBe(false);
  });
});

describe("buying", () => {
  test("buys a single, takes the price, writes a ledger row", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await fund(t, me, 100);
    const r = await buy(t, me, "fighter.mojo");
    expect(r).toEqual({ balance: 40, owned: ["fighter.mojo"] });
    const w = await wallet(t, me);
    expect(w.owned).toEqual(["fighter.mojo"]);
    expect(w.child).toBeNull();
    expect(w.prices["game.chess"]).toBe(150);
    const ledger = await t.run((ctx) => ctx.db.query("bananaLedger").collect());
    expect(ledger).toHaveLength(1);
    expect(ledger[0]).toMatchObject({ kind: "unlock", amount: -60, item: "fighter.mojo" });
    await expect(buy(t, me, "fighter.mojo")).rejects.toThrow("OWNED");
  });

  test("refusals: unknown, no bananas", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await expect(buy(t, me, "fighter.kai")).rejects.toThrow("UNKNOWN_ITEM");
    await expect(buy(t, me, "game.chess")).rejects.toThrow("NO_BANANAS");
    await fund(t, me, 149);
    await expect(buy(t, me, "game.chess")).rejects.toThrow("NO_BANANAS");
  });

  test("a bundle prices the rest of the set and stores its members", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await fund(t, me, 1000);
    await buy(t, me, "fighter.mojo");
    const r = await buy(t, me, "bundle.animals");
    expect(r.balance).toBe(1000 - 60 - 405);
    expect(r.owned).toHaveLength(10);
    expect(r.owned).not.toContain("bundle.animals");
    await expect(buy(t, me, "bundle.animals")).rejects.toThrow("OWNED");
  });

  test("first pick: one free single fighter or stage, once", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    expect((await wallet(t, me)).firstPickReady).toBe(true);
    await expect(buy(t, me, "look.painted", true)).rejects.toThrow("NOT_ELIGIBLE");
    await expect(buy(t, me, "bundle.stages", true)).rejects.toThrow("NOT_ELIGIBLE");
    await expect(buy(t, me, "game.chess", true)).rejects.toThrow("NOT_ELIGIBLE");
    const r = await buy(t, me, "fighter.golem", true);
    expect(r).toEqual({ balance: 0, owned: ["fighter.golem"] });
    expect((await wallet(t, me)).firstPickReady).toBe(false);
    await expect(buy(t, me, "stage.neon", true)).rejects.toThrow("FIRST_PICK_USED");
  });

  test("a child buys only when the guardian allows it", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    await fund(t, child, 500);
    expect((await wallet(t, child)).child).toEqual({ ask: true, spend: "all" });
    expect((await buy(t, child, "game.chess")).balance).toBe(350);
    await rules(t, parent, child, { spend: "lifelines" });
    await expect(buy(t, child, "game.reversi")).rejects.toThrow("CHILD_ASK");
    await rules(t, parent, child, { spend: "none" });
    await expect(buy(t, child, "stage.neon")).rejects.toThrow("CHILD_ASK");
    // The free first pick is not spending.
    expect((await buy(t, child, "stage.neon", true)).balance).toBe(350);
  });
});

describe("welcome", () => {
  test("the launch gift comes once, to accounts older than launch", async () => {
    const t = convexTest(schema);
    const old = await signUp(t, "old");
    const fresh = await signUp(t, "fresh");
    await t.run(async (ctx) => {
      await ctx.db.patch(old.userId, { createdAt: LAUNCH_AT - 1000 });
      await ctx.db.patch(fresh.userId, { createdAt: LAUNCH_AT + 1000 });
    });
    const w = (who: Who) => t.mutation(api.lifelines.welcome, as(who)) as Promise<any>;
    expect((await w(old)).gift).toBe(150);
    expect((await w(old)).gift).toBe(0);
    expect((await wallet(t, old)).balance).toBe(150);
    expect((await w(fresh)).gift).toBe(0);
    const led = await t.run((ctx) => ctx.db.query("bananaLedger").collect());
    expect(led.map((r) => r.kind)).toEqual(["launchGift"]);
  });

  test("a child's allowance is paid weekly by the guardian who set it, never owed", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    await t.run(async (ctx) => {
      await ctx.db.patch(child.userId, { createdAt: LAUNCH_AT + 1 });
    });
    const w = () => t.mutation(api.lifelines.welcome, as(child)) as Promise<any>;
    await rules(t, parent, child, { allowancePerWeek: 50 });
    // Parent is broke: skipped, not owed.
    expect((await w()).allowance).toBe(0);
    await fund(t, parent, 120);
    expect((await w()).allowance).toBe(50);
    expect((await w()).allowance).toBe(0);
    expect((await wallet(t, child)).balance).toBe(50);
    expect((await wallet(t, parent)).balance).toBe(70);
    // Next week it pays again.
    await t.run(async (ctx) => {
      const row = await ctx.db.query("lifelines").withIndex("by_user", (q: any) => q.eq("userId", child.userId)).first();
      await ctx.db.patch(row!._id, { allowanceWeek: 1 });
    });
    expect((await w()).allowance).toBe(50);
    await expect(rules(t, parent, child, { allowancePerWeek: 30 })).rejects.toThrow("BAD_RULE");
  });
});

describe("kids asking", () => {
  test("ask, then approve: the guardian pays the current price and it lands on the child", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    await fund(t, parent, 200);
    const { requestId } = await ask(t, child, "game.chess", { note: "pls", sticker: "🙏" });
    const mine = await t.query(api.bananaRequests.mine, as(child));
    expect(mine).toHaveLength(1);
    expect(mine[0]).toMatchObject({ item: "game.chess", price: 150, status: "open" });

    const q: any[] = await t.query(api.family.listGuardianQueue, asG(parent));
    const item = q.find((i) => i.kind === "banana");
    expect(item).toMatchObject({
      requestId, childId: child.userId, childName: "lena", item: "game.chess",
      price: 150, note: "pls", sticker: "🙏",
    });

    const res = await answer(t, parent, requestId, "approve");
    expect(res).toEqual({ status: "approved", guardianBalance: 50 });
    expect((await wallet(t, child)).owned).toEqual(["game.chess"]);
    expect(await t.query(api.bananaRequests.mine, as(child))).toHaveLength(0);
    expect((await t.query(api.family.listGuardianQueue, asG(parent))).filter((i: any) => i.kind === "banana")).toHaveLength(0);
    await expect(answer(t, parent, requestId, "decline")).rejects.toThrow("ALREADY_ANSWERED");
    const hist: any[] = await t.query(api.family.bananaHistory, { ...asG(parent), childId: child.userId });
    expect(hist.map((h) => h.kind)).toEqual(["unlockedBy"]);
  });

  test("approve needs the guardian's own bananas", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    await fund(t, parent, 149);
    const { requestId } = await ask(t, child, "game.chess");
    await expect(answer(t, parent, requestId, "approve")).rejects.toThrow("NO_BANANAS");
    expect((await wallet(t, child)).owned).toEqual([]);
  });

  test("gift moves bananas instead; decline closes; strangers cannot answer", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const stranger = await signUp(t, "stranger");
    await fund(t, parent, 100);
    const a = await ask(t, child, "game.chess");
    await expect(answer(t, stranger, a.requestId, "approve")).rejects.toThrow("NOT_A_GUARDIAN");
    await expect(answer(t, parent, a.requestId, "gift", 0)).rejects.toThrow("BAD_AMOUNT");
    await expect(answer(t, parent, a.requestId, "gift", 1001)).rejects.toThrow("BAD_AMOUNT");
    const g = await answer(t, parent, a.requestId, "gift", 40);
    expect(g).toEqual({ status: "gifted", guardianBalance: 60 });
    expect((await wallet(t, child)).balance).toBe(40);
    const b = await ask(t, child, "stage.neon");
    expect((await answer(t, parent, b.requestId, "decline")).status).toBe("declined");
    expect((await wallet(t, child)).owned).toEqual([]);
  });

  test("limits: not a child, ask off, owned, duplicate, 3 open, decline cooldown, withdraw", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    await expect(ask(t, parent, "game.chess")).rejects.toThrow("NOT_CHILD");
    await expect(ask(t, child, "fighter.kai")).rejects.toThrow("UNKNOWN_ITEM");

    await rules(t, parent, child, { ask: false });
    await expect(ask(t, child, "game.chess")).rejects.toThrow("ASK_OFF");
    await rules(t, parent, child, { ask: true });

    const a = await ask(t, child, "game.chess");
    await expect(ask(t, child, "game.chess")).rejects.toThrow("ALREADY_ASKED");
    await ask(t, child, "stage.neon");
    await ask(t, child, "stage.deck");
    await expect(ask(t, child, "game.reversi")).rejects.toThrow("TOO_MANY");

    // Withdrawing frees a slot (and the item).
    await t.mutation(api.bananaRequests.withdraw, { ...as(child), requestId: a.requestId });
    await expect(
      t.mutation(api.bananaRequests.withdraw, { ...as(child), requestId: a.requestId }),
    ).rejects.toThrow("ALREADY_ANSWERED");
    const again = await ask(t, child, "game.chess");

    // A decline blocks the same item for 24h.
    await answer(t, parent, again.requestId, "decline");
    await expect(ask(t, child, "game.chess")).rejects.toThrow("COOLDOWN");
    await t.run(async (ctx) => {
      for (const r of await ctx.db.query("bananaRequests").collect()) {
        if (r.status === "declined") await ctx.db.patch(r._id, { decidedAt: Date.now() - 25 * 3_600_000 });
      }
    });
    await ask(t, child, "game.chess").catch((e) => expect(String(e)).toContain("TOO_MANY"));

    // Owned items are not askable.
    await fund(t, child, 0, { owned: ["game.reversi"] });
    await expect(ask(t, child, "game.reversi")).rejects.toThrow("OWNED");
  });

  test("open asks expire after 7 days, on read", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    await fund(t, parent, 500);
    const { requestId } = await ask(t, child, "game.chess");
    await t.run((ctx) => ctx.db.patch(requestId, { createdAt: Date.now() - 8 * 86_400_000 }));
    expect(await t.query(api.bananaRequests.mine, as(child))).toHaveLength(0);
    expect((await t.query(api.family.listGuardianQueue, asG(parent))).filter((i: any) => i.kind === "banana")).toHaveLength(0);
    await expect(answer(t, parent, requestId, "approve")).rejects.toThrow("EXPIRED");
    // An expired ask does not block asking again.
    await ask(t, child, "game.chess");
  });

  test("auto-yes approves inside the weekly budget when the guardian can pay", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    await fund(t, parent, 1000);
    await rules(t, parent, child, { autoYesPerWeek: 120 });
    const a = await ask(t, child, "stage.neon"); // 40
    expect(a.status).toBe("approved");
    expect((await wallet(t, child)).owned).toEqual(["stage.neon"]);
    expect((await wallet(t, parent)).balance).toBe(960);
    await ask(t, child, "stage.deck"); // 80 total
    // 80 + 80 > 120: goes to the queue instead.
    const c = await ask(t, child, "game.reversi");
    expect(c.status).toBe("open");
    const r: any = await t.query(api.family.bananaRules, { ...asG(parent), childId: child.userId });
    expect(r).toMatchObject({ autoYesPerWeek: 120, autoYesSpent: 80, autoYesByMe: true });
    // A broke guardian cannot auto-approve.
    await fund(t, parent, 10);
    expect((await ask(t, child, "stage.aurora")).status).toBe("open");
  });

  test("sendBananas and rules need a guardian", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const stranger = await signUp(t, "stranger");
    await fund(t, parent, 30);
    await expect(
      t.mutation(api.family.sendBananas, { ...asG(stranger), childId: child.userId, amount: 5 }),
    ).rejects.toThrow("NOT_A_GUARDIAN");
    await expect(
      t.mutation(api.family.sendBananas, { ...asG(parent), childId: child.userId, amount: 31 }),
    ).rejects.toThrow("NO_BANANAS");
    const r = await t.mutation(api.family.sendBananas, { ...asG(parent), childId: child.userId, amount: 10 });
    expect(r).toEqual({ guardianBalance: 20 });
    expect((await wallet(t, child)).balance).toBe(10);
    await expect(rules(t, stranger, child, { ask: false })).rejects.toThrow("NOT_A_GUARDIAN");
    await expect(
      t.query(api.family.bananaHistory, { ...asG(stranger), childId: child.userId }),
    ).rejects.toThrow("NOT_A_GUARDIAN");
    const hist: any[] = await t.query(api.family.bananaHistory, { ...asG(parent), childId: child.userId });
    expect(hist).toHaveLength(1);
    expect(hist[0]).toMatchObject({ kind: "giftReceived", amount: 10 });
  });
});

describe("the RevenueCat webhook", () => {
  const OLD = process.env.REVENUECAT_WEBHOOK_AUTH;
  beforeEach(() => {
    process.env.REVENUECAT_WEBHOOK_AUTH = "Bearer s3cret";
  });
  afterEach(() => {
    if (OLD === undefined) delete process.env.REVENUECAT_WEBHOOK_AUTH;
    else process.env.REVENUECAT_WEBHOOK_AUTH = OLD;
  });

  const post = (t: T, event: any, auth: string | null = "Bearer s3cret") =>
    t.fetch("/revenuecat", {
      method: "POST",
      headers: auth === null ? {} : { Authorization: auth },
      body: JSON.stringify({ event }),
    });
  const purchase = (me: Who, product: string, tx: string, type = "NON_RENEWING_PURCHASE") => ({
    type,
    app_user_id: me.userId,
    product_id: product,
    transaction_id: tx,
    environment: "PRODUCTION",
  });

  test("bad or missing auth is 401 and credits nothing", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ev = purchase(me, "monkeyhub.bananas.basket", "tx1");
    expect((await post(t, ev, "Bearer nope")).status).toBe(401);
    expect((await post(t, ev, null)).status).toBe(401);
    delete process.env.REVENUECAT_WEBHOOK_AUTH;
    expect((await post(t, ev, "Bearer s3cret")).status).toBe(401);
    expect((await wallet(t, me)).balance).toBe(0);
  });

  test("the first pack pays double, later ones pay face value, a retry pays nothing", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    expect((await wallet(t, me)).firstPackBonus).toBe(true);
    expect((await post(t, purchase(me, "monkeyhub.bananas.basket", "tx1"))).status).toBe(200);
    expect((await wallet(t, me)).balance).toBe(900);
    expect((await wallet(t, me)).firstPackBonus).toBe(false);
    await post(t, purchase(me, "monkeyhub.bananas.basket", "tx1"));
    expect((await wallet(t, me)).balance).toBe(900);
    await post(t, purchase(me, "monkeyhub.bananas.handful", "tx2", "INITIAL_PURCHASE"));
    expect((await wallet(t, me)).balance).toBe(980);
  });

  test("a refund takes back what that purchase paid, once", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await post(t, purchase(me, "monkeyhub.bananas.handful", "tx1")); // 160 (doubled)
    await buy(t, me, "game.chess"); // 150 -> 10 left
    const refund = purchase(me, "monkeyhub.bananas.handful", "tx1", "CANCELLATION");
    expect((await post(t, refund)).status).toBe(200);
    expect((await wallet(t, me)).balance).toBe(-150);
    await post(t, refund);
    expect((await wallet(t, me)).balance).toBe(-150);
    const led = await t.run((ctx) => ctx.db.query("bananaLedger").collect());
    expect(led.filter((r) => r.kind === "refund")).toHaveLength(1);
  });

  test("unknown users, products and event types are 200 and ignored", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    expect((await post(t, { ...purchase(me, "monkeyhub.bananas.basket", "a"), app_user_id: "$RCAnonymousID:abc" })).status).toBe(200);
    expect((await post(t, purchase(me, "some.other.product", "b"))).status).toBe(200);
    expect((await post(t, { type: "TEST", app_user_id: me.userId })).status).toBe(200);
    expect((await post(t, purchase(me, "monkeyhub.bananas.basket", "c", "RENEWAL"))).status).toBe(200);
    expect((await wallet(t, me)).balance).toBe(0);
  });
});

describe("match gates", () => {
  async function table(t: T) {
    const host = await signUp(t, "host");
    const guest = await signUp(t, "guest");
    const roomId = await t.mutation(api.rooms.create, { ...as(host), name: "night", isPrivate: false });
    await t.mutation(api.rooms.join, { ...as(guest), roomId });
    return { host, guest, roomId };
  }
  const create = (t: T, w: Who, roomId: any, game: string) =>
    t.mutation(api.matches.create, { ...as(w), roomId, game, mode: "live" } as any) as Promise<any>;

  test("a locked game needs the caller to own it; free games always start", async () => {
    const t = convexTest(schema);
    const { host, guest, roomId } = await table(t);
    await expect(create(t, host, roomId, "chess")).rejects.toThrow("LOCKED_GAME");
    for (const g of ["tictactoe", "connectfour", "dots"]) {
      const room = await t.mutation(api.rooms.create, { ...as(host), name: g, isPrivate: false });
      expect((await create(t, host, room, g)).matchId).toBeTruthy();
    }
    await fund(t, host, 0, { owned: ["game.chess"] });
    const { matchId } = await create(t, host, roomId, "chess");
    // Joining never checks: the host's unlock covers the guest.
    await t.mutation(api.matches.join, { ...as(guest), matchId });
    // The guest does not own it, so they cannot start their own.
    await expect(create(t, guest, roomId, "chess")).rejects.toThrow("LOCKED_GAME");
  });

  test("a rematch is a new send: the asker must own the game", async () => {
    const t = convexTest(schema);
    const { host, guest, roomId } = await table(t);
    await fund(t, host, 0, { owned: ["game.chess"] });
    const { matchId } = await create(t, host, roomId, "chess");
    await t.mutation(api.matches.join, { ...as(guest), matchId });
    await t.run((ctx) => ctx.db.patch(matchId, { status: "finished" }));
    await expect(t.mutation(api.matches.rematch, { ...as(guest), matchId })).rejects.toThrow("LOCKED_GAME");
    const again = (await t.mutation(api.matches.rematch, { ...as(host), matchId })) as any;
    expect(again.matchId).toBeTruthy();
  });

  test("startTurns refuses a locked game", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    await t.mutation(api.friends.sendRequest, { ...as(a), friendUsername: "bob" });
    await t.mutation(api.friends.acceptRequest, { ...as(b), requesterId: a.userId });
    const roomId = await t.mutation(api.rooms.getOrCreateDM, {
      sessionToken: a.token, userId: a.userId, friendId: b.userId,
    });
    await expect(
      t.mutation(api.matches.startTurns, { ...as(a), roomId, game: "chess", move: "e2e4", clientMoveId: "m1" }),
    ).rejects.toThrow("LOCKED_GAME");
  });

  test("setPick: locked fighters and stages need the picker's own unlock; random and free are fine", async () => {
    const t = convexTest(schema);
    const { host, guest, roomId } = await table(t);
    const { matchId } = await create(t, host, roomId, "fight");
    await t.mutation(api.matches.join, { ...as(guest), matchId });
    const pick = (w: Who, a: any) =>
      t.mutation(api.matches.setPick, { ...as(w), matchId, ...a }) as Promise<any>;

    await pick(host, { pick: 0, stage: 0 }); // free human, free stage
    await pick(host, { pick: -1, stage: -1 }); // random
    await expect(pick(host, { pick: 1 })).rejects.toThrow("LOCKED_FIGHTER");
    await expect(pick(host, { stage: 2 })).rejects.toThrow("LOCKED_STAGE");

    await fund(t, host, 0, { owned: ["fighter.mojo", "stage.neon"] });
    await pick(host, { pick: 1, stage: 2 });
    // The guest's own picks are checked against the guest's wallet.
    await expect(pick(guest, { pick: 1 })).rejects.toThrow("LOCKED_FIGHTER");
    await pick(guest, { pick: 12 });
    // A guest's stage is ignored (the host's call), so it is not checked.
    await pick(guest, { stage: 4 });
  });
});
