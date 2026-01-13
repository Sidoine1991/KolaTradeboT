#!/usr/bin/env python3
"""
Module de collecte des statistiques pour le dashboard
Récupère les stats des modèles ML, trading, et décisions en temps réel
"""

import os
import sys
import json
import pandas as pd
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from collections import defaultdict
import warnings
warnings.filterwarnings('ignore')

# Chemin du dossier MT5 Predictions
MT5_PREDICTIONS_DIR = Path(
    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\Common\Files\Predictions"
)

class DashboardStats:
    """Collecte toutes les statistiques pour le dashboard"""
    
    def __init__(self):
        self.predictions_dir = MT5_PREDICTIONS_DIR
    
    def get_model_performance_stats(self) -> Dict:
        """Statistiques de performance des modèles ML par catégorie"""
        stats = {}
        
        if not self.predictions_dir.exists():
            return {"error": "Dossier Predictions non trouvé"}
        
        # Parcourir tous les fichiers CSV
        all_predictions = []
        for csv_file in self.predictions_dir.glob("*_predictions.csv"):
            try:
                df = pd.read_csv(csv_file, sep=";", parse_dates=["time"])
                all_predictions.append(df)
            except:
                continue
        
        if not all_predictions:
            return {"error": "Aucune prédiction trouvée"}
        
        combined = pd.concat(all_predictions, ignore_index=True)
        
        # Stats par modèle
        if "model_name" in combined.columns:
            for model_name in combined["model_name"].unique():
                if pd.isna(model_name) or model_name == "":
                    continue
                
                model_df = combined[combined["model_name"] == model_name]
                
                # Actions
                actions = model_df["action"].value_counts().to_dict()
                
                # Confiance moyenne
                avg_conf = float(model_df["confidence"].mean()) if "confidence" in model_df.columns else 0.0
                
                # Dernière utilisation
                last_use = model_df["time"].max().isoformat() if "time" in model_df.columns else None
                
                stats[model_name] = {
                    "total_predictions": len(model_df),
                    "actions": actions,
                    "buy_count": actions.get("buy", 0),
                    "sell_count": actions.get("sell", 0),
                    "hold_count": actions.get("hold", 0),
                    "avg_confidence": avg_conf,
                    "last_used": last_use
                }
        
        # Stats par catégorie
        category_stats = {}
        if "category" in combined.columns:
            for category in combined["category"].unique():
                if pd.isna(category) or category == "":
                    continue
                
                cat_df = combined[combined["category"] == category]
                category_stats[category] = {
                    "total": len(cat_df),
                    "avg_confidence": float(cat_df["confidence"].mean()) if "confidence" in cat_df.columns else 0.0,
                    "buy_pct": (cat_df["action"] == "buy").sum() / len(cat_df) * 100,
                    "sell_pct": (cat_df["action"] == "sell").sum() / len(cat_df) * 100,
                    "hold_pct": (cat_df["action"] == "hold").sum() / len(cat_df) * 100
                }
        
        return {
            "models": stats,
            "categories": category_stats,
            "total_predictions": len(combined),
            "date_range": {
                "start": combined["time"].min().isoformat() if "time" in combined.columns else None,
                "end": combined["time"].max().isoformat() if "time" in combined.columns else None
            }
        }
    
    def get_trading_stats(self) -> Dict:
        """Statistiques de trading (winners/losers) depuis les prédictions"""
        stats = {
            "total_trades": 0,
            "buy_trades": 0,
            "sell_trades": 0,
            "hold_decisions": 0,
            "avg_confidence": 0.0,
            "high_confidence_trades": 0,  # >= 70%
            "medium_confidence_trades": 0,  # 50-70%
            "low_confidence_trades": 0,  # < 50%
            "by_category": {},
            "by_style": {},
            "recent_decisions": [],
            "confidence_distribution": {},
            "action_distribution": {},
            "hourly_activity": {},
            "daily_activity": {}
        }
        
        if not self.predictions_dir.exists():
            return stats
        
        all_predictions = []
        for csv_file in self.predictions_dir.glob("*_predictions.csv"):
            try:
                df = pd.read_csv(csv_file, sep=";", parse_dates=["time"])
                all_predictions.append(df)
            except:
                continue
        
        if not all_predictions:
            return stats
        
        combined = pd.concat(all_predictions, ignore_index=True)
        
        # Filtrer seulement les trades (exclure HOLD)
        trades = combined[combined["action"].isin(["buy", "sell"])]
        
        stats["total_trades"] = len(trades)
        stats["buy_trades"] = (trades["action"] == "buy").sum()
        stats["sell_trades"] = (trades["action"] == "sell").sum()
        stats["hold_decisions"] = (combined["action"] == "hold").sum()
        
        if len(trades) > 0:
            stats["avg_confidence"] = float(trades["confidence"].mean())
            stats["high_confidence_trades"] = (trades["confidence"] >= 0.70).sum()
            stats["medium_confidence_trades"] = ((trades["confidence"] >= 0.50) & (trades["confidence"] < 0.70)).sum()
            stats["low_confidence_trades"] = (trades["confidence"] < 0.50).sum()
        
        # Par catégorie
        if "category" in trades.columns:
            for category in trades["category"].unique():
                if pd.isna(category) or category == "":
                    continue
                cat_trades = trades[trades["category"] == category]
                stats["by_category"][category] = {
                    "count": len(cat_trades),
                    "buy": (cat_trades["action"] == "buy").sum(),
                    "sell": (cat_trades["action"] == "sell").sum(),
                    "avg_confidence": float(cat_trades["confidence"].mean()) if len(cat_trades) > 0 else 0.0
                }
        
        # Par style
        if "style" in trades.columns:
            for style in trades["style"].unique():
                if pd.isna(style) or style == "":
                    continue
                style_trades = trades[trades["style"] == style]
                stats["by_style"][style] = {
                    "count": len(style_trades),
                    "avg_confidence": float(style_trades["confidence"].mean()) if len(style_trades) > 0 else 0.0
                }
        
        # Distribution de confiance
        if len(trades) > 0 and "confidence" in trades.columns:
            conf_bins = [0, 0.3, 0.5, 0.7, 0.9, 1.0]
            conf_labels = ["0-30%", "30-50%", "50-70%", "70-90%", "90-100%"]
            stats["confidence_distribution"] = {
                label: int(((trades["confidence"] >= conf_bins[i]) & (trades["confidence"] < conf_bins[i+1])).sum())
                for i, label in enumerate(conf_labels[:-1])
            }
            stats["confidence_distribution"]["90-100%"] = int((trades["confidence"] >= 0.9).sum())
        
        # Distribution des actions
        if "action" in combined.columns:
            stats["action_distribution"] = combined["action"].value_counts().to_dict()
        
        # Activité horaire (dernières 24h)
        if "time" in combined.columns:
            combined["hour"] = pd.to_datetime(combined["time"]).dt.hour
            stats["hourly_activity"] = combined.groupby("hour").size().to_dict()
            
            # Activité quotidienne (7 derniers jours)
            combined["date"] = pd.to_datetime(combined["time"]).dt.date
            last_7_days = combined[combined["date"] >= (datetime.now().date() - timedelta(days=7))]
            if len(last_7_days) > 0:
                stats["daily_activity"] = {
                    str(date): int(count) 
                    for date, count in last_7_days.groupby("date").size().items()
                }
        
        # Dernières décisions (10 plus récentes)
        if len(combined) > 0:
            recent = combined.nlargest(10, "time") if "time" in combined.columns else combined.tail(10)
            # Sélectionner les colonnes disponibles
            available_cols = ["time", "symbol", "action", "confidence", "style", "category", "model_name"]
            cols_to_use = [col for col in available_cols if col in recent.columns]
            recent_dict = recent[cols_to_use].copy()
            
            if "time" in recent_dict.columns:
                recent_dict["time"] = recent_dict["time"].dt.strftime('%Y-%m-%d %H:%M:%S')
            
            # Si category est vide, essayer de la déduire depuis le symbole
            if "category" in recent_dict.columns:
                for idx in recent_dict.index:
                    if pd.isna(recent_dict.loc[idx, "category"]) or recent_dict.loc[idx, "category"] == "":
                        symbol = recent_dict.loc[idx, "symbol"]
                        # Déduire la catégorie depuis le symbole
                        if isinstance(symbol, str):
                            symbol_upper = symbol.upper()
                            if "BOOM" in symbol_upper or "CRASH" in symbol_upper:
                                recent_dict.loc[idx, "category"] = "BOOM_CRASH"
                            elif "VOLATILITY" in symbol_upper or "STEP" in symbol_upper or "JUMP" in symbol_upper:
                                recent_dict.loc[idx, "category"] = "VOLATILITY"
                            elif any(pair in symbol_upper for pair in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF']):
                                if 'INDEX' not in symbol_upper:
                                    recent_dict.loc[idx, "category"] = "FOREX"
                            elif any(metal in symbol_upper for metal in ['XAU', 'XAG', 'OIL', 'GAS']):
                                recent_dict.loc[idx, "category"] = "COMMODITIES"
            
            stats["recent_decisions"] = recent_dict.to_dict("records")
        
        return stats
    
    def get_robot_performance_stats(self) -> Dict:
        """Statistiques de performance globale du robot"""
        stats = {
            "total_decisions": 0,
            "active_symbols": set(),
            "decisions_today": 0,
            "decisions_last_hour": 0,
            "most_traded_symbols": {},
            "decision_distribution": {},
            "confidence_trend": {}
        }
        
        if not self.predictions_dir.exists():
            return stats
        
        all_predictions = []
        for csv_file in self.predictions_dir.glob("*_predictions.csv"):
            try:
                df = pd.read_csv(csv_file, sep=";", parse_dates=["time"])
                all_predictions.append(df)
            except:
                continue
        
        if not all_predictions:
            return stats
        
        combined = pd.concat(all_predictions, ignore_index=True)
        
        stats["total_decisions"] = len(combined)
        
        if "symbol" in combined.columns:
            stats["active_symbols"] = list(combined["symbol"].unique())
            symbol_counts = combined["symbol"].value_counts()
            stats["most_traded_symbols"] = symbol_counts.head(10).to_dict()
        
        # Décisions aujourd'hui
        if "time" in combined.columns:
            today = datetime.now().date()
            today_df = combined[pd.to_datetime(combined["time"]).dt.date == today]
            stats["decisions_today"] = len(today_df)
            
            # Dernière heure
            one_hour_ago = datetime.now() - timedelta(hours=1)
            recent_df = combined[pd.to_datetime(combined["time"]) >= one_hour_ago]
            stats["decisions_last_hour"] = len(recent_df)
        
        # Distribution des décisions
        if "action" in combined.columns:
            stats["decision_distribution"] = combined["action"].value_counts().to_dict()
        
        # Tendance de confiance (moyenne par jour)
        if "time" in combined.columns and "confidence" in combined.columns:
            combined["date"] = pd.to_datetime(combined["time"]).dt.date
            daily_conf = combined.groupby("date")["confidence"].mean()
            stats["confidence_trend"] = {
                date.isoformat(): float(conf) 
                for date, conf in daily_conf.items()
            }
        
        return stats
    
    def get_all_stats(self) -> Dict:
        """Récupère toutes les statistiques"""
        return {
            "timestamp": datetime.now().isoformat(),
            "model_performance": self.get_model_performance_stats(),
            "trading_stats": self.get_trading_stats(),
            "robot_performance": self.get_robot_performance_stats()
        }

