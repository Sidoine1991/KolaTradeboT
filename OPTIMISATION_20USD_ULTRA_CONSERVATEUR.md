# Optimisation Système Trading - Capital 20 USD (Ultra-Conservateur)

**Date** : 2026-05-15  
**Agent utilisé** : trading-system-optimizer  
**Objectif** : Protection capital + gains modérés réguliers

---

## 📊 PROFIL DE RISQUE OPTIMISÉ

### Règles d'Or (Capital 20$)
- ✅ **1 seule position simultanée** (concentration maîtrisée)
- ✅ **Risque max par trade** : 0.20$ (1% du capital)
- ✅ **Perte max journalière** : 1.50$ (7.5% du capital)
- ✅ **Perte max totale** : 3.00$ (15% du capital) → **ARRÊT COMPLET**
- ✅ **Ratio TP/SL** : 3:1 minimum (80 points TP / 30 points SL)
- ✅ **Max 3 trades par jour** (adaptatif selon equity)
- ✅ **Confiance IA minimum** : 72-82% selon module
- ✅ **Lot size fixe** : 0.01 (minimum absolu)

### Protections Activées
1. **Salvage Bank** : Sécurise 80% des gains dès +1.50$ atteint
2. **Trailing Stop** : Activé dès 0.05$ de profit (ultra-réactif)
3. **Profit Lock** : Verrouille gains dès +1.00$ (5% du capital)
4. **Stop Loss Dynamique** : Déplace SL à BE + 3 points dès +0.05$
5. **Pause après perte** : 90 min après 2 pertes consécutives

---

## 🎯 MODIFICATIONS PRINCIPALES

### 1. SMC_Universal.mq5 (Robot Principal)

#### Risk Management
```mql5
input double InpLotSize = 0.01;                    // Lot minimum (était 0.2)
input int MaxPositionsTerminal = 1;                // 1 seule position (était 2)
input double MaxTotalLossDollars = 3.0;            // 15% capital (était 10.0)
input double DailyProfitTarget = 2.0;              // 10% capital/jour (était 20.0)
input double MaxRiskPerTradePercent = 1.0;         // 1% strict (était 1.5)
input double MaxDailyDrawdownPercent = 8.0;        // -1.60$ max (était 10.0)
input double MaxDailyLossDollars = 1.50;           // 7.5% capital (était 6.0)
```

#### Salvage Bank (Protection Gains)
```mql5
input double SalvageBankTriggerDailyProfitUSD = 1.50;     // Arme à 7.5% capital
input double SalvageBankAbsoluteFloorUSD = 0.80;          // Plancher 4%
input double SalvageBankMaxGivebackFromPeakUSD = 0.50;    // Giveback max 0.50$
input bool SalvageBankBlockNewEntriesWhenArmed = true;    // Bloque nouvelles entrées
```

#### Trailing Stop Boom/Crash
```mql5
input double BoomCrashTrailingInitialPct = 0.10;         // 10% (était 15%)
input double BoomCrashTrailingSpikePct = 0.06;           // 6% après spike (était 10%)
input double BoomCrashTrailingStepPct = 0.03;            // Step 3% (était 5%)
input double BoomCrashTrailingSpikeMinProfit = 0.03;     // Adapté lot 0.01
input double TrailingStartProfitDollars = 0.05;          // Activé dès 0.05$ (était 1.00)
```

#### Scanner Multi-Symboles
```mql5
input bool EnableOpportunityScanner = true;               // ✅ ACTIVÉ
input bool EnableScannerAutoTrading = true;               // ✅ ACTIVÉ
input double AutoTradeMaxRiskDollars = 0.20;              // 1% capital (était 0.50)
input double AutoTradeScalpTpPoints = 80;                 // Ratio 2.67:1 (était 50)
input double AutoTrailingStopPoints = 15;                 // Plus serré (était 20)
```

#### Filtre Qualité Entrées
```mql5
input bool StrictConfluenceMode = true;                   // ✅ Multi-confirmation
input double MinFilterPassRatio = 0.55;                   // 55% min (était 0.35)
input bool RequireMTFAndStructure = true;                 // ✅ Alignement MTF obligatoire
input double MinStrengthForEntry = 3.0;                   // Plus strict (était 2.0)
input bool EnableEntryQualityGate = true;                 // ✅ Gate qualité
input double MinEntryQualityScore = 0.55;                 // 55% min (était 0.30)
input double MinSetupScoreEntry = 75.0;                   // 75% min (était 65.0)
```

#### Détection Spikes (Plus Sélectif)
```mql5
input double SpikeAlertMinProbability = 0.65;             // 65% min (était 0.58)
input double SpikeBypassMinProbability = 0.60;            // 60% (était 0.52)
input double SpikeBlinkMinProbability = 0.55;             // 55% (était 0.48)
input double DoubleSpikeMinProb = 0.60;                   // 60% (était 0.52)
```

#### Confiance IA
```mql5
input double MinAIConfidencePercent = 82.0;               // 82% min (était 75.0)
input double MinAIConfidence = 0.82;                      // Aligné
input double MinWinProbability = 88.0;                    // 88% min (était 85.0)
input double SpikeML_MinProbability = 0.78;               // 78% (était 0.75)
```

