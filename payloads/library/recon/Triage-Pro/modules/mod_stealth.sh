#!/bin/bash
# stealth module
# author: turkkat284-ui
# description: Triage-pro stealth module

source /usr/bin/sharkjack_display_helpers.sh 2>/dev/null || true

LOOT_FILE="/root/loot/triage_pro/stealth_$(date +%s).txt"
CAP_FILE="/tmp/stealth_capture.cap"

DISPLAY_CLEAR
DISPLAY_TEXT "Stealth Mode..." 0 0
DISPLAY_TEXT "Listening LLDP/CDP" 0 16
DISPLAY_TEXT "Duration: 15s" 0 32

timeout 15 tcpdump -i eth0 -n -s 1500 -c 2 'ether proto 0x88cc or ether proto 0x2000' > $CAP_FILE 2>/dev/null

SWITCH_NAME=$(grep -a -oP 'System Name: \K.+' $CAP_FILE | head -n 1)
PORT_ID=$(grep -a -oP 'Port id: \K.+' $CAP_FILE | head -n 1)
VLAN_ID=$(grep -a -oP 'VLAN id: \K[0-9]+' $CAP_FILE | head -n 1)

DISPLAY_CLEAR
DISPLAY_TEXT "=== RECON RESULT ===" 0 0
DISPLAY_TEXT "Sw: ${SWITCH_NAME:-Unknown}" 0 16
DISPLAY_TEXT "Port: ${PORT_ID:-Not Found}" 0 32
DISPLAY_TEXT "VLAN: ${VLAN_ID:-None/Untagged}" 0 48

{
    echo "--- Passive Recon Report ---"
    echo "Date: $(date)"
    echo "Switch: ${SWITCH_NAME:-Unknown}"
    echo "Port: ${PORT_ID:-Not Found}"
    echo "VLAN ID: ${VLAN_ID:-None/Untagged}"
} > "$LOOT_FILE"

sleep 5