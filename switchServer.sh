#!/bin/bash
# Move every MonkeyHub client between the two deployments.
#
#   ./switchServer.sh              pick interactively
#   ./switchServer.sh homeserver   move traffic to the home server
#   ./switchServer.sh primary      bring everyone back to the VPS
#   ./switchServer.sh status       show where both stand, change nothing
#
# The app asks `serverDirectory:current` before it opens a socket and then
# subscribes to it, so flipping the row moves people within a second — no
# relaunch, no rebuild. See backend/convex/serverDirectory.ts.
#
# ───────── why this writes BOTH deployments ─────────
#
# Clients ask the VPS first, so the VPS row is what actually moves anybody.
# The home server's copy matters in exactly one case: a client that is already
# on the home server while the VPS is unreachable falls back to asking the home
# server, and one still saying "homeserver" there would keep precisely the
# clients that listened to you. Doing it by hand twice is the kind of thing that
# gets forgotten once and strands people, which is the whole reason this file
# exists.
#
# ───────── why the order is home server, then VPS ─────────
#
# The VPS is the trigger: it is what clients read. Writing the home server first
# means that by the moment the VPS says "go", the destination already agrees —
# so nobody arrives somewhere that immediately tells them to leave again.
# Reversing it produces exactly that flap on the return leg, where the clients
# being recalled are the ones subscribed to the home server's row.
#
# ───────── credentials ─────────
#
# VPS:         backend/.env.local, same as deploy.sh. Nothing to pass.
# Home server: minted over SSH on demand (`generate_admin_key.sh` inside the
#              backend container) and never written to disk. There is no source
#              checkout on that box and there does not need to be — a restore
#              brings back DATA; functions arrive by `npx convex deploy`.

set -uo pipefail

# ───────── configuration ─────────

readonly HS_HOST="monkeyhub-homeserver-api.walhallaa.com"
readonly HS_URL="https://${HS_HOST}"
# Reached over Tailscale, not the LAN. The old 192.168.68.107 address only
# resolves from inside the house, so `status` and `homeserver` both died with
# "No route to host" from anywhere else — which is precisely where you are when
# you need to move traffic off a failing box. Override in .env.local if the
# address changes.
readonly HS_SSH="${HS_SSH:-muratcankoc@100.104.73.75}"
readonly HS_CONTAINER="termio-clone-backend"

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKEND="$ROOT/backend"

# The VPS address comes from the same file `npx convex deploy` reads, so this
# script cannot drift from the deployment the rest of the tooling targets.
VPS_URL="$(sed -n 's/^CONVEX_SELF_HOSTED_URL=//p' "$BACKEND/.env.local" 2>/dev/null | tr -d '"' | head -1)"
readonly VPS_URL
readonly VPS_HOST="${VPS_URL#https://}"

readonly C_DIM=$'\033[2m' C_B=$'\033[1m' C_OFF=$'\033[0m'
readonly C_OK=$'\033[32m' C_WARN=$'\033[33m' C_ERR=$'\033[31m' C_ACC=$'\033[36m'

die() { printf "%s✗ %s%s\n" "$C_ERR" "$*" "$C_OFF" >&2; exit 1; }
note() { printf "%s%s%s\n" "$C_DIM" "$*" "$C_OFF"; }

# ───────── reading the current state ─────────

# What a deployment says right now, as `serve` or the empty string.
#
# Over the same public HTTP endpoint the app itself uses, deliberately: if this
# prints "primary" then a client asking the same question gets "primary". A
# check that consulted the database directly could agree with the row and still
# disagree with what is being served.
serve_of() {
    local url="$1" body
    body="$(curl -s -m 8 -X POST "$url/api/query" \
        -H 'Content-Type: application/json' \
        -d '{"path":"serverDirectory:current","args":{},"format":"json"}' 2>/dev/null)" || return 1
    [[ "$body" == *'"status":"success"'* ]] || return 1
    sed -n 's/.*"serve":"\([a-z]*\)".*/\1/p' <<<"$body"
}

note_of() {
    local url="$1" body
    body="$(curl -s -m 8 -X POST "$url/api/query" \
        -H 'Content-Type: application/json' \
        -d '{"path":"serverDirectory:current","args":{},"format":"json"}' 2>/dev/null)" || return 1
    sed -n 's/.*"note":"\([^"]*\)".*/\1/p' <<<"$body"
}

print_status() {
    local label url serve n
    for pair in "VPS|$VPS_URL" "home server|$HS_URL"; do
        label="${pair%%|*}"
        url="${pair#*|}"
        serve="$(serve_of "$url")" || serve=""
        if [[ -z "$serve" ]]; then
            printf "  %-12s %s%-42s%s %sunreachable / not deployed%s\n" \
                "$label" "$C_DIM" "${url#https://}" "$C_OFF" "$C_ERR" "$C_OFF"
            continue
        fi
        n="$(note_of "$url")"
        printf "  %-12s %s%-42s%s serving: %s%s%s%s\n" \
            "$label" "$C_DIM" "${url#https://}" "$C_OFF" \
            "$C_B" "$serve" "$C_OFF" \
            "${n:+$C_DIM  — $n$C_OFF}"
    done
}

# ───────── writing ─────────

# `convex run` reaches an internalMutation because the CLI carries admin
# credentials, which is why `serverDirectory:set` has no public write surface:
# a public version would let anyone redirect every client of this app.
write_vps() {
    local payload="$1"
    (cd "$BACKEND" && npx convex run serverDirectory:set "$payload" >/dev/null 2>&1)
}

