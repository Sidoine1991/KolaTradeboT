"""
# API WhatsApp Webhook TradBOT

## Exemples de commandes pour générer du contenu interactif WhatsApp via Twilio

# 1. Envoyer un message texte simple
curl -X POST https://api.twilio.com/2010-04-01/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages.json \
  --data-urlencode "To=whatsapp:+1234567890" \
  --data-urlencode "From=whatsapp:+14155238886" \
  --data-urlencode "Body=Bonjour, voici un message texte!" \
  -u 'ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:YOUR_AUTH_TOKEN'

# 2. Envoyer un message avec boutons (interactive message)
curl -X POST https://api.twilio.com/v1/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages \
  -u 'ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:YOUR_AUTH_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "to": "whatsapp:+1234567890",
    "from": "whatsapp:+14155238886",
    "interactive": {
      "type": "button",
      "body": {"text": "Que souhaitez-vous faire?"},
      "action": {
        "buttons": [
          {"type": "reply", "reply": {"id": "order", "title": "Placer un ordre"}},
          {"type": "reply", "reply": {"id": "close", "title": "Fermer une position"}},
          {"type": "reply", "reply": {"id": "status", "title": "Statut du bot"}},
          {"type": "reply", "reply": {"id": "help", "title": "Aide"}}
        ]
      }
    }
  }'

# 3. Envoyer une liste déroulante (list message)
curl -X POST https://api.twilio.com/v1/Accounts/ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/Messages \
  -u 'ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:YOUR_AUTH_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "to": "whatsapp:+1234567890",
    "from": "whatsapp:+14155238886",
    "interactive": {
      "type": "list",
      "body": {"text": "Choisissez un symbole"},
      "action": {
        "button": "Voir les symboles",
        "sections": [
          {"title": "Symboles disponibles", "rows": [
            {"id": "eurusd", "title": "EURUSD"},
            {"id": "usdjpy", "title": "USDJPY"},
            {"id": "btcusd", "title": "BTCUSD"}
          ]}
        ]
      }
    }
  }'
"""

from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.responses import PlainTextResponse, HTMLResponse
from twilio.request_validator import RequestValidator
import os
from backend.mt5_order_utils import place_order_mt5, close_order_mt5, close_all_mt5, modify_order_mt5
from twilio.rest import Client
import requests
import threading
import time
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, PlainTextResponse
import json
from pathlib import Path
import streamlit as st
from frontend.whatsapp_notify import send_whatsapp_message_unified as send_whatsapp_message

app = FastAPI()
router = APIRouter()

onglets = st.tabs(["Tableau de bord", "Messagerie WhatsApp"])

# IMPORTANT : L'endpoint doit être appelé SANS slash final (/whatsapp_webhook), sinon FastAPI redirige ou retourne 405.
# Utilise toujours https://<ngrok-url>/whatsapp_webhook (pas de slash à la fin) dans Twilio et tes tests.

# --- Token Twilio (à mettre dans une variable d'environnement en production !) ---
TWILIO_AUTH_TOKEN = "8ee2b981c70120c9342e9ebbcd642dc9"
validator = RequestValidator(TWILIO_AUTH_TOKEN)

AUTHORIZED_NUMBERS = None  # Optionnel : liste blanche de numéros WhatsApp

# --- État utilisateur en mémoire (clé = numéro WhatsApp) ---
USER_STATE = {}
USER_STATE_LOCK = threading.Lock()

MENU_MAIN = "MENU_MAIN"
MENU_ORDER = "MENU_ORDER"
MENU_SYMBOLS = "MENU_SYMBOLS"
MENU_POSITIONS = "MENU_POSITIONS"
MENU_AIDE = "MENU_AIDE"
MENU_STATUT = "MENU_STATUT"
MENU_TECH_ANALYSIS = "MENU_TECH_ANALYSIS"
MENU_FUNDAMENTAL = "MENU_FUNDAMENTAL"
MENU_LAST_SIGNAL = "MENU_LAST_SIGNAL"

# --- Navigation symboles interactive ---
MENU_CATEGORIES = "CHOIX_CATEGORIE"
MENU_SYMBOLS = "CHOIX_SYMBOLE"

# Affiche la liste des catégories numérotées
def show_symbol_categories(user):
    from backend.mt5_connector import get_symbols_by_category
    categories = get_symbols_by_category()
    user_state = get_user_state(user)
    user_state['categories'] = list(categories.keys())
    set_user_state(user, {**user_state, 'menu': MENU_CATEGORIES})
    msg = "📊 Catégories disponibles :\n"
    for idx, cat in enumerate(user_state['categories'], 1):
        msg += f"{idx}. {cat} ({len(categories[cat])})\n"
    msg += "\nTape le numéro de la catégorie pour voir les symboles, ou 'menu' pour revenir."
    return msg

# Affiche la liste des symboles d'une catégorie numérotés
def show_symbols_in_category(user, cat_idx):
    from backend.mt5_connector import get_symbols_by_category
    categories = get_symbols_by_category()
    user_state = get_user_state(user)
    cat_list = list(categories.keys())
    if not (1 <= cat_idx <= len(cat_list)):
        return "Numéro de catégorie invalide."
    cat = cat_list[cat_idx-1]
    symbols = categories[cat]
    user_state['symbols'] = symbols
    user_state['current_category'] = cat
    set_user_state(user, {**user_state, 'menu': MENU_SYMBOLS})
    msg = f"📁 {cat} ({len(symbols)}) :\n"
    for idx, sym in enumerate(symbols, 1):
        msg += f"{idx}. {sym}\n"
    msg += "\nTape le numéro du symbole pour voir le détail, ou 'menu' pour revenir."
    return msg

# Affiche le détail d'un symbole
def show_symbol_detail(user, sym_idx):
    user_state = get_user_state(user)
    symbols = user_state.get('symbols', [])
    if not (1 <= sym_idx <= len(symbols)):
        return "Numéro de symbole invalide."
    symbol = symbols[sym_idx-1]
    # Exemple de détail (à enrichir selon tes besoins)
    msg = f"🔎 Détail pour {symbol} :\n- Catégorie : {user_state.get('current_category', '')}\n- Tape 'menu' pour revenir."
    return msg

MENU_MAP = {
    "1": MENU_STATUT, "statut": MENU_STATUT, "status": MENU_STATUT,
    "2": MENU_SYMBOLS, "symboles": MENU_SYMBOLS, "symbols": MENU_SYMBOLS, "symbole": MENU_SYMBOLS,
    "3": MENU_ORDER, "ordre": MENU_ORDER, "order": MENU_ORDER,
    "4": MENU_POSITIONS, "positions": MENU_POSITIONS, "position": MENU_POSITIONS,
    "5": MENU_AIDE, "aide": MENU_AIDE, "help": MENU_AIDE,
    "6": "MENU_AUTO_MONITOR", "auto-monitor": "MENU_AUTO_MONITOR",
    "7": MENU_TECH_ANALYSIS, "analyse technique": MENU_TECH_ANALYSIS, "technical": MENU_TECH_ANALYSIS,
    "8": MENU_FUNDAMENTAL, "analyse fondamentale": MENU_FUNDAMENTAL, "fundamental": MENU_FUNDAMENTAL,
    "9": MENU_LAST_SIGNAL, "dernier signal": MENU_LAST_SIGNAL, "last signal": MENU_LAST_SIGNAL,
    "10": "MENU_TREND", "tendance": "MENU_TREND", "trend": "MENU_TREND",
    "0": MENU_MAIN, "menu": MENU_MAIN
}

def get_user_state(user):
    with USER_STATE_LOCK:
        return USER_STATE.get(user, {"menu": MENU_MAIN})

def set_user_state(user, state):
    with USER_STATE_LOCK:
        USER_STATE[user] = state

