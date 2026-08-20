# Deep links

Everything that has to agree for a tapped invite to open the app instead of a
browser, and how to find out which piece is wrong when it doesn't.

There is exactly one deep link in this app today: the room invite. Everything
below is about that URL.

```
https://monkeyhub.walhallaa.com/j/MUZU4KUP7V
                                └┬┘ └───┬──┘
                                 │      └── the invite code, `roomInvites.ts`
                                 └───────── the only path the app claims
```

**The shape lives in `lib/invites/invite_link.dart`.** Four things parse it and
all four must agree; changing the path there is a change to all of them:

| Where | What it does | File |
|---|---|---|
| The app | Parses inbound URLs, builds outbound ones | `lib/invites/invite_link.dart` |
| iOS / macOS | Decides the tap opens the app | `hosting/static/.well-known/apple-app-site-association` |
| Android | Same, per install | `hosting/static/.well-known/assetlinks.json` |
| The web | What people **without** the app land on | `hosting/invite.template.html` |

`test/invite_link_test.dart` pins the Dart half, including everything the parser
must *refuse* — the landing page, `/downloads/`, `/web/`. That narrowness is
deliberate: an app that claimed `/` would swallow its own download page.

> ### Example codes must contain a `U`
>
> Every code written down here or shown in the UI comes from
> `kExampleInviteCode` in `lib/invites/invite_link.dart`, and it contains a `U`
> on purpose. The server mints from Crockford base32 — no I, L, O or U — and
> `normalizeCode` folds I/L to `1` and O to `0` so a typo still resolves. **U is
> the one excluded letter that is neither minted nor produced by folding**, so a
> string containing one can never match a live invite.
>
> A placeholder that merely *looks* like a code eventually **is** somebody's
> code, and every screenshot of it becomes a working key to a private room. 50
> bits makes that unlikely, not impossible — the wrong standard for a string we
> choose ourselves and print forever. A test enforces it.

---

## The pieces

### 1. The app

`app_links` (pubspec) delivers URLs; `lib/invites/deep_link_service.dart` reads
both arrival paths — the cold-start `getInitialLink()` and the warm stream — and
hands invites to `_openInvite` in `lib/app.dart`, which stashes and replays if
the app isn't ready. A link tapped on a fresh install survives the whole
sign-up detour; that is the case worth caring about.

Nothing joins automatically. A link opens `JoinByInviteScreen` and asks. A URL
that changed your account state on tap is what every phishing link wants.

### 2. iOS and macOS — universal links

Three things, and **only the first fails loudly**:

1. `com.apple.developer.associated-domains` = `applinks:monkeyhub.walhallaa.com`
   in all four entitlements files (`ios/Runner/Runner.entitlements`,
   `ios/Runner/RunnerRelease.entitlements`, `macos/Runner/DebugProfile.entitlements`,
   `macos/Runner/Release.entitlements`). Already committed.
2. **Associated Domains enabled on the App ID** in the Apple Developer portal.
   Signing does *not* fail without it — the capability is simply absent from the
   profile and every link opens Safari.
3. The AASA served at `https://monkeyhub.walhallaa.com/.well-known/apple-app-site-association`
   as `application/json`, no redirect, no file extension. The Caddy
   `handle /.well-known/*` block sets the Content-Type explicitly, because the
   file has no extension and Caddy would otherwise serve `application/octet-stream`
   — which iOS rejects silently.

App ID: `37TC2VKVJ6.com.walhallaa.chatTest-20241220` (same bundle id on both
platforms, so one entry covers iOS and macOS).

**Apple's CDN caches the AASA for up to 24h.** A device that already fetched a
bad copy keeps using it until the app is reinstalled. Test on a device that has
never had the broken version, or reinstall.

### 3. Android — App Links

`android/app/src/main/AndroidManifest.xml` carries an `autoVerify="true"`
intent-filter for `https://monkeyhub.walhallaa.com/j/*`. At install time Android
fetches `assetlinks.json` and, if the package and the signing certificate's
SHA-256 fingerprint are listed, opens the URL with no chooser dialog.

Verification is **per-install, needs the network, and fails silently.** The only
way to see the state:

```sh
adb shell pm get-app-links com.walhallaa.chattest20241220
```

Look for `monkeyhub.walhallaa.com: verified`. `legacy_failure` or `1024` means
the fetch failed or the fingerprint didn't match.

