#!/bin/bash
# Title: Triage-Pro
# Author: turkkat284-ui
# Description: Interactive Network Triage & NAC Bypass Suite for Shark Jack Display


source /usr/bin/sharkjack_display_helpers.sh 2>/dev/null || true

# Loot klasörünü hazırla
LOOT_DIR="/root/loot/triage_pro"
mkdir -p "$LOOT_DIR"

show_menu() {
    DISPLAY_CLEAR
    DISPLAY_TEXT "=== TRIAGE PRO ===" 0 0
    DISPLAY_TEXT "1> passive Recon" 0 16
    DISPLAY_TEXT "2> NAC Bypass" 0 32
    DISPLAY_TEXT "3> Fast Scan" 0 48
}

show_menu

while true; do
    
    EVENT=$(get_input_event 2>/dev/null)

    case "$EVENT" in
        "UP"|"1")
            DISPLAY_CLEAR
            DISPLAY_TEXT "Passive Recon..." 0 0
            bash ./modules/mod_stealth.sh
            break
            ;;
        "SELECT"|"2")
            DISPLAY_CLEAR
            DISPLAY_TEXT "NAC Bypass..." 0 0
            bash ./modules/mod_nac.sh
            break
            ;;
        "DOWN"|"3")
            DISPLAY_CLEAR
            DISPLAY_TEXT "Fast Scan..." 0 0
            bash ./modules/mod_scan.sh
            break
            ;;
    esac
    sleep 0.2
done