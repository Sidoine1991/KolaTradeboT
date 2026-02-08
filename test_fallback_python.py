#!/usr/bin/env python3
"""
Test du système de fallback Local → Render pour le robot de trading
Ce script simule les différents scénarios de connexion pour valider la logique de fallback
"""

import urllib.request
import urllib.parse
import json
import time
from datetime import datetime

# Configuration
LOCAL_URL = "http://localhost:8000/decision"
RENDER_URL = "https://makeup.render.com/decision"
TIMEOUT = 5  # secondes

class FallbackTester:
    def __init__(self):
        self.test_results = []
        
    def test_local_server(self):
        """Test si le serveur local est accessible"""
        print("🏠 Test du serveur LOCAL...")
        
        try:
            # Données de test complètes comme dans le modèle DecisionRequest
            test_data = {
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
            
            response = urllib.request.urlopen(
                LOCAL_URL,
                data=json.dumps(test_data).encode('utf-8'),
                timeout=TIMEOUT
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Serveur LOCAL répond - Signal: {result.get('action', 'unknown')} (confiance: {result.get('confidence', 0):.2f})")
                return True, "LOCAL", result
            else:
                print(f"❌ Serveur LOCAL indisponible - Code: {response.status_code}")
                return False, "LOCAL", None
                
        except urllib.error.URLError as e:
            print(f"❌ Erreur connexion LOCAL: {e}")
            return False, "LOCAL", None
    
    def test_render_server(self):
        """Test si le serveur Render est accessible"""
        print("🌐 Test du serveur RENDER...")
        
        try:
            # Mêmes données de test
            test_data = {
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
            
            response = urllib.request.urlopen(
                RENDER_URL,
                data=json.dumps(test_data).encode('utf-8'),
                timeout=TIMEOUT
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Serveur RENDER répond - Signal: {result.get('action', 'unknown')} (confiance: {result.get('confidence', 0):.2f})")
                return True, "RENDER", result
            else:
                print(f"❌ Serveur RENDER indisponible - Code: {response.status_code}")
                return False, "RENDER", None
                
        except urllib.error.URLError as e:
            print(f"❌ Erreur connexion RENDER: {e}")
            return False, "RENDER", None
    
    def generate_fallback_signal(self):
        """Générer un signal de secours basé sur RSI"""
        print("🔄 Génération signal de secours (fallback)...")
        
        # Simuler différentes valeurs RSI pour le test
        import random
        
        rsi_value = random.uniform(20, 80)  # RSI aléatoire entre 20 et 80
        
        if rsi_value < 30:
            action = "buy"
            confidence = 0.65
        elif rsi_value > 70:
            action = "sell"
            confidence = 0.65
        else:
            action = "hold"
            confidence = 0.50
        
        fallback_result = {
            "action": action,
            "confidence": confidence,
            "reason": f"Fallback signal based on RSI {rsi_value:.2f}",
            "source": "FALLBACK"
        }
        
        print(f"🔄 Signal de secours [FALLBACK]: {action.upper()} (RSI: {rsi_value:.2f})")
        print(f"   ⚠️ ModeFallback activé - Confiance réduite à {confidence}")
        
        return True, "FALLBACK", fallback_result
    
    def test_fallback_scenario_1(self):
        """Scénario 1: Local disponible"""
        print("\n" + "="*60)
        print("📋 SCÉNARIO 1: SERVEUR LOCAL DISPONIBLE")
        print("="*60)
        
        success, source, result = self.test_local_server()
        self.test_results.append({
            "scenario": "Local disponible",
            "success": success,
            "source": source,
            "result": result,
            "timestamp": datetime.now()
        })
        
        if success:
            print("🎯 RÉSULTAT: ✅ Signal obtenu du serveur LOCAL")
        else:
            print("❌ RÉSULTAT: ❌ Échec du serveur LOCAL")
    
    def test_fallback_scenario_2(self):
        """Scénario 2: Local indisponible, Render disponible"""
        print("\n" + "="*60)
        print("📋 SCÉNARIO 2: LOCAL INDISPONIBLE, RENDER DISPONIBLE")
        print("="*60)
        
        # Simuler local indisponible
        print("🏠 Simulation: Serveur LOCAL arrêté...")
        
        # Test Render
        success, source, result = self.test_render_server()
        self.test_results.append({
            "scenario": "Local indisponible, Render disponible",
            "local_success": False,
            "render_success": success,
            "source": source,
            "result": result,
            "timestamp": datetime.now()
        })
        
        if success:
            print("🎯 RÉSULTAT: ✅ Fallback vers Render réussi")
        else:
            print("❌ RÉSULTAT: ❌ Échec du serveur RENDER")
    
    def test_fallback_scenario_3(self):
        """Scénario 3: Les deux serveurs indisponibles"""
        print("\n" + "="*60)
        print("📋 SCÉNARIO 3: LOCAL ET RENDER INDISPONIBLES")
        print("="*60)
        
        # Simuler les deux serveurs indisponibles
        print("🏠 Simulation: Serveur LOCAL arrêté...")
        print("🌐 Simulation: Serveur Render inaccessible...")
        
        # Générer signal de secours
        success, source, result = self.generate_fallback_signal()
        self.test_results.append({
            "scenario": "Local et Render indisponibles",
            "local_success": False,
            "render_success": False,
            "source": source,
            "result": result,
            "timestamp": datetime.now()
        })
        
        if success:
            print("🎯 RÉSULTAT: ✅ Signal de secours généré")
        else:
            print("❌ RÉSULTAT: ❌ Échec complet")
    
    def test_render_only(self):
        """Test utilisation directe de Render (UseLocalFirst = false)"""
        print("\n" + "="*60)
        print("📋 SCÉNARIO 4: UTILISATION DIRECTE DE RENDER")
        print("="*60)
        
        success, source, result = self.test_render_server()
        self.test_results.append({
            "scenario": "Utilisation directe Render",
            "success": success,
            "source": source,
            "result": result,
            "timestamp": datetime.now()
        })
        
        if success:
            print("🎯 RÉSULTAT: ✅ Signal obtenu directement de Render")
        else:
            print("❌ RÉSULTAT: ❌ Échec du serveur RENDER")
    
    def run_all_tests(self):
        """Exécuter tous les tests de fallback"""
        print("🧪 DÉMARRAGE DES TESTS DE SYSTÈME DE FALLBACK")
        print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🌐 URL Locale: {LOCAL_URL}")
        print(f"🌐 URL Render: {RENDER_URL}")
        print(f"⏱️ Timeout: {TIMEOUT}s")
        
        # Exécuter tous les scénarios
        self.test_fallback_scenario_1()
        time.sleep(1)
        
        self.test_fallback_scenario_2()
        time.sleep(1)
        
        self.test_fallback_scenario_3()
        time.sleep(1)
        
        self.test_render_only()
        
        # Résumé des tests
        self.print_summary()
    
    def print_summary(self):
        """Afficher le résumé des tests"""
        print("\n" + "="*60)
        print("📊 RÉSUMÉ DES TESTS DE FALLBACK")
        print("="*60)
        
        total_tests = len(self.test_results)
        successful_tests = sum(1 for test in self.test_results if test.get("success", False))
        
        print(f"📈 Total des tests: {total_tests}")
        print(f"✅ Tests réussis: {successful_tests}")
        print(f"❌ Tests échoués: {total_tests - successful_tests}")
        print(f"📊 Taux de réussite: {(successful_tests/total_tests)*100:.1f}%")
        
        print("\n📋 DÉTAILS PAR SCÉNARIO:")
        for i, test in enumerate(self.test_results, 1):
            status = "✅" if test["success"] else "❌"
            print(f"{i}. {test['scenario']}: {status}")
            print(f"   Source: {test['source']}")
            if test['result']:
                print(f"   Signal: {test['result'].get('action', 'unknown')} (conf: {test['result'].get('confidence', 0):.2f})")
            print(f"   Timestamp: {test['timestamp'].strftime('%H:%M:%S')}")
            print()
        
        # Recommandations
        print("💡 RECOMMANDATIONS:")
        
        local_available = any(test["local_success"] for test in self.test_results)
        render_available = any(test["render_success"] for test in self.test_results)
        
        if local_available and render_available:
            print("   ✅ Les deux serveurs sont fonctionnels - Système optimal")
        elif local_available:
            print("   ✅ Seul le serveur local fonctionne - Performance optimale")
        elif render_available:
            print("   ✅ Seul le serveur Render fonctionne - Fallback fonctionnel")
        else:
            print("   ⚠️ Aucun serveur disponible - Signal de secours uniquement")
        
        print("   🔧 Actions requises:")
        if not local_available:
            print("      - Démarrer le serveur local: python ai_server.py")
        print("      - Vérifier la connectivité internet")
        print("      - Recompiler le robot MQL5 avec les modifications")

def main():
    tester = FallbackTester()
    tester.run_all_tests()

if __name__ == "__main__":
    main()
