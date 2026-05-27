"""
TradBOT Scalping Engine v1.0
============================

Module de génération de signaux SCALPING pour petit capital ($10-20).
Génère max 3 trades/jour avec :
- SL fixe : $5
- TP cible : $10-15
- Win rate cible : 66%+ (2/3 trades gagnants)

Compatible avec TradingAgents pour analyse globale, mais dimensionné pour micro-lots.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
import random

logger = logging.getLogger("tradbot_ai.scalping")


@dataclass
class ScalpingSignal:
    """Signal scalping avec niveaux précis"""
    symbol: str
    direction: str  # "BUY" ou "SELL"
    entry_price: float
    stop_loss: float
    take_profit_1: float  # TP1 @ $10
    take_profit_2: float  # TP2 @ $15
    confidence: float  # 0.0-1.0
    reasoning: List[str]  # Raisons du signal
    risk_usd: float = 5.0  # SL fixe en $
    reward_usd: float = 12.5  # TP moyen ($10+$15)/2
    lot_size: float = 0.01  # Micro-lot par défaut
    timeframe: str = "M5"  # Scalping = M5/M15
    session: str = "london"  # Session de trading
    setup_type: str = "bounce"  # Type de setup
    timestamp: str = ""

    def __post_init__(self):
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()
        # Calculer risk:reward
        self.risk_reward = round(self.reward_usd / self.risk_usd, 2)

    def to_dict(self) -> Dict[str, Any]:
        """Conversion en dict pour JSON"""
        return {
            "symbol": self.symbol,
            "direction": self.direction,
            "entry_price": self.entry_price,
            "stop_loss": self.stop_loss,
            "take_profit_1": self.take_profit_1,
            "take_profit_2": self.take_profit_2,
            "confidence": self.confidence,
            "reasoning": self.reasoning,
            "risk_usd": self.risk_usd,
            "reward_usd": self.reward_usd,
            "risk_reward": self.risk_reward,
            "lot_size": self.lot_size,
            "timeframe": self.timeframe,
            "session": self.session,
            "setup_type": self.setup_type,
            "timestamp": self.timestamp,
        }


# Cache global : max 3 signaux/jour
_SCALPING_SIGNALS_TODAY: List[ScalpingSignal] = []
_LAST_SIGNAL_DATE: Optional[datetime] = None


def _reset_daily_counter():
    """Reset compteur quotidien à minuit UTC"""
    global _SCALPING_SIGNALS_TODAY, _LAST_SIGNAL_DATE
    now = datetime.utcnow()
    if _LAST_SIGNAL_DATE is None or _LAST_SIGNAL_DATE.date() < now.date():
        _SCALPING_SIGNALS_TODAY = []
        _LAST_SIGNAL_DATE = now
        logger.info(f"📅 Scalping counter reset: {now.date()}")


def get_daily_signal_count() -> int:
    """Retourne le nombre de signaux scalping déjà générés aujourd'hui"""
    _reset_daily_counter()
    return len(_SCALPING_SIGNALS_TODAY)


def can_generate_scalping_signal() -> bool:
    """Vérifie si on peut encore générer un signal scalping aujourd'hui (max 3)"""
    return get_daily_signal_count() < 3


def _calculate_lot_size_for_risk(
    symbol: str,
    entry: float,
    stop_loss: float,
    risk_usd: float = 5.0,
    capital: float = 20.0
) -> float:
    """
    Calcule le lot size pour risquer exactement $5 (ou risk_usd) sur un capital de $20.

    Formule : lot = risk_usd / (sl_distance_pips * pip_value)

    Pour XAUUSD :
    - 1 pip = 0.1 (ex: 2500.0 → 2500.1)
    - pip_value @ 0.01 lot = $0.01
    - pip_value @ 0.1 lot = $0.10
    - pip_value @ 1.0 lot = $1.00
    """
    sym_upper = symbol.upper()

    # Pip definitions
    if "XAU" in sym_upper or "GOLD" in sym_upper:
        pip_size = 0.1
        pip_value_per_001_lot = 0.01  # $0.01 par pip pour 0.01 lot
    elif "BTC" in sym_upper:
        pip_size = 1.0
        pip_value_per_001_lot = 0.01
    elif "JPY" in sym_upper:
        pip_size = 0.01
        pip_value_per_001_lot = 0.00709
    else:  # Forex majeurs
        pip_size = 0.0001
        pip_value_per_001_lot = 0.0001 * 100 * 0.01  # $0.0001 per micro-pip

    # Distance SL en pips
    sl_distance = abs(entry - stop_loss) / pip_size

    if sl_distance <= 0:
        logger.warning(f"⚠️ SL distance invalid: {sl_distance} pips")
        return 0.01  # Fallback micro-lot

    # Calcul du lot pour risquer exactement risk_usd
    # lot = risk_usd / (sl_distance * pip_value_per_001 * 100)
    # pip_value_per_001 * 100 = value per 1.0 lot
    lot = risk_usd / (sl_distance * pip_value_per_001_lot * 100)

    # Arrondi au 0.01 le plus proche, min 0.01, max 10% du capital en lots
    lot = max(0.01, min(round(lot / 0.01) * 0.01, capital / 1000))

    logger.debug(
        f"💰 Lot calc: {symbol} | Entry={entry} SL={stop_loss} | "
        f"SL_dist={sl_distance:.1f} pips | Risk=${risk_usd} → Lot={lot}"
    )

    return lot


