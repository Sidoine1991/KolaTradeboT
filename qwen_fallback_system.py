#!/usr/bin/env python3
"""
Système de fallback complet pour Qwen
Mode dégradé quand Ollama est trop lent
"""

import os
import time
import json
from typing import Dict, Any, Optional
from datetime import datetime

class QwenFallbackSystem:
    def __init__(self):
        self.ollama_timeout = 30  # secondes (augmenté pour éviter les timeouts prématurés)
        self.fallback_mode = False
        self.last_ollama_success = None
        
    def get_emergency_signal(self, symbol: str, rsi: float, macd: float, atr: float, volume: int = 1000) -> Dict[str, Any]:
        """Génère signal trading ultra-rapide sans IA"""
        
        # Règles simples basées sur indicateurs
        signal = "HOLD"
        confidence = 50
        reason = "Neutral market"
        
        # RSI overbought/oversold
        if rsi > 70:
            if macd > 0:
                signal = "SELL"
                confidence = 75
                reason = "RSI overbought + MACD bullish"
            else:
                signal = "SELL"
                confidence = 85
                reason = "RSI overbought + MACD bearish"
        elif rsi < 30:
            if macd < 0:
                signal = "BUY"
                confidence = 75
                reason = "RSI oversold + MACD bearish"
            else:
                signal = "BUY"
                confidence = 85
                reason = "RSI oversold + MACD bullish"
        elif rsi > 60:
            if macd > 0.001:
                signal = "HOLD"
                confidence = 60
                reason = "RSI high but MACD strong"
            else:
                signal = "SELL"
                confidence = 65
                reason = "RSI high + MACD weakening"
        elif rsi < 40:
            if macd < -0.001:
                signal = "HOLD"
                confidence = 60
                reason = "RSI low but MACD weak"
            else:
                signal = "BUY"
                confidence = 65
                reason = "RSI low + MACD strengthening"
        
        # Ajustement basé sur ATR (volatilité)
        if atr > 0.002:  # haute volatilité
            confidence = min(confidence - 10, 90)
            reason += " (high volatility)"
        elif atr < 0.0005:  # basse volatilité
            confidence = min(confidence + 5, 90)
            reason += " (low volatility)"
        
        return {
            "signal": signal,
            "confidence": confidence,
            "reason": reason,
            "mode": "emergency_fallback",
            "timestamp": datetime.now().isoformat(),
            "indicators": {
                "rsi": rsi,
                "macd": macd,
                "atr": atr,
                "volume": volume
            }
        }
    
    def try_ollama_with_fallback(self, prompt: str, symbol: str = "EURUSD") -> Dict[str, Any]:
        """Essaye Ollama, fallback vers règles si timeout"""
        
        # Extraire les indicateurs du prompt
        try:
            rsi = float([x for x in prompt.split() if 'RSI=' in x][0].split('=')[1])
            macd = float([x for x in prompt.split() if 'MACD=' in x][0].split('=')[1])
            atr = float([x for x in prompt.split() if 'ATR=' in x][0].split('=')[1])
        except:
            # Valeurs par défaut si parsing échoue
            rsi, macd, atr = 50, 0, 0.001
        
        # Essayer Ollama
        try:
            import requests
            
            payload = {
                "model": "qwen3.5:4b",
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": 0.1,
                    "num_predict": 50,
                    "top_k": 5,
                    "top_p": 0.8,
                    "repeat_penalty": 1.05,
                    "num_ctx": 512,
                    "seed": 42,
                    "stop": ["\n\n", "###", "---"]
                }
            }
            
            start = time.time()
            resp = requests.post("http://localhost:11434/api/generate", json=payload, timeout=self.ollama_timeout)
            end = time.time()
            
            if resp.status_code == 200 and (end - start) < self.ollama_timeout:
                response = resp.json().get("response", "").strip()
                self.last_ollama_success = datetime.now()
                self.fallback_mode = False
                
                # Parser la réponse Qwen
                return self.parse_qwen_response(response, symbol, rsi, macd, atr)
            else:
                raise Exception("Timeout or error")
                
        except Exception as e:
            print(f"⚠️ Ollama timeout/fallback: {e}")
            self.fallback_mode = True
            
            # Mode d'urgence
            return self.get_emergency_signal(symbol, rsi, macd, atr)
    
    def parse_qwen_response(self, response: str, symbol: str, rsi: float, macd: float, atr: float) -> Dict[str, Any]:
        """Parse la réponse de Qwen en format structuré"""
        
        # Valeurs par défaut
        signal = "HOLD"
        confidence = 50
        reason = response[:100]  # Prendre le début comme raison
        
        # Chercher BUY/SELL/HOLD
        response_upper = response.upper()
        if "BUY" in response_upper:
            signal = "BUY"
        elif "SELL" in response_upper:
            signal = "SELL"
        
        # Chercher un chiffre de confiance
        import re
        confidence_match = re.search(r'(\d{1,3})%', response)
        if confidence_match:
            confidence = int(confidence_match.group(1))
            confidence = max(0, min(100, confidence))  # Clamp 0-100
        
        return {
            "signal": signal,
            "confidence": confidence,
            "reason": reason,
            "mode": "qwen_optimized",
            "timestamp": datetime.now().isoformat(),
            "response": response,
            "indicators": {
                "rsi": rsi,
                "macd": macd,
                "atr": atr
            }
        }
    
    def get_status(self) -> Dict[str, Any]:
        """Retourne le statut du système"""
        return {
            "fallback_mode": self.fallback_mode,
            "last_ollama_success": self.last_ollama_success.isoformat() if self.last_ollama_success else None,
            "ollama_timeout": self.ollama_timeout,
            "status": "operational"
        }

