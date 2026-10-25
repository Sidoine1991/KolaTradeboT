#!/usr/bin/env python3
"""
Script simple pour démarrer l'API de signaux TradBOT
Usage: python start_signal_api.py
"""

import json
import http.server
import socketserver
import threading
import time
from pathlib import Path

# Port de l'API
API_PORT = 8001

# Fichier de données des signaux
SIGNALS_FILE = Path("signals.json")

class SignalHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        """Gestion des requêtes GET"""
        if self.path == "/":
            response = {
                "message": "TradBOT Signal API", 
                "endpoints": ["/health", "/signals", "/test"],
                "status": "running"
            }
        elif self.path == "/health":
            signals = self._load_signals()
            response = {
                "status": "ok", 
                "count": len(signals.get("signals", [])),
                "timestamp": time.time()
            }
        elif self.path == "/signals":
            response = self._load_signals()
        elif self.path == "/test":
            signals = self._load_signals()
            response = {
                "message": "API working", 
                "signals_count": len(signals.get("signals", [])),
                "timestamp": time.time()
            }
        else:
            self.send_response(404)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"detail": "Not Found"}).encode())
            return
        
        # Envoi de la réponse
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(response, indent=2).encode())
    
    def _load_signals(self):
        """Charge les signaux depuis le fichier JSON"""
        try:
            if SIGNALS_FILE.exists():
                with open(SIGNALS_FILE, 'r', encoding='utf-8') as f:
                    data = json.load(f)
            else:
                data = {"signals": []}
        except Exception as e:
            print(f"Erreur chargement signaux: {e}")
            data = {"signals": []}

        # Nettoyer les signaux contre-tendance Boom/Crash
        signals = data.get("signals", [])
        filtered_signals = self._filter_boom_crash_signals(signals)
        if len(filtered_signals) != len(signals):
            blocked = len(signals) - len(filtered_signals)
            print(f"🚫 {blocked} signal(s) Boom/Crash bloqué(s) (BUY Crash / SELL Boom interdits)")
        data["signals"] = filtered_signals
        return data

    @staticmethod
    def _filter_boom_crash_signals(signals):
        """Retire les signaux contre-tendance sur Boom/Crash"""
        filtered = []
        for signal in signals:
            symbol = str(signal.get("symbol", "")).upper()
            side = str(signal.get("side", "")).upper()

            is_sell_boom = "BOOM" in symbol and side == "SELL"
            is_buy_crash = "CRASH" in symbol and side == "BUY"

            if is_sell_boom or is_buy_crash:
                continue

            filtered.append(signal)

        return filtered
    
    def log_message(self, format, *args):
        """Supprime les logs par défaut"""
        pass

def start_api():
    """Démarre le serveur API"""
    try:
        print(f"🚀 Démarrage de l'API TradBOT sur le port {API_PORT}...")
        
        # Créer le fichier signals.json s'il n'existe pas
        if not SIGNALS_FILE.exists():
            with open(SIGNALS_FILE, 'w', encoding='utf-8') as f:
                json.dump({"signals": []}, f, indent=2)
            print(f"✅ Fichier {SIGNALS_FILE} créé")
        
        # Démarrer le serveur
        with socketserver.TCPServer(("", API_PORT), SignalHandler) as httpd:
            print(f"✅ API démarrée avec succès sur http://localhost:{API_PORT}")
            print(f"📊 Endpoints disponibles:")
            print(f"   - http://localhost:{API_PORT}/")
            print(f"   - http://localhost:{API_PORT}/health")
            print(f"   - http://localhost:{API_PORT}/signals")
            print(f"   - http://localhost:{API_PORT}/test")
            print(f"📁 Fichier de signaux: {SIGNALS_FILE.absolute()}")
            print(f"🔄 Appuyez sur Ctrl+C pour arrêter")
            
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print(f"\n🛑 Arrêt de l'API...")
    except Exception as e:
        print(f"❌ Erreur démarrage API: {e}")

if __name__ == "__main__":
    start_api()