# Minted fresh each time and held only in this shell. There is no admin key on
# disk for the home server and there should not be one.
#
# Runs from backend/ like the VPS write does, and for a reason worth stating:
# the env vars decide WHICH deployment this reaches, but the CLI still resolves
# the project — package.json, convex/ — from the working directory. Pointed at
# the home server from the repo root it fails with "Unable to read your
# package.json", which reads like a credentials problem and is not one.
write_homeserver() {
    local payload="$1" key
    key="$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$HS_SSH" \
        "docker exec $HS_CONTAINER ./generate_admin_key.sh 2>/dev/null | tail -1" 2>/dev/null)" || return 1
    [[ "$key" == *"|"* ]] || return 1
    (cd "$BACKEND" && CONVEX_SELF_HOSTED_URL="$HS_URL" \
        CONVEX_SELF_HOSTED_ADMIN_KEY="$key" \
        npx convex run serverDirectory:set "$payload" >/dev/null 2>&1)
}

# ───────── the switch ─────────

apply() {
    local target="$1" note_text="${2:-}" payload
    payload="{\"serve\":\"$target\""
    [[ -n "$note_text" ]] && payload+=",\"note\":$(printf '%s' "$note_text" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
    payload+="}"

    # The home server has to be writable BEFORE traffic is pointed at it. Any
    # other order sends people to a machine that has not been told it is
    # supposed to have them — and if the VPS then becomes unreachable, its stale
    # row is the one they fall back to reading.
    printf "\n  %s→%s writing the home server…  " "$C_ACC" "$C_OFF"
    if write_homeserver "$payload"; then
        printf "%sok%s\n" "$C_OK" "$C_OFF"
    elif [[ "$target" == "homeserver" ]]; then
        printf "%sfailed%s\n" "$C_ERR" "$C_OFF"
        die "refusing to send traffic to a home server this script cannot reach.
   Check it is up and that SSH to $HS_SSH works, then try again."
    else
        printf "%sfailed%s\n" "$C_WARN" "$C_OFF"
        # Safe to continue in this direction only. Clients on the home server
        # poll the VPS every half-minute and will come home on their own; the
        # stale row there only matters if the VPS also goes down, and it is
        # already saying the more conservative of the two answers.
        note "   Continuing anyway — this direction does not depend on it."
        note "   Re-run once the home server is reachable so its row agrees."
    fi

    printf "  %s→%s writing the VPS…          " "$C_ACC" "$C_OFF"
    if write_vps "$payload"; then
        printf "%sok%s\n" "$C_OK" "$C_OFF"
    else
        printf "%sfailed%s\n" "$C_ERR" "$C_OFF"
        die "the VPS write failed — nothing has moved.
   This is the row clients actually read, so the switch did not happen."
    fi

    printf "\n%sNow:%s\n" "$C_B" "$C_OFF"
    print_status
    printf "\n"
    if [[ "$target" == "homeserver" ]]; then
        note "Clients move within a second. They stay signed in — the two"
        note "deployments are replicated, so this is a reconnect, not a sign-out."
    else
        note "Clients still on the VPS move immediately. Ones already on the home"
        note "server come back within ~30s, which is how often they re-ask."
    fi
}

# ───────── entry ─────────

[[ -n "$VPS_URL" ]] || die "no CONVEX_SELF_HOSTED_URL in backend/.env.local — is this the right checkout?"
command -v npx >/dev/null || die "npx not found."

printf "\n%sMonkeyHub — which server serves everyone?%s\n\n" "$C_B" "$C_OFF"
print_status

case "${1:-}" in
    status) printf "\n"; exit 0 ;;
    primary|homeserver) target="$1" ;;
    "")
        printf "\n  %s1%s  VPS          %s%s%s\n" "$C_B" "$C_OFF" "$C_DIM" "$VPS_HOST" "$C_OFF"
        printf "  %s2%s  home server  %s%s%s\n" "$C_B" "$C_OFF" "$C_DIM" "$HS_HOST" "$C_OFF"
        printf "  %sq%s  quit\n\n" "$C_B" "$C_OFF"
        read -r -p "  serve from [1/2/q]: " choice
        case "$choice" in
            1) target="primary" ;;
            2) target="homeserver" ;;
            *) printf "\n"; exit 0 ;;
        esac
        ;;
    -h|--help)
        printf "\n  %s./switchServer.sh%s              pick interactively\n" "$C_B" "$C_OFF"
        printf "  %s./switchServer.sh homeserver%s   move traffic to the home server\n" "$C_B" "$C_OFF"
        printf "  %s./switchServer.sh primary%s      bring everyone back to the VPS\n" "$C_B" "$C_OFF"
        printf "  %s./switchServer.sh status%s       show both, change nothing\n\n" "$C_B" "$C_OFF"
        exit 0 ;;
    *) die "unknown argument '$1'. Try: primary | homeserver | status" ;;
esac

# Only worth asking in one direction: the note is shown in the app's info sheet,
# which is only reachable from the badge, which only exists off the VPS.
note_text=""
if [[ "$target" == "homeserver" ]]; then
    printf "\n"
    read -r -p "  why? (shown in the app, blank to skip): " note_text
fi

current="$(serve_of "$VPS_URL")" || current=""
if [[ "$current" == "$target" && -z "$note_text" ]]; then
    printf "\n%sAlready serving from %s — nothing to do.%s\n\n" "$C_DIM" "$target" "$C_OFF"
    exit 0
fi

printf "\n  This moves %severy client%s to %s%s%s.\n" "$C_B" "$C_OFF" "$C_B" "$target" "$C_OFF"
read -r -p "  go ahead? [y/N]: " ok
[[ "$ok" =~ ^[Yy]$ ]] || { printf "\n%sCancelled.%s\n\n" "$C_DIM" "$C_OFF"; exit 0; }

apply "$target" "$note_text"
