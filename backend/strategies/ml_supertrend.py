"""
Module d'intégration de la stratégie ML-SuperTrend pour TradBOT
"""
import os
import sys
import logging
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
import pandas as pd
import MetaTrader5 as mt5

# Ajouter le chemin du projet ML-SuperTrend-MT5 au path
ml_supertrend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'ml_supertrend'))
if ml_supertrend_path not in sys.path:
    sys.path.insert(0, ml_supertrend_path)

from core.supertrend_bot import SuperTrendBot, Config as STConfig

# Configuration du logger
logger = logging.getLogger(__name__)

@dataclass
class MLSuperTrendConfig:
    """Configuration pour la stratégie ML-SuperTrend"""
    symbol: str = "EURUSD"
    timeframe: str = "H1"
    atr_period: int = 10
    min_factor: float = 1.0
    max_factor: float = 5.0
    factor_step: float = 0.5
    risk_percent: float = 1.0
    max_positions: int = 1

class MLSuperTrendStrategy:
    """Classe d'intégration de la stratégie ML-SuperTrend"""
    
    def __init__(self, config: Optional[MLSuperTrendConfig] = None):
        """Initialise la stratégie avec la configuration fournie"""
        self.config = config or MLSuperTrendConfig()
        self.bot = None
        self.timeframe_map = {
            "M1": mt5.TIMEFRAME_M1,
            "M5": mt5.TIMEFRAME_M5,
            "M15": mt5.TIMEFRAME_M15,
            "H1": mt5.TIMEFRAME_H1,
            "H4": mt5.TIMEFRAME_H4,
            "D1": mt5.TIMEFRAME_D1
        }
    
    def initialize(self) -> bool:
        """Initialise la stratégie"""
        try:
            print(f"🔍 Configuration de la stratégie pour {self.config.symbol} ({self.config.timeframe})")
            
            # Vérifier que le timeframe est valide
            mt5_timeframe = self.timeframe_map.get(self.config.timeframe)
            if mt5_timeframe is None:
                print(f"❌ Timeframe non supporté: {self.config.timeframe}")
                print(f"Timeframes supportés: {list(self.timeframe_map.keys())}")
                return False
                
            print(f"✅ Timeframe valide: {self.config.timeframe} -> {mt5_timeframe}")
            
            # Configuration de la stratégie
            print("⚙️ Création de la configuration STConfig...")
            st_config = STConfig(
                symbol=self.config.symbol,
                timeframe=mt5_timeframe,
                atr_period=self.config.atr_period,
                min_factor=self.config.min_factor,
                max_factor=self.config.max_factor,
                factor_step=self.config.factor_step,
                risk_percent=self.config.risk_percent,
                max_positions=self.config.max_positions
            )
            
            print("🚀 Initialisation du SuperTrendBot...")
            # Initialisation du bot
            self.bot = SuperTrendBot(st_config)
            
            # Vérifier que le bot a été correctement initialisé
            if self.bot is None:
                print("❌ Échec de la création du SuperTrendBot")
                return False
                
            print("✅ SuperTrendBot initialisé avec succès")
            return True
            
        except ImportError as ie:
            print(f"❌ Erreur d'importation: {ie}")
            import traceback
            traceback.print_exc()
            return False
        except Exception as e:
            print(f"❌ Erreur lors de l'initialisation de la stratégie ML-SuperTrend: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def get_signals(self, data: pd.DataFrame) -> Dict:
        """
        Analyse les données et retourne les signaux de trading
        
        Args:
            data: DataFrame contenant les données OHLCV
            
        Returns:
            Dict: Dictionnaire contenant les signaux et les indicateurs
        """
        if self.bot is None:
            if not self.initialize():
                return {"error": "Échec de l'initialisation de la stratégie"}
        
        try:
            # Si nous avons un bot initialisé, utilisons sa logique d'analyse
            # Note: Cette partie devra être adaptée en fonction de la façon dont SuperTrendBot est conçu
            if hasattr(self.bot, 'analyze'):
                return self.bot.analyze(data)
            else:
                # Implémentation de secours si la méthode analyze n'existe pas
                return self._default_analysis(data)
                
        except Exception as e:
            logger.error(f"Erreur lors de l'analyse des signaux: {e}")
            return {"error": str(e)}
    
    def _default_analysis(self, data: pd.DataFrame) -> Dict:
        """
        Analyse par défaut des données pour générer des signaux
        
        Args:
            data: DataFrame contenant les données OHLCV
            
        Returns:
            Dict: Dictionnaire contenant les signaux et indicateurs
        """
        try:
            # Vérifier que nous avons les colonnes nécessaires
            required_columns = ['open', 'high', 'low', 'close', 'volume']
            if not all(col in data.columns for col in required_columns):
                return {"error": f"Données manquantes. Colonnes requises: {required_columns}"}
                
            # Calculer les indicateurs de base
            signals = {
                'signal': 'NEUTRAL',
                'price': data['close'].iloc[-1],
                'indicators': {
                    'close': data['close'].iloc[-1],
                    'volume': data['volume'].iloc[-1],
                    'atr': self._calculate_atr(data, period=14).iloc[-1],
                    'ma20': data['close'].rolling(window=20).mean().iloc[-1],
                    'ma50': data['close'].rolling(window=50).mean().iloc[-1]
                },
                'timestamp': data.index[-1].strftime('%Y-%m-%d %H:%M:%S'),
                'symbol': self.config.symbol,
                'timeframe': self.config.timeframe
            }
            
            # Logique de signal basique (à remplacer par la logique ML-SuperTrend réelle)
            close = data['close']
            ma20 = signals['indicators']['ma20']
            ma50 = signals['indicators']['ma50']
            
            if close.iloc[-1] > ma20 and close.iloc[-1] > ma50:
                signals['signal'] = 'BUY'
            elif close.iloc[-1] < ma20 and close.iloc[-1] < ma50:
                signals['signal'] = 'SELL'
                
            return signals
            
        except Exception as e:
            logger.error(f"Erreur dans l'analyse par défaut: {e}")
            return {"error": f"Erreur dans l'analyse par défaut: {str(e)}"}
            
    def _calculate_atr(self, data: pd.DataFrame, period: int = 14) -> pd.Series:
        """Calcule l'Average True Range (ATR)"""
        try:
            high = data['high']
            low = data['low']
            close = data['close']
            
            tr1 = high - low
            tr2 = (high - close.shift()).abs()
            tr3 = (low - close.shift()).abs()
            
            tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
            atr = tr.rolling(window=period).mean()
            
            return atr
            
        except Exception as e:
            logger.error(f"Erreur dans le calcul ATR: {e}")
            return pd.Series(index=data.index, dtype=float)
        """Analyse par défaut si la méthode du bot n'est pas disponible"""
        # Cette méthode peut être implémentée pour fournir une analyse de base
        # si la méthode du bot n'est pas disponible
        return {
            "signal": "NEUTRE",
            "indicators": {
                "atr": None,
                "supertrend": None
            },
            "timestamp": pd.Timestamp.now().isoformat()
        }
    
    def get_required_columns(self) -> List[str]:
        """Retourne la liste des colonnes requises pour l'analyse"""
        return ["open", "high", "low", "close", "volume"]
    
    def get_default_parameters(self) -> Dict:
        """Retourne les paramètres par défaut de la stratégie"""
        return {
            "atr_period": 10,
            "min_factor": 1.0,
            "max_factor": 5.0,
            "factor_step": 0.5,
            "risk_percent": 1.0,
            "max_positions": 1
        }

# Exemple d'utilisation
if __name__ == "__main__":
    # Configuration de base
    config = MLSuperTrendConfig(
        symbol="EURUSD",
        timeframe="H1",
        risk_percent=1.0
    )
    
    # Initialisation de la stratégie
    strategy = MLSuperTrendStrategy(config)
    
    # Ici, vous pourriez charger des données et appeler strategy.get_signals(data)
    print("Stratégie ML-SuperTrend initialisée avec succès")
