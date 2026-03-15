#!/bin/bash
# nanobot systemd installation script
# Installs and configures systemd services for nanobot

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NANO_DIR="$(dirname "$SCRIPT_DIR")"
SYSTEMD_DIR="/etc/systemd/system"
USER_NAME="${USER:-nn}"

echo "🐈 nanobot systemd installer"
echo "============================"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Check if systemd is available
if ! command -v systemctl &> /dev/null; then
    echo "ERROR: systemd not found. This script requires systemd."
    exit 1
fi

echo "Installing nanobot services..."
echo ""

# Copy service files
echo "  → Copying service files..."
cp "$SCRIPT_DIR/nanobot.service" "$SYSTEMD_DIR/nanobot.service"
cp "$SCRIPT_DIR/nanobot-watchdog.service" "$SYSTEMD_DIR/nanobot-watchdog.service"

# Set correct user in service files
echo "  → Configuring user..."
sed -i "s/User=nn/User=$USER_NAME/g" "$SYSTEMD_DIR/nanobot.service"
sed -i "s/Group=nn/Group=$USER_NAME/g" "$SYSTEMD_DIR/nanobot.service"
sed -i "s/User=nn/User=$USER_NAME/g" "$SYSTEMD_DIR/nanobot-watchdog.service"
sed -i "s/Group=nn/Group=$USER_NAME/g" "$SYSTEMD_DIR/nanobot-watchdog.service"

# Reload systemd
echo "  → Reloading systemd daemon..."
systemctl daemon-reload

# Enable services
echo "  → Enabling services..."
systemctl enable nanobot.service
systemctl enable nanobot-watchdog.service

# Create log directory
echo "  → Setting up logging..."
mkdir -p /var/log/nanobot
chown "$USER_NAME:$USER_NAME" /var/log/nanobot 2>/dev/null || true

echo ""
echo "✓ Installation complete!"
echo ""
echo "Available commands:"
echo "  sudo systemctl start nanobot        # Start gateway"
echo "  sudo systemctl stop nanobot         # Stop gateway"
echo "  sudo systemctl restart nanobot      # Restart gateway"
echo "  sudo systemctl status nanobot       # Check status"
echo "  sudo journalctl -u nanobot -f       # View logs"
echo ""
echo "  sudo systemctl start nanobot-watchdog   # Start watchdog"
echo "  sudo systemctl status nanobot-watchdog  # Check watchdog status"
echo ""
echo "Services will auto-start on boot."
echo ""

# Ask if user wants to start now
if [ "${1:-}" != "--no-start" ]; then
    read -p "Start nanobot now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl start nanobot
        systemctl start nanobot-watchdog
        echo ""
        echo "✓ nanobot started!"
        echo "  Status: systemctl status nanobot"
        echo "  Logs:   journalctl -u nanobot -f"
    fi
fi
