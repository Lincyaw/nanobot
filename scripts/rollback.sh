#!/bin/bash
# nanobot emergency rollback script
# Restores from the most recent backup or a specific backup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANO_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$NANO_DIR/.backups"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --list              List available backups"
    echo "  --restore [FILE]    Restore from latest or specific backup"
    echo "  --verify [FILE]     Verify backup integrity"
    echo "  --help              Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --list"
    echo "  $0 --restore"
    echo "  $0 --restore nanobot_backup_20260310_120000.tar.gz"
}

list_backups() {
    echo "Available backups:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -lht "$BACKUP_DIR"/nanobot_backup_*.tar.gz 2>/dev/null || echo "  No backups found"
    else
        echo "  Backup directory not found"
    fi
}

verify_backup() {
    local backup_file="$1"
    if [ -z "$backup_file" ]; then
        backup_file=$(ls -t "$BACKUP_DIR"/nanobot_backup_*.tar.gz 2>/dev/null | head -1)
    fi
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        echo "ERROR: Backup file not found"
        exit 1
    fi
    
    echo "Verifying: $backup_file"
    if tar -tzf "$backup_file" > /dev/null 2>&1; then
        echo "✓ Backup is valid"
        exit 0
    else
        echo "✗ Backup is corrupted"
        exit 1
    fi
}

restore_backup() {
    local backup_file="$1"
    if [ -z "$backup_file" ]; then
        backup_file=$(ls -t "$BACKUP_DIR"/nanobot_backup_*.tar.gz 2>/dev/null | head -1)
    fi
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        echo "ERROR: Backup file not found"
        exit 1
    fi
    
    echo "Restoring from: $backup_file"
    
    # Stop nanobot if running
    systemctl stop nanobot 2>/dev/null || true
    
    # Create pre-restore backup
    PRE_RESTORE_DIR="$BACKUP_DIR/pre_restore_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$PRE_RESTORE_DIR"
    tar -czf "$PRE_RESTORE_DIR/nanobot.tar.gz" \
        --exclude='.venv' \
        --exclude='.git' \
        -C "$NANO_DIR" \
        nanobot/ 2>/dev/null || true
    
    # Extract backup
    tar -xzf "$backup_file" -C "$NANO_DIR"
    
    echo "✓ Restore complete"
    echo "Pre-restore backup saved to: $PRE_RESTORE_DIR"
    
    # Restart nanobot
    systemctl start nanobot 2>/dev/null || echo "Note: nanobot service not started (systemd may not be configured)"
}

# Parse arguments
case "${1:-}" in
    --list)
        list_backups
        ;;
    --restore)
        restore_backup "$2"
        ;;
    --verify)
        verify_backup "$2"
        ;;
    --help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
