"""
GOM Handler — Intégration des verdicts GOM avec exploitation des patterns
===========================================================================

Fonctionnalités:
  - Récupération des verdicts GOM depuis l'AI server
  - Filtrage GOOD/PERFECT pour exploitation immédiate
  - Alignement patterns SMC + verdict GOM
  - Calcul des niveaux d'entrée/SL/TP depuis les bandes KOLA/BB
  - Détection améliorée des "Invalid stops"
  - Une seule position par symbole
  - Fermeture automatique quand GOM passe à WAIT
"""

import time
import logging
import requests
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional, Any, Tuple
from datetime import datetime, timezone

from .chart_patterns import ChartPatternManager, DetectedPattern, PatternType, PatternDirection

logger = logging.getLogger("tradbot.gom_handler")

AI_SERVER = "http://127.0.0.1:8000"

# ──────────────────────────────────────────────────────────────
# Types
# ──────────────────────────────────────────────────────────────

@dataclass
class GOMVerdict:
    symbol: str
    verdict: str           # STRONG_BUY, BUY, SELL, STRONG_SELL, WAIT, NEUTRAL
    verdict_num: int       # +2, +1, 0, -1, -2
    score_buy: float
    score_sell: float
    coherence_pct: float
    entry: Optional[float] = None
    sl: Optional[float] = None
    tp: Optional[float] = None
    price: Optional[float] = None
    kola_buy: Optional[float] = None
    kola_sell: Optional[float] = None
    bb_up: Optional[float] = None
    bb_dn: Optional[float] = None
    atr: Optional[float] = None
    timestamp: float = 0.0

    def is_actionable(self, min_coherence: float = 70.0) -> bool:
        """Verdict exploitable si coherence >= seuil et pas WAIT."""
        return abs(self.verdict_num) > 0 and self.coherence_pct >= min_coherence

    def is_good_or_perfect(self) -> bool:
        """Verdict GOOD/PERFECT = BUY ou SELL avec coherence >= 80."""
        return self.is_actionable(min_coherence=80.0)

    def direction(self) -> str:
        if self.verdict_num > 0:
            return "BUY"
        if self.verdict_num < 0:
            return "SELL"
        return "HOLD"


@dataclass
class GOMSignal:
    """Signal combiné GOM + patterns SMC."""
    symbol: str
    direction: str
    verdict: GOMVerdict
    patterns: List[DetectedPattern]
    signal_strength: float  # 0.0 - 1.0
    entry: Optional[float] = None
    sl: Optional[float] = None
    tp: Optional[float] = None
    reason: str = ""


