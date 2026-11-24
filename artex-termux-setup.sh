#!/data/data/com.termux/files/usr/bin/bash
# ARTEX-Global Termux Setup Script
# Installs all dependencies and builds ARTEX for Android/ARM64

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${BLUE}[*]${NC} %s\n" "$*"; }
ok() { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*" >&2; }
die() { printf "${RED}[x]${NC} %s\n" "$*" >&2; exit 1; }

# Check Termux environment
[ -d "/data/data/com.termux/files/usr" ] || die "This script must run in Termux"

# Set up directories
ARTEX_DIR="${HOME}/artex-global"
BUILD_DIR="${ARTEX_DIR}"
DATA_DIR="${HOME}/artex-data"
PGDATA="${DATA_DIR}/postgres"
SKILLS_DIR="${DATA_DIR}/skills"

info "Setting up ARTEX-Global for Termux"
info "Project directory: ${ARTEX_DIR}"
info "Data directory: ${DATA_DIR}"

# 1. Install system packages
info "Installing Termux packages..."
pkg update -y
pkg upgrade -y

# Core packages
pkg install -y \
    git \
    go \
    nodejs-lts \
    npm \
    postgresql \
    python \
    rust \
    cargo \
    clang \
    make \
    cmake \
    pkg-config \
    libsqlite \
    openssl \
    libuuid \
    zlib \
    libiconv \
    gettext \
    libxml2 \
    libxslt \
    readline \
    ncurses \
    termux-tools \
    proot-distro \
    ripgrep \
    curl \
    wget \
    vim \
    jq \
    unzip \
    nmap \
    netcat-openbsd \
    inetutils \
    whois \
    dnsutils \
    iputils \
    bind-tools \
    openssh \
    tsu \
    upx

# Node.js 20+ is needed (check version)
NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    warn "Node.js version is ${NODE_VERSION}, need 20+. Installing via nvm..."
    pkg install -y nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 20
    nvm use 20
    nvm alias default 20
fi

# 2. Install Go 1.26+ if not available
GO_VERSION=$(go version | grep -oE 'go1\.[0-9]+' | sed 's/go1\.//')
if [ "$GO_VERSION" -lt 26 ]; then
    warn "Go version is 1.${GO_VERSION}, need 1.26+. Installing from source..."
    cd /tmp
    wget -q "https://go.dev/dl/go1.26.3.linux-arm64.tar.gz"
    rm -rf /data/data/com.termux/files/usr/lib/go
    tar -C /data/data/com.termux/files/usr/lib -xzf go1.26.3.linux-arm64.tar.gz
    ln -sf /data/data/com.termux/files/usr/lib/go/bin/go /data/data/com.termux/files/usr/bin/go
    ln -sf /data/data/com.termux/files/usr/lib/go/bin/gofmt /data/data/com.termux/files/usr/bin/gofmt
    ok "Go updated to $(go version)"
fi

# 3. Clone or update repository
info "Cloning ARTEX-Global repository..."
if [ -d "${ARTEX_DIR}/.git" ]; then
    info "Repository exists, pulling latest changes..."
    cd "${ARTEX_DIR}"
    git pull
else
    git clone https://github.com/jiwoochris/artex-global.git "${ARTEX_DIR}"
    cd "${ARTEX_DIR}"
fi

# 4. Build frontend (Next.js static export)
info "Building Next.js frontend..."
cd "${ARTEX_DIR}/web"

# Install npm dependencies (include devDependencies for build)
info "Installing npm dependencies (this may take a while)..."
npm ci --include=dev 2>&1 | tail -20

info "Building static frontend..."
NEXT_EXPORT=1 npm run build:static 2>&1 | tail -30

# Sync to embed directory
info "Syncing frontend to embed directory..."
mkdir -p "${ARTEX_DIR}/server/webui/dist"
rsync -a --delete "${ARTEX_DIR}/web/out/" "${ARTEX_DIR}/server/webui/dist/"

# 5. Build Go binary for android/arm64
info "Building Go binary for android/arm64..."
cd "${ARTEX_DIR}"

# Set up build environment
export CGO_ENABLED=0
export GOOS=android
export GOARCH=arm64
export GOSUMDB=sum.golang.org

# Build with embedui tag
BUILD_VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_VERSION="${BUILD_VERSION#v}"

info "Building version: ${BUILD_VERSION}"
go build \
    -tags embedui \
    -trimpath \
    -ldflags "-s -w -buildid= -X main.version=${BUILD_VERSION}" \
    -o "${ARTEX_DIR}/artex" \
    ./cmd/artex

# Compress with UPX if available
if command -v upx >/dev/null 2>&1; then
    info "Compressing binary with UPX..."
    upx --best --lzma "${ARTEX_DIR}/artex" || warn "UPX compression failed, keeping uncompressed binary"
fi

ok "Binary built: ${ARTEX_DIR}/artex"
file "${ARTEX_DIR}/artex"

# 6. Set up PostgreSQL
info "Setting up PostgreSQL..."
mkdir -p "${PGDATA}"

# Initialize database if not exists
if [ ! -f "${PGDATA}/PG_VERSION" ]; then
    info "Initializing PostgreSQL data directory..."
    initdb -D "${PGDATA}" --auth=trust -U artex
fi

# Configure PostgreSQL for local connections
cat > "${PGDATA}/postgresql.conf" <<'PGCONF'
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

cat > "${PGDATA}/pg_hba.conf" <<'PGHBA'
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
PGHBA

# 7. Create startup scripts
info "Creating startup scripts..."

# PostgreSQL start script
cat > "${DATA_DIR}/start-postgres.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
PGDATA="${HOME}/artex-data/postgres"
LOGFILE="${HOME}/artex-data/postgres.log"

if pg_ctl -D "${PGDATA}" status >/dev/null 2>&1; then
    echo "PostgreSQL is already running"
    exit 0
fi

echo "Starting PostgreSQL..."
pg_ctl -D "${PGDATA}" -l "${LOGFILE}" start

# Wait for PostgreSQL to be ready
for i in {1..30}; do
    if pg_isready -d "${PGDATA}" -q; then
        echo "PostgreSQL is ready"
        exit 0
    fi
    sleep 1
done

echo "PostgreSQL failed to start" >&2
exit 1
EOF
chmod +x "${DATA_DIR}/start-postgres.sh"

# PostgreSQL stop script
cat > "${DATA_DIR}/stop-postgres.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
PGDATA="${HOME}/artex-data/postgres"
echo "Stopping PostgreSQL..."
pg_ctl -D "${PGDATA}" -m fast stop
EOF
chmod +x "${DATA_DIR}/stop-postgres.sh"

# Create database and user
cat > "${DATA_DIR}/setup-db.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e
PGDATA="${HOME}/artex-data/postgres"

# Start PostgreSQL if not running
if ! pg_ctl -D "${PGDATA}" status >/dev/null 2>&1; then
    "${HOME}/artex-data/start-postgres.sh"
fi

# Create database and user
psql -h 127.0.0.1 -p 5432 -U artex -d postgres -c "CREATE DATABASE artex;" 2>/dev/null || true
psql -h 127.0.0.1 -p 5432 -U artex -d postgres -c "CREATE USER artex WITH PASSWORD 'artex';" 2>/dev/null || true
psql -h 127.0.0.1 -p 5432 -U artex -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE artex TO artex;" 2>/dev/null || true

echo "Database setup complete"
EOF
chmod +x "${DATA_DIR}/setup-db.sh"

# Copy skills directory
info "Setting up skills directory..."
mkdir -p "${SKILLS_DIR}"
cp -r "${ARTEX_DIR}/skills/"* "${SKILLS_DIR}/" 2>/dev/null || true

# 8. Create config.json for Termux
info "Creating Termux configuration..."
cat > "${DATA_DIR}/config.json" <<EOF
{
  "database": {
    "host": "127.0.0.1",
    "port": 5432,
    "user": "artex",
    "password": "artex",
    "dbname": "artex",
    "sslmode": "disable"
  },
  "skill_dir": "${SKILLS_DIR}",
  "language": "en"
}
EOF

# 9. Create ARTEX start script for Termux
cat > "${DATA_DIR}/start-artex.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# ARTEX Termux Start Script

set -euo pipefail

ARTEX_BIN="${HOME}/artex-global/artex"
CONFIG_FILE="${HOME}/artex-data/config.json"
DATA_DIR="${HOME}/artex-data"
SKILLS_DIR="${DATA_DIR}/skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { printf "${BLUE}[*]${NC} %s\n" "$*"; }
ok() { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*" >&2; }
die() { printf "${RED}[x]${NC} %s\n" "$*" >&2; exit 1; }

# Check binary exists
[ -x "${ARTEX_BIN}" ] || die "ARTEX binary not found at ${ARTEX_BIN}. Run build first."

# Check config exists
[ -f "${CONFIG_FILE}" ] || die "Config file not found at ${CONFIG_FILE}"

# Start PostgreSQL
info "Starting PostgreSQL..."
"${DATA_DIR}/start-postgres.sh"

# Setup database
info "Setting up database..."
"${DATA_DIR}/setup-db.sh"

# Export environment variables
export ARTEX_CONFIG="${CONFIG_FILE}"
export ARTEX_SKILL_DIR="${SKILLS_DIR}"
export ARTEX_PG_DSN="postgres://artex:artex@127.0.0.1:5432/artex?sslmode=disable"

# Default bind address (127.0.0.1 for security)
BIND_ADDR="${ARTEX_BIND:-127.0.0.1:8787}"
PROXY_ADDR="${ARTEX_PROXY:-127.0.0.1:8788}"

# Parse command line args
ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -addr|--addr)
            BIND_ADDR="$2"
            shift 2
            ;;
        -proxy|--proxy)
            PROXY_ADDR="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Add default args if not provided
