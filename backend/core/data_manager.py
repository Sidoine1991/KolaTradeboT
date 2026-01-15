"""
Gestionnaire de données pour l'application de trading
"""
import pandas as pd
import MetaTrader5 as mt5
import numpy as np
from datetime import datetime, timedelta
import time
import logging
from typing import Optional, Dict, List, Union

# Configuration du logger
logger = logging.getLogger(__name__)

class DataManager:
    """Gestionnaire de données pour la récupération et le traitement des données de marché"""
    
    def __init__(self):
        """Initialise le gestionnaire de données"""
        self.connected = False
        self.initialize_mt5()
    
    def initialize_mt5(self) -> bool:
        """Initialise la connexion à MT5"""
        try:
            if not mt5.initialize():
                logger.error("Échec de l'initialisation de MT5")
                self.connected = False
                return False
                
            self.connected = True
            logger.info("Connexion à MT5 établie avec succès")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de l'initialisation de MT5: {e}")
            self.connected = False
            return False
    
    def get_historical_data(
        self, 
        symbol: str, 
        timeframe: str, 
        count: int = 1000,
        from_date: Optional[datetime] = None,
        to_date: Optional[datetime] = None
    ) -> pd.DataFrame:
        """
        Récupère les données historiques pour un symbole et une période donnés
        
        Args:
            symbol: Symbole (ex: 'EURUSD')
            timeframe: Période (ex: 'M5', 'H1', 'D1')
            count: Nombre de bougies à récupérer
            from_date: Date de début
            to_date: Date de fin
            
        Returns:
            DataFrame contenant les données OHLCV
        """
        if not self.connected and not self.initialize_mt5():
            logger.error("Impossible de se connecter à MT5")
            return pd.DataFrame()
        
        try:
            # Conversion du timeframe MT5
            tf_map = {
                'M1': mt5.TIMEFRAME_M1,
                'M5': mt5.TIMEFRAME_M5,
                'M15': mt5.TIMEFRAME_M15,
                'M30': mt5.TIMEFRAME_M30,
                'H1': mt5.TIMEFRAME_H1,
                'H4': mt5.TIMEFRAME_H4,
                'D1': mt5.TIMEFRAME_D1,
                'W1': mt5.TIMEFRAME_W1,
                'MN1': mt5.TIMEFRAME_MN1
            }
            
            mt5_timeframe = tf_map.get(timeframe.upper())
            if not mt5_timeframe:
                logger.error(f"Timeframe non supporté: {timeframe}")
                return pd.DataFrame()
            
            # Sélection du symbole
            selected = mt5.symbol_select(symbol, True)
            if not selected:
                logger.error(f"Symbole non trouvé: {symbol}")
                return pd.DataFrame()
            
            # Récupération des données
            if from_date and to_date:
                rates = mt5.copy_rates_range(symbol, mt5_timeframe, from_date, to_date)
            elif from_date:
                rates = mt5.copy_rates_from(symbol, mt5_timeframe, from_date, count)
            elif to_date:
                rates = mt5.copy_rates_to(symbol, mt5_timeframe, to_date, count)
            else:
                rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, 0, count)
            
            if rates is None or len(rates) == 0:
                logger.error(f"Aucune donnée disponible pour {symbol} {timeframe}")
                return pd.DataFrame()
            
            # Conversion en DataFrame
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            df.set_index('time', inplace=True)
            df.rename(columns={
                'open': 'open',
                'high': 'high',
                'low': 'low',
                'close': 'close',
                'tick_volume': 'volume',
                'spread': 'spread',
                'real_volume': 'real_volume'
            }, inplace=True)
            
            # Calcul des indicateurs de base
            df = self._calculate_technical_indicators(df)
            
            return df
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des données: {e}")
            return pd.DataFrame()
    
    def get_tick_data(self, symbol: str, count: int = 1000) -> pd.DataFrame:
        """
        Récupère les données de ticks pour un symbole
        
        Args:
            symbol: Symbole (ex: 'EURUSD')
            count: Nombre de ticks à récupérer
            
        Returns:
            DataFrame contenant les données de ticks
        """
        if not self.connected and not self.initialize_mt5():
            logger.error("Impossible de se connecter à MT5")
            return pd.DataFrame()
            
        try:
            ticks = mt5.copy_ticks_from(symbol, datetime.now(), count, mt5.COPY_TICKS_ALL)
            if ticks is None or len(ticks) == 0:
                logger.error(f"Aucun tick disponible pour {symbol}")
                return pd.DataFrame()
                
            df = pd.DataFrame(ticks)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            df.set_index('time', inplace=True)
            
            return df
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des ticks: {e}")
            return pd.DataFrame()
    
    def get_account_info(self) -> Dict:
        """
        Récupère les informations du compte
        
        Returns:
            Dictionnaire contenant les informations du compte
        """
        if not self.connected and not self.initialize_mt5():
            logger.error("Impossible de se connecter à MT5")
            return {}
            
        try:
            account_info = mt5.account_info()._asdict()
            return account_info
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des informations du compte: {e}")
            return {}
    
    def get_symbol_info(self, symbol: str) -> Dict:
        """
        Récupère les informations d'un symbole
        
        Args:
            symbol: Symbole (ex: 'EURUSD')
            
        Returns:
            Dictionnaire contenant les informations du symbole
        """
        if not self.connected and not self.initialize_mt5():
            logger.error("Impossible de se connecter à MT5")
            return {}
            
        try:
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info:
                return symbol_info._asdict()
            return {}
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des informations du symbole {symbol}: {e}")
            return {}
    
    def _calculate_technical_indicators(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Calcule les indicateurs techniques sur les données OHLCV
        
        Args:
            df: DataFrame contenant les données OHLCV
            
        Returns:
            DataFrame avec les indicateurs techniques ajoutés
        """
        try:
            # Moyennes mobiles avec niveaux ajustés
            for period in [5, 15, 29, 50, 75, 80, 95, 90]:
                df[f'ma{period}'] = df['close'].rolling(window=period).mean()
                df[f'ema{period}'] = df['close'].ewm(span=period).mean()
            
            # RSI
            delta = df['close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
            rs = gain / loss
            df['rsi'] = 100 - (100 / (1 + rs))
            
            # MACD
            exp1 = df['close'].ewm(span=12, adjust=False).mean()
            exp2 = df['close'].ewm(span=26, adjust=False).mean()
            df['macd'] = exp1 - exp2
            df['macd_signal'] = df['macd'].ewm(span=9, adjust=False).mean()
            df['macd_hist'] = df['macd'] - df['macd_signal']
            
            # Bandes de Bollinger
            df['bb_middle'] = df['close'].rolling(window=20).mean()
            df['bb_std'] = df['close'].rolling(window=20).std()
            df['bb_upper'] = df['bb_middle'] + (df['bb_std'] * 2)
            df['bb_lower'] = df['bb_middle'] - (df['bb_std'] * 2)
            
            # ATR (Average True Range)
            high_low = df['high'] - df['low']
            high_close = (df['high'] - df['close'].shift()).abs()
            low_close = (df['low'] - df['close'].shift()).abs()
            ranges = pd.concat([high_low, high_close, low_close], axis=1)
            true_range = ranges.max(axis=1)
            df['atr'] = true_range.rolling(window=14).mean()
            
            # Volume moyen
            df['volume_ma20'] = df['volume'].rolling(window=20).mean()
            
            return df
            
        except Exception as e:
            logger.error(f"Erreur lors du calcul des indicateurs techniques: {e}")
            return df
    
    def shutdown(self):
        """Ferme la connexion à MT5"""
        if self.connected:
            mt5.shutdown()
            self.connected = False
            logger.info("Connexion à MT5 fermée")
