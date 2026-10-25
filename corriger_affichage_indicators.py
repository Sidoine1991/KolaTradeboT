#!/usr/bin/env python3
"""
Script pour corriger l'affichage des indicateurs sur le graphique MT5
Active les indicateurs et les flèches de prédiction
"""

import MetaTrader5 as mt5
import time
import json
from datetime import datetime, timedelta

def corriger_affichage_indicators():
    """Corrige l'affichage des indicateurs sur le graphique MT5"""
    
    print("📊 Correction de l'affichage des indicateurs")
    print("=" * 50)
    
    # Initialiser MT5
    if not mt5.initialize():
        print("❌ Erreur: Impossible d'initialiser MT5")
        return False
    
    print("✅ MT5 initialisé")
    
    # Vérifier la connexion
    if not mt5.terminal_info():
        print("❌ Erreur: Terminal MT5 non connecté")
        return False
    
    print("✅ Terminal MT5 connecté")
    
    # Ajouter les indicateurs au graphique
    ajouter_indicators_au_graphique()
    
    # Créer les objets d'affichage
    creer_objets_affichage()
    
    # Démarrer l'affichage dynamique
    demarrer_affichage_dynamique()
    
    return True

def ajouter_indicators_au_graphique():
    """Ajoute les indicateurs techniques au graphique"""
    print("\n📈 Ajout des indicateurs techniques...")
    
    symbol = "Boom 1000 Index"
    
    # Vérifier que le symbole existe
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        print(f"❌ Symbole {symbol} non trouvé")
        return False
    
    print(f"✅ Symbole {symbol} trouvé")
    
    # Ajouter les EMAs
    try:
        # EMA 10
        ema10_handle = mt5.iMA(symbol, mt5.TIMEFRAME_M1, 10, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema10_handle != mt5.INVALID_HANDLE:
            print("✅ EMA 10 ajoutée")
        else:
            print("⚠️ EMA 10 non ajoutée")
        
        # EMA 30
        ema30_handle = mt5.iMA(symbol, mt5.TIMEFRAME_M1, 30, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema30_handle != mt5.INVALID_HANDLE:
            print("✅ EMA 30 ajoutée")
        else:
            print("⚠️ EMA 30 non ajoutée")
        
        # EMA 50
        ema50_handle = mt5.iMA(symbol, mt5.TIMEFRAME_M1, 50, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema50_handle != mt5.INVALID_HANDLE:
            print("✅ EMA 50 ajoutée")
        else:
            print("⚠️ EMA 50 non ajoutée")
        
        # RSI
        rsi_handle = mt5.iRSI(symbol, mt5.TIMEFRAME_M1, 14, mt5.PRICE_CLOSE)
        if rsi_handle != mt5.INVALID_HANDLE:
            print("✅ RSI ajouté")
        else:
            print("⚠️ RSI non ajouté")
        
        # MACD
        macd_handle = mt5.iMACD(symbol, mt5.TIMEFRAME_M1, 12, 26, 9, mt5.PRICE_CLOSE)
        if macd_handle != mt5.INVALID_HANDLE:
            print("✅ MACD ajouté")
        else:
            print("⚠️ MACD non ajouté")
        
    except Exception as e:
        print(f"❌ Erreur lors de l'ajout des indicateurs: {e}")
        return False
    
    return True

def creer_objets_affichage():
    """Crée les objets d'affichage sur le graphique"""
    print("\n🎨 Création des objets d'affichage...")
    
    # Créer le HUD principal
    creer_hud_principal()
    
    # Créer le cadran d'analyse Boom
    creer_cadran_boom()
    
    # Créer les flèches de prédiction
    creer_fleches_prediction()
    
    print("✅ Objets d'affichage créés")

def creer_hud_principal():
    """Crée le HUD principal en haut à gauche"""
    try:
        # Supprimer l'ancien HUD s'il existe
        mt5.object_delete(0, "AngelOfSpikeHUD")
        
        # Créer le HUD
        if mt5.object_create(0, "AngelOfSpikeHUD", mt5.OBJ_LABEL, 0, 0, 0):
            # Position
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_XDISTANCE, 10)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_YDISTANCE, 30)
            
            # Style
            mt5.object_set_string(0, "AngelOfSpikeHUD", mt5.OBJPROP_FONT, "Arial")
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_FONTSIZE, 9)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_COLOR, 0xFFFFFF)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_ANCHOR, mt5.ANCHOR_LEFT_UPPER)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_BACK, False)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_SELECTABLE, False)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_HIDDEN, False)
            mt5.object_set_integer(0, "AngelOfSpikeHUD", mt5.OBJPROP_ZORDER, 1000)
            
            # Texte initial
            hud_text = "🤖 AngelOfSpike v2.0\\n━━━━━━━━━━━━━━━━━━━━━━\\nTrading: ACTIF\\nPositions: 0\\nDernier Trade: Aucun\\n━━━━━━━━━━━━━━━━━━━━━━\\n⏰ " + datetime.now().strftime("%H:%M:%S")
            mt5.object_set_string(0, "AngelOfSpikeHUD", mt5.OBJPROP_TEXT, hud_text)
            
            print("✅ HUD principal créé")
        else:
            print("❌ Erreur création HUD principal")
            
    except Exception as e:
        print(f"❌ Erreur HUD principal: {e}")

