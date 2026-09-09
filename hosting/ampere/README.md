# The Ampere box — `belesampere`, 129.151.223.191

MonkeyHub's production backend since this migration. Oracle Ampere A1:
**aarch64**, 2 vCPU, 11.9 GB RAM, 45 GB disk, no CPU steal, no swap (and none
needed). It replaces the 956 MB Oracle VM described in
`hosting/termio-docker-compose.yaml`, whose every setting was a clamp fighting
for room on a box that could only be fixed with more RAM.

Everything here is installed from this repo by `hosting/migrate-to-ampere.sh`.
**Edit these files, not the box** — an edit made on the box is lost on the next
install and exists in no history. `migrate-to-ampere.sh status` compares
checksums so the two cannot drift silently.

## Layout

```
/opt/stacks/                     one directory per Docker Compose stack
├── monkeyhub-convex/            production Convex + its dashboard
│   └── docker-compose.yml       ← hosting/ampere/convex-compose.yml
└── edge/                        every Cloudflare tunnel on this box
    ├── docker-compose.yml       ← hosting/ampere/edge-compose.yml
    └── cloudflared/
        ├── termio.yml           ← hosting/ampere/cloudflared/termio.yml
        ├── monkeyhub.yml        ← hosting/ampere/cloudflared/monkeyhub.yml
        ├── <tunnel-uuid>.json   secret, copied off the old VPS, 0600
        └── cert.pem             secret, Cloudflare account cert, 0600

/srv/monkeyhub/                  static content, rsynced here by deploy.sh
├── site/                        landing page + /j/<code> invites + .well-known
├── downloads/                   every platform's artifacts
└── web/                         the Flutter web build

/etc/caddy/
├── Caddyfile                    ← hosting/ampere/Caddyfile (one import line)
└── monkeyhub.conf               ← hosting/caddy-monkeyhub.conf, via deploy.sh --infra

docker network `edge`            external, shared: how tunnels reach any stack
docker volume `monkeyhub-convex-data`   the Convex data directory
```

## Why stacks are separate but share one network

Each stack is self-contained — its own directory, its own compose project, its
own lifecycle. `docker compose up/down` in one never touches another. The single
shared, `external` Docker network `edge` is what lets the tunnels in `edge/`
address containers in any other stack **by name** (`http://monkeyhub-convex-backend:3210`)
without publishing ports to the host.

That is the whole extension point. To add a second Convex backend — a staging
deployment, a second app — nothing here has to change:

1. `mkdir /opt/stacks/<name>` and put a `docker-compose.yml` in it that joins
   the `edge` network (copy the `networks:` block from `convex-compose.yml`).
2. Give it its own **named** volume and its own container names.
3. Add an `ingress:` entry to a tunnel config in `edge/cloudflared/` pointing at
   the new container name, and `docker compose restart` the edge stack.
4. Commit the compose file to `hosting/ampere/` so the box and git agree.

Host ports are not the coordination mechanism, so a second backend needs no port
arithmetic. The two loopback bindings that do exist (`127.0.0.1:3210`, `:6791`)
are for local debugging over an SSH tunnel, nothing else.

## Why Caddy is a host service and not a container

`./deploy.sh --infra` installs `hosting/caddy-monkeyhub.conf` to
`/etc/caddy/monkeyhub.conf`, runs `caddy validate` against the merged config and
then `systemctl reload caddy`. That contract is what keeps a bad site config from
ever taking the site down, and it is driven through systemd. Containerising Caddy
would mean rewriting that path in `deploy.sh` for no gain — the static content it
serves is a plain directory tree that `deploy.sh` rsyncs anyway.

So Caddy stays where `deploy.sh` expects it, and the one container that needs to
reach it (`edge-monkeyhub-tunnel`) does so through `host.docker.internal`.

Caddy listens on **:8081 only** — no :80, no :443, no certificates. Everything
public arrives through cloudflared, which dials out. This box needs no inbound
port beyond SSH, and no Oracle security-list change.

## The tooling already points here

`deploy.sh` defaults to this box in the file itself — `VM_HOST`,
`VM_USER` and `VM_SSH_KEY` — rather than relying on `.env.local`, because
`.env.local` is gitignored and a fresh checkout would otherwise deploy the site
to the retired machine. So `--web`, `--site` and `--infra` need no setup. Any of
the three can still be overridden from `.env.local` if the box or key moves:

```sh
VM_HOST=129.151.223.191
VM_USER=ubuntu
VM_SSH_KEY=$HOME/Documents/BelesMakinem/BelesAmpere.key
```

The key lives with the other machine keys, alongside a connect helper matching
the convention already in that folder:

```
~/Documents/BelesMakinem/BelesAmpere.key           0400, the private key
~/Documents/BelesMakinem/BelesAmpere.key.pub
~/Documents/BelesMakinem/BelesAmpere_connect.sh    ./BelesAmpere_connect.sh → a shell
```

`switchServer.sh` needs no change at all: it reads the deployment URL out of
`backend/.env.local`, and that hostname — `termio-api.walhallaa.com` — now
resolves to this box's tunnel. "primary" means this machine. The admin key
already in `backend/.env.local` works here too, because `instance_name` and
`instance_secret` came across inside the copied data directory.

## Operating it

```sh
# what is running
ssh -i ~/Documents/BelesMakinem/BelesAmpere.key ubuntu@129.151.223.191 'docker ps'

# the backend's log
ssh -i ~/Documents/BelesMakinem/BelesAmpere.key ubuntu@129.151.223.191 'docker logs --tail 50 monkeyhub-convex-backend'

# restart one stack, leaving the other alone
ssh -i ~/Documents/BelesMakinem/BelesAmpere.key ubuntu@129.151.223.191 'cd /opt/stacks/monkeyhub-convex && docker compose restart'

# the dashboard is public through the tunnel:
#   https://termio-dashboard.walhallaa.com
#   deployment URL: https://termio-api.walhallaa.com  (+ an admin key, below)
#
# or reach it without the tunnel by forwarding the loopback port:
ssh -i ~/Documents/BelesMakinem/BelesAmpere.key -L 6791:127.0.0.1:6791 ubuntu@129.151.223.191
#   then open http://127.0.0.1:6791
```

An admin key is minted on demand and never stored on disk:

```sh
ssh -i ~/Documents/BelesMakinem/BelesAmpere.key ubuntu@129.151.223.191 'docker exec monkeyhub-convex-backend ./generate_admin_key.sh | tail -1'
```
