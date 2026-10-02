#!/bin/bash
# Title: Triage-Pro
# Author: turkkat284-ui
# Description: Interactive Network Triage & NAC Bypass Suite for Shark Jack Display

# Source display helpers
source /usr/bin/sharkjack_display_helpers.sh 2>/dev/null || {
    echo "[!] Display helpers not found"
    exit 1
}

# Get script directory for module paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
LOOT_DIR="/root/loot/triage_pro"

# Create directories
mkdir -p "$LOOT_DIR"
mkdir -p "$MODULES_DIR"

# Verify modules exist
verify_modules() {
    local modules=("mod_stealth.sh" "mod_nac.sh" "mod_scan.sh")
    for module in "${modules[@]}"; do
        if [ ! -f "$MODULES_DIR/$module" ]; then
            DISPLAY_CLEAR
            DISPLAY_TEXT "ERROR: Missing $module" 0 0
            DISPLAY_TEXT "Check module files" 0 16
            sleep 3
            return 1
        fi
    done
    return 0
}

show_menu() {
    DISPLAY_CLEAR
    DISPLAY_TEXT "=== TRIAGE PRO ===" 0 0
    DISPLAY_TEXT "1> Passive Recon" 0 16
    DISPLAY_TEXT "2> NAC Bypass" 0 32
    DISPLAY_TEXT "3> Fast Scan" 0 48
}

# Cleanup on exit
cleanup() {
    DISPLAY_CLEAR
    DISPLAY_TEXT "Triage-Pro Closed" 0 0
    exit 0
}

trap cleanup SIGINT SIGTERM

# Initial menu display
show_menu
sleep 1

# Main loop
while true; do
    EVENT=$(get_input_event 2>/dev/null)
    
    if [ -z "$EVENT" ]; then
        sleep 0.2
        continue
    fi

    case "$EVENT" in
        "UP"|"1")
            DISPLAY_CLEAR
            DISPLAY_TEXT "Starting..." 0 0
            DISPLAY_TEXT "Passive Recon" 0 16
            sleep 1
            
            if [ -f "$MODULES_DIR/mod_stealth.sh" ]; then
                bash "$MODULES_DIR/mod_stealth.sh"
                show_menu
            else
                DISPLAY_TEXT "ERROR: mod_stealth.sh" 0 0
                sleep 2
                show_menu
            fi
            ;;
            
        "SELECT"|"2")
            DISPLAY_CLEAR
            DISPLAY_TEXT "Starting..." 0 0
            DISPLAY_TEXT "NAC Bypass" 0 16
            sleep 1
            
            if [ -f "$MODULES_DIR/mod_nac.sh" ]; then
                bash "$MODULES_DIR/mod_nac.sh"
                show_menu
            else
                DISPLAY_TEXT "ERROR: mod_nac.sh" 0 0
                sleep 2
                show_menu
            fi
            ;;
            
        "DOWN"|"3")
            DISPLAY_CLEAR
            DISPLAY_TEXT "Starting..." 0 0
            DISPLAY_TEXT "Fast Scan" 0 16
            sleep 1
            
            if [ -f "$MODULES_DIR/mod_scan.sh" ]; then
                bash "$MODULES_DIR/mod_scan.sh"
                show_menu
            else
                DISPLAY_TEXT "ERROR: mod_scan.sh" 0 0
                sleep 2
                show_menu
            fi
            ;;
    esac
    
    sleep 0.2
done
