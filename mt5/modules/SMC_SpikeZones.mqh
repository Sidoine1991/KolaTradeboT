//+------------------------------------------------------------------+
//| SMC_SpikeZones.mqh - Spike Zone Clustering System                     |
//| Les spikes clusterisent près des zones S/R - tracking statistique      |
//| Basé sur recherche: spikes souvent aux mêmes niveaux                  |
//+------------------------------------------------------------------+
#ifndef SMC_SPIKE_ZONES_MQH
#define SMC_SPIKE_ZONES_MQH

#define SPIKE_ZONE_MAX 20

struct SMC_SpikeZone
{
   double   priceLevel;
   int      spikeCount;
   datetime lastSpikeTime;
   double   avgSpikeSize;
   double   totalSpikeSize;
   bool     isActive;
};

SMC_SpikeZone g_spikeZones[SPIKE_ZONE_MAX];
// g_spikeZoneCount est déclaré dans SMC_Universal.mq5, on utilise une variable locale ici
int g_spikeZoneCountLocal = 0;

//+------------------------------------------------------------------+
//| Initialiser le système de zones de spikes                            |
//+------------------------------------------------------------------+
void SMC_SZ_Init()
{
   for(int i = 0; i < SPIKE_ZONE_MAX; i++)
   {
      ZeroMemory(g_spikeZones[i]);
   }
   g_spikeZoneCountLocal = 0;
}

//+------------------------------------------------------------------+
//| Enregistrer un spike dans une zone                                   |
//+------------------------------------------------------------------+
void SMC_SZ_RegisterSpike(const double price, const double spikeSize)
{
   // Trouver ou créer une zone proche (±20 points)
   int foundIndex = -1;
   for(int i = 0; i < g_spikeZoneCountLocal; i++)
   {
      if(MathAbs(g_spikeZones[i].priceLevel - price) < 20)
      {
         foundIndex = i;
         break;
      }
   }
   
   if(foundIndex >= 0)
   {
      // Mettre à jour la zone existante
      g_spikeZones[foundIndex].spikeCount++;
      g_spikeZones[foundIndex].totalSpikeSize += spikeSize;
      g_spikeZones[foundIndex].avgSpikeSize = g_spikeZones[foundIndex].totalSpikeSize / g_spikeZones[foundIndex].spikeCount;
      g_spikeZones[foundIndex].lastSpikeTime = TimeCurrent();
      g_spikeZones[foundIndex].isActive = true;
   }
   else
   {
      // Créer une nouvelle zone
      if(g_spikeZoneCountLocal < SPIKE_ZONE_MAX)
      {
         g_spikeZones[g_spikeZoneCountLocal].priceLevel = price;
         g_spikeZones[g_spikeZoneCountLocal].spikeCount = 1;
         g_spikeZones[g_spikeZoneCountLocal].totalSpikeSize = spikeSize;
         g_spikeZones[g_spikeZoneCountLocal].avgSpikeSize = spikeSize;
         g_spikeZones[g_spikeZoneCountLocal].lastSpikeTime = TimeCurrent();
         g_spikeZones[g_spikeZoneCountLocal].isActive = true;
         g_spikeZoneCountLocal++;
         
         Print("[SZ] Nouvelle zone créée @ ", DoubleToString(price, 2));
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est proche d'une zone de spike                   |
//+------------------------------------------------------------------+
bool SMC_SZ_IsNearSpikeZone(const double price, const double tolerance = 15)
{
   for(int i = 0; i < g_spikeZoneCountLocal; i++)
   {
      if(!g_spikeZones[i].isActive) continue;
      
      if(MathAbs(g_spikeZones[i].priceLevel - price) < tolerance)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Obtenir la zone de spike la plus proche                              |
//+------------------------------------------------------------------+
SMC_SpikeZone SMC_SZ_GetNearestZone(const double price)
{
   SMC_SpikeZone nearest;
   ZeroMemory(nearest);
   
   double minDist = DBL_MAX;
   
   for(int i = 0; i < g_spikeZoneCountLocal; i++)
   {
      if(!g_spikeZones[i].isActive) continue;
      
      double dist = MathAbs(g_spikeZones[i].priceLevel - price);
      if(dist < minDist)
      {
         minDist = dist;
         nearest = g_spikeZones[i];
      }
   }
   
   return nearest;
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de spikes dans une zone                            |
//+------------------------------------------------------------------+
int SMC_SZ_GetZoneSpikeCount(const double price, const double tolerance = 15)
{
   for(int i = 0; i < g_spikeZoneCountLocal; i++)
   {
      if(!g_spikeZones[i].isActive) continue;
      
      if(MathAbs(g_spikeZones[i].priceLevel - price) < tolerance)
      {
         return g_spikeZones[i].spikeCount;
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Obtenir la taille moyenne des spikes dans une zone                     |
//+------------------------------------------------------------------+
double SMC_SZ_GetZoneAvgSpikeSize(const double price, const double tolerance = 15)
{
   for(int i = 0; i < g_spikeZoneCountLocal; i++)
   {
      if(!g_spikeZones[i].isActive) continue;
      
      if(MathAbs(g_spikeZones[i].priceLevel - price) < tolerance)
      {
         return g_spikeZones[i].avgSpikeSize;
      }
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Nettoyer les zones inactives (plus de spikes depuis 30 minutes)      |
//+------------------------------------------------------------------+
void SMC_SZ_CleanupInactiveZones()
{
   datetime cutoff = TimeCurrent() - 1800;  // 30 minutes
   
   for(int i = 0; i < g_spikeZoneCountLocal; i++)
   {
      if(g_spikeZones[i].isActive && g_spikeZones[i].lastSpikeTime < cutoff)
      {
         g_spikeZones[i].isActive = false;
         Print("[SZ] Zone désactivée @ ", DoubleToString(g_spikeZones[i].priceLevel, 2));
      }
   }
}

//+------------------------------------------------------------------+
//| Obtenir le niveau de risque basé sur les zones de spikes            |
//+------------------------------------------------------------------+
double SMC_SZ_GetZoneRiskLevel(const double price)
{
   SMC_SpikeZone nearest = SMC_SZ_GetNearestZone(price);
   
   if(nearest.spikeCount == 0) return 0.0;
   
   double distance = MathAbs(nearest.priceLevel - price);
   
   // Plus proche + plus de spikes = risque élevé
   double proximityRisk = (1.0 - MathMin(distance / 50.0, 1.0)) * 50;
   double frequencyRisk = MathMin(nearest.spikeCount * 10, 50);
   
   return MathMin(100, proximityRisk + frequencyRisk);
}

//+------------------------------------------------------------------+
//| Réduire la position près des zones de spike à haute fréquence        |
//+------------------------------------------------------------------+
double SMC_SZ_GetPositionSizeMultiplier(const double price)
{
   double riskLevel = SMC_SZ_GetZoneRiskLevel(price);
   
   if(riskLevel > 70) return 0.5;
   if(riskLevel > 50) return 0.7;
   if(riskLevel > 30) return 0.85;
   
   return 1.0;
}

#endif // SMC_SPIKE_ZONES_MQH
