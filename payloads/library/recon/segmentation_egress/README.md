# Shark Jack Display - Segmentation + Egress Check

Characterizes what this one drop is allowed to reach: which outbound ports
actually escape, whether the path is direct / captive-portal / proxied / SSL-
inspected, which gateway admin ports answer from a user drop, and whether you can
reach the sensitive internal targets you list.

> **Authorized use only.** Run only on networks you own or are contracted to
> assess, within the agreed scope and time window. This payload sends probes to a
> configurable external IP and to the internal targets YOU specify: only set
> `SEG_TARGETS` to ranges the engagement authorizes. Nothing is exfiltrated: all
> output stays on-device under `/root/loot/segmentation/` until you retrieve it.
>

## What it checks

| Section | What you learn |
|---------|----------------|
| **Egress** | which outbound TCP ports escape to the internet (open/closed = allowed, filtered = blocked), plus outbound DNS |
| **Internet path** | direct vs captive-portal/proxy vs blocked; the cert issuer for an external HTTPS host (an internal CA issuer means SSL inspection) |
| **Gateway mgmt** | which admin ports on the gateway answer from a user drop (mgmt reachable from a user VLAN is a finding) |
| **Segmentation** | reachability to the sensitive internal targets you list in `SEG_TARGETS` |

## Output (loot)

`/root/loot/segmentation/<UTC-timestamp>_<pid>/`:

```
summary.txt        <- read this first
egress_tcp.txt egress_udp53.txt http_probe.txt
gateway_mgmt.txt   segmentation.txt (when SEG_TARGETS set)
vlan_egress.txt    <- per tagged-VLAN egress (when SCAN_TAGGED_VLANS=1)
```

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `DHCP_WAIT_SECS` | `30` | wait for a lease before failing |
| `EXT_IP` | `1.1.1.1` | external egress probe target. Point at an authorized/known target if a public resolver is not acceptable in your engagement |
| `EXT_HOST` | `example.com` | external hostname for HTTP/TLS path tests (RFC 2606 reserved documentation domain) |
| `EGRESS_PORTS` | common set | outbound ports to test |
| `SEG_TARGETS` | `""` | internal ranges to test reachability TO. Empty = gateway mgmt surface only. **Authorized scope only** |
| `SEG_PORTS` | common set | ports to test against `SEG_TARGETS` |
| `SCAN_TAGGED_VLANS` | `1` | **active VLAN-hopping** on a trunk; set `0` for client sites unless explicitly authorized |
| `VLAN_PROBE_IDS` | `""` | fallback VIDs if none are sniffed |
| `PASSIVE_VLAN_SECS` | `12` | passive 802.1Q listen window (needs `tcpdump`) |
| `LOOT_BASE` | `/root/loot/segmentation` | where loot lands |

## Requirements

- **`nmap`** (ships on the device). Optional: **`wget`** or **`curl`** and
  **`openssl`** for the HTTP/TLS internet-path test (it degrades gracefully if
  absent).

## LED / screen cues

`SETUP` -> `SPECIAL` (lease) -> `STAGE1` egress -> `STAGE2` internet path ->
`STAGE3` gateway mgmt -> `STAGE4` segmentation -> `STAGE5` per-VLAN -> `CLEANUP`
-> `FINISH`. Red `FAIL` means no DHCP lease.

## Notes

- `SEG_TARGETS` is empty by default on purpose: with no internal targets set, the
  payload only profiles egress and the gateway management surface.
- `SCAN_TAGGED_VLANS=1` is active VLAN-hopping: noisy and intrusive. It no-ops on
  a plain access port. Leave it `0` unless the engagement authorizes it.
