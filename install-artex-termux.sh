#!/data/data/com.termux/files/usr/bin/bash
# ARTEX-Global One-Line Installer for Termux
# Usage: curl -fsSL https://raw.githubusercontent.com/.../install-artex-termux.sh | bash
# Or: bash install-artex-termux.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${BLUE}[*]${NC} %s\n" "$*"; }
ok() { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*" >&2; }
die() { printf "${RED}[x]${NC} %s\n" "$*" >&2; exit 1; }

# Check Termux
[ -d "/data/data/com.termux/files/usr" ] || die "Must run in Termux"

# Grant storage if needed
if [ ! -d "/sdcard" ] && [ ! -L "/sdcard" ]; then
    info "Requesting storage permission..."
    termux-setup-storage
    sleep 2
fi

# Install base packages
info "Installing base packages..."
pkg update -y && pkg upgrade -y
pkg install -y git go nodejs-lts npm postgresql python rust cargo clang make cmake pkg-config \
    libsqlite openssl libuuid zlib libiconv gettext libxml2 libxslt readline ncurses \
    termux-tools ripgrep curl wget vim jq unzip nmap netcat-openbsd inetutils whois \
    dnsutils iputils bind-tools openssh tsu upx

# Ensure Go 1.26+
GO_VER=$(go version 2>/dev/null | grep -oE 'go1\.[0-9]+' | sed 's/go1\.//' || echo 0)
if [ "$GO_VER" -lt 26 ]; then
    info "Installing Go 1.26+..."
    cd /tmp
    wget -q "https://go.dev/dl/go1.26.3.linux-arm64.tar.gz"
    rm -rf /data/data/com.termux/files/usr/lib/go
    tar -C /data/data/com.termux/files/usr/lib -xzf go1.26.3.linux-arm64.tar.gz
    ln -sf /data/data/com.termux/files/usr/lib/go/bin/go /data/data/com.termux/files/usr/bin/go
    ln -sf /data/data/com.termux/files/usr/lib/go/bin/gofmt /data/data/com.termux/files/usr/bin/gofmt
    ok "Go $(go version | awk '{print $3}')"
fi

# Ensure Node 20+
NODE_VER=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1 || echo 0)
if [ "$NODE_VER" -lt 20 ]; then
    info "Installing Node.js 20 via nvm..."
    pkg install -y nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 20
    nvm use 20
    nvm alias default 20
fi

# Clone repo
ARTEX_DIR="$HOME/artex-global"
info "Cloning ARTEX-Global..."
if [ -d "$ARTEX_DIR/.git" ]; then
    cd "$ARTEX_DIR" && git pull
else
    git clone https://github.com/jiwoochris/artex-global.git "$ARTEX_DIR"
    cd "$ARTEX_DIR"
fi

# Build frontend
info "Building frontend (Next.js)..."
cd "$ARTEX_DIR/web"
npm ci --include=dev
NEXT_EXPORT=1 npm run build:static
mkdir -p "$ARTEX_DIR/server/webui/dist"
rsync -a --delete "$ARTEX_DIR/web/out/" "$ARTEX_DIR/server/webui/dist/"

# Build binary
info "Building Go binary for android/arm64..."
cd "$ARTEX_DIR"
export CGO_ENABLED=0 GOOS=android GOARCH=arm64 GOSUMDB=sum.golang.org
BUILD_VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_VERSION="${BUILD_VERSION#v}"
go build -tags embedui -trimpath -ldflags "-s -w -buildid= -X main.version=${BUILD_VERSION}" -o "$ARTEX_DIR/artex" ./cmd/artex
command -v upx >/dev/null && upx --best --lzma "$ARTEX_DIR/artex" 2>/dev/null || true
ok "Binary: $ARTEX_DIR/artex"

# Setup data dir
DATA_DIR="$HOME/artex-data"
PGDATA="$DATA_DIR/postgres"
SKILLS_DIR="$DATA_DIR/skills"
mkdir -p "$PGDATA" "$SKILLS_DIR"

# Init PostgreSQL
info "Initializing PostgreSQL..."
[ -f "$PGDATA/PG_VERSION" ] || initdb -D "$PGDATA" --auth=trust -U artex

cat > "$PGDATA/postgresql.conf" <<'PGCONF'
listen_addresses = '127.0.0.1'
port = 5432
max_connections = 100
shared_buffers = 64MB
dynamic_shared_memory_type = posix
wal_level = minimal
fsync = off
synchronous_commit = off
full_page_writes = off
PGCONF

cat > "$PGDATA/pg_hba.conf" <<'PGHBA'
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
PGHBA

# Copy skills
cp -r "$ARTEX_DIR/skills/"* "$SKILLS_DIR/" 2>/dev/null || true

# Create config
cat > "$DATA_DIR/config.json" <<EOF
{
  "database": {
    "host": "127.0.0.1",
    "port": 5432,
    "user": "artex",
    "password": "artex",
    "dbname": "artex",
    "sslmode": "disable"
  },
  "skill_dir": "$SKILLS_DIR",
  "language": "en"
}
EOF

# Create management scripts
cat > "$DATA_DIR/start-postgres.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
PGDATA="$HOME/artex-data/postgres"
LOGFILE="$HOME/artex-data/postgres.log"
pg_ctl -D "$PGDATA" status >/dev/null 2>&1 && exit 0
pg_ctl -D "$PGDATA" -l "$LOGFILE" start
for i in {1..30}; do pg_isready -d "$PGDATA" -q && exit 0; sleep 1; done
exit 1
EOF
chmod +x "$DATA_DIR/start-postgres.sh"

cat > "$DATA_DIR/stop-postgres.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pg_ctl -D "$HOME/artex-data/postgres" -m fast stop
EOF
chmod +x "$DATA_DIR/stop-postgres.sh"

