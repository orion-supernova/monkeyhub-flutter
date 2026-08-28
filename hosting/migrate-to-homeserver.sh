#!/bin/bash
# Move the production Convex deployment off the 956 MB Oracle VM and onto the
# home server, data and functions together.
#
#   ./hosting/migrate-to-homeserver.sh            status: the gap between the two
#                                                 boxes, in facts. Changes nothing.
#   ./hosting/migrate-to-homeserver.sh prepare    put the new compose + image +
#                                                 empty volume on the home server.
#                                                 No downtime, nothing served yet.
#   ./hosting/migrate-to-homeserver.sh copy       bulk-copy the VPS's data while it
#                                                 keeps serving. No downtime. Safe to
#                                                 run repeatedly — each run is a
#                                                 shorter delta for the cutover.
#   ./hosting/migrate-to-homeserver.sh cutover    THE WINDOW. Stops the VPS backend,
#                                                 takes the final delta, brings the
#                                                 home server up on it, verifies.
#                                                 Traffic does not move yet.
#   ./hosting/migrate-to-homeserver.sh verify     probe the home server's functions
#                                                 and data. Changes nothing.
#   ./hosting/migrate-to-homeserver.sh rollback   point the home server's compose
#                                                 back at the old clone volume.
#
# Traffic is moved by `./switchServer.sh homeserver`, which is deliberately NOT
# part of this script. Filling the standby and pointing users at it are two
# decisions, and only the second one is visible to anybody.
#
# ───────── why replace, rather than sync the missing pieces ─────────
#
# The home server has been a standby since 2026-08-13. What it is missing is
# both halves at once:
#
#   functions   everything from 2026-08-19 on — device login, room admin roles
#               and invites, speaker colours, the whole interactions feature
#               (polls / checklists / events), and the schema they need.
#   data        two weeks of real user content — messages, game rounds,
#               interactions — that exists only on the VPS.
#
# `npx convex deploy` fixes the first half in one command. It does NOT fix the
# second, and worse, it has to run schema validation against two-week-old rows
# whose migrations only ever ran on the VPS. That is a deploy that can fail
# halfway on the box you are trying to make trustworthy.
#
# Copying /convex/data wholesale fixes both halves at once and cannot fail
# validation, because the bytes being copied are the ones the VPS is validating
# against right now. A Convex data directory holds the pushed modules as well
# as the rows, so the functions come along with it — the "a restore brings back
# data, not functions" warning in DEPLOY.md is about LOGICAL snapshots
# (`npx convex export`), not about this.
#
# It is also the gentler of the two on a box at 30% memory pressure. A logical
# export walks every table through the UDF machinery; a file copy is read()
# and send(), and `messages` is a large table on a VM with 181 MB free.
#
# ───────── the one thing that would break this ─────────
#
# The home server has been running the OLD backend image (a08c5b76…, the
# 2026-03-10 build). The VPS was upgraded to 1f2044e3… (2026-08-10) on
# 2026-08-28, which REWROTE its system tables into a format the older build
# cannot read.
#
# So the image must go forward here BEFORE this data lands, and `prepare` is
# what does it. An older backend on newer data boots, prints `backend listening
# on 0.0.0.0:3210`, and then fails every single request with
# ``missing field `state```. That is not a theory — it is what a rollback
# attempt did to the VPS on 2026-08-28.
#
# Going forward on THIS box is safe in the way it was not on the VPS. The
# warning in tune-termio-vm.sh not to run `upgrade` again is about 956 MB of
# RAM, where the August build swapped 3.25 GB and drove IO pressure to 39%.
# This box has 7.3 GB and a load average of 0.06. Its RAM was always the fix.

set -uo pipefail

# ───────── configuration ─────────

