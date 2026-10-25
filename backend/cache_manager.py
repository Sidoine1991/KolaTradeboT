import streamlit as st
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
import hashlib
import json

class CacheManager:
    """Gestionnaire de cache intelligent pour optimiser les performances"""
    
    def __init__(self):
        self.cache_ttl = {
            'mt5_data': 300,      # 5 minutes pour les données MT5
            'indicators': 60,     # 1 minute pour les indicateurs
            'analysis': 120,      # 2 minutes pour l'analyse
            'signals': 30         # 30 secondes pour les signaux
        }
    
    def generate_cache_key(self, prefix: str, **kwargs) -> str:
        """Génère une clé de cache unique"""
        key_data = f"{prefix}_{json.dumps(kwargs, sort_keys=True)}"
        return hashlib.md5(key_data.encode()).hexdigest()
    
    @st.cache_data(ttl=300)
    def get_cached_mt5_data(self, symbol: str, timeframe: str, count: int) -> Optional[pd.DataFrame]:
        """Cache les données MT5 avec TTL de 5 minutes"""
        from mt5_connector import get_ohlc
        try:
            return get_ohlc(symbol, timeframe, count)
        except Exception as e:
            st.error(f"Erreur lors de la récupération des données: {e}")
            return None
    
    @st.cache_data(ttl=60)
    def get_cached_indicators(self, df: pd.DataFrame, indicators: list) -> pd.DataFrame:
        """Cache les calculs d'indicateurs techniques"""
        from technical_analysis import add_technical_indicators
        try:
            return add_technical_indicators(df, indicators)
        except Exception as e:
            st.error(f"Erreur lors du calcul des indicateurs: {e}")
            return df
    
    @st.cache_data(ttl=120)
    def get_cached_analysis(self, df: pd.DataFrame, analysis_type: str) -> Dict[str, Any]:
        """Cache les analyses techniques"""
        from technical_analysis import get_trend_analysis, get_support_resistance_levels, get_volatility_analysis
        
        if analysis_type == 'trend':
            return get_trend_analysis(df)
        elif analysis_type == 'support_resistance':
            return get_support_resistance_levels(df)
        elif analysis_type == 'volatility':
            return get_volatility_analysis(df)
        else:
            return {}
    
    @st.cache_data(ttl=30)
    def get_cached_signals(self, df: pd.DataFrame, threshold: float) -> pd.DataFrame:
        """Cache les signaux de trading"""
        from signal_generator import generate_trading_signals
        try:
            signals = generate_trading_signals(df)
            return pd.DataFrame(signals) if signals else pd.DataFrame()
        except Exception as e:
            st.error(f"Erreur lors de la génération des signaux: {e}")
            return pd.DataFrame()
    
    def clear_cache(self, cache_type: str = None):
        """Efface le cache spécifique ou tout le cache"""
        if cache_type:
            st.cache_data.clear()
        else:
            st.cache_data.clear()
            st.cache_resource.clear()

# Instance globale du gestionnaire de cache
cache_manager = CacheManager() 