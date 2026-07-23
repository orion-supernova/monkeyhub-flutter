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
(signed APK published to the download page at https://monkeyhub-2b2c6.web.app)
or **AAB** (Google Play, internal testing track).

## Flags (non-interactive / CI)

| Flag | Effect |
|---|---|
| `--ios` | iOS → App Store Connect |
| `--android[=apk\|play]` | Android; `apk` (default) = hosted download page, `play` = Play internal |
| `--all` | Convex + iOS + Android(apk) |
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

## APK download page

- Template: `hosting/index.template.html` (edit THIS, not the generated copy).
- On every APK deploy the script rebuilds `hosting/public/` (gitignored):
  stamps version/size/date, copies `monkeyhub-latest.apk` +
  `monkeyhub-<version>.apk`, deploys via `npx firebase-tools`.
- First-time on a machine: `npx firebase-tools login` (the script tells you
  when it's needed).
- Stable share link: **https://monkeyhub-2b2c6.web.app** (the
  `monkeyhub-latest.apk` URL never changes).

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
