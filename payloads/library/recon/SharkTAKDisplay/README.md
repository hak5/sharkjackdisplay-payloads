# SharkTAKDisplay

<p align="center"><img src="https://raw.githubusercontent.com/SECT0101/SharkTAKDisplay/main/docs/logo.png" width="260" alt="SharkTAKDisplay: TAKtical Sharky"></p>

Wired network survey for the **Hak5 Shark Jack Display**, delivered to **TAK** (ATAK, WinTAK, iTAK, WebTAK, CloudTAK).

Plug the jack into a port, run a survey, and the results go to TAK in two parts:

- **A CoT marker at the jack's position.** The survey summary is in the remarks: subnet, gateway, DHCP servers, switch, port and VLAN, internet and public IP, host count, top open services, and baseline changes.
- **A data package attached to that marker.** It holds `summary.txt`, `hosts.tsv`, the nmap output (text and XML), the DHCP and LLDP details, the baseline diff and the packet capture. You can send it to one TAK contact or to everyone, or only upload it to the TAK Server.

If the network you plug into can't reach your TAK Server, the results are **queued**. Use *Send to TAK > Send Queue* the next time the jack is online.

> Use SharkTAKDisplay only on networks you own or are authorized to assess. It is a community payload and is not supported by Hak5.

## Scans

| Scan | What it does |
|---|---|
| **Fingerprint** | IP, gateway (with MAC), DNS, and link speed. DHCP servers, flagging **more than one as possible rogue DHCP**: the jack sends its own DHCP request without changing its address, and `tcpdump` catches every server that answers. Without tcpdump it reports its lease server, and with nmap-full it also runs `broadcast-dhcp-discover`. LLDP/CDP neighbor (switch, port, port description, VLAN, management IP, and LLDP-MED location), listened for in **receive-only** mode so the jack doesn't announce itself. SNMP `sysLocation` from the switch or gateway. Internet check, public IP and ISP, and whether the TAK Server is reachable. |
| **Hosts+Services** | nmap ARP/ping sweep, then `--top-ports` (default 100) with `-sV --version-light`. Light safe NSE scripts are optional: `http-title`, `ssl-cert`, `smb-os-discovery`, `smb2-security-mode`, `rdp-ntlm-info` and `banner`. These need **nmap-full**, since the firmware's basic nmap has no script engine. *Install Packages* offers to swap it in. The sweep never covers more than a /24 unless you raise *Max Subnet*. |
| **Baseline Diff** | Compares against a saved known-good scan for this network, which is keyed by subnet and gateway MAC, so every site gets its own baseline automatically. Reports **new devices**, missing devices, and new open ports on known devices. When there are changes, the marker turns yellow (unknown) and a GeoChat line goes to All Chat Rooms. |
| **Packet Capture** | `tcpdump` for N seconds (default 30). The pcap goes in the data package. |

**Full Survey** runs Fingerprint, Hosts+Services and Baseline Diff (when a baseline exists), plus the capture if *Capture in Survey* is on. It then offers to save a baseline for a new network, and to send.

## Location

The Shark Jack has no GPS or Wi-Fi radio, so location comes from the network or from you. In **auto** mode SharkTAKDisplay uses the first of these that works:

1. **LLDP-MED coordinates** from the switch, if the network publishes them (common where E911 is set up).
2. **Anchor to my ATAK**: your phone's last position, read from the TAK Server. Set *Location > My ATAK Callsign*. You're standing next to the jack, so this is usually accurate to a few meters. Positions older than 30 minutes are ignored.
3. **Saved site** (*Location > Saved Sites*, or *Save current*) or a **manual** lat/lon.
4. **Coordinates in the switch's SNMP or LLDP location text**, for example `Bldg 4 IDF 36.1627,-86.7816`.
5. **Public IP geolocation**, which is only accurate to about the city. The marker gets a 25 km CE so TAK shows that it's rough.
6. The last known position.

You can also force one method with *Location > Mode*. The CoT's `precisionlocation` and remarks always say which method was used.

The location is fixed **when the survey is sent or queued**, so a survey queued on-site keeps its on-site position even if it's sent later from home. The ATAK anchor needs the TAK Server to be reachable at that moment.

## Sending

*Send Survey* (also offered after every scan):

| Choice | Marker | Data package |
|---|---|---|
| **Contact** | to that contact only | file share to that contact |
| **Everyone** | to everyone | file share to everyone |
| **UploadOnly** | to everyone | uploaded to the TAK Server's Data Packages, no file share |
| **QueueOnly** | kept in the queue | kept in the queue |

The contact list comes from the TAK Server: the latest SA it sends after connecting, plus `/Marti/api/contacts/all` when you use a certificate.

When the jack talks to TAK it also sends its own position report (`a-f-G-E-S`, 5-minute stale), so it shows briefly as a contact. *Host Markers* (off by default) adds one marker per host in a 25 m ring around the jack. Those are **not** real device positions, and the remarks say so. New devices are yellow and known devices are neutral.

