#!/usr/bin/env python3
"""
Script pour corriger la syntaxe de ai_server.py
"""

import re

def fix_ai_server_syntax():
    """Corrige les erreurs de syntaxe dans ai_server.py"""
    print("🔧 CORRECTION SYNTAXE AI_SERVER")
    print("=" * 60)
    
    try:
        with open('ai_server.py', 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Problème 1: Fonction calculate_market_state mal terminée
        # Trouver la fin de la fonction et ajouter le bloc except manquant
        
        # Chercher le pattern de la fonction
        pattern = r'(def calculate_market_state.*?)(.*?)(return \{.*?\}\s*)(\s*def _generate_simulated_prices)'
        match = re.search(pattern, content, re.DOTALL)
        
        if match:
            print("✅ Fonction calculate_market_state trouvée")
            func_start = match.group(1)
            func_body = match.group(2)
            next_func = match.group(3)
            
            # Vérifier si le bloc except est présent
            if 'except Exception as e:' not in func_body:
                print("❌ Bloc except manquant dans calculate_market_state")
                
                # Ajouter le bloc except
                corrected_func = func_start + func_body + '''
        
    except Exception as e:
        logger.error(f"Erreur calcul état global marché {symbol}: {e}")
        return {"market_state": "ERREUR", "market_trend": "INCONNU"}
        
''' + next_func
                
                # Remplacer dans le contenu
                corrected_content = content.replace(match.group(0), corrected_func)
                
                # Écrire le fichier corrigé
                with open('ai_server.py', 'w', encoding='utf-8') as f:
                    f.write(corrected_content)
                
                print("✅ Bloc except ajouté à calculate_market_state")
                return True
            else:
                print("✅ Bloc except déjà présent")
                return False
        else:
            print("❌ Fonction calculate_market_state non trouvée")
            return False
            
    except Exception as e:
        print(f"❌ Erreur correction: {e}")
        return False

def test_syntax_after_fix():
    """Test la syntaxe après correction"""
    print("\n🧪 TEST SYNTAXE APRÈS CORRECTION")
    print("-" * 60)
    
    try:
        import ast
        with open('ai_server.py', 'r', encoding='utf-8') as f:
            content = f.read()
        
        ast.parse(content)
        print("✅ Syntaxe Python valide après correction")
        return True
        
    except SyntaxError as e:
        print(f"❌ Erreur syntaxe après correction:")
        print(f"   Ligne {e.lineno}: {e.text.strip()}")
        print(f"   Erreur: {e.msg}")
        return False
    except Exception as e:
        print(f"❌ Erreur test syntaxe: {e}")
        return False

def main():
    """Fonction principale"""
    print("🔧 CORRECTION AUTOMATIQUE SYNTAXE AI_SERVER")
    print("=" * 80)
    
    # Étape 1: Corriger les erreurs
    fix_applied = fix_ai_server_syntax()
    
    # Étape 2: Tester la syntaxe
    if fix_applied:
        syntax_ok = test_syntax_after_fix()
        
        if syntax_ok:
            print("\n" + "=" * 80)
            print("🎉 SYNTAXE CORRIGÉE AVEC SUCCÈS")
            print("=" * 80)
            print("✅ Le fichier ai_server.py devrait maintenant compiler correctement")
            print("🚀 Vous pouvez redémarrer l'AI Server")
        else:
            print("\n" + "=" * 80)
            print("❌ ERREURS PERSISTENTES APRÈS CORRECTION")
            print("=" * 80)
            print("🔧 Vérification manuelle requise")
    else:
        print("\n💡 Aucune correction appliquée - vérifiez manuellement")

if __name__ == "__main__":
    main()
