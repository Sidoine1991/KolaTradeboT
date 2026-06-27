#!/usr/bin/env python3
"""
XAUUSD Scalping Trade Monitor
Suivi temps réel des 9 niveaux de TP avec alertes WhatsApp
Trade: XAUUSD BUY @ 4266/4260 avec 9 TP progressifs
"""

import json
import time
from datetime import datetime
from pathlib import Path
import requests
import sys

# Configuration
TRADE_CONFIG = {
    "symbol": "XAUUSD",
    "direction": "BUY",
    "entry_low": 4260,
    "entry_high": 4266,
    "tp_levels": [4270, 4274, 4280, 4284, 4290, 4294, 4299, 4304, 4310],
    "sl": 4255,  # Inferred
}

# Mondes
CLOSED_TP_FILE = Path("D:/Dev/TradBOT/data/xauusd_scalp_tp_closed.json")
PSYCHOBOT_WEBHOOK = "https://psychobot-1si7.onrender.com/send-message"
PHONE = "+2290196911346"

# État des TP fermés
closed_tps = {}

def load_closed_tps():
    """Charge les TP déjà fermés"""
    global closed_tps
    if CLOSED_TP_FILE.exists():
        try:
            with open(CLOSED_TP_FILE, 'r') as f:
                closed_tps = json.load(f)
            print(f"✅ État chargé: {len(closed_tps)} TP fermés")
        except:
            closed_tps = {}
    else:
        closed_tps = {str(tp): False for tp in TRADE_CONFIG["tp_levels"]}
        save_closed_tps()

def save_closed_tps():
    """Sauvegarde l'état des TP fermés"""
    CLOSED_TP_FILE.write_text(json.dumps(closed_tps, indent=2))

def send_whatsapp_alert(tp_level, message):
    """Envoie une alerte WhatsApp via PsychoBot"""
    try:
        payload = {
            "phone": PHONE,
            "message": message,
            "source": "xauusd-scalp-monitor"
        }
        response = requests.post(
            PSYCHOBOT_WEBHOOK,
            json=payload,
            timeout=5
        )
        if response.status_code in [200, 201]:
            print(f"✅ WhatsApp envoyé: TP {tp_level}")
            return True
        else:
            print(f"❌ WhatsApp FAILED (HTTP {response.status_code})")
            return False
    except Exception as e:
        print(f"❌ WhatsApp ERROR: {e}")
        return False

def check_tp_reached(current_price):
    """
    Vérifie si un TP est atteint
    Pour un BUY: price >= TP
    """
    for tp_level in TRADE_CONFIG["tp_levels"]:
        tp_str = str(tp_level)

        # TP atteint ET pas encore fermé
        if current_price >= tp_level and not closed_tps.get(tp_str, False):
            profit = current_price - TRADE_CONFIG["entry_low"]
            pips = (profit * 10000) / 100  # Approximation

            msg = (
                f"🟢 XAUUSD TP ATTEINT!\n"
                f"📊 Niveau: TP {tp_level}\n"
                f"💰 Prix actuel: {current_price:.2f}\n"
                f"📈 Profit: {profit:.2f} points\n"
                f"⏰ {datetime.now().strftime('%H:%M:%S')}"
            )

            print(f"\n{'='*50}")
            print(f"🎯 TP {tp_level} ATTEINT @ {current_price:.2f}")
            print(f"{'='*50}\n")

            # Envoyer alerte WhatsApp
            send_whatsapp_alert(tp_level, msg)

            # Marquer comme fermé
            closed_tps[tp_str] = True
            save_closed_tps()

            return True

    return False

def monitor_trade():
    """Boucle de suivi du trade"""
    print("\n" + "="*60)
    print("🚀 XAUUSD SCALPING TRADE MONITOR")
    print("="*60)
    print(f"Entry: {TRADE_CONFIG['entry_low']} - {TRADE_CONFIG['entry_high']} BUY")
    print(f"SL: {TRADE_CONFIG['sl']}")
    print(f"TPs: {TRADE_CONFIG['tp_levels']}")
    print("="*60 + "\n")

    load_closed_tps()

    # Affiche l'état initial
    print("État des TP:")
    for tp in TRADE_CONFIG["tp_levels"]:
        status = "✅ FERMÉ" if closed_tps.get(str(tp), False) else "⏳ OUVERT"
        print(f"  TP {tp}: {status}")
    print()

    # Boucle de suivi (pour tests manuels, on peut entrer les prix)
    while True:
        try:
            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Entrez le prix actuel (ou 'q' pour quitter):")
            user_input = input(">>> ").strip()

            if user_input.lower() == 'q':
                print("❌ Suivi arrêté.")
                break

            try:
                current_price = float(user_input)
                print(f"\n📍 Prix actuel: {current_price:.2f}")

                # Vérifier SL
                if current_price <= TRADE_CONFIG["sl"]:
                    msg = (
                        f"🔴 XAUUSD STOP LOSS ATTEINT!\n"
                        f"📊 SL: {TRADE_CONFIG['sl']}\n"
                        f"💰 Prix: {current_price:.2f}\n"
                        f"⏰ {datetime.now().strftime('%H:%M:%S')}"
                    )
                    print(f"\n{'='*50}")
                    print("🛑 STOP LOSS DÉCLENCHÉ!")
                    print(f"{'='*50}\n")
                    send_whatsapp_alert("SL", msg)
                    break

                # Vérifier TP
                check_tp_reached(current_price)

                # Afficher progression
                profit = current_price - TRADE_CONFIG["entry_low"]
                remaining_tps = sum(1 for tp in TRADE_CONFIG["tp_levels"]
                                   if not closed_tps.get(str(tp), False))

                print(f"💹 Profit actuel: {profit:+.2f}")
                print(f"📊 TPs restants: {remaining_tps}/9")

                if remaining_tps == 0:
                    print("\n🎉 TOUS LES TP FERMÉS! 🎉")
                    break

            except ValueError:
                print(f"❌ Prix invalide: {user_input}")
                continue

        except KeyboardInterrupt:
            print("\n❌ Suivi arrêté par l'utilisateur.")
            break
        except Exception as e:
            print(f"❌ Erreur: {e}")
            continue

if __name__ == "__main__":
    monitor_trade()
