"""
Système d'apprentissage adaptatif pour TradBOT
- Tracking des trades (gagné/perdu + montants)
- Ajustement automatique des stratégies par symbole
- Apprentissage continu des erreurs et réussites
"""

import json
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
import statistics

@dataclass
class TradeResult:
    """Résultat d'un trade"""
    symbol: str
    direction: str  # BUY/SELL
    profit: float  # En USD
    confidence: float = 0.0  # Confiance IA au moment de l'ouverture
    setup_score: float = 0.0  # Score setup au moment de l'ouverture
    gom_verdict: str = "UNKNOWN"  # WAIT/GOOD/PERFECT
    ticket: int = 0
    open_time: Optional[datetime] = None
    close_time: Optional[datetime] = None
    open_price: float = 0.0
    close_price: float = 0.0

    @property
    def is_win(self) -> bool:
        return self.profit > 0

    @property
    def duration_minutes(self) -> float:
        return (self.close_time - self.open_time).total_seconds() / 60


class AdaptiveLearningSystem:
    """Système d'apprentissage adaptatif par symbole"""

    def __init__(self, db_path: str = "D:/Dev/TradBOT/data/adaptive_learning.db"):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_database()

    def _init_database(self):
        """Initialiser la base de données SQLite"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        # Table des trades
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS trades (
                ticket INTEGER PRIMARY KEY,
                symbol TEXT NOT NULL,
                direction TEXT NOT NULL,
                open_time TEXT NOT NULL,
                close_time TEXT NOT NULL,
                open_price REAL NOT NULL,
                close_price REAL NOT NULL,
                profit REAL NOT NULL,
                confidence REAL NOT NULL,
                setup_score REAL NOT NULL,
                gom_verdict TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        # Table des stratégies adaptatives par symbole
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS adaptive_strategies (
                symbol TEXT PRIMARY KEY,
                min_confidence REAL DEFAULT 0.75,
                min_setup_score REAL DEFAULT 80.0,
                min_gom_score REAL DEFAULT 0.45,
                trailing_stop_pct REAL DEFAULT 20.0,
                max_positions INTEGER DEFAULT 2,
                win_rate REAL DEFAULT 0.0,
                avg_profit REAL DEFAULT 0.0,
                avg_loss REAL DEFAULT 0.0,
                total_trades INTEGER DEFAULT 0,
                last_updated TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        # Table de l'historique des ajustements
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS strategy_adjustments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                symbol TEXT NOT NULL,
                parameter TEXT NOT NULL,
                old_value REAL NOT NULL,
                new_value REAL NOT NULL,
                reason TEXT NOT NULL,
                timestamp TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        conn.commit()
        conn.close()

    def record_trade(self, trade: TradeResult):
        """Enregistrer un trade et mettre à jour la stratégie"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        # Gérer les valeurs optionnelles
        open_time_str = trade.open_time.isoformat() if trade.open_time else datetime.now().isoformat()
        close_time_str = trade.close_time.isoformat() if trade.close_time else datetime.now().isoformat()

        # Insérer le trade
        cursor.execute("""
            INSERT OR REPLACE INTO trades
            (ticket, symbol, direction, open_time, close_time, open_price, close_price,
             profit, confidence, setup_score, gom_verdict)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            trade.ticket,
            trade.symbol,
            trade.direction,
            open_time_str,
            close_time_str,
            trade.open_price,
            trade.close_price,
            trade.profit,
            trade.confidence,
            trade.setup_score,
            trade.gom_verdict
        ))

        conn.commit()
        conn.close()

        # Mettre à jour la stratégie adaptative
        self._update_strategy(trade.symbol)

        print(f"[OK] Trade enregistre: {trade.symbol} {trade.direction} "
              f"{'WIN' if trade.is_win else 'LOSS'} {trade.profit:+.2f}$")

    def _update_strategy(self, symbol: str):
        """Mettre à jour la stratégie adaptative pour un symbole"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        # Récupérer les 50 derniers trades du symbole
        cursor.execute("""
            SELECT profit, confidence, setup_score, gom_verdict
            FROM trades
            WHERE symbol = ?
            ORDER BY close_time DESC
            LIMIT 50
        """, (symbol,))

        trades = cursor.fetchall()

        if not trades:
            conn.close()
            return

        # Calculer statistiques
        profits = [t[0] for t in trades]
        confidences = [t[1] for t in trades]
        setup_scores = [t[2] for t in trades]

        wins = [p for p in profits if p > 0]
        losses = [p for p in profits if p < 0]

        win_rate = len(wins) / len(trades) if trades else 0
        avg_profit = statistics.mean(wins) if wins else 0
        avg_loss = abs(statistics.mean(losses)) if losses else 0

        # Récupérer stratégie actuelle
        cursor.execute("""
            SELECT min_confidence, min_setup_score, min_gom_score, trailing_stop_pct
            FROM adaptive_strategies
            WHERE symbol = ?
        """, (symbol,))

        current_strategy = cursor.fetchone()

        if current_strategy:
            old_confidence, old_setup, old_gom, old_trailing = current_strategy
        else:
            old_confidence, old_setup, old_gom, old_trailing = (0.75, 80.0, 0.45, 20.0)

        # LOGIQUE D'ADAPTATION AUTOMATIQUE
        new_confidence = old_confidence
        new_setup = old_setup
        new_gom = old_gom
        new_trailing = old_trailing

        # Règle 1: Si win rate < 70% -> Augmenter seuils (plus strict)
        if win_rate < 0.70:
            new_confidence = min(0.90, old_confidence + 0.02)
            new_setup = min(90.0, old_setup + 2.0)
            new_gom = min(0.60, old_gom + 0.02)
            reason = f"Win rate faible ({win_rate*100:.1f}%) -> Filtres plus stricts"
            self._log_adjustment(symbol, "min_confidence", old_confidence, new_confidence, reason)
            self._log_adjustment(symbol, "min_setup_score", old_setup, new_setup, reason)
            self._log_adjustment(symbol, "min_gom_score", old_gom, new_gom, reason)

        # Règle 2: Si win rate > 85% -> Réduire seuils (plus de trades)
        elif win_rate > 0.85:
            new_confidence = max(0.65, old_confidence - 0.02)
            new_setup = max(70.0, old_setup - 2.0)
            new_gom = max(0.35, old_gom - 0.02)
            reason = f"Win rate élevé ({win_rate*100:.1f}%) -> Filtres assouplis"
            self._log_adjustment(symbol, "min_confidence", old_confidence, new_confidence, reason)
            self._log_adjustment(symbol, "min_setup_score", old_setup, new_setup, reason)
            self._log_adjustment(symbol, "min_gom_score", old_gom, new_gom, reason)

        # Règle 3: Si avg_loss > avg_profit -> Augmenter trailing stop
        if losses and wins and avg_loss > avg_profit:
            new_trailing = max(15.0, old_trailing - 2.0)
            reason = f"Pertes moyennes ({avg_loss:.2f}$) > gains ({avg_profit:.2f}$) -> Trailing stop serré"
            self._log_adjustment(symbol, "trailing_stop_pct", old_trailing, new_trailing, reason)

        # Règle 4: Si avg_profit > avg_loss * 1.5 -> Réduire trailing stop (laisser courir)
        elif wins and losses and avg_profit > avg_loss * 1.5:
            new_trailing = min(30.0, old_trailing + 2.0)
            reason = f"Gains moyens ({avg_profit:.2f}$) >> pertes ({avg_loss:.2f}$) -> Trailing stop large"
            self._log_adjustment(symbol, "trailing_stop_pct", old_trailing, new_trailing, reason)

        # Mettre à jour la stratégie
        cursor.execute("""
            INSERT OR REPLACE INTO adaptive_strategies
            (symbol, min_confidence, min_setup_score, min_gom_score, trailing_stop_pct,
             win_rate, avg_profit, avg_loss, total_trades, last_updated)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            symbol,
            new_confidence,
            new_setup,
            new_gom,
            new_trailing,
            win_rate,
            avg_profit,
            avg_loss,
            len(trades),
            datetime.now().isoformat()
        ))

        conn.commit()
        conn.close()

        print(f"[STRATEGIE] Adapte pour {symbol}:")
        print(f"   Win rate: {win_rate*100:.1f}% | Confidence: {new_confidence*100:.0f}% | "
              f"Setup: {new_setup:.0f} | Trailing: {new_trailing:.0f}%")

    def _log_adjustment(self, symbol: str, parameter: str, old_value: float,
                       new_value: float, reason: str):
        """Logger un ajustement de stratégie"""
        if abs(new_value - old_value) < 0.001:
            return  # Pas de changement significatif

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO strategy_adjustments (symbol, parameter, old_value, new_value, reason)
            VALUES (?, ?, ?, ?, ?)
        """, (symbol, parameter, old_value, new_value, reason))

        conn.commit()
        conn.close()

        print(f"[AJUSTEMENT] {symbol}: {parameter} {old_value:.2f} -> {new_value:.2f}")
        print(f"   Raison: {reason}")

    def get_strategy(self, symbol: str) -> Optional[Dict]:
        """Obtenir la stratégie adaptative pour un symbole"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            SELECT min_confidence, min_setup_score, min_gom_score, trailing_stop_pct,
                   win_rate, avg_profit, avg_loss, total_trades
            FROM adaptive_strategies
            WHERE symbol = ?
        """, (symbol,))

        row = cursor.fetchone()
        conn.close()

        if not row:
            return None

        return {
            "min_confidence": row[0],
            "min_setup_score": row[1],
            "min_gom_score": row[2],
            "trailing_stop_pct": row[3],
            "win_rate": row[4],
            "avg_profit": row[5],
            "avg_loss": row[6],
            "total_trades": row[7]
        }

    def get_all_strategies(self) -> Dict[str, Dict]:
        """Obtenir toutes les stratégies adaptatives"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            SELECT symbol, min_confidence, min_setup_score, min_gom_score, trailing_stop_pct,
                   win_rate, avg_profit, avg_loss, total_trades
            FROM adaptive_strategies
        """)

        rows = cursor.fetchall()
        conn.close()

        return {
            row[0]: {
                "min_confidence": row[1],
                "min_setup_score": row[2],
                "min_gom_score": row[3],
                "trailing_stop_pct": row[4],
                "win_rate": row[5],
                "avg_profit": row[6],
                "avg_loss": row[7],
                "total_trades": row[8]
            }
            for row in rows
        }

    def get_recent_adjustments(self, symbol: Optional[str] = None, limit: int = 20) -> List[Dict]:
        """Obtenir les ajustements récents"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        if symbol:
            cursor.execute("""
                SELECT symbol, parameter, old_value, new_value, reason, timestamp
                FROM strategy_adjustments
                WHERE symbol = ?
                ORDER BY timestamp DESC
                LIMIT ?
            """, (symbol, limit))
        else:
            cursor.execute("""
                SELECT symbol, parameter, old_value, new_value, reason, timestamp
                FROM strategy_adjustments
                ORDER BY timestamp DESC
                LIMIT ?
            """, (limit,))

        rows = cursor.fetchall()
        conn.close()

        return [
            {
                "symbol": row[0],
                "parameter": row[1],
                "old_value": row[2],
                "new_value": row[3],
                "reason": row[4],
                "timestamp": row[5]
            }
            for row in rows
        ]

    def get_performance_summary(self, days: int = 30) -> Dict:
        """Obtenir un résumé des performances"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        since = (datetime.now() - timedelta(days=days)).isoformat()

        cursor.execute("""
            SELECT
                symbol,
                COUNT(*) as total_trades,
                SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END) as wins,
                SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) as losses,
                SUM(profit) as net_profit,
                AVG(CASE WHEN profit > 0 THEN profit END) as avg_win,
                AVG(CASE WHEN profit < 0 THEN profit END) as avg_loss
            FROM trades
            WHERE close_time >= ?
            GROUP BY symbol
            ORDER BY net_profit DESC
        """, (since,))

        rows = cursor.fetchall()
        conn.close()

        return {
            row[0]: {
                "total_trades": row[1],
                "wins": row[2],
                "losses": row[3],
                "win_rate": row[2] / row[1] if row[1] > 0 else 0,
                "net_profit": row[4],
                "avg_win": row[5] or 0,
                "avg_loss": abs(row[6]) if row[6] else 0,
                "profit_factor": abs(row[5] / row[6]) if row[6] and row[5] else 0
            }
            for row in rows
        }


