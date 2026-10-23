#!/bin/bash
# MonkeyHub deploy script (Convex backend + iOS + Android).
#
# Interactive: run ./deploy.sh with no platform flags in a terminal and pick
# targets from a checkbox menu (↑/↓ move, space toggles, enter ships).
# Non-interactive: pass platform flags (see -h) — the menu is skipped.
#
# Pipelines:
#   Convex   → npx convex deploy (from backend/)
#   iOS      → flutter build ios → xcodebuild archive/export → App Store Connect
#   macOS    → --macos: flutter build macos → xcodebuild archive/export →
#                       App Store Connect. Same ASC API key as iOS.
#   Android  → flutter build appbundle → Google Play internal track
#              (needs a verified Play account; see DEPLOY.md)
#   Web      → --web: flutter build web → rsync to the Oracle VM, served by
#                     Caddy behind cloudflared
#                     (https://monkeyhub.walhallaa.com/web/)
#   Site     → --site: stamp the landing + downloads pages and push them. No
#                      build, so it takes seconds.
#   Windows  → --windows: built on GitHub Actions (.github/workflows/desktop.yml,
#                         Flutter can't cross-compile desktop) → MSIX downloaded
#                         here → Microsoft Store via the msstore CLI.
#   Linux    → --linux: built on GitHub Actions → tarball downloaded here →
#                       /downloads/ on the VM, then the AUR (monkeyhub-bin)
#                       when an AUR SSH key is set up. See DEPLOY.md.
#   Windows and Linux share ONE workflow run, started right after the version
#   bump so it builds while this Mac does iOS/Android, and collected when their
#   turn comes. Both are in --all.
#
# Order: Convex first, then the platforms in PLATFORM_ORDER (mobile first:
# iOS → Android → macOS → Windows → Linux → web, or the picker's tick order),
# then the site last.
#
# One host, three paths (see hosting/caddy-monkeyhub.conf):
#   /            landing page      /srv/monkeyhub/site
#   /downloads/  every platform    /srv/monkeyhub/downloads
#   /web/        Flutter web app   /srv/monkeyhub/web
#   /j/<code>    room invite       /srv/monkeyhub/site/j.html
#
# Android used to ship as a self-hosted APK from that /downloads/ page. It now
# ships through Play only, and the page is the migration notice instead — see
# "Release announcement" below for how the already-installed APKs are told.
# /downloads/ still renders artifacts.json, which is how a future macOS DMG or
# Windows build gets a card without touching this script's page code.
#
# IMPORTANT — two similarly-named files at project root:
#   env.local   (no dot)  → runtime app config (CONVEX_URL, VAPID_PUBLIC_KEY).
#                           Bundled into the app via pubspec assets — DO NOT put
#                           deploy secrets here.
#   .env.local  (with dot) → deploy-only secrets (App Store Connect API key,
#                           optional PLAY_SERVICE_ACCOUNT_JSON). NOT bundled.

set -uo pipefail

SCRIPT_START_TIME=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ANDROID_PACKAGE="com.walhallaa.chattest20241220"
# Partner Center → MonkeyHub: Your Inner Circle. Also the public Store URL.
MS_STORE_PRODUCT_ID="9PLTX7L6B52S"
MS_STORE_URL="https://apps.microsoft.com/detail/$MS_STORE_PRODUCT_ID"
DESKTOP_WORKFLOW="desktop.yml"
AUR_PACKAGE="monkeyhub-bin"

# ----- self-hosted site (Oracle Ampere + Caddy + cloudflared) -----
# Override any of these from .env.local if the box or key ever moves.
#
# This is the Ampere box (belesampere), which took over from the 956 MB Oracle
# VM at 79.76.54.204 on 2026-09-09 — see hosting/ampere/README.md and
# hosting/migrate-to-ampere.sh. The site tree, the Caddy contract
# (/etc/caddy/Caddyfile importing monkeyhub.conf) and the two Cloudflare
# tunnels all moved with it, so --site, --web and --infra work here unchanged.
#
# The default is edited here rather than left to .env.local ON PURPOSE:
# .env.local is gitignored, so a fresh checkout would otherwise deploy the site
# to a machine that no longer serves it.
VM_HOST="${VM_HOST:-129.151.223.191}"
VM_USER="${VM_USER:-ubuntu}"
VM_SSH_KEY="${VM_SSH_KEY:-$HOME/Documents/BelesMakinem/BelesAmpere.key}"

# ----- the home server -----
# The second Convex deployment: the warm STANDBY. The VPS is primary (it was
# the other way round for a while after the 2026-08-28 migration). Reached
# over Tailscale rather than the 192.168.68.107 LAN address, so a deploy works
# from anywhere and not only from inside the house. It needs no SSH key here —
# it goes through the agent — and no admin key on disk: the key is minted
# inside the container per run. See hosting/migrate-to-homeserver.sh.
HOMESERVER_URL="${HOMESERVER_URL:-https://monkeyhub-homeserver-api.walhallaa.com}"
HOMESERVER_SSH="${HOMESERVER_SSH:-muratcankoc@100.104.73.75}"
HOMESERVER_CONTAINER="${HOMESERVER_CONTAINER:-termio-clone-backend}"
VM_SITE_DIR="/srv/monkeyhub/site"
VM_DL_DIR="/srv/monkeyhub/downloads"
VM_WEB_DIR="/srv/monkeyhub/web"
SITE_URL="https://monkeyhub.walhallaa.com"
HOSTING_URL="https://monkeyhub.walhallaa.com/downloads"
# Trailing slash matters: /web without it costs every visitor a redirect.
WEB_URL="https://monkeyhub.walhallaa.com/web/"

# Shown in the update sheet on already-installed APKs, which resolve the
# android-apk channel forever (the MH_CHANNEL define beats installerStore — see
# lib/update/release_channel.dart). They cannot update in place: Play App
# Signing re-signs the AAB with Google's key, so the signature no longer matches
# the upload key their APK carries and Android refuses the install. Hence
# "remove it first" rather than "tap update".
APK_MIGRATION_NOTE="Android now ships through Google Play. This sideloaded copy can't update itself — the download page has the two steps to move over. Your chats stay safe; you'll just sign in again."

# What has actually shipped, per platform. Lives on the VM because it outlives
# any one deploy — shipping Android must not erase the macOS row.
DL_MANIFEST="$VM_DL_DIR/artifacts.json"

# ----- flags -----
SKIP_VERSION_BUMP=false
RUN_CONVEX=""      # ""=undecided (menu/default), true/false once resolved
# A Convex deploy lands on BOTH deployments, not just the one serving traffic.
# The VPS is primary and the home server is a warm standby switchServer.sh can
# flip to, and a standby running last fortnight's functions is not a standby —
# it is an outage with a DNS record. Set false
# (or --no-homeserver) when the home server is unreachable and you accept the
# drift; deploy.sh says so loudly in the summary either way.
#
# This governs the release ROWS too (publish_release, set_min_supported), not
# just the function push. They were split for a while, and the split is what
# made 1.3.89 ship to a home server (primary back then) still telling every
# client 1.3.88 was the newest build — the deploy said success, because the box
# it wrote to agreed.
RUN_HOMESERVER=true
DEPLOY_IOS=""
DEPLOY_MACOS=false # --macos: App Store Connect. Also included by --all.
DEPLOY_ANDROID=""
DEPLOY_WEB=false   # --web: flutter build web → VM. Also included by --all.
DEPLOY_SITE=false  # --site: landing + downloads pages. No build. Also by --all.
DEPLOY_WINDOWS=false # --windows: CI build → Microsoft Store. Also by --all.
DEPLOY_LINUX=false   # --linux: CI build → /downloads/ + AUR. Also by --all.
# The order the platforms ship in. Mobile first: those are what testers are
# waiting on. The interactive picker replaces it with the order its rows were
# ticked in. Convex always runs before all of these and Site after them.
PLATFORM_ORDER="ios android macos windows linux web"
RUN_UPLOAD=true    # iOS: upload IPA to ASC. Android: AAB to Play. Web: to the VM.
# Delete a platform's build output (and its Xcode DerivedData) the moment its
# upload succeeds, so the next platform builds into the space it leaves. This
# Mac runs short of disk mid-deploy otherwise. Only after a real upload: a
# --no-upload run, a failed upload or a manual-upload AAB keeps everything.
# --keep-builds / the picker's last row turn it off.
FREE_SPACE=true
RUN_GIT=true
DRY_RUN=false
PLATFORM_ARGS=false
# Standalone actions: they do their one job and exit, never mixed with a build.
ACTION=""          # "" | infra | rollback-web | set-min-supported | sync-releases
SET_MIN_CHANNEL=""
SET_MIN_VERSION=""

# Per-platform stage sets, space-separated. Empty = "whatever --<platform> or the
# picker asked for", resolved to the full pipeline once DEPLOY_* is final (see
# "stage defaults" below). --<platform>-<stage> flags APPEND to these instead of
# replacing, so e.g. `--ios-export --ios-upload` composes into "export upload"
# and skips only the build+archive stage — this is how a failed-then-retried
# upload resumes without rebuilding. iOS/macOS: archive → export → upload.
# Android/web/Windows/Linux: build → upload. (Windows/Linux "build" is the CI
# run plus downloading its artifact into build/.)
IOS_STAGES=""
MACOS_STAGES=""
ANDROID_STAGES=""
WEB_STAGES=""
WINDOWS_STAGES=""
LINUX_STAGES=""
has_stage() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

print_help() {
    cat <<EOF
Usage: ./deploy.sh [flags]

No platform flags + a terminal → interactive picker (space toggles, enter go).
Platforms ship in the order you tick them; flags ship mobile first:
iOS → Android → macOS → Windows → Linux → web, then the site.
No platform flags + no TTY     → legacy default: Convex + iOS.

Platform flags (any of these skips the picker):
  --ios                 Ship iOS to App Store Connect.
  --macos               Ship macOS to App Store Connect.
  --android             Ship Android: AAB to the Google Play internal track.
  --web                 Build Flutter web and publish it at $WEB_URL.
  --site                Landing + downloads pages only. No build — seconds.
  --windows             Build on GitHub Actions, submit the MSIX to the
                        Microsoft Store.
  --linux               Build on GitHub Actions, publish the tarball on
                        /downloads/ and push the AUR package.
  --all                 Convex + iOS + Android + macOS + Windows + Linux +
                        web + site.
  --convex-only         Backend only — no builds, no version bump.
  --no-convex           Skip 'npx convex deploy'.
  --no-homeserver       Push Convex to the VPS only, not the home server —
                        functions AND the release rows a shipped build
                        announces. Leaves the two backends disagreeing about
                        both; --sync-releases fixes the second half.

Standalone actions (run alone and exit):
  --rollback-web        Put the previous web build back. Run it twice to undo.
  --infra               Install hosting/caddy-monkeyhub.conf on the VM. Validates
                        the whole config first and won't reload if it fails.
  --set-min-supported <channel> <version>
                        Force-update: clients on <channel> below <version> lose
                        the "Later" button on their update prompt. Leaves the
                        channel's published version untouched. <version> may
                        be "clear" to lift the requirement. Channels:
                        ios-testflight, macos-testflight, android-play,
                        android-apk, web, windows, linux. One channel per run; press 'f' in the
                        interactive picker to tick several at once.
  --sync-releases       Copy every channel's release row from the VPS onto the
                        home server. Repairs the drift left by deploys from
                        before this script announced to both — the home server
                        serves the clients, so a stale row there means a shipped
                        build nobody is told about. Prints what it finds; a
                        no-op when the two already agree.

Per-platform stages: each platform's pipeline is independent stages that can be
run on their own — most useful to resume after a partial failure (e.g. iOS
archived fine but the App Store Connect upload timed out) without redoing the
earlier, already-successful, expensive stages. Combine flags to run more than
one stage (e.g. --ios-export --ios-upload); a bare --ios/--macos/--android/--web/
--windows/--linux still runs every stage, same as always.
  iOS:      --ios-archive   --ios-export   --ios-upload
  macOS:    --macos-archive --macos-export --macos-upload
  Android:  --android-build --android-upload
  Web:      --web-build     --web-upload
  Windows:  --windows-build --windows-upload
  Linux:    --linux-build   --linux-upload
A stage-only run that skips its platform's first stage leaves the version bump
and 'flutter clean' out too — it's shipping whatever is already built, so the
version must match what's actually in that build.

Platforms are independent: if one fails, the rest still run (iOS failing
doesn't stop Android/web/macOS or the git commit for whatever did ship). The
script exits non-zero at the end if anything failed, so CI/scripts still see
it — check the per-platform summary at the end for what to retry.

Behavior flags:
  --skip-version-bump   Re-ship the same version.
  --no-upload           Build/export but skip ASC upload AND the VM upload.
  --no-git              Don't commit/push the version bump.
  --keep-builds         Keep each platform's build output after its upload.
                        By default it is deleted once the upload succeeds
                        (build/ folders plus that workspace's Xcode
                        DerivedData) so the next platform has room to build.
  --dry                 --no-convex --no-upload --no-git --skip-version-bump.
  -h, --help            Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-version-bump) SKIP_VERSION_BUMP=true ;;
        --no-convex)         RUN_CONVEX=false ;;
        --no-homeserver)     RUN_HOMESERVER=false ;;
        --no-upload)         RUN_UPLOAD=false ;;
        --no-git)            RUN_GIT=false ;;
        --keep-builds)       FREE_SPACE=false ;;
        --ios)               DEPLOY_IOS=true;  PLATFORM_ARGS=true ;;
        --ios-archive)        DEPLOY_IOS=true; PLATFORM_ARGS=true; IOS_STAGES="${IOS_STAGES:+$IOS_STAGES }archive" ;;
        --ios-export)         DEPLOY_IOS=true; PLATFORM_ARGS=true; IOS_STAGES="${IOS_STAGES:+$IOS_STAGES }export" ;;
        --ios-upload)         DEPLOY_IOS=true; PLATFORM_ARGS=true; IOS_STAGES="${IOS_STAGES:+$IOS_STAGES }upload" ;;
        --macos)             DEPLOY_MACOS=true; PLATFORM_ARGS=true ;;
        --macos-archive)      DEPLOY_MACOS=true; PLATFORM_ARGS=true; MACOS_STAGES="${MACOS_STAGES:+$MACOS_STAGES }archive" ;;
        --macos-export)       DEPLOY_MACOS=true; PLATFORM_ARGS=true; MACOS_STAGES="${MACOS_STAGES:+$MACOS_STAGES }export" ;;
        --macos-upload)       DEPLOY_MACOS=true; PLATFORM_ARGS=true; MACOS_STAGES="${MACOS_STAGES:+$MACOS_STAGES }upload" ;;
        --android)           DEPLOY_ANDROID=true; PLATFORM_ARGS=true ;;
        --android-build)      DEPLOY_ANDROID=true; PLATFORM_ARGS=true; ANDROID_STAGES="${ANDROID_STAGES:+$ANDROID_STAGES }build" ;;
        --android-upload)     DEPLOY_ANDROID=true; PLATFORM_ARGS=true; ANDROID_STAGES="${ANDROID_STAGES:+$ANDROID_STAGES }upload" ;;
        # Kept so the old muscle memory and any saved command still work —
        # Play is now the only Android target, so this says what it always did.
        --android=play)      DEPLOY_ANDROID=true; PLATFORM_ARGS=true ;;
        --android=apk)
            echo "❌ --android=apk is gone: Android ships through Google Play only."
            echo "   Use --android (AAB → Play internal track)."
            echo "   Already-installed APKs are told where to go by the"
            echo "   android-apk release row — see DEPLOY.md → 'Retired: the APK'."
            exit 1
            ;;
        --web)               DEPLOY_WEB=true; PLATFORM_ARGS=true ;;
        --web-build)          DEPLOY_WEB=true; PLATFORM_ARGS=true; WEB_STAGES="${WEB_STAGES:+$WEB_STAGES }build" ;;
        --web-upload)         DEPLOY_WEB=true; PLATFORM_ARGS=true; WEB_STAGES="${WEB_STAGES:+$WEB_STAGES }upload" ;;
        --site)              DEPLOY_SITE=true; PLATFORM_ARGS=true ;;
        --windows)           DEPLOY_WINDOWS=true; PLATFORM_ARGS=true ;;
        --windows-build)      DEPLOY_WINDOWS=true; PLATFORM_ARGS=true; WINDOWS_STAGES="${WINDOWS_STAGES:+$WINDOWS_STAGES }build" ;;
        --windows-upload)     DEPLOY_WINDOWS=true; PLATFORM_ARGS=true; WINDOWS_STAGES="${WINDOWS_STAGES:+$WINDOWS_STAGES }upload" ;;
        --linux)             DEPLOY_LINUX=true; PLATFORM_ARGS=true ;;
        --linux-build)        DEPLOY_LINUX=true; PLATFORM_ARGS=true; LINUX_STAGES="${LINUX_STAGES:+$LINUX_STAGES }build" ;;
        --linux-upload)       DEPLOY_LINUX=true; PLATFORM_ARGS=true; LINUX_STAGES="${LINUX_STAGES:+$LINUX_STAGES }upload" ;;
        --all)               DEPLOY_IOS=true; DEPLOY_ANDROID=true; DEPLOY_MACOS=true
                             DEPLOY_WINDOWS=true; DEPLOY_LINUX=true; DEPLOY_WEB=true
                             DEPLOY_SITE=true; PLATFORM_ARGS=true ;;
        # Zeroes web and site too, so "backend only" holds even after --all.
        --convex-only)       RUN_CONVEX=true; DEPLOY_IOS=false; DEPLOY_MACOS=false
                             DEPLOY_ANDROID=false; DEPLOY_WINDOWS=false; DEPLOY_LINUX=false
                             DEPLOY_WEB=false; DEPLOY_SITE=false
                             SKIP_VERSION_BUMP=true; PLATFORM_ARGS=true ;;
        --rollback-web)      ACTION="rollback-web" ;;
        --infra)             ACTION="infra" ;;
        --sync-releases)     ACTION="sync-releases" ;;
        --set-min-supported)
            ACTION="set-min-supported"
            SET_MIN_CHANNEL="${2:-}"
            SET_MIN_VERSION="${3:-}"
            shift 2
            ;;
        --dry)
            DRY_RUN=true
            RUN_CONVEX=false
            RUN_UPLOAD=false
            RUN_GIT=false
            SKIP_VERSION_BUMP=true
            ;;
        -h|--help) print_help; exit 0 ;;
        *) echo "❌ Unknown flag: $1"; print_help; exit 1 ;;
    esac
    shift
done

# Every SSH/rsync call to the VM shares these. BatchMode so a missing key fails
# fast instead of hanging on a password prompt nobody is there to type.
VM_SSH_OPTS="-i $VM_SSH_KEY -o BatchMode=yes -o ConnectTimeout=15"

vm_ssh() { ssh $VM_SSH_OPTS "$VM_USER@$VM_HOST" "$@"; }

require_vm() {
    if [ ! -f "$VM_SSH_KEY" ]; then
        echo "❌ VM SSH key not found: $VM_SSH_KEY"
        echo "   Set VM_SSH_KEY in .env.local if the key lives elsewhere."
        exit 1
    fi
    if ! ssh $VM_SSH_OPTS -o StrictHostKeyChecking=accept-new "$VM_USER@$VM_HOST" true 2>/dev/null; then
        echo "❌ Can't reach $VM_USER@$VM_HOST over SSH."
        echo "   Check the box is up and the key is authorized, then re-run."
        exit 1
    fi
}

# ----- standalone actions -----
# Both do one job and exit. Neither builds anything, so neither needs the
# picker, a version bump, or the Flutter toolchain.

# The live web build is swapped in as a whole directory, and the one it replaced
# is kept next to it. Rolling back is therefore a rename, not a rebuild — and
# because this swaps rather than restores, running it twice lands you back where
# you started.
rollback_web() {
    require_vm
    echo "↩️  Rolling back the web app..."
    if ! vm_ssh "[ -d $VM_WEB_DIR.prev ]"; then
        echo "❌ No previous build at $VM_WEB_DIR.prev — nothing to roll back to."
        exit 1
    fi
    if vm_ssh "set -e
               rm -rf $VM_WEB_DIR.swap
               mv $VM_WEB_DIR $VM_WEB_DIR.swap
               mv $VM_WEB_DIR.prev $VM_WEB_DIR
               mv $VM_WEB_DIR.swap $VM_WEB_DIR.prev"; then
        echo "  ✅ $WEB_URL now serves the previous build"
        echo "     (run --rollback-web again to swap back)"
    else
        echo "❌ Rollback failed. Inspect by hand:"
        echo "   ssh -i $VM_SSH_KEY $VM_USER@$VM_HOST 'ls -d $VM_WEB_DIR*'"
        exit 1
    fi
}

