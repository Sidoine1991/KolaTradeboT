#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de correction d'AngelOfSpike_Fixed.mq5 selon le plan détaillé
"""

import re

def corriger_angelofspike_fixed():
    """Applique les corrections selon le plan détaillé"""
    
    print("Application des corrections selon le plan detaille...")
    
    try:
        # Lire le fichier
        with open('AngelOfSpike_Fixed.mq5', 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        corrections_applied = 0
        
        # 1. Corriger les guillemets manquants
        print("1. Correction des guillemets manquants...")
        
        # Variables globales avec guillemets manquants
        guillemets_fixes = [
            (r'string g_currentSymbol = ";', 'string g_currentSymbol = "";'),
            (r'string g_spikePredictionSymbol = ";', 'string g_spikePredictionSymbol = "";'),
            (r'string g_lastSameSymbol = ";', 'string g_lastSameSymbol = "";'),
            (r'string g_concurrentSymbolList = ";', 'string g_concurrentSymbolList = "";'),
            (r'string g_lastBoomAnalysis = ";', 'string g_lastBoomAnalysis = "";'),
            (r'string g_boomApiResponse = ";', 'string g_boomApiResponse = "";'),
            (r'if\(g_currentSymbol != "\)', 'if(g_currentSymbol != "")'),
            (r'g_currentSymbol = ";', 'g_currentSymbol = "";'),
            (r'if\(analysis == "\)', 'if(analysis == "")'),
        ]
        
        for pattern, replacement in guillemets_fixes:
            if re.search(pattern, content):
                content = re.sub(pattern, replacement, content)
                corrections_applied += 1
                print(f"   Corrige: {pattern}")
        
        # 2. Corriger la structure IndicatorData
        print("2. Correction de la structure IndicatorData...")
        
        if 'struct IndicatorData' in content and '{' not in content.split('struct IndicatorData')[1].split('\n')[0]:
            content = content.replace('struct IndicatorData', 'struct IndicatorData\n{')
            corrections_applied += 1
            print("   Structure IndicatorData corrigee")
        
        # 3. Corriger les fonctions sans accolades ouvrantes
        print("3. Correction des fonctions sans accolades ouvrantes...")
        
        functions_to_fix = [
            'bool InitializeIndicators(string symbol)',
            'void ReleaseIndicators()',
            'int OnInit()',
            'void OnDeinit(const int reason)',
            'void OnTick()',
            'void OnTimer()',
            'int AnalyzeConfluenceStrategy(const string symbol = NULL)',
            'int AnalyzeIndicator2025(const string symbol)',
            'int AnalyzeSupportResistance(const string symbol)',
            'int AnalyzeOrderBlock(const string symbol)',
            'int AnalyzeOTE_FIBO(const string symbol)',
            'int AnalyzeBOS_CHoCH(const string symbol)',
            'bool ExecuteTrade(const string symbol, const int direction)',
            'bool ExecuteTradeInternal(ENUM_ORDER_TYPE orderType, double lotSize, string comment = "")',
            'double CalculateSL(ENUM_ORDER_TYPE orderType, double maxLossUSD, double lotSize, double &out_sl_price)',
            'double CalculateLotSize(const string symbol)',
            'bool CalculateSLTP(const string symbol, const int direction, const double lot, const double entry_price, double &sl_price, double &tp_price)',
            'bool CheckGlobalRiskLimits()',
            'void ManageOpenPositions()',
            'bool IsPositionOpenForSymbol(const string symbol)',
            'int CountOpenTrades()',
            'bool InitializeIndicators(const string symbol)',
            'void ReleaseIndicators()',
            'void ShowPredictionArrow(const string symbol, const int direction)',
            'void ShowSignalArrow(int signal, string symbol = NULL)',
            'void CleanupOldArrows()',
            'void UpdateHUD()',
            'void CreateBoomDisplay()',
            'void UpdateBoomDisplay()',
            'void RemoveBoomDisplay()',
            'void SendCustomNotification(const string message)',
        ]
        
        for func in functions_to_fix:
            pattern = func + r'(?!\s*\{)'
            if re.search(pattern, content):
                content = re.sub(pattern, func + '\n{', content)
                corrections_applied += 1
                print(f"   Fonction corrigee: {func}")
        
        # 4. Supprimer les accolades en trop
        print("4. Suppression des accolades en trop...")
        
        # Supprimer les blocs d'accolades en trop
        content = re.sub(r'\{\{\{\{\{\{\s*\n\s*\n\s*\n\s*\n\s*\n\s*\}\s*\}\s*\}\s*\}\s*\}\s*\}', '', content)
        if '{{{{{{' in original_content and '{{{{{{' not in content:
            corrections_applied += 1
            print("   Accolades en trop supprimees")
        
        # 5. Corriger les chaînes multiligne dans StringFormat
        print("5. Correction des chaînes multiligne...")
        
        # Remplacer les sauts de ligne littéraux par \\n
        content = re.sub(r'StringFormat\(\s*"[^"]*\n[^"]*"', lambda m: m.group(0).replace('\n', '\\n'), content)
        
        # 6. Corriger les déclarations avec indentation incorrecte
        print("6. Correction de l'indentation...")
        
        # Retirer les espaces inutiles au début des lignes de déclarations globales
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if line.strip().startswith('string') and line.startswith(' '):
                lines[i] = line.lstrip()
                corrections_applied += 1
        
        content = '\n'.join(lines)
        
        # 7. Corriger les mots-clés collés
        print("7. Correction des mots-clés collés...")
        
        keyword_fixes = [
            ('returnfalse', 'return false'),
            ('returntrue', 'return true'),
            ('returnINIT_FAILED', 'return INIT_FAILED'),
            ('returnINIT_SUCCEEDED', 'return INIT_SUCCEEDED'),
            ('return0', 'return 0'),
            ('return1', 'return 1'),
            ('return-1', 'return -1'),
            ('elseif', 'else if'),
            ('elsedouble', 'else { double'),
        ]
        
        for old, new in keyword_fixes:
            if old in content:
                content = content.replace(old, new)
                corrections_applied += 1
                print(f"   Mot-cle corrige: {old} -> {new}")
        
        # Sauvegarder le fichier corrigé
        if content != original_content:
            with open('AngelOfSpike_Fixed.mq5', 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"\nFichier corrige avec {corrections_applied} corrections appliquees")
        else:
            print("\nAucune correction necessaire - le fichier est deja correct")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors de la correction: {e}")
        return False

if __name__ == "__main__":
    corriger_angelofspike_fixed()