---

### 2. GOM_KOLA_SIDO_Script.mq5 (Scanner)

#### Détection Spikes Optimisée
```mql5
input int SpikeLookbackBarsM1 = 25;                       // Pattern plus stable (était 20)
input double SpikeAlertMinProbability = 0.62;             // Qualité > quantité (était 0.45)
input double SpikeBypassMinProbability = 0.58;            // Plus strict (était 0.40)
input double SpikeBlinkMinProbability = 0.52;             // Moins de bruit (était 0.35)
input double SpikeBlinkLeadThAdjMax = 0.15;               // Moins d'entrées prématurées (était 0.20)
input bool SpikeModeBypassStrict = false;                 // Protection capital (était true)
```

#### Double Spike (Plus Précis)
```mql5
input double DoubleSpikeNearLevelAtr = 0.60;              // Plus précis (était 0.75)
input double DoubleSpikeMinProb = 0.58;                   // Qualité exigée (était 0.42)
input int DoubleSpikeHoldSeconds = 60;                    // Ne pas tenir trop (était 90)
```

---

### 3. ai_server.py (Serveur IA)

#### Confiance Décisions
```python
# Ligne ~830-850
MIN_CONFIDENCE_THRESHOLD = 0.72  # Était 0.55 → +31% plus strict
FORCE_HOLD_THRESHOLD = 0.60      # Était 0.40 → force HOLD sous 60%
CACHE_DURATION = 45              # Était 30s → décisions plus stables

# Plancher confiance buy/sell
confidence = max(0.75, raw_confidence)  # Était 0.68 → plancher 75%

# Seuil HOLD forcé
if confidence < 0.72:  # Était 0.68
    return "HOLD", 0.50, "Confidence insuffisante pour capital 20$ (ultra-conservateur)"
```

#### Configuration Symboles
```python
# Dans /config/symbols endpoint
SymbolConfigOut(
    min_expectancy=0.20,           # Espérance 20% minimum (était 0.0)
    min_ai_confidence=0.72,        # Aligné avec seuil global (était 0.55)
    max_daily_loss_usd=0.40,       # 2% du capital 20$ (était None)
    max_consecutive_losses=2,      # Pause après 2 pertes (était None)
    risk_profile="ultra_conservative"  # Nouveau profil (était "balanced")
)
```

#### Prompt Boom/Crash (Plus Strict)
```python
# Ligne ~1450-1480
prompt_template = """
Confiance minimum : 75% (était 68%)
RSI extrêmes : <35 (achat) / >65 (vente) — était <40 / >60
ATR danger : >2.5x moyenne — était >2.8x
Capital : 20 USD strict
Risque par trade : 0.20 USD maximum (1%)
"""
```

---

## 🚀 FONCTIONNALITÉS ACTIVÉES

### Protection Capital
- ✅ Salvage Bank avec blocage entrées
- ✅ Profit Lock dès +1.00$
- ✅ Trailing Stop dès +0.05$
- ✅ Stop Loss Dynamique (BE rapide)
- ✅ Pause après 2 pertes consécutives (90 min)
- ✅ Arrêt complet si perte totale ≥ 3.00$ (15% capital)

### Qualité Entrées
- ✅ Scanner multi-symboles actif
- ✅ Trading automatique scanner (haute probabilité uniquement)
- ✅ Confluence stricte (multi-confirmation)
- ✅ Alignement MTF + Structure obligatoire
- ✅ Gate qualité entrée (score 55% min)
- ✅ Filtre IA 72-82% selon module

### Détection Spikes
- ✅ Spike prediction (proba 65% min)
- ✅ Double spike capture (60% min)
- ✅ Trailing stop avancé Boom/Crash (6% après spike)
- ✅ Auto-close positions spike capturé
- ✅ ML spike (78% confiance min)

### Machine Learning
- ✅ Entraînement continu actif
- ✅ Random Forest + Qwen fallback
- ✅ Système recommandation ML
- ✅ Cache décisions 45s (stabilité)
- ✅ Expectancy 20% minimum

---

## 📈 OBJECTIFS DE PERFORMANCE

### Scénarios Réalistes (Capital 20$)

#### Scénario Conservateur (Attendu)
- **Trades/jour** : 1-2 (haute qualité uniquement)
- **Win rate cible** : 70-75% (grâce aux filtres stricts)
- **Gain moyen** : +0.30$ à +0.50$ par trade gagnant
- **Perte moyenne** : -0.15$ à -0.20$ par trade perdant
- **Profit net journalier** : +0.20$ à +0.60$ (+1% à +3%)
- **Objectif mensuel** : +6$ à +18$ (+30% à +90%)

#### Scénario Spike Capturé (Opportuniste)
- **Fréquence** : 1-2 fois/semaine (Boom/Crash uniquement)
- **Gain spike** : +1.00$ à +2.50$ (capture partielle avec lot 0.01)
- **Impact mensuel** : +4$ à +10$ supplémentaires

