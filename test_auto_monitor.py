#!/usr/bin/env python3
"""
Test simple de l'automatisation des signaux
"""
import sys
import os
sys.path.insert(0, os.path.abspath('.'))

from backend.auto_signal_monitor import AutoSignalMonitor
import time

def test_auto_monitor():
    """Test simple du moniteur automatique"""
    print("🧪 TEST AUTO-MONITOR")
    print("=" * 30)
    
    # Créer le moniteur
    monitor = AutoSignalMonitor()
    
    # Test de récupération des symboles
    print("📡 Test récupération symboles...")
    try:
        symbols = monitor.get_symbols_to_monitor()
        print(f"✅ {len(symbols)} symboles récupérés")
        print(f"📋 Symboles: {symbols[:5]}...")
    except Exception as e:
        print(f"❌ Erreur récupération symboles: {e}")
        return False
    
    # Test de scan d'un symbole
    print("\n🔍 Test scan d'un symbole...")
    try:
        test_symbol = symbols[0] if symbols else "EURUSD"
        print(f"Test avec {test_symbol}")
        
        signal = monitor.scan_symbol(test_symbol)
        if signal:
            print(f"✅ Signal généré: {signal['recommendation']} (confiance: {signal['confidence']:.1%})")
        else:
            print("ℹ️ Aucun signal généré (normal si conditions non remplies)")
            
    except Exception as e:
        print(f"❌ Erreur scan: {e}")
        return False
    
    print("\n✅ Test terminé avec succès")
    return True

if __name__ == "__main__":
    success = test_auto_monitor()
    if success:
        print("\n🎉 L'automatisation est prête à être utilisée !")
    else:
        print("\n❌ Des problèmes ont été détectés") 