# Chat folders

Telegram-style folders over the chat list. Owner of how the feature behaves;
UI rules live in `docs/architecture/ui-architecture.html`, backend rules in
`docs/backend/backend-handbook.html`.

## Behaviour

- **A folder is a rule, not a copy.** It takes in chat kinds (direct messages,
  groups), chats added by hand, and leaves out chats kept out by hand plus
  three switches: muted, read (nothing unread), archived (on by default).
  Precedence, same as Telegram: kept out by hand > added by hand > kinds and
  switches. The app applies it to the room list it already has
  (`ChatFolder.matches`, `lib/data/chat_folders.dart`).
- **Limits.** 10 folders per account, 100 chats added by hand and 100 kept out
  by hand per folder, names up to 24 characters. Enforced in the app and in
  `chatFolders.save` (`MAX_FOLDERS`, `MAX_FOLDER_ROOMS`, `MAX_FOLDER_NAME`).
  At the cap, "Create a Folder" is disabled and the footer says why.
- **Tabs.** With at least one folder, a strip of tabs ("All" + folders, each
  with its emoji and the number of its chats with something unread) sits under
  the search reveal. Tap selects; long-press opens Edit / Edit Folders / Delete.
  The selection persists (`SettingsStore.activeFolderId`); a deleted folder
  reads as All. Requests and the archived row show only in All. Filter chips
  still apply on top of a folder.
- **Chats tab long-press** (all tab bars, native UITabBar included): Edit
  Folders (Add Folder with none), All Chats, every folder with its unread count.
  Picking a folder lands on Chats with it selected.
- **Calls tab long-press:** Hide Calls Tab, with a toast pointing to
  Settings > Navigation, where the switch brings it back.
- **Chat row long-press:** Add to Folder (a menu of folders with checks, plus
  New Folder seeded with that chat) and, inside a folder, Remove from Folder.
  Removing a chat the folder takes by kind adds it to "kept out by hand".
- **Folder tags.** Each folder has an optional tag colour (7, Telegram's set;
  new folders take the first unused one). In All Chats a chat carries a small
  coloured chip per folder it is in (up to 3). Switch: Settings > Chat Folders >
  Show folder tags (default on).
- **Suggested folders:** Unread, Personal (direct messages), Groups; offered
  only while the account has no folder doing the same thing.
- **Sync:** folders live on the server, so they follow the account to every
  device. The last list is cached locally so the tabs draw at cold start, and
  cleared at sign-out.

Not done (Telegram has them): shareable folder invite links, swiping the list
sideways between folders (row swipes own that gesture), per-folder pinned order.

## Backend cost (R17)

| Action | Reads | Writes | Re-runs per recipient | Idle |
|---|---|---|---|---|
| `chatFolders:list` subscription | ≤ 10 rows, one index range | 0 | only the owner's, on their own folder edits | 0 (one index probe at subscribe; nothing for users without folders) |
| Create a folder | ≤ 11 (own folders) + rate bucket | 1 insert + bucket | 1 (owner) | 0 |
| Edit a folder / add a chat to it | 1 + bucket | 1 replace + bucket | 1 (owner) | 0 |
| Delete | 1 | 1 | 1 (owner) | 0 |
| Reorder | ≤ 10 + bucket | only rows whose position moved | 1 (owner) | 0 |

No fan-out, no jobs, nothing reads rooms or messages. Rows are ≤ ~8 KB worst
case and written only on user edits (not hot). Room ids are soft references:
the app ignores ids it is not a member of and drops them on its next save.
Account deletion cascades through `referenceRules.ts`.
