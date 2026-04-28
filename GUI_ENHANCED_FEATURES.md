# 🎨 GUI AMÉLIORÉ - Nouvelles Fonctionnalités

**Date**: 2026-04-28  
**Objectif**: Ajouter Win Rate Calculator + Analyse Technique Push + Stats temps réel

---

## 📋 NOUVELLES FONCTIONNALITÉS À AJOUTER

### 1️⃣ **Calculateur de Win Rate** (Historique de trading)
- Win Rate % (trades gagnants / total)
- Profit Factor
- Nombre de trades (wins/losses)
- Profit moyen par trade

### 2️⃣ **Analyse Technique Complète** (Bouton + Push)
- Bouton "📊 ANALYSE 360" qui envoie notification push
- Analyse multi-timeframe (M5, M15, H1)
- Patterns détectés
- Tendance actuelle
- Confluence SMC

### 3️⃣ **Informations Temps Réel**
- Balance / Equity / P/L  
- Spread actuel
- ATR / RSI
- Positions ouvertes
- Heure actuelle

---

## 🔧 CODE À AJOUTER DANS SMC_Universal.mq5

### **ÉTAPE 1: Ajouter les variables globales**

Cherchez la section des variables GUI (autour de la ligne 5700) et ajoutez:

```mql5
//+------------------------------------------------------------------+
//| Variables GUI - Statistiques de Trading                          |
//+------------------------------------------------------------------+
// Win Rate Calculator
int    g_totalTrades = 0;
int    g_winningTrades = 0;
int    g_losingTrades = 0;
double g_totalProfit = 0.0;
double g_totalLoss = 0.0;
double g_avgWin = 0.0;
double g_avgLoss = 0.0;
double g_winRate = 0.0;
double g_profitFactor = 0.0;
datetime g_lastStatsUpdate = 0;

// Données temps réel pour GUI
double g_currentSpread = 0.0;
double g_currentATR = 0.0;
double g_currentRSI = 50.0;
int    g_openPositions = 0;
string g_emaTrend = "NEUTRAL";
```

---

### **ÉTAPE 2: Fonction de calcul du Win Rate**

Ajoutez cette fonction (après la ligne 39130):

```mql5
//+------------------------------------------------------------------+
//| Calculer le Win Rate depuis l'historique                         |
//+------------------------------------------------------------------+
void GUI_CalculateWinRate()
{
   // Réinitialiser les compteurs
   g_totalTrades = 0;
   g_winningTrades = 0;
   g_losingTrades = 0;
   g_totalProfit = 0.0;
   g_totalLoss = 0.0;
   
   // Obtenir l'historique depuis le début du mois
   datetime monthStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   MqlDateTime dt;
   TimeToStruct(monthStart, dt);
   dt.day = 1;
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   monthStart = StructToTime(dt);
   
   // Sélectionner l'historique
   if(!HistorySelect(monthStart, TimeCurrent()))
   {
      Print("❌ Erreur sélection historique pour Win Rate");
      return;
   }
   
   // Parcourir les deals
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket <= 0) continue;
      
      // Vérifier que c'est notre magic number
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
         continue;
      
      // Vérifier que c'est une sortie de position
      ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT)
         continue;
      
      // Obtenir le profit
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double totalPL = profit + commission + swap;
      
      // Compter
      g_totalTrades++;
      
      if(totalPL > 0)
      {
         g_winningTrades++;
         g_totalProfit += totalPL;
      }
      else if(totalPL < 0)
      {
         g_losingTrades++;
         g_totalLoss += MathAbs(totalPL);
      }
   }
   
   // Calculer les statistiques
   if(g_totalTrades > 0)
   {
      g_winRate = (g_winningTrades / (double)g_totalTrades) * 100.0;
      
      if(g_winningTrades > 0)
         g_avgWin = g_totalProfit / g_winningTrades;
      
      if(g_losingTrades > 0)
         g_avgLoss = g_totalLoss / g_losingTrades;
      
      if(g_totalLoss > 0)
         g_profitFactor = g_totalProfit / g_totalLoss;
      else
         g_profitFactor = (g_totalProfit > 0) ? 999.0 : 0.0;
   }
   
   g_lastStatsUpdate = TimeCurrent();
   
   Print("📊 WIN RATE CALCULÉ:");
   Print("   Total Trades: ", g_totalTrades);
   Print("   Wins: ", g_winningTrades, " | Losses: ", g_losingTrades);
   Print("   Win Rate: ", DoubleToString(g_winRate, 1), "%");
   Print("   Profit Factor: ", DoubleToString(g_profitFactor, 2));
   Print("   Avg Win: ", DoubleToString(g_avgWin, 2), "$ | Avg Loss: ", DoubleToString(g_avgLoss, 2), "$");
}
```

