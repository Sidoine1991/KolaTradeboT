#!/usr/bin/env python3
"""
Compteur de trades clôturés depuis le dernier réentraînement + historique
pour digests WhatsApp / métriques chart.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

log = logging.getLogger("tradbot_ai")

_ROOT = Path(__file__).resolve().parent
CLOSES_FILE = _ROOT / "closes_since_retrain.json"
RESULTS_FILE = _ROOT / "last_retrain_results.json"
HISTORY_FILE = _ROOT / "retrain_history.json"
HISTORY_MAX = 40

# Catégories trading suivies (alignées EA + continuous_learning)
TRACKED_CATEGORIES = (
    "BOOM_CRASH",
    "VOLATILITY",
    "FOREX",
    "METAL",
    "CRYPTO",
    "COMMODITIES",
)


def map_symbol_to_trading_category(symbol: str) -> str:
    """Catégorie trading pour compteur / retrain / digest."""
    s = (symbol or "").upper().replace(" ", "")
    if any(
        x in s
        for x in (
            "BOOM",
            "CRASH",
            "PAINX",
            "GAINX",
            "FLIPX",
            "SWITCHX",
            "PLUSX",
            "FIBOX",
            "QUADX",
            "TRENDX",
            "BREAKX",
        )
    ):
        return "BOOM_CRASH"
    if any(
        x in s
        for x in (
            "VOLATILITY",
            "RANGEBREAK",
            "JUMP",
            "STEP",
            "FXVOL",
            "SFVVOL",
            "SFXVOL",
        )
    ):
        return "VOLATILITY"
    if any(x in s for x in ("XAU", "GOLD", "XAG", "SILVER")):
        return "METAL"
    if any(
        x in s
        for x in (
            "BTC",
            "ETH",
            "ADA",
            "DOT",
            "SOL",
            "XRP",
            "LTC",
            "BNB",
            "DOGE",
            "CRYPTO",
        )
    ):
        return "CRYPTO"
    if any(x in s for x in ("OIL", "COPPER", "WTI", "BRENT", "NATGAS")):
        return "COMMODITIES"
    if any(
        x in s
        for x in (
            "USD",
            "EUR",
            "GBP",
            "JPY",
            "AUD",
            "CAD",
            "CHF",
            "NZD",
        )
    ):
        return "FOREX"
    return "COMMODITIES"


def _load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if data is not None else default
    except Exception as e:
        log.warning("[ML-TRACKER] lecture %s: %s", path.name, e)
        return default


def _save_json(path: Path, data: Any) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception as e:
        log.warning("[ML-TRACKER] écriture %s: %s", path.name, e)


def get_closes_since_retrain() -> Dict[str, int]:
    raw = _load_json(CLOSES_FILE, {})
    out: Dict[str, int] = {c: 0 for c in TRACKED_CATEGORIES}
    if isinstance(raw, dict):
        for k, v in raw.items():
            try:
                out[str(k)] = int(v)
            except Exception:
                continue
    return out


def increment_close(category: str) -> int:
    """Incrémente le compteur de clôtures pour la catégorie. Retourne le nouveau total."""
    counts = get_closes_since_retrain()
    cat = category if category in counts else category
    counts[cat] = int(counts.get(cat, 0)) + 1
    _save_json(CLOSES_FILE, counts)
    return counts[cat]


def reset_closes(category: str) -> None:
    counts = get_closes_since_retrain()
    counts[category] = 0
    _save_json(CLOSES_FILE, counts)


def get_last_retrain_results() -> Dict[str, Dict[str, Any]]:
    raw = _load_json(RESULTS_FILE, {})
    return raw if isinstance(raw, dict) else {}


def save_retrain_result(category: str, result: Dict[str, Any]) -> None:
    """Persiste le dernier résultat + historique pour digests."""
    results = get_last_retrain_results()
    entry = {
        "category": category,
        "status": result.get("status"),
        "old_accuracy": result.get("old_accuracy"),
        "new_accuracy": result.get("new_accuracy") or result.get("accuracy"),
        "improvement": result.get("improvement"),
        "samples_used": result.get("samples_used"),
        "adaptive_category": result.get("adaptive_category"),
        "auc": result.get("auc"),
        "f1_score": result.get("f1_score"),
        "reason": result.get("reason"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    results[category] = entry
    # Mirror adaptive key if present
    adapt = result.get("adaptive_category")
    if adapt and adapt != category:
        results[adapt] = entry
    _save_json(RESULTS_FILE, results)

    hist: List[Dict[str, Any]] = _load_json(HISTORY_FILE, [])
    if not isinstance(hist, list):
        hist = []
    hist.append(entry)
    hist = hist[-HISTORY_MAX:]
    _save_json(HISTORY_FILE, hist)


def get_retrain_history(limit: int = 20) -> List[Dict[str, Any]]:
    hist = _load_json(HISTORY_FILE, [])
    if not isinstance(hist, list):
        return []
    return hist[-limit:]


def closes_until_retrain(category: str, every_n: int) -> Tuple[int, int]:
    """Retourne (closes_since, remaining_until_n)."""
    n = max(1, int(every_n))
    since = int(get_closes_since_retrain().get(category, 0))
    remaining = max(0, n - since)
    return since, remaining


def format_retrain_whatsapp(category: str, result: Dict[str, Any], every_n: int) -> str:
    """Message PsychoBot après tentative de réentraînement."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    status = str(result.get("status") or "unknown")
    lines = [
        f"🧠 ML RETRAIN [{ts}]",
        f"📂 Catégorie: {category}",
    ]
    if status == "success":
        old_a = float(result.get("old_accuracy") or 0)
        new_a = float(result.get("new_accuracy") or result.get("accuracy") or 0)
        imp = float(result.get("improvement") or (new_a - old_a))
        samples = result.get("samples_used") or "?"
        lines.append("✅ Modèle mis à jour")
        lines.append(f"Précision: {old_a*100:.1f}% → {new_a*100:.1f}% ({imp*100:+.1f} pts)")
        lines.append(f"Échantillons: {samples}")
        if result.get("f1_score") is not None:
            lines.append(f"F1: {float(result['f1_score']):.3f}")
        if result.get("auc") is not None:
            lines.append(f"AUC: {float(result['auc']):.3f}")
        lines.append(f"Prochain retrain dans {every_n} trades clôturés")
    elif status == "no_improvement":
        old_a = float(result.get("old_accuracy") or 0)
        new_a = float(result.get("new_accuracy") or 0)
        imp = float(result.get("improvement") or 0)
        lines.append("⏸️ Pas d'amélioration suffisante (≥2% requis)")
        lines.append(f"Test: {old_a*100:.1f}% → {new_a*100:.1f}% ({imp*100:+.1f} pts)")
        lines.append("Ancien modèle conservé")
        lines.append(f"Compteur remis — prochain essai dans {every_n} trades")
    elif status == "skipped":
        lines.append(f"⏭️ Ignoré: {result.get('reason', 'unknown')}")
        if result.get("trades_count") is not None:
            lines.append(
                f"Trades dispo: {result.get('trades_count')} / min {result.get('min_required', '?')}"
            )
    else:
        lines.append(f"⚠️ Statut: {status}")
        if result.get("reason"):
            lines.append(f"Raison: {result.get('reason')}")
        if result.get("error"):
            lines.append(f"Erreur: {result.get('error')}")
    return "\n".join(lines)


