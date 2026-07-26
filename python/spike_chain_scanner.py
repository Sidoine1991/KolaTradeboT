#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SpikeChainScanner — Détection temps réel de chaînes de spikes multi-symboles.

Analyse les bougies M1 uploadées par l'EA via /mt5/upload-candles :
1. Détecte les spikes (body > ATR * threshold)
2. Compte les spikes consécutifs par symbole dans une fenêtre de temps
3. Valide le verdict GOM (GOOD / PERFECT requis)
4. Vérifie l'état de correction du prix (pullback vs impulsif)
5. Stocke les alertes + push WebSocket pour notification EA

Intégré dans ai_server.py comme store global + endpoints.
"""

import logging
import time
import asyncio
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Any, Deque
from collections import deque

logger = logging.getLogger("spike_chain_scanner")

# ── Configuration ───────────────────────────────────────────────────
SPIKE_BODY_ATR_MULT = 2.0       # body > ATR(14) * 2.0 = spike
CHAIN_WINDOW_SEC = 180           # 3 minutes max pour chaîne
CHAIN_MIN_LENGTH = 2             # 2+ spikes consécutifs = chaîne
ALERT_TTL_SEC = 300              # alerte expire après 5 min
ATR_PERIOD = 14                  # période ATR
ATR_WARMUP = 20                  # bougies min pour calculer ATR


@dataclass
class SpikeEvent:
    """Un spike détecté sur une bougie M1."""
    symbol: str
    direction: str          # "UP" ou "DOWN"
    price: float            # prix de clôture
    open_price: float
    close_price: float
    body: float             # |close - open|
    atr: float
    body_atr_ratio: float   # body / ATR
    timestamp: float        # epoch seconds
    candle_index: int = 0   # index dans le DataFrame


@dataclass
class ChainAlert:
    """Alerte chaîne de spikes détectée."""
    symbol: str
    direction: str                  # direction dominante de la chaîne
    chain_length: int               # nombre de spikes dans la chaîne
    spike_times: List[float]        # timestamps des spikes
    avg_body_atr: float             # body/ATR moyen
    last_price: float               # dernier prix
    gom_verdict: str = "UNKNOWN"    # verdict GOM au moment du scan
    gom_verdict_num: int = 0        # verdict_num (GOOD=±2, PERFECT=±3)
    gom_ok: bool = False            # True si verdict GOOD/PERFECT
    price_pullback_pct: float = 0.0 # % de pullback depuis dernier spike
    correction_state: str = "impulsif"  # "impulsif", "pullback", "reversal"
    alert_id: str = ""
    timestamp: str = ""
    active: bool = True
    notified_to_ea: bool = False


class SpikeChainScanner:
    """
    Scanner multi-symboles de chaînes de spikes.
    Stocké comme singleton dans ai_server.py.
    """

    def __init__(self):
        # Par symbole : deque de (epoch, open, close, body, atr)
        self._candle_history: Dict[str, Deque] = {}
        # Dernier spike détecté par symbole
        self._last_spike: Dict[str, SpikeEvent] = {}
        # Chaîne en cours par symbole
        self._active_chain: Dict[str, List[SpikeEvent]] = {}
        # Alertes actives (non lues par EA)
        self._alerts: Dict[str, ChainAlert] = {}
        # Verdicts GOM (référence vers _GOM_VERDICT_STORE du serveur)
        self._gom_store: Optional[Dict] = None
        # Lock pour les alertes
        self._lock = asyncio.Lock()
        # Stats
        self._scan_count = 0
        self._spike_count = 0
        self._chain_count = 0

    def set_gom_store(self, store: Dict):
        """Lie le store GOM verdicts du serveur."""
        self._gom_store = store

    def process_candles(self, symbol: str, candles: List[Dict]) -> List[ChainAlert]:
        """
        Traite des bougies M1 pour un symbole.
        Appelé depuis /mt5/upload-candles.
        Retourne les alertes générées (vide si pas de chaîne).
        """
        if not candles:
            return []

        sym = symbol.upper().strip()
        if sym not in self._candle_history:
            self._candle_history[sym] = deque(maxlen=500)

        alerts = []
        for candle in candles:
            ts = candle.get("time", 0)
            o = float(candle.get("open", 0))
            h = float(candle.get("high", 0))
            l = float(candle.get("low", 0))
            c = float(candle.get("close", 0))
            v = float(candle.get("volume", 0))

            body = abs(c - o)
            self._candle_history[sym].append({
                "time": ts, "open": o, "high": h, "low": l,
                "close": c, "volume": v, "body": body,
            })

        # Calculer ATR et scanner les nouvelles bougies
        history = list(self._candle_history[sym])
        if len(history) < ATR_WARMUP:
            return []

        # ATR(14) sur tout l'historique
        atr = self._compute_atr(history)
        if atr <= 0:
            return []

        # Scanner les dernières bougies (max 5 dernières pour perf)
        scan_start = max(0, len(history) - 5)
        for i in range(scan_start, len(history)):
            bar = history[i]
            body = bar["body"]
            ratio = body / atr if atr > 0 else 0

            if ratio >= SPIKE_BODY_ATR_MULT:
                direction = "UP" if bar["close"] > bar["open"] else "DOWN"
                spike = SpikeEvent(
                    symbol=sym,
                    direction=direction,
                    price=bar["close"],
                    open_price=bar["open"],
                    close_price=bar["close"],
                    body=body,
                    atr=atr,
                    body_atr_ratio=ratio,
                    timestamp=bar["time"],
                    candle_index=i,
                )
                self._spike_count += 1
                alert = self._register_spike(sym, spike)
                if alert:
                    alerts.append(alert)

        return alerts

    def _compute_atr(self, bars: List[Dict]) -> float:
        """Calcule l'ATR(14) sur l'historique des bougies."""
        if len(bars) < ATR_PERIOD + 1:
            return 0.0

        true_ranges = []
        for i in range(1, len(bars)):
            h = bars[i]["high"]
            l = bars[i]["low"]
            prev_c = bars[i - 1]["close"]
            tr = max(h - l, abs(h - prev_c), abs(l - prev_c))
            true_ranges.append(tr)

        # Wilder smoothing (EMA avec period = ATR_PERIOD)
        if len(true_ranges) < ATR_PERIOD:
            return sum(true_ranges) / max(len(true_ranges), 1)

        atr = sum(true_ranges[:ATR_PERIOD]) / ATR_PERIOD
        for tr in true_ranges[ATR_PERIOD:]:
            atr = (atr * (ATR_PERIOD - 1) + tr) / ATR_PERIOD
        return atr

    def _register_spike(self, sym: str, spike: SpikeEvent) -> Optional[ChainAlert]:
        """
        Enregistre un spike et vérifie si une chaîne est formée.
        Retourne une ChainAlert si conditions remplies, sinon None.
        """
        now = spike.timestamp
        chain = self._active_chain.get(sym, [])

        # Nettoyer les spikes trop anciens (hors fenêtre)
        cutoff = now - CHAIN_WINDOW_SEC
        chain = [s for s in chain if s.timestamp >= cutoff]

        # Vérifier direction cohérente
        if chain and chain[-1].direction != spike.direction:
            # Changement de direction → reset chaîne
            chain = []

        chain.append(spike)
        self._active_chain[sym] = chain

        # Mise à jour dernier spike
        self._last_spike[sym] = spike

        # Vérifier longueur chaîne
        if len(chain) >= CHAIN_MIN_LENGTH:
            return self._build_chain_alert(sym, chain)

        return None

    def _build_chain_alert(self, sym: str, chain: List[SpikeEvent]) -> ChainAlert:
        """Construit une alerte chaîne depuis la chaîne active."""
        direction = chain[-1].direction
        avg_ratio = sum(s.body_atr_ratio for s in chain) / len(chain)
        last_price = chain[-1].price
        first_price = chain[0].price

        # Pullback: écart entre premier spike et prix actuel
        price_range = last_price - first_price if first_price != 0 else 0
        pullback_pct = abs(price_range / first_price * 100) if first_price != 0 else 0.0

        # État de correction
        if len(chain) >= 3:
            # 3+ spikes consécutifs = fort momentum
            correction_state = "impulsif"
        elif pullback_pct > 0.5:
            correction_state = "pullback"
        else:
            correction_state = "impulsif"

        # Vérifier GOM verdict
        gom_verdict = "UNKNOWN"
        gom_verdict_num = 0
        gom_ok = False
        if self._gom_store:
            gom_data = self._gom_store.get(sym, {})
            if gom_data:
                gom_verdict = gom_data.get("verdict", "UNKNOWN")
                gom_verdict_num = gom_data.get("verdict_num", 0)
                gom_ok = abs(gom_verdict_num) >= 2  # GOOD=2, PERFECT=3

        alert_id = f"{sym}_{direction}_{int(time.time())}_{len(chain)}"
        alert = ChainAlert(
            symbol=sym,
            direction=direction,
            chain_length=len(chain),
            spike_times=[s.timestamp for s in chain],
            avg_body_atr=round(avg_ratio, 2),
            last_price=last_price,
            gom_verdict=gom_verdict,
            gom_verdict_num=gom_verdict_num,
            gom_ok=gom_ok,
            price_pullback_pct=round(pullback_pct, 4),
            correction_state=correction_state,
            alert_id=alert_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
            active=True,
        )

        self._chain_count += 1
        logger.info(
            f"[SPIKE-CHAIN] 🔗 Chaîne {len(chain)}x {direction} sur {sym} | "
            f"GOM={gom_verdict}({gom_verdict_num}) OK={gom_ok} | "
            f"Body/ATR={avg_ratio:.1f} | Pullback={pullback_pct:.3f}%"
        )

        # Stocker l'alerte (anciennement écrasée)
        self._alerts[alert_id] = alert
        return alert

    async def get_active_alerts(self, symbol: str = None) -> List[Dict]:
        """Retourne les alertes actives (non notifiées ou récentes)."""
        async with self._lock:
            now_iso = datetime.now(timezone.utc)
            result = []
            expired = []

            for aid, alert in self._alerts.items():
                if not alert.active:
                    continue
                # Vérifier TTL
                try:
                    alert_time = datetime.fromisoformat(alert.timestamp.replace("Z", "+00:00"))
                    age = (now_iso - alert_time).total_seconds()
                except Exception:
                    age = 0

                if age > ALERT_TTL_SEC:
                    expired.append(aid)
                    continue

                if symbol and alert.symbol != symbol.upper():
                    continue

                result.append({
                    "alert_id": alert.alert_id,
                    "symbol": alert.symbol,
                    "direction": alert.direction,
                    "chain_length": alert.chain_length,
                    "spike_count": alert.chain_length,
                    "gom_verdict": alert.gom_verdict,
                    "gom_verdict_num": alert.gom_verdict_num,
                    "gom_ok": alert.gom_ok,
                    "last_price": alert.last_price,
                    "price_pullback_pct": alert.price_pullback_pct,
                    "correction_state": alert.correction_state,
                    "avg_body_atr": alert.avg_body_atr,
                    "timestamp": alert.timestamp,
                    "notified": alert.notified_to_ea,
                })

            # Nettoyer les expirées
            for aid in expired:
                del self._alerts[aid]

            return result

    async def acknowledge_alert(self, alert_id: str) -> bool:
        """Marque une alerte comme notifiée à l'EA."""
        async with self._lock:
            alert = self._alerts.get(alert_id)
            if alert:
                alert.notified_to_ea = True
                alert.active = False
                logger.info(f"[SPIKE-CHAIN] Alerte {alert_id} acquittée par EA")
                return True
            return False

    def get_spike_history(self, symbol: str, limit: int = 50) -> List[Dict]:
        """Retourne les spikes détectés récemment pour un symbole."""
        sym = symbol.upper().strip()
        history = self._candle_history.get(sym, deque())
        spikes = []
        atr = self._compute_atr(list(history))

        for bar in list(history)[-limit:]:
            body = bar["body"]
            ratio = body / atr if atr > 0 else 0
            if ratio >= SPIKE_BODY_ATR_MULT:
                spikes.append({
                    "time": bar["time"],
                    "direction": "UP" if bar["close"] > bar["open"] else "DOWN",
                    "price": bar["close"],
                    "body": round(body, 6),
                    "atr": round(atr, 6),
                    "body_atr_ratio": round(ratio, 2),
                })
        return spikes

    def get_stats(self) -> Dict:
        """Retourne les stats du scanner."""
        return {
            "scan_count": self._scan_count,
            "spike_count": self._spike_count,
            "chain_count": self._chain_count,
            "active_chains": len(self._active_chain),
            "active_alerts": sum(1 for a in self._alerts.values() if a.active),
            "symbols_tracked": list(self._candle_history.keys()),
            "last_spike": {
                sym: {
                    "direction": sp.direction,
                    "price": sp.price,
                    "timestamp": sp.timestamp,
                    "body_atr_ratio": round(sp.body_atr_ratio, 2),
                }
                for sym, sp in self._last_spike.items()
            },
        }

    def force_scan(self, symbol: str) -> Optional[Dict]:
        """
        Force un scan immédiat d'un symbole avec les données en cache.
        Utilisé par /spike-chain/scan.
        """
        self._scan_count += 1
        sym = symbol.upper().strip()
        history = list(self._candle_history.get(sym, deque()))
        if len(history) < ATR_WARMUP:
            return None

        atr = self._compute_atr(history)
        if atr <= 0:
            return None

        # Scanner les 5 dernières bougies
        chain = self._active_chain.get(sym, [])
        now = time.time()
        cutoff = now - CHAIN_WINDOW_SEC
        chain = [s for s in chain if s.timestamp >= cutoff]

        new_spikes = []
        for bar in history[-5:]:
            body = bar["body"]
            ratio = body / atr if atr > 0 else 0
            if ratio >= SPIKE_BODY_ATR_MULT:
                direction = "UP" if bar["close"] > bar["open"] else "DOWN"
                spike = SpikeEvent(
                    symbol=sym,
                    direction=direction,
                    price=bar["close"],
                    open_price=bar["open"],
                    close_price=bar["close"],
                    body=body,
                    atr=atr,
                    body_atr_ratio=ratio,
                    timestamp=bar["time"],
                )
                new_spikes.append(spike)

        # Retourne l'état actuel
        return {
            "symbol": sym,
            "atr": round(atr, 6),
            "total_bars": len(history),
            "new_spikes": len(new_spikes),
            "active_chain_length": len(chain),
            "spikes": [
                {"direction": s.direction, "ratio": round(s.body_atr_ratio, 2), "price": s.price}
                for s in new_spikes
            ],
        }
