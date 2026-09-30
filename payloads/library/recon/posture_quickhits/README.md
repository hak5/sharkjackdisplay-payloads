# Shark Jack Display - Security Posture Quick-Hits

Sweeps the live hosts for the findings that actually drive a remediation
proposal and writes them as a severity-tagged list. Targeted scripts run only
against hosts with the relevant port open, so it stays reasonably quick.

> **Authorized use only.** Run only on networks you own or are contracted to
> assess, within the agreed scope and time window. Default-community SNMP testing
> and SMB enumeration are standard assessment steps; stay within authorized
> scope. Nothing is exfiltrated: all output stays on-device under
> `/root/loot/posture/` until you retrieve it.

## What it checks

| Finding | Severity |
|---------|----------|
| SMBv1 still enabled | HIGH (ransomware-relevant) |
| SMB signing not required | HIGH |
| SNMP default community (`public`/`private`) responds | MED |
| Legacy cleartext: telnet (23), FTP (21), r-services (512/513/514) | MED / LOW |
| Exposed RDP (3389) / VNC (5900) | MED |
| Legacy TLS (1.0 / SSLv3), weak cipher grades (C/D/F) | LOW |

## Output (loot)

`/root/loot/posture/<UTC-timestamp>_<pid>/`:

```
summary.txt   <- severity-tagged findings + affected hosts (read this first)
smb.txt snmp.txt legacy.txt tls.txt   <- per-check raw nmap output
discovery.gnmap
```

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `DHCP_WAIT_SECS` | `30` | wait for a lease before failing |
| `NMAP_TIMING` | `-T4` | `-T3` quieter, `-T5` aggressive |
| `HOST_TIMEOUT` | `60s` | per-host budget so one slow host cannot stall the run |
| `SNMP_COMMUNITIES` | `"public private"` | default strings to test on UDP/161 |
| `SCAN_TAGGED_VLANS` | `1` | **active VLAN-hopping** on a trunk; set `0` for client sites unless explicitly authorized |
| `VLAN_PROBE_IDS` | `""` | fallback VIDs if none are sniffed |
| `PASSIVE_VLAN_SECS` | `12` | passive 802.1Q listen window (needs `tcpdump`) |
| `LOOT_BASE` | `/root/loot/posture` | where loot lands |

## Requirements

- **`nmap`** (ships on the device). **`tcpdump`** optional, only for passive
  802.1Q tag sniffing on a trunk.

## LED / screen cues

`SETUP` -> `SPECIAL` (lease) -> `STAGE1` scan -> `CLEANUP` (scoring findings) ->
`FINISH`. Red `FAIL` means no DHCP lease or no live hosts.

## Notes

- It scans every live host, so on a busy /24 run it on USB-C power.
- `SCAN_TAGGED_VLANS=1` is active VLAN-hopping: noisy and intrusive. It no-ops on
  a plain access port. Leave it `0` unless the engagement authorizes it.