def reset_user_state(user):
    set_user_state(user, {"menu": MENU_MAIN})

def menu_main():
    return (
        "Bienvenue sur TradBOT WhatsApp ! 🤖\n\n"
        "Menu principal :\n"
        "1. Statut du bot - Voir l'état actuel du bot\n"
        "2. Liste des symboles - Afficher tous les symboles disponibles\n"
        "3. Passer un ordre - Acheter ou vendre un actif\n"
        "4. Voir les positions ouvertes - Liste et gestion des positions\n"
        "5. Aide / Commandes - Obtenir de l'aide sur les commandes\n"
        "6. Auto-Monitor - Contrôler le moniteur automatique\n"
        "7. Analyse technique - Recevoir une analyse technique d'un symbole\n"
        "8. Analyse fondamentale - Recevoir une analyse fondamentale d'un symbole\n"
        "9. Dernier signal - Voir le dernier signal généré\n"
        "10. Tendance consolidée - Recevoir la tendance multi-timeframe\n"
        "11. Modifier un ordre (SL/TP)\n"
        "12. Historique des trades\n"
        "13. Performance\n"
        "14. Favoris\n"
        "15. Alertes\n"
        "16. Configuration\n"
        "17. Support/FAQ\n"
        "18. Assistant IA (Gemma3)\n"
        "0. Revenir au menu principal\n\n"
        "Réponds par le numéro ou le mot-clé (ex : 1 ou statut)\n"
        "\n"
        "💡 Astuce : Tu peux aussi envoyer 'menu' à tout moment pour revenir ici.\n"
        "\n"
        "Commandes rapides : /modif, /historique, /perf, /favoris, /alerte, /config, /faq, /support, /ia, /gemma"
    )

def menu_statut():
    # TODO: Statut dynamique
    return (
        "✅ Statut du bot :\n"
        "- Auto-monitor : actif\n"
        "- Dernier signal : EURUSD BUY à 1.12345\n"
        "- Solde : 10 000 $\n"
        "Tape 0 pour revenir au menu principal."
    )

def menu_symbols(user=None):
    from backend.mt5_connector import get_symbols_by_category
    from backend.whatsapp_utils import send_whatsapp_message
    try:
        categories = get_symbols_by_category()
    except Exception as e:
        return f"❌ Erreur lors de la récupération des symboles : {e}"

    # Envoie un message par catégorie
    for categorie, symboles in categories.items():
        if not symboles:
            continue
        msg = f"📁 {categorie} ({len(symboles)}) :\n"
        for i in range(0, len(symboles), 10):
            msg += "  " + ", ".join(symboles[i:i+10]) + "\n"
        # Envoie le message pour chaque catégorie
        if user:
            send_whatsapp_message(msg, user)
        else:
            send_whatsapp_message(msg)
    return "📊 Liste des symboles envoyée par catégorie. Tape le nom d'un symbole pour plus d'infos ou 'menu' pour revenir."

def menu_order():
    return (
        "📝 Passer un ordre de trading :\n"
        "Syntaxe :\n"
        "ORDRE [BUY/SELL] [SYMBOL] [LOT] [PRIX] [SL] [TP]\n"
        "Exemple :\n"
        "ORDRE BUY EURUSD 0.1 1.12345 1.12000 1.13000\n"
        "\n"
        "Paramètres :\n"
        "- BUY/SELL : sens de l'ordre\n"
        "- SYMBOL : nom du symbole (ex : EURUSD)\n"
        "- LOT : taille de la position (ex : 0.1)\n"
        "- PRIX : prix d'entrée (optionnel, sinon marché)\n"
        "- SL : stop loss (optionnel)\n"
        "- TP : take profit (optionnel)\n"
        "\n"
        "Tape 0 pour revenir au menu principal."
    )

def menu_positions():
    try:
        from backend.mt5_connector import get_open_positions
        positions = get_open_positions()
    except Exception as e:
        return f"❌ Erreur récupération positions : {e}"
    if not positions:
        return "Aucune position ouverte actuellement.\nTape 0 pour revenir au menu principal."
    msg = "📂 Positions ouvertes :\n"
    for pos in positions:
        msg += f"- {pos['symbol']} | {pos['type']} | Lot: {pos['volume']} | Prix: {pos['price_open']} | PnL: {pos['profit']:.2f}\n"
    msg += "\nPour fermer une position :\nCLOSE [SYMBOL]\nExemple : CLOSE EURUSD\n"
    msg += "Tape 0 pour revenir au menu principal."
    return msg

def menu_modif():
    return (
        "✏️ Modifier SL/TP d'une position :\n"
        "Réponds étape par étape :\n"
        "1. Indique le symbole à modifier (ex: EURUSD)\n"
        "2. Indique le nouveau SL (ou laisse vide)\n"
        "3. Indique le nouveau TP (ou laisse vide)\n"
        "Tape 0 pour revenir au menu principal."
    )

def menu_stop_all():
    return (
        "🛑 Fermer toutes les positions ouvertes :\n"
        "Syntaxe :\n"
        "STOP ALL\n"
        "Tape 0 pour revenir au menu principal."
    )

def menu_aide():
    return (
        "Commandes disponibles :\n"
        "1. STATUT – Voir le statut du bot\n"
        "2. SYMBOLES – Liste des symboles\n"
        "3. ORDRE – Passer un ordre\n"
        "4. POSITIONS – Voir/fermer les positions\n"
        "5. MENU – Revenir au menu principal\n"
        "TENDANCE ou /trend – Recevoir la tendance consolidée multi-timeframe\n"
    )

def menu_auto_monitor():
    return (
        "⚙️ Contrôle Auto-Monitor :\n"
        "- /start : Démarrer l'auto-moniteur\n"
        "- /stop : Arrêter l'auto-moniteur\n"
        "- /status : Voir l'état du moniteur\n"
        "- /monitor_stats : Statistiques scans/signaux\n"
        "- /monitor_config clé valeur : Modifier la config (ex: /monitor_config intervalle 5)\n"
        "  Clés possibles : intervalle, min_conf, max_signaux, categories\n"
        "  Exemples : /monitor_config intervalle 5 | /monitor_config min_conf 60 | /monitor_config categories forex,synthetic_index\n"
        "Tape la commande ou 0 pour revenir au menu principal."
    )

def menu_monitor_stats():
    try:
        from backend.auto_signal_monitor import get_monitor_status
        stats = get_monitor_status()
    except Exception as e:
        return f"❌ Erreur récupération stats : {e}"
    msg = (
        "📊 Statistiques Auto-Monitor :\n"
        f"- Scans effectués : {stats.get('scan_count', 0)}\n"
        f"- Signaux générés : {stats.get('signals_generated', 0)}\n"
        f"- Signaux acceptés : {stats.get('signals_accepted', 0)}\n"
        f"- Signaux rejetés : {stats.get('signals_rejected', 0)}\n"
        f"- Dernier signal accepté : {stats.get('last_signal', 'N/A')}\n"
        "Tape 0 pour revenir au menu principal."
    )
    return msg

