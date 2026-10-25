"""
Script de test pour diagnostiquer les problèmes d'import du ML Pipeline.
"""

import sys
import os

print("🔍 Diagnostic des imports ML Pipeline")
print("=" * 50)

# Ajout du répertoire racine au path
current_dir = os.path.dirname(os.path.abspath(__file__))
root_dir = current_dir
sys.path.insert(0, root_dir)

print(f"📁 Répertoire courant : {current_dir}")
print(f"📁 Répertoire racine : {root_dir}")
print(f"🐍 Python path : {sys.path[:3]}")

# Test des imports de base
print("\n📦 Test des imports de base...")

try:
    import pandas as pd
    print("✅ pandas importé")
except ImportError as e:
    print(f"❌ pandas : {e}")

try:
    import numpy as np
    print("✅ numpy importé")
except ImportError as e:
    print(f"❌ numpy : {e}")

try:
    import sklearn
    print("✅ sklearn importé")
except ImportError as e:
    print(f"❌ sklearn : {e}")

try:
    import ta
    print("✅ ta (technical analysis) importé")
except ImportError as e:
    print(f"❌ ta : {e}")

# Test des imports du backend
print("\n🔧 Test des imports du backend...")

try:
    from backend import mt5_connector
    print("✅ mt5_connector importé")
except ImportError as e:
    print(f"❌ mt5_connector : {e}")

try:
    from backend import technical_analysis
    print("✅ technical_analysis importé")
except ImportError as e:
    print(f"❌ technical_analysis : {e}")

# Test de l'import principal
print("\n🚀 Test de l'import principal...")

try:
    from backend.automated_ml_pipeline import AutomatedMLPipeline
    print("✅ AutomatedMLPipeline importé avec succès !")
    
    # Test d'initialisation
    try:
        pipeline = AutomatedMLPipeline()
        print("✅ Pipeline initialisé avec succès !")
        print(f"📊 Symboles disponibles : {len(pipeline.symbols)}")
    except Exception as e:
        print(f"❌ Erreur d'initialisation : {e}")
        
except ImportError as e:
    print(f"❌ AutomatedMLPipeline : {e}")
    
    # Tentative de diagnostic
    print("\n🔍 Diagnostic de l'erreur...")
    
    # Vérifier si le fichier existe
    pipeline_file = os.path.join(root_dir, "backend", "automated_ml_pipeline.py")
    if os.path.exists(pipeline_file):
        print(f"✅ Fichier trouvé : {pipeline_file}")
        
        # Vérifier la taille du fichier
        file_size = os.path.getsize(pipeline_file)
        print(f"📏 Taille du fichier : {file_size} octets")
        
        if file_size < 1000:
            print("⚠️ Fichier trop petit, possiblement incomplet")
        
        # Lire les premières lignes
        try:
            with open(pipeline_file, 'r', encoding='utf-8') as f:
                first_lines = f.readlines()[:10]
                print("📄 Premières lignes du fichier :")
                for i, line in enumerate(first_lines, 1):
                    print(f"   {i:2d}: {line.rstrip()}")
        except Exception as e:
            print(f"❌ Erreur lecture fichier : {e}")
    else:
        print(f"❌ Fichier non trouvé : {pipeline_file}")

print("\n" + "=" * 50)
print("🏁 Diagnostic terminé")
