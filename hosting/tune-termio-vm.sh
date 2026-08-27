#!/bin/bash
# Fit the Convex backend into the Oracle VM's 956 MB.
#
#   ./hosting/tune-termio-vm.sh            status: where the box stands. Changes nothing.
#   ./hosting/tune-termio-vm.sh apply      the four steps below, then verify + status.
#   ./hosting/tune-termio-vm.sh reset-zram re-arm zram after a thrash has clogged its
#                                          slot table (status shows USED ≈ full while
#                                          DATA is a few MB). No restart — but only
#                                          on a calm box; it refuses under pressure.
#   ./hosting/tune-termio-vm.sh upgrade    pull a newer convex-backend image and
#                                          recreate. Same six-minute outage as `apply`.
#
# ───────── why `upgrade` exists ─────────
#
# Two of the caps in the compose file DO NOT EXIST in the image on the box (built
# 2026-03-10): INDEX_CACHE_SIZE and SOURCE_MAP_CACHE_MAX_SIZE_BYTES. The binary
# has no such strings, so the backend ignores them and the shared index cache —
# the single largest item at a 512 MiB default, on a 956 MB box — is still
# uncapped. It is the largest unapplied win available here, and the only way to
# collect it is a newer image. `image: …:latest` alone does not do that: compose
# will not re-pull a tag it already has locally, which is exactly why the box has
# been sitting on a March build.
#
# After it, check the log actually says the names were recognised:
#   docker logs termio-backend 2>&1 | grep Overriding
# INDEX_CACHE_SIZE appearing there is the whole point of the exercise.
#
# The diagnosis this answers is at the top of hosting/termio-docker-compose.yaml.
# In one line: the backend's default caches are sized for a fleet, it grew to a
# 1.35 GB working set on a 956 MB box, 1.27 GB of that lived in swap on the boot
# volume, and every query paged itself back in from disk before it could run.
#
# What `apply` does, in order. Every step is idempotent — re-running is a no-op.
#
#   1. Stops the Convex dashboard container and its auto-start. A Next.js
#      server idling at ~150 MB for a page opened a few times a month. The
#      command to bring it back for a session is printed at the end.
#   2. Enables zram: 512 MB of zstd-compressed swap IN RAM at priority 100,
#      ahead of the 4 GB /swapfile on the boot volume. Persisted as
#      zram-swap.service + a modules-load entry, so it survives a reboot. A
#      page that has to leave RAM now costs a memcpy to come back instead of a
#      block-volume read. The swapfile stays, as overflow.
#   3. Installs hosting/termio-docker-compose.yaml — the memory caps — after
#      backing up the copy on the box.
#   4. Recreates ONLY the backend container with the new environment
#      (`docker compose up -d backend`; etcd is untouched, the volume with
#      db.sqlite3 is untouched). This is the one visible step, and on this
#      disk it is a SIX-MINUTE outage, not a restart: the backend re-reads
#      the whole database while bootstrapping ("Bootstrapping table
#      metadata…" in its log) before it listens. Every client's socket drops
#      and reconnects afterwards, and pending sends retry on their own
#      (ChatRepository's reconnect sweep). Pick a quiet stretch, not a quiet
#      minute. The first `npx convex deploy` after it may need one retry.
#
# Rolling back: step 4 is reversed by restoring the backup this prints and
# running `docker compose up -d backend` again; step 2 by
# `sudo systemctl disable --now zram-swap`; step 1 by the dashboard command at
# the end. Nothing here touches data.
#
# Credentials: the same VM_HOST / VM_USER / VM_SSH_KEY as deploy.sh, with the
# same .env.local override.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# deploy-only overrides (VM_HOST etc.), never bundled — see deploy.sh.
if [ -f .env.local ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env.local
    set +a
fi

VM_HOST="${VM_HOST:-79.76.54.204}"
VM_USER="${VM_USER:-ubuntu}"
VM_SSH_KEY="${VM_SSH_KEY:-$HOME/Documents/BelesMakinem/ssh-key-2024-12-04-2.key}"
VM_SSH_OPTS="-i $VM_SSH_KEY -o BatchMode=yes -o ConnectTimeout=15"

# Where the compose project lives on the box. `docker inspect termio-backend`
# reports it under the com.docker.compose.project.config_files label.
COMPOSE_DIR="/home/ubuntu/convex-instances/termio-backend/self-hosted/docker"
COMPOSE_SRC="hosting/termio-docker-compose.yaml"

vm_ssh() { ssh $VM_SSH_OPTS "$VM_USER@$VM_HOST" "$@"; }

require_vm() {
    if [ ! -f "$VM_SSH_KEY" ]; then
        echo "❌ VM SSH key not found: $VM_SSH_KEY"
        echo "   Set VM_SSH_KEY in .env.local if the key lives elsewhere."
        exit 1
    fi
    if ! ssh $VM_SSH_OPTS -o StrictHostKeyChecking=accept-new "$VM_USER@$VM_HOST" true 2>/dev/null; then
        echo "❌ Cannot reach $VM_USER@$VM_HOST over SSH."
        exit 1
    fi
}

# ───────── status ─────────

status() {
    require_vm
    local local_sum
    local_sum=$(md5 -q "$COMPOSE_SRC" 2>/dev/null || md5sum "$COMPOSE_SRC" | cut -d' ' -f1)
    vm_ssh "bash -s" "$local_sum" "$COMPOSE_DIR" <<'REMOTE'
LOCAL_SUM="$1"; D="$2"
echo "── memory ──"
free -m | sed -n '1,3p'
echo
echo "── swap devices (zram0 should be listed, at PRIO 100) ──"
swapon --show
echo
echo "── zram: what it actually holds ──"
# USED above is the kernel's slot count and can sit at the full 512M while
# DATA here says a few MB: a thrash (a backend bootstrap does it) cycles
# pages through zram, and the slots stay claimed after the data is gone —
# from then on every swap-out goes to the disk swapfile instead. That is what
# 2026-08-27 looked like. The reset is cheap, because only DATA has to come
# back into RAM:   sudo swapoff /dev/zram0 && sudo swapon -p 100 /dev/zram0
zramctl 2>/dev/null || echo "zramctl unavailable"
echo
echo "── memory pressure (share of the last 10 s / 60 s / 5 min some task waited on memory) ──"
sed -n '1p' /proc/pressure/memory
echo
echo "── containers ──"
docker ps -a --format '{{.Names}}\t{{.Status}}' | grep '^termio' | sort
echo
echo "── convex-local-backend: resident vs. swapped ──"
for p in $(pgrep -f 'convex-local-backend' 2>/dev/null); do
    awk '/^VmRSS|^VmSwap/{printf "%s %s %s   ", $1, $2, $3} END{print ""}' "/proc/$p/status" 2>/dev/null
done
echo
echo "── compose file ──"
if [ -f "$D/docker-compose.yaml" ]; then
    remote_sum=$(md5sum "$D/docker-compose.yaml" | cut -d' ' -f1)
    if [ "$remote_sum" = "$LOCAL_SUM" ]; then
        echo "matches hosting/termio-docker-compose.yaml"
    else
        echo "DIFFERS from hosting/termio-docker-compose.yaml (apply not run, or edited on the box)"
    fi
    if docker inspect termio-backend --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -q '^INDEX_CACHE_SIZE='; then
        echo "running backend: memory caps ACTIVE"
    else
        echo "running backend: memory caps NOT active (container predates them)"
    fi
else
    echo "no docker-compose.yaml at $D"
fi
REMOTE
}

# ───────── apply ─────────

apply() {
    require_vm
    [ -f "$COMPOSE_SRC" ] || { echo "❌ Missing $COMPOSE_SRC"; exit 1; }

    echo "🧱 Tuning $VM_HOST for the backend's memory…"
    echo

    echo "1/4  Dashboard off (opt-in from now on)"
    vm_ssh "docker stop termio-dashboard >/dev/null 2>&1; docker update --restart=no termio-dashboard >/dev/null 2>&1; true"
    echo "     ✅ termio-dashboard stopped"

    echo "2/4  zram swap in RAM"
    if ! vm_ssh "sudo bash -s" <<'REMOTE'
set -e
modprobe zram
echo zram > /etc/modules-load.d/zram.conf
cat > /usr/local/sbin/zram-swap-start <<'EOF'
#!/bin/bash
# 512 MB of zstd-compressed swap in RAM, ahead of /swapfile.
# Managed by zram-swap.service; installed by hosting/tune-termio-vm.sh.
set -e
modprobe zram
[ -e /sys/block/zram0 ] || echo 0 > /sys/class/zram-control/hot_add
# Already up (a service restart): leave it alone.
grep -q zram0 /proc/swaps && exit 0
echo zstd > /sys/block/zram0/comp_algorithm
echo 512M > /sys/block/zram0/disksize
mkswap -L zram0 /dev/zram0 >/dev/null
swapon -p 100 /dev/zram0
EOF
cat > /usr/local/sbin/zram-swap-stop <<'EOF'
#!/bin/bash
swapoff /dev/zram0 2>/dev/null || true
echo 1 > /sys/block/zram0/reset 2>/dev/null || true
EOF
chmod +x /usr/local/sbin/zram-swap-start /usr/local/sbin/zram-swap-stop
cat > /etc/systemd/system/zram-swap.service <<'EOF'
[Unit]
Description=Compressed swap in RAM (zram0, zstd, 512M, prio 100 - ahead of /swapfile)

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/zram-swap-start
ExecStop=/usr/local/sbin/zram-swap-stop

[Install]
WantedBy=multi-user.target
EOF
# Swap-in from zram is a memcpy per page; readahead clustering only wastes
# them. And with a fast swap, evicting a cold anonymous page is cheaper than
# dropping a page of db.sqlite3 that the disk has to serve again, so the
# kernel is told to prefer it (the default 60 assumes swap is the slow one).
printf '# zram swap: no readahead, and prefer it over dropping file cache\nvm.page-cluster = 0\nvm.swappiness = 100\n' > /etc/sysctl.d/60-zram.conf
sysctl -q -p /etc/sysctl.d/60-zram.conf
systemctl daemon-reload
systemctl enable --now zram-swap.service >/dev/null 2>&1
grep -q zram0 /proc/swaps
REMOTE
    then
        echo "❌ zram did not come up. Nothing else has been changed yet."
        echo "   ssh in and run: sudo systemctl status zram-swap; sudo journalctl -u zram-swap"
        exit 1
    fi
    echo "     ✅ zram0 active at priority 100"

    echo "3/4  Compose file"
    local stamp backup
    stamp=$(date +%F)
    backup="docker-compose.yaml.bak-$stamp"
    scp $VM_SSH_OPTS "$COMPOSE_SRC" "$VM_USER@$VM_HOST:/tmp/termio-compose.yaml" >/dev/null || {
        echo "❌ Copy failed."; exit 1; }
    if ! vm_ssh "set -e; cd $COMPOSE_DIR; cp -n docker-compose.yaml $backup 2>/dev/null || true; cp /tmp/termio-compose.yaml docker-compose.yaml; docker compose config -q"; then
        echo "❌ docker compose rejected the file — the running backend is untouched."
        echo "   The previous file is $COMPOSE_DIR/$backup on the box."
        exit 1
    fi
    echo "     ✅ installed (previous copy: $COMPOSE_DIR/$backup)"

    echo "4/4  Recreating the backend container (clients reconnect on their own)"
    if ! vm_ssh "cd $COMPOSE_DIR && docker compose up -d backend 2>&1 | tail -3"; then
        echo "❌ docker compose up failed. Check: ssh … 'docker logs termio-backend --tail 50'"
        exit 1
    fi
    # Ninety seconds of probing, but two different endings. The backend
    # bootstraps for ~6 min on this disk before it listens (it re-reads the
    # database), so "not answering yet" is NOT the failure signal — the
    # container dying is. A dead or restarting container fails this in
    # seconds; a live one that is merely still loading gets a truthful
    # "still bootstrapping" and a clean exit, and status confirms it later.
    printf "     waiting for the backend to answer"
    local i state
    for i in $(seq 1 18); do
        state=$(vm_ssh "docker inspect termio-backend --format '{{.State.Status}}'" 2>/dev/null)
        if [ "$state" != "running" ]; then
            echo
            echo "❌ Container is '${state:-gone}' — it did not stay up. Look at:"
            echo "   ssh … 'docker logs termio-backend --tail 50'"
            echo "   Previous compose file: $COMPOSE_DIR/$backup"
            exit 1
        fi
        if vm_ssh "curl -sf --max-time 5 http://127.0.0.1:3212/version >/dev/null"; then
            echo
            echo "     ✅ backend up ($(vm_ssh 'curl -s --max-time 5 http://127.0.0.1:3212/version'))"
            break
        fi
        if [ "$i" = 18 ]; then
            echo
            echo "     ⏳ container is up but still bootstrapping — normal here (6 min 20 s on"
            echo "        2026-08-27: it re-reads the database before it listens). Not an error."
            echo "        Watch it:  ssh … 'docker logs -f termio-backend'  until it prints"
            echo "        'backend listening on 0.0.0.0:3210', then run: $0"
            exit 0
        fi
        printf "."
        sleep 5
    done

    echo
    status
    echo
    echo "Dashboard, when you want it (from $COMPOSE_DIR on the box):"
    echo "    docker compose --profile dashboard up -d dashboard"
    echo "    docker compose stop dashboard          # when done"
    echo
    echo "Give it a minute of real traffic, then re-run './hosting/tune-termio-vm.sh' and"
    echo "compare: VmSwap on the backend should be near zero and stay there."
}

# ───────── reset-zram ─────────

# The kernel counts a zram slot as used until the page that owned it is
# finally freed — and after a thrash cycles hundreds of MB through the device,
# the slots stay claimed long after zram has dropped their data. At that point
# every new swap-out goes to /swapfile on the boot volume, which is the exact
# thing zram was installed to prevent. swapoff only has to bring back what
# zram actually holds (the DATA column, a few MB), and the sysctl file is
# re-applied so swappiness lands too.
#
# ONLY ON A CALM BOX. While zram0 is being swapped off it takes no new pages,
# so anything the kernel reclaims in that window lands on the disk swapfile
# instead — on 2026-08-27, run at 30% memory pressure, that was 320 MB to
# disk and a five-minute thrash to recover from. The guard below refuses
# above 5% and is not to be argued with.
reset_zram() {
    require_vm
    local psi
    psi=$(vm_ssh "sed -n 's/^some avg10=\([0-9.]*\).*/\1/p' /proc/pressure/memory" 2>/dev/null)
    if [ -z "$psi" ] || [ "${psi%%.*}" -ge 5 ]; then
        echo "❌ Memory pressure is at ${psi:-?}% (10 s average) — not resetting zram now."
        echo "   Wait for a calm stretch (status shows the line) and run this again."
        exit 1
    fi
    echo "♻️  Re-arming zram0 on ${VM_HOST} (pressure ${psi}%)..."
    if ! vm_ssh "sudo bash -s" <<'REMOTE'
set -e
zramctl /dev/zram0 2>/dev/null || true
swapoff /dev/zram0
swapon -p 100 /dev/zram0
[ -f /etc/sysctl.d/60-zram.conf ] && sysctl -q -p /etc/sysctl.d/60-zram.conf
grep -q zram0 /proc/swaps
REMOTE
    then
        echo "❌ zram0 did not come back. Check: ssh … 'sudo zramctl; swapon --show'"
        exit 1
    fi
    echo "     ✅ zram0 re-armed at priority 100, sysctl re-applied"
    echo
    status
}

# ───────── upgrade ─────────

# Pull a current convex-backend image and recreate onto it.
#
# Separate from `apply` on purpose. `apply` is about THIS box's configuration
# and is safe to re-run forever; this one changes the software, and the caps it
# is chasing are only worth an outage when you have a quiet stretch to spend.
#
# The digest before and after is printed rather than the tag, because the tag
# does not change and is precisely what made this invisible for five months.
upgrade() {
    require_vm
    echo "⬆️  Upgrading the Convex backend image on $VM_HOST…"
    echo
    local before after
    before=$(vm_ssh "docker inspect ghcr.io/get-convex/convex-backend:latest --format '{{index .RepoDigests 0}}'" 2>/dev/null || echo "unknown")
    echo "1/3  Current image"
    echo "     $before"

    echo "2/3  Pulling"
    if ! vm_ssh "cd $COMPOSE_DIR && docker compose pull backend 2>&1 | tail -3"; then
        echo "❌ Pull failed — nothing has changed, the backend is still running."
        exit 1
    fi
    after=$(vm_ssh "docker inspect ghcr.io/get-convex/convex-backend:latest --format '{{index .RepoDigests 0}}'" 2>/dev/null || echo "unknown")
    if [ "$before" = "$after" ]; then
        echo "     ✅ already current — nothing to do, no outage taken."
        echo "     $after"
        exit 0
    fi
    echo "     ✅ new image"
    echo "     $after"
    echo

    echo "3/3  Recreating the backend (SIX-MINUTE outage on this disk — see the header)"
    if ! vm_ssh "cd $COMPOSE_DIR && docker compose up -d backend 2>&1 | tail -3"; then
        echo "❌ up failed. Roll back with:"
        echo "   ssh … 'cd $COMPOSE_DIR && docker compose down backend'"
        echo "   then pin the old digest in the compose file: $before"
        exit 1
    fi
    echo
    echo "Watch it come back:  ssh … 'docker logs -f termio-backend'"
    echo "Then confirm the caps the old build ignored are recognised now:"
    echo "    ssh … 'docker logs termio-backend 2>&1 | grep Overriding'"
    echo "INDEX_CACHE_SIZE in that list is the win this upgrade exists for."
    echo
    echo "If the new build misbehaves, roll back by pinning the old digest in"
    echo "hosting/termio-docker-compose.yaml and re-running '$0 apply':"
    echo "    $before"
}

case "${1:-status}" in
    status) status ;;
    apply)  apply ;;
    upgrade) upgrade ;;
    reset-zram) reset_zram ;;
    -h|--help|help)
        sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *)
        echo "Usage: $0 [status|apply|upgrade|reset-zram]"; exit 1 ;;
esac