# Instance globale
learning_system = AdaptiveLearningSystem()


def test_system():
    """Test du système d'apprentissage"""
    print("=" * 60)
    print("TEST SYSTÈME D'APPRENTISSAGE ADAPTATIF")
    print("=" * 60)

    # Simuler quelques trades
    test_trades = [
        TradeResult(
            ticket=1001,
            symbol="Boom 1000 Index",
            direction="BUY",
            open_time=datetime.now() - timedelta(minutes=10),
            close_time=datetime.now() - timedelta(minutes=5),
            open_price=13000.0,
            close_price=13050.0,
            profit=0.85,
            confidence=0.78,
            setup_score=82.0,
            gom_verdict="GOOD_BUY"
        ),
        TradeResult(
            ticket=1002,
            symbol="Boom 1000 Index",
            direction="BUY",
            open_time=datetime.now() - timedelta(minutes=15),
            close_time=datetime.now() - timedelta(minutes=10),
            open_price=13010.0,
            close_price=12995.0,
            profit=-0.25,
            confidence=0.72,
            setup_score=75.0,
            gom_verdict="WAIT"
        ),
    ]

    for trade in test_trades:
        learning_system.record_trade(trade)

    # Afficher stratégie
    print("\n" + "=" * 60)
    strategy = learning_system.get_strategy("Boom 1000 Index")
    if strategy:
        print(f"\nStratégie adaptée pour Boom 1000 Index:")
        for key, value in strategy.items():
            print(f"  {key}: {value}")

    # Afficher ajustements
    print("\n" + "=" * 60)
    adjustments = learning_system.get_recent_adjustments(limit=5)
    if adjustments:
        print("\nDerniers ajustements:")
        for adj in adjustments:
            print(f"  {adj['symbol']}: {adj['parameter']} "
                  f"{adj['old_value']:.2f} -> {adj['new_value']:.2f}")
            print(f"    Raison: {adj['reason']}")

    print("\n" + "=" * 60)
    print("[OK] Test termine")


if __name__ == "__main__":
    test_system()
