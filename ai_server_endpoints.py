#!/usr/bin/env python3
"""
Nouveaux endpoints pour le serveur IA TradBOT
Métriques de performance et monitoring
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, List, Optional
from datetime import datetime, date
import logging

logger = logging.getLogger("tradbot_endpoints")

# Créer un router pour les nouveaux endpoints
router = APIRouter()

# ==================== MODÈLES PYDANTIC ====================

class TradeRecord(BaseModel):
    symbol: str
    action: str  # "buy" ou "sell"
    entry_price: float
    exit_price: float
    lot_size: float
    profit_loss: float
    timestamp: datetime

class DailyMetricsResponse(BaseModel):
    date: str
    total_trades: int
    wins: int
    losses: int
    profit: float
    loss: float
    net_profit: float
    win_rate: float
    avg_win: float
    avg_loss: float
    profit_factor: float
    risk_reward: float
    target_reached: bool  # Si objectif 50$ atteint

class SymbolPerformanceResponse(BaseModel):
    symbol: str
    total_trades: int
    wins: int
    losses: int
    net_profit: float
    win_rate: float
    avg_profit_per_trade: float

class StrategyPerformanceResponse(BaseModel):
    strategy: str
    total_trades: int
    wins: int
    losses: int
    net_profit: float
    win_rate: float
    avg_profit_per_trade: float


# ==================== ENDPOINTS MÉTRIQUES ====================

@router.post("/metrics/record_trade")
async def record_trade(trade: TradeRecord):
    """Enregistre un trade pour le suivi des performances"""
    try:
        from ai_server_improvements import performance_metrics
        
        performance_metrics.record_trade(
            symbol=trade.symbol,
            action=trade.action,
            entry_price=trade.entry_price,
            exit_price=trade.exit_price,
            lot_size=trade.lot_size,
            profit_loss=trade.profit_loss,
            timestamp=trade.timestamp
        )
        
        logger.info(f"Trade enregistré: {trade.symbol} {trade.action} P/L: {trade.profit_loss:.2f}$")
        
        return {
            "status": "success",
            "message": "Trade enregistré avec succès"
        }
    except Exception as e:
        logger.error(f"Erreur enregistrement trade: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/metrics/daily", response_model=DailyMetricsResponse)
async def get_daily_metrics(date_str: Optional[str] = None):
    """
    Récupère les métriques de performance journalières
    
    Args:
        date_str: Date au format YYYY-MM-DD (défaut: aujourd'hui)
    """
    try:
        from ai_server_improvements import performance_metrics
        
        # Parser la date
        if date_str:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        else:
            target_date = datetime.now().date()
            
        # Calculer les métriques
        metrics = performance_metrics.calculate_daily_metrics(target_date)
        
        # Vérifier si l'objectif de 50$ est atteint
        target_reached = metrics['net_profit'] >= 50.0
        
        return DailyMetricsResponse(
            date=target_date.isoformat(),
            total_trades=metrics['total_trades'],
            wins=metrics.get('wins', 0),
            losses=metrics.get('losses', 0),
            profit=metrics['profit'],
            loss=metrics['loss'],
            net_profit=metrics['net_profit'],
            win_rate=metrics['win_rate'],
            avg_win=metrics['avg_win'],
            avg_loss=metrics['avg_loss'],
            profit_factor=metrics['profit_factor'],
            risk_reward=metrics['risk_reward'],
            target_reached=target_reached
        )
    except Exception as e:
        logger.error(f"Erreur calcul métriques journalières: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/metrics/symbols")
async def get_symbols_performance():
    """Récupère la performance par symbole"""
    try:
        from ai_server_improvements import performance_metrics
        
        # Liste des symboles à analyser
        symbols = [
            "Volatility 75 Index",
            "Volatility 100 Index",
            "Boom 500 Index",
            "Boom 1000 Index",
            "Crash 500 Index",
            "Crash 1000 Index",
            "Step Index"
        ]
        
        results = []
        for symbol in symbols:
            perf = performance_metrics.calculate_symbol_performance(symbol)
            if perf['total_trades'] > 0:
                avg_profit = perf['net_profit'] / perf['total_trades']
                results.append(SymbolPerformanceResponse(
                    symbol=symbol,
                    total_trades=perf['total_trades'],
                    wins=perf['wins'],
                    losses=perf['losses'],
                    net_profit=perf['net_profit'],
                    win_rate=perf['win_rate'],
                    avg_profit_per_trade=avg_profit
                ))
        
        # Trier par profit net décroissant
        results.sort(key=lambda x: x.net_profit, reverse=True)
        
        return {
            "timestamp": datetime.now().isoformat(),
            "symbols": results,
            "best_performer": results[0].symbol if results else None,
            "worst_performer": results[-1].symbol if results else None
        }
    except Exception as e:
        logger.error(f"Erreur calcul performance symboles: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/metrics/strategies")
async def get_strategies_performance():
    """Récupère l'efficacité par stratégie"""
    try:
        from ai_server_improvements import performance_metrics
        
        # Analyser les trades par stratégie (basé sur les commentaires)
        strategies_stats = {
            'spike': {'trades': [], 'name': 'Détection Spikes'},
            'ema_cross': {'trades': [], 'name': 'Croisement EMA'},
            'fibonacci': {'trades': [], 'name': 'Rebond Fibonacci'},
            'vwap': {'trades': [], 'name': 'Stratégie VWAP'},
            'smc': {'trades': [], 'name': 'SMC Order Blocks'}
        }
        
        # Classifier les trades (simulation - à adapter selon vos données réelles)
        for trade in performance_metrics.trades_history:
            # Logique de classification basée sur les patterns
            if 'spike' in trade.get('comment', '').lower():
                strategies_stats['spike']['trades'].append(trade)
            elif 'ema' in trade.get('comment', '').lower():
                strategies_stats['ema_cross']['trades'].append(trade)
            elif 'fib' in trade.get('comment', '').lower():
                strategies_stats['fibonacci']['trades'].append(trade)
            elif 'vwap' in trade.get('comment', '').lower():
                strategies_stats['vwap']['trades'].append(trade)
            elif 'smc' in trade.get('comment', '').lower():
                strategies_stats['smc']['trades'].append(trade)
        
        results = []
        for strategy_key, strategy_data in strategies_stats.items():
            trades = strategy_data['trades']
            if trades:
                wins = [t for t in trades if t['profit_loss'] > 0]
                total_profit = sum(t['profit_loss'] for t in trades)
                win_rate = len(wins) / len(trades) * 100
                avg_profit = total_profit / len(trades)
                
                results.append(StrategyPerformanceResponse(
                    strategy=strategy_data['name'],
                    total_trades=len(trades),
                    wins=len(wins),
                    losses=len(trades) - len(wins),
                    net_profit=total_profit,
                    win_rate=win_rate,
                    avg_profit_per_trade=avg_profit
                ))
        
        # Trier par win rate décroissant
        results.sort(key=lambda x: x.win_rate, reverse=True)
        
        return {
            "timestamp": datetime.now().isoformat(),
            "strategies": results,
            "best_strategy": results[0].strategy if results else None,
            "recommendation": "Privilégier les stratégies avec win rate > 60%" if results else None
        }
    except Exception as e:
        logger.error(f"Erreur calcul performance stratégies: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/metrics/summary")
async def get_performance_summary():
    """Résumé global des performances"""
    try:
        from ai_server_improvements import performance_metrics
        
        # Métriques du jour
        today_metrics = performance_metrics.calculate_daily_metrics()
        
        # Calculer les métriques sur 7 jours
        week_trades = [
            t for t in performance_metrics.trades_history
            if (datetime.now().date() - t['date']).days <= 7
        ]
        
        week_profit = sum(t['profit_loss'] for t in week_trades)
        week_wins = len([t for t in week_trades if t['profit_loss'] > 0])
        week_win_rate = week_wins / len(week_trades) * 100 if week_trades else 0
        
        # Calculer le meilleur et pire jour
        daily_profits = {}
        for trade in performance_metrics.trades_history:
            date_key = trade['date'].isoformat()
            if date_key not in daily_profits:
                daily_profits[date_key] = 0
            daily_profits[date_key] += trade['profit_loss']
        
        best_day = max(daily_profits.items(), key=lambda x: x[1]) if daily_profits else (None, 0)
        worst_day = min(daily_profits.items(), key=lambda x: x[1]) if daily_profits else (None, 0)
        
        return {
            "timestamp": datetime.now().isoformat(),
            "today": {
                "net_profit": today_metrics['net_profit'],
                "trades": today_metrics['total_trades'],
                "win_rate": today_metrics['win_rate'],
                "target_progress": f"{today_metrics['net_profit']}/50.00$",
                "target_reached": today_metrics['net_profit'] >= 50.0
            },
            "week": {
                "net_profit": week_profit,
                "trades": len(week_trades),
                "win_rate": week_win_rate,
                "avg_daily_profit": week_profit / 7 if week_trades else 0
            },
            "records": {
                "best_day": {
                    "date": best_day[0],
                    "profit": best_day[1]
                },
                "worst_day": {
                    "date": worst_day[0],
                    "profit": worst_day[1]
                }
            },
            "status": "🎯 Objectif atteint!" if today_metrics['net_profit'] >= 50.0 else "📊 En cours..."
        }
    except Exception as e:
        logger.error(f"Erreur résumé performances: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/metrics/reset_daily")
async def reset_daily_metrics():
    """Réinitialise les métriques journalières (à appeler à minuit)"""
    try:
        from ai_server_improvements import performance_metrics
        
        # Archiver les trades du jour avant reset
        today = datetime.now().date()
        today_trades = [t for t in performance_metrics.trades_history if t['date'] == today]
        
        logger.info(f"Reset journalier: {len(today_trades)} trades archivés pour {today}")
        
        # Note: On ne supprime pas l'historique, juste un marqueur pour le nouveau jour
        return {
            "status": "success",
            "message": f"Métriques journalières prêtes pour {datetime.now().date()}",
            "archived_trades": len(today_trades)
        }
    except Exception as e:
        logger.error(f"Erreur reset métriques: {e}")
        raise HTTPException(status_code=500, detail=str(e))