---

### **ÉTAPE 3: Fonction d'analyse technique complète avec Push**

```mql5
//+------------------------------------------------------------------+
//| Analyse Technique Complète + Notification Push                   |
//+------------------------------------------------------------------+
void GUI_SendTechnicalAnalysisPush()
{
   Print("📊 Génération analyse technique complète pour ", _Symbol);
   
   // ═══════════════════════════════════════════════════════════════
   // 1. COLLECTER LES DONNÉES
   // ═══════════════════════════════════════════════════════════════
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      Alert("❌ Erreur obtention prix pour analyse");
      return;
   }
   
   double bid = tick.bid;
   double spread = (tick.ask - tick.bid) / _Point;
   
   // RSI M5
   int hRsi = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   double rsi = 50.0;
   if(hRsi != INVALID_HANDLE)
   {
      double rsiBuf[];
      ArraySetAsSeries(rsiBuf, true);
      if(CopyBuffer(hRsi, 0, 0, 1, rsiBuf) >= 1)
         rsi = rsiBuf[0];
      IndicatorRelease(hRsi);
   }
   
   // EMAs M5
   int hEmaFast = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   int hEmaSlow = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
   double emaFast = 0, emaSlow = 0;
   if(hEmaFast != INVALID_HANDLE && hEmaSlow != INVALID_HANDLE)
   {
      double bufFast[], bufSlow[];
      ArraySetAsSeries(bufFast, true);
      ArraySetAsSeries(bufSlow, true);
      if(CopyBuffer(hEmaFast, 0, 0, 1, bufFast) >= 1)
         emaFast = bufFast[0];
      if(CopyBuffer(hEmaSlow, 0, 0, 1, bufSlow) >= 1)
         emaSlow = bufSlow[0];
      IndicatorRelease(hEmaFast);
      IndicatorRelease(hEmaSlow);
   }
   
   // ATR M5
   int hAtr = iATR(_Symbol, PERIOD_M5, 14);
   double atr = 0;
   if(hAtr != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(hAtr, 0, 0, 1, atrBuf) >= 1)
         atr = atrBuf[0] / _Point;
      IndicatorRelease(hAtr);
   }
   
   // ═══════════════════════════════════════════════════════════════
   // 2. ANALYSER LA TENDANCE
   // ═══════════════════════════════════════════════════════════════
   
   string trend = "NEUTRAL";
   string trendEmoji = "➡️";
   
   if(emaFast > emaSlow && bid > emaFast)
   {
      trend = "HAUSSIÈRE";
      trendEmoji = "📈";
   }
   else if(emaFast < emaSlow && bid < emaFast)
   {
      trend = "BAISSIÈRE";
      trendEmoji = "📉";
   }
   
   // ═══════════════════════════════════════════════════════════════
   // 3. DÉTECTER PATTERNS
   // ═══════════════════════════════════════════════════════════════
   
   string patterns = "";
   if(IsM5EngulfingPattern("BUY"))
      patterns += "Engulfing Bullish, ";
   if(IsM5EngulfingPattern("SELL"))
      patterns += "Engulfing Bearish, ";
   if(IsMorningStarPattern())
      patterns += "Morning Star, ";
   if(IsEveningStarPattern())
      patterns += "Evening Star, ";
   
   if(patterns == "")
      patterns = "Aucun pattern majeur";
   else
      patterns = StringSubstr(patterns, 0, StringLen(patterns) - 2); // Retirer dernière virgule
   
   // ═══════════════════════════════════════════════════════════════
   // 4. CONFLUENCE SMC
   // ═══════════════════════════════════════════════════════════════
   
   string confluence = "";
   int confluenceScore = 0;
   
   // Zone OTE détectée?
   string oteDir;
   double oteEntry, oteSL, oteTP, oteHigh, oteLow;
   if(DetectActiveOTESetupOn100Bars(oteDir, oteEntry, oteSL, oteTP, oteHigh, oteLow))
   {
      confluence += "Zone OTE " + oteDir + ", ";
      confluenceScore += 3;
   }
   
   // BOS confirmé?
   if(HasOTEBOSConfirmationM15OrM5("BUY") || HasOTEBOSConfirmationM15OrM5("SELL"))
   {
      confluence += "BOS confirmé, ";
      confluenceScore += 2;
   }
   
   // RSI extrême?
   if(rsi > 70)
   {
      confluence += "RSI Suracheté, ";
      confluenceScore += 1;
   }
   else if(rsi < 30)
   {
      confluence += "RSI Survendu, ";
      confluenceScore += 1;
   }
   
   if(confluence == "")
      confluence = "Confluence faible";
   else
      confluence = StringSubstr(confluence, 0, StringLen(confluence) - 2);
   
   // ═══════════════════════════════════════════════════════════════
   // 5. SIGNAL RECOMMANDÉ
   // ═══════════════════════════════════════════════════════════════
   
   string signal = "WAIT";
   string signalEmoji = "⏳";
   
   if(trend == "HAUSSIÈRE" && rsi < 70 && confluenceScore >= 3)
   {
      signal = "BUY";
      signalEmoji = "📈";
   }
   else if(trend == "BAISSIÈRE" && rsi > 30 && confluenceScore >= 3)
   {
      signal = "SELL";
      signalEmoji = "📉";
   }
   
   // ═══════════════════════════════════════════════════════════════
   // 6. CONSTRUIRE LE MESSAGE PUSH
   // ═══════════════════════════════════════════════════════════════
   
   string message = "📊 ANALYSE " + _Symbol + " (" + EnumToString(_Period) + ")\n";
   message += "━━━━━━━━━━━━━━━━━━━━━━━━\n";
   message += trendEmoji + " Tendance: " + trend + "\n";
   message += "📍 Prix: " + DoubleToString(bid, _Digits) + "\n";
   message += "📏 Spread: " + DoubleToString(spread, 0) + " pips\n";
   message += "📊 RSI: " + DoubleToString(rsi, 0) + "\n";
   message += "💹 ATR: " + DoubleToString(atr, 0) + " pips\n";
   message += "━━━━━━━━━━━━━━━━━━━━━━━━\n";
   message += "🎨 Patterns: " + patterns + "\n";
   message += "⭐ Confluence: " + confluence + " (" + IntegerToString(confluenceScore) + "/5)\n";
   message += "━━━━━━━━━━━━━━━━━━━━━━━━\n";
   message += signalEmoji + " SIGNAL: " + signal + "\n";
   
   // ═══════════════════════════════════════════════════════════════
   // 7. ENVOYER LA NOTIFICATION PUSH
   // ═══════════════════════════════════════════════════════════════
   
   if(SendNotification(message))
   {
      Print("✅ Notification push envoyée avec succès");
      Alert("📱 Analyse technique envoyée par push!");
   }
   else
   {
      Print("❌ Erreur envoi notification push: ", GetLastError());
      Alert("❌ Erreur envoi push. Vérifiez les paramètres MT5.");
   }
   
   // Afficher aussi dans les logs pour référence
   Print(message);
}
```