# The Caddy site block lives in this repo, not just on the box. Validation runs
# against the WHOLE config (the file alone can't catch a clash with the
# nestzone block), and a failure leaves the running config untouched.
push_infra() {
    require_vm
    local conf="hosting/caddy-monkeyhub.conf"
    [ -f "$conf" ] || { echo "❌ Missing $conf"; exit 1; }

    echo "🧱 Installing $conf on $VM_HOST..."
    scp $VM_SSH_OPTS "$conf" "$VM_USER@$VM_HOST:/tmp/monkeyhub.conf" >/dev/null || {
        echo "❌ Copy failed."; exit 1; }

    if ! vm_ssh "sudo cp /tmp/monkeyhub.conf /etc/caddy/monkeyhub.conf"; then
        echo "❌ Could not write /etc/caddy/monkeyhub.conf."
        exit 1
    fi
    if ! vm_ssh "grep -q 'import monkeyhub.conf' /etc/caddy/Caddyfile"; then
        echo "❌ /etc/caddy/Caddyfile does not import monkeyhub.conf."
        echo "   One-time fix on the box — replace the inline :8081 block with:"
        echo "       import monkeyhub.conf"
        echo "   See DEPLOY.md → 'Where it runs'."
        exit 1
    fi
    if ! vm_ssh "sudo caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1"; then
        echo "❌ Caddy rejected the config — NOT reloading. The running site is untouched."
        vm_ssh "sudo caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -5"
        exit 1
    fi
    if vm_ssh "sudo systemctl reload caddy"; then
        echo "  ✅ Caddy reloaded"
    else
        echo "❌ Reload failed: ssh … 'sudo journalctl -u caddy -n 30'"
        exit 1
    fi
}


# ----- reaching both Convex deployments -----
# `convex deploy` has pushed FUNCTIONS to both boxes since the migration (see
# run_convex). The `convex run` calls did not: they inherit backend/.env.local,
# so every releases:publish landed on the VPS alone. Since 2026-08-28 that is
# the box nobody is talking to — the home server serves the traffic, so the row
# that tells a client "there is a newer build" was being written where no client
# reads it. Shipping a build was invisible to every live user, and the drift was
# silent because the deploy it came from reported success. Code and release rows
# have to move together; --sync-releases below repairs a run that predates this.

# Mints the home server's admin key into HOMESERVER_KEY, once per shell.
#
# Sets a global rather than printing it: $(…) runs the function in a subshell,
# so a printing version would re-mint on every call and the caller would never
# see the cache — and a full --all run publishes five channels.
#
# A failed mint is cached too. When the box is unreachable the SSH connect
# timeout is the whole cost, and paying it once a run beats paying it once a
# channel; every caller still reports the miss on its own line.
HOMESERVER_KEY=""
HOMESERVER_KEY_TRIED=false
homeserver_admin_key() {
    if [ "$HOMESERVER_KEY_TRIED" = true ]; then
        [ -n "$HOMESERVER_KEY" ]
        return
    fi
    HOMESERVER_KEY_TRIED=true
    local key
    key="$(ssh -o BatchMode=yes -o ConnectTimeout=15 -n "$HOMESERVER_SSH" \
               "docker exec $HOMESERVER_CONTAINER ./generate_admin_key.sh 2>/dev/null | tail -1" 2>/dev/null)"
    # Shaped "<instance>|<hex>". Anything else is an SSH banner, a docker error
    # or the empty string, and exporting one of those as a credential buys a
    # confusing 401 instead of a clear "could not reach the box".
    case "$key" in
        *"|"*) HOMESERVER_KEY="$key" ;;
    esac
    [ -n "$HOMESERVER_KEY" ]
}

# Runs one Convex function on the home server. Exit 2 specifically means "could
# not mint a key", which is a different problem from a function that ran and
# failed, and the two want different advice.
#
# Runs from backend/ like the VPS call does, and for a reason worth stating: the
# env vars decide WHICH deployment this reaches, but the CLI still resolves the
# project (package.json, convex/) from the working directory. Pointed at the
# home server from the repo root it fails with "Unable to read your
# package.json", which reads like a credentials problem and is not one.
convex_run_homeserver() {   # $1 = function, $2 = payload
    homeserver_admin_key || return 2
    (cd backend &&
        CONVEX_SELF_HOSTED_URL="$HOMESERVER_URL" \
        CONVEX_SELF_HOSTED_ADMIN_KEY="$HOMESERVER_KEY" \
        npx convex run "$1" "$2" >/dev/null 2>&1)
}

# Runs one Convex function against BOTH deployments, VPS first — the same
# primary-before-standby ordering run_convex uses, for the same reason.
#
# A half-failure is reported, not fatal: one row written is strictly better than
# none, and the caller prints the retry for whichever half missed.
# CONVEX_RUN_FAILED names the targets that failed, "" when all of them landed.
CONVEX_RUN_FAILED=""
convex_run_both() {   # $1 = function, $2 = payload
    local fn="$1" payload="$2" why=""
    CONVEX_RUN_FAILED=""

    (cd backend && npx convex run "$fn" "$payload" >/dev/null 2>&1) ||
        CONVEX_RUN_FAILED="the VPS"

    if [ "$RUN_HOMESERVER" != true ]; then
        [ -z "$CONVEX_RUN_FAILED" ]
        return
    fi

    convex_run_homeserver "$fn" "$payload"
    case $? in
        0) ;;
        2) why="the home server (no admin key — is it up and Tailscale connected?)" ;;
        *) why="the home server" ;;
    esac
    [ -z "$why" ] || CONVEX_RUN_FAILED="${CONVEX_RUN_FAILED:+$CONVEX_RUN_FAILED and }$why"

    [ -z "$CONVEX_RUN_FAILED" ]
}

# The retry lines for a call that half-landed, meant to be pasted. The home
# server's line mints its key inline, because there is none on disk to point at.
convex_retry_hint() {   # $1 = function, $2 = already-shell-quoted payload
    echo "     VPS:         (cd backend && npx convex run $1 $2)"
    [ "$RUN_HOMESERVER" = true ] || return 0
    echo "     home server: (cd backend && CONVEX_SELF_HOSTED_URL=$HOMESERVER_URL \\"
    echo "                     CONVEX_SELF_HOSTED_ADMIN_KEY=\"\$(ssh $HOMESERVER_SSH 'docker exec $HOMESERVER_CONTAINER ./generate_admin_key.sh | tail -1')\" \\"
    echo "                     npx convex run $1 $2)"
}

# Reads back a channel's currently published version, or fails (nothing on
# stdout) if the channel has never been published to. Shared by
# set_min_supported (so a force-update never clobbers `version`, a required
# arg on releases:publish) and the picker's 'f' flow (so "require whatever's
# already live" needs no typing).
#
# Reads ONE deployment — the VPS, the default target — while its callers write
# both, and that asymmetry is deliberate. A read that had to pick a winner
# between two disagreeing boxes would need a version comparison to do it
# safely: read the older box, republish it to both, and you have just told
# every live client that the newest build is one they already have. The VPS is
# the box that has received every publish to date, so it is the one that can
# answer for the history. Once writes go to both there is nothing to choose
# between; --sync-releases squares up whatever came before.
channel_current_version() {   # $1 = channel
    local current
    current=$(cd backend && npx convex run releases:latest "{\"channel\":\"$1\"}" 2>/dev/null)
    [ -z "$current" ] || [ "$current" = "null" ] && return 1
    echo "$current" | jq -r '.version'
}

# Force-updates an already-shipped channel without a new build. `version` is a
# required arg on releases:publish (see backend/convex/releases.ts), so this
# reads back the channel's current version first and republishes it unchanged —
# only minSupported moves. "clear" sends null to lift the gate; anything else
# is set as the new minSupported string. Returns rather than exits — the
# --set-min-supported CLI action exits on a false return itself; the picker's
# 'f' flow instead falls back to its checklist so a failure doesn't kill the
# whole interactive session.
set_min_supported() {   # $1 = channel, $2 = version, or "clear"
    local channel="$1"
    local min="$2"
    if [ -z "$channel" ] || [ -z "$min" ]; then
        echo "❌ Usage: --set-min-supported <channel> <version|clear>"
        return 1
    fi
    local version
    version=$(channel_current_version "$channel")
    if [ -z "$version" ]; then
        echo "❌ No published release found for channel '$channel' — nothing to gate."
        echo "   Channels: ios-testflight, macos-testflight, android-play, android-apk, web."
        return 1
    fi
    local payload
    if [ "$min" = "clear" ]; then
        payload=$(jq -nc --arg channel "$channel" --arg version "$version" \
            '{channel: $channel, version: $version, minSupported: null}')
    else
        payload=$(jq -nc --arg channel "$channel" --arg version "$version" --arg min "$min" \
            '{channel: $channel, version: $version, minSupported: $min}')
    fi
    # Both deployments: a gate missing from the standby vanishes the moment
    # traffic is flipped to it.
    if convex_run_both releases:publish "$payload"; then
        if [ "$min" = "clear" ]; then
            echo "  ✅ Cleared minSupported on $channel (still shipping $version)"
        else
            echo "  ✅ $channel now requires >= $min (still shipping $version) — older clients lose \"Later\""
        fi
    else
        echo "❌ Failed to update $channel on $CONVEX_RUN_FAILED. Retry with:"
        convex_retry_hint releases:publish "$(printf '%s' "$payload" | jq -Rr @sh)"
        return 1
    fi
}

# Copies every channel's release row from the VPS to the home server, and says
# what it found on the way. The repair tool for everything published before this
# script wrote both boxes: those runs left the home server — the one clients
# actually read — announcing an older build than the one that shipped.
#
# Reads over the public HTTP query rather than `convex run`, for the same reason
# switchServer.sh's serve_of does: this is the exact endpoint the app hits on
# cold start, so what it prints is what a client is being told.
RELEASE_CHANNELS="ios-testflight macos-testflight android-play android-apk web"

release_row() {   # $1 = base url, $2 = channel → the row as JSON, or "null"
    curl -s -m 10 -X POST "$1/api/query" \
        -H 'Content-Type: application/json' \
        -d "{\"path\":\"releases:latest\",\"args\":{\"channel\":\"$2\"},\"format\":\"json\"}" \
        2>/dev/null |
        jq -c 'if .status == "success" then .value else "unreachable" end' 2>/dev/null
}

sync_releases() {
    local vps_url
    vps_url=$(sed -n 's/^CONVEX_SELF_HOSTED_URL=//p' backend/.env.local 2>/dev/null | tr -d '"' | head -1)
    if [ -z "$vps_url" ]; then
        echo "❌ No CONVEX_SELF_HOSTED_URL in backend/.env.local — nothing to copy from."
        return 1
    fi

    echo "🔄 Squaring up release rows"
    echo "   from  $vps_url  (the VPS — primary, the box clients read)"
    echo "   onto  $HOMESERVER_URL  (the home server — the standby)"
    echo ""

    local failed=false changed=0 channel src dst src_ver dst_ver payload dst_cmp
    for channel in $RELEASE_CHANNELS; do
        src=$(release_row "$vps_url" "$channel")
        dst=$(release_row "$HOMESERVER_URL" "$channel")

        if [ "$src" = '"unreachable"' ] || [ -z "$src" ]; then
            printf "  ❌ %-18s could not read the VPS\n" "$channel"
            failed=true
            continue
        fi
        if [ "$src" = "null" ]; then
            printf "  ⏭️  %-18s never published anywhere\n" "$channel"
            continue
        fi
        if [ "$dst" = '"unreachable"' ] || [ -z "$dst" ]; then
            printf "  ❌ %-18s could not read the home server\n" "$channel"
            failed=true
            continue
        fi
        # Every optional field goes explicitly, nulls included. releases:publish
        # reads an OMITTED key as "leave what is there", so copying only the
        # fields the VPS has set would leave a stale minSupported or updateUrl
        # standing on the home server — the half of the row most likely to be
        # the reason the two disagree in the first place.
        payload=$(echo "$src" | jq -c '{channel, version, minSupported, updateUrl, notes}')
        # Compared on those same five fields rather than on the whole row,
        # because `latest` also returns publishedAt and that is a per-write
        # clock: the two boxes get different values for the very same sync, so
        # comparing it would report "different" forever and rewrite all five
        # channels on every run.
        dst_cmp=$(echo "$dst" | jq -c 'if . == null then null else {channel, version, minSupported, updateUrl, notes} end')

        if [ "$payload" = "$dst_cmp" ]; then
            printf "  ✅ %-18s already matching (%s)\n" "$channel" "$(echo "$src" | jq -r '.version')"
            continue
        fi

        src_ver=$(echo "$src" | jq -r '.version')
        dst_ver=$(echo "$dst" | jq -r 'if . == null then "nothing" else .version end')

        if convex_run_homeserver releases:publish "$payload"; then
            printf "  ✅ %-18s %s → %s\n" "$channel" "$dst_ver" "$src_ver"
            changed=$((changed + 1))
        else
            printf "  ❌ %-18s could not write %s to the home server\n" "$channel" "$src_ver"
            failed=true
        fi
    done

    echo ""
    if [ "$failed" = true ]; then
        echo "⚠️  Some channels did not sync. If the key is the problem, check that"
        echo "   ssh $HOMESERVER_SSH works and Tailscale is up, then re-run."
        return 1
    fi
    if [ "$changed" -eq 0 ]; then
        echo "✨ Nothing to do — both deployments already agree on every channel."
    else
        echo "✨ $changed channel(s) synced. Clients on the home server now see what shipped."
    fi
}

case "$ACTION" in
    rollback-web)      rollback_web; exit 0 ;;
    infra)              push_infra;   exit 0 ;;
    set-min-supported)  set_min_supported "$SET_MIN_CHANNEL" "$SET_MIN_VERSION" || exit 1; exit 0 ;;
    sync-releases)      sync_releases || exit 1; exit 0 ;;
esac

# ----- interactive platform picker -----
# Shared by pick_platforms and pick_stage_menu below. Reads one logical
# keypress from fd 3 into KEY_KIND (PLAIN/UP/DOWN/ESC) and, for PLAIN,
# KEY_CHAR.
#
# macOS's stock /bin/bash is 3.2, which has no fractional `read -t` timeout —
# distinguishing a bare Esc from the start of an arrow-key escape sequence
# ("Esc [ A") needs a full second's wait for a second byte that, for a bare
# Esc, never comes. A real keypress typed quickly right after Esc can land
# inside that second, and naively discarding whatever the lookahead read
# picked up would silently eat it — most noticeably when Esc cancels a
# pick_stage_menu sub-menu (Tab, or 'f') and the very next key is meant for
# the checklist underneath. $?, not just an empty variable, is what tells a
# genuine timeout (nothing arrived) apart from "Enter arrived, and happens to
# read as empty" — read -n1 strips Enter to "", same as a timeout leaves the
# variable, so only the exit status disambiguates them.
#
# The rescued byte is parked in PENDING_KEY_FILE and replayed by the next
# read_key call — via a file, not a variable, because pick_stage_menu is
# invoked as `choice=$(pick_stage_menu ...)`, a command substitution
# subshell, so a variable it set could never reach the caller. $$ is stable
# across that subshell (bash keeps it as the invoking shell's PID, not the
# subshell's), so every read_key call — inside or outside pick_stage_menu —
# agrees on the same path.
PENDING_KEY_FILE="${TMPDIR:-/tmp}/.monkeyhub_deploy_pending_key.$$"
rm -f "$PENDING_KEY_FILE" 2>/dev/null
read_key() {
    local key esc2 esc2_rc esc3 esc3_rc pending
    if [ -f "$PENDING_KEY_FILE" ]; then
        pending=$(cat "$PENDING_KEY_FILE")
        rm -f "$PENDING_KEY_FILE"
        [ "$pending" = "__ENTER__" ] && key="" || key="$pending"
    else
        IFS= read -rsn1 -u3 key
    fi
    if [ "$key" = $'\x1b' ]; then
        IFS= read -rsn1 -t 1 -u3 esc2; esc2_rc=$?
        if [ $esc2_rc -ne 0 ]; then
            KEY_KIND=ESC; return
        fi
        if [ "$esc2" = "[" ]; then
            IFS= read -rsn1 -t 1 -u3 esc3; esc3_rc=$?
            if [ $esc3_rc -ne 0 ]; then
                KEY_KIND=ESC; return
            fi
            case "$esc3" in
                A) KEY_KIND=UP; return ;;
                B) KEY_KIND=DOWN; return ;;
                *) KEY_KIND=ESC
                   [ -n "$esc3" ] && printf '%s' "$esc3" > "$PENDING_KEY_FILE"
                   return ;;
            esac
        elif [ -z "$esc2" ]; then
            printf '%s' "__ENTER__" > "$PENDING_KEY_FILE"
            KEY_KIND=ESC
            return
        else
            printf '%s' "$esc2" > "$PENDING_KEY_FILE"
            KEY_KIND=ESC
            return
        fi
    fi
    KEY_KIND=PLAIN
    KEY_CHAR="$key"
}

# Single-select sub-menu opened by pressing Tab on an iOS/macOS/Android/Web row
# in pick_platforms below — scopes that platform to one stage (see "Per-platform
# stages" in -h) without leaving the picker. Prints the chosen token to stdout
# for the caller to capture via $(...); every interactive redraw below is
# therefore sent to stderr instead, since anything on stdout here would be
# swallowed into that capture rather than reaching the terminal. $1 = title,
# then "token:option label" pairs. Returns 1 with no output on Esc (cancel).
pick_stage_menu() {
    local title="$1"; shift
    local tokens=() opts=() pair
    for pair in "$@"; do
        tokens+=("${pair%%:*}")
        opts+=("${pair#*:}")
    done
    local n=${#opts[@]} sel=0 i arrow cancelled=false
    {
        printf "    %s  (↑/↓ move · enter choose · esc cancel)\033[K\n" "$title"
        while true; do
            for i in $(seq 0 $((n - 1))); do
                [ "$i" = "$sel" ] && arrow="❯" || arrow=" "
                printf "      %s %s\033[K\n" "$arrow" "${opts[$i]}"
            done
            read_key
            case "$KEY_KIND" in
                UP)   sel=$(( (sel + n - 1) % n )) ;;
                DOWN) sel=$(( (sel + 1) % n )) ;;
                ESC)  cancelled=true; break ;;
                PLAIN) [ -z "$KEY_CHAR" ] && break ;;  # enter
            esac
            tput cuu $n 2>/dev/null
        done
        # Erase everything this menu drew (title + n options) and leave the
        # cursor exactly where it was before the menu opened.
        tput cuu $((n + 1)) 2>/dev/null
        for i in $(seq 0 $n); do printf "\033[K\n"; done
        tput cuu $((n + 1)) 2>/dev/null
    } 1>&2
    [ "$cancelled" = true ] && return 1
    echo "${tokens[$sel]}"
}

