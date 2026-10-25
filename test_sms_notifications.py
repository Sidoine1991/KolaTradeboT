#!/usr/bin/env python3
"""
Test des notifications SMS pour TradBOT
"""

import sys
from pathlib import Path

# Ajouter le répertoire src au path
sys.path.append(str(Path(__file__).parent / 'src'))

def test_sms_notifications():
    """Test complet des notifications SMS"""
    print("📱 Test des notifications SMS TradBOT")
    print("=" * 50)
    print(f"📞 Numéro configuré: +22996911346")
    print()
    
    try:
        from sms_notification_service import get_sms_service, send_trading_signal, send_spike_alert
        
        # Obtenir le service SMS
        sms_service = get_sms_service()
        
        if not sms_service.firebase_service or not sms_service.firebase_service.initialized:
            print("❌ Service Firebase non initialisé")
            print("💡 Installez les dépendances: pip install firebase-admin")
            return False
        
        print("✅ Service SMS initialisé")
        
        # Test 1: Notification de test
        print("\n1. Test de notification de base...")
        success = sms_service.test_sms_notification()
        if success:
            print("✅ Notification de test envoyée!")
        else:
            print("❌ Échec de l'envoi de la notification de test")
        
        # Test 2: Signal de trading
        print("\n2. Test de signal de trading...")
        signal_success = send_trading_signal(
            symbol="EURUSD",
            action="BUY",
            price=1.0850,
            confidence=0.85,
            timeframe="M5",
            indicators={
                'rsi': 35.2,
                'macd': 'bullish',
                'sma_20': 1.0840
            }
        )
        
        if signal_success:
            print("✅ Signal de trading envoyé!")
        else:
            print("❌ Échec de l'envoi du signal de trading")
        
        # Test 3: Alerte de spike
        print("\n3. Test d'alerte de spike...")
        spike_success = send_spike_alert(
            symbol="Boom 1000 Index",
            price=17965.28,
            spike_percentage=2.5
        )
        
        if spike_success:
            print("✅ Alerte de spike envoyée!")
        else:
            print("❌ Échec de l'envoi de l'alerte de spike")
        
        # Test 4: Résumé quotidien
        print("\n4. Test de résumé quotidien...")
        summary_data = {
            'total_signals': 15,
            'successful_signals': 12,
            'total_pnl': 1250.50,
            'win_rate': 0.80
        }
        
        summary_success = sms_service.send_daily_summary_sms(summary_data)
        
        if summary_success:
            print("✅ Résumé quotidien envoyé!")
        else:
            print("❌ Échec de l'envoi du résumé quotidien")
        
        # Résumé des tests
        print("\n" + "=" * 50)
        print("📋 RÉSUMÉ DES TESTS")
        print("=" * 50)
        
        tests = [
            ("Notification de test", success),
            ("Signal de trading", signal_success),
            ("Alerte de spike", spike_success),
            ("Résumé quotidien", summary_success)
        ]
        
        for test_name, test_result in tests:
            status = "✅" if test_result else "❌"
            print(f"{status} {test_name}")
        
        all_success = all(result for _, result in tests)
        
        if all_success:
            print("\n🎉 Tous les tests SMS ont réussi!")
            print("📱 Vous devriez recevoir les notifications sur +22996911346")
        else:
            print("\n⚠️  Certains tests ont échoué")
            print("💡 Vérifiez la configuration Firebase")
        
        return all_success
        
    except ImportError as e:
        print(f"❌ Erreur d'importation: {e}")
        print("💡 Installez les dépendances: pip install firebase-admin")
        return False
    except Exception as e:
        print(f"❌ Erreur lors du test: {e}")
        return False

if __name__ == "__main__":
    success = test_sms_notifications()
    sys.exit(0 if success else 1)
