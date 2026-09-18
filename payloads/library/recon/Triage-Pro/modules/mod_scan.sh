#!/bin/bash
# Triage Pro Fast Scan Script
# author: turkkat284
# description: This script performs a fast network scan using nmap and displays the results on the Shark Jack's OLED screen. It saves the scan results to a loot file for further analysis.

source /usr/bin/sharkjack_display_helpers.sh 2>/dev/null || true

LOOT_FILE="/root/loot/triage_pro/scan_$(date +%s).txt"
SCAN_FILE="/tmp/scan_results.txt"

DISPLAY_CLEAR
DISPLAY_TEXT "Fast Scan..." 0 0
DISPLAY_TEXT "Discovering Network" 0 16

SUBNET=$(ip route show dev eth0 | grep -v default | awk '{print $1}')

if [ -z "$SUBNET" ]; then
    DISPLAY_CLEAR
    DISPLAY_TEXT "=== SCAN RESULT ===" 0 0
    DISPLAY_TEXT "Status: No Subnet" 0 16
    DISPLAY_TEXT "Connect Network First" 0 32
    sleep 5
    exit 1
fi

DISPLAY_CLEAR
DISPLAY_TEXT "Scanning Subnet:" 0 0
DISPLAY_TEXT "$SUBNET" 0 16

nmap -F -T4 --open "$SUBNET" -oG $SCAN_FILE >/dev/null 2>&1

HOST_COUNT=$(grep -c "Status: Up" $SCAN_FILE 2>/dev/null || echo "0")
SMB_COUNT=$(grep "445/open" $SCAN_FILE | wc -l)
HTTP_COUNT=$(grep -E "80/open|443/open" $SCAN_FILE | wc -l)

DISPLAY_CLEAR
DISPLAY_TEXT "=== SCAN RESULT ===" 0 0
DISPLAY_TEXT "Hosts Up: $HOST_COUNT" 0 16
DISPLAY_TEXT "SMB (445): $SMB_COUNT" 0 32
DISPLAY_TEXT "HTTP: $HTTP_COUNT" 0 48

{
    echo "--- Fast Triage Scan Report ---"
    echo "Date: $(date)"
    echo "Subnet: $SUBNET"
    echo "Live Hosts: $HOST_COUNT"
    echo "SMB Ports Open: $SMB_COUNT"
    echo "HTTP/HTTPS Open: $HTTP_COUNT"
    echo ""
    echo "--- Raw Details ---"
    cat $SCAN_FILE 2>/dev/null
} > "$LOOT_FILE"

sleep 5