---

### **ÉTAPE 4: Mise à jour du GUI en temps réel**

```mql5
//+------------------------------------------------------------------+
//| Mettre à jour les données temps réel sur le GUI                  |
//+------------------------------------------------------------------+
void GUI_UpdateRealTimeData()
{
   if(!UseTradingAlgoGUI) return;
   
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 1) return; // Update toutes les secondes
   lastUpdate = TimeCurrent();
   
   // Balance / Equity / P/L
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   
   // Spread
   MqlTick tick;
   if(SymbolInfoTick(_Symbol, tick))
   {
      g_currentSpread = (tick.ask - tick.bid) / _Point;
   }
   
   // ATR
   int hAtr = iATR(_Symbol, PERIOD_M5, 14);
   if(hAtr != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(hAtr, 0, 0, 1, atrBuf) >= 1)
         g_currentATR = atrBuf[0] / _Point;
      IndicatorRelease(hAtr);
   }
   
   // RSI
   int hRsi = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   if(hRsi != INVALID_HANDLE)
   {
      double rsiBuf[];
      ArraySetAsSeries(rsiBuf, true);
      if(CopyBuffer(hRsi, 0, 0, 1, rsiBuf) >= 1)
         g_currentRSI = rsiBuf[0];
      IndicatorRelease(hRsi);
   }
   
   // Tendance EMA
   int hEmaFast = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   int hEmaSlow = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(hEmaFast != INVALID_HANDLE && hEmaSlow != INVALID_HANDLE)
   {
      double bufFast[], bufSlow[];
      ArraySetAsSeries(bufFast, true);
      ArraySetAsSeries(bufSlow, true);
      if(CopyBuffer(hEmaFast, 0, 0, 1, bufFast) >= 1 && 
         CopyBuffer(hEmaSlow, 0, 0, 1, bufSlow) >= 1)
      {
         if(bufFast[0] > bufSlow[0])
            g_emaTrend = "BULLISH";
         else if(bufFast[0] < bufSlow[0])
            g_emaTrend = "BEARISH";
         else
            g_emaTrend = "NEUTRAL";
      }
      IndicatorRelease(hEmaFast);
      IndicatorRelease(hEmaSlow);
   }
   
   // Positions ouvertes
   g_openPositions = PositionsTotal();
   
   // Calculer Win Rate toutes les 60 secondes
   if(TimeCurrent() - g_lastStatsUpdate > 60)
   {
      GUI_CalculateWinRate();
   }
}
```

