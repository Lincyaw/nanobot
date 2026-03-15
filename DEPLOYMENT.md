# nanobot Deployment & Reliability Guide

## 🛡️ Reliability Features

nanobot includes comprehensive self-protection and recovery mechanisms:

### 1. **Systemd Services**
- Auto-start on boot
- Automatic restart on failure
- Graceful shutdown handling
- Resource isolation and security hardening

### 2. **Watchdog Monitor**
- Continuous health monitoring (every 10s)
- Automatic crash recovery with exponential backoff
- Critical file integrity verification
- Auto-rollback on repeated failures

### 3. **Backup System**
- Automatic backup before each start
- Emergency backup on detected issues
- Rolling backup retention (last 10)
- Manual rollback capability

### 4. **Code Integrity**
- Checksum verification of core files
- Change detection and alerting
- Automatic backup on unexpected changes

---

## 📦 Installation

### Quick Install (systemd)

```bash
cd /home/nn/.nanobot/workspace/nano/scripts
sudo ./install-systemd.sh
```

This will:
- Install systemd service files
- Configure auto-start on boot
- Set up logging
- Optionally start services immediately

### Manual Installation

```bash
# Copy service files
sudo cp scripts/nanobot.service /etc/systemd/system/
sudo cp scripts/nanobot-watchdog.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable services
sudo systemctl enable nanobot
sudo systemctl enable nanobot-watchdog

# Start services
sudo systemctl start nanobot
sudo systemctl start nanobot-watchdog
```

---

## 🔧 Usage

### Service Management

```bash
# Gateway service
sudo systemctl start nanobot
sudo systemctl stop nanobot
sudo systemctl restart nanobot
sudo systemctl status nanobot

# Watchdog service
sudo systemctl start nanobot-watchdog
sudo systemctl stop nanobot-watchdog
sudo systemctl status nanobot-watchdog

# View logs
sudo journalctl -u nanobot -f
sudo journalctl -u nanobot-watchdog -f
```

### Backup & Rollback

```bash
# List available backups
./scripts/rollback.sh --list

# Restore from latest backup
./scripts/rollback.sh --restore

# Restore from specific backup
./scripts/rollback.sh --restore nanobot_backup_20260310_120000.tar.gz

# Verify backup integrity
./scripts/rollback.sh --verify [FILE]
```

### Integrity Monitoring

```bash
# Generate checksums (do this after known-good state)
./scripts/integrity.sh generate

# Verify current state
./scripts/integrity.sh verify

# Continuous monitoring
./scripts/integrity.sh watch
```

---

## 📊 Health Metrics

Health metrics are stored in `.health_metrics.json`:

```json
{
  "starts": 42,
  "crashes": 3,
  "recoveries": 3,
  "last_crash": "2026-03-10T15:30:00",
  "uptime_total": 86400,
  "last_check": "2026-03-10T23:58:00"
}
```

View health log:
```bash
tail -f /home/nn/.nanobot/workspace/nano/.health.log
```

---

## 🚨 Recovery Scenarios

### Scenario 1: Gateway Crashes
1. Watchdog detects crash within 10s
2. Automatic restart with 5s backoff
3. If successful, counter resets
4. If fails 5 times, triggers rollback

### Scenario 2: Code Corruption
1. Integrity check detects missing/corrupted files
2. Emergency backup created
3. Gateway restart attempted
4. If still failing, automatic rollback

### Scenario 3: Bad Code Deployment
```bash
# Manual rollback
./scripts/rollback.sh --restore

# Or list and choose specific backup
./scripts/rollback.sh --list
./scripts/rollback.sh --restore nanobot_backup_YYYYMMDD_HHMMSS.tar.gz
```

---

## 🔐 Security Features

- **NoNewPrivileges**: Prevents privilege escalation
- **ProtectSystem**: Read-only system directories
- **ProtectHome**: Restricted home directory access
- **PrivateTmp**: Isolated temporary directory
- **ReadWritePaths**: Explicit write access only to workspace/config

---

## 📝 Configuration

Edit `scripts/nanobot.service` to customize:
- Port number
- Environment variables
- Restart behavior
- Security settings

After changes:
```bash
sudo systemctl daemon-reload
sudo systemctl restart nanobot
```

---

## 🐛 Troubleshooting

### Service won't start
```bash
# Check status
sudo systemctl status nanobot

# View detailed logs
sudo journalctl -u nanobot -n 100 --no-pager

# Test manually
cd /home/nn/.nanobot/workspace/nano
.venv/bin/uv run nanobot gateway
```

### Watchdog not monitoring
```bash
# Check watchdog status
sudo systemctl status nanobot-watchdog

# View watchdog logs
sudo journalctl -u nanobot-watchdog -f
```

### Rollback failed
```bash
# Check backup directory
ls -la /home/nn/.nanobot/workspace/nano/.backups/

# Verify backup
./scripts/rollback.sh --verify [FILE]

# Manual extraction
tar -xzf [FILE] -C /home/nn/.nanobot/workspace/nano/
```

---

## 📈 Best Practices

1. **Before major changes**: Run `./scripts/integrity.sh generate`
2. **After stable deployment**: Verify backups exist in `.backups/`
3. **Regular monitoring**: Check `.health_metrics.json` for crash patterns
4. **Log rotation**: Configure `logrotate` for `/var/log/nanobot/`
5. **Alert integration**: Extend watchdog to send notifications on critical events

---

## 🔄 Development Workflow

When developing nanobot:

```bash
# 1. Make changes
# Edit code in nanobot/

# 2. Test locally
uv run nanobot agent -m "test"

# 3. Generate new checksums (if changes are good)
./scripts/integrity.sh generate

# 4. Commit to git
git add -A && git commit -m "feat: ..."

# 5. Deploy
sudo systemctl restart nanobot
```

**Remember**: Commit early, commit often! 🐈
