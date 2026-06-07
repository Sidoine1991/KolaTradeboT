#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TradBOT Autonomous Pipeline
Scan matinal TradingView → Top 5 → TradingAgents (parallel) → Fusion → Pending-Order → EA → Monitor 20min

⚠️ IMPORTANT: TradingAgents est OBLIGATOIRE pour obtenir entry/SL/TP précis.
             Ne jamais utiliser --skip-ta en production.

Usage:
  python autonomous_pipeline.py                 # Pipeline complet (RECOMMANDÉ)
  python autonomous_pipeline.py --top-n 3       # Seulement top 3
  python autonomous_pipeline.py --capital 20    # Compte $20
  python autonomous_pipeline.py --dry-run       # Simulation, pas d'ordres réels
  python autonomous_pipeline.py --skip-ta       # ⚠️ DÉCONSEILLÉ: TV uniquement (entry/SL/TP = None)

Workflow:
  1. Phase 1: Scan TradingView MCP → Top-N symboles avec scores
  2. Phase 2: TradingAgents analyse TOUS les top-N en parallèle (600s timeout)
            → ⏳ ATTENTE COMPLÈTE avant phase 3
  3. Phase 3: Fusion TV score + TA direction + Validation Boom/Crash
            → ALIGNED si TV et TA dans même sens
  4. Phase 4: Envoi ordres → TradeManager AVEC entry/SL/TP précis
  5. Phase 5: Vérification EA registry (300s polling)
  6. Phase 6: Monitor 20min pour symboles EA ready

Règles Critiques:
  - SELL interdit sur Boom (Boom = BUY uniquement)
  - BUY interdit sur Crash (Crash = SELL uniquement)
  - Correction multi-TF → REJECT (M1/M5 opposés H1/H4)
  - Score TV < 5.0 → REJECT
