//+------------------------------------------------------------------+
//|                                           AngelOfSpike_v5.2.mq5  |
//|                    Copyright 2025, Professional Trading EA       |
//|               Optimisé pour la chasse aux spikes ultra-précis    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Professional Trading EA"
#property link      "https://www.mql5.com"
#property version   "5.2"
#property description "AngelOfSpike v5.2 - Version finale, stable et optimisée pour la chasse aux spikes ultra-précis."

//--- Includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Object.mqh>

//+------------------------------------------------------------------+
//| Input Parameters - CONFIGURATION OPTIMISÉE POUR PROFIT MAX / PERTE MIN
//+------------------------------------------------------------------+

// === GESTION DES RISQUES & OBJECTIFS JOURNALIERS (LE PLUS IMPORTANT) ===
input group "=== GESTION DES RISQUES & OBJECTIFS ===";
input bool   InpEnableBasketClose      = true;     // [!!] Activer la clôture du panier (journée de trading)
input double InpBasketProfitCloseUSD   = 50.0;     // [GAINS] Objectif de profit pour arrêter la journée ($)
input double InpBasketLossCloseUSD     = 4.0;      // [PERTES] Perte maximale pour arrêter la journée ($)
input int    InpMaxSimultaneousTrades  = 2;        // [RISQUE] Nombre maximum de trades simultanés (2 MAX)
input double InpLotSize                = 0.2;      // [RISQUE] Taille de lot fixe (pour Boom/Crash)

// === STRATÉGIE PRINCIPALE : CHASSEUR DE SPIKES ULTRA-PRÉCIS ===
input group "=== STRATÉGIE ULTRA-PRÉCISE ===";
input bool   InpUltraPreciseMode         = true;     // [!!] Activer le mode Ultra-Précis
input double InpUltraHighConfidence      = 98.0;     // [FILTRE] Seuil de confiance minimum pour entrer (%)
input bool   InpImmediateCloseAfterSpike = true;     // [GAINS] Fermer immédiatement après capture du spike
input double InpQuickGainThreshold       = 0.50;     // [GAINS] Seuil de profit pour la fermeture rapide ($)
input bool   InpAntiCounterTrend         = true;     // [SÉCURITÉ] Interdire BUY sur Crash / SELL sur Boom

// === CONFIGURATION SL/TP (CALCUL UNIQUE À L'OUVERTURE) ===
input group "=== GESTION STOP LOSS & TAKE PROFIT ===";
input bool   InpUseOptimalSLTP       = true;     // [!!] Utiliser SL/TP optimaux basés sur l'ATR
input double InpSL_ATR_Multiplier    = 0.8;      // [SL] Multiplicateur ATR pour le Stop Loss (plus petit = plus serré)
input double InpTP_ATR_Multiplier    = 1.6;      // [TP] Multiplicateur ATR pour le Take Profit (assure un bon R:R)
input int    InpATR_Period           = 14;       // Période de l'ATR
input bool   InpForceSLTPOnEveryTrade= true;     // [SÉCURITÉ] Forcer un SL/TP sur chaque trade
input double InpMinRiskRewardRatio   = 1.5;      // [R:R] Ratio Risque/Récompense minimum

// === FILTRES DE CONFIRMATION (OPTIONNELS) ===
input group "=== FILTRES DE CONFIRMATION ===";
input bool   InpEnableSRDetection    = true;     // Activer la détection de Support/Résistance comme filtre
input bool   InpPrioritizeSREntries  = true;     // Privilégier les entrées proches des zones S/R
input int    InpSRMinTouches         = 2;        // Nombre de touches minimum pour valider une zone S/R
input double InpSRMinConfidence      = 70.0;     // Confiance minimum pour une zone S/R
input double InpSRZoneTolerance      = 0.0005;   // Tolérance zone S/R (en prix)
input int    InpSRLookbackBars       = 100;      // Barres à analyser pour S/R

