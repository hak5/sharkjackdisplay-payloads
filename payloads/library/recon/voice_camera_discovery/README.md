# Shark Jack Display - Voice & Camera Discovery

Passively inventories the VoIP and physical-security estate on the segment it
lands on, **sending nothing**. In one capture window it identifies IP phones,
cameras and NVRs, and the voice VLAN the switch hands this port, then writes a
leadership-ready inventory. Built for physical-security reviews, office moves,
and M&A site surveys, the moments when "what cameras and phones are actually on
this network, and where?" is the whole question.

> **Authorized use only.** Passive capture only: no DHCP request, no probes, no
> scans, which makes it safe to run on a live client network. Run only on
> networks you own or are contracted to assess, within the agreed scope and time
> window, and do not retain third-party capture data beyond the engagement.
> Nothing is exfiltrated: all output stays on-device under
> `/root/loot/voice_camera/` until you retrieve it.

## How it identifies things

It does not trust any single source; it fuses passive signals and records the
evidence behind every classification:

| Device | Signals (strongest first) |
|--------|---------------------------|
| **Cameras / NVRs** | ONVIF **WS-Discovery** (UDP 3702), mDNS A/V services (`_onvif`, `_rtsp`, `_axis-video`, vendor types), MAC OUI |
| **IP phones** | mDNS **SIP** services, MAC OUI (Polycom, Yealink, Cisco, Avaya, Mitel, Grandstream, Snom, ...), DHCP vendor class |
| **Voice VLAN** | **LLDP-MED** Network Policy (Voice) and/or **CDP**, corroborated by the 802.1Q tag IDs seen on the wire |

Each inventory row carries an **Evidence** column (e.g. `ONVIF/WS-Discovery, OUI:Axis`),
so a high-confidence ONVIF hit reads differently from an OUI-only guess. A device
that announces via ONVIF but never ARPs during the window is still listed (with an
unknown MAC), so you do not miss a silent NVR.

## Scope: what "the segment" means (read this)

A single wired port only sees the **broadcast domain(s) it is in**. Multicast
discovery (WS-Discovery, mDNS, SSDP) and ARP only reach you from the VLAN your
port is on (or every tagged VLAN, if it is a trunk). So:

- **Voice VLAN detection works even from a phone/data access port**, because the
  switch advertises the voice VLAN to that port via LLDP-MED/CDP, and voice frames
  are tagged (visible in the 802.1Q tag list).
- **To inventory a dedicated camera VLAN, land on that VLAN or on a trunk.** From a
  data-only access port you will see the phones/cameras sharing that VLAN, but not
  devices isolated on a separate camera VLAN.

The report states this scope in its header so the deliverable is honest about what
it could and could not see.

## Output (loot)

`/root/loot/voice_camera/<UTC-timestamp>_<pid>/`:

```
summary.txt        <- voice VLAN + phone/camera inventory tables (read this first)
capture.pcap       <- full passive capture (open in Wireshark)
lldp.txt / cdp.txt <- neighbor + voice VLAN decode
wsdiscovery.txt    <- ONVIF WS-Discovery (camera/NVR)
mdns.txt / ssdp.txt <- service discovery
dhcp.txt           <- DHCP option decode (hostnames, vendor classes)
arp_hosts.tsv      <- passive host list (IP + MAC)
phones.tsv / cameras.tsv <- the inventory tables (tab-separated, for import)
```

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `LISTEN_SECS` | `180` | capture window. LLDP/CDP announce every 30-60s and phones/cameras beacon periodically, so `>=120s` is wise; longer catches more |
| `LOOT_BASE` | `/root/loot/voice_camera` | where loot lands |

## Requirements

- **`tcpdump`** (not on stock firmware): `opkg update && opkg install tcpdump`.
  `nmap` is not used by this payload, it never scans.

## LED / screen cues

`SETUP` -> `SPECIAL` (listening, with a progress bar) -> `STAGE1` (decoding) ->
`STAGE2` (classifying) -> `CLEANUP` (writing loot) -> `FINISH`. Red `FAIL` means
`tcpdump` is not installed. The final `ALERT` carries the phone count, camera
count, and the detected voice VLAN.

## Notes

- **Works on 802.1X / NAC ports**: it never requests an IP, so a port that will
  not hand out a lease is no obstacle to discovery.
- The OUI table is a curated convenience for well-known phone/camera vendors. The
  device's `nmap-mac-prefixes` is authoritative for vendor strings, and protocol
  evidence (ONVIF / mDNS / LLDP-MED) outranks OUI for classification. A vendor of
  `-` with strong protocol evidence is still a confident hit.
- Promiscuous mode is left on intentionally so multicast discovery frames arrive.
- Like the passive listener, this brings `eth0` up without an address
  (`ip link set eth0 up`) so it announces nothing. There is no passive/monitor
  `NETMODE` on this device.
- For the widest inventory, run a longer window and, where authorized, land on a
  trunk so every VLAN's discovery traffic is visible in one pass.