def menu_tech_analysis(user, symbol=None):
    if not symbol:
        return "Envoie le symbole à analyser (ex: EURUSD, BTCUSD, AAPL) :"
    try:
        import pandas as pd
        from backend.technical_analysis import add_technical_indicators, get_trend_analysis, get_support_resistance_levels
        from backend.mt5_connector import get_ohlc
        # Récupérer les données OHLC (par défaut 100 bougies 1H)
        df = get_ohlc(symbol, timeframe='1h', count=100)
        if df is None or df.empty:
            set_user_state(user, {"menu": MENU_MAIN, "last_symbol": symbol})
            return f"❌ Impossible de récupérer les données pour {symbol}. Ce symbole n'est pas supporté. Veux-tu la liste des symboles disponibles ? (oui/non)"
        df = add_technical_indicators(df)
        trend = get_trend_analysis(df)
        levels = get_support_resistance_levels(df)
        set_user_state(user, {"menu": "AWAIT_ORDER_CONFIRM", "last_symbol": symbol})
        msg = f"\U0001F4C8 Analyse technique de {symbol} :\n"
        msg += f"- Tendance : {trend.get('trend','?')} (force : {trend.get('trend_strength','?')})\n"
        msg += f"- Momentum (RSI) : {trend.get('momentum','?')}\n"
        msg += f"- Volatilité : {trend.get('volatility','?')}\n"
        if levels:
            if 'pivot' in levels:
                msg += f"- Pivot : {levels['pivot']:.5f}\n"
            if 'resistance' in levels and levels['resistance']:
                msg += f"- Résistances : {', '.join([f'{r:.5f}' for r in levels['resistance']])}\n"
            if 'support' in levels and levels['support']:
                msg += f"- Supports : {', '.join([f'{s:.5f}' for s in levels['support']])}\n"
        msg += f"\nVeux-tu passer un ordre sur {symbol} ? (oui/non)"
        return msg
    except Exception as e:
        set_user_state(user, {"menu": MENU_MAIN, "last_symbol": symbol})
        return f"Erreur analyse technique : {e}\nTape 0 pour revenir au menu principal."

def menu_fundamental(user, symbol=None):
    if not symbol:
        return "Envoie le symbole à analyser (ex: EURUSD, BTCUSD, AAPL) :"
    try:
        from backend.fundamental_analysis import get_fundamental_analysis
        analysis = get_fundamental_analysis(symbol)
        if 'error' in analysis:
            set_user_state(user, {"menu": MENU_MAIN, "last_symbol": symbol})
            return f"❌ {analysis['error']}\nCe symbole n'est pas supporté. Veux-tu la liste des symboles disponibles ? (oui/non)"
        msg = f"\U0001F4CA Analyse fondamentale de {symbol} :\n"
        if 'recommendation' in analysis:
            msg += f"- Recommandation : {analysis['recommendation']} (confiance : {analysis.get('confidence','?')}%)\n"
        if 'economic_factors' in analysis:
            ef = analysis['economic_factors']
            if isinstance(ef, dict):
                for k, v in ef.items():
                    msg += f"- {k.capitalize()} : {v}\n"
            elif isinstance(ef, list):
                for v in ef:
                    msg += f"- {v}\n"
        if 'risk_factors' in analysis and isinstance(analysis['risk_factors'], list) and analysis['risk_factors']:
            msg += f"- Risques : {', '.join(str(r) for r in analysis['risk_factors'])}\n"
        set_user_state(user, {"menu": "AWAIT_ORDER_CONFIRM", "last_symbol": symbol})
        msg += f"\nVeux-tu passer un ordre sur {symbol} ? (oui/non)"
        return msg
    except Exception as e:
        set_user_state(user, {"menu": MENU_MAIN, "last_symbol": symbol})
        return f"Erreur analyse fondamentale : {e}\nTape 0 pour revenir au menu principal."

def menu_last_signal(user):
    import json
    from pathlib import Path
    files = ["alpha_vantage_signals.json", "polygon_signals.json"]
    last = None
    for f in files:
        p = Path(f)
        if p.exists():
            with p.open("r", encoding="utf-8") as file:
                lines = file.readlines()
                if lines:
                    sig = json.loads(lines[-1])
                    if not last or sig.get("timestamp","") > last.get("timestamp",""):
                        last = sig
    if last:
        return f"Dernier signal :\n{last['message']}\nTape 0 pour revenir au menu principal."
    else:
        return "Aucun signal enregistré pour l'instant. Tape 0 pour revenir au menu principal."

def menu_trend_consolidated(user=None):
    import json
    from pathlib import Path
    from frontend.whatsapp_notify import send_whatsapp_message_unified as send_whatsapp_message
    try:
        file = Path("trend_summary.json")
        if not file.exists():
            return "Aucune donnée de tendance consolidée disponible pour le moment."
        with file.open("r", encoding="utf-8") as f:
            trend_data = json.load(f)
        tf_order = ["1d", "8h", "6h", "4h", "1h", "30m", "15m", "5m", "1m"]
        tf_labels = ["D1", "H8", "H6", "H4", "H1", "M30", "M15", "M5", "M1"]
        lines = [f"📊 Tendance consolidée pour {trend_data.get('symbol', '?')}"]
        for tf, label in zip(tf_order, tf_labels):
            tf_info = trend_data["trends"].get(tf, {})
            trend = tf_info.get("trend", "?")
            force = tf_info.get("force", "?")
            try:
                force_pct = f"{int(force)}%" if force != "?" else "?"
            except:
                force_pct = "?"
            lines.append(f"{label} : {trend} ({force_pct})")
        lines.append(f"Synthèse : {trend_data.get('consolidated', '?')} | Scalping possible : {trend_data.get('scalping_possible', '?')}")
        msg = "\n".join(lines)
        if user:
            send_whatsapp_message(msg, user)
        return msg
    except Exception as e:
        return f"Erreur lors de la récupération de la tendance consolidée : {e}"

def ask_gemma3(prompt, user_state=None):
    import subprocess
    import sys
    # Contexte TradBOT
    context = (
        "Tu es l'assistant IA de TradBOT, une plateforme de trading algorithmique avancée. "
        "Tu as accès aux signaux, tendances multi-timeframe, analyses techniques et fondamentales, "
        "et tu aides l'utilisateur à prendre de bonnes décisions de trading. "
    )
    # Ajoute le dernier symbole ou tendance si dispo
    if user_state:
        symbol = user_state.get('symbol') or user_state.get('last_symbol')
        if symbol:
            context += f"Le symbole principal est : {symbol}. "
        trend = user_state.get('trend_heatmap_data', {}).get('consolidated') if user_state.get('trend_heatmap_data') else None
        if trend:
            context += f"La tendance consolidée actuelle est : {trend}. "
    context += "Voici la question de l'utilisateur : "
    full_prompt = context + prompt
    try:
        result = subprocess.run([
            "ollama", "run", "gemma3"],
            input=full_prompt.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=180
        )
        output = result.stdout.decode("utf-8").strip()
        return output if output else "[Aucune réponse de Gemma3]"
    except Exception as e:
        return "⏳ L'IA a mis trop de temps à répondre ou a rencontré une erreur. Essaie une question plus courte ou réessaie dans quelques instants."

# Ajout des nouveaux états pour l'interaction étape par étape
AWAIT_ORDER_TYPE = "AWAIT_ORDER_TYPE"
AWAIT_ORDER_SYMBOL = "AWAIT_ORDER_SYMBOL"
AWAIT_ORDER_LOT = "AWAIT_ORDER_LOT"
AWAIT_ORDER_PRICE = "AWAIT_ORDER_PRICE"
AWAIT_ORDER_SL = "AWAIT_ORDER_SL"
AWAIT_ORDER_TP = "AWAIT_ORDER_TP"
AWAIT_TECH_SYMBOL = "AWAIT_TECH_SYMBOL"
AWAIT_FUND_SYMBOL = "AWAIT_FUND_SYMBOL"
AWAIT_ORDER_CONFIRM = "AWAIT_ORDER_CONFIRM"
# Nouveaux états pour interactions avancées
AWAIT_MODIF_SYMBOL = "AWAIT_MODIF_SYMBOL"
AWAIT_MODIF_SL = "AWAIT_MODIF_SL"
AWAIT_MODIF_TP = "AWAIT_MODIF_TP"
AWAIT_ALERT_SYMBOL = "AWAIT_ALERT_SYMBOL"
AWAIT_ALERT_TYPE = "AWAIT_ALERT_TYPE"
AWAIT_ALERT_VALUE = "AWAIT_ALERT_VALUE"
AWAIT_FAVORIS_ACTION = "AWAIT_FAVORIS_ACTION"
AWAIT_FAVORIS_SYMBOL = "AWAIT_FAVORIS_SYMBOL"
AWAIT_CONFIG_TYPE = "AWAIT_CONFIG_TYPE"
AWAIT_CONFIG_VALUE = "AWAIT_CONFIG_VALUE"
AWAIT_SUPPORT_QUESTION = "AWAIT_SUPPORT_QUESTION"
AWAIT_GEMMA3 = "AWAIT_GEMMA3"

