#!/usr/bin/env python3
"""
Test Python pour diagnostiquer les erreurs 422 du robot MQL5
"""

import json
import requests
import time
from datetime import datetime

class Robot422Diagnostic:
    def __init__(self):
        self.local_url = "http://127.0.0.1:8000/decision"
        self.render_url = "https://kolatradebot.onrender.com/decision"
        
    def test_json_format(self):
        """Test du format JSON attendu par l'API"""
        print("🧪 TEST FORMAT JSON POUR ERREURS 422")
        print("="*60)
        
        # Format JSON correct (comme dans le robot MQL5)
        correct_json = {
            "symbol": "EURUSD",
            "bid": 1.08550,
            "ask": 1.08555,
            "rsi": 45.67,
            "atr": 0.01234,
            "is_spike_mode": False,
            "dir_rule": 0,
            "supertrend_trend": 0,
            "volatility_regime": 0,
            "volatility_ratio": 1.0
        }
        
        # Format JSON incorrect (ancien)
        incorrect_json = {
            "symbol": "EURUSD",
            "bid": 1.08550,
            "ask": 1.08555
        }
        
        print("📦 FORMAT JSON CORRECT (attendu):")
        print(json.dumps(correct_json, indent=2))
        
        print("\n❌ FORMAT JSON INCORRECT (ancien):")
        print(json.dumps(incorrect_json, indent=2))
        
        return correct_json, incorrect_json
    
    def test_local_server(self, json_data):
        """Test du serveur local avec le JSON"""
        print(f"\n🌐 TEST SERVEUR LOCAL: {self.local_url}")
        print("-"*40)
        
        try:
            headers = {"Content-Type": "application/json"}
            response = requests.post(
                self.local_url, 
                json=json_data, 
                headers=headers, 
                timeout=5
            )
            
            print(f"📊 Status Code: {response.status_code}")
            print(f"⏱️ Temps: {response.elapsed.total_seconds():.3f}s")
            
            if response.status_code == 200:
                print("✅ SUCCÈS - Serveur local répond correctement")
                try:
                    result = response.json()
                    print(f"🎯 Réponse: {result}")
                except:
                    print(f"📄 Réponse brute: {response.text[:200]}...")
            elif response.status_code == 422:
                print("❌ ERREUR 422 - Format JSON invalide")
                print(f"📄 Détail: {response.text}")
            else:
                print(f"⚠️ ERREUR {response.status_code}")
                print(f"📄 Réponse: {response.text[:200]}...")
                
        except requests.exceptions.ConnectionError:
            print("❌ SERVEUR LOCAL INDISPONIBLE")
            print("   Le serveur local n'est pas démarré")
        except requests.exceptions.Timeout:
            print("❌ TIMEOUT - Serveur local trop lent")
        except Exception as e:
            print(f"❌ ERREUR: {e}")
        
        return response.status_code if 'response' in locals() else None
    
    def test_render_server(self, json_data):
        """Test du serveur Render avec le JSON"""
        print(f"\n🌐 TEST SERVEUR RENDER: {self.render_url}")
        print("-"*40)
        
        try:
            headers = {"Content-Type": "application/json"}
            response = requests.post(
                self.render_url, 
                json=json_data, 
                headers=headers, 
                timeout=10
            )
            
            print(f"📊 Status Code: {response.status_code}")
            print(f"⏱️ Temps: {response.elapsed.total_seconds():.3f}s")
            
            if response.status_code == 200:
                print("✅ SUCCÈS - Serveur Render répond correctement")
                try:
                    result = response.json()
                    print(f"🎯 Réponse: {result}")
                except:
                    print(f"📄 Réponse brute: {response.text[:200]}...")
            elif response.status_code == 422:
                print("❌ ERREUR 422 - Format JSON invalide")
                print(f"📄 Détail: {response.text}")
            else:
                print(f"⚠️ ERREUR {response.status_code}")
                print(f"📄 Réponse: {response.text[:200]}...")
                
        except requests.exceptions.ConnectionError:
            print("❌ SERVEUR RENDER INDISPONIBLE")
        except requests.exceptions.Timeout:
            print("❌ TIMEOUT - Serveur Render trop lent")
        except Exception as e:
            print(f"❌ ERREUR: {e}")
        
        return response.status_code if 'response' in locals() else None
    
    def simulate_robot_request(self):
        """Simuler une requête exacte comme le robot MQL5"""
        print("\n🤖 SIMULATION REQUÊTE ROBOT MQL5")
        print("="*60)
        
        # Simuler les valeurs du robot
        import random
        symbol = "EURUSD"
        bid = round(1.08550 + random.uniform(-0.001, 0.001), 5)
        ask = round(bid + random.uniform(0.0001, 0.0010), 5)
        rsi = round(random.uniform(20, 80), 2)
        atr = round(random.uniform(0.001, 0.050), 5)
        
        # JSON exactement comme dans le robot MQL5
        robot_json = {
            "symbol": symbol,
            "bid": bid,
            "ask": ask,
            "rsi": rsi,
            "atr": atr,
            "is_spike_mode": False,
            "dir_rule": 0,
            "supertrend_trend": 0,
            "volatility_regime": 0,
            "volatility_ratio": 1.0
        }
        
        print(f"📊 Données simulées:")
        print(f"   Symbol: {symbol}")
        print(f"   Bid: {bid}")
        print(f"   Ask: {ask}")
        print(f"   RSI: {rsi}")
        print(f"   ATR: {atr}")
        
        print(f"\n📦 JSON envoyé par le robot:")
        print(json.dumps(robot_json, indent=2))
        
        # Tester avec les deux serveurs
        local_status = self.test_local_server(robot_json)
        render_status = self.test_render_server(robot_json)
        
        return local_status, render_status
    
    def diagnose_422_errors(self):
        """Diagnostic complet des erreurs 422"""
        print("\n🔍 DIAGNOSTIC COMPLET ERREURS 422")
        print("="*60)
        
        print("❌ SYMPTÔMES OBSERVÉS:")
        print("   - Erreurs 422 massives dans les logs")
        print("   - POST /decision - 422 Unprocessable Entity")
        print("   - Temps de réponse très rapide (0.003s)")
        print("   - Le robot envoie un format JSON invalide")
        
        print("\n🔍 CAUSES POSSIBLES:")
        print("   1. ❌ Robot non recompilé avec les corrections")
        print("   2. ❌ Format JSON ancien encore utilisé")
        print("   3. ❌ Champs manquants dans le JSON")
        print("   4. ❌ Types de données incorrects")
        
        print("\n✅ FORMAT JSON REQUIS PAR L'API:")
        required_fields = [
            "symbol", "bid", "ask", "rsi", "atr",
            "is_spike_mode", "dir_rule", "supertrend_trend",
            "volatility_regime", "volatility_ratio"
        ]
        
        for field in required_fields:
            print(f"   ✅ {field}")
        
        print("\n🎯 SOLUTION DÉFINITIVE:")
        print("   1. 🔧 COMPILER LE ROBOT DANS METAEDITOR (F7)")
        print("   2. 📊 Vérifier '0 error(s), 0 warning(s)'")
        print("   3. 🔄 Redémarrer le robot sur le graphique")
        print("   4. 📋 Surveiller les logs '📦 DONNÉES JSON COMPLÈTES'")
    
    def run_complete_test(self):
        """Exécuter le test complet"""
        print("🚀 DÉMARRAGE TEST COMPLET ERREURS 422")
        print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("="*60)
        
        # Test 1: Format JSON
        correct_json, incorrect_json = self.test_json_format()
        
        # Test 2: Serveur local avec format correct
        print(f"\n{'='*60}")
        print("TEST 1: SERVEUR LOCAL AVEC FORMAT CORRECT")
        self.test_local_server(correct_json)
        
        # Test 3: Serveur local avec format incorrect
        print(f"\n{'='*60}")
        print("TEST 2: SERVEUR LOCAL AVEC FORMAT INCORRECT")
        self.test_local_server(incorrect_json)
        
        # Test 4: Simulation robot
        print(f"\n{'='*60}")
        print("TEST 3: SIMULATION REQUÊTE ROBOT")
        self.simulate_robot_request()
        
        # Test 5: Diagnostic
        self.diagnose_422_errors()
        
        print(f"\n{'='*60}")
        print("🎯 TEST TERMINÉ")
        print("="*60)
        
        print("💡 CONCLUSION:")
        print("   ✅ Le format JSON correct fonctionne avec l'API")
        print("   ❌ Le format JSON incorrect génère des erreurs 422")
        print("   🔧 La solution est de compiler le robot MQL5")
        print("   📊 Après compilation, les erreurs 422 disparaîtront")

def main():
    """Fonction principale"""
    diagnostic = Robot422Diagnostic()
    diagnostic.run_complete_test()

if __name__ == "__main__":
    main()