cat > "$DATA_DIR/setup-db.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
"$HOME/artex-data/start-postgres.sh"
psql -h 127.0.0.1 -p 5432 -U artex -d postgres -c "CREATE DATABASE artex;" 2>/dev/null || true
psql -h 127.0.0.1 -p 5432 -U artex -d postgres -c "CREATE USER artex WITH PASSWORD 'artex';" 2>/dev/null || true
psql -h 127.0.0.1 -p 5432 -U artex -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE artex TO artex;" 2>/dev/null || true
EOF
chmod +x "$DATA_DIR/setup-db.sh"

# Main run script
cat > "$HOME/run-artex.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ARTEX_BIN="$HOME/artex-global/artex"
CONFIG_FILE="$HOME/artex-data/config.json"
DATA_DIR="$HOME/artex-data"
SKILLS_DIR="$DATA_DIR/skills"

[ -x "$ARTEX_BIN" ] || { echo "Binary not found: $ARTEX_BIN"; exit 1; }
[ -f "$CONFIG_FILE" ] || { echo "Config not found: $CONFIG_FILE"; exit 1; }

"$DATA_DIR/start-postgres.sh"
"$DATA_DIR/setup-db.sh"

export ARTEX_CONFIG="$CONFIG_FILE"
export ARTEX_SKILL_DIR="$SKILLS_DIR"
export ARTEX_PG_DSN="postgres://artex:artex@127.0.0.1:5432/artex?sslmode=disable"

BIND_ADDR="${ARTEX_BIND:-127.0.0.1:8787}"
PROXY_ADDR="${ARTEX_PROXY:-127.0.0.1:8788}"

ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -addr|--addr) BIND_ADDR="$2"; shift 2 ;;
        -proxy|--proxy) PROXY_ADDR="$2"; shift 2 ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

HAS_ADDR=0; HAS_PROXY=0
for a in "${ARGS[@]}"; do case "$a" in -addr*) HAS_ADDR=1;; -proxy*) HAS_PROXY=1;; esac; done
[ $HAS_ADDR -eq 0 ] && ARGS+=("-addr" "$BIND_ADDR")
[ $HAS_PROXY -eq 0 ] && ARGS+=("-proxy" "$PROXY_ADDR")

echo "Starting ARTEX on $BIND_ADDR (proxy: $PROXY_ADDR)"
echo "Web UI: http://$BIND_ADDR"
echo "Press Ctrl+C to stop"

cd "$HOME/artex-global"
RESTART_CODE=75; MAX_DELAY=60; DELAY=1; child=0; stopping=0
forward() { stopping=1; [ "$child" -ne 0 ] && kill -TERM "$child" 2>/dev/null || true; }
trap forward INT TERM

while :; do
    "$ARTEX_BIN" "${ARGS[@]}" & child=$!
    wait "$child"; code=$?
    [ "$code" -gt 128 ] && { wait "$child"; code=$?; }
    child=0
    [ "$stopping" -eq 1 ] && { echo "Stopped"; exit 0; }
    case "$code" in
        0) echo "Exited normally"; exit 0 ;;
        "$RESTART_CODE") echo "Restarting (update)..."; DELAY=1 ;;
        *) echo "Exited code $code, restart in ${DELAY}s"; sleep "$DELAY"; DELAY=$((DELAY*2)); [ $DELAY -gt $MAX_DELAY ] && DELAY=$MAX_DELAY ;;
    esac
done
EOF
chmod +x "$HOME/run-artex.sh"

# Stop script
cat > "$HOME/stop-artex.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill -f "artex.*-addr" 2>/dev/null && echo "ARTEX stopped" || echo "ARTEX not running"
"$HOME/artex-data/stop-postgres.sh" 2>/dev/null && echo "PostgreSQL stopped" || echo "PostgreSQL not running"
EOF
chmod +x "$HOME/stop-artex.sh"

# Update script
cat > "$HOME/update-artex.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
"$HOME/stop-artex.sh" 2>/dev/null || true
cd "$HOME/artex-global"
git pull
cd web && npm ci --include=dev && NEXT_EXPORT=1 npm run build:static
rsync -a --delete "$HOME/artex-global/web/out/" "$HOME/artex-global/server/webui/dist/"
cd "$HOME/artex-global"
export CGO_ENABLED=0 GOOS=android GOARCH=arm64 GOSUMDB=sum.golang.org
BUILD_VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_VERSION="${BUILD_VERSION#v}"
go build -tags embedui -trimpath -ldflags "-s -w -buildid= -X main.version=${BUILD_VERSION}" -o "$HOME/artex-global/artex" ./cmd/artex
command -v upx >/dev/null && upx --best --lzma "$HOME/artex-global/artex" 2>/dev/null || true
cp -r "$HOME/artex-global/skills/"* "$HOME/artex-data/skills/" 2>/dev/null || true
echo "Updated to $BUILD_VERSION. Run ~/run-artex.sh"
EOF
chmod +x "$HOME/update-artex.sh"

ok "Installation complete!"
echo ""
echo "=============================="
echo "  ARTEX-Global ready on Termux"
echo "=============================="
echo ""
echo "Start:     ~/run-artex.sh"
echo "Stop:      ~/stop-artex.sh"
echo "Update:    ~/update-artex.sh"
echo ""
echo "Web UI:    http://127.0.0.1:8787"
echo "First run: visit /setup, enter token from logs"
echo ""
echo "LAN access: ARTEX_BIND=0.0.0.0 ~/run-artex.sh"
echo "Background: nohup ~/run-artex.sh > ~/artex.log 2>&1 &"
EOF
chmod +x /data/data/com.termux/files/home/hack/install-artex-termux.sh