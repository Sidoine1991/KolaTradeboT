#!/usr/bin/env python3
"""
Test du service de notification unifié TradBOT
Support SMS et WhatsApp via Vonage + Firebase
"""

import sys
from pathlib import Path

# Ajouter le répertoire src au path
sys.path.append(str(Path(__file__).parent / 'src'))

def test_unified_notifications():
    """Test complet du service de notification unifié"""
    print("📱 Test du Service de Notification Unifié TradBOT")
    print("=" * 60)
    
    try:
        from unified_notification_service import get_unified_service, send_trading_signal, send_confirmed_signal, send_spike_alert
        
        # Obtenir le service unifié
        service = get_unified_service()
        
        # Afficher le statut des services
        status = service.get_status()
        print("\n📊 Statut des services:")
        print(f"   SMS: {'✅' if status['sms_enabled'] else '❌'} ({status['phone_number']})")
        print(f"   WhatsApp: {'✅' if status['whatsapp_enabled'] else '❌'} ({status['whatsapp_number']})")
        print(f"   Firebase: {'✅' if status['firebase_enabled'] else '❌'}")
        print(f"   Vonage configuré: {'✅' if status['vonage_configured'] else '❌'}")
        
        # Test 1: Test de tous les services
        print("\n1. Test de tous les services...")
        test_results = service.test_all_services()
        
        for service_name, result in test_results.items():
            status_icon = "✅" if result else "❌"
            print(f"   {status_icon} {service_name.upper()}")
        
        # Test 2: Signal de trading standard
        print("\n2. Test de signal de trading standard...")
        signal_results = send_trading_signal(
            symbol="Boom 1000 Index",
            action="BUY",
            price=17952.469,
            confidence=0.85,
            timeframe="M5"
        )
        
        print("   Résultats du signal de trading:")
        for service_name, result in signal_results.items():
            status_icon = "✅" if result else "❌"
            print(f"   {status_icon} {service_name.upper()}")
        
        # Test 3: Signal confirmé de l'API
        print("\n3. Test de signal confirmé de l'API...")
        confirmed_results = send_confirmed_signal(
            symbol="EURUSD",
            action="BUY",
            price=1.0850,
            confidence=0.92,
            source="API Alpha Vantage"
        )
        
        print("   Résultats du signal confirmé:")
        for service_name, result in confirmed_results.items():
            status_icon = "✅" if result else "❌"
            print(f"   {status_icon} {service_name.upper()}")
        
        # Test 4: Alerte de spike
        print("\n4. Test d'alerte de spike...")
        spike_results = send_spike_alert(
            symbol="Crash 500 Index",
            price=3298.225,
            spike_percentage=2.5
        )
        
        print("   Résultats de l'alerte de spike:")
        for service_name, result in spike_results.items():
            status_icon = "✅" if result else "❌"
            print(f"   {status_icon} {service_name.upper()}")
        
        # Test 5: Différents types de signaux
        print("\n5. Test de différents types de signaux...")
        
        test_signals = [
            {
                "symbol": "Boom 1000 Index",
                "action": "BUY",
                "price": 17952.469,
                "confidence": 0.88
            },
            {
                "symbol": "Crash 500 Index",
                "action": "SELL",
                "price": 3298.225,
                "confidence": 0.82
            },
            {
                "symbol": "EURUSD",
                "action": "BUY",
                "price": 1.0850,
                "confidence": 0.75
            }
        ]
        
        for i, signal in enumerate(test_signals, 1):
            print(f"\n   Test {i}: {signal['symbol']} {signal['action']}")
            results = send_trading_signal(
                symbol=signal['symbol'],
                action=signal['action'],
                price=signal['price'],
                confidence=signal['confidence']
            )
            
            for service_name, result in results.items():
                status_icon = "✅" if result else "❌"
                print(f"     {status_icon} {service_name.upper()}")
        
        # Résumé final
        print("\n" + "=" * 60)
        print("📋 RÉSUMÉ DES TESTS")
        print("=" * 60)
        
        all_tests = [
            ("Test des services", any(test_results.values())),
            ("Signal de trading", any(signal_results.values())),
            ("Signal confirmé", any(confirmed_results.values())),
            ("Alerte de spike", any(spike_results.values()))
        ]
        
        for test_name, test_result in all_tests:
            status_icon = "✅" if test_result else "❌"
            print(f"{status_icon} {test_name}")
        
        # Recommandations
        print("\n💡 Recommandations:")
        if not status['vonage_configured']:
            print("   • Configurez les clés Vonage pour SMS et WhatsApp")
            print("   • Ajoutez VONAGE_API_KEY et VONAGE_API_SECRET dans .env")
        
        if not status['sms_enabled']:
            print("   • Configurez VONAGE_SMS_TO dans .env")
        
        if not status['whatsapp_enabled']:
            print("   • Configurez VONAGE_WHATSAPP_TO_SANDBOX dans .env")
        
        print("\n🎯 Utilisation dans votre code:")
        print("   from src.unified_notification_service import send_trading_signal")
        print("   send_trading_signal('EURUSD', 'BUY', 1.0850, 0.85)")
        
        return all(test_result for _, test_result in all_tests)
        
    except ImportError as e:
        print(f"❌ Erreur d'importation: {e}")
        return False
    except Exception as e:
        print(f"❌ Erreur lors du test: {e}")
        return False

if __name__ == "__main__":
    success = test_unified_notifications()
    sys.exit(0 if success else 1)