# Checkbox sibling of pick_stage_menu, used by the picker's 'f' flow so one
# force-update can cover several channels in a single pass. Same draw/erase
# discipline and the same stderr-only redraw (stdout belongs to the caller's
# $(...) capture); prints the ticked tokens space-separated. Returns 1 with no
# output on Esc *and* on Enter with nothing ticked — both mean "never mind",
# and the caller has no reason to tell them apart.
pick_multi_menu() {
    local title="$1"; shift
    local tokens=() opts=() pair
    for pair in "$@"; do
        tokens+=("${pair%%:*}")
        opts+=("${pair#*:}")
    done
    local n=${#opts[@]} sel=0 i arrow marker all_on cancelled=false out=""
    local checked=()
    for i in $(seq 0 $((n - 1))); do checked[$i]=0; done
    {
        printf "    %s  (↑/↓ · space toggle · a all · enter go · esc)\033[K\n" "$title"
        while true; do
            for i in $(seq 0 $((n - 1))); do
                [ "$i" = "$sel" ] && arrow="❯" || arrow=" "
                [ "${checked[$i]}" = 1 ] && marker="◉" || marker="◯"
                printf "      %s %s %s\033[K\n" "$arrow" "$marker" "${opts[$i]}"
            done
            read_key
            case "$KEY_KIND" in
                UP)   sel=$(( (sel + n - 1) % n )) ;;
                DOWN) sel=$(( (sel + 1) % n )) ;;
                ESC)  cancelled=true; break ;;
                PLAIN)
                    case "$KEY_CHAR" in
                        " ") checked[$sel]=$(( 1 - checked[$sel] )) ;;
                        # One key for both halves of "all": 'a' ticks everything,
                        # and unticks everything once it is already all ticked.
                        a|A)
                            all_on=true
                            for i in $(seq 0 $((n - 1))); do
                                [ "${checked[$i]}" = 1 ] || { all_on=false; break; }
                            done
                            for i in $(seq 0 $((n - 1))); do
                                [ "$all_on" = true ] && checked[$i]=0 || checked[$i]=1
                            done
                            ;;
                        "") break ;;  # enter
                    esac
                    ;;
            esac
            tput cuu $n 2>/dev/null
        done
        # Erase everything this menu drew (title + n options) and leave the
        # cursor exactly where it was before the menu opened.
        tput cuu $((n + 1)) 2>/dev/null
        for i in $(seq 0 $n); do printf "\033[K\n"; done
        tput cuu $((n + 1)) 2>/dev/null
    } 1>&2
    [ "$cancelled" = true ] && return 1
    for i in $(seq 0 $((n - 1))); do
        [ "${checked[$i]}" = 1 ] && out="$out ${tokens[$i]}"
    done
    [ -z "$out" ] && return 1
    echo "${out# }"
}

# Picker row → platform key, for the ship order. Rows 1-6 are platforms.
picker_row_key() {
    case "$1" in
        1) echo ios ;; 2) echo macos ;; 3) echo android ;;
        4) echo windows ;; 5) echo linux ;; 6) echo web ;;
    esac
}
# Space-separated list helpers for that order.
order_without() { local out="" k; for k in $1; do [ "$k" = "$2" ] || out="$out $k"; done; echo "${out# }"; }
order_index() { local i=1 k; for k in $1; do [ "$k" = "$2" ] && { echo $i; return; }; i=$((i + 1)); done; }

# Checkbox menu on the controlling terminal. Only used when the caller gave no
# platform flags and we actually have a TTY to talk to.
pick_platforms() {
    local labels=("Convex backend" "iOS  → App Store Connect"
                  "macOS → App Store Connect"
                  "Android → Google Play (internal track)"
                  "Windows → Microsoft Store (built on GitHub Actions)"
                  "Linux → downloads page + AUR (built on GitHub Actions)"
                  "Web  → $WEB_URL" "Site → $SITE_URL  (pages only, no build)"
                  "Bump version (patch)"
                  "Free disk space after each upload")
    # Menu starts on Convex only. Unlike --all (which ships everything), the
    # picker leaves the rest unticked so a bare Enter stays cheap and a stray
    # Enter can't kick off an App Store / Play upload by accident.
    local selected=(1 0 0 0 0 0 0 0 0 0)
    [ "$FREE_SPACE" = true ] && selected[9]=1
    # Honor explicit --no-convex / --macos / --web / --site even in interactive mode.
    [ "$RUN_CONVEX" = false ] && selected[0]=0
    [ "$DEPLOY_MACOS" = true ] && selected[2]=1
    [ "$DEPLOY_WINDOWS" = true ] && selected[4]=1
    [ "$DEPLOY_LINUX" = true ] && selected[5]=1
    [ "$DEPLOY_WEB" = true ] && selected[6]=1
    [ "$DEPLOY_SITE" = true ] && selected[7]=1
    # "Bump version" only does anything once an app platform ships (see
    # "Version bump only makes sense..." below) — a Convex- or Site-only run
    # would show it pre-checked for no reason. It defaults on the moment
    # an app platform is (iOS/macOS/Android/Windows/Linux — matching --skip-version-bump's own default: bump
    # unless told not to) and off again the moment none of them are, tracked
    # live as those three rows get toggled — see the space-key handling below.
    # --skip-version-bump always wins, even over a pre-set --macos.
    if [ "$SKIP_VERSION_BUMP" != true ]; then
        { [ "${selected[1]}" = 1 ] || [ "${selected[2]}" = 1 ] || [ "${selected[3]}" = 1 ] \
          || [ "${selected[4]}" = 1 ] || [ "${selected[5]}" = 1 ]; } \
            && selected[8]=1
    fi
    local prev_any_app=false
    { [ "${selected[1]}" = 1 ] || [ "${selected[2]}" = 1 ] || [ "${selected[3]}" = 1 ] \
      || [ "${selected[4]}" = 1 ] || [ "${selected[5]}" = 1 ]; } \
        && prev_any_app=true
    local cursor=0 count=10 extra=2 i marker arrow label key pos
    # Ship order = the order platform rows get ticked. Rows already ticked by
    # a flag (--macos etc.) start it, in the default mobile-first order.
    local pick_order=""
    for key in $PLATFORM_ORDER; do
        for i in 1 2 3 4 5 6; do
            [ "$(picker_row_key $i)" = "$key" ] && [ "${selected[$i]}" = 1 ] \
                && pick_order="$pick_order $key"
        done
    done
    pick_order="${pick_order# }"
    # Per-platform stage override, set via Tab. Empty = full pipeline. Threaded
    # into IOS_STAGES etc. below once Enter is pressed — see "stage defaults".
    local pstage_ios="" pstage_macos="" pstage_android="" pstage_web=""
    local pstage_windows="" pstage_linux=""

    exec 3</dev/tty
    tput civis 2>/dev/null || true
    echo "Select what to deploy  (↑/↓ move · space toggle · enter go · tab stage · f force-update)"
    echo "Platforms ship in the order you tick them (the number). Convex goes first, Site last."
    while true; do
        local skip_erase=false
        for i in $(seq 0 $((count - 1))); do
            [ "${selected[$i]}" = 1 ] && marker="◉" || marker="◯"
            [ "$i" = "$cursor" ] && arrow="❯" || arrow=" "
            label="${labels[$i]}"
            key=$(picker_row_key "$i")
            if [ -n "$key" ]; then
                pos=$(order_index "$pick_order" "$key")
                [ -n "$pos" ] && label="$pos. $label" || label="   $label"
            fi
            case "$i" in
                1) [ -n "$pstage_ios" ]     && label="$label  [$pstage_ios]" ;;
                2) [ -n "$pstage_macos" ]   && label="$label  [$pstage_macos]" ;;
                3) [ -n "$pstage_android" ] && label="$label  [$pstage_android]" ;;
                4) [ -n "$pstage_windows" ] && label="$label  [$pstage_windows]" ;;
                5) [ -n "$pstage_linux" ]   && label="$label  [$pstage_linux]" ;;
                6) [ -n "$pstage_web" ]     && label="$label  [$pstage_web]" ;;
            esac
            printf "  %s %s %s\033[K\n" "$arrow" "$marker" "$label"
        done
        printf "\n  [f] Force-update channels (edit minSupported)…\033[K\n"
        read_key
        if [ "$KEY_KIND" = "UP" ]; then
            cursor=$(( (cursor + count - 1) % count ))
        elif [ "$KEY_KIND" = "DOWN" ]; then
            cursor=$(( (cursor + 1) % count ))
        elif [ "$KEY_KIND" = "ESC" ]; then
            :  # bare Esc on the checklist itself is a no-op
        elif [ "$KEY_KIND" = "PLAIN" ] && [ "$KEY_CHAR" = " " ]; then
            selected[$cursor]=$(( 1 - selected[$cursor] ))
            key=$(picker_row_key "$cursor")
            if [ -n "$key" ]; then
                pick_order=$(order_without "$pick_order" "$key")
                [ "${selected[$cursor]}" = 1 ] && pick_order="${pick_order:+$pick_order }$key"
            fi
            case "$cursor" in
                1|2|3|4|5)
                    local any_app=false
                    { [ "${selected[1]}" = 1 ] || [ "${selected[2]}" = 1 ] || [ "${selected[3]}" = 1 ] \
                      || [ "${selected[4]}" = 1 ] || [ "${selected[5]}" = 1 ]; } \
                        && any_app=true
                    if [ "$any_app" = true ] && [ "$prev_any_app" = false ]; then
                        selected[8]=1  # first app platform checked — default the bump back on
                    elif [ "$any_app" = false ]; then
                        selected[8]=0  # no app platform left — bump would be a no-op
                    fi
                    prev_any_app=$any_app
                    ;;
            esac
        elif [ "$KEY_KIND" = "PLAIN" ] && [ "$KEY_CHAR" = $'\t' ]; then
            local choice rc=1
            case "$cursor" in
                1) choice=$(pick_stage_menu "iOS — pick a stage" "full:Full pipeline" \
                                "archive:Archive only" "export:Export only" \
                                "upload:Upload only"); rc=$? ;;
                2) choice=$(pick_stage_menu "macOS — pick a stage" "full:Full pipeline" \
                                "archive:Archive only" "export:Export only" \
                                "upload:Upload only"); rc=$? ;;
                3) choice=$(pick_stage_menu "Android — pick a stage" "full:Full pipeline" \
                                "build:Build only" "upload:Upload only"); rc=$? ;;
                4) choice=$(pick_stage_menu "Windows — pick a stage" "full:Full pipeline" \
                                "build:Build only (CI + download)" "upload:Upload only"); rc=$? ;;
                5) choice=$(pick_stage_menu "Linux — pick a stage" "full:Full pipeline" \
                                "build:Build only (CI + download)" "upload:Upload only"); rc=$? ;;
                6) choice=$(pick_stage_menu "Web — pick a stage" "full:Full pipeline" \
                                "build:Build only" "upload:Upload only"); rc=$? ;;
            esac
            if [ "$rc" = 0 ]; then
                [ "$choice" = "full" ] && choice=""
                key=$(picker_row_key "$cursor")
                if [ -n "$key" ] && [ -z "$(order_index "$pick_order" "$key")" ]; then
                    pick_order="${pick_order:+$pick_order }$key"
                fi
                case "$cursor" in
                    1) pstage_ios="$choice";     selected[1]=1 ;;
                    2) pstage_macos="$choice";   selected[2]=1 ;;
                    3) pstage_android="$choice"; selected[3]=1 ;;
                    4) pstage_windows="$choice"; selected[4]=1 ;;
                    5) pstage_linux="$choice";   selected[5]=1 ;;
                    6) pstage_web="$choice";     selected[6]=1 ;;
                esac
            fi
        elif [ "$KEY_KIND" = "PLAIN" ] && { [ "$KEY_CHAR" = "f" ] || [ "$KEY_CHAR" = "F" ]; }; then
            # Both steps below are a pick_*_menu, so Esc at either one cancels
            # straight back to this checklist — nothing is printed and nothing
            # needs erasing (both menus always clean up after themselves,
            # success or cancel). Only a completed force-update — or a channel
            # that had to be dropped — leaves output on screen, which is
            # deliberate: skip_erase leaves it visible above the redrawn
            # checklist instead of scrolling it away unread.
            local fu_channels fu_current fu_action fu_version rc c
            local fu_ok=() fu_ver=() fu_dropped="" fu_n fu_title fu_same fu_label
            fu_channels=$(pick_multi_menu "Force-update which channels?" \
                "ios-testflight:iOS · TestFlight" "macos-testflight:macOS · TestFlight" \
                "android-play:Android · Play" "android-apk:Android · sideloaded APK" \
                "web:Web" "windows:Windows" "linux:Linux"); rc=$?
            if [ "$rc" = 0 ]; then
                # A `releases:latest` round-trip per ticked channel, so say so
                # rather than sit there looking hung. The line is erased again
                # (cursor left at its column 0) before anything else prints.
                printf "  ⏳ Reading current versions…\033[K\n"
                for c in $fu_channels; do
                    fu_current=$(channel_current_version "$c")
                    if [ -z "$fu_current" ]; then
                        # Never published to, so there is no `version` to
                        # republish and nothing to gate — drop that one channel
                        # instead of failing the whole batch.
                        fu_dropped="$fu_dropped $c"
                    else
                        fu_ok+=("$c")
                        fu_ver+=("$fu_current")
                    fi
                done
                tput cuu 1 2>/dev/null
                printf "\033[K"
                for c in $fu_dropped; do
                    echo "  ⚠️  No published release for $c yet — nothing to force."
                    skip_erase=true
                done
                fu_n=${#fu_ok[@]}
                if [ "$fu_n" -gt 0 ]; then
                    if [ "$fu_n" = 1 ]; then
                        fu_label="${fu_ok[0]}"
                        fu_same="Require ${fu_ver[0]} — forces everyone below it to update now"
                    else
                        fu_label="$fu_n channels"
                        fu_same="Require each channel's latest — forces everyone below it to update now"
                    fi
                    fu_title="Force-update $fu_label"
                    fu_action=$(pick_stage_menu "$fu_title" \
                        "same:$fu_same" \
                        "custom:Type a different minimum version" \
                        "clear:Clear the requirement"); rc=$?
                    if [ "$rc" = 0 ]; then
                        case "$fu_action" in
                            # "same" is per channel — each keeps its own latest,
                            # which is the whole point of ticking several at once.
                            same)
                                for i in $(seq 0 $((fu_n - 1))); do
                                    set_min_supported "${fu_ok[$i]}" "${fu_ver[$i]}"
                                done
                                skip_erase=true ;;
                            clear)
                                for c in "${fu_ok[@]}"; do
                                    set_min_supported "$c" "clear"
                                done
                                skip_erase=true ;;
                            custom)
                                tput cnorm 2>/dev/null || true
                                IFS= read -rp "  Minimum supported version for $fu_label (blank cancels): " \
                                    -u3 fu_version
                                tput civis 2>/dev/null || true
                                if [ -n "$fu_version" ]; then
                                    for c in "${fu_ok[@]}"; do
                                        set_min_supported "$c" "$fu_version"
                                    done
                                    skip_erase=true
                                else
                                    # Cancelled — erase the prompt line so the
                                    # trailing tput cuu below (which assumes the
                                    # cursor is exactly count+extra lines below
                                    # the checklist) stays correct.
                                    tput cuu 1 2>/dev/null
                                    printf "\033[K\n"
                                    tput cuu 1 2>/dev/null
                                fi
                                ;;
                        esac
                    fi
                fi
            fi
        elif [ "$KEY_KIND" = "PLAIN" ] && [ -z "$KEY_CHAR" ]; then  # enter
            break
        fi
        [ "$skip_erase" = false ] && tput cuu $((count + extra)) 2>/dev/null
    done
    tput cnorm 2>/dev/null || true
    exec 3<&-

    RUN_CONVEX=$([ "${selected[0]}" = 1 ] && echo true || echo false)
    DEPLOY_IOS=$([ "${selected[1]}" = 1 ] && echo true || echo false)
    DEPLOY_MACOS=$([ "${selected[2]}" = 1 ] && echo true || echo false)
    DEPLOY_ANDROID=$([ "${selected[3]}" = 1 ] && echo true || echo false)
    DEPLOY_WINDOWS=$([ "${selected[4]}" = 1 ] && echo true || echo false)
    DEPLOY_LINUX=$([ "${selected[5]}" = 1 ] && echo true || echo false)
    DEPLOY_WEB=$([ "${selected[6]}" = 1 ] && echo true || echo false)
    DEPLOY_SITE=$([ "${selected[7]}" = 1 ] && echo true || echo false)
    SKIP_VERSION_BUMP=$([ "${selected[8]}" = 1 ] && echo false || echo true)
    FREE_SPACE=$([ "${selected[9]}" = 1 ] && echo true || echo false)
    # Ticked platforms in tick order, then the rest (unticked, so they no-op).
    for key in $PLATFORM_ORDER; do
        [ -z "$(order_index "$pick_order" "$key")" ] && pick_order="${pick_order:+$pick_order }$key"
    done
    PLATFORM_ORDER="$pick_order"
    [ -n "$pstage_ios" ]     && IOS_STAGES="$pstage_ios"
    [ -n "$pstage_macos" ]   && MACOS_STAGES="$pstage_macos"
    [ -n "$pstage_android" ] && ANDROID_STAGES="$pstage_android"
    [ -n "$pstage_web" ]     && WEB_STAGES="$pstage_web"
    [ -n "$pstage_windows" ] && WINDOWS_STAGES="$pstage_windows"
    [ -n "$pstage_linux" ]   && LINUX_STAGES="$pstage_linux"

    if [ "$RUN_CONVEX" = false ] && [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_MACOS" = false ] \
       && [ "$DEPLOY_ANDROID" = false ] && [ "$DEPLOY_WEB" = false ] && [ "$DEPLOY_SITE" = false ] \
       && [ "$DEPLOY_WINDOWS" = false ] && [ "$DEPLOY_LINUX" = false ]; then
        echo "Nothing selected — exiting."
        exit 0
    fi
}

if [ "$PLATFORM_ARGS" = false ]; then
    if [ -t 0 ] && [ -e /dev/tty ]; then
        pick_platforms
    else
        # Legacy non-interactive default: Convex + iOS.
        DEPLOY_IOS=true
        DEPLOY_ANDROID=false
    fi
fi
# A pages-only run is HTML and nothing else. Pushing the backend as a side
# effect would turn a five-second copy-fix into a full deploy nobody asked for —
# so --site on its own leaves Convex alone. Ask for both and you get both.
if [ -z "$RUN_CONVEX" ] && [ "$DEPLOY_SITE" = true ] \
   && [ "$DEPLOY_IOS" != true ] && [ "$DEPLOY_ANDROID" != true ] && [ "$DEPLOY_WEB" != true ] \
   && [ "$DEPLOY_WINDOWS" != true ] && [ "$DEPLOY_LINUX" != true ]; then
    RUN_CONVEX=false
