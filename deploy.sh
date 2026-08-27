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
#                       App Store Connect. Same ASC API key as iOS. Not part
#                       of --all yet — run it explicitly until the App Store
#                       Connect side is proven out; see DEPLOY.md.
#   Android  → flutter build appbundle → Google Play internal track
#              (needs a verified Play account; see DEPLOY.md)
#   Web      → --web: flutter build web → rsync to the Oracle VM, served by
#                     Caddy behind cloudflared
#                     (https://monkeyhub.walhallaa.com/web/)
#   Site     → --site: stamp the landing + downloads pages and push them. No
#                      build, so it takes seconds.
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

# ----- self-hosted site (Oracle VM + Caddy + cloudflared) -----
# Override any of these from .env.local if the box or key ever moves.
VM_HOST="${VM_HOST:-79.76.54.204}"
VM_USER="${VM_USER:-ubuntu}"
VM_SSH_KEY="${VM_SSH_KEY:-$HOME/Documents/BelesMakinem/ssh-key-2024-12-04-2.key}"
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
DEPLOY_IOS=""
DEPLOY_MACOS=false # --macos: App Store Connect. NOT in --all yet.
DEPLOY_ANDROID=""
DEPLOY_WEB=false   # --web: flutter build web → VM. Also included by --all.
DEPLOY_SITE=false  # --site: landing + downloads pages. No build. Also by --all.
RUN_UPLOAD=true    # iOS: upload IPA to ASC. Android: AAB to Play. Web: to the VM.
RUN_GIT=true
DRY_RUN=false
PLATFORM_ARGS=false
# Standalone actions: they do their one job and exit, never mixed with a build.
ACTION=""          # "" | infra | rollback-web | set-min-supported
SET_MIN_CHANNEL=""
SET_MIN_VERSION=""

# Per-platform stage sets, space-separated. Empty = "whatever --<platform> or the
# picker asked for", resolved to the full pipeline once DEPLOY_* is final (see
# "stage defaults" below). --<platform>-<stage> flags APPEND to these instead of
# replacing, so e.g. `--ios-export --ios-upload` composes into "export upload"
# and skips only the build+archive stage — this is how a failed-then-retried
# upload resumes without rebuilding. iOS/macOS: archive → export → upload.
# Android/web: build → upload.
IOS_STAGES=""
MACOS_STAGES=""
ANDROID_STAGES=""
WEB_STAGES=""
has_stage() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

print_help() {
    cat <<EOF
Usage: ./deploy.sh [flags]

No platform flags + a terminal → interactive picker (space toggles, enter go).
No platform flags + no TTY     → legacy default: Convex + iOS.

Platform flags (any of these skips the picker):
  --ios                 Ship iOS to App Store Connect.
  --macos               Ship macOS to App Store Connect. Not included in
                        --all yet — see DEPLOY.md.
  --android             Ship Android: AAB to the Google Play internal track.
  --web                 Build Flutter web and publish it at $WEB_URL.
  --site                Landing + downloads pages only. No build — seconds.
  --all                 Convex + iOS + Android + web + site.
  --convex-only         Backend only — no builds, no version bump.
  --no-convex           Skip 'npx convex deploy'.

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
                        android-apk, web. Also reachable from the interactive
                        picker by pressing 'f'.

Per-platform stages: each platform's pipeline is independent stages that can be
run on their own — most useful to resume after a partial failure (e.g. iOS
archived fine but the App Store Connect upload timed out) without redoing the
earlier, already-successful, expensive stages. Combine flags to run more than
one stage (e.g. --ios-export --ios-upload); a bare --ios/--macos/--android/--web
still runs every stage, same as always.
  iOS:      --ios-archive   --ios-export   --ios-upload
  macOS:    --macos-archive --macos-export --macos-upload
  Android:  --android-build --android-upload
  Web:      --web-build     --web-upload
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
  --dry                 --no-convex --no-upload --no-git --skip-version-bump.
  -h, --help            Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-version-bump) SKIP_VERSION_BUMP=true ;;
        --no-convex)         RUN_CONVEX=false ;;
        --no-upload)         RUN_UPLOAD=false ;;
        --no-git)            RUN_GIT=false ;;
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
        --all)               DEPLOY_IOS=true; DEPLOY_ANDROID=true; DEPLOY_WEB=true
                             DEPLOY_SITE=true; PLATFORM_ARGS=true ;;
        # Zeroes web and site too, so "backend only" holds even after --all.
        --convex-only)       RUN_CONVEX=true; DEPLOY_IOS=false; DEPLOY_MACOS=false
                             DEPLOY_ANDROID=false
                             DEPLOY_WEB=false; DEPLOY_SITE=false
                             SKIP_VERSION_BUMP=true; PLATFORM_ARGS=true ;;
        --rollback-web)      ACTION="rollback-web" ;;
        --infra)             ACTION="infra" ;;
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