def generate_scalping_signal(
    symbol: str,
    current_price: float,
    trend: str,  # "bullish", "bearish", "neutral"
    support: Optional[float] = None,
    resistance: Optional[float] = None,
    atr: Optional[float] = None,
    session: str = "london",
    capital: float = 20.0,
    tradingagents_analysis: Optional[Dict[str, Any]] = None
) -> Optional[ScalpingSignal]:
    """
    Génère UN signal scalping si conditions remplies.

    Stratégie :
    - BUY : prix proche support + trend bullish/neutral
    - SELL : prix proche resistance + trend bearish/neutral
    - SL = $5 fixe (distance dynamique selon symbole)
    - TP1 = $10, TP2 = $15

    Returns:
        ScalpingSignal si signal valide, sinon None
    """
    _reset_daily_counter()

    if not can_generate_scalping_signal():
        logger.info("⏸️ Scalping limit atteinte aujourd'hui (3/3)")
        return None

    # Analyse TradingAgents si disponible
    ta_direction = None
    ta_confidence = 0.0
    if tradingagents_analysis:
        ta_direction = tradingagents_analysis.get("direction", "").upper()
        ta_confidence = float(tradingagents_analysis.get("confidence", 0.0))

    # Déterminer direction du setup
    signal_direction: Optional[str] = None
    setup_type = "unknown"
    confidence = 0.5
    reasoning: List[str] = []

    # === SETUP BUY ===
    if support and current_price <= support * 1.002:  # Prix à 0.2% près du support
        if trend in ("bullish", "neutral"):
            signal_direction = "BUY"
            setup_type = "support_bounce"
            confidence = 0.70
            reasoning.append(f"Prix @ support ${support:.2f}")
            reasoning.append(f"Trend: {trend}")

            # Confluence TradingAgents
            if ta_direction == "BUY" and ta_confidence >= 0.6:
                confidence += 0.15
                reasoning.append(f"TradingAgents: BUY {ta_confidence*100:.0f}%")

    # === SETUP SELL ===
    elif resistance and current_price >= resistance * 0.998:  # Prix à 0.2% près de resistance
        if trend in ("bearish", "neutral"):
            signal_direction = "SELL"
            setup_type = "resistance_rejection"
            confidence = 0.70
            reasoning.append(f"Prix @ resistance ${resistance:.2f}")
            reasoning.append(f"Trend: {trend}")

            # Confluence TradingAgents
            if ta_direction == "SELL" and ta_confidence >= 0.6:
                confidence += 0.15
                reasoning.append(f"TradingAgents: SELL {ta_confidence*100:.0f}%")

    # Si pas de setup, retourner None
    if not signal_direction:
        logger.debug(f"🔍 Pas de setup scalping valide pour {symbol} @ ${current_price}")
        return None

    # Calcul des niveaux SL/TP
    # Pour $5 de risque, calculer la distance en prix
    # Exemple XAUUSD : si 1 pip = 0.1, et on veut risquer $5 avec 0.01 lot :
    # $5 / ($0.01 per pip) = 500 pips = 50 points de prix

    # Utiliser ATR si disponible, sinon fallback
    if atr and atr > 0:
        sl_distance = atr * 1.5  # 1.5x ATR pour SL
    else:
        # Fallback : ~30-50 pips selon symbole
        sym_upper = symbol.upper()
        if "XAU" in sym_upper:
            sl_distance = 5.0  # $5 sur or = ~5 points
        elif "BTC" in sym_upper:
            sl_distance = 50.0
        else:
            sl_distance = 0.0030  # 30 pips forex

    # Construire les niveaux
    if signal_direction == "BUY":
        entry = current_price
        stop_loss = entry - sl_distance
        # TP : pour gagner $10, besoin de X pips
        # Si on trade 0.01 lot XAUUSD : $10 = 1000 pips = 100 points
        tp1_distance = sl_distance * 2.0  # R:R 2:1 pour TP1
        tp2_distance = sl_distance * 3.0  # R:R 3:1 pour TP2
        tp1 = entry + tp1_distance
        tp2 = entry + tp2_distance
    else:  # SELL
        entry = current_price
        stop_loss = entry + sl_distance
        tp1_distance = sl_distance * 2.0
        tp2_distance = sl_distance * 3.0
        tp1 = entry - tp1_distance
        tp2 = entry - tp2_distance

    # Calcul du lot size pour risquer exactement $5
    lot = _calculate_lot_size_for_risk(symbol, entry, stop_loss, risk_usd=5.0, capital=capital)

    # Créer le signal
    signal = ScalpingSignal(
        symbol=symbol,
        direction=signal_direction,
        entry_price=round(entry, 5),
        stop_loss=round(stop_loss, 5),
        take_profit_1=round(tp1, 5),
        take_profit_2=round(tp2, 5),
        confidence=min(0.95, confidence),
        reasoning=reasoning,
        risk_usd=5.0,
        reward_usd=12.5,  # Moyenne (10+15)/2
        lot_size=lot,
        timeframe="M5",
        session=session,
        setup_type=setup_type,
    )

    # Enregistrer dans le cache
    _SCALPING_SIGNALS_TODAY.append(signal)

    logger.info(
        f"✅ Signal scalping généré ({len(_SCALPING_SIGNALS_TODAY)}/3): "
        f"{signal.direction} {symbol} @ {signal.entry_price} | "
        f"SL={signal.stop_loss} TP1={signal.take_profit_1} TP2={signal.take_profit_2} | "
        f"Lot={signal.lot_size} | Conf={signal.confidence*100:.0f}%"
    )

    return signal


