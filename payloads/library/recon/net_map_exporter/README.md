# Shark Jack Display - Network Map Exporter

Builds a field-observed topology map from a single wired drop and exports it in
formats you can drop straight into a deliverable: a Mermaid diagram, a Graphviz
DOT graph, a generic JSON graph model, and a plain-text summary. One plug-in,
one tidy map of "what is this drop actually connected to, and what lives on its
subnet?"

> **Authorized use only.** This payload is **active**: it pulls a DHCP lease and
> runs nmap against the access subnet. Run only on networks you own or are
> contracted to assess, within the agreed scope and time window. Nothing is
> exfiltrated: all output stays on-device under `/root/loot/network_map/` until
> you retrieve it.

## How it works

| Phase | What happens |
|-------|--------------|
| **Passive listen** | brings `eth0` up with no address and captures LLDP/CDP/ARP: switch name, the port you are patched into, VLAN, switch mgmt IP |
| **DHCP** | `NETMODE DHCP_CLIENT`, derives the lease, subnet CIDR, gateway, and DNS |
| **Discovery + service sample** | `nmap -sn` sweep of the access subnet, then `nmap -sV --top-ports` over the live hosts |
| **VLAN traversal** (opt-in) | passively sniffs 802.1Q tags, then for each tagged VLAN brings up `eth0.<vid>`, pulls DHCP, discovers + service-scans that subnet, and folds its hosts into the map labeled by VLAN/subnet |
| **Export** | merges passive + active data across every segment and writes the four output formats |

If DHCP fails the run is **not** aborted: it exports a passive-only map from the
LLDP/CDP/ARP data and ends amber to flag the partial result.

> **VLAN traversal is off by default** (`SCAN_TAGGED_VLANS=0`). Without it the map
> only covers the access subnet (the one VLAN your port lands on). Turn it on to
> map and scan the other VLANs a trunk carries, which is what makes the node count
> match a payload like `full_recon`. It is active VLAN-hopping: authorized
> engagements only, and a no-op on a plain access port.

## Output (loot)

`/root/loot/network_map/<UTC-timestamp>_<pid>/`:

```
summary.txt        <- observed topology + host count (read this first)
topology.json      <- generic {nodes, edges} graph model (ingest into other tools)
topology.mmd        <- Mermaid diagram (paste into a Markdown doc or mermaid.live)
topology.dot       <- Graphviz DOT (render: dot -Tpng topology.dot -o map.png)
passive.pcap       <- full passive capture
lldp.txt / cdp.txt <- neighbor decode
passive_arp.tsv    <- passively observed hosts (IP + MAC)
native.discovery.gnmap  native.services.{nmap,xml}   <- access-subnet raw nmap
vlan<id>.discovery.gnmap vlan<id>.services.{nmap,xml} <- per tagged-VLAN raw nmap
```

The graph is shaped `drop -> port -> switch`, then one **subnet node per segment**
(the access subnet plus each scanned VLAN) hung off the switch, with that
segment's gateway and hosts attached to it. Each subnet node and host carries its
VLAN/subnet in the JSON, so a multi-VLAN map stays unambiguous. Free-text labels
(switch descriptions, hostnames) are escaped per format, so a Cisco description
full of quotes, commas, and parentheses still produces valid `.mmd`/`.dot`/JSON.

## Configuration (top of [`payload.txt`](payload.txt))

| Knob | Default | Notes |
|------|---------|-------|
| `DHCP_WAIT_SECS` | `30` | wait for a lease before falling back to passive-only |
| `PASSIVE_LISTEN_SECS` | `75` | LLDP/CDP/ARP capture window (LLDP/CDP beacon every 30-60s) |
| `TOP_PORTS` | `100` | top-N TCP ports per host in the service sample |
| `NMAP_TIMING` | `-T4` | `-T3` quieter, `-T5` aggressive |
| `HOST_TIMEOUT` | `60s` | per-host budget so one slow host cannot stall the run |
| `PASSIVE_VLAN_SECS` | `15` | passive 802.1Q listen window (needs `tcpdump`) |
| `SCAN_TAGGED_VLANS` | `0` | **active VLAN-hopping**: scan each tagged VLAN and fold its hosts in. Set `1` for a full multi-VLAN map; leave `0` on an access port or when not authorized |
| `VLAN_PROBE_IDS` | `""` | fallback VIDs to try if none are sniffed, e.g. `"10 20 30"` |
| `LOOT_BASE` | `/root/loot/network_map` | where loot lands |

## Requirements

- **`nmap`** (ships on the device) for discovery and the service sample.
- **`tcpdump`** optional but recommended: it supplies the passive LLDP/CDP/ARP
  layer (switch, port, VLAN) and the 802.1Q tag sniff used for VLAN traversal.
  `opkg update && opkg install tcpdump`.
- **`ip`** and **`udhcpc`** (on the device) are used by VLAN traversal to bring up
  tagged sub-interfaces and lease each VLAN; `kmod-8021q` must be present for
  tagged interfaces (`opkg install kmod-8021q`).

## LED / screen cues

`SETUP` -> `SPECIAL` (passive listen) -> `STAGE1` DHCP -> `STAGE2` discovery ->
`STAGE4` VLAN map -> `STAGE5` per-VLAN scan (when `SCAN_TAGGED_VLANS=1`) ->
`CLEANUP` (writing exports) -> `FINISH`. If DHCP failed it ends on amber `SPECIAL`
(passive-only map). Red `FAIL` means `nmap` is missing. The final `ALERT` carries
the host count and segment count.

## Limitations / scope

- **It is a field-observed map from one vantage point**, not an authoritative
  switch-fabric map. With `SCAN_TAGGED_VLANS=1` it covers the access subnet plus
  the tagged VLANs the port trunks; VLANs the port does not carry, and segments
  reachable only via L3 routing, are still out of view. Combine runs from multiple
  drops or with switch management data for the whole estate.
- **VLAN traversal needs a trunk**: on a plain access port no tags are seen, so it
  maps just the one subnet (set `VLAN_PROBE_IDS` to force-try specific VIDs).
- On a busy /24 the service sample is the slow part; run on USB-C power and tune
  `TOP_PORTS` / `NMAP_TIMING` for the time you have.
- For a one-VLAN-only quick identity check use `port_id_beacon`; for a full
  drop validation use `jack_survey`. This payload is the one that produces
  importable topology artifacts.