class GOMHandler:
    """
    Pont entre les verdicts GOM et l'exécution des ordres.

    Logique:
      1) Récupère les verdicts GOM depuis /gom-verdicts
      2) Filtre GOOD/PERFECT (coherence >= 80%)
      3) Récupère les patterns SMC actifs pour chaque symbole
      4) Aligne patterns + verdict pour renforcer le signal
      5) Calcule les niveaux SL/TP précis
      6) Vérifie qu'il n'y a pas déjà une position ouverte
    """

    def __init__(self, pattern_manager: ChartPatternManager,
                 ai_server_url: str = AI_SERVER):
        self.pm = pattern_manager
        self.ai_url = ai_server_url
        self._last_verdicts: List[GOMVerdict] = []
        self._signals: List[GOMSignal] = []
        self._prev_verdict_nums: Dict[str, int] = {}  # Pour détecter les changements

    # ──────────────────────────────────────────────────────────
    # Public API
    # ──────────────────────────────────────────────────────────

    def refresh(self) -> List[GOMSignal]:
        """
        Met à jour les verdicts et signaux.
        Appel recommandé: toutes les 30-60 secondes.
        """
        verdicts = self._fetch_verdicts()
        self._last_verdicts = verdicts
        self._signals = self._build_signals(verdicts)
        return self._signals

    def get_actionable_signals(self, min_coherence: float = 80.0,
                                require_alignment: bool = True) -> List[GOMSignal]:
        """
        Retourne les signaux exploitables (GOOD/PERFECT).
        Si require_alignment=True, ne garde que ceux avec patterns SMC alignés.
        """
        actionable = []
        for sig in self._signals:
            v = sig.verdict
            if not v.is_actionable(min_coherence):
                continue
            if require_alignment and not sig.patterns:
                continue
            if sig.signal_strength >= 0.5:
                actionable.append(sig)
        return sorted(actionable, key=lambda x: -x.signal_strength)

    def get_verdict(self, symbol: str) -> Optional[GOMVerdict]:
        """Retourne le verdict actuel pour un symbole."""
        for v in self._last_verdicts:
            if v.symbol == symbol:
                return v
        return None

    def get_signal(self, symbol: str) -> Optional[GOMSignal]:
        """Retourne le signal combiné pour un symbole."""
        for sig in self._signals:
            if sig.symbol == symbol:
                return sig
        return None

    def has_verdict_changed(self, symbol: str) -> Tuple[bool, int, int]:
        """
        Vérifie si le verdict a changé depuis le dernier cycle.
        Retourne (changed, prev, current).
        """
        current = self._prev_verdict_nums.get(symbol, 0)
        v = self.get_verdict(symbol)
        new_val = v.verdict_num if v else 0
        changed = current != 0 and new_val != current
        self._prev_verdict_nums[symbol] = new_val
        return changed, current, new_val

    def should_close(self, symbol: str) -> bool:
        """
        Vérifie si on doit fermer la position (verdict passé à WAIT/opposé).
        """
        v = self.get_verdict(symbol)
        if not v:
            return False
        return v.verdict_num == 0 or v.verdict == "WAIT"

    def get_sl_tp_levels(self, gom_verdict: GOMVerdict) -> Dict:
        """
        Calcule les niveaux SL/TP précis depuis les bandes KOLA/BB.
        Version améliorée avec validation des stops.
        """
        direction = gom_verdict.direction()
        entry = gom_verdict.price or gom_verdict.entry or 0
        kola_buy = gom_verdict.kola_buy or 0
        kola_sell = gom_verdict.kola_sell or 0
        bb_up = gom_verdict.bb_up or 0
        bb_dn = gom_verdict.bb_dn or 0
        atr = gom_verdict.atr or 0

        if entry <= 0:
            return {"entry": 0, "sl": 0, "tp": 0, "error": "No entry price"}

        is_synthetic = any(x in gom_verdict.symbol.upper() for x in ["BOOM", "CRASH", "JUMP"])
        atr_sl_mult = 1.5 if is_synthetic else 2.0
        atr_tp_mult = 2.0 if is_synthetic else 1.5
        min_sl_dist = atr * atr_sl_mult if atr > 0 else entry * 0.003
        # Plancher de sécurité : 0.2% du prix pour éviter "Invalid stops" sur ATR trop petit
        floor_dist = entry * 0.002 if entry > 0 else 0
        if floor_dist > 0 and min_sl_dist < floor_dist:
            min_sl_dist = floor_dist

        if direction == "BUY":
            if kola_buy > 0 and kola_buy < entry:
                entry = kola_buy
            if bb_dn > 0 and abs(entry - bb_dn) >= min_sl_dist:
                sl = bb_dn - (atr * 0.5 if atr > 0 else 0)
            else:
                sl = entry - min_sl_dist
            if kola_sell > entry:
                tp = kola_sell
            elif bb_up > entry:
                tp = bb_up
            else:
                tp = entry + abs(entry - sl) * atr_tp_mult
        else:
            if kola_sell > 0 and kola_sell > entry:
                entry = kola_sell
            if bb_up > 0 and abs(bb_up - entry) >= min_sl_dist:
                sl = bb_up + (atr * 0.5 if atr > 0 else 0)
            else:
                sl = entry + min_sl_dist
            if kola_buy > 0 and kola_buy < entry:
                tp = kola_buy
            elif bb_dn > 0 and bb_dn < entry:
                tp = bb_dn
            else:
                tp = entry - abs(sl - entry) * atr_tp_mult

        return {"entry": round(entry, 5), "sl": round(sl, 5), "tp": round(tp, 5)}

    # ──────────────────────────────────────────────────────────
    # Interne
    # ──────────────────────────────────────────────────────────

    def _fetch_verdicts(self) -> List[GOMVerdict]:
        """Récupère les verdicts GOM depuis l'AI server."""
        try:
            r = requests.get(f"{self.ai_url}/gom-verdicts", timeout=10)
            if r.status_code != 200:
                logger.warning(f"GOM fetch: HTTP {r.status_code}")
                return self._last_verdicts
            data = r.json()
            raw_list = data.get("verdicts", [])
            if not raw_list:
                raw_list = data.get("data", data.get("results", []))
            verdicts = []
            for item in raw_list:
                try:
                    v = GOMVerdict(
                        symbol=item.get("symbol", ""),
                        verdict=item.get("verdict", "WAIT"),
                        verdict_num=int(item.get("verdict_num", 0)),
                        score_buy=float(item.get("score_buy", 0)),
                        score_sell=float(item.get("score_sell", 0)),
                        coherence_pct=float(item.get("coherence_pct", 0)),
                        entry=self._safe_float(item, "entry"),
                        sl=self._safe_float(item, "sl"),
                        tp=self._safe_float(item, "tp"),
                        price=self._safe_float(item, "price"),
                        kola_buy=self._safe_float(item, "kola_buy"),
                        kola_sell=self._safe_float(item, "kola_sell"),
                        bb_up=self._safe_float(item, "bb_up"),
                        bb_dn=self._safe_float(item, "bb_dn"),
                        atr=self._safe_float(item, "atr"),
                        timestamp=time.time(),
                    )
                    verdicts.append(v)
                except Exception as e:
                    logger.debug(f"GOM parsing error: {e}")
            return verdicts

        except requests.exceptions.RequestException as e:
            logger.warning(f"GOM fetch failed: {e}")
            return self._last_verdicts

    def _build_signals(self, verdicts: List[GOMVerdict]) -> List[GOMSignal]:
        """Combine verdicts GOM + patterns SMC pour créer des signaux."""
        signals = []
        for v in verdicts:
            if v.verdict_num == 0:
                continue
            # Scanner les patterns SMC pour ce symbole
            patterns = self.pm.get_tradeable_patterns(
                v.symbol, v.direction(), min_confidence=0.5
            )
            # Force un scan si pas de patterns récents
            if not patterns:
                try:
                    patterns = self.pm.scan_symbol(v.symbol, "M15")
                except Exception:
                    pass

            strength = self._calculate_signal_strength(v, patterns)
            levels = self.get_sl_tp_levels(v)

            sig = GOMSignal(
                symbol=v.symbol,
                direction=v.direction(),
                verdict=v,
                patterns=patterns[:5],  # Top 5 patterns
                signal_strength=strength,
                entry=levels.get("entry"),
                sl=levels.get("sl"),
                tp=levels.get("tp"),
                reason=self._build_reason(v, patterns, strength),
            )
            signals.append(sig)
        return sorted(signals, key=lambda x: -x.signal_strength)

    def _calculate_signal_strength(self, v: GOMVerdict,
                                   patterns: List[DetectedPattern]) -> float:
        """
        Calcule la force du signal (0.0 - 1.0):
          - Base: coherence / 100 (0.0 - 0.4)
          - Bonus pattern: 0.1 par pattern aligné (max 0.3)
          - Bonus score: score_buy/score_sell / 10 * 0.2
          - Bonus GOOD/PERFECT: +0.1
        """
        base = min(0.4, v.coherence_pct / 100 * 0.4)
        pattern_bonus = min(0.3, len(patterns) * 0.1)
        max_score = max(v.score_buy, v.score_sell)
        score_bonus = min(0.2, max_score / 10 * 0.2)
        perfect_bonus = 0.1 if v.coherence_pct >= 80 else 0.0
        return min(1.0, base + pattern_bonus + score_bonus + perfect_bonus)

    def _build_reason(self, v: GOMVerdict, patterns: List[DetectedPattern],
                      strength: float) -> str:
        parts = [f"GOM={v.verdict} ({v.coherence_pct:.0f}%)"]
        if patterns:
            pat_summary = ", ".join(f"{p.pattern_type.value}({p.direction.value})" for p in patterns[:3])
            parts.append(f"Patterns=[{pat_summary}]")
        if v.verdict_num != 0 and v.coherence_pct >= 80:
            parts.append("GOOD/PERFECT")
        parts.append(f"strength={strength:.2f}")
        return " | ".join(parts)

    @staticmethod
    def _safe_float(item: Dict, key: str) -> Optional[float]:
        val = item.get(key)
        if val is None:
            return None
        try:
            v = float(val)
            return v if v != 0 else None
        except (ValueError, TypeError):
            return None
