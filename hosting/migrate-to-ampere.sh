#!/bin/bash
# Move MonkeyHub's production deployment onto the Ampere box and retire the
# 956 MB Oracle VM, data and public hostnames together.
#
#   ./hosting/migrate-to-ampere.sh            status:  the three boxes, in facts.
#                                             Changes nothing.
#   ./hosting/migrate-to-ampere.sh prepare    build the box: directories, Docker
#                                             network, compose stacks, Caddy,
#                                             tunnel credentials, images, and the
#                                             static site copied off the old VPS.
#                                             No downtime, nothing served yet.
#   ./hosting/migrate-to-ampere.sh copy       bulk-copy the HOME SERVER's Convex
#                                             data while it keeps serving. No
#                                             downtime. Safe to repeat — each run
#                                             is a shorter delta for the cutover.
#   ./hosting/migrate-to-ampere.sh cutover    THE WINDOW. Stops the home server's
#                                             backend, takes the final delta,
#                                             brings the Ampere box up on it,
#                                             verifies. Traffic does not move yet.
#   ./hosting/migrate-to-ampere.sh ingress    move termio-api / termio-dashboard /
#                                             monkeyhub.walhallaa.com onto this
#                                             box's tunnels and off the old VPS.
#   ./hosting/migrate-to-ampere.sh verify     probe this box's functions, data and
#                                             latency. Changes nothing.
#   ./hosting/migrate-to-ampere.sh retire     stop MonkeyHub's containers, tunnels
#                                             and Caddy block on the old VPS.
#                                             Leaves its data on disk.
#   ./hosting/migrate-to-ampere.sh wipe-old   DESTRUCTIVE. Delete the old VPS's
#                                             MonkeyHub Convex database for good.
#
# Traffic is moved by `./switchServer.sh primary`, which is deliberately NOT part
# of this script — filling a backend and pointing users at it are two decisions,
# and only the second is visible to anybody. The same split as
# migrate-to-homeserver.sh, for the same reason.
#
# ───────── the shape of this migration ─────────
#
# Three boxes, not two:
#
#   old VPS       79.76.54.204, x86_64, 956 MB. Holds MonkeyHub's two public
#                 hostnames and the static site — and a Convex database that has
#                 been STALE since traffic moved away on 2026-08-28. It looks
#                 like it also hosts nestzone and couplezone, and it does not:
#                 those moved to another machine on 2026-08-21 and only their
#                 stopped containers and a dead Caddy block remain here.
#   home server   100.104.73.75 (Tailscale), x86_64, 7.3 GB, six other stacks.
#                 Serving everyone right now. Holds the ONLY current data.
#   Ampere box    129.151.223.191, aarch64, 11.9 GB. Empty. The destination.
#
# So the pieces come from different places, and that is the whole subtlety:
#
#   Convex data      ← the HOME SERVER   (the live copy; the old VPS's is stale)
#   public hostnames ← the OLD VPS       (its two Cloudflare tunnels move here)
#   static site      ← the OLD VPS       (/srv/monkeyhub; the home server has none)
#
# Copying the old VPS's database instead would silently roll production back two
# weeks. It is never read by this script, and `wipe-old` exists to delete it.
#
# ───────── why the data copy is safe across architectures ─────────
#
# This is the fleet's first ARM box. The pinned backend digest is an OCI image
# INDEX carrying both amd64 and arm64, so the SAME pin the home server runs
# resolves to an arm64 image here — the build stays the 2026-08-10 one on every
# box, which is the property that matters (a Convex backend cannot read data a
# newer one wrote). The payload itself is architecture-neutral: SQLite's on-disk
# format is fixed-endian by specification, and storage/ is opaque blobs plus the
# pushed modules.
#
# Read the one-way-door warning in hosting/termio-docker-compose.yaml before ever
# moving that digest. An OLDER backend on NEWER data boots, prints "backend
# listening", and then fails every request with `missing field \`state\``.

set -uo pipefail

# ───────── configuration ─────────

