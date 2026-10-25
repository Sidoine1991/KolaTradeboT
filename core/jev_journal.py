"""
Jev Journal — evaluation forward des decisions Jev
===================================================

Objectif : mesurer si les decisions de l'agent Jev sont *bonnes*, avant de les
brancher sur l'EA. Un avis SMC sans mesure de hit-rate ne vaut rien.

Le journal est un JSONL append-only (crash-safe, pas de reecriture complete) :
une ligne par cycle, avec la decision, la confiance, et — une fois l'horizon
atteint — le resultat forward.

Resolution de symbole
---------------------
MT5 et les verdicts GOM n'utilisent pas les memes noms (``EURMXN.C`` chez GOM,
``EURMXN`` chez MT5). ``resolve_symbol`` essaie les variantes usuelles.

Deg gracieux
------------
Si MT5 est indisponible, l'entree reste ``pending`` : elle sera resolue a un
cycle ulterieur plutot que perdue. Rien ne leve.
"""

from __future__ import annotations

import json
import logging
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger("tradbot.jev_journal")

# Data dir aligne sur le reste du projet (cf. ai_server.py DATA_DIR)
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = _PROJECT_ROOT / "data"
DECISIONS_DIR = DATA_DIR / "decisions"
JOURNAL_PATH = DECISIONS_DIR / "jev_decisions.jsonl"

# Horizon de validation forward : apres combien de minutes on tranche.
DEFAULT_HORIZON_MIN = 15.0

# Suffixes de broker a essayer pour reconcilier GOM <-> MT5.
_SYMBOL_SUFFIXES = (".C", ".m", ".a", ".i", ".s", "micro", "mini")


# ──────────────────────────────────────────────────────────────
# Prix (MT5, degrade gracieusement)
# ──────────────────────────────────────────────────────────────


def _mt5():
    try:
        import MetaTrader5 as mt5  # noqa: PLC0415
        return mt5
    except Exception:
        return None


_MT5_READY: Optional[bool] = None


def _mt5_connected(mt5: Any) -> bool:
    """Initialise MT5 une seule fois. Sans ca, symbol_info_tick renvoie None."""
    global _MT5_READY
    if _MT5_READY is None:
        try:
            _MT5_READY = bool(mt5.initialize())
            if not _MT5_READY:
                logger.warning("jev_journal: MT5.initialize() echoue — prix indisponible")
        except Exception as exc:
            logger.warning("jev_journal: MT5 indisponible (%s)", exc)
            _MT5_READY = False
    return _MT5_READY


def resolve_symbol(symbol: str) -> Optional[str]:
    """Retourne le nom MT5 correspondant, ou None si introuvable."""
    mt5 = _mt5()
    if mt5 is None or not _mt5_connected(mt5):
        return None
    base = (symbol or "").strip()
    if not base:
        return None

    candidates = [base]
    for suf in _SYMBOL_SUFFIXES:
        if base.endswith(suf):
            candidates.append(base[: -len(suf)])
            break
    else:
        candidates.extend(f"{base}{suf}" for suf in (".m", ".C"))

    # Dedupe en preservant l'ordre
    seen, ordered = set(), []
    for c in candidates:
        if c and c not in seen:
            seen.add(c)
            ordered.append(c)

    for cand in ordered:
        try:
            if mt5.symbol_info(cand) is not None:
                return cand
        except Exception:
            continue
    return None


def get_price(symbol: str) -> Optional[float]:
    """Mid-price courant. None si MT5 indisponible (jamais d'exception)."""
    mt5 = _mt5()
    if mt5 is None or not _mt5_connected(mt5):
        return None
    resolved = resolve_symbol(symbol)
    if not resolved:
        return None
    try:
        tick = mt5.symbol_info_tick(resolved)
    except Exception:
        return None
    if not tick:
        return None
    bid, ask = float(tick.bid or 0.0), float(tick.ask or 0.0)
    if bid > 0 and ask > 0:
        return (bid + ask) / 2.0
    return bid or ask or None


# ──────────────────────────────────────────────────────────────
# Journal
# ──────────────────────────────────────────────────────────────


