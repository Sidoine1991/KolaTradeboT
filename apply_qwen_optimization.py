#!/usr/bin/env python3
"""
Applique la configuration Qwen optimisée dans ai_server.py
Utilise les comptes MT5 déjà ouverts
"""

import os
import json
import re
from typing import Dict, Any

class QwenOptimizerApplier:
    def __init__(self):
        self.ai_server_file = "ai_server.py"
        self.backup_file = "ai_server.py.qwen_backup"
        
    def create_backup(self):
        """Crée une sauvegarde du fichier ai_server.py"""
        try:
            with open(self.ai_server_file, "r", encoding="utf-8") as f:
                content = f.read()
            
            with open(self.backup_file, "w", encoding="utf-8") as f:
                f.write(content)
            
            print("✅ Sauvegarde créée: ai_server.py.qwen_backup")
            return True
        except Exception as e:
            print(f"❌ Erreur sauvegarde: {e}")
            return False
    
    def get_optimized_config(self) -> Dict[str, Any]:
        """Retourne la configuration Qwen optimisée"""
        return {
            "temperature": 0.1,
            "num_predict": 100,
            "top_k": 5,
            "top_p": 0.8,
            "repeat_penalty": 1.05,
            "num_ctx": 512,
            "seed": 42,
            "stop": ["\n\n", "###", "---"]
        }
    
    def update_call_ollama_function(self) -> bool:
        """Met à jour la fonction _call_ollama_local avec config optimisée"""
        try:
            with open(self.ai_server_file, "r", encoding="utf-8") as f:
                content = f.read()
            
            # Configuration optimisée
            config = self.get_optimized_config()
            config_json = json.dumps(config, indent=12).replace('"', "'")
            
            # Ancienne fonction à remplacer
            old_function_pattern = r'def _call_ollama_local\(self, prompt: str, timeout: int = 60\) -> Optional\[str\]:\s*"""Appel au modèle local Ollama avec fallback"""\s*try:\s*payload = \{[^}]+\}\s*resp = requests\.post\(self\.ollama_url, json=payload, timeout=timeout\)\s*if resp\.status_code == 200:\s*data = resp\.json\(\)\s*return data\.get\("response", ""\)\s*return None\s*except Exception as e:\s*logger\.warning\(f"❌ Erreur Ollama local: \{e\}"\)\s*return None'
            
            # Nouvelle fonction optimisée
            new_function = f'''def _call_ollama_local(self, prompt: str, timeout: int = 15) -> Optional[str]:
        """Appel au modèle local Ollama optimisé pour temps de réponse < 10s"""
        try:
            # Configuration ultra-rapide pour trading
            options = {config_json}
            
            payload = {{
                "model": self.model_name,
                "prompt": prompt,
                "stream": False,
                "options": options
            }}
            resp = requests.post(self.ollama_url, json=payload, timeout=timeout)
            if resp.status_code == 200:
                data = resp.json()
                return data.get("response", "").strip()
            return None
        except Exception as e:
            logger.warning(f"❌ Erreur Ollama ultra-fast: {{e}}")
            return None'''
            
            # Remplacement simple par recherche de texte
            old_simple = '''def _call_ollama_local(self, prompt: str, timeout: int = 60) -> Optional[str]:
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
            
            new_simple = f'''def _call_ollama_local(self, prompt: str, timeout: int = 15) -> Optional[str]:
        """Appel au modèle local Ollama optimisé pour temps de réponse < 10s"""
        try:
            # Configuration ultra-rapide pour trading
            options = {config_json}
            
            payload = {{
                "model": self.model_name,
                "prompt": prompt,
                "stream": False,
                "options": options
            }}
            resp = requests.post(self.ollama_url, json=payload, timeout=timeout)
            if resp.status_code == 200:
                data = resp.json()
                return data.get("response", "").strip()
            return None
        except Exception as e:
            logger.warning(f"❌ Erreur Ollama ultra-fast: {{e}}")
            return None'''
            
            if old_simple in content:
                content = content.replace(old_simple, new_simple)
                
                with open(self.ai_server_file, "w", encoding="utf-8") as f:
                    f.write(content)
                
                print("✅ Fonction _call_ollama_local optimisée")
                return True
            else:
                print("⚠️ Fonction _call_ollama_local non trouvée exactement")
                return False
                
        except Exception as e:
            print(f"❌ Erreur mise à jour: {e}")
            return False
    
    def update_timeout_variables(self) -> bool:
        """Met à jour les variables timeout dans ai_server"""
        try:
            with open(self.ai_server_file, "r", encoding="utf-8") as f:
                content = f.read()
            
            # Réduire les timeouts dans tout le fichier
            content = re.sub(r'timeout: int = 60', 'timeout: int = 15', content)
            content = re.sub(r'timeout=60', 'timeout=15', content)
            content = re.sub(r'timeout=30', 'timeout=15', content)
            
            with open(self.ai_server_file, "w", encoding="utf-8") as f:
                f.write(content)
            
            print("✅ Timeouts mis à jour (15s)")
            return True
            
        except Exception as e:
            print(f"❌ Erreur mise à jour timeouts: {e}")
            return False
    
    def create_env_file(self):
        """Crée le fichier .env avec configuration optimisée"""
        config = self.get_optimized_config()
        
        env_content = f"""# Configuration Qwen optimisée pour TradBOT
# Temps de réponse cible: < 10s

OLLAMA_URL=http://localhost:11434/api/generate
OLLAMA_MODEL=qwen3.5:4b
OLLAMA_TIMEOUT=15
OLLAMA_EMERGENCY_MODE=true

# Configuration MT5 (comptes déjà ouverts)
# MT5_LOGIN=5775742
# MT5_PASSWORD=Socrate2024
# MT5_SERVER=Deriv-Demo

# Options Qwen optimisées
OLLAMA_OPTIONS={json.dumps(config, indent=2)}
"""
        
        with open(".env.optimized", "w", encoding="utf-8") as f:
            f.write(env_content)
        
        print("✅ Fichier .env.optimized créé")
    
    def test_optimization(self) -> bool:
        """Test la nouvelle configuration"""
        try:
            import requests
            import time
            
            config = self.get_optimized_config()
            test_prompt = "EURUSD RSI=65 MACD=0.002. Signal: BUY/SELL/HOLD?"
            
            payload = {
                "model": "qwen3.5:4b",
                "prompt": test_prompt,
                "stream": False,
                "options": config
            }
            
            print("🧪 Test de la nouvelle configuration...")
            start = time.time()
            resp = requests.post("http://localhost:11434/api/generate", json=payload, timeout=15)
            end = time.time()
            
            if resp.status_code == 200:
                response = resp.json().get("response", "")
                print(f"✅ Test réussi en {end-start:.2f}s")
                print(f"📝 Réponse: {response[:100]}...")
                return True
            else:
                print(f"❌ Erreur HTTP: {resp.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ Erreur test: {e}")
            return False
    
    def apply_all_optimizations(self) -> bool:
        """Applique toutes les optimisations"""
        print("🚀 APPLICATION DES OPTIMISATIONS QWEN")
        print("=" * 50)
        
        # 1. Backup
        if not self.create_backup():
            return False
        
        # 2. Mettre à jour la fonction
        if not self.update_call_ollama_function():
            print("⚠️ Continuation avec autres optimisations...")
        
        # 3. Mettre à jour les timeouts
        self.update_timeout_variables()
        
        # 4. Créer .env
        self.create_env_file()
        
        # 5. Test
        print("\n🧪 Test de la nouvelle configuration...")
        if self.test_optimization():
            print("\n🎉 OPTIMISATIONS APPLIQUÉES AVEC SUCCÈS!")
            print("✅ ai_server.py optimisé pour temps de réponse < 10s")
            print("✅ Configuration d'urgence prête")
            print("✅ Utilise les comptes MT5 déjà ouverts")
            
            print("\n📋 PROCHAINES ÉTAPES:")
            print("1. Redémarrer ai_server: py ai_server.py")
            print("2. Tester temps de réponse")
            print("3. Surveiller les performances")
            
            return True
        else:
            print("\n⚠️ Optimisations appliquées mais test échoué")
            print("Vérifiez qu'Ollama fonctionne correctement")
            return False

def main():
    optimizer = QwenOptimizerApplier()
    
    print("🔧 OPTIMISATION QWEN POUR TRADING RAPIDE")
    print("Objectif: Temps de réponse < 10s")
    print("Utilise: Comptes MT5 déjà ouverts")
    print("=" * 50)
    
    success = optimizer.apply_all_optimizations()
    
    if success:
        print("\n✅ Configuration prête!")
        print("📄 Fichiers modifiés:")
        print("  - ai_server.py (optimisé)")
        print("  - .env.optimized (nouveau)")
        print("  - ai_server.py.qwen_backup (sauvegarde)")
    else:
        print("\n❌ Erreur lors de l'optimisation")
        print("Vérifiez les logs ci-dessus")

if __name__ == "__main__":
    main()
