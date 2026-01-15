# Test minimal pour DataManager
import sys
import os
from datetime import datetime, timedelta

# Configuration de base du logging
import logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Ajout du repertoire parent au path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from core.data_manager import DataManager
    logger.info("DataManager importe avec succes")
except ImportError as e:
    logger.error(f"Erreur d'importation: {e}")
    sys.exit(1)

def test_dm():
    try:
        logger.info("Initialisation du DataManager...")
        dm = DataManager()
        
        # Test de recuperation des donnees
        logger.info("Recuperation des donnees...")
        end_date = datetime.now()
        start_date = end_date - timedelta(days=1)
        
        df = dm.get_historical_data(
            symbol='EURUSD',
            timeframe='M5',
            from_date=start_date,
            to_date=end_date
        )
        
        if df is not None and not df.empty:
            logger.info(f"Donnees recuperees: {len(df)} bougies")
            print("\nApercu des donnees:")
            print(df.head())
            return True
        else:
            logger.error("Aucune donnee recuperee")
            return False
            
    except Exception as e:
        logger.error(f"Erreur: {e}")
        return False

if __name__ == "__main__":
    logger.info("Debut du test")
    success = test_dm()
    
    if success:
        logger.info("Test reussi!")
    else:
        logger.error("Echec du test")
    
    logger.info("Fin du test")