MENU_MAP.update({
    "18": "MENU_GEMMA3", "ia": "MENU_GEMMA3", "gemma": "MENU_GEMMA3", "/ia": "MENU_GEMMA3", "/gemma": "MENU_GEMMA3"
})

def menu_gemma3():
    return (
        "🤖 Assistant IA (Gemma3) :\n"
        "Pose ta question à l'IA (ex: 'avis ia EURUSD', 'conseil sur le money management', 'explique le RSI', etc.)\n"
        "Tape 0 pour revenir au menu principal."
    )

def handle_menu(user, message):
    state = get_user_state(user)
    menu = state.get("menu", MENU_MAIN)
    msg = message.strip()
    # --- Menu principal interactif (boutons) ---
    if msg.lower() in ["menu", "0"]:
        send_whatsapp_message(
            message=None,
            interactive={
                "type": "button",
                "body": {"text": "Bienvenue sur TradBOT WhatsApp ! 🤖\nQue veux-tu faire ?"},
                "action": {
                    "buttons": [
                        {"type": "reply", "reply": {"id": "statut", "title": "Statut du bot"}},
                        {"type": "reply", "reply": {"id": "symboles", "title": "Liste des symboles"}},
                        {"type": "reply", "reply": {"id": "ordre", "title": "Passer un ordre"}}
                    ]
                }
            }
        )
        return "Menu interactif envoyé. Si tu ne vois pas les boutons, tape le numéro ou le mot-clé."
    # --- Callback des boutons du menu principal ---
    if msg.lower().startswith("payload:"):
        payload_id = msg[8:].strip().lower()
        if payload_id == "statut":
            return menu_statut()
        if payload_id == "symboles":
            # Sous-menu interactif : liste de catégories
            categories = [
                {"id": "forex", "title": "Forex"},
                {"id": "synthetic", "title": "Synthetic Index"},
                {"id": "crypto", "title": "Crypto"}
            ]
            send_whatsapp_message(
                message=None,
                interactive={
                    "type": "list",
                    "body": {"text": "Choisis une catégorie de symboles"},
                    "action": {
                        "button": "Voir les catégories",
                        "sections": [
                            {"title": "Catégories", "rows": categories}
                        ]
                    }
                }
            )
            return "Menu catégories envoyé. Si tu ne vois pas la liste, tape le nom de la catégorie."
        if payload_id == "ordre":
            set_user_state(user, {"menu": AWAIT_ORDER_TYPE})
            return "📝 Veux-tu BUY ou SELL ? (ex: BUY)\nTape 0 pour revenir au menu principal."
        # Callback d'une catégorie (ex: forex, synthetic, crypto)
        if payload_id in ["forex", "synthetic", "crypto"]:
            return f"Tu as choisi la catégorie : {payload_id}. (Affichage des symboles à venir)"
    # Gestion des payloads/callbacks (pour migration future)
    if msg.lower().startswith("payload:"):
        payload = msg[8:]
        # TODO: gérer les payloads interactifs ici
        return "[Fonctionnalité bouton à venir]"
    # Ajout détection commande tendance consolidée
    if msg.lower() in ["trend", "/trend", "tendance", "10"]:
        return menu_trend_consolidated(user)
    # Gestion de la relance pour symbole non supporté
    if menu == MENU_MAIN and msg.lower() in ["oui", "yes"] and state.get("last_symbol_error", False):
        set_user_state(user, {"menu": MENU_MAIN})
        return menu_symbols(user)
    # --- INTERACTION ETAPE PAR ETAPE POUR PASSER UN ORDRE (Menu 3) ---
    if menu == MENU_ORDER or menu == AWAIT_ORDER_TYPE:
        if menu == MENU_ORDER:
            set_user_state(user, {"menu": AWAIT_ORDER_TYPE})
            return "📝 Veux-tu BUY ou SELL ? (ex: BUY)\nTape 0 pour revenir au menu principal."
        if menu == AWAIT_ORDER_TYPE:
            if msg.upper() not in ["BUY", "SELL"]:
                return "Merci de répondre par BUY ou SELL.\nTape 0 pour revenir au menu principal."
            set_user_state(user, {"menu": AWAIT_ORDER_SYMBOL, "order_type": msg.upper()})
            return "Quel symbole veux-tu trader ? (ex: EURUSD)\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_ORDER_SYMBOL:
        set_user_state(user, {**state, "menu": AWAIT_ORDER_LOT, "symbol": msg.upper()})
        return "Quel volume (lot) ? (ex: 0.1)\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_ORDER_LOT:
        try:
            lot = float(msg.replace(",", "."))
            set_user_state(user, {**state, "menu": AWAIT_ORDER_PRICE, "lot": lot})
            return "Prix d'entrée (laisser vide pour marché) ? (ex: 1.12345 ou tape 'marche')\nTape 0 pour revenir au menu principal."
        except Exception:
            return "Merci d'indiquer un nombre pour le lot.\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_ORDER_PRICE:
        price = None
        if msg.lower() not in ["", "marche", "marché"]:
            try:
                price = float(msg.replace(",", "."))
            except Exception:
                return "Merci d'indiquer un prix valide ou 'marche'.\nTape 0 pour revenir au menu principal."
        set_user_state(user, {**state, "menu": AWAIT_ORDER_SL, "price": price})
        return "Stop Loss (SL) ? (laisser vide pour aucun)\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_ORDER_SL:
        sl = None
        if msg.strip() != "":
            try:
                sl = float(msg.replace(",", "."))
            except Exception:
                return "Merci d'indiquer un nombre pour le SL ou laisser vide.\nTape 0 pour revenir au menu principal."
        set_user_state(user, {**state, "menu": AWAIT_ORDER_TP, "sl": sl})
        return "Take Profit (TP) ? (laisser vide pour aucun)\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_ORDER_TP:
        tp = None
        if msg.strip() != "":
            try:
                tp = float(msg.replace(",", "."))
            except Exception:
                return "Merci d'indiquer un nombre pour le TP ou laisser vide.\nTape 0 pour revenir au menu principal."
        # On a toutes les infos, on passe l'ordre !
        order_type = state.get("order_type")
        symbol = state.get("symbol")
        lot = state.get("lot")
        price = state.get("price")
        sl = state.get("sl")
        from backend.mt5_order_utils import place_order_mt5
        ok, msg_order = place_order_mt5(symbol, order_type, lot, price, sl, tp)
        set_user_state(user, {"menu": MENU_MAIN})
        return f"{msg_order}\n\n0. Menu principal"
    # --- INTERACTION ETAPE PAR ETAPE POUR ANALYSE TECHNIQUE (Menu 7) ---
    if menu == MENU_TECH_ANALYSIS or menu == AWAIT_TECH_SYMBOL:
        if menu == MENU_TECH_ANALYSIS:
            set_user_state(user, {"menu": AWAIT_TECH_SYMBOL})
            return "Quel symbole veux-tu analyser techniquement ? (ex: EURUSD)\nTape 0 pour revenir au menu principal."
        if menu == AWAIT_TECH_SYMBOL:
            symbol = msg.upper()
            result = menu_tech_analysis(user, symbol)
            # Si analyse OK, propose de passer un ordre
            if result.startswith("\U0001F4C8 Analyse technique"):
                set_user_state(user, {"menu": AWAIT_ORDER_CONFIRM, "last_symbol": symbol})
                return result + "\n\nVeux-tu passer un ordre sur ce symbole ? (oui/non)\nTape 0 pour revenir au menu principal."
            else:
                set_user_state(user, {"menu": MENU_MAIN})
                return result + "\n\n0. Menu principal"
    # --- INTERACTION ETAPE PAR ETAPE POUR ANALYSE FONDAMENTALE (Menu 8) ---
    if menu == MENU_FUNDAMENTAL or menu == AWAIT_FUND_SYMBOL:
        if menu == MENU_FUNDAMENTAL:
            set_user_state(user, {"menu": AWAIT_FUND_SYMBOL})
            return "Quel symbole veux-tu analyser fondamentalement ? (ex: EURUSD)\nTape 0 pour revenir au menu principal."
        if menu == AWAIT_FUND_SYMBOL:
            symbol = msg.upper()
            result = menu_fundamental(user, symbol)
            # Si analyse OK, propose de passer un ordre
            if result.startswith("\U0001F4CA Analyse fondamentale"):
                set_user_state(user, {"menu": AWAIT_ORDER_CONFIRM, "last_symbol": symbol})
                return result + "\n\nVeux-tu passer un ordre sur ce symbole ? (oui/non)\nTape 0 pour revenir au menu principal."
            else:
                set_user_state(user, {"menu": MENU_MAIN})
                return result + "\n\n0. Menu principal"
    # --- Confirmation de passage d'ordre après analyse ---
    if menu == AWAIT_ORDER_CONFIRM:
        if msg.lower() in ["oui", "yes"]:
            set_user_state(user, {"menu": AWAIT_ORDER_TYPE})
            return "📝 Veux-tu BUY ou SELL ? (ex: BUY)\nTape 0 pour revenir au menu principal."
        else:
            set_user_state(user, {"menu": MENU_MAIN})
            return "Ok, je reste à ta disposition ! Tape 0 pour revenir au menu principal."
    # Gestion de la mémorisation du dernier symbole pour requêtes rapides
    if menu == MENU_MAIN and msg.lower() in ["analyse fondamentale du même symbole", "analyse fondamentale du meme symbole", "analyse fondamentale du dernier symbole"]:
        symbol = state.get("last_symbol", None)
        if symbol:
            return menu_fundamental(user, symbol)
        else:
            return "Aucun symbole mémorisé. Envoie d'abord une analyse sur un symbole."
    if menu == MENU_MAIN and msg.lower() in ["analyse technique du même symbole", "analyse technique du meme symbole", "analyse technique du dernier symbole"]:
        symbol = state.get("last_symbol", None)
        if symbol:
            return menu_tech_analysis(user, symbol)
        else:
            return "Aucun symbole mémorisé. Envoie d'abord une analyse sur un symbole."
    # Navigation symboles interactive
    if menu == MENU_MAIN and msg.lower() in ["2", "symboles", "liste des symboles"]:
        return show_symbol_categories(user)
    if menu == MENU_CATEGORIES:
        try:
            idx = int(msg)
            return show_symbols_in_category(user, idx)
        except Exception:
            return "Réponds par le numéro de la catégorie."
    if menu == MENU_SYMBOLS:
        try:
            idx = int(msg)
            return show_symbol_detail(user, idx)
        except Exception:
            return "Réponds par le numéro du symbole."
    # Navigation par numéro ou mot-clé
    if msg.lower() in [k for k in MENU_MAP]:
        menu = MENU_MAP[msg.lower()]
        set_user_state(user, {"menu": menu})
    # Gestion des menus
    if menu == MENU_MAIN:
        return menu_main()
    elif menu == MENU_STATUT:
        set_user_state(user, {"menu": MENU_MAIN})
        return menu_statut() + "\n\n0. Menu principal"
    elif menu == MENU_SYMBOLS:
        set_user_state(user, {"menu": MENU_MAIN})
        return menu_symbols(user) + "\n\n0. Menu principal"
    elif menu == MENU_ORDER:
        set_user_state(user, {"menu": AWAIT_ORDER_TYPE})
        return "📝 Veux-tu BUY ou SELL ? (ex: BUY)\nTape 0 pour revenir au menu principal."
    elif menu == MENU_POSITIONS:
        set_user_state(user, {"menu": MENU_MAIN})
        return menu_positions() + "\n\n0. Menu principal"
    elif menu == MENU_AIDE:
        set_user_state(user, {"menu": MENU_MAIN})
        return menu_aide() + "\n\n0. Menu principal"
    elif menu == "MENU_AUTO_MONITOR":
        set_user_state(user, {"menu": MENU_MAIN})
        return menu_auto_monitor() + "\n\n0. Menu principal"
    elif menu == MENU_TECH_ANALYSIS:
        set_user_state(user, {"menu": AWAIT_TECH_SYMBOL})
        return "Quel symbole veux-tu analyser techniquement ? (ex: EURUSD)\nTape 0 pour revenir au menu principal."
    elif menu == MENU_FUNDAMENTAL:
        set_user_state(user, {"menu": AWAIT_FUND_SYMBOL})
        return "Quel symbole veux-tu analyser fondamentalement ? (ex: EURUSD)\nTape 0 pour revenir au menu principal."
    elif menu == MENU_LAST_SIGNAL:
        set_user_state(user, {"menu": MENU_MAIN})
        return menu_last_signal(user) + "\n\n0. Menu principal"
    elif menu == "MENU_TREND":
        set_user_state(user, {"menu": MENU_MAIN})
        return menu_trend_consolidated(user) + "\n\n0. Menu principal"
    elif menu == MENU_MAIN and msg.lower() in ["auto-monitor", "monitor", "moniteur", "6"]:
        return menu_auto_monitor()
    if msg.lower() in ["/monitor_stats", "monitor_stats", "stats"]:
        return menu_monitor_stats()
    if msg.lower() in ["/start", "start"]:
        from backend.auto_signal_monitor import start_auto_monitor
        start_auto_monitor()
        return "🚀 Auto-moniteur démarré ! Tape /status pour l'état."
    if msg.lower() in ["/stop", "stop"]:
        from backend.auto_signal_monitor import stop_auto_monitor
        stop_auto_monitor()
        return "🛑 Auto-moniteur arrêté. Tape /status pour l'état."
    if msg.lower() in ["/status", "status"]:
        from backend.auto_signal_monitor import get_monitor_status
        status = get_monitor_status()
        return f"⚙️ Statut Auto-Monitor : {status}"
    # --- INTERACTION ETAPE PAR ETAPE POUR MODIFICATION D'ORDRE (Menu 11) ---
    if menu == "MENU_MODIF" or menu == AWAIT_MODIF_SYMBOL:
        if menu == "MENU_MODIF":
            set_user_state(user, {"menu": AWAIT_MODIF_SYMBOL})
            return "Quel symbole veux-tu modifier ? (ex: EURUSD)\nTape 0 pour revenir au menu principal."
        if menu == AWAIT_MODIF_SYMBOL:
            set_user_state(user, {**state, "menu": AWAIT_MODIF_SL, "modif_symbol": msg.upper()})
            return "Nouveau Stop Loss (SL) ? (laisser vide pour inchangé)\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_MODIF_SL:
        sl = None
        if msg.strip() != "":
            try:
                sl = float(msg.replace(",", "."))
            except Exception:
                return "Merci d'indiquer un nombre pour le SL ou laisser vide.\nTape 0 pour revenir au menu principal."
        set_user_state(user, {**state, "menu": AWAIT_MODIF_TP, "modif_sl": sl})
        return "Nouveau Take Profit (TP) ? (laisser vide pour inchangé)\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_MODIF_TP:
        tp = None
        if msg.strip() != "":
            try:
                tp = float(msg.replace(",", "."))
            except Exception:
                return "Merci d'indiquer un nombre pour le TP ou laisser vide.\nTape 0 pour revenir au menu principal."
        symbol = state.get("modif_symbol")
        sl = state.get("modif_sl")
        from backend.mt5_order_utils import modify_order_mt5
        ok, msg_modif = modify_order_mt5(symbol, sl, tp)
        set_user_state(user, {"menu": MENU_MAIN})
        return f"{msg_modif}\n\n0. Menu principal"
    # --- INTERACTION HISTORIQUE (Menu 12) ---
    if menu == "MENU_HISTORIQUE":
        set_user_state(user, {"menu": MENU_MAIN})
        # Ici, on peut filtrer par symbole ou tout afficher
        if msg.lower() in ["tous", "all", "*"]:
            # Charger tout l'historique (exemple simplifié)
            from backend.trade_history import load_trade_history
            trades = load_trade_history()
            if not trades:
                return "Aucun trade enregistré.\n0. Menu principal"
            return f"{len(trades)} trades trouvés.\nExemple :\n{trades[-1]}\n0. Menu principal"
        else:
            from backend.trade_history import load_trade_history
            trades = load_trade_history()
            filtered = [t for t in trades if t.get('symbol', '').upper() == msg.upper()]
            if not filtered:
                return f"Aucun trade trouvé pour {msg.upper()}.\n0. Menu principal"
            return f"{len(filtered)} trades pour {msg.upper()}.\nExemple :\n{filtered[-1]}\n0. Menu principal"
    # --- INTERACTION PERFORMANCE (Menu 13) ---
    if menu == "MENU_PERF":
        set_user_state(user, {"menu": MENU_MAIN})
        # Exemple simplifié
        from backend.trade_history import load_trade_history
        trades = load_trade_history()
        if not trades:
            return "Aucune donnée de performance.\n0. Menu principal"
        total = sum(t.get('result', 0) for t in trades)
        win = sum(1 for t in trades if t.get('result', 0) > 0)
        loss = sum(1 for t in trades if t.get('result', 0) < 0)
        winrate = win / (win + loss) * 100 if (win + loss) > 0 else 0
        return f"Performance :\n- Total PnL : {total:.2f}\n- Winrate : {winrate:.1f}%\n- Trades : {len(trades)}\n0. Menu principal"
    # --- INTERACTION FAVORIS (Menu 14) ---
    if menu == "MENU_FAVORIS" or menu == AWAIT_FAVORIS_ACTION:
        if menu == "MENU_FAVORIS":
            set_user_state(user, {"menu": AWAIT_FAVORIS_ACTION})
            return "Tape 'ajouter' pour ajouter un favori, 'retirer' pour en retirer, ou 'liste' pour voir tes favoris.\nTape 0 pour revenir au menu principal."
        if menu == AWAIT_FAVORIS_ACTION:
            if msg.lower() == "ajouter":
                set_user_state(user, {**state, "menu": AWAIT_FAVORIS_SYMBOL, "favoris_action": "ajouter"})
                return "Quel symbole veux-tu ajouter aux favoris ?\nTape 0 pour revenir au menu principal."
            elif msg.lower() == "retirer":
                set_user_state(user, {**state, "menu": AWAIT_FAVORIS_SYMBOL, "favoris_action": "retirer"})
                return "Quel symbole veux-tu retirer des favoris ?\nTape 0 pour revenir au menu principal."
            elif msg.lower() == "liste":
                favoris = state.get("favoris", [])
                return f"Favoris actuels : {', '.join(favoris) if favoris else 'Aucun.'}\n0. Menu principal"
            else:
                return "Merci de répondre par 'ajouter', 'retirer' ou 'liste'.\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_FAVORIS_SYMBOL:
        favoris = state.get("favoris", [])
        action = state.get("favoris_action")
        symbol = msg.upper()
        if action == "ajouter":
            if symbol not in favoris:
                favoris.append(symbol)
            set_user_state(user, {"menu": MENU_MAIN, "favoris": favoris})
            return f"{symbol} ajouté aux favoris.\n0. Menu principal"
        elif action == "retirer":
            if symbol in favoris:
                favoris.remove(symbol)
            set_user_state(user, {"menu": MENU_MAIN, "favoris": favoris})
            return f"{symbol} retiré des favoris.\n0. Menu principal"
        else:
            set_user_state(user, {"menu": MENU_MAIN, "favoris": favoris})
            return "Action inconnue.\n0. Menu principal"
    # --- INTERACTION ALERTES (Menu 15) ---
    if menu == "MENU_ALERTES" or menu == AWAIT_ALERT_SYMBOL:
        if menu == "MENU_ALERTES":
            set_user_state(user, {"menu": AWAIT_ALERT_SYMBOL})
            return "Pour créer une alerte, indique le symbole (ex: EURUSD), ou tape 'liste' pour voir les alertes.\nTape 0 pour revenir au menu principal."
        if menu == AWAIT_ALERT_SYMBOL:
            if msg.lower() == "liste":
                alertes = state.get("alertes", [])
                return f"Alertes actuelles : {alertes if alertes else 'Aucune.'}\n0. Menu principal"
            set_user_state(user, {**state, "menu": AWAIT_ALERT_TYPE, "alert_symbol": msg.upper()})
            return "Quel type d'alerte ? (prix, croisement, etc.)\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_ALERT_TYPE:
        set_user_state(user, {**state, "menu": AWAIT_ALERT_VALUE, "alert_type": msg.lower()})
        return "Quelle valeur déclenche l'alerte ? (ex: 1.1200)\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_ALERT_VALUE:
        alertes = state.get("alertes", [])
        symbol = state.get("alert_symbol")
        type_ = state.get("alert_type")
        value = msg
        alertes.append({"symbol": symbol, "type": type_, "value": value})
        set_user_state(user, {"menu": MENU_MAIN, "alertes": alertes})
        return f"Alerte créée sur {symbol} ({type_} {value}).\n0. Menu principal"
    # --- INTERACTION CONFIGURATION (Menu 16) ---
    if menu == "MENU_CONFIG" or menu == AWAIT_CONFIG_TYPE:
        if menu == "MENU_CONFIG":
            set_user_state(user, {"menu": AWAIT_CONFIG_TYPE})
            return "Quel paramètre veux-tu configurer ? (risque, notif, langue, etc.)\nTape 0 pour revenir au menu principal."
        if menu == AWAIT_CONFIG_TYPE:
            set_user_state(user, {**state, "menu": AWAIT_CONFIG_VALUE, "config_type": msg.lower()})
            return "Quelle valeur veux-tu définir ?\nTape 0 pour revenir au menu principal."
    if menu == AWAIT_CONFIG_VALUE:
        config = state.get("config", {})
        config_type = state.get("config_type")
        value = msg
        config[config_type] = value
        set_user_state(user, {"menu": MENU_MAIN, "config": config})
        return f"Configuration '{config_type}' définie à '{value}'.\n0. Menu principal"
    # --- INTERACTION SUPPORT/FAQ (Menu 17) ---
    if menu == "MENU_SUPPORT" or menu == AWAIT_SUPPORT_QUESTION:
        if menu == "MENU_SUPPORT":
            set_user_state(user, {"menu": AWAIT_SUPPORT_QUESTION})
            return "Pose ta question ou tape 'faq' pour la liste des questions fréquentes.\nTape 0 pour revenir au menu principal."
        if menu == AWAIT_SUPPORT_QUESTION:
            if msg.lower() == "faq":
                return "FAQ :\n- Comment passer un ordre ?\n- Comment modifier un SL/TP ?\n- ...\n0. Menu principal"
            else:
                # Ici, on pourrait envoyer la question à un support humain ou IA
                set_user_state(user, {"menu": MENU_MAIN})
                return "Merci pour ta question, le support va te répondre bientôt !\n0. Menu principal"
    # --- INTERACTION AVEC GEMMA3 (Menu 18 ou /ia ou /gemma) ---
    if menu == "MENU_GEMMA3" or menu == AWAIT_GEMMA3:
        if menu == "MENU_GEMMA3":
            set_user_state(user, {"menu": AWAIT_GEMMA3})
            return menu_gemma3()
        if menu == AWAIT_GEMMA3:
            if msg.lower() in ["0", "non", "menu"]:
                set_user_state(user, {"menu": MENU_MAIN})
                return "Retour au menu principal."
            # Réponse différée : on répond tout de suite à Twilio, puis on envoie la vraie réponse IA en tâche de fond
            def send_gemma3_response(user, question, user_state):
                try:
                    from backend.api.whatsapp_webhook import ask_gemma3
                    reponse = ask_gemma3(question, user_state)
                except Exception as e:
                    reponse = "⏳ L'IA a mis trop de temps à répondre ou a rencontré une erreur. Essaie une question plus courte ou réessaie dans quelques instants."
                from frontend.whatsapp_notify import send_whatsapp_message
                send_whatsapp_message(f"🤖 Réponse IA Gemma3 :\n{reponse}", user)
            threading.Thread(target=send_gemma3_response, args=(user, msg, state)).start()
            set_user_state(user, {"menu": AWAIT_GEMMA3})
            return "Je traite ta demande, réponse dans quelques secondes...\nVeux-tu poser une autre question à l'IA ? (oui/non ou 0 pour menu principal)"
    if msg.lower() in ["/ia", "/gemma"]:
        set_user_state(user, {"menu": "MENU_GEMMA3"})
        return menu_gemma3()
    # --- Raccourcis directs ---
    if msg.lower() in ["/modif"]:
        set_user_state(user, {"menu": "MENU_MODIF"})
        return menu_modif()
    if msg.lower() in ["/historique"]:
        set_user_state(user, {"menu": "MENU_HISTORIQUE"})
        return menu_historique()
    if msg.lower() in ["/perf"]:
        set_user_state(user, {"menu": "MENU_PERF"})
        return menu_perf()
    if msg.lower() in ["/favoris"]:
        set_user_state(user, {"menu": "MENU_FAVORIS"})
        return menu_favoris()
    if msg.lower() in ["/alerte"]:
        set_user_state(user, {"menu": "MENU_ALERTES"})
        return menu_alertes()
    if msg.lower() in ["/config"]:
        set_user_state(user, {"menu": "MENU_CONFIG"})
        return menu_config()
    if msg.lower() in ["/faq", "/support"]:
        set_user_state(user, {"menu": "MENU_SUPPORT"})
        return menu_support()
    else:
        reset_user_state(user)
        return menu_main()

