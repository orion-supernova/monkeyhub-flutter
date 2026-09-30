# Deploying MonkeyHub

`./deploy.sh` ships the Convex backend, iOS, and Android. Run it with no flags
in a terminal to get the interactive picker:

```
Select what to deploy  (↑/↓ move · space toggle · enter go · tab stage · f force-update)
  ❯ ◉ Convex backend
    ◯ iOS  → App Store Connect
    ◯ macOS → App Store Connect (TestFlight)
    ◯ Android → Google Play (internal track)
    ◯ Web  → https://monkeyhub.walhallaa.com/web/
    ◯ Site → https://monkeyhub.walhallaa.com  (pages only, no build)
    ◯ Bump version (patch)

  [f] Force-update channels (edit minSupported)…
```

Space toggles, enter ships. Only Convex starts checked — shipping an app is
opt-in, so a stray Enter can't kick off an App Store / Play upload. "Bump
version" tracks iOS/macOS/Android live: it only does anything once an app is
shipping, so it checks itself the moment the first of those three is checked
(matching `--skip-version-bump`'s own default — bump unless told not to) and
unchecks itself again the moment none of them are, rather than sitting checked
for a Convex- or Site-only run where it would be a no-op. Toggle it by hand at
any point to override for that run (e.g. re-ship the same version). Tab on the
iOS/macOS/Android/Web row opens a one-off sub-menu to scope that platform to a
single stage (see [Per-platform stages](#per-platform-stages) below) instead of
its full pipeline — picking one also checks that row; Esc cancels back to the
checklist with no change. `f` walks through the same kind of sub-menu to
force-update channels, except its first step is a checklist of its own: space
ticks a channel, `a` ticks all of them (and unticks them again once they all
are), and everything ticked gets the same treatment in one pass. Then "require
whatever's already live" is one keystroke — no version to type unless you want
a different one — and with several channels ticked each keeps its *own* latest
version rather than being flattened onto one number. A ticked channel that has
never been published to is dropped with a warning instead of failing the batch.
Esc at any step backs out to the checklist too, same as Tab. Android means one
thing now: an AAB to the Play internal testing track. The self-hosted APK is
retired — see [Retired: the APK](#retired-the-apk).

## Moving traffic between the two backends

`./switchServer.sh` decides which of the two deployments every client talks to:
the Oracle VPS (`termio-api.walhallaa.com`) or the home server
(`monkeyhub-homeserver-api.walhallaa.com`). They hold replicated data, so a move
is a reconnect — nobody is signed out and nothing is lost.

```
./switchServer.sh              pick interactively
./switchServer.sh homeserver   move traffic to the home server (asks why — shown in the app)
./switchServer.sh primary      bring everyone back to the VPS
./switchServer.sh status       show where both stand, change nothing
```

It writes the directive row on **both** deployments, home server first. That
order is not cosmetic: the VPS row is what clients read, so writing it last
means the destination already agrees by the moment anyone is sent there.

Clients apply it live — they subscribe to `serverDirectory:current` over the
socket they already have, so a flip moves them within a second, with a toast.
Ones already on the home server take up to ~30s, because a Convex subscription
rides the socket and theirs is connected to the home server; they re-ask the
VPS on a timer instead. See `backend/convex/serverDirectory.ts` and
`lib/backend/server_directory.dart`.

Credentials: the VPS comes from `backend/.env.local` like everything else. The
home server's admin key is minted over SSH per run and never stored — there is
no source checkout on that box, and there does not need to be.

Both boxes are reached over Tailscale (`muratcankoc@100.104.73.75`), not the
`192.168.68.107` LAN address this used to carry. That address only resolves
from inside the house, so `switchServer.sh` failed with "No route to host"
from anywhere else — which is precisely where you are standing when you need
to move traffic off a failing box.

**A deploy goes to BOTH deployments.** `./deploy.sh` pushes the VPS first and
the home server second — standby before primary, the same order `switchServer.sh`
writes its directive row in, so whichever way you flip later, the destination
already has the newer code. A standby running last fortnight's functions is not
a standby; it is an outage with a DNS record. `--no-homeserver` pushes to the
VPS alone when the home server is down and you accept the drift.

**A restore brings back data, not functions.** That warning is about *logical*
snapshots (`npx convex export`). After restoring one, deploy explicitly or the
box answers `Could not find public function` for anything added since. The
manual form, still the escape hatch when deploy.sh is not what you want:

```
key=$(ssh muratcankoc@100.104.73.75 'docker exec termio-clone-backend ./generate_admin_key.sh | tail -1')
(cd backend && CONVEX_SELF_HOSTED_URL=https://monkeyhub-homeserver-api.walhallaa.com \
   CONVEX_SELF_HOSTED_ADMIN_KEY="$key" npx convex deploy)
```

A *file-level* copy of `/convex/data` is the other case, and it behaves the
opposite way: the data directory holds the pushed modules as well as the rows,
so functions travel with it. That is what `hosting/migrate-to-homeserver.sh`
does — see [Migrating between the two boxes](#migrating-between-the-two-boxes).

`SERVE_FROM` / `PRIMARY_URL` / `HOMESERVER_URL` / `SERVE_NOTE` env vars are a
legacy fallback, read only when the row is absent. Prefer the row: env vars are
a fine way to configure a backend and a hopeless way to notify one, because a
Convex query invalidates on the database reads it made and a query over
`process.env` recomputes for nobody. A leftover `SERVE_FROM=homeserver` also
sits dormant and silently reactivates if the row is ever lost.

## Migrating between the two boxes

`hosting/migrate-to-homeserver.sh` moves the whole deployment — rows, files and
functions — from the Oracle VM to the home server. Run 2026-08-28.

```
./hosting/migrate-to-homeserver.sh            status: the gap, in facts. Changes nothing.
./hosting/migrate-to-homeserver.sh prepare    compose + matching image + empty volume
./hosting/migrate-to-homeserver.sh copy       bulk data copy while the VPS keeps serving
./hosting/migrate-to-homeserver.sh cutover    THE WINDOW — stop, final delta, start, verify
./hosting/migrate-to-homeserver.sh rollback   put the home server back on the old volume
```

It copies `/convex/data` at the file level rather than taking a logical
snapshot, which is what makes it one operation instead of two: a Convex data
directory holds the pushed modules as well as the rows, so the functions travel
with the data and there is no "restore, then remember to deploy" step. It also
cannot fail schema validation, because the bytes being copied are the ones the
source is already validating against. And it is far gentler on a box at 30%
memory pressure than walking every table through the UDF machinery.

**`copy` before `cutover` is what makes the window short.** Both passes are
rsync, so the second one only sends what changed: the 2026-08-28 run moved
782 MB in the warm-up and then **14 MB of the 495 MB database** in the window —
a 54× speedup, and the reason the whole outage was **163 seconds**. `copy` is
safe to run as often as you like beforehand.

**The image digests must match, and this is the one that bites.** The home
server sat on the March build (`a08c5b76…`) while the VPS had been upgraded to
August (`1f2044e3…`), and an older Convex backend cannot read what a newer one
wrote: it boots, prints `backend listening on 0.0.0.0:3210`, and then fails
every request with ``missing field `state```. `prepare` pins the matching digest
and `cutover` greps the log for that exact string before declaring success.
Going forward on the home server is safe in the way it was not on the VPS — the
warning in `tune-termio-vm.sh` is about 956 MB of RAM, not about the build.

**The rollback is a volume, not a backup.** The old standby's data stays in
`termio-clone-data`, unreferenced and untouched; the migration fills a new
named volume, `termio-prod-data`. Nothing in the new compose can reach the old
one — but `docker volume prune` can, so prune that box with care.

### What the move bought

Measured on each box immediately after, with the idle-gap probe from
`tune-termio-vm.sh` (`serverDirectory:current`, which needs no admin key):

| | Oracle VM | home server |
|---|---|---|
| RAM | 956 MB, ~190 MB available | 7.3 GB, ~5.0 GB available |
| memory pressure `some avg300` | 20-30% | negligible |
| bootstrap after a recreate | ~6 min | **10 s** |
| query after 30 s idle | 420-800 ms | **1.2 ms** |
| disk | 45 G | 456 G |

The 30-second-idle number is the one that matters: on the VM it was the working
set being reclaimed between calls, which is what "the clock icon takes forever
to become a tick" actually was. The home server's curve is flat.

### What did not move

`etcd`. The VM's compose runs a `termio-etcd` container that the backend has
never spoken to — `docker logs termio-backend | grep -ic etcd` is `0` — costing
20-28 MB and bursty CPU on a box with under 200 MB free. It came from an
upstream compose template for a clustered mode this deployment does not use.
The home server has always run without it, which is the proof it is not needed;
`hosting/homeserver-docker-compose.yml` simply omits it.

## GIFs and stickers — per-backend setup

Two things live on each backend rather than in the code, and a backend without
them simply shows no GIF tab / no sticker packs (nothing breaks). Do both on
**both** boxes — the home server over the tailnet, as everywhere else here:

```sh
cd backend
# KLIPY (GIF + sticker search). Not a secret: KLIPY designs for it to ship in
# clients, and `expressions:config` hands it to them.
npx convex env set KLIPY_API_KEY <key>
CONVEX_SELF_HOSTED_URL=http://100.104.73.75:3210 npx convex env set KLIPY_API_KEY <key>

# Ads in the KLIPY grid: "0" = off, unset = on. OFF as of 2026-09-30 — the
# privacy policy promises "no advertising", Play's "Contains ads" is No, and
# MonkeyHub's audience includes children (Play Families policy allows only
# certified ad SDKs). Flip it only after all three say otherwise.
npx convex env set KLIPY_ADS 0

# The official sticker packs (Noto Animated Emoji, CC BY 4.0). Idempotent —
# re-running finishes a half-done seed and skips what is there.
npx convex run expressions:seedOfficialPacks '{}'

# The packs built on a Mac and uploaded: MonkeyHub Crew (the brand's own
# monkeys, cut out of branding/ — first in the strip and on by default) and
# three Fluent 3D packs (Microsoft, MIT). Build once, then upload to each box
# — also idempotent. The crew needs the Fluent build for its props.
python3 -m venv .venv && .venv/bin/pip install pillow skia-python numpy
.venv/bin/python ../tool/stickers/fluent_packs.py build/stickers/fluent   # needs gh
.venv/bin/python ../tool/stickers/crew_pack.py build/stickers/crew build/stickers/fluent
for m in build/stickers/crew build/stickers/fluent; do
  node scripts/seed-sticker-packs.mjs $m/manifest.json
  node scripts/seed-sticker-packs.mjs $m/manifest.json http://100.104.73.75:3210
done
# The first cartoon monkeys (monkeyhub-monkeys) were retired on 2026-09-30
# with expressions:retireOfficialStickers; do not reseed them.
npx convex run expressions:seedStatus '{}'     # 19 packs, 522 stickers
```

KLIPY's terms shape the client, not this list: API calls and media loads come
from the device (never proxied through our servers), media URLs are used
verbatim, and results are shown in KLIPY's order. Content filtering is set in
the KLIPY Partner Panel, not in code — child accounts additionally send
`content_filter=high` and never request ads.

## One host, three paths

```
monkeyhub.walhallaa.com/            landing page      /srv/monkeyhub/site
monkeyhub.walhallaa.com/downloads/  get-the-app page  /srv/monkeyhub/downloads
monkeyhub.walhallaa.com/web/        Flutter web app   /srv/monkeyhub/web
monkeyhub.walhallaa.com/download    301 → /downloads/
```

`/download` (singular) keeps answering forever. It was the link shared publicly,
and it is stored server-side as the `android-apk` channel's `updateUrl`, so
already-installed APKs ask for it until they next check in. Retiring the APK
made that redirect **more** important, not less: it is the entire route by which
a sideloaded copy reaches the page explaining how to move to Play.

### Why /web/ and not web.monkeyhub.walhallaa.com

Because the subdomain cannot get a certificate on this plan. Cloudflare's free
Universal SSL covers exactly two names on this zone:

```
subject=CN=walhallaa.com
X509v3 Subject Alternative Name: DNS:*.walhallaa.com, DNS:walhallaa.com
```

`*.walhallaa.com` is one level only, so `web.monkeyhub.walhallaa.com` fails the
handshake outright (`tls alert handshake failure`, alert 40). Covering it needs
Advanced Certificate Manager (~$10/mo). A one-level name like
`monkeyhub-web.walhallaa.com` *would* be covered — but a separate origin drops
every web user's Convex session (localStorage is per-origin), forces a fresh
notification-permission prompt, and invalidates every Web Push subscription
(they are bound to the origin). Staying on one origin costs one `--base-href`
flag and nothing else.

## Flags (non-interactive / CI)

| Flag | Effect |
|---|---|
| `--ios` | iOS → App Store Connect |
| `--macos` | macOS → App Store Connect. **Not** included in `--all` yet — run it explicitly until the App Store Connect side is proven out (see [macOS](#macos) below) |
| `--android` | AAB → Google Play internal track (`--android=play` still works; `--android=apk` now errors out) |
| `--web` | Flutter web build → https://monkeyhub.walhallaa.com/web/ |
| `--site` | Landing + downloads pages only. No build, no Convex — seconds |
| `--all` | Convex + iOS + Android + web + site |
| `--convex-only` | Backend only (no builds, no version bump) |
| `--no-convex` / `--no-upload` / `--no-git` / `--skip-version-bump` / `--dry` | Same as before |

### Per-platform stages

Each app platform's pipeline is independent stages, runnable on their own —
mainly to resume after a partial failure (iOS archives fine but the ASC upload
times out) without repeating the earlier, expensive stages:

| Platform | Stages |
|---|---|
| iOS | `--ios-archive` → `--ios-export` → `--ios-upload` |
| macOS | `--macos-archive` → `--macos-export` → `--macos-upload` |
| Android | `--android-build` → `--android-upload` |
| Web | `--web-build` → `--web-upload` |

Combine flags to run more than one stage (`--ios-export --ios-upload`); a bare
`--ios`/`--macos`/`--android`/`--web` still runs every stage. A stage-only run
that skips its platform's first stage also skips `flutter clean` and the
version bump — it's shipping whatever is already on disk, so the version has
to match what's actually built into it.

### Platform isolation

Platforms run independently: if one fails, the rest still run — iOS failing
doesn't stop Android/web/macOS, or the git commit for whatever *did* ship.
`deploy.sh` exits non-zero at the end if anything failed (so CI still sees
it), and prints a per-platform ✅/❌ summary with which `--<platform>-<stage>`
flag to retry.

Standalone actions — they run alone and exit:

| Flag | Effect |
|---|---|
| `--rollback-web` | Put the previous web build back. Swaps, so running it twice undoes it |
| `--infra` | Install `hosting/caddy-monkeyhub.conf` on the VM: validates the whole config first, reloads only if it passes |
| `--set-min-supported <channel> <version\|clear>` | Force-update a channel — see [Manual commands](#manual-commands). Also reachable from the interactive picker via `f` |
| `--sync-releases` | Copy every channel's release row from the VPS onto the home server. Prints what it finds and is a no-op when the two agree — the repair for rows written before deploy.sh announced to both |

Any deploy that publishes to the VM also refreshes the two pages, because both
print the current version in their footer. Left to a separate flag that footer
rots one deploy at a time, and nobody notices a stale version on a front page.
`--android` is no longer one of those deploys: it ships to Play and puts nothing
on the VM, so it has no page to refresh.

Versioning: patch-only bump (`1.3.21+1 → 1.3.22+1`), the `+1` never changes.
Android `versionCode` is derived in `android/app/build.gradle.kts`
(`1.3.22 → 10322`) so Play upgrades always increase.

## Update prompts (version check)

Every cold start, the app asks the backend "what's the newest build on *my*
channel?" and — if it's behind — offers LATER / UPDATE, where UPDATE opens the
right place for how that copy was actually installed. Client lives in
`lib/update/`, backend in `backend/convex/releases.ts` (`appReleases` table).

deploy.sh announces each channel automatically, but only **after that channel's
upload succeeds**, so a failed build never advertises a version nobody can get.

The announcement goes to **both deployments**, same as the function push. It did
not always: `npx convex run` inherits `backend/.env.local`, which addresses the
VPS, so for a while a release announced itself only on the standby. Since the
2026-08-28 migration that is the box no client talks to — 1.3.89 shipped to a
home server still answering "1.3.88 is the newest", and nothing looked wrong,
because the deploy asked the one box that agreed with it. `--sync-releases`
squares up rows written in that window; `--no-homeserver` deliberately
reintroduces the split for a run when the home server is unreachable.

| Channel | Who publishes it | How the app knows it's on that channel |
|---|---|---|
| `ios-testflight` | deploy.sh, after the ASC upload | its own receipt at runtime (`sandboxReceipt`) |
| `ios-appstore` | **manual** — an ASC upload isn't a release | its own receipt at runtime |
| `android-apk` | deploy.sh, after each **Play** upload — it is a migration notice now, not a release. See [Retired: the APK](#retired-the-apk) | `--dart-define` baked into the retired APKs |
| `android-play` | deploy.sh, after the fastlane upload | `--dart-define`, and Play-vs-sideload at runtime |
| `web` | deploy.sh, after the web rsync | `--dart-define` |
| `macos-testflight` | deploy.sh, after the ASC upload | `--dart-define` — see caveat below |
| `macos-appstore` | **manual** — an ASC upload isn't a release, same as `ios-appstore` | `--dart-define` only |
| `macos-dmg` | **manual** (no self-hosted DMG build in deploy.sh yet) | `--dart-define` only |
| `windows` / `linux` | **manual** (not built yet) | `--dart-define` only |

The iOS build deliberately carries **no** `MH_CHANNEL` define: one binary serves
both TestFlight and the App Store, so a stamped channel would be wrong for half
its users. iOS resolves its own channel from its receipt instead. Android and web
get the define because each artifact really does belong to one channel.

**macOS caveat:** macOS reports no installer info at all (`installerStore` is
always null), so DMG / TestFlight / Mac App Store can only be told apart by the
define — unlike iOS there's no receipt to probe at runtime. `./deploy.sh --macos`
always stamps `--dart-define=MH_CHANNEL=macos-testflight`, because an ASC upload
is a TestFlight build until someone submits it for review, same as
`ios-testflight`. `macos-appstore` is published by hand once a build is actually
approved for sale — see [Manual commands](#manual-commands). A future
self-hosted DMG build would stamp `macos-dmg` instead.

### Manual commands

> **Every `npx convex run` below reaches the VPS only.** It reads
> `backend/.env.local`, and that file addresses the standby — so a row published
> by hand lands where no client reads it, which is the exact failure
> `--sync-releases` exists to clean up. Either follow a manual publish with
> `./deploy.sh --sync-releases`, or run it a second time against the home
> server:
>
> ```sh
> cd backend
> CONVEX_SELF_HOSTED_URL=https://monkeyhub-homeserver-api.walhallaa.com \
> CONVEX_SELF_HOSTED_ADMIN_KEY="$(ssh muratcankoc@100.104.73.75 \
>   'docker exec termio-clone-backend ./generate_admin_key.sh | tail -1')" \
> npx convex run releases:publish '<the same payload>'
> ```

Publish a channel by hand (omitted fields keep their stored values, so this
won't clobber a `minSupported` or a store link):

```sh
cd backend
npx convex run releases:publish '{"channel":"ios-appstore","version":"1.3.30"}'
```

Point a channel at a store listing once it exists — this fixes **already
installed** builds, which is the whole reason the URL lives server-side:

```sh
npx convex run releases:publish '{"channel":"ios-appstore","version":"1.3.30",
  "updateUrl":"itms-apps://apps.apple.com/app/id<APPLE_ID>"}'
```

Make an update mandatory (LATER disappears, the sheet can't be dismissed). Use
only when old clients are genuinely broken — anyone below this is locked out of
the app until they update, so it is only safe when the route out actually works
for everyone it hits. `./deploy.sh --set-min-supported <channel> <version>` does
this without a new build — it reads the channel's current row via
`releases:latest` first so it republishes the same `version`, only moving
`minSupported`:

```sh
./deploy.sh --set-min-supported android-play 1.3.28
```

which is equivalent to:

```sh
npx convex run releases:publish '{"channel":"android-play","version":"1.3.30","minSupported":"1.3.28"}'
```

Clear it again with `clear` (sends `minSupported: null`):

```sh
./deploy.sh --set-min-supported android-play clear
# npx convex run releases:publish '{"channel":"android-play","version":"1.3.30","minSupported":null}'
```

The flag takes one channel. To do several at once, use the picker's `f` menu
instead — it applies the same choice ("require each channel's own latest", a
typed version, or clear) across everything you tick.

Not on `android-apk` while the Play track is invite-only — see
[Retired: the APK](#retired-the-apk).

Read back what a channel is currently serving:

```sh
npx convex run releases:latest '{"channel":"android-apk"}'
```

`publish` is an `internalMutation` on purpose — reachable from the CLI's admin
credentials, but with no public write surface, since a public version would let
anyone fake a mandatory-update prompt for every user.

## Android signing

- Upload keystore: `~/keystores/monkeyhub_upload.jks` (alias `monkeyhub`).
  **BACK THIS FILE UP** (plus `android/key.properties`, which holds its
  passwords) — it is the permanent Play upload key, and losing it means an
  identity-verification round-trip with Google to register a replacement.
- `android/key.properties` is gitignored; on a new machine, restore both files
  before deploying Android.
- Without `key.properties` the release build silently falls back to **debug**
  signing (so `flutter run --release` works anywhere) — deploy.sh detects this
  and refuses to ship.

## The pages (landing + downloads)

**Share link: https://monkeyhub.walhallaa.com/downloads/**

- Templates: `hosting/site.template.html` (landing) and
  `hosting/downloads.template.html`. Edit THESE, never the generated copies
  under `hosting/public/`. Each opens with an `MH:DOC` comment that is stripped
  at render time, so maintainer notes never reach a browser.
- `hosting/static/` is copied verbatim to the site root: `robots.txt` and the
  service-worker tombstone (below).
- `./deploy.sh --site` stamps both pages and pushes them. No build, no Convex.

The downloads page now has two jobs: it is the **migration notice** for the
retired APK (the app's own UPDATE button sends people here), and it is the
download page for platforms we self-host — which, since Android left, means the
desktop builds still to come.

### The downloads manifest

The downloads page is rendered from `/srv/monkeyhub/downloads/artifacts.json`
**on the VM**, not from this script's variables:

```json
{
  "macos-dmg": { "version": "1.4.0", "file": "monkeyhub-1.4.0.dmg",
                 "size": "120MB", "updatedAt": "Aug 01, 2026" }
}
```

Each deploy merges only its own key, so shipping one platform can never erase
another's row — which is exactly what a page stamped from one build's variables
would do. One card per entry, plus fixed cards for Android, iOS and the browser.
**The manifest is empty today**; the `MH:EMPTY` block stands in for the grid, and
the fixed cards carry the page.

Adding a platform is one `case` line in `platform_meta()` in deploy.sh (icon,
label, button text) and whatever builds the artifact. The template needs no edit.

- Upload order is **artifact first, manifest second**, so the page can never
  advertise a file still crossing the wire.
- **Retention is latest-only, per platform** — the manifest names the file the
  new release supersedes, so another platform's build sitting next to it is
  never touched.
- Download buttons point at `monkeyhub-<version>.<ext>`, never a stable
  `-latest` name: Cloudflare overrides the origin's `no-cache` on binaries with
  a 4 h browser TTL, so a fixed URL could hand out the previous build right
  after a release. A new version = a new URL.

### Retired: the APK

Android shipped as a self-hosted APK until 1.3.44. It now ships through Play
only. `--android=apk` errors out; `flutter build apk`, the VM rsync, the
versioned-hardlink retention and the `android-apk` manifest key are all gone.

What is deliberately **not** gone is the `android-apk` release channel, because
it is the only way to reach the people still running one of those APKs:

- Those builds were compiled with `--dart-define=MH_CHANNEL=android-apk`, and
  that define beats `installerStore` in `resolveChannel()`, so they ask about
  that channel for as long as they stay installed.
- **They cannot update in place.** Play App Signing re-signs the AAB with
  Google's key; their APK carries our upload key. Android refuses an install
  when the signature changes, so migrating means uninstall → install from Play.
  Chats live in Convex and survive; the Android encrypted store does not, so
  they sign in again and any child-device pairing has to be redone.
- So `deploy.sh` republishes `android-apk` after **every Play upload**, pointing
  `updateUrl` at the downloads page with `APK_MIGRATION_NOTE` as `notes`. It is
  re-announced each time rather than set once because `update_checker.dart`
  bails when the installed version is `>=` the published one — a frozen row goes
  quiet the moment someone's build catches up with it.
- It is deliberately **not** mandatory. Setting `minSupported` while the Play
  track is invite-only would lock people out of the app with no way back in.
  Once the listing is public, this makes the sheet blocking:

  ```sh
  cd backend
  npx convex run releases:publish '{"channel":"android-apk","version":"1.4.0","minSupported":"1.4.0"}'
  ```

The invite ask on the page is a `mailto:` to `info@walhallaa.com`, not a form:
the page is static HTML on Caddy with no backend, and the whole ask retires the
day the Play listing goes public.

### Where it runs

| Piece | Location |
|---|---|
| Files | `ubuntu@129.151.223.191:/srv/monkeyhub/{site,downloads,web}` |
| Web server | Caddy — the `:8081` block lives in this repo at `hosting/caddy-monkeyhub.conf`, installed to `/etc/caddy/monkeyhub.conf`, pulled in by `import monkeyhub.conf` |
| Tunnel | `monkeyhub-tunnel` (`96c30746-…`), `/etc/cloudflared/config-monkeyhub.yml`, unit `cloudflared-monkeyhub` |
| SSH key | `~/Documents/BelesMakinem/ssh-key-2024-12-04-2.key` |

Edit the Caddy config **in the repo** and run `./deploy.sh --infra`. An edit made
on the box is lost on the next install and exists in no history. `--infra`
validates the whole config before reloading, so a bad edit can't take the site
down. (`ubuntu` has passwordless sudo; the pre-`import` Caddyfile is backed up
at `/etc/caddy/Caddyfile.bak.premonkeyhubsplit`.)

Override `VM_HOST` / `VM_USER` / `VM_SSH_KEY` in `.env.local` if the box or key
moves. deploy.sh SSH-pings the VM during pre-flight, so an unreachable box fails
in seconds instead of after a 15-minute build.

Debugging: `sudo journalctl -u cloudflared-monkeyhub -n 50` and
`curl -sI http://127.0.0.1:8081/downloads/` on the box (bypasses Cloudflare).

## Web app

`./deploy.sh --web` builds Flutter web **with `--base-href /web/`** and publishes
it at **https://monkeyhub.walhallaa.com/web/**. The base href is baked in at
build time, so a build made without that flag 404s on every asset.

### Deploys are atomic, and reversible

The build is rsynced into `web.staging` (seeded from the live copy with `cp -al`,
so hardlinks make it free) and swapped in with a single rename. A visitor sees
the old build, then the new one — never a mix, and a failed sync leaves the live
site untouched. The build it replaced stays as `web.prev`:

```sh
./deploy.sh --rollback-web    # swaps web ↔ web.prev; run twice to undo
```

### Caching: why /web/ is no-store

Flutter reuses its output filenames across builds — `main.dart.js` keeps its name
and changes its bytes — so nothing under `/web/` is safely cacheable by URL.
`no-cache` is not enough: this zone has a 4 h Browser Cache TTL and Cloudflare
caches by extension, so a `no-cache` `.js` came back to the client rewritten as
`max-age=14400`. Four hours of a deploy being invisible — and worse, a window
where a fresh `index.html` pairs with a stale `main.dart.js`, which would make
the app's own update prompt lie. `no-store` is honoured end to end
(`cf-cache-status: BYPASS`).

There is no service-worker cache to soften it: `flutter build web` ships
Flutter's self-unregistering worker stub, so every visit is a real fetch.

**Measure the wire, not the disk.** `main.dart.js` is 6.4 MB in `ls`, but 1.8 MB
gzipped, and a whole cold load is **~1.9 MB**:

```sh
curl -s -H "Accept-Encoding: gzip, br" -o /dev/null -w "%{size_download}\n" \
  https://monkeyhub.walhallaa.com/web/main.dart.js
```

That is a small price for never serving a stale build. SDK fonts and the engine
(`assets/fonts/`, `assets/packages/*/assets/`, `canvaskit/`) are exempt at
`max-age=86400` — worth ~23 KB today, but it is the rule that stops `canvaskit/`
being re-fetched every visit if the renderer ever changes.

**Deliberately not done:** purging Cloudflare on deploy would allow a long
`max-age` instead — a zone-scoped API token (Zone → Cache Purge), a `curl`
against `/client/v4/zones/<zone>/purge_cache` after the swap in `upload_web()`,
and relaxing the `no-store`. It buys back under 2 MB per visit in exchange for a
credential to store and rotate. Not worth it at this audience size; revisit if
the app ever faces a lot of people on mobile data.

### Service workers

- `/web/mh-push-sw.js` handles Web Push. It ships with the Flutter build and
  registers itself at scope `/web/push/` — narrower than its own directory on
  purpose, so it can never collide with whatever worker `flutter build web`
  decides to install at `/web/`. Push delivery does not care that no page lives
  at that path.
  (Nothing is served at the origin root any more. The old push SDK needed that
  because it hardcoded the worker's path; the Caddy rule for it is gone.)
- `/flutter_service_worker.js` at the root is a **tombstone**
  (`hosting/static/`) that unregisters itself and clears caches, in case anyone
  still has a genuinely-caching worker from when the app was served at `/`.

One standing limitation, not a maturity caveat: `flutter_callkit_incoming` is
mobile-only, so a browser gets no CallKit / ConnectionService ringing.

Note a web deploy reaches every user on their next page load, with no store
review and nothing to install — so `--all` lands web well before the iOS build
finishes review.

## Google Play

The publishing pipeline is wired end to end: `fastlane` is installed, the
service account `play-publisher@monkeyhub-2b2c6.iam.gserviceaccount.com` exists
with **Release to testing tracks** scoped to this app, its key is at
`~/keystores/monkeyhub-play-key.json`, `.env.local` points
`PLAY_SERVICE_ACCOUNT_JSON` at it, and the Play Developer API is enabled on
`monkeyhub-2b2c6` (project number `691782206017`). The package
`com.walhallaa.chattest20241220` was fixed by the first upload and can never
change; it must keep matching `ANDROID_PACKAGE` in `deploy.sh`.

`./deploy.sh --android` builds the AAB and pushes it to the internal track by
itself. Sanity-check the service-account link with:

```sh
fastlane run validate_play_store_json_key json_key:$HOME/keystores/monkeyhub-play-key.json
```

### Track progression

Internal → closed → production. This matters beyond Play Console, because it is
what the downloads page can honestly promise:

| Track | Who can install | What the page says |
|---|---|---|
| **Internal** (today) | emails on the tester list, added by hand | "invite only", `mailto:` request button |
| **Closed** | testers who opt in via a shared link | swap the `mailto:` for the opt-in URL |
| **Production** | anyone | drop the invite card; `market://details?id=…` resolves for everyone, which `update_destination.dart` already falls back to |

The `android-apk` migration notice stays non-mandatory until production — see
[Retired: the APK](#retired-the-apk) for why, and for the one-liner that makes
it blocking afterwards.

## iOS

Unchanged: ASC API key in `~/.appstoreconnect/private_keys/`, IDs in
`.env.local` (`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`).
Optional extension setup: see `NOTIFICATION_SETUP.md`.

**The build now ships a second binary.** `ShareExtension.appex` is the app's
entry in the system share sheet; it has its own bundle id
(`com.walhallaa.chatTest-20241220.ShareExtension`), which needs its own App ID
in the developer portal with **App Groups** enabled — on the app's App ID too.
Neither is optional and only one of them fails loudly. Do both before the first
upload; the checklist and the failure modes are in `SHARE_SHEET.md`.

The extension target is generated by `tool/setup_ios_share_extension.rb`, which
`pod install` runs. If a `flutter clean` or a project regeneration ever loses
it, that script puts it back — running it by hand is safe and idempotent.

## macOS

`./deploy.sh --macos` builds, archives, and uploads to App Store Connect —
same shape as iOS, same ASC API key, no separate setup on the `.env.local`
side. `DEVELOPMENT_TEAM` is now set on the macOS Runner target (it was blank
before this shipped; same team as iOS, `37TC2VKVJ6`, since it's one Apple
Developer account).

**No new app record needed** — macOS's bundle ID
(`com.walhallaa.chatTest-20241220`, set in `macos/Runner/Configs/AppInfo.xcconfig`)
is identical to iOS's, so a macOS build lands on the *same* App Store Connect
app that already has iOS TestFlight testers on it, not a separate one.

The one thing only Apple's side can confirm before the first run: that app's
page in App Store Connect has to have **macOS added as a platform** on it
(an iOS-only app doesn't have macOS "on" by default — it's a per-app platform
list, not a per-bundle-ID one). Apple sometimes auto-adds it on the first
build for a new platform, sometimes it wants a manual add first via the app's
page. If it's missing, the archive/export steps still succeed — it's the
`xcrun altool --upload-app` step that will reject it, and the fix is that ASC
click, not a new app. Not part of `--all` yet; ship it with an explicit
`--macos` until that first upload is confirmed working end to end.

## The backend's memory on the VM

The Oracle box has 956 MB and the Convex backend's default caches are sized for
a fleet (~1.5 GB between them), so left alone it swaps most of itself out to
the boot volume and every query pages itself back in before it can run. The
symptoms are one-row mutations blowing the 1 s user-time limit, `Restarting
Isolate user_timeout` bursts in `docker logs termio-backend`, and journald's
"Under memory pressure, flushing caches". Chat feels slow for everyone at once.

`hosting/termio-docker-compose.yaml` is the compose file that runs the backend,
with the caps that fit it in RAM and the dashboard made opt-in; it is installed
by `./hosting/tune-termio-vm.sh apply`, which also enables zram (compressed
swap in RAM, ahead of the swapfile) and recreates the backend container. That
recreate is **about six minutes of outage** on this disk — the backend re-reads
the whole database while bootstrapping before it listens — so pick a quiet
stretch, and expect the first `npx convex deploy` afterwards to need one retry
(the cold bundle analysis trips a 4 s limit). `./hosting/tune-termio-vm.sh`
with no argument reports where the box stands and changes nothing. Read it
right: the backend's `VmSwap` stays around 1 GB even when healthy — that is a
cold heap left over from bootstrap, never touched again — so the numbers that
mean something are its `VmRSS`, the memory-pressure line, and whether
`docker logs termio-backend` has stopped saying `Restarting Isolate
user_timeout`. One more thing status shows: zram's real fill. If `swapon`
says zram0 is full while `zramctl` says it holds a few MB, a thrash has
clogged its slot table and swap is silently going to disk again —
`./hosting/tune-termio-vm.sh reset-zram` fixes that in seconds. Edit the
compose file in the repo, not on the box — same rule as the Caddy config.

The dashboard is no longer always on. For a session of it, on the box, from
`~/convex-instances/termio-backend/self-hosted/docker`:

```
docker compose --profile dashboard up -d dashboard
docker compose stop dashboard          # when done
```