"""

import sys
import io
import os
import json
import math
import time
import subprocess
import argparse
import logging
from pathlib import Path
from datetime import datetime, timedelta
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional, Any
from concurrent.futures import ThreadPoolExecutor, as_completed, TimeoutError as FutureTimeout

import requests

# Fix Windows encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

_HERE    = Path(__file__).resolve().parent
_ROOT    = _HERE.parent
_LOG_DIR = _ROOT / "logs"
_LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(_LOG_DIR / "autonomous_pipeline.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("pipeline")

# Scan result uses import from morning_scan_report
sys.path.insert(0, str(_HERE))


# ---------------------------------------------------------------------------
# Whitelist pipeline — partagée avec mt5_ai_client.py ET TradeManager MQL5
# ---------------------------------------------------------------------------

_WHITELIST_PATH = _ROOT / "data" / "pipeline_whitelist.json"
# Dossier Common/Files MT5 — lu par TradeManager via FILE_COMMON
_MT5_COMMON_FILES = Path(os.environ.get("APPDATA", "")) / "MetaQuotes" / "Terminal" / "Common" / "Files"


# Mapping ticker TradingView → nom symbole MT5 Deriv
_TV_TO_MT5: dict = {
    "DERIV:BOOM_1000_INDEX":  "Boom 1000 Index",
    "DERIV:BOOM_500_INDEX":   "Boom 500 Index",
    "DERIV:BOOM_300_INDEX":   "Boom 300 Index",
    "DERIV:CRASH_1000_INDEX": "Crash 1000 Index",
    "DERIV:CRASH_500_INDEX":  "Crash 500 Index",
    "DERIV:CRASH_300_INDEX":  "Crash 300 Index",
}


def _tv_to_mt5_symbol(sym: str) -> str:
    """Convertit un ticker TV (DERIV:BOOM_1000_INDEX) en nom MT5 (Boom 1000 Index)."""
    return _TV_TO_MT5.get(sym, sym)


def _publish_pipeline_whitelist(scans) -> None:
    """Écrit la whitelist dans data/ ET dans MT5 Common/Files pour TradeManager."""
    import json as _json
    payload = {
        "generated_at": datetime.utcnow().isoformat(),
        "symbols": [
            {
                "symbol": s.mt5_symbol,
                "direction": s.direction,
                "score": round(s.confluence_score, 2),
            }
            for s in scans
        ],
    }
    content = _json.dumps(payload, indent=2)
    symbols = [s.mt5_symbol for s in scans]

    # 1. Écriture locale (pour mt5_ai_client.py)
    try:
        _WHITELIST_PATH.parent.mkdir(parents=True, exist_ok=True)
        _WHITELIST_PATH.write_text(content, encoding="utf-8")
    except Exception as e:
        log.warning("Whitelist locale non écrite: %s", e)

    # 2. Écriture dans MT5 Common/Files (pour TradeManager MQL5)
    try:
        mt5_wl = _MT5_COMMON_FILES / "pipeline_whitelist.json"
        if _MT5_COMMON_FILES.exists():
            mt5_wl.write_text(content, encoding="utf-8")
            log.info("Whitelist MT5 publiée: %s → %s", symbols, mt5_wl)
        else:
            log.warning("MT5 Common/Files introuvable: %s", _MT5_COMMON_FILES)
    except Exception as e:
        log.warning("Whitelist MT5 non écrite: %s", e)

    log.info("Whitelist publiée: %s", symbols)


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class ScanResult:
    symbol:          str   # Ticker TV (ex: DERIV:BOOM_1000_INDEX ou XAUUSD)
    direction:       str
    confluence_score: float
    entry_price:     Optional[float]
    stop_loss:       Optional[float]
    take_profit:     Optional[float]
    current_price:   float
    atr:             Optional[float]
    reasons:         List[str]
    entry_valid:     bool

    @property
    def mt5_symbol(self) -> str:
        """Nom du symbole pour MT5 (ex: Boom 1000 Index)."""
        return _tv_to_mt5_symbol(self.symbol)


@dataclass
class TAResult:
    symbol:              str
    signal_rating:       str
    normalized_rating:   str
    expert_analysis:     str
    final_trade_decision: str
    confidence:          float
    success:             bool
    entry_price:         Optional[float] = None
    stop_loss:           Optional[float] = None
    take_profit:         Optional[float] = None
    current_price:       Optional[float] = None
    atr:                 Optional[float] = None
    error:               Optional[str]  = None
    elapsed_sec:         float          = 0.0


@dataclass
class FusedSignal:
    symbol:          str
    direction:       str
    verdict:         str      # ALIGNED | CONFLICT | REJECT
    tv_score:        float
    ta_rating:       str
    entry_price:     Optional[float]
    stop_loss:       Optional[float]
    take_profit:     Optional[float]
    current_price:   float
    atr:             Optional[float]
    lot:             float
    confidence:      float
    reasoning:       str


@dataclass
class PendingOrderResult:
    symbol:      str
    order_id:    Optional[str]
    success:     bool
    lot:         float
    direction:   str
    entry_price: Optional[float]
    stop_loss:   Optional[float]
    take_profit: Optional[float]
    error:       Optional[str] = None


@dataclass
class PipelineReport:
    run_at:            str
    scan_count:        int
    top_n_candidates:  List[str]
    top_n_scans:       List["ScanResult"] = field(default_factory=list)
    ta_success:        int = 0
    ta_failed:         int = 0
    aligned_count:     int = 0
    orders_placed:     List[str] = field(default_factory=list)
    orders_failed:     List[str] = field(default_factory=list)
    ea_ready:          List[str] = field(default_factory=list)
    ea_missing:        List[str] = field(default_factory=list)
    monitor_launched:  List[str] = field(default_factory=list)
    dry_run:           bool = False
    elapsed_sec:       float = 0.0


@dataclass
class PipelineConfig:
    ai_server_url:       str   = field(default_factory=lambda: os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000"))
    psychobot_url:       str   = field(default_factory=lambda: os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com"))
    phone:               str   = field(default_factory=lambda: os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346"))
    top_n:               int   = 5
    max_concurrent_ta:   int   = 3
    ta_timeout_sec:      int   = 600
    capital:             float = 50.0
    risk_pct:            float = 0.02
    min_tv_score:        float = 0.5  # Abaissé pour accepter plus de signaux (était 5.0)
    min_tv_score_tv_only: float = 2.0  # Abaissé (était 7.0)
    ea_poll_interval_sec: int  = 30
    ea_poll_max_sec:     int   = 300
    monitor_interval_sec: int  = 1200   # 20 min
    dry_run:             bool  = False
    skip_ta:             bool  = False


# ---------------------------------------------------------------------------
# Symbol utilities (copié de tradbot_bridge pour éviter l'import circulaire)
# ---------------------------------------------------------------------------

_SYMBOL_CATEGORIES = {
    "BOOM":  ["BOOM1000", "BOOM900", "BOOM600", "BOOM500", "BOOM300"],
    "CRASH": ["CRASH1000", "CRASH900", "CRASH600", "CRASH500", "CRASH300"],
    "VOLATILITY": ["V10N", "V25", "V50", "V75", "V100", "1HZ"],
    "GOLD":  ["XAUUSD"],
    "SILVER": ["XAGUSD"],
    "INDICES": ["US30", "US500", "NAS100", "USTEC", "UK100", "GER40"],
    "CRYPTO": ["BTCUSD", "ETHUSD"],
}

def _get_symbol_category(symbol: str) -> str:
    # Nettoyer préfixes TV (DERIV:BOOM_500_INDEX → BOOM500INDEX)
    s = symbol.upper().replace(" ", "").replace("DERIV:", "").replace("_INDEX", "").replace("INDEX", "")
    for cat, symbols in _SYMBOL_CATEGORIES.items():
        if any(s.startswith(p) for p in symbols):
            return cat
    if "BOOM" in s:
        return "BOOM"
    if "CRASH" in s:
        return "CRASH"
    if any(s.startswith(p) for p in ("1HZ", "R_", "V10", "V25", "V50", "V75", "V100", "VOLATILITY")):
        return "VOLATILITY"
    return "FOREX"


def _lot_min(symbol: str) -> float:
    cat = _get_symbol_category(symbol)
    return 0.20 if cat in ("BOOM", "CRASH") else 0.01


def _compute_lot(symbol: str, entry: float, sl: float, capital: float, risk_pct: float) -> float:
    # RÈGLE : toujours utiliser le lot minimum — sécurité maximale
    return _lot_min(symbol)

def _compute_lot_full(symbol: str, entry: float, sl: float, capital: float, risk_pct: float) -> float:
    """Calcul complet du lot (conservé pour référence, non utilisé en auto)."""
    """
    Lot = risk_amount / (sl_dist_in_price_points * dollar_per_point_per_lot)
    Références (valeur du point par lot entier):
      XAUUSD : $100/lot  → 1 pt = $1 / 0.01 lot
      Forex  : ~$10/lot  → 1 pip = $10 / lot (1 pip = 0.0001)
      BOOM/CRASH : ~$1/pt / lot
      Indices US30/NAS100 : ~$10/pt / lot
    On exprime sl_dist en unités de prix brutes et ajuste dollar_per_point.
    """
    lot_min = _lot_min(symbol)
    risk_amount = capital * risk_pct
    sl_dist = abs(entry - sl)
    if sl_dist <= 0:
        return lot_min

    cat = _get_symbol_category(symbol)
    # dollar_per_point_per_lot : combien de $ par unité de prix par lot standard
    if cat in ("BOOM", "CRASH"):
        dollar_per_point = 1.0
    elif cat == "VOLATILITY":
        dollar_per_point = 0.5
    elif cat == "GOLD":
        dollar_per_point = 100.0   # XAUUSD: 1 pt = $100 / lot
    elif cat == "SILVER":
        dollar_per_point = 50.0
    elif cat in ("INDICES",):
        dollar_per_point = 10.0
    elif cat == "CRYPTO":
        dollar_per_point = 1.0
    else:
        # Forex: sl_dist ~ pips×0.0001, valeur pip = ~$10/lot
        dollar_per_point = 10.0 / 0.0001 * 0.0001  # = 10.0 (normalised)

    raw = risk_amount / (sl_dist * dollar_per_point)

    # Arrondi au lot_step inférieur (évite float precision issues)
    lot_step = lot_min
    floored = math.floor(raw / lot_step) * lot_step
    lot = max(lot_min, round(floored, 2))

    # Sécurité: jamais plus de 10% du capital en 1 trade
    lot = min(lot, round(capital * 0.10 / max(sl_dist * dollar_per_point, 0.001), 2))
    lot = max(lot_min, lot)
    return lot


# ---------------------------------------------------------------------------
# Core pipeline
# ---------------------------------------------------------------------------

class AutonomousPipeline:

    def __init__(self, config: PipelineConfig):
        self.cfg = config
        self.session = requests.Session()
        self.session.headers.update({"Content-Type": "application/json"})

    # ── Phase 1 : SCAN ──────────────────────────────────────────────────────

    def phase_scan(self) -> List[ScanResult]:
        log.info("=== PHASE 1 : Scan TradingView ===")
        from morning_scan_report import MorningScanReportGenerator
        gen = MorningScanReportGenerator()
        symbols = gen.get_open_market_symbols()
        log.info("Scanning %d symboles ouverts...", len(symbols))

        raw_results = gen.run_mcp_watchlist_scan(symbols)
        self._last_raw_scan = raw_results  # conservé pour rapport Word
        normalized  = [gen.normalize_result(r) for r in raw_results]
        # Accepte aussi les résultats avec direction claire même si entry_valid=False
        # (le seuil entry_valid=True est recalculé en Phase 3 via min_tv_score)
        valid = [
            r for r in normalized
            if r.get("success")
            and r.get("direction") in ("BUY", "SELL")
            and r.get("confluence_score", 0) >= self.cfg.min_tv_score
        ]
        if not valid:
            # Fallback: prendre tout ce qui a une direction même avec score faible
            valid = [
                r for r in normalized
                if r.get("success") and r.get("direction") in ("BUY", "SELL")
            ]
        sorted_all  = sorted(valid, key=lambda x: x.get("confluence_score", 0), reverse=True)
        top         = sorted_all[:self.cfg.top_n]

        scan_results = []
        for r in top:
            scan_results.append(ScanResult(
                symbol          = r["symbol"],
                direction       = r["direction"],
                confluence_score= float(r.get("confluence_score", 0)),
                entry_price     = r.get("entry_price"),
                stop_loss       = r.get("stop_loss"),
                take_profit     = r.get("take_profit"),
                current_price   = float(r.get("current_price") or 0),
                atr             = r.get("atr"),
                reasons         = r.get("reasons", []),
                entry_valid     = bool(r.get("entry_valid")),
            ))
            log.info("  TOP: %-10s %-4s score=%.1f/10  entry=%s",
                     r["symbol"], r["direction"], r.get("confluence_score", 0), r.get("entry_price"))

        log.info("Scan terminé: %d setups valides, %d retenus (top %d)",
                 len(valid), len(top), self.cfg.top_n)

        # Publier la whitelist pour mt5_ai_client.py
        _publish_pipeline_whitelist(scan_results)

        return scan_results

    # ── Phase 2 : ENRICH (TradingAgents) ────────────────────────────────────

    def _fetch_gom_levels(self, symbol: str) -> dict:
        """Récupère setup_entry/sl/tp depuis le poller GOM (données GOM KOLA script TradingView)."""
        mt5_sym = _tv_to_mt5_symbol(symbol)
        for sym in [mt5_sym, symbol]:
            try:
                r = requests.get(
                    f"{self.cfg.ai_server_url}/gom-verdict",
                    params={"symbol": sym}, timeout=4,
                )
                if r.status_code != 200:
                    continue
                data = r.json()
                if not data.get("ok"):
                    continue
                entry = data.get("setup_entry") or data.get("entry_price")
                sl    = data.get("setup_sl")    or data.get("stop_loss")
                tp    = data.get("setup_tp1")   or data.get("take_profit")
                atr   = data.get("atr")
                price = data.get("close") or data.get("current_price")
                # Calculer SL/TP via ATR si manquants mais ATR présent
                if entry and atr and not sl:
                    atr_f = float(atr)
                    direction = data.get("tf_global_dir", "")
                    is_buy = "BULL" in direction.upper() if direction else True
                    sl = round(float(entry) - atr_f * 1.5, 5) if is_buy else round(float(entry) + atr_f * 1.5, 5)
                if entry and sl and not tp:
                    sl_dist = abs(float(entry) - float(sl))
                    is_buy = float(entry) > float(sl)
                    tp = round(float(entry) + sl_dist * 2.0, 5) if is_buy else round(float(entry) - sl_dist * 2.0, 5)
                if entry and sl and tp:
                    log.info("  [GOM] %s → entry=%.5f SL=%.5f TP=%.5f", symbol, float(entry), float(sl), float(tp))
                    return {"entry": float(entry), "sl": float(sl), "tp": float(tp),
                            "atr": float(atr) if atr else None, "price": float(price) if price else None}
            except Exception:
                continue
        return {}

    def phase_enrich(self, candidates: List[ScanResult]) -> List[TAResult]:
        if self.cfg.skip_ta:
            log.info("=== PHASE 2 : Skip TradingAgents — récupération niveaux GOM ===")
            results = []
            for c in candidates:
                gom = self._fetch_gom_levels(c.symbol)
                entry = gom.get("entry") or c.entry_price
                sl    = gom.get("sl")    or c.stop_loss
                tp    = gom.get("tp")    or c.take_profit
                atr   = gom.get("atr")   or c.atr
                price = gom.get("price") or c.current_price
                if entry and sl and tp:
                    log.info("  [GOM ✅] %s entry=%.5f SL=%.5f TP=%.5f", c.symbol, entry, sl, tp)
                else:
                    log.warning("  [GOM ⚠️] %s — niveaux manquants (entry=%s SL=%s TP=%s)", c.symbol, entry, sl, tp)
                results.append(TAResult(
                    symbol=c.symbol, signal_rating=c.direction,
                    normalized_rating=c.direction, expert_analysis="",
                    final_trade_decision="", confidence=c.confluence_score / 10.0,
                    success=True, entry_price=entry,
                    stop_loss=sl, take_profit=tp,
                    current_price=price, atr=atr,
                ))
            return results

        log.info("=== PHASE 2 : TradingAgents (%d symboles, max %d en parallèle, timeout %ds) ===",
                 len(candidates), self.cfg.max_concurrent_ta, self.cfg.ta_timeout_sec)
        log.info("⏳ Attente COMPLÈTE de tous les TradingAgents avant phase 3 (fusion)...")

        date_str = datetime.utcnow().strftime("%Y-%m-%d")
        worker   = str(_HERE / "ta_worker.py")

        # Charger .env si pas encore chargé (subprocess ne l'hérite pas toujours)
        _env_file = _ROOT / ".env"
        if _env_file.exists() and not os.getenv("AI_TRADINGAGENTS_REPO_PATH"):
            for line in _env_file.read_text(encoding="utf-8").splitlines():
                if "=" in line and not line.startswith("#"):
                    k, _, v = line.partition("=")
                    os.environ.setdefault(k.strip(), v.strip())

        # Utiliser le venv TradingAgents — contient typer, langchain, etc.
        ta_repo = os.getenv("AI_TRADINGAGENTS_REPO_PATH", "")
        _ta_venv = Path(ta_repo) / ".venv" / "Scripts" / "python.exe" if ta_repo else None
        python = str(_ta_venv) if _ta_venv and _ta_venv.exists() else sys.executable
        log.info("  [TA] Python: %s", python)

        def _run_one(scan: ScanResult) -> TAResult:
            log.info("  [TA] Démarrage analyse: %s", scan.symbol)
            t0  = time.time()
            cmd = [python, worker, scan.symbol, date_str]
            try:
                proc = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=self.cfg.ta_timeout_sec,
                )
                stdout = proc.stdout.strip()
                if not stdout:
                    raise ValueError(f"stdout vide, stderr={proc.stderr[-300:]}")
                data = json.loads(stdout)
                elapsed = round(time.time() - t0, 1)
                log.info("  [TA] %s → %s (%ss)", scan.symbol,
                         data.get("normalized_rating", "?"), elapsed)
                return TAResult(
                    symbol              = scan.symbol,
                    signal_rating       = data.get("signal_rating", "HOLD"),
                    normalized_rating   = data.get("normalized_rating", "HOLD"),
                    expert_analysis     = data.get("expert_analysis", ""),
                    final_trade_decision= data.get("final_trade_decision", ""),
                    confidence          = float(data.get("confidence", 0.5)),
                    success             = bool(data.get("success", False)),
                    entry_price         = data.get("entry_price"),
                    stop_loss           = data.get("stop_loss"),
                    take_profit         = data.get("take_profit"),
                    current_price       = data.get("current_price"),
                    atr                 = data.get("atr"),
                    error               = data.get("error"),
                    elapsed_sec         = elapsed,
                )
            except subprocess.TimeoutExpired:
                log.warning("  [TA] %s : TIMEOUT après %ds", scan.symbol, self.cfg.ta_timeout_sec)
                return TAResult(symbol=scan.symbol, signal_rating="TIMEOUT",
                                normalized_rating="HOLD", expert_analysis="",
                                final_trade_decision="", confidence=0.0, success=False,
                                error="Timeout", elapsed_sec=round(time.time() - t0, 1))
            except Exception as e:
                log.error("  [TA] %s : ERREUR %s", scan.symbol, e)
                return TAResult(symbol=scan.symbol, signal_rating="ERROR",
                                normalized_rating="HOLD", expert_analysis="",
                                final_trade_decision="", confidence=0.0, success=False,
                                error=str(e), elapsed_sec=round(time.time() - t0, 1))

        results = []
        with ThreadPoolExecutor(max_workers=self.cfg.max_concurrent_ta) as pool:
            future_map = {pool.submit(_run_one, c): c for c in candidates}
            try:
                # ⏳ ATTENTE BLOQUANTE - Tous les workers doivent terminer avant de continuer
                log.info("  [TA] Attente de %d analyses TradingAgents...", len(candidates))
                for future in as_completed(future_map, timeout=self.cfg.ta_timeout_sec + 60):
                    try:
                        result = future.result()
                        results.append(result)
                        # Log progrès
                        completed = len(results)
                        total = len(candidates)
                        pct = int(completed / total * 100)
                        log.info("  [TA] Progrès: %d/%d (%d%%) — %s terminé",
                                completed, total, pct, result.symbol)
                    except Exception as e:
                        scan = future_map[future]
                        results.append(TAResult(symbol=scan.symbol, signal_rating="ERROR",
                                                normalized_rating="HOLD", expert_analysis="",
                                                final_trade_decision="", confidence=0.0,
                                                success=False, error=str(e), elapsed_sec=0))
            except FutureTimeout:
                # Certains workers n'ont pas répondu dans le budget global
                for future, scan in future_map.items():
                    if not future.done():
                        log.warning("  [TA] %s : timeout global — annulé", scan.symbol)
                        results.append(TAResult(
                            symbol=scan.symbol, signal_rating="TIMEOUT",
                            normalized_rating="HOLD", expert_analysis="",
                            final_trade_decision="", confidence=0.0, success=False,
                            error="Global timeout", elapsed_sec=float(self.cfg.ta_timeout_sec),
                        ))

        success_n = sum(1 for r in results if r.success)
        log.info("✅ Enrichissement COMPLET: %d/%d succès — Passage à phase 3 (fusion)", success_n, len(results))
        return results

    # ── Phase 3 : FUSE ──────────────────────────────────────────────────────

    def phase_fuse(self, scans: List[ScanResult], ta_results: List[TAResult]) -> List[FusedSignal]:
        log.info("=== PHASE 3 : Fusion TV + TA ===")
        ta_by_symbol = {r.symbol: r for r in ta_results}
        fused = []

        for scan in scans:
            ta = ta_by_symbol.get(scan.symbol)

            # 🚫 RÈGLE CRITIQUE: Validation Boom/Crash AVANT fusion
            boom_crash_ok, boom_crash_reason = self._validate_boom_crash_direction(scan.symbol, scan.direction)
            if not boom_crash_ok:
                log.warning("  🚫 %s: %s — REJET IMMÉDIAT", scan.symbol, boom_crash_reason)
                fused.append(FusedSignal(
                    symbol=scan.symbol, direction=scan.direction, verdict="REJECT",
                    tv_score=scan.confluence_score, ta_rating="N/A",
                    entry_price=None, stop_loss=None, take_profit=None,
                    current_price=scan.current_price, atr=scan.atr, lot=0.0,
                    confidence=0.0, reasoning=boom_crash_reason,
                ))
                continue

            verdict, direction, confidence, reasoning = self._compute_verdict(scan, ta)

            # Choisir les niveaux : TradingAgents prioritaire si disponibles, sinon TV
            entry = None
            sl    = None
            tp    = None
            if ta and ta.success:
                entry = ta.entry_price or scan.entry_price
                sl    = ta.stop_loss   or scan.stop_loss
                tp    = ta.take_profit or scan.take_profit
            else:
                entry = scan.entry_price
                sl    = scan.stop_loss
                tp    = scan.take_profit

            current = (ta.current_price if ta and ta.current_price else scan.current_price) or 0
            atr     = (ta.atr if ta and ta.atr else scan.atr)

            # Calculer SL/TP si manquants via ATR
            if verdict == "ALIGNED" and entry:
                entry_f = float(entry)
                if atr and not sl:
                    atr_f = float(atr)
                    sl = round(entry_f - atr_f * 1.5, 5) if direction == "BUY" else round(entry_f + atr_f * 1.5, 5)
                if sl and not tp:
                    sl_dist = abs(entry_f - float(sl))
                    tp = round(entry_f + sl_dist * 2.0, 5) if direction == "BUY" else round(entry_f - sl_dist * 2.0, 5)

            lot = 0.0
            if verdict == "ALIGNED" and entry and sl:
                lot = _compute_lot(scan.symbol, float(entry), float(sl), self.cfg.capital, self.cfg.risk_pct)

            fused.append(FusedSignal(
                symbol        = scan.symbol,
                direction     = direction,
                verdict       = verdict,
                tv_score      = scan.confluence_score,
                ta_rating     = ta.normalized_rating if ta else "N/A",
                entry_price   = entry,
                stop_loss     = sl,
                take_profit   = tp,
                current_price = current,
                atr           = atr,
                lot           = lot,
                confidence    = confidence,
                reasoning     = reasoning,
            ))
            icon = "✅" if verdict == "ALIGNED" else "⚡" if verdict == "CONFLICT" else "❌"
            log.info("  %s %-10s %-4s | TV=%.1f TA=%-4s → %s",
                     icon, scan.symbol, direction, scan.confluence_score,
                     ta.normalized_rating if ta else "N/A", verdict)

        aligned = [f for f in fused if f.verdict == "ALIGNED"]
        log.info("Fusion terminée: %d/%d ALIGNED", len(aligned), len(fused))
        return fused

    @staticmethod
    def _validate_boom_crash_direction(symbol: str, direction: str) -> tuple[bool, str]:
        """
        🚫 RÈGLE CRITIQUE: SELL interdit sur Boom, BUY interdit sur Crash.
        Indices synthétiques unidirectionnels — violation = perte garantie 100%.

        Returns:
            (ok, reason): (True, "") si valide, (False, raison) si interdit
        """
        symbol_upper = symbol.upper()
        direction_upper = direction.upper()

        # BOOM = BUY uniquement (spikes haussiers)
        if "BOOM" in symbol_upper and direction_upper == "SELL":
            return False, "🚫 SELL INTERDIT sur Boom (Boom = BUY uniquement - spikes haussiers)"

        # CRASH = SELL uniquement (spikes baissiers)
        if "CRASH" in symbol_upper and direction_upper == "BUY":
            return False, "🚫 BUY INTERDIT sur Crash (Crash = SELL uniquement - spikes baissiers)"

        return True, ""

    @staticmethod
    def _check_trend_alignment(scan: ScanResult) -> tuple[bool, str]:
        """
        Gate tendance globale multi-TF.
        Règle absolue : ne jamais trader une correction.
        - tf_global_dir GOM doit être aligné avec la direction
        - Si M1/M5 opposés à H1/H4 → zone correction → REJECT
        Retourne (ok, raison)
        """
        # Récupérer GOM verdict pour ce symbole
        try:
            r = requests.get(
                f"{os.getenv('AI_SERVER_URL','http://127.0.0.1:8000')}/gom-verdict",
                params={"symbol": scan.symbol}, timeout=3,
            )
            if r.status_code != 200:
                return True, "GOM indisponible — gate ignoré"
            gom = r.json()
            if not gom.get("ok"):
                return True, "Pas de GOM — gate ignoré"
        except Exception:
            return True, "GOM inaccessible — gate ignoré"

        direction = scan.direction.upper()

        # 1. Tendance globale (tf_global_dir)
        global_dir = str(gom.get("tf_global_dir", "")).upper()
        if global_dir in ("BULL", "BEAR"):
            expected = "BUY" if global_dir == "BULL" else "SELL"
            if direction != expected:
                return False, f"Contre tendance globale: global={global_dir} signal={direction}"

        # 2. Cohérence multi-TF (M1/M5 vs H1/H4)
        # Les TF courts doivent être alignés avec les TF longs
        tf_m1  = str(gom.get("tf_m1_dir",  "")).upper()
        tf_m5  = str(gom.get("tf_m5_dir",  "")).upper()
        tf_h1  = str(gom.get("tf_h1_dir",  "")).upper()
        tf_h4  = str(gom.get("tf_h4_dir",  "")).upper()

        # Détecter zone correction : TF courts opposés aux TF longs
        long_dirs  = [d for d in [tf_h1, tf_h4] if d in ("BULL","BEAR","UP","DOWN","BUY","SELL")]
        short_dirs = [d for d in [tf_m1, tf_m5] if d in ("BULL","BEAR","UP","DOWN","BUY","SELL")]

        def _is_bearish(d): return d in ("BEAR","DOWN","SELL")
        def _is_bullish(d): return d in ("BULL","UP","BUY")

        if long_dirs and short_dirs:
            long_bull  = sum(1 for d in long_dirs  if _is_bullish(d))
            long_bear  = sum(1 for d in long_dirs  if _is_bearish(d))
            short_bull = sum(1 for d in short_dirs if _is_bullish(d))
            short_bear = sum(1 for d in short_dirs if _is_bearish(d))

            long_trend  = "BULL" if long_bull  > long_bear  else "BEAR" if long_bear  > long_bull  else None
            short_trend = "BULL" if short_bull > short_bear else "BEAR" if short_bear > short_bull else None

            if long_trend and short_trend and long_trend != short_trend:
                return False, (
                    f"Zone correction: M1/M5={short_trend} vs H1/H4={long_trend} — "
                    f"attendre realignement TF courts"
                )

        return True, "Tendance multi-TF alignée"

    @staticmethod
    def _compute_verdict(scan: ScanResult, ta: Optional[TAResult]):
        """
        Matrice de décision TV + TA:
          1. Gate tendance globale multi-TF (correction → REJECT absolu)
          2. BUY + BUY  >= 5   → ALIGNED BUY
             SELL + SELL >= 5  → ALIGNED SELL
             direction opposée → CONFLICT (reject)
             BUY/SELL + HOLD >= 7 → ALIGNED (TV dominant)
             score < 5          → REJECT
        """
        tv_dir   = scan.direction.upper()
        tv_score = scan.confluence_score

        if tv_score < 5.0:
            return "REJECT", tv_dir, 0.3, f"Score TV {tv_score:.1f} < 5.0"

        if tv_dir not in ("BUY", "SELL"):
            return "REJECT", tv_dir, 0.3, "Direction TV neutre"

        # Gate tendance globale — règle absolue
        trend_ok, trend_reason = AutonomousPipeline._check_trend_alignment(scan)
        if not trend_ok:
            return "REJECT", tv_dir, 0.2, f"CORRECTION: {trend_reason}"

        if ta is None or not ta.success:
            if tv_score >= 7.0:
                conf = min(tv_score / 10.0, 0.85)
                return "ALIGNED", tv_dir, conf, f"TV only (score {tv_score:.1f}>=7, TA indisponible)"
            return "REJECT", tv_dir, 0.4, f"TA indisponible et score TV {tv_score:.1f} < 7"

        ta_dir = ta.normalized_rating.upper()

        # Alignement parfait
        if tv_dir == ta_dir and ta_dir in ("BUY", "SELL"):
            conf = min((tv_score / 10.0 * 0.6) + (ta.confidence * 0.4), 0.95)
            return "ALIGNED", tv_dir, conf, f"TV {tv_score:.1f}/10 + TA {ta_dir} | {trend_reason}"

        # Opposition directe
        if ta_dir in ("BUY", "SELL") and ta_dir != tv_dir:
            return "CONFLICT", tv_dir, 0.3, f"CONFLIT TV={tv_dir} vs TA={ta_dir}"

        # TA=HOLD mais TV forte
        if ta_dir == "HOLD":
            if tv_score >= 7.0:
                conf = min(tv_score / 10.0 * 0.7, 0.75)
                return "ALIGNED", tv_dir, conf, f"TV dominant {tv_score:.1f}/10 (TA=HOLD) | {trend_reason}"
            return "REJECT", tv_dir, 0.35, f"TA=HOLD et score TV {tv_score:.1f} < 7"

        return "REJECT", tv_dir, 0.3, "Cas non couvert"

    # ── Phase 4 : PUSH ──────────────────────────────────────────────────────

    def phase_push(self, signals: List[FusedSignal]) -> List[PendingOrderResult]:
        log.info("=== PHASE 4 : Envoi ordres → TradeManager ===")
        aligned = [s for s in signals if s.verdict == "ALIGNED"]

        if not aligned:
            log.info("  Aucun signal ALIGNED — aucun ordre envoyé")
            return []

        # Vérification entry/SL/TP présents
        missing_levels = [s.symbol for s in aligned if not (s.entry_price and s.stop_loss and s.take_profit)]
        if missing_levels:
            log.warning("  ⚠️ Ordres INCOMPLETS (entry/SL/TP manquants): %s", missing_levels)
            log.warning("  ⚠️ TradeManager ne pourra pas exécuter correctement!")

        if self.cfg.dry_run:
            log.info("  DRY-RUN: simulation de %d ordres", len(aligned))
            return [
                PendingOrderResult(
                    symbol=s.symbol, order_id="DRY-RUN", success=True,
                    lot=s.lot, direction=s.direction,
                    entry_price=s.entry_price, stop_loss=s.stop_loss, take_profit=s.take_profit,
                )
                for s in aligned
            ]

        log.info("  📤 Envoi %d ordres COMPLETS (entry/SL/TP depuis TradingAgents)...", len(aligned))
        results = []
        for sig in aligned:
            result = self._push_one_order(sig)
            results.append(result)
            icon = "✅" if result.success else "❌"
            log.info("  %s Ordre %s %s @ %s SL=%s TP=%s lot=%s",
                     icon, sig.direction, sig.symbol,
                     sig.entry_price, sig.stop_loss, sig.take_profit, sig.lot)

        ok = sum(1 for r in results if r.success)
        log.info("Ordres envoyés: %d/%d", ok, len(results))
        return results

    def _push_one_order(self, sig: FusedSignal) -> PendingOrderResult:
        payload = {
            "symbol":         sig.symbol,
            "action":         sig.direction.lower(),
            "recommendation": sig.direction,
            "execution_type": "market",
            "entry_price":    sig.entry_price,
            "stop_loss":      sig.stop_loss,
            "take_profit":    sig.take_profit,
            "lot":            sig.lot,
            "confidence":     round(sig.confidence, 3),
            "source":         "autonomous_pipeline",
            "comment":        f"TV={sig.tv_score:.1f} TA={sig.ta_rating}",
            "reasoning":      sig.reasoning,
            "status":         "ready",
        }
        try:
            r = self.session.post(
                f"{self.cfg.ai_server_url}/pending-order",
                json=payload, timeout=10,
            )
            r.raise_for_status()
            resp = r.json()
            return PendingOrderResult(
                symbol=sig.symbol, order_id=resp.get("order_id"),
                success=True, lot=sig.lot, direction=sig.direction,
                entry_price=sig.entry_price, stop_loss=sig.stop_loss,
                take_profit=sig.take_profit,
            )
        except Exception as e:
            return PendingOrderResult(
                symbol=sig.symbol, order_id=None, success=False,
                lot=sig.lot, direction=sig.direction,
                entry_price=sig.entry_price, stop_loss=sig.stop_loss,
                take_profit=sig.take_profit, error=str(e),
            )

    # ── Phase 5 : EA READINESS ───────────────────────────────────────────────

    def phase_ea_readiness(self, symbols: List[str]) -> Dict[str, bool]:
        """Vérifie l'EA registry — NON BLOQUANT.
        Les ordres sont déjà dans /pending-order sur l'AI server.
        TradeManager les récupère à son prochain poll (3s) dès qu'il est attaché.
        On vérifie une seule fois et on notifie si manquant, sans bloquer le pipeline.
        """
        log.info("=== PHASE 5 : Vérification EA registry ===")
        if not symbols:
            return {}

        registered = self._get_registered_symbols()
        log.info("  Symboles enregistrés dans EA: %s", registered)

        missing = [s for s in symbols if s not in registered]
        ready   = {s: s in registered for s in symbols}

        if missing:
            log.info("  Symboles absents de MT5: %s", missing)
            log.info("  ℹ️ Ordres en attente sur /pending-order — TradeManager les exécutera au prochain poll")
            self._alert_missing_symbols(missing)
        else:
            log.info("  ✅ Tous les symboles sont dans l'EA registry")

        return ready

    def _get_registered_symbols(self) -> List[str]:
        try:
            r = self.session.get(
                f"{self.cfg.ai_server_url}/tradingagents/realtime/status",
                timeout=5,
            )
            if r.status_code == 200:
                data = r.json()
                return [s.upper() for s in (data.get("symbols_mt5_push") or [])]
        except Exception:
            pass
        return []

    def _alert_missing_symbols(self, missing: List[str]):
        symbols_str = ", ".join(missing)
        msg = (
            f"*TradBOT — Ordres en attente*\n"
            f"Pipeline autonome: {len(missing)} ordre(s) placé(s) sur le serveur\n\n"
            f"*{symbols_str}*\n\n"
            f"✅ Ordres sauvegardés sur /pending-order\n"
            f"⏳ TradeManager les exécutera automatiquement\n"
            f"   dès qu'il sera attaché sur ces charts MT5"
        )
        log.info("  WhatsApp alert → %s", symbols_str)
        self._send_whatsapp(msg)

    def _send_whatsapp(self, message: str) -> bool:
        for attempt in range(3):
            try:
                r = requests.post(
                    f"{self.cfg.psychobot_url}/send-message",
                    json={"phone": self.cfg.phone, "message": message},
                    timeout=15,
                    verify=False,
                )
                if r.status_code == 200:
                    return True
                log.warning("  WhatsApp HTTP %d (tentative %d/3)", r.status_code, attempt + 1)
            except Exception as e:
                log.warning("  WhatsApp erreur (tentative %d/3): %s", attempt + 1, e)
            if attempt < 2:
                time.sleep(5)
        return False

    # ── Phase 6 : MONITOR ───────────────────────────────────────────────────

    def phase_monitor(self, symbols: List[str], fused_signals: List[FusedSignal] = None):
        if not symbols:
            return
        log.info("=== PHASE 6 : Lancement notifier trade pour %s ===", symbols)
        notifier_script = _HERE / "trade_notifier.py"
        monitor_script  = _HERE / "bridge_followup_monitor.py"

        sig_by_symbol = {s.symbol: s for s in (fused_signals or [])}

        for symbol in symbols:
            sig = sig_by_symbol.get(symbol)

            # Lancer trade_notifier si on a les niveaux
            if notifier_script.exists() and sig and sig.entry_price and sig.stop_loss and sig.take_profit:
                try:
                    subprocess.Popen(
                        [sys.executable, str(notifier_script),
                         "--symbol",    symbol,
                         "--direction", sig.direction,
                         "--entry",     str(sig.entry_price),
                         "--sl",        str(sig.stop_loss),
                         "--tp",        str(sig.take_profit),
                         "--lot",       str(sig.lot or 0.01)],
                        cwd=str(_ROOT),
                        creationflags=subprocess.CREATE_NEW_CONSOLE if sys.platform == "win32" else 0,
                    )
                    log.info("  ✅ Trade notifier démarré: %s %s e=%s sl=%s tp=%s",
                             symbol, sig.direction, sig.entry_price, sig.stop_loss, sig.take_profit)
                    continue
                except Exception as e:
                    log.warning("  Trade notifier %s : %s", symbol, e)

            # Fallback: bridge_followup_monitor si pas de niveaux
            if monitor_script.exists():
                try:
                    subprocess.Popen(
                        [sys.executable, str(monitor_script),
                         "--symbol", symbol,
                         "--interval", str(self.cfg.monitor_interval_sec)],
                        cwd=str(_ROOT),
                        creationflags=subprocess.CREATE_NEW_CONSOLE if sys.platform == "win32" else 0,
                    )
                    log.info("  ✅ Monitor fallback démarré: %s", symbol)
                except Exception as e:
                    log.warning("  Monitor %s : %s", symbol, e)

    # ── Orchestrateur principal ──────────────────────────────────────────────

    def run(self) -> PipelineReport:
        t0 = time.time()
        run_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
        log.info("=" * 60)
        log.info("TradBOT Autonomous Pipeline — %s", run_at)
        log.info("Capital: $%.0f  Risque: %.0f%%  Top-%d  DryRun: %s",
                 self.cfg.capital, self.cfg.risk_pct * 100, self.cfg.top_n, self.cfg.dry_run)
        log.info("=" * 60)

        # Phase 1 — Scan
        try:
            scans = self.phase_scan()
        except Exception as e:
            log.error("Scan échoué: %s — pipeline arrêté", e)
            raise

        if not scans:
            log.warning("Aucun setup valide — pipeline terminé")
            return PipelineReport(
                run_at=run_at, scan_count=0, top_n_candidates=[],
                ta_success=0, ta_failed=0, aligned_count=0,
                orders_placed=[], orders_failed=[], ea_ready=[],
                ea_missing=[], monitor_launched=[], dry_run=self.cfg.dry_run,
                elapsed_sec=round(time.time() - t0, 1),
            )

        # Phase 2 — Enrich
        ta_results = self.phase_enrich(scans)
        ta_success = sum(1 for r in ta_results if r.success)
        ta_failed  = len(ta_results) - ta_success

        # Phase 3 — Fuse
        fused = self.phase_fuse(scans, ta_results)
        aligned = [f for f in fused if f.verdict == "ALIGNED"]

        # Phase 4 — Push orders
        order_results = self.phase_push(fused)
        orders_placed = [r.symbol for r in order_results if r.success]
        orders_failed = [r.symbol for r in order_results if not r.success]

        # Phase 5 — EA readiness (seulement pour les ordres réussis)
        ea_ready_map = self.phase_ea_readiness(orders_placed)
        ea_ready   = [s for s, ok in ea_ready_map.items() if ok]
        ea_missing = [s for s, ok in ea_ready_map.items() if not ok]

        # Phase 6 — Monitor (seulement symboles EA ready)
        self.phase_monitor(ea_ready, fused_signals=[s for s in fused if s.verdict == "ALIGNED"])

        # Rapport WhatsApp final
        elapsed = round(time.time() - t0, 1)
        report = PipelineReport(
            run_at=run_at,
            scan_count=len(scans),
            top_n_candidates=[s.symbol for s in scans],
            top_n_scans=scans,
            ta_success=ta_success,
            ta_failed=ta_failed,
            aligned_count=len(aligned),
            orders_placed=orders_placed,
            orders_failed=orders_failed,
            ea_ready=ea_ready,
            ea_missing=ea_missing,
            monitor_launched=ea_ready,
            dry_run=self.cfg.dry_run,
            elapsed_sec=elapsed,
        )
        self._send_summary_whatsapp(report, fused)
        self._print_terminal_summary(report, fused)
        self._send_word_report()

        log.info("Pipeline terminé en %.1fs", elapsed)
        return report

    def _send_word_report(self):
        """Génère le rapport Word complet et l'envoie via WhatsApp (base64)."""
        try:
            from morning_scan_report import MorningScanReportGenerator
            gen = MorningScanReportGenerator()
            raw = getattr(self, "_last_raw_scan", None)
            if not raw:
                log.warning("Pas de données scan pour rapport Word")
                return
            log.info("=== Génération rapport Word ===")
            gen.run(scan_results=raw)
        except Exception as e:
            log.warning("Rapport Word échoué: %s", e)

    def _send_summary_whatsapp(self, report: PipelineReport, fused: List[FusedSignal]):
        dry_tag = " (DRY-RUN)" if report.dry_run else ""
        aligned = [f for f in fused if f.verdict == "ALIGNED"]

        msg = (
            f"*TradBOT — Pipeline Autonome{dry_tag}*\n"
            f"_{report.run_at}_\n\n"
        )

        # Top-N détaillé avec score
        if report.top_n_scans:
            msg += f"*Top-{len(report.top_n_scans)} scannés:*\n"
            for s in report.top_n_scans:
                icon = "🟢" if s.direction == "BUY" else "🔴"
                stars = "⭐" * min(int(s.confluence_score / 2), 5)
                msg += f"{icon} *{s.symbol}* {s.direction} — score {s.confluence_score:.1f}/10 {stars}\n"
            msg += "\n"
        else:
            msg += f"Scan: *0* symbole retenu sur 14 analysés\n\n"

        msg += (
            f"TradingAgents: {report.ta_success} OK / {report.ta_failed} échecs\n"
            f"Convergence: *{report.aligned_count} ALIGNED*\n\n"
        )

        if aligned:
            msg += "*Signaux confirmés:*\n"
            for sig in aligned:
                icon = "🟢" if sig.direction == "BUY" else "🔴"
                msg += (
                    f"{icon} *{sig.symbol}* {sig.direction} "
                    f"TV={sig.tv_score:.1f} TA={sig.ta_rating}\n"
                    f"   Entry={sig.entry_price} SL={sig.stop_loss} TP={sig.take_profit} lot={sig.lot}\n"
                )
            msg += "\n"
        else:
            msg += "_Aucun signal ALIGNED ce cycle_\n\n"

        if report.orders_placed:
            msg += f"*Ordres placés:* {', '.join(report.orders_placed)}\n"
        if report.orders_failed:
            msg += f"*Ordres échoués:* {', '.join(report.orders_failed)}\n"
        if report.ea_missing:
            msg += f"*EA manquant:* {', '.join(report.ea_missing)} — ouvrir graphique MT5\n"
        if report.monitor_launched:
            msg += f"*Monitor 20min:* {', '.join(report.monitor_launched)}\n"

        msg += f"\n_Durée pipeline: {report.elapsed_sec:.0f}s_"
        self._send_whatsapp(msg)

    def _print_terminal_summary(self, report: PipelineReport, fused: List[FusedSignal]):
        sep = "─" * 60
        print(f"\n{sep}")
        print(f"  PIPELINE AUTONOME — {report.run_at}")
        print(sep)
        print(f"  Candidats  : {', '.join(report.top_n_candidates)}")
        print(f"  TA succès  : {report.ta_success}/{report.ta_success + report.ta_failed}")
        print(f"  ALIGNED    : {report.aligned_count}")
        print(f"  Ordres OK  : {report.orders_placed}")
        print(f"  Ordres KO  : {report.orders_failed}")
        print(f"  EA ready   : {report.ea_ready}")
        print(f"  EA missing : {report.ea_missing}")
        print(f"  Monitor    : {report.monitor_launched}")
        print(f"  Durée      : {report.elapsed_sec:.1f}s")
        print(sep)
        print()

        print(f"  {'SYMBOLE':<10} {'DIR':<5} {'VERDICT':<10} {'TV':>5} {'TA':<5} {'ENTRY':>10} {'SL':>10} {'TP':>10} {'LOT':>6}")
        print(f"  {'-'*9} {'-'*4} {'-'*9} {'-'*5} {'-'*4} {'-'*10} {'-'*10} {'-'*10} {'-'*6}")
        for sig in fused:
            icon = "✅" if sig.verdict == "ALIGNED" else "⚡" if sig.verdict == "CONFLICT" else "❌"
            print(f"  {sig.symbol:<10} {sig.direction:<5} {icon}{sig.verdict:<9} "
                  f"{sig.tv_score:>5.1f} {sig.ta_rating:<5} "
                  f"{str(sig.entry_price or 'N/A'):>10} "
                  f"{str(sig.stop_loss or 'N/A'):>10} "
                  f"{str(sig.take_profit or 'N/A'):>10} "
                  f"{sig.lot:>6.2f}")
        print()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="TradBOT Autonomous Pipeline")
    parser.add_argument("--top-n",    type=int,   default=5,   help="Nombre de symboles top à analyser")
    parser.add_argument("--capital",  type=float, default=50,  help="Capital compte ($)")
    parser.add_argument("--risk",     type=float, default=0.02,help="Risque par trade (ex: 0.02 = 2%%)")
    parser.add_argument("--dry-run",  action="store_true",     help="Simulation — pas d'ordres réels")
    parser.add_argument("--skip-ta",  action="store_true",     help="⚠️ DÉCONSEILLÉ: Skip TradingAgents (pas de entry/SL/TP précis)")
    parser.add_argument("--ta-timeout", type=int, default=600, help="Timeout TradingAgents par symbole (sec) — défaut 600s pour analyses complètes")
    parser.add_argument("--min-score",  type=float, default=5.0, help="Score TV minimum pour ALIGNED")
    args = parser.parse_args()

    cfg = PipelineConfig(
        top_n            = args.top_n,
        capital          = args.capital,
        risk_pct         = args.risk,
        dry_run          = args.dry_run,
        skip_ta          = args.skip_ta,
        ta_timeout_sec   = args.ta_timeout,
        min_tv_score     = args.min_score,
        max_concurrent_ta= min(3, args.top_n),
    )

    pipeline = AutonomousPipeline(cfg)
    try:
        pipeline.run()
    except KeyboardInterrupt:
        log.info("Pipeline interrompu par l'utilisateur")
        sys.exit(0)
    except Exception as e:
        log.error("Pipeline échoué: %s", e, exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
