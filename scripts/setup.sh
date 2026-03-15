# nanobot Self-Setup Script
# Run this to configure reliability features

#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANO_DIR="$(dirname "$SCRIPT_DIR")"

echo "🐈 nanobot Self-Setup"
echo "===================="
echo ""

# 1. Generate initial checksums
echo "1/4 Generating code integrity checksums..."
if [ -f "$SCRIPT_DIR/integrity.sh" ]; then
    "$SCRIPT_DIR/integrity.sh" generate
else
    echo "  Skipping (integrity.sh not found)"
fi

# 2. Create initial backup
echo ""
echo "2/4 Creating initial backup..."
if [ -f "$SCRIPT_DIR/on-start.sh" ]; then
    "$SCRIPT_DIR/on-start.sh"
else
    echo "  Skipping (on-start.sh not found)"
fi

# 3. Check systemd availability
echo ""
echo "3/4 Checking systemd..."
if command -v systemctl &> /dev/null; then
    echo "  systemd found"
    echo "  Run: sudo $SCRIPT_DIR/install-systemd.sh"
else
    echo "  systemd not available (skipping service installation)"
fi

# 4. Verify git repository
echo ""
echo "4/4 Verifying git repository..."
if [ -d "$NANO_DIR/.git" ]; then
    echo "  Git repository found"
    cd "$NANO_DIR"
    echo "  Current branch: $(git branch --show-current)"
    echo "  Recent commits:"
    git log --oneline -3
else
    echo "  WARNING: No git repository found"
    echo "  Run: cd $NANO_DIR && git init"
fi

echo ""
echo "✓ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Install systemd services: sudo $SCRIPT_DIR/install-systemd.sh"
echo "  2. Start gateway: sudo systemctl start nanobot"
echo "  3. Start watchdog: sudo systemctl start nanobot-watchdog"
echo "  4. Monitor: sudo journalctl -u nanobot -f"
echo ""
