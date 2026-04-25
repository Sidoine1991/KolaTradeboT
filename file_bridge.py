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

# IMPORTANT:
# Ne pas importer `ai_server` ici. `ai_server.py` a un bootstrap lourd (Supabase/MT5/etc)
# et sa surface d'API change selon les commits (process_analysis peut ne pas exister).
# Le bridge doit rester stable: il appelle le serveur via HTTP.
try:
    import requests  # type: ignore
except Exception:  # pragma: no cover
    requests = None  # type: ignore
    import urllib.request
    import urllib.error

# ─── Configuration ────────────────────────────────────────────────────────────

# Dossier MQL5/Files — adapter selon votre installation MT5
MT5_FILES_DIR = Path(os.path.expandvars(os.environ.get(
    "MT5_FILES",
    r"C:\Users\%USERNAME%\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
)))

SIGNAL_OUTPUT_DIR = Path("signals")
SIGNAL_OUTPUT_DIR.mkdir(exist_ok=True)

AI_SERVER_URL = os.environ.get("AI_SERVER_URL", "http://127.0.0.1:8000").rstrip("/")
AI_DECISION_ENDPOINT = os.environ.get("AI_DECISION_ENDPOINT", "/decision")

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

            # Traiter via le serveur IA (HTTP)
            result = await call_ai_server(data)

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


async def call_ai_server(payload: dict) -> dict:
    """
    Appelle le serveur IA local déjà démarré.
    Par défaut: POST http://127.0.0.1:8000/decision (endpoint unifié).
    """
    url = f"{AI_SERVER_URL}{AI_DECISION_ENDPOINT}"
    # Wrapper stable: le serveur peut aussi accepter directement le payload.
    body = {"payload": payload}

    def _do_request_sync() -> dict:
        if requests is not None:
            r = requests.post(url, json=body, timeout=15)
            try:
                return r.json()
            except Exception:
                return {"status": "ERROR", "message": f"Réponse non-JSON ({r.status_code}): {r.text[:300]}"}

        # Fallback urllib
        req = urllib.request.Request(
            url,
            data=json.dumps(body).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
                return json.loads(raw)
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", errors="replace") if hasattr(e, "read") else str(e)
            return {"status": "ERROR", "message": f"HTTPError {e.code}: {raw[:300]}"}
        except Exception as e:
            return {"status": "ERROR", "message": str(e)}

    return await asyncio.to_thread(_do_request_sync)


# ─── Point d'entrée ───────────────────────────────────────────────────────────

def main():
    watch_dir = MT5_FILES_DIR if MT5_FILES_DIR.exists() else Path(".")
    log.info(f"Surveillance du dossier : {watch_dir.absolute()}")
    if not MT5_FILES_DIR.exists():
        log.warning(f"⚠️ Le dossier MT5 spécifié n'existe pas. Surveillance du dossier local par défaut.")
    log.info("En attente de fichiers analysis_*.json depuis MT5...")

    observer = Observer()
    observer.schedule(AnalysisFileHandler(), str(watch_dir), recursive=False)
    observer.start()

    try:
        while True:
            # Heartbeat + diagnostic: afficher les derniers fichiers "analysis_*.json"
            try:
                recent = sorted(
                    watch_dir.glob("analysis_*.json"),
                    key=lambda p: p.stat().st_mtime,
                    reverse=True,
                )[:5]
                if recent:
                    names = ", ".join([f"{p.name}" for p in recent])
                    log.info(f"⏳ Heartbeat: derniers analysis_*.json: {names}")
                else:
                    log.info("⏳ Heartbeat: aucun analysis_*.json détecté dans le dossier surveillé")
            except Exception as e:
                log.warning(f"Heartbeat: impossible de lister analysis_*.json: {e}")
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        log.info("Bridge arrêté.")
    observer.join()


if __name__ == "__main__":
    main()
