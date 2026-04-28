#!/usr/bin/env python3
"""
Script de diagnostic pour vérifier les conflits IA/positions dans MT5
"""

import MetaTrader5 as mt5
import json
from datetime import datetime

def check_mt5_positions_conflict():
    """Vérifier les positions actuelles et les conflits IA potentiels"""
    
    print("🔍 Diagnostic Conflit IA/Positions MT5")
    print("=" * 50)
    
    # Initialiser MT5
    if not mt5.initialize():
        print("❌ Impossible d'initialiser MT5")
        return
    
    try:
        # Récupérer les positions
        positions = mt5.positions_get()
        
        if positions is None or len(positions) == 0:
            print("📊 Aucune position ouverte")
            return
        
        print(f"📊 {len(positions)} position(s) trouvée(s)")
        print()
        
        # Simuler les données IA (à adapter selon votre système)
        # Pour l'exemple, je vais simuler que l'IA dit BUY
        simulated_ia_action = "BUY"
        simulated_ia_confidence = 0.85
        
        print("🤖 État IA Server (simulé):")
        print(f"   Action: {simulated_ia_action}")
        print(f"   Confiance: {simulated_ia_confidence * 100:.1f}%")
        print()
        
        # Analyser chaque position
        conflicts_detected = []
        
        for pos in positions:
            pos_type = "BUY" if pos.type == mt5.POSITION_TYPE_BUY else "SELL"
            profit = pos.profit
            symbol = pos.symbol
            ticket = pos.ticket
            comment = pos.comment
            open_time = datetime.fromtimestamp(pos.time)
            
            # Vérifier le conflit
            conflict = False
            if pos_type == "SELL" and simulated_ia_action == "BUY":
                conflict = True
            elif pos_type == "BUY" and simulated_ia_action == "SELL":
                conflict = True
            
            print(f"📋 Position #{ticket}")
            print(f"   Symbole: {symbol}")
            print(f"   Type: {pos_type}")
            print(f"   Profit: {profit:.2f}$")
            print(f"   Commentaire: {comment}")
            print(f"   Ouverture: {open_time.strftime('%H:%M:%S')}")
            
            if conflict:
                conflicts_detected.append(pos)
                print(f"   🚨 CONFLIT IA: Position {pos_type} vs IA {simulated_ia_action}")
                
                # Analyser les raisons possibles de non-fermeture
                age_seconds = (datetime.now() - open_time).total_seconds()
                
                print(f"   🔍 Analyse du conflit:")
                print(f"      Âge: {age_seconds:.0f}s")
                
                if "SMC_CH" in comment:
                    print(f"      ⚠️ Protection: Boom/Crash LIMIT (SMC_CH)")
                if "RETURN_MOVE" in comment:
                    print(f"      ⚠️ Protection: Boom/Crash RETURN_MOVE")
                if "SPIKE TRADE" in comment:
                    print(f"      ⚠️ Protection: SPIKE TRADE")
                if age_seconds < 30:
                    print(f"      ⚠️ Protection: Position récente (<30s)")
                
                print(f"      💡 Solution: Activer ForceImmediateConflictClose=true")
            else:
                print(f"   ✅ Alignement: Position {pos_type} = IA {simulated_ia_action}")
            
            print()
        
        # Résumé
        print("📊 RÉSUMÉ DU DIAGNOSTIC")
        print("=" * 30)
        
        if conflicts_detected:
            print(f"🚨 {len(conflicts_detected)} CONFLIT(S) DÉTECTÉ(S)")
            print()
            print("⚠️ POSITIONS EN CONFLIT:")
            for i, pos in enumerate(conflicts_detected, 1):
                pos_type = "BUY" if pos.type == mt5.POSITION_TYPE_BUY else "SELL"
                print(f"   {i}. {pos.symbol} - {pos_type} (Profit: {pos.profit:.2f}$)")
            
            print()
            print("🔧 ACTIONS RECOMMANDÉES:")
            print("   1. Vérifier que UseDirectionConflictClose = true")
            print("   2. Activer ForceImmediateConflictClose = true")
            print("   3. Redémarrer le robot MT5")
            print("   4. Surveiller les logs 'CONFLIT IA DÉTECTÉ'")
            
        else:
            print("✅ AUCUN CONFLIT DÉTECTÉ")
            print("   Toutes les positions sont alignées avec l'IA")
        
        # Informations sur le robot
        print()
        print("🤖 PARAMÈTRES DU ROBOT À VÉRIFIER:")
        print("   UseDirectionConflictClose: true (activé)")
        print("   ForceImmediateConflictClose: true (nouveau - forcé)")
        print("   UseAIServer: true (activé)")
        print("   MinAIConfidence: 0.55 (55% minimum)")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
    finally:
        mt5.shutdown()

def show_expected_logs():
    """Montrer les logs attendus après correction"""
    
    print("\n📋 LOGS ATTENDUS APRÈS CORRECTION")
    print("=" * 40)
    
    print("🚨 CONFLIT IA DÉTECTÉ - Crash 1000 Index")
    print("   | Type=SELL | IA=BUY 85.0% | Profit=-1.25$")
    print("   | Âge=45s | Comment=SPIKE TRADE")
    print("   | ⚠️ FERMETURE IMMÉDIATE PRIORITAIRE SUR CONFLIT")
    print("🔥 FORCE IMMÉDIAT ACTIVÉ - Fermeture sans aucune protection")
    print("⚠️ POSITION FERMÉE (conflit IA) - Crash 1000 Index")
    print("   | Type=SELL | IA=BUY 85.0% | PERTE=-1.25$")

if __name__ == "__main__":
    print("🚀 Diagnostic Conflit IA/Positions")
    print("=" * 50)
    
    check_mt5_positions_conflict()
    show_expected_logs()
    
    print("\n🎯 OBJECTIF:")
    print("   • IA Server = BUY")
    print("   • Position SELL sur Crash = FERMÉE immédiatement")
    print("   • Plus de protections qui bloquent la fermeture")
