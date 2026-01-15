"""
API REST pour la prédiction des mouvements futurs des prix
Endpoints : /predict, /explain, /symbols, /timeframes
"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))
from fastapi import FastAPI, Query, Request, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any
from backend.mt5_connector import get_ohlc, get_all_symbols, TIMEFRAME_MAPPING, get_current_price
from backend.adaptive_predict import predict_adaptive
import threading
import redis
import json
from backend.trend_summary import get_multi_timeframe_trend
from backend.indicators_modern import (
    compute_market_structure,
    compute_smart_money,
    compute_vwap,
    compute_squeeze,
    compute_supertrend,
    compute_pivots,
)
from backend.signal_generator import generate_and_send_signal
from backend.multi_timeframe_signal_generator import generate_mtf_signal_for_symbol
from backend.auto_signal_monitor import start_auto_monitor, stop_auto_monitor, get_monitor_status, update_monitor_config, get_monitor_instance
import threading
import time
from datetime import datetime
from fastapi import BackgroundTasks
from backend.technical_analysis import get_support_resistance_zones
from backend.whatsapp_utils import send_whatsapp_message
from backend.auto_signal_monitor import AutoSignalMonitor
from frontend.whatsapp_notify import send_whatsapp_vonage_sandbox
from frontend.whatsapp_notify import send_whatsapp_message_unified
import base64
from dotenv import load_dotenv
import math

# Charger .env pour clés Gemini
try:
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    dotenv_path = os.path.join(project_root, '.env')
    if os.path.exists(dotenv_path):
        load_dotenv(dotenv_path)
    else:
        load_dotenv()
except Exception:
    pass

# Stockage temporaire des ordres en attente (à remplacer par une solution persistante en prod)
pending_orders = {}
pending_orders_lock = threading.Lock()

REDIS_HOST = os.getenv('REDIS_HOST', 'localhost')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
REDIS_DB = int(os.getenv('REDIS_DB', 0))
r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB)

TREND_VALIDATION_KEY = "trend_validation_enabled"
def set_trend_validation(enabled: bool):
    r.set(TREND_VALIDATION_KEY, "1" if enabled else "0")
def get_trend_validation():
    val = r.get(TREND_VALIDATION_KEY)
    if val is None:
        return True  # Par défaut activé
    return val.decode() == "1"

app = FastAPI(title="API Prédiction Prix", description="API REST pour la prédiction des mouvements futurs des prix.")
# Utilitaire: assainir les nombres non JSON (NaN/Inf)
def _sanitize(obj):
    if isinstance(obj, dict):
        return {k: _sanitize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_sanitize(v) for v in obj]
    if isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return None
    return obj

# --- Inclusion du router WhatsApp Webhook ---
# L'URL publique à utiliser dans Twilio est : https://a7008b0f0e52.ngrok-free.app/whatsapp_webhook
from backend.api.whatsapp_webhook import router as whatsapp_router
app.include_router(whatsapp_router)

# --- Inclusion du router Robot Integration ---
from backend.api.robot_integration import router as robot_router
app.include_router(robot_router)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class PredictRequest(BaseModel):
    symbol: str
    timeframe: str
    count: int = 200

class AnalyzeChartRequest(BaseModel):
    image_base64: str
    mime_type: str | None = None
    filename: str | None = None


@app.get("/symbols", response_model=List[str])
def get_symbols():
    """Retourne la liste des symboles disponibles."""
    return get_all_symbols()

@app.get("/timeframes", response_model=List[str])
def get_timeframes():
    """Retourne la liste des timeframes disponibles."""
    return list(TIMEFRAME_MAPPING.keys())

# --- Modern indicators endpoints ---
@app.get("/indicators/market_structure")
def indicators_market_structure(symbol: str, timeframe: str = "5m", count: int = 200):
    try:
        df = get_ohlc(symbol, timeframe=timeframe, count=count)
        res = compute_market_structure(df)
        return _sanitize(res)
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/indicators/smart_money")
def indicators_smart_money(symbol: str, timeframe: str = "5m", count: int = 200):
    try:
        df = get_ohlc(symbol, timeframe=timeframe, count=count)
        res = compute_smart_money(df)
        return _sanitize(res)
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/indicators/vwap")
def indicators_vwap(symbol: str, timeframe: str = "5m", count: int = 200):
    try:
        df = get_ohlc(symbol, timeframe=timeframe, count=count)
        res = compute_vwap(df)
        return _sanitize(res)
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/indicators/squeeze")
def indicators_squeeze(symbol: str, timeframe: str = "5m", count: int = 200):
    try:
        df = get_ohlc(symbol, timeframe=timeframe, count=count)
        res = compute_squeeze(df)
        return _sanitize(res)
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/indicators/supertrend")
def indicators_supertrend(symbol: str, timeframe: str = "5m", count: int = 200, period: int = 10, multiplier: float = 3.0):
    try:
        df = get_ohlc(symbol, timeframe=timeframe, count=count)
        res = compute_supertrend(df, period=period, multiplier=multiplier)
        return _sanitize(res)
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/indicators/pivots")
def indicators_pivots(symbol: str, timeframe: str = "5m", count: int = 200, mode: str = "classic"):
    try:
        df = get_ohlc(symbol, timeframe=timeframe, count=count)
        res = compute_pivots(df, mode=mode)
        return _sanitize(res)
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.post("/analyze_chart")
def analyze_chart(req: AnalyzeChartRequest):
    """Analyse une capture de graphique (image base64) via Gemini Vision et extrait symbol, timeframe, S/R, pattern."""
    try:
        import google.generativeai as genai
        api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
        if not api_key:
            raise HTTPException(status_code=400, detail="GEMINI_API_KEY manquante")
        genai.configure(api_key=api_key)

        model_name = os.getenv("GEMINI_VISION_MODEL", "gemini-1.5-flash")
        model = genai.GenerativeModel(model_name)

        import base64 as _b64
        # Nettoyer éventuel préfixe data URL
        b64_str = req.image_base64
        if b64_str.startswith('data:'):
            try:
                b64_str = b64_str.split(',')[1]
            except Exception:
                pass
        # Déterminer mime
        mime = req.mime_type or 'image/png'
        if not req.mime_type and req.filename:
            fn = req.filename.lower()
            if fn.endswith('.jpg') or fn.endswith('.jpeg'):
                mime = 'image/jpeg'
        # Validation base64
        try:
            _ = _b64.b64decode(b64_str)
        except Exception:
            raise HTTPException(status_code=400, detail="image_base64 invalide")

        prompt = (
            "Analyse l'image du graphique et RENVOIE UNIQUEMENT un JSON compact avec ces clés: "
            "symbol (string), timeframe (string), support_zones (liste de nombres), resistance_zones (liste de nombres), patterns (liste de strings). "
            "Si tu n'es pas sûr, mets des valeurs raisonnables ou une liste vide, mais ne renvoie jamais d'autre texte."
        )

        # Envoyer l'image en base64 (conforme au SDK Gemini)
        resp = model.generate_content([
            {"text": prompt},
            {"inline_data": {"mime_type": mime, "data": b64_str}}
        ])
        text = getattr(resp, "text", None)
        if not text and hasattr(resp, "candidates") and resp.candidates:
            try:
                text = resp.candidates[0].content.parts[0].text
            except Exception:
                text = None
        if not text:
            raise HTTPException(status_code=500, detail="Réponse vide de Gemini Vision")
        # Essayer de parser JSON (y compris si encadré par des ```json ... ```)
        cleaned = text.strip()
        if cleaned.startswith("```"):
            # Retirer les fences
            cleaned = cleaned.strip("`")
            # enlever éventuel 'json' au début
            if cleaned.lower().startswith("json"):
                cleaned = cleaned[4:].lstrip()
        # Extraire premier objet JSON si nécessaire
        try:
            data = json.loads(cleaned)
        except Exception:
            try:
                import re
                m = re.search(r"\{[\s\S]*\}", cleaned)
                data = json.loads(m.group(0)) if m else {}
            except Exception:
                data = {}

        # Normalisation simple des champs attendus
        result = {
            "symbol": data.get("symbol"),
            "timeframe": data.get("timeframe"),
            "support_zones": data.get("support_zones", []),
            "resistance_zones": data.get("resistance_zones", []),
            "patterns": data.get("patterns", []),
            "raw": text
        }
        return result
    except HTTPException:
        raise
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.post("/predict")
def predict(req: PredictRequest):
    """Retourne la prédiction du modèle adaptatif pour un symbole/timeframe."""
    df = get_ohlc(req.symbol, req.timeframe, req.count)
    if df is None or df.empty:
        return {"error": "Aucune donnée OHLCV disponible pour ce symbole/timeframe."}
    result = predict_adaptive(req.symbol, df)
    return result

@app.post("/explain")
def explain(req: PredictRequest):
    """Retourne l'explication de la prédiction (features, importances, etc.)."""
    df = get_ohlc(req.symbol, req.timeframe, req.count)
    if df is None or df.empty:
        return {"error": "Aucune donnée OHLCV disponible pour ce symbole/timeframe."}
    result = predict_adaptive(req.symbol, df)
    # Ajout des importances de features si possible
    try:
        import joblib
        from backend.adaptive_predict import MODEL_CONFIGS
        model_path = MODEL_CONFIGS[result['category']]['model_path']
        model = joblib.load(model_path)
        if hasattr(model, 'feature_importances_'):
            result['feature_importances'] = dict(zip(result['features_used'], model.feature_importances_))
    except Exception as e:
        result['feature_importances'] = f"Non disponible: {e}"
    return result

