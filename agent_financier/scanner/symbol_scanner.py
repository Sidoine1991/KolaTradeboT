#!/usr/bin/env python3
"
Scanner de symboles pour l'Agent Financier SMC.
Identifie les plus belles opportunités selon les critères Smart Money Concepts.
"
import yaml
import requests
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SymbolScanner:
    """Scanne les marchés pour trouver les setups SMC les plus pertinents."""
    
    def __init__(self, config_path: str = "config/config.yaml"):
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        self.symbols = self._expand_symbol_list()
        logger.info(f"Scanner initialisé avec {len(self.symbols)} symboles")
    
    def _expand_symbol_list(self) -> List[Dict[str, Any]]:
        symbols = []
        for category, data in self.config['symbols'].items():
            for pair in data['pairs']:
                symbols.append({
                    'symbol': pair,
                    'category': category,
                    'timeframes': data['timeframes']
                })
        return symbols
    
    def get_all_symbols(self) -> List[Dict[str, Any]]:
        return self.symbols
    
    def fetch_tv_data_web(self, symbol: str, timeframe: str = "H1") -> Dict[str, Any]:
        
        try:
            from tvdatafeed import TvDatafeed, Interval
            tv = TvDatafeed()
            interval_map = {
                "M15": Interval.in_15_minute,
                "H1": Interval.in_1_hour,
                "H4": Interval.in_4_hour,
                "D1": Interval.in_daily
            }
            interval = interval_map.get(timeframe, Interval.in_1_hour)
            df = tv.get_hist(symbol=symbol, exchange="FOREX_COM", interval=interval, n_bars=200)
            if df is not None and not df.empty:
                return {"status": "ok", "data": df.to_dict('records'), "count": len(df)}
        except ImportError:
            logger.warning("tvdatafeed non installé, utilisation mode demo")
        except Exception as e:
            logger.error(f"Erreur tvdatafeed: {e}")
        
        return {"status": "demo", "data": [], "symbol": symbol, "timeframe": timeframe}

if __name__ == "__main__":
    scanner = SymbolScanner()
    symbols = scanner.get_all_symbols()
    print(f"Symboles scannés: {len(symbols)}")