def _horizon_min() -> float:
    try:
        return float(os.getenv("JEV_FORWARD_HORIZON_MIN") or DEFAULT_HORIZON_MIN)
    except (TypeError, ValueError):
        return DEFAULT_HORIZON_MIN


def _read_all() -> List[Dict[str, Any]]:
    if not JOURNAL_PATH.exists():
        return []
    rows: List[Dict[str, Any]] = []
    try:
        with open(JOURNAL_PATH, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue  # ligne corrompue : on l'ignore plutot que crasher
    except OSError as exc:
        logger.warning("jev_journal: lecture impossible: %s", exc)
    return rows


def _append(entry: Dict[str, Any]) -> None:
    try:
        DECISIONS_DIR.mkdir(parents=True, exist_ok=True)
        with open(JOURNAL_PATH, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except OSError as exc:
        logger.warning("jev_journal: ecriture impossible: %s", exc)


def _rewrite(rows: List[Dict[str, Any]]) -> None:
    """Reecrit le journal (on resout peu d'entrees a la fois)."""
    tmp = JOURNAL_PATH.with_suffix(".jsonl.tmp")
    try:
        DECISIONS_DIR.mkdir(parents=True, exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as fh:
            for row in rows:
                fh.write(json.dumps(row, ensure_ascii=False) + "\n")
        tmp.replace(JOURNAL_PATH)
    except OSError as exc:
        logger.warning("jev_journal: reecriture impossible: %s", exc)


# ──────────────────────────────────────────────────────────────
# Validation forward
# ──────────────────────────────────────────────────────────────


def _resolve_pending(rows: List[Dict[str, Any]], now: float) -> int:
    """Tranche les entrees pendantes dont l'horizon est atteint.

    Retourne le nombre d'entrees resolues. Silencieux si MT5 est off.
    """
    horizon_s = _horizon_min() * 60.0
    resolved = 0
    dirty = False

    for row in rows:
        if row.get("status") != "pending":
            continue
        # HOLD : rien a valider, on clot immediatement.
        if row.get("direction") == "HOLD":
            row["status"] = "skipped"
            row["reason"] = "HOLD (aucune direction a valider)"
            dirty = True
            continue

        age = now - float(row.get("ts") or 0.0)
        if age < horizon_s:
            continue

        price_now = get_price(row.get("symbol", ""))
        if price_now is None:
            continue  # MT5 off : on retentera au prochain cycle
        entry_price = row.get("entry_price")
        if not entry_price:
            row["status"] = "skipped"
            row["reason"] = "prix d'entree inconnu a l'enregistrement"
            dirty = True
            continue

        ret = (price_now - entry_price) / entry_price * 100.0
        direction = row.get("direction")
        correct = (ret > 0) if direction == "BUY" else (ret < 0)

        row["status"] = "resolved"
        row["resolved_at"] = now
        row["price_after"] = round(price_now, 8)
        row["forward_return_pct"] = round(ret, 5)
        row["correct"] = bool(correct)
        row["resolved_symbol"] = resolve_symbol(row.get("symbol", "")) or None
        dirty = True
        resolved += 1

    if dirty:
        _rewrite(rows)
    return resolved


def record(
    *,
    symbol: str,
    direction: str,
    confidence: float,
    probabilities: Dict[str, float],
    setup_quality: Optional[float],
    setup_confidence: Optional[float],
    enter_now: Optional[float],
    actionable: bool,
    coherence: Optional[float] = None,
    smc_patterns: Optional[List[str]] = None,
    model: str = "jev-latest",
) -> Dict[str, Any]:
    """Enregistre une decision et opportunement resout les anciennes.

    Retourne l'entree ecrite (utile pour les tests et le debug).
    """
    now = time.time()
    rows = _read_all()
    _resolve_pending(rows, now)

    entry_price = get_price(symbol)
    entry: Dict[str, Any] = {
        "ts": now,
        "iso": datetime.now(timezone.utc).isoformat(),
        "symbol": symbol,
        "model": model,
        "direction": direction,
        "confidence": round(float(confidence), 4),
        "probabilities": probabilities,
        "setup_quality": setup_quality,
        "setup_confidence": setup_confidence,
        "enter_now": enter_now,
        "actionable": bool(actionable),
        "coherence": coherence,
        "smc_patterns": smc_patterns or [],
        "entry_price": round(entry_price, 8) if entry_price else None,
        "resolved_symbol": resolve_symbol(symbol) if entry_price else None,
        "status": "pending" if direction != "HOLD" else "skipped",
        "horizon_min": _horizon_min(),
    }
    if direction == "HOLD":
        entry["reason"] = "HOLD (aucune direction a valider)"

    rows.append(entry)
    _append(entry)
    return entry


# ──────────────────────────────────────────────────────────────
# Statistiques
# ──────────────────────────────────────────────────────────────


def stats(min_samples: int = 20) -> Dict[str, Any]:
    """Hit-rate Jev. C'est LA metrique qui decide du branchement sur l'EA."""
    rows = _read_all()
    horizon = _horizon_min()

    directional = [r for r in rows if r.get("direction") != "HOLD"]
    resolved = [r for r in directional if r.get("status") == "resolved"]
    pending = [r for r in directional if r.get("status") == "pending"]
    holds = [r for r in rows if r.get("direction") == "HOLD"]

    def _acc(subset: List[Dict[str, Any]]) -> Optional[float]:
        if not subset:
            return None
        return round(100.0 * sum(1 for r in subset if r.get("correct")) / len(subset), 2)

    def _avg(subset: List[Dict[str, Any]], key: str) -> Optional[float]:
        vals = [float(r[key]) for r in subset if r.get(key) is not None]
        return round(sum(vals) / len(vals), 4) if vals else None

    resolved_actionable = [r for r in resolved if r.get("actionable")]

    # Confiance moyenne ponderee par la justesse : detecte la sur-confiance.
    calibration = None
    if resolved:
        calibration = round(
            _avg(resolved, "confidence") * 100.0
            - 100.0 * (sum(1 for r in resolved if r.get("correct")) / len(resolved)),
            2,
        )

    return {
        "journal": str(JOURNAL_PATH),
        "horizon_min": horizon,
        "total_cycles": len(rows),
        "holds": len(holds),
        "hold_rate_pct": round(100.0 * len(holds) / len(rows), 2) if rows else None,
        "directional": len(directional),
        "resolved": len(resolved),
        "pending": len(pending),
        "actionable": sum(1 for r in rows if r.get("actionable")),
        "accuracy_all_pct": _acc(resolved),
        "accuracy_actionable_pct": _acc(resolved_actionable),
        "sample_sizes": {
            "resolved": len(resolved),
            "resolved_actionable": len(resolved_actionable),
            "min_samples": min_samples,
        },
        "avg_confidence": _avg(resolved, "confidence"),
        "avg_forward_return_pct": _avg(resolved, "forward_return_pct"),
        # > 0 = Jev sur-confiant (confiance > hit-rate)
        "overconfidence_pct": calibration,
        "verdict": _verdict(len(resolved_actionable), _acc(resolved_actionable), calibration, min_samples),
    }


def _verdict(n: int, acc: Optional[float], calibration: Optional[float],
             min_samples: int = 20) -> str:
    """Seuil de decision avant de brancher Jev sur l'EA."""
    if n < min_samples:
        return f"INSUFFISANT ({n}/{min_samples} decisions actionnable resolues) — continue a collecter"
    if acc is None:
        return "INDETERMINE"
    if acc >= 60.0 and (calibration is None or calibration <= 10.0):
        return "OK pour branchement EA (gate seulement)"
    if acc >= 50.0:
        return "MARGINAL — a surveiller, ne pas brancher en auto"
    return "REJETER — hit-rate insuffisant"


def recent(limit: int = 20) -> List[Dict[str, Any]]:
    """Dernieres entrees (les plus recentes en premier)."""
    rows = _read_all()
    return list(reversed(rows[-limit:]))


def pending() -> List[Dict[str, Any]]:
    """Decisions directionnelles encore dans la fenetre forward."""
    return [r for r in _read_all() if r.get("status") == "pending"]
