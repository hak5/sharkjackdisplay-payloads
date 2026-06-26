#!/usr/bin/env bash
# ============================================================================
#  deploy-shark.sh - provision a Shark Jack Display from a repo + config file
# ----------------------------------------------------------------------------
#  A firmware update wipes the overlay (your payloads and the nmap OUI database
#  go with it). Run this afterward to push a chosen set of payloads from THIS
#  repository onto the device, applying any per-payload config overrides you
#  define in a config file.
#
#  Unlike a blind "push everything", you list exactly which payloads you want in
#  shark.conf and, under each, optional find-and-replace overrides applied to
#  that payload's payload.txt before it is sent (so your jump host IP, expected
#  switch names, etc. are baked in per deployment).
#
#  Quick start:
#    ./deploy-shark.sh --init          # write a starter shark.conf
#    $EDITOR shark.conf                # pick payloads + set overrides
#    ./deploy-shark.sh --dry-run       # render + validate, touch no device
#    ./deploy-shark.sh                 # provision the device
#
#  Run ./deploy-shark.sh --help for full usage.
# ============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
PAYLOAD_LIBRARY="$REPO_ROOT/payloads/library"
DEFAULT_CONFIG="$SCRIPT_DIR/shark.conf"
PREFIX_URL="https://raw.githubusercontent.com/nmap/nmap/master/nmap-mac-prefixes"
DEFAULT_IP="172.16.24.1"        # Shark Jack arming-mode address

# ---- logging (all to stderr so function stdout stays clean) ----------------
info() { printf '%s\n' "$*" >&2; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

# ---- usage -----------------------------------------------------------------
usage() {
  cat <<EOF
deploy-shark.sh - provision a Shark Jack Display from this repo + a config file

USAGE
  ./deploy-shark.sh [options]

OPTIONS
  -h, --help          Show this help and exit.
  --init [FILE]       Write a starter config (template) and exit. Default
                      target is shark.conf next to this script. Refuses to
                      overwrite unless --force is given.
  --config FILE       Use FILE instead of the default ($DEFAULT_CONFIG).
  --dry-run           Render payloads with their overrides applied and report
                      what WOULD be pushed. Touches no device, asks for nothing.
  --no-oui            Skip installing the nmap MAC/OUI database.
  --force             Allow --init to overwrite an existing config.

CONFIG FILE (shark.conf)
  Sectioned, one section per payload to load. Create one with --init.

    [options]                          # optional global settings
    shark_ip = 172.16.24.1             # default device IP (password is always
                                       #   prompted, never stored)
    install_oui_db = yes               # yes/no

    [payload_name]                     # the payload's dir under payloads/library/
      FIND --> REPLACE                 # optional literal find/replace applied to
                                       #   this payload's payload.txt before push.
                                       #   FIND must match the line EXACTLY.

  A payload section with no FIND --> REPLACE lines is pushed unchanged. Lines
  starting with # are comments. shark.conf is gitignored: keep your real IPs,
  hostnames, and overrides there.

WHAT IT DOES
  1. Reads the config and resolves each named payload under payloads/library/.
  2. Applies each payload's overrides to a temporary copy (warns loudly if a
     FIND string is not present, so a typo cannot silently no-op).
  3. Pushes each as /root/library/my_payloads/<name>/payload.txt.
  4. Installs the nmap OUI database (unless --no-oui).

AUTH
  Uses sshpass if installed (password entered once). Otherwise falls back to a
  single shared SSH connection that prompts once.
    macOS: brew install hudochenkov/sshpass/sshpass
EOF
}

