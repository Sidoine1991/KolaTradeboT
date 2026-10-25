"""
Vérifie la structure des packages et les chemins d'import
"""
import os
import sys
import importlib.util
from pathlib import Path

def check_file_exists(path):
    """Vérifie si un fichier existe et est lisible"""
    path = Path(path)
    exists = path.exists() and path.is_file()
    return exists, str(path.absolute())

def check_package_structure():
    """Vérifie la structure des packages et les chemins d'import"""
    print("=== Vérification de la structure des packages ===\n")
    
    # Vérification des dossiers principaux
    base_dirs = [
        'backend',
        'backend/core',
        'backend/risk',
        'backend/execution',
        'backend/strategies',
        'config'
    ]
    
    # Vérification des fichiers __init__.py
    init_files = [
        'backend/__init__.py',
        'backend/core/__init__.py',
        'backend/risk/__init__.py',
        'backend/execution/__init__.py',
        'backend/strategies/__init__.py'
    ]
    
    # Vérification des modules principaux
    modules = [
        'backend/core/data_manager.py',
        'backend/core/strategy_engine.py',
        'backend/risk/risk_manager.py',
        'backend/execution/order_executor.py',
        'config/settings.py'
    ]
    
    # Vérification des dossiers
    print("Dossiers requis:")
    for d in base_dirs:
        exists = os.path.exists(d) and os.path.isdir(d)
        print(f"  - {d}: {'✓' if exists else '✗'}")
    
    # Vérification des fichiers __init__.py
    print("\nFichiers __init__.py:")
    for f in init_files:
        exists, path = check_file_exists(f)
        print(f"  - {f}: {'✓' if exists else f'✗ ({path})'}")
    
    # Vérification des modules
    print("\nModules principaux:")
    for m in modules:
        exists, path = check_file_exists(m)
        print(f"  - {m}: {'✓' if exists else f'✗ ({path})'}")
    
    # Vérification des imports
    print("\n=== Test des imports ===\n")
    
    # Ajout du répertoire racine au path Python
    root_dir = str(Path(__file__).parent.absolute())
    if root_dir not in sys.path:
        sys.path.insert(0, root_dir)
    
    # Test d'import des modules principaux
    imports_to_test = [
        'backend.core.data_manager',
        'backend.core.strategy_engine',
        'backend.risk.risk_manager',
        'backend.execution.order_executor',
        'config.settings'
    ]
    
    for module_name in imports_to_test:
        try:
            spec = importlib.util.find_spec(module_name)
            if spec is None:
                print(f"✗ {module_name}: Module non trouvé")
                print(f"   Chemin de recherche: {sys.path}")
            else:
                print(f"✓ {module_name}: Import réussi")
                print(f"   Emplacement: {spec.origin}")
                
                # Essai d'import réel
                try:
                    module = importlib.import_module(module_name)
                    print(f"   Classe principale: {getattr(module, module_name.split('.')[-1].title(), 'Non trouvée')}")
                except Exception as e:
                    print(f"   Erreur lors de l'import: {e}")
                    
        except Exception as e:
            print(f"✗ {module_name}: Erreur - {e}")
    
    print("\n=== Vérification terminée ===")

if __name__ == "__main__":
    check_package_structure()
