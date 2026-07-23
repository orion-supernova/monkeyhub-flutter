# Deploying MonkeyHub

`./deploy.sh` ships the Convex backend, iOS, and Android. Run it with no flags
in a terminal to get the interactive picker:

```
Select what to deploy  (↑/↓ move · space toggle · enter go)
  ❯ ◉ Convex backend
    ◉ iOS  → App Store Connect
    ◯ Android
```

Space toggles, enter ships. Selecting Android asks one more question: **APK**
(signed APK published to the download page at https://monkeyhub.walhallaa.com/download)
or **AAB** (Google Play, internal testing track).

## Flags (non-interactive / CI)

| Flag | Effect |
|---|---|
| `--ios` | iOS → App Store Connect |
| `--android[=apk\|play]` | Android; `apk` (default) = self-hosted download page, `play` = Play internal |
| `--web` | Flutter web build → https://monkeyhub.walhallaa.com (opt-in, experimental) |
| `--all` | Convex + iOS + Android(apk) — web is never included |
| `--convex-only` | Backend only (no builds, no version bump) |
| `--no-convex` / `--no-upload` / `--no-git` / `--skip-version-bump` / `--dry` | Same as before |

Versioning: patch-only bump (`1.3.21+1 → 1.3.22+1`), the `+1` never changes.
Android `versionCode` is derived in `android/app/build.gradle.kts`
(`1.3.22 → 10322`) so Play/side-load upgrades always increase.

## Android signing

- Upload keystore: `~/keystores/monkeyhub_upload.jks` (alias `monkeyhub`).
  **BACK THIS FILE UP** (plus `android/key.properties`, which holds its
  passwords) — losing it means losing the ability to update the app for
  side-load users, and it will be the permanent Play upload key.
- `android/key.properties` is gitignored; on a new machine, restore both files
  before deploying Android.
- Without `key.properties` the release build silently falls back to **debug**
  signing (so `flutter run --release` works anywhere) — deploy.sh detects this
  and refuses to ship.

## APK download page (self-hosted)

**Share link: https://monkeyhub.walhallaa.com/download**

This used to be Firebase Hosting. The Spark (free) plan refuses to serve APKs
(`Executable files are forbidden on the Spark billing plan`), so Android
distribution moved to the Oracle VM.

- Templates: `hosting/index.template.html` (download page) and
  `hosting/root.template.html` (placeholder at the site root). Edit THESE, not
  the generated copies.
- On every APK deploy the script rebuilds `hosting/public/` (gitignored):
  stamps version/size/date/filename, then rsyncs `index.html` +
  `monkeyhub-latest.apk` to the VM. The versioned name is created server-side
  as a hardlink, so the 163 MB only crosses the wire once (~1 min).
- **Retention is latest-only** — each deploy deletes the previous versioned APK.
- The page's download button points at `monkeyhub-<version>.apk`, not
  `monkeyhub-latest.apk`, on purpose: Cloudflare overrides the origin's
  `no-cache` on `.apk` with a 4 h browser TTL, so a stable URL could hand out
  the previous build right after a release. A new version = a new URL.
  `monkeyhub-latest.apk` still exists for casual sharing.

### Where it runs

| Piece | Location |
|---|---|
| Files | `ubuntu@79.76.54.204:/srv/monkeyhub/{download,web}` |
| Web server | Caddy, `:8081` block in `/etc/caddy/Caddyfile` |
| Tunnel | `monkeyhub-tunnel` (`96c30746-…`), `/etc/cloudflared/config-monkeyhub.yml`, unit `cloudflared-monkeyhub` |
| SSH key | `~/Documents/BelesMakinem/ssh-key-2024-12-04-2.key` |

Override `VM_HOST` / `VM_USER` / `VM_SSH_KEY` in `.env.local` if the box or key
moves. deploy.sh SSH-pings the VM during pre-flight, so an unreachable box fails
in seconds instead of after a 15-minute build.

Debugging: `sudo journalctl -u cloudflared-monkeyhub -n 50` and
`curl -sI http://127.0.0.1:8081/download/` on the box (bypasses Cloudflare).

## Web app

`./deploy.sh --web` builds Flutter web and rsyncs `build/web/` to
`/srv/monkeyhub/web/`, served at **https://monkeyhub.walhallaa.com/**. Until the
first run, that URL shows the `hosting/root.template.html` placeholder (the
script only uploads the placeholder when no `main.dart.js` is present, so it
never clobbers a real build).

Experimental: `convex_flutter` has a web implementation, but
`flutter_callkit_incoming` and the WebRTC/recording plugins are mobile-only —
chat may work in a browser, calling won't.

## Switching Android to Google Play (once the account is verified)

1. Play Console → Create app (`MonkeyHub`, package
   `com.walhallaa.chattest20241220`).
2. First AAB upload is manual: `./deploy.sh --android=play` builds it, then
   drag `build/app/outputs/bundle/release/app-release.aab` into
   Internal testing → Create release. Google enrolls the app in Play App
   Signing using our upload key automatically.
3. Automate future uploads: Play Console → API access → link a Google Cloud
   service account → download its JSON key → add to `.env.local`:
   `PLAY_SERVICE_ACCOUNT_JSON=/path/to/play-key.json` and `brew install fastlane`.
   From then on `--android=play` uploads to the internal track by itself.

## iOS

Unchanged: ASC API key in `~/.appstoreconnect/private_keys/`, IDs in
`.env.local` (`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`).
Optional extension setup: see `NOTIFICATION_SETUP.md`.
