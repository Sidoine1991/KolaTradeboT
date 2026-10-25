#!/usr/bin/env python3
"""
Script simple de diagnostic pour les tables Supabase vides
"""

import os
import sys

def check_server():
    """Vérifie si le serveur IA fonctionne"""
    print("🔍 VÉRIFICATION SERVEUR IA")
    try:
        # Essayer de faire un ping simple
        import urllib.request
        try:
            response = urllib.request.urlopen("http://localhost:8000/health", timeout=5)
            print(f"✅ Serveur IA accessible: HTTP {response.status_code}")
            return True
        except:
            print("❌ Serveur IA non accessible")
            print("   💡 Démarrer avec: python ai_server_supabase.py")
            return False
    except ImportError:
        print("⚠️ urllib non disponible, vérification manuelle requise")
        return False

def check_tables():
    """Instructions pour vérifier les tables"""
    print("\n📊 VÉRIFICATION TABLES SUPABASE")
    print("🔗 URL Supabase:", os.getenv('SUPABASE_URL', 'Non configuré'))
    print("🔑 Clé API:", "Configurée" if os.getenv('SUPABASE_ANON_KEY') else "Non configurée")

    print("\n📋 ÉTAPES POUR VÉRIFIER LES TABLES:")
    print("1. Ouvrir Supabase Dashboard")
    print("2. Aller dans Table Editor")
    print("3. Vérifier tables: model_performance, trade_feedback, predictions")
    print("4. Si vides, les données n'ont pas été reçues")

def check_robot():
    """Instructions pour vérifier le robot"""
    print("\n🤖 VÉRIFICATION ROBOT MT5")
    print("📋 LOGS À CHERCHER DANS MT5:")
    print("   - '📤 ENVOI FEEDBACK IA' (envoi des données)")
    print("   - '✅ FEEDBACK IA ENVOYÉ' (succès)")
    print("   - '❌ ÉCHEC ENVOI FEEDBACK IA' (échec)")

    print("\n🔧 ACTIONS CORRECTIVES:")
    print("1. Démarrer le serveur IA")
    print("2. Ouvrir le robot MT5 et attendre qu'il ferme des positions")
    print("3. Vérifier les logs du robot pour confirmer l'envoi")

def main():
    print("🚀 DIAGNOSTIC - Tables Supabase vides")
    print("=" * 50)

    server_ok = check_server()
    check_tables()
    check_robot()

    print("\n" + "=" * 60)
    print("💡 RÉSUMÉ DU PROBLÈME:")
    if not server_ok:
        print("❌ Le serveur IA n'est pas en cours d'exécution")
        print("   → Démarrer avec: python ai_server_supabase.py")
    else:
        print("✅ Serveur IA OK - Problème = pas de trades fermés")
        print("   → Attendre que le robot MT5 ferme des positions")

    print("\n📊 Tables vides = Normal si aucun trade n'a été fermé")
    print("   Les données arrivent uniquement lors des fermetures de positions")
    print("=" * 60)

if __name__ == "__main__":
    main()