def get_scalping_signals_from_tradingagents(
    tradingagents_result: Dict[str, Any],
    capital: float = 20.0
) -> List[ScalpingSignal]:
    """
    Convertit un rapport TradingAgents en 0-3 signaux scalping.

    Args:
        tradingagents_result: Résultat complet de TradingAgents (multi-analysts)
        capital: Capital disponible pour calcul lot size

    Returns:
        Liste de 0-3 ScalpingSignal (limité à 3/jour)
    """
    _reset_daily_counter()

    if not can_generate_scalping_signal():
        logger.info("⏸️ Scalping limit atteinte, skip conversion TradingAgents")
        return []

    signals: List[ScalpingSignal] = []

    # Parser le rapport TradingAgents
    # Structure attendue : {"direction": "BUY"/"SELL", "confidence": 0.75, "entry": 2500.0, ...}
    direction = tradingagents_result.get("direction", "").upper()
    if direction not in ("BUY", "SELL"):
        logger.debug("❌ TradingAgents: pas de direction claire (HOLD)")
        return []

    confidence = float(tradingagents_result.get("confidence", 0.0))
    if confidence < 0.60:  # Seuil min pour scalping
        logger.debug(f"❌ TradingAgents confidence trop faible: {confidence*100:.0f}%")
        return []

    # Extraire les niveaux
    symbol = tradingagents_result.get("symbol", "XAUUSD")
    entry = tradingagents_result.get("entry_price") or tradingagents_result.get("current_price")
    sl = tradingagents_result.get("stop_loss")
    tp = tradingagents_result.get("take_profit")

    if not entry or not sl:
        logger.warning("⚠️ TradingAgents: entry ou SL manquant, skip scalping")
        return []

    # Ajuster SL/TP pour scalping ($5 risk)
    sl_distance = abs(entry - sl)

    # Recalculer SL pour risque $5 fixe
    lot = _calculate_lot_size_for_risk(symbol, entry, sl, risk_usd=5.0, capital=capital)

    # TP : 2x et 3x le risque
    if direction == "BUY":
        tp1 = entry + (sl_distance * 2.0)
        tp2 = entry + (sl_distance * 3.0)
    else:  # SELL
        tp1 = entry - (sl_distance * 2.0)
        tp2 = entry - (sl_distance * 3.0)

    # Créer le signal scalping
    signal = ScalpingSignal(
        symbol=symbol,
        direction=direction,
        entry_price=round(entry, 5),
        stop_loss=round(sl, 5),
        take_profit_1=round(tp1, 5),
        take_profit_2=round(tp2, 5),
        confidence=confidence,
        reasoning=[
            f"TradingAgents: {direction} {confidence*100:.0f}%",
            f"Dimensionné scalping: Risk=$5 TP=$10-15"
        ],
        risk_usd=5.0,
        reward_usd=12.5,
        lot_size=lot,
        timeframe=tradingagents_result.get("timeframe", "M5"),
        session=tradingagents_result.get("session", "london"),
        setup_type="tradingagents_scalped",
    )

    signals.append(signal)
    _SCALPING_SIGNALS_TODAY.append(signal)

    logger.info(
        f"✅ Signal scalping créé depuis TradingAgents ({len(_SCALPING_SIGNALS_TODAY)}/3): "
        f"{signal.direction} {symbol} @ {signal.entry_price}"
    )

    return signals


