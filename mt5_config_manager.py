#!/usr/bin/env python3
"""
Gestionnaire de configuration MT5 pour les deux comptes
ID 5775742: Deriv-Demo (pass: Socrate2024)
ID 435547595: Exness-MT5Trial9 (pass: Socrate2024@)
"""

import MetaTrader5 as mt5
import json
from typing import Dict, Any, Optional
from datetime import datetime

class MT5ConfigManager:
    def __init__(self):
        self.accounts = {
            "deriv_demo": {
                "login": 5775742,
                "password": "Socrate2024",
                "server": "Deriv-Demo",
                "name": "Deriv Demo"
            },
            "exness_trial": {
                "login": 435547595,
                "password": "Socrate2024@",
                "server": "Exness-MT5Trial9",
                "name": "Exness Trial"
            }
        }
        
    def test_connection(self, account_key: str) -> Dict[str, Any]:
        """Test la connexion pour un compte spécifique"""
        if account_key not in self.accounts:
            return {"success": False, "error": "Compte inconnu"}
        
        account = self.accounts[account_key]
        
        # Initialiser MT5
        if not mt5.initialize():
            return {"success": False, "error": f"Initialisation MT5: {mt5.last_error()}"}
        
        try:
            # Tentative de connexion
            authorized = mt5.login(
                login=account["login"],
                password=account["password"],
                server=account["server"]
            )
            
            if not authorized:
                error = mt5.last_error()
                return {"success": False, "error": f"Connexion échouée: {error}"}
            
            # Récupérer infos compte
            account_info = mt5.account_info()
            if not account_info:
                return {"success": False, "error": "Impossible de récupérer infos compte"}
            
            # Vérifier symboles disponibles
            test_symbols = ["EURUSD", "GBPUSD", "Boom 300 Index", "Crash 300 Index"]
            symbol_status = {}
            
            for symbol in test_symbols:
                symbol_info = mt5.symbol_info(symbol)
                if symbol_info:
                    symbol_status[symbol] = {
                        "visible": symbol_info.visible,
                        "trade_mode": symbol_info.trade_mode,
                        "description": symbol_info.description
                    }
                else:
                    symbol_status[symbol] = {"visible": False, "trade_mode": "N/A"}
            
            return {
                "success": True,
                "account": {
                    "login": account_info.login,
                    "server": account_info.server,
                    "balance": account_info.balance,
                    "equity": account_info.equity,
                    "margin": account_info.margin,
                    "free_margin": account_info.margin_free,
                    "leverage": account_info.leverage,
                    "currency": account_info.currency
                },
                "symbols": symbol_status,
                "terminal_info": {
                    "name": mt5.terminal_info().name if mt5.terminal_info() else "N/A",
                    "version": mt5.terminal_info().build if mt5.terminal_info() else "N/A",
                    "connected": mt5.terminal_info().connected if mt5.terminal_info() else False
                }
            }
            
        finally:
            mt5.shutdown()
    
    def test_all_accounts(self) -> Dict[str, Any]:
        """Test tous les comptes configurés"""
        results = {}
        
        print("🔍 TEST DES COMPTES MT5")
        print("=" * 50)
        
        for account_key in self.accounts:
            print(f"\n📊 Test compte: {self.accounts[account_key]['name']}")
            result = self.test_connection(account_key)
            results[account_key] = result
            
            if result["success"]:
                acc = result["account"]
                print(f"✅ Connexion réussie")
                print(f"   Solde: {acc['balance']} {acc['currency']}")
                print(f"   Marge libre: {acc['free_margin']} {acc['currency']}")
                print(f"   Levier: 1:{acc['leverage']}")
                
                # Afficher symboles disponibles
                print("   Symboles:")
                for symbol, status in result["symbols"].items():
                    if status["visible"]:
                        print(f"     ✅ {symbol}")
                    else:
                        print(f"     ❌ {symbol}")
            else:
                print(f"❌ Échec: {result['error']}")
        
        return results
    
    def create_config_file(self, active_account: str = "deriv_demo") -> str:
        """Crée le fichier de configuration MT5"""
        config = {
            "mt5_accounts": self.accounts,
            "active_account": active_account,
            "settings": {
                "timeout_seconds": 30,
                "retry_attempts": 3,
                "symbols_to_monitor": ["EURUSD", "GBPUSD", "Boom 300 Index", "Crash 300 Index"],
                "timeframes": ["M1", "M5", "M15", "H1"]
            }
        }
        
        config_file = "mt5_accounts_config.json"
        with open(config_file, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        
        return config_file
    
    def get_best_account_for_trading(self, test_results: Dict[str, Any]) -> Optional[str]:
        """Détermine le meilleur compte pour le trading"""
        best_account = None
        best_score = -1
        
        for account_key, result in test_results.items():
            if not result["success"]:
                continue
            
            score = 0
            acc = result["account"]
            
            # Score basé sur le solde
            if acc["balance"] > 1000:
                score += 3
            elif acc["balance"] > 100:
                score += 2
            else:
                score += 1
            
            # Score basé sur la marge libre
            if acc["free_margin"] > 500:
                score += 2
            elif acc["free_margin"] > 50:
                score += 1
            
            # Score basé sur les symboles disponibles
            available_symbols = sum(1 for s in result["symbols"].values() if s["visible"])
            score += available_symbols
            
            if score > best_score:
                best_score = score
                best_account = account_key
        
        return best_account

def main():
    manager = MT5ConfigManager()
    
    # Tester tous les comptes
    results = manager.test_all_accounts()
    
    # Déterminer le meilleur compte
    best_account = manager.get_best_account_for_trading(results)
    
    if best_account:
        print(f"\n🏆 Meilleur compte pour trading: {manager.accounts[best_account]['name']}")
        
        # Créer fichier de config
        config_file = manager.create_config_file(best_account)
        print(f"✅ Fichier de configuration créé: {config_file}")
        
        # Créer script de connexion rapide
        quick_connect = f'''#!/usr/bin/env python3
"""
Connexion rapide au compte MT5 recommandé
"""
import MetaTrader5 as mt5

def connect_to_best_account():
    """Connexion au meilleur compte"""
    account_info = {manager.accounts[best_account]}
    
    if not mt5.initialize():
        print("❌ Initialisation MT5 échouée")
        return False
    
    authorized = mt5.login(
        login=account_info["login"],
        password=account_info["password"],
        server=account_info["server"]
    )
    
    if authorized:
        print(f"✅ Connecté à {account_info['name']}")
        return True
    else:
        print(f"❌ Connexion échouée: {{mt5.last_error()}}")
        return False

if __name__ == "__main__":
    connect_to_best_account()
'''
        
        with open("quick_mt5_connect.py", "w", encoding="utf-8") as f:
            f.write(quick_connect)
        
        print("✅ Script de connexion rapide créé: quick_mt5_connect.py")
    
    else:
        print("\n❌ Aucun compte valide trouvé pour le trading")

if __name__ == "__main__":
    main()
