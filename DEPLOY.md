# Deploying MonkeyHub

`./deploy.sh` ships the Convex backend, iOS, and Android. Run it with no flags
in a terminal to get the interactive picker:

```
Select what to deploy  (↑/↓ move · space toggle · enter go)
  ❯ ◉ Convex backend
    ◉ iOS  → App Store Connect
    ◯ Android → Google Play (internal track)
```

Space toggles, enter ships. Android means one thing now: an AAB to the Play
internal testing track. The self-hosted APK is retired — see
[Retired: the APK](#retired-the-apk).

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
| `--android` | AAB → Google Play internal track (`--android=play` still works; `--android=apk` now errors out) |
| `--web` | Flutter web build → https://monkeyhub.walhallaa.com/web/ |
| `--site` | Landing + downloads pages only. No build, no Convex — seconds |
| `--all` | Convex + iOS + Android + web + site |
| `--convex-only` | Backend only (no builds, no version bump) |
| `--no-convex` / `--no-upload` / `--no-git` / `--skip-version-bump` / `--dry` | Same as before |

Standalone actions — they run alone and exit:

| Flag | Effect |
|---|---|
| `--rollback-web` | Put the previous web build back. Swaps, so running it twice undoes it |
| `--infra` | Install `hosting/caddy-monkeyhub.conf` on the VM: validates the whole config first, reloads only if it passes |

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

| Channel | Who publishes it | How the app knows it's on that channel |
|---|---|---|
| `ios-testflight` | deploy.sh, after the ASC upload | its own receipt at runtime (`sandboxReceipt`) |
| `ios-appstore` | **manual** — an ASC upload isn't a release | its own receipt at runtime |
| `android-apk` | deploy.sh, after each **Play** upload — it is a migration notice now, not a release. See [Retired: the APK](#retired-the-apk) | `--dart-define` baked into the retired APKs |
| `android-play` | deploy.sh, after the fastlane upload | `--dart-define`, and Play-vs-sideload at runtime |
| `web` | deploy.sh, after the web rsync | `--dart-define` |
| `macos-dmg` / `macos-testflight` / `macos-appstore` | **manual** (no macOS build in deploy.sh yet) | `--dart-define` only — see caveat below |
| `windows` / `linux` | **manual** (not built yet) | `--dart-define` only |

The iOS build deliberately carries **no** `MH_CHANNEL` define: one binary serves
both TestFlight and the App Store, so a stamped channel would be wrong for half
its users. iOS resolves its own channel from its receipt instead. Android and web
get the define because each artifact really does belong to one channel.

**macOS caveat:** macOS reports no installer info at all, so DMG / TestFlight /
Mac App Store can only be told apart by the define — and as on iOS, one ASC
binary serves both TestFlight and the Mac App Store. When macOS ships, a DMG
build gets `--dart-define=MH_CHANNEL=macos-dmg`; an ASC build has to pick one of
the two ASC channels (or grow a receipt probe like iOS's).

### Manual commands

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
for everyone it hits:

```sh
npx convex run releases:publish '{"channel":"android-play","version":"1.3.30","minSupported":"1.3.28"}'
```

Clear it again by passing `null`:

```sh
npx convex run releases:publish '{"channel":"android-play","version":"1.3.30","minSupported":null}'
```

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
| Files | `ubuntu@79.76.54.204:/srv/monkeyhub/{site,downloads,web}` |
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
