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
#   Android  → APK mode:  flutter build apk → rsync to the Oracle VM, served by
#                         Caddy behind cloudflared
#                         (https://monkeyhub.walhallaa.com/download)
#            → Play mode: flutter build appbundle → Google Play internal track
#                         (needs verified Play account; see DEPLOY.md)
#   Web      → --web: flutter build web → rsync to the same VM, served at
#                     https://monkeyhub.walhallaa.com/
#
# The APK used to live on Firebase Hosting; the Spark (free) plan refuses to
# serve executables ("Executable files are forbidden on the Spark billing plan"),
# so Android distribution moved to the self-hosted VM. See DEPLOY.md.
#
# IMPORTANT — two similarly-named files at project root:
#   env.local   (no dot)  → runtime app secrets (CONVEX_URL, ONESIGNAL_APP_ID).
#                           Bundled into the app via pubspec assets — DO NOT put
#                           deploy secrets here.
#   .env.local  (with dot) → deploy-only secrets (App Store Connect API key,
#                           optional PLAY_SERVICE_ACCOUNT_JSON). NOT bundled.

set -uo pipefail

SCRIPT_START_TIME=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ANDROID_PACKAGE="com.walhallaa.chattest20241220"

# ----- self-hosted download page (Oracle VM + Caddy + cloudflared) -----
# Override any of these from .env.local if the box or key ever moves.
VM_HOST="${VM_HOST:-79.76.54.204}"
VM_USER="${VM_USER:-ubuntu}"
VM_SSH_KEY="${VM_SSH_KEY:-$HOME/Documents/BelesMakinem/ssh-key-2024-12-04-2.key}"
VM_APK_DIR="/srv/monkeyhub/download"
VM_WEB_DIR="/srv/monkeyhub/web"
HOSTING_URL="https://monkeyhub.walhallaa.com/download"
WEB_URL="https://monkeyhub.walhallaa.com"

# ----- flags -----
SKIP_VERSION_BUMP=false
RUN_CONVEX=""      # ""=undecided (menu/default), true/false once resolved
DEPLOY_IOS=""
DEPLOY_ANDROID=""
ANDROID_MODE="apk" # apk | play
DEPLOY_WEB=false   # --web: flutter build web → VM. Also included by --all.
RUN_UPLOAD=true    # iOS: upload IPA to ASC. Android APK / web: rsync to the VM.
RUN_GIT=true
DRY_RUN=false
PLATFORM_ARGS=false

print_help() {
    cat <<EOF
Usage: ./deploy.sh [flags]

No platform flags + a terminal → interactive picker (space toggles, enter go).
No platform flags + no TTY     → legacy default: Convex + iOS.

Platform flags (any of these skips the picker):
  --ios                 Ship iOS to App Store Connect.
  --android[=apk|play]  Ship Android. apk (default): signed APK + self-hosted
                        download page. play: AAB for Google Play internal.
  --web                 Build Flutter web and publish it at $WEB_URL.
  --all                 Convex + iOS + Android(apk) + web.
  --convex-only         Backend only — no builds, no version bump.
  --no-convex           Skip 'npx convex deploy'.

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
        --android)           DEPLOY_ANDROID=true; PLATFORM_ARGS=true ;;
        --android=apk)       DEPLOY_ANDROID=true; ANDROID_MODE="apk";  PLATFORM_ARGS=true ;;
        --android=play)      DEPLOY_ANDROID=true; ANDROID_MODE="play"; PLATFORM_ARGS=true ;;
        --web)               DEPLOY_WEB=true; PLATFORM_ARGS=true ;;
        --all)               DEPLOY_IOS=true; DEPLOY_ANDROID=true; DEPLOY_WEB=true
                             PLATFORM_ARGS=true ;;
        # Zeroes web too, so "backend only" holds even after --all or --web.
        --convex-only)       RUN_CONVEX=true; DEPLOY_IOS=false; DEPLOY_ANDROID=false
                             DEPLOY_WEB=false
                             SKIP_VERSION_BUMP=true; PLATFORM_ARGS=true ;;
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

