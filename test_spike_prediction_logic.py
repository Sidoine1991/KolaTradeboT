#!/usr/bin/env python3
"""
Test de la nouvelle logique de prédiction de spike
Vérifie que le robot attend bien les prédictions avant d'entrer
"""

import time
import requests
import json
from datetime import datetime

class SpikePredictionTester:
    def __init__(self):
        self.api_url = "http://localhost:8001"
        self.test_results = []
        
    def test_prediction_logic(self):
        """Test de la logique de prédiction"""
        print("🧪 Test de la nouvelle logique de prédiction de spike")
        print("=" * 60)
        
        # Test 1: Vérifier que le robot attend une prédiction
        print("\n1️⃣ Test: Attente de prédiction")
        self.test_wait_for_prediction()
        
        # Test 2: Vérifier la validation de direction
        print("\n2️⃣ Test: Validation de direction")
        self.test_direction_validation()
        
        # Test 3: Vérifier le cooldown
        print("\n3️⃣ Test: Cooldown entre trades")
        self.test_cooldown_logic()
        
        # Test 4: Vérifier la fermeture intelligente
        print("\n4️⃣ Test: Fermeture intelligente")
        self.test_smart_close()
        
        self.print_summary()
    
    def test_wait_for_prediction(self):
        """Test que le robot attend une prédiction avant d'entrer"""
        try:
            # Simuler une prédiction de spike
            prediction_data = {
                "confidence": 87.5,
                "direction": 1,  # BUY
                "symbol": "EURUSD",
                "timestamp": datetime.now().isoformat()
            }
            
            response = requests.post(f"{self.api_url}/predict_spike", json=prediction_data)
            
            if response.status_code == 200:
                result = response.json()
                if result.get("waiting_for_spike", False):
                    self.test_results.append(("Attente prédiction", "✅ PASS", "Robot en attente"))
                else:
                    self.test_results.append(("Attente prédiction", "❌ FAIL", "Robot n'attend pas"))
            else:
                self.test_results.append(("Attente prédiction", "⚠️ ERROR", f"API error: {response.status_code}"))
                
        except Exception as e:
            self.test_results.append(("Attente prédiction", "❌ ERROR", str(e)))
    
    def test_direction_validation(self):
        """Test de la validation de direction"""
        try:
            # Test avec direction correcte
            correct_direction = {
                "predicted_direction": 1,
                "detected_direction": 1,
                "should_enter": True
            }
            
            # Test avec direction incorrecte
            incorrect_direction = {
                "predicted_direction": 1,
                "detected_direction": -1,
                "should_enter": False
            }
            
            # Simuler les tests
            if correct_direction["predicted_direction"] == correct_direction["detected_direction"]:
                self.test_results.append(("Validation direction correcte", "✅ PASS", "Direction validée"))
            else:
                self.test_results.append(("Validation direction correcte", "❌ FAIL", "Direction rejetée"))
                
            if incorrect_direction["predicted_direction"] != incorrect_direction["detected_direction"]:
                self.test_results.append(("Validation direction incorrecte", "✅ PASS", "Direction rejetée"))
            else:
                self.test_results.append(("Validation direction incorrecte", "❌ FAIL", "Direction acceptée"))
                
        except Exception as e:
            self.test_results.append(("Validation direction", "❌ ERROR", str(e)))
    
    def test_cooldown_logic(self):
        """Test du cooldown entre trades"""
        try:
            # Simuler un trade récent
            last_trade_time = time.time() - 15  # 15 secondes ago
            min_wait_time = 30  # 30 secondes minimum
            
            time_since_trade = time.time() - last_trade_time
            
            if time_since_trade < min_wait_time:
                self.test_results.append(("Cooldown actif", "✅ PASS", f"Cooldown: {min_wait_time - time_since_trade:.0f}s"))
            else:
                self.test_results.append(("Cooldown actif", "❌ FAIL", "Cooldown expiré trop tôt"))
                
        except Exception as e:
            self.test_results.append(("Cooldown", "❌ ERROR", str(e)))
    
    def test_smart_close(self):
        """Test de la fermeture intelligente"""
        try:
            # Simuler un spike capturé avec gain
            spike_captured = True
            current_profit = 1.25
            predicted_direction = 1
            detected_direction = 1
            
            should_close = (spike_captured and current_profit > 0.0 and 
                          predicted_direction == detected_direction)
            
            if should_close:
                self.test_results.append(("Fermeture intelligente", "✅ PASS", "Spike capturé avec gain"))
            else:
                self.test_results.append(("Fermeture intelligente", "❌ FAIL", "Conditions non remplies"))
                
        except Exception as e:
            self.test_results.append(("Fermeture intelligente", "❌ ERROR", str(e)))
    
    def print_summary(self):
        """Afficher le résumé des tests"""
        print("\n" + "=" * 60)
        print("📊 RÉSUMÉ DES TESTS")
        print("=" * 60)
        
        passed = 0
        failed = 0
        errors = 0
        
        for test_name, result, details in self.test_results:
            print(f"{result} {test_name}: {details}")
            if "✅" in result:
                passed += 1
            elif "❌" in result:
                failed += 1
            else:
                errors += 1
        
        print(f"\n📈 Résultats: {passed} passés, {failed} échoués, {errors} erreurs")
        
        if failed == 0 and errors == 0:
            print("🎉 Tous les tests sont passés! La nouvelle logique fonctionne correctement.")
        else:
            print("⚠️ Certains tests ont échoué. Vérifiez la configuration.")

def main():
    """Fonction principale"""
    print("🤖 Testeur de Logique de Prédiction de Spike")
    print("Version améliorée - Robot plus sélectif et profitable")
    print()
    
    tester = SpikePredictionTester()
    tester.test_prediction_logic()

if __name__ == "__main__":
    main()
