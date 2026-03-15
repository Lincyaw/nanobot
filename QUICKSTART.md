# nanobot Reliability Quick Reference

## 🚀 Quick Start

```bash
# Install systemd services
cd /home/nn/.nanobot/workspace/nano/scripts
sudo ./install-systemd.sh

# Or run full setup
./setup.sh
```

## 📋 Service Commands

```bash
# Gateway
sudo systemctl start|stop|restart|status nanobot

# Watchdog
sudo systemctl start|stop|restart|status nanobot-watchdog

# Logs
sudo journalctl -u nanobot -f
sudo journalctl -u nanobot-watchdog -f
```

## 🛡️ Recovery Commands

```bash
# List backups
./scripts/rollback.sh --list

# Restore latest
./scripts/rollback.sh --restore

# Verify integrity
./scripts/integrity.sh verify

# Generate checksums (after good state)
./scripts/integrity.sh generate
```

## 📊 Health Files

| File | Purpose |
|------|---------|
| `.health.log` | Health check logs |
| `.health_metrics.json` | Crash/recovery stats |
| `.backups/` | Automatic backups |
| `.integrity.log` | Integrity alerts |

## 🔧 Configuration Files

| File | Location |
|------|----------|
| Gateway service | `scripts/nanobot.service` |
| Watchdog service | `scripts/nanobot-watchdog.service` |
| Watchdog code | `scripts/watchdog.py` |

## 🎯 Key Features

- ✅ Auto-restart on crash (5 attempts max)
- ✅ Exponential backoff (5s → 300s)
- ✅ Auto-rollback after 5 failures
- ✅ Backup before each start
- ✅ Code integrity monitoring
- ✅ Health metrics tracking
- ✅ Graceful shutdown

## 🐛 Troubleshooting

```bash
# Check what's wrong
sudo systemctl status nanobot
sudo journalctl -u nanobot -n 50

# Test manually
cd /home/nn/.nanobot/workspace/nano
.venv/bin/uv run nanobot gateway

# Force rollback
./scripts/rollback.sh --restore
```