# Instance globale pour utilisation dans ai_server
fallback_system = QwenFallbackSystem()

def get_trading_signal_with_fallback(symbol: str, rsi: float, macd: float, atr: float, volume: int = 1000) -> Dict[str, Any]:
    """Interface simple pour ai_server"""
    
    # Construire prompt
    prompt = f"{symbol} RSI={rsi} MACD={macd} ATR={atr}. Signal: BUY/SELL/HOLD | Confiance: 0-100"
    
    # Appeler avec fallback
    return fallback_system.try_ollama_with_fallback(prompt, symbol)

def main():
    """Test du système de fallback"""
    print("🚨 TEST SYSTÈME FALLBACK QWEN")
    print("=" * 50)
    
    # Test 1: Scénario normal
    print("📊 Test 1 - Scénario normal:")
    result = get_trading_signal_with_fallback("EURUSD", 65, 0.002, 0.0012)
    print(f"   Signal: {result['signal']}")
    print(f"   Confiance: {result['confidence']}%")
    print(f"   Mode: {result['mode']}")
    print(f"   Raison: {result['reason']}")
    
    # Test 2: Scénario overbought
    print("\n📈 Test 2 - Scénario overbought:")
    result = get_trading_signal_with_fallback("EURUSD", 75, 0.003, 0.0015)
    print(f"   Signal: {result['signal']}")
    print(f"   Confiance: {result['confidence']}%")
    print(f"   Mode: {result['mode']}")
    print(f"   Raison: {result['reason']}")
    
    # Test 3: Scénario oversold
    print("\n📉 Test 3 - Scénario oversold:")
    result = get_trading_signal_with_fallback("EURUSD", 25, -0.002, 0.0008)
    print(f"   Signal: {result['signal']}")
    print(f"   Confiance: {result['confidence']}%")
    print(f"   Mode: {result['mode']}")
    print(f"   Raison: {result['reason']}")
    
    # Statut
    print(f"\n📊 Statut système: {fallback_system.get_status()}")
    
    print("\n✅ Système de fallback prêt!")
    print("📋 Intégration dans ai_server:")
    print("   from qwen_fallback_system import get_trading_signal_with_fallback")
    print("   result = get_trading_signal_with_fallback(symbol, rsi, macd, atr)")

if __name__ == "__main__":
    main()