// === FONCTIONNALITÉS DÉSACTIVÉES (POUR SIMPLIFIER ET SÉCURISER) ===
input group "=== FONCTIONNALITÉS AVANCÉES (DÉSACTIVÉES) ===";
input bool   _spacer_1_              = false;    // --- STRATÉGIES COMPLEXES (Conflits) ---
input bool   InpUseSmartTrading      = false;
input bool   InpEnableICT            = false;
input bool   InpUseAIForAnticipation = false;
input bool   InpUseExternalSignals   = false;
input bool   InpEnableGodMode        = false;
input bool   _spacer_2_              = false;    // --- MODIFICATION DE TRADES (Interdit par broker) ---
input bool   InpUseTrailingStopSmart = false;
input bool   InpUsePartialClose      = false;
input bool   InpUseAdaptiveSL        = false;
input bool   _spacer_3_              = false;    // --- VISUELS & AUTRES ---
input bool   InpShowVolumeProfile    = false;
input bool   InpShowLiquidityZones   = false;
input bool   InpEnableSpikeReentry   = false;
input double InpMaxRiskPerTrade      = 0.5; // Obsolète mais gardé pour éviter erreur compilation
input double InpMaxDailyLoss         = 10.0; // Obsolète, remplacé par BasketClose

// === PARAMÈTRES GÉNÉRAUX & VISUELS ===
input group "=== PARAMÈTRES GÉNÉRAUX ===";
input bool   InpEnableTrading        = true;     // Activer/Désactiver le trading
input int    InpMagicNumber          = 123456;   // Magic Number du robot
input bool   InpShowDashboard        = true;     // Afficher le panneau d'informations
input bool   InpSendNotifications    = true;     // Activer les notifications push
input bool   InpDrawSRZones          = true;     // Dessiner les zones S/R sur le graphique
input color  InpSRSupportColor       = clrLime;  // Couleur zones support
input color  InpSRResistanceColor    = clrRed;   // Couleur zones résistance


//+------------------------------------------------------------------+
//| Structures de Données                                            |
//+------------------------------------------------------------------+
struct SRZone
  {
   double          level;
   double          strength;
   int             touch_count;
   bool            is_support;
   bool            is_active;
   ENUM_TIMEFRAMES timeframe;
  };

//+------------------------------------------------------------------+
//| Variables Globales                                               |
//+------------------------------------------------------------------+
CTrade          g_trade;
SRZone          g_sr_zones[50];
int             g_sr_zone_count = 0;
datetime        g_last_sr_update = 0;
bool            g_dailyHalted = false; // Flag pour arrêter le trading pour la journée
int             g_lastDay = -1; // CORRIGÉ: Utilise un int pour le jour

//+------------------------------------------------------------------+
//| Fonctions Helper (utilitaires)                                   |
//+------------------------------------------------------------------+

//--- Vérifie si le symbole est un indice Boom/Crash/Volatility
bool IsBoomCrashIndex(string symbol)
  {
   return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 || StringFind(symbol, "Volatility") >= 0);
  }

//--- Applique la règle BUY sur Boom, SELL sur Crash
int EnforceBoomCrashDirection(int desiredDirection)
  {
   if(!InpAntiCounterTrend || !IsBoomCrashIndex(_Symbol))
      return desiredDirection;
   if(StringFind(_Symbol, "Boom") >= 0 && desiredDirection < 0)
      return 0; // Pas de SELL sur Boom
   if(StringFind(_Symbol, "Crash") >= 0 && desiredDirection > 0)
      return 0; // Pas de BUY sur Crash
   return desiredDirection;
  }

//--- Ferme toutes les positions pour un magic number donné
void CloseAllPositions(int magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      g_trade.PositionClose(tk);
     }
  }

//--- Calculer le profit/perte journalier des deals clôturés
double CalculateDailyPnl()
  {
   double pnl = 0;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime today_start = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);

   if(HistorySelect(today_start, TimeCurrent()))
     {
      // CORRIGÉ: uint -> int pour éviter l'avertissement "sign mismatch"
      for(int i = 0; i < (int)HistoryDealsTotal(); i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
           {
            pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
           }
        }
     }
   return pnl;
  }

