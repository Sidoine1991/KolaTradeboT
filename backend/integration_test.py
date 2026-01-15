"""
Script d'intégration pour tester le backend de TradBOT

Ce script démontre comment les différents composants du backend interagissent ensemble :
1. Récupération des données avec DataManager
2. Génération de signaux avec StrategyEngine
3. Calcul de la taille de position avec RiskManager
4. Exécution d'ordres avec OrderExecutor (simulé en mode démo)
"""
import os
import sys
import logging
from datetime import datetime, timedelta
import pandas as pd

# Ajout du répertoire parent au chemin pour les imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('trading_bot.log')
    ]
)
logger = logging.getLogger(__name__)

# Import des modules du backend
from core.data_manager import DataManager
from core.strategy_engine import StrategyEngine, TrendFollowingStrategy, SignalType
from risk.risk_manager import RiskManager
from execution.order_executor import OrderExecutor
from config.settings import MT5_CONFIG, TRADING_CONFIG, INDICATORS_CONFIG

class BackendIntegrationTest:
    """Classe pour tester l'intégration des composants du backend"""
    
    def __init__(self, symbol='EURUSD', timeframe='M5', demo_mode=True):
        """Initialisation des composants"""
        self.symbol = symbol
        self.timeframe = timeframe
        self.demo_mode = demo_mode
        self.initial_balance = 10000  # Solde initial pour les tests
        
        # Initialisation des composants
        self.data_manager = DataManager()
        self.strategy_engine = StrategyEngine()
        self.risk_manager = RiskManager(
            initial_balance=self.initial_balance,
            risk_per_trade=TRADING_CONFIG['risk_per_trade'],
            max_daily_drawdown=TRADING_CONFIG['max_daily_drawdown']
        )
        # Initialisation de l'OrderExecutor avec les paramètres de connexion MT5
        self.order_executor = OrderExecutor(
            account=MT5_CONFIG.get('login'),
            server=MT5_CONFIG.get('server'),
            password=MT5_CONFIG.get('password')
        )
        
        # Enregistrement et activation de la stratégie
        self.strategy_engine.add_strategy('trend_following', TrendFollowingStrategy)
        self.strategy_engine.activate_strategy(
            strategy_id='trend_following',
            symbol=symbol,
            timeframe=timeframe,
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
        
        logger.info("Initialisation du test d'intégration terminée")
    
    def run_test(self, days_back=1):
        """Exécute le test d'intégration"""
        logger.info("Démarrage du test d'intégration")
        
        try:
            # 1. Récupération des données historiques
            logger.info(f"Récupération des données pour {self.symbol} sur {self.timeframe}")
            end_date = datetime.now()
            start_date = end_date - timedelta(days=days_back)
            
            df = self.data_manager.get_historical_data(
                symbol=self.symbol,
                timeframe=self.timeframe,
                from_date=start_date,
                to_date=end_date
            )
            
            if df is None or df.empty:
                logger.error("Aucune donnée récupérée. Vérifiez la connexion à MT5.")
                return False
                
            logger.info(f"Données récupérées : {len(df)} bougies")
            
            # 2. Génération des signaux
            logger.info("Génération des signaux de trading...")
            signals = self.strategy_engine.process_data(self.symbol, self.timeframe, df)
            
            if not signals:
                logger.warning("Aucun signal généré.")
                return False
                
            # Prendre le dernier signal généré
            last_signal = signals[-1]
            logger.info(f"Dernier signal généré: {last_signal.signal_type.name} à {last_signal.timestamp}")
            
            # 3. Vérification des conditions de risque
            if last_signal.signal_type != SignalType.HOLD:
                logger.info("Signal de trading détecté, vérification des conditions de risque...")
                
                # Calcul de la taille de position
                entry_price = last_signal.price
                stop_loss = last_signal.stop_loss
                take_profit = last_signal.take_profit
                
                position_size, risk_amount = self.risk_manager.calculate_position_size(
                    entry_price=entry_price,
                    stop_loss=stop_loss,
                    account_balance=self.initial_balance,
                    risk_per_trade=TRADING_CONFIG['risk_per_trade']
                )
                
                if position_size <= 0:
                    logger.warning("Taille de position nulle ou négative. Trade annulé.")
                    return False
                    
                logger.info(f"Taille de position calculée: {position_size:.2f} lots")
                
                # 4. Exécution de l'ordre (simulé en mode démo)
                logger.info("Tentative d'exécution de l'ordre...")
                
                if last_signal.signal_type == SignalType.BUY:
                    order_type = 'buy'
                else:  # SignalType.SELL
                    order_type = 'sell'
                
                result = self.order_executor.place_market_order(
                    symbol=self.symbol,
                    order_type=order_type,
                    volume=position_size,
                    stop_loss=stop_loss,
                    take_profit=take_profit,
                    comment="Trade généré par le test d'intégration"
                )
                
                if result.retcode == 10009:  # MT5.TRADE_RETCODE_DONE
                    logger.info(f"Ordre exécuté avec succès. Ticket: {result.order}")
                    return True
                else:
                    logger.error(f"Erreur lors de l'exécution de l'ordre: {result.comment}")
                    return False
            else:
                logger.info("Aucun signal de trading valide pour le moment.")
                return True
                
        except Exception as e:
            logger.exception(f"Erreur lors du test d'intégration: {str(e)}")
            return False

def main():
    """Fonction principale"""
    # Configuration
    symbol = 'EURUSD'
    timeframe = 'M5'
    demo_mode = True  # Mettre à False pour le trading réel
    
    # Création et exécution du test
    test = BackendIntegrationTest(symbol=symbol, timeframe=timeframe, demo_mode=demo_mode)
    success = test.run_test(days_back=1)
    
    if success:
        logger.info("Test d'intégration terminé avec succès!")
    else:
        logger.warning("Test d'intégration terminé avec des avertissements ou des erreurs.")

if __name__ == "__main__":
    main()