def parse_command(body):
    body = body.strip()
    parts = body.split()
    if not parts:
        return None, "Commande vide. Tapez 'aide' pour la liste."
    cmd = parts[0].upper()
    if cmd == "ORDRE" and len(parts) >= 4:
        # ORDRE BUY EURUSD 0.1 1.12345 1.12000 1.13000
        try:
            order_type = parts[1].upper()
            symbol = parts[2].upper()
            lot = float(parts[3])
            price = float(parts[4]) if len(parts) > 4 else None
            sl = float(parts[5]) if len(parts) > 5 else None
            tp = float(parts[6]) if len(parts) > 6 else None
            return ("ORDRE", dict(order_type=order_type, symbol=symbol, lot=lot, price=price, sl=sl, tp=tp)), None
        except Exception as e:
            return None, f"Erreur parsing ORDRE : {e}"
    elif cmd == "CLOSE" and len(parts) >= 2:
        symbol = parts[1].upper()
        return ("CLOSE", dict(symbol=symbol)), None
    elif cmd == "STOP" and len(parts) >= 2 and parts[1].upper() == "ALL":
        return ("STOP_ALL", {}), None
    elif cmd == "MODIF" and len(parts) >= 2:
        symbol = parts[1].upper()
        sl = None
        tp = None
        for p in parts[2:]:
            if p.upper().startswith("SL="):
                try: sl = float(p[3:])
                except: pass
            if p.upper().startswith("TP="):
                try: tp = float(p[3:])
                except: pass
        return ("MODIF", dict(symbol=symbol, sl=sl, tp=tp)), None
    elif cmd == "STATUT":
        return ("STATUT", {}), None
    elif cmd == "AIDE" or cmd == "HELP":
        return ("AIDE", {}), None
    elif cmd in ["TREND", "TENDANCE"]:
        return ("TREND", {}), None
    else:
        return None, "Commande non reconnue. Tapez 'aide' pour la liste."

