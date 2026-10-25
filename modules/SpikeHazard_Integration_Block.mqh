//+------------------------------------------------------------------+
//| SPIKE HAZARD — bloc a integrer dans SMC_Universal.mq5            |
//| VERSION FINALE — modele entraine sur Boom500 M1 reel (790k barres)|
//| Direction confirmee: CLUSTERING (risque elevee juste apres un     |
//| spike, PAS un cooldown). Voir Boom500_spike_hazard.json.          |
//|                                                                    |
//| IMPORTANT: le modele est BAR-LEVEL (M1), pas tick-level. Ce bloc  |
//| compte donc des BARRES depuis le dernier spike, pas des ticks —   |
//| c'est l'unite sur laquelle le modele a ete entraine et validé.    |
//| Si un jour un modele tick-level est valide (via ExportTickHistory |
//| + train_spike_hazard.py SANS --bar-level), il faudra un bloc      |
//| distinct comptant les ticks, avec son propre polling plus frequent|
//|                                                                    |
//| INTEGRATION:                                                      |
//|  1. Coller ce bloc dans SMC_Universal.mq5 (avant OnTick).         |
//|  2. Dans OnInit(): appeler SH_Init();                            |
//|  3. Dans OnTick(): appeler SH_OnTick(); en tout debut de fonction |
//|  4. Dans OnDeinit(): appeler SH_Cleanup();                       |
//+------------------------------------------------------------------+

input group "=== SPIKE HAZARD (clustering post-spike, modele M1 Boom500) ==="
input bool   SH_Enabled            = true;   // Activer le module spike hazard
input double SH_KSigma             = 8.0;    // Seuil detection spike (x sigma local sur delta M1), DOIT matcher train_spike_hazard.py
input int    SH_BufferSize         = 200;    // Taille buffer roulant (en barres) pour ecart-type local
input int    SH_PollIntervalMs     = 2000;   // Frequence d'appel serveur (ms) — modele bar-level, pas besoin de plus frequent
input bool   SH_ShowOnChart        = true;   // Afficher le label sur le graphique

// --- Etat interne ---
// Le compteur avance a CHAQUE NOUVELLE BARRE M1, pas a chaque tick — sinon
// l'echelle envoyee au serveur ne correspondrait plus a celle du modele
// (n_grid du JSON va de 0.7 a ~1431 "barres", pas de ticks).
double   g_SH_closeBuffer[];
int      g_SH_bufferIdx        = 0;
int      g_SH_bufferCount      = 0;
datetime g_SH_lastBarTime      = 0;
double   g_SH_lastClose        = 0.0;
long     g_SH_barsSinceLastSpike = 0;
ulong    g_SH_lastPollMs       = 0;

bool     g_SH_available   = false;
double   g_SH_hazardPct   = 0.0;
string   g_SH_regime      = "N/A";

#define SH_LABEL_NAME "SH_SpikeHazardLabel"

//+------------------------------------------------------------------+
void SH_Init()
{
   ArrayResize(g_SH_closeBuffer, MathMax(SH_BufferSize, 10));
   ArrayInitialize(g_SH_closeBuffer, 0.0);
   g_SH_bufferIdx   = 0;
   g_SH_bufferCount = 0;
   g_SH_lastBarTime = iTime(_Symbol, PERIOD_M1, 0);
   g_SH_lastClose   = 0.0;
   g_SH_barsSinceLastSpike = 0;
   g_SH_lastPollMs  = 0;
}

//+------------------------------------------------------------------+
void SH_Cleanup()
{
   if(ObjectFind(0, SH_LABEL_NAME) >= 0)
      ObjectDelete(0, SH_LABEL_NAME);
}

//+------------------------------------------------------------------+
double SH_LocalSigma()
{
   if(g_SH_bufferCount < 10) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < g_SH_bufferCount; i++) sum += g_SH_closeBuffer[i];
   double mean = sum / g_SH_bufferCount;
   double sq = 0.0;
   for(int i = 0; i < g_SH_bufferCount; i++) sq += MathPow(g_SH_closeBuffer[i] - mean, 2);
   return MathSqrt(sq / g_SH_bufferCount);
}

//+------------------------------------------------------------------+
// A appeler en tout debut de OnTick() — ne fait le travail que sur       |
// nouvelle barre M1 (modele bar-level). Polling serveur separe/throttle.|
//+------------------------------------------------------------------+
void SH_OnTick()
{
   if(!SH_Enabled) return;

   datetime curBarTime = iTime(_Symbol, PERIOD_M1, 0);
   if(curBarTime != g_SH_lastBarTime)
   {
      SH_OnNewBar();
      g_SH_lastBarTime = curBarTime;
   }

   ulong nowMs = GetTickCount64();
   if(nowMs - g_SH_lastPollMs >= (ulong)SH_PollIntervalMs)
   {
      g_SH_lastPollMs = nowMs;
      SH_PollServer();
   }

   if(SH_ShowOnChart)
      SH_UpdateChartLabel();
}