# ----- interactive platform picker -----
# Checkbox menu on the controlling terminal. Only used when the caller gave no
# platform flags and we actually have a TTY to talk to.
pick_platforms() {
    local labels=("Convex backend" "iOS  → App Store Connect" "Android" "Web  → $WEB_URL")
    # Menu starts on Convex + iOS only. Unlike --all (which now ships web too),
    # the picker leaves Android and Web unticked so a bare Enter stays cheap.
    local selected=(1 1 0 0)
    # Honor explicit --no-convex / --web even in interactive mode.
    [ "$RUN_CONVEX" = false ] && selected[0]=0
    [ "$DEPLOY_WEB" = true ] && selected[3]=1
    local cursor=0 count=4 key rest i marker arrow

    exec 3</dev/tty
    tput civis 2>/dev/null || true
    echo "Select what to deploy  (↑/↓ move · space toggle · enter go)"
    while true; do
        for i in 0 1 2 3; do
            [ "${selected[$i]}" = 1 ] && marker="◉" || marker="◯"
            [ "$i" = "$cursor" ] && arrow="❯" || arrow=" "
            printf "  %s %s %s\033[K\n" "$arrow" "$marker" "${labels[$i]}"
        done
        IFS= read -rsn1 -u3 key
        if [ "$key" = $'\x1b' ]; then
            # -t 1: a bare ESC press must not hang (macOS bash 3.2 has no
            # fractional read timeouts).
            IFS= read -rsn2 -t 1 -u3 rest || rest=""
            case "$rest" in
                "[A") cursor=$(( (cursor + count - 1) % count )) ;;
                "[B") cursor=$(( (cursor + 1) % count )) ;;
            esac
        elif [ "$key" = " " ]; then
            selected[$cursor]=$(( 1 - selected[$cursor] ))
        elif [ -z "$key" ]; then  # enter
            break
        fi
        tput cuu $count 2>/dev/null
    done
    tput cnorm 2>/dev/null || true
    exec 3<&-

    RUN_CONVEX=$([ "${selected[0]}" = 1 ] && echo true || echo false)
    DEPLOY_IOS=$([ "${selected[1]}" = 1 ] && echo true || echo false)
    DEPLOY_ANDROID=$([ "${selected[2]}" = 1 ] && echo true || echo false)
    DEPLOY_WEB=$([ "${selected[3]}" = 1 ] && echo true || echo false)

    if [ "$DEPLOY_ANDROID" = true ]; then
        pick_android_mode
    fi
    if [ "$RUN_CONVEX" = false ] && [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_ANDROID" = false ] && [ "$DEPLOY_WEB" = false ]; then
        echo "Nothing selected — exiting."
        exit 0
    fi
}

