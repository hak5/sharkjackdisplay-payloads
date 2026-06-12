SMB Spy v2.0

Hak5 Shark Jack Display Payload

Author: Hackazillarex

Version: 2.0 (Shark Jack Display)

Category: Network Recon / Discovery


Description

SMB Spy is a network reconnaissance payload for the Hak5 Shark Jack Display. It automatically discovers live hosts on the local subnet, scans for open SMB (port 445) services, logs MAC addresses and vendor information, and generates next-step command suggestions for further investigation — all from the device's built-in display interface.


Features


Ping sweep — counts live hosts on the subnet before the main scan so you know what you're working with
SMB discovery — scans port 445 across the entire subnet using nmap
Network context logging — captures your assigned IP, default gateway, and DNS server at the top of every loot file
Scan timer — records exactly how long the SMB scan took
MAC & vendor identification — logs hardware address and manufacturer for each SMB host found
Next-step suggestions — writes ready-to-run smbclient, smbmap, and crackmapexec commands for every discovered target directly into the loot file
Interactive results menu — browse discovered hosts on the display after the scan completes
Loot file viewer — review previously saved scan results directly from the main menu without re-running a scan


Loot

All output is saved to /root/loot/smb_discovery/ on the device.

Each scan run produces two files:

FileContentssmb_hosts_YYYY-MM-DD_HH-MM-SS.txtParsed results, network info, scan timer, next-step suggestionsnmap_raw_YYYY-MM-DD_HH-MM-SS.txtRaw nmap output for the SMB scan

Example Loot File Output
=== SMB Spy v2.0 ===
Timestamp: 2024-11-01_14-32-10
My IP:   192.168.1.50
Gateway: 192.168.1.1
DNS:     192.168.1.1
Network: 192.168.1.0/24
--------------------------------
Live hosts on subnet: 12
Starting SMB discovery scan...
Scan duration: 47s

SMB OPEN: 192.168.1.10
  MAC: AA:BB:CC:DD:EE:FF
  Vendor: Dell Inc.

SMB OPEN: 192.168.1.25
  MAC: 11:22:33:44:55:66
  Vendor: Hewlett Packard

================================
NEXT STEP SUGGESTIONS
================================

Target: 192.168.1.10
  smbclient -L //192.168.1.10 -U user
  smbmap -H 192.168.1.10 -u user -p pass
  crackmapexec smb 192.168.1.10

Target: 192.168.1.25
  smbclient -L //192.168.1.25 -U user
  smbmap -H 192.168.1.25 -u user -p pass
  crackmapexec smb 192.168.1.25

Menu Structure

Main Menu
├── Start SMB Spy       → runs full scan sequence
├── View Loot Files     → browse saved scan results
└── Quit

Scan Sequence
1. Wait for Ethernet link
2. Request IP via DHCP
3. Log network info (IP, gateway, DNS)
4. Ping sweep → display live host count
5. nmap -p 445 scan with progress bar
6. Parse results → log SMB hosts + MAC/vendor
7. Write next-step suggestions to loot file
8. Display summary on screen
9. Optional: browse results interactively

Legal Notice

This payload is intended for use on networks you own or have explicit written permission to test. Unauthorized network scanning may be illegal in your jurisdiction. The author assumes no liability for misuse.
