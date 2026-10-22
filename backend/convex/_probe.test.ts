import { test } from "vitest";
import schema from "./schema";
import { schemaRefs, tableIndexes } from "./schemaRefs";
test("p", () => {
  const r = schemaRefs(schema as any);
  console.log(r.length, new Set(r.map(x=>x.table)).size);
  const by: Record<string,string[]> = {};
  for (const x of r) { const idxs = tableIndexes(schema as any, x.table).filter(i=>i.fields[0]===x.path).map(i=>i.name);
    (by[x.table] ??= []).push(`${x.path}>${x.target}${x.array?"[]":""}${x.optional?"?":""} {${idxs.join(",")}}`); }
  for (const [t,l] of Object.entries(by)) console.log(t+": "+l.join(" | "));
});