//--- Mise à jour du tableau de bord
void UpdateDashboard()
  {
   if(!InpShowDashboard)
      return;

   // CORRIGÉ: Utilisation de StringFormat pour éviter les avertissements de conversion implicite
   string text = "--- AngelOfSpike v5.2 ---\n";
   text += "Mode: Chasseur de Spikes Ultra-Précis\n";
   text += StringFormat("Objectif Jour: $%.2f\n", InpBasketProfitCloseUSD);
   text += StringFormat("Perte Max Jour: $%.2f\n", InpBasketLossCloseUSD);

   double open_pnl = 0;
   int open_trades = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionSelect(i))
        {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
           {
            open_pnl += PositionGetDouble(POSITION_PROFIT);
            open_trades++;
           }
        }
     }
   double daily_pnl = CalculateDailyPnl();

   text += StringFormat("Profit/Perte Jour: $%.2f\n", daily_pnl + open_pnl);
   text += StringFormat("Trades Ouverts: %d / %d\n", open_trades, InpMaxSimultaneousTrades);
   if(g_dailyHalted)
     {
      text += "\n!! TRADING ARRÊTÉ POUR LA JOURNÉE !!";
     }

   if(ObjectFind(0, "Dashboard") < 0)
     {
      ObjectCreate(0, "Dashboard", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "Dashboard", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "Dashboard", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "Dashboard", OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, "Dashboard", OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, "Dashboard", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "Dashboard", OBJPROP_BACK, true);
      ObjectSetInteger(0, "Dashboard", OBJPROP_BGCOLOR, C'30,30,30');
     }
   ObjectSetString(0, "Dashboard", OBJPROP_TEXT, text);
   ObjectSetInteger(0, "Dashboard", OBJPROP_COLOR, g_dailyHalted ? clrRed : clrLime);
  }


//+------------------------------------------------------------------+
//| Fonctions de Détection S/R                                       |
//+------------------------------------------------------------------+
void UpdateSRZones()
  {
   if(!InpEnableSRDetection)
      return;

   g_sr_zone_count = 0;
   ENUM_TIMEFRAMES timeframes[] = {PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15, PERIOD_M5};

   for(int tf = 0; tf < ArraySize(timeframes); tf++)
     {
      MqlRates rates[];
      if(CopyRates(_Symbol, timeframes[tf], 0, InpSRLookbackBars, rates) < InpSRLookbackBars)
         continue;

      for(int i = 3; i < InpSRLookbackBars - 3; i++)
        {
         bool is_pivot_high = rates[i].high > rates[i - 1].high && rates[i].high > rates[i + 1].high && rates[i].high > rates[i - 2].high && rates[i].high > rates[i + 2].high;
         bool is_pivot_low = rates[i].low < rates[i - 1].low && rates[i].low < rates[i + 1].low && rates[i].low < rates[i - 2].low && rates[i].low < rates[i + 2].low;

         if(is_pivot_high)
            AddSRZone(rates[i].high, false, timeframes[tf]);
         if(is_pivot_low)
            AddSRZone(rates[i].low, true, timeframes[tf]);
        }
     }

   if(InpDrawSRZones)
      DrawSRZones();
   g_last_sr_update = TimeCurrent();
  }

void AddSRZone(double level, bool is_support, ENUM_TIMEFRAMES timeframe)
  {
   for(int i = 0; i < g_sr_zone_count; i++)
     {
      if(MathAbs(g_sr_zones[i].level - level) <= InpSRZoneTolerance && g_sr_zones[i].is_support == is_support)
        {
         g_sr_zones[i].touch_count++;
         g_sr_zones[i].strength = MathMin(1.0, g_sr_zones[i].touch_count / 3.0);
         return;
        }
     }

   if(g_sr_zone_count < ArraySize(g_sr_zones))
     {
      g_sr_zones[g_sr_zone_count].level = level;
      g_sr_zones[g_sr_zone_count].is_support = is_support;
      g_sr_zones[g_sr_zone_count].touch_count = 1;
      g_sr_zones[g_sr_zone_count].timeframe = timeframe;
      g_sr_zones[g_sr_zone_count].is_active = true;
      g_sr_zones[g_sr_zone_count].strength = 0.33;
      g_sr_zone_count++;
     }
  }