# Same convention as tune-termio-vm.sh and deploy.sh: .env.local may override
# any of these if a box or a key moves.
if [ -f .env.local ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env.local
    set +a
fi

# The VPS — the source.
VM_HOST="${VM_HOST:-79.76.54.204}"
VM_USER="${VM_USER:-ubuntu}"
VM_SSH_KEY="${VM_SSH_KEY:-$HOME/Documents/BelesMakinem/ssh-key-2024-12-04-2.key}"
VM_SSH_OPTS="-i $VM_SSH_KEY -o BatchMode=yes -o ConnectTimeout=15"
VM_COMPOSE_DIR="/home/ubuntu/convex-instances/termio-backend/self-hosted/docker"
VM_CONTAINER="termio-backend"
VPS_URL="https://termio-api.walhallaa.com"

# The home server — the destination. Reached over Tailscale, not the LAN: the
# 192.168.68.107 address in switchServer.sh only resolves from inside the house,
# and a migration you can only run from one room is not a migration.
HS_SSH_HOST="${HS_SSH_HOST:-muratcankoc@100.104.73.75}"
HS_SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=15"
HS_COMPOSE_DIR="${HS_COMPOSE_DIR:-/home/muratcankoc/termio-clone}"
HS_CONTAINER="termio-clone-backend"
HS_URL="https://monkeyhub-homeserver-api.walhallaa.com"
HS_VOLUME="termio-prod-data"       # the new, named volume this migration fills
HS_OLD_VOLUME="termio-clone-data"  # the 2026-08-13 standby, kept as the rollback

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_SRC="$ROOT/hosting/homeserver-docker-compose.yml"

# Staging on this laptop. The data goes VPS → here → home server rather than
# VPS → home server directly, so the VPS's private key never has to be copied
# onto a third box. The stopover is also a third copy of production, which is
# not the worst thing to have during a migration.
STAGING="${STAGING:-$HOME/.monkeyhub-migration/convex-data}"

# rsync's progress meter is a carriage-return animation: useful on a terminal,
# and 100 KB of overwritten noise the moment the output is piped or logged.
if [ -t 1 ]; then RSYNC_INFO="--info=progress2"; else RSYNC_INFO="--info=stats2"; fi

C_DIM=$'\033[2m'; C_B=$'\033[1m'; C_OFF=$'\033[0m'
C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_ACC=$'\033[36m'

die()  { printf "%s✗ %s%s\n" "$C_ERR" "$*" "$C_OFF" >&2; exit 1; }
note() { printf "%s  %s%s\n" "$C_DIM" "$*" "$C_OFF"; }
ok()   { printf "%s✓ %s%s\n" "$C_OK" "$*" "$C_OFF"; }
warn() { printf "%s! %s%s\n" "$C_WARN" "$*" "$C_OFF"; }
head_() { printf "\n%s── %s ──%s\n" "$C_B" "$*" "$C_OFF"; }

vm_ssh() { ssh $VM_SSH_OPTS "$VM_USER@$VM_HOST" "$@"; }
hs_ssh() { ssh $HS_SSH_OPTS "$HS_SSH_HOST" "$@"; }

# The same two, with -n. ssh reads stdin by default and hands it to the remote
# command, so an ssh call standing between a pipe and a `read` EATS the line the
# read was waiting for — which is exactly how the first cutover attempt answered
# its own confirmation prompt with nothing and aborted. Use these everywhere the
# remote command has no stdin to consume; the plain ones are for the `bash -s`
# heredocs in status(), which genuinely need it.
vm_ssh_n() { ssh $VM_SSH_OPTS -n "$VM_USER@$VM_HOST" "$@"; }
hs_ssh_n() { ssh $HS_SSH_OPTS -n "$HS_SSH_HOST" "$@"; }

require_hosts() {
    [ -f "$VM_SSH_KEY" ] || die "VM SSH key not found: $VM_SSH_KEY (set VM_SSH_KEY in .env.local)"
    vm_ssh_n -o StrictHostKeyChecking=accept-new true 2>/dev/null \
        || die "Cannot reach the VPS at $VM_USER@$VM_HOST over SSH."
    hs_ssh_n -o StrictHostKeyChecking=accept-new true 2>/dev/null \
        || die "Cannot reach the home server at $HS_SSH_HOST over SSH (is Tailscale up?)"
}

# Confirmation that also works when the script is driven from a pipe or a log,
# where there is no terminal to type at. `CONFIRM=cutover ./… cutover` is the
# non-interactive form; a human still gets the prompt.
confirm() {
    local want="$1"
    if [ -n "${CONFIRM:-}" ]; then
        [ "$CONFIRM" = "$want" ] || die "CONFIRM is not '$want' — nothing changed"
        note "confirmed non-interactively (CONFIRM=$want)"
        return 0
    fi
    printf "\n%sType '%s' to begin: %s" "$C_B" "$want" "$C_OFF"
    read -r reply
    [ "$reply" = "$want" ] || die "aborted — nothing changed"
}

# The VPS keeps /convex/data on an ANONYMOUS volume, so it has no stable name to
# hardcode — ask Docker where it actually is rather than guessing.
vm_data_path() {
    vm_ssh_n "docker inspect $VM_CONTAINER --format '{{range .Mounts}}{{if eq .Destination \"/convex/data\"}}{{.Source}}{{end}}{{end}}'" 2>/dev/null
}

# ───────── the function gap, measured without credentials ─────────
#
# A Convex deployment answers an unknown function with "Could not find public
# function", and an existing one that needs auth with an auth error. Both are
# proof of what is deployed, and neither needs an admin key — which is why this
# check works against a box we have no source checkout on.
#
# One function per feature, ordered oldest to newest. The first three predate
# the standby and should be present on both; the rest are the gap.
PROBE_FNS=(
    "serverDirectory:current"                    # 2026-08-13
    "games:daily"                                # older
    "bookmarks:listForRoom"                      # 2026-08-09
    "deviceLogin:getDeviceLoginRequestStatus"    # 2026-08-19
    "roomAdmin:myPermissions"                    # 2026-08-20
    "speakerColors:mine"                         # 2026-08-24
    "interactions:listForRoom"                   # 2026-08-26
    "interactions:stateForMessages"              # 2026-08-26
)

probe_functions() {
    local url="$1" missing=0 body
    for fn in "${PROBE_FNS[@]}"; do
        body=$(curl -s --max-time 25 -X POST "$url/api/query" \
                    -H 'Content-Type: application/json' \
                    -d "{\"path\":\"$fn\",\"args\":{},\"format\":\"json\"}" 2>/dev/null)
        if [ -z "$body" ]; then
            printf "    %s? %-44s no answer%s\n" "$C_WARN" "$fn" "$C_OFF"
            missing=$((missing + 1))
        elif printf '%s' "$body" | grep -qi "Could not find public function"; then
            printf "    %s✗ %-44s absent%s\n" "$C_ERR" "$fn" "$C_OFF"
            missing=$((missing + 1))
        else
            printf "    %s✓%s %-44s present\n" "$C_OK" "$C_OFF" "$fn"
        fi
    done
    return $missing
}

# ───────── status ─────────

status() {
    require_hosts

    head_ "the VPS — $VM_HOST"
    vm_ssh "bash -s" <<'REMOTE'
free -m | awk '/^Mem:/ {printf "  memory      %s MB total, %s MB available\n", $2, $7}'
awk '/^some/ {printf "  pressure    some avg300=%s\n", substr($4,8)}' /proc/pressure/memory
docker inspect termio-backend --format '  image       {{.Config.Image}}' 2>/dev/null | sed 's/sha256:\(............\).*/\1…/'
docker exec termio-backend du -sh /convex/data 2>/dev/null | awk '{printf "  data        %s\n", $1}'
docker stats --no-stream --format '{{.Name}}  {{.MemUsage}}  cpu {{.CPUPerc}}' 2>/dev/null | sed 's/^/  container   /'
REMOTE

    head_ "the home server — ${HS_SSH_HOST#*@}"
    hs_ssh "bash -s" "$HS_VOLUME" "$HS_OLD_VOLUME" <<'REMOTE'
NEW="$1"; OLD="$2"
free -m | awk '/^Mem:/ {printf "  memory      %s MB total, %s MB available\n", $2, $7}'
awk '{printf "  load        %s\n", $1" "$2" "$3}' /proc/loadavg
df -h / | awk 'NR==2 {printf "  disk        %s free of %s\n", $4, $2}'
docker inspect termio-clone-backend --format '  image       {{.Config.Image}}' 2>/dev/null | sed 's/sha256:\(............\).*/\1…/'
for v in "$NEW" "$OLD"; do
    if docker volume inspect "$v" >/dev/null 2>&1; then
        echo "  volume      $v exists"
    else
        echo "  volume      $v — not created yet"
    fi
done
REMOTE

    head_ "compose file — box vs repo"
    local local_sum remote_sum
    local_sum=$(md5 -q "$COMPOSE_SRC" 2>/dev/null || md5sum "$COMPOSE_SRC" | cut -d' ' -f1)
    remote_sum=$(hs_ssh "md5sum $HS_COMPOSE_DIR/docker-compose.yml 2>/dev/null | cut -d' ' -f1")
    if [ "$local_sum" = "$remote_sum" ]; then
        ok "the home server is running this repo's compose file"
    else
        warn "the box's compose differs from hosting/homeserver-docker-compose.yml"
        note "run 'prepare' to install it"
    fi

    head_ "functions on the VPS (the truth)"
    probe_functions "$VPS_URL"
    head_ "functions on the home server"
    probe_functions "$HS_URL"
    local gap=$?
    if [ "$gap" -gt 0 ]; then
        printf "\n"
        warn "$gap of ${#PROBE_FNS[@]} probed functions are missing on the home server"
    else
        printf "\n"
        ok "the home server answers every probed function"
    fi

    head_ "who is serving"
    note "run ./switchServer.sh status — it reads the directive row on both"
}

# ───────── prepare ─────────
#
# Everything here is invisible to users: the home server keeps serving nothing,
# the VPS keeps serving everyone.

prepare() {
    require_hosts
    [ -f "$COMPOSE_SRC" ] || die "missing $COMPOSE_SRC"

    head_ "installing the compose file"
    hs_ssh_n "mkdir -p $HS_COMPOSE_DIR" || die "cannot create $HS_COMPOSE_DIR"
    # Keep the old one. It is the only record of how the standby was wired.
    hs_ssh_n "cd $HS_COMPOSE_DIR && [ -f docker-compose.yml ] && cp -n docker-compose.yml docker-compose.yml.pre-migration || true"
    scp $HS_SSH_OPTS "$COMPOSE_SRC" "$HS_SSH_HOST:$HS_COMPOSE_DIR/docker-compose.yml" >/dev/null \
        || die "could not copy the compose file over"
    ok "compose installed (previous kept as docker-compose.yml.pre-migration)"

    head_ "creating the destination volume"
    hs_ssh_n "docker volume create $HS_VOLUME" >/dev/null || die "could not create volume $HS_VOLUME"
    ok "$HS_VOLUME ready — $HS_OLD_VOLUME left untouched as the rollback"

    head_ "pulling the backend image"
    note "same digest the VPS runs; ~200 MB, one time"
    hs_ssh_n "cd $HS_COMPOSE_DIR && docker compose pull termio-clone-backend" 2>&1 | tail -5
    ok "image pulled"

    printf "\n"
    ok "prepared. Nothing is serving from it yet."
    note "next: $0 copy"
}

# ───────── copy ─────────
#
# The bulk pass, with the VPS still serving. rsync is restartable and
# incremental, so running this twice is not twice the work — the second run
# copies only what changed, which is the entire point of doing it before the
# window rather than inside it.

copy() {
    require_hosts
    local src; src=$(vm_data_path)
    [ -n "$src" ] || die "could not find the VPS's /convex/data mount"
    note "VPS data lives at $src"
    mkdir -p "$STAGING" || die "cannot create staging dir $STAGING"

    head_ "pass 1 — VPS → this laptop (VPS stays up)"
    warn "the database file is live, so this copy is NOT consistent on its own"
    note "'cutover' takes the consistent delta with the backend stopped"
    # --rsync-path="sudo rsync": /convex/data is root-owned inside the volume and
    # the ubuntu user has passwordless sudo. The key never leaves this laptop.
    # No --delete here: this is the bulk warm-up, and cutover reconciles.
    rsync -aH $RSYNC_INFO --partial \
          --exclude 'tmp/' --exclude '*-journal' --exclude '*-wal' \
          --rsync-path="sudo rsync" \
          -e "ssh $VM_SSH_OPTS" \
          "$VM_USER@$VM_HOST:$src/" "$STAGING/" \
        || die "rsync from the VPS failed"
    ok "bulk copy staged at $STAGING"

    head_ "pass 2 — this laptop → home server (staging area)"
    hs_ssh_n "mkdir -p ~/termio-migration-staging" || die "cannot create staging on the home server"
    rsync -aH $RSYNC_INFO --partial \
          -e "ssh $HS_SSH_OPTS" \
          "$STAGING/" "$HS_SSH_HOST:~/termio-migration-staging/" \
        || die "rsync to the home server failed"
    ok "staged on the home server"

    printf "\n"
    note "run 'copy' again any time — each run shortens the cutover window"
    note "when ready: $0 cutover"
}

# ───────── cutover ─────────
#
# The only step with a window. Everything before it was warm-up.

cutover() {
    require_hosts
    local src; src=$(vm_data_path)
    [ -n "$src" ] || die "could not find the VPS's /convex/data mount"

    hs_ssh_n "docker volume inspect $HS_VOLUME" >/dev/null 2>&1 \
        || die "volume $HS_VOLUME does not exist — run '$0 prepare' first"

    head_ "what is about to happen"
    cat <<EOF
  1. the VPS backend STOPS  — chat stops for everyone, from here
  2. the final delta is copied, database consistent because nothing is writing
  3. the home server comes up on that data, on the matching image
  4. its functions are probed
  5. traffic does NOT move — that stays yours, via ./switchServer.sh homeserver

  Writes made on the VPS after step 1 would be lost, which is why step 1 is a
  stop and not a "copy while it runs".
EOF
    confirm cutover

    local t0=$SECONDS

    head_ "1/5 stopping the VPS backend"
    vm_ssh_n "cd $VM_COMPOSE_DIR && docker compose stop backend" 2>&1 | tail -3
    ok "VPS backend stopped — the window is open"

    head_ "2/5 final delta, VPS → laptop → home server"
    # --delete now: this pass must produce an exact copy, not a merge with
    # whatever pass 1 left behind. tmp/ is scratch the backend rebuilds.
    rsync -aH --delete $RSYNC_INFO --partial \
          --exclude 'tmp/' \
          --rsync-path="sudo rsync" \
          -e "ssh $VM_SSH_OPTS" \
          "$VM_USER@$VM_HOST:$src/" "$STAGING/" \
        || { warn "delta from the VPS failed — restarting it"; vm_ssh_n "cd $VM_COMPOSE_DIR && docker compose start backend"; die "aborted"; }
    rsync -aH --delete $RSYNC_INFO --partial \
          -e "ssh $HS_SSH_OPTS" \
          "$STAGING/" "$HS_SSH_HOST:~/termio-migration-staging/" \
        || { warn "delta to the home server failed — restarting the VPS"; vm_ssh_n "cd $VM_COMPOSE_DIR && docker compose start backend"; die "aborted"; }
    ok "consistent copy is on the home server"

    head_ "3/5 filling the volume and starting the home server"
    # A helper container, because writing into a Docker volume needs root and
    # this box's sudo is interactive. The container has the root the shell does
    # not, and disappears afterwards.
    hs_ssh_n "cd $HS_COMPOSE_DIR && docker compose down" 2>&1 | tail -3
    hs_ssh_n "docker run --rm -v $HS_VOLUME:/dst -v \$HOME/termio-migration-staging:/src:ro alpine sh -c 'rm -rf /dst/* && cp -a /src/. /dst/'" \
        || die "could not fill $HS_VOLUME"
    ok "volume filled"
    hs_ssh_n "cd $HS_COMPOSE_DIR && docker compose up -d" 2>&1 | tail -5

    head_ "4/5 waiting for the backend to finish bootstrap"
    note "it re-reads a ~495 MB SQLite file; on this box that is fast, but not instant"
    local waited=0
    while [ $waited -lt 600 ]; do
        if hs_ssh_n "docker logs $HS_CONTAINER 2>&1 | grep -q 'backend listening on'"; then
            ok "backend listening (${waited}s)"
            break
        fi
        sleep 10; waited=$((waited + 10))
        printf "%s    …%ss%s\r" "$C_DIM" "$waited" "$C_OFF"
    done
    if [ $waited -ge 600 ]; then
        warn "no 'backend listening' after 10 minutes — check the log:"
        note "ssh $HS_SSH_HOST 'docker logs --tail 50 $HS_CONTAINER'"
    fi

    # The specific failure worth naming, because it is silent otherwise: an
    # older backend on newer data serves errors, not refusals.
    if hs_ssh_n "docker logs $HS_CONTAINER 2>&1 | grep -q 'missing field'"; then
        warn "the log contains 'missing field' — this is the old-image-on-new-data failure."
        die "the image digest does not match the VPS. Fix the pin and re-run 'prepare'."
    fi

    head_ "5/5 verifying"
    verify

    printf "\n%sThe window has been open for %s seconds.%s\n" "$C_B" "$((SECONDS - t0))" "$C_OFF"
    warn "the VPS backend is still STOPPED and nobody is being served"
    cat <<EOF

  Move traffic when the verification above looks right:

      ./switchServer.sh homeserver

  Then bring the VPS back as a standby (it will be stale, which is expected):

      ssh -i $VM_SSH_KEY $VM_USER@$VM_HOST \\
          'cd $VM_COMPOSE_DIR && docker compose start backend'
EOF
}

# ───────── verify ─────────

verify() {
    head_ "the home server's functions"
    probe_functions "$HS_URL"
    local gap=$?
    if [ "$gap" -eq 0 ]; then
        ok "every probed function is present — the copy brought the modules across"
    else
        warn "$gap probed functions still missing"
        note "if the data copy was complete this should be 0; a deploy would also fix it:"
        note "  key=\$(ssh $HS_SSH_HOST 'docker exec $HS_CONTAINER ./generate_admin_key.sh | tail -1')"
        note "  (cd backend && CONVEX_SELF_HOSTED_URL=$HS_URL CONVEX_SELF_HOSTED_ADMIN_KEY=\"\$key\" npx convex deploy)"
    fi

    head_ "the home server's health"
    hs_ssh "bash -s" <<'REMOTE'
free -m | awk '/^Mem:/ {printf "  memory      %s MB available of %s MB\n", $7, $2}'
docker exec termio-clone-backend du -sh /convex/data 2>/dev/null | awk '{printf "  data        %s\n", $1}'
docker logs --tail 200 termio-clone-backend 2>&1 | grep -ci "error" | awk '{printf "  errors      %s in the last 200 log lines\n", $1}'
REMOTE

    head_ "latency, measured on the box"
    # The idle-gap probe from tune-termio-vm.sh. A flat curve is a healthy box;
    # a spike that grows with the gap means the working set is being reclaimed.
    # serverDirectory:current is public, so this needs no admin key.
    hs_ssh_n 'D='"'"'{"path":"serverDirectory:current","args":{},"format":"json"}'"'"'
        for gap in 0 5 15 30; do sleep $gap; printf "  after %2ss idle: " $gap
            curl -s -o /dev/null -w "%{time_starttransfer}s\n" -X POST \
                http://127.0.0.1:3210/api/query -H "Content-Type: application/json" -d "$D"
        done'
}

# ───────── rollback ─────────

rollback() {
    require_hosts
    head_ "pointing the home server back at the old standby volume"
    warn "this returns the home server to its 2026-08-13 state"
    note "it does not touch the VPS, and does not move traffic"
    confirm rollback

    hs_ssh_n "cd $HS_COMPOSE_DIR && docker compose down" 2>&1 | tail -3
    hs_ssh_n "cd $HS_COMPOSE_DIR && [ -f docker-compose.yml.pre-migration ] && cp docker-compose.yml.pre-migration docker-compose.yml" \
        || die "no docker-compose.yml.pre-migration to restore"
    hs_ssh_n "cd $HS_COMPOSE_DIR && docker compose up -d" 2>&1 | tail -3
    ok "home server is back on $HS_OLD_VOLUME and the old image"
    warn "if traffic is on the home server, move it back: ./switchServer.sh primary"
}

# ───────── dispatch ─────────

case "${1:-status}" in
    status)   status ;;
    prepare)  prepare ;;
    copy)     copy ;;
    cutover)  cutover ;;
    verify)   require_hosts; verify ;;
    rollback) rollback ;;
    *)
        sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
        exit 1 ;;
esac
