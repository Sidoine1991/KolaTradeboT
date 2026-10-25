"""
Module de chat basé sur Gemma pour l'analyse de trading
Capture les informations des indicateurs et propose des signaux de trading
"""
import os
import sys
import json
import torch
import streamlit as st
from typing import Dict, List, Any, Optional
from datetime import datetime
import pandas as pd
import numpy as np
from dotenv import load_dotenv

# Ajouter le chemin du modèle Gemma
GEMMA_MODEL_PATH = r"D:\Dev\model_gemma"

# Charger les variables d'environnement depuis le .env du projet
try:
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    dotenv_path = os.path.join(project_root, '.env')
    if os.path.exists(dotenv_path):
        load_dotenv(dotenv_path)
    else:
        load_dotenv()  # fallback: charge depuis CWD si présent
except Exception:
    pass

class GemmaTradingChat:
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.chat_history = []
        self.trading_context = {}
        self.loaded_at: Optional[str] = None
        self.last_error: Optional[str] = None
        self.provider: str = "gemma"  # gemma | gemini | mock
        
    def load_model(self):
        """Charger le modèle Gemma avec gestion optimisée de la mémoire"""
        try:
            # Si déjà chargé (hors mode MOCK), ne rien faire
            if self.model is not None and self.model != "MOCK":
                return True

            from transformers import AutoTokenizer, AutoModelForCausalLM
            
            print(f"🔄 Chargement du modèle Gemma depuis {GEMMA_MODEL_PATH}")
            
            # Charger le tokenizer
            self.tokenizer = AutoTokenizer.from_pretrained(
                GEMMA_MODEL_PATH,
                trust_remote_code=True
            )
            
            # Essayer CUDA 8-bit puis 4-bit si GPU dispo, sinon CPU standard
            loaded = False
            if self.device == "cuda":
                try:
                    # 8-bit quantization
                    print("⚙️ Tentative de chargement 8-bit (bitsandbytes)")
                    self.model = AutoModelForCausalLM.from_pretrained(
                        GEMMA_MODEL_PATH,
                        trust_remote_code=True,
                        load_in_8bit=True,
                        device_map="auto",
                        low_cpu_mem_usage=True,
                        use_safetensors=True
                    )
                    loaded = True
                except Exception as e8:
                    msg = f"8-bit indisponible: {e8}"
                    print(f"ℹ️ {msg}")
                    self.last_error = msg
                    try:
                        # 4-bit quantization
                        print("⚙️ Tentative de chargement 4-bit (bitsandbytes)")
                        try:
                            from transformers import BitsAndBytesConfig
                        except Exception as imp_err:
                            raise RuntimeError(f"BitsAndBytesConfig non disponible: {imp_err}")
                        quant_config = BitsAndBytesConfig(
                            load_in_4bit=True,
                            bnb_4bit_compute_dtype=torch.float16,
                            bnb_4bit_use_double_quant=True,
                            bnb_4bit_quant_type="nf4",
                        )
                        self.model = AutoModelForCausalLM.from_pretrained(
                            GEMMA_MODEL_PATH,
                            trust_remote_code=True,
                            device_map="auto",
                            low_cpu_mem_usage=True,
                            use_safetensors=True,
                            quantization_config=quant_config
                        )
                        loaded = True
                    except Exception as e4:
                        msg = f"4-bit indisponible: {e4}"
                        print(f"ℹ️ {msg}")
                        self.last_error = msg

            if not loaded:
                # CPU path avec offload pour éviter les allocations contiguës massives
                try:
                    print("⚙️ Tentative CPU avec offload disque (accelerate)")
                    from pathlib import Path
                    offload_dir = Path(r"D:\Dev\model_offload")
                    offload_dir.mkdir(parents=True, exist_ok=True)
                    self.model = AutoModelForCausalLM.from_pretrained(
                        GEMMA_MODEL_PATH,
                        torch_dtype=torch.float32,
                        device_map="auto",
                        max_memory={"cpu": "6GiB"},
                        offload_folder=str(offload_dir),
                        trust_remote_code=True,
                        low_cpu_mem_usage=True,
                        use_safetensors=True
                    )
                except Exception as e_off:
                    print(f"ℹ️ CPU offload indisponible: {e_off}")
                    # Dernier recours: CPU direct (peut OOM)
                    self.model = AutoModelForCausalLM.from_pretrained(
                        GEMMA_MODEL_PATH,
                        torch_dtype=torch.float32,
                        device_map=None,
                        trust_remote_code=True,
                        low_cpu_mem_usage=True,
                        use_safetensors=True
                    )
            
            if self.device == "cpu":
                self.model = self.model.to(self.device)
            
            print("✅ Modèle Gemma chargé avec succès")
            self.loaded_at = datetime.now().isoformat()
            self.last_error = None
            self.provider = "gemma"
            return True
            
        except Exception as e:
            print(f"❌ Erreur lors du chargement du modèle Gemma: {e}")
            self.last_error = str(e)
            # Fallback: tenter Gemini Flash si clé API présente
            if self.load_gemini_model():
                print("✅ Fallback Gemini activé (Flash)")
                return True
            print("🔄 Activation du mode fallback (simulation)")
            self.model = "MOCK"  # Mode simulation
            self.tokenizer = "MOCK"
            self.provider = "mock"
            self.loaded_at = datetime.now().isoformat()
            return False
    
    def update_trading_context(self, symbol: str, timeframe: str, data: Dict[str, Any]):
        """Mettre à jour le contexte de trading avec les données actuelles"""
        self.trading_context = {
            "symbol": symbol,
            "timeframe": timeframe,
            "timestamp": datetime.now().isoformat(),
            "current_price": data.get("current_price", 0),
            "indicators": data.get("indicators", {}),
            "ml_signals": data.get("ml_signals", {}),
            "trend_analysis": data.get("trend_analysis", {}),
            "support_resistance": data.get("support_resistance", {}),
            "setup_detection": data.get("setup_detection", {}),
            "volatility": data.get("volatility", {}),
            "volume_analysis": data.get("volume_analysis", {})
        }
    
    def generate_trading_analysis(self, user_question: str = "") -> str:
        """Générer une analyse de trading basée sur le contexte actuel"""
        if getattr(self, "provider", "gemma") == "gemini":
            return self._generate_gemini(user_question)
        if self.model == "MOCK" or self.tokenizer == "MOCK":
            return self._generate_mock_analysis(user_question)
        
        if not self.model or not self.tokenizer:
            return "❌ Modèle Gemma non chargé"
        
        try:
            # Construire le prompt avec le contexte de trading
            prompt = self._build_trading_prompt(user_question)
            
            # Tokeniser le prompt
            inputs = self.tokenizer(prompt, return_tensors="pt").to(self.device)
            
            # Générer la réponse
            with torch.no_grad():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=256,
                    temperature=0.3,
                    do_sample=False,
                    pad_token_id=self.tokenizer.eos_token_id
                )
            
            # Décoder la réponse
            response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            
            # Extraire seulement la partie générée
            if prompt in response:
                response = response[len(prompt):].strip()
            
            return response
            
        except Exception as e:
            return f"❌ Erreur lors de la génération: {str(e)}"

    def load_gemini_model(self) -> bool:
        """Initialiser l'accès au modèle Gemini Flash si clé API disponible."""
        try:
            api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
            if not api_key:
                self.last_error = "GEMINI_API_KEY manquante"
                return False
            try:
                import google.generativeai as genai
            except Exception as imp:
                self.last_error = f"google-generativeai non installé: {imp}"
                return False
            genai.configure(api_key=api_key)
            # Optionnel: ping léger
            try:
                _ = genai.list_models()
            except Exception:
                pass
            self.model = "GEMINI_FLASH"  # tag interne
            self.tokenizer = None
            self.provider = "gemini"
            self.loaded_at = datetime.now().isoformat()
            return True
        except Exception as e:
            self.last_error = str(e)
            return False

    def use_gemini(self) -> bool:
        """Forcer l'utilisation de Gemini si possible (sans tenter Gemma)."""
        if self.load_gemini_model():
            print("✅ Provider basculé sur Gemini (Flash)")
            return True
        return False

    def _generate_gemini(self, user_question: str = "") -> str:
        """Générer via Gemini Flash (API)."""
        try:
            import google.generativeai as genai
            prompt = self._build_trading_prompt(user_question)
            model_name = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
            model = genai.GenerativeModel(model_name)
            resp = model.generate_content(prompt, safety_settings=None)
            text = getattr(resp, "text", None)
            if not text and hasattr(resp, "candidates") and resp.candidates:
                try:
                    text = resp.candidates[0].content.parts[0].text
                except Exception:
                    text = None
            return text or "❌ Réponse vide de l'API Gemini"
        except Exception as e:
            self.last_error = f"Gemini erreur: {e}"
            return self._generate_mock_analysis(user_question)
    
    def _generate_mock_analysis(self, user_question: str = "") -> str:
        """Générer une analyse simulée basée sur les indicateurs"""
        symbol = self.trading_context.get("symbol", "SYMBOL")
        current_price = float(self.trading_context.get("current_price", 0) or 0)
        indicators = self.trading_context.get("indicators", {})
        ml_signals = self.trading_context.get("ml_signals", {})
        
        rsi = float(indicators.get("rsi", 50) or 50)
        direction = ml_signals.get("direction", "HOLD")
        direction_strength = float(ml_signals.get("direction_strength", 0.5) or 0.5)
        
        # Logique de trading basique
        if rsi < 30 and direction == "BUY":
            signal = "BUY"
            confidence = min(85, 60 + direction_strength * 25)
        elif rsi > 70 and direction == "SELL":
            signal = "SELL"
            confidence = min(85, 60 + direction_strength * 25)
        else:
            signal = "HOLD"
            confidence = 35
        
        # Calcul des niveaux
        if signal != "HOLD":
            if signal == "BUY":
                entry_price = current_price * 1.0001  # Légèrement au-dessus
                tp = current_price * 1.002  # +20 pips
                sl = current_price * 0.999  # -10 pips
            else:
                entry_price = current_price * 0.9999  # Légèrement en-dessous
                tp = current_price * 0.998  # -20 pips
                sl = current_price * 1.001  # +10 pips
        else:
            # Proposer une LIMIT prudente autour du prix courant
            entry_price = current_price
            tp = current_price * 1.001
            sl = current_price * 0.999
        
        return f"""🎯 SIGNAL: {signal}
📊 TYPE: {'MARKET' if signal != 'HOLD' else 'LIMIT'}
💰 PRIX: {entry_price:.5f}
📦 LOTS: 0.01
🎯 TP: {tp:.5f}
🛡️ SL: {sl:.5f}
📈 CONFIANCE: {confidence:.0f}%
💡 JUSTIFICATION: RSI {rsi:.1f}, dir={direction} ({direction_strength:.2f}). Mode {self.provider}."""
    
    def _build_trading_prompt(self, user_question: str) -> str:
        """Construire le prompt pour l'analyse de trading"""
        
        # Informations de base
        symbol = self.trading_context.get("symbol", "N/A")
        current_price = self.trading_context.get("current_price", 0)
        timeframe = self.trading_context.get("timeframe", "N/A")
        
        # Indicateurs techniques
        indicators = self.trading_context.get("indicators", {})
        rsi = indicators.get("rsi", "N/A")
        macd = indicators.get("macd", "N/A")
        bb_position = indicators.get("bb_position", "N/A")
        
        # Signaux ML
        ml_signals = self.trading_context.get("ml_signals", {})
        direction = ml_signals.get("direction", "HOLD")
        direction_strength = ml_signals.get("direction_strength", 0)
        spike_risk = ml_signals.get("spike", "LOW_SPIKE_RISK")
        
        # Analyse de tendance
        trend_analysis = self.trading_context.get("trend_analysis", {})
        consolidated_trend = trend_analysis.get("consolidated_trend", {})
        overall_trend = consolidated_trend.get("trend", "neutral")
        overall_force = consolidated_trend.get("force", 0)
        
        # Support/Résistance
        support_resistance = self.trading_context.get("support_resistance", {})
        support_zones = support_resistance.get("support_zones", [])
        resistance_zones = support_resistance.get("resistance_zones", [])
        
        # Volatilité
        volatility = self.trading_context.get("volatility", {})
        atr = volatility.get("atr", "N/A")
        
        prompt = f"""Tu es un expert en trading. Réponds de façon ULTRA CONCISE (8 lignes), strictement au format demandé.

CONTEXTE DE TRADING:
- Symbole: {symbol}
- Prix actuel: {current_price}
- Timeframe: {timeframe}
- Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

INDICATEURS TECHNIQUES:
- RSI: {rsi}
- MACD: {macd}
- Position Bollinger Bands: {bb_position}
- ATR (volatilité): {atr}

SIGNAUX ML:
- Direction prédite: {direction}
- Force du signal: {direction_strength:.2f}
- Risque de spike: {spike_risk}

ANALYSE DE TENDANCE:
- Tendance consolidée: {overall_trend}
- Force globale: {overall_force}

SUPPORT/RÉSISTANCE:
- Zones de support: {len(support_zones)} zones détectées
- Zones de résistance: {len(resistance_zones)} zones détectées

QUESTION UTILISATEUR: {user_question if user_question else "Analyse et propose un signal"}

INSTRUCTIONS:
1) Donne uniquement les 8 lignes attendues (aucun texte additionnel).
2) Si signaux clairs (tendance forte ou RSI extrême), choisis BUY/SELL sinon HOLD LIMIT.
3) Évite N/A. Utilise des valeurs raisonnables (prix proches, TP/SL courts si doute).
4) Pas de paragraphes.

RÉPONSE ATTENDUE (format structuré):
🎯 SIGNAL: [BUY/SELL]
📊 TYPE: [MARKET/LIMIT]
💰 PRIX: [prix d'entrée]
📦 LOTS: [taille de position]
🎯 TP: [Take Profit]
🛡️ SL: [Stop Loss]
📈 CONFIANCE: [pourcentage]
💡 JUSTIFICATION: [très courte: 1 ligne, indicateurs clés]

Réponds maintenant:"""

        return prompt
    
    def extract_trading_signal(self, response: str) -> Dict[str, Any]:
        """Extraire les informations de trading de la réponse"""
        signal_info = {
            "signal": "HOLD",
            "type": "MARKET",
            "price": 0,
            "lots": 0.01,
            "tp": 0,
            "sl": 0,
            "confidence": 0,
            "justification": response
        }
        
        try:
            lines = response.split('\n')
            for line in lines:
                if "SIGNAL:" in line:
                    if "BUY" in line.upper():
                        signal_info["signal"] = "BUY"
                    elif "SELL" in line.upper():
                        signal_info["signal"] = "SELL"
                
                elif "TYPE:" in line:
                    if "LIMIT" in line.upper():
                        signal_info["type"] = "LIMIT"
                
                elif "PRIX:" in line:
                    try:
                        price_str = line.split("PRIX:")[1].strip()
                        signal_info["price"] = float(price_str)
                    except:
                        pass
                
                elif "LOTS:" in line:
                    try:
                        lots_str = line.split("LOTS:")[1].strip()
                        signal_info["lots"] = max(0.01, float(lots_str))
                    except:
                        pass
                
                elif "TP:" in line:
                    try:
                        tp_str = line.split("TP:")[1].strip()
                        signal_info["tp"] = float(tp_str)
                    except:
                        pass
                
                elif "SL:" in line:
                    try:
                        sl_str = line.split("SL:")[1].strip()
                        signal_info["sl"] = float(sl_str)
                    except:
                        pass
                
                elif "CONFIANCE:" in line:
                    try:
                        conf_str = line.split("CONFIANCE:")[1].strip().replace("%", "")
                        signal_info["confidence"] = float(conf_str)
                    except:
                        pass
        
        except Exception as e:
            print(f"Erreur lors de l'extraction du signal: {e}")
        
        return signal_info
    
    def add_to_chat_history(self, user_message: str, bot_response: str, signal_info: Dict[str, Any]):
        """Ajouter à l'historique du chat"""
        self.chat_history.append({
            "timestamp": datetime.now().isoformat(),
            "user": user_message,
            "bot": bot_response,
            "signal": signal_info,
            "context": self.trading_context.copy()
        })
        
        # Limiter l'historique à 50 messages
        if len(self.chat_history) > 50:
            self.chat_history = self.chat_history[-50:]

    def clear_history(self):
        """Effacer l'historique du chat."""
        self.chat_history = []

    def get_status(self) -> Dict[str, Any]:
        """Retourne l'état du modèle (prêt/mock/non chargé)."""
        if self.model is None:
            return {"ready": False, "mode": "unloaded", "device": self.device, "loaded_at": None, "last_error": self.last_error, "provider": self.provider}
        if self.model == "MOCK":
            return {"ready": True, "mode": "mock", "device": self.device, "loaded_at": self.loaded_at, "last_error": self.last_error, "provider": self.provider}
        if getattr(self, "provider", "gemma") == "gemini":
            return {"ready": True, "mode": "model", "device": "api", "loaded_at": self.loaded_at, "last_error": self.last_error, "provider": "gemini"}
        return {"ready": True, "mode": "model", "device": self.device, "loaded_at": self.loaded_at, "last_error": self.last_error, "provider": self.provider}

# Instance globale
gemma_chat = GemmaTradingChat()
