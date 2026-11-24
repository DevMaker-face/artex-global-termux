<div align="center">

# ARTEX-Global Termux Edition

**Run ARTEX-Global entirely on Android via Termux** — no root required

[![license: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![platform: Android](https://img.shields.io/badge/platform-Android%20%2B%20Termux-green.svg)](https://f-droid.org/packages/com.termux/)

</div>

---

> ⚠️ **Security & Misuse Warning — Read First**
>
> **This repository is published for authorized environments only, solely to develop defense and detection capabilities.**
>
> ARTEX is an autonomous offensive tool powerful enough to carry an attack from reconnaissance through intrusion to data exfiltration with minimal human involvement — so the harm from misuse is equally severe. This Termux edition is not published to assist attackers. Its purpose is to help defenders understand how these autonomous AI attacks work and build the capacity to detect and block them.
>
> - **Unauthorized use is a crime in itself.** Do not run any scan, probe, or exploitation against systems you do not own or for which you lack explicit written authorization.
> - **Do not target production services or third-party assets.** Only verify in learning, research, and locally isolated environments you own (deliberately vulnerable targets like OWASP Juice Shop or DVWA).
> - **Read from a defender's perspective.** This repository also bundles defense and detection material — detection signatures and hardening checklists — for autonomous AI attacks. → **[Defense & Detection Guide](artex-global/docs/defense-en.md)** (also in [Korean](artex-global/docs/defense-ko.md))
>
> If you do not agree with this warning or the [usage restrictions & disclaimer](#license-and-disclaimer) below, do not download or use this repository.

---

## What Is This?

This is a **Termux-native adaptation** of [ARTEX-Global](https://github.com/jiwoochris/artex-global) — an autonomous multi-agent LLM-driven penetration testing system (Go backend + Next.js frontend).

- ✅ **Runs natively on Android** via Termux (ARM64 binary, no emulation)
- ✅ **Single binary** with embedded Next.js frontend
- ✅ **PostgreSQL** runs locally on device
- ✅ **All tools native** (nmap, ripgrep, curl, etc. via Termux packages)
- ✅ **Skills system** included (api-recon, playwright-cli, termux-netdiscover, etc.)
- ✅ **Detection rules** (Sigma, Suricata, ATT&CK) bundled for defense research

> **Based on**: [jiwoochris/artex-global](https://github.com/jiwoochris/artex-global) (AGPL-3.0)  
> **Upstream**: [Autumn-27/ARTEX](https://github.com/Autumn-27/ARTEX) (AGPL-3.0)

---

## Quick Start

### Prerequisites

- **Termux** from [F-Droid](https://f-droid.org/packages/com.termux/) or GitHub (NOT Play Store)
- **Android 7.0+** (API 24+)
- **Minimum 4GB RAM** (8GB+ recommended for LLM operations)
- **Storage permission** granted: `termux-setup-storage`

### One-Command Install

```bash
# 1. Clone this repo
cd ~/hack
git clone https://github.com/DevMaker-face/artex-global-termux.git
cd artex-global-termux

# 2. Run setup (installs Go, Node.js, PostgreSQL, builds ARTEX)
chmod +x artex-termux-setup.sh
./artex-termux-setup.sh

# 3. Start ARTEX
~/run-artex.sh

# 4. Open browser to http://127.0.0.1:8787
#    First visit: go to /setup, enter setup token from logs
```

---

## Directory Structure

```
~/hack/artex-global-termux/   # This repo (source)
~/artex-global/               # Built binary + source (linked from setup)
~/artex-data/                 # Runtime data (created by setup)
├── config.json               # Configuration
├── postgres/                 # PostgreSQL data directory
├── postgres.log              # PostgreSQL logs
├── skills/                   # Skills directory
├── start-postgres.sh         # PostgreSQL management
├── stop-postgres.sh
├── setup-db.sh
└── start-artex.sh            # ARTEX daemon script
~/run-artex.sh                # Main start command
~/stop-artex.sh               # Stop everything
~/update-artex.sh             # Update to latest version
```

---

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

---

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

### Custom Bind Address (LAN Access)
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

---

## First-Time Setup

1. Start ARTEX: `~/run-artex.sh`
2. Check logs for setup token:
   ```bash
   grep "Setup token" ~/artex.log
   # Or if running foreground, check terminal output
   ```
3. Open browser to `http://127.0.0.1:8787/setup`
4. Enter setup token and create admin password
5. Configure LLM settings in **System → Settings → LLM Settings**

---

## LLM Configuration

ARTEX supports multiple LLM providers:

### Anthropic (Claude) — Recommended
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

---

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

---

## Troubleshooting

### PostgreSQL Won't Start
```bash
# Check logs
cat ~/artex-data/postgres.log

# Common fix: remove stale lock
rm -f ~/artex-data/postgres/postmaster.pid
~/artex-data/start-postgres.sh
```

### Build Fails - Go Version
```bash
go version
# Should be go1.26+
# If not, the setup script installs it automatically
```

### Build Fails - Node.js Version
```bash
node --version
# Should be v20+
# Use nvm: nvm install 20 && nvm use 20
```

### Out of Memory During Build
```bash
# Increase swap (requires root)
su -c "swapon /dev/block/zram0"  # If zram configured
# Or add swap file
dd if=/dev/zero of=/data/swap bs=1M count=2048
mkswap /data/swap
su -c "swapon /data/swap"
```

### Port Already in Use
```bash
# Find and kill process on port 8787
pkill -f "artex.*-addr"
# Or use different port
~/run-artex.sh -addr 127.0.0.1:8789
```

### Binary Not Found
```bash
# Rebuild
cd ~/artex-global
export CGO_ENABLED=0 GOOS=android GOARCH=arm64
go build -tags embedui -trimpath -ldflags "-s -w" -o artex ./cmd/artex
```

---

## Performance Notes

- **Android/ARM64** binary runs natively (no emulation)
- **PostgreSQL** runs on device — may be slower than desktop
- **LLM API calls** go over network — latency depends on connection
- **Frontend** is embedded static files — fast loading
- **Tools** (nmap, ripgrep, etc.) are native Termux binaries

---

## Security Considerations

⚠️ **Important**: ARTEX is a penetration testing framework. Only use against:

- Systems you own
- Systems you have explicit written authorization for
- Isolated test environments (DVWA, Juice Shop, etc.)

Default bind address is `127.0.0.1` for security. Only expose to LAN after:

1. Initial setup complete (admin password set)
2. You understand the risks
3. You're on a trusted network

---

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

---

## Logs

| Log | Location |
|-----|----------|
| ARTEX | `~/artex.log` (if using nohup) or terminal |
| PostgreSQL | `~/artex-data/postgres.log` |
| Boot script | `~/artex-boot.log` |

---

## Uninstall

```bash
~/stop-artex.sh
rm -rf ~/artex-global ~/artex-data ~/run-artex.sh ~/stop-artex.sh ~/update-artex.sh
rm -rf ~/.termux/boot/artex-boot.sh*
```

---

## Repository Structure

```
artex-global-termux/
├── artex-global/              # Full ARTEX-Global source (submodule-like)
│   ├── agent/                 # Multi-agent LLM system (planner, worker, etc.)
│   ├── server/                # Go HTTP server, API, auth, engine
│   ├── db/                    # PostgreSQL schema & queries
│   ├── traffic/               # MITM recording proxy
│   ├── intercept/             # Tool approval gate
│   ├── detections/            # Sigma, Suricata, ATT&CK rules
│   ├── skills/                # Skills (api-recon, playwright, etc.)
│   ├── web/                   # Next.js frontend (embedded)
│   └── ...                    # See artex-global/README.md
├── artex-termux-setup.sh      # Full environment setup
├── install-artex-termux.sh    # Quick installer
├── start-artex.sh             # Start script (used by run-artex.sh)
├── stop-artex.sh              # Stop script
├── config.example.json        # Example config
├── skills/                    # Termux-specific skills
│   └── termux-netdiscover/    # Network discovery for Termux
├── README-TERMUX.md           # Detailed Termux guide
├── ARTEX_SYSTEM_SPEC.md       # System specification
└── DEVEX_SYSTEM_SPEC.md       # Developer experience spec
```

---

## License and Disclaimer

### Open Source License

This project is distributed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**. Full terms are in the [LICENSE](artex-global/LICENSE) file.

Anyone may freely use, modify, and distribute this software, but **derivative works must also be released under AGPL-3.0**. In particular, if you modify this project and **provide it to users over a network (e.g., as an online service), you must make the complete corresponding source code available to those users**.

> ⚠️ **Important**: An open source license alone does not restrict how the software can be used. The "Usage Restrictions" and "Disclaimer" below are an additional covenant and serious notice that the original author requires of users — please observe them.

### Usage Restrictions

- Use this tool for **reading and studying the source code**, and for **verifying its technical principles in a locally isolated environment**.
- Unless the target is your own or you have **explicit written authorization**, do not scan, probe, exploit, or attack any website, online service, or connected system.
- Using it for illegal intrusion, data theft, denial of service (DoS), or any other destructive or criminal activity is strictly prohibited.
- You must comply with all network security, data protection, and computer crime laws of your country and region.

### Disclaimer

This project is provided **"AS IS"**, without warranty of any kind, express or implied. The original author and contributors are not liable for any direct or indirect damages, data loss, system damage, or legal disputes arising from the use of this tool (regardless of whether it was used appropriately or not). **Downloading, installing, or using this project constitutes having read, understood, and accepted all the above conditions.**

**All legal responsibility and consequences fall on the user.**

---

## Upstream & Credits

- **Original ARTEX**: [Autumn-27/ARTEX](https://github.com/Autumn-27/ARTEX) (currently inaccessible, checked 2026-10)
- **ARTEX-Global**: [jiwoochris/artex-global](https://github.com/jiwoochris/artex-global) — localized edition (EN/KO/ZH/JA/ES)
- **Agent SDK**: [Autumn-27/norma](https://github.com/Autumn-27/norma)
- **Termux Adaptation**: This repository

---

## For Full Documentation

See the **ARTEX-Global documentation** inside `artex-global/`:

- **Main README**: [`artex-global/README.md`](artex-global/README.md) (English)
- **Español**: [`artex-global/README.es.md`](artex-global/README.es.md)
- **한국어**: [`artex-global/README.ko.md`](artex-global/README.ko.md)
- **中文**: [`artex-global/README.zh.md`](artex-global/README.zh.md)
- **日本語**: [`artex-global/README.ja.md`](artex-global/README.ja.md)
- **Architecture**: [`artex-global/README.md#system-architecture`](artex-global/README.md#system-architecture)
- **Defense & Detection**: [`artex-global/docs/defense-en.md`](artex-global/docs/defense-en.md)
- **Detections**: [`artex-global/detections/`](artex-global/detections/)
- **Changelog**: [`artex-global/CHANGELOG.en.md`](artex-global/CHANGELOG.en.md)
- **Contributing**: [`artex-global/CONTRIBUTING.en.md`](artex-global/CONTRIBUTING.en.md)