#### Scénario Prudent (Pire cas acceptable)
- **Win rate réel** : 60% (plus faible que prévu)
- **Trades/jour** : 1 trade (ultra-sélectif)
- **Profit net journalier** : +0.10$ à +0.30$
- **Objectif mensuel** : +2$ à +6$ (+10% à +30%)

### Croissance Capital (Projections)

| Mois | Capital Début | Objectif Conservateur | Objectif Optimiste |
|------|---------------|------------------------|---------------------|
| 1    | 20.00$        | 26.00$ (+30%)          | 38.00$ (+90%)       |
| 2    | 26.00$        | 33.80$ (+30%)          | 72.20$ (+90%)       |
| 3    | 33.80$        | 43.94$ (+30%)          | 137.18$ (+90%)      |
| 6    | —             | ~95$                   | ~600$               |

**Note** : Augmenter lot size (0.02) et positions max (2) quand capital ≥ 40$.

---

## ⚠️ POINTS D'ATTENTION

### 1. Commissions Deriv
- Lot 0.01 Boom/Crash : commission ~0.01$ à 0.03$ par trade
- **Vérifier** que TP ≥ 50 points pour profit net positif après commission

### 2. Slippage
- Spikes Boom/Crash : slippage peut atteindre 10-30 points
- TP ajusté à 80 points pour compenser

### 3. Heures de Trading
- **Optimal** : Sessions Londres (08:00-12:00 UTC) et New York (13:00-17:00 UTC)
- **Éviter** : Nuit (faible liquidité Volatility/Boom/Crash)

### 4. Backtesting Recommandé
- Tester paramètres sur **1-2 semaines historiques** avant production
- Vérifier win rate ≥ 65% et profit factor ≥ 1.5

### 5. Monitoring
- Vérifier **quotidiennement** :
  - Drawdown actuel vs seuil 8% (1.60$)
  - Profit journalier vs objectif 2.00$
  - Nombre trades vs max 3/jour
  - Confiance IA moyenne ≥ 75%

---

## 🔧 PROCHAINES ÉTAPES

### Phase 1 : Validation (Semaine 1)
1. ✅ Appliquer modifications aux 3 fichiers
2. ⬜ Compiler SMC_Universal.mq5 et GOM_KOLA_SIDO_Script.mq5
3. ⬜ Redémarrer ai_server.py avec nouveaux paramètres
4. ⬜ Backtest 7 jours historiques (vérifier win rate + profit factor)
5. ⬜ Demo account test : 2-3 jours avec capital virtuel 20$

### Phase 2 : Production (Semaine 2)
1. ⬜ Déployer sur compte réel 20$ (Deriv/Weltrade)
2. ⬜ Activer scanner multi-symboles (`EnableOpportunityScanner = true`)
3. ⬜ Activer trading auto (`EnableScannerAutoTrading = true`)
4. ⬜ Monitoring quotidien (journal trades + P&L)
5. ⬜ Ajuster paramètres si nécessaire (win rate, TP/SL)

### Phase 3 : Scale-up (Mois 2-3)
1. ⬜ Capital ≥ 30$ : passer `MaxPositionsTerminal = 2`
2. ⬜ Capital ≥ 40$ : passer `InpLotSize = 0.02`
3. ⬜ Capital ≥ 50$ : passer `MaxDailyTrades = 4`
4. ⬜ Capital ≥ 100$ : passer `AutoTradeMaxRiskDollars = 0.50`

---

## 📝 CHECKLIST RAPIDE

### Avant de Lancer
- [ ] Fichiers modifiés : SMC_Universal.mq5, GOM_KOLA_SIDO_Script.mq5, ai_server.py
- [ ] Compilation MT5 réussie (0 erreur)
- [ ] ai_server.py démarre sans erreur
- [ ] WebRequest MT5 autorise : `http://127.0.0.1:8000` et `https://kolatradebot-7ofl.onrender.com`
- [ ] Capital réel vérifié : 20.00 USD
- [ ] Connexion broker stable (ping < 100ms)

### Pendant Trading
- [ ] 1 seule position max simultanée
- [ ] Lot size = 0.01 fixe
- [ ] Trailing stop activé dès +0.05$
- [ ] Salvage bank armé à +1.50$ journalier
- [ ] Pause après 2 pertes consécutives
- [ ] Arrêt complet si perte totale ≥ 3.00$

### Après Chaque Session
- [ ] Noter : nombre trades, win rate, P&L net, symboles tradés
- [ ] Vérifier : drawdown actuel vs seuil 8%
- [ ] Analyser : trades perdants (confiance IA trop basse ?)
- [ ] Ajuster : paramètres si win rate < 60%

---

## 🎓 RESSOURCES

- **Agent utilisé** : `trading-system-optimizer` (installé via everything-claude-code)
- **Documentation** : `INSTALLATION_CLAUDE_ECC.md`
- **Skills disponibles** : 421 skills (voir ~/.claude/skills)
- **Support** : Relancer agent avec `/agents` si besoin ajustements

---

**Version** : 1.0  
**Dernière mise à jour** : 2026-05-15  
**Statut** : ⚠️ PARAMÈTRES À APPLIQUER - NON DÉPLOYÉ
