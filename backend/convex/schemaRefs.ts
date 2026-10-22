/**
 * Schema reference walker.
 *
 * Convex has no foreign keys, so every `v.id("table")` in the schema is a
 * reference that nothing enforces. This module lists them all so a test (and,
 * later, a paged orphan scan) can check each one has a rule in
 * `referenceRules.ts`.
 *
 * Pure and dependency-free on purpose: it takes the schema object (the default
 * export of `schema.ts`) and reads only what `defineSchema` / `defineTable`
 * expose at runtime:
 *   - `schema.tables[name].validator.json`: the table's field validators in
 *     Convex's JSON form (`{ type: "id", tableName }`, `object`, `array`,
 *     `union`, `record`, ...; object fields are `{ fieldType, optional }`);
 *   - `schema.tables[name].indexes`: `[{ indexDescriptor, fields }]`.
 * Nothing here imports Convex, so it also runs inside a Convex function.
 *
 * Path syntax: dotted for object fields (`replyToPreview.senderId`), `[]` for
 * array elements (`mentions[].userId`), `{}` for record values. Fields shared
 * by several union branches are reported once.
 */

export interface SchemaRef {
  /** Table that holds the reference. */
  table: string;
  /** Path to the field inside a document of that table. */
  path: string;
  /** Referenced table; `_storage` for file references. */
  target: string;
  /** True when the path passes through an array (or record) element. */
  array: boolean;
  /** True when the field may be absent (itself, or any object on the way). */
  optional: boolean;
}

export interface SchemaIndex {
  name: string;
  fields: string[];
}

/** The slice of the schema this module reads. */
export interface SchemaLike {
  tables: Record<string, any>;
}

type Found = { path: string; target: string; array: boolean; optional: boolean };

function walk(
  node: any,
  path: string,
  array: boolean,
  optional: boolean,
  out: Found[],
): void {
  if (!node || typeof node !== "object") return;
  switch (node.type) {
    case "id":
      out.push({ path, target: node.tableName, array, optional });
      return;
    case "object":
      for (const [key, field] of Object.entries<any>(node.value ?? {})) {
        walk(
          field.fieldType,
          path === "" ? key : `${path}.${key}`,
          array,
          optional || field.optional === true,
          out,
        );
      }
      return;
    case "array":
      walk(node.value, `${path}[]`, true, optional, out);
      return;
    case "record":
      walk(node.values?.fieldType, `${path}{}`, true, optional, out);
      return;
    case "union":
      for (const branch of node.value ?? []) walk(branch, path, array, optional, out);
      return;
    default:
      return;
  }
}

/** Every reference path in the schema, sorted by table then path. */
export function schemaRefs(schema: SchemaLike): SchemaRef[] {
  const refs: SchemaRef[] = [];
  for (const [table, def] of Object.entries(schema.tables)) {
    const found: Found[] = [];
    walk(def.validator?.json, "", false, false, found);
    const seen = new Map<string, SchemaRef>();
    for (const f of found) {
      const key = `${f.path}->${f.target}`;
      const prior = seen.get(key);
      if (prior) {
        // Same path in several union branches: optional if any branch is.
        prior.optional = prior.optional || f.optional;
        continue;
      }
      seen.set(key, { table, ...f });
    }
    refs.push(...seen.values());
  }
  return refs.sort((a, b) =>
    a.table === b.table
      ? a.path.localeCompare(b.path)
      : a.table.localeCompare(b.table),
  );
}

/** Indexes of one table, by name. */
export function tableIndexes(schema: SchemaLike, table: string): SchemaIndex[] {
  const idx: any[] = schema.tables[table]?.indexes ?? [];
  return idx.map((i) => ({ name: i.indexDescriptor, fields: [...i.fields] }));
}

/** `"table.path"`, the key `REFERENCE_RULES` uses. */
export function refKey(ref: { table: string; path: string }): string {
  return `${ref.table}.${ref.path}`;
}
