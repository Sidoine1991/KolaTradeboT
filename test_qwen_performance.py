#!/usr/bin/env python3
"""
Test de performance pour vérifier l'optimisation Qwen
"""

import time
import requests
import json
import os

def test_qwen_performance():
    """Test les temps de réponse avant/après optimisation"""
    
    ollama_url = os.getenv("OLLAMA_URL", "http://localhost:11434/api/generate")
    model_name = os.getenv("OLLAMA_MODEL", "qwen3.5:4b")
    
    # Test prompt simple
    test_prompt = "Analyse EURUSD: RSI=65, MACD=0.002, ATR=0.0015. Donne sentiment(BULLISH/BEARISH/NEUTRAL) et action(BUY/SELL/HOLD)."
    
    configs = [
        {
            "name": "Ancienne config",
            "options": {
                "temperature": 0.3,
                "num_predict": 800,
            },
            "timeout": 60
        },
        {
            "name": "Nouvelle config optimisée",
            "options": {
                "temperature": 0.2,
                "num_predict": 300,
                "top_k": 20,
                "top_p": 0.9,
                "repeat_penalty": 1.15,
                "num_ctx": 1024,
                "seed": 42
            },
            "timeout": 20
        }
    ]
    
    print("🚀 Test de performance Qwen")
    print("=" * 40)
    
    for config in configs:
        print(f"\n📊 Test: {config['name']}")
        
        payload = {
            "model": model_name,
            "prompt": test_prompt,
            "stream": False,
            "options": config["options"]
        }
        
        start_time = time.time()
        try:
            response = requests.post(ollama_url, json=payload, timeout=config["timeout"])
            end_time = time.time()
            
            if response.status_code == 200:
                result = response.json()
                response_time = end_time - start_time
                response_length = len(result.get('response', ''))
                
                print(f"⚡ Temps: {response_time:.2f}s")
                print(f"📝 Longueur: {response_length} caractères")
                print(f"✅ Succès: {response.status_code}")
                print(f"🎯 Réponse: {result.get('response', '')[:100]}...")
            else:
                print(f"❌ Erreur: {response.status_code}")
                
        except Exception as e:
            print(f"❌ Exception: {e}")
    
    print(f"\n🎉 Test terminé!")

if __name__ == "__main__":
    test_qwen_performance()