# Reads back a channel's currently published version, or fails (nothing on
# stdout) if the channel has never been published to. Shared by
# set_min_supported (so a force-update never clobbers `version`, a required
# arg on releases:publish) and the picker's 'f' flow (so "require whatever's
# already live" needs no typing).
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
    if (cd backend && npx convex run releases:publish "$payload" >/dev/null 2>&1); then
        if [ "$min" = "clear" ]; then
            echo "  ✅ Cleared minSupported on $channel (still shipping $version)"
        else
            echo "  ✅ $channel now requires >= $min (still shipping $version) — older clients lose \"Later\""
        fi
    else
        echo "❌ Failed to update $channel. Retry with:"
        echo "     (cd backend && npx convex run releases:publish $(printf '%s' "$payload" | jq -Rr @sh))"
        return 1
    fi
}

case "$ACTION" in
    rollback-web)      rollback_web; exit 0 ;;
    infra)              push_infra;   exit 0 ;;
    set-min-supported)  set_min_supported "$SET_MIN_CHANNEL" "$SET_MIN_VERSION" || exit 1; exit 0 ;;
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
        printf "    %s — pick a stage  (↑/↓ move · enter choose · esc cancel)\033[K\n" "$title"
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

# Checkbox menu on the controlling terminal. Only used when the caller gave no
# platform flags and we actually have a TTY to talk to.
pick_platforms() {
    local labels=("Convex backend" "iOS  → App Store Connect"
                  "macOS → App Store Connect"
                  "Android → Google Play (internal track)"
                  "Web  → $WEB_URL" "Site → $SITE_URL  (pages only, no build)"
                  "Bump version (patch)")
    # Menu starts on Convex only. Unlike --all (which ships everything), the
    # picker leaves the rest unticked so a bare Enter stays cheap and a stray
    # Enter can't kick off an App Store / Play upload by accident.
    local selected=(1 0 0 0 0 0 0)
    # Honor explicit --no-convex / --macos / --web / --site even in interactive mode.
    [ "$RUN_CONVEX" = false ] && selected[0]=0
    [ "$DEPLOY_MACOS" = true ] && selected[2]=1
    [ "$DEPLOY_WEB" = true ] && selected[4]=1
    [ "$DEPLOY_SITE" = true ] && selected[5]=1
    # "Bump version" only does anything once an app platform ships (see
    # "Version bump only makes sense..." below) — a Convex- or Site-only run
    # would show it pre-checked for no reason. It defaults on the moment
    # iOS/macOS/Android is (matching --skip-version-bump's own default: bump
    # unless told not to) and off again the moment none of them are, tracked
    # live as those three rows get toggled — see the space-key handling below.
    # --skip-version-bump always wins, even over a pre-set --macos.
    if [ "$SKIP_VERSION_BUMP" != true ]; then
        { [ "${selected[1]}" = 1 ] || [ "${selected[2]}" = 1 ] || [ "${selected[3]}" = 1 ]; } \
            && selected[6]=1
    fi
    local prev_any_app=false
    { [ "${selected[1]}" = 1 ] || [ "${selected[2]}" = 1 ] || [ "${selected[3]}" = 1 ]; } \
        && prev_any_app=true
    local cursor=0 count=7 extra=2 i marker arrow label
    # Per-platform stage override, set via Tab. Empty = full pipeline. Threaded
    # into IOS_STAGES etc. below once Enter is pressed — see "stage defaults".
    local pstage_ios="" pstage_macos="" pstage_android="" pstage_web=""

    exec 3</dev/tty
    tput civis 2>/dev/null || true
    echo "Select what to deploy  (↑/↓ move · space toggle · enter go · tab stage · f force-update)"
    while true; do
        local skip_erase=false
        for i in $(seq 0 $((count - 1))); do
            [ "${selected[$i]}" = 1 ] && marker="◉" || marker="◯"
            [ "$i" = "$cursor" ] && arrow="❯" || arrow=" "
            label="${labels[$i]}"
            case "$i" in
                1) [ -n "$pstage_ios" ]     && label="$label  [$pstage_ios]" ;;
                2) [ -n "$pstage_macos" ]   && label="$label  [$pstage_macos]" ;;
                3) [ -n "$pstage_android" ] && label="$label  [$pstage_android]" ;;
                4) [ -n "$pstage_web" ]     && label="$label  [$pstage_web]" ;;
            esac
            printf "  %s %s %s\033[K\n" "$arrow" "$marker" "$label"
        done
        printf "\n  [f] Force-update a channel (edit minSupported)…\033[K\n"
        read_key
        if [ "$KEY_KIND" = "UP" ]; then
            cursor=$(( (cursor + count - 1) % count ))
        elif [ "$KEY_KIND" = "DOWN" ]; then
            cursor=$(( (cursor + 1) % count ))
        elif [ "$KEY_KIND" = "ESC" ]; then
            :  # bare Esc on the checklist itself is a no-op
        elif [ "$KEY_KIND" = "PLAIN" ] && [ "$KEY_CHAR" = " " ]; then
            selected[$cursor]=$(( 1 - selected[$cursor] ))
            case "$cursor" in
                1|2|3)
                    local any_app=false
                    { [ "${selected[1]}" = 1 ] || [ "${selected[2]}" = 1 ] || [ "${selected[3]}" = 1 ]; } \
                        && any_app=true
                    if [ "$any_app" = true ] && [ "$prev_any_app" = false ]; then
                        selected[6]=1  # first app platform checked — default the bump back on
                    elif [ "$any_app" = false ]; then
                        selected[6]=0  # no app platform left — bump would be a no-op
                    fi
                    prev_any_app=$any_app
                    ;;
            esac
        elif [ "$KEY_KIND" = "PLAIN" ] && [ "$KEY_CHAR" = $'\t' ]; then
            local choice rc=1
            case "$cursor" in
                1) choice=$(pick_stage_menu "iOS" "full:Full pipeline" "archive:Archive only" \
                                "export:Export only" "upload:Upload only"); rc=$? ;;
                2) choice=$(pick_stage_menu "macOS" "full:Full pipeline" "archive:Archive only" \
                                "export:Export only" "upload:Upload only"); rc=$? ;;
                3) choice=$(pick_stage_menu "Android" "full:Full pipeline" "build:Build only" \
                                "upload:Upload only"); rc=$? ;;
                4) choice=$(pick_stage_menu "Web" "full:Full pipeline" "build:Build only" \
                                "upload:Upload only"); rc=$? ;;
            esac
            if [ "$rc" = 0 ]; then
                [ "$choice" = "full" ] && choice=""
                case "$cursor" in
                    1) pstage_ios="$choice";     selected[1]=1 ;;
                    2) pstage_macos="$choice";   selected[2]=1 ;;
                    3) pstage_android="$choice"; selected[3]=1 ;;
                    4) pstage_web="$choice";     selected[4]=1 ;;
                esac
            fi
        elif [ "$KEY_KIND" = "PLAIN" ] && { [ "$KEY_CHAR" = "f" ] || [ "$KEY_CHAR" = "F" ]; }; then
            # Both steps below are pick_stage_menu, so Esc at either one cancels
            # straight back to this checklist — nothing is printed and nothing
            # needs erasing (pick_stage_menu always cleans up after itself,
            # success or cancel). Only a completed force-update leaves output on
            # screen, which is deliberate: skip_erase leaves it visible above the
            # redrawn checklist instead of scrolling it away unread.
            local fu_channel fu_current fu_action fu_version rc
            fu_channel=$(pick_stage_menu "Force-update which channel?" \
                "ios-testflight:iOS · TestFlight" "macos-testflight:macOS · TestFlight" \
                "android-play:Android · Play" "android-apk:Android · sideloaded APK" \
                "web:Web"); rc=$?
            if [ "$rc" = 0 ]; then
                fu_current=$(channel_current_version "$fu_channel")
                if [ -z "$fu_current" ]; then
                    echo "  ⚠️  No published release for $fu_channel yet — nothing to force."
                    skip_erase=true
                else
                    fu_action=$(pick_stage_menu "Force-update $fu_channel (latest: $fu_current)" \
                        "same:Require $fu_current — forces everyone below it to update now" \
                        "custom:Type a different minimum version" \
                        "clear:Clear the requirement"); rc=$?
                    if [ "$rc" = 0 ]; then
                        case "$fu_action" in
                            same)   set_min_supported "$fu_channel" "$fu_current"; skip_erase=true ;;
                            clear)  set_min_supported "$fu_channel" "clear"; skip_erase=true ;;
                            custom)
                                tput cnorm 2>/dev/null || true
                                IFS= read -rp "  Minimum supported version for $fu_channel (blank cancels): " \
                                    -u3 fu_version
                                tput civis 2>/dev/null || true
                                if [ -n "$fu_version" ]; then
                                    set_min_supported "$fu_channel" "$fu_version"
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
    DEPLOY_WEB=$([ "${selected[4]}" = 1 ] && echo true || echo false)
    DEPLOY_SITE=$([ "${selected[5]}" = 1 ] && echo true || echo false)
    SKIP_VERSION_BUMP=$([ "${selected[6]}" = 1 ] && echo false || echo true)
    [ -n "$pstage_ios" ]     && IOS_STAGES="$pstage_ios"
    [ -n "$pstage_macos" ]   && MACOS_STAGES="$pstage_macos"
    [ -n "$pstage_android" ] && ANDROID_STAGES="$pstage_android"
    [ -n "$pstage_web" ]     && WEB_STAGES="$pstage_web"

    if [ "$RUN_CONVEX" = false ] && [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_MACOS" = false ] \
       && [ "$DEPLOY_ANDROID" = false ] && [ "$DEPLOY_WEB" = false ] && [ "$DEPLOY_SITE" = false ]; then
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
   && [ "$DEPLOY_IOS" != true ] && [ "$DEPLOY_ANDROID" != true ] && [ "$DEPLOY_WEB" != true ]; then
    RUN_CONVEX=false
fi
[ -z "$RUN_CONVEX" ] && RUN_CONVEX=true
[ -z "$DEPLOY_IOS" ] && DEPLOY_IOS=false
[ -z "$DEPLOY_ANDROID" ] && DEPLOY_ANDROID=false
# Version bump only makes sense when an app ships.
if [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_ANDROID" = false ] && [ "$DEPLOY_MACOS" = false ]; then
    SKIP_VERSION_BUMP=true
fi

# ----- stage defaults -----
# DEPLOY_X=true with no stage flags/picker choice means the full pipeline.
[ "$DEPLOY_IOS" = true ]     && [ -z "$IOS_STAGES" ]     && IOS_STAGES="archive export upload"
[ "$DEPLOY_MACOS" = true ]   && [ -z "$MACOS_STAGES" ]   && MACOS_STAGES="archive export upload"
[ "$DEPLOY_ANDROID" = true ] && [ -z "$ANDROID_STAGES" ] && ANDROID_STAGES="build upload"
[ "$DEPLOY_WEB" = true ]     && [ -z "$WEB_STAGES" ]     && WEB_STAGES="build upload"

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
if [ "$RUN_UPLOAD" = true ] && [ "$DEPLOY_WEB" = true ]; then
    DEPLOY_SITE=true
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
echo "  • Web build:        $([ "$DEPLOY_WEB" = true ] && echo yes || echo no)$([ "$DEPLOY_WEB" = true ] && stage_note "$WEB_STAGES" "build upload")"
echo "  • Landing/downloads:$([ "$DEPLOY_SITE" = true ] && echo " yes" || echo " no")"
echo "  • Upload/publish:   $([ "$RUN_UPLOAD" = true ] && echo yes || echo no)"
echo "  • Git commit/push:  $([ "$RUN_GIT" = true ] && echo yes || echo no)"
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
IOS_STATUS="skip"
MACOS_STATUS="skip"
ANDROID_STATUS="skip"
WEB_STATUS="skip"
SITE_STATUS="skip"
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
    if { [ "$DEPLOY_IOS" = true ] || [ "$DEPLOY_MACOS" = true ] || [ "$DEPLOY_ANDROID" = true ]; } \
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
    if [ "$DEPLOY_WEB" = true ] || [ "$DEPLOY_SITE" = true ]; then
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

    convex_deploy() {
        local attempt=1
        while true; do
            if (cd backend && npx convex deploy); then
                return 0
            fi
            if [ "$attempt" -ge 3 ]; then
                echo "   convex deploy failed $attempt times — not transient." >&2
                return 1
            fi
            echo "   convex deploy attempt $attempt failed; retrying in 10s…" >&2
            attempt=$((attempt + 1))
            sleep 10
        done
    }
    run_with_spinner "Deploying Convex backend" convex_deploy || return 1
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
# No --prod, deliberately: this backend is self-hosted (CONVEX_SELF_HOSTED_URL in
# backend/.env.local), so there's one deployment and the CLI already targets the
# same URL the app reads from env.local. --prod is a Convex-cloud concept and
# does not apply here — adding it would break this call, not harden it.
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
    if (cd backend && npx convex run releases:publish "$payload" >/dev/null 2>&1); then
        echo "  ✅ Announced $DISPLAY_VERSION on $channel"
    else
        # The retry line is meant to be copy-pasted, and $payload can contain an
        # apostrophe (APK_MIGRATION_NOTE has two), which would close the shell's
        # single-quoted string early and paste as something that doesn't run.
        # jq's @sh emits the argument already correctly quoted for a shell —
        # surrounding quotes included, hence no '…' around it below.
        local quoted
        quoted=$(printf '%s' "$payload" | jq -Rr @sh)
        echo "  ⚠️  Could not announce $DISPLAY_VERSION on $channel — users won't be prompted."
        echo "     Retry with:  (cd backend && npx convex run releases:publish $quoted)"
    fi
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
# No android-apk row any more: Android ships through Play, and the page carries
# a fixed migration card for it instead of a download button.
platform_meta() {   # $1 = platform key → sets PM_ICON / PM_NAME / PM_KIND / PM_BTN
    case "$1" in
        macos-dmg)   PM_ICON="🖥️"; PM_NAME="macOS";   PM_KIND="DMG"
                     PM_BTN="Download the DMG" ;;
        windows)     PM_ICON="🪟"; PM_NAME="Windows"; PM_KIND="Installer"
                     PM_BTN="Download for Windows" ;;
        linux)       PM_ICON="🐧"; PM_NAME="Linux";   PM_KIND="AppImage"
                     PM_BTN="Download the AppImage" ;;
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

