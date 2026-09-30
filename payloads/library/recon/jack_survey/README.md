# Shark Jack Display - Jack Survey / Drop Validator

Plug it into one wall jack and walk away with a per-drop verdict. It answers the
four questions a site survey actually has to settle for every port:

- **Does this port work?** carrier, negotiated speed and duplex.
- **Where does it go?** LLDP/CDP switch name, model, and the exact port you are
  patched into, plus the switch management IP.
- **What VLAN is it?** the VLAN advertised by LLDP/CDP, with the access-subnet
  CIDR as a fallback hint.
- **Can users actually use it?** DHCP lease, gateway, DNS, and HTTP/HTTPS
  reachability out to the internet.

The run ends on a single tiered verdict (`PASS`, `PASS WITH NOTES`, `LIMITED`,
`MISPATCH SUSPECTED`, or `FAIL`) so a non-engineer walking the floor can label
each jack from the screen alone. This is the workhorse for infrastructure
consulting and M&A due-diligence walk-throughs where you have to certify a room
of drops fast.

> **Authorized use only.** Run only on networks you own or are contracted to
> assess, within the agreed scope and time window. The payload is mostly
> passive: it listens, requests one DHCP lease, and sends a few small outbound
> reachability probes to `INTERNET_TEST_HOST`. Nothing is exfiltrated: all output
> stays on-device under `/root/loot/jack_survey/` until you retrieve it.

## How it works

It runs quietest-first, the same opening order as the passive listener, so the
jack is profiled before it ever announces an address:

| Phase | What happens |
|-------|--------------|
| **Link** | brings `eth0` up and waits for carrier; reads negotiated speed/duplex |
| **Passive discovery** | a passive `tcpdump` capture harvests LLDP/CDP (switch, port, VLAN, mgmt IP), passive ARP host count, DHCP servers seen, and spanning-tree presence, all before requesting an address |
| **DHCP** | `NETMODE DHCP_CLIENT`, times the lease, derives IP / CIDR / gateway / DNS / domain; `nmap broadcast-dhcp-discover` adds lease time, NTP, PXE/TFTP, and WPAD/proxy detail |
| **Expected-value checks** | optional: compares observed switch / port / VLAN / CIDR against the `EXPECTED_*` knobs to flag a mispatched drop |
| **Internet tests** | DNS resolution plus HTTPS and HTTP reachability to `INTERNET_TEST_HOST` |
| **VLAN visibility / reachability** | reads tagged VLANs out of the passive capture (a tag means the port is really a trunk); optionally tags onto each VLAN to test what is reachable. No scanning. See the VLAN section below |
| **Report** | scores every check and writes the site-survey report |

## Output (loot)

`/root/loot/jack_survey/<UTC-timestamp>_<pid>/`:

```
summary.txt        <- verdict + per-check table + full detail (read this first)
checks.tsv         <- machine-readable PASS/WARN/FAIL/MISMATCH/INFO rows
passive.pcap       <- passive capture (open in Wireshark)
lldp.txt / cdp.txt <- full neighbor decode
arp_hosts.tsv      <- passively observed hosts (IP + MAC)
dhcp.txt           <- nmap DHCP discover detail
vlan_reach.txt     <- per-VLAN reachability probe (when PROBE_VLAN_REACH=1)
dns_test.txt / https_test.txt / http_test.txt
```

`summary.txt` leads with the verdict and a `[STATUS] label  detail` check table,
then breaks out physical link, DHCP, switch/port, VLAN (with a confidence note),
passive observations, and internet results.

## The verdict

| Result | Meaning |
|--------|---------|
| `PASS` | link, DHCP, and internet all good |
| `PASS WITH NOTES` | core checks passed, but warnings were recorded (e.g. sub-gig speed) |
| `LIMITED` | link is up but DHCP failed, or DHCP works but the internet is blocked/limited |
| `MISPATCH SUSPECTED` | an observed value does not match an `EXPECTED_*` you set |
| `FAIL` | no physical link (check patch panel, switch port, cable, or jack termination) |

## Configuration (top of [`payload.txt`](payload.txt))

Leave the `EXPECTED_*` values blank for a generic survey; fill them in when you
are validating a drop against a documented patch schedule and want mispatches
flagged automatically.

| Knob | Default | Notes |
|------|---------|-------|
| `LINK_WAIT_SECS` | `20` | seconds to wait for carrier before declaring the jack dead |
| `DHCP_WAIT_SECS` | `30` | wait for a lease before reporting DHCP failed |
| `PASSIVE_LISTEN_SECS` | `90` | passive LLDP/CDP capture window. LLDP/CDP announce every 30-60s, so >=90s catches a cycle |
| `INTERNET_TEST_HOST` | `example.com` | DNS + HTTP/HTTPS reachability target (RFC 2606 reserved documentation domain) |
| `EXPECTED_SWITCH` | `""` | expected LLDP/CDP switch name; mismatch flags a mispatch |
| `EXPECTED_PORT` | `""` | expected switch port ID |
| `EXPECTED_VLAN` | `""` | expected VLAN ID |
| `EXPECTED_CIDR` | `""` | expected access-subnet CIDR, e.g. `10.20.30.0/24` |
| `EXPECTED_SPEED_MIN` | `1000` | minimum Mbps; below this is a `WARN`. Empty disables the check |
| `EXPECTED_DUPLEX` | `full` | expected duplex; mismatch is a `WARN`. Empty disables the check |
| `PROBE_VLAN_REACH` | `0` | `1` = actively test which VLANs are *reachable* (tag on, try DHCP + gateway ping, tear down). Active VLAN tagging; authorized scope only |
| `VLAN_PROBE_IDS` | `""` | extra VIDs to test for reachability even if no tagged frames were seen, e.g. `"99 200"` |
| `VLAN_DHCP_WAIT` | `6` | per-VLAN DHCP timeout (seconds) during the reach probe |
| `LOOT_BASE` | `/root/loot/jack_survey` | where loot lands |

