#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de validation finale des corrections d'AngelOfSpike_Fixed.mq5
"""

def valider_corrections():
    """Valide que toutes les corrections ont été appliquées"""
    
    print("Validation des corrections finales...")
    
    try:
        # Lire le fichier
        with open('AngelOfSpike_Fixed.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
        
        issues = []
        
        # 1. Vérifier les guillemets manquants
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if 'string' in line and '=' in line and line.count('"') == 1:
                issues.append(f'Ligne {i+1}: Guillemet manquant - {line.strip()}')
        
        # 2. Vérifier la structure IndicatorData
        if 'struct IndicatorData' in content and '{' not in content.split('struct IndicatorData')[1].split('\n')[0]:
            issues.append('Structure IndicatorData mal formee')
        
        # 3. Vérifier les fonctions sans accolades
        functions_to_check = [
            'bool InitializeIndicators(',
            'void ReleaseIndicators()',
            'int OnInit()',
            'void OnDeinit(',
            'void OnTick()',
            'void OnTimer()',
        ]
        
        for func in functions_to_check:
            if func in content and '{' not in content.split(func)[1].split('\n')[0]:
                issues.append(f'Fonction sans accolade: {func}')
        
        # 4. Vérifier les mots-clés collés
        keywords = ['returnfalse', 'returntrue', 'returnINIT_FAILED', 'returnINIT_SUCCEEDED', 'return0', 'return1', 'return-1', 'elseif', 'elsedouble']
        for keyword in keywords:
            if keyword in content:
                issues.append(f'Mot-cle colle: {keyword}')
        
        # 5. Vérifier les accolades en trop
        if '{{{{{{' in content or '}}}}}}' in content:
            issues.append('Accolades en trop detectees')
        
        # 6. Vérifier les chaînes multiligne mal formées
        if 'StringFormat(' in content and '\n' in content.split('StringFormat(')[1].split(')')[0]:
            issues.append('Chaînes multiligne mal formees dans StringFormat')
        
        if issues:
            print("Problemes restants:")
            for issue in issues:
                print(f"  - {issue}")
            return False
        else:
            print("Aucun probleme detecte - toutes les corrections ont ete appliquees avec succes!")
            return True
        
    except Exception as e:
        print(f"Erreur lors de la validation: {e}")
        return False

if __name__ == "__main__":
    valider_corrections()