def help_message():
    return (
        "Commandes WhatsApp disponibles :\n"
        "- ORDRE BUY/SELL SYMBOLE LOT [PRIX SL TP] : Place un ordre. Ex: ORDRE BUY EURUSD 0.1 1.12345 1.12000 1.13000\n"
        "- CLOSE SYMBOLE : Ferme toutes les positions sur le symbole. Ex: CLOSE EURUSD\n"
        "- STOP ALL : Ferme toutes les positions ouvertes.\n"
        "- MODIF SYMBOLE SL=... TP=... : Modifie SL/TP d'un symbole. Ex: MODIF EURUSD SL=1.12100 TP=1.13500\n"
        "- STATUT : Affiche le statut du bot.\n"
        "- AIDE : Affiche cette aide.\n"
    )

def generate_clickable_menu(numero_bot='<NUMERO_BOT>'):
    """
    Génère le menu principal WhatsApp avec des liens cliquables (Click-to-WhatsApp).
    Remplace <NUMERO_BOT> par ton numéro WhatsApp (ex: 33612345678) pour la prod.
    """
    base_url = f"https://wa.me/{numero_bot}?text="
    # Commandes et exemples
    menu = f'''
🤖 TRADBOT - MENU PRINCIPAL

📋 Commandes disponibles:

📊 SYMBOLES
• [Liste des symboles]({base_url}%2Fsymboles)
• [Tendance d'un symbole]({base_url}%2Ftendance%20EURUSD)

🚨 SIGNALS
• [Signal détaillé]({base_url}%2Fsignal%20EURUSD)
• [Signal multi-timeframe]({base_url}%2Fsignal_mtf%20EURUSD)
• [Signal rapide]({base_url}%2Fsignal_rapide%20EURUSD)

📈 ANALYSE
• [Analyse complète]({base_url}%2Fanalyse%20EURUSD)
• [Prix actuel]({base_url}%2Fprix%20EURUSD)

⚙ VALIDATION TENDANCE
• [Activer]({base_url}%2Fvalidation_tendance%20on) | [Désactiver]({base_url}%2Fvalidation_tendance%20off)

❓ AIDE
• [Aide]({base_url}%2Faide)
• [Statut du bot]({base_url}%2Fstatus)

💡 Exemple: [Signal MTF Boom 500 Index]({base_url}%2Fsignal_mtf%20Boom%20500%20Index)

Validation de tendance: ✅ ACTIVÉE
'''
    return menu