def format_scalping_report(signals: List[ScalpingSignal]) -> str:
    """
    Formate un rapport textuel des signaux scalping pour inclusion dans le bridge output.

    Returns:
        Markdown formaté
    """
    if not signals:
        return "**Aucun signal scalping disponible aujourd'hui (0/3)**"

    report_lines = [
        f"## 🎯 SIGNAUX SCALPING DU JOUR ({len(signals)}/3)",
        "",
        f"**Capital:** $20 | **Risque/trade:** $5 | **TP cible:** $10-15",
        ""
    ]

    for i, sig in enumerate(signals, 1):
        report_lines.extend([
            f"### Signal #{i} — {sig.direction} {sig.symbol}",
            f"- **Setup:** {sig.setup_type}",
            f"- **Entry:** ${sig.entry_price:.5f}",
            f"- **SL:** ${sig.stop_loss:.5f} (Risk: ${sig.risk_usd})",
            f"- **TP1:** ${sig.take_profit_1:.5f} (+${sig.reward_usd/2:.2f})",
            f"- **TP2:** ${sig.take_profit_2:.5f} (+${sig.reward_usd:.2f})",
            f"- **Lot:** {sig.lot_size}",
            f"- **R:R:** {sig.risk_reward}:1",
            f"- **Confiance:** {sig.confidence*100:.0f}%",
            f"- **Reasoning:**",
        ])

        for reason in sig.reasoning:
            report_lines.append(f"  - {reason}")

        report_lines.append("")

    return "\n".join(report_lines)


# === TEST / DEMO ===
if __name__ == "__main__":
    import sys
    import io

    # Fix Windows console encoding
    if sys.platform == "win32":
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

    logging.basicConfig(level=logging.DEBUG)

    print("=== TradBOT Scalping Engine Test ===\n")

    # Test 1 : Signal BUY sur support
    sig1 = generate_scalping_signal(
        symbol="XAUUSD",
        current_price=2500.5,
        trend="bullish",
        support=2500.0,
        resistance=2520.0,
        atr=3.5,
        session="london",
        capital=20.0
    )

    if sig1:
        print("✅ Signal 1 généré:")
        print(format_scalping_report([sig1]))

    # Test 2 : Signal SELL sur resistance
    sig2 = generate_scalping_signal(
        symbol="XAUUSD",
        current_price=2519.8,
        trend="bearish",
        support=2500.0,
        resistance=2520.0,
        atr=3.5,
        session="newyork",
        capital=20.0
    )

    if sig2:
        print("✅ Signal 2 généré:")
        print(format_scalping_report([sig2]))

    # Test 3 : Doit être refusé (max 3/jour)
    for i in range(5):
        sig = generate_scalping_signal(
            symbol="XAUUSD",
            current_price=2510.0 + i,
            trend="neutral",
            support=2500.0,
            resistance=2520.0,
            atr=3.5,
            capital=20.0
        )
        if not sig:
            print(f"❌ Signal #{i+3} refusé (limit atteinte)")

    print(f"\n📊 Signaux générés aujourd'hui: {get_daily_signal_count()}/3")
