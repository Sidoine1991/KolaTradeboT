#!/usr/bin/env python3
"""
Test du cooldown de 3 minutes pour les alertes spike
"""
import os
import requests
from dotenv import load_dotenv
from datetime import datetime, timedelta

load_dotenv()

def test_cooldown_3min():
    """Test du cooldown de 3 minutes"""
    print("🧪 TEST COOLDOWN 3 MINUTES")
    print("=" * 40)
    
    # Configuration
    api_key = os.getenv("VONAGE_API_KEY")
    api_secret = os.getenv("VONAGE_API_SECRET")
    from_name = os.getenv("VONAGE_SMS_FROM", "TradBOT")
    to_num = os.getenv("VONAGE_SMS_TO", "22996911346")
    
    # Simulation de notifications avec cooldown
    notifications = {}
    cooldown_seconds = 180  # 3 minutes
    
    test_cases = [
        {"time": "18:00:00", "symbol": "Boom 1000 Index", "probability": 0.85},
        {"time": "18:01:00", "symbol": "Boom 1000 Index", "probability": 0.82},  # Trop tôt (1 min)
        {"time": "18:02:00", "symbol": "Boom 1000 Index", "probability": 0.88},  # Trop tôt (2 min)
        {"time": "18:03:30", "symbol": "Boom 1000 Index", "probability": 0.90},  # OK (3.5 min)
        {"time": "18:04:00", "symbol": "Crash 500 Index", "probability": 0.75},  # OK (différent symbole)
        {"time": "18:05:00", "symbol": "Boom 1000 Index", "probability": 0.87},  # Trop tôt (1.5 min)
        {"time": "18:07:00", "symbol": "Boom 1000 Index", "probability": 0.91},  # OK (3.5 min)
    ]
    
    for i, case in enumerate(test_cases, 1):
        print(f"\n🔄 Test {i}: {case['time']} - {case['symbol']}")
        
        # Simuler le timestamp
        test_time = datetime.strptime(f"2024-01-01 {case['time']}", "%Y-%m-%d %H:%M:%S")
        now_ts = test_time.timestamp()
        
        # Vérifier le cooldown (utiliser le symbole comme clé, pas l'heure)
        spike_key = f"spike:{case['symbol']}"
        last_spike_ts = notifications.get(spike_key, 0)
        
        time_diff = now_ts - last_spike_ts
        print(f"   Dernière alerte: {datetime.fromtimestamp(last_spike_ts).strftime('%H:%M:%S') if last_spike_ts > 0 else 'Jamais'}")
        print(f"   Temps écoulé: {time_diff:.0f} secondes")
        print(f"   Cooldown requis: {cooldown_seconds} secondes")
        
        if time_diff >= cooldown_seconds or last_spike_ts == 0:
            print(f"   ✅ COOLDOWN OK - Envoi de l'alerte")
            
            # Simuler l'envoi
            if case['probability'] > 0.70:
                print(f"   📱 SMS envoyé: {case['symbol']} ({case['probability']:.0%})")
                print(f"   💬 WhatsApp envoyé: {case['symbol']} ({case['probability']:.0%})")
                notifications[spike_key] = now_ts
            else:
                print(f"   ❌ Probabilité trop faible: {case['probability']:.0%}")
        else:
            remaining = cooldown_seconds - time_diff
            print(f"   ⏳ COOLDOWN ACTIF - Attendre {remaining:.0f} secondes de plus")
    
    print(f"\n📊 RÉSUMÉ:")
    print(f"   Total d'alertes envoyées: {len(notifications)}")
    print(f"   Cooldown configuré: {cooldown_seconds} secondes (3 minutes)")

if __name__ == "__main__":
    test_cooldown_3min()