void DrawSRZones()
  {
   ObjectsDeleteAll(0, "SR_");
   for(int i = 0; i < g_sr_zone_count; i++)
     {
      if(!g_sr_zones[i].is_active || g_sr_zones[i].touch_count < InpSRMinTouches || g_sr_zones[i].strength * 100 < InpSRMinConfidence)
         continue;

      string obj_name = StringFormat("SR_%d", i);
      color zone_color = g_sr_zones[i].is_support ? InpSRSupportColor : InpSRResistanceColor;

      if(ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, g_sr_zones[i].level))
        {
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, zone_color);
         ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
        }
     }
  }

bool IsNearSRZone(double price, bool is_buy_signal, double &out_level, double &out_strength)
  {
   if(!InpPrioritizeSREntries)
      return false;

   for(int i = 0; i < g_sr_zone_count; i++)
     {
      if(!g_sr_zones[i].is_active || g_sr_zones[i].touch_count < InpSRMinTouches)
         continue;

      // Pour un achat, on cherche un support proche. Pour une vente, une résistance.
      if((is_buy_signal && !g_sr_zones[i].is_support) || (!is_buy_signal && g_sr_zones[i].is_support))
         continue;

      if(MathAbs(g_sr_zones[i].level - price) <= InpSRZoneTolerance)
        {
         out_level = g_sr_zones[i].level;
         out_strength = g_sr_zones[i].strength;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Fonctions de Détection de Spike                                  |
//+------------------------------------------------------------------+

//--- Calcule un score de confiance pour un signal de spike potentiel
double GetSpikeSignalConfidence()
  {
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_M1, 0, 20, rates);
   if(copied < 20)
   {
      Print("Erreur: Impossible de copier les données des prix. Copiés: ", IntegerToString(copied), " sur 20");
      return 0.0;
   }

   double confidence = 0.0;

   // 1. Compression de volatilité (ATR)
   int atr_handle = iATR(_Symbol, PERIOD_M1, 14);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Erreur: Impossible de créer le handle ATR. Code d'erreur: ", IntegerToString(GetLastError()));
      return 0.0;
   }

   double atr_val[10] = {0};
   int atr_copied = CopyBuffer(atr_handle, 0, 0, 10, atr_val);
   if(atr_copied != 10)
   {
      Print("Erreur: Impossible de copier les données ATR. Copiés: ", IntegerToString(atr_copied), " sur 10. Erreur: ", IntegerToString(GetLastError()));
      IndicatorRelease(atr_handle);
      return 0.0;
   }

   double current_atr = atr_val[0];
   double avg_atr = 0.0;
   for(int i = 1; i < 10; i++)
   {
      avg_atr += atr_val[i];
   }
   avg_atr /= 9.0;

   Print("ATR Actuel: ", DoubleToString(current_atr, (int)_Digits), " - ATR Moyen: ", DoubleToString(avg_atr, (int)_Digits));

   if(avg_atr > 0 && current_atr < avg_atr * 0.7)
   {
      confidence += 30.0; // Compression forte
      Print("Compression de volatilité détectée!");
   }
   
   // Libérer le handle ATR après utilisation
   if(!IndicatorRelease(atr_handle))
   {
      Print("Attention: Impossible de libérer le handle ATR. Erreur: ", IntegerToString(GetLastError()));
   }
   
   // 2. Volume (si disponible)
   if(MarketInfo(_Symbol, MODE_TRADE_CALC_MODE) != SYMBOL_CALC_MODE_FOREX)
   {
      long volume_array[5] = {0};
      int volume_copied = CopyTickVolume(_Symbol, PERIOD_M1, 0, 5, volume_array);
      if(volume_copied == 5)
      {
         double avg_volume = (volume_array[1] + volume_array[2] + volume_array[3] + volume_array[4]) / 4.0;
         if(avg_volume > 0) // Éviter la division par zéro
         {
            double volume_ratio = (double)volume_array[0] / avg_volume;
            if(volume_ratio > 2.0) // Volume actuel 2x supérieur à la moyenne
            {
               confidence += 20.0;
               Print("Volume anormalement élevé détecté: ", DoubleToString(volume_ratio, 1), "x la moyenne");
            }
         }
      }
      else
      {
         Print("Avertissement: Impossible de copier les données de volume. Copiés: ", IntegerToString(volume_copied), " sur 5");
      }
   }
   
   // 3. Analyse des bougies récentes
   double body_sizes[5] = {0};
   for(int i = 0; i < MathMin(5, copied); i++)
   {
      body_sizes[i] = MathAbs(rates[i].close - rates[i].open);
   }
   
   // Vérification de la contraction des mouvements
   if(body_sizes[1] > 0 && body_sizes[2] > 0 && // Éviter la division par zéro
      body_sizes[0] < body_sizes[1] * 0.5 && 
      body_sizes[1] < body_sizes[2] * 0.7)
   {
      confidence += 20.0;
      Print("Contraction des mouvements détectée");
   }
   
   // 4. Vérification des niveaux de support/résistance
   // (à implémenter avec une détection plus sophistiquée)
   
   // 5. Limiter la confiance à 100%
   if(confidence > 100.0) 
   {
      confidence = 100.0;
   }
   
   Print("Niveau de confiance total: ", DoubleToString(confidence, 1), "%");
   return NormalizeDouble(confidence, 2);
  }

//--- Détecte un spike pour entrer en position (logique principale)
bool DetectSpikeForEntry(int &direction)
  {
   if(!InpUltraPreciseMode)
      return false;

   double confidence = GetSpikeSignalConfidence();

   if(confidence < InpUltraHighConfidence)
     {
      return false;
     }

   // Déterminer la direction en fonction de la tendance et des règles Boom/Crash
   int ema_fast_h = iMA(_Symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
   int ema_slow_h = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(ema_fast_h == INVALID_HANDLE || ema_slow_h == INVALID_HANDLE)
      return false;

   double ema_fast[1], ema_slow[1];
   if(CopyBuffer(ema_fast_h, 0, 0, 1, ema_fast) < 1 || CopyBuffer(ema_slow_h, 0, 0, 1, ema_slow) < 1)
     {
      IndicatorRelease(ema_fast_h);
      IndicatorRelease(ema_slow_h);
      return false;
     }
   IndicatorRelease(ema_fast_h);
   IndicatorRelease(ema_slow_h);

   int trend_direction = (ema_fast[0] > ema_slow[0]) ? 1 : -1;
   direction = EnforceBoomCrashDirection(trend_direction);

   if(direction != 0)
     {
      PrintFormat("Spike imminent détecté! Direction: %s, Confiance: %.1f%%", (direction > 0 ? "BUY" : "SELL"), confidence);
      return true;
     }

   return false;
  }

//--- Détecte un spike pour fermer une position
bool DetectSpikeForClose(ulong ticket)
  {
   if(!InpImmediateCloseAfterSpike)
      return false;
   if(!PositionSelectByTicket(ticket))
      return false;

   double profit = PositionGetDouble(POSITION_PROFIT);
   if(profit < InpQuickGainThreshold)
      return false; // Ne fermer que si un petit gain est déjà sécurisé

   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, 2, rates) < 2)
      return false;

   // Détection simple : la dernière bougie est beaucoup plus grande que la précédente
   double range_now = rates[0].high - rates[0].low;
   double range_prev = rates[1].high - rates[1].low;

   // CORRIGÉ: Ajout de parenthèses pour clarifier la précédence des opérateurs
   if((range_prev > 0) && (range_now > (range_prev * 3.0)))
     {
      PrintFormat("Spike de sortie détecté sur le trade %d. Fermeture immédiate.", ticket);
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Fonctions de Trading                                             |
//+------------------------------------------------------------------+
bool ExecuteTrade(int direction)
  {
   // Vérifier les limites de trades simultanés
   int open_trades = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionSelect(i) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
         open_trades++;
        }
     }
   if(open_trades >= InpMaxSimultaneousTrades)
     {
      PrintFormat("Limite de %d trades simultanés atteinte. Aucun nouveau trade.", InpMaxSimultaneousTrades);
      return false;
     }

   double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl_price = 0, tp_price = 0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Calcul du SL/TP optimal
   if(InpUseOptimalSLTP)
     {
      int atr_handle = iATR(_Symbol, PERIOD_M1, InpATR_Period);
      if(atr_handle != INVALID_HANDLE)
        {
         double atr_val[1];
         if(CopyBuffer(atr_handle, 0, 0, 1, atr_val) > 0)
           {
            double sl_dist = atr_val[0] * InpSL_ATR_Multiplier;
            double tp_dist = atr_val[0] * InpTP_ATR_Multiplier;

            // Assurer un ratio R:R minimum
            if(tp_dist < sl_dist * InpMinRiskRewardRatio)
              {
               tp_dist = sl_dist * InpMinRiskRewardRatio;
              }

            if(direction > 0)
              {
               sl_price = price - sl_dist;
               tp_price = price + tp_dist;
              }
            else
              {
               sl_price = price + sl_dist;
               tp_price = price - tp_dist;
              }
           }
         IndicatorRelease(atr_handle);
        }
     }

   // Si le calcul échoue, on ne trade pas. C'est plus sûr.
   if(sl_price == 0 || tp_price == 0)
     {
      Print("Calcul SL/TP a échoué. Le trade est annulé pour des raisons de sécurité.");
      return false;
     }

   // Vérifier le niveau de stop minimum du broker
   double stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   if(direction > 0)
     {
      if(price - sl_price < stops_level)
         sl_price = price - stops_level;
      if(tp_price - price < stops_level)
         tp_price = price + stops_level;
     }
   else
     {
      if(sl_price - price < stops_level)
         sl_price = price + stops_level;
      if(price - tp_price < stops_level)
         tp_price = price - tp_price;
     }

   // Exécution du trade
   bool result = false;
   if(direction > 0)
     {
      result = g_trade.Buy(InpLotSize, _Symbol, price, sl_price, tp_price, "AngelOfSpike v5.2");
     }
   else
     {
      result = g_trade.Sell(InpLotSize, _Symbol, price, sl_price, tp_price, "AngelOfSpike v5.2");
     }

   if(result)
     {
      PrintFormat("Trade %s exécuté avec succès. SL: %.5f, TP: %.5f", (direction > 0 ? "BUY" : "SELL"), sl_price, tp_price);
      if(InpSendNotifications)
        {
         SendNotification(StringFormat("AngelOfSpike: Trade %s sur %s", (direction > 0 ? "BUY" : "SELL"), _Symbol));
        }
     }
   else
     {
      PrintFormat("Échec de l'exécution du trade. Erreur: %d", (int)g_trade.ResultRetcode());
     }

   return result;
  }

