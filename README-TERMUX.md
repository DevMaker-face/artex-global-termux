# ARTEX-Global on Termux (Android)

Complete guide to running ARTEX-Global entirely on Android via Termux.

## Prerequisites

- **Termux** (from F-Droid or GitHub, NOT Play Store)
- **Android 7.0+** (API 24+)
- **Minimum 4GB RAM** (8GB+ recommended for LLM operations)
- **Storage permission** granted to Termux (`termux-setup-storage`)

## Quick Start

```bash
# 1. Install Termux from F-Droid: https://f-droid.org/packages/com.termux/
# 2. Grant storage permission
termux-setup-storage

# 3. Run the setup script
cd ~/hack
chmod +x artex-termux-setup.sh
./artex-termux-setup.sh

# 4. Start ARTEX
~/run-artex.sh

# 5. Open browser to http://127.0.0.1:8787
#    First visit: go to /setup, enter setup token from logs
```

## What Gets Installed

| Component | Version | Purpose |
|-----------|---------|---------|
| Go | 1.26+ | Backend compilation |
| Node.js | 20 LTS | Frontend build |
| PostgreSQL | 16+ | Database |
| Rust/Cargo | Latest | Some Go dependencies |
| Tools | Various | nmap, ripgrep, curl, etc. |

## Directory Structure

```
~/artex-global/          # Source code + compiled binary
~/artex-data/            # Runtime data
├── config.json          # Configuration
├── postgres/            # PostgreSQL data directory
├── postgres.log         # PostgreSQL logs
├── skills/              # Skills directory (copied from source)
├── start-postgres.sh    # PostgreSQL management
├── stop-postgres.sh
├── setup-db.sh
└── start-artex.sh       # ARTEX daemon script
~/run-artex.sh           # Main start command
~/stop-artex.sh          # Stop everything
~/update-artex.sh        # Update to latest version
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ARTEX_BIND` | `127.0.0.1:8787` | Bind address for web UI |
| `ARTEX_PROXY` | `127.0.0.1:8788` | Traffic proxy port |
| `ARTEX_CONFIG` | `~/artex-data/config.json` | Config file path |
| `ARTEX_PG_DSN` | Auto from config | PostgreSQL connection string |
| `ARTEX_SKILL_DIR` | `~/artex-data/skills` | Skills directory |
| `ANTHROPIC_API_KEY` | - | For Claude models |
| `OPENAI_API_KEY` | - | For OpenAI models |

### Config File (`~/artex-data/config.json`)

```json
{
  "database": {
    "host": "127.0.0.1",
    "port": 5432,
    "user": "artex",
    "password": "artex",
    "dbname": "artex",
    "sslmode": "disable"
  },
  "skill_dir": "/data/data/com.termux/files/home/artex-data/skills",
  "language": "en"
}
```

## Running ARTEX

### Foreground (see logs)
```bash
~/run-artex.sh
```

### Background (persistent)
```bash
nohup ~/run-artex.sh > ~/artex.log 2>&1 &
echo $! > ~/artex.pid
```

### Custom bind address (LAN access)
```bash
# Bind to all interfaces
ARTEX_BIND=0.0.0.0:8787 ~/run-artex.sh

# Or with explicit args
~/run-artex.sh -addr 0.0.0.0:8787 -proxy 0.0.0.0:8788
```

### Stop ARTEX
```bash
~/stop-artex.sh
```

## First-Time Setup

1. Start ARTEX: `~/run-artex.sh`
2. Check logs for setup token:
   ```bash
   grep "Setup token" ~/artex.log
   # Or if running foreground, check terminal output
   ```
3. Open browser to `http://127.0.0.1:8787/setup`
4. Enter setup token and create admin password
5. Configure LLM settings in System → Settings → LLM Settings

## LLM Configuration

ARTEX supports multiple LLM providers:

### Anthropic (Claude) - Recommended
```bash
export ANTHROPIC_API_KEY=sk-ant-...
# Or set in UI: System → Settings → LLM Settings
```