@app.get("/trend_summary")
def trend_summary(symbol: str, nocache: int = 0):
    """
    Retourne la tendance consolidée multi-timeframe pour un symbole.
    """
    try:
        # Cache Redis (30s) pour réduire la latence et éviter les timeouts
        cache_key = f"trend_summary:{symbol}"
        if not nocache:
            cached = r.get(cache_key)
            if cached:
                try:
                    return json.loads(cached)
                except Exception:
                    pass
        result = get_multi_timeframe_trend(symbol)
        if not nocache:
            try:
                r.setex(cache_key, 30, json.dumps(result, ensure_ascii=False))
            except Exception:
                pass
        return result
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/trend")
def get_trend(symbol: str, timeframe: str = "M1"):
    """
    Retourne la tendance dynamique pour un symbole et un timeframe précis.
    Réponse normalisée pour le robot MT5: direction, strength, confidence, signal.
    """
    try:
        # Obtenir la tendance multi-timeframe existante
        data = get_multi_timeframe_trend(symbol)

        # Mapping des timeframes attendus -> clés de get_multi_timeframe_trend
        tf_map = {
            "M1": "1m", "1M": "1m", "1MIN": "1m",
            "M5": "5m", "5M": "5m",
            "M15": "15m", "15M": "15m",
            "M30": "30m", "30M": "30m",
            "H1": "1h", "1H": "1h",
            "H4": "4h", "4H": "4h",
            "D1": "1d", "1D": "1d",
        }
        key = tf_map.get(str(timeframe).upper(), "1m")

        trends = data.get("trends", {}) if isinstance(data, dict) else {}
        tf_info = trends.get(key, {}) if isinstance(trends, dict) else {}

        # Fallback sur la tendance consolidée si TF manquant
        consolidated = data.get("consolidated", {}) if isinstance(data, dict) else {}

        raw_trend = tf_info.get("trend") or consolidated.get("trend") or "NEUTRAL"
        raw_force = tf_info.get("force", consolidated.get("force", 0))
        raw_conf = tf_info.get("confidence", consolidated.get("confidence", 0))

        # Normaliser direction pour le robot (BUY/SELL/NEUTRE)
        trend_upper = str(raw_trend).upper()
        if "BULL" in trend_upper or trend_upper == "UP":
            direction = "BUY"
            signal = "bullish"
        elif "BEAR" in trend_upper or trend_upper == "DOWN":
            direction = "SELL"
            signal = "bearish"
        else:
            direction = "NEUTRE"
            signal = "neutral"

        return _sanitize({
            "symbol": symbol,
            "timeframe": timeframe,
            "direction": direction,      # BUY / SELL / NEUTRE
            "strength": float(raw_force) if isinstance(raw_force, (int, float)) else 0.0,
            "confidence": float(raw_conf) if isinstance(raw_conf, (int, float)) else 0.0,
            "signal": signal,
            "source": "trend_summary",
            "raw": tf_info or consolidated,
        })
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.post("/trend_summary/generate")
def generate_trend_summary(symbol: str = "EURUSD"):
    """
    Calcule et sauvegarde la tendance consolidée multi-timeframe pour un symbole dans trend_summary.json
    """
    try:
        result = get_multi_timeframe_trend(symbol)
        from pathlib import Path
        import json
        with Path("trend_summary.json").open("w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        return {"status": "ok", "detail": "trend_summary.json généré", "data": result}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/trend_summary/batch")
