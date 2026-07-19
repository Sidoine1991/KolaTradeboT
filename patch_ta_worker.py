#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Patch pour ai_server.py - Remplacer _run_tradingagents_once par la version worker séparé."""

import re
from pathlib import Path

TARGET = Path("D:\\Dev\\TradBOT\\ai_server.py")

# Lecture du fichier
content = TARGET.read_text(encoding='utf-8')

# Définir la nouvelle fonction complète (version worker séparé)
NEW_FUNC = '''async def _run_tradingagents_once(symbol: str) -> Dict[str, Any]:
    """Exécute une analyse TradingAgents via le processus séparé (worker HTTP)."""
    symbol = (symbol or "").strip().upper()
    if not symbol:
        raise ValueError("symbol requis")

    started_at = time.time()

    # Lancer le worker si necessaire (lazy start)
    _start_tradingagents_worker()

    result = await _call_ta_worker(symbol)

    if result and result.get("status") in ("ok", "cached"):
        result.setdefault("symbol", symbol)
        if "latency_ms" not in result:
            result["latency_ms"] = (time.time() - started_at) * 1000.0
        return result

    # Fallback: retourner HOLD si worker indisponible
    latency_ms = (time.time() - started_at) * 1000.0
    logger.warning("[TA-Worker] Echec pour %s (%.0fms) - retour HOLD", symbol, latency_ms)
    return {
        "symbol": symbol,
        "status": "error",
        "recommendation": "HOLD",
        "confidence": 0.0,
        "reasoning": "TradingAgents worker indisponible ou timeout",
        "latency_ms": latency_ms,
    }
'''

# Pattern pour trouver la fonction complète
# Chercher "async def _run_tradingagents_once" et tout jusqu'au retour
pattern = r'async def _run_tradingagents_once\(symbol: str\) -> Dict\[str, Any\]:.*?(?=\nasync def _tradingagents_realtime_loop)'

match = re.search(pattern, content, re.DOTALL)
if match:
    old_func = match.group(0)
    content = content.replace(old_func, NEW_FUNC)
    
    # Ajouter les helper functions avant la fonction principale
    HELPERS = '''import subprocess as _subprocess
import aiohttp

# === TradingAgents Worker Séparé ===
_TA_WORKER_URL = os.getenv("TA_WORKER_URL", "http://127.0.0.1:15000")
_TA_WORKER_TIMEOUT = float(os.getenv("TA_WORKER_TIMEOUT", "120.0"))
_TA_WORKER_PROC = None


def _start_tradingagents_worker() -> None:
    """Démarre le worker TradingAgents comme processus fils séparé."""
    global _TA_WORKER_PROC
    if _TA_WORKER_PROC is not None:
        if _TA_WORKER_PROC.poll() is not None:
            _TA_WORKER_PROC = None
        else:
            return
    
    try:
        script = str(Path(__file__).resolve().parent / "tradingagents_worker.py")
        _TA_WORKER_PROC = _subprocess.Popen(
            [sys.executable, script],
            stdout=_subprocess.PIPE,
            stderr=_subprocess.PIPE,
            creationflags=_subprocess.CREATE_NO_WINDOW,
        )
        logger.info("[TA-Worker] Processus demarre (PID=%d) -> %s", _TA_WORKER_PROC.pid, _TA_WORKER_URL)
    except Exception as exc:
        logger.warning("[TA-Worker] Impossible de demarrer le worker: %s", exc)
        _TA_WORKER_PROC = None


def _stop_tradingagents_worker() -> None:
    """Arrête proprement le worker."""
    global _TA_WORKER_PROC
    if _TA_WORKER_PROC is not None:
        try:
            _TA_WORKER_PROC.terminate()
            _TA_WORKER_PROC.wait(timeout=5)
        except Exception:
            _TA_WORKER_PROC.kill()
        _TA_WORKER_PROC = None
        logger.info("[TA-Worker] Processus arrete")


async def _call_ta_worker(symbol: str):
    """Appelle le worker TradingAgents via HTTP sécurisé avec timeout."""
    try:
        import aiohttp
        payload = {"symbol": symbol}
        timeout_val = _TA_WORKER_TIMEOUT
        async with aiohttp.ClientSession() as session:
            async with session.post(f"{_TA_WORKER_URL}/run", json=payload, timeout=aiohttp.ClientTimeout(total=timeout_val)) as resp:
                if resp.status == 200:
                    return await resp.json()
                else:
                    logger.warning("[TA-Worker] HTTP %d pour %s", resp.status, symbol)
                    return None
    except Exception as exc:
        logger.debug("[TA-Worker] Erreur pour %s: %s", symbol, exc)
        return None


'''
    
    # Insérer le code avant la fonction principale
    content = content.replace(NEW_FUNC, HELPERS + NEW_FUNC)
    
    # Écriture du fichier
    TARGET.write_text(content, encoding='utf-8')
    print("✅ Patch appliqué avec succès !")
    print("📋 Résumé des changements:")
    print("   - _run_tradingagents_once() utilise maintenant un worker HTTP séparé")
    print("   - Le worker est démarré automatiquement via _start_tradingagents_worker()")
    print("   - Le code bloquant TradingAgents est isolé dans tradingagents_worker.py")
    print("   - Le serveur principal reste réactif même si TA prend 120s")
else:
    print("❌ Impossible de trouver la fonction _run_tradingagents_once")