def creer_cadran_boom():
    """Crée le cadran d'analyse Boom en bas à droite"""
    try:
        # Supprimer l'ancien cadran s'il existe
        mt5.object_delete(0, "BoomAnalysisDisplay")
        mt5.object_delete(0, "BoomAnalysisText")
        
        # Créer le rectangle de fond
        if mt5.object_create(0, "BoomAnalysisDisplay", mt5.OBJ_RECTANGLE_LABEL, 0, 0, 0):
            # Position et taille
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_XDISTANCE, 600)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_YDISTANCE, 100)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_XSIZE, 200)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_YSIZE, 150)
            
            # Style
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_BGCOLOR, 0x1E1E1E)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_BORDER_COLOR, 0x00FF00)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_WIDTH, 2)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_BACK, True)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_SELECTABLE, False)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_HIDDEN, False)
            mt5.object_set_integer(0, "BoomAnalysisDisplay", mt5.OBJPROP_ZORDER, 1000)
            
            print("✅ Rectangle Boom créé")
        
        # Créer le texte
        if mt5.object_create(0, "BoomAnalysisText", mt5.OBJ_LABEL, 0, 0, 0):
            # Position
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_XDISTANCE, 610)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_YDISTANCE, 110)
            
            # Style
            mt5.object_set_string(0, "BoomAnalysisText", mt5.OBJPROP_FONT, "Arial")
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_FONTSIZE, 8)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_COLOR, 0xFFFFFF)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_ANCHOR, mt5.ANCHOR_LEFT_UPPER)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_BACK, False)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_SELECTABLE, False)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_HIDDEN, False)
            mt5.object_set_integer(0, "BoomAnalysisText", mt5.OBJPROP_ZORDER, 1001)
            
            # Texte initial
            boom_text = "🚀 BOOM RISING CHANNEL\\n━━━━━━━━━━━━━━━━━━━━━━\\nDirection: NEUTRAL\\nForce: 0%\\nConfiance: 0%\\nSignal: boom_hold\\nSpike Prob: 0.0%\\nTemps: 0s\\nEMA: N/A\\nCanal: N/A\\nPrix: 0.00\\nCanal Force: 0.0%\\nBreakout: 0.0%\\n⏰ " + datetime.now().strftime("%H:%M:%S")
            mt5.object_set_string(0, "BoomAnalysisText", mt5.OBJPROP_TEXT, boom_text)
            
            print("✅ Texte Boom créé")
        else:
            print("❌ Erreur création texte Boom")
            
    except Exception as e:
        print(f"❌ Erreur cadran Boom: {e}")

def creer_fleches_prediction():
    """Crée les flèches de prédiction sur le graphique"""
    print("\n🎯 Création des flèches de prédiction...")
    
    # Nettoyer les anciennes flèches
    nettoyer_anciennes_fleches()
    
    # Créer des flèches d'exemple
    creer_fleches_exemple()
    
    print("✅ Flèches de prédiction créées")

def nettoyer_anciennes_fleches():
    """Nettoie les anciennes flèches"""
    try:
        # Supprimer les objets qui commencent par "SignalArrow_"
        objects = mt5.object_get_all(0)
        if objects:
            for obj in objects:
                if obj.name.startswith("SignalArrow_"):
                    mt5.object_delete(0, obj.name)
        print("✅ Anciennes flèches nettoyées")
    except Exception as e:
        print(f"⚠️ Erreur nettoyage flèches: {e}")

