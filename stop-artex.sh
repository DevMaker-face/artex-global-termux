#!/data/data/com.termux/files/usr/bin/bash
# ARTEX-Global Termux - Stop everything

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${BLUE}[*]${NC} %s\n" "$*"; }
ok() { printf "${GREEN}[+]${NC} %s\n" "$*"; }

info "Stopping ARTEX..."
pkill -f "artex.*-addr" 2>/dev/null && ok "ARTEX stopped" || info "ARTEX was not running"

info "Stopping PostgreSQL..."
pg_ctl -D "$HOME/artex-data/postgres" -m fast stop 2>/dev/null && ok "PostgreSQL stopped" || info "PostgreSQL was not running"

ok "All stopped"