# ---- template config (used by --init and shipped as shark.conf.example) -----
template_config() {
  cat <<'EOF'
# ============================================================================
#  shark.conf - deploy configuration for deploy-shark.sh
# ----------------------------------------------------------------------------
#  Pick which payloads to load onto the Shark Jack Display, and optionally
#  override config values inside each payload before it is pushed.
#
#  FORMAT
#    [options]                         global settings (optional)
#      shark_ip = 172.16.24.1          default device IP (password is prompted)
#      install_oui_db = yes            install the nmap OUI database (yes/no)
#
#    [payload_name]                    one section per payload to load. The name
#                                      is the payload's directory under
#                                      payloads/library/<category>/.
#      FIND --> REPLACE                optional. Literal find-and-replace applied
#                                      to that payload's payload.txt before it is
#                                      pushed. FIND must match the line EXACTLY
#                                      (copy it from the payload's CONFIG block).
#
#  A payload section with no FIND --> REPLACE lines is loaded unchanged.
#  Lines starting with # are comments. This file is gitignored: keep your real
#  IPs / hostnames / secrets here.
# ============================================================================

[options]
shark_ip = 172.16.24.1
install_oui_db = yes

# --- Load the port-ID beacon, unchanged ---
[port_id_beacon]

# --- Load jack_survey, pre-filled with the drop you expect ---
[jack_survey]
EXPECTED_SWITCH="" --> EXPECTED_SWITCH="MDF-SW-01"
EXPECTED_VLAN="" --> EXPECTED_VLAN="20"

# --- Load the remote debug bridge, pointed at your jump host ---
[remote_debug_bridge]
JUMP_HOST="X.X.X.X" --> JUMP_HOST="203.0.113.10"
JUMP_USER="sharkdebug" --> JUMP_USER="bridge"
EOF
}

# ---- config parsing helpers (awk; bash 3.2 safe; tolerate CRLF) ------------
# List payload section names in file order (excludes [options]).
list_payloads() {
  awk '
    { sub(/\r$/,"") }
    /^[[:space:]]*\[.*\][[:space:]]*$/ {
      s=$0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/,"",s)
      if (s != "options" && s != "") print s
    }
  ' "$CONFIG"
}

# Print the FIND --> REPLACE lines belonging to one payload section.
overrides_for() {
  awk -v sec="$1" '
    { sub(/\r$/,"") }
    /^[[:space:]]*\[.*\][[:space:]]*$/ {
      s=$0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/,"",s); cur=s; next
    }
    cur==sec {
      line=$0; sub(/^[[:space:]]+/,"",line); sub(/[[:space:]]+$/,"",line)
      if (line=="" || line ~ /^#/) next
      print line
    }
  ' "$CONFIG"
}

# Read a key from the [options] section.
get_option() {
  awk -v key="$1" '
    { sub(/\r$/,"") }
    /^[[:space:]]*\[.*\][[:space:]]*$/ {
      s=$0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/,"",s); cur=s; next
    }
    cur=="options" {
      line=$0; sub(/^[[:space:]]+/,"",line); sub(/[[:space:]]+$/,"",line)
      if (line=="" || line ~ /^#/) next
      n=index(line,"="); if (n==0) next
      k=substr(line,1,n-1); v=substr(line,n+1)
      gsub(/[[:space:]]+$/,"",k); gsub(/^[[:space:]]+/,"",k)
      gsub(/^[[:space:]]+/,"",v); gsub(/[[:space:]]+$/,"",v)
      if (k==key) { print v; exit }
    }
  ' "$CONFIG"
}

# Literal (non-regex) global find/replace on a file, to stdout.
apply_override() {
  awk -v find="$2" -v repl="$3" '
    { sub(/\r$/,"")
      out=""; rest=$0
      while ((p=index(rest,find))>0) { out=out substr(rest,1,p-1) repl; rest=substr(rest,p+length(find)) }
      print out rest }
  ' "$1"
}

