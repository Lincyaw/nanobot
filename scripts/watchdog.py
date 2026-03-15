#!/usr/bin/env python3
"""
nanobot Watchdog - Intelligent health monitor and auto-recovery system.

Features:
- Monitors gateway health via HTTP and process checks
- Auto-recovers from crashes with exponential backoff
- Detects code corruption and triggers rollback
- Sends alerts on critical failures
- Maintains health metrics and logs
"""

import asyncio
import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

import httpx

# Configuration
NANO_DIR = Path(__file__).parent.parent
SCRIPTS_DIR = NANO_DIR / "scripts"
BACKUP_DIR = NANO_DIR / ".backups"
HEALTH_LOG = NANO_DIR / ".health.log"
METRICS_FILE = NANO_DIR / ".health_metrics.json"
GATEWAY_PORT = int(os.getenv("NANOBOT_PORT", "8080"))
GATEWAY_URL = f"http://localhost:{GATEWAY_PORT}"

# Health check settings
CHECK_INTERVAL = 10  # seconds
MAX_RESTART_ATTEMPTS = 5
RESTART_BACKOFF_BASE = 5  # seconds
RESTART_BACKOFF_MAX = 300  # 5 minutes

# Critical files that must exist
CRITICAL_FILES = [
    NANO_DIR / "nanobot" / "__init__.py",
    NANO_DIR / "nanobot" / "cli" / "commands.py",
    NANO_DIR / "pyproject.toml",
    Path("/home/nn/.nanobot/workspace/SOUL.md"),
]


class HealthMetrics:
    """Track health metrics over time."""

    def __init__(self, path: Path):
        self.path = path
        self.data = self._load()

    def _load(self) -> dict:
        if self.path.exists():
            try:
                return json.loads(self.path.read_text())
            except Exception:
                pass
        return {
            "starts": 0,
            "crashes": 0,
            "recoveries": 0,
            "last_crash": None,
            "uptime_total": 0,
            "last_check": None,
        }

    def save(self):
        self.path.write_text(json.dumps(self.data, indent=2))

    def record_start(self):
        self.data["starts"] += 1
        self.data["last_check"] = datetime.now().isoformat()
        self.save()

    def record_crash(self):
        self.data["crashes"] += 1
        self.data["last_crash"] = datetime.now().isoformat()
        self.save()

    def record_recovery(self):
        self.data["recoveries"] += 1
        self.save()


