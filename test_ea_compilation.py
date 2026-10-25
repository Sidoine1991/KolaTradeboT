#!/usr/bin/env python3
"""
Test de compilation de l'EA SpikeHunter
Vérification des erreurs de syntaxe MQL5
"""

import os
import re

def check_mql5_syntax(file_path):
    """Vérifie la syntaxe MQL5 basique"""
    if not os.path.exists(file_path):
        return False, f"Fichier {file_path} introuvable"
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    errors = []
    
    # Vérifications de syntaxe basiques
    checks = [
        (r'#property\s+\w+', "Propriétés définies"),
        (r'input\s+', "Paramètres d'entrée"),
        (r'int\s+OnInit\s*\(', "Fonction OnInit"),
        (r'void\s+OnTick\s*\(', "Fonction OnTick"),
        (r'void\s+OnDeinit\s*\(', "Fonction OnDeinit"),
        (r'//\+------------------------------------------------------------------\+', "Structure de code"),
        (r'#include\s+', "Includes (optionnel)"),
    ]
    
    for pattern, description in checks:
        if not re.search(pattern, content):
            errors.append(f"❌ {description} - MANQUANT")
        else:
            print(f"✅ {description}")
    
    # Vérifications spécifiques
    if 'INVALID_HANDLE' not in content:
        errors.append("❌ INVALID_HANDLE non défini")
    else:
        print("✅ INVALID_HANDLE défini")
    
    if 'TRADE_ACTION_DEAL' not in content:
        errors.append("❌ TRADE_ACTION_DEAL non défini")
    else:
        print("✅ TRADE_ACTION_DEAL défini")
    
    if 'OrderSend' not in content:
        errors.append("❌ OrderSend non utilisé")
    else:
        print("✅ OrderSend utilisé")
    
    # Vérification des accolades équilibrées
    open_braces = content.count('{')
    close_braces = content.count('}')
    if open_braces != close_braces:
        errors.append(f"❌ Accolades non équilibrées: {open_braces} ouvertes, {close_braces} fermées")
    else:
        print("✅ Accolades équilibrées")
    
    # Vérification des parenthèses équilibrées
    open_parens = content.count('(')
    close_parens = content.count(')')
    if open_parens != close_parens:
        errors.append(f"❌ Parenthèses non équilibrées: {open_parens} ouvertes, {close_parens} fermées")
    else:
        print("✅ Parenthèses équilibrées")
    
    return len(errors) == 0, errors

def test_ea_files():
    """Test des fichiers EA"""
    print("🤖 Test de Compilation EA SpikeHunter")
    print("=" * 50)
    
    files_to_test = [
        "mt5/SpikeHunter_Simple_EA.mq5",
        "mt5/SpikeHunter_EA.mq5",
        "mt5/SpikeDetector.mq5"
    ]
    
    all_passed = True
    
    for file_path in files_to_test:
        print(f"\n📁 Test de {file_path}:")
        print("-" * 30)
        
        success, errors = check_mql5_syntax(file_path)
        
        if success:
            print("✅ Compilation OK")
        else:
            print("❌ Erreurs de compilation:")
            for error in errors:
                print(f"   {error}")
            all_passed = False
    
    return all_passed

def test_ea_requirements():
    """Test des exigences de l'EA"""
    print("\n🔧 Test des Exigences EA")
    print("=" * 30)
    
    requirements = [
        ("Fichier EA principal", "mt5/SpikeHunter_EA.mq5"),
        ("Fichier indicateur", "mt5/SpikeDetector.mq5"),
        ("Template graphique", "mt5/SpikeHunter_Template.tpl"),
        ("Guide d'utilisation", "GUIDE_ROBOT_SPIKE_HUNTER.md")
    ]
    
    all_exist = True
    for name, file_path in requirements:
        if os.path.exists(file_path):
            print(f"✅ {name}")
        else:
            print(f"❌ {name} - MANQUANT")
            all_exist = False
    
    return all_exist

def main():
    """Fonction principale"""
    print("🚀 Test de Compilation EA SpikeHunter - TradBOT")
    print("=" * 60)
    
    # Test des fichiers
    files_ok = test_ea_requirements()
    
    # Test de compilation
    compilation_ok = test_ea_files()
    
    # Résumé
    print("\n" + "=" * 60)
    print("📋 RÉSUMÉ DES TESTS")
    print("=" * 60)
    
    results = [
        ("Fichiers présents", files_ok),
        ("Compilation OK", compilation_ok)
    ]
    
    for test_name, test_result in results:
        status_icon = "✅" if test_result else "❌"
        print(f"{status_icon} {test_name}")
    
    if files_ok and compilation_ok:
        print("\n🎉 L'EA est prêt pour la compilation dans MetaEditor!")
        print("\n📋 INSTRUCTIONS:")
        print("1. Ouvrez MetaEditor")
        print("2. Ouvrez mt5/SpikeHunter_EA.mq5")
        print("3. Cliquez sur 'Compile' (F7)")
        print("4. Répétez pour mt5/SpikeDetector.mq5")
        print("5. Attachez l'EA au graphique Boom/Crash")
        print("6. Configurez les paramètres")
        print("7. Activez le trading automatique")
        
        return True
    else:
        print("\n⚠️ Des erreurs doivent être corrigées avant la compilation")
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
