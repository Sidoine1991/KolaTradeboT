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
POLL_INTERVAL = 60   # secondes (surclassé par --interval)

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
    """Convertit tout format numerique (FR/EN, espaces, virgules) en float."""
    if s is None:
        return None
    try:
        import re as _re
        cleaned = _re.sub(r'[^\d,.\-]', '', str(s))
        if '.' in cleaned and ',' in cleaned:
            cleaned = cleaned.replace(',', '')
        else:
            cleaned = cleaned.replace(',', '.')
        return float(cleaned) if cleaned else None
    except (ValueError, TypeError):
        return None
def parse_gom_study(raw: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Extrait les valeurs GOM KOLA depuis la réponse data_get_study_values.
    Calcule le verdict BUY/SELL/WAIT à partir des scores.

    La CLI 'tv values' retourne directement :
      {"success": true, "study_count": N, "studies": [...]}
    ou wrappé dans raw["studies"].
    """
    studies_payload = raw.get("studies") or raw
    studies = []

    # Normalise : dict avec clé "studies", liste directe, ou dict racine
    if isinstance(studies_payload, dict):
        studies = studies_payload.get("studies", [])
        if not studies and studies_payload.get("study_count"):
            studies = [studies_payload]  # fallback si mal wrappé
    elif isinstance(studies_payload, list):
        studies = studies_payload

    gom_study = None
    for s in studies:
        name = (s.get("name") or "").lower()
        if "gom" in name or "kola" in name:
            gom_study = s
            break

    if not gom_study:
        log.warning("Indicateur GOM·KOLA non trouvé dans les studies — est-il visible sur le chart ?")
        return None

    vals = gom_study.get("values", {})

    vwap   = _parse_fr_float(vals.get("VWAP"))
    bb_up  = _parse_fr_float(vals.get("BB Sup"))
    bb_mid = _parse_fr_float(vals.get("BB Mid"))
    bb_dn  = _parse_fr_float(vals.get("BB Inf"))
    st     = _parse_fr_float(vals.get("Supertrend"))
    fib_0  = _parse_fr_float(vals.get("Fib 0%"))
    f236   = _parse_fr_float(vals.get("Fib 23.6%"))
    f382   = _parse_fr_float(vals.get("Fib 38.2%"))
    f500   = _parse_fr_float(vals.get("Fib 50%"))
    f618   = _parse_fr_float(vals.get("Fib 61.8%"))
    f786   = _parse_fr_float(vals.get("Fib 78.6%"))
    f100   = _parse_fr_float(vals.get("Fib 100%"))

    # Prix depuis quote
    quote_payload = raw.get("quote") or {}
    if isinstance(quote_payload, dict):
        price = _parse_fr_float(
            str(quote_payload.get("last") or quote_payload.get("close") or 0)
        )
    else:
        price = None

    # ── Calcul verdict (réplique logique Pine v2) ──────────
    score_buy  = 0.0
    score_sell = 0.0

    if st and price:
        if price > st:
            score_buy  += 1.5
        else:
            score_sell += 1.5

    if vwap and price:
        if price > vwap:
            score_buy  += 1.0
        else:
            score_sell += 1.0

    if bb_mid and price:
        if price > bb_mid:
            score_buy  += 0.5
        else:
            score_sell += 0.5

    gap     = abs(score_buy - score_sell)
    verdict = "WAIT"
    if score_buy  > score_sell and gap >= 1.2:
        verdict = "BUY"
    elif score_sell > score_buy  and gap >= 1.2:
        verdict = "SELL"

    # Supertrend direction
    st_dir = 0
    if st and price:
        st_dir = 1 if price > st else -1

    return {
        "symbol":     SYMBOL,
        "verdict":    verdict,
        "score_buy":  round(score_buy,  1),
        "score_sell": round(score_sell, 1),
        "spike_pct":  0,
        "vwap":       vwap,
        "bb_up":      bb_up,
        "bb_mid":     bb_mid,
        "bb_dn":      bb_dn,
        "st_line":    st,
        "st_dir":     st_dir,
        "fib_0":      fib_0,
        "fib_236":    f236,
        "fib_382":    f382,
        "fib_500":    f500,
        "fib_618":    f618,
        "fib_786":    f786,
        "fib_100":    f100,
        "price":      price,
    }


# ─────────────────────────────────────────────────────────────
# Push vers AI server
# ─────────────────────────────────────────────────────────────

def push_gom_verdict(payload: Dict[str, Any]) -> bool:
    try:
        r = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=payload,
            timeout=5,
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

def read_and_push() -> bool:
    """
    Lit study values + quote via CLI tradingview-kola,
    calcule le verdict GOM, pousse vers /gom-verdict.
    """
    # 1. Valeurs indicateurs (VWAP, BB, Supertrend, Fibo…)
    studies_raw = _run_tv_cli(["values"])
    if not studies_raw:
        log.warning("⚠️ 'tv values' a échoué — TradingView ouvert avec GOM·KOLA visible ?")
        return False

    # 2. Prix live
    quote_raw = _run_tv_cli(["quote"])

    # Combiner pour parse
    combined = {
        "studies": studies_raw,
        "quote":   quote_raw or {},
        "success": True,
    }

    payload = parse_gom_study(combined)
    if not payload:
        return False

    return push_gom_verdict(payload)


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
    args = parser.parse_args()

    if args.once:
        success = read_and_push()
        sys.exit(0 if success else 1)

    log.info(f"🚀 GOM Poller démarré — intervalle {args.interval}s")
    while True:
        try:
            read_and_push()
        except KeyboardInterrupt:
            log.info("⏹️ Arrêt")
            break
        except Exception as e:
            log.error(f"❌ Erreur inattendue: {e}")
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
