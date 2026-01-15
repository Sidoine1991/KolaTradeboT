"""
Test d'intégration pour le backend de TradBOT

Ce script teste l'intégration des composants principaux du backend.
"""
import os
import sys
import logging
from datetime import datetime, timedelta
import pandas as pd

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('trading_test.log')
    ]
)
logger = logging.getLogger(__name__)

# Ajout du répertoire parent au chemin pour les imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from core.data_manager import DataManager
    from core.strategy_engine import StrategyEngine, TrendFollowingStrategy, SignalType
    from risk.risk_manager import RiskManager
    from execution.order_executor import OrderExecutor
    from config.settings import MT5_CONFIG, TRADING_CONFIG
    
    logger.info("Tous les modules ont été importés avec succès.")
    
except ImportError as e:
    logger.error(f"Erreur d'importation: {e}")
    sys.exit(1)

class IntegrationTest:
    """Classe de test d'intégration pour le backend"""
    
    def __init__(self):
        """Initialise les composants pour le test"""
        self.symbol = 'EURUSD'
        self.timeframe = 'M5'
        self.initial_balance = 10000
        
        try:
            # Initialisation des composants
            self.data_manager = DataManager()
            logger.info("DataManager initialisé")
            
            self.strategy_engine = StrategyEngine()
            logger.info("StrategyEngine initialisé")
            
            self.risk_manager = RiskManager(
                initial_balance=self.initial_balance,
                risk_per_trade=TRADING_CONFIG['risk_per_trade'],
                max_daily_drawdown=TRADING_CONFIG['max_daily_drawdown']
            )
            logger.info("RiskManager initialisé")
            
            self.order_executor = OrderExecutor(
                account=MT5_CONFIG.get('login'),
                server=MT5_CONFIG.get('server'),
                password=MT5_CONFIG.get('password')
            )
            logger.info("OrderExecutor initialisé")
            
            # Configuration de la stratégie
            self.setup_strategy()
            
        except Exception as e:
            logger.error(f"Erreur lors de l'initialisation: {e}")
            raise
    
    def setup_strategy(self):
        """Configure la stratégie de trading"""
        try:
            # Enregistrement de la stratégie
            self.strategy_engine.add_strategy('trend_following', TrendFollowingStrategy)
            
            # Activation de la stratégie
            self.strategy_engine.activate_strategy(
                strategy_id='trend_following',
                symbol=self.symbol,
                timeframe=self.timeframe,
                params={
                    'ma_fast': 20,
                    'ma_slow': 50,
                    'rsi_period': 14,
                    'rsi_overbought': 70,
                    'rsi_oversold': 30,
                    'atr_period': 14,
                    'atr_multiplier': 2.0,
                    'min_trend_strength': 0.5
                }
            )
            logger.info("Stratégie configurée avec succès")
            
        except Exception as e:
            logger.error(f"Erreur lors de la configuration de la stratégie: {e}")
            raise
    
    def run_test(self, days_back=1):
        """Exécute le test d'intégration"""
        logger.info("Démarrage du test d'intégration")
        
        try:
            # 1. Récupération des données
            logger.info(f"Récupération des données pour {self.symbol} {self.timeframe}")
            end_date = datetime.now()
            start_date = end_date - timedelta(days=days_back)
            
            df = self.data_manager.get_historical_data(
                symbol=self.symbol,
                timeframe=self.timeframe,
                from_date=start_date,
                to_date=end_date
            )
            
            if df is None or df.empty:
                logger.error("Aucune donnée récupérée")
                return False
                
            logger.info(f"Données récupérées: {len(df)} bougies")
            
            # 2. Génération des signaux
            logger.info("Génération des signaux...")
            signals = self.strategy_engine.process_data(self.symbol, self.timeframe, df)
            
            if not signals:
                logger.warning("Aucun signal généré")
                return False
                
            # Afficher le dernier signal
            last_signal = signals[-1]
            logger.info(f"Dernier signal: {last_signal.signal_type.name} à {last_signal.timestamp}")
            
            # 3. Vérification des conditions de risque
            if last_signal.signal_type != SignalType.HOLD:
                logger.info("Traitement du signal de trading...")
                
                # Calcul de la taille de position
                position_size, risk_amount = self.risk_manager.calculate_position_size(
                    entry_price=last_signal.price,
                    stop_loss=last_signal.stop_loss,
                    account_balance=self.initial_balance,
                    risk_per_trade=TRADING_CONFIG['risk_per_trade']
                )
                
                if position_size <= 0:
                    logger.warning("Taille de position non valide")
                    return False
                    
                logger.info(f"Taille de position calculée: {position_size:.2f} lots")
                
                # 4. Exécution de l'ordre (simulé)
                order_type = 'buy' if last_signal.signal_type == SignalType.BUY else 'sell'
                
                result = self.order_executor.place_market_order(
                    symbol=self.symbol,
                    order_type=order_type,
                    volume=position_size,
                    stop_loss=last_signal.stop_loss,
                    take_profit=last_signal.take_profit,
                    comment="Test d'intégration"
                )
                
                if result.retcode == 10009:  # MT5.TRADE_RETCODE_DONE
                    logger.info(f"Ordre exécuté avec succès. Ticket: {result.order}")
                    return True
                else:
                    logger.error(f"Erreur d'exécution: {result.comment}")
                    return False
            else:
                logger.info("Aucun signal de trading valide")
                return True
                
        except Exception as e:
            logger.exception(f"Erreur lors du test: {e}")
            return False

def main():
    """Fonction principale"""
    try:
        logger.info("Démarrage du test d'intégration")
        test = IntegrationTest()
        success = test.run_test(days_back=1)
        
        if success:
            logger.info("Test d'intégration réussi!")
        else:
            logger.warning("Test d'intégration terminé avec des avertissements")
            
    except Exception as e:
        logger.error(f"Échec du test d'intégration: {e}")
        return 1
        
    return 0

if __name__ == "__main__":
    sys.exit(main())
