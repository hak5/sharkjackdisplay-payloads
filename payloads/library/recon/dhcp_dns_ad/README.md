# Shark Jack Display - DHCP + DNS / AD Profiler

Answers "what kind of network is this?" in one pass: it reads the whole DHCP
offer, finds the Active Directory domain and its domain controllers, attempts a
zone transfer, checks DNS hygiene, and samples host naming.

> **Authorized use only.** Run only on networks you own or are contracted to
> assess, within the agreed scope and time window. The AXFR attempt is a
> standard assessment check; keep it within authorized scope. Nothing is
> exfiltrated: all output stays on-device under `/root/loot/dhcp_dns_ad/` until
> you retrieve it.

## What it collects

| Section | How |
|---------|-----|
| **DHCP profile** | the whole offer: DNS, domain, NTP, lease time, PXE/TFTP (66/67), WPAD/proxy (252), server-id |
| **Active Directory** | SRV lookups (`_ldap`/`_kerberos`/`_gc`) to find domain controllers and confirm an AD domain |
| **Zone transfer** | attempts AXFR against the internal DNS (a classic, reportable misconfiguration) |
| **DNS hygiene** | open-recursion check on the internal resolver |
| **Naming sample** | low-noise reverse-PTR sweep (`nmap -sL`, no host probes) to learn host naming |

## Output (loot)

`/root/loot/dhcp_dns_ad/<UTC-timestamp>_<pid>/`:

```
summary.txt        <- read this first
dhcp.txt           <- full DHCP discover output
ad_srv.txt         <- AD SRV enumeration
axfr.txt           <- zone-transfer attempt
dns_recursion.txt  ptr_names.txt  vlan_profiles.txt
```

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `DHCP_WAIT_SECS` | `30` | how long to wait for a lease before failing |
| `DOMAIN_OVERRIDE` | `""` | force the AD domain if DHCP does not advertise one |
| `TRY_ZONE_TRANSFER` | `1` | attempt AXFR against the internal DNS server |
| `PTR_SWEEP` | `1` | reverse-resolve the local subnet for naming |
| `SCAN_TAGGED_VLANS` | `1` | **active VLAN-hopping** on a trunk; set `0` for client sites unless explicitly authorized |
| `VLAN_PROBE_IDS` | `""` | fallback VIDs if none are sniffed, e.g. `"2 3 10"` |
| `PASSIVE_VLAN_SECS` | `12` | passive 802.1Q listen window (needs `tcpdump`) |
| `LOOT_BASE` | `/root/loot/dhcp_dns_ad` | where loot lands |

## Requirements

- **`nmap`** (ships on the device). **`tcpdump`** optional, only for passive
  802.1Q tag sniffing on a trunk.

## LED / screen cues

`SETUP` -> `SPECIAL` (lease) -> `STAGE1` DHCP -> `STAGE2` DNS/AD -> `STAGE3`
per-VLAN -> `CLEANUP` -> `FINISH`. Red `FAIL` means no DHCP lease (NAC/802.1X,
no DHCP, or a dead drop).

## Notes

- `SCAN_TAGGED_VLANS=1` is active VLAN-hopping: noisy and intrusive. It no-ops on
  a plain access port. Leave it `0` unless the engagement authorizes it.