Note: `EXPECTED_SPEED_MIN` and `EXPECTED_DUPLEX` are checked even in generic mode,
so a 100 Mbps or half-duplex drop is flagged `PASS WITH NOTES` even when no
switch/port/VLAN is set. Blank either one to silence it.

## Requirements

- **`tcpdump`** for passive LLDP/CDP discovery (not on stock firmware:
  `opkg update && opkg install tcpdump`). Without it, link/DHCP/internet still
  run and switch identity is simply recorded as "not advertised".
- **`nmap`** (ships on the device) for the detailed DHCP offer; optional.
- **`nslookup`** and **`wget`** or **`curl`** for the DNS/internet tests. Each
  check degrades gracefully to "unknown" if its tool is missing.
- **`ip`** and **`udhcpc`** (busybox, on the device) are only used by the opt-in
  VLAN reach probe; `ping` is used for the gateway check. Without them the probe
  records "skipped" and everything else still runs.

## On the VLAN reading

A normal **access port** strips the 802.1Q tag before the frame reaches the
device, so the access VLAN *ID* is not directly observable from the jack. The
report is honest about this: if LLDP/CDP advertised a VLAN it is reported with
high confidence; otherwise the verdict falls back to the access-subnet CIDR as a
subnet hint and labels the VLAN confidence "low".

Beyond the access VLAN, the payload also reports the **port mode**, which is
where misconfigured drops give themselves away:

- **Visibility (passive, always on, free).** The opening passive capture runs
  with no address on the wire. An access port strips tags, so *any* tagged
  802.1Q frame in that capture means the port is actually a **trunk**. The report
  lists every tagged VLAN it saw and labels the port `access` or `trunk`
  accordingly. This is the cheap, zero-risk tell for a jack that is documented as
  an access port but was left trunking, or carries a voice VLAN, or sits behind a
  port-based routing rule that bridges VLANs it should not.
- **Reachability (opt-in, `PROBE_VLAN_REACH=1`).** For each VLAN it saw (plus any
  you list in `VLAN_PROBE_IDS`), it brings up an `eth0.<vid>` sub-interface, asks
  for a short DHCP lease, records the CIDR and gateway, pings the gateway once,
  then tears the sub-interface down. That answers "which other VLANs can this
  jack actually *reach*" end to end. A lease on a VLAN you did not expect, or a
  reachable gateway across VLANs, is exactly the symptom of a port-based routing
  rule or a CatOS/NXOS trunk-default mismatch.

Crucially, jack_survey **never scans** the other VLANs: no host sweep, no port
scan. Visibility is read from the capture it already took; reachability is a
single DHCP request and one gateway ping per VLAN. Both report as `INFO`, so they
enrich the survey without flipping the pass/fail verdict (a tagged voice VLAN is
common and not, on its own, a fault). If you want it louder, set an
`EXPECTED_VLAN` and read the tagged-VLAN list against it.

> The reach probe is active VLAN tagging and is the **last** step in the run, on
> purpose: it can briefly repoint the device's default route while a sub-interface
> is up (it restores `eth0`'s route afterward, best-effort). Leave
> `PROBE_VLAN_REACH=0` unless the engagement authorizes tagging onto other VLANs.

## LED / screen cues

`SETUP` -> `SPECIAL` (waiting for link) -> `STAGE1` passive discovery -> `STAGE2`
DHCP -> `STAGE3` internet tests -> `STAGE4` VLAN reach probe (only when
`PROBE_VLAN_REACH=1`) -> `CLEANUP` (writing report) -> verdict LED. A green
`FINISH` means `PASS` / `PASS WITH NOTES`; amber `SPECIAL` means `LIMITED` or
`MISPATCH SUSPECTED`; red `FAIL` means no link. The final `ALERT` carries the
verdict, the leased IP, and the negotiated speed/duplex.

## Notes

- **Walk-the-floor workflow**: leave all `EXPECTED_*` blank to certify whatever a
  jack happens to be, or paste a row from the patch schedule into the
  `EXPECTED_*` knobs to have the device call out mispatched cabling for you.
- **Trunk-on-an-access-jack is free to catch**: the port-mode line flags a jack
  that is really trunking even with `PROBE_VLAN_REACH` off, since it is read from
  the passive capture. Turn the reach probe on when you need to know *which*
  VLANs a misconfigured port actually bridges onto (the port-based routing rule
  / CatOS-to-NXOS trunk-default class of bug).
- **Works on dead and NAC'd drops too**: no carrier ends in a clean `FAIL` with a
  remediation hint; link-up-but-no-lease (802.1X / NAC / no DHCP) reports
  `LIMITED` rather than hanging.
- A run is roughly `PASSIVE_LISTEN_SECS` plus DHCP and probe time (about two to
  three minutes on defaults), so a battery charge covers a long corridor of jacks.
