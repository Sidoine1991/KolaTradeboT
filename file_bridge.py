"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  file_bridge.py — Pont entre MT5 (fichiers JSON) et ai_server.py            ║
║  Surveille le dossier MQL5/Files et relaie les analyses vers l'IA           ║
╚══════════════════════════════════════════════════════════════════════════════╝

Usage : python file_bridge.py
Surveille les fichiers analysis_*.json produits par l'EA MQL5
et appelle directement le moteur AI pour produire les signaux.
"""

import asyncio
import json
import logging
import time
import os
import sys
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Importer le moteur AI
sys.path.insert(0, str(Path(__file__).parent))
from ai_server import process_analysis, log as ai_log

# ─── Configuration ────────────────────────────────────────────────────────────

# Dossier MQL5/Files — adapter selon votre installation MT5
MT5_FILES_DIR = Path(os.environ.get(
    "MT5_FILES",
    r"C:\Users\%USERNAME%\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
))

SIGNAL_OUTPUT_DIR = Path("signals")
SIGNAL_OUTPUT_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [BRIDGE] %(message)s"
)
log = logging.getLogger("FILE_BRIDGE")


# ─── Gestionnaire d'événements ────────────────────────────────────────────────

class AnalysisFileHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.is_directory:
            return
        path = Path(event.src_path)
        if path.name.startswith("analysis_") and path.suffix == ".json":
            asyncio.run(self.handle_analysis_file(path))

    def on_created(self, event):
        self.on_modified(event)

    async def handle_analysis_file(self, filepath: Path):
        # Petite pause pour s'assurer que l'écriture est complète
        await asyncio.sleep(0.1)

        try:
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read().strip()
            if not content:
                return

            data   = json.loads(content)
            symbol = data.get("symbol", "UNKNOWN")
            log.info(f"Analyse reçue : {symbol}")

            # Traiter via le moteur AI
            result = await process_analysis(data)

            # Écrire le signal pour que l'EA puisse le lire
            signal_path = filepath.parent / "AI_MT5_signals.json"
            with open(signal_path, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=2)

            # Logger le résultat
            status = result.get("status", "UNKNOWN")
            if status == "SIGNALS":
                count = result.get("count", 0)
                log.info(f"✅ {count} signal(s) générés pour {symbol}")
                for sig in result.get("signals", []):
                    log.info(f"   → {sig['mode']} {sig['action']} | R:R={sig['risk_reward']} | conf={sig['confluence_score']}")
            else:
                log.info(f"HOLD pour {symbol} — {result.get('reason', '')}")

            # Sauvegarder dans le dossier signals local
            ts    = int(time.time())
            fname = f"{symbol}_{ts}_{status}.json"
            with open(SIGNAL_OUTPUT_DIR / fname, "w", encoding="utf-8") as f:
                json.dump({"input": data, "output": result}, f,
                          ensure_ascii=False, indent=2)

        except json.JSONDecodeError as e:
            log.error(f"JSON invalide dans {filepath.name}: {e}")
        except Exception as e:
            log.exception(f"Erreur traitement {filepath.name}")


# ─── Point d'entrée ───────────────────────────────────────────────────────────

def main():
    watch_dir = MT5_FILES_DIR if MT5_FILES_DIR.exists() else Path(".")
    log.info(f"Surveillance du dossier : {watch_dir}")
    log.info("En attente de fichiers analysis_*.json depuis MT5...")

    observer = Observer()
    observer.schedule(AnalysisFileHandler(), str(watch_dir), recursive=False)
    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        log.info("Bridge arrêté.")
    observer.join()


if __name__ == "__main__":
    main()
