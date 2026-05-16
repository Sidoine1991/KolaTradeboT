#!/usr/bin/env python3
"""
Solution d'urgence pour Qwen - Diagnostic et réparation rapide
"""

import os
import json
import time
import requests
import subprocess
from typing import Dict, Any, Optional

class QwenEmergencyFix:
    def __init__(self):
        self.ollama_url = "http://localhost:11434/api/generate"
        self.model_name = "qwen3.5:4b"
        
    def diagnose_ollama(self) -> Dict[str, Any]:
        """Diagnostic complet d'Ollama"""
        print("🔍 DIAGNOSTIC OLLAMA")
        print("=" * 40)
        
        diagnosis = {}
        
        # 1. Vérifier si Ollama tourne
        try:
            resp = requests.get("http://localhost:11434/api/tags", timeout=5)
            diagnosis["ollama_running"] = resp.status_code == 200
            diagnosis["models_available"] = len(resp.json().get("models", [])) if resp.status_code == 200 else 0
        except:
            diagnosis["ollama_running"] = False
            diagnosis["models_available"] = 0
        
        # 2. Vérifier la mémoire
        try:
            result = subprocess.run(["wmic", "computersystem", "get", "TotalPhysicalMemory"], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                memory_line = [line for line in result.stdout.split('\n') if line.strip() and 'Total' not in line]
                if memory_line:
                    memory_gb = int(memory_line[0].strip()) // (1024**3)
                    diagnosis["memory_gb"] = memory_gb
                    diagnosis["memory_sufficient"] = memory_gb >= 8
        except:
            diagnosis["memory_gb"] = "Unknown"
            diagnosis["memory_sufficient"] = False
        
        # 3. Test de requête simple
        diagnosis["simple_test"] = self.test_simple_request()
        
        return diagnosis
    
    def test_simple_request(self) -> Dict[str, Any]:
        """Test avec requête minimale"""
        try:
            payload = {
                "model": self.model_name,
                "prompt": "Hi",
                "stream": False,
                "options": {
                    "num_predict": 5,
                    "temperature": 0.1
                }
            }
            
            start = time.time()
            resp = requests.post(self.ollama_url, json=payload, timeout=30)
            end = time.time()
            
            return {
                "success": resp.status_code == 200,
                "response_time": end - start,
                "response": resp.json().get("response", "") if resp.status_code == 200 else None,
                "error": None if resp.status_code == 200 else f"HTTP {resp.status_code}"
            }
        except Exception as e:
            return {
                "success": False,
                "response_time": 30,
                "response": None,
                "error": str(e)
            }
    
    def restart_ollama(self) -> bool:
        """Redémarre Ollama avec paramètres optimisés"""
        print("🔄 Redémarrage d'Ollama avec paramètres optimisés...")
        
        try:
            # Arrêter Ollama
            subprocess.run(["taskkill", "/F", "/IM", "ollama.exe"], capture_output=True)
            time.sleep(2)
            
            # Démarrer avec moins de mémoire
            cmd = ['ollama', 'serve']
            env = os.environ.copy()
            env['OLLAMA_MAX_LOADED_MODELS'] = '1'
            env['OLLAMA_NUM_PARALLEL'] = '1'
            
            # Démarrer en arrière-plan
            subprocess.Popen(cmd, env=env, creationflags=subprocess.CREATE_NEW_CONSOLE)
            
            time.sleep(5)
            return True
        except Exception as e:
            print(f"❌ Erreur redémarrage: {e}")
            return False
    
    def create_emergency_config(self) -> str:
        """Crée configuration d'urgence"""
        config = {
            "OLLAMA_TIMEOUT": "30",
            "OLLAMA_MODEL": "qwen3.5:4b",
            "OLLAMA_EMERGENCY_MODE": "true",
            "OLLAMA_OPTIONS": {
                "temperature": 0.0,
                "num_predict": 50,
                "top_k": 1,
                "top_p": 0.5,
                "repeat_penalty": 1.0,
                "num_ctx": 256,
                "seed": 42
            }
        }
        
        env_content = """# Configuration d'urgence Qwen
# Mode dégradé pour temps de réponse minimal

OLLAMA_TIMEOUT=30
OLLAMA_MODEL=qwen3.5:4b
OLLAMA_EMERGENCY_MODE=true
OLLAMA_OPTIONS={"temperature": 0.0, "num_predict": 50, "top_k": 1, "top_p": 0.5, "repeat_penalty": 1.0, "num_ctx": 256, "seed": 42}
"""
        
        with open(".env.emergency", "w") as f:
            f.write(env_content)
        
        return ".env.emergency"
    
    def create_emergency_prompt_function(self) -> str:
        """Crée fonction de prompt d'urgence"""
        return '''
def get_emergency_trading_signal(symbol, rsi, macd, atr):
    """Génère signal trading ultra-rapide en mode dégradé"""
    
    # Règles simples sans IA
    rsi = float(rsi)
    macd = float(macd)
    
    if rsi > 70 and macd > 0:
        return {"signal": "SELL", "confidence": 75, "reason": "RSI overbought"}
    elif rsi < 30 and macd < 0:
        return {"signal": "BUY", "confidence": 75, "reason": "RSI oversold"}
    elif rsi > 60:
        return {"signal": "HOLD", "confidence": 60, "reason": "RSI high"}
    elif rsi < 40:
        return {"signal": "HOLD", "confidence": 60, "reason": "RSI low"}
    else:
        return {"signal": "HOLD", "confidence": 50, "reason": "Neutral"}
'''
    
    def apply_emergency_fix(self) -> bool:
        """Applique la solution d'urgence complète"""
        print("🚨 APPLICATION SOLUTION D'URGENCE")
        print("=" * 40)
        
        # 1. Diagnostic
        diagnosis = self.diagnose_ollama()
        
        print(f"📊 Ollama actif: {diagnosis.get('ollama_running', False)}")
        print(f"📊 Modèles disponibles: {diagnosis.get('models_available', 0)}")
        print(f"📊 Mémoire RAM: {diagnosis.get('memory_gb', 'Unknown')} GB")
        print(f"📊 Test simple: {'✅' if diagnosis.get('simple_test', {}).get('success') else '❌'}")
        
        # 2. Si Ollama ne répond pas, redémarrer
        if not diagnosis.get('simple_test', {}).get('success'):
            print("\n🔄 Tentative de redémarrage...")
            if self.restart_ollama():
                time.sleep(5)
                # Retester
                new_test = self.test_simple_request()
                if new_test['success']:
                    print("✅ Ollama redémarré avec succès")
                else:
                    print("❌ Ollama toujours inaccessible")
        
        # 3. Créer config d'urgence
        config_file = self.create_emergency_config()
        print(f"✅ Fichier {config_file} créé")
        
        # 4. Créer fonction de secours
        emergency_function = self.create_emergency_prompt_function()
        with open("emergency_trading.py", "w") as f:
            f.write(emergency_function)
        print("✅ Fichier emergency_trading.py créé")
        
        return True

def main():
    fixer = QwenEmergencyFix()
    
    print("🚨 SOLUTION D'URGENCE QWEN")
    print("Problème: Temps de réponse > 60s")
    print("Objectif: Temps < 15s ou mode dégradé")
    print("=" * 50)
    
    success = fixer.apply_emergency_fix()
    
    if success:
        print("\n🎯 SOLUTIONS APPLIQUÉES:")
        print("1. ✅ Diagnostic complet effectué")
        print("2. ✅ Redémarrage Ollama si nécessaire")
        print("3. ✅ Configuration d'urgence créée (.env.emergency)")
        print("4. ✅ Fonction de secours créée (emergency_trading.py)")
        print("\n📋 PROCHAINES ÉTAPES:")
        print("- Utiliser .env.emergency pour config actuelle")
        print("- Si Ollama ne répond pas, utiliser emergency_trading.get_emergency_trading_signal()")
        print("- Surveiller l'utilisation mémoire (< 8GB recommandé)")

if __name__ == "__main__":
    main()
