import {
  internalMutation as baseInternalMutation,
  mutation as baseMutation,
} from "./_generated/server";
import { COUNTED_FIELDS, applyMessageChange } from "./contentCountsCore";

/**
 * Write hooks: derived data kept true by the database layer itself, rather
 * than by every call site remembering to update it.
 *
 * Every mutation in the backend is built from the two builders below (the
 * authenticated ones in `functions.ts` wrap [mutation]). Each hands its
 * handler a `ctx.db` that behaves exactly like Convex's, except that a write
 * to a hooked table also runs that table's hook in the same transaction. So a
 * derived row commits or rolls back with the write that moved it.
 *
 * `dbHooks.test.ts` fails if any file imports `mutation` or
 * `internalMutation` from `_generated/server` directly, which is the only way
 * to write without the hooks.
 *
 * ## Hooks
 *
 *  - `messages` → `roomContentCounts` (see `contentCounts.ts`). Inserts cost
 *    nothing extra to classify. A patch that touches none of
 *    [COUNTED_FIELDS] (reactions, receipts, edits to text without links,
 *    the bulk of message writes) returns before any read. A delete or replace
 *    reads the old row once.
 */

const HOOKED = "messages";

function touchesCounted(value: Record<string, unknown> | undefined): boolean {
  if (!value) return false;
  for (const k of COUNTED_FIELDS) if (k in value) return true;
  return false;
}

/**
 * The id and table a write was aimed at, from either call shape:
 * `patch(id, value)` or `patch("table", id, value)`.
 */
function target(db: any, args: any[]): { id: any; rest: any[]; hooked: boolean } {
  if (typeof args[0] === "string" && args.length >= 2 && typeof args[1] === "string") {
    // The two-string form is ambiguous only in shape: a table name is never an
    // id, and `normalizeId` settles which one this is.
    if (db.normalizeId(args[0], args[1]) !== null) {
      return { id: args[1], rest: args.slice(2), hooked: args[0] === HOOKED };
    }
  }
  const id = args[0];
  return { id, rest: args.slice(1), hooked: db.normalizeId(HOOKED, id) !== null };
}

export function hookDb(db: any): any {
  const overrides: Record<string, any> = {
    async insert(table: string, value: any) {
      const id = await db.insert(table, value);
      if (table === HOOKED) await applyMessageChange(db, null, value);
      return id;
    },
    async patch(...args: any[]) {
      const { id, rest, hooked } = target(db, args);
      const value = rest[0];
      if (!hooked || !touchesCounted(value)) return db.patch(...args);
      const before = await db.get(id);
      await db.patch(...args);
      // An `undefined` in a patch unsets the field, and reads as unset to
      // `contribution` too, so the merge is exact.
      await applyMessageChange(db, before, before ? { ...before, ...value } : null);
    },
    async replace(...args: any[]) {
      const { id, rest, hooked } = target(db, args);
      if (!hooked) return db.replace(...args);
      const before = await db.get(id);
      await db.replace(...args);
      await applyMessageChange(db, before, { ...rest[0], roomId: rest[0]?.roomId ?? before?.roomId });
    },
    async delete(...args: any[]) {
      const { id, hooked } = target(db, args);
      if (!hooked) return db.delete(...args);
      const before = await db.get(id);
      await db.delete(...args);
      if (before) await applyMessageChange(db, before, null);
    },
  };
  return new Proxy(db, {
    get(t, prop, _receiver) {
      if (typeof prop === "string" && prop in overrides) return overrides[prop];
      const value = Reflect.get(t, prop, t);
      return typeof value === "function" ? value.bind(t) : value;
    },
  });
}

/**
 * The handler's context with the hooked `db`. A spread, not a prototype
 * wrapper: `deletionCore.ts` spreads the context it is given, and a spread of
 * a prototype wrapper keeps only its own keys, losing `scheduler` and
 * `storage`. That same spread, live in production, is the evidence that
 * Convex's context keys are own and enumerable.
 */
function hookCtx(ctx: any): any {
  return { ...ctx, db: hookDb(ctx.db) };
}

function hooked(builder: any): any {
  return (def: any) => {
    if (typeof def === "function") {
      return builder((ctx: any, args: any) => def(hookCtx(ctx), args));
    }
    return builder({
      ...def,
      handler: (ctx: any, args: any) => def.handler(hookCtx(ctx), args),
    });
  };
}

/** `internalMutation`, with the write hooks. Import this, never the generated one. */
export const internalMutation: typeof baseInternalMutation = hooked(baseInternalMutation);

/** `mutation`, with the write hooks. `functions.ts` builds every public mutation on it. */
export const mutation: typeof baseMutation = hooked(baseMutation);
