#!/bin/bash
# MonkeyHub deploy script (iOS + Convex backend).
#
# Default behavior: deploy Convex backend → flutter clean/get → bump pubspec
# patch version → pod install → flutter build iOS → xcodebuild archive + export
# → upload to App Store Connect → commit + push the version bump.
#
# Run-and-ship: ./deploy.sh
# See ./deploy.sh -h for flags.
#
# IMPORTANT — two similarly-named files at project root:
#   env.local   (no dot)  → runtime app secrets (CONVEX_URL, ONESIGNAL_APP_ID).
#                           Bundled into the IPA via pubspec assets — DO NOT put
#                           deploy secrets here.
#   .env.local  (with dot) → deploy-only secrets (App Store Connect API key).
#                           NOT bundled. This script reads from here.

set -uo pipefail

SCRIPT_START_TIME=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ----- flags -----
SKIP_VERSION_BUMP=false
RUN_CONVEX=true
RUN_UPLOAD=true
RUN_GIT=true
DRY_RUN=false

print_help() {
    cat <<EOF
Usage: ./deploy.sh [flags]

Default (no flags): full ship — Convex deploy + version bump + iOS build +
ASC upload + git push.

Flags:
  --skip-version-bump   Re-ship the same version (e.g. after fixing a build issue).
  --no-convex           Skip 'npx convex deploy' (run from backend/).
  --no-upload           Archive + export the IPA but do NOT upload to App Store Connect.
  --no-git              Don't commit/push the version bump.
  --dry                 Same as --no-convex --no-upload --no-git --skip-version-bump.
                        Use this to test the build path end-to-end without side effects.
  -h, --help            Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-version-bump) SKIP_VERSION_BUMP=true ;;
        --no-convex)         RUN_CONVEX=false ;;
        --no-upload)         RUN_UPLOAD=false ;;
        --no-git)            RUN_GIT=false ;;
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

echo "🐵 MonkeyHub deploy"
echo "  • Convex deploy:    $([ "$RUN_CONVEX" = true ] && echo yes || echo no)"
echo "  • Version bump:     $([ "$SKIP_VERSION_BUMP" = false ] && echo yes || echo no)"
echo "  • iOS build:        yes"
echo "  • Upload to ASC:    $([ "$RUN_UPLOAD" = true ] && echo yes || echo no)"
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

    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ deploy.sh is iOS-only and must run on macOS."
        exit 1
    fi

    # Runtime app secrets — bundled into the IPA. Build will silently miss
    # CONVEX_URL / ONESIGNAL_APP_ID if this is absent.
    if [ ! -f "env.local" ]; then
        echo "❌ Missing env.local at project root (runtime app secrets)."
        echo "   Copy env.example to env.local and fill in values."
        exit 1
    fi

    # Deploy-only secrets — NOT bundled. Note the leading dot.
    if [ ! -f ".env.local" ]; then
        echo "❌ Missing .env.local at project root (deploy secrets)."
        echo "   Create it with:"
        echo "     APP_STORE_CONNECT_KEY_ID=<10-char key id>"
        echo "     APP_STORE_CONNECT_ISSUER_ID=<uuid>"
        echo "   ⚠️  Note the leading dot — .env.local (deploy) is distinct from"
        echo "       env.local (runtime, bundled into the IPA)."
        exit 1
    fi

    load_env_file .env.local

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
        # deploy file). Spygame keeps Convex at root; MonkeyHub keeps it under
        # backend/, so we don't validate against root paths.
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

    # ASC creds are needed for BOTH archive/export (xcodebuild auth, so it can
    # fetch the Distribution cert + provisioning profile without a logged-in
    # Xcode account) AND the upload step. So validate unconditionally — even
    # --no-upload still needs them to sign the archive.
    check_key APP_STORE_CONNECT_KEY_ID
    check_key APP_STORE_CONNECT_ISSUER_ID

    # Directory holding the .p8. Override APP_STORE_CONNECT_KEY_DIR in
    # .env.local if your key isn't at the default path (e.g. when juggling
    # keys across multiple Apple Developer teams).
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

    echo "  ✅ Environment OK"
}

validate_environment

# ----- Convex deploy -----
# IMPORTANT: must run from backend/ — MonkeyHub's convex/ lives there, not at
# the project root. Running from root would fail because there's no convex.json
# / convex/ at root.
if [ "$RUN_CONVEX" = true ]; then
    convex_deploy() { (cd backend && npx convex deploy); }
    run_with_spinner "Deploying Convex backend" convex_deploy
fi

# ----- Flutter prep -----
run_with_spinner "Flutter clean" flutter clean
run_with_spinner "Flutter pub get" flutter pub get

# ----- Version bump -----
# MonkeyHub bumps only the patch (1.3.11 → 1.3.12); the +B suffix stays pinned
# at +1. (Spygame bumps both — MonkeyHub treats the patch as the user-facing
# build number.)
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

# ----- iOS build -----
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

# Refreshes Generated.xcconfig with the current pubspec version. Runtime keys
# (CONVEX_URL, ONESIGNAL_APP_ID) ride along via the bundled env.local asset, so
# no --dart-define flags are needed.
run_with_spinner "Building Flutter for iOS (release)" \
    flutter build ios --release --no-codesign

# -authenticationKey* lets xcodebuild fetch the Distribution cert + provisioning
# profile via the App Store Connect API, so this works on a machine with no
# Xcode account configured. Without these flags, exportArchive fails with
# "No signing certificate 'iOS Distribution' found / No Accounts" and retries
# until it gives up.
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

# The IPA is named after CFBundleName, not PRODUCT_NAME, so we glob for it
# rather than hardcoding "Runner.ipa".
IPA_PATH="$(find build/ios -maxdepth 1 -type f -name '*.ipa' | head -n 1)"
if [ -z "$IPA_PATH" ] || [ ! -f "$IPA_PATH" ]; then
    echo "❌ No .ipa found in build/ios/ after export"
    ls -la build/ios/ || true
    exit 1
fi
echo "  ✅ IPA at $IPA_PATH"

# ----- Upload -----
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
[ "$RUN_UPLOAD" = true ] && echo "  🍎 Uploaded to:    App Store Connect (TestFlight will show the build in a few minutes)"
[ "$RUN_UPLOAD" = false ] && echo "  📦 IPA available:  $IPA_PATH"
echo ""
echo "⏱️  Timing:"
echo "  🍎 iOS build:      ${IOS_BUILD_TIME}s"
echo "  📊 Total:          ${TOTAL_TIME}s"
