# Docs

Every fact has one home. Find the doc that owns the topic below, read it before
working in that area, and update it in the same commit as the change. Never
copy a rule into a second doc; link to its owner instead.

## Handbooks (living, kept current)

| Doc | Owns |
|---|---|
| `architecture/ui-architecture.html` | All UI and client architecture: rules, layers, `Caps`, UI kits, **native iOS glass controls** (§4, "The liquid kit's native controls", incl. how to add a kind), component catalog, layout. §9 bugs found, §10 checklist for new work, §11 decisions. |
| `backend/backend-handbook.html` | All Convex backend work: rules R1-R19, per-action budgets, improvement plan. |

## Feature designs (living, one per feature)

| Doc | Owns |
|---|---|
| `design/calls.md` | Call bubbles, Calls tab (rows, merged rows, details sheet), call stats, favourites. |
| `design/chat-chrome-language.md` | Chat chrome motion and look. |
| `design/swipe-up-fork.html` | Swipe-up fork (huddle, vanish, room sheet, dock). |
| `fighting-game/` | Jungle Fist plan and its style and roster labs. |
| `GLASS_SPEC.md` | The Signal iOS 26 visual and motion target for sheets and glass (reference frames in `glass_reference/`). |

## Records (dated snapshots, not maintained)

Plans, handoffs and audits as they were on their date. Read for history; the
handbooks and designs above win where they differ.

`glass-handoff.md`, `call-quality-2026-11-05.md`, `security-audit-2026-10-15.md`,
`data-integrity-*.md`, `backend/c1-cursors-design.md`.

## Where things go

- **A bug that taught something** → the owning handbook's bugs table (for UI:
  `ui-architecture.html` §9), plus a checklist line (§10) if it should change
  how future work is done.
- **A decision or a rejected alternative** → the owning handbook's decisions
  log (§11), and the feature design if it is about one feature.
- **How a feature behaves** → its `design/` doc.
- **A new feature** → a new `design/` doc and a row in the table above.
- **A one-off plan or handoff** → a dated record; never edit it later.