def trend_summary_batch(n: int = 10, exclude: str = None):
    import random
    all_symbols = get_all_symbols()
    if exclude and exclude in all_symbols:
        all_symbols = [s for s in all_symbols if s != exclude]
    selected = random.sample(all_symbols, min(n, len(all_symbols)))
    results = []
    for symbol in selected:
        trend = get_multi_timeframe_trend(symbol)
        # force = moyenne des forces des timeframes, ou force du timeframe M1 si dispo
        forces = [tf.get('force', 0) for tf in trend.get('trends', {}).values() if isinstance(tf, dict) and 'force' in tf]
        avg_force = int(sum(forces)/len(forces)) if forces else 0
        m1_force = trend.get('trends', {}).get('1m', {}).get('force', avg_force)
        results.append({
            "symbol": symbol,
            "consolidated": trend.get("consolidated"),
            "scalping_possible": trend.get("scalping_possible"),
            "force": m1_force
        })
    return results

@app.get("/send_signal_now")
def send_signal_now(symbol: str):
    """Génère et envoie immédiatement un signal WhatsApp pour le symbole donné."""
    try:
        result = generate_and_send_signal(symbol)
        return {"status": "ok", "detail": result}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.get("/test_whatsapp")
def test_whatsapp():
    """Test simple d'envoi WhatsApp pour diagnostiquer les problèmes de communication."""
    try:
        from backend.whatsapp_utils import send_whatsapp_message
        import datetime
        
        # Message de test
        test_msg = f"🧪 TEST WhatsApp TradBOT\n⏰ {datetime.datetime.now().strftime('%H:%M:%S')}\n✅ Connexion WhatsApp OK"
        
        print(f"📱 [TEST] Tentative d'envoi message de test WhatsApp")
        result = send_whatsapp_message(test_msg)
        print(f"📱 [TEST] Résultat: {result}")
        
        return {
            "status": "test_sent", 
            "message": test_msg,
            "whatsapp_result": result,
            "timestamp": datetime.datetime.now().isoformat()
        }
    except Exception as e:
        print(f"❌ [TEST] Erreur test WhatsApp: {str(e)}")
        return {
            "status": "test_error", 
            "error": str(e),
            "timestamp": datetime.datetime.now().isoformat()
        }

@app.get("/support_resistance_zones")
def support_resistance_zones(symbol: str, timeframe: str = "5m", count: int = 200):
    """Retourne les zones de support/résistance détectées pour un symbole et timeframe donnés."""
    df = get_ohlc(symbol, timeframe=timeframe, count=count)
    if df is None or df.empty:
        return []
    zones = get_support_resistance_zones(df)
    return zones

@app.get("/validate_order")
def validate_order(token: str, request: Request):
    """Valide et place un ordre MT5 à partir d'un token unique reçu par WhatsApp (stockage Redis)."""
    key = f'order:{token}'
    order_json = r.get(key)
    if not order_json:
        raise HTTPException(status_code=404, detail="Token invalide ou ordre déjà validé.")
    r.delete(key)
    order_info = json.loads(order_json)
    # Place l'ordre sur MT5
    from backend.mt5_connector import place_order_mt5
    symbol = order_info['symbol']
    order = order_info['order']
    side = order.get('recommendation', 'BUY').upper()
    price = float(order.get('price', 0))
    sl = float(order.get('sl', 0))
    tp = float(order.get('tp', 0))
    lot = 0.01  # À adapter selon la config utilisateur
    order_type = 'MARKET'
    result = place_order_mt5(symbol, order_type, lot, price, sl, tp, side)
    if result.get('success'):
        return {"message": f"Ordre {side} placé avec succès sur {symbol} à {price}."}
    else:
        return {"error": f"Erreur lors du placement de l'ordre : {result.get('error', 'inconnu')}"}

auto_signal_thread = None
auto_signal_stop = threading.Event()
auto_signal_config = {"symbol": None, "interval": 15}

def auto_signal_worker():
    while not auto_signal_stop.is_set():
        symbol = auto_signal_config["symbol"]
        interval = auto_signal_config["interval"]
        if symbol:
            generate_and_send_signal(symbol)
        # Attendre l'intervalle ou l'arrêt
        for _ in range(interval * 6):
            if auto_signal_stop.is_set():
                break
            time.sleep(10)

