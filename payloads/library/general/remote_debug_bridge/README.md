# Shark Jack Display - Remote Debug Bridge

Turns the Shark Jack into a temporary remote-troubleshooting appliance. Plug it
into the stranded network, walk to a desk, and reach the gear from a laptop
instead of from a cold aisle. It pulls an address, opens a **reverse SSH tunnel**
out to a jump host you control, exposes its own sshd back through that tunnel, and
**auto-reconnects** if the link blips, all while showing live status on the OLED
and logging every attempt on-device.

> Born from a three-day production outage debugging isolated Brocade VCS fabric
> nodes with five people plugged directly into switches in a datacenter. The
> point of this payload is to never have to do that again: drop it on the
> segment, and triage from the conference room.

> **Authorized use only.** This opens a remote-access path *into* a network. Run
> it only on networks you own or are contracted to support, with written
> authorization, and tear it down when the work is done. Auth is key-only to a
> jump host you control, with strict host-key checking; nothing is exfiltrated and
> local logs stay on-device under `/root/loot/debug_bridge/`. See the Legal and
> Disclaimer sections of the repository README.

## How it works

| Phase | What happens |
|-------|--------------|
| **Setup** | preflight: `ssh` present, key present, `JUMP_HOST` configured, jump host key pinned in `KNOWN_HOSTS`. Any miss fails fast with a screen hint |
| **Network up** | `NETMODE` per `NET_MODE` (DHCP / static / auto), waits for carrier and an IPv4 address, best-effort NTP sync |
| **Reachability** | pings the jump host (informational; it still tries SSH if ICMP is filtered) and writes the connection summary |
| **Bridge loop** | a short auth'd command proves egress + key auth and drops an "I'm alive" breadcrumb on the jump host, then opens `ssh -N -R` and holds it. On exit it reconnects (see below) |

## What you connect to

The reverse forward maps a port on the jump host's loopback back to the Shark
Jack's own sshd:

```
jump host 127.0.0.1:REMOTE_PORT  ->  Shark Jack 127.0.0.1:22
```

So from the jump host you run:

```
ssh -p 2222 root@127.0.0.1
```

and you land on the **Shark Jack**, which is L2-present on the stranded segment.
From that shell you reach the switches / fabric (`ssh admin@<switch-mgmt-ip>`,
set up further local forwards, etc). The Shark Jack is your beachhead; it is not
forwarding the switches directly.

## One-time setup

**1. Jump host** (a small always-on VM with a public IP). Create an unprivileged
user for the bridge:

```
sudo adduser --disabled-password sharkdebug
```

**2. Keypair on the Shark Jack:**

```
ssh-keygen -t ed25519 -f /root/.ssh/sharkjack_debug -N ""
```

**3. Authorize the key on the jump host** (paste `sharkjack_debug.pub` into the
jump user's `authorized_keys`). Optionally lock the key down to just this tunnel:

```
restrict,permitlisten="127.0.0.1:2222" ssh-ed25519 AAAA... sharkjack_debug
```

**4. Pin the jump host's key** on the Shark Jack (required, because the payload
enforces `StrictHostKeyChecking=yes`):

```
ssh-keyscan -p 22 <JUMP_HOST> >> /root/.ssh/known_hosts
```

**5. Edit the CONFIG block** of [`payload.txt`](payload.txt): set at least
`JUMP_HOST` (and `JUMP_USER` if you changed it). Deploy.

## Output (loot)

`/root/loot/debug_bridge/<UTC-timestamp>_<pid>/`:

```
summary.txt   <- connection info + how to connect + final status (read this first)
bridge.log    <- chronological attempt timeline (dials, uptimes, exit codes)
```

## Auto-reconnect behavior

The loop distinguishes a healthy session from a hard failure:

- A tunnel that stays up at least `STABLE_SECS` is treated as **healthy**. When it
  later drops, the consecutive-failure counter resets, so a long triage session
  survives any number of transient blips.
- Only **consecutive fast failures** (bad key, jump host down, `REMOTE_PORT`
  already bound) count toward `MAX_RETRIES`, with a backoff that grows on each
  repeat (capped at 60s). After `MAX_RETRIES` in a row, it gives up and ends red.

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `JUMP_USER` | `sharkdebug` | unprivileged user on the jump host |
| `JUMP_HOST` | `X.X.X.X` | **must set**: jump host public IP/DNS. Placeholder fails fast |
| `JUMP_PORT` | `22` | jump host sshd port |
| `REMOTE_BIND` | `127.0.0.1` | bind the listener to the jump host loopback (not public) |
| `REMOTE_PORT` | `2222` | jump-host port that maps back to the Shark Jack |
| `SSH_KEY` | `/root/.ssh/sharkjack_debug` | private key for the bridge |
| `KNOWN_HOSTS` | `/root/.ssh/known_hosts` | pinned jump host key |
| `NET_MODE` | `DHCP_CLIENT` | `STATIC` for a datacenter mgmt drop (fill `STATIC_*`), or `AUTO` |
| `STATIC_IP` / `STATIC_SUBNET` / `STATIC_GATEWAY` | `192.168.1.*` | used only when `NET_MODE=STATIC` |
| `DHCP_WAIT_SECS` | `30` | wait for an address before failing |
| `CONNECT_TIMEOUT` | `10` | per-dial TCP/auth timeout |
| `MAX_RETRIES` | `15` | give up after this many *consecutive fast* failures |
| `RETRY_SLEEP` | `10` | base wait between dials (grows on repeats) |
| `STABLE_SECS` | `60` | a tunnel up this long resets the failure counter |
| `LOOT_BASE` | `/root/loot/debug_bridge` | where loot lands |

## Requirements

- **`openssh-client` on the Shark Jack.** The options used (`ServerAliveInterval`,
  `ExitOnForwardFailure`, `UserKnownHostsFile`, etc.) are OpenSSH syntax. If your
  firmware ships only Dropbear, install it: `opkg update && opkg install
  openssh-client`.
- **The Shark Jack's own sshd** listening on `127.0.0.1:22` (this is how you
  manage the device, so it is normally already running).
- **A reachable jump host** running sshd with TCP forwarding allowed (the default).
  Binding to `127.0.0.1` needs no `GatewayPorts`.

## LED / screen cues

`SETUP` -> `SPECIAL` (network up) -> `STAGE1` (jump reachability) -> `STAGE2`
(dialing) -> `ATTACK` (tunnel up, solid). It cycles `STAGE2`/`ATTACK` across
reconnects. Red `FAIL` means a preflight failed (no `ssh`, missing key,
unconfigured `JUMP_HOST`, empty `KNOWN_HOSTS`), no network, or the reconnect
budget was exhausted. The OLED shows the current dial count, the reverse-forward
target, and reconnect state.

## Notes / limitations

- **The drop must have egress to the jump host.** The Shark Jack has one port: the
  network you land on must be able to reach `JUMP_HOST` on `JUMP_PORT` outbound. A
  fully air-gapped segment cannot form the tunnel.
- **Pick a free `REMOTE_PORT`.** If it is already bound on the jump host,
  `ExitOnForwardFailure` makes the tunnel exit immediately (counts as a fast
  failure). One Shark Jack per `REMOTE_PORT`.
- **Tear it down.** Pull the device when finished, and remove the key from the
  jump host's `authorized_keys` at the end of the engagement.
- **Keep the listener on loopback.** `REMOTE_BIND=127.0.0.1` means the bridge is
  reachable only by someone already on the jump host, not the public internet.
