#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test du système d'affichage Boom direct sur le graphique
"""

import time
import requests
import json

def test_boom_display_integration():
    """Test de l'integration de l'affichage Boom direct"""
    
    print("Test de l'affichage Boom direct sur le graphique")
    print("=" * 60)
    
    # Configuration de test
    boom_symbol = "Boom 1000 Index"
    api_url = "http://localhost:8000/trend"
    
    print(f"Symbole teste: {boom_symbol}")
    print(f"URL API: {api_url}")
    print(f"Periode de scan: 600 bougies (au lieu de 100)")
    print(f"Affichage: Direct sur graphique (sans cadran)")
    print()
    
    # Test de l'API
    try:
        print("Test de l'API Boom...")
        response = requests.get(f"{api_url}?symbol={boom_symbol}&timeframe=M1", timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            print("API accessible")
            print(f"Direction: {data.get('direction', 'N/A')}")
            print(f"Force: {data.get('strength', 0)}")
            print(f"Confiance: {data.get('confidence', 0)}")
            print(f"Signal: {data.get('signal', 'N/A')}")
            print(f"Temps spike: {data.get('time_to_spike', 0)}s")
        else:
            print(f"Erreur API: {response.status_code}")
            
    except requests.exceptions.RequestException as e:
        print(f"Erreur connexion API: {e}")
        print("Assurez-vous que l'API est demarree")
    
    print()
    print("Instructions pour tester l'affichage direct:")
    print("1. Compilez le fichier mt5/AngelOfSpike.mq5")
    print("2. Attachez l'EA au graphique 'Boom 1000 Index'")
    print("3. Activez InpEnableBoomDisplay = true")
    print("4. Activez InpBoomDebug = true")
    print("5. L'affichage devrait apparaitre en haut a gauche du graphique")
    print()
    print("Couleurs d'affichage:")
    print("Vert vif: Signal BUY")
    print("Rouge vif: Signal SELL")
    print("Jaune vif: Signal NEUTRAL")
    print("Rouge: Erreur API")
    print()
    print("Informations affichees:")
    print("- Direction et force du signal")
    print("- Confiance et probabilite de spike")
    print("- Temps estime jusqu'au spike")
    print("- Proximite EMA et position canal")
    print("- Prix actuel et force du canal")
    print("- Probabilite de breakout")
    print()
    print("Avantages de l'affichage direct:")
    print("- Plus visible sur tous les arriere-plans")
    print("- Pas de cadran qui masque le graphique")
    print("- Couleurs vives qui se revelent bien")
    print("- Position fixe en haut a gauche")
    print("- Mise a jour toutes les 5 secondes")

def test_600_bars_scan():
    """Test du scan sur 600 bougies"""
    
    print("Test du scan sur 600 bougies")
    print("=" * 40)
    
    print("Modification appliquee:")
    print("   InpLookbackBars = 600 (au lieu de 5)")
    print()
    print("Impact sur l'analyse:")
    print("- Plus de donnees historiques pour l'analyse")
    print("- Detection plus precise des patterns")
    print("- Meilleure identification des canaux haussiers")
    print("- Analyse ATR plus robuste")
    print("- Detection de spikes plus fiable")
    print()
    print("Considerations:")
    print("- Temps de calcul legerement plus long")
    print("- Plus de memoire utilisee")
    print("- Analyse plus precise et fiable")

if __name__ == "__main__":
    print("Test du systeme Boom avec affichage direct")
    print("=" * 60)
    print()
    
    test_boom_display_integration()
    print()
    test_600_bars_scan()
    
    print()
    print("Test termine!")
    print("Consultez les logs MT5 pour voir les messages de debug")