## Setup

On first run SharkTAKDisplay creates everything it needs. `/root/sharktakdisplay/certs/` gets a `README.txt` that explains what to put there, and the payload folder gets a `default.cfg` with every main setting. If the screen says *New here?*, go to **Settings > Setup Check**.

1. **Install the packages.** On a network with internet, run *Settings > Install Packages*. It installs `openssl-util`, `libopenssl-legacy`, `unzip`, `tcpdump` and `snmp-utils` in one go, then offers `nmap-full` (nmap scripts). If nmap-full won't install, basic nmap is put back. Do this at home, before deploying. Over SSH the same thing is `opkg update; opkg install openssl-util libopenssl-legacy unzip tcpdump snmp-utils`. Ignore the `hak5` feed error from `opkg update`, since that feed doesn't exist.
2. **Add your TAK certificate.** The easiest way is to make an ATAK **connection package** (`.zip`) for the jack on your TAK Server and copy it into the certs folder:

   ```
   scp sharkjack.zip root@JACK-IP:/root/sharktakdisplay/certs/
   ```
   SharkTAKDisplay reads the server, port and both certificates from it, then renames the zip to `.imported`. It asks for the `.p12` password only if the package's own password doesn't work. Copy the file itself, not a folder that holds it.

   Other ways in: `client.pem` (cert and unencrypted key) plus `ca.pem`; your `.p12` files, with the password entered on the device; or *Settings > TAK Server > Enroll* with your TAK username and password.
3. **Check the settings.** A connection package fills in the server. Otherwise set it on the device (*Settings > TAK Server > Server IP / Server Name*) or edit `default.cfg` in the payload folder over SSH:

   ```
   TAK_HOST: takserver.example.com
   TAK_PROTO: tls
   TAK_PORT: 8089
   API_PORT: 8443
   CALLSIGN: SHARK-1
   MY_ATAK: YOURATAKCALLSIGN
   ```
   Set `MY_ATAK` to the ATAK callsign on the phone you carry on-site. That's the callsign the location anchors to.

   SharkTAKDisplay keeps one line per setting and changes it in place, so edits made over SSH stay put across reboots. If the file ever has the same setting more than once, the next run tidies it up, keeps your values over the defaults, and saves the old file as `default.cfg.bak`.
4. **Run Settings > Setup Check.** It shows packages and TAK status (server, certificate, CA, callsign, anchor), offers to fix what's missing, and finishes with a link test.

SSH works while the payload runs, because the payload starts the SSH server, and *Settings > SSH / IP* shows the address. Outside the payload, the jack's IP is under *About > Networking*. In DHCP Server mode it's `172.16.24.1`. The default SSH login is `root` / `hak5shark`; change it.

**Coming from SharkTAK?** The first run moves `/root/sharktak` to `/root/sharktakdisplay`, along with your certs, queue, baselines and device UID, plus `/root/loot/sharktak`. It also copies the old payload folder's `default.cfg` if the new one has none. Then you can delete the old `SharkTAK` payload folder.

## Settings

| Key (`default.cfg`) | Default | Notes |
|---|---|---|
| `TAK_HOST` | `takserver.example.com` | placeholder, change it |
| `TAK_PROTO` | `tls` | `tls` (8089, cert), `tcp` (8087/8088), `udp` (send only, no contacts or anchor) |
| `TAK_PORT` / `API_PORT` / `ENROLL_PORT` | `8089` / `8443` / `8446` | API 8080 without a cert |
| `CALLSIGN`, `TEAM`, `ROLE` | `SHARK-1`, `Cyan`, `Team Member` | |
| `MY_ATAK` | (empty) | your ATAK callsign for the anchor |
| `ANCHOR_MAX_AGE` | `1800` | seconds |
| `LOC_MODE` | `auto` | `auto`, `atak`, `site`, `manual`, `ip` |
| `SITE`, `MANUAL_LAT`, `MANUAL_LON` | (empty) | |
| `IPGEO`, `IPGEO_URL` | `1`, `https://ipinfo.io/json` | set `IPGEO=0` to never contact a geolocation service |
| `SURVEY_NETMODE` | `DHCP_CLIENT` | or `STATIC` (Shark Jack `config.txt` values) |
| `SCAN_SCOPE` | `24` | largest subnet swept: `24`, `23`, `22`, `20`, `full` |
| `TOP_PORTS` | `100` | `20`, `100`, `300`, `1000` on the device |
| `SERVICE_VERSIONS`, `NSE` | `1`, `0` | |
| `HOST_TIMEOUT` | `90s` | per host |
| `LLDP_WAIT` | `35` | seconds; CDP can take up to 60 |
| `SNMP`, `SNMP_COMMUNITY` | `1`, `public` | |
| `PCAP_SECONDS`, `PCAP_MAX_PACKETS`, `SURVEY_PCAP` | `30`, `20000`, `0` | |
| `HOST_MARKERS`, `HOST_RING_M`, `MAX_HOST_MARKERS` | `0`, `25`, `40` | |
| `STALE_HOURS` | `24` | survey marker lifetime |
| `LISTEN` | `8` | seconds to listen for contacts |
| `CHAT_ALERT` | `1` | GeoChat when a baseline change or rogue DHCP is found |
| `SCAN_BATCH` | `4` | hosts per service-scan batch; each batch is saved as soon as it finishes |
| `BATCH_LIMIT` | `240` | seconds before a stuck batch is stopped and the scan moves on |
| `MIN_FREE_KB` | `30000` | version detection (`-sV`) needs about 20 MB, so it only runs with this much free memory |
| `WATCHDOG_KB` | `3000` | stop nmap if free memory falls below this, so the jack doesn't freeze |
| `SCAN_RATE` | `50` | nmap `--max-rate` in packets per second; the jack's Ethernet can lock up under floods |
| `SCAN_TYPE` | `connect` | `connect` (`-sT`, gentle) or `syn` (`-sS`, raw packets, faster) |
| `BIG_SCAN_HOSTS` | `24` | on battery, ask before a service scan of more live hosts than this |

