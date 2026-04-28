#!/usr/bin/env python3
"""
Script pour mettre à jour les niveaux de support/résistance réels dans Supabase
Basé sur l'analyse des données historiques du marché
"""

import os
import sys
import json
import requests
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
import MetaTrader5 as mt5
from supabase import create_client, Client

class SupportResistanceUpdater:
    def __init__(self):
        """Initialiser l'updater de niveaux S/R"""
        self.supabase_url = os.getenv("SUPABASE_URL", "https://your-project.supabase.co")
        self.supabase_key = os.getenv("SUPABASE_KEY", "your-supabase-key")
        
        # Connexion à Supabase
        self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
        
        # Symboles à analyser
        self.symbols = [
            "Boom 1000 Index",
            "Crash 1000 Index", 
            "Boom 300 Index",
            "Crash 300 Index",
            "Boom 500 Index",
            "Crash 500 Index"
        ]
        
        # Timeframes pour l'analyse
        self.timeframes = ["M1", "M5", "M15", "H1"]
        
        print("🔧 SupportResistanceUpdater initialisé")

    def connect_mt5(self) -> bool:
        """Connexion à MetaTrader 5"""
        try:
            if not mt5.initialize():
                print("❌ Échec initialisation MT5")
                return False
                
            print("✅ MT5 connecté")
            return True
        except Exception as e:
            print(f"❌ Erreur connexion MT5: {e}")
            return False

    def get_historical_data(self, symbol: str, timeframe: str, bars: int = 1000) -> Optional[pd.DataFrame]:
        """Récupérer les données historiques"""
        try:
            mt5_timeframe = getattr(mt5, f'TIMEFRAME_{timeframe}')
            rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, bars)
            
            if rates is None or len(rates) == 0:
                print(f"❌ Pas de données pour {symbol} {timeframe}")
                return None
                
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            return df
            
        except Exception as e:
            print(f"❌ Erreur récupération données {symbol} {timeframe}: {e}")
            return None

    def find_support_resistance_levels(self, df: pd.DataFrame, window: int = 20) -> Tuple[List[float], List[float]]:
        """
        Trouver les niveaux de support/résistance basés sur l'analyse des prix
        
        Args:
            df: DataFrame avec données OHLC
            window: Fenêtre pour l'analyse
            
        Returns:
            Tuple(List[supports], List[resistances])
        """
        supports = []
        resistances = []
        
        # Calculer les pivots points
        df['pivot_high'] = df['high'].rolling(window, center=True).max()
        df['pivot_low'] = df['low'].rolling(window, center=True).min()
        
        # Identifier les pivots significatifs
        for i in range(window, len(df) - window):
            # Support (pivot low)
            if df['low'].iloc[i] == df['pivot_low'].iloc[i]:
                support_level = df['low'].iloc[i]
                # Vérifier si c'est un niveau significatif (touché plusieurs fois)
                touches = self.count_level_touches(df, support_level, tolerance=0.001)
                if touches >= 2:  # Au moins 2 touches
                    supports.append(support_level)
                    
            # Résistance (pivot high)
            if df['high'].iloc[i] == df['pivot_high'].iloc[i]:
                resistance_level = df['high'].iloc[i]
                # Vérifier si c'est un niveau significatif
                touches = self.count_level_touches(df, resistance_level, tolerance=0.001)
                if touches >= 2:
                    resistances.append(resistance_level)
        
        # Nettoyer et regrouper les niveaux similaires
        supports = self.group_similar_levels(supports, tolerance=0.002)
        resistances = self.group_similar_levels(resistances, tolerance=0.002)
        
        return supports, resistances

    def count_level_touches(self, df: pd.DataFrame, level: float, tolerance: float = 0.001) -> int:
        """Compter combien de fois un niveau a été touché"""
        touches = 0
        for _, row in df.iterrows():
            if abs(row['low'] - level) <= level * tolerance or abs(row['high'] - level) <= level * tolerance:
                touches += 1
        return touches

    def group_similar_levels(self, levels: List[float], tolerance: float = 0.002) -> List[float]:
        """Regrouper les niveaux similaires"""
        if not levels:
            return []
            
        levels_sorted = sorted(levels)
        grouped = []
        
        current_group = [levels_sorted[0]]
        
        for level in levels_sorted[1:]:
            if abs(level - current_group[0]) <= current_group[0] * tolerance:
                current_group.append(level)
            else:
                # Moyenner le groupe et ajouter aux résultats
                avg_level = np.mean(current_group)
                grouped.append(avg_level)
                current_group = [level]
        
        # Ajouter le dernier groupe
        if current_group:
            avg_level = np.mean(current_group)
            grouped.append(avg_level)
            
        return grouped

    def calculate_strength_score(self, df: pd.DataFrame, level: float, level_type: str) -> float:
        """
        Calculer un score de force pour un niveau S/R
        
        Args:
            df: DataFrame avec données historiques
            level: Niveau à évaluer
            level_type: 'support' ou 'resistance'
            
        Returns:
            Score de 0-100
        """
        score = 0.0
        
        # 1. Nombre de touches (max 40 points)
        touches = self.count_level_touches(df, level)
        score += min(touches * 5, 40)
        
        # 2. Âge du niveau (max 20 points) - niveaux plus récents = plus pertinents
        recent_touches = 0
        for i in range(min(50, len(df))):
            row = df.iloc[-(i+1)]
            if level_type == 'support' and abs(row['low'] - level) <= level * 0.001:
                recent_touches += 1
            elif level_type == 'resistance' and abs(row['high'] - level) <= level * 0.001:
                recent_touches += 1
        
        score += min(recent_touches * 4, 20)
        
        # 3. Volume moyen au niveau (max 25 points)
        volume_at_level = []
        for _, row in df.iterrows():
            if level_type == 'support' and abs(row['low'] - level) <= level * 0.001:
                volume_at_level.append(row['tick_volume'])
            elif level_type == 'resistance' and abs(row['high'] - level) <= level * 0.001:
                volume_at_level.append(row['tick_volume'])
        
        if volume_at_level:
            avg_volume = np.mean(volume_at_level)
            max_volume = df['tick_volume'].max()
            score += (avg_volume / max_volume) * 25
        
        # 4. Distance par rapport au prix actuel (max 15 points)
        current_price = df['close'].iloc[-1]
        distance_pct = abs(current_price - level) / level
        if distance_pct < 0.005:  # Moins de 0.5%
            score += 15
        elif distance_pct < 0.01:  # Moins de 1%
            score += 10
        elif distance_pct < 0.02:  # Moins de 2%
            score += 5
        
        return min(score, 100)

    def update_supabase_levels(self, symbol: str, timeframe: str, supports: List[float], resistances: List[float], df: pd.DataFrame):
        """Mettre à jour les niveaux dans Supabase"""
        try:
            # Supprimer les anciens niveaux pour ce symbole/timeframe
            self.supabase.table("support_resistance_levels").delete().eq("symbol", symbol).eq("timeframe", timeframe).execute()
            
            # Insérer les nouveaux niveaux
            for i, (support, resistance) in enumerate(zip(supports, resistances)):
                # Calculer les scores de force
                support_score = self.calculate_strength_score(df, support, 'support')
                resistance_score = self.calculate_strength_score(df, resistance, 'resistance')
                avg_score = (support_score + resistance_score) / 2
                
                # Compter les touches
                support_touches = self.count_level_touches(df, support)
                resistance_touches = self.count_level_touches(df, resistance)
                avg_touches = (support_touches + resistance_touches) // 2
                
                level_data = {
                    "symbol": symbol,
                    "support": support,
                    "resistance": resistance,
                    "timeframe": timeframe,
                    "strength_score": avg_score,
                    "touch_count": avg_touches,
                    "last_touch": datetime.now().isoformat()
                }
                
                result = self.supabase.table("support_resistance_levels").insert(level_data).execute()
                
                if result.data:
                    print(f"✅ Niveau S/R inséré: {symbol} S:{support:.5f} R:{resistance:.5f} Score:{avg_score:.1f}")
                else:
                    print(f"❌ Erreur insertion niveau: {result}")
                    
        except Exception as e:
            print(f"❌ Erreur mise à jour Supabase {symbol} {timeframe}: {e}")

    def analyze_symbol(self, symbol: str):
        """Analyser un symbole sur tous les timeframes"""
        print(f"\n📊 Analyse de {symbol}")
        
        for timeframe in self.timeframes:
            print(f"  🕐 Analyse {timeframe}...")
            
            # Récupérer les données
            df = self.get_historical_data(symbol, timeframe, bars=1000)
            if df is None:
                continue
                
            # Trouver les niveaux S/R
            supports, resistances = self.find_support_resistance_levels(df)
            
            if supports and resistances:
                # Prendre les 3 meilleurs niveaux
                supports = supports[:3]
                resistances = resistances[:3]
                
                # Mettre à jour Supabase
                self.update_supabase_levels(symbol, timeframe, supports, resistances, df)
                
                print(f"    ✅ {len(supports)} supports et {len(resistances)} résistances trouvés")
            else:
                print(f"    ⚠️ Pas de niveaux S/R significatifs trouvés")

    def run_analysis(self):
        """Lancer l'analyse complète"""
        print("🚀 Début de l'analyse des niveaux S/R")
        
        if not self.connect_mt5():
            return
            
        try:
            for symbol in self.symbols:
                if mt5.symbol_select(symbol, True):
                    self.analyze_symbol(symbol)
                else:
                    print(f"❌ Symbole {symbol} non disponible")
                    
        except Exception as e:
            print(f"❌ Erreur durant l'analyse: {e}")
        finally:
            mt5.shutdown()
            
        print("✅ Analyse terminée")

if __name__ == "__main__":
    updater = SupportResistanceUpdater()
    updater.run_analysis()
