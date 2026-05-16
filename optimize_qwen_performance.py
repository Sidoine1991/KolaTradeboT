#!/usr/bin/env python3
"""
Script d'optimisation des performances du modèle Qwen pour TradBOT
Réduit les temps de réponse tout en maintenant la qualité des analyses
"""

import os
import json
import time
import requests
from typing import Dict, Any, Optional

class QwenOptimizer:
    def __init__(self):
        self.ollama_url = os.getenv("OLLAMA_URL", "http://localhost:11434/api/generate")
        self.model_name = os.getenv("OLLAMA_MODEL", "qwen3.5:4b")
        
    def test_current_performance(self) -> Dict[str, float]:
        """Test les performances actuelles du modèle"""
        print("🔍 Test des performances actuelles...")
        
        test_prompt = "Analyse EURUSD: RSI=65, MACD=0.002, ATR=0.0015, Spread=0.0001. Donne une analyse rapide."
        
        start_time = time.time()
        response = self._call_ollama(test_prompt, timeout=60)
        end_time = time.time()
        
        return {
            "response_time": end_time - start_time,
            "success": response is not None,
            "response_length": len(response) if response else 0
        }
    
    def _call_ollama(self, prompt: str, timeout: int = 30) -> Optional[str]:
        """Appel Ollama avec paramètres par défaut"""
        try:
            payload = {
                "model": self.model_name,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": 0.3,
                    "num_predict": 800,
                }
            }
            resp = requests.post(self.ollama_url, json=payload, timeout=timeout)
            if resp.status_code == 200:
                data = resp.json()
                return data.get("response", "")
            return None
        except Exception:
            return None
    
    def test_optimized_configs(self) -> Dict[str, Any]:
        """Test différentes configurations pour trouver la plus rapide"""
        print("⚡ Test des configurations optimisées...")
        
        configs = [
            {
                "name": "Ultra-Rapide",
                "options": {
                    "temperature": 0.1,
                    "num_predict": 200,  # Réduit de 800 à 200
                    "top_k": 10,
                    "top_p": 0.9,
                    "repeat_penalty": 1.1
                },
                "timeout": 15
            },
            {
                "name": "Équilibré",
                "options": {
                    "temperature": 0.2,
                    "num_predict": 400,  # Moitié de la valeur par défaut
                    "top_k": 20,
                    "top_p": 0.95,
                    "repeat_penalty": 1.15
                },
                "timeout": 25
            },
            {
                "name": "Qualité-Speed",
                "options": {
                    "temperature": 0.3,
                    "num_predict": 600,  # 25% de réduction
                    "top_k": 30,
                    "top_p": 0.95,
                    "repeat_penalty": 1.2
                },
                "timeout": 35
            }
        ]
        
        test_prompt = "EURUSD RSI=65 MACD=0.002 ATR=0.0015. Analyse rapide: sentiment(BULLISH/BEARISH/NEUTRAL), action(BUY/SELL/HOLD), confiance(0-100%)."
        
        results = {}
        for config in configs:
            print(f"  Test configuration: {config['name']}")
            
            start_time = time.time()
            response = self._call_ollama_optimized(test_prompt, config["options"], config["timeout"])
            end_time = time.time()
            
            results[config['name']] = {
                "response_time": end_time - start_time,
                "success": response is not None,
                "response_length": len(response) if response else 0,
                "config": config["options"]
            }
            
            time.sleep(1)  # Pause entre les tests
        
        return results
    
    def _call_ollama_optimized(self, prompt: str, options: Dict[str, Any], timeout: int) -> Optional[str]:
        """Appel Ollama avec configuration optimisée"""
        try:
            payload = {
                "model": self.model_name,
                "prompt": prompt,
                "stream": False,
                "options": options
            }
            resp = requests.post(self.ollama_url, json=payload, timeout=timeout)
            if resp.status_code == 200:
                data = resp.json()
                return data.get("response", "")
            return None
        except Exception:
            return None
    
    def generate_optimized_config(self) -> Dict[str, Any]:
        """Génère la configuration optimisée recommandée"""
        return {
            "OLLAMA_TIMEOUT": "20",  # Réduit de 60 à 20 secondes
            "OLLAMA_OPTIONS": {
                "temperature": 0.2,
                "num_predict": 400,  # Réduit de 800 à 400 tokens
                "top_k": 20,
                "top_p": 0.95,
                "repeat_penalty": 1.15,
                "num_ctx": 2048,  # Contexte réduit pour plus de vitesse
                "seed": 42  # Pour reproductibilité
            }
        }
    
    def create_optimized_prompt_template(self) -> str:
        """Crée un template de prompt optimisé pour la vitesse"""
        return """Analyse {symbol} {timeframe}: RSI={rsi} MACD={macd} ATR={atr} Spread={spread}.
Format JSON obligatoire:
{{"sentiment":"BULLISH/BEARISH/NEUTRAL","action":"BUY/SELL/HOLD","confidence":85,"reasoning":"court"}}"""
    
    def update_ai_server_config(self) -> bool:
        """Met à jour la configuration dans ai_server.py"""
        try:
            with open("ai_server.py", "r", encoding="utf-8") as f:
                content = f.read()
            
            # Backup du fichier original
            with open("ai_server.py.backup", "w", encoding="utf-8") as f:
                f.write(content)
            
            # Remplacer les paramètres de _call_ollama_local
            old_options = '''"options": {
                "temperature": 0.3,
                "num_predict": 800,
            }'''
            
            new_options = '''"options": {
                "temperature": 0.2,
                "num_predict": 400,
                "top_k": 20,
                "top_p": 0.95,
                "repeat_penalty": 1.15,
                "num_ctx": 2048
            }'''
            
            if old_options in content:
                content = content.replace(old_options, new_options)
                
                with open("ai_server.py", "w", encoding="utf-8") as f:
                    f.write(content)
                
                print("✅ ai_server.py optimisé avec succès")
                return True
            else:
                print("⚠️ Options non trouvées dans ai_server.py")
                return False
                
        except Exception as e:
            print(f"❌ Erreur lors de la mise à jour: {e}")
            return False
    
    def run_performance_test(self) -> Dict[str, Any]:
        """Exécute le test complet de performance"""
        print("🚀 Lancement du test de performance Qwen")
        print("=" * 50)
        
        # Test actuel
        current_perf = self.test_current_performance()
        print(f"⏱️ Temps de réponse actuel: {current_perf['response_time']:.2f}s")
        
        # Test configurations optimisées
        optimized_results = self.test_optimized_configs()
        
        # Analyse des résultats
        print("\n📊 RÉSULTATS DES TESTS:")
        print("=" * 50)
        
        best_config = None
        best_time = float('inf')
        
        for name, result in optimized_results.items():
            time_taken = result['response_time']
            print(f"{name}: {time_taken:.2f}s ({'✅' if result['success'] else '❌'})")
            
            if result['success'] and time_taken < best_time:
                best_time = time_taken
                best_config = name
        
        improvement = ((current_perf['response_time'] - best_time) / current_perf['response_time']) * 100
        
        print(f"\n🎉 Meilleure configuration: {best_config}")
        print(f"⚡ Amélioration: {improvement:.1f}% plus rapide")
        print(f"🕐 Temps réduit: {current_perf['response_time']:.2f}s → {best_time:.2f}s")
        
        return {
            "current_performance": current_perf,
            "optimized_results": optimized_results,
            "best_config": best_config,
            "improvement_percent": improvement,
            "recommended_config": self.generate_optimized_config()
        }

