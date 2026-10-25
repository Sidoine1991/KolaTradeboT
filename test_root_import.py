# Test d'import depuis la racine du projet
import sys
import os

print("=== Test d'import depuis la racine ===")
print(f"Python version: {sys.version}")
print(f"Working directory: {os.getcwd()}")

# Ajout du répertoire backend au path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

print("\n=== Test d'import de DataManager ===")
try:
    from core.data_manager import DataManager
    print("SUCCES: DataManager importé avec succès"
          f"\nClasse: {DataManager.__module__}.{DataManager.__name__}")
    
    # Test d'initialisation
    try:
        dm = DataManager()
        print("SUCCES: DataManager initialisé avec succès")
    except Exception as e:
        print(f"ERREUR: Échec de l'initialisation: {e}")
        
except ImportError as e:
    print(f"ERREUR: Échec de l'import: {e}")
    print("\n=== Contenu du répertoire backend/core/ ===")
    try:
        print("\n".join(os.listdir('backend/core')))
    except Exception as e:
        print(f"Impossible de lister le répertoire: {e}")

print("\nTest terminé")