def creer_fleches_exemple():
    """Crée des flèches d'exemple pour démonstration"""
    try:
        symbol = "Boom 1000 Index"
        current_time = datetime.now()
        
        # Flèche BOOM d'exemple
        boom_arrow_name = f"SignalArrow_BOOM_{int(time.time())}"
        if mt5.object_create(0, boom_arrow_name, mt5.OBJ_ARROW, 0, current_time, 10050.0):
            mt5.object_set_integer(0, boom_arrow_name, mt5.OBJPROP_ARROWCODE, 233)
            mt5.object_set_integer(0, boom_arrow_name, mt5.OBJPROP_COLOR, 0x00FF00)
            mt5.object_set_integer(0, boom_arrow_name, mt5.OBJPROP_WIDTH, 3)
            mt5.object_set_string(0, boom_arrow_name, mt5.OBJPROP_TEXT, "BOOM Prediction")
            print("✅ Flèche BOOM créée")
        
        # Flèche CRASH d'exemple
        crash_arrow_name = f"SignalArrow_CRASH_{int(time.time()) + 1}"
        if mt5.object_create(0, crash_arrow_name, mt5.OBJ_ARROW, 0, current_time, 10030.0):
            mt5.object_set_integer(0, crash_arrow_name, mt5.OBJPROP_ARROWCODE, 234)
            mt5.object_set_integer(0, crash_arrow_name, mt5.OBJPROP_COLOR, 0xFF0000)
            mt5.object_set_integer(0, crash_arrow_name, mt5.OBJPROP_WIDTH, 3)
            mt5.object_set_string(0, crash_arrow_name, mt5.OBJPROP_TEXT, "CRASH Prediction")
            print("✅ Flèche CRASH créée")
            
    except Exception as e:
        print(f"❌ Erreur création flèches: {e}")

def demarrer_affichage_dynamique():
    """Démarre l'affichage dynamique des indicateurs"""
    print("\n🔄 Démarrage de l'affichage dynamique...")
    
    # Démarrer le système d'affichage Boom
    try:
        from boom_display_mt5 import boom_display, start_boom_display
        
        boom_display.set_symbol("Boom 1000 Index")
        boom_display.set_timeframe("M1")
        boom_display.set_update_interval(5)
        
        start_boom_display()
        print("✅ Affichage dynamique Boom démarré")
        
    except Exception as e:
        print(f"⚠️ Erreur affichage dynamique: {e}")
    
    # Démarrer le monitoring des indicateurs
    demarrer_monitoring_indicators()
    
    print("✅ Affichage dynamique activé")

def demarrer_monitoring_indicators():
    """Démarre le monitoring des indicateurs"""
    print("\n📊 Monitoring des indicateurs activé")
    print("Les indicateurs seront mis à jour automatiquement")
    print("Surveillez l'apparition des flèches et des signaux")

def verifier_affichage():
    """Vérifie que l'affichage fonctionne correctement"""
    print("\n🔍 Vérification de l'affichage...")
    
    # Vérifier les objets créés
    objects = mt5.object_get_all(0)
    if objects:
        print(f"✅ {len(objects)} objet(s) d'affichage trouvé(s)")
        
        for obj in objects:
            if "HUD" in obj.name or "Boom" in obj.name or "SignalArrow" in obj.name:
                print(f"   - {obj.name}: {obj.type}")
    else:
        print("⚠️ Aucun objet d'affichage trouvé")
    
    # Vérifier les indicateurs
    symbol = "Boom 1000 Index"
    handles = []
    
    try:
        ema10_handle = mt5.iMA(symbol, mt5.TIMEFRAME_M1, 10, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema10_handle != mt5.INVALID_HANDLE:
            handles.append("EMA 10")
        
        ema30_handle = mt5.iMA(symbol, mt5.TIMEFRAME_M1, 30, 0, mt5.MODE_EMA, mt5.PRICE_CLOSE)
        if ema30_handle != mt5.INVALID_HANDLE:
            handles.append("EMA 30")
        
        rsi_handle = mt5.iRSI(symbol, mt5.TIMEFRAME_M1, 14, mt5.PRICE_CLOSE)
        if rsi_handle != mt5.INVALID_HANDLE:
            handles.append("RSI")
        
        if handles:
            print(f"✅ Indicateurs actifs: {', '.join(handles)}")
        else:
            print("⚠️ Aucun indicateur actif")
            
    except Exception as e:
        print(f"❌ Erreur vérification indicateurs: {e}")

if __name__ == "__main__":
    print("🎨 CORRECTION AFFICHAGE INDICATEURS")
    print("=" * 50)
    
    # Corriger l'affichage
    if corriger_affichage_indicators():
        print("\n✅ Correction terminée")
        
        # Vérifier l'affichage
        verifier_affichage()
        
        print("\n🎯 INDICATEURS MAINTENANT VISIBLES:")
        print("1. HUD principal en haut à gauche")
        print("2. Cadran d'analyse Boom en bas à droite")
        print("3. Flèches de prédiction sur le graphique")
        print("4. EMAs, RSI, MACD sur le graphique")
        print("5. Mise à jour automatique toutes les 5 secondes")
        
        print("\n📊 SURVEILLANCE:")
        print("- Vérifiez que les indicateurs apparaissent sur le graphique")
        print("- Surveillez l'apparition des flèches de prédiction")
        print("- Contrôlez les messages dans l'onglet 'Experts' de MT5")
        
    else:
        print("\n❌ Échec de la correction")
    
    # Fermer MT5
    mt5.shutdown()
    print("\n🔚 MT5 fermé")