# Resolve a payload name to its payload.txt under payloads/library/<cat>/<name>/.
resolve_payload() {  # echoes path on success, empty on failure
  local name="$1" matches=()
  shopt -s nullglob
  matches=( "$PAYLOAD_LIBRARY"/*/"$name"/payload.txt )
  shopt -u nullglob
  [ ${#matches[@]} -eq 0 ] && return 1
  [ ${#matches[@]} -gt 1 ] && warn "multiple payloads named '$name'; using ${matches[0]}"
  printf '%s\n' "${matches[0]}"
}

# Render one payload (apply its overrides) into <out>. Sets RP_APPLIED/RP_MISSING.
render_payload() {  # render_payload <src> <out> <name>
  local src="$1" out="$2" name="$3" line find repl
  RP_APPLIED=0; RP_MISSING=0
  cp "$src" "$out"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      *' --> '*) : ;;
      *) warn "  [$name] malformed override (need ' --> '): $line"; continue ;;
    esac
    find="${line%% --> *}"
    repl="${line#* --> }"
    if ! grep -qF -- "$find" "$out"; then
      warn "  [$name] FIND not present, override SKIPPED: $find"
      RP_MISSING=$((RP_MISSING + 1)); continue
    fi
    apply_override "$out" "$find" "$repl" > "$out.tmp" && mv "$out.tmp" "$out"
    RP_APPLIED=$((RP_APPLIED + 1))
  done < <(overrides_for "$name")
}

# ---- argument parsing ------------------------------------------------------
CONFIG="$DEFAULT_CONFIG"
DRY_RUN=0
NO_OUI=0
FORCE=0
DO_INIT=0
INIT_TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --init)
      DO_INIT=1
      if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then INIT_TARGET="$2"; shift; fi
      ;;
    --config)
      [ $# -ge 2 ] || die "--config needs a FILE argument"
      CONFIG="$2"; shift ;;
    --dry-run) DRY_RUN=1 ;;
    --no-oui)  NO_OUI=1 ;;
    --force)   FORCE=1 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# ---- --init: write a template and exit -------------------------------------
if [ "$DO_INIT" -eq 1 ]; then
  target="${INIT_TARGET:-$DEFAULT_CONFIG}"
  if [ -e "$target" ] && [ "$FORCE" -ne 1 ]; then
    die "$target already exists (use --force to overwrite)"
  fi
  template_config > "$target"
  info "[ok] wrote template config: $target"
  info "    edit it to choose payloads and overrides, then run: ./deploy-shark.sh"
  exit 0
fi

# ---- preflight -------------------------------------------------------------
[ -d "$PAYLOAD_LIBRARY" ] || die "payload library not found at $PAYLOAD_LIBRARY"
[ -f "$CONFIG" ] || die "config not found: $CONFIG (create one with: ./deploy-shark.sh --init)"

PAYLOADS=()
while IFS= read -r p; do [ -n "$p" ] && PAYLOADS+=("$p"); done < <(list_payloads)
[ ${#PAYLOADS[@]} -gt 0 ] || die "no payload sections in $CONFIG (add at least one [payload_name])"

# Options from config.
CFG_IP=$(get_option shark_ip || true)
CFG_OUI=$(get_option install_oui_db || true)
case "$(printf '%s' "${CFG_OUI:-yes}" | tr 'A-Z' 'a-z')" in
  no|false|0|off) NO_OUI=1 ;;
esac

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/shark-deploy.XXXXXX")
trap 'rm -rf "$WORKDIR"' EXIT

info "[*] Config : $CONFIG"
info "[*] Source : $PAYLOAD_LIBRARY"
info "[*] Payloads requested: ${#PAYLOADS[@]}"

# ---- DRY RUN: render and report, touch nothing -----------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  info "[*] DRY RUN - rendering only, no device contacted."
  resolved=0
  for name in "${PAYLOADS[@]}"; do
    src=$(resolve_payload "$name" || true)
    if [ -z "$src" ]; then warn "  - $name: NOT FOUND under payloads/library/"; continue; fi
    out="$WORKDIR/$name.payload.txt"
    render_payload "$src" "$out" "$name"
    info "  + $name (overrides applied: $RP_APPLIED, skipped: $RP_MISSING)"
    resolved=$((resolved + 1))
  done
  info "[*] Rendered $resolved payload(s) into: $WORKDIR"
  info "[*] OUI database would be: $([ "$NO_OUI" -eq 1 ] && echo skipped || echo installed)"
  info "[ok] Dry run complete. Re-run without --dry-run to provision a device."
  trap - EXIT          # keep rendered files around for inspection
  exit 0
fi

# ---- prompts ---------------------------------------------------------------
default_ip="${CFG_IP:-$DEFAULT_IP}"
read -r -p "Shark IP [$default_ip]: " SHARK_IP
SHARK_IP=${SHARK_IP:-$default_ip}
read -r -s -p "Shark root password: " SHARK_PASS; echo
[ -n "$SHARK_PASS" ] || die "no password entered"

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8)

# ---- auth wrapper: sshpass, else one shared SSH master (prompts once) -------
if command -v sshpass >/dev/null 2>&1; then
  RSH() { sshpass -p "$SHARK_PASS" ssh "${SSH_OPTS[@]}" "root@$SHARK_IP" "$@"; }
  RCP() { sshpass -p "$SHARK_PASS" scp "${SSH_OPTS[@]}" "$@"; }
else
  info "[i] sshpass not found - opening one SSH connection (enter the password once when asked)."
  CTRL="${TMPDIR:-/tmp}/shark-deploy-$$.ctl"
  ssh "${SSH_OPTS[@]}" -M -S "$CTRL" -o ControlPersist=600 -fN "root@$SHARK_IP"
  trap 'ssh -S "$CTRL" -O exit "root@$SHARK_IP" 2>/dev/null || true; rm -rf "$WORKDIR"' EXIT
  RSH() { ssh "${SSH_OPTS[@]}" -S "$CTRL" "root@$SHARK_IP" "$@"; }
  RCP() { scp "${SSH_OPTS[@]}" -o ControlPath="$CTRL" "$@"; }
fi

info "[*] Target: root@$SHARK_IP"
RSH 'echo "[ok] connected: $(cat /proc/sys/kernel/hostname 2>/dev/null || echo shark)"'

# ---- push payloads (rendered, only payload.txt) ----------------------------
info "[*] Pushing payloads to /root/library/my_payloads/ ..."
count=0
for name in "${PAYLOADS[@]}"; do
  src=$(resolve_payload "$name" || true)
  if [ -z "$src" ]; then warn "  - skip $name (not found under payloads/library/)"; continue; fi
  out="$WORKDIR/$name.payload.txt"
  render_payload "$src" "$out" "$name"
  RSH "mkdir -p /root/library/my_payloads/$name"
  RCP "$out" "root@$SHARK_IP:/root/library/my_payloads/$name/payload.txt"
  info "  + $name (overrides: $RP_APPLIED applied, $RP_MISSING skipped)"
  count=$((count + 1))
done
info "[*] Pushed $count payload(s)."

# ---- nmap OUI database -----------------------------------------------------
if [ "$NO_OUI" -eq 1 ]; then
  info "[*] Skipping nmap OUI database (per config/--no-oui)."
else
  info "[*] Installing nmap MAC/OUI database..."
  TMP_PREFIX="$WORKDIR/nmap-mac-prefixes"
  curl -fL "$PREFIX_URL" -o "$TMP_PREFIX"
  info "    downloaded $(wc -l < "$TMP_PREFIX" | tr -d ' ') OUI rows"
  RCP "$TMP_PREFIX" "root@$SHARK_IP:/root/nmap-mac-prefixes"
  RSH 'ln -sf /root/nmap-mac-prefixes /usr/share/nmap/nmap-mac-prefixes'
fi

# ---- verify ----------------------------------------------------------------
info "[*] Verifying..."
RSH '
  echo "  payloads:"; ls -1 /root/library/my_payloads 2>/dev/null | sed "s/^/    /"
  echo "  oui db:   $(ls -l /usr/share/nmap/nmap-mac-prefixes 2>/dev/null | sed "s/.* -> /-> /")"
  echo "  oui rows: $(wc -l < /root/nmap-mac-prefixes 2>/dev/null | tr -d " ")"
'
info "[ok] $SHARK_IP provisioned. Browse Payloads on the device to run them."
