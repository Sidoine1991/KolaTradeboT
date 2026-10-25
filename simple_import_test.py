# Test d'import minimal
import sys
import os

print("=== Test d'import minimal ===")
print(f"Python version: {sys.version}")
print(f"Working directory: {os.getcwd()}")

# Ajout du répertoire backend au path
backend_path = os.path.join(os.path.dirname(__file__), 'backend')
print(f"\nAjout au path: {backend_path}")
sys.path.insert(0, backend_path)

# Liste des dossiers dans backend
print("\nContenu du dossier backend:")
try:
    print("\n".join(os.listdir(backend_path)))
except Exception as e:
    print(f"Erreur: {e}")

# Essai d'import de DataManager
print("\nTentative d'import de DataManager...")
try:
    from core.data_manager import DataManager
    print("SUCCÈS: DataManager importé")
    print(f"Emplacement: {DataManager.__module__}.{DataManager.__name__}")
except ImportError as e:
    print(f"ÉCHEC: {e}")
    
    # Afficher le chemin de recherche Python
    print("\nChemin de recherche Python:")
    for i, path in enumerate(sys.path):
        print(f"{i+1}. {path}")

print("\nTest terminé")