HAS_ADDR=0
HAS_PROXY=0
for arg in "${ARGS[@]}"; do
    case "$arg" in
        -addr*) HAS_ADDR=1 ;;
        -proxy*) HAS_PROXY=1 ;;
    esac
done

[ $HAS_ADDR -eq 0 ] && ARGS+=("-addr" "${BIND_ADDR}")
[ $HAS_PROXY -eq 0 ] && ARGS+=("-proxy" "${PROXY_ADDR}")

info "Starting ARTEX on ${BIND_ADDR} (proxy: ${PROXY_ADDR})"
info "Web UI: http://${BIND_ADDR}"
info "Press Ctrl+C to stop"

# Run ARTEX (with auto-restart on exit code 75 for updates)
RESTART_CODE=75
MAX_DELAY=60
DELAY=1

child=0
stopping=0

forward() {
    stopping=1
    if [ "$child" -ne 0 ]; then
        kill -TERM "$child" 2>/dev/null || true
    fi
}
trap forward INT TERM

cd "${HOME}/artex-global"

while :; do
    "${ARTEX_BIN}" "${ARGS[@]}" &
    child=$!

    wait "$child"
    code=$?
    if [ "$code" -gt 128 ]; then
        wait "$child"
        code=$?
    fi
    child=0

    if [ "$stopping" -eq 1 ]; then
        info "ARTEX stopped"
        exit 0
    fi

    case "$code" in
        0)
            info "ARTEX exited normally"
            exit 0
            ;;
        "$RESTART_CODE")
            info "Restart requested (update/rollback), restarting..."
            DELAY=1
            ;;
        *)
            warn "ARTEX exited with code $code, restarting in ${DELAY}s..."
            sleep "$DELAY"
            DELAY=$((DELAY * 2))
            [ "$DELAY" -gt "$MAX_DELAY" ] && DELAY=$MAX_DELAY
            ;;
    esac
