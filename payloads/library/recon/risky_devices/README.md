# Shark Jack Display - Rogue / Risky Device Detector

Finds the devices nobody remembers plugging in and the ones that do not belong,
then writes a leadership-ready table:

```
Device | Manufacturer | Version | IP | Open Ports
```

It classifies every live host by fusing three signals: MAC OUI (with a built-in
table for Raspberry Pi and Espressif so they are caught even when the device's
OUI database is stale), an open-port fingerprint, and banners / OS / hostname.
Risky or unexpected devices are listed first (the leadership headline); the full
inventory follows.

> **Authorized use only.** Run only on networks you own or are contracted to
> assess, within the agreed scope and time window. Nothing is exfiltrated: all
> output stays on-device under `/root/loot/risky/` until you retrieve it. See the
> Legal and Disclaimer sections of the repository README.

## What it catches

Raspberry Pi / SBCs, consumer Wi-Fi routers and APs, printers / MFPs, IP cameras
and NVRs, DIY / IoT boards, and endpoints (laptops/desktops) exposing server,
database, or container ports they should not.

## Output (loot)

`/root/loot/risky/<UTC-timestamp>_<pid>/`:

```
summary.txt   <- flagged-for-review table + full inventory (read this first)
services.txt  <- combined nmap -sV -O output, per-host detail
snmp.txt       <- SNMP sysDescr (printer/switch firmware)
disc_*.gnmap services_*.txt   <- per-VLAN raw scans
```

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `DHCP_WAIT_SECS` | `30` | wait for a lease before failing |
| `NMAP_TIMING` | `-T4` | `-T3` quieter, `-T5` aggressive |
| `HOST_TIMEOUT` | `120s` | per-host budget |
| `OS_DETECT` | `1` | `nmap -O` (helps tell a server from a laptop) |
| `SNMP_LOOKUP` | `1` | pull SNMP sysDescr (printer/switch firmware) |
| `PORTSET` | (signal ports) | short classification-signal port list |
| `SCAN_TAGGED_VLANS` | `1` | **active VLAN-hopping** on a trunk; set `0` for client sites unless explicitly authorized |
| `VLAN_PROBE_IDS` | `""` | fallback VIDs if none are sniffed |
| `PASSIVE_VLAN_SECS` | `12` | passive 802.1Q listen window (needs `tcpdump`) |
| `LOOT_BASE` | `/root/loot/risky` | where loot lands |

## Requirements

- **`nmap`** (ships on the device). **`tcpdump`** optional, only for passive
  802.1Q tag sniffing on a trunk.

## LED / screen cues

`SETUP` -> `SPECIAL` (lease) -> `STAGE1` scan -> `STAGE4` classify -> `CLEANUP`
(writing loot) -> `FINISH`. Red `FAIL` means no DHCP lease or no live hosts.

## Notes

- `SCAN_TAGGED_VLANS=1` is active VLAN-hopping: noisy and intrusive. It no-ops on
  a plain access port. Leave it `0` unless the engagement authorizes it.
- Vendor "Unknown" in output is usually a stale `nmap-mac-prefixes` table, not a
  real gap.