//--- Gère les trades ouverts (pour la fermeture rapide)
void ManageOpenTrades()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      // Logique de fermeture immédiate après spike + petit gain
      if(DetectSpikeForClose(ticket))
        {
         g_trade.PositionClose(ticket);
        }
     }
  }


//+------------------------------------------------------------------+
//| Fonctions Principales du Robot (OnInit, OnDeinit, OnTick)        |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("--- AngelOfSpike v5.2 ---");
   Print("Stratégie: Chasseur de Spikes Ultra-Précis");
   Print("Gestion de risque: Clôture du panier (Basket Close)");
   Print("Initialisation terminée. Robot prêt.");

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   // CORRIGÉ: Initialise g_lastDay à une valeur invalide pour forcer la mise à jour au premier tick.
   g_lastDay = -1;

   // Nettoyer les objets du graphique au démarrage
   ObjectsDeleteAll(0);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Print("Arrêt du robot AngelOfSpike v5.2. Raison: ", IntegerToString((int)reason));
   ObjectsDeleteAll(0);
  }

void OnTick()
  {
   // 0. Vérification journalière et mise à jour du dashboard
   // CORRIGÉ: Utilisation de TimeToStruct pour être compatible MQL5
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != g_lastDay)
     {
      g_lastDay = dt.day;
      g_dailyHalted = false; // Réinitialiser le blocage pour le nouveau jour
      Print("Nouveau jour de trading. Le robot est réactivé.");
     }
   if(InpShowDashboard)
      UpdateDashboard();

   // 1. GESTION DE RISQUE PRIORITAIRE : Clôture du panier
   if(InpEnableBasketClose && !g_dailyHalted)
     {
      double open_pnl = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         if(PositionSelect(i) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
           {
            open_pnl += PositionGetDouble(POSITION_PROFIT);
           }
        }

      double total_pnl_today = CalculateDailyPnl() + open_pnl;

      // Objectif de profit atteint
      if(total_pnl_today >= InpBasketProfitCloseUSD)
        {
         Print("OBJECTIF DE PROFIT JOURNALIER ATTEINT! ($" + DoubleToString(total_pnl_today, 2) + "). Fermeture de toutes les positions.");
         CloseAllPositions(InpMagicNumber);
         g_dailyHalted = true;
        }
      // Limite de perte atteinte
      else if(total_pnl_today <= -InpBasketLossCloseUSD)
        {
         Print("LIMITE DE PERTE JOURNALIÈRE ATTEINTE! ($" + DoubleToString(-total_pnl_today, 2) + "). Fermeture de toutes les positions.");
         CloseAllPositions(InpMagicNumber);
         g_dailyHalted = true;
        }
     }

   // Si le trading est arrêté pour la journée, ne rien faire d'autre
   if(g_dailyHalted)
     {
      return;
     }

   // 2. GESTION DES TRADES OUVERTS (Fermeture sur spike)
   ManageOpenTrades();

   // Si trading désactivé, sortir
   if(!InpEnableTrading)
      return;

   // 3. MISE À JOUR DES FILTRES (S/R)
   if(TimeCurrent() - g_last_sr_update > 60) // Toutes les 60 secondes
     {
      UpdateSRZones();
     }

   // 4. LOGIQUE D'ENTRÉE : Attendre un signal de haute qualité
   int trade_direction = 0;
   static datetime last_log_time = 0;
   
   // Vérifier le marché toutes les 5 secondes
   if(TimeCurrent() - last_log_time >= 5)
   {
      last_log_time = TimeCurrent();
      
      // Vérifier la connexion au marché
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      {
         Print("Terminal connecté au marché - Vérification des signaux...");
         
         // Vérifier les données des prix
         MqlRates rates[];
         int copied = CopyRates(_Symbol, PERIOD_M1, 0, 1, rates);
         if(copied == 1)
         {
            double current_price_value = rates[0].close; // Renommé pour éviter le conflit
            Print("Dernier tick: ", TimeToString(TimeCurrent()));
            Print("Prix actuel: ", DoubleToString(current_price_value, (int)_Digits));
            
            // Tester la détection de signal
            double signal_confidence = GetSpikeSignalConfidence();
            Print("Confiance du signal: ", DoubleToString(signal_confidence, 1), "%");
            
            // Vérifier la direction du marché
            int ema_fast_handle = iMA(_Symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
            int ema_slow_handle = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
            
            if(ema_fast_handle != INVALID_HANDLE && ema_slow_handle != INVALID_HANDLE)
            {
               double ema_fast[1], ema_slow[1];
               if(CopyBuffer(ema_fast_handle, 0, 0, 1, ema_fast) > 0 && 
                  CopyBuffer(ema_slow_handle, 0, 0, 1, ema_slow) > 0)
               {
                  Print("EMA10: ", DoubleToString(ema_fast[0], (int)_Digits), 
                        " | EMA20: ", DoubleToString(ema_slow[0], (int)_Digits));
                  Print("Tendance: ", (ema_fast[0] > ema_slow[0] ? "Haussière" : "Baissière"));
               }
               IndicatorRelease(ema_fast_handle);
               IndicatorRelease(ema_slow_handle);
            }
            
            // Vérifier les signaux de trading
            if(DetectSpikeForEntry(trade_direction))
            {
               string direction_str = (trade_direction > 0) ? "ACHAT" : "VENTE";
               Print("!!! SIGNAL DE TRADING DÉTECTÉ !!! Direction: ", direction_str);
               
               if(ExecuteTrade(trade_direction))
               {
                  Print("Ordre exécuté avec succès!");
               }
               else
               {
                  int last_error = GetLastError();
                  Print("Échec de l'exécution de l'ordre. Erreur: ", IntegerToString(last_error));
               }
            }
         }
         else
         {
            Print("Erreur: Impossible d'obtenir les données de prix");
         }
      }
      else
      {
         Print("ATTENTION: Le terminal n'est pas connecté au marché!");
      }
   }
  }