done
EOF
chmod +x "${DATA_DIR}/start-artex.sh"

# 10. Create a complete run script
cat > "${HOME}/run-artex.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Complete ARTEX runner for Termux

set -euo pipefail

DATA_DIR="${HOME}/artex-data"

info() { printf "\033[0;34m[*]\033[0m %s\n" "$*"; }
ok() { printf "\033[0;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
die() { printf "\033[0;31m[x]\033[0m %s\n" "$*" >&2; exit 1; }

# Check if already running
if pgrep -f "artex.*-addr" >/dev/null 2>&1; then
    warn "ARTEX appears to be already running"
    echo "Use 'pkill -f artex' to stop it first, or run with -f to force"
    exit 1
fi

info "Starting ARTEX-Global on Termux"
"${DATA_DIR}/start-artex.sh" "$@"
EOF
chmod +x "${HOME}/run-artex.sh"

# 11. Create stop script
cat > "${HOME}/stop-artex.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Stop ARTEX and PostgreSQL

set -euo pipefail

info() { printf "\033[0;34m[*]\033[0m %s\n" "$*"; }
ok() { printf "\033[0;32m[+]\033[0m %s\n" "$*"; }

info "Stopping ARTEX..."
pkill -f "artex.*-addr" 2>/dev/null && ok "ARTEX stopped" || info "ARTEX was not running"

info "Stopping PostgreSQL..."
"${HOME}/artex-data/stop-postgres.sh" 2>/dev/null && ok "PostgreSQL stopped" || info "PostgreSQL was not running"
EOF
chmod +x "${HOME}/stop-artex.sh"

# 12. Create update script
cat > "${HOME}/update-artex.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Update ARTEX-Global to latest version

set -euo pipefail

ARTEX_DIR="${HOME}/artex-global"
DATA_DIR="${HOME}/artex-data"

info() { printf "\033[0;34m[*]\033[0m %s\n" "$*"; }
ok() { printf "\033[0;32m[+]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$*" >&2; }
die() { printf "\033[0;31m[x]\033[0m %s\n" "$*" >&2; exit 1; }

info "Updating ARTEX-Global..."

# Stop if running
"${HOME}/stop-artex.sh" 2>/dev/null || true

# Pull latest changes
cd "${ARTEX_DIR}"
info "Pulling latest changes..."
git pull

# Rebuild frontend
info "Rebuilding frontend..."
cd "${ARTEX_DIR}/web"
npm ci --include=dev
NEXT_EXPORT=1 npm run build:static
rsync -a --delete "${ARTEX_DIR}/web/out/" "${ARTEX_DIR}/server/webui/dist/"

# Rebuild binary
info "Rebuilding Go binary..."
cd "${ARTEX_DIR}"
export CGO_ENABLED=0
export GOOS=android
export GOARCH=arm64
export GOSUMDB=sum.golang.org
BUILD_VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_VERSION="${BUILD_VERSION#v}"
go build \
    -tags embedui \
    -trimpath \
    -ldflags "-s -w -buildid= -X main.version=${BUILD_VERSION}" \
    -o "${ARTEX_DIR}/artex" \
    ./cmd/artex

if command -v upx >/dev/null 2>&1; then
    upx --best --lzma "${ARTEX_DIR}/artex" || warn "UPX compression failed"
fi

# Update skills
info "Updating skills..."
mkdir -p "${DATA_DIR}/skills"
cp -r "${ARTEX_DIR}/skills/"* "${DATA_DIR}/skills/" 2>/dev/null || true

ok "Update complete! Version: ${BUILD_VERSION}"
info "Run ~/run-artex.sh to start"
EOF
chmod +x "${HOME}/update-artex.sh"

# 13. Create Termux boot script (for auto-start on boot)
cat > "${HOME}/.termux/boot/artex-boot.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Auto-start ARTEX on Termux boot (optional)
# Enable with: termux-wake-lock && mv this file to ~/.termux/boot/

# Wait for system to settle
sleep 10

# Start ARTEX in background
nohup ~/run-artex.sh > ~/artex-boot.log 2>&1 &
echo $! > ~/artex.pid
EOF
mkdir -p "${HOME}/.termux/boot"
chmod +x "${HOME}/.termux/boot/artex-boot.sh"

ok "Setup complete!"
echo ""
echo "========================================="
echo "  ARTEX-Global Termux Setup Complete"
echo "========================================="
echo ""
echo "Directory structure:"
echo "  ${ARTEX_DIR}       - Source code & binary"
echo "  ${DATA_DIR}        - Data, config, PostgreSQL"
echo "  ${SKILLS_DIR}      - Skills directory"
echo ""
echo "Commands:"
echo "  ~/run-artex.sh          - Start ARTEX (foreground)"
echo "  ~/stop-artex.sh         - Stop ARTEX and PostgreSQL"
echo "  ~/update-artex.sh       - Update to latest version"
echo ""
echo "Access web UI at: http://127.0.0.1:8787"
echo "First run: visit /setup and enter setup token from logs"
echo ""
echo "To bind to all interfaces (for LAN access):"
echo "  ARTEX_BIND=0.0.0.0 ~/run-artex.sh"
echo ""
echo "To run in background:"
echo "  nohup ~/run-artex.sh > ~/artex.log 2>&1 &"
echo ""
echo "To enable auto-start on Termux boot:"
echo "  mv ~/.termux/boot/artex-boot.sh ~/.termux/boot/artex-boot.sh.enabled"
echo "  termux-wake-lock"
EOF
chmod +x /data/data/com.termux/files/home/hack/artex-termux-setup.sh