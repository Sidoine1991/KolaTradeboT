#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os

def corriger_accolades_final():
    """Corriger les accolades déséquilibrées dans AngelOfSpike_Fixed.mq5"""
    
    print("=== CORRECTION DES ACCOLADES FINALES ===")
    
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
        
        # Sauvegarder le fichier corrigé
        with open(fichier_ea, 'w', encoding='utf-8') as f:
            f.write(contenu)
        
        print(f"Fichier {fichier_ea} corrige avec succes!")
        
        # Vérification finale
        print("Verification finale...")
        
        # Recompter les accolades
        accolades_ouvrantes = contenu.count('{')
        accolades_fermantes = contenu.count('}')
        
        print(f"Accolades ouvrantes: {accolades_ouvrantes}")
        print(f"Accolades fermantes: {accolades_fermantes}")
        
        if accolades_ouvrantes == accolades_fermantes:
            print("OK: Accolades equilibrees")
        else:
            print("ERREUR: Accolades desequilibrees!")
            return False
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de la correction: {e}")
        return False

if __name__ == "__main__":
    corriger_accolades_final()
