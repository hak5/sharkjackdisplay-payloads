# Shark Jack Display - Port ID Beacon

Plug it into an unknown wall jack and read the switch and port straight off the
OLED, usually in seconds:

```
Switch: MDF-SW-01
Port:   Gi1/0/47
```

It listens passively for a single LLDP or CDP frame, which already names the
switch and the exact port you are patched into, and **stops the instant it has an
answer**. That solves most of the "where does this cable actually go?" problem
without dragging a toner-and-probe kit or a second laptop to the closet.

> **Authorized use only.** Passive: no probes, no scans, no DHCP. Run only on
> networks you own or are contracted to assess. Minimal output stays on-device
> under `/root/loot/port_id/`.

## How it works

1. Brings `eth0` up with no address (announces nothing) and waits for carrier.
2. Captures only LLDP (`0x88cc`) and CDP (Cisco multicast) frames.
3. Polls the capture every couple of seconds and decodes the **switch name** and
   **port ID**, preferring LLDP and falling back to CDP.
4. Breaks the moment it has a result and shows it; writes a one-page summary.

Because it returns as soon as a frame arrives, it is typically near-instant. The
`WAIT_SECS` cap only matters on a switch that beacons slowly (CDP defaults to 60s)
or not at all.

## Output

On screen: `Switch:` and `Port:` (or `No LLDP/CDP heard` if the wait elapses).

In loot, `/root/loot/port_id/<UTC-timestamp>_<pid>/`:

```
summary.txt    <- switch, port, source (LLDP/CDP), port description, mgmt IP
lldp.txt / cdp.txt   <- full neighbor decode
capture.pcap   <- the frames it caught
```

The summary carries a little more than the screen (port description, switch
platform, management IP) for when you want it.

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `WAIT_SECS` | `75` | worst-case wait. LLDP beacons ~30s, CDP ~60s, so 75s guarantees a cycle. It is a cap: the payload breaks early on the first frame |
| `POLL` | `2` | how often to check the capture for a result |
| `LOOT_BASE` | `/root/loot/port_id` | where loot lands |

## Requirements

- **`tcpdump`** (not on stock firmware): `opkg update && opkg install tcpdump`.

## LED / screen cues

`SETUP` -> `SPECIAL` (listening, spinner) -> `FINISH` with the switch/port, or red
`FAIL` if no LLDP/CDP was heard. The result is also pushed as an `ALERT` so it
stays on screen.

## Notes

- **No result is a real answer too.** If the switch has LLDP/CDP disabled, or the
  jack lands on an unmanaged switch or a dumb injector, there is nothing to hear
  and it reports `No LLDP/CDP heard`. That itself tells you the upstream is not a
  managed switch advertising its identity.
- Works on 802.1X / NAC ports: it never requests an IP.
- For a full drop work-up (link, DHCP, VLAN, internet, mispatch detection) use the
  `jack_survey` payload instead; this one is the quick "just tell me the port"
  beacon.
