#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ollama Client pour TradBOT
===========================
Client pour utiliser les modèles Ollama locaux en complément de Claude Code.
Supporte: qwen3.5:4b, glm-ocr:latest, gpt-oss:20b
"""

import os
import json
import logging
import requests
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger("tradbot_ai.ollama")


@dataclass
class OllamaConfig:
    """Configuration Ollama."""
    host: str = "http://localhost:11434"
    timeout: int = 30
    default_model: str = "qwen3.5:4b"
    enabled: bool = False


class OllamaClient:
    """Client Ollama pour les modèles locaux."""
    
    def __init__(self, config: Optional[OllamaConfig] = None):
        self.config = config or OllamaConfig()
        self.available_models = []
        self._check_availability()
    
    def _check_availability(self):
        """Vérifie si Ollama est disponible et liste les modèles."""
        try:
            response = requests.get(f"{self.config.host}/api/tags", timeout=5)
            if response.status_code == 200:
                data = response.json()
                self.available_models = [m["name"] for m in data.get("models", [])]
                self.config.enabled = True
                logger.info(f"✅ Ollama disponible - {len(self.available_models)} modèles: {self.available_models}")
            else:
                self.config.enabled = False
                logger.warning(f"⚠️ Ollama non disponible (status {response.status_code})")
        except Exception as e:
            self.config.enabled = False
            logger.warning(f"⚠️ Ollama non connecté: {e}")
    
    def is_available(self) -> bool:
        """Vérifie si Ollama est disponible."""
        return self.config.enabled
    
    def get_models(self) -> List[str]:
        """Retourne la liste des modèles disponibles."""
        return self.available_models
    
    def generate(
        self,
        prompt: str,
        model: Optional[str] = None,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        stream: bool = False
    ) -> Dict[str, Any]:
        """
        Génère une réponse avec Ollama.
        
        Args:
            prompt: Prompt utilisateur
            model: Modèle à utiliser (défaut: config.default_model)
            system_prompt: Prompt système optionnel
            temperature: Température (0.0-1.0)
            max_tokens: Nombre max de tokens
            stream: Streaming
            
        Returns:
            Dict avec 'text', 'model', 'duration', etc.
        """
        if not self.config.enabled:
            return {
                "success": False,
                "error": "Ollama non disponible",
                "text": None
            }
        
        model = model or self.config.default_model
        if model not in self.available_models:
            logger.warning(f"Modèle {model} non disponible, utilisation de {self.available_models[0] if self.available_models else self.config.default_model}")
            model = self.available_models[0] if self.available_models else self.config.default_model
        
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": stream,
            "options": {
                "temperature": temperature,
            }
        }
        
        if system_prompt:
            payload["system"] = system_prompt
        
        if max_tokens:
            payload["options"]["num_predict"] = max_tokens
        
        try:
            response = requests.post(
                f"{self.config.host}/api/generate",
                json=payload,
                timeout=self.config.timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                return {
                    "success": True,
                    "text": result.get("response", ""),
                    "model": result.get("model", model),
                    "duration": result.get("total_duration", 0) / 1e9,  # ns to s
                    "eval_count": result.get("eval_count", 0),
                    "prompt_eval_count": result.get("prompt_eval_count", 0),
                }
            else:
                logger.error(f"Ollama error {response.status_code}: {response.text}")
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}",
                    "text": None
                }
        except Exception as e:
            logger.error(f"Ollama generation error: {e}")
            return {
                "success": False,
                "error": str(e),
                "text": None
            }
    
    def chat(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Chat avec Ollama (format messages).
        
        Args:
            messages: Liste de messages [{"role": "user|system", "content": "..."}]
            model: Modèle à utiliser
            temperature: Température
            max_tokens: Nombre max de tokens
            
        Returns:
            Dict avec 'text', 'model', etc.
        """
        if not self.config.enabled:
            return {
                "success": False,
                "error": "Ollama non disponible",
                "text": None
            }
        
        model = model or self.config.default_model
        if model not in self.available_models:
            model = self.available_models[0] if self.available_models else self.config.default_model
        
        payload = {
            "model": model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": temperature,
            }
        }
        
        if max_tokens:
            payload["options"]["num_predict"] = max_tokens
        
        try:
            response = requests.post(
                f"{self.config.host}/api/chat",
                json=payload,
                timeout=self.config.timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                return {
                    "success": True,
                    "text": result.get("message", {}).get("content", ""),
                    "model": result.get("model", model),
                    "duration": result.get("total_duration", 0) / 1e9,
                }
            else:
                logger.error(f"Ollama chat error {response.status_code}: {response.text}")
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}",
                    "text": None
                }
        except Exception as e:
            logger.error(f"Ollama chat error: {e}")
            return {
                "success": False,
                "error": str(e),
                "text": None
            }


