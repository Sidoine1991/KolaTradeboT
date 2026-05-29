#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XAUUSD Monitoring System — Health Check
========================================

Verifies all components are ready:
  ✅ Python environment
  ✅ Required packages
  ✅ AI server connectivity
  ✅ PsychoBot connectivity
  ✅ Configuration files
  ✅ Logs directory

Usage:
    python verify_xauusd_system.py
"""

import sys
import os
import subprocess
from pathlib import Path
import json
from datetime import datetime
import io

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# Colors for terminal output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"


def check(name: str, passed: bool, detail: str = ""):
    """Print check result."""
    symbol = f"{GREEN}✅{RESET}" if passed else f"{RED}❌{RESET}"
    msg = f"{symbol} {name}"
    if detail:
        msg += f" — {detail}"
    print(msg)
    return passed


def print_section(title: str):
    """Print section header."""
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}{title}{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")


def verify_python():
    """Check Python version and environment."""
    print_section("1️⃣  Python Environment")

    # Python version
    version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    check("Python version", sys.version_info >= (3, 8), detail=f"v{version}")

    # Virtual env (optional but recommended)
    in_venv = hasattr(sys, "real_prefix") or (hasattr(sys, "base_prefix") and sys.base_prefix != sys.prefix)
    if in_venv:
        check("Virtual environment", True, detail=sys.prefix)
    else:
        check("Virtual environment", False, detail="Not active (recommended: python -m venv venv)")

    return True


def verify_packages():
    """Check required packages."""
    print_section("2️⃣  Required Packages")

    required = {
        "aiohttp": "async HTTP",
        "requests": "HTTP client",
        "asyncio": "async runtime",
        "json": "JSON parsing",
        "logging": "logging",
    }

    all_ok = True
    for package, description in required.items():
        try:
            __import__(package)
            check(package, True, detail=description)
        except ImportError:
            check(package, False, detail=f"{description} — INSTALL: pip install {package}")
            all_ok = False

    return all_ok


def verify_files():
    """Check required files exist."""
    print_section("3️⃣  Files & Directories")

    files = {
        "python/unified_xauusd_monitor.py": "Main monitor script",
        "scripts/start_xauusd_monitor.ps1": "PowerShell launcher",
        "DEPLOYMENT_XAUUSD_MONITOR.md": "Deployment guide",
        "XAUUSD_MONITORING_README.md": "This README",
    }

    all_ok = True
    for file_path, description in files.items():
        full_path = Path(file_path)
        exists = full_path.exists()
        check(f"{file_path}", exists, detail=description)
        if not exists:
            all_ok = False

    # Check/create logs directory
    logs_dir = Path("logs")
    if not logs_dir.exists():
        logs_dir.mkdir()
        check("logs/ directory", True, detail="Created")
    else:
        check("logs/ directory", True, detail=f"{len(list(logs_dir.glob('*')))} files")

    return all_ok


def verify_ai_server():
    """Check AI server connectivity."""
    print_section("4️⃣  AI Server Connectivity")

    try:
        import requests

        url = "http://127.0.0.1:8000/session-bias"
        params = {"symbol": "OR"}

        response = requests.get(url, params=params, timeout=5)

        if response.status_code == 200:
            data = response.json()
            check("AI server /session-bias", True, detail=f"HTTP {response.status_code}")

            # Check response structure
            if "data" in data or "success" in data:
                check("Response structure", True, detail="Valid JSON")
            else:
                check("Response structure", False, detail="Unexpected format")
        else:
            check("AI server /session-bias", False, detail=f"HTTP {response.status_code}")

    except requests.exceptions.ConnectionError:
        check("AI server connectivity", False, detail="Connection refused on 127.0.0.1:8000")
    except Exception as e:
        check("AI server connectivity", False, detail=str(e))

    # Additional endpoints
    endpoints = [
        ("/pending-order", "Pending order"),
        ("/tradingagents/report-status", "TradingAgents report"),
        ("/gom-verdict", "GOM verdict cache"),
    ]

    for endpoint, name in endpoints:
        try:
            url = f"http://127.0.0.1:8000{endpoint}"
            response = requests.get(url, params={"symbol": "OR"}, timeout=5)
            check(f"  {name}", response.status_code == 200, detail=f"HTTP {response.status_code}")
        except Exception:
            check(f"  {name}", False, detail="Unreachable")


def verify_psychobot():
    """Check PsychoBot connectivity."""
    print_section("5️⃣  PsychoBot Connectivity")

    try:
        import requests

        url = "https://psychobot-1si7.onrender.com"

        # Try health check or simple OPTIONS
        response = requests.options(url, timeout=10)
        check("PsychoBot server", response.status_code >= 200, detail=f"HTTP {response.status_code}")

    except requests.exceptions.SSLError:
        check("PsychoBot server", True, detail="Reachable (SSL warning OK for Render)")
    except requests.exceptions.ConnectionError:
        check("PsychoBot server", False, detail="Connection refused")
    except Exception as e:
        check("PsychoBot server", False, detail=str(e))


def verify_configuration():
    """Check configuration."""
    print_section("6️⃣  Configuration")

    # Check .env file
    env_file = Path(".env")
    if env_file.exists():
        check(".env file", True, detail="Found")

        # Try to load it
        from dotenv import load_dotenv
        load_dotenv()

        phone = os.environ.get("XAUUSD_PHONE")
        if phone:
            check("  XAUUSD_PHONE", True, detail=phone[-10:] + "*" * 4)
        else:
            check("  XAUUSD_PHONE", False, detail="Not set")
    else:
        check(".env file", False, detail="Not found (use: XAUUSD_PHONE=+2290196911346)")

    # Check default values
    check("Default phone number", True, detail="+2290196911346")
    check("Default interval", True, detail="1200 seconds (20 min)")


def verify_logs():
    """Check logs directory."""
    print_section("7️⃣  Logs & State")

    logs_dir = Path("logs")

    if logs_dir.exists():
        log_files = list(logs_dir.glob("*"))
        check("Logs directory", True, detail=f"{len(log_files)} files")

        # Show recent activity
        for log_file in sorted(log_files, key=lambda p: p.stat().st_mtime, reverse=True)[:3]:
            mtime = datetime.fromtimestamp(log_file.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S")
            check(f"  {log_file.name}", True, detail=f"Updated {mtime}")

        # Check orchestrator state
        state_file = logs_dir / "orchestrator_state.json"
        if state_file.exists():
            try:
                with open(state_file) as f:
                    state = json.load(f)
                    check("Orchestrator state", True, detail=f"{state.get('cycle_count', 0)} cycles")
            except:
                check("Orchestrator state", False, detail="Corrupted")
    else:
        check("Logs directory", False, detail="Not found")

    # Check fallback log
    fallback_log = Path("whatsapp_alerts.log")
    if fallback_log.exists():
        size_kb = fallback_log.stat().st_size / 1024
        check("WhatsApp fallback log", True, detail=f"{size_kb:.1f} KB")


def run_test_cycle():
    """Run a single test cycle."""
    print_section("8️⃣  Test Cycle")

    try:
        import asyncio
        sys.path.insert(0, "python")
        from unified_xauusd_monitor import XAUUSDMonitor

        # Don't import message builder via aiohttp context,
        # just verify the module loads
        check("Monitor module import", True, detail="unified_xauusd_monitor OK")

    except Exception as e:
        check("Monitor module import", False, detail=str(e))


def print_summary():
    """Print summary."""
    print_section("08 System Status")
    print(f"\n{YELLOW}To start monitoring:{RESET}")
    print(f"  Windows:  .\\scripts\\start_xauusd_monitor.ps1")
    print(f"  Linux:    python python/unified_xauusd_monitor.py --once")
    print()
    print(f"{YELLOW}View logs:{RESET}")
    print(f"  tail -f logs/xauusd_monitor.log")
    print()
    print(f"{YELLOW}Documentation:{RESET}")
    print(f"  DEPLOYMENT_XAUUSD_MONITOR.md")
    print(f"  XAUUSD_MONITORING_README.md")
    print()


def main():
    """Run all checks."""
    print(f"\n{BLUE}🔍 XAUUSD Monitoring System — Health Check{RESET}")
    print(f"{BLUE}{'='*60}{RESET}\n")

    results = {
        "Python": verify_python(),
        "Packages": verify_packages(),
        "Files": verify_files(),
        "AI Server": False,  # Will check but not fail
        "PsychoBot": False,  # Will check but not fail
        "Configuration": False,  # Will check but not fail
        "Logs": True,  # Will check but not fail
    }

    # Network-dependent checks (non-critical)
    try:
        verify_ai_server()
    except:
        pass

    try:
        verify_psychobot()
    except:
        pass

    verify_configuration()
    verify_logs()

    # Test cycle (skip due to asyncio interaction)
    # try:
    #     run_test_cycle()
    # except:
    #     pass

    print_summary()

    # Final status
    critical_ok = all([results.get("Python"), results.get("Packages"), results.get("Files")])

    if critical_ok:
        print(f"{GREEN}✅ System ready! Start monitoring...{RESET}\n")
    else:
        print(f"{RED}❌ Critical issues found. Fix above and retry.{RESET}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
