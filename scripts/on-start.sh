#!/bin/bash
# nanobot on-start script
# Creates backup before each start for rollback capability

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANO_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$NANO_DIR/.backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Keep only last 10 backups
cd "$BACKUP_DIR"
ls -t nanobot_backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --

# Create backup of critical files
BACKUP_FILE="$BACKUP_DIR/nanobot_backup_${TIMESTAMP}.tar.gz"
echo "Creating backup: $BACKUP_FILE"

tar -czf "$BACKUP_FILE" \
    --exclude='.venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.git' \
    -C "$NANO_DIR" \
    nanobot/ \
    pyproject.toml \
    uv.lock \
    2>/dev/null || true

echo "Backup created successfully"

# Log startup
echo "[$(date -Iseconds)] nanobot started" >> "$NANO_DIR/.startup.log"

exit 0