> ### ⚠️ Play App Signing — one fingerprint is still missing
>
> `hosting/static/.well-known/assetlinks.json` currently lists **only the upload
> key**:
>
> ```
> 90:3E:C6:73:4B:30:3E:F6:DD:3B:D7:FC:21:E9:02:ED:EC:07:9A:E4:59:39:F3:39:50:35:E4:09:2E:C8:37:3F
> ```
>
> Play re-signs the app with a **different** certificate, so **installs from Play
> will not verify** until that fingerprint is added too. Get it from
> **Play Console → your app → Setup → App integrity → App signing key
> certificate → SHA-256**, and add it as a second string in the
> `sha256_cert_fingerprints` array. Both belong there: the upload key covers
> local `flutter build apk --release` installs, the app-signing key covers
> everyone else.
>
> Until then, App Links work on locally-signed builds and degrade to
> "opens in the browser" on Play installs — where the landing page and its
> `monkeyhub://` button still get the user in.

### 4. The web page

`hosting/invite.template.html` → rendered by `deploy.sh` to
`hosting/public/site/j.html` → served by Caddy for every `/j/*` path.

Almost nobody with the app sees it: the OS intercepts the tap first. It exists
for people **without** the app, and for the link unfurlers in other messengers.

**It deliberately does not name the room.** An invite URL gets pasted into other
chats, and every one of those fetches the page from a datacentre to build a
preview card. If the page resolved the code server-side, a private group's name
would appear to everyone in an unrelated conversation the moment somebody pasted
the link — no tap required. Only the app resolves a code, over the
authenticated connection. The page shows the code, an "Open in MonkeyHub"
button on the `monkeyhub://` fallback scheme, and a link to the downloads page.

### 5. The fallback scheme

`monkeyhub://join/<code>` is registered on iOS (`CFBundleURLTypes` in
`ios/Runner/Info.plist`) and Android (a second, non-autoVerify intent-filter).
**It is never what gets shared.** It exists for the device where App Link
verification failed, and for hand-testing.

---

## Testing

```sh
# iOS simulator — the shared form (works only if the AASA is live)
xcrun simctl openurl booted "https://monkeyhub.walhallaa.com/j/MUZU4KUP7V"
# …and the fallback, which needs no association at all
xcrun simctl openurl booted "monkeyhub://join/MUZU4KUP7V"

# Android
adb shell am start -a android.intent.action.VIEW \
  -d "https://monkeyhub.walhallaa.com/j/MUZU4KUP7V"
adb shell pm get-app-links com.walhallaa.chattest20241220

# The served files, after ./deploy.sh --site
curl -sI https://monkeyhub.walhallaa.com/.well-known/apple-app-site-association | grep -i content-type
curl -s  https://monkeyhub.walhallaa.com/.well-known/assetlinks.json | jq .
curl -s  https://monkeyhub.walhallaa.com/j/MUZU4KUP7V | head -20
```

`content-type: application/json` on the first one is the check that matters.

## Deploying

`./deploy.sh --site` renders and rsyncs the invite page and the two
`.well-known/` files along with the rest of the site — they live in
`hosting/static/`, which is copied wholesale.

`./deploy.sh --infra` installs `hosting/caddy-monkeyhub.conf`, which owns the
`/j/*` rewrite and the `.well-known` Content-Type. Without it `/j/<code>` 404s
with a zero-byte body — a blank white page — and the AASA is served with **no**
Content-Type at all, which iOS rejects silently so no link ever opens the app.
Both symptoms look like application bugs and are neither.

Already run once, on 2026-08-20. Run it again after any edit to that conf.

> `.well-known` is a dotfile directory. `deploy.sh` copies the static tree with
> `cp -R hosting/static/. …` — the trailing `/.` is what includes it. A `*`
> glob would skip it silently and break every universal link on the next deploy.

## When a link opens the browser instead

In order of how often it is the answer:

1. **Android, Play install** — the app-signing fingerprint isn't in
   `assetlinks.json`. See the warning above.
2. **iOS** — Associated Domains not enabled on the App ID, or a cached bad AASA.
   Reinstall to clear the cache.
3. **Either** — the URL isn't the exact `/j/<code>` shape. Two path segments, no
   more, no fewer.
4. **Either** — Caddy hasn't been reloaded with the new config; `curl` the
   `.well-known` URL and check the Content-Type.
5. **In-app browsers** (Instagram, some mail clients) never hand off to apps at
   all. The landing page's "Open in MonkeyHub" button is the way out.