@app.post("/start_auto_signal")
def start_auto_signal(symbol: str, interval: int = 15):
    global auto_signal_thread
    auto_signal_config["symbol"] = symbol
    auto_signal_config["interval"] = interval
    auto_signal_stop.clear()
    if auto_signal_thread is None or not auto_signal_thread.is_alive():
        auto_signal_thread = threading.Thread(target=auto_signal_worker, daemon=True)
        auto_signal_thread.start()
    return {"status": "started", "symbol": symbol, "interval": interval}

@app.post("/stop_auto_signal")
def stop_auto_signal():
    auto_signal_stop.set()
    return {"status": "stopped"}

@app.post("/update_auto_signal")
def update_auto_signal(symbol: str = None, interval: int = None):
    if symbol:
        auto_signal_config["symbol"] = symbol
    if interval:
        auto_signal_config["interval"] = interval
    return {"status": "updated", "symbol": auto_signal_config["symbol"], "interval": auto_signal_config["interval"]} 

@app.get("/real_time_price")
def get_real_time_price(symbol: str):
    """Retourne le prix actuel d'un symbole."""
    try:
        from backend.mt5_connector import get_current_price
        current_price = get_current_price(symbol)
        if current_price is None:
            return {"error": f"Prix non disponible pour {symbol}"}
        
        return {
            "symbol": symbol,
            "price": current_price,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/support_resistance_advanced")
def get_advanced_support_resistance(symbol: str, timeframe: str = "1h", count: int = 200):
    """Retourne les niveaux de support et résistance avancés."""
    try:
        from backend.mt5_connector import get_ohlc
        from backend.advanced_support_resistance import AdvancedSupportResistance
        
        # Récupérer les données OHLC
        df = get_ohlc(symbol, timeframe, count)
        if df is None or df.empty:
            return {"error": f"Aucune donnée disponible pour {symbol}"}
        
        # Utiliser l'algorithme avancé
        detector = AdvancedSupportResistance()
        levels = detector.detect_all_levels(df, symbol)
        
        return {
            "symbol": symbol,
            "timeframe": timeframe,
            "levels": levels,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/symbols_whatsapp")
def get_symbols_for_whatsapp():
    """Retourne la liste des symboles disponibles pour sélection WhatsApp."""
    symbols = get_all_symbols()
    # Filtrer pour ne garder que les symboles populaires
    popular_symbols = [
        "Boom 500 Index", "Boom 1000 Index", "Boom 100 Index",
        "EURUSD", "GBPUSD", "USDJPY", "AUDUSD",
        "BTCUSD", "ETHUSD", "XAUUSD"
    ]
    available_symbols = [s for s in symbols if s in popular_symbols]
    return {
        "symbols": available_symbols,
        "message": "📊 Symboles disponibles:\n" + "\n".join([f"• {s}" for s in available_symbols])
    }

@app.get("/send_detailed_signal")
def send_detailed_signal(symbol: str):
    """Génère et envoie un signal détaillé avec tendance consolidée, prix, SL, TP."""
    try:
        from backend.mt5_connector import get_ohlc, get_current_price
        from backend.technical_analysis import add_technical_indicators
        from backend.whatsapp_utils import send_whatsapp_message
        from backend.trend_summary import get_multi_timeframe_trend
        from backend.signal_generator import generate_signal
        import datetime
        
        print(f"🔍 [DETAILED] Début signal détaillé pour {symbol}")
        
        # Récupération des données
        df = get_ohlc(symbol, timeframe="5m", count=200)
        if df is None or df.empty:
            return {"status": "error", "detail": "Pas de données pour ce symbole."}
        
        # Prix actuel
        current_price = get_current_price(symbol)
        if not current_price:
            current_price = df['close'].iloc[-1]
        
        # Indicateurs techniques
        df = add_technical_indicators(df)
        signal = generate_signal(df)
        
        # Tendance consolidée
        trend = get_multi_timeframe_trend(symbol)
        
        # Calcul SL et TP basé sur la volatilité
        atr_value = df['atr_14'].iloc[-1] if 'atr_14' in df.columns else current_price * 0.01
        if signal['signal'] == 'HAUSSE':
            sl = current_price - (atr_value * 2)  # SL à 2 ATR sous le prix
            tp = current_price + (atr_value * 3)  # TP à 3 ATR au-dessus
        else:
            sl = current_price + (atr_value * 2)  # SL à 2 ATR au-dessus
            tp = current_price - (atr_value * 3)  # TP à 3 ATR en-dessous
        
        # Tendance consolidée simplifiée
        bullish_count = sum(1 for tf in trend.values() if tf.get('trend') == 'BULLISH')
        bearish_count = sum(1 for tf in trend.values() if tf.get('trend') == 'BEARISH')
        
        if bullish_count > bearish_count:
            consolidated_trend = "📈 HAUSSIER"
        elif bearish_count > bullish_count:
            consolidated_trend = "📉 BAISSIER"
        else:
            consolidated_trend = "➡️ NEUTRE"
        
        # Message WhatsApp détaillé
        timestamp = datetime.datetime.now().strftime("%d/%m/%Y %H:%M")
        msg = f"""🚨 SIGNAL DE TRADING DÉTAILLÉ

📊 Symbole: {symbol}
⏰ Heure: {timestamp}
🎯 Signal: {signal['signal']} ({signal['confidence']}%)
�� Tendance consolidée: {consolidated_trend}

💰 PRIX D'ENTRÉE: {current_price:.5f}
🛑 STOP LOSS: {sl:.5f}
🎯 TAKE PROFIT: {tp:.5f}

📊 DÉTAILS TECHNIQUES:
• RSI: {df['rsi_14'].iloc[-1]:.1f}
• MACD: {df['macd'].iloc[-1]:.5f}
• Raison: {signal['reason']}

⏱️ Validité: 30 minutes
⚠️ Gestion des risques obligatoire"""
        
        print(f"📱 [DETAILED] Envoi message détaillé")
        send_result = send_whatsapp_message(msg)
        
        return {
            "status": "sent",
            "symbol": symbol,
            "signal": signal,
            "trend": consolidated_trend,
            "price": current_price,
            "sl": sl,
            "tp": tp,
            "whatsapp": send_result,
            "timestamp": timestamp
        }
        
    except Exception as e:
        print(f"❌ [DETAILED] Erreur: {str(e)}")
        return {"status": "error", "detail": str(e)} 

@app.get("/send_mtf_signal")
def send_mtf_signal(symbol: str):
    """Génère et envoie un signal multi-timeframe avec validation de tendance globale."""
    try:
        print(f"🚀 [API] Demande signal MTF pour {symbol}")
        print(f"🔍 [API] Début génération signal pour {symbol}")
        
        # Test direct avec notre logique
        from backend.multi_timeframe_signal_generator import MultiTimeframeSignalGenerator
        generator = MultiTimeframeSignalGenerator()
        
        # Générer le signal
        signal = generator.generate_mtf_signal(symbol)
        
        if signal:
            print(f"✅ [API] Signal généré avec succès: {signal}")
            # Envoyer par WhatsApp
            whatsapp_sent = generator.send_mtf_signal_whatsapp(signal)
            
            if whatsapp_sent:
                return {
                    'status': 'sent',
                    'signal': signal,
                    'symbol': symbol,
                    'whatsapp_sent': True
                }
            else:
                return {
                    'status': 'whatsapp_error',
                    'signal': signal,
                    'symbol': symbol,
                    'whatsapp_sent': False
                }
        else:
            print(f"❌ [API] Aucun signal généré pour {symbol}")
            return {
                'status': 'no_signal',
                'detail': 'Aucun signal valide généré',
                'symbol': symbol
            }
            
    except Exception as e:
        print(f"❌ [API] Erreur signal MTF: {e}")
        import traceback
        traceback.print_exc()
        return {"status": "error", "detail": str(e)}

@app.get("/analyze_signal_quality")
def analyze_signal_quality(symbol: str):
    """Analyse détaillée de la qualité d'un signal sans l'envoyer."""
    try:
        from backend.multi_timeframe_signal_generator import MultiTimeframeSignalGenerator
        from backend.mt5_connector import get_ohlc, get_current_price
        from backend.technical_analysis import add_technical_indicators
        from backend.signal_generator import generate_signal
        from backend.trend_summary import get_multi_timeframe_trend
        
        print(f"🔍 [ANALYSE] Analyse qualité signal pour {symbol}")
        
        # Récupérer les données
        df = get_ohlc(symbol, timeframe="5m", count=200)
        if df is None or df.empty:
            return {"status": "error", "detail": "Pas de données pour ce symbole."}
        
        # Ajouter les indicateurs techniques
        df = add_technical_indicators(df)
        
        # Générer le signal technique
        technical_signal = generate_signal(df)
        
        # Récupérer la tendance multi-timeframe
        trend_data = get_multi_timeframe_trend(symbol)
        
        # Créer l'instance du générateur
        generator = MultiTimeframeSignalGenerator()
        
        # Analyser le consensus de tendance
        trend_consensus = generator.analyze_trend_consensus(trend_data)
        
        # Prix actuel
        current_price = get_current_price(symbol) or df['close'].iloc[-1]
        
        # Calculs de confiance
        technical_confidence_raw = technical_signal.get('confidence', 0)
        if isinstance(technical_confidence_raw, (int, float)):
            technical_confidence = float(technical_confidence_raw) / 100
        else:
            technical_confidence = 0.5
            
        trend_confidence = float(trend_consensus.get('confidence', 0))
        combined_confidence = (technical_confidence * 0.7) + (trend_confidence * 0.3)
        
        # Validation de l'alignement
        signal_direction = technical_signal['signal']
        dominant_trend = trend_consensus['dominant_trend']
        
        is_aligned = False
        if signal_direction == 'HAUSSE' and dominant_trend == 'BULLISH':
            is_aligned = True
        elif signal_direction == 'BAISSE' and dominant_trend == 'BEARISH':
            is_aligned = True
        
        # Critères de validation
        criteria = {
            "min_confidence_met": combined_confidence >= generator.min_confidence,
            "technical_confidence_met": technical_confidence >= 0.65,
            "trend_confidence_met": trend_confidence >= 0.5,
            "alignment_met": is_aligned,
            "not_neutral_signal": signal_direction != 'NEUTRE',
            "not_neutral_trend": dominant_trend != 'NEUTRAL'
        }
        
        # Résultat global
        all_criteria_met = all(criteria.values())
        
        return {
            "status": "analysis_complete",
            "symbol": symbol,
            "signal_quality": {
                "technical_signal": technical_signal,
                "trend_consensus": trend_consensus,
                "technical_confidence": technical_confidence,
                "trend_confidence": trend_confidence,
                "combined_confidence": combined_confidence,
                "is_aligned": is_aligned,
                "current_price": current_price,
                "signal_direction": signal_direction,
                "dominant_trend": dominant_trend
            },
            "validation_criteria": criteria,
            "signal_approved": all_criteria_met,
            "min_confidence_threshold": generator.min_confidence,
            "technical_confidence_threshold": 0.65,
            "trend_confidence_threshold": 0.5
        }
        
    except Exception as e:
        print(f"❌ [ANALYSE] Erreur: {str(e)}")
        return {"status": "error", "detail": str(e)}

@app.post("/auto_monitor/start")
def start_auto_monitor():
    monitor = get_monitor_instance()
    if hasattr(monitor, 'start'):
        monitor.start()
    return {"status": "started"}

@app.post("/auto_monitor/stop")
def stop_auto_monitor():
    monitor = get_monitor_instance()
    if hasattr(monitor, 'stop'):
        monitor.stop()
    return {"status": "stopped"}

@app.get("/auto_monitor/status")
def auto_monitor_status():
    """
    Retourne le statut du moniteur automatique (running, stats, config, etc.)
    """
    try:
        monitor = get_monitor_instance()
        status = monitor.get_status()
        return status
    except Exception as e:
        return {"status": "error", "detail": str(e)}

def format_monitor_status(status):
    config = status.get('config', {})
    stats = status.get('stats', {})
    return (
        f"📊 Statut du Moniteur\n\n"
        f"{'🟢 Moniteur EN COURS' if status.get('running') else '🟠 Moniteur ARRÊTÉ'}\n\n"
        f"⚙️ Configuration :\n"
        f"• Intervalle scan : {config.get('scan_interval', '?')} min\n"
        f"• Confiance min : {config.get('min_confidence', '?')}%\n"
        f"• Confiance tendance min : {config.get('min_trend_confidence', '?')}%\n"
        f"• Alignement min : {config.get('min_alignment_score', '?')}\n"
        f"• Limite signaux/heure : {config.get('max_signals_per_hour', '?')}\n"
        f"• WhatsApp : {'activé' if config.get('enable_whatsapp') else 'désactivé'}\n"
        f"• Logging : {'activé' if config.get('enable_logging') else 'désactivé'}\n"
        f"• Mode exploratoire : {'activé' if config.get('exploratory_mode') else 'désactivé'}\n"
        f"• Catégories scannées : {', '.join(config.get('categories_to_scan', []))}\n\n"
        f"📈 Statistiques :\n"
        f"• Scans totaux : {stats.get('total_scans', 0)}\n"
        f"• Signaux générés : {stats.get('signals_generated', 0)}\n"
        f"• Signaux envoyés : {stats.get('signals_sent', 0)}\n"
        f"• Signaux rejetés : {stats.get('signals_rejected', 0)}\n"
        f"• Erreurs : {stats.get('errors', 0)}\n"
        f"• Timeouts : {stats.get('timeouts', 0)}\n"
        f"• Dernier signal : {stats.get('last_signal_time', 'Aucun')}\n"
        f"• Uptime : {status.get('uptime', 'N/A')}\n\n"
        f"🔢 Symboles prioritaires : {status.get('priority_symbols_count', 0)}\n"
        f"🔢 Symboles échoués : {status.get('failed_symbols_count', 0)}\n"
        f"🔢 Signaux cette heure : {status.get('signal_count_this_hour', 0)} / {status.get('max_signals_per_hour', 0)}\n\n"
        f"Distribution confiance :\n"
        f"- Haute (80-100%) : {stats.get('confidence_distribution', {}).get('high', 0)}\n"
        f"- Moyenne (70-79%) : {stats.get('confidence_distribution', {}).get('medium', 0)}\n"
        f"- Basse (<70%) : {stats.get('confidence_distribution', {}).get('low', 0)}"
    )

@app.put("/auto_monitor/config")
def update_auto_monitor_config(config: Dict[str, Any]):
    """Met à jour la configuration du moniteur automatique."""
    try:
        update_monitor_config(config)
        return {
            "status": "success", 
            "message": "Configuration mise à jour",
            "new_config": config
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Erreur mise à jour config: {str(e)}")

@app.get("/auto_monitor/config")
def get_auto_monitor_config():
    """Retourne la configuration actuelle du moniteur automatique."""
    try:
        monitor = get_monitor_instance()
        return {
            "status": "success",
            "config": monitor.config
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur récupération config: {str(e)}")

@app.post("/auto_monitor/scan_now")
def trigger_manual_scan():
    """Déclenche un scan manuel immédiat de tous les symboles."""
    try:
        monitor = get_monitor_instance()
        if not monitor.running:
            raise HTTPException(status_code=400, detail="Le moniteur n'est pas démarré")
        
        # Lancer un scan dans un thread séparé
        def run_scan():
            monitor.scan_all_symbols()
        
        scan_thread = threading.Thread(target=run_scan, daemon=True)
        scan_thread.start()
        
        return {
            "status": "success",
            "message": "Scan manuel déclenché",
            "timestamp": time.time()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur scan manuel: {str(e)}")

@app.post("/auto_monitor/reset_stats")
def reset_auto_monitor_stats():
    """Réinitialise les statistiques du moniteur automatique."""
    try:
        monitor = get_monitor_instance()
        monitor.stats = {
            'total_scans': 0,
            'signals_generated': 0,
            'signals_sent': 0,
            'signals_rejected': 0,
            'errors': 0,
            'timeouts': 0,
            'last_signal_time': None,
            'last_scan_time': None,
            'uptime_start': monitor.stats.get('uptime_start'),
            'symbols_scanned': {},
            'confidence_distribution': {
                'high': 0,
                'medium': 0,
                'low': 0
            }
        }
        monitor.signal_count = 0
        monitor.last_reset = datetime.now()
        
        return {
            "status": "success",
            "message": "Statistiques réinitialisées"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur réinitialisation stats: {str(e)}")

@app.get("/whatsapp_menu")
def send_whatsapp_menu():
    """Envoie le menu principal WhatsApp avec les commandes disponibles."""
    try:
        from backend.whatsapp_utils import send_whatsapp_message
        trend_validation = get_trend_validation()
        etat = "✅ ACTIVÉE" if trend_validation else "❌ DÉSACTIVÉE"
        menu_msg = f"""🤖 TRADBOT - MENU PRINCIPAL\n\n📋 Commandes disponibles:\n\n📊 SYMBOLES\n• /symboles - Liste des symboles disponibles\n• /tendance SYMBOLE - Tendance consolidée d'un symbole\n\n🚨 SIGNALS\n• /signal SYMBOLE - Signal détaillé avec SL/TP\n• /signal_mtf SYMBOLE - Signal multi-timeframe (recommandé)\n• /signal_rapide SYMBOLE - Signal rapide\n\n📈 ANALYSE\n• /analyse SYMBOLE - Analyse complète\n• /prix SYMBOLE - Prix actuel\n\n⚙️ VALIDATION TENDANCE\n• /validation_tendance on|off\n\n❓ AIDE\n• /aide - Ce menu\n• /status - Statut du bot\n\n💡 Exemple: /signal_mtf Boom 500 Index\n\nValidation de tendance: {etat}"""
        send_result = send_whatsapp_message(menu_msg)
        return {"status": "menu_sent", "whatsapp": send_result}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

@app.post("/whatsapp_command")
async def process_whatsapp_command(request: Request):
    print(">>> WhatsApp command received")
    form = await request.form()
    print("Form data:", form)
    command = form.get('Body', '')
    print("Command:", command)
    command = command.strip().lower()
    monitor = get_monitor_instance()
    if command in ["/status", "status"]:
        status = monitor.get_status()
        msg = format_monitor_status(status)
        send_whatsapp_message(msg)
        return {"status": "ok", "detail": status}
    elif command in ["/start", "start"]:
        start_auto_monitor()
        send_whatsapp_message("🚀 Moniteur démarré !")
        return {"status": "started"}
    elif command in ["/stop", "stop"]:
        stop_auto_monitor()
        send_whatsapp_message("🛑 Moniteur arrêté !")
        return {"status": "stopped"}
    elif command.startswith("/config"):
        parts = command.split()
        if len(parts) == 3:
            key, value = parts[1], parts[2]
            try:
                value = int(value) if value.isdigit() else float(value) if "." in value else value
            except Exception:
                pass
            monitor.update_config({key: value})
            send_whatsapp_message(f"⚙️ Config modifiée : {key} = {value}")
            return {"status": "config_updated", "key": key, "value": value}
        else:
            send_whatsapp_message("❓ Usage: /config clé valeur")
            return {"status": "error", "detail": "Usage: /config clé valeur"}
    elif command.startswith("/signal"):
        parts = command.split()
        if len(parts) >= 2:
            symbol = " ".join(parts[1:])
            from backend.signal_generator import generate_and_send_signal
            result = generate_and_send_signal(symbol)
            send_whatsapp_message(f"🎯 Signal généré pour {symbol}: {result}")
            return {"status": "signal_sent", "detail": result}
        else:
            send_whatsapp_message("❓ Usage: /signal SYMBOL")
            return {"status": "error", "detail": "Usage: /signal SYMBOL"}
    elif command in ["/help", "/aide", "help", "aide"]:
        help_msg = (
            "🤖 Commandes disponibles:\n"
            "/status - Statut du moniteur\n"
            "/start - Démarrer le moniteur\n"
            "/stop - Arrêter le moniteur\n"
            "/config clé valeur - Modifier une config (ex: /config min_confidence 60)\n"
            "/signal SYMBOL - Générer un signal pour un symbole\n"
            "/help - Afficher cette aide"
        )
        send_whatsapp_message(help_msg)
        return {"status": "help_sent"}
    else:
        send_whatsapp_message(f"❌ Commande inconnue : {command}\nTape /help pour la liste des commandes.")
        return {"status": "error", "detail": "Commande inconnue"} 

@app.post("/vonage/inbound")
async def vonage_inbound(request: Request):
    data = await request.json()
    print("[VONAGE IN]", data)
    to = data.get("from")
    text = data.get("text", "").strip().lower()
    button_id = data.get("button", {}).get("payload") or data.get("button", {}).get("id")
    if not to:
        return {"status": "no 'from' in payload"}
    # --- Menu principal interactif enrichi ---
    if text == "menu" or button_id == "menu_main":
        # Test : envoi d'un message texte simple pour valider la chaîne Vonage
        print("[DEBUG] Envoi message texte simple Vonage pour test")
        send_whatsapp_message_unified(
            message="Test texte simple depuis TradBOT (sandbox Vonage)",
            to=to
        )
        return {"status": "menu sent (texte simple)"}
    # --- Sous-menu symboles interactif ---
    if text == "2" or button_id == "symboles":
        send_whatsapp_message_unified(
            message=None,
            to=to,
            interactive={
                "type": "list",
                "body": {"text": "Choisis une catégorie de symboles :"},
                "action": {
                    "button": "Catégories",
                    "sections": [
                        {"title": "Catégories principales", "rows": [
                            {"id": "cat_forex", "title": "Forex"},
                            {"id": "cat_synthetic", "title": "Synthetic Index"},
                            {"id": "cat_crypto", "title": "Crypto"},
                            {"id": "cat_stock", "title": "Indices"},
                        ]}
                    ]
                }
            }
        )
        return {"status": "symboles menu sent"}
    # --- Gestion des callbacks de sous-menus ---
    if button_id and button_id.startswith("cat_"):
        cat_map = {
            "cat_forex": "EURUSD, USDJPY, GBPUSD, ...",
            "cat_synthetic": "Boom 1000, Crash 1000, Volatility 75, ...",
            "cat_crypto": "BTCUSD, ETHUSD, ...",
            "cat_stock": "US30, NAS100, SPX500, ...",
        }
        msg = f"Symboles de la catégorie :\n{cat_map.get(button_id, 'Aucun symbole trouvé.')}"
        send_whatsapp_message_unified(msg, to)
        return {"status": "cat sent"}
    # --- Statut du bot ---
    if text == "1" or button_id == "statut":
        send_whatsapp_message_unified("🤖 Statut du bot : opérationnel !", to)
        return {"status": "statut sent"}
    # --- Passer un ordre ---
    if text == "3" or button_id == "ordre":
        send_whatsapp_message_unified("Pour passer un ordre, envoie : ORDRE BUY EURUSD 0.1 SL=... TP=...", to)
        return {"status": "ordre sent"}
    # --- Tendance consolidée ---
    if text == "10" or button_id == "trend":
        send_whatsapp_message_unified("📊 Tendance consolidée : (exemple)\nD1: bullish\nH4: bearish\n...", to)
        return {"status": "trend sent"}
    # --- Historique des trades ---
    if button_id == "historique":
        send_whatsapp_message_unified("📈 Historique des trades :\n(Exemple) EURUSD BUY 0.1 @ 1.12345 ...", to)
        return {"status": "historique sent"}
    # --- Performance ---
    if button_id == "perf":
        send_whatsapp_message_unified("📊 Performance :\nWinrate: 62%\nGain total: +1200$\nDrawdown: 4%", to)
        return {"status": "perf sent"}
    # --- Favoris (sous-menu) ---
    if button_id == "favoris":
        send_whatsapp_message_unified(
            message=None,
            to=to,
            interactive={
                "type": "list",
                "body": {"text": "Gestion des favoris :"},
                "action": {
                    "button": "Actions",
                    "sections": [
                        {"title": "Favoris", "rows": [
                            {"id": "fav_liste", "title": "Voir mes favoris"},
                            {"id": "fav_ajouter", "title": "Ajouter un favori"},
                            {"id": "fav_supprimer", "title": "Supprimer un favori"},
                        ]}
                    ]
                }
            }
        )
        return {"status": "favoris menu sent"}
    if button_id == "fav_liste":
        send_whatsapp_message_unified("⭐️ Favoris : EURUSD, BTCUSD", to)
        return {"status": "favoris liste sent"}
    if button_id == "fav_ajouter":
        send_whatsapp_message_unified("Envoie le symbole à ajouter à tes favoris.", to)
        return {"status": "favoris ajouter sent"}
    if button_id == "fav_supprimer":
        send_whatsapp_message_unified("Envoie le symbole à supprimer de tes favoris.", to)
        return {"status": "favoris supprimer sent"}
    # --- Alertes (sous-menu) ---
    if button_id == "alertes":
        send_whatsapp_message_unified(
            message=None,
            to=to,
            interactive={
                "type": "list",
                "body": {"text": "Gestion des alertes :"},
                "action": {
                    "button": "Actions",
                    "sections": [
                        {"title": "Alertes", "rows": [
                            {"id": "alerte_liste", "title": "Voir mes alertes"},
                            {"id": "alerte_ajouter", "title": "Ajouter une alerte"},
                            {"id": "alerte_supprimer", "title": "Supprimer une alerte"},
                        ]}
                    ]
                }
            }
        )
        return {"status": "alertes menu sent"}
    if button_id == "alerte_liste":
        send_whatsapp_message_unified("🔔 Alertes : EURUSD > 1.15, BTCUSD < 30000", to)
        return {"status": "alerte liste sent"}
    if button_id == "alerte_ajouter":
        send_whatsapp_message_unified("Envoie le symbole et la condition d'alerte (ex: EURUSD > 1.15)", to)
        return {"status": "alerte ajouter sent"}
    if button_id == "alerte_supprimer":
        send_whatsapp_message_unified("Envoie l'alerte à supprimer.", to)
        return {"status": "alerte supprimer sent"}
    # --- Configuration ---
    if button_id == "config":
        send_whatsapp_message_unified("⚙️ Configuration :\n- Risque par trade : 1%\n- Notifications : activées\n- Langue : Français", to)
        return {"status": "config sent"}
    # --- Support/FAQ ---
    if button_id == "support":
        send_whatsapp_message_unified("🆘 Support / FAQ :\n- Tape /help pour la liste des commandes\n- Contacte l'équipe au +33 6 XX XX XX XX", to)
        return {"status": "support sent"}
    # --- Assistant IA (Gemma3) ---
    if button_id == "ia":
        send_whatsapp_message_unified("🤖 Assistant IA (Gemma3) :\nPose ta question à l'IA, ex : 'avis ia EURUSD'", to)
        return {"status": "ia sent"}
    # --- Aide / Commandes ---
    if text == "5" or button_id == "aide":
        send_whatsapp_message_unified("Commandes principales :\nmenu, 1, 2, 3, 10, historique, perf, favoris, alertes, config, support, ia", to)
        return {"status": "aide sent"}
    # --- Fallback : commande inconnue ---
    send_whatsapp_message_unified("Commande non reconnue. Tape 'menu' pour revenir au menu principal.", to)
    return {"status": "unknown command"}

@app.post("/vonage/dlr")
async def vonage_dlr(request: Request):
    try:
        data = await request.json()
    except Exception:
        data = await request.body()
        try:
            data = data.decode()
        except Exception:
            pass
    print("[VONAGE DLR]", data)
    return {"status": "ok"}

# --- Montage automatique du sous-app WhatsApp Webhook ---
# from backend.api import whatsapp_webhook
# app.mount("/whatsapp_webhook", whatsapp_webhook.app) 

@app.get("/")
def root():
    return {"message": "🚀 TradBOT API opérationnelle. Consultez /docs pour la documentation."}

@app.get("/health")
def health():
    """Endpoint de santé ultra-rapide."""
    try:
        # Ping léger Redis (optionnel)
        try:
            r.ping()
            cache = "ok"
        except Exception:
            cache = "unavailable"
        return {"status": "ok", "cache": cache}
    except Exception as e:
        return {"status": "error", "detail": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 