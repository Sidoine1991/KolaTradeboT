#!/usr/bin/env python3
"""
Poller Local - Proxy entre EA (MetaEditor/Windows) et AI Servers:
- Local AI Server (http://127.0.0.1:8000) **PRIMAIRE** (votre ai_server.py)
- Render AI Server (https://kolatradebot-7ofl.onrender.com) **SECONDAIRE** (fallback)
Remplace la communication directe EA -> AI Server par EA -> Poller Local -> (Local primaire ou Render secondaire)
"""
import os
import sys
import logging
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS
import time
from threading import Thread

# Configuration
LOCAL_AI_URL = "http://127.0.0.1:8000"      # Votre ai_server.py local (PRIMAIRE)
RENDER_URL = "https://kolatradebot-7ofl.onrender.com"  # Render AI Server (SECONDAIRE)
POLLER_PORT = 8765
REQUEST_TIMEOUT = 12  # secondes (légèrement réduit car local devrait être rapide)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('poller_local.log')
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Autoriser les requêtes cross-origin

# Cache simple pour éviter de spammer les serveurs
response_cache = {}
CACHE_TTL = 5  # secondes

def get_fallback_verdict(symbol: str, source: str) -> dict:
    """Verdict de fallback en cas d'échec des deux serveurs"""
    return {
        "verdict": "WAIT",
        "verdict_num": 0,
        "confidence": 0.0,
        "coherence": 0.0,
        "reason": f"Both AI servers unavailable for {symbol} - fallback WAIT from {source}",
        "source": source,
        "timestamp": int(time.time())
    }

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "poller": "local (primary: local AI, secondary: Render)",
        "local_ai_url": LOCAL_AI_URL,
        "render_url": RENDER_URL,
        "timestamp": int(time.time())
    })

@app.route('/gom-verdict', methods=['GET'])
def gom_verdict():
    """
    Proxy vers le AI Server Primaire (local) puis secondaire (Render) en cas d'échec
    Query params: symbol=XAUUSD
    """
    symbol = request.args.get('symbol', '').strip()
    if not symbol:
        return jsonify({"error": "Missing 'symbol' parameter"}), 400

    logger.info(f"Request for symbol: {symbol} from {request.remote_addr}")

    # Vérifier cache
    cache_key = f"gom-verdict:{symbol}"
    if cache_key in response_cache:
        cached_data, cached_time = response_cache[cache_key]
        if time.time() - cached_time < CACHE_TTL:
            logger.info(f"Cache HIT for {symbol}")
            return jsonify(cached_data)

    # --- TENTATIVE PRIMAIRE : Serveur IA LOCAL ---
    try:
        local_endpoint = f"{LOCAL_AI_URL}/gom-verdict"
        params = {'symbol': symbol}

        logger.info(f"Attempting PRIMARY (local AI): {local_endpoint}?symbol={symbol}")
        response = requests.get(
            local_endpoint,
            params=params,
            timeout=REQUEST_TIMEOUT,
            headers={'User-Agent': 'TradBOT-LocalPoller/1.0'}
        )

        if response.status_code == 200:
            data = response.json()
            logger.info(f"Local AI response for {symbol}: {data.get('verdict', 'N/A')}")

            # Mettre en cache
            response_cache[cache_key] = (data, time.time())
            return jsonify(data)
        else:
            logger.warning(f"Local AI returned {response.status_code} for {symbol}, trying Render as fallback")
    except requests.exceptions.Timeout:
        logger.warning(f"Timeout connecting to LOCAL AI for {symbol}, trying Render as fallback")
    except requests.exceptions.ConnectionError:
        logger.warning(f"Connection error to LOCAL AI for {symbol}, trying Render as fallback")
    except Exception as e:
        logger.warning(f"Unexpected error with LOCAL AI for {symbol}: {e}, trying Render as fallback")

    # --- TENTATIVE SECONDAIRE : Serveur IA RENDER ---
    try:
        render_endpoint = f"{RENDER_URL}/gom-verdict"
        params = {'symbol': symbol}

        logger.info(f"Attempting SECONDARY (Render): {render_endpoint}?symbol={symbol}")
        response = requests.get(
            render_endpoint,
            params=params,
            timeout=REQUEST_TIMEOUT,
            headers={'User-Agent': 'TradBOT-LocalPoller/1.0'}
        )

        if response.status_code == 200:
            data = response.json()
            logger.info(f"Render response for {symbol}: {data.get('verdict', 'N/A')}")

            # Mettre en cache
            response_cache[cache_key] = (data, time.time())
            return jsonify(data)
        else:
            logger.error(f"Render error {response.status_code} for {symbol}")
            return jsonify({
                "error": f"Render server error: {response.status_code}",
                "verdict": "WAIT",
                "verdict_num": 0,
                "source": "RENDER_ERROR"
            }), 502

    except requests.exceptions.Timeout:
        logger.error(f"Timeout connecting to Render for {symbol}")
        return jsonify({
            "error": "Timeout connecting to Render AI server",
            "verdict": "WAIT",
            "verdict_num": 0,
            "source": "TIMEOUT"
        }), 504

    except requests.exceptions.ConnectionError:
        logger.error(f"Connection error to Render for {symbol}")
        return jsonify({
            "error": "Cannot connect to Render AI server",
            "verdict": "WAIT",
            "verdict_num": 0,
            "source": "CONNECTION_ERROR"
        }), 503

    except Exception as e:
        logger.exception(f"Unexpected error for {symbol}: {e}")
        return get_fallback_verdict(symbol, "INTERNAL_ERROR"), 500

@app.route('/gom-kola-dashboard', methods=['GET'])
def gom_kola_dashboard():
    """
    Proxy vers l'endpoint dashboard de Render (seulement Render a cette fonctionnalité)
    Utilisé par le scanner GOM dans l'EA
    Note: Le dashboard n'est disponible que sur Render, pas sur l'ai_server local
    """
    try:
        response = requests.get(
            f"{RENDER_URL}/gom-kola-dashboard",
            timeout=REQUEST_TIMEOUT
        )
        if response.status_code == 200:
            return jsonify(response.json())
        else:
            return jsonify({"error": "Dashboard unavailable"}), 502
    except Exception as e:
        logger.exception(f"Dashboard proxy error: {e}")
        return jsonify({"error": str(e)}), 500

def cleanup_cache():
    """Nettoyage périodique du cache"""
    while True:
        time.sleep(60)
        now = time.time()
        expired = [k for k, (_, t) in response_cache.items() if now - t > CACHE_TTL * 2]
        for k in expired:
            del response_cache[k]
        if expired:
            logger.debug(f"Cleaned {len(expired)} expired cache entries")

if __name__ == '__main__':
    logger.info("=" * 70)
    logger.info("Starting TradBOT Local Poller (LOCAL AI PRIMARY, Render SECONDARY)")
    logger.info(f"Primary AI URL (local): {LOCAL_AI_URL}")
    logger.info(f"Secondary AI URL (Render): {RENDER_URL}")
    logger.info(f"Listening on port: {POLLER_PORT}")
    logger.info("=" * 70)

    # Démarrer le thread de nettoyage cache
    cache_thread = Thread(target=cleanup_cache, daemon=True)
    cache_thread.start()

    # Lancer le serveur Flask
    # host='0.0.0.0' pour accepter les connexions depuis l'EA (même machine ou réseau local)
    # Utilisez '127.0.0.1' si l'EA tourne sur la même machine uniquement
    app.run(host='0.0.0.0', port=POLLER_PORT, threaded=True, debug=False)