fi
[ -z "$RUN_CONVEX" ] && RUN_CONVEX=true
[ -z "$DEPLOY_IOS" ] && DEPLOY_IOS=false
[ -z "$DEPLOY_ANDROID" ] && DEPLOY_ANDROID=false
# Version bump only makes sense when an app ships.
if [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_ANDROID" = false ] && [ "$DEPLOY_MACOS" = false ] \
   && [ "$DEPLOY_WINDOWS" = false ] && [ "$DEPLOY_LINUX" = false ]; then
    SKIP_VERSION_BUMP=true
fi

# ----- stage defaults -----
# DEPLOY_X=true with no stage flags/picker choice means the full pipeline.
[ "$DEPLOY_IOS" = true ]     && [ -z "$IOS_STAGES" ]     && IOS_STAGES="archive export upload"
[ "$DEPLOY_MACOS" = true ]   && [ -z "$MACOS_STAGES" ]   && MACOS_STAGES="archive export upload"
[ "$DEPLOY_ANDROID" = true ] && [ -z "$ANDROID_STAGES" ] && ANDROID_STAGES="build upload"
[ "$DEPLOY_WEB" = true ]     && [ -z "$WEB_STAGES" ]     && WEB_STAGES="build upload"
[ "$DEPLOY_WINDOWS" = true ] && [ -z "$WINDOWS_STAGES" ] && WINDOWS_STAGES="build upload"
[ "$DEPLOY_LINUX" = true ]   && [ -z "$LINUX_STAGES" ]   && LINUX_STAGES="build upload"

# A platform whose stage set skips its own first stage (archive/build) is
# resuming from an artifact a previous run already produced — 'flutter clean'
# would delete that artifact out from under it, and a fresh version bump would
# no longer match what's actually baked into it. NEEDS_FLUTTER_BUILD gates the
# shared "flutter clean && pub get" prep step below; NEEDS_ARTIFACT_REUSE, if
# true for ANY platform this run, disables 'flutter clean' and the version
# bump for the WHOLE run — simpler and safer than tracking it per platform when
# 'flutter clean' would nuke every platform's build/ output at once regardless
# of which one asked for it.
NEEDS_FLUTTER_BUILD=false
NEEDS_ARTIFACT_REUSE=false
if [ "$DEPLOY_IOS" = true ]; then
    has_stage "$IOS_STAGES" archive && NEEDS_FLUTTER_BUILD=true || NEEDS_ARTIFACT_REUSE=true
fi
if [ "$DEPLOY_MACOS" = true ]; then
    has_stage "$MACOS_STAGES" archive && NEEDS_FLUTTER_BUILD=true || NEEDS_ARTIFACT_REUSE=true
fi
if [ "$DEPLOY_ANDROID" = true ]; then
    has_stage "$ANDROID_STAGES" build && NEEDS_FLUTTER_BUILD=true || NEEDS_ARTIFACT_REUSE=true
fi
if [ "$DEPLOY_WEB" = true ]; then
    has_stage "$WEB_STAGES" build && NEEDS_FLUTTER_BUILD=true || NEEDS_ARTIFACT_REUSE=true
fi
# Windows/Linux compile on CI, so they never need the local clean + pub get —
# but an upload-only run reuses the artifact an earlier run downloaded into
# build/, which a 'flutter clean' for another platform would delete.
if [ "$DEPLOY_WINDOWS" = true ] && ! has_stage "$WINDOWS_STAGES" build; then
    NEEDS_ARTIFACT_REUSE=true
fi
if [ "$DEPLOY_LINUX" = true ] && ! has_stage "$LINUX_STAGES" build; then
    NEEDS_ARTIFACT_REUSE=true
fi
if [ "$NEEDS_ARTIFACT_REUSE" = true ] && [ "$SKIP_VERSION_BUMP" = false ]; then
    echo "⏭️  Skipping version bump — a stage-only platform is reusing a previous"
    echo "    build/ output, so the version must match what's already baked into it."
    SKIP_VERSION_BUMP=true
fi

# Anything that publishes to the VM also refreshes the pages, because both of
# them print the current version in their footer. Left to a separate flag that
# footer would quietly rot one deploy at a time — and a stale version on the
# front page is exactly the thing nobody notices.
#
# Android is deliberately NOT in here any more: it ships to Play and puts
# nothing on the VM, so a Play deploy has no page to refresh.
if [ "$RUN_UPLOAD" = true ] && { [ "$DEPLOY_WEB" = true ] || [ "$DEPLOY_LINUX" = true ]; }; then
    DEPLOY_SITE=true   # Linux adds a card to the downloads page
fi

# Stages shown only when they're a strict subset of the platform's full
# pipeline — the everyday case (nothing/full selected) stays quiet.
stage_note() {   # $1 = stages string, $2 = full stages string
    [ "$1" = "$2" ] && return
    echo " [${1// /,}]"
}

echo ""
echo "🐵 MonkeyHub deploy"
echo "  • Convex deploy:    $([ "$RUN_CONVEX" = true ] && echo yes || echo no)"
echo "  • Version bump:     $([ "$SKIP_VERSION_BUMP" = false ] && echo yes || echo no)"
echo "  • iOS build:        $([ "$DEPLOY_IOS" = true ] && echo yes || echo no)$([ "$DEPLOY_IOS" = true ] && stage_note "$IOS_STAGES" "archive export upload")"
echo "  • macOS build:      $([ "$DEPLOY_MACOS" = true ] && echo yes || echo no)$([ "$DEPLOY_MACOS" = true ] && stage_note "$MACOS_STAGES" "archive export upload")"
echo "  • Android build:    $([ "$DEPLOY_ANDROID" = true ] && echo "yes (AAB → Play)" || echo no)$([ "$DEPLOY_ANDROID" = true ] && stage_note "$ANDROID_STAGES" "build upload")"
echo "  • Windows build:    $([ "$DEPLOY_WINDOWS" = true ] && echo "yes (CI → Microsoft Store)" || echo no)$([ "$DEPLOY_WINDOWS" = true ] && stage_note "$WINDOWS_STAGES" "build upload")"
echo "  • Linux build:      $([ "$DEPLOY_LINUX" = true ] && echo "yes (CI → downloads + AUR)" || echo no)$([ "$DEPLOY_LINUX" = true ] && stage_note "$LINUX_STAGES" "build upload")"
echo "  • Web build:        $([ "$DEPLOY_WEB" = true ] && echo yes || echo no)$([ "$DEPLOY_WEB" = true ] && stage_note "$WEB_STAGES" "build upload")"
echo "  • Landing/downloads:$([ "$DEPLOY_SITE" = true ] && echo " yes" || echo " no")"
SHIP_ORDER_NOTE=""
for p in $PLATFORM_ORDER; do
    flag="DEPLOY_$(printf '%s' "$p" | tr '[:lower:]' '[:upper:]')"
    [ "${!flag}" = true ] && SHIP_ORDER_NOTE="${SHIP_ORDER_NOTE:+$SHIP_ORDER_NOTE → }$p"
done
[ "$DEPLOY_SITE" = true ] && SHIP_ORDER_NOTE="${SHIP_ORDER_NOTE:+$SHIP_ORDER_NOTE → }site"
[ -n "$SHIP_ORDER_NOTE" ] && echo "  • Ship order:       $SHIP_ORDER_NOTE"
echo "  • Upload/publish:   $([ "$RUN_UPLOAD" = true ] && echo yes || echo no)"
echo "  • Git commit/push:  $([ "$RUN_GIT" = true ] && echo yes || echo no)"
echo "  • Free disk:        $([ "$FREE_SPACE" = true ] && echo "yes (each platform's build is deleted after its upload)" || echo no)"
[ "$DRY_RUN" = true ] && echo "  • Mode: DRY (no side effects)"
[ "$NEEDS_ARTIFACT_REUSE" = true ] && echo "  • Reusing build/ output from a previous run for at least one platform"
echo ""

# A stage-only run that reuses a previous run's build/ output (see NEEDS_ARTIFACT_REUSE
# above) skips the version bump and the build itself — so unlike every other
# path through this script, there is no fresh compile to catch a stale
# artifact before it goes out. --ios-upload run days after the archive it
# resumes, on a build already shipped last week, would upload that same old
# build again with nobody the wiser. Show exactly what's about to go out and
# ask, once, before any of it touches App Store Connect / Play / the VM.
# Non-interactive (CI, or stdin/tty absent) skips the prompt — there is nobody
# to answer it, and a script invoking this deliberately picked these flags.
if [ "$NEEDS_ARTIFACT_REUSE" = true ] && [ "$RUN_UPLOAD" = true ] && [ -t 0 ] && [ -e /dev/tty ]; then
    describe_artifact() {   # $1 = dir, $2 = glob
        local f
        f="$(find "$1" -maxdepth 1 -type f -name "$2" 2>/dev/null | head -n 1)"
        if [ -n "$f" ]; then
            echo "$f — built $(date -r "$f" '+%b %d, %Y %H:%M')"
        else
            echo "(none found at $1/$2 — that stage will fail with a clear error)"
        fi
    }
    echo "⚠️  This reuses existing build output instead of building fresh:"
    if [ "$DEPLOY_IOS" = true ] && ! has_stage "$IOS_STAGES" archive; then
        echo "   iOS upload:     $(describe_artifact build/ios '*.ipa')"
    fi
    if [ "$DEPLOY_MACOS" = true ] && ! has_stage "$MACOS_STAGES" archive; then
        echo "   macOS upload:   $(describe_artifact build/macos-export '*.pkg')"
    fi
    if [ "$DEPLOY_ANDROID" = true ] && ! has_stage "$ANDROID_STAGES" build; then
        echo "   Android upload: $(describe_artifact build/app/outputs/bundle/release '*.aab')"
    fi
    if [ "$DEPLOY_WEB" = true ] && ! has_stage "$WEB_STAGES" build; then
        echo "   Web upload:     build/web/ (no single file to date-check)"
    fi
    if [ "$DEPLOY_WINDOWS" = true ] && ! has_stage "$WINDOWS_STAGES" build; then
        echo "   Windows upload: $(describe_artifact build/windows-store '*.msix')"
    fi
    if [ "$DEPLOY_LINUX" = true ] && ! has_stage "$LINUX_STAGES" build; then
        echo "   Linux upload:   $(describe_artifact build/linux-release '*.tar.gz')"
    fi
    echo "   Version to be announced: $(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d+ -f1)"
    read -rp "Continue? [y/N] " confirm_reuse
    case "$confirm_reuse" in
        y|Y) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
fi

# ----- spinner helpers -----
# Restores the cursor, and undoes the version bump when a run dies partway. A
# build number that never shipped must not stay in pubspec.yaml: the next run
# bumps from whatever it finds, so a failed deploy would silently burn a version
# and leave the tree dirty. Set by the version-bump step and the git step below.
#
# SHIPPED_SOMETHING guards the case DEPLOY_COMPLETE alone used to miss: with
# several platforms in one run (iOS, macOS, Android, web), an EARLIER one can
# ship successfully and only a LATER one fails — e.g. iOS uploads and
# announces 1.3.79, then macOS blows up. DEPLOY_COMPLETE is still false there
# (the whole run didn't finish), but reverting pubspec.yaml to 1.3.78 would be
# wrong: 1.3.79 is already live on TestFlight, so the *next* run must bump
# past it, not re-mint and re-upload the same version. Once any platform's
# publish_release call fires this run, the bump is no longer reversible.
#
# Platforms are isolated from each other (see run_with_spinner below): one
# failing does not stop the rest, so DEPLOY_COMPLETE is no longer "the script
# reached the end without dying" — it's set from ANY_STEP_FAILED right before
# the git step, once every requested platform has actually been attempted.
VERSION_BUMP_APPLIED=false
PREVIOUS_VERSION=""
DEPLOY_COMPLETE=false
SHIPPED_SOMETHING=false
ANY_STEP_FAILED=false
CONVEX_STATUS="skip"
# Set by publish_release when a release row landed on one deployment but not the
# other. Not folded into ANY_STEP_FAILED: the build itself shipped, and failing
# the run would be wrong — but the summary has to say so, because the failure
# mode is a version that is live and invisible, which looks like nothing at all.
RELEASE_ROWS_INCOMPLETE=false
IOS_STATUS="skip"
MACOS_STATUS="skip"
ANDROID_STATUS="skip"
WEB_STATUS="skip"
SITE_STATUS="skip"
WINDOWS_STATUS="skip"
LINUX_STATUS="skip"
function finish {
    local rc=$?
    tput cnorm 2>/dev/null || true
    if [ $rc -ne 0 ] && [ "$VERSION_BUMP_APPLIED" = true ] && [ "$DEPLOY_COMPLETE" = false ] \
       && [ "$SHIPPED_SOMETHING" = false ]; then
        sed -i '' "s/^version: .*/version: $PREVIOUS_VERSION/" "$SCRIPT_DIR/pubspec.yaml"
        echo "  ↩︎  Reverted pubspec.yaml to $PREVIOUS_VERSION (deploy did not finish)"
    elif [ $rc -ne 0 ] && [ "$VERSION_BUMP_APPLIED" = true ] && [ "$DEPLOY_COMPLETE" = false ]; then
        echo "  ⚠️  Not reverting pubspec.yaml — at least one platform already shipped this version."
    fi
}
trap finish EXIT

spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local spinstr='|/-\'
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        for i in $(seq 0 $((${#spinstr} - 1))); do
            tput sc 2>/dev/null
            tput cup $(($(tput lines) - 1)) 0 2>/dev/null
            printf "%s %s" "${spinstr:$i:1}" "$message"
            tput rc 2>/dev/null
            sleep "$delay"
        done
    done
    tput sc 2>/dev/null
    tput cup $(($(tput lines) - 1)) 0 2>/dev/null
    printf "   %s\n" "$message"
    tput rc 2>/dev/null
    tput cnorm 2>/dev/null || true
}

# Returns the step's exit code rather than exiting the script — platforms are
# isolated (see the finish()/ANY_STEP_FAILED comment above), so a failure here
# must only stop the CALLING platform's function (via its own `|| return 1`ing
# each call site), not the whole run. Every call site is responsible for that
# guard; this just stops pretending the step succeeded.
# The Xcode DerivedData folder that belongs to [workspace] (a path relative to
# the repo), matched on the WorkspacePath Xcode records in it, so another
# project's folder (they are all called Runner-<hash>) is never touched.
derived_data_for() {   # $1 = workspace path relative to the repo
    local want="$PWD/$1" d
    for d in "$HOME"/Library/Developer/Xcode/DerivedData/Runner-*; do
        [ -f "$d/info.plist" ] || continue
        [ "$(/usr/libexec/PlistBuddy -c 'Print WorkspacePath' "$d/info.plist" 2>/dev/null)" = "$want" ] \
            && echo "$d"
    done
}

# Free what [platform]'s build left on disk, once its upload has succeeded —
# see FREE_SPACE. Every path is that platform's alone: nothing another
# platform still has to build from, and nothing the deploy still reads (the
# Android symbols are archived to build/symbols/ before this runs, and kept).
free_platform_space() {   # $1 = ios | macos | android | web | windows | linux
    [ "$FREE_SPACE" = true ] || return 0
    local paths=() name
    case "$1" in
        ios)
            paths=(build/ios build/Runner.xcarchive)
            while IFS= read -r name; do [ -n "$name" ] && paths+=("$name"); done \
                < <(derived_data_for ios/Runner.xcworkspace) ;;
        macos)
            paths=(build/macos build/macos-export build/Runner-macOS.xcarchive)
            while IFS= read -r name; do [ -n "$name" ] && paths+=("$name"); done \
                < <(derived_data_for macos/Runner.xcworkspace) ;;
        android)
            # Gradle builds the app and every plugin into build/<project name>
            # (android/build.gradle.kts). The plugin names come from Flutter's
            # own list rather than a pattern, so build/ios and friends can
            # never match.
            paths=(build/app)
            if [ -f .flutter-plugins-dependencies ]; then
                while IFS= read -r name; do
                    case "$name" in ""|ios|macos|web|symbols|app) continue ;; esac
                    paths+=("build/$name")
                done < <(jq -r '.plugins.android[]?.name' .flutter-plugins-dependencies 2>/dev/null)
            fi ;;
        web)
            paths=(build/web) ;;
        windows)
            paths=(build/windows-store) ;;
        linux)
            paths=(build/linux-release build/aur) ;;
        *) return 0 ;;
    esac
    local existing=() p kb=0
    for p in "${paths[@]}"; do
        [ -e "$p" ] || continue
        existing+=("$p")
        kb=$((kb + $(du -sk "$p" 2>/dev/null | cut -f1)))
    done
    [ ${#existing[@]} -gt 0 ] || return 0
    rm -rf "${existing[@]}"
    echo "  🧹 Freed $(awk -v k="$kb" 'BEGIN { if (k >= 1048576) printf "%.1f GB", k/1048576; else printf "%d MB", k/1024 }') ($1 build output; $(df -h / | awk 'NR==2 { print $4 }') free now)"
}

run_with_spinner() {
    local description="$1"
    shift
    echo "$description..."
    "$@" &
    local pid=$!
    spinner "$pid" "$description"
    wait "$pid"
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "  ✅ $description"
    else
        echo "  ❌ $description failed (exit $exit_code)"
    fi
    return $exit_code
}

# Load a dotenv file into the environment without running values through bash
# command interpretation. `source .env.local` chokes on values containing
# unquoted '|', '&', ';', '$()' etc. — common in keys/secrets. This loader:
#   - skips blanks and # comments
#   - strips matched surrounding "..." or '...'
#   - expands $VAR / ${VAR} / ${VAR:-default} (so $HOME paths still work)
#   - neutralizes command substitution and backticks
load_env_file() {
    local file="$1"
    [ -f "$file" ] || return 1
    local line key value stripped first last safe
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        stripped="${line#"${line%%[![:space:]]*}"}"
        [ -z "$stripped" ] && continue
        [ "${stripped:0:1}" = "#" ] && continue
        [[ "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        key="${key//[[:space:]]/}"
        key="${key#export}"
        [ -z "$key" ] && continue
        if [ ${#value} -ge 2 ]; then
            first="${value:0:1}"
            last="${value: -1}"
            if { [ "$first" = '"' ] && [ "$last" = '"' ]; } || \
               { [ "$first" = "'" ] && [ "$last" = "'" ]; }; then
                value="${value:1:${#value}-2}"
            fi
        fi
        safe="${value//\\/\\\\}"
        safe="${safe//\"/\\\"}"
        safe="${safe//\`/\\\`}"
        safe="${safe//\$(/\\\$(}"
        eval "value=\"$safe\""
        export "$key=$value"
    done < "$file"
}

# Auto-create a sensible ExportOptions.plist on first run. signingStyle=automatic
# + -allowProvisioningUpdates lets Xcode resolve the team/profile via the API
# key, so no hard-coded teamID is needed here.
ensure_export_options() {
    local plist="ios/ExportOptions.plist"
    if [ -f "$plist" ]; then
        return 0
    fi
    echo "  • Generating $plist (first run)"
    cat > "$plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST
}

# Same idea as ensure_export_options, for the macOS archive. method=app-store
# exports a signed .pkg — the format ASC accepts for both TestFlight and Mac
# App Store review, same as one .ipa serves both on iOS.
ensure_macos_export_options() {
    local plist="macos/ExportOptions.plist"
    if [ -f "$plist" ]; then
        return 0
    fi
    echo "  • Generating $plist (first run)"
    cat > "$plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST
}

# CocoaPods install with three escalating attempts (see the iOS build section
# below for why each level exists). Shared by iOS and macOS — both ship a
# Podfile and hit the same failure modes. $1 = platform dir (ios|macos).
pod_install_with_retries() {
    local dir="$1"
    local log_base="/tmp/monkeyhub_pod_${dir}"
    local status=0
    _pod_install_attempt() {
        local log="$1"; shift
        (cd "$dir" && pod install "$@") >"$log" 2>&1
    }
    if ! _pod_install_attempt "${log_base}_install.log"; then
        echo "  ⚠️  pod install failed, retrying with --repo-update..."
        if ! _pod_install_attempt "${log_base}_repo_update.log" --repo-update; then
            echo "  ⚠️  still failing — discarding $dir/Podfile.lock and re-resolving..."
            rm -f "$dir/Podfile.lock"
            _pod_install_attempt "${log_base}_retry.log" --repo-update || status=1
        fi
    fi
    if [ $status -ne 0 ]; then
        echo "❌ CocoaPods install failed ($dir). Logs:"
        echo "   ${log_base}_install.log"
        echo "   ${log_base}_repo_update.log"
        echo "   ${log_base}_retry.log"
        echo "   $dir/Podfile.lock was removed — 'cd $dir && pod install' to rebuild it."
        return 1
    fi
    echo "  ✅ Pods installed ($dir)"
}

# ----- environment validation -----
validate_environment() {
    echo "🔐 Validating environment..."

    if { [ "$DEPLOY_IOS" = true ] || [ "$DEPLOY_MACOS" = true ]; } && [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ The iOS/macOS pipelines need macOS (xcodebuild). Deselect them or run on a Mac."
        exit 1
    fi

    # Runtime app config — bundled into the app. Builds silently miss
    # CONVEX_URL / VAPID_PUBLIC_KEY if this is absent.
    if { [ "$DEPLOY_IOS" = true ] || [ "$DEPLOY_MACOS" = true ] || [ "$DEPLOY_ANDROID" = true ] \
         || [ "$DEPLOY_WINDOWS" = true ] || [ "$DEPLOY_LINUX" = true ]; } \
       && [ ! -f "env.local" ]; then
        echo "❌ Missing env.local at project root (runtime app secrets)."
        echo "   Copy env.example to env.local and fill in values."
        exit 1
    fi

    # Deploy-only secrets — NOT bundled. Note the leading dot. Required for
    # iOS (ASC key); optional for Android (PLAY_SERVICE_ACCOUNT_JSON).
    [ -f ".env.local" ] && load_env_file .env.local

    check_key() {
        local key_name=$1
        local key_value=${!key_name:-}
        if [ -z "$key_value" ]; then
            echo "❌ Missing $key_name in .env.local"
            exit 1
        fi
        if [[ "$key_value" == *"replace-with-"* ]] || [[ "$key_value" == *"your_"*"_here"* ]]; then
            echo "❌ $key_name still has a placeholder value in .env.local"
            exit 1
        fi
    }

    if [ "$RUN_CONVEX" = true ]; then
        # Convex deploy reads its creds from backend/.env.local (not the root
        # deploy file).
        if [ ! -f "backend/.env.local" ]; then
            echo "❌ Missing backend/.env.local (Convex deploy creds)."
            echo "   Expected CONVEX_SELF_HOSTED_URL and CONVEX_SELF_HOSTED_ADMIN_KEY."
            exit 1
        fi
        if [ ! -f "backend/package.json" ]; then
            echo "❌ Missing backend/package.json — can't run 'npx convex deploy'."
            exit 1
        fi
    fi

    if [ "$DEPLOY_IOS" = true ] || [ "$DEPLOY_MACOS" = true ]; then
        if [ ! -f ".env.local" ]; then
            echo "❌ Missing .env.local at project root (deploy secrets)."
            echo "   Create it with:"
            echo "     APP_STORE_CONNECT_KEY_ID=<10-char key id>"
            echo "     APP_STORE_CONNECT_ISSUER_ID=<uuid>"
            echo "   ⚠️  Note the leading dot — .env.local (deploy) is distinct from"
            echo "       env.local (runtime, bundled into the IPA)."
            exit 1
        fi
        # ASC creds are needed for BOTH archive/export (xcodebuild auth) AND
        # the upload step, so validate even with --no-upload. iOS and macOS
        # share the same key — one Apple Developer team, one App Store
        # Connect account.
        check_key APP_STORE_CONNECT_KEY_ID
        check_key APP_STORE_CONNECT_ISSUER_ID

        local key_dir="${APP_STORE_CONNECT_KEY_DIR:-$HOME/.appstoreconnect/private_keys}"
        P8_FILE_PATH="$key_dir/AuthKey_$APP_STORE_CONNECT_KEY_ID.p8"
        if [ ! -f "$P8_FILE_PATH" ]; then
            echo "❌ App Store Connect API key not found at:"
            echo "   $P8_FILE_PATH"
            echo "   Download the .p8 from App Store Connect → Users and Access → Keys"
            echo "   and place it there, or set APP_STORE_CONNECT_KEY_DIR in .env.local."
            exit 1
        fi
        [ "$DEPLOY_IOS" = true ] && ensure_export_options
        [ "$DEPLOY_MACOS" = true ] && ensure_macos_export_options
    fi

    if [ "$DEPLOY_ANDROID" = true ]; then
        # Upload keystore — release builds fall back to DEBUG signing without
        # it, which must never ship. Wired via android/key.properties.
        if [ ! -f "android/key.properties" ]; then
            echo "❌ Missing android/key.properties (upload-key config)."
            echo "   Expected keys: storeFile / storePassword / keyAlias / keyPassword"
            echo "   pointing at the keystore (e.g. ~/keystores/monkeyhub_upload.jks)."
            echo "   See DEPLOY.md → 'Android signing'."
            exit 1
        fi
        local store_file
        store_file=$(grep '^storeFile=' android/key.properties | cut -d= -f2-)
        if [ -z "$store_file" ] || [ ! -f "$store_file" ]; then
            echo "❌ Keystore not found: '${store_file:-<unset>}' (from android/key.properties)."
            exit 1
        fi

        # Play upload key — checked here rather than after the build, so a bad
        # path fails in seconds instead of after a full AAB compile.
        if [ "$RUN_UPLOAD" = true ] \
           && [ -n "${PLAY_SERVICE_ACCOUNT_JSON:-}" ] && [ ! -f "$PLAY_SERVICE_ACCOUNT_JSON" ]; then
            echo "❌ Play key not found: '$PLAY_SERVICE_ACCOUNT_JSON'"
            echo "   (from PLAY_SERVICE_ACCOUNT_JSON in .env.local)."
            echo "   Unset it to build the AAB and upload by hand instead."
            exit 1
        fi

        # fastlane is the other half of automated upload — checked here too so
        # a missing install fails in seconds instead of silently falling back
        # to "upload manually" after a full AAB compile.
        if [ "$RUN_UPLOAD" = true ] \
           && [ -n "${PLAY_SERVICE_ACCOUNT_JSON:-}" ] && ! command -v fastlane >/dev/null 2>&1; then
            echo "❌ fastlane not found — needed for automated Play upload."
            echo "   Install it: brew install fastlane   (or: sudo gem install fastlane)"
            echo "   Unset PLAY_SERVICE_ACCOUNT_JSON to build the AAB and upload by hand instead."
            exit 1
        fi

        # publish_release builds its JSON with jq, and the Android path is the
        # one that passes prose ($APK_MIGRATION_NOTE) through it. Finding this
        # out after a full AAB build would be a bad joke.
        if [ "$RUN_UPLOAD" = true ] && ! command -v jq >/dev/null 2>&1; then
            echo "❌ jq not found — needed to build the release-announcement payload."
            echo "   brew install jq"
            exit 1
        fi
    fi

    # Windows/Linux: the build is a GitHub Actions run, so gh has to be logged
    # in and able to see this repo. Checked now, not after iOS has spent 15
    # minutes archiving.
    if [ "$DEPLOY_WINDOWS" = true ] || [ "$DEPLOY_LINUX" = true ]; then
        if ! command -v gh >/dev/null 2>&1; then
            echo "❌ gh not found — Windows/Linux build on GitHub Actions."
            echo "   brew install gh && gh auth login"
            exit 1
        fi
        if ! gh auth status >/dev/null 2>&1; then
            echo "❌ gh is not logged in. Run: gh auth login"
            exit 1
        fi
        if ! command -v jq >/dev/null 2>&1; then
            echo "❌ jq not found — needed to read the CI run. brew install jq"
            exit 1
        fi
    fi
    # The Store upload is optional — without it the MSIX is handed over for a
    # manual Partner Center upload, same as the AAB before Play was automated.
    # But a half-configured setup should fail now, not after the build.
    if [ "$DEPLOY_WINDOWS" = true ] && [ "$RUN_UPLOAD" = true ] && [ -n "${MS_STORE_CLIENT_ID:-}" ]; then
        check_key MS_STORE_TENANT_ID
        check_key MS_STORE_SELLER_ID
        check_key MS_STORE_CLIENT_SECRET
        if ! command -v msstore >/dev/null 2>&1; then
            echo "❌ msstore not found — needed for the automated Microsoft Store upload."
            echo "   brew install microsoft/msstore-cli/msstore-cli"
            echo "   (needs the .NET 9 runtime), or unset MS_STORE_CLIENT_ID to upload"
            echo "   the MSIX by hand."
            exit 1
        fi
    fi

    # The page templates are needed by every VM-publishing path, not just
    # Android — the landing page now ships on its own.
    if [ "$DEPLOY_SITE" = true ]; then
        local missing="" f
        for f in hosting/site.template.html hosting/downloads.template.html; do
            [ -f "$f" ] || missing="$missing\n   $f"
        done
        if [ -n "$missing" ]; then
            echo "❌ Page templates missing:"
            printf "%b\n" "$missing"
            exit 1
        fi
        # render_downloads() merges the per-platform manifest with jq. Finding
        # this out after a 15-minute build would be a bad joke.
        if ! command -v jq >/dev/null 2>&1; then
            echo "❌ jq not found — needed to merge $DL_MANIFEST."
            echo "   brew install jq"
            exit 1
        fi
    fi

    # The VM serves the pages and the web build — prove it's reachable BEFORE
    # burning 15 minutes on a build we then can't publish. Android is not in
    # here: it goes to Play and never touches the VM.
    if [ "$DEPLOY_WEB" = true ] || [ "$DEPLOY_SITE" = true ] || [ "$DEPLOY_LINUX" = true ]; then
        if [ "$RUN_UPLOAD" = true ]; then
            require_vm
        fi
    fi

    echo "  ✅ Environment OK"
}

validate_environment

# ----- Convex deploy -----
# IMPORTANT: must run from backend/ — MonkeyHub's convex/ lives there.
# Isolated like every platform below (see run_with_spinner): a failed backend
# push does not stop the app builds that follow — they would just run against
# whatever backend is already live — but it still marks the run as failed
# overall via ANY_STEP_FAILED.
run_convex() {
    # Retried, because this step fails transiently and would otherwise take
    # every platform in the run down with it.
    #
    # The observed failure is the backend answering evaluate_push with
    # "Function execution timed out (maximum duration: 1s)" plus a Node TLS
    # "self-signed certificate", on a push that succeeds unchanged seconds
    # later. Module evaluation has a hard 1s budget, and this deployment now
    # has a `use node` module (backend/convex/webPush.ts — Web Push needs ECDH,
    # which the V8 isolate lacks), so a cold Node runner can blow it.
    #
    # Deliberately NOT retried forever: three attempts distinguishes a blip
    # from a genuine schema or type error, which no amount of retrying fixes.
    # Typecheck BEFORE the push, as its own step.
    #
    # `convex deploy` runs its own typecheck, but its default is "try": with no
    # tsconfig and no local `typescript`, it skips — silently, with a zero exit
    # — and this deployment had neither for its whole life. A deploy was
    # therefore the first thing that ever looked at these types, and on a
    # single self-hosted deployment that means production is the test.
    #
    # Both are now real (`backend/convex/tsconfig.json`, `typescript` in
    # devDependencies), so this is belt and braces — but it is the half that
    # fails FAST and says which file, instead of surfacing as a push that
    # bundles and then dies during module evaluation.
    #
    # Skipped rather than failed when `node_modules` is absent: a checkout that
    # has not run `npm install` is not a broken build, and `convex deploy`
    # below will install what it needs anyway.
    convex_typecheck() {
        if [ ! -x backend/node_modules/.bin/tsc ]; then
            echo "   (no backend/node_modules — skipping typecheck; convex deploy will still run its own)" >&2
            return 0
        fi
        (cd backend && npm run --silent typecheck)
    }
    run_with_spinner "Typechecking Convex functions" convex_typecheck || return 1

    # One push to whatever deployment the environment currently points at,
    # retried. $1 only names the target for the log.
    convex_push() {
        local label="$1" attempt=1
        while true; do
            if (cd backend && npx convex deploy); then
                return 0
            fi
            if [ "$attempt" -ge 3 ]; then
                echo "   convex deploy to $label failed $attempt times — not transient." >&2
                return 1
            fi
            echo "   convex deploy to $label attempt $attempt failed; retrying in 10s…" >&2
            attempt=$((attempt + 1))
            sleep 10
        done
    }

    # The VPS: the default target, straight out of backend/.env.local. Nothing
    # to override, which is what keeps this the one that cannot be misaddressed.
    convex_deploy() { convex_push "the VPS"; }

    # The home server. Its admin key is minted over SSH per run and never
    # written to disk — there is no source checkout on that box and there does
    # not need to be. (Since the migration its data is a byte-copy of the VPS's,
    # so the two instances share a secret and the VPS key would in fact work
    # here; minting anyway is what keeps this correct if they ever diverge.)
    #
    # A subshell with real exports, not `VAR=x func`: bash leaves the latter's
    # assignments visible after the call for a function, and a stray
    # CONVEX_SELF_HOSTED_URL pointing at the home server is exactly the kind of
    # thing that makes the NEXT deploy in this script go somewhere surprising.
    convex_deploy_homeserver() {
        if ! homeserver_admin_key; then
            echo "   Could not mint an admin key on $HOMESERVER_SSH." >&2
            echo "   Is the box up and Tailscale connected? Re-run with --no-homeserver" >&2
            echo "   to push to the VPS alone and accept the drift." >&2
            return 1
        fi
        (
            export CONVEX_SELF_HOSTED_URL="$HOMESERVER_URL"
            export CONVEX_SELF_HOSTED_ADMIN_KEY="$HOMESERVER_KEY"
            convex_push "the home server"
        )
    }

    # Order is deliberate: the VPS (primary, serving traffic) first, the home
    # server (standby) second. The standby is the one that is often
    # unreachable (Tailscale down on this Mac), and `|| return 1` below means a
    # failure there must never be what stops the primary from getting the push.
    run_with_spinner "Deploying Convex backend → VPS" convex_deploy || return 1
    if [ "$RUN_HOMESERVER" = true ]; then
        # Minted out here, in the main shell, rather than inside the spinner:
        # run_with_spinner backgrounds what it runs, so a key minted in there
        # dies with the subshell and every later publish_release would SSH for
        # its own copy. Failure is not handled here — convex_deploy_homeserver
        # asks again, gets the cached miss, and prints the advice.
        homeserver_admin_key || true
        run_with_spinner "Deploying Convex backend → home server" convex_deploy_homeserver || return 1
    else
        echo "  ⚠️  --no-homeserver: the home server keeps its current functions." >&2
    fi
    return 0
}
if [ "$RUN_CONVEX" = true ]; then
    if run_convex; then
        CONVEX_STATUS="ok"
    else
        CONVEX_STATUS="failed"
        ANY_STEP_FAILED=true
        echo "  ⚠️  Convex deploy failed — continuing with the rest of the run."
    fi
fi

# ----- Android crash-symbol archive -----
# Release Android builds are minified and obfuscated (the Flutter Gradle plugin
# turns R8 on for release; android/app/build.gradle.kts never says so, which is
# why this is easy to miss). Every build overwrites mapping.txt, so without this
# a crash report from a shipped build is permanently unreadable — the position
# we were in when calls started crashing on 1.3.41.
#
# Play deobfuscates its own crash reports from the mapping the AAB carries, but
# this local copy is what makes a stack trace mailed in by a tester (or pulled
# off a handset with adb) readable too.
#
# Kept OUT of hosting/public: these are build artifacts for our own diagnosis,
# and the downloads directory is served to the internet.
#
# Retrace a trace later with:
#   $ANDROID_HOME/cmdline-tools/latest/bin/retrace \
#       build/symbols/<version>/mapping.txt crash.txt
archive_android_symbols() {   # $1 = version
    local version="$1"
    local dest="build/symbols/$version"
    local mapping="build/app/outputs/mapping/release/mapping.txt"
    local natives="build/app/outputs/native-debug-symbols/release/native-debug-symbols.zip"
    [ -f "$mapping" ] || [ -f "$natives" ] || return 0
    mkdir -p "$dest"
    [ -f "$mapping" ] && cp "$mapping" "$dest/mapping.txt"
    [ -f "$natives" ] && cp "$natives" "$dest/native-debug-symbols.zip"
    echo "  • Archived crash symbols → $dest"
}

# ----- Release announcement -----
# Records "the latest build on <channel> is <version>" so already-installed
# clients learn they're behind (see lib/update/ and backend/convex/releases.ts).
#
# Called per channel AFTER that channel's upload succeeds — announcing a version
# whose upload then failed would send every user to a store that doesn't have it.
#
# Two deliberate departures from the rest of this script:
#   • Not run_with_spinner. That exits the script on failure, which here would
#     abandon an already-uploaded build before the version-bump commit. A failed
#     announcement is recoverable; the retry command is printed.
#   • `convex run` reaches an internalMutation because the CLI carries admin
#     credentials — which is the point, since a *public* publish endpoint would
#     let anyone fake a mandatory-update prompt for every user.
#
# No --prod, deliberately: this backend is self-hosted, so there is no
# prod/dev pair to choose between — --prod is a Convex-cloud concept and adding
# it would break this call, not harden it. There ARE two deployments, which is a
# different axis entirely: convex_run_both writes the row to the VPS and the
# home server, because the CLI's default target (backend/.env.local) is only
# the VPS, and a release announced on the primary alone is gone the moment
# traffic flips to the standby.
#
# $2 (updateUrl) and $3 (notes) are optional; omitting either leaves whatever is
# already stored, so a hand-set store link or minSupported survives the next
# deploy. That is releases:publish's "undefined → leave as-is" contract, and it
# is why the payload below omits keys rather than sending empty strings.
#
# jq builds the JSON rather than string interpolation: $3 is prose written for
# humans (see APK_MIGRATION_NOTE), and one apostrophe or quote in it would
# otherwise produce a payload the CLI rejects — or, worse, a valid one that says
# something else.
publish_release() {   # $1 = channel, $2 = updateUrl (optional), $3 = notes (optional)
    local channel="$1"
    local update_url="${2:-}"
    local notes="${3:-}"
    # Deliberately NOT gated on --no-convex. That flag means "don't push backend
    # code", not "don't record what shipped" — and the retry line this script
    # prints after a failed upload recommends --no-convex, which is exactly when
    # a silent skip would hurt. Every call site already sits inside a
    # RUN_UPLOAD=true branch, so --no-upload and --dry never reach here.
    local payload
    payload=$(jq -nc \
        --arg channel "$channel" \
        --arg version "$DISPLAY_VERSION" \
        --arg updateUrl "$update_url" \
        --arg notes "$notes" \
        '{channel: $channel, version: $version}
         + (if $updateUrl == "" then {} else {updateUrl: $updateUrl} end)
         + (if $notes == "" then {} else {notes: $notes} end)')
    if convex_run_both releases:publish "$payload"; then
        echo "  ✅ Announced $DISPLAY_VERSION on $channel"
    else
        # The retry lines are meant to be copy-pasted, and $payload can contain
        # an apostrophe (APK_MIGRATION_NOTE has two), which would close the
        # shell's single-quoted string early and paste as something that doesn't
        # run. jq's @sh emits the argument already correctly quoted for a shell —
        # surrounding quotes included, hence no '…' around it below.
        local quoted
        quoted=$(printf '%s' "$payload" | jq -Rr @sh)
        # Named per box rather than "failed": a home-server miss is a standby
        # the next --sync-releases squares up, while a VPS miss is the one where
        # the build ships and nobody is told about it.
        echo "  ⚠️  Could not announce $DISPLAY_VERSION on $channel — $CONVEX_RUN_FAILED did not take it."
        case "$CONVEX_RUN_FAILED" in
            *VPS*) echo "     Clients read the VPS, so nobody will be prompted to update." ;;
            *"home server"*) echo "     Clients read the VPS, so they are told; the standby catches up with --sync-releases." ;;
        esac
        echo "     Retry with:"
        convex_retry_hint releases:publish "$quoted"
        RELEASE_ROWS_INCOMPLETE=true
    fi
}

# ----- TestFlight: announce when Apple has processed the build -----
# altool returning means Apple RECEIVED the upload, not that testers can
# install it: processing takes 5-30 minutes, and until it's done TestFlight has
# nothing to offer, so a row published at upload time sends testers to an empty
# Update button. So the upload's delivery ID goes to `altool --build-status
# --wait` in the background (the rest of the run carries on), and the row is
# published when Apple says the build is processed. await_testflight_processing,
# after the platform loop, collects the result.
#
# No delivery ID in the upload output (an altool that prints a different shape)
# falls back to the old behaviour, announced at once, and says so.
TESTFLIGHT_WAITS=""          # space-separated "channel|pid|logfile"
TESTFLIGHT_UNANNOUNCED=""    # channels whose processing never confirmed
TESTFLIGHT_WAIT_LIMIT=3600   # seconds; Apple calls >24h stuck, an hour is plenty

asc_upload() {   # $1 = ios|macos, $2 = file, $3 = log
    xcrun altool --upload-app \
        --type "$1" \
        --file "$2" \
        --apiKey "$APP_STORE_CONNECT_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
        --apiKeyPath "$P8_FILE_PATH" >"$3" 2>&1
}

announce_when_processed() {   # $1 = channel, $2 = upload log
    local channel="$1" log="$2" uuid delivery out
    uuid='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
    # Any text between the label and the id ("Delivery UUID: ..." has a hex
    # D in it, so a no-hex gap never matched).
    delivery=$(grep -ioE "delivery.{0,40}$uuid" "$log" 2>/dev/null \
        | grep -oE "$uuid" | head -n 1)
    if [ -z "$delivery" ]; then
        echo "  ⚠️  No delivery ID in the upload output ($log)."
        echo "     Announcing $channel now, before Apple finishes processing."
        publish_release "$channel"
        return 0
    fi
    out="/tmp/monkeyhub_${channel}_processing.log"
    rm -f "$out" "$out.rc"
    (
        xcrun altool --build-status --delivery-id "$delivery" --wait \
            --apiKey "$APP_STORE_CONNECT_KEY_ID" \
            --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
            --apiKeyPath "$P8_FILE_PATH" >"$out" 2>&1 &
        local apid=$!
        ( sleep "$TESTFLIGHT_WAIT_LIMIT"; kill "$apid" 2>/dev/null ) &
        local kpid=$!
        wait "$apid"
        echo $? >"$out.rc"
        kill "$kpid" 2>/dev/null
    ) &
    TESTFLIGHT_WAITS="$TESTFLIGHT_WAITS $channel|$!|$out"
    echo "  ⏳ $channel: announced once Apple finishes processing (delivery $delivery)"
}

await_testflight_processing() {
    [ -n "$TESTFLIGHT_WAITS" ] || return 0
    local entry channel pid out rc
    for entry in $TESTFLIGHT_WAITS; do
        IFS='|' read -r channel pid out <<<"$entry"
        if kill -0 "$pid" 2>/dev/null; then
            echo "⏳ Waiting for Apple to process the $channel build..."
            spinner "$pid" "Apple is processing the $channel build"
        fi
        wait "$pid" 2>/dev/null
        rc=$(cat "$out.rc" 2>/dev/null || echo 1)
        # Exit 0 alone isn't enough: altool has reported a failed processing
        # state with a clean exit before. Any FAILED/INVALID/ERROR line vetoes.
        if [ "$rc" = 0 ] && ! grep -qE 'FAILED|INVALID|ERROR' "$out"; then
            echo "  ✅ $channel: processed, testers can install it"
            publish_release "$channel"
        else
            echo "  ⚠️  $channel: Apple's processing didn't confirm (exit $rc). Log: $out"
            echo "     Not announced. Once TestFlight shows the build, announce it with:"
            echo "       (cd backend && npx convex run releases:publish '{\"channel\":\"$channel\",\"version\":\"$DISPLAY_VERSION\"}')"
            echo "       ./deploy.sh --sync-releases"
            TESTFLIGHT_UNANNOUNCED="$TESTFLIGHT_UNANNOUNCED $channel"
        fi
    done
}

# ----- the static pages -----
# Two pages, one visual language, both generated from templates in hosting/:
#   site.template.html      → /srv/monkeyhub/site      → the front door
#   downloads.template.html → /srv/monkeyhub/downloads → every platform
#
# The downloads page is driven by artifacts.json ON THE VM rather than by this
# script's variables, and that is the whole point: a deploy only knows about the
# platform it just built. Rendering from local state would mean shipping Android
# silently deleting the macOS row. Instead each deploy merges its own key into
# whatever is already there.

# Presentation per platform. The manifest carries facts (version, file, size,
# date); this carries how they are shown. New platform = one line here.
#
# linux has its own fixed card (with the AUR line) and android-apk is retired,
# so render_downloads() never asks about either.
platform_meta() {   # $1 = platform key → sets PM_ICON / PM_NAME / PM_KIND / PM_BTN
    case "$1" in
        macos-dmg)   PM_ICON="💻"; PM_NAME="Mac (direct download)"; PM_KIND="DMG"
                     PM_BTN="Download the DMG" ;;
        windows)     PM_ICON="🪟"; PM_NAME="Windows (direct download)"; PM_KIND="Installer"
                     PM_BTN="Download for Windows" ;;
        *)           PM_ICON="📦"; PM_NAME="$1";      PM_KIND="File"
                     PM_BTN="Download" ;;
    esac
}

# Whatever the VM currently says has shipped. An absent or hand-mangled file
# degrades to "nothing yet" rather than taking the deploy down with it.
dl_manifest_fetch() {
    local raw
    raw=$(vm_ssh "cat $DL_MANIFEST 2>/dev/null" 2>/dev/null)
    if [ -n "$raw" ] && printf '%s' "$raw" | jq -e 'type == "object"' >/dev/null 2>&1; then
        printf '%s' "$raw"
    else
        echo '{}'
    fi
}

vm_ensure_dirs() { vm_ssh "mkdir -p $VM_SITE_DIR $VM_DL_DIR $VM_WEB_DIR"; }

# Each template opens with a note to whoever edits it next, explaining the token
# names and this script's half of the bargain. Useful in the repo, no business
# being downloaded by every visitor — so everything from MH:DOC to the end of
# that comment is cut on the way out.
strip_doc() { awk '/<!-- MH:DOC/ {d=1} d { if (/-->/) d=0; next } {print}'; }

# Fill the template from the manifest: the Linux card's tokens (or drop its
# MH:LINUX-DL blocks when nothing has shipped), then the MH:CARD block once per
# remaining entry (or not at all). Every other card is fixed in the template.
render_downloads() {   # $1 = manifest file, $2 = output html
    local manifest="$1" out="$2"
    local tpl="hosting/downloads.template.html"
    local cards="" key card ver file size updated meta tmp_cards page
    local lx_file lx_ver lx_meta

    for key in $(jq -r 'keys[]' "$manifest"); do
        case "$key" in linux|android-apk) continue ;; esac
        file=$(jq -r --arg k "$key" '.[$k].file // ""' "$manifest")
        [ -n "$file" ] || continue
        ver=$(jq -r --arg k "$key" '.[$k].version // "?"' "$manifest")
        size=$(jq -r --arg k "$key" '.[$k].size // "?"' "$manifest")
        updated=$(jq -r --arg k "$key" '.[$k].updatedAt // "?"' "$manifest")
        platform_meta "$key"
        meta="$PM_KIND · $size · updated $updated"

        card=$(awk '/<!-- MH:CARD -->/{f=1;next} /<!-- MH:\/CARD -->/{f=0} f' "$tpl")
        # Parameter expansion, not sed: filenames and labels never have to be
        # escaped for a regex they were never meant to be part of.
        card=${card//__PLAT_KEY__/$key}
        card=${card//__PLAT_ICON__/$PM_ICON}
        card=${card//__PLAT_NAME__/$PM_NAME}
        card=${card//__PLAT_VERSION__/$ver}
        card=${card//__PLAT_HREF__/$file}
        card=${card//__PLAT_BTN__/$PM_BTN}
        card=${card//__PLAT_META__/$meta}
        cards="$cards$card"$'\n'
    done

    tmp_cards=$(mktemp)
    printf '%s' "$cards" > "$tmp_cards"

    # Swap the MH:CARD block for the rendered cards (possibly none).
    page=$(awk -v cardfile="$tmp_cards" '
        /<!-- MH:CARD -->/     { skip=1
                                 while ((getline line < cardfile) > 0) print line
                                 close(cardfile); next }
        /<!-- MH:\/CARD -->/   { skip=0; next }
        !skip                  { print }
    ' "$tpl")
    rm -f "$tmp_cards"

    lx_file=$(jq -r '.linux.file // ""' "$manifest")
    if [ -n "$lx_file" ]; then
        lx_ver=$(jq -r '.linux.version // "?"' "$manifest")
        lx_meta="tar.gz · $(jq -r '.linux.size // "?"' "$manifest") · updated $(jq -r '.linux.updatedAt // "?"' "$manifest")"
        page=$(printf '%s\n' "$page" | grep -v 'MH:/\{0,1\}LINUX-DL')
        page=${page//__LINUX_HREF__/$lx_file}
        page=${page//__LINUX_VERSION__/$lx_ver}
        page=${page//__LINUX_META__/$lx_meta}
    else
        page=$(printf '%s\n' "$page" | awk '/<!-- MH:LINUX-DL -->/{d=1;next} /<!-- MH:\/LINUX-DL -->/{d=0;next} !d')
    fi

    # The yay line only once the AUR package really exists. Asked at stamp
    # time; no answer (offline, timeout, bad JSON) counts as "not there".
    local aur_count
    aur_count=$(curl -fsS --max-time 8 'https://aur.archlinux.org/rpc/v5/info?arg[]=monkeyhub-bin' 2>/dev/null \
        | jq -r '.resultcount // 0' 2>/dev/null)
    if [ "${aur_count:-0}" -gt 0 ] 2>/dev/null; then
        page=$(printf '%s\n' "$page" | awk '/<!-- MH:NOAUR -->/{d=1;next} /<!-- MH:\/NOAUR -->/{d=0;next} !d' | grep -v 'MH:/\{0,1\}AUR -->')
    else
        page=$(printf '%s\n' "$page" | awk '/<!-- MH:AUR -->/{d=1;next} /<!-- MH:\/AUR -->/{d=0;next} !d' | grep -v 'MH:/\{0,1\}NOAUR -->')
    fi

    printf '%s\n' "$page" | sed -e "s/__UPDATED_AT__/$STAMP_DATE/g" | strip_doc > "$out"
}

# Stage and push both pages. Seconds, no build — which is why every VM-touching
# deploy can afford to run it and keep the printed version honest.
deploy_site() {
    echo "🏠 Publishing landing + downloads pages..."
    rm -rf hosting/public/site
    mkdir -p hosting/public/site hosting/public/downloads

    sed -e "s/__APP_VERSION__/$DISPLAY_VERSION/g" \
        -e "s/__UPDATED_AT__/$STAMP_DATE/g" \
        hosting/site.template.html | strip_doc > hosting/public/site/index.html
    # The invite page. One document for every code — Caddy rewrites every path
    # under /j/ to it (see the `handle /j/*` block) and the page reads the code
    # out of its own URL. No placeholders to substitute; it goes through
    # strip_doc for the same reason the others do, so the MH:DOC block
    # explaining why this page never names the room stays out of the browser.
    strip_doc < hosting/invite.template.html > hosting/public/site/j.html
    # robots.txt, the service-worker tombstone, the self-hosted webfonts and
    # the two app-association files are served from the site root alongside the
    # page — see hosting/static/flutter_service_worker.js, hosting/static/fonts/
    # and hosting/static/.well-known/.
    #
    # `-R … /.` rather than `*`: the fonts live in a subdirectory, `.well-known`
    # is a DOTFILE directory that a `*` glob would skip entirely — silently
    # breaking every universal link on the next deploy — and plain cp skips
    # directories with a non-zero exit that would abort the deploy.
    cp -R hosting/static/. hosting/public/site/

    if [ "$RUN_UPLOAD" = false ]; then
        echo "⏭️  Skipping page upload (--no-upload). Staged in hosting/public/site/."
        return 0
    fi

    vm_ensure_dirs || { echo "❌ Could not create the site directories on $VM_HOST."; return 1; }

    # Render from what the VM says shipped, INCLUDING anything this run just
    # added a moment ago (the Android block writes the manifest before we run).
    dl_manifest_fetch > hosting/public/downloads/artifacts.json
    render_downloads hosting/public/downloads/artifacts.json hosting/public/downloads/index.html

    if ! rsync -a --delete -e "ssh $VM_SSH_OPTS" \
            hosting/public/site/ "$VM_USER@$VM_HOST:$VM_SITE_DIR/"; then
        echo "❌ Landing page upload to $VM_USER@$VM_HOST failed."
        return 1
    fi
    # No --delete here: the artifacts themselves live in this directory.
    if ! rsync -a -e "ssh $VM_SSH_OPTS" \
            hosting/public/downloads/index.html \
            "$VM_USER@$VM_HOST:$VM_DL_DIR/"; then
        echo "❌ Downloads page upload to $VM_USER@$VM_HOST failed."
        return 1
    fi
    echo "  ✅ $SITE_URL  and  $HOSTING_URL/"
}

# Nothing app-side selected → done after Convex.
if [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_MACOS" = false ] && [ "$DEPLOY_ANDROID" = false ] \
   && [ "$DEPLOY_WEB" = false ] && [ "$DEPLOY_SITE" = false ] \
   && [ "$DEPLOY_WINDOWS" = false ] && [ "$DEPLOY_LINUX" = false ]; then
    echo ""
    if [ "$ANY_STEP_FAILED" = true ]; then
        echo "❌ Backend-only deploy failed"
        exit 1
    fi
    echo "✨ Backend-only deploy complete"
    exit 0
fi

# ----- Flutter prep -----
# Skipped for a pages-only run: `--site` ships HTML, and a clean + pub get would
# turn a five-second deploy into a two-minute one for nothing. Also skipped —
# clean only, pub get still runs — when NEEDS_ARTIFACT_REUSE (a stage-only
# platform is resuming from an earlier run's build/ output): 'flutter clean'
# would delete exactly the archive/IPA/AAB/web build it's trying to reuse,
# regardless of which platform asked for the reuse.
if [ "$NEEDS_FLUTTER_BUILD" = true ]; then
    if [ "$NEEDS_ARTIFACT_REUSE" = true ]; then
        echo "⏭️  Skipping 'flutter clean' — reusing build/ output from a previous run."
        run_with_spinner "Flutter pub get" flutter pub get || { echo "❌ Flutter pub get failed."; exit 1; }
    else
        run_with_spinner "Flutter clean" flutter clean || { echo "❌ Flutter clean failed."; exit 1; }
        run_with_spinner "Flutter pub get" flutter pub get || { echo "❌ Flutter pub get failed."; exit 1; }
    fi
fi

# ----- Version bump -----
# MonkeyHub bumps only the patch (1.3.11 → 1.3.12); the +B suffix stays pinned
# at +1 — the patch is the user-facing build number. Android's versionCode is
# derived from this in android/app/build.gradle.kts (1.3.12 → 10312).
NEW_VERSION=""
if [ "$SKIP_VERSION_BUMP" = false ]; then
    echo "📝 Bumping version..."
    VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
    echo "  • Current: $VERSION"

    MAJOR=$(echo "$VERSION" | cut -d. -f1)
    MINOR=$(echo "$VERSION" | cut -d. -f2)
    PATCH=$(echo "$VERSION" | cut -d. -f3 | cut -d+ -f1)
    BUILD=$(echo "$VERSION" | cut -d+ -f2)

    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH+$BUILD"

    echo "  • New:     $NEW_VERSION"
    sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
    PREVIOUS_VERSION="$VERSION"
    VERSION_BUMP_APPLIED=true
    echo "  ✅ pubspec.yaml updated"
else
    NEW_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
    echo "⏭️  Skipping version bump — using $NEW_VERSION"
fi
DISPLAY_VERSION="${NEW_VERSION%%+*}"
# One timestamp for the whole run, so the landing page, the downloads page and
# the manifest entry all agree about when this shipped.
STAMP_DATE=$(date '+%b %d, %Y')

# ----- Windows + Linux: GitHub Actions -----
# Flutter builds desktop only on its own OS, so this Mac cannot compile either.
# One workflow run (.github/workflows/desktop.yml) builds both, triggered by a
# throwaway tag that names the platforms and the version:
#
#   desktop-build/windows+linux/1.3.90/1760000000
#
# It is started HERE, right after the version bump and before iOS, so the
# ~15-minute CI build overlaps the local iOS/Android ones; run_windows /
# run_linux collect it when their turn comes. Only the compile is remote — the
# Store submission, the VM upload, the release rows and the AUR push all happen
# below, from this Mac, like every other platform.
#
# CI builds what is on origin, not this working tree. The tag points at HEAD,
# so HEAD is pushed first if origin doesn't have it; uncommitted edits are
# NOT in the build, and the start says so. pubspec.yaml's bump is the one
# exception that doesn't matter: the version travels in the tag.
DESKTOP_TAG=""
DESKTOP_RUN_ID=""
DESKTOP_RUN_URL=""
DESKTOP_COLLECTED=false
DESKTOP_START_FAILED=false
DESKTOP_LOG="/tmp/monkeyhub_desktop_ci.log"
WINDOWS_BUILD_TIME=0
LINUX_BUILD_TIME=0
MSIX_PATH="build/windows-store/MonkeyHub.msix"
LINUX_TARBALL=""

desktop_ci_start() {
    local platforms=""
    [ "$DEPLOY_WINDOWS" = true ] && has_stage "$WINDOWS_STAGES" build && platforms="windows"
    [ "$DEPLOY_LINUX" = true ] && has_stage "$LINUX_STAGES" build && platforms="${platforms:+$platforms+}linux"
    [ -n "$platforms" ] || return 0

    echo "☁️  Desktop: starting the GitHub Actions build ($platforms)"
    if [ "$DRY_RUN" = true ]; then
        echo "  ⏭️  --dry: not pushing a build tag (that is a side effect)."
        DESKTOP_START_FAILED=true
        return 0
    fi
    if ! git cat-file -e "HEAD:.github/workflows/$DESKTOP_WORKFLOW" 2>/dev/null; then
        echo "  ❌ .github/workflows/$DESKTOP_WORKFLOW is not committed — CI has nothing to run."
        DESKTOP_START_FAILED=true
        return 1
    fi

    # The workflow pins a Flutter version; a drift from this Mac's means the
    # desktop builds and the mobile ones were made by different toolchains.
    local local_flutter ci_flutter
    local_flutter=$(flutter --version --machine 2>/dev/null | jq -r '.frameworkVersion // empty')
    ci_flutter=$(sed -n "s/^  FLUTTER_VERSION: '\(.*\)'/\1/p" ".github/workflows/$DESKTOP_WORKFLOW")
    if [ -n "$local_flutter" ] && [ -n "$ci_flutter" ] && [ "$local_flutter" != "$ci_flutter" ]; then
        echo "  ⚠️  CI builds with Flutter $ci_flutter, this Mac has $local_flutter."
        echo "     Update FLUTTER_VERSION in .github/workflows/$DESKTOP_WORKFLOW."
    fi

    local dirty
    dirty=$(git status --porcelain | grep -v ' pubspec.yaml$' || true)
    if [ -n "$dirty" ]; then
        echo "  ⚠️  Uncommitted changes are NOT in the Windows/Linux build (CI builds HEAD):"
        printf '%s\n' "$dirty" | head -n 8 | sed 's/^/       /'
    fi

    local branch
    branch=$(git branch --show-current)
    git fetch -q origin 2>/dev/null || true
    if [ -z "$(git branch -r --contains HEAD 2>/dev/null | grep 'origin/')" ]; then
        if [ "$RUN_GIT" != true ]; then
            echo "  ❌ HEAD isn't on origin and --no-git forbids pushing it — CI can't see it."
            DESKTOP_START_FAILED=true
            return 1
        fi
        echo "  • Pushing $branch so CI can build HEAD"
        if ! git push -q origin "$branch"; then
            echo "  ❌ git push origin $branch failed."
            DESKTOP_START_FAILED=true
            return 1
        fi
    fi

    # env.local is gitignored but bundled into the app, so CI gets it from a
    # secret. Refreshed every run: a stale copy would ship a desktop build
    # pointed at last month's backend, and nothing would say so.
    if ! gh secret set ENV_LOCAL < env.local >/dev/null; then
        echo "  ❌ Could not update the ENV_LOCAL repo secret (gh secret set)."
        DESKTOP_START_FAILED=true
        return 1
    fi

    DESKTOP_TAG="desktop-build/$platforms/$DISPLAY_VERSION/$(date +%s)"
    if ! { git tag "$DESKTOP_TAG" HEAD && git push -q origin "refs/tags/$DESKTOP_TAG"; }; then
        echo "  ❌ Could not push the build tag $DESKTOP_TAG."
        git tag -d "$DESKTOP_TAG" >/dev/null 2>&1
        DESKTOP_TAG=""
        DESKTOP_START_FAILED=true
        return 1
    fi
    echo "  ✅ Build started at $(git rev-parse --short HEAD) — collected after the local platforms"
}

# The run behind DESKTOP_TAG: wait for it, then download whatever artifacts it
# produced. Once per deploy — Windows and Linux share the run, and whichever
# asks first does the waiting. A failed job doesn't stop the other platform's
# artifact from being collected.
desktop_ci_collect() {
    [ "$DESKTOP_COLLECTED" = true ] && return 0
    DESKTOP_COLLECTED=true
    [ -n "$DESKTOP_TAG" ] || return 1

    local i
    for i in $(seq 1 30); do
        DESKTOP_RUN_ID=$(gh run list --workflow "$DESKTOP_WORKFLOW" --branch "$DESKTOP_TAG" \
            --limit 1 --json databaseId -q '.[0].databaseId // empty' 2>/dev/null)
        [ -n "$DESKTOP_RUN_ID" ] && break
        sleep 4
    done
    if [ -z "$DESKTOP_RUN_ID" ]; then
        echo "  ❌ No workflow run appeared for $DESKTOP_TAG after 2 minutes."
        echo "     Check https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"
        return 1
    fi
    DESKTOP_RUN_URL=$(gh run view "$DESKTOP_RUN_ID" --json url -q .url 2>/dev/null)
    echo "  • $DESKTOP_RUN_URL"

    # The exit code is not the verdict: one job can fail while the other's
    # artifact is perfectly good. Each platform checks its own job below.
    run_with_spinner "Waiting for the GitHub Actions build" \
        sh -c "gh run watch '$DESKTOP_RUN_ID' --interval 20 --exit-status > '$DESKTOP_LOG' 2>&1" || true

    rm -rf build/desktop-ci
    gh run download "$DESKTOP_RUN_ID" -D build/desktop-ci >/dev/null 2>&1 || true
    if [ -f build/desktop-ci/windows-msix/MonkeyHub.msix ]; then
        mkdir -p build/windows-store
        mv -f build/desktop-ci/windows-msix/MonkeyHub.msix "$MSIX_PATH"
    fi
    local tarball
    tarball=$(find build/desktop-ci/linux-tarball -name '*.tar.gz' 2>/dev/null | head -n 1)
    if [ -n "$tarball" ]; then
        rm -rf build/linux-release && mkdir -p build/linux-release
        mv -f "$tarball" build/linux-release/
    fi
    rm -rf build/desktop-ci

    # The tag only existed to aim the run; leaving it would pile one up per deploy.
    git push -q origin ":refs/tags/$DESKTOP_TAG" 2>/dev/null || true
    git tag -d "$DESKTOP_TAG" >/dev/null 2>&1 || true
}

desktop_job_conclusion() {   # $1 = job name (windows | linux)
    gh run view "$DESKTOP_RUN_ID" --json jobs \
        -q ".jobs[] | select(.name == \"$1\") | .conclusion" 2>/dev/null
}

# Shared by run_windows/run_linux: collect the run and say why a platform's
# artifact is missing, pointing at the failing job's log rather than at ours.
desktop_build_stage() {   # $1 = windows | linux, $2 = expected artifact path
    if [ "$DESKTOP_START_FAILED" = true ] || [ -z "$DESKTOP_TAG" ]; then
        echo "  ❌ The CI build never started (see ☁️ above)."
        return 1
    fi
    desktop_ci_collect || return 1
    if [ "$(desktop_job_conclusion "$1")" != "success" ] || [ ! -f "$2" ]; then
        echo "  ❌ The $1 job did not produce $2."
        echo "     Logs: gh run view $DESKTOP_RUN_ID --log-failed   ($DESKTOP_RUN_URL)"
        return 1
    fi
    echo "  ✅ $(basename "$2") ($(du -h "$2" | cut -f1 | tr -d ' ')) from CI"
}

desktop_ci_start || true

# ----- iOS build -----
# Three independent stages (see IOS_STAGES / "stage defaults" above): archive
# (pods + flutter build + xcodebuild archive), export (IPA from the archive),
# upload (altool + publish_release). A stage-only invocation resumes using
# whatever the previous stage already left on disk — that's the whole point of
# splitting these apart: an ASC upload that times out shouldn't cost a re-archive.
IOS_BUILD_TIME=0
IPA_PATH=""
run_ios() {
    local do_archive=false do_export=false do_upload=false
    has_stage "$IOS_STAGES" archive && do_archive=true
    has_stage "$IOS_STAGES" export && do_export=true
    has_stage "$IOS_STAGES" upload && do_upload=true
    IOS_START_TIME=$(date +%s)

    if [ "$do_archive" = true ]; then
        echo "🍎 iOS: archive"
        echo "  • CocoaPods install"
        # Three escalating attempts, because the ways this fails need different
        # remedies — and each one is safe to reach for only after the cheaper one
        # has been tried:
        #   1. plain install    — the everyday case, uses the existing Podfile.lock.
        #   2. --repo-update    — the spec repo is too old to see a pod version a
        #                         freshly bumped plugin asks for.
        #   3. drop the lock    — Podfile.lock pins a transitive version the bumped
        #                         plugin no longer accepts (e.g. flutter_webrtc 1.4.0
        #                         wanting WebRTC-SDK 144.7559.09 against a lock
        #                         pinning .01). No amount of repo-updating resolves
        #                         that; the stale pin itself has to go. Safe because
        #                         every version this project deliberately controls is
        #                         pinned in the Podfile, not the lock.
        pod_install_with_retries ios || return 1

        # Refreshes Generated.xcconfig with the current pubspec version. Runtime
        # keys ride along via the bundled env.local asset — no --dart-define needed.
        #
        # Note there's deliberately no --dart-define=MH_CHANNEL here, unlike the
        # Android and web builds. This ONE binary serves both TestFlight and (later)
        # the App Store, so any channel stamped into it would be wrong for half its
        # users. iOS is the case where runtime detection is strictly better: the app
        # reads its own receipt at launch (package_info_plus installerStore →
        # com.apple.testflight vs com.apple) and resolves its own channel. See
        # lib/update/release_channel.dart.
        run_with_spinner "Building Flutter for iOS (release)" \
            flutter build ios --release --no-codesign || return 1

        # -authenticationKey* lets xcodebuild fetch the Distribution cert +
        # provisioning profile via the ASC API — works with no Xcode account.
        run_with_spinner "Creating Xcode archive" \
            xcodebuild -workspace ios/Runner.xcworkspace \
                -scheme Runner \
                -configuration Release \
                -archivePath build/Runner.xcarchive \
                archive \
                -destination 'generic/platform=iOS' \
                -allowProvisioningUpdates \
                -authenticationKeyPath "$P8_FILE_PATH" \
                -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
                -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID" || return 1
    fi

    if [ "$do_export" = true ]; then
        if [ ! -d build/Runner.xcarchive ]; then
            echo "❌ No archive at build/Runner.xcarchive — run --ios-archive (or --ios) first."
            return 1
        fi
        run_with_spinner "Exporting IPA" \
            env PATH="/usr/bin:$PATH" xcodebuild -exportArchive \
                -archivePath build/Runner.xcarchive \
                -exportPath build/ios \
                -exportOptionsPlist ios/ExportOptions.plist \
                -allowProvisioningUpdates \
                -authenticationKeyPath "$P8_FILE_PATH" \
                -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
                -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID" || return 1

        # The IPA is named after CFBundleName, not PRODUCT_NAME, so glob for it.
        IPA_PATH="$(find build/ios -maxdepth 1 -type f -name '*.ipa' | head -n 1)"
        if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
            echo "❌ No .ipa found in build/ios/ after export"
            ls -la build/ios/ || true
            return 1
        fi
        echo "  ✅ IPA at $IPA_PATH"
    fi

    if [ "$do_upload" = true ]; then
        if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
            IPA_PATH="$(find build/ios -maxdepth 1 -type f -name '*.ipa' | head -n 1)"
        fi
        if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
            echo "❌ No .ipa found in build/ios/ — run --ios-export (or --ios-archive, or --ios) first."
            return 1
        fi
        if [ "$RUN_UPLOAD" = true ]; then
            local upload_log=/tmp/monkeyhub_ios_upload.log
            run_with_spinner "Uploading to App Store Connect" \
                asc_upload ios "$IPA_PATH" "$upload_log" \
                || { tail -n 20 "$upload_log"; echo "     Log: $upload_log"; return 1; }

            # TestFlight only, and only once Apple has processed the build. App
            # Store installs don't read a row's version at all: they ask the
            # App Store itself (lib/update/apple_store.dart), so approval
            # reaches them with nothing to publish.
            announce_when_processed ios-testflight "$upload_log"
            SHIPPED_SOMETHING=true
            free_platform_space ios
            IPA_PATH=""
        else
            echo "⏭️  Skipping App Store Connect upload (--no-upload)"
        fi
    fi

    IOS_END_TIME=$(date +%s)
    IOS_BUILD_TIME=$((IOS_END_TIME - IOS_START_TIME))
    return 0
}

# ----- macOS build -----
# Same shape as iOS: archive via xcodebuild, export a signed artifact, upload
# with altool. Export produces a .pkg (method=app-store) instead of a .ipa.
#
# One difference from iOS under the hood: macOS can't tell its channel apart
# at runtime the way iOS reads its receipt (package_info_plus always reports a
# null installerStore here — see lib/update/release_channel.dart), so the
# build carries the channel as a --dart-define instead. Otherwise this is the
# same story as iOS: an ASC upload isn't a released App Store version, so
# publish_release always announces the TestFlight-side channel here too.
#
# --config-only instead of iOS's --no-codesign: macOS has no such flag, and a
# real (non-config-only) `flutter build macos` tries to codesign locally with
# whatever development identity is on this Mac — which fails outright the
# first time a target's entitlements (app sandbox, associated domains, …)
# haven't been provisioned yet ("has entitlements that require signing with a
# development certificate"). --config-only only refreshes Generated.xcconfig
# (pubspec version, the dart-defines) and skips the build+sign step entirely;
# the actual build+sign happens in the xcodebuild archive below, which
# resolves its own certificate via -allowProvisioningUpdates + the ASC key —
# the same mechanism that already works for iOS.
MACOS_BUILD_TIME=0
PKG_PATH=""
run_macos() {
    local do_archive=false do_export=false do_upload=false
    has_stage "$MACOS_STAGES" archive && do_archive=true
    has_stage "$MACOS_STAGES" export && do_export=true
    has_stage "$MACOS_STAGES" upload && do_upload=true
    MACOS_START_TIME=$(date +%s)

    if [ "$do_archive" = true ]; then
        echo "🖥️  macOS: archive"
        echo "  • CocoaPods install"
        pod_install_with_retries macos || return 1

        run_with_spinner "Configuring Flutter for macOS (release)" \
            flutter build macos --release --config-only --dart-define=MH_CHANNEL=macos-testflight || return 1

        run_with_spinner "Creating Xcode archive" \
            xcodebuild -workspace macos/Runner.xcworkspace \
                -scheme Runner \
                -configuration Release \
                -archivePath build/Runner-macOS.xcarchive \
                archive \
                -destination 'generic/platform=macOS' \
                -allowProvisioningUpdates \
                -authenticationKeyPath "$P8_FILE_PATH" \
                -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
                -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID" || return 1
    fi

    if [ "$do_export" = true ]; then
        if [ ! -d build/Runner-macOS.xcarchive ]; then
            echo "❌ No archive at build/Runner-macOS.xcarchive — run --macos-archive (or --macos) first."
            return 1
        fi
        run_with_spinner "Exporting installer package" \
            env PATH="/usr/bin:$PATH" xcodebuild -exportArchive \
                -archivePath build/Runner-macOS.xcarchive \
                -exportPath build/macos-export \
                -exportOptionsPlist macos/ExportOptions.plist \
                -allowProvisioningUpdates \
                -authenticationKeyPath "$P8_FILE_PATH" \
                -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
                -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID" || return 1

        PKG_PATH="$(find build/macos-export -maxdepth 1 -type f -name '*.pkg' | head -n 1)"
        if [ -z "$PKG_PATH" ] || [ ! -f "$PKG_PATH" ]; then
            echo "❌ No .pkg found in build/macos-export/ after export"
            ls -la build/macos-export/ || true
            return 1
        fi
        echo "  ✅ Package at $PKG_PATH"
    fi

    if [ "$do_upload" = true ]; then
        if [ -z "$PKG_PATH" ] || [ ! -f "$PKG_PATH" ]; then
            PKG_PATH="$(find build/macos-export -maxdepth 1 -type f -name '*.pkg' | head -n 1)"
        fi
        if [ -z "$PKG_PATH" ] || [ ! -f "$PKG_PATH" ]; then
            echo "❌ No .pkg found in build/macos-export/ — run --macos-export (or --macos-archive, or --macos) first."
            return 1
        fi
        if [ "$RUN_UPLOAD" = true ]; then
            local upload_log=/tmp/monkeyhub_macos_upload.log
            run_with_spinner "Uploading to App Store Connect" \
                asc_upload macos "$PKG_PATH" "$upload_log" \
                || { tail -n 20 "$upload_log"; echo "     Log: $upload_log"; return 1; }

            announce_when_processed macos-testflight "$upload_log"
            SHIPPED_SOMETHING=true
            free_platform_space macos
            PKG_PATH=""
        else
            echo "⏭️  Skipping App Store Connect upload (--no-upload)"
        fi
    fi

    MACOS_END_TIME=$(date +%s)
    MACOS_BUILD_TIME=$((MACOS_END_TIME - MACOS_START_TIME))
    return 0
}

# ----- Android build -----
# Two independent stages: build (produces the AAB) and upload (fastlane supply
# + publish_release, for both the Play row and the android-apk sideloader row).
# --android-upload resumes a failed Play upload from the already-built AAB
# without repeating the Flutter compile.
ANDROID_BUILD_TIME=0
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
run_android() {
    local do_build=false do_upload=false
    has_stage "$ANDROID_STAGES" build && do_build=true
    has_stage "$ANDROID_STAGES" upload && do_upload=true
    ANDROID_START_TIME=$(date +%s)

    if [ "$do_build" = true ]; then
        echo "🤖 Android: build (AAB)"
        run_with_spinner "Building Flutter app bundle (release)" \
            flutter build appbundle --release --dart-define=MH_CHANNEL=android-play || return 1

        if [ ! -f "$AAB_PATH" ]; then
            echo "❌ No AAB at $AAB_PATH after build"
            return 1
        fi
        echo "  ✅ AAB at $AAB_PATH"

        archive_android_symbols "$DISPLAY_VERSION"
    fi

    if [ "$do_upload" = true ]; then
        if [ ! -f "$AAB_PATH" ]; then
            echo "❌ No AAB at $AAB_PATH — run --android-build (or --android) first."
            return 1
        fi
        # Automated upload needs a verified Play account, the app created in
        # Play Console, a linked service account (PLAY_SERVICE_ACCOUNT_JSON in
        # .env.local) and fastlane. Until then we hand over the AAB.
        if [ "$RUN_UPLOAD" = true ] && [ -n "${PLAY_SERVICE_ACCOUNT_JSON:-}" ] && command -v fastlane >/dev/null 2>&1; then
            run_with_spinner "Uploading to Google Play (internal track)" \
                fastlane supply \
                    --package_name "$ANDROID_PACKAGE" \
                    --aab "$AAB_PATH" \
                    --track internal \
                    --json_key "$PLAY_SERVICE_ACCOUNT_JSON" \
                    --skip_upload_metadata --skip_upload_images --skip_upload_screenshots || return 1
            publish_release android-play
            SHIPPED_SOMETHING=true

            # …and tell the sideloaders, who are a separate audience with a separate
            # problem. Their APK stamped MH_CHANNEL=android-apk at build time, and
            # that define beats installerStore forever, so they will ask about this
            # channel for as long as that copy is installed. It is the only line of
            # communication we have with them.
            #
            # Re-announced on EVERY Play release rather than set once, because
            # update_checker.dart bails when the installed version is >= the
            # published one — a frozen row goes quiet the moment someone's build
            # catches up with it.
            #
            # Not mandatory (no minSupported): the way out costs them a re-install
            # and, while the track is invite-only, an invite they may not have.
            # Locking them out of the app before that is a trap, not a prompt.
            publish_release android-apk "$HOSTING_URL/" "$APK_MIGRATION_NOTE"
            free_platform_space android
        else
            echo "⏭️  No automated Play upload (needs PLAY_SERVICE_ACCOUNT_JSON in"
            echo "    .env.local + fastlane + a verified Play account — see DEPLOY.md)."
            echo "    Upload manually: Play Console → MonkeyHub → Internal testing →"
            echo "    Create release → drop in $AAB_PATH"
        fi
    fi

    ANDROID_END_TIME=$(date +%s)
    ANDROID_BUILD_TIME=$((ANDROID_END_TIME - ANDROID_START_TIME))
    return 0
}

# ----- Windows (--windows) -----
# build  = collect the CI run's MSIX into build/windows-store/
# upload = submit it to the Microsoft Store with the msstore CLI.
#
# The submission API only works once the app has ONE submission finished in
# Partner Center by hand, and needs an Entra ID app registered there (Account
# settings → User management → Microsoft Entra applications) — MS_STORE_* in
# .env.local. Until both exist the MSIX is handed over for a manual upload,
# exactly how Android worked before Play was automated. See DEPLOY.md.
#
# Announced the moment the submission is in, even though certification takes
# hours to days. Current builds don't take the row's version as evidence of
# anything: they ask the Store itself (StoreContext, see
# lib/update/windows_store_update.dart), which offers the package only once it
# has cleared, and install it in place. The row is still published for its
# minSupported/notes, and for builds that predate that check.
run_windows() {
    local do_build=false do_upload=false
    has_stage "$WINDOWS_STAGES" build && do_build=true
    has_stage "$WINDOWS_STAGES" upload && do_upload=true
    local start=$(date +%s)
    if [ "$DRY_RUN" = true ]; then
        echo "⏭️  Windows: skipped under --dry (its build is a CI run started by a pushed tag)."
        return 0
    fi

    if [ "$do_build" = true ]; then
        echo "🪟 Windows: build (GitHub Actions → MSIX)"
        desktop_build_stage windows "$MSIX_PATH" || return 1
    fi

    if [ "$do_upload" = true ]; then
        if [ ! -f "$MSIX_PATH" ]; then
            echo "❌ No MSIX at $MSIX_PATH — run --windows-build (or --windows) first."
            return 1
        fi
        if [ "$RUN_UPLOAD" = true ] && [ -n "${MS_STORE_CLIENT_ID:-}" ]; then
            run_with_spinner "Configuring the Microsoft Store CLI" \
                sh -c 'msstore reconfigure --tenantId "$MS_STORE_TENANT_ID" --sellerId "$MS_STORE_SELLER_ID" \
                        --clientId "$MS_STORE_CLIENT_ID" --clientSecret "$MS_STORE_CLIENT_SECRET" \
                        >/tmp/monkeyhub_msstore.log 2>&1' || return 1
            # -i is the DIRECTORY holding the .msix, not the file: given the
            # file, msstore answers "Input directory does not exist".
            run_with_spinner "Submitting to the Microsoft Store" \
                sh -c "msstore publish '$PWD' -i '$(dirname "$MSIX_PATH")' -id '$MS_STORE_PRODUCT_ID' \
                        >>/tmp/monkeyhub_msstore.log 2>&1" \
                || { echo "     Log: /tmp/monkeyhub_msstore.log"; return 1; }
            publish_release windows "$MS_STORE_URL"
            SHIPPED_SOMETHING=true
            free_platform_space windows
        elif [ "$RUN_UPLOAD" = true ]; then
            echo "⏭️  No automated Store upload (needs MS_STORE_* in .env.local + msstore — see DEPLOY.md)."
            echo "    Upload manually: Partner Center → MonkeyHub → current submission →"
            echo "    Packages → drop in $MSIX_PATH → Submit for certification."
        else
            echo "⏭️  Skipping Microsoft Store upload (--no-upload). MSIX at $MSIX_PATH"
        fi
    fi

    WINDOWS_BUILD_TIME=$(( $(date +%s) - start ))
    return 0
}

# ----- Linux (--linux) -----
# build  = collect the CI run's tarball into build/linux-release/
# upload = put it on /downloads/ (the page grows a Linux card from
#          artifacts.json), announce it, then push the AUR package.
#
# The AUR step is optional and skipped quietly until it is set up: an AUR
# account with this Mac's key on it (AUR_SSH_KEY in .env.local, default
# ~/.ssh/aur). The package is monkeyhub-bin — "-bin" because it repackages our
# tarball rather than building from source, which is what the AUR expects a
# closed-source binary to be called. Its PKGBUILD downloads the tarball from
# /downloads/, so the VM upload has to land first.
#
# Older tarballs stay on the VM (the AUR's sha256 pins an exact file, and a
# user mid-upgrade may still be fetching the previous one), pruned to three.
dl_manifest_put() {   # $1 = key, $2 = file, $3 = size, $4 = sha256 (optional)
    # sha256 is what the Linux self-updater (lib/update/linux_self_update_io.dart)
    # checks the download against; it refuses to install a tarball without one.
    local current
    current=$(dl_manifest_fetch)
    printf '%s' "$current" | jq --arg k "$1" --arg f "$2" --arg v "$DISPLAY_VERSION" \
        --arg s "$3" --arg d "$STAMP_DATE" --arg h "${4:-}" \
        '.[$k] = ({file: $f, version: $v, size: $s, updatedAt: $d}
                  + (if $h == "" then {} else {sha256: $h} end))' \
        | vm_ssh "cat > $DL_MANIFEST.tmp && mv $DL_MANIFEST.tmp $DL_MANIFEST"
}

aur_publish() {   # $1 = tarball path
    local key="${AUR_SSH_KEY:-$HOME/.ssh/aur}"
    if [ ! -f "$key" ]; then
        echo "⏭️  No AUR key at $key — skipping the AUR (see DEPLOY.md → Linux)."
        return 0
    fi
    local sha url dir="build/aur"
    sha=$(shasum -a 256 "$1" | cut -d' ' -f1)
    url="$HOSTING_URL/$(basename "$1")"
    export GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    rm -rf "$dir"
    # Cloning an AUR name nobody has pushed yet gives an empty repo — the first
    # push is what creates the package.
    if ! git clone -q "ssh://aur@aur.archlinux.org/$AUR_PACKAGE.git" "$dir" 2>/dev/null; then
        unset GIT_SSH_COMMAND
        echo "  ❌ Could not clone the AUR repo — is $key registered on your AUR account?"
        return 1
    fi
    sed -e "s|__VERSION__|$DISPLAY_VERSION|g" -e "s|__SHA256__|$sha|g" -e "s|__URL__|$url|g" \
        linux/packaging/aur/PKGBUILD.template > "$dir/PKGBUILD"
    sed -e "s|__VERSION__|$DISPLAY_VERSION|g" -e "s|__SHA256__|$sha|g" -e "s|__URL__|$url|g" \
        linux/packaging/aur/SRCINFO.template > "$dir/.SRCINFO"
    (
        cd "$dir" &&
        git add PKGBUILD .SRCINFO &&
        { git diff --cached --quiet || git -c user.name="$(git -C "$SCRIPT_DIR" config user.name)" \
              -c user.email="$(git -C "$SCRIPT_DIR" config user.email)" \
              commit -q -m "$DISPLAY_VERSION"; } &&
        git push -q origin HEAD:master
    )
    local rc=$?
    unset GIT_SSH_COMMAND
    if [ $rc -eq 0 ]; then
        echo "  ✅ AUR: $AUR_PACKAGE $DISPLAY_VERSION (https://aur.archlinux.org/packages/$AUR_PACKAGE)"
    else
        echo "  ❌ AUR push failed. Retry with:   ./deploy.sh --linux-upload --no-convex"
    fi
    return $rc
}

run_linux() {
    local do_build=false do_upload=false
    has_stage "$LINUX_STAGES" build && do_build=true
    has_stage "$LINUX_STAGES" upload && do_upload=true
    local start=$(date +%s)
    if [ "$DRY_RUN" = true ]; then
        echo "⏭️  Linux: skipped under --dry (its build is a CI run started by a pushed tag)."
        return 0
    fi
    LINUX_TARBALL="build/linux-release/monkeyhub-linux-x64-$DISPLAY_VERSION.tar.gz"

    if [ "$do_build" = true ]; then
        echo "🐧 Linux: build (GitHub Actions → tarball)"
        desktop_build_stage linux "$LINUX_TARBALL" || return 1
    fi

    if [ "$do_upload" = true ]; then
        if [ ! -f "$LINUX_TARBALL" ]; then
            LINUX_TARBALL=$(find build/linux-release -name '*.tar.gz' 2>/dev/null | head -n 1)
        fi
        if [ -z "$LINUX_TARBALL" ] || [ ! -f "$LINUX_TARBALL" ]; then
            echo "❌ No tarball in build/linux-release/ — run --linux-build (or --linux) first."
            return 1
        fi
        if [ "$RUN_UPLOAD" = true ]; then
            local name size
            name=$(basename "$LINUX_TARBALL")
            size=$(du -h "$LINUX_TARBALL" | cut -f1 | tr -d ' ')B
            vm_ensure_dirs || return 1
            run_with_spinner "Uploading $name to the VM" \
                rsync -a -e "ssh $VM_SSH_OPTS" "$LINUX_TARBALL" "$VM_USER@$VM_HOST:$VM_DL_DIR/" || return 1
            vm_ssh "cd $VM_DL_DIR && ls -1t monkeyhub-linux-x64-*.tar.gz 2>/dev/null | tail -n +4 | xargs -r rm -f" || true
            if ! dl_manifest_put linux "$name" "$size" \
                    "$(shasum -a 256 "$LINUX_TARBALL" | cut -d' ' -f1)"; then
                echo "  ❌ Uploaded, but could not record it in $DL_MANIFEST."
                return 1
            fi
            echo "  ✅ $HOSTING_URL/$name"
            publish_release linux "$HOSTING_URL/"
            SHIPPED_SOMETHING=true
            # The AUR is a second channel for the same file: its failure is
            # reported, but the tarball already shipped, so it doesn't fail Linux.
            aur_publish "$LINUX_TARBALL" || LINUX_AUR_FAILED=true
            free_platform_space linux
        else
            echo "⏭️  Skipping Linux upload (--no-upload). Tarball at $LINUX_TARBALL"
        fi
    fi

    LINUX_BUILD_TIME=$(( $(date +%s) - start ))
    return 0
}
LINUX_AUR_FAILED=false

# ----- Web build (--web, or as part of --all) -----
# Published under /web/, with the landing page owning the root. --base-href is
# what makes that work and it is baked in at build time, so a build made without
# it will 404 on every asset.
#
# One standing limitation, not a caveat about maturity: the native call UI
# (flutter_callkit_incoming) is mobile-only, so a browser gets no CallKit /
# ConnectionService ringing.
#
# --wasm compiles to WasmGC and ALSO emits the dart2js output; flutter_bootstrap.js
# picks between them at runtime, so a browser without WasmGC quietly gets the JS
# build and nothing breaks. It costs compatibility nothing and roughly doubles
# build/web, since both artifacts ship.
#
# This only became possible once flutter_secure_storage 10 replaced its dart:html
# web implementation with dart:js_interop — that was the one hard blocker. The
# flutter_rust_bridge `is JSAny` lint the dry run still reports is a warning and
# does not stop the compile, which is why the dry run stays on: it is now a
# report about a build we actually make.
WEB_BUILD_TIME=0
# Swap a whole directory rather than rsync over the live one. Syncing in place
# serves a mix of two builds for as long as it takes, and a failed sync leaves
# it that way with nothing to go back to. Here the visitor sees the old build
# until a single rename, then the new one — and the build it replaced stays
# put for --rollback-web.
upload_web() {
    vm_ensure_dirs || return 1
    # Hardlinks: seeding the staging copy costs no disk and no time, and
    # rsync then only sends what actually changed.
    vm_ssh "set -e
            rm -rf $VM_WEB_DIR.staging
            cp -al $VM_WEB_DIR $VM_WEB_DIR.staging" || return 1
    rsync -a --delete -e "ssh $VM_SSH_OPTS" \
        build/web/ "$VM_USER@$VM_HOST:$VM_WEB_DIR.staging/" || return 1
    vm_ssh "set -e
            rm -rf $VM_WEB_DIR.prev
            mv $VM_WEB_DIR $VM_WEB_DIR.prev
            mv $VM_WEB_DIR.staging $VM_WEB_DIR" || return 1
}
run_web() {
    local do_build=false do_upload=false
    has_stage "$WEB_STAGES" build && do_build=true
    has_stage "$WEB_STAGES" upload && do_upload=true
    WEB_START_TIME=$(date +%s)

    if [ "$do_build" = true ]; then
        echo "🌐 Web: build"
        run_with_spinner "Building Flutter web (release, wasm)" \
            flutter build web --wasm --release --base-href /web/ --dart-define=MH_CHANNEL=web || return 1

        if [ ! -f "build/web/main.dart.js" ] && [ ! -f "build/web/flutter_bootstrap.js" ]; then
            echo "❌ No web build output at build/web/"
            return 1
        fi

        # A --wasm build that stops emitting WasmGC still produces a complete,
        # working JS-only site, so the regression is invisible: same deploy, same
        # green ticks, silently the slower build from then on. Warn rather than
        # exit — the JS build is fine to ship, it just is not what was asked for.
        if [ ! -f "build/web/main.dart.wasm" ]; then
            echo "  ⚠️  --wasm emitted no main.dart.wasm. Shipping the dart2js build."
            echo '     Check "flutter build web --wasm" output for a new hard blocker.'
        fi
    fi

    if [ "$do_upload" = true ]; then
        if [ ! -f "build/web/main.dart.js" ] && [ ! -f "build/web/flutter_bootstrap.js" ]; then
            echo "❌ No web build output at build/web/ — run --web-build (or --web) first."
            return 1
        fi
        if [ "$RUN_UPLOAD" = true ]; then
            if upload_web; then
                echo "  ✅ Web app at $WEB_URL"
                # WasmGC streaming-instantiates, which the browser only does for an
                # `application/wasm` response — anything else and it falls back to
                # the JS build without surfacing an error. nginx has shipped that
                # mapping since 1.21, so this normally passes; it is here because
                # when it does not, everything still looks perfectly fine.
                if [ -f "build/web/main.dart.wasm" ]; then
                    wasm_ct=$(curl -fsSI "${WEB_URL}main.dart.wasm" 2>/dev/null \
                        | tr -d '\r' \
                        | awk -F': ' 'tolower($1) == "content-type" { print tolower($2) }')
                    case "$wasm_ct" in
                        application/wasm*)
                            echo "  ✅ Serving main.dart.wasm as application/wasm" ;;
                        "")
                            echo "  ⚠️  Could not read the Content-Type of main.dart.wasm." ;;
                        *)
                            echo "  ⚠️  main.dart.wasm serves as '$wasm_ct', not application/wasm."
                            echo "     Browsers will silently run the JS build instead. Add to nginx:"
                            echo "       types { application/wasm wasm; }" ;;
                    esac
                fi
                # A tab left open for days keeps running the build it loaded, so a
                # long-lived session still needs telling. The prompt reloads rather
                # than navigating anywhere.
                publish_release web
                SHIPPED_SOMETHING=true
                free_platform_space web
            else
                echo "❌ Web upload to $VM_USER@$VM_HOST failed."
                echo "   The live build is untouched — the swap only happens after"
                echo "   the sync succeeds. Retry with:   ./deploy.sh --web-upload"
                return 1
            fi
        else
            echo "⏭️  Skipping web upload (--no-upload). Build in build/web/."
        fi
    fi

    WEB_END_TIME=$(date +%s)
    WEB_BUILD_TIME=$((WEB_END_TIME - WEB_START_TIME))
    return 0
}

# ----- Ship the platforms, in PLATFORM_ORDER -----
# Each platform above only DEFINES its run_<p>; this is where they run. Order
# is PLATFORM_ORDER (mobile first by default, or the order the picker's rows
# were ticked in). Convex has already run, and Site always runs after all of
# them — see below. Isolated: one failing never stops the next.
ship_platform() {   # $1 = ios|android|macos|windows|linux|web
    local upper label flag status_var
    upper=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    flag="DEPLOY_$upper"
    [ "${!flag}" = true ] || return 0
    case "$1" in
        ios) label="iOS" ;; macos) label="macOS" ;; android) label="Android" ;;
        windows) label="Windows" ;; linux) label="Linux" ;; web) label="Web" ;;
    esac
    status_var="${upper}_STATUS"
    if "run_$1"; then
        printf -v "$status_var" '%s' ok
    else
        printf -v "$status_var" '%s' failed
        ANY_STEP_FAILED=true
        echo "  ⚠️  $label failed — continuing with the rest of the run."
    fi
}
for p in $PLATFORM_ORDER; do
    ship_platform "$p"
done

# TestFlight rows wait on Apple's processing, which ran in the background while
# the other platforms built. Before the git step, so a run that ends here has
# every row it is going to publish.
await_testflight_processing

# ----- Landing + downloads pages -----
# Last, so the downloads page renders from a manifest that already includes
# anything this run just shipped. Isolated like every platform above: a failed
# page publish shouldn't cost the git commit for builds that DID ship.
run_site() {
    if ! deploy_site; then
        echo "   Retry with:   ./deploy.sh --site"
        return 1
    fi
    return 0
}
if [ "$DEPLOY_SITE" = true ]; then
    if run_site; then
        SITE_STATUS="ok"
    else
        SITE_STATUS="failed"
        ANY_STEP_FAILED=true
        echo "  ⚠️  Site publish failed — continuing with the rest of the run."
    fi
fi

# ----- Git -----
# Every platform has now been attempted (isolated failures included — see
# run_with_spinner/ANY_STEP_FAILED above), so the version bump's fate is
# decided: DEPLOY_COMPLETE=true unless something failed, matching what it
# meant before platforms were isolated (the run reached its natural end
# without an early abort). The EXIT trap uses this, together with
# SHIPPED_SOMETHING, to decide whether to revert pubspec.yaml.
DEPLOY_COMPLETE=$([ "$ANY_STEP_FAILED" = false ] && echo true || echo false)
# A run where nothing shipped gets its bump reverted by the EXIT trap, so
# committing it first would push a version that exists nowhere and leave the
# tree disagreeing with HEAD.
if [ "$DEPLOY_COMPLETE" = false ] && [ "$SHIPPED_SOMETHING" = false ]; then
    echo "⏭️  Skipping git commit/push — nothing shipped, the bump is reverted"
elif [ "$RUN_GIT" = true ] && [ "$SKIP_VERSION_BUMP" = false ]; then
    echo "🔄 Git commit + push..."
    if [ -n "$(git status --porcelain pubspec.yaml)" ]; then
        git add pubspec.yaml
        git commit -m "chore: bump version to $NEW_VERSION"
        CURRENT_BRANCH=$(git branch --show-current)
        # No remote is a setup gap, not a push failure, and `git push` reports it
        # as a bare `fatal:` that reads like the deploy broke. The deploy is done
        # by this point either way — the commit is safe on disk.
        if ! git remote get-url origin >/dev/null 2>&1; then
            echo "  ⚠️  No 'origin' remote — commit is local only."
            echo "       Add one with:  git remote add origin <url>"
        elif git push origin "$CURRENT_BRANCH"; then
            echo "  ✅ Pushed to origin/$CURRENT_BRANCH"
        else
            echo "  ⚠️  git push failed. Commit is local; push manually with:"
            echo "       git push origin $CURRENT_BRANCH"
        fi
    else
        echo "  • pubspec.yaml has no staged changes, nothing to commit"
    fi
elif [ "$RUN_GIT" = false ]; then
    echo "⏭️  Skipping git commit/push (--no-git)"
fi

# ----- Summary -----
SCRIPT_END_TIME=$(date +%s)
TOTAL_TIME=$((SCRIPT_END_TIME - SCRIPT_START_TIME))

status_icon() { case "$1" in ok) echo "✅" ;; failed) echo "❌" ;; *) echo "⏭️ " ;; esac; }

echo ""
if [ "$ANY_STEP_FAILED" = true ]; then
    echo "⚠️  Deploy finished with failures — see ❌ lines above and below"
else
    echo "✨ Deploy complete"
fi
echo "  📱 Version:        $NEW_VERSION"
[ "$RUN_CONVEX" = true ] && echo "  $(status_icon "$CONVEX_STATUS") Convex:            $CONVEX_STATUS"
if [ "$DEPLOY_IOS" = true ]; then
    if [ "$IOS_STATUS" = ok ] && [ "$RUN_UPLOAD" = true ]; then
        if [[ " $TESTFLIGHT_UNANNOUNCED " == *" ios-testflight "* ]]; then
            echo "  ⚠️  iOS:            uploaded, but processing didn't confirm, so not announced (see above)"
        else
            echo "  ✅ iOS:            on TestFlight and announced; the App Store follows approval on its own"
        fi
    elif [ "$IOS_STATUS" = ok ]; then
        echo "  ✅ iOS IPA:        $IPA_PATH"
    else
        echo "  ❌ iOS:            failed — retry with --ios-archive / --ios-export / --ios-upload"
    fi
fi
if [ "$DEPLOY_MACOS" = true ]; then
    if [ "$MACOS_STATUS" = ok ] && [ "$RUN_UPLOAD" = true ]; then
        if [[ " $TESTFLIGHT_UNANNOUNCED " == *" macos-testflight "* ]]; then
            echo "  ⚠️  macOS:          uploaded, but processing didn't confirm, so not announced (see above)"
        else
            echo "  ✅ macOS:          on TestFlight and announced; the Mac App Store follows approval on its own"
        fi
    elif [ "$MACOS_STATUS" = ok ]; then
        echo "  ✅ macOS package:  $PKG_PATH"
    else
        echo "  ❌ macOS:          failed — retry with --macos-archive / --macos-export / --macos-upload"
    fi
fi
if [ "$DEPLOY_ANDROID" = true ]; then
    if [ "$ANDROID_STATUS" = ok ]; then
        if [ -f "$AAB_PATH" ]; then
            echo "  ✅ Android AAB:    $AAB_PATH"
        else
            echo "  ✅ Android AAB:    uploaded, then deleted to free disk space"
        fi
        [ "$RUN_UPLOAD" = true ] && echo "     → Play internal track; sideloaders pointed at $HOSTING_URL/"
    else
        echo "  ❌ Android:        failed — retry with --android-build / --android-upload"
    fi
fi
if [ "$DEPLOY_WINDOWS" = true ] && [ "$DRY_RUN" = true ]; then
    echo "  ⏭️  Windows:        skipped (--dry)"
elif [ "$DEPLOY_WINDOWS" = true ]; then
    if [ "$WINDOWS_STATUS" = ok ] && [ "$RUN_UPLOAD" = true ] && [ -n "${MS_STORE_CLIENT_ID:-}" ]; then
        echo "  ✅ Windows:        submitted to the Microsoft Store (certification: hours to days)"
    elif [ "$WINDOWS_STATUS" = ok ]; then
        echo "  ✅ Windows MSIX:   $MSIX_PATH"
    else
        echo "  ❌ Windows:        failed — retry with --windows-build / --windows-upload"
    fi
fi
if [ "$DEPLOY_LINUX" = true ] && [ "$DRY_RUN" = true ]; then
    echo "  ⏭️  Linux:          skipped (--dry)"
elif [ "$DEPLOY_LINUX" = true ]; then
    if [ "$LINUX_STATUS" = ok ] && [ "$RUN_UPLOAD" = true ]; then
        echo "  ✅ Linux:          $HOSTING_URL/"
        [ "$LINUX_AUR_FAILED" = true ] && echo "     ⚠️  AUR push failed — see above"
    elif [ "$LINUX_STATUS" = ok ]; then
        echo "  ✅ Linux tarball:  $LINUX_TARBALL"
    else
        echo "  ❌ Linux:          failed — retry with --linux-build / --linux-upload"
    fi
fi
if [ "$DEPLOY_WEB" = true ]; then
    if [ "$WEB_STATUS" = ok ] && [ "$RUN_UPLOAD" = true ]; then
        echo "  ✅ Web:            $WEB_URL"
    elif [ "$WEB_STATUS" = ok ]; then
        echo "  ✅ Web build:      build/web/"
    else
        echo "  ❌ Web:            failed — retry with --web-build / --web-upload"
    fi
fi
if [ "$DEPLOY_SITE" = true ]; then
    if [ "$SITE_STATUS" = ok ] && [ "$RUN_UPLOAD" = true ]; then
        echo "  ✅ Landing page:   $SITE_URL"
    elif [ "$SITE_STATUS" = ok ]; then
        echo "  ✅ Pages:          hosting/public/"
    else
        echo "  ❌ Site:           failed — retry with --site"
    fi
fi
[ "$DEPLOY_WEB" = true ] && [ "$WEB_STATUS" = ok ] && [ "$RUN_UPLOAD" = true ] && \
    echo "     ↩︎  Undo the web deploy with:  ./deploy.sh --rollback-web"
if [ "$RELEASE_ROWS_INCOMPLETE" = true ]; then
    echo "  ⚠️  Release rows: one deployment did not take them (see ⚠️ lines above)."
    echo "     Square them up with:  ./deploy.sh --sync-releases"
fi
echo ""
echo "⏱️  Timing:"
[ "$DEPLOY_IOS" = true ]     && echo "  🍎 iOS build:      ${IOS_BUILD_TIME}s"
[ "$DEPLOY_MACOS" = true ]   && echo "  🖥️  macOS build:    ${MACOS_BUILD_TIME}s"
[ "$DEPLOY_ANDROID" = true ] && echo "  🤖 Android build:  ${ANDROID_BUILD_TIME}s"
[ "$DEPLOY_WINDOWS" = true ] && echo "  🪟 Windows:        ${WINDOWS_BUILD_TIME}s (mostly waiting on CI)"
[ "$DEPLOY_LINUX" = true ]   && echo "  🐧 Linux:          ${LINUX_BUILD_TIME}s (mostly waiting on CI)"
[ "$DEPLOY_WEB" = true ]     && echo "  🌐 Web build:      ${WEB_BUILD_TIME}s"
echo "  📊 Total:          ${TOTAL_TIME}s"

# Non-zero here is what makes ANY_STEP_FAILED visible to CI/scripts and to the
# EXIT trap above (which decides whether to revert the version bump).
if [ "$ANY_STEP_FAILED" = true ]; then
    exit 1
fi
