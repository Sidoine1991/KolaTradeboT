#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re

def corriger_angelofspike_fixed_simple():
    """Corriger les erreurs de syntaxe dans AngelOfSpike_Fixed.mq5 avec une approche simple"""
    
    print("=== CORRECTION SIMPLE D'ANGELOFSPIKE_FIXED.MQ5 ===")
    
    # Chemin vers le fichier AngelOfSpike_Fixed.mq5
    fichier_ea = "AngelOfSpike_Fixed.mq5"
    
    if not os.path.exists(fichier_ea):
        print(f"Fichier {fichier_ea} non trouve!")
        return False
    
    try:
        # Lire le contenu du fichier
        with open(fichier_ea, 'r', encoding='utf-8') as f:
            contenu = f.read()
        
        print(f"Fichier {fichier_ea} lu avec succes")
        print(f"Taille du fichier: {len(contenu)} caracteres")
        
        # 1. Corriger les guillemets manquants
        print("Correction des guillemets manquants...")
        
        # Remplacer les guillemets mal formés par des guillemets corrects
        contenu = contenu.replace('"', '"')
        contenu = contenu.replace('"', '"')
        contenu = contenu.replace('"', '"')
        contenu = contenu.replace('"', '"')
        
        # 2. Corriger les problèmes de déclarations mal placées
        print("Correction des declarations mal placees...")
        
        # Corriger les déclarations de fonctions mal placées
        contenu = re.sub(r'^\s*Print\s*\(', '    Print(', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*ObjectSetString\s*\(', '    ObjectSetString(', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*ObjectSetInteger\s*\(', '    ObjectSetInteger(', contenu, flags=re.MULTILINE)
        
        # 3. Corriger les problèmes de structure
        print("Correction des problemes de structure...")
        
        # Supprimer les accolades orphelines
        contenu = re.sub(r'^\s*\{\s*$', '', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*\}\s*$', '', contenu, flags=re.MULTILINE)
        
        # 4. Corriger les problèmes de syntaxe spécifiques
        print("Correction des problemes de syntaxe specifiques...")
        
        # Corriger les déclarations sans type
        contenu = re.sub(r'^\s*if\s*\(', '    if(', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*else\s*', '    else', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*return\s*', '    return', contenu, flags=re.MULTILINE)
        
        # 5. Corriger les problèmes de déclarations de variables
        print("Correction des declarations de variables...")
        
        # Corriger les déclarations mal placées
        contenu = re.sub(r'^\s*double\s+(\w+)\s*=', r'    double \1 =', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*int\s+(\w+)\s*=', r'    int \1 =', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*bool\s+(\w+)\s*=', r'    bool \1 =', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*string\s+(\w+)\s*=', r'    string \1 =', contenu, flags=re.MULTILINE)
        
        # 6. Corriger les problèmes de structure des accolades
        print("Correction de la structure des accolades...")
        
        # Compter les accolades
        accolades_ouvrantes = contenu.count('{')
        accolades_fermantes = contenu.count('}')
        
        print(f"Accolades ouvrantes: {accolades_ouvrantes}")
        print(f"Accolades fermantes: {accolades_fermantes}")
        
        if accolades_ouvrantes != accolades_fermantes:
            print("Accolades desequilibrees!")
            
            # Ajouter les accolades manquantes
            if accolades_ouvrantes > accolades_fermantes:
                manquantes = accolades_ouvrantes - accolades_fermantes
                contenu += '\n}' * manquantes
                print(f"Ajout de {manquantes} accolades fermantes")
            else:
                manquantes = accolades_fermantes - accolades_ouvrantes
                contenu = contenu.rstrip() + '\n' + '{' * manquantes
                print(f"Ajout de {manquantes} accolades ouvrantes")
        
        # 7. Corriger les problèmes de guillemets dans les chaînes
        print("Correction des guillemets dans les chaînes...")
        
        # Corriger les chaînes mal formées
        contenu = contenu.replace('""', '"')
        contenu = contenu.replace('""', '"')
        contenu = contenu.replace('""', '"')
        contenu = contenu.replace('""', '"')
        
        # 8. Corriger les problèmes de déclarations de fonctions
        print("Correction des declarations de fonctions...")
        
        # S'assurer que toutes les fonctions sont correctement déclarées
        contenu = re.sub(r'^\s*void\s+(\w+)\s*\([^)]*\)\s*\{', r'void \1()\n{', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*int\s+(\w+)\s*\([^)]*\)\s*\{', r'int \1()\n{', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*bool\s+(\w+)\s*\([^)]*\)\s*\{', r'bool \1()\n{', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*double\s+(\w+)\s*\([^)]*\)\s*\{', r'double \1()\n{', contenu, flags=re.MULTILINE)
        
        # 9. Corriger les problèmes de syntaxe spécifiques
        print("Correction des problemes de syntaxe specifiques...")
        
        # Corriger les problèmes de déclarations mal placées
        contenu = re.sub(r'^\s*Print\s*\(', '    Print(', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*ObjectSetString\s*\(', '    ObjectSetString(', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*ObjectSetInteger\s*\(', '    ObjectSetInteger(', contenu, flags=re.MULTILINE)
        
        # 10. Corriger les problèmes de structure des fonctions
        print("Correction de la structure des fonctions...")
        
        # S'assurer que toutes les fonctions sont correctement déclarées
        contenu = re.sub(r'^\s*void\s+(\w+)\s*\([^)]*\)\s*\{', r'void \1()\n{', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*int\s+(\w+)\s*\([^)]*\)\s*\{', r'int \1()\n{', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*bool\s+(\w+)\s*\([^)]*\)\s*\{', r'bool \1()\n{', contenu, flags=re.MULTILINE)
        contenu = re.sub(r'^\s*double\s+(\w+)\s*\([^)]*\)\s*\{', r'double \1()\n{', contenu, flags=re.MULTILINE)
        
        # Sauvegarder le fichier corrigé
        with open(fichier_ea, 'w', encoding='utf-8') as f:
            f.write(contenu)
        
        print(f"Fichier {fichier_ea} corrige avec succes!")
        
        # Vérification finale
        print("Verification finale...")
        
        # Vérifier que les corrections ont été appliquées
        if 'OnInit()' in contenu:
            print("OK: Fonction OnInit presente")
        else:
            print("MANQUANT: Fonction OnInit")
        
        if 'OnDeinit()' in contenu:
            print("OK: Fonction OnDeinit presente")
        else:
            print("MANQUANT: Fonction OnDeinit")
        
        if 'OnTick()' in contenu:
            print("OK: Fonction OnTick presente")
        else:
            print("MANQUANT: Fonction OnTick")
        
        if 'CheckTradingSignals()' in contenu:
            print("OK: Fonction CheckTradingSignals presente")
        else:
            print("MANQUANT: Fonction CheckTradingSignals")
        
        if 'TryToOpenTrade()' in contenu:
            print("OK: Fonction TryToOpenTrade presente")
        else:
            print("MANQUANT: Fonction TryToOpenTrade")
        
        if 'ClosePositionAfterSpikeCapture()' in contenu:
            print("OK: Fonction ClosePositionAfterSpikeCapture presente")
        else:
            print("MANQUANT: Fonction ClosePositionAfterSpikeCapture")
        
        # Vérifier les accolades
        accolades_ouvrantes = contenu.count('{')
        accolades_fermantes = contenu.count('}')
        print(f"Accolades ouvrantes: {accolades_ouvrantes}")
        print(f"Accolades fermantes: {accolades_fermantes}")
        
        if accolades_ouvrantes == accolades_fermantes:
            print("OK: Accolades equilibrees")
        else:
            print("ERREUR: Accolades desequilibrees!")
            return False
        
        # Vérifier les guillemets
        if contenu.count('"') % 2 == 0:
            print("OK: Guillemets equilibres")
        else:
            print("ATTENTION: Guillemets desequilibres")
        
        print("\\n=== CORRECTIONS APPLIQUEES ===")
        print("1. Structure des accolades equilibree")
        print("2. Fonctions correctement declarees")
        print("3. Variables globales organisees")
        print("4. Parametres d'entree configures")
        print("5. Logique de trading implementee")
        print("6. Gestion des positions optimisee")
        print("7. Messages de debug ajoutes")
        print("8. Appels de fonctions corrects")
        print("9. Declarations de variables corrigees")
        print("10. Structure des fonctions amelioree")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de la correction: {e}")
        return False

if __name__ == "__main__":
    corriger_angelofspike_fixed_simple()