def main():
    optimizer = QwenOptimizer()
    
    # Exécuter les tests
    results = optimizer.run_performance_test()
    
    # Proposer l'application des optimisations
    print(f"\n🔧 Appliquer les optimisations?")
    print("1. Mettre à jour ai_server.py avec la meilleure configuration")
    print("2. Créer un fichier .env.optimized")
    print("3. Afficher uniquement les recommandations")
    
    choice = input("\nChoix (1-3): ").strip()
    
    if choice == "1":
        if optimizer.update_ai_server_config():
            print("✅ Configuration appliquée avec succès!")
        else:
            print("❌ Échec de l'application")
    elif choice == "2":
        config = results["recommended_config"]
        with open(".env.optimized", "w") as f:
            f.write("# Configuration optimisée Qwen\n")
            f.write(f"OLLAMA_TIMEOUT={config['OLLAMA_TIMEOUT']}\n")
            f.write(f"OLLAMA_OPTIONS={json.dumps(config['OLLAMA_OPTIONS'])}\n")
        print("✅ Fichier .env.optimized créé!")
    else:
        print("\n📋 RECOMMANDATIONS:")
        print(f"• Utiliser timeout: {results['recommended_config']['OLLAMA_TIMEOUT']}s")
        print("• Réduire num_predict à 400 tokens")
        print("• Ajouter top_k=20, top_p=0.95")
        print("• Utiliser temperature=0.2 pour plus de cohérence")

if __name__ == "__main__":
    main()