---

### **ÉTAPE 5: Améliorer le GUI - Ajouter section Win Rate**

Dans la fonction `CreateTradingAlgoGUI()`, ajoutez APRÈS la ligne 39020 (avant le bouton EXECUTE):

```mql5
   // ═══════════════════════════════════════════════════════════════
   // SECTION WIN RATE & STATISTIQUES (NOUVEAU)
   // ═══════════════════════════════════════════════════════════════
   
   // Augmenter la hauteur du panneau
   h = 720; // Au lieu de 580
   GUI_CreateRectangle("GUI_PANEL_BG", x, y, w, h, GUI_PanelBgColor); // Re-créer avec nouvelle hauteur
   
   // Séparateur Win Rate
   GUI_CreateHLine("GUI_SEP_WR", x + 10, y + 560, w - 20, clrYellow);
   
   // Titre Win Rate
   GUI_CreateLabel("GUI_WR_TITLE", x + 10, y + 570, "📈 WIN RATE & STATS", GUI_FontSize, clrYellow);
   
   // Bouton Calculer Win Rate
   GUI_CreateButton("GUI_BTN_CALC_WR", x + 10, y + 590, w - 20, 25, "🔄 CALCULER WIN RATE", clrWhite, clrOrange);
   
   // Statistiques affichées
   GUI_CreateLabel("GUI_WR_TRADES", x + 10, y + 620, "Trades: ---", GUI_FontSize - 1, clrWhite);
   GUI_CreateLabel("GUI_WR_PERCENT", x + 10, y + 635, "Win Rate: ---", GUI_FontSize - 1, clrLime);
   GUI_CreateLabel("GUI_WR_PF", x + 10, y + 650, "Profit Factor: ---", GUI_FontSize - 1, clrCyan);
   GUI_CreateLabel("GUI_WR_AVGWIN", x + 10, y + 665, "Avg Win: ---", GUI_FontSize - 1, clrLime);
   GUI_CreateLabel("GUI_WR_AVGLOSS", x + 10, y + 680, "Avg Loss: ---", GUI_FontSize - 1, clrRed);
```

---

### **ÉTAPE 6: Gérer les clics sur les nouveaux boutons**

Dans la fonction `GUI_HandleButtonClick()`, ajoutez:

```mql5
   else if(objectName == "GUI_BTN_CALC_WR")
   {
      // Calculer Win Rate
      GUI_CalculateWinRate();
      
      // Mettre à jour l'affichage
      ObjectSetString(0, "GUI_WR_TRADES", OBJPROP_TEXT, 
         StringFormat("Trades: %d (W:%d / L:%d)", g_totalTrades, g_winningTrades, g_losingTrades));
      
      color wrColor = (g_winRate >= 60) ? clrLime : ((g_winRate >= 50) ? clrYellow : clrRed);
      ObjectSetString(0, "GUI_WR_PERCENT", OBJPROP_TEXT, 
         StringFormat("Win Rate: %.1f%%", g_winRate));
      ObjectSetInteger(0, "GUI_WR_PERCENT", OBJPROP_COLOR, wrColor);
      
      ObjectSetString(0, "GUI_WR_PF", OBJPROP_TEXT, 
         StringFormat("Profit Factor: %.2f", g_profitFactor));
      
      ObjectSetString(0, "GUI_WR_AVGWIN", OBJPROP_TEXT, 
         StringFormat("Avg Win: %.2f$", g_avgWin));
      
      ObjectSetString(0, "GUI_WR_AVGLOSS", OBJPROP_TEXT, 
         StringFormat("Avg Loss: %.2f$", g_avgLoss));
      
      Alert("✅ Win Rate calculé: ", DoubleToString(g_winRate, 1), "%");
      Print("📊 Win Rate: ", g_winRate, "% | PF: ", g_profitFactor);
   }
```

