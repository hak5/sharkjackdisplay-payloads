# Shark Jack Display - PoE Survey

Tells you the Power-over-Ethernet posture of a drop before you commit an access
point, IP camera, or any other powered device to it: is the port PoE-capable, at
what class/type, and what power budget. It does this **passively**, by reading
what the switch advertises over LLDP and CDP, the same negotiation APs and
cameras themselves use.

> **Read this first: what this can and cannot do.** The Shark Jack is not a PoE
> powered device and has **no way to electrically measure** line voltage or
> current. Its NIC magnetics block DC, and it presents no PD signature, so a
> compliant switch never even energizes the port (which is also why this is
> safe). This payload therefore does **not** meter power. It reports what the
> switch *advertises* over LLDP/CDP, which is authoritative for what the port
> will negotiate, but only exists if the switch runs LLDP/CDP and advertises
> power. When nothing is advertised, the result is **inconclusive** and you
> should confirm with a hardware PoE tester.

> **Authorized use only.** Passive capture: no probes, no scans, no DHCP. Run
> only on networks you own or are contracted to assess, within the agreed scope
> and time window. Nothing is exfiltrated: all output stays on-device under
> `/root/loot/poe_survey/` until you retrieve it. See the Legal and Disclaimer
> sections of the repository README.

## What it reads

| Question | Source |
|----------|--------|
| **PoE present?** | LLDP 802.3 *Power-via-MDI* TLV: PSE-capable + power state (enabled/disabled), or a CDP power TLV |
| **PoE class / type?** | the advertised class (0-4); the payload maps it to its 802.3af/at power envelope |
| **Power budget?** | LLDP *Extended Power-via-MDI* PSE-allocated / PD-requested watts (0.1 W units), and Cisco CDP "Power Available" (mW) |

The report always prints the **raw power TLV lines** alongside the parsed values,
so you can see exactly what the switch said rather than trusting the parse.

## The verdict

| Verdict | Meaning |
|---------|---------|
| **PoE AVAILABLE** | the switch advertised PoE power on this port (LLDP and/or CDP). Class and watts are reported |
| **INCONCLUSIVE** | LLDP/CDP were heard but carried no power TLV. The port may be non-PoE, or PoE is simply not advertised. Confirm with a hardware PoE tester |
| **UNKNOWN** | no LLDP/CDP heard at all (unmanaged switch, a dumb injector, or LLDP/CDP disabled). Use a hardware PoE tester |

`INCONCLUSIVE` and `UNKNOWN` are honest outcomes, not failures: a passive read
cannot prove the *absence* of PoE, only confirm what is advertised.

## Output (loot)

`/root/loot/poe_survey/<UTC-timestamp>_<pid>/`:

```
summary.txt        <- verdict + parsed power + raw TLV lines (read this first)
capture.pcap       <- full passive capture (open in Wireshark)
lldp.txt / cdp.txt <- full neighbor decode
poe_lldp.txt / poe_cdp.txt <- the extracted power lines
```

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `LISTEN_SECS` | `120` | capture window. LLDP carries the power TLV every ~30s and CDP every ~60s, so `>=90s` catches a couple cycles |
| `LOOT_BASE` | `/root/loot/poe_survey` | where loot lands |

## Requirements

- **`tcpdump`** (not on stock firmware): `opkg update && opkg install tcpdump`.
  `nmap` is not used, this payload never scans.

## LED / screen cues

`SETUP` -> `SPECIAL` (listening, with a progress bar) -> `STAGE1` (reading power
TLVs) -> `CLEANUP` (writing loot) -> verdict LED. Green `FINISH` means **PoE
AVAILABLE**; amber `SPECIAL` means **INCONCLUSIVE** or **UNKNOWN**; red `FAIL`
means `tcpdump` is not installed. The final `ALERT` carries the verdict, class,
and allocated watts.

## Notes / accuracy

- **It reflects advertisement, not metering.** On a managed switch with LLDP-MED
  (common on AP/voice access ports) you will typically get class and allocated
  watts. On a switch that advertises only capability (not a live allocation),
  the class-to-power envelope is your guide to the budget.
- **Works on 802.1X / NAC ports**: it never requests an IP, so a locked-down port
  is no obstacle to reading LLDP/CDP.
- **Watts units**: LLDP power values are 0.1 W per 802.3at (the report shows both
  the raw value and the converted watts); CDP power is milliwatts.
- For a port behind a **dumb PoE injector** or an unmanaged PoE switch, there is
  no advertisement to read, so this returns `UNKNOWN`. That is the one case where
  only a hardware PoE tester (or actually plugging in the target device) will
  tell you.
