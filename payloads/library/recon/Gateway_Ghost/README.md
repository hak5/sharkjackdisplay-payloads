Title: Gateway Ghost
Description: Captive portal logger
Author: Hackazillarex
Version: 1.0

A lightweight, dependency-free captive portal payload for the Shark Jack Display. It hijacks the guest network, forces devices to a "Connection Lost" login page, and captures credentials without requiring httpd, nginx, or python3.
⚡ Quick Specs

    Target: Shark Jack Display (Alphawise)
    Dependencies: socat, dnsmasq (pre-installed)
    Loot Location: /root/loot/ghost_portal/

    Files Generated:
    ghost_capture.log — captured credentials
    portal.log — HTTP request log
    error.log — service error log

🚀 How It Works

    DNS Sinkhole: Uses dnsmasq to redirect all DNS queries to the Shark Jack IP, forcing browsers to hit the portal.
    Gateway Lock: Removes the default route and disables IP forwarding, effectively "locking" the network until the portal is satisfied.
    HTTP Handler: A socat-driven shell script serves the portal HTML and parses POST data for credentials.
    Unlock: Once the user submits the form (or hits the /authorize endpoint), the gateway is restored and DNS redirects are cleared. (Currently not working yet)


⚠️ Known Limitations

For best capture rates, connecting devices should meet these conditions:

Condition:	                  Reason
New or cached-cleared device:	Previously visited pages may load from browser cache, bypassing the DNS lookup and portal trigger.
IPv6 disabled:	              Devices with IPv6 enabled may use IPv6 DNS servers assigned by the real router, bypassing the Shark Jack DNS sinkhole.
New page navigation:	        Visiting a fresh/uncached page triggers a DNS lookup, which the sinkhole catches.

How to Bypass (for testing)

    Clear browser cache: Ctrl+Shift+Del → Clear all → Reload
    Use Incognito/Private mode
    Disable IPv6 (Windows): Network Settings → Adapter Properties → Uncheck "Internet Protocol Version 6 (IPv6)"

📂 File Structure

/tmp/portal/
├── web/portal.html          # Captive portal HTML
├── dnsmasq.conf             # DNS configuration
├── dnsmasq_state_locked.conf # All-DNS-redirect-to-Shark-Jack rule
├── dnsmasq_state_unlocked.conf # Empty (normal DNS passthrough)
├── dnsmasq_state.conf       # Active state (symlink/copy of above)
├── toggle_gate.sh           # Lock/unlock gateway + DNS state
└── portal_handler.sh        # SOCAT HTTP request handler

/root/loot/ghost_portal/
├── ghost_capture.log        # 🎯 Captured credentials
├── portal.log               # HTTP request log
└── error.log                # dnsmasq & socat error output

🔧 Configuration

Edit variables at the top of setup_payload() to customize:
Variable:	Default	Description
RUN_DIR:	/tmp/portal	Working directory for config files
PORTAL_DIR:	$RUN_DIR/web	Location of portal.html
GHOST_IF:	eth0	Network interface to bind to
LOOT_BASE:	/root/loot/ghost_portal	Directory where logs are saved

To customize the portal design, edit the embedded HTML in the write_portal_files() function.

  🛠️ Troubleshooting

    Services not starting: Check /root/loot/ghost_portal/error.log for dnsmasq and socat output.
    Portal not showing up: Ensure the victim device has IPv6 disabled and has cleared its browser cache.
    Credentials missing: Verify ghost_capture.log permissions and that the POST request hits /ghostcapture.

Legal and Ethical Use

This payload is intended for educational purposes and authorized security testing only. 
Users are responsible for ensuring they have proper authorization before using this tool on any network.
The author is not responsible for any misuse of this software.