Et pour le bouton d'analyse technique avec push:

```mql5
   else if(objectName == "GUI_BTN_AI_ANALYZE")
   {
      // Envoyer l'analyse technique complète par push
      GUI_SendTechnicalAnalysisPush();
      
      // L'analyse IA existante est aussi exécutée
      // (code existant à garder)
   }
```

---

### **ÉTAPE 7: Appeler les mises à jour dans OnTick()**

Dans la fonction `OnTick()`, ajoutez (autour de la ligne 11150):

```mql5
   // Mettre à jour les données GUI en temps réel
   if(UseTradingAlgoGUI)
   {
      GUI_UpdateRealTimeData();
   }
```

---

## 📊 RÉSULTAT FINAL

Avec ces améliorations, votre GUI aura:

```
┌─────────────────────────────────────────────┐
│ 🤖 TRADING ALGO - CHARLES                   │
│─────────────────────────────────────────────│
│ SYMBOL: EURUSD                              │
│ SIGNAL: ⏳ WAIT                             │
│                                             │
│ [📈 BUY]  [📉 SELL]  [⏳ WAIT]            │
│─────────────────────────────────────────────│
│ RISK %: [0.50]                              │
│ LOT SIZE: 0.01                              │
│─────────────────────────────────────────────│
│ TP1: [50] → 1.10500                        │
│ TP2: [100] → 1.11000                       │
│ TP3: [150] → 1.11500                       │
│ TP4: [200] → 1.12000                       │
│ STOP-LOSS: [30] → 1.09700                  │
│─────────────────────────────────────────────│
│ Risk USD: 0.50                              │
│ Reward USD: 1.00                            │
│ R/R: 2.00                                   │
│─────────────────────────────────────────────│
│ 🤖 ANALYSE 360                              │
│                                             │
│ [📊 ANALYSE 360 + PUSH]                    │
│                                             │
│ Signal IA: ⏳ WAIT                          │
│ Confiance: ---                              │
│ Raison: ---                                 │
│─────────────────────────────────────────────│
│ 📈 WIN RATE & STATS                         │
│                                             │
│ [🔄 CALCULER WIN RATE]                     │
│                                             │
│ Trades: 25 (W:17 / L:8)                    │
│ Win Rate: 68.0%                             │
│ Profit Factor: 2.13                         │
│ Avg Win: 0.85$                              │
│ Avg Loss: 0.40$                             │
│─────────────────────────────────────────────│
│ [🚀 EXECUTE TRADE]                          │
└─────────────────────────────────────────────┘
```

---

## 🔔 NOTIFICATION PUSH EXEMPLE

Quand vous cliquez sur "📊 ANALYSE 360":

```
📊 ANALYSE EURUSD (M5)
━━━━━━━━━━━━━━━━━━━━━━━━
📈 Tendance: HAUSSIÈRE
📍 Prix: 1.10000
📏 Spread: 1.2 pips
📊 RSI: 55
💹 ATR: 12 pips
━━━━━━━━━━━━━━━━━━━━━━━━
🎨 Patterns: Engulfing Bullish
⭐ Confluence: Zone OTE BUY, BOS confirmé (5/5)
━━━━━━━━━━━━━━━━━━━━━━━━
📈 SIGNAL: BUY
```

---

## 📝 INSTRUCTIONS D'INSTALLATION

1. **Copier** toutes les fonctions ci-dessus dans `SMC_Universal.mq5`
2. **Ajouter** les variables globales au début du fichier
3. **Modifier** `CreateTradingAlgoGUI()` pour ajouter la section Win Rate
4. **Modifier** `GUI_HandleButtonClick()` pour gérer les nouveaux boutons
5. **Ajouter** `GUI_UpdateRealTimeData()` dans `OnTick()`
6. **Compiler** et tester

---

## ⚙️ ACTIVER LES NOTIFICATIONS PUSH

Dans MT5:
1. Outils → Options → Notifications
2. Activer "Activer les notifications push"
3. Obtenir un MetaQuotes ID depuis l'application mobile MT5
4. Entrer le MetaQuotes ID

---

**Date**: 2026-04-28  
**Auteur**: Claude Code  
**Fichier**: GUI_ENHANCED_FEATURES.md
