#!/bin/bash
# nanobot health check script
# Returns 0 if healthy, 1 if unhealthy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANO_DIR="$(dirname "$SCRIPT_DIR")"
VENV_PYTHON="$NANO_DIR/.venv/bin/python"
HEALTH_FILE="/tmp/nanobot.health"
MAX_AGE=120  # seconds

# Check if venv exists
if [ ! -f "$VENV_PYTHON" ]; then
    echo "ERROR: Virtual environment not found at $VENV_PYTHON"
    exit 1
fi

# Check if workspace exists
if [ ! -d "/home/nn/.nanobot/workspace" ]; then
    echo "ERROR: Workspace directory not found"
    exit 1
fi

# Check if SOUL.md exists (core identity file)
if [ ! -f "/home/nn/.nanobot/workspace/SOUL.md" ]; then
    echo "ERROR: SOUL.md not found - core identity missing"
    exit 1
fi

# Check if gateway port is responsive (if running)
if command -v curl &> /dev/null; then
    if curl -s --connect-timeout 2 http://localhost:8080/health > /dev/null 2>&1; then
        echo "Gateway is responding"
        date +%s > "$HEALTH_FILE"
        exit 0
    fi
fi

# Check if process is running
if pgrep -f "nanobot gateway" > /dev/null; then
    echo "Gateway process is running"
    date +%s > "$HEALTH_FILE"
    exit 0
fi

# If not running, that's okay for pre-start check
echo "Gateway not running (pre-start check)"
exit 0
