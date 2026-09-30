# Shark Jack Display - Passive Listener

Bring the link up, send (almost) nothing, and listen. In one window this
harvests everything the switch and the neighbors broadcast for free, with no
port scans and no unicast probes. It is the quietest opening move on an
unfamiliar wired drop.

> **Authorized use only.** Run only on networks you own or are contracted to
> assess, within the agreed scope and time window. Nothing is exfiltrated: all
> output stays on-device under `/root/loot/passive/` until you retrieve it.
>

## What it collects

| Source | What you learn |
|--------|----------------|
| LLDP / CDP | switch name, model, software, the port you are patched into, native VLAN, switch management IP |
| mDNS / SSDP / UPnP | device landscape (printers, Apple, TVs, cameras) |
| NetBIOS / LLMNR | Windows names and naming conventions |
| Passive ARP | live hosts with zero probes (IP + MAC + vendor) |
| DHCP / STP | DHCP servers seen, spanning-tree presence |

A single LLDP/CDP frame often describes the switching estate better than an hour
of scanning, which is why this runs first.

## Output (loot)

Everything lands under `/root/loot/passive/<UTC-timestamp>_<pid>/`:

```
summary.txt        <- human-readable summary (read this first)
capture.pcap       <- full passive capture (open in Wireshark)
lldp.txt / cdp.txt <- full neighbor decode
mdns.txt ssdp.txt netbios_ips.txt arp_hosts.tsv  <- per-protocol extracts
```

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `LISTEN_SECS` | `120` | capture window. LLDP/CDP announce every 30-60s, so >=90s catches a cycle |
| `LOOT_BASE` | `/root/loot/passive` | where loot lands |

## Requirements

- **`tcpdump`** (not on stock firmware): `opkg update && opkg install tcpdump`.
  `nmap` is not used by this payload.

## LED / screen cues

`SETUP` -> `SPECIAL` (listening) -> `STAGE1` (decoding) -> `CLEANUP` (writing
loot) -> `FINISH`. Red `FAIL` means `tcpdump` is not installed.

## Notes

- Works even on 802.1X / NAC ports: it never requests an IP, so a port that will
  not hand out a lease is no obstacle.
- Promiscuous mode is left on intentionally so multicast control frames arrive.
- This payload deliberately brings `eth0` up without acquiring an address
  (`ip link set eth0 up`) so it announces nothing. There is no passive/monitor
  `NETMODE` on this device; see the suite notes if your reviewer expects an
  explicit `NETMODE`.
