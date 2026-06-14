# Shark Jack Display - Direct Host Profiler

Answers one question: **which physical device is HostXYZ?** When something on the
network is noisy or eating bandwidth but is not bad enough to justify blanket-
blocking its MAC on the switch, unplug the suspect, cable it straight into the
Shark Jack, and run this. The device gets a DHCP lease, announces who it is, gets
scanned, and lands in an identification report, all without ever touching the
production network.

> **Authorized use only.** Run only on devices you own or are contracted to
> assess, within the agreed scope and time window. This payload is active only
> against the single directly-attached device. The Shark Jack serves DHCP on its
> one Ethernet port and has no uplink, so the device gets an address but no route
> off the Shark Jack: it is isolated by construction and cannot reach the
> production network. Nothing is exfiltrated: all output stays on-device under
> `/root/loot/direct_host/` until you retrieve it. See the Legal and Disclaimer
> sections of the repository README.

## How it works

| Phase | What happens |
|-------|--------------|
| **Link** | brings `eth0` up, waits for carrier, reads speed/duplex |
| **DHCP server** | starts a passive `tcpdump`, then `NETMODE DHCP_SERVER` (the device's built-in server). No uplink exists, so the client gets an address but no path off the Shark Jack |
| **Capture** | the passive `tcpdump` runs the whole time, recording the DHCP exchange and any mDNS / NetBIOS / LLMNR the device announces |
| **Wait for client** | watches the ARP table for the device once it takes the lease (falling back to the assigned IP in the DHCP ACK), then holds the capture open briefly to collect name traffic |
| **Identify** | pulls the DHCP hostname (Option 12) and vendor-class (Option 60), the client MAC, mDNS `.local` names, and a NetBIOS name via `nmap --script nbstat` |
| **Scan host** | `nmap -sV -O` against **only** that one leased IP for ports, service/version, and an OS guess |
| **Report** | fuses every signal into a single device-identification verdict |

The report leads with the headline answer (resolved device name + type), then lists
every signal it used so you can see *why* it landed there.

## Output (loot)

`/root/loot/direct_host/<UTC-timestamp>_<pid>/`:

```
summary.txt        <- identity verdict + signals + open ports (read this first)
passive.pcap       <- full capture (open in Wireshark)
dhcp_packets.txt   <- decoded DHCP options (hostname, vendor-class, client MAC, Your-IP)
mdns_raw.txt / mdns_names.txt
netbios_raw.txt / nbstat.nmap
llmnr_raw.txt / llmnr_tokens.txt
services.nmap / services.gnmap / services.xml   <- single-host scan (XML imports)
```

## Identification signals

It does not trust any single source. The resolved **device name** prefers the
DHCP Option 12 hostname, then the NetBIOS name, then nmap's rDNS/PTR. The
**device type** is inferred by fusing the MAC vendor (OUI), the DHCP vendor-class
(e.g. `MSFT 5.0`, `android-dhcp-13`, `dhcpcd`), any announced names, the OS guess,
and the open-port fingerprint, so it can call out a printer, camera/NVR, Raspberry
Pi / SBC, IoT board, Windows / Apple / Linux host, or a mobile device.

## How it serves DHCP

It uses the device's built-in **`NETMODE DHCP_SERVER`**, which serves the unit's
`config.txt` subnet, rather than bundling its own `udhcpd` (not all firmware
images ship the `udhcpd` server applet). The isolation that matters here is
inherent, not configured: the Shark Jack has a single Ethernet port and no
uplink, so a directly-cabled client receives an address but has no route to the
internet or to anything else. One device at a time is a consequence of cabling
one device directly to the port.

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `LINK_WAIT_SECS` | `20` | wait for carrier before declaring no link |
| `CLIENT_WAIT_SECS` | `60` | how long to wait for the device to take a lease |
| `PASSIVE_LISTEN_SECS` | `45` | name-capture window held open after the lease |
| `PORTSET` | (identity ports) | TCP ports scanned on the one client |
| `NMAP_TIMING` | `-T4` | `-T3` quieter, `-T5` aggressive |
| `HOST_TIMEOUT` | `60s` | per-scan budget |
| `LOOT_BASE` | `/root/loot/direct_host` | where loot lands |

The served subnet comes from the unit's `config.txt` (used by `NETMODE
DHCP_SERVER`); adjust it there if it collides with the target's expectations.

## Requirements

- **`nmap`** (ships on the device). DHCP is served by the firmware's built-in
  `NETMODE DHCP_SERVER`, so no separate DHCP daemon is required.
- **`tcpdump`** recommended: it captures the DHCP hostname, vendor-class, and the
  mDNS / NetBIOS / LLMNR names. Without it, lease + port-scan still run and naming
  falls back to nmap alone (`opkg update && opkg install tcpdump`).

## LED / screen cues

`SETUP` -> `SPECIAL` (waiting for link) -> `STAGE1` DHCP server up -> `STAGE2`
waiting for the client -> `STAGE3` profiling the host -> `CLEANUP` (writing report)
-> `FINISH`. Red `FAIL` means no link or `nmap` missing. A `LIMITED` result means
the link came up but no device took a lease. The final `ALERT` carries the
resolved name and client IP.

## Notes / limitations

- **The device must be a DHCP client.** A statically-addressed host will not take
  a lease, so the run reports `LIMITED`. That is the common case for a noisy
  endpoint, but bear it in mind for appliances pinned to a static IP.
- **One device at a time**, by virtue of cabling a single device to the port.
- **No internet is offered to the device, on purpose.** It cannot phone home, get
  blocklisted, or be tipped off mid-profile; it also means cloud-only gadgets may
  reveal less than they would online.
- Vendor "Unknown" is usually a stale `nmap-mac-prefixes` table, not a real gap;
  cross-check the OUI against the DHCP vendor-class and announced names.
