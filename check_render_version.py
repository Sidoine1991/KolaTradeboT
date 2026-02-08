#!/usr/bin/env python3
"""
Script pour vérifier la version du serveur AI sur Render
"""

import requests
import json
from datetime import datetime

def check_render_version():
    """Vérifier la version du serveur AI sur Render"""
    print("🔍 VÉRIFICATION VERSION SERVEUR AI RENDER")
    print("=" * 50)
    
    try:
        # Test endpoint racine pour obtenir la version
        response = requests.get("https://kolatradebot.onrender.com/", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            version = data.get('version', 'Inconnue')
            print(f"✅ Serveur Render accessible")
            print(f"📊 Version actuelle: {version}")
            
            # Vérifier les endpoints disponibles
            endpoints = data.get('endpoints', [])
            if endpoints:
                print(f"🔗 Endpoints disponibles: {len(endpoints)}")
                for endpoint in endpoints:
                    print(f"   - {endpoint}")
            
            # Vérifier si les nouveaux endpoints sont présents
            if '/test' in str(endpoints) and '/validate' in str(endpoints):
                print("✅ Nouveaux endpoints /test et /validate détectés")
            else:
                print("⚠️  Nouveaux endpoints non détectés")
                
        else:
            print(f"❌ Erreur HTTP: {response.status_code}")
            
    except requests.exceptions.Timeout:
        print("⌛ Timeout: Le serveur Render met du temps à démarrer")
        print("💡 Essayez à nouveau dans 30 secondes")
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur de connexion: {e}")
        print("💡 Le serveur Render est peut-être en cours de démarrage")
    
    except json.JSONDecodeError:
        print("❌ Réponse JSON invalide")
        print("💡 Le serveur peut avoir un problème")
    
    print("\n" + "=" * 50)
    print("📋 VERSIONS LOCALES:")
    
    # Lire la version locale
    try:
        with open('ai_server.py', 'r') as f:
            content = f.read()
            for line in content.split('\n'):
                if 'version' in line.lower() and '=' in line:
                    print(f"   {line.strip()}")
    except:
        print("   Impossible de lire la version locale")
    
    print("\n🎯 ACTION RECOMMANDÉE:")
    print("   Si les versions diffèrent, déployez sur Render")

if __name__ == "__main__":
    check_render_version()