## Menu

```
Full Survey
Scans        > Fingerprint, Hosts+Services, Baseline Diff, Packet Capture
Send to TAK  > Send Survey, Send Queue, Refresh Contacts, Test Link
Location     > Show Location, Anchor to ATAK, Saved Sites, Manual Lat/Lon, Mode, My ATAK Callsign
Baseline     > Compare Now, Save Baseline, Delete Baseline
Results      (summary, then browse hosts)
Settings     > Setup Check, Install Packages, SSH / IP, Show Settings, TAK Server >, Scan Options >, Output Options >
               TAK Server > Server IP, Server Name, Protocol, Ports, Callsign, Import Package, Certificate, Enroll
Quit
```

## Files

| Path | What |
|---|---|
| `/root/sharktakdisplay/certs/` | TAK certificates or the connection package (`chmod 700`, never share them) |
| payload folder `default.cfg` | settings (format `KEY: value`) |
| `/root/sharktakdisplay/queue/`, `sent/` | results waiting to be sent, and sent |
| `/root/sharktakdisplay/baselines/` | one known-good scan per network |
| `/root/sharktakdisplay/sites.txt` | saved sites: `name\|lat\|lon` |
| `/root/sharktakdisplay/contacts.txt` | TAK contacts last seen |
| `/root/loot/sharktakdisplay/<date-time>/` | every survey: summary, hosts, nmap, DHCP, LLDP, diff, pcap, data package |
| `/root/sharktakdisplay/logs/` | logs (`ssl.log`, `upload.log`, `opkg.log`, `p12.log`, `import.log`, `zipcheck.log`), plus `history.log` and `step`, the last step that was running. Kept on flash so they survive a shutdown or a flat battery |

## Battery

The battery lasts about 30 minutes, and a long service scan keeps the CPU at full load. On a busy network that can flatten the battery or shut the jack off. To reduce the damage:

- On battery with more than `BIG_SCAN_HOSTS` live hosts, SharkTAKDisplay asks before the service scan. *Lighter* scans the top 20 ports without version detection.
- Hosts are scanned in batches of `SCAN_BATCH`, and each batch is saved as it finishes, so a shutdown keeps what was already done.
- nmap runs at the lowest CPU priority (`nice`) as a connect scan (`-sT`), with `-T3`, a packet rate cap (`SCAN_RATE`) and capped parallelism, so the screen and SSH stay responsive. While scanning, `logs/vitals.log` records free memory, load and nmap's memory every 3 seconds, so a lockup leaves evidence. A watchdog checks memory every second and stops nmap if free memory falls below `WATCHDOG_KB`, before the jack can freeze; the results so far are kept. A batch that runs past `BATCH_LIMIT` is stopped, and the scan moves on. Version detection only runs with `MIN_FREE_KB` free, so on the Shark Jack Display the service scan is normally ports only.
- The last step is written to `/root/sharktakdisplay/logs/step`. After an unclean stop, the next start shows where it stopped.

For big networks, version detection, NSE or 1000 ports, run from a USB-C power bank.

## Notes

- SharkTAKDisplay doesn't do credential attacks or anything destructive. nmap uses `-T4 --max-retries 1` with a per-host timeout.
- The data package is a standard MANIFEST v2 package. OpenWrt 23.05 has no `zip` package for this chip, so SharkTAKDisplay writes the zip itself with the firmware's `gzip`, and checks each one with `unzip -t` before sending. Its files are attached to the survey marker, so in ATAK they appear under the marker's attachments after import.
- The ATAK anchor uses the TAK Server's latest SA (sent when a client connects) and falls back to `/Marti/api/cot/xml/<uid>` with a certificate.