def build_ml_digest_message(
    every_n: int,
    feedback_by_category: Optional[Dict[str, Dict[str, Any]]] = None,
    weaknesses: Optional[List[str]] = None,
    retrain_hints: Optional[List[str]] = None,
) -> str:
    """Digest évolution ML pour WhatsApp (texte, pas de graphiques)."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    counts = get_closes_since_retrain()
    results = get_last_retrain_results()
    hist = get_retrain_history(8)

    lines = [
        f"📊 ML DIGEST [{ts}]",
        f"Seuil retrain: tous les {every_n} trades clôturés / catégorie",
        "",
        "—— Compteurs depuis dernier retrain ——",
    ]
    for cat in TRACKED_CATEGORIES:
        since = int(counts.get(cat, 0))
        rem = max(0, every_n - since)
        bar = "🟢" if rem == 0 else ("🟡" if since >= every_n * 0.7 else "⚪")
        lines.append(f"{bar} {cat}: {since}/{every_n} (reste {rem})")

    lines.append("")
    lines.append("—— Derniers modèles ——")
    shown = 0
    for cat in TRACKED_CATEGORIES:
        r = results.get(cat)
        if not r:
            continue
        shown += 1
        st = r.get("status") or "?"
        new_a = r.get("new_accuracy")
        old_a = r.get("old_accuracy")
        when = (r.get("timestamp") or "")[:16].replace("T", " ")
        if new_a is not None and old_a is not None:
            lines.append(
                f"• {cat}: {st} | {float(old_a)*100:.1f}%→{float(new_a)*100:.1f}% | {when}"
            )
        elif new_a is not None:
            lines.append(f"• {cat}: {st} | acc={float(new_a)*100:.1f}% | {when}")
        else:
            lines.append(f"• {cat}: {st} | {when}")
    if shown == 0:
        lines.append("• Aucun retrain enregistré encore")

    if feedback_by_category:
        lines.append("")
        lines.append("—— Performance trades 30j ——")
        for cat, st in sorted(feedback_by_category.items(), key=lambda x: -int(x[1].get("count") or 0)):
            cnt = int(st.get("count") or 0)
            wins = int(st.get("wins") or 0)
            wr = (wins / cnt * 100.0) if cnt else 0.0
            pnl = float(st.get("total_profit") or 0.0)
            weak = "⚠️" if wr < 45 and cnt >= 10 else ("✅" if wr >= 55 else "·")
            lines.append(f"{weak} {cat}: {cnt} trades | WR {wr:.0f}% | P/L {pnl:+.1f}")

    lines.append("")
    lines.append("—— Faiblesses actuelles ——")
    if weaknesses:
        for w in weaknesses[:6]:
            lines.append(f"• {w}")
    else:
        # Heuristique locale si pas fourni
        weak_found = False
        if feedback_by_category:
            for cat, st in feedback_by_category.items():
                cnt = int(st.get("count") or 0)
                wins = int(st.get("wins") or 0)
                wr = (wins / cnt * 100.0) if cnt else 0.0
                if cnt >= 8 and wr < 45:
                    lines.append(f"• {cat}: winrate faible ({wr:.0f}% sur {cnt})")
                    weak_found = True
                r = results.get(cat) or {}
                if r.get("status") == "no_improvement":
                    lines.append(f"• {cat}: dernier retrain sans gain modèle")
                    weak_found = True
        if not weak_found:
            lines.append("• Pas de faiblesse nette détectée (données limitées)")

    lines.append("")
    lines.append("—— Axes de réentraînement ——")
    if retrain_hints:
        for h in retrain_hints[:5]:
            lines.append(f"👉 {h}")
    else:
        for cat in TRACKED_CATEGORIES:
            since = int(counts.get(cat, 0))
            if since >= every_n:
                lines.append(f"👉 {cat}: seuil atteint — retrain imminent")
            elif since >= max(1, every_n // 2):
                rem = every_n - since
                lines.append(f"👉 {cat}: encore {rem} clôtures avant retrain")
        if feedback_by_category:
            for cat, st in feedback_by_category.items():
                cnt = int(st.get("count") or 0)
                wins = int(st.get("wins") or 0)
                wr = (wins / cnt * 100.0) if cnt else 0.0
                if cnt >= 15 and wr < 42:
                    lines.append(f"👉 {cat}: prioriser features / labels (WR {wr:.0f}%)")

    if hist:
        lines.append("")
        lines.append("—— Historique récent ——")
        for h in reversed(hist[-5:]):
            when = (h.get("timestamp") or "")[:16].replace("T", " ")
            lines.append(f"· {when} {h.get('category')} → {h.get('status')}")

    lines.append("")
    lines.append("💡 Graphiques détaillés: dashboard /ml/metrics + journal MT5")
    return "\n".join(lines)


def enrich_metrics_payload(
    symbol: str,
    base: Dict[str, Any],
    every_n: int,
) -> Dict[str, Any]:
    """Ajoute category / last_retrain / closes / f1 pour l'EA et l'API."""
    cat = map_symbol_to_trading_category(symbol)
    since, remaining = closes_until_retrain(cat, every_n)
    results = get_last_retrain_results()
    last = results.get(cat) or {}

    out = dict(base)
    out["category"] = cat
    out["closes_since_retrain"] = since
    out["closes_until_retrain"] = remaining
    out["retrain_every_n"] = every_n
    out["last_retrain_at"] = last.get("timestamp") or ""
    out["last_retrain_status"] = last.get("status") or ""
    if last.get("new_accuracy") is not None:
        try:
            acc = float(last["new_accuracy"])
            # Chart attend souvent un % string
            if "accuracy" not in out or out.get("data_source") == "computed":
                out["model_accuracy"] = f"{acc * 100.0:.1f}" if acc <= 1.0 else f"{acc:.1f}"
        except Exception:
            pass
    if last.get("f1_score") is not None:
        out["f1_score"] = last.get("f1_score")
    elif out.get("f1_score") is None:
        # fallback: dériver d'accuracy plate si ratio
        try:
            a = float(str(out.get("accuracy", "0")).replace("%", ""))
            if a > 1.0:
                a = a / 100.0
            out["f1_score"] = round(a, 3)
        except Exception:
            out["f1_score"] = None
    if last.get("auc") is not None:
        out["auc"] = last.get("auc")
    if last.get("old_accuracy") is not None and last.get("new_accuracy") is not None:
        try:
            out["accuracy_delta"] = round(
                float(last["new_accuracy"]) - float(last["old_accuracy"]), 4
            )
        except Exception:
            pass
    return out
