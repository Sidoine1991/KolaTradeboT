#!/usr/bin/env python3
"""
AI Server avec indentation corrigée - Version de secours
"""

# Copie du fichier original avec corrections minimales
import shutil
import os

def create_fixed_version():
    """Créer une version corrigée du serveur AI"""
    
    print("CRÉATION VERSION CORRIGÉE")
    print("=" * 40)
    
    # Copier le fichier original
    shutil.copy('ai_server.py', 'ai_server_backup.py')
    print("✅ Backup créé: ai_server_backup.py")
    
    # Lire et corriger les erreurs évidentes
    with open('ai_server.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Corrections simples
    corrections = [
        # Corriger l'indentation du for loop
        ('for i in range(periods):\nif np.random.random()', 'for i in range(periods):\n            if np.random.random()'),
        
        # Corriger d'autres erreurs d'indentation évidentes
        ('                if signal == "BUY":\n                    confidence', '                if signal == "BUY":\n                    confidence'),
        ('                if signal == "SELL":\n                    confidence', '                if signal == "SELL":\n                    confidence'),
    ]
    
    corrected_content = content
    for old, new in corrections:
        if old in corrected_content:
            corrected_content = corrected_content.replace(old, new)
            print(f"✅ Correction appliquée: {old[:50]}...")
    
    # Sauvegarder la version corrigée
    with open('ai_server_fixed.py', 'w', encoding='utf-8') as f:
        f.write(corrected_content)
    
    print("✅ Version corrigée créée: ai_server_fixed.py")
    print("\n🎯 UTILISATION:")
    print("   python ai_server_fixed.py")
    print("\n📋 Si des erreurs persistent:")
    print("   1. Utiliser ai_server_backup.py")
    print("   2. Corriger manuellement dans l'IDE")

if __name__ == "__main__":
    create_fixed_version()
