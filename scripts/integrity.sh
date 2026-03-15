#!/bin/bash
# nanobot code integrity monitor
# Watches for critical file changes and triggers alerts/backups

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANO_DIR="$(dirname "$SCRIPT_DIR")"
WATCH_DIR="$NANO_DIR/nanobot"
CHECKSUM_FILE="$NANO_DIR/.integrity_checksums"
ALERT_LOG="$NANO_DIR/.integrity.log"

log_alert() {
    echo "[$(date -Iseconds)] $1" >> "$ALERT_LOG"
    echo "$1"
}

generate_checksums() {
    echo "Generating integrity checksums..."
    find "$WATCH_DIR" -name "*.py" -type f -exec md5sum {} \; | sort > "$CHECKSUM_FILE"
    log_alert "CHECKSUMS_GENERATED: $(wc -l < "$CHECKSUM_FILE") files"
}

verify_checksums() {
    if [ ! -f "$CHECKSUM_FILE" ]; then
        log_alert "WARNING: No checksum file found, generating..."
        generate_checksums
        return 0
    fi
    
    local changes=0
    local current_checksums=$(mktemp)
    
    find "$WATCH_DIR" -name "*.py" -type f -exec md5sum {} \; | sort > "$current_checksums"
    
    if ! diff -q "$CHECKSUM_FILE" "$current_checksums" > /dev/null 2>&1; then
        log_alert "ALERT: Code integrity check failed - files modified!"
        diff "$CHECKSUM_FILE" "$current_checksums" >> "$ALERT_LOG"
        changes=1
        
        # Auto-backup on unexpected changes
        if [ -n "$AUTO_BACKUP_ON_CHANGE" ]; then
            log_alert "Triggering emergency backup..."
            "$SCRIPT_DIR/on-start.sh"
        fi
    else
        log_alert "OK: Code integrity verified"
    fi
    
    rm -f "$current_checksums"
    return $changes
}

case "${1:-verify}" in
    generate)
        generate_checksums
        ;;
    verify)
        verify_checksums
        ;;
    watch)
        log_alert "Starting integrity watch (Ctrl+C to stop)..."
        while true; do
            verify_checksums
            sleep 60
        done
        ;;
    *)
        echo "Usage: $0 {generate|verify|watch}"
        exit 1
        ;;
esac
