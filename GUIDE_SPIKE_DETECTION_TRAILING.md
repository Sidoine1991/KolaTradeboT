# 🎯 GUIDE COMPLET : Détection Spike + Trailing Stop Boom/Crash

## 📋 Table des Matières

1. [Détection Automatique de Spike](#1-détection-automatique-de-spike)
2. [Trailing Stop Spécial Boom/Crash](#2-trailing-stop-spécial-boomcrash)
3. [Code MT5 (MQL5)](#3-code-mt5-mql5)
4. [Code Python (MT5 API)](#4-code-python-mt5-api)
5. [Stratégies Avancées](#5-stratégies-avancées)

---

## 1. Détection Automatique de Spike

### 🎯 Qu'est-ce qu'un Spike Boom/Crash ?

**BOOM** :
- Mouvement haussier **rapide et violent**
- Prix monte de 0.3% à 2% en **quelques secondes**
- Volume explose
- ATR se comprime avant, puis explose

**CRASH** :
- Mouvement baissier **rapide et violent**
- Prix descend de -0.3% à -2% en **quelques secondes**
- Volume explose
- ATR se comprime avant, puis explose

### 📊 5 Indicateurs de Spike

#### Indicateur 1 : **Mouvement Prix Rapide**
```
Variation % = (Prix Actuel - Prix il y a 5s) / Prix il y a 5s × 100

BOOM SPIKE:  Variation ≥ +0.3% en ≤ 5 secondes
CRASH SPIKE: Variation ≤ -0.3% en ≤ 5 secondes
```

#### Indicateur 2 : **Compression ATR (Calme avant la Tempête)**
```
ATR Actuel / Moyenne ATR (20 périodes) < 0.5

Si ATR compressé + Volume spike = SPIKE IMMINENT
```

#### Indicateur 3 : **Volume Spike**
```
Volume Actuel / Moyenne Volume (20 périodes) > 2.0

Volume > 2× moyenne = Signal fort
```

#### Indicateur 4 : **Accélération Prix**
```
Accélération = (Variation 0-1) - (Variation 2-3)

Si accélération > 0.002 = Momentum explosif
```

#### Indicateur 5 : **Pattern Pré-Spike**
```
- Range se resserre (compression)
- Prix proche MA 20
- 3+ bougies calmes consécutives
- Prix près canal SMC
```

### 🔢 Formule de Probabilité Spike

```
Proba Spike = 0.25×Compression + 0.20×Accélération + 0.20×Volume + 
              0.15×Range + 0.10×Pattern + 0.10×Canal

Valeur entre 0 et 1 (0% à 100%)

< 0.50 = Faible probabilité
0.50-0.75 = Probabilité moyenne
> 0.75 = Probabilité élevée (ALERTE!)
```

---

## 2. Trailing Stop Spécial Boom/Crash

### 🎯 Pourquoi un Trailing Stop Spécial ?

**Boom/Crash sont DIFFÉRENTS de Forex** :
- ✅ Mouvements **très rapides** (spikes)
- ✅ Retracements **brutaux** après spike
- ✅ Besoin de **sécuriser gains rapidement**
- ❌ Trailing classique = trop lent ou trop serré

### 📈 Stratégie Trailing Stop Boom 1000

```
BOOM 1000 = Spikes haussiers fréquents

Phase 1: Position ouverte BUY
├─ Pas de trailing (laisser respirer)
│
Phase 2: Spike détecté (+0.5% en 3s)
├─ Activer trailing agressif
├─ Distance: 0.15% du prix actuel
├─ Step: 0.05% (suit chaque mouvement)
│
Phase 3: Profit ≥ 0.10$
├─ Serrer trailing à 0.10%
├─ Protéger 70% du gain
│
Phase 4: Retracement commence
└─ Fermer si prix recule de 0.10% depuis plus haut
```

### 📉 Stratégie Trailing Stop Crash 500

```
CRASH 500 = Spikes baissiers fréquents

Phase 1: Position ouverte SELL
├─ Pas de trailing (laisser respirer)
│
Phase 2: Spike détecté (-0.5% en 3s)
├─ Activer trailing agressif
├─ Distance: 0.15% du prix actuel
├─ Step: 0.05% (suit chaque mouvement)
│
Phase 3: Profit ≥ 0.10$
├─ Serrer trailing à 0.10%
├─ Protéger 70% du gain
│
Phase 4: Retracement commence
└─ Fermer si prix remonte de 0.10% depuis plus bas
```

### 🎚️ Paramètres Adaptés par Indice

| Indice | Distance Initiale | Distance Spike | Step | Profit Min |
|--------|------------------|----------------|------|-----------|
| **Boom 500** | 0.20% | 0.15% | 0.05% | 0.08$ |
| **Boom 1000** | 0.15% | 0.10% | 0.05% | 0.10$ |
| **Crash 500** | 0.20% | 0.15% | 0.05% | 0.08$ |
| **Crash 1000** | 0.15% | 0.10% | 0.05% | 0.10$ |

---

## 3. Code MT5 (MQL5)

### 📦 Classe de Détection Spike

```mql5
//+------------------------------------------------------------------+
//| Classe de Détection de Spike Boom/Crash                         |
//+------------------------------------------------------------------+
class CSpikeDetector
{
private:
   string   m_symbol;
   double   m_lastPrice;
   datetime m_lastPriceTime;
   double   m_spikeThreshold;    // 0.003 = 0.3%
   int      m_spikeTimeWindow;   // 5 secondes
   
public:
   CSpikeDetector(string symbol = NULL, double threshold = 0.003, int timeWindow = 5)
   {
      m_symbol = (symbol == NULL) ? _Symbol : symbol;
      m_spikeThreshold = threshold;
      m_spikeTimeWindow = timeWindow;
      m_lastPrice = 0.0;
      m_lastPriceTime = 0;
   }
   
   //--- Détection spike rapide
   bool DetectSpike(string &direction, double &spikePercent)
   {
      datetime now = TimeCurrent();
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Initialisation première fois
      if(m_lastPriceTime == 0 || m_lastPrice <= 0.0)
      {
         m_lastPrice = currentPrice;
         m_lastPriceTime = now;
         return false;
      }
      
      // Vérifier fenêtre de temps
      int elapsed = (int)(now - m_lastPriceTime);
      if(elapsed > m_spikeTimeWindow || elapsed <= 0)
      {
         m_lastPrice = currentPrice;
         m_lastPriceTime = now;
         return false;
      }
      
      // Calculer variation %
      double priceChange = currentPrice - m_lastPrice;
      spikePercent = (priceChange / m_lastPrice) * 100.0;
      
      // Détection Boom (spike haussier)
      if(StringFind(m_symbol, "Boom") >= 0 && spikePercent >= m_spikeThreshold * 100.0)
      {
         direction = "BUY";
         Print("🎯 BOOM SPIKE: +", DoubleToString(spikePercent, 2), "% en ", elapsed, "s");
         
         // Reset pour prochaine détection
         m_lastPrice = currentPrice;
         m_lastPriceTime = now;
         return true;
      }
      
      // Détection Crash (spike baissier)
      if(StringFind(m_symbol, "Crash") >= 0 && spikePercent <= -m_spikeThreshold * 100.0)
      {
         direction = "SELL";
         Print("🎯 CRASH SPIKE: ", DoubleToString(spikePercent, 2), "% en ", elapsed, "s");
         
         // Reset pour prochaine détection
         m_lastPrice = currentPrice;
         m_lastPriceTime = now;
         return true;
      }
      
      return false;
   }
   
   //--- Calculer probabilité spike (algorithme complet)
   double CalculateSpikeprobability()
   {
      // 1. Compression ATR
      double atrCompression = GetATRCompression();
      
      // 2. Accélération prix
      double acceleration = GetPriceAcceleration();
      
      // 3. Volume spike
      double volumeRatio = GetVolumeRatio();
      
      // 4. Range compression
      double rangeRatio = GetRangeRatio();
      
      // 5. Pattern pré-spike
      double patternScore = GetPreSpikePattern();
      
      // 6. Proximité canal
      double channelScore = GetChannelProximity();
      
      // Formule pondérée
      double probability = 
         0.25 * atrCompression +
         0.20 * acceleration +
         0.20 * volumeRatio +
         0.15 * rangeRatio +
         0.10 * patternScore +
         0.10 * channelScore;
      
      return MathMax(0.0, MathMin(1.0, probability));
   }
   
private:
   //--- Compression ATR (0..1)
   double GetATRCompression()
   {
      int atrHandle = iATR(m_symbol, PERIOD_M1, 14);
      if(atrHandle == INVALID_HANDLE) return 0.0;
      
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 20, atr) < 20)
      {
         IndicatorRelease(atrHandle);
         return 0.0;
      }
      
      double currentATR = atr[0];
      double avgATR = 0.0;
      for(int i = 1; i < 20; i++) avgATR += atr[i];
      avgATR /= 19.0;
      
      IndicatorRelease(atrHandle);
      
      if(avgATR <= 0.0) return 0.0;
      
      double ratio = currentATR / avgATR;
      if(ratio >= 1.0) return 0.0;
      
      // Compression forte = score élevé
      return MathMin((1.0 - ratio) / 0.6, 1.0);
   }
   
   //--- Accélération prix (0..1)
   double GetPriceAcceleration()
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(m_symbol, PERIOD_M1, 0, 5, rates) < 5) return 0.0;
      
      double change1 = (rates[0].close - rates[1].close) / rates[1].close;
      double change2 = (rates[2].close - rates[3].close) / rates[3].close;
      double accel = MathAbs(change1 - change2);
      
      return MathMin(accel / 0.003, 1.0);
   }
   
   //--- Volume ratio (0..1)
   double GetVolumeRatio()
   {
      long volumes[];
      ArraySetAsSeries(volumes, true);
      if(CopyTickVolume(m_symbol, PERIOD_M1, 0, 20, volumes) < 20) return 0.0;
      
      double currentVol = (double)volumes[0];
      double avgVol = 0.0;
      for(int i = 1; i < 20; i++) avgVol += (double)volumes[i];
      avgVol /= 19.0;
      
      if(avgVol <= 0.0) return 0.0;
      
      double ratio = currentVol / avgVol;
      if(ratio <= 1.0) return 0.0;
      
      return MathMin((ratio - 1.0) / 1.5, 1.0);
   }
   
   //--- Range compression (0..1)
   double GetRangeRatio()
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(m_symbol, PERIOD_M1, 0, 10, rates) < 10) return 0.0;
      
      double currentRange = MathAbs(rates[0].high - rates[0].low);
      double avgRange = 0.0;
      for(int i = 1; i < 10; i++)
         avgRange += MathAbs(rates[i].high - rates[i].low);
      avgRange /= 9.0;
      
      if(avgRange <= 0.0) return 0.0;
      
      double ratio = currentRange / avgRange;
      if(ratio <= 1.0) return 0.0;
      
      return MathMin((ratio - 1.0) / 1.0, 1.0);
   }
   
   //--- Pattern pré-spike (0..1)
   double GetPreSpikePattern()
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(m_symbol, PERIOD_M1, 0, 50, rates) < 50) return 0.0;
      
      // Range 10 vs 50
      double hi10 = rates[0].high, lo10 = rates[0].low;
      for(int i = 0; i < 10; i++)
      {
         hi10 = MathMax(hi10, rates[i].high);
         lo10 = MathMin(lo10, rates[i].low);
      }
      double range10 = hi10 - lo10;
      
      double hi50 = rates[0].high, lo50 = rates[0].low;
      for(int i = 0; i < 50; i++)
      {
         hi50 = MathMax(hi50, rates[i].high);
         lo50 = MathMin(lo50, rates[i].low);
      }
      double range50 = hi50 - lo50;
      
      // Compression
      bool compression = (range50 > 0.0 && range10 < range50 * 0.4);
      
      // Consolidation MA
      double ma20 = 0.0;
      for(int i = 0; i < 20; i++) ma20 += rates[i].close;
      ma20 /= 20.0;
      bool consolidation = (ma20 > 0.0 && (MathAbs(rates[0].close - ma20) / ma20) < 0.01);
      
      if(compression && consolidation) return 1.0;
      if(compression) return 0.5;
      return 0.0;
   }
   
   //--- Proximité canal (0..1)
   double GetChannelProximity()
   {
      // Simplifié: utiliser BBands comme proxy
      int bbHandle = iBands(m_symbol, PERIOD_H1, 20, 0, 2.0, PRICE_CLOSE);
      if(bbHandle == INVALID_HANDLE) return 0.0;
      
      double upper[], lower[], middle[];
      ArraySetAsSeries(upper, true);
      ArraySetAsSeries(lower, true);
      ArraySetAsSeries(middle, true);
      
      if(CopyBuffer(bbHandle, 1, 0, 1, upper) < 1 ||
         CopyBuffer(bbHandle, 2, 0, 1, lower) < 1 ||
         CopyBuffer(bbHandle, 0, 0, 1, middle) < 1)
      {
         IndicatorRelease(bbHandle);
         return 0.0;
      }
      
      double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double distUpper = MathAbs(price - upper[0]);
      double distLower = MathAbs(price - lower[0]);
      double bandWidth = upper[0] - lower[0];
      
      IndicatorRelease(bbHandle);
      
      if(bandWidth <= 0.0) return 0.0;
      
      double minDist = MathMin(distUpper, distLower);
      double proximity = 1.0 - (minDist / (bandWidth / 2.0));
      
      return MathMax(0.0, MathMin(1.0, proximity));
   }
};
```

### 📦 Classe Trailing Stop Boom/Crash

```mql5
//+------------------------------------------------------------------+
//| Classe Trailing Stop Spécial Boom/Crash                         |
//+------------------------------------------------------------------+
class CBoomCrashTrailingStop
{
private:
   string   m_symbol;
   ulong    m_positionTicket;
   double   m_distanceInitial;    // 0.0015 = 0.15%
   double   m_distanceSpike;      // 0.0010 = 0.10%
   double   m_stepPercent;        // 0.0005 = 0.05%
   double   m_minProfitUSD;       // 0.10 = 0.10$
   double   m_highestPrice;       // Plus haut atteint (BUY)
   double   m_lowestPrice;        // Plus bas atteint (SELL)
   bool     m_spikeMode;          // Mode agressif activé
   CTrade   m_trade;
   
public:
   CBoomCrashTrailingStop()
   {
      m_symbol = _Symbol;
      m_positionTicket = 0;
      m_distanceInitial = 0.0015;  // 0.15%
      m_distanceSpike = 0.0010;    // 0.10%
      m_stepPercent = 0.0005;      // 0.05%
      m_minProfitUSD = 0.10;
      m_highestPrice = 0.0;
      m_lowestPrice = 0.0;
      m_spikeMode = false;
   }
   
   //--- Initialiser pour une position
   void Init(ulong ticket, string symbol = NULL)
   {
      m_positionTicket = ticket;
      if(symbol != NULL) m_symbol = symbol;
      
      if(!PositionSelectByTicket(ticket)) return;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      if(ptype == POSITION_TYPE_BUY)
      {
         m_highestPrice = openPrice;
         m_lowestPrice = 0.0;
      }
      else
      {
         m_lowestPrice = openPrice;
         m_highestPrice = 0.0;
      }
      
      m_spikeMode = false;
      
      Print("🎯 Trailing Stop initialisé | Ticket: ", ticket, " | Symbol: ", m_symbol);
   }
   
   //--- Mettre à jour trailing (appeler à chaque tick)
   void Update(bool spikeDetected = false)
   {
      if(m_positionTicket == 0) return;
      if(!PositionSelectByTicket(m_positionTicket)) return;
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentPrice = (ptype == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(m_symbol, SYMBOL_BID) :
                           SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double netProfit = profit + swap;
      
      // Activer mode spike si détecté ET profit > seuil
      if(spikeDetected && netProfit >= m_minProfitUSD)
      {
         if(!m_spikeMode)
         {
            m_spikeMode = true;
            Print("🚀 MODE SPIKE activé | Profit: ", DoubleToString(netProfit, 2), "$ | Trailing agressif");
         }
      }
      
      // Position BUY
      if(ptype == POSITION_TYPE_BUY)
      {
         // Mettre à jour plus haut
         if(currentPrice > m_highestPrice || m_highestPrice == 0.0)
            m_highestPrice = currentPrice;
         
         // Calculer nouveau SL
         double distance = m_spikeMode ? m_distanceSpike : m_distanceInitial;
         double newSL = m_highestPrice * (1.0 - distance);
         
         // Arrondir
         double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tickSize > 0)
            newSL = MathRound(newSL / tickSize) * tickSize;
         
         // Appliquer si SL actuel < nouveau SL
         double currentSL = PositionGetDouble(POSITION_SL);
         if(newSL > currentSL + m_stepPercent * currentPrice)
         {
            double tp = PositionGetDouble(POSITION_TP);
            if(m_trade.PositionModify(m_positionTicket, newSL, tp))
            {
               Print("✅ Trailing SL BUY: ", DoubleToString(newSL, _Digits),
                     " | Plus haut: ", DoubleToString(m_highestPrice, _Digits),
                     " | Mode: ", (m_spikeMode ? "SPIKE" : "NORMAL"));
            }
         }
      }
      // Position SELL
      else
      {
         // Mettre à jour plus bas
         if(currentPrice < m_lowestPrice || m_lowestPrice == 0.0)
            m_lowestPrice = currentPrice;
         
         // Calculer nouveau SL
         double distance = m_spikeMode ? m_distanceSpike : m_distanceInitial;
         double newSL = m_lowestPrice * (1.0 + distance);
         
         // Arrondir
         double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tickSize > 0)
            newSL = MathRound(newSL / tickSize) * tickSize;
         
         // Appliquer si SL actuel > nouveau SL ou pas de SL
         double currentSL = PositionGetDouble(POSITION_SL);
         if(currentSL == 0.0 || newSL < currentSL - m_stepPercent * currentPrice)
         {
            double tp = PositionGetDouble(POSITION_TP);
            if(m_trade.PositionModify(m_positionTicket, newSL, tp))
            {
               Print("✅ Trailing SL SELL: ", DoubleToString(newSL, _Digits),
                     " | Plus bas: ", DoubleToString(m_lowestPrice, _Digits),
                     " | Mode: ", (m_spikeMode ? "SPIKE" : "NORMAL"));
            }
         }
      }
   }
   
   //--- Configurer paramètres
   void SetParameters(double distanceInitial, double distanceSpike, double step, double minProfit)
   {
      m_distanceInitial = distanceInitial;
      m_distanceSpike = distanceSpike;
      m_stepPercent = step;
      m_minProfitUSD = minProfit;
   }
};
```

### 🎯 Utilisation dans Expert Advisor

```mql5
//+------------------------------------------------------------------+
//| Expert Advisor avec Spike Detection + Trailing                  |
//+------------------------------------------------------------------+
#property strict

// Instances globales
CSpikeDetector g_spikeDetector;
CBoomCrashTrailingStop g_trailing;

//--- Input parameters
input bool   EnableSpikeDetection = true;
input double SpikeThreshold = 0.003;  // 0.3%
input int    SpikeTimeWindow = 5;     // 5 secondes

input bool   EnableTrailingStop = true;
input double TrailingDistanceInitial = 0.0015;  // 0.15%
input double TrailingDistanceSpike = 0.0010;    // 0.10%
input double TrailingStep = 0.0005;             // 0.05%
input double TrailingMinProfit = 0.10;          // 0.10$

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialiser détecteur de spike
   g_spikeDetector.CSpikeDetector(_Symbol, SpikeThreshold, SpikeTimeWindow);
   
   // Configurer trailing
   g_trailing.SetParameters(TrailingDistanceInitial, TrailingDistanceSpike,
                            TrailingStep, TrailingMinProfit);
   
   Print("✅ EA Boom/Crash initialisé | Spike Detection: ", 
         (EnableSpikeDetection ? "ON" : "OFF"),
         " | Trailing: ", (EnableTrailingStop ? "ON" : "OFF"));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Détecter spike
   string spikeDirection = "";
   double spikePercent = 0.0;
   bool spikeDetected = false;
   
   if(EnableSpikeDetection)
   {
      spikeDetected = g_spikeDetector.DetectSpike(spikeDirection, spikePercent);
      
      if(spikeDetected)
      {
         Print("🎯 SPIKE DÉTECTÉ: ", spikeDirection, " | ",
               DoubleToString(spikePercent, 2), "%");
         SendNotification("Spike " + _Symbol + " " + spikeDirection);
      }
   }
   
   // 2. Gérer trailing stop sur positions ouvertes
   if(EnableTrailingStop)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         
         // Initialiser trailing si pas encore fait
         if(g_trailing.m_positionTicket != ticket)
            g_trailing.Init(ticket, _Symbol);
         
         // Mettre à jour trailing
         g_trailing.Update(spikeDetected);
      }
   }
}
```

---

## 4. Code Python (MT5 API)

### 📦 Installation

```bash
pip install MetaTrader5
pip install numpy pandas
```

### 🐍 Classe de Détection Spike (Python)

```python
import MetaTrader5 as mt5
import numpy as np
import pandas as pd
from datetime import datetime, timedelta

class SpikeDetector:
    """Détecteur de spike pour Boom/Crash"""
    
    def __init__(self, symbol, threshold=0.003, time_window=5):
        """
        Args:
            symbol: Nom du symbole (ex: "Boom 1000 Index")
            threshold: Seuil de variation (0.003 = 0.3%)
            time_window: Fenêtre de temps en secondes
        """
        self.symbol = symbol
        self.threshold = threshold
        self.time_window = time_window
        self.last_price = 0.0
        self.last_price_time = None
    
    def detect_spike(self):
        """
        Détecte un spike rapide
        
        Returns:
            tuple: (spike_detected, direction, spike_percent)
        """
        # Prix actuel
        tick = mt5.symbol_info_tick(self.symbol)
        if tick is None:
            return False, None, 0.0
        
        current_price = tick.bid
        current_time = datetime.now()
        
        # Initialisation
        if self.last_price_time is None or self.last_price <= 0:
            self.last_price = current_price
            self.last_price_time = current_time
            return False, None, 0.0
        
        # Vérifier fenêtre de temps
        elapsed = (current_time - self.last_price_time).total_seconds()
        if elapsed > self.time_window or elapsed <= 0:
            self.last_price = current_price
            self.last_price_time = current_time
            return False, None, 0.0
        
        # Calculer variation %
        price_change = current_price - self.last_price
        spike_percent = (price_change / self.last_price) * 100.0
        
        # Détection Boom (spike haussier)
        if "Boom" in self.symbol and spike_percent >= self.threshold * 100.0:
            print(f"🎯 BOOM SPIKE: +{spike_percent:.2f}% en {elapsed:.1f}s")
            self.last_price = current_price
            self.last_price_time = current_time
            return True, "BUY", spike_percent
        
        # Détection Crash (spike baissier)
        if "Crash" in self.symbol and spike_percent <= -self.threshold * 100.0:
            print(f"🎯 CRASH SPIKE: {spike_percent:.2f}% en {elapsed:.1f}s")
            self.last_price = current_price
            self.last_price_time = current_time
            return True, "SELL", spike_percent
        
        return False, None, spike_percent
    
    def calculate_spike_probability(self):
        """
        Calcule probabilité de spike (0 à 1)
        
        Returns:
            float: Probabilité entre 0 et 1
        """
        # Récupérer données M1
        rates = mt5.copy_rates_from_pos(self.symbol, mt5.TIMEFRAME_M1, 0, 50)
        if rates is None or len(rates) < 50:
            return 0.0
        
        df = pd.DataFrame(rates)
        
        # 1. Compression ATR
        atr_compression = self._get_atr_compression(df)
        
        # 2. Accélération prix
        acceleration = self._get_price_acceleration(df)
        
        # 3. Volume spike
        volume_ratio = self._get_volume_ratio(df)
        
        # 4. Range compression
        range_ratio = self._get_range_ratio(df)
        
        # 5. Pattern pré-spike
        pattern_score = self._get_prespike_pattern(df)
        
        # Formule pondérée
        probability = (
            0.25 * atr_compression +
            0.20 * acceleration +
            0.20 * volume_ratio +
            0.15 * range_ratio +
            0.20 * pattern_score
        )
        
        return max(0.0, min(1.0, probability))
    
    def _get_atr_compression(self, df):
        """Compression ATR (0..1)"""
        df['HL'] = df['high'] - df['low']
        df['ATR'] = df['HL'].rolling(14).mean()
        
        if len(df) < 20:
            return 0.0
        
        current_atr = df['ATR'].iloc[-1]
        avg_atr = df['ATR'].iloc[-20:-1].mean()
        
        if avg_atr <= 0:
            return 0.0
        
        ratio = current_atr / avg_atr
        if ratio >= 1.0:
            return 0.0
        
        return min((1.0 - ratio) / 0.6, 1.0)
    
    def _get_price_acceleration(self, df):
        """Accélération prix (0..1)"""
        if len(df) < 5:
            return 0.0
        
        closes = df['close'].values
        change1 = (closes[-1] - closes[-2]) / closes[-2]
        change2 = (closes[-3] - closes[-4]) / closes[-4]
        accel = abs(change1 - change2)
        
        return min(accel / 0.003, 1.0)
    
    def _get_volume_ratio(self, df):
        """Volume ratio (0..1)"""
        if len(df) < 20:
            return 0.0
        
        current_vol = df['tick_volume'].iloc[-1]
        avg_vol = df['tick_volume'].iloc[-20:-1].mean()
        
        if avg_vol <= 0:
            return 0.0
        
        ratio = current_vol / avg_vol
        if ratio <= 1.0:
            return 0.0
        
        return min((ratio - 1.0) / 1.5, 1.0)
    
    def _get_range_ratio(self, df):
        """Range expansion (0..1)"""
        if len(df) < 10:
            return 0.0
        
        current_range = df['high'].iloc[-1] - df['low'].iloc[-1]
        avg_range = (df['high'].iloc[-10:-1] - df['low'].iloc[-10:-1]).mean()
        
        if avg_range <= 0:
            return 0.0
        
        ratio = current_range / avg_range
        if ratio <= 1.0:
            return 0.0
        
        return min((ratio - 1.0) / 1.0, 1.0)
    
    def _get_prespike_pattern(self, df):
        """Pattern pré-spike (0..1)"""
        if len(df) < 50:
            return 0.0
        
        # Range 10 vs 50
        hi10 = df['high'].iloc[-10:].max()
        lo10 = df['low'].iloc[-10:].min()
        range10 = hi10 - lo10
        
        hi50 = df['high'].iloc[-50:].max()
        lo50 = df['low'].iloc[-50:].min()
        range50 = hi50 - lo50
        
        # Compression
        compression = range50 > 0 and range10 < range50 * 0.4
        
        # Consolidation MA
        ma20 = df['close'].iloc[-20:].mean()
        current_close = df['close'].iloc[-1]
        consolidation = ma20 > 0 and abs(current_close - ma20) / ma20 < 0.01
        
        if compression and consolidation:
            return 1.0
        elif compression:
            return 0.5
        else:
            return 0.0
```

### 🐍 Classe Trailing Stop (Python)

```python
class BoomCrashTrailingStop:
    """Trailing stop spécial Boom/Crash"""
    
    def __init__(self, symbol):
        self.symbol = symbol
        self.position_ticket = None
        self.distance_initial = 0.0015  # 0.15%
        self.distance_spike = 0.0010    # 0.10%
        self.step_percent = 0.0005      # 0.05%
        self.min_profit_usd = 0.10
        self.highest_price = 0.0
        self.lowest_price = 0.0
        self.spike_mode = False
    
    def init(self, ticket):
        """Initialiser pour une position"""
        self.position_ticket = ticket
        
        positions = mt5.positions_get(ticket=ticket)
        if positions is None or len(positions) == 0:
            return False
        
        pos = positions[0]
        
        if pos.type == mt5.ORDER_TYPE_BUY:
            self.highest_price = pos.price_open
            self.lowest_price = 0.0
        else:
            self.lowest_price = pos.price_open
            self.highest_price = 0.0
        
        self.spike_mode = False
        
        print(f"🎯 Trailing Stop initialisé | Ticket: {ticket}")
        return True
    
    def update(self, spike_detected=False):
        """Mettre à jour trailing (appeler à chaque tick)"""
        if self.position_ticket is None:
            return
        
        positions = mt5.positions_get(ticket=self.position_ticket)
        if positions is None or len(positions) == 0:
            return
        
        pos = positions[0]
        tick = mt5.symbol_info_tick(self.symbol)
        if tick is None:
            return
        
        current_price = tick.bid if pos.type == mt5.ORDER_TYPE_BUY else tick.ask
        net_profit = pos.profit + pos.swap
        
        # Activer mode spike
        if spike_detected and net_profit >= self.min_profit_usd:
            if not self.spike_mode:
                self.spike_mode = True
                print(f"🚀 MODE SPIKE activé | Profit: {net_profit:.2f}$")
        
        # Position BUY
        if pos.type == mt5.ORDER_TYPE_BUY:
            # Mettre à jour plus haut
            if current_price > self.highest_price or self.highest_price == 0.0:
                self.highest_price = current_price
            
            # Calculer nouveau SL
            distance = self.distance_spike if self.spike_mode else self.distance_initial
            new_sl = self.highest_price * (1.0 - distance)
            
            # Arrondir
            symbol_info = mt5.symbol_info(self.symbol)
            if symbol_info is not None:
                tick_size = symbol_info.trade_tick_size
                new_sl = round(new_sl / tick_size) * tick_size
            
            # Appliquer si meilleur
            if new_sl > pos.sl + self.step_percent * current_price:
                request = {
                    "action": mt5.TRADE_ACTION_SLTP,
                    "position": self.position_ticket,
                    "sl": new_sl,
                    "tp": pos.tp,
                }
                
                result = mt5.order_send(request)
                if result is not None and result.retcode == mt5.TRADE_RETCODE_DONE:
                    print(f"✅ Trailing SL BUY: {new_sl:.5f} | "
                          f"Plus haut: {self.highest_price:.5f} | "
                          f"Mode: {'SPIKE' if self.spike_mode else 'NORMAL'}")
        
        # Position SELL
        else:
            # Mettre à jour plus bas
            if current_price < self.lowest_price or self.lowest_price == 0.0:
                self.lowest_price = current_price
            
            # Calculer nouveau SL
            distance = self.distance_spike if self.spike_mode else self.distance_initial
            new_sl = self.lowest_price * (1.0 + distance)
            
            # Arrondir
            symbol_info = mt5.symbol_info(self.symbol)
            if symbol_info is not None:
                tick_size = symbol_info.trade_tick_size
                new_sl = round(new_sl / tick_size) * tick_size
            
            # Appliquer si meilleur
            if pos.sl == 0.0 or new_sl < pos.sl - self.step_percent * current_price:
                request = {
                    "action": mt5.TRADE_ACTION_SLTP,
                    "position": self.position_ticket,
                    "sl": new_sl,
                    "tp": pos.tp,
                }
                
                result = mt5.order_send(request)
                if result is not None and result.retcode == mt5.TRADE_RETCODE_DONE:
                    print(f"✅ Trailing SL SELL: {new_sl:.5f} | "
                          f"Plus bas: {self.lowest_price:.5f} | "
                          f"Mode: {'SPIKE' if self.spike_mode else 'NORMAL'}")
```

### 🐍 Bot Complet (Python)

```python
import MetaTrader5 as mt5
import time

# Initialiser MT5
if not mt5.initialize():
    print("Erreur initialisation MT5")
    quit()

# Configuration
SYMBOL = "Boom 1000 Index"
SPIKE_THRESHOLD = 0.003  # 0.3%
CHECK_INTERVAL = 0.5     # 0.5 seconde

# Instances
spike_detector = SpikeDetector(SYMBOL, SPIKE_THRESHOLD, 5)
trailing = BoomCrashTrailingStop(SYMBOL)

print(f"🤖 Bot Boom/Crash démarré | {SYMBOL}")

try:
    while True:
        # 1. Détecter spike
        spike_detected, direction, spike_percent = spike_detector.detect_spike()
        
        if spike_detected:
            print(f"🎯 SPIKE DÉTECTÉ: {direction} | {spike_percent:.2f}%")
        
        # 2. Calculer probabilité spike
        if int(time.time()) % 10 == 0:  # Toutes les 10 secondes
            probability = spike_detector.calculate_spike_probability()
            if probability >= 0.75:
                print(f"⚠️ SPIKE IMMINENT: {probability*100:.1f}%")
        
        # 3. Gérer trailing stop sur positions ouvertes
        positions = mt5.positions_get(symbol=SYMBOL)
        if positions is not None and len(positions) > 0:
            for pos in positions:
                if trailing.position_ticket != pos.ticket:
                    trailing.init(pos.ticket)
                
                trailing.update(spike_detected)
        
        # Attendre
        time.sleep(CHECK_INTERVAL)

except KeyboardInterrupt:
    print("\n🛑 Bot arrêté")
    mt5.shutdown()
```

---

## 5. Stratégies Avancées

### 🎯 Stratégie 1 : Spike + Retracement

```
1. Détecter spike (ex: Boom +0.8% en 3s)
2. Attendre retracement 30-50% du spike
3. Entrer dans le sens du spike
4. TP = Extension 127.2% du spike
5. SL = Bas du retracement
```

### 🎯 Stratégie 2 : Double Spike

```
1. Détecter 1er spike
2. Fermer position immédiatement (bank 0.10$+)
3. Si proba spike ≥ 85% dans les 60s suivantes
4. Réentrer (2e spike imminent)
5. Trailing agressif dès entrée
```

### 🎯 Stratégie 3 : Spike Antipathique

```
1. Boom: Position SELL ouverte
2. Spike BUY détecté → Fermer IMMÉDIATEMENT
3. Ne pas réentrer contre spike
4. Attendre fin de momentum (30-60s)
```

### 🎯 Stratégie 4 : Scalping Spike

```
1. Proba spike ≥ 75%
2. Ouvrir position préventive (mini lot 0.01)
3. Si spike confirmé → Pyramider (+0.02 lot)
4. TP total = 0.15$ (rapide)
5. SL = -0.05$ (serré)
```

---

## 📊 Tableau Récapitulatif

| Critère | Valeur Recommandée | Notes |
|---------|-------------------|-------|
| **Seuil spike** | 0.3% en 5s | Boom/Crash 500: 0.4% |
| **Proba spike alerte** | ≥ 75% | Notification push |
| **Trailing initial** | 0.15% | Laisser respirer |
| **Trailing spike** | 0.10% | Agressif après spike |
| **Step** | 0.05% | Suit chaque mouvement |
| **Profit min (spike mode)** | 0.10$ | Avant mode agressif |
| **Cooldown spike** | 30s | Entre 2 détections |

---

## 🚀 Prochaines Étapes

1. **Tester en Démo** : Valider détection + trailing
2. **Optimiser Seuils** : Boom 500 vs 1000 vs Crash
3. **Backtester** : 3 mois historique minimum
4. **Live Petit Lot** : 0.01 lot pour validation
5. **Scaler** : Augmenter lots progressivement

---

**Date** : 2025-05-14
**Compatibilité** : MT5 + Python 3.8+
**Symboles** : Boom 500/1000, Crash 500/1000
