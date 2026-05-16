#!/usr/bin/env python3
"""
Configuration ultra-rapide pour Qwen - Temps de réponse < 10s
Paramètres agressifs pour trading en temps réel
"""

import os
import json
import time
import requests
from typing import Dict, Any, Optional

class QwenUltraFast:
    def __init__(self):
        self.ollama_url = os.getenv("OLLAMA_URL", "http://localhost:11434/api/generate")
        self.model_name = os.getenv("OLLAMA_MODEL", "qwen3.5:4b")
        
    def get_ultra_fast_config(self) -> Dict[str, Any]:
        """Configuration ultra-rapide pour trading"""
        return {
            "temperature": 0.1,          # Minimum de variabilité
            "num_predict": 100,          # Très court - uniquement les décisions
            "top_k": 5,                  # Peu de choix
            "top_p": 0.8,                # Décisions rapides
            "repeat_penalty": 1.05,      # Léger penalty
            "num_ctx": 512,              # Contexte minimal
            "seed": 42,                  # Reproductible
            "stop": ["\n\n", "###", "---"]  # Arrêt rapide
        }
    
    def get_trading_prompt_template(self) -> str:
        """Template ultra-concis pour trading"""
        return """{symbol} {timeframe}: RSI={rsi} MACD={macd} ATR={atr}
Décision: BUY/SELL/HOLD | Confiance: 0-100 | Raison: 5 mots max"""
    
    def test_ultra_fast(self) -> Dict[str, Any]:
        """Test la configuration ultra-rapide"""
        print("⚡ Test configuration ULTRA-FAST...")
        
        config = self.get_ultra_fast_config()
        prompt = self.get_trading_prompt_template().format(
            symbol="EURUSD", timeframe="M5", rsi=65, macd=0.002, atr=0.0015
        )
        
        start_time = time.time()
        response = self._call_ollama(prompt, config, timeout=10)
        end_time = time.time()
        
        return {
            "response_time": end_time - start_time,
            "success": response is not None,
            "response": response,
            "config": config
        }
    
    def _call_ollama(self, prompt: str, options: Dict[str, Any], timeout: int = 10) -> Optional[str]:
        """Appel Ollama avec configuration ultra-rapide"""
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
                return data.get("response", "").strip()
            return None
        except Exception as e:
            print(f"❌ Erreur: {e}")
            return None
    
    def create_optimized_env_file(self):
        """Crée le fichier .env.ultra_fast"""
        config = self.get_ultra_fast_config()
        
        env_content = f"""# Configuration ULTRA-FAST Qwen pour TradBOT
# Temps de réponse cible: < 10s

OLLAMA_TIMEOUT=10
OLLAMA_MODEL=qwen3.5:4b
OLLAMA_OPTIONS={json.dumps(config, indent=2)}

# Template de prompt optimisé
TRADING_PROMPT_TEMPLATE={self.get_trading_prompt_template()}
"""
        
        with open(".env.ultra_fast", "w", encoding="utf-8") as f:
            f.write(env_content)
        
        print("✅ Fichier .env.ultra_fast créé")
    
    def update_ai_server_ultra_fast(self) -> bool:
        """Met à jour ai_server.py avec config ultra-rapide"""
        try:
            with open("ai_server.py", "r", encoding="utf-8") as f:
                content = f.read()
            
            # Sauvegarde
            with open("ai_server.py.ultra_backup", "w", encoding="utf-8") as f:
                f.write(content)
            
            # Remplacer la fonction _call_ollama_local
            old_function = '''def _call_ollama_local(self, prompt: str, timeout: int = 60) -> Optional[str]:
        """Appel au modèle local Ollama avec fallback"""
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
        except Exception as e:
            logger.warning(f"❌ Erreur Ollama local: {e}")
            return None'''
            
            new_function = '''def _call_ollama_local(self, prompt: str, timeout: int = 10) -> Optional[str]:
        """Appel au modèle local Ollama ultra-rapide"""
        try:
            # Configuration ultra-rapide
            options = {
                "temperature": 0.1,
                "num_predict": 100,
                "top_k": 5,
                "top_p": 0.8,
                "repeat_penalty": 1.05,
                "num_ctx": 512,
                "seed": 42,
                "stop": ["\\n\\n", "###", "---"]
            }
            
            payload = {
                "model": self.model_name,
                "prompt": prompt,
                "stream": False,
                "options": options
            }
            resp = requests.post(self.ollama_url, json=payload, timeout=timeout)
            if resp.status_code == 200:
                data = resp.json()
                return data.get("response", "").strip()
            return None
        except Exception as e:
            logger.warning(f"❌ Erreur Ollama ultra-fast: {e}")
            return None'''
            
            if old_function in content:
                content = content.replace(old_function, new_function)
                
                with open("ai_server.py", "w", encoding="utf-8") as f:
                    f.write(content)
                
                print("✅ ai_server.py mis à jour en mode ULTRA-FAST")
                return True
            else:
                print("⚠️ Fonction _call_ollama_local non trouvée")
                return False
                
        except Exception as e:
            print(f"❌ Erreur mise à jour: {e}")
            return False

def main():
    optimizer = QwenUltraFast()
    
    print("🚀 CONFIGURATION ULTRA-FAST QWEN")
    print("=" * 50)
    
    # Test
    result = optimizer.test_ultra_fast()
    
    print(f"⏱️ Temps de réponse: {result['response_time']:.2f}s")
    print(f"✅ Succès: {result['success']}")
    if result['response']:
        print(f"📝 Réponse: {result['response']}")
    
    if result['success'] and result['response_time'] < 15:
        print("\n🎉 Configuration ultra-rapide validée!")
        
        choice = input("\nAppliquer les optimisations? (1=Oui, 2=Seulement .env): ").strip()
        
        if choice == "1":
            optimizer.update_ai_server_ultra_fast()
            optimizer.create_optimized_env_file()
            print("✅ Optimisations appliquées!")
        elif choice == "2":
            optimizer.create_optimized_env_file()
            print("✅ Fichier .env.ultra_fast créé!")
    else:
        print("\n❌ La configuration a échoué ou est trop lente")
        print("Vérifiez qu'Ollama fonctionne correctement")

if __name__ == "__main__":
    main()