class Watchdog:
    """Main watchdog controller."""

    def __init__(self):
        self.running = True
        self.restart_attempts = 0
        self.last_restart = 0
        self.metrics = HealthMetrics(METRICS_FILE)
        self.gateway_process: Optional[subprocess.Popen] = None

        # Ensure directories exist
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)

    def log(self, message: str, level: str = "INFO"):
        """Log message to file and stdout."""
        timestamp = datetime.now().isoformat()
        log_line = f"[{timestamp}] [{level}] {message}\n"
        print(log_line.strip())
        with open(HEALTH_LOG, "a") as f:
            f.write(log_line)

    def check_critical_files(self) -> bool:
        """Verify all critical files exist."""
        for file_path in CRITICAL_FILES:
            if not file_path.exists():
                self.log(f"Critical file missing: {file_path}", "ERROR")
                return False
        return True

    def check_gateway_http(self) -> bool:
        """Check if gateway responds to HTTP health check."""
        try:
            with httpx.Client(timeout=5.0) as client:
                response = client.get(f"{GATEWAY_URL}/health")
                return response.status_code == 200
        except Exception:
            return False

    def check_gateway_process(self) -> bool:
        """Check if gateway process is running."""
        try:
            result = subprocess.run(
                ["pgrep", "-f", "nanobot gateway"],
                capture_output=True,
                text=True,
            )
            return result.returncode == 0 and bool(result.stdout.strip())
        except Exception:
            return False

    def is_gateway_healthy(self) -> bool:
        """Comprehensive health check."""
        # Process check is primary
        if self.check_gateway_process():
            return True
        # HTTP check is secondary (gateway might not expose /health)
        if self.check_gateway_http():
            return True
        return False

    def trigger_backup(self):
        """Create emergency backup before recovery actions."""
        try:
            backup_script = SCRIPTS_DIR / "on-start.sh"
            if backup_script.exists():
                subprocess.run(
                    [str(backup_script)],
                    cwd=str(NANO_DIR),
                    capture_output=True,
                    timeout=30,
                )
                self.log("Emergency backup created")
        except Exception as e:
            self.log(f"Backup failed: {e}", "ERROR")

    def trigger_rollback(self):
        """Attempt automatic rollback from latest backup."""
        try:
            rollback_script = SCRIPTS_DIR / "rollback.sh"
            if rollback_script.exists():
                result = subprocess.run(
                    [str(rollback_script), "--restore"],
                    cwd=str(NANO_DIR),
                    capture_output=True,
                    text=True,
                    timeout=60,
                )
                if result.returncode == 0:
                    self.log("Automatic rollback successful", "SUCCESS")
                    return True
                else:
                    self.log(f"Rollback failed: {result.stderr}", "ERROR")
        except Exception as e:
            self.log(f"Rollback error: {e}", "ERROR")
        return False

    def calculate_backoff(self) -> int:
        """Calculate exponential backoff delay."""
        delay = min(
            RESTART_BACKOFF_BASE * (2 ** self.restart_attempts),
            RESTART_BACKOFF_MAX,
        )
        return int(delay)

    def restart_gateway(self):
        """Attempt to restart the gateway service."""
        self.restart_attempts += 1

        if self.restart_attempts > MAX_RESTART_ATTEMPTS:
            self.log(
                f"Max restart attempts ({MAX_RESTART_ATTEMPTS}) reached. "
                "Triggering rollback...",
                "CRITICAL",
            )
            self.metrics.record_crash()
            if self.trigger_rollback():
                self.restart_attempts = 0
                self.metrics.record_recovery()
            return

        backoff = self.calculate_backoff()
        self.log(
            f"Restart attempt {self.restart_attempts}/{MAX_RESTART_ATTEMPTS} "
            f"(waiting {backoff}s)",
            "WARNING",
        )

        time.sleep(backoff)

        # Try systemd restart first
        try:
            subprocess.run(
                ["systemctl", "restart", "nanobot"],
                capture_output=True,
                timeout=10,
            )
            self.log("Gateway restarted via systemd")
        except Exception:
            # Fallback: direct process start
            self.log("systemd restart failed, attempting direct start", "WARNING")
            try:
                venv_python = NANO_DIR / ".venv" / "bin" / "python"
                if venv_python.exists():
                    self.gateway_process = subprocess.Popen(
                        [str(venv_python), "-m", "nanobot", "gateway"],
                        cwd=str(NANO_DIR),
                        start_new_session=True,
                    )
                    self.log("Gateway started directly")
                else:
                    self.log("Virtual environment not found", "ERROR")
            except Exception as e:
                self.log(f"Direct start failed: {e}", "ERROR")

        self.metrics.record_start()

    def run_health_loop(self):
        """Main health monitoring loop."""
        self.log("Watchdog starting...")
        self.metrics.record_start()

        while self.running:
            try:
                # Check critical files
                if not self.check_critical_files():
                    self.log("Critical files missing!", "CRITICAL")
                    self.trigger_backup()
                    self.restart_gateway()
                    continue

                # Check gateway health
                if not self.is_gateway_healthy():
                    self.log("Gateway unhealthy!", "WARNING")
                    self.metrics.record_crash()
                    self.trigger_backup()
                    self.restart_gateway()
                else:
                    # Reset restart counter on success
                    if self.restart_attempts > 0:
                        self.log("Gateway recovered, resetting attempt counter")
                        self.restart_attempts = 0
                        self.metrics.record_recovery()

                self.metrics.data["last_check"] = datetime.now().isoformat()
                self.metrics.save()

            except Exception as e:
                self.log(f"Health check error: {e}", "ERROR")

            time.sleep(CHECK_INTERVAL)

    def stop(self):
        """Graceful shutdown."""
        self.log("Watchdog stopping...")
        self.running = False
        self.metrics.save()

        if self.gateway_process:
            self.gateway_process.terminate()


def main():
    watchdog = Watchdog()

    def signal_handler(signum, frame):
        watchdog.stop()
        sys.exit(0)

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    try:
        watchdog.run_health_loop()
    except KeyboardInterrupt:
        watchdog.stop()
    except Exception as e:
        watchdog.log(f"Fatal error: {e}", "CRITICAL")
        raise


if __name__ == "__main__":
    main()