# --- Utilisation dans la génération du menu principal ---
def get_main_menu(numero_bot='<NUMERO_BOT>'):
    """
    Retourne le menu principal WhatsApp enrichi (avec liens cliquables).
    """
    return generate_clickable_menu(numero_bot=numero_bot)

# --- Webhook WhatsApp FastAPI ---
# Ce fichier expose POST /whatsapp_webhook (pour Twilio/WhatsApp) et GET /whatsapp_webhook (statut)

def save_whatsapp_message(message):
    import os
    print('Dossier courant (cwd) :', os.getcwd())
    file = Path("messages_whatsapp.json")
    with file.open("a", encoding="utf-8") as f:
        f.write(json.dumps(message, ensure_ascii=False) + "\n")
    print("Message WhatsApp sauvegardé :", message)

@router.post("/whatsapp_webhook")
async def whatsapp_webhook(request: Request, From: str = Form(...), Body: str = Form(...)):
    import os
    print('Dossier courant (cwd) :', os.getcwd())
    print(f"Message WhatsApp reçu de {From}: {Body}")
    message_data = {
        "from": From,
        "body": Body,
        "timestamp": time.time()
    }
    save_whatsapp_message(message_data)
    # --- Gestion des callbacks interactifs (boutons) ---
    try:
        data = await request.json()
    except Exception:
        data = {}
    if 'interactive' in data:
        interactive = data['interactive']
        if 'button_reply' in interactive:
            btn_id = interactive['button_reply'].get('id', '').lower()
            return PlainTextResponse(handle_menu(From, f"payload:{btn_id}"))
    if Body.strip().lower() in ["menu", "0"]:
        reset_user_state(From)
        return PlainTextResponse(menu_main())
    if Body.strip().lower() in MENU_MAP or get_user_state(From).get("menu", MENU_MAIN) != MENU_MAIN:
        return PlainTextResponse(handle_menu(From, Body))
    cmd_tuple, err = parse_command(Body)
    if err:
        return PlainTextResponse(menu_main() + "\n\n" + help_message())
    if not cmd_tuple:
        return PlainTextResponse(menu_main() + "\n\n" + help_message())
    cmd, params = cmd_tuple
    if cmd == "ORDRE":
        ok, msg = place_order_mt5(params['symbol'], params['order_type'], params['lot'], params.get('price'), params.get('sl'), params.get('tp'))
        return PlainTextResponse(msg + "\n\n" + menu_main())
    elif cmd == "CLOSE":
        ok, msg = close_order_mt5(params['symbol'])
        return PlainTextResponse(msg + "\n\n" + menu_main())
    elif cmd == "STOP_ALL":
        ok, msg = close_all_mt5()
        return PlainTextResponse(msg + "\n\n" + menu_main())
    elif cmd == "MODIF":
        ok, msg = modify_order_mt5(params['symbol'], params.get('sl'), params.get('tp'))
        return PlainTextResponse(msg + "\n\n" + menu_main())
    elif cmd == "STATUT":
        return PlainTextResponse(menu_statut() + "\n\n" + menu_main())
    elif cmd == "AIDE":
        return PlainTextResponse(menu_aide() + "\n\n" + menu_main())
    elif cmd == "TREND":
        return PlainTextResponse(menu_trend_consolidated(From) + "\n\n" + menu_main())
    else:
        return PlainTextResponse(menu_main() + "\n\n" + help_message())

