# Account Lifecycle Audit (superseded)

Superseded on 2026-10-22 by
[`docs/data-integrity-and-scale-plan-2026-10-22.md`](docs/data-integrity-and-scale-plan-2026-10-22.md).

The old audit was removed because it had gone stale: its line numbers no longer
pointed at the code it described, and several of its claims (for example which
tables `purgeUser` cleans, and what a deleted account leaves behind) stopped
being true as the teardown was fixed and the schema grew.

Where to look instead:

- What deleting an account or room leaves behind, and the rule for every
  reference: section 2 of the plan, and `backend/convex/referenceRules.ts`
  (enforced by `referenceRules.test.ts`).
- What the live database actually contains: `backend/convex/integrity.ts`, the
  weekly paged integrity check (`internal.integrity.latest`).
- What is fixed and what is still open: the phases in section 6 of the plan.
