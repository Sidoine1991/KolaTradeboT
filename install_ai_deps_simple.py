#!/usr/bin/env python3
"""
Script simplifié pour installer les dépendances du serveur AI
"""

import subprocess
import sys

def install_package(package, version=None):
    """Installer un package avec version spécifique si nécessaire"""
    try:
        if version:
            cmd = [sys.executable, "-m", "pip", "install", f"{package}=={version}", "--timeout", "60"]
        else:
            cmd = [sys.executable, "-m", "pip", "install", package, "--timeout", "60"]
        
        print(f"📦 Installation de {package}{'==' + version if version else ''}...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"✅ {package} installé avec succès")
            return True
        else:
            print(f"❌ Erreur installation {package}: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"❌ Exception installation {package}: {e}")
        return False

def main():
    """Installation des dépendances essentielles"""
    print("🔧 INSTALLATION DÉPENDANCES SERVEUR AI")
    print("=" * 50)
    
    # Packages essentiels avec versions compatibles
    packages = [
        ("fastapi", "0.104.1"),  # Version stable plus ancienne
        ("uvicorn", "0.24.0"),   # Version compatible
        ("pydantic", "1.10.13"), # Version compatible avec fastapi 0.104
        ("requests", "2.31.0"),
    ]
    
    success_count = 0
    
    for package, version in packages:
        if install_package(package, version):
            success_count += 1
        print("-" * 30)
    
    print(f"\n📊 Résultat: {success_count}/{len(packages)} packages installés")
    
    if success_count == len(packages):
        print("\n✅ Toutes les dépendances installées!")
        print("\n🚀 Vous pouvez maintenant démarrer le serveur:")
        print("   python ai_server.py")
    else:
        print("\n⚠️  Certaines dépendances ont échoué")
        print("📝 Essayez d'installer manuellement:")
        for package, version in packages:
            print(f"   pip install {package}=={version}")
    
    print("\n🎯 Test du serveur après installation:")
    print("   python debug_local_ai_server_simple.py")

if __name__ == "__main__":
    main()