### OpenAI / OpenAI-Compatible
```bash
export OPENAI_API_KEY=sk-...
export ARTEX_LLM_BASE_URL=https://api.openai.com/v1  # Or your proxy
# Set model in UI or via ARTEX_LLM_MODEL
```

### Local Models (Ollama, etc.)
```bash
export ARTEX_LLM_BASE_URL=http://127.0.0.1:11434/v1
export ARTEX_LLM_MODEL=llama3.1:70b
export OPENAI_API_KEY=dummy  # Required but unused
```

## Updating

```bash
~/update-artex.sh
```

This will:
1. Stop ARTEX and PostgreSQL
2. Pull latest changes from GitHub
3. Rebuild frontend (Next.js static export)
4. Recompile Go binary for android/arm64
5. Update skills directory
6. Restart ready for `~/run-artex.sh`

## Troubleshooting

### PostgreSQL won't start
```bash
# Check logs
cat ~/artex-data/postgres.log

# Common fix: remove stale lock
rm -f ~/artex-data/postgres/postmaster.pid
~/artex-data/start-postgres.sh
```

### Build fails - Go version
```bash
# Check Go version
go version
# Should be go1.26+
# If not, the setup script installs it automatically
```

### Build fails - Node.js version
```bash
# Check Node version
node --version
# Should be v20+
# Use nvm to install: nvm install 20 && nvm use 20
```

### Out of memory during build
```bash
# Increase swap (requires root)
su -c "swapon /dev/block/zram0"  # If zram configured
# Or add swap file
dd if=/dev/zero of=/data/swap bs=1M count=2048
mkswap /data/swap
su -c "swapon /data/swap"
```

### Port already in use
```bash
# Find and kill process on port 8787
pkill -f "artex.*-addr"
# Or use different port
~/run-artex.sh -addr 127.0.0.1:8789
```

### Binary not found
```bash
# Rebuild
cd ~/artex-global
export CGO_ENABLED=0 GOOS=android GOARCH=arm64
go build -tags embedui -trimpath -ldflags "-s -w" -o artex ./cmd/artex
```

## Performance Notes

- **Android/ARM64** binary runs natively (no emulation)
- **PostgreSQL** runs on device - may be slower than desktop
- **LLM API calls** go over network - latency depends on connection
- **Frontend** is embedded static files - fast loading
- **Tools** (nmap, ripgrep, etc.) are native Termux binaries

## Security Considerations

⚠️ **Important**: ARTEX is a penetration testing framework. Only use against:
- Systems you own
- Systems you have explicit written authorization for
- Isolated test environments (DVWA, Juice Shop, etc.)

Default bind address is `127.0.0.1` for security. Only expose to LAN after:
1. Initial setup complete (admin password set)
2. You understand the risks
3. You're on a trusted network

## Auto-Start on Boot (Optional)

```bash
# Enable Termux wake lock (prevents sleep)
termux-wake-lock

# Enable boot script
mv ~/.termux/boot/artex-boot.sh ~/.termux/boot/artex-boot.sh.enabled

# Disable
mv ~/.termux/boot/artex-boot.sh.enabled ~/.termux/boot/artex-boot.sh
termux-wake-unlock
```

## Logs

| Log | Location |
|-----|----------|
| ARTEX | `~/artex.log` (if using nohup) or terminal |
| PostgreSQL | `~/artex-data/postgres.log` |
| Boot script | `~/artex-boot.log` |

## Uninstall

```bash
~/stop-artex.sh
rm -rf ~/artex-global ~/artex-data ~/run-artex.sh ~/stop-artex.sh ~/update-artex.sh
rm -rf ~/.termux/boot/artex-boot.sh*
```

## License

ARTEX-Global is licensed under AGPL-3.0. This adaptation script is provided as-is.

---

**Based on**: https://github.com/jiwoochris/artex-global
**Upstream**: Autumn-27/ARTEX (AGPL-3.0)