//+------------------------------------------------------------------+
// Traite la barre M1 qui vient de se cloturer (close de la barre[1])     |
//+------------------------------------------------------------------+
void SH_OnNewBar()
{
   double closedBarClose = iClose(_Symbol, PERIOD_M1, 1);
   if(closedBarClose <= 0) return;

   if(g_SH_lastClose == 0.0) { g_SH_lastClose = closedBarClose; return; }

   double delta = closedBarClose - g_SH_lastClose;
   g_SH_lastClose = closedBarClose;

   int cap = ArraySize(g_SH_closeBuffer);
   g_SH_closeBuffer[g_SH_bufferIdx % cap] = delta;
   g_SH_bufferIdx++;
   if(g_SH_bufferCount < cap) g_SH_bufferCount++;

   double sigma = SH_LocalSigma();
   bool isSpike = (sigma > 0.0) && (MathAbs(delta) > SH_KSigma * sigma);

   if(isSpike)
      g_SH_barsSinceLastSpike = 0;
   else
      g_SH_barsSinceLastSpike++;
}

//+------------------------------------------------------------------+
// Appel a /spike-hazard (endpoint leger non-cache, cf ai_server.py)      |
// Le parametre s'appelle 'n_ticks_since_last_spike' cote API (nom herite |
// de la conception initiale tick-level) mais transporte ici un compte   |
// de BARRES — coherent avec le modele Boom500 charge cote serveur.      |
//+------------------------------------------------------------------+
void SH_PollServer()
{
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");

   string url = AI_ServerURL + "/ml/spike-hazard?symbol=" + symEnc +
                "&n_ticks_since_last_spike=" + IntegerToString(g_SH_barsSinceLastSpike);
   string headers = "";
   char post[], result[];
   string resultHeaders;

   int res = WebRequest("GET", url, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(res != 200)
   {
      g_SH_available = false;
      return;
   }

   string json = CharArrayToString(result);
   string availStr = ExtractJsonValue(json, "spike_hazard_available");
   g_SH_available = (availStr == "true");

   if(g_SH_available)
   {
      g_SH_hazardPct = StringToDouble(ExtractJsonValue(json, "spike_hazard_pct"));
      g_SH_regime    = ExtractJsonValue(json, "spike_hazard_regime");
   }
   else
   {
      g_SH_hazardPct = 0.0;
      g_SH_regime    = "N/A";
   }
}

//+------------------------------------------------------------------+
// Affichage chart — label autonome (pas besoin du dashboard GOM)         |
// ELEVATED_RISK = regime confirme sur donnees reelles (clustering).      |
// COOLDOWN_ACTIVE = conserve pour compat si un futur modele/symbole      |
// detecte un jour l'autre direction.                                     |
//+------------------------------------------------------------------+
void SH_UpdateChartLabel()
{
   if(ObjectFind(0, SH_LABEL_NAME) < 0)
   {
      ObjectCreate(0, SH_LABEL_NAME, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, SH_LABEL_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, SH_LABEL_NAME, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, SH_LABEL_NAME, OBJPROP_YDISTANCE, GOMDashboardY + 40);
      ObjectSetInteger(0, SH_LABEL_NAME, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, SH_LABEL_NAME, OBJPROP_FONT, "Consolas");
   }

   string text;
   color clr;

   if(!g_SH_available)
   {
      text = StringFormat("SPIKE HAZARD: N/A (modele non valide) | n=%d barres", g_SH_barsSinceLastSpike);
      clr = clrGray;
   }
   else if(g_SH_regime == "ELEVATED_RISK")
   {
      text = StringFormat("SPIKE HAZARD: %.2f%% [RISQUE ELEVE] | n=%d barres", g_SH_hazardPct, g_SH_barsSinceLastSpike);
      clr = clrOrangeRed;
   }
   else if(g_SH_regime == "COOLDOWN_ACTIVE")
   {
      text = StringFormat("SPIKE HAZARD: %.2f%% [COOLDOWN] | n=%d barres", g_SH_hazardPct, g_SH_barsSinceLastSpike);
      clr = clrOrange;
   }
   else
   {
      text = StringFormat("SPIKE HAZARD: %.2f%% [NORMAL] | n=%d barres", g_SH_hazardPct, g_SH_barsSinceLastSpike);
      clr = clrLimeGreen;
   }

   ObjectSetString(0, SH_LABEL_NAME, OBJPROP_TEXT, text);
   ObjectSetInteger(0, SH_LABEL_NAME, OBJPROP_COLOR, clr);
}
