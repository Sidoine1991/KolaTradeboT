/*
   =============================================================================
   SNIPER_MODE_v1.37_VERIFICATION.py
   =============================================================================
   
   Script Python pour vérifier que toutes les corrections v1.37 ont été
   appliquées au fichier SMC_Universal.mq5
   
   Utilisation:
   $ python SNIPER_MODE_v1.37_VERIFICATION.py d:\\Dev\\TradBOT\\mt5\\SMC_Universal.mq5
   
   Résultat:
   ✅ ou ❌ pour chaque correction + rapport détaillé
   
   =============================================================================
*/

import re
import sys
from pathlib import Path

class SMCVerifier:
    def __init__(self, filepath):
        self.filepath = Path(filepath)
        self.content = self.filepath.read_text(encoding='utf-8', errors='ignore')
        self.results = {}
    
    def check_correction_1(self):
        """✅ Correction 1: CalculateLotSize() - Cap $3 MAX"""
        patterns = [
            r'double maxLossUSD = SMC_HardMaxLossUSD\(\);',
            r'double estLoss = \(slPoints \* pipVal\) \* lotSize;',
            r'if\(estLoss > maxLossUSD \* 1\.05\)',
            r'LOT CAPPED TO',
        ]
        
        found_all = all(re.search(p, self.content, re.IGNORECASE) for p in patterns)
        
        if found_all:
            self.results['Correction 1: CalculateLotSize Cap'] = {
                'status': '✅ APPLIQUÉE',
                'lines': self._find_line('double maxLossUSD = SMC_HardMaxLossUSD'),
                'description': 'Cap $3 MAX sur CalculateLotSize()',
            }
            return True
        else:
            self.results['Correction 1: CalculateLotSize Cap'] = {
                'status': '❌ MANQUANTE',
                'lines': -1,
                'description': 'Cap $3 MAX non trouvé',
            }
            return False
    
    def check_correction_2(self):
        """✅ Correction 2: NormalizeVolumeForSymbol() - Cap $3"""
        patterns = [
            r'// SNIPER: V[éé]rifier que le lot ne violera pas',
            r'potentialLoss > maxLossUSD \* 1\.05',
            r'NormalizeVolumeForSymbol.*capped',
        ]
        
        found_some = sum(1 for p in patterns if re.search(p, self.content, re.IGNORECASE)) >= 2
        
        if found_some:
            self.results['Correction 2: NormalizeVolumeForSymbol Cap'] = {
                'status': '✅ APPLIQUÉE',
                'lines': self._find_line('NormalizeVolumeForSymbol'),
                'description': 'Double validation du cap $ pour normalisation volume',
            }
            return True
        else:
            self.results['Correction 2: NormalizeVolumeForSymbol Cap'] = {
                'status': '❌ MANQUANTE',
                'lines': -1,
                'description': 'Double cap non trouvé',
            }
            return False
    
    def check_correction_3(self):
        """⏳ Correction 3: ExecuteSpikeTrade() - SNIPER PRE-CHECKS"""
        patterns = [
            r'// 1\) SPREAD CHECK',
            r'spreadPips > maxSpreadPips',
            r'// 2\) CAPITAL DISPO CHECK',
            r'equity < maxLossUSD \* 5',
            r'// 4\) GOM VERDICT PRE-CHECK',
            r'// 5\) CORRECTION ZONE CHECK',
        ]
        
        found_all = all(re.search(p, self.content, re.IGNORECASE) for p in patterns)
        
        if found_all:
            self.results['Correction 3: ExecuteSpikeTrade Pre-Checks'] = {
                'status': '✅ APPLIQUÉE',
                'lines': self._find_line('void ExecuteSpikeTrade'),
                'description': 'Spread check + capital check + GOM check + correction check',
            }
            return True
        else:
            self.results['Correction 3: ExecuteSpikeTrade Pre-Checks'] = {
                'status': '⏳ MANQUANTE',
                'lines': self._find_line('void ExecuteSpikeTrade'),
                'description': 'Ajouter 5 vérifications sniper AVANT lot calculation',
            }
            return False
    
    def check_correction_4(self):
        """⏳ Correction 4: SMC_IsCorrectionZoneForDirection() - DÉTECTION STRICTE"""
        patterns = [
            r'// v1\.37: LOGIQUE STRICTE',
            r'if\(correctionSignals >= 3\)',
            r'// Cas 2:.*ATR.*compressé',
            r'< \(sumATR / 50\.0\) \* 0\.20',
        ]
        
        found_all = all(re.search(p, self.content, re.IGNORECASE) for p in patterns)
        
        if found_all:
            self.results['Correction 4: Correction Detection Stricte'] = {
                'status': '✅ APPLIQUÉE',
                'lines': self._find_line('bool SMC_IsCorrectionZoneForDirection'),
                'description': '3 signaux OU 2 forts = correction (pas 2 modérés)',
            }
            return True
        else:
            self.results['Correction 4: Correction Detection Stricte'] = {
                'status': '⏳ MANQUANTE',
                'lines': self._find_line('bool SMC_IsCorrectionZoneForDirection'),
                'description': 'Passer de "2+ signaux" à "3 signaux OU 2 forts"',
            }
            return False
    
    def check_correction_5(self):
        """⏳ Correction 5: SMC_GetChartPatternFromAI() - NOUVELLE FONCTION"""
        if 'SMC_GetChartPatternFromAI' in self.content:
            self.results['Correction 5: Chart Pattern AI Integration'] = {
                'status': '✅ APPLIQUÉE',
                'lines': self._find_line('bool SMC_GetChartPatternFromAI'),
                'description': 'Fonction d\'appel à ai_server.py /analyze/gemma',
            }
            return True
        else:
            self.results['Correction 5: Chart Pattern AI Integration'] = {
                'status': '⏳ MANQUANTE',
                'lines': -1,
                'description': 'Créer fonction SMC_GetChartPatternFromAI()',
            }
            return False
    
    def check_correction_6(self):
        """⏳ Correction 6: PositionCloseWithLog() - SNIPER HOLD"""
        patterns = [
            r'// v1\.37: SNIPER HOLD',
            r'spreadCost < spreadCost \* 1\.5',
            r'SNIPER-HOLD',
        ]
        
        found_some = sum(1 for p in patterns if re.search(p, self.content, re.IGNORECASE)) >= 2
        
        if found_some:
            self.results['Correction 6: SNIPER HOLD'] = {
                'status': '✅ APPLIQUÉE',
                'lines': self._find_line('SNIPER HOLD'),
                'description': 'Hold si perte < coût spread potentiel',
            }
            return True
        else:
            self.results['Correction 6: SNIPER HOLD'] = {
                'status': '⏳ MANQUANTE',
                'lines': self._find_line('bool PositionCloseWithLog'),
                'description': 'Ajouter logique hold sur micro-perte',
            }
            return False
    
    def check_correction_7(self):
        """⏳ Correction 7: CanPlaceOrderByGOM() - SÉLECTION SNIPER"""
        patterns = [
            r'// v1\.37: SNIPER SELECT',
            r'spread trop large pour sniper',
            r'SMC_GetChartPatternFromAI.*symbol.*patType',
        ]
        
        found_some = sum(1 for p in patterns if re.search(p, self.content, re.IGNORECASE)) >= 2
        
        if found_some:
            self.results['Correction 7: CanPlaceOrderByGOM Sniper Select'] = {
                'status': '✅ APPLIQUÉE',
                'lines': self._find_line('bool CanPlaceOrderByGOM'),
                'description': 'Spread check + capital check + pattern AI',
            }
            return True
        else:
            self.results['Correction 7: CanPlaceOrderByGOM Sniper Select'] = {
                'status': '⏳ MANQUANTE',
                'lines': self._find_line('bool CanPlaceOrderByGOM'),
                'description': 'Ajouter checks spread + capital + pattern AI',
            }
            return False
    
    def _find_line(self, pattern):
        """Trouver le numéro de ligne d'un pattern"""
        for i, line in enumerate(self.content.split('\n'), 1):
            if pattern.lower() in line.lower():
                return i
        return -1
    
    def verify_all(self):
        """Exécuter tous les checks"""
        print("\n" + "="*80)
        print("  SMC_UNIVERSAL.mq5 v1.37 SNIPER MODE - VERIFICATION")
        print("="*80 + "\n")
        
        print(f"📄 Fichier: {self.filepath}")
        print(f"📊 Taille: {len(self.content):,} caractères")
        print(f"📈 Lignes: {len(self.content.split(chr(10))):,}\n")
        
        results = []
        results.append(("Correction 1", self.check_correction_1()))
        results.append(("Correction 2", self.check_correction_2()))
        results.append(("Correction 3", self.check_correction_3()))
        results.append(("Correction 4", self.check_correction_4()))
        results.append(("Correction 5", self.check_correction_5()))
        results.append(("Correction 6", self.check_correction_6()))
        results.append(("Correction 7", self.check_correction_7()))
        
        applied = sum(1 for _, ok in results if ok)
        
        print("RÉSULTATS:")
        print("-" * 80)
        
        for name, (title, ok) in zip([f"#{i}" for i in range(1, 8)], 
                                      [(k, v) for k, v in self.results.items()]):
            r = self.results[title]
            status_icon = r['status'].split()[0]  # ✅, ❌, ou ⏳
            line_info = f"@ ligne {r['lines']}" if r['lines'] > 0 else ""
            
            print(f"{name} {status_icon:>3} | {title:<40} | {line_info}")
            print(f"       └─ {r['description']}")
        
        print("\n" + "-" * 80)
        print(f"✅ APPLIQUÉES:  {sum(1 for r in self.results.values() if '✅' in r['status'])}")
        print(f"⏳ À FAIRE:     {sum(1 for r in self.results.values() if '⏳' in r['status'])}")
        print(f"❌ MANQUANTES: {sum(1 for r in self.results.values() if '❌' in r['status'])}")
        
        print("\n" + "="*80)
        
        if applied >= 2:
            print("✅ STATUS: Au moins 2 corrections appliquées - compilation possible")
        else:
            print("❌ STATUS: Impossible de compiler - corrections critiques manquantes")
        
        print("="*80 + "\n")
        
        return applied >= 2
    
    def print_summary(self):
        """Afficher résumé pour integration continuous"""
        print("\n📋 CHECKLIST IMPLEMENTATION:\n")
        
        for i, (title, result) in enumerate(self.results.items(), 1):
            checkbox = "☑️" if "✅" in result['status'] else "☐"
            print(f"{checkbox} {i}. {title}")
            if "manquante" in result['description'].lower() or "à ajouter" in result['description'].lower():
                print(f"   └─ 👉 {result['description']}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python SNIPER_MODE_v1.37_VERIFICATION.py <filepath>")
        print("Example: python SNIPER_MODE_v1.37_VERIFICATION.py d:\\\\Dev\\\\TradBOT\\\\mt5\\\\SMC_Universal.mq5")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    if not Path(filepath).exists():
        print(f"❌ Fichier non trouvé: {filepath}")
        sys.exit(1)
    
    verifier = SMCVerifier(filepath)
    success = verifier.verify_all()
    verifier.print_summary()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
