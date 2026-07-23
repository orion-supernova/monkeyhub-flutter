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
#   Android  → APK mode:  flutter build apk → Firebase Hosting download page
#                         (https://monkeyhub-2b2c6.web.app)
#            → Play mode: flutter build appbundle → Google Play internal track
#                         (needs verified Play account; see DEPLOY.md)
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

FIREBASE_PROJECT="monkeyhub-2b2c6"
HOSTING_URL="https://monkeyhub-2b2c6.web.app"
ANDROID_PACKAGE="com.walhallaa.chattest20241220"

# ----- flags -----
SKIP_VERSION_BUMP=false
RUN_CONVEX=""      # ""=undecided (menu/default), true/false once resolved
DEPLOY_IOS=""
DEPLOY_ANDROID=""
ANDROID_MODE="apk" # apk | play
RUN_UPLOAD=true    # iOS: upload IPA to ASC. Android APK: deploy to hosting.
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
  --android[=apk|play]  Ship Android. apk (default): signed APK + hosted
                        download page. play: AAB for Google Play internal.
  --all                 Convex + iOS + Android(apk).
  --convex-only         Backend only — no builds, no version bump.
  --no-convex           Skip 'npx convex deploy'.

Behavior flags:
  --skip-version-bump   Re-ship the same version.
  --no-upload           Build/export but skip ASC upload AND hosting deploy.
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
        --all)               DEPLOY_IOS=true; DEPLOY_ANDROID=true; PLATFORM_ARGS=true ;;
        --convex-only)       RUN_CONVEX=true; DEPLOY_IOS=false; DEPLOY_ANDROID=false
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
    local labels=("Convex backend" "iOS  → App Store Connect" "Android")
    local selected=(1 1 0)   # defaults mirror the legacy behavior
    # Honor explicit --no-convex even in interactive mode.
    [ "$RUN_CONVEX" = false ] && selected[0]=0
    local cursor=0 count=3 key rest i marker arrow

    exec 3</dev/tty
    tput civis 2>/dev/null || true
    echo "Select what to deploy  (↑/↓ move · space toggle · enter go)"
    while true; do
        for i in 0 1 2; do
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

    if [ "$DEPLOY_ANDROID" = true ]; then
        pick_android_mode
    fi
    if [ "$RUN_CONVEX" = false ] && [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_ANDROID" = false ]; then
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
            if [ ! -f "hosting/index.template.html" ] || [ ! -f "firebase.json" ]; then
                echo "❌ Hosting files missing (hosting/index.template.html + firebase.json)."
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

# Nothing app-side selected → done after Convex.
if [ "$DEPLOY_IOS" = false ] && [ "$DEPLOY_ANDROID" = false ]; then
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
            flutter build apk --release

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

        echo "  • Staging download page (hosting/public)"
        rm -rf hosting/public
        mkdir -p hosting/public
        cp "$APK_PATH" "hosting/public/monkeyhub-latest.apk"
        cp "$APK_PATH" "hosting/public/monkeyhub-$DISPLAY_VERSION.apk"
        sed -e "s/__APP_VERSION__/$DISPLAY_VERSION/g" \
            -e "s/__APK_SIZE__/${APK_SIZE}B/g" \
            -e "s/__UPDATED_AT__/$STAMP_DATE/g" \
            hosting/index.template.html > hosting/public/index.html

        if [ "$RUN_UPLOAD" = true ]; then
            firebase_deploy() {
                npx --yes firebase-tools deploy --only hosting --project "$FIREBASE_PROJECT" --non-interactive \
                    > /tmp/monkeyhub_firebase_deploy.log 2>&1
            }
            echo "Deploying download page to Firebase Hosting..."
            if firebase_deploy; then
                echo "  ✅ Hosted at $HOSTING_URL"
            else
                if grep -qiE "not logged in|authentication|credential|login" /tmp/monkeyhub_firebase_deploy.log; then
                    echo "❌ Firebase Hosting deploy failed — not logged in."
                    echo "   One-time fix:  npx firebase-tools login"
                    echo "   Then re-run:   ./deploy.sh --android=apk --skip-version-bump --no-convex"
                else
                    echo "❌ Firebase Hosting deploy failed. Log:"
                    echo "   /tmp/monkeyhub_firebase_deploy.log"
                fi
                exit 1
            fi
        else
            echo "⏭️  Skipping hosting deploy (--no-upload). Page staged in hosting/public/."
        fi

    else
        echo "🤖 Starting Android build (AAB → Google Play)..."
        run_with_spinner "Building Flutter app bundle (release)" \
            flutter build appbundle --release

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
echo ""
echo "⏱️  Timing:"
[ "$DEPLOY_IOS" = true ]     && echo "  🍎 iOS build:      ${IOS_BUILD_TIME}s"
[ "$DEPLOY_ANDROID" = true ] && echo "  🤖 Android build:  ${ANDROID_BUILD_TIME}s"
echo "  📊 Total:          ${TOTAL_TIME}s"