# Instance globale
_ollama_client: Optional[OllamaClient] = None
OLLAMA_AVAILABLE = False


def init_ollama_client() -> OllamaClient:
    """Initialise le client Ollama depuis les variables d'environnement."""
    global _ollama_client, OLLAMA_AVAILABLE
    
    if _ollama_client is not None:
        return _ollama_client
    
    config = OllamaConfig(
        host=os.getenv("OLLAMA_HOST", "http://localhost:11434"),
        timeout=int(os.getenv("OLLAMA_TIMEOUT", "30")),
        default_model=os.getenv("OLLAMA_DEFAULT_MODEL", "qwen3.5:4b"),
    )
    
    _ollama_client = OllamaClient(config)
    OLLAMA_AVAILABLE = _ollama_client.is_available()
    
    return _ollama_client


def get_ollama_client() -> Optional[OllamaClient]:
    """Retourne le client Ollama initialisé."""
    return _ollama_client


def analyze_trading_with_ollama(
    symbol: str,
    price: float,
    indicators: Dict[str, Any],
    model: Optional[str] = None
) -> Dict[str, Any]:
    """
    Analyse de trading avec Ollama.
    
    Args:
        symbol: Symbole de trading
        price: Prix actuel
        indicators: Dictionnaire d'indicateurs techniques
        model: Modèle Ollama à utiliser
        
    Returns:
        Dict avec action, confidence, reason
    """
    client = get_ollama_client()
    if not client or not client.is_available():
        return {
            "success": False,
            "action": "hold",
            "confidence": 0.0,
            "reason": "Ollama non disponible"
        }
    
    # Construire le prompt
    prompt = f"""Analyse trading pour {symbol}:

Prix actuel: {price:.5f}

Indicateurs techniques:
"""
    for key, value in indicators.items():
        if isinstance(value, (int, float)):
            prompt += f"- {key}: {value:.2f}\n"
        else:
            prompt += f"- {key}: {value}\n"
    
    prompt += """
Donne ta recommandation au format JSON:
{
    "action": "BUY/SELL/HOLD",
    "confidence": 0.00,
    "reason": "raison courte (1-2 phrases)",
    "stop_loss": 0.00000,
    "take_profit": 0.00000
}
"""
    
    result = client.generate(
        prompt=prompt,
        model=model,
        temperature=0.3  # Plus basse pour plus de précision
    )
    
    if result["success"]:
        try:
            # Extraire le JSON de la réponse
            text = result["text"]
            # Nettoyer le texte pour extraire le JSON
            if "```json" in text:
                text = text.split("```json")[1].split("```")[0].strip()
            elif "```" in text:
                text = text.split("```")[1].split("```")[0].strip()
            
            analysis = json.loads(text)
            return {
                "success": True,
                "action": analysis.get("action", "hold").upper(),
                "confidence": float(analysis.get("confidence", 0.5)),
                "reason": analysis.get("reason", ""),
                "stop_loss": float(analysis.get("stop_loss", 0.0)),
                "take_profit": float(analysis.get("take_profit", 0.0)),
                "model": result["model"],
                "duration": result["duration"]
            }
        except Exception as e:
            logger.error(f"Erreur parsing Ollama response: {e}")
            return {
                "success": False,
                "action": "hold",
                "confidence": 0.0,
                "reason": f"Erreur parsing: {str(e)}"
            }
    else:
        return {
            "success": False,
            "action": "hold",
            "confidence": 0.0,
            "reason": result.get("error", "Erreur inconnue")
        }


if __name__ == "__main__":
    # Test simple
    logging.basicConfig(level=logging.INFO)
    
    client = init_ollama_client()
    
    if client.is_available():
        print(f"✅ Ollama connecté - Modèles: {client.get_models()}")
        
        # Test simple
        result = client.generate("Bonjour, qui es-tu?")
        print(f"Réponse: {result}")
        
        # Test trading
        indicators = {
            "RSI": 65.5,
            "EMA_20": 1.0850,
            "EMA_50": 1.0840,
            "ATR": 0.0015
        }
        trading_result = analyze_trading_with_ollama("EURUSD", 1.0855, indicators)
        print(f"Analyse trading: {trading_result}")
    else:
        print("❌ Ollama non disponible")