@app.get("/whatsapp_webhook")
async def whatsapp_webhook_status():
    return PlainTextResponse("Webhook WhatsApp opérationnel (GET). Utilisez POST pour envoyer un message.")

@app.get("/")
async def root():
    return HTMLResponse("""
        <h2>🚀 TradBOT Webhook API</h2>
        <p>Serveur opérationnel.<br>
        <b>GET /whatsapp_webhook</b> : statut du webhook<br>
        <b>POST /whatsapp_webhook</b> : endpoint WhatsApp/Twilio<br>
        <i>Powered by FastAPI</i>
        </p>
    """)

@app.get("/whatsapp_symbols_menu")
def send_whatsapp_symbols_menu():
    """Envoie une liste déroulante WhatsApp (list message) avec tous les symboles disponibles."""
    ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "YOUR_AUTH_TOKEN")
    FROM = os.getenv("TWILIO_WHATSAPP_FROM", "whatsapp:+14155238886")
    TO = os.getenv("TWILIO_WHATSAPP_TO", "whatsapp:+1234567890")
    url = f"https://api.twilio.com/v1/Accounts/{ACCOUNT_SID}/Messages"
    # Récupère dynamiquement les symboles (ici exemple statique, à remplacer par une vraie extraction)
    symbols = [
        {"id": "eurusd", "title": "EURUSD"},
        {"id": "usdjpy", "title": "USDJPY"},
        {"id": "btcusd", "title": "BTCUSD"},
        {"id": "xauusd", "title": "XAUUSD"},
        {"id": "nas100", "title": "NAS100"},
        {"id": "spx500", "title": "SPX500"},
        # ... ajoute dynamiquement tous les symboles de ton backend
    ]
    payload = {
        "to": TO,
        "from": FROM,
        "interactive": {
            "type": "list",
            "body": {"text": "Choisissez un ou plusieurs symboles à scanner"},
            "action": {
                "button": "Voir les symboles",
                "sections": [
                    {"title": "Symboles disponibles", "rows": symbols}
                ]
            }
        }
    }
    resp = requests.post(url, auth=(ACCOUNT_SID, AUTH_TOKEN), json=payload)
    try:
        resp_json = resp.json()
    except Exception:
        resp_json = {"raw": resp.text}
    return {"status": "menu symboles envoyé", "twilio_response": resp_json}

# Modifie le menu principal pour ajouter le bouton "Activer Auto-Monitor"
@app.get("/whatsapp_menu")
def send_whatsapp_menu():
    """Envoie un menu interactif WhatsApp (boutons) via Twilio API (REST direct car le SDK ne supporte pas encore 'interactive')."""
    ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "YOUR_AUTH_TOKEN")
    FROM = os.getenv("TWILIO_WHATSAPP_FROM", "whatsapp:+14155238886")
    TO = os.getenv("TWILIO_WHATSAPP_TO", "whatsapp:+1234567890")
    url = f"https://api.twilio.com/v1/Accounts/{ACCOUNT_SID}/Messages"
    payload = {
        "to": TO,
        "from": FROM,
        "interactive": {
            "type": "button",
            "body": {"text": "Que souhaitez-vous faire?"},
            "action": {
                "buttons": [
                    {"type": "reply", "reply": {"id": "order", "title": "Placer un ordre"}},
                    {"type": "reply", "reply": {"id": "close", "title": "Fermer une position"}},
                    {"type": "reply", "reply": {"id": "status", "title": "Statut du bot"}},
                    {"type": "reply", "reply": {"id": "help", "title": "Aide"}},
                    {"type": "reply", "reply": {"id": "auto_monitor", "title": "Activer Auto-Monitor"}},
                    {"type": "reply", "reply": {"id": "symbols_menu", "title": "Choisir symboles à scanner"}}
                ]
            }
        }
    }
    resp = requests.post(url, auth=(ACCOUNT_SID, AUTH_TOKEN), json=payload)
    try:
        resp_json = resp.json()
    except Exception:
        resp_json = {"raw": resp.text}
    return {"status": "menu envoyé", "twilio_response": resp_json}

# Dans le webhook principal, il faudra gérer les callbacks des boutons :
# - Si id == 'auto_monitor' : activer le moniteur automatique (POST backend)
# - Si id == 'symbols_menu' : appeler send_whatsapp_symbols_menu()
# - Si id == 'order', 'close', etc. : logique existante
# - Pour la sélection de symboles, stocker le choix utilisateur (par numéro WhatsApp) et appliquer la config de scan
# (À compléter dans la gestion POST /whatsapp_webhook selon le champ 'interactive' du payload Twilio) 