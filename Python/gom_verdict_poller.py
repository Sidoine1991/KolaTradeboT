# -*- coding: utf-8 -*-
"""
GOM Verdict Poller — sans webhook TradingView payant
=====================================================

Lit les valeurs du Pine Script GOM KOLA directement depuis
TradingView Desktop via CDP (MCP tradingview-kola), puis pousse
le verdict vers l'AI server /gom-verdict toutes les N secondes.

Architecture :
    TradingView Desktop (CDP)
        → data_get_study_values  (valeurs Pine visibles)
        → quote_get              (prix live)
        ↓
    /gom-verdict  (AI server local)
        ↓
    xauusd_whatsapp_monitor.py  (lit /gom-verdict à chaque check)

Usage :
    python Python/gom_verdict_poller.py            # toutes les 60s
    python Python/gom_verdict_poller.py --interval 30
    python Python/gom_verdict_poller.py --once      # une seule fois
"""

from __future__ import annotations

import argparse
import json
import logging
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, Optional

import requests

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────
AI_SERVER_URL = "http://127.0.0.1:8000"
SYMBOL        = "XAUUSD"
MCP_NODE_ROOT = Path(r"D:\Dev\Depot Github\tradingview-mcp_kola")
TV_CLI        = MCP_NODE_ROOT / "src" / "cli" / "index.js"
POLL_INTERVAL = 5    # secondes — sync quasi temps réel (surclassé par --interval)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-Poller] %(message)s",
    handlers=[
        logging.StreamHandler(open(sys.stdout.fileno(), mode="w", encoding="utf-8", closefd=False)),
        logging.FileHandler("gom_poller.log", encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────
# Appel MCP via Node.js (même pattern que tv_mcp_client.py)
# ─────────────────────────────────────────────────────────────

_MCP_SCRIPT = Path(__file__).parent / "gom_mcp_reader.mjs"

_MCP_JS = r"""
// gom_mcp_reader.mjs — lit study values + quote via CDP TradingView
// Appelé par gom_verdict_poller.py via subprocess

import { createMcpClient } from '@tradingview-kola/mcp';

async function main() {
  const client = await createMcpClient();
  try {
    const [studies, quote] = await Promise.all([
      client.callTool('data_get_study_values', {}),
      client.callTool('quote_get', {}),
    ]);
    console.log(JSON.stringify({ studies, quote, success: true }));
  } catch(e) {
    console.log(JSON.stringify({ success: false, error: String(e) }));
  } finally {
    await client.close();
  }
}
main();
"""


def _run_tv_cli(command: list[str]) -> Optional[Dict[str, Any]]:
    """
    Appelle la CLI tradingview-kola : node src/cli/index.js <commande>
    Exemple : node src/cli/index.js values
              node src/cli/index.js quote
    """
    try:
        proc = subprocess.run(
            ["node", str(TV_CLI)] + command,
            capture_output=True, text=True, timeout=30,
            cwd=str(MCP_NODE_ROOT),
        )
        stdout = proc.stdout.strip()
        if not stdout:
            log.warning(f"tv {' '.join(command)} — sortie vide. stderr: {proc.stderr[:200]}")
            return None
        return json.loads(stdout)
    except json.JSONDecodeError as e:
        log.warning(f"tv {' '.join(command)} — JSON invalide: {e}")
        return None
    except Exception as e:
        log.warning(f"tv {' '.join(command)} — erreur: {e}")
        return None


# ─────────────────────────────────────────────────────────────
# Parse des valeurs Pine Script
# ─────────────────────────────────────────────────────────────

def _parse_fr_float(s) -> Optional[float]:
    """Convertit tout format numerique (FR/EN, espaces, virgules) en float.
    Gere le tiret unicode U+2212 (−) retourné par TradingView data_window.
    """
    if s is None:
        return None
    try:
        import re as _re
        # Normaliser le tiret Unicode − (U+2212) en tiret ASCII - avant tout traitement
        text = str(s).replace('−', '-').replace('–', '-').replace('—', '-')
        cleaned = _re.sub(r'[^\d,.\-]', '', text)
        if '.' in cleaned and ',' in cleaned:
            cleaned = cleaned.replace(',', '')
        else:
            cleaned = cleaned.replace(',', '.')
        return float(cleaned) if cleaned else None
    except (ValueError, TypeError):
        return None
def _val_from_study(vals: Dict[str, Any], *keys: str) -> Optional[float]:
    """Cherche une clé plot Pine (data_window) avec alias."""
    for k in keys:
        if k in vals:
            v = _parse_fr_float(vals[k])
            if v is not None:
                return v
        for vk, vv in vals.items():
            if vk.lower() == k.lower():
                v = _parse_fr_float(vv)
                if v is not None:
                    return v
    return None


def _verdict_text_from_num(verdict_num: int) -> str:
    n = int(round(verdict_num))
    if n >= 3:
        return "PERFECT BUY"
    if n == 2:
        return "GOOD BUY"
    if n == 1:
        return "BUY"
    if n == 0:
        return "WAIT"
    if n == -1:
        return "SELL"
    if n == -2:
        return "GOOD SELL"
    if n <= -3:
        return "PERFECT SELL"
    return "WAIT"


def parse_gom_study(raw: Dict[str, Any], symbol: str = SYMBOL) -> Optional[Dict[str, Any]]:
    """
    Lit les plots data_window de GOM_KOLA_SIDO.pine (score_buy, verdict_num, …).
    Fallback : ancien calcul simplifié si plots absents.
    """
    studies_payload = raw.get("studies") or raw
    studies: list = []

    if isinstance(studies_payload, dict):
        studies = studies_payload.get("studies", [])
        if not studies and studies_payload.get("study_count"):
            studies = [studies_payload]
    elif isinstance(studies_payload, list):
        studies = studies_payload

    gom_study = None
    for s in studies:
        name = (s.get("name") or s.get("title") or "").lower()
        if "gom" in name or "kola" in name or "sido" in name:
            gom_study = s
            break

    if not gom_study:
        # Logger les noms d'études disponibles pour aider au diagnostic
        available = [s.get("name") or s.get("title") or "?" for s in studies]
        log.warning(
            "Indicateur GOM KOLA SIDO non trouvé parmi [%s] — "
            "chart TV XAUUSD avec GOM actif ? (TV a peut-être basculé sur un autre tab)",
            ", ".join(available) if available else "aucune étude visible"
        )
        return None

    vals = gom_study.get("values") or gom_study.get("plots") or {}

    score_buy = _val_from_study(vals, "score_buy", "Score Buy", "BUY score")
    score_sell = _val_from_study(vals, "score_sell", "Score Sell", "SELL score")
    verdict_num = _val_from_study(vals, "verdict_num", "verdict_num")
    spike_pct = _val_from_study(vals, "spike_pct", "Spike %", "spike_pct")
    rsi = _val_from_study(vals, "rsi", "RSI")
    st_dir = _val_from_study(vals, "st_dir", "st_dir")
    entry_quality = _val_from_study(vals, "entry_quality", "Quality", "entry_quality")
    coherence_pct = _val_from_study(vals, "coherence_pct", "Coherence", "coherence_pct")
    kola_buy = _val_from_study(vals, "kola_buy", "kola_buy")
    kola_sell = _val_from_study(vals, "kola_sell", "kola_sell")
    verdict_gap = _val_from_study(vals, "verdict_gap", "Force", "verdict_gap")

    vwap = _val_from_study(vals, "vwap", "VWAP")
    bb_up = _val_from_study(vals, "bb_up", "BB Sup")
    bb_mid = _val_from_study(vals, "bb_mid", "BB Mid")
    bb_dn = _val_from_study(vals, "bb_dn", "BB Inf")
    st_line = _val_from_study(vals, "st_line", "Supertrend")

    # TF Global — exportés depuis Pine via plot() data_window
    tf_global_dir_raw = _val_from_study(vals, "tf_global_dir")   # -1/0/1
    tf_global_strength = _val_from_study(vals, "tf_global_strength")  # max(tb,ts) 0-7
    tf_bull_count = _val_from_study(vals, "tf_bull_count")
    tf_bear_count = _val_from_study(vals, "tf_bear_count")
    # Convertir gd (-1/0/1) en label BULL/BEAR/NEUT
    if tf_global_dir_raw is not None:
        _gd = int(round(tf_global_dir_raw))
        tf_global_dir_label = "BULL" if _gd == 1 else "BEAR" if _gd == -1 else "NEUT"
    else:
        tf_global_dir_label = ""
    # Convertir 0-7 votes → 0-100%
    tf_global_strength_pct = int(round((tf_global_strength or 0) / 7.0 * 100))

    quote_payload = raw.get("quote") or {}
    price = None
    if isinstance(quote_payload, dict):
        price = _parse_fr_float(
            str(quote_payload.get("last") or quote_payload.get("close") or 0)
        )

    # ── Mode exact : plots Pine (identique au tableau TV) ──
    if score_buy is not None and score_sell is not None:
        vnum = int(verdict_num) if verdict_num is not None else 0
        verdict = _verdict_text_from_num(vnum)
        gap = verdict_gap if verdict_gap is not None else abs(score_buy - score_sell)
        kola_state = "---"
        if kola_buy and price and abs(price - kola_buy) <= abs(price) * 0.002:
            kola_state = "NEAR BUY"
        elif kola_sell and price and abs(price - kola_sell) <= abs(price) * 0.002:
            kola_state = "NEAR SELL"

        return {
            "symbol": symbol,
            "verdict": verdict,
            "verdict_num": vnum,
            "score_buy": round(score_buy, 1),
            "score_sell": round(score_sell, 1),
            "spike_pct": round(spike_pct or 0, 1),
            "rsi": int(rsi or 50),
            "st_dir": int(st_dir or 0),
            "entry_quality": round(entry_quality or 0, 1),
            "coherence_pct": round(coherence_pct or 0, 1),
            "kola_buy": kola_buy or 0,
            "kola_sell": kola_sell or 0,
            "kola_state": kola_state,
            "verdict_gap": round(gap, 2),
            "vwap": vwap,
            "bb_up": bb_up,
            "bb_mid": bb_mid,
            "bb_dn": bb_dn,
            "st_line": st_line,
            "price": price,
            # TF Global — fixe la confiance à 0% dans TradeManager/dashboard
            "tf_global_dir": tf_global_dir_label,
            "tf_global_strength": tf_global_strength_pct,
            "tf_bull_count": int(tf_bull_count or 0),
            "tf_bear_count": int(tf_bear_count or 0),
            "source": "tradingview",
        }

    # ── Fallback ancien calcul ──
    fib_0 = _val_from_study(vals, "fib_0", "Fib 0%")
    f236 = _val_from_study(vals, "fib_236", "Fib 23.6%")
    score_buy = 0.0
    score_sell = 0.0
    st = st_line
    if st and price:
        if price > st:
            score_buy += 1.5
        else:
            score_sell += 1.5
    if vwap and price:
        if price > vwap:
            score_buy += 1.0
        else:
            score_sell += 1.0
    if bb_mid and price:
        if price > bb_mid:
            score_buy += 0.5
        else:
            score_sell += 0.5
    gap = abs(score_buy - score_sell)
    verdict = "WAIT"
    if score_buy > score_sell and gap >= 1.2:
        verdict = "BUY"
    elif score_sell > score_buy and gap >= 1.2:
        verdict = "SELL"
    st_dir_i = 1 if (st and price and price > st) else -1 if st and price else 0

    return {
        "symbol": symbol,
        "verdict": verdict,
        "verdict_num": 1 if verdict == "BUY" else -1 if verdict == "SELL" else 0,
        "score_buy": round(score_buy, 1),
        "score_sell": round(score_sell, 1),
        "spike_pct": 0,
        "vwap": vwap,
        "bb_up": bb_up,
        "bb_mid": bb_mid,
        "bb_dn": bb_dn,
        "st_line": st,
        "st_dir": st_dir_i,
        "fib_0": fib_0,
        "fib_236": f236,
        "price": price,
        "source": "tradingview_fallback",
    }


# ─────────────────────────────────────────────────────────────
# Push vers AI server
# ─────────────────────────────────────────────────────────────

def push_gom_verdict(payload: Dict[str, Any]) -> bool:
    try:
        r = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=payload,
            timeout=10,   # 10s — POST rapide via BackgroundTasks (ne plus bloquer)
        )
        if r.ok and r.json().get("ok"):
            log.info(
                f"✅ /gom-verdict OK → {payload['symbol']} "
                f"verdict={payload['verdict']} "
                f"buy={payload['score_buy']} sell={payload['score_sell']} "
                f"prix={payload.get('price')}"
            )
            return True
        log.error(f"❌ /gom-verdict HTTP {r.status_code}: {r.text[:200]}")
        return False
    except Exception as e:
        log.error(f"❌ Push /gom-verdict: {e}")
        return False


# ─────────────────────────────────────────────────────────────
# Lecture TV : essaie REST MCP d'abord, puis subprocess
# ─────────────────────────────────────────────────────────────

def _read_tv_via_http() -> Optional[Dict[str, Any]]:
    """
    Lit study values + quote via le serveur MCP HTTP local (port 3000).
    Plus fiable que subprocess — pas de problème d'encodage stdout.
    Fallback sur subprocess CLI si le serveur HTTP n'est pas disponible.
    """
    MCP_HTTP_PORTS = [3000, 3001, 3002]
    for port in MCP_HTTP_PORTS:
        try:
            import urllib.request as _ur
            # data_get_study_values
            req = _ur.Request(f"http://127.0.0.1:{port}/data_get_study_values",
                              method="POST",
                              headers={"Content-Type": "application/json"},
                              data=b"{}")
            with _ur.urlopen(req, timeout=15) as r:
                studies_raw = json.loads(r.read().decode("utf-8"))
            # quote_get
            req2 = _ur.Request(f"http://127.0.0.1:{port}/quote_get",
                               method="POST",
                               headers={"Content-Type": "application/json"},
                               data=b'{"symbol":"OANDA:XAUUSD"}')
            with _ur.urlopen(req2, timeout=15) as r2:
                quote_raw = json.loads(r2.read().decode("utf-8"))
            log.info(f"✅ MCP HTTP port {port} OK")
            return {"studies": studies_raw, "quote": quote_raw, "success": True}
        except Exception:
            continue
    return None


def _refocus_tv_chart() -> None:
    """
    Force TradingView à revenir sur le chart XAUUSD si possible.
    Appelle 'node src/cli/index.js chart set-symbol OANDA:XAUUSD' via CLI.
    Silencieux en cas d'échec — c'est un best-effort.
    """
    try:
        proc = subprocess.run(
            ["node", str(TV_CLI), "chart", "set-symbol", "OANDA:XAUUSD"],
            capture_output=True, text=True, timeout=10,
            cwd=str(MCP_NODE_ROOT),
        )
        if proc.returncode == 0:
            log.info("🔄 Re-focus TV sur OANDA:XAUUSD OK")
        # Si échec, on continue quand même
    except Exception:
        pass


def read_and_push(symbol: str = SYMBOL) -> bool:
    """
    Lit study values + quote (CLI subprocess), pousse le verdict GOM vers /gom-verdict.
    Si GOM non trouvé (TV sur mauvais tab), tente un re-focus et réessaie une fois.
    """
    for attempt in range(2):
        studies_raw = _run_tv_cli(["values"])
        if not studies_raw:
            log.warning("⚠️ 'tv values' a échoué — TradingView ouvert avec GOM KOLA SIDO visible ?")
            return False

        quote_raw = _run_tv_cli(["quote"])
        combined = {
            "studies": studies_raw,
            "quote": quote_raw or {},
            "success": True,
        }

        payload = parse_gom_study(combined, symbol=symbol)
        if payload:
            return push_gom_verdict(payload)

        # GOM non trouvé — tenter re-focus TV sur XAUUSD avant 2ème essai
        if attempt == 0:
            log.info("⟳ GOM absent — re-focus TV sur XAUUSD puis retry...")
            _refocus_tv_chart()
            import time as _t; _t.sleep(2)

    return False


# ─────────────────────────────────────────────────────────────
# Point d'entrée
# ─────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Poller GOM KOLA → /gom-verdict sans webhook payant"
    )
    parser.add_argument(
        "--interval", type=int, default=POLL_INTERVAL,
        help=f"Intervalle entre lectures en secondes (défaut={POLL_INTERVAL})"
    )
    parser.add_argument(
        "--once", action="store_true",
        help="Lire une seule fois et quitter"
    )
    parser.add_argument(
        "--symbol", type=str, default=SYMBOL,
        help="Symbole MT5/TV pour le store serveur (ex. XAUUSD, XAUEUR)"
    )
    args = parser.parse_args()
    sym = args.symbol.upper().strip()
    if sym == "XAUEUR":
        sym = "XAUUSD"

    if args.once:
        success = read_and_push(sym)
        sys.exit(0 if success else 1)

    log.info(f"🚀 GOM Poller démarré — {sym} — intervalle {args.interval}s")
    log.info(f"   Flux: TradingView CDP → /gom-verdict → TradeManager MT5")
    while True:
        try:
            read_and_push(sym)
        except KeyboardInterrupt:
            log.info("⏹️ Arrêt")
            break
        except Exception as e:
            log.error(f"❌ Erreur inattendue: {e}")
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
