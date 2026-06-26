# Shark Jack Display - Wired Recon + Loot

A plug-and-walk-away wired reconnaissance payload for the Hak5 **Shark Jack
Display**. Drop it into an RJ45 port on an authorized network, give it a few
minutes, and pull a tidy loot report off the device.

This is a working tool for
> *authorized* network recon during tech-consulting engagements (office and
> datacenter walk-throughs, HID/AV/IoT debugging, inventory sanity checks).
> Treat it like any active scanner: in scope, in writing, in the time window.

## What it collects

| # | Goal | How |
|---|------|-----|
| 1 | **Router / gateway**: hostname, IP, MAC, vendor, OS + version | default route -> `nmap -O -sV` on the gateway |
| 2 | **VLANs / subnets**: VLAN ID + CIDR | access subnet from our lease (always); passive 802.1Q tag sniff on a trunk; optional active scan of each tagged VLAN (folds its hosts into the report, labeled by VLAN) |
| 3 | **Hosts**: hostname, IP, MAC, vendor, VLAN/subnet | `nmap -sn` ARP/ping sweep of the access subnet |
| 4 | **Open ports** per host: port/proto + service/version | `nmap -sV --top-ports N` over the live hosts |
| 5 | **Loot**: a human report + raw nmap artifacts | written to `/root/loot/recon/<run>/` |

## Output (loot)

Everything lands under `/root/loot/recon/<UTC-timestamp>_<pid>/`:

```
summary.txt                  <- the human-readable deliverable (read this first)
router.{nmap,gnmap,xml}      <- gateway scan + OS detection
discovery.{nmap,gnmap,xml}   <- host discovery sweep
services.{nmap,gnmap,xml}    <- service/version scan (XML imports into other tools)
vlans.txt                    <- VLAN / subnet findings
```

`summary.txt` is sectioned: run header, **ROUTER/GATEWAY**, **VLANs/SUBNETS**, a
**HOSTS** table (IP / hostname / MAC / vendor / VLAN), and **PER-HOST OPEN
PORTS**. The `.xml` files are kept so you can import a run into a notebook or
another tool back at the desk.

Nothing leaves the device. There is no callback or exfil: you retrieve loot
yourself over SSH/SharkLink.

## Tuning (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `NET_MODE` | `DHCP_CLIENT` | `STATIC` for static datacenter drops (fill `STATIC_*`), or `AUTO` |
| `DHCP_WAIT_SECS` | `30` | how long to wait for an address before failing out |
| `TOP_PORTS` | `200` | top-N TCP ports per host; raise to `1000` for depth, lower for speed |
| `NMAP_TIMING` | `-T4` | `-T3` quieter, `-T5` aggressive |
| `HOST_TIMEOUT` | `90s` | per-host budget so one slow host cannot stall the run |
| `ROUTER_OS_DETECT` | `1` | run `nmap -O` on the gateway (slower, but that is requirement 1) |
| `EXTRA_NMAP` | `""` | e.g. `--script nbstat` to add NetBIOS names |
| `RANDOMIZE_MAC_ADDR` | `0` | leave `0` for consulting work: NAC/inventory often key on MAC |
| `PASSIVE_VLAN_SECS` | `15` | passive 802.1Q listen window (needs `tcpdump`) |
| `SCAN_TAGGED_VLANS` | `0` | discover + scan hosts on tagged VLANs (auto-uses the sniffed tag IDs); see the VLAN note. **Off by default** |

## On VLAN discovery (read this)

A single access port only ever shows you **one** VLAN: the untagged access VLAN
the switch put that port on. The switch strips 802.1Q tags before the frame
reaches us, so a VLAN *ID* is simply not observable from an access port. The
payload is honest about that:

- **Always**: it records the access subnet **CIDR** from our own DHCP lease.
  That is the one VLAN you are actually on.
- **Passive (default, needs `tcpdump`)**: if the drop is a **trunk**, tagged
  frames carry their VLAN IDs in the clear. The payload listens briefly and
  records every tag ID it sees. On a normal access port this correctly reports
  "none (looks like an access port)".
- **Active (`SCAN_TAGGED_VLANS=1`, opt-in)**: for each tagged VLAN it found
  passively, it brings up an `eth0.<vid>` sub-interface, pulls a DHCP lease to
  recover that VLAN's **CIDR**, then **discovers and port-scans that subnet** and
  folds those hosts into the report labeled `vlan<vid>`. This is what surfaces
  devices living on other VLANs of a trunk (e.g. a Wi-Fi client VLAN). If no tags
  were seen, it falls back to `VLAN_PROBE_IDS`. This is VLAN-hopping: intrusive,
  noisy, slower (one scan pass per VLAN), and only appropriate on an engagement
  that explicitly authorizes it. Defaults **off**.

So: CIDR you always get; VLAN IDs you get on a trunk (passive); and with the
opt-in active scan you also get the **hosts and ports on each tagged VLAN**. The
report labels every host with the subnet/VLAN it belongs to.

## Limitations / gotchas

- **802.1X / NAC**: a port enforcing 802.1X will not hand you a lease. The
  payload fails cleanly (red LED, on-screen note, a `summary.txt` explaining
  why) rather than hanging.
- **Battery**: on-battery runtime is ~25-35 min. Defaults aim to finish a busy
  /24 inside that. For a big subnet or `TOP_PORTS=1000`, run on USB-C power.
- **Scope is L2-local**: it maps the segment the port lands on. Other subnets
  are only reached via the opt-in VLAN probe.
- **Requires `nmap`** (ships on the Shark Jack). `tcpdump` is optional and only
  used for passive tag sniffing (`opkg update && opkg install tcpdump`).

## LED / screen cues

`SETUP` (init) -> `SPECIAL` (waiting for a lease) -> `STAGE1` router -> `STAGE2`
discovery -> `STAGE3` port/service scan -> `STAGE4` VLANs -> `CLEANUP` writing
loot -> `FINISH`. Red `FAIL` means no usable network on `eth0`. The display
mirrors each phase via `SCREEN_WRITE`, shows a spinner during scans and a
progress bar while the report is assembled, and ends on an `ALERT` with the host
and open-port counts.

## Setup

Flash -> import the payload -> set it to autorun (or browse-and-run) -> deploy ->
retrieve loot.
