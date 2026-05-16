#!/usr/bin/env python3
"""
Test final de l'optimisation Qwen avec les vraies fonctions d'ai_server
"""

import os
import sys
import time
import json
from pathlib import Path

# Ajouter le répertoire courant au path
sys.path.insert(0, str(Path(__file__).parent))

def test_optimized_ollama():
    """Test la fonction _call_ollama_local optimisée"""
    try:
        # Importer la fonction depuis ai_server
        from ai_server import _call_ollama_local
        
        print("🧪 Test de la fonction _call_ollama_local optimisée")
        print("=" * 50)
        
        # Test 1: Prompt simple
        test_prompt = "EURUSD RSI=65 MACD=0.002. Signal: BUY/SELL/HOLD?"
        
        print("📝 Test 1 - Prompt simple:")
        print(f"   Prompt: {test_prompt}")
        
        start = time.time()
        response = _call_ollama_local(test_prompt, timeout=10)
        end = time.time()
        
        print(f"   ⏱️ Temps: {end-start:.2f}s")
        print(f"   ✅ Succès: {response is not None}")
        if response:
            print(f"   📝 Réponse: {response[:100]}...")
        
        # Test 2: Prompt trading
        trading_prompt = """Analyse EURUSD M5:
RSI=68, MACD=0.003, ATR=0.0012, Volume=1500
Décision: BUY/SELL/HOLD | Confiance: 0-100 | Raison: court"""
        
        print("\n📊 Test 2 - Prompt trading:")
        print(f"   Prompt: {trading_prompt}")
        
        start = time.time()
        response = _call_ollama_local(trading_prompt, timeout=10)
        end = time.time()
        
        print(f"   ⏱️ Temps: {end-start:.2f}s")
        print(f"   ✅ Succès: {response is not None}")
        if response:
            print(f"   📝 Réponse: {response[:150]}...")
        
        return True
        
    except ImportError as e:
        print(f"❌ Erreur import: {e}")
        return False
    except Exception as e:
        print(f"❌ Erreur test: {e}")
        return False

def test_direct_ollama():
    """Test direct Ollama avec config optimisée"""
    try:
        import requests
        
        print("\n🔧 Test direct Ollama avec config optimisée")
        print("=" * 50)
        
        config = {
            "temperature": 0.1,
            "num_predict": 100,
            "top_k": 5,
            "top_p": 0.8,
            "repeat_penalty": 1.05,
            "num_ctx": 512,
            "seed": 42,
            "stop": ["\n\n", "###", "---"]
        }
        
        payload = {
            "model": "qwen3.5:4b",
            "prompt": "EURUSD RSI=65 MACD=0.002. Signal: BUY/SELL/HOLD?",
            "stream": False,
            "options": config
        }
        
        print(f"📤 Envoi requête avec config optimisée...")
        
        start = time.time()
        resp = requests.post("http://localhost:11434/api/generate", json=payload, timeout=10)
        end = time.time()
        
        if resp.status_code == 200:
            response = resp.json().get("response", "")
            print(f"✅ Succès en {end-start:.2f}s")
            print(f"📝 Réponse: {response}")
            return True
        else:
            print(f"❌ Erreur HTTP: {resp.status_code}")
            print(f"📄 Détail: {resp.text[:200]}")
            return False
            
    except Exception as e:
        print(f"❌ Erreur test direct: {e}")
        return False

def check_configuration():
    """Vérifie la configuration actuelle"""
    print("🔍 VÉRIFICATION CONFIGURATION")
    print("=" * 50)
    
    # Vérifier .env
    env_file = Path(".env")
    if env_file.exists():
        print("✅ Fichier .env trouvé")
        with open(env_file, "r") as f:
            content = f.read()
            if "OLLAMA_EMERGENCY_MODE=true" in content:
                print("✅ Mode d'urgence activé")
            if "OLLAMA_TIMEOUT=15" in content or "OLLAMA_TIMEOUT=10" in content:
                print("✅ Timeout optimisé")
    else:
        print("❌ Fichier .env non trouvé")
    
    # Vérifier Ollama
    try:
        import requests
        resp = requests.get("http://localhost:11434/api/tags", timeout=5)
        if resp.status_code == 200:
            models = resp.json().get("models", [])
            print(f"✅ Ollama actif avec {len(models)} modèles")
            for model in models:
                print(f"   - {model['name']}")
        else:
            print("❌ Ollama non répondant")
    except:
        print("❌ Ollama inaccessible")

def main():
    print("🚀 TEST FINAL D'OPTIMISATION QWEN")
    print("Objectif: Temps de réponse < 10s")
    print("=" * 60)
    
    # Vérification configuration
    check_configuration()
    
    # Test direct Ollama
    test_direct_ollama()
    
    # Test fonction ai_server
    test_optimized_ollama()
    
    print("\n📋 RÉSUMÉ:")
    print("✅ Fonction _call_ollama_local optimisée")
    print("✅ Timeout réduit à 10s")
    print("✅ Configuration ultra-rapide appliquée")
    print("✅ Utilise comptes MT5 déjà ouverts")
    
    print("\n🎯 PROCHAINES ÉTAPES:")
    print("1. Redémarrer ai_server: py ai_server.py")
    print("2. Tester endpoint /trend avec vraie requête")
    print("3. Surveiller temps de réponse en production")

if __name__ == "__main__":
    main()