# Expand the template's repeat block once per manifest entry. With no entries
# the MH:EMPTY block stands in, so the page is never a bare heading.
render_downloads() {   # $1 = manifest file, $2 = output html
    local manifest="$1" out="$2"
    local tpl="hosting/downloads.template.html"
    local cards="" key card ver file size updated meta tmp_cards

    for key in $(jq -r 'keys[]' "$manifest"); do
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
        card=${card//__PLAT_ICON__/$PM_ICON}
        card=${card//__PLAT_NAME__/$PM_NAME}
        card=${card//__PLAT_VERSION__/$ver}
        card=${card//__PLAT_HREF__/$file}
        card=${card//__PLAT_BTN__/$PM_BTN}
        card=${card//__PLAT_META__/$meta}
        cards="$cards$card"$'\n'
    done

    tmp_cards=$(mktemp)
    if [ -n "$cards" ]; then
        printf '%s' "$cards" > "$tmp_cards"
    else
        awk '/<!-- MH:EMPTY -->/{f=1;next} /<!-- MH:\/EMPTY -->/{f=0} f' "$tpl" > "$tmp_cards"
    fi

    # Drop everything from MH:CARD to MH:/EMPTY and put the rendered cards there.
    awk -v cardfile="$tmp_cards" '
        /<!-- MH:CARD -->/     { skip=1
                                 while ((getline line < cardfile) > 0) print line
                                 close(cardfile); next }
        /<!-- MH:\/EMPTY -->/  { skip=0; next }
        !skip                  { print }
    ' "$tpl" | sed -e "s/__UPDATED_AT__/$STAMP_DATE/g" | strip_doc > "$out"
    rm -f "$tmp_cards"
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
   && [ "$DEPLOY_WEB" = false ] && [ "$DEPLOY_SITE" = false ]; then
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
            run_with_spinner "Uploading to App Store Connect" \
                xcrun altool --upload-app \
                    --type ios \
                    --file "$IPA_PATH" \
                    --apiKey "$APP_STORE_CONNECT_KEY_ID" \
                    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
                    --apiKeyPath "$P8_FILE_PATH" || return 1

            # TestFlight only. An ASC upload is not a released App Store version, so
            # the ios-appstore row stays where it is until a build is actually
            # approved for sale — see DEPLOY.md for the one-liner that moves it.
            publish_release ios-testflight
            SHIPPED_SOMETHING=true
        else
            echo "⏭️  Skipping App Store Connect upload (--no-upload)"
        fi
    fi

    IOS_END_TIME=$(date +%s)
    IOS_BUILD_TIME=$((IOS_END_TIME - IOS_START_TIME))
    return 0
}
if [ "$DEPLOY_IOS" = true ]; then
    if run_ios; then
        IOS_STATUS="ok"
    else
        IOS_STATUS="failed"
        ANY_STEP_FAILED=true
        echo "  ⚠️  iOS failed — continuing with the rest of the run."
    fi
fi

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
            run_with_spinner "Uploading to App Store Connect" \
                xcrun altool --upload-app \
                    --type macos \
                    --file "$PKG_PATH" \
                    --apiKey "$APP_STORE_CONNECT_KEY_ID" \
                    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
                    --apiKeyPath "$P8_FILE_PATH" || return 1

            publish_release macos-testflight
            SHIPPED_SOMETHING=true
        else
            echo "⏭️  Skipping App Store Connect upload (--no-upload)"
        fi
    fi

    MACOS_END_TIME=$(date +%s)
    MACOS_BUILD_TIME=$((MACOS_END_TIME - MACOS_START_TIME))
    return 0
}
if [ "$DEPLOY_MACOS" = true ]; then
    if run_macos; then
        MACOS_STATUS="ok"
    else
        MACOS_STATUS="failed"
        ANY_STEP_FAILED=true
        echo "  ⚠️  macOS failed — continuing with the rest of the run."
    fi
fi

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
if [ "$DEPLOY_ANDROID" = true ]; then
    if run_android; then
        ANDROID_STATUS="ok"
    else
        ANDROID_STATUS="failed"
        ANY_STEP_FAILED=true
        echo "  ⚠️  Android failed — continuing with the rest of the run."
    fi
fi

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
if [ "$DEPLOY_WEB" = true ]; then
    if run_web; then
        WEB_STATUS="ok"
    else
        WEB_STATUS="failed"
        ANY_STEP_FAILED=true
        echo "  ⚠️  Web failed — continuing with the rest of the run."
    fi
fi

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
if [ "$RUN_GIT" = true ] && [ "$SKIP_VERSION_BUMP" = false ]; then
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
        echo "  ✅ iOS:            App Store Connect (TestFlight shows the build in a few minutes)"
    elif [ "$IOS_STATUS" = ok ]; then
        echo "  ✅ iOS IPA:        $IPA_PATH"
    else
        echo "  ❌ iOS:            failed — retry with --ios-archive / --ios-export / --ios-upload"
    fi
fi
if [ "$DEPLOY_MACOS" = true ]; then
    if [ "$MACOS_STATUS" = ok ] && [ "$RUN_UPLOAD" = true ]; then
        echo "  ✅ macOS:          App Store Connect (TestFlight shows the build in a few minutes)"
    elif [ "$MACOS_STATUS" = ok ]; then
        echo "  ✅ macOS package:  $PKG_PATH"
    else
        echo "  ❌ macOS:          failed — retry with --macos-archive / --macos-export / --macos-upload"
    fi
fi
if [ "$DEPLOY_ANDROID" = true ]; then
    if [ "$ANDROID_STATUS" = ok ]; then
        echo "  ✅ Android AAB:    $AAB_PATH"
        [ "$RUN_UPLOAD" = true ] && echo "     → Play internal track; sideloaders pointed at $HOSTING_URL/"
    else
        echo "  ❌ Android:        failed — retry with --android-build / --android-upload"
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
echo ""
echo "⏱️  Timing:"
[ "$DEPLOY_IOS" = true ]     && echo "  🍎 iOS build:      ${IOS_BUILD_TIME}s"
[ "$DEPLOY_MACOS" = true ]   && echo "  🖥️  macOS build:    ${MACOS_BUILD_TIME}s"
[ "$DEPLOY_ANDROID" = true ] && echo "  🤖 Android build:  ${ANDROID_BUILD_TIME}s"
[ "$DEPLOY_WEB" = true ]     && echo "  🌐 Web build:      ${WEB_BUILD_TIME}s"
echo "  📊 Total:          ${TOTAL_TIME}s"

# Non-zero here is what makes ANY_STEP_FAILED visible to CI/scripts and to the
# EXIT trap above (which decides whether to revert the version bump).
if [ "$ANY_STEP_FAILED" = true ]; then
    exit 1
fi
