# coturn — TURN relay for WebRTC calls

WebRTC peer-to-peer fails for users behind symmetric NAT (carrier-grade NAT,
some corporate networks). A TURN server relays media in those cases. Without
TURN ~10–15% of calls can't connect.

The client already supports TURN: it calls `calls:getIceConfig` before
creating the PeerConnection. When `TURN_URL` + `TURN_SECRET` are set in the
Convex environment, the action issues 1-hour scoped credentials and the
client receives them in the iceServers list. When the env vars are missing,
the action returns STUN-only and the client still works — TURN is purely
additive.

Recommended host: an Oracle Cloud Always-Free ARM Ampere VM (1 OCPU / 6 GB).
coturn relays at ~50 KB/s per call so the box handles thousands of
concurrent calls before the free tier's bandwidth quota matters.

---

## 1. Install coturn

Ubuntu 22.04/24.04:

```bash
sudo apt update
sudo apt install -y coturn
sudo sed -i 's/^#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn
```

## 2. Generate a secret

```bash
openssl rand -hex 32
```

Save the output — it goes into both `turnserver.conf` and Convex env vars.

## 3. Configure /etc/turnserver.conf

Drop in the template at `turnserver.conf.example` in this directory. Replace
the placeholders:

- `<VM_PUBLIC_IP>` — the Oracle VM's public IPv4 (from the Instance Details page).
- `<SHARED_SECRET>` — the openssl-generated hex string from step 2.

```bash
sudo cp turnserver.conf.example /etc/turnserver.conf
sudo nano /etc/turnserver.conf    # fill placeholders
```

## 4. Open the firewall

On the **Oracle Cloud console** → VCN → Security List → Ingress Rules, allow:

- 3478/tcp + 3478/udp (TURN control)
- 49152–65535/udp (TURN relay range)
- 5349/tcp (turns:// over TLS, optional but recommended)

On the **VM** (Ubuntu uses iptables under the hood — Oracle's default rules
block almost everything):

```bash
sudo iptables -I INPUT -p udp --dport 3478 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 3478 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 5349 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 49152:65535 -j ACCEPT
sudo netfilter-persistent save
```

## 5. Start coturn

```bash
sudo systemctl restart coturn
sudo systemctl enable coturn
sudo systemctl status coturn   # confirm "active (running)"
sudo journalctl -u coturn -n 50
```

## 6. Smoke test from any machine

Install coturn-utils locally (Mac: `brew install coturn`; Linux: `apt install
coturn`), then:

```bash
turnutils_uclient -t -T -u dummy -w <SHARED_SECRET> -v <VM_PUBLIC_IP>
```

Expect a series of `pinged` / `0 ms` lines. Failures here mean firewall or
config — fix before touching Convex.

## 7. Wire to Convex

In the Convex dashboard → Settings → Environment Variables, set:

- `TURN_URL` = `turn:<VM_PUBLIC_IP>:3478`
- `TURN_SECRET` = `<SHARED_SECRET>` (same value as in turnserver.conf)

That's it. The client's next call will fetch the new iceServers list
automatically — no app rebuild needed.

## 8. Verify from the app

During a call on opposite networks (one device cellular, one wifi), grep
the Flutter console for `iceConnectionState`. You should see candidates
with `typ relay` appear when direct P2P fails. If you only ever see
`typ host` / `typ srflx`, TURN isn't reachable — recheck firewall.

## 9. Optional: TLS via Let's Encrypt

`turn:` runs unencrypted over UDP/TCP. `turns:` (TLS on 5349) works in
networks that block raw UDP. Get a cert with certbot, point coturn at the
fullchain.pem / privkey.pem, then point a DNS A record at your VM and use
`turns:turn.your-domain.example:5349` as TURN_URL.

## Operational notes

- The shared-secret REST API generates per-user 1-hour credentials. No
  long-term password ships with the client; rotating `TURN_SECRET` cuts off
  active credential generation immediately (existing 1-hour tokens still
  work until they expire).
- coturn logs every relay session at INFO level. If you see suspicious
  bandwidth, `journalctl -u coturn | grep "session.*allocated"` shows who
  used it (per `username` = `<expiry>:<userId>`).
- The Oracle free tier has 10 TB/month egress. A 5-minute video call relayed
  through TURN uses ~15 MB. Math: ~660k call-minutes/month before you cap.
