#!/data/data/com.termux/files/usr/bin/bash
# ARTEX-Global Termux - One-command startup
# Starts PostgreSQL + ARTEX with proper environment and network access

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { printf "${BLUE}[*]${NC} %s\n" "$*"; }
ok() { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*" >&2; }
die() { printf "${RED}[x]${NC} %s\n" "$*" >&2; exit 1; }

# Paths
ARTEX_BIN="$HOME/hack/artex-global/artex"
CONFIG_FILE="$HOME/artex-data/config.json"
PGDATA="$HOME/artex-data/postgres"
SKILLS_DIR="$HOME/artex-data/skills"
PGLOG="$HOME/artex-data/postgres.log"

# Check binary exists
[ -x "$ARTEX_BIN" ] || die "Binary not found: $ARTEX_BIN"

# Ensure network tools are available for ARTEX workers
# Termux paths where network tools live
TERMUX_BIN="/data/data/com.termux/files/usr/bin"
TERMUX_SBIN="/data/data/com.termux/files/usr/sbin"

# Verify and install missing network tools
ensure_network_tools() {
    local tools=("ip" "route" "netstat" "ss" "arp" "ping" "dig" "nslookup" "nmap" "curl" "wget")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        info "Installing missing network tools: ${missing[*]}"
        # Termux package names may differ from standard Linux
        pkg install -y iproute2 net-tools dnsutils nmap curl wget aosp-utils 2>&1 | tail -5
    fi
    
    ok "Network tools available"
}

ensure_network_tools

# Start PostgreSQL if not running
if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
    info "Starting PostgreSQL..."
    pg_ctl -D "$PGDATA" -l "$PGLOG" start
    for i in {1..10}; do
        pg_isready -d "$PGDATA" -q && break
        sleep 1
    done
    ok "PostgreSQL ready"
else
    ok "PostgreSQL already running"
fi

# Detect gateway IP for ARTEX workers (if possible)
detect_gateway() {
    local gw=""
    # Try multiple methods - each in subshell to not trigger set -e
    if command -v ip >/dev/null 2>&1; then
        gw=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1) || true
    fi
    if [ -z "$gw" ] && command -v route >/dev/null 2>&1; then
        gw=$(route -n 2>/dev/null | awk '/^0\.0\.0\.0/ {print $2}' | head -1) || true
    fi
    if [ -z "$gw" ] && [ -r /proc/net/route ]; then
        gw=$(awk '$2 == "00000000" {printf "%d.%d.%d.%d\n", strtonum("0x"substr($3,7,2)), strtonum("0x"substr($3,5,2)), strtonum("0x"substr($3,3,2)), strtonum("0x"substr($3,1,2))}' /proc/net/route 2>/dev/null | head -1) || true
    fi
    if [ -n "$gw" ]; then
        info "Detected gateway: $gw"
        export ARTEX_GATEWAY="$gw"
    else
        warn "Could not detect gateway - ARTEX workers may have limited network discovery"
        warn "Run 'ip route show default' manually to find your router IP"
    fi
}

detect_gateway

# Export environment with full Termux PATH for network tools
export ARTEX_CONFIG="$CONFIG_FILE"
export ARTEX_SKILL_DIR="$SKILLS_DIR"
export ARTEX_PG_DSN="postgres://artex:artex@127.0.0.1:5432/artex?sslmode=disable"
export PATH="$TERMUX_BIN:$TERMUX_SBIN:$PATH"

# Default bind addresses
BIND_ADDR="${ARTEX_BIND:-127.0.0.1:8787}"
PROXY_ADDR="${ARTEX_PROXY:-127.0.0.1:8788}"

# Parse args
ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -addr|--addr) BIND_ADDR="$2"; shift 2 ;;
        -proxy|--proxy) PROXY_ADDR="$2"; shift 2 ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

# Add defaults if not provided
HAS_ADDR=0; HAS_PROXY=0
for a in "${ARGS[@]}"; do case "$a" in -addr*) HAS_ADDR=1;; -proxy*) HAS_PROXY=1;; esac; done
[ $HAS_ADDR -eq 0 ] && ARGS+=("-addr" "$BIND_ADDR")
[ $HAS_PROXY -eq 0 ] && ARGS+=("-proxy" "$PROXY_ADDR")

info "Starting ARTEX on $BIND_ADDR (proxy: $PROXY_ADDR)"
info "Web UI: http://$BIND_ADDR"
[ -n "${ARTEX_GATEWAY:-}" ] && info "Gateway hint for workers: $ARTEX_GATEWAY"
info "Press Ctrl+C to stop"

cd "$HOME/hack/artex-global"

# Debug: show environment
info "Environment: ARTEX_CONFIG=$ARTEX_CONFIG ARTEX_SKILL_DIR=$ARTEX_SKILL_DIR"

# Run with auto-restart on exit code 75 (for self-update)
RESTART_CODE=75
MAX_DELAY=60
DELAY=1
child=0
stopping=0

forward() {
    stopping=1
    [ "$child" -ne 0 ] && kill -TERM "$child" 2>/dev/null || true
}
trap forward INT TERM

while :; do
    info "Launching: $ARTEX_BIN ${ARGS[*]}"
    "$ARTEX_BIN" "${ARGS[@]}" &
    child=$!
    info "ARTEX PID: $child"
    wait "$child"
    code=$?
    [ "$code" -gt 128 ] && { wait "$child"; code=$?; }
    child=0

    [ "$stopping" -eq 1 ] && { info "Stopped"; exit 0; }

    case "$code" in
        0) info "Exited normally"; exit 0 ;;
        "$RESTART_CODE") info "Restarting (update applied)..."; DELAY=1 ;;
        *) warn "Exited code $code, restart in ${DELAY}s"; sleep "$DELAY"; DELAY=$((DELAY*2)); [ $DELAY -gt $MAX_DELAY ] && DELAY=$MAX_DELAY ;;
    esac
done