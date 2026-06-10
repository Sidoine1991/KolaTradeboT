#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Start GOM Synchronization
=========================
Lance le MCP GOM Bridge + Poller en arrière-plan.

Services lancés :
  1. mcp_gom_bridge.py → Capture TradingView (MCP) → cache local
  2. gom_poller_robust.py → Lit cache → envoie à /gom-verdict
"""

import subprocess
import sys
import time
import logging
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [Launcher] %(message)s",
)
log = logging.getLogger("launcher")

PYTHON = sys.executable
ROOT = Path(__file__).parent
LOG_DIR = ROOT / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)


def start_service(name: str, script: str, args: list = None) -> subprocess.Popen:
    """Lance un service en arrière-plan."""
    cmd = [PYTHON, str(ROOT / script)]
    if args:
        cmd.extend(args)

    log.info(f"🚀 Démarrage: {name}")
    log.info(f"   Commande: {' '.join(cmd)}")

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    log.info(f"   PID: {proc.pid}")
    return proc


def main():
    log.info("=" * 70)
    log.info("GOM SYNCHRONIZATION LAUNCHER")
    log.info("=" * 70)

    try:
        # 1. Vérifier que ai_server répond
        import requests

        try:
            resp = requests.get("http://127.0.0.1:8000/health", timeout=3)
            if resp.status_code != 200:
                log.error("❌ AI Server non prêt (unhealthy)")
                sys.exit(1)
            log.info("✅ AI Server healthy")
        except Exception as e:
            log.error(f"❌ AI Server indisponible: {e}")
            sys.exit(1)

        # 2. Lancer les services
        bridge = start_service(
            "MCP GOM Bridge",
            "python/mcp_gom_bridge.py",
            ["--interval", "5"],
        )
        time.sleep(2)

        poller = start_service(
            "GOM Poller",
            "gom_poller_robust.py",
            ["--interval", "10"],
        )

        log.info("=" * 70)
        log.info("✅ Services lancés")
        log.info(f"   Bridge PID: {bridge.pid}")
        log.info(f"   Poller PID: {poller.pid}")
        log.info("=" * 70)

        # 3. Surveiller les services
        while True:
            if bridge.poll() is not None:
                log.error(f"❌ Bridge crashed (code {bridge.returncode})")
                poller.terminate()
                sys.exit(1)

            if poller.poll() is not None:
                log.error(f"❌ Poller crashed (code {poller.returncode})")
                bridge.terminate()
                sys.exit(1)

            time.sleep(5)

    except KeyboardInterrupt:
        log.info("⏹️  Arrêt des services...")
        bridge.terminate()
        poller.terminate()
        bridge.wait(timeout=5)
        poller.wait(timeout=5)
        log.info("✅ Services arrêtés")


if __name__ == "__main__":
    main()
