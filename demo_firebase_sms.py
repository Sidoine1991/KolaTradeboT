#!/usr/bin/env python3
"""
Démonstration de l'utilisation du service Firebase pour les notifications SMS
"""

import os
import sys
import time
from pathlib import Path

# Ajouter le répertoire src au path
sys.path.append(str(Path(__file__).parent / 'src'))

def demo_firebase_sms():
    """Démonstration des fonctionnalités Firebase SMS"""
    print("🔥 Démonstration Firebase SMS pour TradBOT")
    print("=" * 50)
    
    try:
        from firebase_service import get_firebase_service
        
        # Obtenir le service Firebase
        service = get_firebase_service()
        
        if not service.initialized:
            print("❌ Service Firebase non initialisé")
            print("💡 Installez les dépendances: pip install firebase-admin")
            return
        
        print("✅ Service Firebase initialisé")
        
        # Demander le numéro de téléphone
        phone_number = input("\n📱 Entrez votre numéro de téléphone (format: +1234567890): ").strip()
        
        if not phone_number:
            phone_number = "+1234567890"  # Numéro par défaut
            print(f"⚠️  Utilisation du numéro par défaut: {phone_number}")
        
        # Test 1: Envoi d'une notification SMS de test
        print(f"\n1. Envoi d'une notification SMS de test...")
        
        test_message = "🔥 Test TradBOT - Configuration Firebase réussie!"
        success = service.send_sms_notification(
            phone_number=phone_number,
            message=test_message,
            title="TradBOT Test"
        )
        
        if success:
            print("✅ Notification SMS envoyée avec succès!")
        else:
            print("❌ Échec de l'envoi de la notification SMS")
        
        # Test 2: Sauvegarde d'un signal de trading
        print(f"\n2. Sauvegarde d'un signal de trading...")
        
        signal_data = {
            'symbol': 'EURUSD',
            'action': 'BUY',
            'price': 1.0850,
            'confidence': 0.85,
            'indicators': {
                'rsi': 35.2,
                'macd': 'bullish',
                'sma_20': 1.0840
            },
            'message': 'Signal d\'achat EURUSD - RSI survente + MACD haussier'
        }
        
        signal_id = service.save_trading_signal(signal_data)
        
        if signal_id:
            print(f"✅ Signal de trading sauvegardé: {signal_id}")
        else:
            print("❌ Échec de la sauvegarde du signal")
        
        # Test 3: Récupération des signaux
        print(f"\n3. Récupération des signaux de trading...")
        
        signals = service.get_trading_signals(limit=5)
        print(f"📊 {len(signals)} signaux récupérés")
        
        for i, signal in enumerate(signals[:3], 1):
            print(f"   {i}. {signal.get('symbol', 'N/A')} - {signal.get('action', 'N/A')} - {signal.get('confidence', 0):.2f}")
        
        # Test 4: Sauvegarde de données de marché
        print(f"\n4. Sauvegarde de données de marché...")
        
        market_data = {
            'open': 1.0845,
            'high': 1.0860,
            'low': 1.0840,
            'close': 1.0855,
            'volume': 1000000,
            'timeframe': 'M5'
        }
        
        success = service.save_market_data('EURUSD', market_data)
        
        if success:
            print("✅ Données de marché sauvegardées")
        else:
            print("❌ Échec de la sauvegarde des données de marché")
        
        # Test 5: Récupération des données de marché
        print(f"\n5. Récupération des données de marché...")
        
        market_data_list = service.get_market_data('EURUSD', limit=3)
        print(f"📈 {len(market_data_list)} points de données récupérés")
        
        for i, data in enumerate(market_data_list[:2], 1):
            print(f"   {i}. EURUSD - Close: {data.get('close', 'N/A')} - Volume: {data.get('volume', 'N/A')}")
        
        # Résumé
        print(f"\n" + "=" * 50)
        print("📋 RÉSUMÉ DE LA DÉMONSTRATION")
        print("=" * 50)
        
        print("✅ Toutes les fonctionnalités Firebase testées!")
        print("\n🔧 Fonctionnalités disponibles:")
        print("   • Envoi de notifications SMS")
        print("   • Sauvegarde des signaux de trading")
        print("   • Récupération des signaux")
        print("   • Sauvegarde des données de marché")
        print("   • Récupération des données de marché")
        print("   • Mise à jour du statut des signaux")
        print("   • Nettoyage des anciennes données")
        
        print(f"\n💡 Intégration dans vos scripts:")
        print("   from src.firebase_service import get_firebase_service")
        print("   service = get_firebase_service()")
        print("   # Utilisez service.send_sms_notification() dans vos signaux")
        
    except ImportError as e:
        print(f"❌ Erreur d'importation: {e}")
        print("💡 Installez les dépendances: pip install firebase-admin")
    except Exception as e:
        print(f"❌ Erreur lors de la démonstration: {e}")

if __name__ == "__main__":
    demo_firebase_sms()