pick_android_mode() {
    local labels=("APK  → hosted download page ($HOSTING_URL)"
                  "AAB  → Google Play, internal testing track")
    local cursor=0 key rest i arrow
    [ "$ANDROID_MODE" = "play" ] && cursor=1

    exec 3</dev/tty
    tput civis 2>/dev/null || true
    echo ""
    echo "Android delivery  (↑/↓ move · enter select)"
    while true; do
        for i in 0 1; do
            [ "$i" = "$cursor" ] && arrow="❯" || arrow=" "
            printf "  %s %s\033[K\n" "$arrow" "${labels[$i]}"
        done
        IFS= read -rsn1 -u3 key
        if [ "$key" = $'\x1b' ]; then
            IFS= read -rsn2 -t 1 -u3 rest || rest=""
            case "$rest" in
                "[A"|"[B") cursor=$(( 1 - cursor )) ;;
            esac
        elif [ -z "$key" ] || [ "$key" = " " ]; then
            break
        fi
        tput cuu 2 2>/dev/null
    done
    tput cnorm 2>/dev/null || true
    exec 3<&-
    ANDROID_MODE=$([ "$cursor" = 0 ] && echo apk || echo play)
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
[ -z "$RUN_CONVEX" ] && RUN_CONVEX=true
[ -z "$DEPLOY_IOS" ] && DEPLOY_IOS=false
[ -z "$DEPLOY_ANDROID" ] && DEPLOY_ANDROID=false
# Version bump only makes sense when an app ships.
if [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_ANDROID" = false ]; then
    SKIP_VERSION_BUMP=true
fi

echo ""
echo "🐵 MonkeyHub deploy"
echo "  • Convex deploy:    $([ "$RUN_CONVEX" = true ] && echo yes || echo no)"
echo "  • Version bump:     $([ "$SKIP_VERSION_BUMP" = false ] && echo yes || echo no)"
echo "  • iOS build:        $([ "$DEPLOY_IOS" = true ] && echo yes || echo no)"
if [ "$DEPLOY_ANDROID" = true ]; then
    echo "  • Android build:    yes ($ANDROID_MODE)"
else
    echo "  • Android build:    no"
fi
echo "  • Web build:        $([ "$DEPLOY_WEB" = true ] && echo yes || echo no)"
echo "  • Upload/publish:   $([ "$RUN_UPLOAD" = true ] && echo yes || echo no)"
echo "  • Git commit/push:  $([ "$RUN_GIT" = true ] && echo yes || echo no)"
[ "$DRY_RUN" = true ] && echo "  • Mode: DRY (no side effects)"
echo ""

# ----- spinner helpers -----
function finish { tput cnorm 2>/dev/null || true; }
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
        exit $exit_code
    fi
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

# ----- environment validation -----
validate_environment() {
    echo "🔐 Validating environment..."

    if [ "$DEPLOY_IOS" = true ] && [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ The iOS pipeline needs macOS (xcodebuild). Deselect iOS or run on a Mac."
        exit 1
    fi

    # Runtime app secrets — bundled into the app. Builds silently miss
    # CONVEX_URL / ONESIGNAL_APP_ID if this is absent.
    if { [ "$DEPLOY_IOS" = true ] || [ "$DEPLOY_ANDROID" = true ]; } && [ ! -f "env.local" ]; then
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

    if [ "$DEPLOY_IOS" = true ]; then
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
        # the upload step, so validate even with --no-upload.
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
        ensure_export_options
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
        if [ "$ANDROID_MODE" = "apk" ]; then
            if [ ! -f "hosting/index.template.html" ] || [ ! -f "hosting/root.template.html" ]; then
                echo "❌ Page templates missing (hosting/index.template.html + hosting/root.template.html)."
                exit 1
            fi
        fi
    fi

    # The VM serves both the APK page and the web build — prove it's reachable
    # BEFORE burning 15 minutes on a build we then can't publish.
    if { [ "$DEPLOY_ANDROID" = true ] && [ "$ANDROID_MODE" = "apk" ]; } || [ "$DEPLOY_WEB" = true ]; then
        if [ "$RUN_UPLOAD" = true ]; then
            if [ ! -f "$VM_SSH_KEY" ]; then
                echo "❌ VM SSH key not found: $VM_SSH_KEY"
                echo "   Set VM_SSH_KEY in .env.local if the key lives elsewhere."
                exit 1
            fi
            if ! ssh -i "$VM_SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 \
                     -o StrictHostKeyChecking=accept-new "$VM_USER@$VM_HOST" true 2>/dev/null; then
                echo "❌ Can't reach $VM_USER@$VM_HOST over SSH."
                echo "   Check the box is up and the key is authorized, then re-run."
                exit 1
            fi
        fi
    fi

    echo "  ✅ Environment OK"
}

validate_environment

# ----- Convex deploy -----
# IMPORTANT: must run from backend/ — MonkeyHub's convex/ lives there.
if [ "$RUN_CONVEX" = true ]; then
    convex_deploy() { (cd backend && npx convex deploy); }
    run_with_spinner "Deploying Convex backend" convex_deploy
fi

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
# $2 (updateUrl) is optional; omitting it leaves whatever is already stored,
# so a hand-set store link or minSupported survives the next deploy.
publish_release() {   # $1 = channel, $2 = updateUrl (optional)
    local channel="$1"
    local update_url="${2:-}"
    # Deliberately NOT gated on --no-convex. That flag means "don't push backend
    # code", not "don't record what shipped" — and the retry line this script
    # prints after a failed upload recommends --no-convex, which is exactly when
    # a silent skip would hurt. Every call site already sits inside a
    # RUN_UPLOAD=true branch, so --no-upload and --dry never reach here.
    local payload="{\"channel\":\"$channel\",\"version\":\"$DISPLAY_VERSION\""
    [ -n "$update_url" ] && payload="$payload,\"updateUrl\":\"$update_url\""
    payload="$payload}"
    if (cd backend && npx convex run releases:publish "$payload" >/dev/null 2>&1); then
        echo "  ✅ Announced $DISPLAY_VERSION on $channel"
    else
        echo "  ⚠️  Could not announce $DISPLAY_VERSION on $channel — users won't be prompted."
        echo "     Retry with:  (cd backend && npx convex run releases:publish '$payload')"
    fi
}

# Nothing app-side selected → done after Convex.
if [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_ANDROID" = false ] && [ "$DEPLOY_WEB" = false ]; then
    echo ""
    echo "✨ Backend-only deploy complete"
    exit 0
fi

# ----- Flutter prep -----
run_with_spinner "Flutter clean" flutter clean
run_with_spinner "Flutter pub get" flutter pub get

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
    echo "  ✅ pubspec.yaml updated"
else
    NEW_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
    echo "⏭️  Skipping version bump — using $NEW_VERSION"
fi
DISPLAY_VERSION="${NEW_VERSION%%+*}"

# ----- iOS build -----
IOS_BUILD_TIME=0
if [ "$DEPLOY_IOS" = true ]; then
    IOS_START_TIME=$(date +%s)
    echo "🍎 Starting iOS build..."

    echo "  • CocoaPods install"
    (
        cd ios
        pod install >/tmp/monkeyhub_pod_install.log 2>&1
        POD_STATUS=$?
        if [ $POD_STATUS -ne 0 ]; then
            echo "  ⚠️  pod install failed, retrying after 'pod repo update'..."
            pod repo update >/tmp/monkeyhub_pod_repo_update.log 2>&1
            pod install >/tmp/monkeyhub_pod_install_retry.log 2>&1
            POD_STATUS=$?
        fi
        if [ $POD_STATUS -ne 0 ]; then
            echo "❌ CocoaPods install failed. Logs:"
            echo "   /tmp/monkeyhub_pod_install.log"
            echo "   /tmp/monkeyhub_pod_repo_update.log"
            echo "   /tmp/monkeyhub_pod_install_retry.log"
            exit 1
        fi
    )
    echo "  ✅ Pods installed"

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
        flutter build ios --release --no-codesign

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
            -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"

    run_with_spinner "Exporting IPA" \
        env PATH="/usr/bin:$PATH" xcodebuild -exportArchive \
            -archivePath build/Runner.xcarchive \
            -exportPath build/ios \
            -exportOptionsPlist ios/ExportOptions.plist \
            -allowProvisioningUpdates \
            -authenticationKeyPath "$P8_FILE_PATH" \
            -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
            -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"

    # The IPA is named after CFBundleName, not PRODUCT_NAME, so glob for it.
    IPA_PATH="$(find build/ios -maxdepth 1 -type f -name '*.ipa' | head -n 1)"
    if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
        echo "❌ No .ipa found in build/ios/ after export"
        ls -la build/ios/ || true
        exit 1
    fi
    echo "  ✅ IPA at $IPA_PATH"

    if [ "$RUN_UPLOAD" = true ]; then
        run_with_spinner "Uploading to App Store Connect" \
            xcrun altool --upload-app \
                --type ios \
                --file "$IPA_PATH" \
                --apiKey "$APP_STORE_CONNECT_KEY_ID" \
                --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID" \
                --apiKeyPath "$P8_FILE_PATH"

        # TestFlight only. An ASC upload is not a released App Store version, so
        # the ios-appstore row stays where it is until a build is actually
        # approved for sale — see DEPLOY.md for the one-liner that moves it.
        publish_release ios-testflight
    else
        echo "⏭️  Skipping App Store Connect upload (--no-upload)"
    fi

    IOS_END_TIME=$(date +%s)
    IOS_BUILD_TIME=$((IOS_END_TIME - IOS_START_TIME))
fi

# ----- Android build -----
ANDROID_BUILD_TIME=0
APK_PATH=""
AAB_PATH=""
if [ "$DEPLOY_ANDROID" = true ]; then
    ANDROID_START_TIME=$(date +%s)

    if [ "$ANDROID_MODE" = "apk" ]; then
        echo "🤖 Starting Android build (APK → hosted download page)..."
        run_with_spinner "Building Flutter APK (release)" \
            flutter build apk --release --dart-define=MH_CHANNEL=android-apk

        APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
        if [ ! -f "$APK_PATH" ]; then
            echo "❌ No APK at $APK_PATH after build"
            exit 1
        fi

        # Refuse to ship a debug-signed APK — build.gradle.kts silently falls
        # back to the debug key when android/key.properties is missing.
        SIGNER_CERT=$(keytool -printcert -jarfile "$APK_PATH" 2>/dev/null | grep -m1 "Owner:")
        if echo "$SIGNER_CERT" | grep -q "Android Debug"; then
            echo "❌ APK is DEBUG-signed ($SIGNER_CERT)."
            echo "   Check android/key.properties + keystore, then rebuild."
            exit 1
        fi
        echo "  ✅ Signed by: ${SIGNER_CERT#Owner: }"

        APK_SIZE=$(du -h "$APK_PATH" | cut -f1 | tr -d ' ')
        STAMP_DATE=$(date '+%b %d, %Y')

        # One APK copy only — the versioned filename is created server-side as a
        # hardlink, so the 163MB goes over the wire once.
        echo "  • Staging download page (hosting/public)"
        rm -rf hosting/public
        mkdir -p hosting/public
        cp "$APK_PATH" "hosting/public/monkeyhub-latest.apk"
        sed -e "s/__APP_VERSION__/$DISPLAY_VERSION/g" \
            -e "s/__APK_SIZE__/${APK_SIZE}B/g" \
            -e "s/__UPDATED_AT__/$STAMP_DATE/g" \
            -e "s/__APK_FILE__/monkeyhub-$DISPLAY_VERSION.apk/g" \
            hosting/index.template.html > hosting/public/index.html

        if [ "$RUN_UPLOAD" = true ]; then
            SSH_OPTS="-i $VM_SSH_KEY -o BatchMode=yes -o ConnectTimeout=15"
            upload_apk() {
                rsync -a --partial --progress -e "ssh $SSH_OPTS" \
                    hosting/public/index.html hosting/public/monkeyhub-latest.apk \
                    "$VM_USER@$VM_HOST:$VM_APK_DIR/" || return 1
                # Retention: latest only. Drop previous versioned APKs, then
                # hardlink the new one so /download/monkeyhub-<v>.apk works
                # (versioned URL = cache-bust; Cloudflare overrides our
                # no-cache on .apk with a 4h browser TTL).
                ssh $SSH_OPTS "$VM_USER@$VM_HOST" \
                    "cd $VM_APK_DIR \
                     && find . -maxdepth 1 -name 'monkeyhub-*.apk' ! -name 'monkeyhub-latest.apk' -delete \
                     && ln -f monkeyhub-latest.apk 'monkeyhub-$DISPLAY_VERSION.apk' \
                     && chmod 644 *.apk index.html"
            }
            echo "Uploading download page to $VM_HOST (${APK_SIZE}B)..."
            if upload_apk; then
                echo "  ✅ Hosted at $HOSTING_URL"
                # The page always links the current versioned APK, so this URL
                # stays correct without the client knowing the filename.
                publish_release android-apk "$HOSTING_URL"
            else
                echo "❌ Upload to $VM_USER@$VM_HOST failed."
                echo "   Check: ssh -i $VM_SSH_KEY $VM_USER@$VM_HOST"
                echo "   Then re-run:   ./deploy.sh --android=apk --skip-version-bump --no-convex"
                exit 1
            fi

            # Keep the root landing page in place until a real web build exists.
            # Match the web-build validation: modern Flutter web may emit
            # flutter_bootstrap.js instead of main.dart.js.
            ssh $SSH_OPTS "$VM_USER@$VM_HOST" "[ -f $VM_WEB_DIR/main.dart.js ] || [ -f $VM_WEB_DIR/flutter_bootstrap.js ]" 2>/dev/null \
                || scp $SSH_OPTS hosting/root.template.html \
                       "$VM_USER@$VM_HOST:$VM_WEB_DIR/index.html" > /dev/null
        else
            echo "⏭️  Skipping VM upload (--no-upload). Page staged in hosting/public/."
        fi

    else
        echo "🤖 Starting Android build (AAB → Google Play)..."
        run_with_spinner "Building Flutter app bundle (release)" \
            flutter build appbundle --release --dart-define=MH_CHANNEL=android-play

        AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
        if [ ! -f "$AAB_PATH" ]; then
            echo "❌ No AAB at $AAB_PATH after build"
            exit 1
        fi
        echo "  ✅ AAB at $AAB_PATH"

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
                    --skip_upload_metadata --skip_upload_images --skip_upload_screenshots
            # run_with_spinner exits on failure, so reaching here means the
            # internal track has the build.
            publish_release android-play
        else
            echo "⏭️  No automated Play upload (needs PLAY_SERVICE_ACCOUNT_JSON in"
            echo "    .env.local + fastlane + a verified Play account — see DEPLOY.md)."
            echo "    Upload manually: Play Console → MonkeyHub → Internal testing →"
            echo "    Create release → drop in $AAB_PATH"
        fi
    fi

    ANDROID_END_TIME=$(date +%s)
    ANDROID_BUILD_TIME=$((ANDROID_END_TIME - ANDROID_START_TIME))
fi

# ----- Web build (--web, or as part of --all) -----
# Replaces the placeholder landing page at $WEB_URL.
#
# One standing limitation, not a caveat about maturity: the native call UI
# (flutter_callkit_incoming) is mobile-only, so a browser gets no CallKit /
# ConnectionService ringing.
WEB_BUILD_TIME=0
if [ "$DEPLOY_WEB" = true ]; then
    WEB_START_TIME=$(date +%s)
    echo "🌐 Starting web build..."
    run_with_spinner "Building Flutter web (release)" \
        flutter build web --release --dart-define=MH_CHANNEL=web

    if [ ! -f "build/web/main.dart.js" ] && [ ! -f "build/web/flutter_bootstrap.js" ]; then
        echo "❌ No web build output at build/web/"
        exit 1
    fi

    if [ "$RUN_UPLOAD" = true ]; then
        WEB_SSH_OPTS="-i $VM_SSH_KEY -o BatchMode=yes -o ConnectTimeout=15"
        if rsync -a --delete -e "ssh $WEB_SSH_OPTS" \
                build/web/ "$VM_USER@$VM_HOST:$VM_WEB_DIR/"; then
            echo "  ✅ Web app at $WEB_URL"
            # A tab left open for days keeps running the build it loaded, so a
            # long-lived session still needs telling. The prompt reloads rather
            # than navigating anywhere.
            publish_release web
        else
            echo "❌ Web upload to $VM_USER@$VM_HOST failed."
            exit 1
        fi
    else
        echo "⏭️  Skipping web upload (--no-upload). Build in build/web/."
    fi

    WEB_END_TIME=$(date +%s)
    WEB_BUILD_TIME=$((WEB_END_TIME - WEB_START_TIME))
fi

# ----- Git -----
if [ "$RUN_GIT" = true ] && [ "$SKIP_VERSION_BUMP" = false ]; then
    echo "🔄 Git commit + push..."
    if [ -n "$(git status --porcelain pubspec.yaml)" ]; then
        git add pubspec.yaml
        git commit -m "chore: bump version to $NEW_VERSION"
        CURRENT_BRANCH=$(git branch --show-current)
        echo "  • Pushing to origin/$CURRENT_BRANCH..."
        if git push origin "$CURRENT_BRANCH"; then
            echo "  ✅ Pushed"
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

echo ""
echo "✨ Deploy complete"
echo "  📱 Version:        $NEW_VERSION"
if [ "$DEPLOY_IOS" = true ]; then
    [ "$RUN_UPLOAD" = true ]  && echo "  🍎 iOS:            App Store Connect (TestFlight shows the build in a few minutes)"
    [ "$RUN_UPLOAD" = false ] && echo "  🍎 iOS IPA:        $IPA_PATH"
fi
if [ "$DEPLOY_ANDROID" = true ] && [ "$ANDROID_MODE" = "apk" ]; then
    [ "$RUN_UPLOAD" = true ]  && echo "  🤖 Android:        $HOSTING_URL  (share this link)"
    [ "$RUN_UPLOAD" = false ] && echo "  🤖 Android APK:    $APK_PATH"
fi
if [ "$DEPLOY_ANDROID" = true ] && [ "$ANDROID_MODE" = "play" ]; then
    echo "  🤖 Android AAB:    $AAB_PATH"
fi
if [ "$DEPLOY_WEB" = true ]; then
    [ "$RUN_UPLOAD" = true ]  && echo "  🌐 Web:            $WEB_URL"
    [ "$RUN_UPLOAD" = false ] && echo "  🌐 Web build:      build/web/"
fi
echo ""
echo "⏱️  Timing:"
[ "$DEPLOY_IOS" = true ]     && echo "  🍎 iOS build:      ${IOS_BUILD_TIME}s"
[ "$DEPLOY_ANDROID" = true ] && echo "  🤖 Android build:  ${ANDROID_BUILD_TIME}s"
[ "$DEPLOY_WEB" = true ]     && echo "  🌐 Web build:      ${WEB_BUILD_TIME}s"
echo "  📊 Total:          ${TOTAL_TIME}s"