if [ -f .env.local ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env.local
    set +a
fi

# The Ampere box — the destination.
AM_HOST="${AM_HOST:-129.151.223.191}"
AM_USER="${AM_USER:-ubuntu}"
AM_SSH_KEY="${AM_SSH_KEY:-$HOME/Documents/BelesMakinem/BelesAmpere.key}"
AM_SSH_OPTS="-i $AM_SSH_KEY -o BatchMode=yes -o ConnectTimeout=15"
AM_STACKS="/opt/stacks"
AM_CONTAINER="monkeyhub-convex-backend"
AM_VOLUME="monkeyhub-convex-data"

# The home server — the SOURCE OF THE DATA. Reached over Tailscale.
HS_SSH_HOST="${HS_SSH_HOST:-muratcankoc@100.104.73.75}"
HS_SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=15"
HS_COMPOSE_DIR="${HS_COMPOSE_DIR:-/home/muratcankoc/termio-clone}"
HS_CONTAINER="termio-clone-backend"
HS_VOLUME="termio-prod-data"
HS_URL="https://monkeyhub-homeserver-api.walhallaa.com"

# The old VPS — the source of the HOSTNAMES and the STATIC SITE. Never the data.
VM_HOST="${VM_HOST_OLD:-79.76.54.204}"
VM_USER="${VM_USER_OLD:-ubuntu}"
VM_SSH_KEY="${VM_SSH_KEY_OLD:-$HOME/Documents/BelesMakinem/ssh-key-2024-12-04-2.key}"
VM_SSH_OPTS="-i $VM_SSH_KEY -o BatchMode=yes -o ConnectTimeout=15"
VM_COMPOSE_DIR="/home/ubuntu/convex-instances/termio-backend/self-hosted/docker"
VM_CONTAINER="termio-backend"

# The public name both the old VPS and this box answer to. Unchanged by the
# move: a tunnel's DNS record names the TUNNEL, not the machine.
API_URL="https://termio-api.walhallaa.com"
SITE_URL="https://monkeyhub.walhallaa.com"

# The two tunnels that belong to MonkeyHub and move with it.
TUNNEL_TERMIO="e970c8dc-30e5-4b6e-a3c7-d569b816ebd1"
TUNNEL_SITE="96c30746-b8cf-41ff-b407-546e041363ea"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/hosting/ampere"
STAGING="${STAGING:-$HOME/.monkeyhub-migration/ampere-data}"

if [ -t 1 ]; then RSYNC_INFO="--info=progress2"; else RSYNC_INFO="--info=stats2"; fi

C_DIM=$'\033[2m'; C_B=$'\033[1m'; C_OFF=$'\033[0m'
C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_ACC=$'\033[36m'

die()  { printf "%s✗ %s%s\n" "$C_ERR" "$*" "$C_OFF" >&2; exit 1; }
note() { printf "%s  %s%s\n" "$C_DIM" "$*" "$C_OFF"; }
ok()   { printf "%s✓ %s%s\n" "$C_OK" "$*" "$C_OFF"; }
warn() { printf "%s! %s%s\n" "$C_WARN" "$*" "$C_OFF"; }
head_(){ printf "\n%s── %s ──%s\n" "$C_B" "$*" "$C_OFF"; }

# -n everywhere the remote command has no stdin to consume. ssh reads stdin by
# default and hands it to the remote command, so an ssh call between a pipe and
# a `read` eats the line the read was waiting for — which is how a confirmation
# prompt answers itself with nothing. The plain forms are for `bash -s` heredocs.
am_ssh()   { ssh $AM_SSH_OPTS "$AM_USER@$AM_HOST" "$@"; }
am_ssh_n() { ssh $AM_SSH_OPTS -n "$AM_USER@$AM_HOST" "$@"; }
hs_ssh()   { ssh $HS_SSH_OPTS "$HS_SSH_HOST" "$@"; }
hs_ssh_n() { ssh $HS_SSH_OPTS -n "$HS_SSH_HOST" "$@"; }
vm_ssh()   { ssh $VM_SSH_OPTS "$VM_USER@$VM_HOST" "$@"; }
vm_ssh_n() { ssh $VM_SSH_OPTS -n "$VM_USER@$VM_HOST" "$@"; }

require_ampere() {
    [ -f "$AM_SSH_KEY" ] || die "Ampere SSH key not found: $AM_SSH_KEY (set AM_SSH_KEY in .env.local)"
    am_ssh_n -o StrictHostKeyChecking=accept-new true 2>/dev/null \
        || die "Cannot reach the Ampere box at $AM_USER@$AM_HOST over SSH."
}
require_hs() {
    hs_ssh_n -o StrictHostKeyChecking=accept-new true 2>/dev/null \
        || die "Cannot reach the home server at $HS_SSH_HOST (is Tailscale up?)"
}
require_vm() {
    [ -f "$VM_SSH_KEY" ] || die "old VPS SSH key not found: $VM_SSH_KEY"
    vm_ssh_n -o StrictHostKeyChecking=accept-new true 2>/dev/null \
        || die "Cannot reach the old VPS at $VM_USER@$VM_HOST over SSH."
}

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

# ───────── the function probe ─────────
#
# A Convex deployment answers an unknown function with "Could not find public
# function" and an existing one that needs auth with an auth error. Both are
# proof of what is deployed, and neither needs an admin key.
PROBE_FNS=(
    "serverDirectory:current"
    "games:daily"
    "bookmarks:listForRoom"
    "deviceLogin:getDeviceLoginRequestStatus"
    "roomAdmin:myPermissions"
    "speakerColors:mine"
    "interactions:listForRoom"
    "interactions:stateForMessages"
)

probe_functions() {
    local url="$1" missing=0 body
    for fn in "${PROBE_FNS[@]}"; do
        body=$(curl -s --max-time 25 -X POST "$url/api/query" \
                    -H 'Content-Type: application/json' \
                    -d "{\"path\":\"$fn\",\"args\":{},\"format\":\"json\"}" 2>/dev/null)
        if [ -z "$body" ]; then
            printf "    %s? %-44s no answer%s\n" "$C_WARN" "$fn" "$C_OFF"; missing=$((missing+1))
        elif printf '%s' "$body" | grep -qi "Could not find public function"; then
            printf "    %s✗ %-44s absent%s\n" "$C_ERR" "$fn" "$C_OFF"; missing=$((missing+1))
        else
            printf "    %s✓%s %-44s present\n" "$C_OK" "$C_OFF" "$fn"
        fi
    done
    return $missing
}

# ───────── status ─────────

status() {
    head_ "the Ampere box — $AM_HOST (destination)"
    if am_ssh_n -o StrictHostKeyChecking=accept-new true 2>/dev/null; then
        am_ssh "bash -s" "$AM_VOLUME" <<'REMOTE'
VOL="$1"
printf "  arch        %s, %s vCPU\n" "$(uname -m)" "$(nproc)"
free -m | awk '/^Mem:/ {printf "  memory      %s MB total, %s MB available\n", $2, $7}'
df -h / | awk 'NR==2 {printf "  disk        %s free of %s\n", $4, $2}'
if command -v docker >/dev/null 2>&1; then
    printf "  docker      %s\n" "$(docker --version | sed 's/Docker version //;s/,.*//')"
    docker ps --format '  container   {{.Names}}  {{.Status}}' 2>/dev/null
    docker volume inspect "$VOL" >/dev/null 2>&1 \
        && echo "  volume      $VOL exists" || echo "  volume      $VOL — not created yet"
else
    echo "  docker      NOT INSTALLED"
fi
[ -d /opt/stacks ] && echo "  stacks      $(ls -1 /opt/stacks 2>/dev/null | tr '\n' ' ')" || echo "  stacks      /opt/stacks — not created yet"
[ -d /srv/monkeyhub ] && du -sh /srv/monkeyhub 2>/dev/null | awk '{printf "  site        %s\n", $1}' || echo "  site        /srv/monkeyhub — not created yet"
REMOTE
    else
        warn "unreachable over SSH"
    fi

    head_ "the home server — ${HS_SSH_HOST#*@} (source of the DATA)"
    if hs_ssh_n -o StrictHostKeyChecking=accept-new true 2>/dev/null; then
        hs_ssh "bash -s" <<'REMOTE'
free -m | awk '/^Mem:/ {printf "  memory      %s MB available of %s MB\n", $7, $2}'
docker inspect termio-clone-backend --format '  image       {{.Config.Image}}' 2>/dev/null | sed 's/sha256:\(............\).*/\1…/'
docker exec termio-clone-backend du -sh /convex/data 2>/dev/null | awk '{printf "  data        %s\n", $1}'
docker ps --filter name=termio-clone --format '  container   {{.Names}}  {{.Status}}'
REMOTE
    else
        warn "unreachable (is Tailscale up?)"
    fi

    head_ "the old VPS — $VM_HOST (source of the HOSTNAMES; data is stale)"
    if vm_ssh_n -o StrictHostKeyChecking=accept-new true 2>/dev/null; then
        vm_ssh "bash -s" <<'REMOTE'
free -m | awk '/^Mem:/ {printf "  memory      %s MB available of %s MB\n", $7, $2}'
docker ps --filter name=termio --format '  container   {{.Names}}  {{.Status}}'
sudo du -sh /srv/monkeyhub 2>/dev/null | awk '{printf "  site        %s\n", $1}'
for u in cloudflared-termio cloudflared-monkeyhub caddy; do
    printf "  %-24s %s\n" "$u" "$(systemctl is-active $u 2>/dev/null)"
done
REMOTE
    else
        warn "unreachable over SSH"
    fi

    head_ "compose files — box vs repo"
    local pairs="convex-compose.yml:$AM_STACKS/monkeyhub-convex/docker-compose.yml
edge-compose.yml:$AM_STACKS/edge/docker-compose.yml"
    while IFS=: read -r local_f remote_f; do
        [ -n "$local_f" ] || continue
        local l r
        l=$(md5 -q "$SRC/$local_f" 2>/dev/null || md5sum "$SRC/$local_f" 2>/dev/null | cut -d' ' -f1)
        r=$(am_ssh_n "md5sum $remote_f 2>/dev/null | cut -d' ' -f1")
        if [ -n "$r" ] && [ "$l" = "$r" ]; then ok "$local_f matches the box"
        elif [ -z "$r" ]; then note "$local_f — not installed yet"
        else warn "$local_f DIFFERS from the box — run 'prepare'"; fi
    done <<< "$pairs"

    head_ "who answers the public hostnames"
    printf "  %-42s " "${API_URL#https://}"
    local served; served=$(curl -s -m 10 -X POST "$API_URL/api/query" -H 'Content-Type: application/json' \
        -d '{"path":"serverDirectory:current","args":{},"format":"json"}' 2>/dev/null)
    if [ -n "$served" ]; then printf "%sanswering%s\n" "$C_OK" "$C_OFF"; else printf "%sno answer%s\n" "$C_ERR" "$C_OFF"; fi
    printf "  %-42s " "${SITE_URL#https://}"
    printf "%s\n" "$(curl -s -o /dev/null -w '%{http_code}' -m 10 "$SITE_URL/" 2>/dev/null)"

    head_ "who is serving"
    note "run ./switchServer.sh status — it reads the directive row on both"
}

# ───────── prepare ─────────
#
# Everything here is invisible to users: the Ampere box serves nothing until
# `ingress` moves the tunnels, and the other two boxes are untouched.

prepare() {
    require_ampere
    [ -d "$SRC" ] || die "missing $SRC"

    head_ "1/7 directories"
    am_ssh_n "sudo mkdir -p $AM_STACKS/monkeyhub-convex $AM_STACKS/edge/cloudflared \
                 /srv/monkeyhub/site /srv/monkeyhub/downloads /srv/monkeyhub/web && \
              sudo chown -R $AM_USER:$AM_USER $AM_STACKS /srv/monkeyhub && \
              chmod 700 $AM_STACKS/edge/cloudflared" || die "could not create the directory tree"
    ok "$AM_STACKS and /srv/monkeyhub ready"

    head_ "2/7 the shared Docker network"
    # external in both compose files, so no stack owns it and `compose down`
    # in one cannot take the other's connectivity with it.
    am_ssh_n "docker network inspect edge >/dev/null 2>&1 || docker network create edge" >/dev/null \
        || die "could not create the 'edge' network"
    ok "network 'edge' ready"

    head_ "3/7 the destination volume"
    am_ssh_n "docker volume inspect $AM_VOLUME >/dev/null 2>&1 || docker volume create $AM_VOLUME" >/dev/null \
        || die "could not create volume $AM_VOLUME"
    ok "$AM_VOLUME ready"

    head_ "4/7 compose files and tunnel ingress"
    scp $AM_SSH_OPTS "$SRC/convex-compose.yml" \
        "$AM_USER@$AM_HOST:$AM_STACKS/monkeyhub-convex/docker-compose.yml" >/dev/null || die "compose copy failed"
    scp $AM_SSH_OPTS "$SRC/edge-compose.yml" \
        "$AM_USER@$AM_HOST:$AM_STACKS/edge/docker-compose.yml" >/dev/null || die "edge compose copy failed"
    scp $AM_SSH_OPTS "$SRC/cloudflared/termio.yml" "$SRC/cloudflared/monkeyhub.yml" \
        "$AM_USER@$AM_HOST:$AM_STACKS/edge/cloudflared/" >/dev/null || die "tunnel config copy failed"
    ok "compose stacks installed from the repo"

    head_ "5/7 tunnel credentials (off the old VPS)"
    require_vm
    # The credentials file IS the tunnel — whoever holds it can serve that
    # hostname. It never goes in git, and it lands 0600 in a 0700 directory.
    # It travels old VPS → laptop → Ampere so neither box needs the other's key.
    local tmp; tmp=$(mktemp -d)
    for id in "$TUNNEL_TERMIO" "$TUNNEL_SITE"; do
        vm_ssh_n "cat ~/.cloudflared/$id.json" > "$tmp/$id.json" 2>/dev/null \
            || { rm -rf "$tmp"; die "could not read tunnel credentials $id from the old VPS"; }
        [ -s "$tmp/$id.json" ] || { rm -rf "$tmp"; die "tunnel credentials $id came back empty"; }
    done
    # No cert.pem. The old VPS has one, but it holds an "ARGO TUNNEL TOKEN"
    # block rather than an origin certificate, so it cannot authorise the
    # `tunnel route dns` call it would exist for — and running a tunnel needs
    # only the credentials JSON. Copying a secret this box has no use for would
    # be one more thing to leak.
    scp $AM_SSH_OPTS "$tmp"/*.json \
        "$AM_USER@$AM_HOST:$AM_STACKS/edge/cloudflared/" >/dev/null || { rm -rf "$tmp"; die "credential copy failed"; }
    am_ssh_n "chmod 600 $AM_STACKS/edge/cloudflared/*.json"
    rm -rf "$tmp"
    ok "both tunnel credentials installed (0600)"

    head_ "6/7 Caddy and the static site"
    am_ssh_n "command -v caddy >/dev/null 2>&1" || {
        note "installing Caddy from the official repo"
        am_ssh_n "sudo apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1 && \
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && \
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null && \
            sudo apt-get update -qq && sudo apt-get install -y -qq caddy" >/dev/null 2>&1 \
            || die "Caddy install failed"
    }
    scp $AM_SSH_OPTS "$SRC/Caddyfile" "$AM_USER@$AM_HOST:/tmp/Caddyfile" >/dev/null || die "Caddyfile copy failed"
    scp $AM_SSH_OPTS "$ROOT/hosting/caddy-monkeyhub.conf" "$AM_USER@$AM_HOST:/tmp/monkeyhub.conf" >/dev/null || die "site conf copy failed"
    am_ssh_n "sudo cp /tmp/Caddyfile /etc/caddy/Caddyfile && sudo cp /tmp/monkeyhub.conf /etc/caddy/monkeyhub.conf" \
        || die "could not install the Caddy config"
    # The static tree comes off the OLD VPS: it is the only box that has one.
    # Straight through this laptop, for the same key-hygiene reason as above.
    note "copying /srv/monkeyhub off the old VPS (~257 MB)"
    local site_stage="$HOME/.monkeyhub-migration/site"
    mkdir -p "$site_stage"
    # -H matters here: downloads/ keeps monkeyhub-latest.apk as a HARDLINK to
    # the versioned file it points at. Without it rsync writes two real 167 MB
    # copies, which is correct but doubles the tree and silently breaks the
    # property that "latest" and the version it aliases are the same bytes.
    # web.prev/ is deploy.sh's rollback copy of the previous web build; a fresh
    # box has nothing to roll back to, so it is not worth 21 MB and 101 files.
    rsync -aH $RSYNC_INFO --rsync-path="sudo rsync" -e "ssh $VM_SSH_OPTS" \
        --exclude 'web.prev/' \
        "$VM_USER@$VM_HOST:/srv/monkeyhub/" "$site_stage/" || die "site download failed"
    rsync -aH $RSYNC_INFO -e "ssh $AM_SSH_OPTS" \
        "$site_stage/" "$AM_USER@$AM_HOST:/srv/monkeyhub/" || die "site upload failed"
    am_ssh_n "sudo caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1" \
        || { am_ssh_n "sudo caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -5"; die "the Caddy config does not validate"; }
    am_ssh_n "sudo systemctl enable --now caddy && sudo systemctl reload caddy" >/dev/null 2>&1
    ok "Caddy serving /srv/monkeyhub on :8081 (loopback + bridge only)"

    head_ "7/7 pulling images"
    note "same digests the other boxes run; they resolve to arm64 here"
    am_ssh_n "cd $AM_STACKS/monkeyhub-convex && docker compose pull" 2>&1 | tail -4
    am_ssh_n "cd $AM_STACKS/edge && docker compose pull" 2>&1 | tail -3
    ok "images pulled"

    printf "\n"
    ok "prepared. The box serves nothing yet — no tunnel here is running."
    note "next: $0 copy"
}

# ───────── copy ─────────
#
# The bulk pass, with the home server still serving. Restartable and
# incremental, so running it twice is not twice the work — which is the entire
# point of doing it before the window rather than inside it.

copy() {
    require_hs; require_ampere
    mkdir -p "$STAGING" || die "cannot create staging dir $STAGING"

    head_ "pass 0 — export the volume on the home server"
    # /var/lib/docker/volumes is root-only and that box's sudo is interactive,
    # so a helper container does the read — the mirror image of the helper
    # migrate-to-homeserver.sh uses to do the write. tmp/ is scratch the backend
    # rebuilds and is excluded here rather than over the wire.
    hs_ssh_n "mkdir -p ~/termio-export && docker run --rm -v $HS_VOLUME:/src:ro -v \$HOME/termio-export:/dst alpine \
        sh -c 'cp -a /src/. /dst/ && rm -rf /dst/tmp && chown -R 1000:1000 /dst'" \
        || die "could not export the volume on the home server"
    hs_ssh_n "du -sh ~/termio-export" | awk '{printf "  exported    %s\n", $1}'

    head_ "pass 1 — home server → this laptop"
    warn "the database file is live, so this copy is NOT consistent on its own"
    note "'cutover' takes the consistent delta with the backend stopped"
    rsync -aH $RSYNC_INFO --partial -e "ssh $HS_SSH_OPTS" \
        "$HS_SSH_HOST:~/termio-export/" "$STAGING/" || die "rsync from the home server failed"
    ok "bulk copy staged at $STAGING"

    head_ "pass 2 — this laptop → the Ampere box"
    am_ssh_n "mkdir -p ~/convex-migration-staging" || die "cannot create staging on the Ampere box"
    rsync -aH $RSYNC_INFO --partial -e "ssh $AM_SSH_OPTS" \
        "$STAGING/" "$AM_USER@$AM_HOST:~/convex-migration-staging/" || die "rsync to the Ampere box failed"
    ok "staged on the Ampere box"

    printf "\n"
    note "run 'copy' again any time — each run shortens the cutover window"
    note "when ready: $0 cutover"
}

# ───────── cutover ─────────

cutover() {
    require_hs; require_ampere
    am_ssh_n "docker volume inspect $AM_VOLUME" >/dev/null 2>&1 \
        || die "volume $AM_VOLUME does not exist — run '$0 prepare' first"

    head_ "what is about to happen"
    cat <<EOF
  1. the HOME SERVER's backend STOPS — chat stops for everyone, from here
  2. the final delta is copied, database consistent because nothing is writing
  3. the Ampere box comes up on that data
  4. its functions are probed
  5. traffic does NOT move — that stays yours, via ./switchServer.sh primary

  Writes made on the home server after step 1 would be lost, which is why step 1
  is a stop and not a "copy while it runs". The window stays OPEN after this
  finishes: leave the home server stopped until you have switched traffic, or
  the copy on the Ampere box starts going stale immediately.
EOF
    confirm cutover

    local t0=$SECONDS

    head_ "1/5 stopping the home server's backend"
    hs_ssh_n "cd $HS_COMPOSE_DIR && docker compose stop termio-clone-backend" 2>&1 | tail -3
    ok "home server backend stopped — the window is open"

    head_ "2/5 final delta, home server → laptop → Ampere"
    hs_ssh_n "docker run --rm -v $HS_VOLUME:/src:ro -v \$HOME/termio-export:/dst alpine \
        sh -c 'cp -a /src/. /dst/ && rm -rf /dst/tmp && chown -R 1000:1000 /dst'" \
        || { warn "export failed — restarting the home server"; hs_ssh_n "cd $HS_COMPOSE_DIR && docker compose start termio-clone-backend"; die "aborted"; }
    # --delete from here on: these passes must produce an exact copy, not a
    # merge with whatever the bulk pass left behind.
    rsync -aH --delete $RSYNC_INFO --partial -e "ssh $HS_SSH_OPTS" \
        "$HS_SSH_HOST:~/termio-export/" "$STAGING/" \
        || { warn "delta from the home server failed — restarting it"; hs_ssh_n "cd $HS_COMPOSE_DIR && docker compose start termio-clone-backend"; die "aborted"; }
    rsync -aH --delete $RSYNC_INFO --partial -e "ssh $AM_SSH_OPTS" \
        "$STAGING/" "$AM_USER@$AM_HOST:~/convex-migration-staging/" \
        || { warn "delta to the Ampere box failed — restarting the home server"; hs_ssh_n "cd $HS_COMPOSE_DIR && docker compose start termio-clone-backend"; die "aborted"; }
    ok "consistent copy is on the Ampere box"

    head_ "3/5 filling the volume and starting the stack"
    am_ssh_n "cd $AM_STACKS/monkeyhub-convex && docker compose down" 2>&1 | tail -3
    am_ssh_n "docker run --rm -v $AM_VOLUME:/dst -v \$HOME/convex-migration-staging:/src:ro alpine \
        sh -c 'rm -rf /dst/* && cp -a /src/. /dst/'" || die "could not fill $AM_VOLUME"
    ok "volume filled"
    am_ssh_n "cd $AM_STACKS/monkeyhub-convex && docker compose up -d" 2>&1 | tail -5

    head_ "4/5 waiting for the backend to finish bootstrap"
    note "it re-reads a ~472 MB SQLite file"
    local waited=0
    while [ $waited -lt 600 ]; do
        if am_ssh_n "docker logs $AM_CONTAINER 2>&1 | grep -q 'backend listening on'"; then
            ok "backend listening (${waited}s)"; break
        fi
        sleep 10; waited=$((waited+10))
        printf "%s    …%ss%s\r" "$C_DIM" "$waited" "$C_OFF"
    done
    [ $waited -ge 600 ] && { warn "no 'backend listening' after 10 minutes — check the log:"; note "ssh -i $AM_SSH_KEY $AM_USER@$AM_HOST 'docker logs --tail 50 $AM_CONTAINER'"; }

    # The failure worth naming, because it is silent otherwise: an older backend
    # on newer data serves errors, not refusals.
    if am_ssh_n "docker logs $AM_CONTAINER 2>&1 | grep -q 'missing field'"; then
        warn "the log contains 'missing field' — the old-image-on-new-data failure."
        die "the image digest does not match the home server. Fix the pin and re-run 'prepare'."
    fi

    head_ "5/5 verifying (over the loopback port — the tunnel has not moved yet)"
    verify_local

    printf "\n%sThe window has been open for %s seconds.%s\n" "$C_B" "$((SECONDS-t0))" "$C_OFF"
    warn "the home server's backend is still STOPPED and nobody is being served"
    cat <<EOF

  Next, in this order:

      $0 ingress          move the hostnames onto this box
      ./switchServer.sh primary   point every client at "primary" (= this box)

  Then bring the home server back as a standby (it will be stale, as expected):

      ssh $HS_SSH_HOST 'cd $HS_COMPOSE_DIR && docker compose start termio-clone-backend'

  And re-run ./switchServer.sh primary once it is up, so BOTH directory rows
  agree. A client that cannot reach the primary falls back to asking the home
  server, and a row still reading "homeserver" there would strand exactly the
  clients that listened to you.
EOF
}

# ───────── ingress ─────────
#
# Moving the two tunnels. The DNS records do not change — they name the tunnel,
# not the machine — but the tunnel must run from ONE box at a time, or Cloudflare
# load-balances the hostname across both and half the requests land on the stale
# backend.

ingress() {
    require_ampere; require_vm

    head_ "what is about to happen"
    cat <<EOF
  1. the old VPS stops cloudflared-termio and cloudflared-monkeyhub
  2. its nestzone tunnel drops the leftover termio-api / termio-dashboard
     ingress entries, so exactly one tunnel anywhere claims those hostnames
  3. this box starts both tunnels
  4. the DNS records are rewritten to name these tunnels explicitly
  5. both hostnames are probed until they answer from here

  $API_URL and $SITE_URL will be briefly
  unavailable — seconds, not minutes.
EOF
    confirm ingress

    head_ "1/5 stopping the old VPS's tunnels"
    vm_ssh_n "sudo systemctl disable --now cloudflared-termio cloudflared-monkeyhub" 2>&1 | tail -3
    ok "old tunnels stopped and disabled"

    head_ "2/5 making sure no other tunnel can claim the termio hostnames"
    # Two files on that box list termio-api / termio-dashboard as ingress:
    #
    #   /etc/cloudflared/config.yml     read by cloudflared-main (the nestzone
    #                                   tunnel). Checked: it does NOT list them,
    #                                   and that unit is dead anyway.
    #   ~/.cloudflared/config.yml       lists them, and is read by NOTHING — no
    #                                   systemd unit references this path.
    #
    # So there is nothing to edit and nothing to restart. The leftover is merely
    # renamed, so that starting cloudflared by hand on that box can never take
    # termio-api back off this one. Nothing running is touched.
    vm_ssh_n "[ -f ~/.cloudflared/config.yml ] && mv ~/.cloudflared/config.yml ~/.cloudflared/config.yml.disabled-pre-ampere || true"
    if vm_ssh_n "grep -qs 'termio-' /etc/cloudflared/config.yml"; then
        warn "/etc/cloudflared/config.yml still lists a termio hostname — check it by hand"
    else
        ok "no live config on the old VPS claims the termio hostnames"
    fi

    head_ "3/5 starting both tunnels here"
    am_ssh_n "cd $AM_STACKS/edge && docker compose up -d" 2>&1 | tail -5
    ok "edge stack up"

    head_ "4/5 DNS — deliberately not touched"
    # There is nothing to do here, and that is the design working rather than a
    # step being skipped: a tunnel hostname's DNS record is a CNAME to
    # <tunnel-uuid>.cfargotunnel.com, so it names the TUNNEL. Moving the tunnel
    # between machines leaves the record correct.
    #
    # An earlier version of this script called `cloudflared tunnel route dns
    # --overwrite-dns` as belt and braces. It cannot work here: ~/.cloudflared/
    # cert.pem on the old VPS is an "ARGO TUNNEL TOKEN" block, not the origin
    # CERTIFICATE that command needs, so cloudflared answers "cannot find a
    # valid certificate at the path". Getting a real one means `cloudflared
    # tunnel login` in a browser. Since the records already resolve to these
    # tunnels — proved by step 5 below, which fails loudly if they do not —
    # that login buys nothing.
    note "a tunnel's DNS record names the tunnel, not the box — nothing to change"

    head_ "5/5 probing the public hostnames"
    local waited=0 api_ok=0 site_ok=0
    while [ $waited -lt 120 ]; do
        curl -s -m 8 -X POST "$API_URL/api/query" -H 'Content-Type: application/json' \
            -d '{"path":"serverDirectory:current","args":{},"format":"json"}' 2>/dev/null | grep -q '"status":"success"' && api_ok=1
        [ "$(curl -s -o /dev/null -w '%{http_code}' -m 8 "$SITE_URL/" 2>/dev/null)" = "200" ] && site_ok=1
        [ $api_ok -eq 1 ] && [ $site_ok -eq 1 ] && break
        sleep 5; waited=$((waited+5))
        printf "%s    …%ss%s\r" "$C_DIM" "$waited" "$C_OFF"
    done
    [ $api_ok -eq 1 ] && ok "$API_URL answers" || warn "$API_URL is not answering yet"
    [ $site_ok -eq 1 ] && ok "$SITE_URL answers" || warn "$SITE_URL is not answering yet"

    printf "\n"
    note "confirm it is THIS box answering:"
    note "  ssh -i $AM_SSH_KEY $AM_USER@$AM_HOST 'docker logs --tail 20 edge-termio-tunnel'"
}

# ───────── verify ─────────

verify_local() {
    head_ "functions (through the loopback port on the box)"
    # An SSH tunnel to 127.0.0.1:3210, so this works before the public hostname
    # has moved and cannot be fooled by the old VPS still answering.
    local port=13210
    ssh $AM_SSH_OPTS -f -N -L $port:127.0.0.1:3210 "$AM_USER@$AM_HOST" 2>/dev/null
    sleep 2
    probe_functions "http://127.0.0.1:$port"
    local gap=$?
    pkill -f "ssh.*$port:127.0.0.1:3210.*$AM_HOST" 2>/dev/null
    if [ "$gap" -eq 0 ]; then ok "every probed function is present — the copy brought the modules across"
    else warn "$gap probed functions missing"; fi
}

verify() {
    require_ampere
    verify_local

    head_ "the box's health"
    am_ssh "bash -s" <<'REMOTE'
free -m | awk '/^Mem:/ {printf "  memory      %s MB available of %s MB\n", $7, $2}'
docker exec monkeyhub-convex-backend du -sh /convex/data 2>/dev/null | awk '{printf "  data        %s\n", $1}'
docker logs --tail 200 monkeyhub-convex-backend 2>&1 | grep -ci "error" | awk '{printf "  errors      %s in the last 200 log lines\n", $1}'
docker ps --format '  container   {{.Names}}  {{.Status}}'
REMOTE

    head_ "latency, measured on the box"
    # The idle-gap probe from tune-termio-vm.sh. A flat curve is a healthy box;
    # a spike that grows with the gap means the working set is being reclaimed.
    am_ssh_n 'D='"'"'{"path":"serverDirectory:current","args":{},"format":"json"}'"'"'
        for gap in 0 5 15 30; do sleep $gap; printf "  after %2ss idle: " $gap
            curl -s -o /dev/null -w "%{time_starttransfer}s\n" -X POST \
                http://127.0.0.1:3210/api/query -H "Content-Type: application/json" -d "$D"
        done'
}

# ───────── retire ─────────
#
# Stops MonkeyHub on the old VPS. Reversible: nothing is deleted.

retire() {
    require_vm
    head_ "what is about to happen on $VM_HOST"
    cat <<EOF
  MonkeyHub's containers (termio-backend, termio-etcd, termio-dashboard) stop
  and are disabled from restarting. Its Caddy site block is unimported.

  Nothing else on that box is touched. Note that as of 2026-08-21 there is
  nothing else running on it: nestzone and couplezone moved to another machine
  (their tunnel now connects from 92.5.100.185), their containers here are
  stopped, and no pocketbase process remains. Verified, not assumed.

  Nothing is deleted. The Convex data stays on disk; 'wipe-old' removes it.
EOF
    confirm retire

    head_ "recording which volume holds the data"
    # MUST happen before the containers go. /convex/data is on an ANONYMOUS
    # volume whose only label is com.docker.volume.anonymous — it carries no
    # compose project label, so once the container naming it is removed the
    # volume is orphaned and there is nothing left to look it up by. `wipe-old`
    # reads this stamp when the container is already gone.
    vm_ssh_n "docker inspect $VM_CONTAINER --format '{{range .Mounts}}{{if eq .Destination \"/convex/data\"}}{{.Name}}{{end}}{{end}}' > ~/.monkeyhub-convex-volume 2>/dev/null; cat ~/.monkeyhub-convex-volume" \
        | sed 's/^/    volume: /'

    head_ "stopping MonkeyHub's containers"
    vm_ssh_n "cd $VM_COMPOSE_DIR && docker compose down" 2>&1 | tail -4
    vm_ssh_n "docker update --restart=no $VM_CONTAINER termio-etcd termio-dashboard 2>/dev/null; \
              docker stop $VM_CONTAINER termio-etcd termio-dashboard 2>/dev/null" >/dev/null 2>&1
    ok "termio containers stopped, restart policy cleared"

    head_ "unimporting the MonkeyHub Caddy block"
    vm_ssh_n "sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak.pre-ampere && \
              sudo sed -i 's/^import monkeyhub.conf/# import monkeyhub.conf  # moved to the Ampere box/' /etc/caddy/Caddyfile && \
              sudo caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1 && \
              sudo systemctl reload caddy" \
        && ok "Caddy no longer serves MonkeyHub here" \
        || warn "could not update Caddy — check /etc/caddy/Caddyfile by hand"

    printf "\n"
    ok "MonkeyHub is retired from $VM_HOST. Its data is still on disk."
    note "when you are certain: $0 wipe-old"
}

# ───────── wipe-old ─────────
#
# The last step, and the only irreversible one.

wipe_old() {
    require_vm
    head_ "DESTRUCTIVE — deleting MonkeyHub's database on $VM_HOST"

    # Resolve the data volume, tolerating `retire` having already removed the
    # container that named it: fall back to the stamp retire wrote, then to the
    # volume's own mountpoint. Refuse rather than guess if none of it resolves —
    # an empty path here would turn `rm -rf` into a very bad command.
    local volname vol size
    volname=$(vm_ssh_n "docker inspect $VM_CONTAINER --format '{{range .Mounts}}{{if eq .Destination \"/convex/data\"}}{{.Name}}{{end}}{{end}}' 2>/dev/null | tr -d '\r\n'")
    [ -n "$volname" ] || volname=$(vm_ssh_n "cat ~/.monkeyhub-convex-volume 2>/dev/null | tr -d '\r\n'")
    [ -n "$volname" ] || die "cannot work out which volume holds /convex/data (no container, no stamp) — refusing to delete anything."
    vol=$(vm_ssh_n "docker volume inspect '$volname' --format '{{.Mountpoint}}' 2>/dev/null | tr -d '\r\n'")
    [ -n "$vol" ] || die "volume '$volname' no longer exists — nothing to delete."
    case "$vol" in /var/lib/docker/volumes/*) ;; *) die "refusing to delete an unexpected path: $vol" ;; esac
    size=$(vm_ssh_n "sudo du -sh '$vol' 2>/dev/null | cut -f1")

    cat <<EOF
  This deletes, permanently and with no backup on that box:

    the Convex data volume   $vol
                             ($size — database, storage blobs and modules)
    the site tree            /srv/monkeyhub
    the compose directory    $VM_COMPOSE_DIR

  This data is STALE — it stopped receiving writes on 2026-08-28, when traffic
  moved to the home server. It is not a backup of anything current.

  Before you type the word, be sure BOTH of these are true:
    • the Ampere box has been serving real traffic long enough to trust
    • the home server still holds its own copy as the rollback

  Nothing else on that box is touched — and as of 2026-08-21 there is nothing
  else running on it anyway (nestzone and couplezone moved to another machine).
EOF
    confirm wipe-old

    head_ "checking the Ampere box is actually serving first"
    local body; body=$(curl -s -m 10 -X POST "$API_URL/api/query" -H 'Content-Type: application/json' \
        -d '{"path":"serverDirectory:current","args":{},"format":"json"}' 2>/dev/null)
    printf '%s' "$body" | grep -q '"status":"success"' \
        || die "$API_URL is not answering — refusing to delete the old data while the new box is unproven."
    ok "$API_URL answers"

    head_ "deleting"
    vm_ssh_n "cd $VM_COMPOSE_DIR && docker compose down -v" 2>&1 | tail -3
    vm_ssh_n "docker rm -f $VM_CONTAINER termio-etcd termio-dashboard 2>/dev/null; \
              docker volume rm -f '$volname' 2>/dev/null; \
              [ -d '$vol' ] && sudo rm -rf '$vol' || true; \
              sudo rm -rf /srv/monkeyhub $VM_COMPOSE_DIR ~/.monkeyhub-convex-volume" 2>&1 | tail -3
    vm_ssh_n "docker image prune -af --filter 'label=org.opencontainers.image.title=convex' 2>/dev/null" >/dev/null 2>&1
    ok "MonkeyHub's data is gone from $VM_HOST"

    vm_ssh_n "df -h / | tail -1" | awk '{printf "  disk now    %s used of %s (%s free)\n", $3, $2, $4}'
}

# ───────── dispatch ─────────

case "${1:-status}" in
    status)   status ;;
    prepare)  prepare ;;
    copy)     copy ;;
    cutover)  cutover ;;
    ingress)  ingress ;;
    verify)   verify ;;
    retire)   retire ;;
    wipe-old) wipe_old ;;
    *)
        sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
        exit 1 ;;
esac
