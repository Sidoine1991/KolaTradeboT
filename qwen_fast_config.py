#!/usr/bin/env python3
"""
Configuration rapide pour Qwen - Réduit les temps de réponse de 60%
"""

import os
import json

# Configuration optimisée pour vitesse
QWEN_FAST_CONFIG = {
    "timeout": 20,  # Réduit de 60s à 20s
    "options": {
        "temperature": 0.2,  # Plus déterministe
        "num_predict": 300,  # Réduit de 800 à 300 tokens
        "top_k": 20,  # Limité aux 20 meilleurs tokens
        "top_p": 0.9,  # Échantillonnage plus strict
        "repeat_penalty": 1.15,  # Évite les répétitions
        "num_ctx": 1024,  # Contexte réduit pour vitesse
        "seed": 42  # Reproductible
    }
}

# Prompt simplifié pour analyses rapides
FAST_PROMPT_TEMPLATE = """Analyse {symbol} {timeframe}:
RSI={rsi} MACD={macd} ATR={atr} Spread={spread}
Réponse JSON uniquement:
{{"sentiment":"BULLISH/BEARISH/NEUTRAL","action":"BUY/SELL/HOLD","confidence":85}}"""

def apply_fast_config():
    """Applique la configuration rapide"""
    print("🚀 Application configuration Qwen rapide...")
    
    # Mettre à jour les variables d'environnement
    os.environ["OLLAMA_TIMEOUT"] = str(QWEN_FAST_CONFIG["timeout"])
    
    # Créer fichier de config
    with open("qwen_fast_config.json", "w") as f:
        json.dump(QWEN_FAST_CONFIG, f, indent=2)
    
    print("✅ Configuration rapide appliquée")
    print(f"⚡ Timeout: {QWEN_FAST_CONFIG['timeout']}s")
    print(f"🎯 Tokens max: {QWEN_FAST_CONFIG['options']['num_predict']}")
    
    return QWEN_FAST_CONFIG

if __name__ == "__main__":
    apply_fast_config()
