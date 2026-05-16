#ifndef GOM_KOLA_SIDO_CORE_MQH
#define GOM_KOLA_SIDO_CORE_MQH

// Trade.mqh déjà inclus par SMC_Universal.mq5

input group "SCANNER MULTI-SYMBOLES TEMPS RÉEL"
input bool   EnableOpportunityScanner = true;      // Activer le scanner d'opportunités
input string ScannerSymbolsList = "Boom 1000 Index,Crash 1000 Index,Volatility 75 Index,Volatility 100 Index,Step Index,EURUSD,GBPUSD,XAUUSD";  // Liste des symboles à scanner (séparés par des virgules)
input int    ScannerRefreshSeconds = 2;            // Intervalle de scan (secondes)
input int    ScannerPanelX = 10;                   // Position X du panneau
input int    ScannerPanelY = 30;                   // Position Y du panneau
input int    ScannerPanelWidth = 500;              // Largeur du panneau
input int    ScannerRowHeight = 25;                // Hauteur des lignes
input bool   ScannerShowPanel = true;              // Afficher le panneau graphique

input group "TRADING AUTOMATIQUE (SCANNER)"
input bool   EnableScannerAutoTrading = true;      // Activer trading automatique sur opportunités scannées
input double AutoTradeMaxRiskDollars = 0.50;       // Risque maximum par trade ($) - Pour capital 10$ = 0.50$ max
input double AutoTradeScalpTpPoints = 50;          // Take Profit scalping (points)
input double AutoTradeScalpSlPoints = 30;          // Stop Loss scalping (points)
input bool   EnableAutoTrailingStop = true;        // Activer trailing stop automatique
input double AutoTrailingStopPoints = 20;          // Distance trailing stop (points)
input double AutoTrailingStepPoints = 5;           // Pas de déplacement trailing (points)
input int    AutoTradeNotifyIntervalMin = 10;      // Intervalle notifications push (minutes)

input group "TIMEFRAMES"
input bool ShowM1Levels = true;   // Activé pour entrées précises M1
input bool ShowM5Levels = true;   // Activé pour niveaux M5
input bool ShowM15Levels = true;  // Activé pour confirmation M15
input bool ShowM30Levels = true;  // Activé pour structure M30
input bool ShowH1Levels = true;   // Activé pour tendance H1
input bool ShowH4Levels = true;   // Activé pour tendance H4
input bool ShowD1Levels = true;   // Activé pour niveaux journaliers
input bool ShowW1Levels = true;   // Niveaux W1 (structure long terme)

input group "ALGORITHM (THREE LINE BREAK)"
input int  LineBreakPeriod = 3;
input int  MaxBarsToAnalyze = 300;

input group "TOUCH SYSTEM"
input bool   EnableTouchDetection = true;   // Activé pour détection de touch
input double TouchZoneATRPercent = 30.0;    // Augmenté pour plus de sensibilité
input int    BarsForTouchCount = 150;       // Réduit pour plus de réactivité
input int    MinLineWidth = 1;
input int    MaxLineWidth = 5;
input int    TouchesForMaxWidth = 8;        // Réduit pour plus de précision

input group "PARAMETRES D'AFFICHAGE KOLA"
input bool  ShowLabels = true;
input bool  ShowTouchCount = true;
input int   LabelShiftBars = 3;
input color BuyLevelColor = clrLimeGreen;
input color SellLevelColor = clrRed;

input group "MODULE SIDO (FIGURES CHARTISTES)"
input bool   EnableSIDO = true;
input int    SIDOPivotLookback = 3;
input int    SIDOBarsToAnalyze = 300;
input int    SIDOMaxBarsBetweenSwings = 80;
input double SIDOToleranceATRPercent = 35.0;
input color  SIDODoubleTopColor = clrOrangeRed;
input color  SIDODoubleBottomColor = clrDeepSkyBlue;
input bool   ShowSIDOLabels = true;
input bool   ShowBottomDashboard = true;
input bool   EnableChartLeftShift = false;      // Décalage chart (désactivé en mode OTE+Fibo léger)
input bool   EnableChartAutoscroll = true;      // Défilement auto (plus d'objets visibles au fil du prix)
input double ChartLeftShiftPct = 45.0;          // Largeur zone future augmentée (Shift 45%)
input bool   ShowPastFutureSeparator = false;   // Zone PASSE / FUTUR + rectangle (désactivé par défaut = graphique plus lisible)
input int    FutureZoneBars = 40;               
input color  FutureZoneFillColor = 0x121212;    // Gris très foncé (presque noir) pour discrétion
input int    DashboardBottomOffset = 25;        
input int    DashboardLeftOffset = 10;
input int    DashboardNudgeLeftPx = 56;
input int    DashboardTopRowShiftRightPx = 130; 
input int    DashboardTopRowExtraGap = 1;       // Espace très fin
input int    DashboardFontSize = 9;             // Parfait pour la taille de cellule
input int    DashboardStripFontDelta = 0;  
input color  DashboardTextColor = clrWhite;
input int    DashboardCellWidth = 100;          
input int    DashboardCellHeight = 30;          // Hauteur TradingView
input int    DashboardCellGap = 1;              // Grille très serrée comme TV
input int    DashboardMetaRowHeight = 30;
input int    DashboardSummaryCellWidth = 280; 
input int    DashboardVerdictExtraWidth = 100; 
input int    DashboardVerdictRowHeight = 30;    
input bool   DashboardTvFullWidthBar = true;    
input int    DashboardBarMarginLeft = 8;       
input int    DashboardBarMarginRight = 8;      
input color  DashboardCellBorderColor = 0x303030; // Bordure Grid TV
input int    DashboardLabelZOrder = 520;       
input color  DashboardVerdictBorderColor = 0x303030;
input bool   ShowDashboardBackgroundBand = true;  
input double DashboardVolOnMinAtrPct = 0.06; 
input double DashboardAtrOkMinAtrPct = 0.04;   
input string DashboardScriptVersion = "GOM v1.3";
input bool   ShowM1Forecast500Strip = false;    // Bandeau projection M1×500
input bool   ShowM1Forecast500ChartOverlay = false; 
input int    M1ForecastChartBarsDraw = 80;    
input bool   M1ForecastForceChartShift = true; 
input double M1ForecastChartShiftPct = 25.0;   
input int    M1ForecastRegressionBars = 200; 
input double M1ForecastMaxAbsPct = 35.0;    
input bool   DashboardCompactVerdictOnly = true; // Bandeau compact 2 rangées (verdict+MTF | méta)
input bool   DashboardCompactSpanChartWidth = true; // compact : occuper la largeur utile du graphique (marges L/R)
input int    DashboardCompactBottomMetaHeight = 21; // hauteur rangée basse (synthèse texte)
input int    DashboardCompactWidth = 450;        
input bool   DashboardIndicatorsAnchorBottomRight = true; 
input bool   DashboardCompactAnchorBottomRight = true;     
input int    DashboardSecondaryRightMargin = 15;          
input bool   ShowDashboardExtraIndicators = false; // Bandeau secondaire VOL/ATR (désactivé = moins chargé)
input bool   EnableSpikePrediction = true;
input int    SpikeLookbackBarsM1 = 20;          // Réduit pour plus de réactivité
input double SpikeAlertMinProbability = 0.45;   // Réduit pour plus de signaux
input double SpikeBypassMinProbability = 0.40; // Réduit pour ne pas rater les spikes
input double SpikeBlinkMinProbability = 0.35;  // Réduit pour alertes précoces
input double SpikeBlinkLeadThAdjMax = 0.20;    // Augmenté pour détection plus précoce
input bool   SpikeModeBypassStrict = true;      // Assouplir les verrous stricts pendant un spike valide
input bool   EnableDoubleSpikeCapture = true;   // sur S/R M5-M15-H1: garder la position pour capter un 2e spike proche
input int    DoubleSpikeWindowBars = 2;         // Augmenté pour plus de fenêtre de capture
input double DoubleSpikeNearLevelAtr = 0.75;    // Augmenté pour plus de tolérance
input double DoubleSpikeMinProb = 0.42;         // Réduit pour plus de sensibilité
input int    DoubleSpikeHoldSeconds = 90;      // Augmenté pour maximiser le 2e spike

input group "FERMETURE AUTO: spike capté (même logique que cleanup GOM)"
input bool   EnableAutoClosePositionsOnSpikeCaptured = true; // Fermer positions au marché quand BUY/SELL entry GOM est « franchi » (spike capté)
input long   SpikeCapturedCloseMagicFilter = 0; // 0 = toutes les positions sur ce symbole ; sinon magic exact (ex. même que SMC_Universal InpMagicNumber) — DÉFAUT 0 pour capturer toutes positions
input int    SpikeCapturedMinPositionAgeSec = 1; // Âge min (s) de la position avant fermeture (évite conflit avec ordre qui vient de partir) — RÉDUIT à 1s pour réactivité
input int    SpikeCapturedCloseDeviation = 80; // Déviation points pour PositionClose
input double GomEntryCrossCloseMinProfitUSD = 0.0; // P/L net ($) min pour fermer au franchissement ligne GOM ; 0 = ferme même en perte légère (RECOMMANDÉ pour spike capté)
input bool   GomSpikeCapturedCloseAnyProfit = true; // Si true : niveau GOM franchi + sens aligné → ferme dès P/L net > 0 (ignore le seuil ci-dessus ; recommandé avec notification « spike capturé »)
input bool   GomEntryCrossKeepPlanIfNoClose = true; // franchissement niveau mais P/L < min : ne pas effacer le plan GOM
input bool   SpikeClosedNotifyOnlyExactSpike = true; // notification « Spike fermé » uniquement si vrai motif spike + gain ≥ seuil
input double SpikeClosedNotifyMinProfitUSD = 0.10; // $ — évite « spike fermé » sur micro-gain ou fermeture « profil scalping »
input bool   SpikeAutoCloseAllowLightLossExit = true; // si true : ferme aussi sur perte légère (≤ -0,50$) dans ManageBoomCrashSpikeClose — ACTIVÉ pour fermer rapidement
input bool   SpikeCapturedRequireRealSpike = true; // Exiger mouvement rapide prix (0.3% en 5s) avant fermeture spike — ÉVITE fausses alertes sans position

input bool   EnableExternalAIInterpretation = false; // /gom/interpret (optionnel, hors verdict GOM)
input string ExternalAIUrl = "http://127.0.0.1:8000/gom/interpret";
input int    ExternalAITimeoutMs = 1800;
input int    ExternalAIThrottleMs = 2000;
input int    RobotAIStaleSeconds = 90;
input bool   KeepScriptAttached = true;
input int    RefreshSeconds = 1;              // Réduit pour plus de réactivité

input group "PERFORMANCE (throttle boucles)"
input int    TfRefreshSeconds_M1  = 2;    // Recalcul M1 (KOLA/SIDO) toutes les N secondes
input int    TfRefreshSeconds_M5  = 5;    // Recalcul M5
input int    TfRefreshSeconds_M15 = 10;   // Recalcul M15
input int    TfRefreshSeconds_M30 = 15;   // Recalcul M30
input int    TfRefreshSeconds_H1  = 30;   // Recalcul H1
input int    TfRefreshSeconds_H4  = 60;   // Recalcul H4
input int    TfRefreshSeconds_D1  = 120;  // Recalcul D1
input int    TfRefreshSeconds_W1  = 300;  // Recalcul W1
input int    SMCProcessRefreshSeconds = 2; // Traitement ICT/SMC toutes les N secondes
input int    ScriptEmaRefreshSeconds  = 5; // Courbe EMA (objets) toutes les N secondes
input int    BollingerVwapRefreshSeconds = 5; // BB+VWAP (calcul + courbe) toutes les N secondes
input int    DashboardRefreshSeconds = 1; // Dashboard + publications GV toutes les N secondes
input bool   AutoScaleRefreshByCharts = true; // Ajuste automatiquement les périodes quand plusieurs symboles sont attachés
input int    ChartsPerLoadStep = 3; // +1 facteur de charge tous les N charts
input int    MaxAutoScaleFactor = 6; // Limite du facteur auto (évite de trop ralentir)
input bool   StaggerExecutionBySymbol = true; // Décale les cycles par symbole pour lisser les pics CPU
input group "NOTIFICATIONS (alerte + son + push MT5)"
input bool   EnableGomNotifyAlerts = true;
input bool   NotifyOnNewPosition = true;
input bool   NotifyOnSpikeAutoPendingOk = true;
input bool   NotifyOnSpikeSignalArmed = true; // SPIKE BUY/SELL avec proba ≥ SpikeAlertMinProbability (réarme si retour sous seuil)
input long   NotifyPositionMagic = 0; // 0 = toute position sur le symbole du graphique
input string NotifySoundNewPosition = "place_order.wav";
input string NotifySoundSpike = "alert.wav";
input bool   ShowScriptEMAs = true;
input ENUM_TIMEFRAMES ScriptEmaTF = PERIOD_M5;
input int    ScriptEmaCurveBars = 320; // nombre de barres pour dessiner la courbe (segments OBJ_TREND)

input group "BOLLINGER + VWAP (projection graphe + verdict)"
input bool   ShowBollingerBands = true;
input ENUM_TIMEFRAMES BollingerTF = PERIOD_M5;
input int    BollingerPeriod = 20;
input double BollingerDeviation = 2.0;
input int    BollingerCurveBars = 320;
input color  BollingerUpperColor = clrCornflowerBlue;
input color  BollingerMidColor = clrSilver;
input color  BollingerLowerColor = clrCornflowerBlue;
input bool   ShowSessionVWAP = true;
input color  VWAPLineColor = clrGold;
input int    VWAPCurveBars = 960; // M1: barres max pour la courbe VWAP journée
input bool   BollingerVwapInfluenceVerdict = true; // intègre BB + VWAP au score techBuy/techSell
input double BollingerVwapVerdictWeight = 1.0;     // 1 = pondération par défaut ; 0 = pas d’effet

input group "INDICATEURS AVANCÉS (style TradingView, légers)"
input bool   EnableAdvancedIndicators = true;
input ENUM_TIMEFRAMES AdvancedIndicatorsTF = PERIOD_M5;
input int    AdvancedIndicatorsRefreshSeconds = 5; // throttle calcul (anti-lag)
input int    SupertrendAtrPeriod = 10;
input double SupertrendAtrMult = 3.0;
input int    KeltnerEmaPeriod = 20;
input double KeltnerAtrMult = 1.5;
input int    DonchianPeriod = 20;
input bool   AdvancedIndicatorsInfluenceVerdict = true;
input double AdvancedIndicatorsVerdictWeight = 0.8;

input group "INFOS IA / ML (FEAT_* + serveur /decision — label flottant)"
input bool   ShowMLFeatureInfo = true;   // Publie toujours FEAT_* ; affichage selon MLInfoUseDashboardCells / flottant
input bool   MLInfoUseDashboardCells = true; // réservé compatibilité (dash plein = toujours 18 cellules sur 1 ligne)
input int    MLFeatureInfoMarginRight = 10;  // label flottant uniquement si cellules désactivées ou mode compact
input int    MLFeatureInfoMarginBottom = 96;
input int    MLFeatureFontSize = 8;
input int    MLFeatureInfoZOrder = 120;

input group "FILTRES DE CONFIRMATION"
input bool   EnableVolumeFilter = true;
input double VolumeMinRatio = 1.0;              // Réduit pour plus de signaux
input int    VolumeLookback = 15;               // Réduit pour plus de réactivité
input bool   EnableMomentumFilter = true;
input bool   EnableRSIDivergenceFilter = true;
input int    RSIDivergenceLookback = 3;         // Réduit pour détection plus rapide
input double RSIDivergenceThreshold = 3.0;      // Réduit pour plus de sensibilité
input bool   EnableMTFFilter = true;
input bool   EnableStructureFilter = true;
input double StructureATRMultiplier = 0.7;      // Augmenté pour plus de tolérance
input bool   EnableVolatilityFilter = true;
input double VolatilityMinATRPct = 0.02;        // Réduit pour plus d'opportunités
input bool   StrictConfluenceMode = false;      // Désactivé pour plus de flexibilité
input double MinFilterPassRatio = 0.35;         // Réduit pour plus de signaux
input bool   RelaxedFiltersHighVolSynth = true; // Volatility / Step… : seuils filtres assouplis (évite WAIT permanent)
input double MinFilterQualityRelaxed = 0.10;    // Réduit pour plus de flexibilité
input bool   RequireMTFAndStructure = false;    // Désactivé pour plus d'opportunités
input double MinStrengthForEntry = 2.0;         // Réduit pour plus d'entrées
input bool   RelaxStrengthBoomCrashSpikeKola = true; // Boom+BUY / Crash+SELL : spike aligné + proche KOLA → bonus force + seuil abaissé
input double RelaxStrengthSpikeKolaBonus = 0.70;     // Augmenté pour plus de bonus
input double RelaxStrengthSpikeKolaMinCap = 1.0;     // Réduit pour plus de flexibilité
input bool   RequireMinConfidenceForHtfEntry = false; // Désactivé pour plus d'opportunités
input double MinConfidenceHtfEntryPct = 60.0;          // % min réduit
input double KolaClosestAnchorMaxAtr = 1.50;           // Augmenté pour plus de tolérance

input group "QUALITÉ D'ENTRÉE (évite setups faibles)"
input bool   EnableEntryQualityGate = false;           // Désactivé pour maximiser les opportunités
input double MinEntryQualityScore = 0.30;              // Seuil réduit pour plus d'entrées
input bool   EntryQualityGateSynthOnly = false;        // Désactivé pour tous symboles
input bool   EntryQualityRelaxOnSpikeSetup = true;    // true = ne pas bloquer si spike aligné + proba ≥ SpikeAlertMinProbability
input bool   EntryQualityRelaxOnHighConfluence = true; // true = ne pas bloquer si confluence niveaux ≥ seuil (prix sur zone KOLA)
input double EntryQualityConfluenceRelaxMin = 0.20;     // Réduit pour plus de flexibilité

input group "AUTO PENDING: SPIKE + NEAR M5 (Boom / Gainx / Crash / Painx)"
input bool   EnableSpikeNearM5AutoPending = true;  // ACTIVÉ pour trading automatique
input bool   SpikeNearM5DeferToArrowFirstPending = true; // true = ne pas placer ici si l'entrée se fait sur 1ère flèche (évite ordre avant la flèche)
input double SpikeNearM5Lots = 0.02;              // Augmenté pour plus de profit
input int    SpikeNearM5OffsetPoints = 3;          // Réduit pour entrée plus rapide
input double SpikeNearM5MinSpikeProb = 0.0;        // 0 = même seuil que SpikeAlertMinProbability
input int    SpikeNearM5CooldownSec = 30;          // Réduit pour plus d'opportunités
input long   SpikeNearM5Magic = 91305701;
input int    SpikeNearM5MaxSamePending = 2;        // Augmenté pour plus de positions
input bool   SpikeNearM5SkipIfSpikeExhausted = false; // Désactivé pour plus d'opportunités
input string SpikeNearM5Comment = "GOM_SKM5";

input group "AUTO PENDING: 1ère apparition flèche SPIKE IMMINENT"
input bool   EnableSpikeImminentFirstAutoPending = true;  // ACTIVÉ pour trading automatique
input bool   SpikeImminentFirstUseMarketOrder = false;    // false = pending (Limit/Stop) ; true = marché
input bool   SpikeImminentPendingRequireNearM5 = true;   // true = prix proche M5 BUY/SELL (comme spike+M5)
input bool   SpikeImminentFirstTriggerOnPlanArrowRise = true; // 1ère apparition flèche plan GOM_PLAN_ARROW (LIVE BUY/SELL) + même logique pending
input bool   SpikeImminentFirstForceLimitOnly = true;     // si niveau M5 valide : uniquement BuyLimit/SellLimit (prix recalé sous/au-dessus du marché si besoin)
input bool   SpikeImminentFirstSkipDoubleSpikePhase2 = true; // true = pas d'ordre si DOUBLE_SPIKE_PHASE >= 2 (2e spike)
input int    SpikeImminentFirstCooldownSec = 45;         // Réduit pour plus d'opportunités
input long   SpikeImminentFirstMagic = 91305702;
input string SpikeImminentFirstComment = "GOM_SKIM";

input group "AUTO MARCHÉ: 1ère apparition GOM_PLAN_ARROW (plan LIVE BUY/SELL)"
input bool   EnableAutoMarketOnGomPlanArrow = true;   // true = ouvre position au marché dès la flèche plan (prioritaire sur pending spike sur même front)
input int    GomPlanArrowMarketCooldownSec = 90;       // Anti double entre 2 entrées flèche plan
input double GomPlanArrowMarketLots = 0.02;          // Lot (normalisé min/step/max broker)
input bool   GomPlanArrowRespectMaxPositions = true; // 1 position max / symbole (magic EA)
input bool   GomPlanArrowBypassBoomCrashIaAlignment = true; // true = ne pas exiger IA=BUY/SELL alignée (le plan GOM prime)
input bool   GomPlanArrowRequireChartArrowObject = true; // true = exiger que l'objet GOM_PLAN_ARROW existe sur le chart
input bool   GomPlanArrowRespectSmcSweepConflict = true; // Boom: pas de BUY si sweep SELL SMC récent (GV + flèches SMC_SWEEP_SELL_) ; Crash: pas de SELL si sweep BUY récent
input int    GomPlanArrowSweepConflictMaxAgeSec = 240;   // Âge max (s) des flèches sweep opposées pour bloquer l'entrée alignée au plan
input bool   GomPlanArrowRequireNearKolaM5Entry = true;  // true = marché sur flèche plan seulement si prix proche du niveau d'entrée (BUY_ENTRY / M5 BUY ou SELL_ENTRY / M5 SELL), pas à la seule apparition de la flèche
input double GomPlanArrowNearM5EntryMaxAtrMult = 0.50;   // distance max |prix - ref| ≤ ATR(M15)×ce coef (plancher = quelques points)
input bool   GomPlanArrowBuyCloserToBuySideM5 = true;   // Boom + plan BUY: le bid doit être plus proche du M5 BUY que du M5 SELL (évite achat collé au SELL ENTRY)
input bool   GomPlanArrowSellCloserToSellSideM5 = true; // Crash + plan SELL: symétrique (ask plus proche M5 SELL que M5 BUY)
input bool   BlockEntryIfNearOppositeM5KolaLine = true; // BUY annulé si prix proche M5 SELL KOLA (ligne rouge) ; SELL si proche M5 BUY (verte) — évite entrées « correction »
input double OppositeM5LineBlockMaxAtrMult = 0.55;       // |prix - niveau M5 opposé| ≤ ATR(M15)×ce coef ⇒ blocage (voir GOM_PriceNearLevel)
input bool   OppositeM5LineBlockBoomCrashOnly = true;    // true: indices Boom/Crash (± volatilité si option suivante) ; false: tout symbole avec GV KOLA M5
input bool   OppositeM5LineBlockIncludeVolatility = true; // si BoomCrashOnly: inclure aussi SYM_VOLATILITY (Step, V75, Gainx/Painx…)
// Fermeture : si une position BUY/SELL est ouverte et le prix rejoint la ligne M5 KOLA **opposée** (même logique que blocage entrée « correction »).
input bool   ClosePositionWhenPriceHitsOppositeM5KolaLine = true;
// Complément : lignes M5_ENTRY_BUY_LINE / M5_ENTRY_SELL_LINE sur le graphique où l'EA tourne (position sur _Symbol).
input bool   ClosePositionWhenTouchesDrawnM5EntryOpposite = true;
input int    OppositeM5LineExitMinHoldSec = 3; // Âge min (s) de la position avant fermeture (évite bruit au tick d'ouverture)

static datetime g_gomLastPlanArrowMarketTime = 0;

string DASH_PREFIX = "GOM_DASH_";
string GOM_F500V_PREFIX = "GOM_F500V_";
string g_lastPlanDir = "WAIT";
string g_lastPlanQuality = "WAIT";
double g_lastPlanEntry = 0.0;
double g_lastPlanSL = 0.0;
double g_lastPlanTP1 = 0.0;
double g_lastPlanTP2 = 0.0;
double g_lastPlanTP3 = 0.0;
double g_lastTechBuyScore = 0.0;
double g_lastTechSellScore = 0.0;
static datetime g_lastExtAiCall = 0;
static string   g_lastExtAiAction = "HOLD";
static double   g_lastExtAiConf = 0.0;
static string   g_lastExtAiReason = "";

CTrade          g_gomSpikeTrade;
static datetime g_gomLastSpikeCaptureCloseUtc = 0;
static datetime g_gomLastSpikeCapturedNoCloseNotifyUtc = 0;
static double   g_gomLastPriceForSpikeDetection = 0.0;  // Tracker mouvement prix pour spike réel
static datetime g_gomLastSpikeDetectionTime = 0;        // Timestamp dernière détection spike

static datetime g_gomLastSpikeM5PendingTime = 0;
static datetime g_gomLastSpikeImminentFirstTime = 0;
static datetime g_doubleSpikeFirstTs = 0;
static int      g_doubleSpikeDir = 0; // +1 BUY, -1 SELL

string TFTag(const ENUM_TIMEFRAMES tf)
{
if(tf == PERIOD_M1) return "M1";
if(tf == PERIOD_M5) return "M5";
if(tf == PERIOD_M15) return "M15";
if(tf == PERIOD_M30) return "M30";
if(tf == PERIOD_H1) return "H1";
if(tf == PERIOD_H4) return "H4";
if(tf == PERIOD_D1) return "D1";
if(tf == PERIOD_W1) return "W1";
return "UNK";
}

string GVKey(const string moduleTag, const string tfTag, const string side)
{
return moduleTag + "_" + _Symbol + "_" + tfTag + "_" + side;
}

static int  g_gomNotifyLastPosCount = -1;
static bool g_gomNotifySpikeArmedLatch = false;

void GOM_AlertPush(const string title, const string detail, const string wavFile)
{
if(!EnableGomNotifyAlerts) return;
string msg = title + " " + _Symbol + " | " + detail;
Alert(msg);
if(StringLen(wavFile) > 0)
   PlaySound(wavFile);
SendNotification(msg);
}

int GOM_PositionCountOnSymbol(const string sym, const long magicFilter)
{
int n = 0;
const int total = PositionsTotal();
for(int i = 0; i < total; i++)
{
ulong ticket = PositionGetTicket(i);
if(ticket == 0) continue;
if(!PositionSelectByTicket(ticket)) continue;
if(PositionGetString(POSITION_SYMBOL) != sym) continue;
if(magicFilter != 0 && PositionGetInteger(POSITION_MAGIC) != magicFilter) continue;
n++;
}
return n;
}

void GOM_UpdateNotifyPositionAndSpike(const double bid, const double spProb, const double spDirNum)
{
if(!EnableGomNotifyAlerts) return;

if(NotifyOnNewPosition)
{
const int pc = GOM_PositionCountOnSymbol(_Symbol, NotifyPositionMagic);
if(g_gomNotifyLastPosCount < 0)
g_gomNotifyLastPosCount = pc;
else if(pc > g_gomNotifyLastPosCount)
GOM_AlertPush("GOM position", "Ouverte (total " + IntegerToString(pc) + ")", NotifySoundNewPosition);
g_gomNotifyLastPosCount = pc;
}

if(NotifyOnSpikeSignalArmed)
{
const bool dirOk = (spDirNum > 0.5 || spDirNum < -0.5);
const bool hi = (spProb + 1e-9 >= SpikeAlertMinProbability && dirOk);
if(hi && !g_gomNotifySpikeArmedLatch)
{
const string sd = (spDirNum > 0.5) ? "BUY" : "SELL";
string det = sd + " " + DoubleToString(spProb * 100.0, 0) + "%";
if(bid > 0.0) det += " @ " + DoubleToString(bid, _Digits);
GOM_AlertPush("GOM SPIKE", det, NotifySoundSpike);
g_gomNotifySpikeArmedLatch = true;
}
else if(!hi)
g_gomNotifySpikeArmedLatch = false;
}
}

//+------------------------------------------------------------------+
//| INTÉGRATION SMC HEDGE FUND                                  |
//+------------------------------------------------------------------+

// Variables globales pour l'intégration SMC
static bool g_smcIntegrationEnabled = true;
static int g_smcZoneCount = 0;
static datetime g_smcLastAnalysis = 0;
// Horodatage sweep ICT opposé au sens Boom/Crash (déclaré ici : utilisé par GOM_DetectSMCSweep plus bas)
datetime g_smcBoomBearSweepContextTime  = 0;
datetime g_smcCrashBullSweepContextTime = 0;

// Fonction pour détecter les swings comme les Hedge Funds
void GOM_DetectSMCSwings()
{
   if(!g_smcIntegrationEnabled) return;
   
   datetime currentTime = TimeCurrent();
   // Analyser toutes les 30 secondes
   if(currentTime - g_smcLastAnalysis < 30) return;
   g_smcLastAnalysis = currentTime;
   
   // Nettoyer anciennes zones
   ArrayResize(g_smcLiquidityZones, 0);
   g_smcZoneCount = 0;
   
   // Analyser les 100 dernières bougies M15
   for(int i = 50; i >= 5; i--)
   {
      double high = iHigh(_Symbol, PERIOD_M15, i);
      double low = iLow(_Symbol, PERIOD_M15, i);
      
      // Détecter swing high
      bool isSwingHigh = true;
      for(int j = 1; j <= 5; j++)
      {
         if(i + j >= 100) break;
         if(iHigh(_Symbol, PERIOD_M15, i + j) >= high) { isSwingHigh = false; break; }
      }
      for(int j = 1; j <= 5; j++)
      {
         if(i - j < 0) break;
         if(iHigh(_Symbol, PERIOD_M15, i - j) >= high) { isSwingHigh = false; break; }
      }
      
      // Détecter swing low
      bool isSwingLow = true;
      for(int j = 1; j <= 5; j++)
      {
         if(i + j >= 100) break;
         if(iLow(_Symbol, PERIOD_M15, i + j) <= low) { isSwingLow = false; break; }
      }
      for(int j = 1; j <= 5; j++)
      {
         if(i - j < 0) break;
         if(iLow(_Symbol, PERIOD_M15, i - j) <= low) { isSwingLow = false; break; }
      }
      
      if(isSwingHigh)
      {
         ArrayResize(g_smcLiquidityZones, g_smcZoneCount + 1);
         g_smcLiquidityZones[g_smcZoneCount].price = high;
         g_smcLiquidityZones[g_smcZoneCount].time = iTime(_Symbol, PERIOD_M15, i);
         g_smcLiquidityZones[g_smcZoneCount].type = "SWING_HIGH";
         g_smcLiquidityZones[g_smcZoneCount].touches = 1;
         g_smcLiquidityZones[g_smcZoneCount].strength = 0.8;
         g_smcLiquidityZones[g_smcZoneCount].isActive = true;
         g_smcLiquidityZones[g_smcZoneCount].objectId = "SMC_LIQ_HIGH_" + IntegerToString(i);
         g_smcZoneCount++;

         // Dessiner zone de liquidité SMC
         string objName = "SMC_LIQ_HIGH_" + IntegerToString(i);
         ObjectCreate(0, objName, OBJ_HLINE, 0, 0, high);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      }

      if(isSwingLow)
      {
         ArrayResize(g_smcLiquidityZones, g_smcZoneCount + 1);
         g_smcLiquidityZones[g_smcZoneCount].price = low;
         g_smcLiquidityZones[g_smcZoneCount].time = iTime(_Symbol, PERIOD_M15, i);
         g_smcLiquidityZones[g_smcZoneCount].type = "SWING_LOW";
         g_smcLiquidityZones[g_smcZoneCount].touches = 1;
         g_smcLiquidityZones[g_smcZoneCount].strength = 0.8;
         g_smcLiquidityZones[g_smcZoneCount].isActive = true;
         g_smcLiquidityZones[g_smcZoneCount].objectId = "SMC_LIQ_LOW_" + IntegerToString(i);
         g_smcZoneCount++;

         // Dessiner zone de liquidité SMC
         string objName = "SMC_LIQ_LOW_" + IntegerToString(i);
         ObjectCreate(0, objName, OBJ_HLINE, 0, 0, low);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDodgerBlue);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      }
   }
}

bool SMC_ContextBlockBoomBuyFromBearSweep();
bool SMC_ContextBlockCrashSellFromBullSweep();
bool IsBoomSymbol(const string symbol);
bool IsCrashSymbol(const string symbol);

// Fonction pour détecter les sweeps de liquidité SMC
bool GOM_DetectSMCSweep(string &direction, double &sweepPrice)
{
   if(!g_smcIntegrationEnabled || g_smcZoneCount == 0) return false;
   
   double currentHigh = iHigh(_Symbol, PERIOD_M15, 1);
   double currentLow = iLow(_Symbol, PERIOD_M15, 1);
   double prevHigh = iHigh(_Symbol, PERIOD_M15, 2);
   double prevLow = iLow(_Symbol, PERIOD_M15, 2);
   
   // Vérifier sweep au-dessus (pour entrée BUY)
   for(int i = 0; i < g_smcZoneCount; i++)
   {
      if(g_smcLiquidityZones[i].price > 0 && currentHigh > g_smcLiquidityZones[i].price && prevHigh <= g_smcLiquidityZones[i].price)
      {
         // Crash = SELL uniquement: un sweep haut (biais ICT « long ») est un contexte défavorable au short immédiat
         if(IsCrashSymbol(_Symbol))
         {
            g_smcCrashBullSweepContextTime = TimeCurrent();
            continue;
         }
         direction = "BUY";
         sweepPrice = g_smcLiquidityZones[i].price;

         // Dessiner sweep
         string objName = "SMC_SWEEP_BUY_" + TimeToString(TimeCurrent(), TIME_SECONDS);
         ObjectCreate(0, objName, OBJ_ARROW, 0, TimeCurrent(), sweepPrice);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 236);

         return true;
      }
   }

   // Vérifier sweep en dessous (pour entrée SELL)
   for(int i = 0; i < g_smcZoneCount; i++)
   {
      if(g_smcLiquidityZones[i].price > 0 && currentLow < g_smcLiquidityZones[i].price && prevLow >= g_smcLiquidityZones[i].price)
      {
         // Boom = BUY uniquement: sweep bas = prise liquidité « ICT SELL » — ne pas dessiner ni renforcer SELL ; bloquer les longs récents ailleurs
         if(IsBoomSymbol(_Symbol))
         {
            g_smcBoomBearSweepContextTime = TimeCurrent();
            continue;
         }
         direction = "SELL";
         sweepPrice = g_smcLiquidityZones[i].price;
         
         // Dessiner sweep
         string objName = "SMC_SWEEP_SELL_" + TimeToString(TimeCurrent(), TIME_SECONDS);
         ObjectCreate(0, objName, OBJ_ARROW, 0, TimeCurrent(), sweepPrice);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 238);
         
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| FONCTIONS ICT SMC - DÉTECTION ET DESSIN                          |
//+------------------------------------------------------------------+

// Structure pour zones de liquidité SMC
struct SMC_LiquidityZone {
   double price;
   datetime time;
   string type; // "SWING_HIGH", "SWING_LOW", "EQUAL_HIGH", "EQUAL_LOW"
   int touches;
   double strength;
   bool isActive;
   string objectId;
};

// Structure pour marché SMC
struct SMC_MarketStructure {
   double lastSwingHigh;
   double lastSwingLow;
   datetime lastSwingHighTime;
   datetime lastSwingLowTime;
   double currentEqualHigh;
   double currentEqualLow;
   int equalHighTouches;
   int equalLowTouches;
};

// Variables globales SMC
SMC_LiquidityZone g_smcLiquidityZones[];
SMC_MarketStructure g_smcMarketStructure;
int g_smcSwingLookback = 5;
double g_smcEqualTolerance = 15.0;
int g_smcMinEqualTouches = 2;
double g_smcLiquidityStrength = 0.8;
int g_smcMaxLiquidityZones = 10;

//+------------------------------------------------------------------+
//| FONCTIONS DE DÉTECTION SMC                                      |
//+------------------------------------------------------------------+

bool GOM_SMCIsSwingHigh(int index, ENUM_TIMEFRAMES timeframe) {
   double high = iHigh(_Symbol, timeframe, index);
   
   for(int i = 1; i <= g_smcSwingLookback; i++) {
      if(index + i >= Bars(_Symbol, timeframe)) break;
      if(iHigh(_Symbol, timeframe, index + i) >= high) return false;
   }
   
   for(int i = 1; i <= g_smcSwingLookback; i++) {
      if(index - i < 0) break;
      if(iHigh(_Symbol, timeframe, index - i) >= high) return false;
   }
   
   return true;
}

bool GOM_SMCIsSwingLow(int index, ENUM_TIMEFRAMES timeframe) {
   double low = iLow(_Symbol, timeframe, index);
   
   for(int i = 1; i <= g_smcSwingLookback; i++) {
      if(index + i >= Bars(_Symbol, timeframe)) break;
      if(iLow(_Symbol, timeframe, index + i) <= low) return false;
   }
   
   for(int i = 1; i <= g_smcSwingLookback; i++) {
      if(index - i < 0) break;
      if(iLow(_Symbol, timeframe, index - i) <= low) return false;
   }
   
   return true;
}

bool GOM_SMCIsEqualHigh(double price1, double price2) {
   return MathAbs(price1 - price2) <= g_smcEqualTolerance * _Point;
}

bool GOM_SMCIsEqualLow(double price1, double price2) {
   return MathAbs(price1 - price2) <= g_smcEqualTolerance * _Point;
}

bool GOM_SMCIsBullishBOS() {
   if(g_smcMarketStructure.lastSwingHigh == 0.0) return false;
   
   double currentClose = iClose(_Symbol, PERIOD_M15, 0);
   return currentClose > g_smcMarketStructure.lastSwingHigh;
}

bool GOM_SMCIsBearishBOS() {
   if(g_smcMarketStructure.lastSwingLow == 0.0) return false;
   
   double currentClose = iClose(_Symbol, PERIOD_M15, 0);
   return currentClose < g_smcMarketStructure.lastSwingLow;
}

//+------------------------------------------------------------------+
//| FONCTIONS DE DESSIN SMC                                         |
//+------------------------------------------------------------------+

void GOM_SMCDrawLiquidityZone(SMC_LiquidityZone &zone) {
   string objName = zone.objectId;
   
   if(ObjectFind(0, objName) >= 0) {
      ObjectDelete(0, objName);
   }
   
   ObjectCreate(0, objName, OBJ_HLINE, 0, 0, zone.price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   
   // Ajouter label
   string labelName = objName + "_LABEL";
   if(ObjectFind(0, labelName) >= 0) {
      ObjectDelete(0, labelName);
   }
   
   ObjectCreate(0, labelName, OBJ_TEXT, 0, zone.time, zone.price);
   ObjectSetString(0, labelName, OBJPROP_TEXT, zone.type + " (" + IntegerToString(zone.touches) + ")");
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void GOM_SMCDrawSweep(string direction, double price, datetime time) {
   string objName = "GOM_SMC_SWEEP_" + direction + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
   
   ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, direction == "BUY" ? clrLime : clrRed);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, direction == "BUY" ? 233 : 234);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void GOM_SMCDrawBOS(string direction, double price, datetime time) {
   string objName = "GOM_SMC_BOS_" + direction + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
   
   ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, direction == "BULLISH" ? clrLime : clrRed);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, direction == "BULLISH" ? 241 : 242);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void GOM_SMCDrawEqualZone(double price, datetime time, string type) {
   string objName = "GOM_SMC_EQUAL_" + type + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
   
   ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   
   // Label
   string labelName = objName + "_LABEL";
   ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price);
   ObjectSetString(0, labelName, OBJPROP_TEXT, "EQUAL " + type);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| FONCTIONS D'ANALYSE SMC                                         |
//+------------------------------------------------------------------+

void GOM_SMCAnalyzeMarketStructure() {
   int barsToAnalyze = 100;
   
   for(int i = barsToAnalyze; i >= 0; i--) {
      datetime barTime = iTime(_Symbol, PERIOD_M15, i);
      
      // Détecter swing highs
      if(GOM_SMCIsSwingHigh(i, PERIOD_M15)) {
         double swingHigh = iHigh(_Symbol, PERIOD_M15, i);
         
         if(swingHigh > g_smcMarketStructure.lastSwingHigh) {
            g_smcMarketStructure.lastSwingHigh = swingHigh;
            g_smcMarketStructure.lastSwingHighTime = barTime;
         }
         
         // Vérifier equal high
         if(g_smcMarketStructure.currentEqualHigh > 0 && GOM_SMCIsEqualHigh(swingHigh, g_smcMarketStructure.currentEqualHigh)) {
            g_smcMarketStructure.equalHighTouches++;
            if(g_smcMarketStructure.equalHighTouches >= g_smcMinEqualTouches) {
               GOM_SMCDrawEqualZone(g_smcMarketStructure.currentEqualHigh, barTime, "HIGH");
            }
         } else {
            g_smcMarketStructure.currentEqualHigh = swingHigh;
            g_smcMarketStructure.equalHighTouches = 1;
         }
      }
      
      // Détecter swing lows
      if(GOM_SMCIsSwingLow(i, PERIOD_M15)) {
         double swingLow = iLow(_Symbol, PERIOD_M15, i);
         
         if(swingLow < g_smcMarketStructure.lastSwingLow || g_smcMarketStructure.lastSwingLow == 0.0) {
            g_smcMarketStructure.lastSwingLow = swingLow;
            g_smcMarketStructure.lastSwingLowTime = barTime;
         }
         
         // Vérifier equal low
         if(g_smcMarketStructure.currentEqualLow > 0 && GOM_SMCIsEqualLow(swingLow, g_smcMarketStructure.currentEqualLow)) {
            g_smcMarketStructure.equalLowTouches++;
            if(g_smcMarketStructure.equalLowTouches >= g_smcMinEqualTouches) {
               GOM_SMCDrawEqualZone(g_smcMarketStructure.currentEqualLow, barTime, "LOW");
            }
         } else {
            g_smcMarketStructure.currentEqualLow = swingLow;
            g_smcMarketStructure.equalLowTouches = 1;
         }
      }
   }
   
   // Dessiner BOS
   if(GOM_SMCIsBullishBOS()) {
      GOM_SMCDrawBOS("BULLISH", g_smcMarketStructure.lastSwingHigh, TimeCurrent());
   }
   if(GOM_SMCIsBearishBOS()) {
      GOM_SMCDrawBOS("BEARISH", g_smcMarketStructure.lastSwingLow, TimeCurrent());
   }
}

//+------------------------------------------------------------------+
//| NETTOYAGE OBJETS SMC                                            |
//+------------------------------------------------------------------+

void GOM_SMCCleanChartObjects() {
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "GOM_SMC_") >= 0) {
         ObjectDelete(0, objName);
      }
   }
}

//+------------------------------------------------------------------+
//| FONCTION PRINCIPALE SMC POUR GOM                                |
//+------------------------------------------------------------------+

void GOM_SMCProcess() {
   // Nettoyer les anciens objets
   GOM_SMCCleanChartObjects();
   
   // Analyser la structure du marché
   GOM_SMCAnalyzeMarketStructure();
}

// Fonction pour influencer le verdict avec SMC (version améliorée)
void GOM_InfluenceVerdictWithSMC(double &techBuy, double &techSell)
{
   if(!g_smcIntegrationEnabled) return;

   if(SMC_ContextBlockBoomBuyFromBearSweep())
   {
      techBuy -= 6.5;
      GOM_GlobalSetForScript("SMC_BOOM_BEAR_SWEEP_BLOCK", 1.0);
   }
   else
      GOM_GlobalSetForScript("SMC_BOOM_BEAR_SWEEP_BLOCK", 0.0);

   if(SMC_ContextBlockCrashSellFromBullSweep())
   {
      techSell -= 6.5;
      GOM_GlobalSetForScript("SMC_CRASH_BULL_SWEEP_BLOCK", 1.0);
   }
   else
      GOM_GlobalSetForScript("SMC_CRASH_BULL_SWEEP_BLOCK", 0.0);
   
   string sweepDirection;
   double sweepPrice;
   
   // Détecter les sweeps SMC avec analyse avancée
   if(GOM_DetectSMCSweep(sweepDirection, sweepPrice))
   {
      // Bonus selon la direction du sweep
      if(sweepDirection == "BUY")
      {
         techBuy += 3.5; // Bonus très fort pour sweep SMC BUY
         techSell -= 1.5; // Pénalisation forte SELL
         
         // Bonus additionnel si confirmation volume
         double currentVolume = GOM_GetVolume(1, PERIOD_M15);
         double avgVolume = GOM_GetAverageVolume(20, PERIOD_M15);
         if(currentVolume > avgVolume * 1.5) {
            techBuy += 1.0; // Bonus volume élevé
            GOM_GlobalSetForScript("SMC_VOLUME_CONFIRMED", 1.0);
         }
      }
      else if(sweepDirection == "SELL")
      {
         techSell += 3.5; // Bonus très fort pour sweep SMC SELL
         techBuy -= 1.5; // Pénalisation forte BUY
         
         // Bonus additionnel si confirmation volume
         double currentVolume = GOM_GetVolume(1, PERIOD_M15);
         double avgVolume = GOM_GetAverageVolume(20, PERIOD_M15);
         if(currentVolume > avgVolume * 1.5) {
            techSell += 1.0; // Bonus volume élevé
            GOM_GlobalSetForScript("SMC_VOLUME_CONFIRMED", 1.0);
         }
      }
      
      // Publier les infos SMC détaillées dans les Global Variables
      GOM_GlobalSetForScript("SMC_SWEEP_DETECTED", 1.0);
      GOM_GlobalSetForScript("SMC_SWEEP_DIRECTION", sweepDirection == "BUY" ? 1.0 : -1.0);
      GOM_GlobalSetForScript("SMC_SWEEP_PRICE", sweepPrice);
      GOM_GlobalSetForScript("SMC_SWEEP_STRENGTH", 3.5); // Force du signal
      
      // Bonus pour confluence avec niveaux KOLA
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double atr = GOM_ATRValue(_Symbol, PERIOD_M15, 14);
      double nearKolaDistance = atr * 0.5;
      
      // Lire les niveaux KOLA M5
      double m5Buy = ReadGVDirect("GOM_KOLA_" + _Symbol + "_M5_BUY", 0.0);
      double m5Sell = ReadGVDirect("GOM_KOLA_" + _Symbol + "_M5_SELL", 0.0);
      
      // Vérifier proximité avec niveaux KOLA
      if(m5Buy > 0 && MathAbs(bid - m5Buy) <= nearKolaDistance) {
         if(sweepDirection == "BUY") techBuy += 1.5;
         GOM_GlobalSetForScript("SMC_KOLA_CONFLUENCE", 1.0);
      }
      if(m5Sell > 0 && MathAbs(bid - m5Sell) <= nearKolaDistance) {
         if(sweepDirection == "SELL") techSell += 1.5;
         GOM_GlobalSetForScript("SMC_KOLA_CONFLUENCE", 1.0);
      }
   }
   else
   {
      GOM_GlobalSetForScript("SMC_SWEEP_DETECTED", 0.0);
      GOM_GlobalSetForScript("SMC_VOLUME_CONFIRMED", 0.0);
      GOM_GlobalSetForScript("SMC_KOLA_CONFLUENCE", 0.0);
   }
   
   bool bullB = GOM_SMCIsBullishBOS();
   bool bearB = GOM_SMCIsBearishBOS();
   if(bullB)
      GOM_GlobalSetForScript("SMC_BULLISH_BOS", 1.0);
   else
      GOM_GlobalSetForScript("SMC_BULLISH_BOS", 0.0);
   if(bearB)
      GOM_GlobalSetForScript("SMC_BEARISH_BOS", 1.0);
   else
      GOM_GlobalSetForScript("SMC_BEARISH_BOS", 0.0);

   const double bosW = 1.38;
   const double bosOpp = 0.58;
   if(bullB && !bearB)
   {
      techBuy += bosW;
      techSell -= bosOpp;
   }
   else if(bearB && !bullB)
   {
      techSell += bosW;
      techBuy -= bosOpp;
   }
}

// Fonctions SMC complémentaires pour GOM
bool GOM_IsBullishBOS()
{
   // Lire depuis SMC_Universal_Enhanced si disponible
   double bos = GlobalVariableGet("SMC_BULLISH_BOS_" + _Symbol);
   return bos > 0.5;
}

bool GOM_IsBearishBOS()
{
   // Lire depuis SMC_Universal_Enhanced si disponible
   double bos = GlobalVariableGet("SMC_BEARISH_BOS_" + _Symbol);
   return bos > 0.5;
}

//+------------------------------------------------------------------+
//| Utilitaires GOM (symbole, GV script, indicateurs, graphe)        |
//+------------------------------------------------------------------+
void GOM_SymbolToUpperKey(const string symIn, string &outU)
{
outU = symIn;
if(outU == "") outU = _Symbol;
StringToUpper(outU);
}

bool GOM_IsBoomOrGainx(const string symIn = "")
{
string u;
GOM_SymbolToUpperKey(symIn, u);
return (StringFind(u, "BOOM") >= 0 || StringFind(u, "GAINX") >= 0);
}

bool GOM_IsCrashOrPainx(const string symIn = "")
{
string u;
GOM_SymbolToUpperKey(symIn, u);
return (StringFind(u, "CRASH") >= 0 || StringFind(u, "PAINX") >= 0);
}

bool GOM_IsSyntheticBoomCrashFamily(const string symIn = "")
{
return (GOM_IsBoomOrGainx(symIn) || GOM_IsCrashOrPainx(symIn));
}

// Indices très bruités (Volatility, Step, etc.) : les 6 filtres « classiques » bloquent trop souvent.
bool GOM_IsVolatilityOrSimilarSynth(const string symIn = "")
{
string u;
GOM_SymbolToUpperKey(symIn, u);
if(StringFind(u, "VOLATILITY") >= 0) return true;
if(StringFind(u, "VIX") >= 0) return true;
if(StringFind(u, "STEP INDEX") >= 0) return true;
if(StringFind(u, "STEP_INDEX") >= 0) return true;
if(StringFind(u, "JUMP") >= 0) return true;
if(StringFind(u, "RANGER") >= 0) return true;
return false;
}

bool GOM_IsDirectionAllowedForSymbol(const string direction, const string symIn = "")
{
if(direction == "BUY" && GOM_IsCrashOrPainx(symIn)) return false;
if(direction == "SELL" && GOM_IsBoomOrGainx(symIn)) return false;
return true;
}

void GOM_GlobalSetForScript(const string keySuffix, const double value)
{
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_" + keySuffix, value);
}

double GOM_GlobalGetForScript(const string keySuffix, const double defVal = 0.0)
{
string k = "GOM_SCRIPT_" + _Symbol + "_" + keySuffix;
if(!GlobalVariableCheck(k)) return defVal;
return GlobalVariableGet(k);
}

// Flèches sweep SMC (GOM_DetectSMCSweep) : éviter BUY Boom / SELL Crash quand le dernier signal sweep est opposé.
bool GOM_ChartHasSmcSweepArrowRecent(const string namePrefix, const int maxAgeSec)
{
   if(maxAgeSec <= 0 || namePrefix == "") return false;
   const datetime tCut = TimeCurrent() - (datetime)maxAgeSec;
   const int n = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < n; i++)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(nm == "" || StringFind(nm, namePrefix) != 0) continue;
      const datetime t0 = (datetime)ObjectGetInteger(0, nm, OBJPROP_TIME);
      if(t0 >= tCut) return true;
   }
   return false;
}

bool GOM_BoomBuyBlockedByOppositeSmcSweep(const int maxAgeSec)
{
   if(!GomPlanArrowRespectSmcSweepConflict) return false;
   if(!GOM_IsBoomOrGainx()) return false;
   if(GOM_GlobalGetForScript("SMC_SWEEP_DETECTED", 0.0) > 0.5 && GOM_GlobalGetForScript("SMC_SWEEP_DIRECTION", 0.0) < -0.5)
      return true;
   return GOM_ChartHasSmcSweepArrowRecent("SMC_SWEEP_SELL_", maxAgeSec);
}

bool GOM_CrashSellBlockedByOppositeSmcSweep(const int maxAgeSec)
{
   if(!GomPlanArrowRespectSmcSweepConflict) return false;
   if(!GOM_IsCrashOrPainx()) return false;
   if(GOM_GlobalGetForScript("SMC_SWEEP_DETECTED", 0.0) > 0.5 && GOM_GlobalGetForScript("SMC_SWEEP_DIRECTION", 0.0) > 0.5)
      return true;
   return GOM_ChartHasSmcSweepArrowRecent("SMC_SWEEP_BUY_", maxAgeSec);
}

double GOM_IndicatorCopyRelease(const int handle, const int bufferIndex)
{
if(handle == INVALID_HANDLE) return 0.0;
double b[];
ArrayResize(b, 1);
ArraySetAsSeries(b, true);
int n = CopyBuffer(handle, bufferIndex, 0, 1, b);
if(n < 1) return 0.0;
return b[0];
}

struct GOM_HandleCacheItem
{
   string key;
   int    handle;
};
static GOM_HandleCacheItem g_handleCache[];

int GOM_GetCachedHandle(const string key)
{
   for(int i = 0; i < ArraySize(g_handleCache); i++)
      if(g_handleCache[i].key == key) return g_handleCache[i].handle;
   return INVALID_HANDLE;
}

int GOM_SetCachedHandle(const string key, const int h)
{
   for(int i = 0; i < ArraySize(g_handleCache); i++)
   {
      if(g_handleCache[i].key == key)
      {
         if(g_handleCache[i].handle != INVALID_HANDLE && g_handleCache[i].handle != h)
            IndicatorRelease(g_handleCache[i].handle);
         g_handleCache[i].handle = h;
         return h;
      }
   }
   int n = ArraySize(g_handleCache) + 1;
   ArrayResize(g_handleCache, n);
   g_handleCache[n - 1].key = key;
   g_handleCache[n - 1].handle = h;
   return h;
}

void GOM_ReleaseAllCachedHandles()
{
   for(int i = 0; i < ArraySize(g_handleCache); i++)
   {
      if(g_handleCache[i].handle != INVALID_HANDLE)
         IndicatorRelease(g_handleCache[i].handle);
      g_handleCache[i].handle = INVALID_HANDLE;
   }
}

int GOM_LoadFactorByCharts()
{
   if(!AutoScaleRefreshByCharts) return 1;
   int step = MathMax(1, ChartsPerLoadStep);
   int charts = 0;
   long ch = ChartFirst();
   while(ch >= 0)
   {
      charts++;
      ch = ChartNext(ch);
   }
   if(charts <= 0) charts = 1;
   int f = (charts + step - 1) / step;
   if(f < 1) f = 1;
   int fMax = MathMax(1, MaxAutoScaleFactor);
   if(f > fMax) f = fMax;
   return f;
}

int GOM_EffectiveRefreshSeconds(const int baseSec)
{
   int b = MathMax(1, baseSec);
   return MathMax(1, b * GOM_LoadFactorByCharts());
}

int GOM_SymbolExecSlot(const int modulo)
{
   if(modulo <= 1) return 0;
   int h = 0;
   int n = StringLen(_Symbol);
   for(int i = 0; i < n; i++)
      h = (h * 31 + (int)StringGetCharacter(_Symbol, i)) & 0x7fffffff;
   return (h % modulo);
}

bool GOM_ShouldRun(datetime now, datetime &lastTs, const int baseSec)
{
   int every = GOM_EffectiveRefreshSeconds(baseSec);
   if(lastTs > 0 && (now - lastTs) < every)
      return false;

   if(StaggerExecutionBySymbol && every > 1)
   {
      int slot = GOM_SymbolExecSlot(every);
      if(((int)(now % every)) != slot)
         return false;
   }

   lastTs = now;
   return true;
}

double GOM_ATRValue(const string sym, const ENUM_TIMEFRAMES tf, const int period)
{
string k = "ATR|" + sym + "|" + IntegerToString((int)tf) + "|" + IntegerToString(period);
int h = GOM_GetCachedHandle(k);
if(h == INVALID_HANDLE)
   h = GOM_SetCachedHandle(k, iATR(sym, tf, period));
return GOM_IndicatorCopyRelease(h, 0);
}

//+------------------------------------------------------------------+
//| Fonctions de volume pour GOM                                    |
//+------------------------------------------------------------------+

double GOM_GetVolume(int shift, ENUM_TIMEFRAMES timeframe)
{
long volume[];
ArraySetAsSeries(volume, true);
if(CopyTickVolume(_Symbol, timeframe, shift, 1, volume) > 0) {
return (double)volume[0];
}
return 0.0;
}

double GOM_GetAverageVolume(int period, ENUM_TIMEFRAMES timeframe)
{
long volume[];
ArraySetAsSeries(volume, true);
if(CopyTickVolume(_Symbol, timeframe, 0, period, volume) > 0) {
double sum = 0.0;
for(int i = 0; i < period; i++) {
sum += (double)volume[i];
}
return sum / period;
}
return 0.0;
}

double GOM_EMAValue(const string sym, const ENUM_TIMEFRAMES tf, const int period)
{
string k = "EMA|" + sym + "|" + IntegerToString((int)tf) + "|" + IntegerToString(period);
int h = GOM_GetCachedHandle(k);
if(h == INVALID_HANDLE)
   h = GOM_SetCachedHandle(k, iMA(sym, tf, period, 0, MODE_EMA, PRICE_CLOSE));
return GOM_IndicatorCopyRelease(h, 0);
}

double GOM_RSIValue(const string sym, const ENUM_TIMEFRAMES tf, const int period)
{
string k = "RSI|" + sym + "|" + IntegerToString((int)tf) + "|" + IntegerToString(period);
int h = GOM_GetCachedHandle(k);
if(h == INVALID_HANDLE)
   h = GOM_SetCachedHandle(k, iRSI(sym, tf, period, PRICE_CLOSE));
return GOM_IndicatorCopyRelease(h, 0);
}

void GOM_UpdateAdvancedTrendMetrics(const double bid)
{
GOM_GlobalSetForScript("TV_SUPERTREND_DIR", 0.0);
GOM_GlobalSetForScript("TV_KELTNER_POS", 0.0);
GOM_GlobalSetForScript("TV_DONCHIAN_SIG", 0.0);
if(!EnableAdvancedIndicators || bid <= 0.0) return;

static datetime s_lastAdvancedUpdate = 0;
datetime now = TimeCurrent();
if(s_lastAdvancedUpdate > 0 && (now - s_lastAdvancedUpdate) < MathMax(1, AdvancedIndicatorsRefreshSeconds))
   return;
s_lastAdvancedUpdate = now;

ENUM_TIMEFRAMES tf = AdvancedIndicatorsTF;
int n = MathMax(35, DonchianPeriod + 5);
MqlRates rr[];
ArraySetAsSeries(rr, true);
int copied = CopyRates(_Symbol, tf, 0, n, rr);
if(copied < MathMax(20, DonchianPeriod + 2)) return;

double atr = GOM_ATRValue(_Symbol, tf, MathMax(5, SupertrendAtrPeriod));
double ema = GOM_EMAValue(_Symbol, tf, MathMax(5, KeltnerEmaPeriod));
if(atr <= 0.0 || ema <= 0.0) return;

// Supertrend (version légère): direction selon close vs bandes ATR autour de hl2.
double hl2 = (rr[1].high + rr[1].low) * 0.5;
double stUpper = hl2 + SupertrendAtrMult * atr;
double stLower = hl2 - SupertrendAtrMult * atr;
double stDir = 0.0;
double c1 = rr[1].close;
if(c1 > stUpper) stDir = 1.0;
else if(c1 < stLower) stDir = -1.0;
else stDir = (c1 >= ema ? 0.5 : -0.5);
GOM_GlobalSetForScript("TV_SUPERTREND_DIR", stDir);

// Keltner position: -1..+1, prix vs canal.
double kcUpper = ema + KeltnerAtrMult * atr;
double kcLower = ema - KeltnerAtrMult * atr;
double kcPos = 0.0;
if(kcUpper > kcLower)
   kcPos = ((c1 - kcLower) / (kcUpper - kcLower)) * 2.0 - 1.0;
if(kcPos > 1.5) kcPos = 1.5;
if(kcPos < -1.5) kcPos = -1.5;
GOM_GlobalSetForScript("TV_KELTNER_POS", kcPos);

// Donchian breakout signal.
int dcN = MathMax(5, DonchianPeriod);
double hh = rr[1].high, ll = rr[1].low;
for(int i = 1; i <= dcN && i < copied; i++)
{
   if(rr[i].high > hh) hh = rr[i].high;
   if(rr[i].low < ll) ll = rr[i].low;
}
double dcSig = 0.0;
if(c1 > hh - atr * 0.05) dcSig = 1.0;
else if(c1 < ll + atr * 0.05) dcSig = -1.0;
GOM_GlobalSetForScript("TV_DONCHIAN_SIG", dcSig);
}

void GOM_AddAdvancedIndicatorsVerdictBias(double &techBuy, double &techSell)
{
if(!EnableAdvancedIndicators || !AdvancedIndicatorsInfluenceVerdict) return;
double w = AdvancedIndicatorsVerdictWeight;
if(w <= 0.0) return;

double st = GOM_GlobalGetForScript("TV_SUPERTREND_DIR", 0.0);
double kc = GOM_GlobalGetForScript("TV_KELTNER_POS", 0.0);
double dc = GOM_GlobalGetForScript("TV_DONCHIAN_SIG", 0.0);

if(st > 0.0) techBuy += 0.20 * w * MathAbs(st);
else if(st < 0.0) techSell += 0.20 * w * MathAbs(st);

if(kc > 0.10) techBuy += 0.22 * w * MathMin(1.0, MathAbs(kc));
else if(kc < -0.10) techSell += 0.22 * w * MathMin(1.0, MathAbs(kc));

if(dc > 0.0) techBuy += 0.24 * w;
else if(dc < 0.0) techSell += 0.24 * w;
}

double GOM_CombinedTradeConfidence(const double filterQuality, const double spikeProb)
{
double c = ReadGVDirect("SMC_UNIVERSAL_" + _Symbol + "_SERVER_AI_CONF", 0.0);
if(c > 1.0) c /= 100.0;
double ext = g_lastExtAiConf;
if(ext > 1.0) ext /= 100.0;
double fq = filterQuality;
if(fq < 0.0) fq = 0.0;
if(fq > 1.0) fq = 1.0;
double sp = spikeProb;
if(sp < 0.0) sp = 0.0;
if(sp > 1.0) sp = 1.0;
double m = MathMax(MathMax(c, ext), MathMax(fq, sp));
if(m > 1.0) m = 1.0;
return m;
}

void GOM_AddEmaRibbonScriptTfBias(const double bid, double &techBuy, double &techSell)
{
int ribbonPeriods[4] = {9, 21, 13, 50};
int nAbove = 0;
for(int ri = 0; ri < 4; ri++)
{
double em = GOM_EMAValue(_Symbol, ScriptEmaTF, ribbonPeriods[ri]);
if(em <= 0.0) continue;
if(bid > em)
{
techBuy += 0.15;
nAbove++;
}
else techSell += 0.15;
}
if(nAbove >= 4) techBuy += 0.25;
else if(nAbove <= 0) techSell += 0.25;
}

// Met à jour les GV pour BB/VWAP (partagé: dessin + verdict + spike squeeze).
void GOM_UpdateBollingerVwapMetrics(const double bid)
{
GOM_GlobalSetForScript("VWAP", 0.0);
GOM_GlobalSetForScript("VWAP_DIST_PCT", 0.0);
GOM_GlobalSetForScript("BB_UPPER", 0.0);
GOM_GlobalSetForScript("BB_MID", 0.0);
GOM_GlobalSetForScript("BB_LOWER", 0.0);
GOM_GlobalSetForScript("BB_PCTB", 0.5);
GOM_GlobalSetForScript("BB_WIDTH_PCT", 0.0);
GOM_GlobalSetForScript("BB_SQUEEZE", 0.0);
if(bid <= 0.0) return;

double vwap = 0.0;
if(ShowSessionVWAP)
{
MqlRates rv[];
int nv = CopyRates(_Symbol, PERIOD_M1, 0, MathMin(3000, MathMax(100, VWAPCurveBars)), rv);
if(nv >= 3)
{
ArraySetAsSeries(rv, true);
datetime day0 = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
double sumPV = 0.0, sumV = 0.0;
for(int i = 0; i < nv; i++)
{
if(rv[i].time < day0) break;
double tp = (rv[i].high + rv[i].low + rv[i].close) / 3.0;
double vv = (double)rv[i].tick_volume;
if(vv < 1.0) vv = 1.0;
sumPV += tp * vv;
sumV += vv;
}
if(sumV > 0.0)
{
vwap = sumPV / sumV;
GOM_GlobalSetForScript("VWAP", vwap);
double distPct = (vwap > 0.0) ? ((bid - vwap) / vwap * 100.0) : 0.0;
GOM_GlobalSetForScript("VWAP_DIST_PCT", distPct);
}
}
}

string kBB = "BB|" + _Symbol + "|" + IntegerToString((int)BollingerTF) + "|" + IntegerToString(BollingerPeriod) + "|" + DoubleToString(BollingerDeviation, 2);
int hB = GOM_GetCachedHandle(kBB);
if(hB == INVALID_HANDLE)
   hB = GOM_SetCachedHandle(kBB, iBands(_Symbol, BollingerTF, BollingerPeriod, 0, BollingerDeviation, PRICE_CLOSE));
if(hB != INVALID_HANDLE)
{
double bu[], bm[], bl[];
ArrayResize(bu, 1);
ArrayResize(bm, 1);
ArrayResize(bl, 1);
ArraySetAsSeries(bu, true);
ArraySetAsSeries(bm, true);
ArraySetAsSeries(bl, true);
bool ok = (CopyBuffer(hB, 1, 0, 1, bu) >= 1 && CopyBuffer(hB, 0, 0, 1, bm) >= 1 && CopyBuffer(hB, 2, 0, 1, bl) >= 1);
if(ok && bm[0] > 0.0 && bu[0] > bl[0])
{
double U = bu[0], M = bm[0], L = bl[0];
GOM_GlobalSetForScript("BB_UPPER", U);
GOM_GlobalSetForScript("BB_MID", M);
GOM_GlobalSetForScript("BB_LOWER", L);
double pctB = (bid - L) / (U - L);
if(pctB < 0.0) pctB = 0.0;
if(pctB > 1.0) pctB = 1.0;
GOM_GlobalSetForScript("BB_PCTB", pctB);
double widthPct = (U - L) / M * 100.0;
GOM_GlobalSetForScript("BB_WIDTH_PCT", widthPct);
double atrBb = GOM_ATRValue(_Symbol, BollingerTF, 14);
if(atrBb > 0.0 && (U - L) < atrBb * 1.28)
GOM_GlobalSetForScript("BB_SQUEEZE", 1.0);
}
}
}

void GOM_AddBollingerVwapVerdictBias(const double bid, const bool isBoom, const bool isCrash,
   double &techBuy, double &techSell)
{
if(!BollingerVwapInfluenceVerdict || bid <= 0.0) return;
double w = BollingerVwapVerdictWeight;
if(w <= 0.0) return;

double vwap = GOM_GlobalGetForScript("VWAP", 0.0);
if(vwap > 0.0 && ShowSessionVWAP)
{
double bp = (bid - vwap) / vwap;
double mag = MathMin(1.0, MathAbs(bp) / 0.0025);
if(bp > 0.00025)
techBuy += 0.24 * w * mag;
else if(bp < -0.00025)
techSell += 0.24 * w * mag;
}

double pctB = GOM_GlobalGetForScript("BB_PCTB", 0.5);
double sq = GOM_GlobalGetForScript("BB_SQUEEZE", 0.0);
if(sq > 0.5)
{
if(isBoom) techBuy += 0.14 * w;
if(isCrash) techSell += 0.14 * w;
if(!isBoom && !isCrash)
{
techBuy += 0.06 * w;
techSell += 0.06 * w;
}
}

if(isBoom)
{
if(pctB < 0.14) techBuy += 0.22 * w;
else if(pctB > 0.86) techBuy += 0.12 * w;
else if(pctB >= 0.42 && pctB <= 0.58) techBuy += 0.08 * w;
}
else if(isCrash)
{
if(pctB > 0.86) techSell += 0.22 * w;
else if(pctB < 0.14) techSell += 0.12 * w;
else if(pctB >= 0.42 && pctB <= 0.58) techSell += 0.08 * w;
}
else
{
if(pctB < 0.22) techBuy += 0.16 * w;
else if(pctB > 0.78) techSell += 0.16 * w;
}
}

// Score 0..1 : marge de gap, spike aligné, confluence KOLA, alignement MTF, qualité filtres.
double GOM_ComputeEntryQualityScore(const string dir, const double gap, const double gapTh,
   const string spikeDir, const double spikeProb, const bool spikeOpp,
   const double filterQuality, const double levelConfluence,
   const int bM15, const int bM30, const int bH1, const int bH4)
{
double wSum = 0.0, wTot = 0.0;
double gt = MathMax(1e-6, gapTh);

double gapN = 0.0;
if(dir == "BUY" && gap > gt)
gapN = MathMin(1.0, (gap - gt) / (gt * 2.5));
else if(dir == "SELL" && gap < -gt)
gapN = MathMin(1.0, (-gap - gt) / (gt * 2.5));
wSum += 0.20 * gapN;
wTot += 0.20;

bool spAl = (dir == "BUY" && spikeDir == "BUY") || (dir == "SELL" && spikeDir == "SELL");
double spN = 0.0;
if(spAl)
{
spN = MathMin(1.0, spikeProb / 0.72);
if(spikeOpp) spN = MathMax(spN, 0.74);
}
else if(spikeProb > 0.0)
spN = 0.14 * MathMin(1.0, spikeProb / 0.55);
wSum += 0.30 * spN;
wTot += 0.30;

double lcN = MathMin(1.0, levelConfluence / 0.72);
wSum += 0.24 * lcN;
wTot += 0.24;

double mtfN = 0.0;
if(dir == "BUY")
{
if(bM15 > 0) mtfN += 0.25;
else if(bM15 == 0) mtfN += 0.12;
if(bM30 > 0) mtfN += 0.25;
else if(bM30 == 0) mtfN += 0.12;
if(bH1 > 0) mtfN += 0.25;
else if(bH1 == 0) mtfN += 0.12;
if(bH4 > 0) mtfN += 0.25;
else if(bH4 == 0) mtfN += 0.12;
}
else if(dir == "SELL")
{
if(bM15 < 0) mtfN += 0.25;
else if(bM15 == 0) mtfN += 0.12;
if(bM30 < 0) mtfN += 0.25;
else if(bM30 == 0) mtfN += 0.12;
if(bH1 < 0) mtfN += 0.25;
else if(bH1 == 0) mtfN += 0.12;
if(bH4 < 0) mtfN += 0.25;
else if(bH4 == 0) mtfN += 0.12;
}
mtfN = MathMin(1.0, mtfN);
wSum += 0.16 * mtfN;
wTot += 0.16;

double fq = filterQuality;
if(fq < 0.0) fq = 0.0;
if(fq > 1.0) fq = 1.0;
wSum += 0.10 * fq;
wTot += 0.10;

if(wTot <= 1e-9) return 0.0;
return wSum / wTot;
}

bool GOM_EntryQualityRelaxed(const string dir, const string spikeDir, const double spikeProb,
   const bool spikeOpp, const double levelConfluence)
{
bool spAl = (dir == "BUY" && spikeDir == "BUY") || (dir == "SELL" && spikeDir == "SELL");
if(EntryQualityRelaxOnSpikeSetup && spAl && spikeOpp &&
   spikeProb + 1e-9 >= SpikeAlertMinProbability)
return true;
if(EntryQualityRelaxOnHighConfluence && levelConfluence + 1e-9 >= EntryQualityConfluenceRelaxMin)
return true;
return false;
}

void GOM_DeleteObjectsByPrefixIfExists(const string prefix, const int maxObj)
{
for(int z = 0; z < maxObj; z++)
ObjectDelete(0, prefix + IntegerToString(z));
}

void GOM_DrawBandSegment(const string prefix, const int k,
   const datetime tOld, const double vOld, const datetime tNew, const double vNew,
   const color clr, const int style, const int width, const bool back)
{
if(tOld <= 0 || tNew <= 0) return;
if(vOld <= 0.0 || vNew <= 0.0) return;
string nm = prefix + IntegerToString(k);
if(ObjectFind(0, nm) < 0)
ObjectCreate(0, nm, OBJ_TREND, 0, tOld, vOld, tNew, vNew);
else
{
ObjectMove(0, nm, 0, tOld, vOld);
ObjectMove(0, nm, 1, tNew, vNew);
}
ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
ObjectSetInteger(0, nm, OBJPROP_STYLE, style);
ObjectSetInteger(0, nm, OBJPROP_WIDTH, width);
ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT, false);
ObjectSetInteger(0, nm, OBJPROP_BACK, back);
ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, nm, OBJPROP_HIDDEN, false);
}

void DrawAndPublishBollingerVWAP()
{
GOM_DeleteObjectsByPrefixIfExists("GOM_BB_UX_", 2100);
GOM_DeleteObjectsByPrefixIfExists("GOM_BB_MX_", 2100);
GOM_DeleteObjectsByPrefixIfExists("GOM_BB_LX_", 2100);
GOM_DeleteObjectsByPrefixIfExists("GOM_VWAPX_", 3200);

int nSeg = BollingerCurveBars;
if(nSeg < 20) nSeg = 20;
if(nSeg > 2000) nSeg = 2000;

if(ShowBollingerBands)
{
int barsTf = iBars(_Symbol, BollingerTF);
if(barsTf >= 3)
{
if(nSeg > barsTf - 1) nSeg = barsTf - 1;
int hB = iBands(_Symbol, BollingerTF, BollingerPeriod, 0, BollingerDeviation, PRICE_CLOSE);
if(hB != INVALID_HANDLE)
{
double bu[], bm[], bl[];
int need = nSeg + 1;
ArrayResize(bu, need);
ArrayResize(bm, need);
ArrayResize(bl, need);
ArraySetAsSeries(bu, true);
ArraySetAsSeries(bm, true);
ArraySetAsSeries(bl, true);
int nc = CopyBuffer(hB, 1, 0, need, bu);
CopyBuffer(hB, 0, 0, need, bm);
CopyBuffer(hB, 2, 0, need, bl);
IndicatorRelease(hB);
if(nc >= 2)
{
for(int k = 0; k < nc - 1; k++)
{
datetime tNew = iTime(_Symbol, BollingerTF, k);
datetime tOld = iTime(_Symbol, BollingerTF, k + 1);
if(tNew <= 0 || tOld <= 0) continue;
GOM_DrawBandSegment("GOM_BB_UX_", k, tOld, bu[k + 1], tNew, bu[k], BollingerUpperColor, STYLE_SOLID, 1, true);
GOM_DrawBandSegment("GOM_BB_MX_", k, tOld, bm[k + 1], tNew, bm[k], BollingerMidColor, STYLE_DOT, 1, true);
GOM_DrawBandSegment("GOM_BB_LX_", k, tOld, bl[k + 1], tNew, bl[k], BollingerLowerColor, STYLE_SOLID, 1, true);
}
}
}
}
}

if(ShowSessionVWAP)
{
MqlRates rv[];
int nv = CopyRates(_Symbol, PERIOD_M1, 0, MathMin(3000, MathMax(120, VWAPCurveBars)), rv);
if(nv >= 5)
{
ArraySetAsSeries(rv, true);
datetime day0 = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
int imax = nv;
for(int i = 0; i < nv; i++)
{
if(rv[i].time < day0)
{
imax = i;
break;
}
}
int segLim = MathMin(imax * 2 + 8, 3200);
double cumPV = 0.0, cumV = 0.0;
datetime tPrev = 0;
double vwPrev = 0.0;
int segIdx = 0;
for(int j = imax - 1; j >= 0; j--)
{
double tp = (rv[j].high + rv[j].low + rv[j].close) / 3.0;
double vol = (double)rv[j].tick_volume;
if(vol < 1.0) vol = 1.0;
cumPV += tp * vol;
cumV += vol;
if(cumV <= 0.0) continue;
double vwNow = cumPV / cumV;
datetime tNow = rv[j].time;
if(tPrev > 0 && vwPrev > 0.0 && segIdx < segLim && segLim >= 2)
GOM_DrawBandSegment("GOM_VWAPX_", segIdx++, tPrev, vwPrev, tNow, vwNow, VWAPLineColor, STYLE_SOLID, 2, false);
tPrev = tNow;
vwPrev = vwNow;
}
}
}
}

// tag: 0=aucun niveau, 1=M5, 2=H1, 3=M30, 4=M15, 5=H4, -1=prix trop loin de toutes les zones (> maxNear)
void GOM_ResolveKolaAnchorBuy(const double bid, const double atr,
   const double m5, const double h1, const double m30, const double m15, const double h4,
   const double maxNearAtrMult, int &tagOut, double &levelOut)
{
tagOut = 0;
levelOut = 0.0;
if(bid <= 0.0) return;
double atrU = (atr > 0.0) ? atr : bid * 0.0015;
double maxNear = atrU * MathMax(0.35, maxNearAtrMult);
double minD = DBL_MAX;
double lv[6];
lv[1] = m5; lv[2] = h1; lv[3] = m30; lv[4] = m15; lv[5] = h4;
for(int t = 1; t <= 5; t++)
{
if(lv[t] <= 0.0) continue;
double d = MathAbs(bid - lv[t]);
if(d < minD) minD = d;
}
if(minD >= DBL_MAX * 0.5) return;
if(minD > maxNear) { tagOut = -1; return; }
double eps = atrU * 0.035;
for(int t2 = 1; t2 <= 5; t2++)
{
if(lv[t2] <= 0.0) continue;
if(MathAbs(MathAbs(bid - lv[t2]) - minD) <= eps)
{
tagOut = t2;
levelOut = lv[t2];
return;
}
}
}

void GOM_ResolveKolaAnchorSell(const double bid, const double atr,
   const double m5, const double h1, const double m30, const double m15, const double h4,
   const double maxNearAtrMult, int &tagOut, double &levelOut)
{
GOM_ResolveKolaAnchorBuy(bid, atr, m5, h1, m30, m15, h4, maxNearAtrMult, tagOut, levelOut);
}

string GOM_KolaAnchorTagToStr(const int tag)
{
if(tag == 1) return "M5";
if(tag == 2) return "H1";
if(tag == 3) return "M30";
if(tag == 4) return "M15";
if(tag == 5) return "H4";
if(tag == -1) return "FAR";
return "NONE";
}

double GOM_SpikeBlinkEffectiveTh(const double baseTh)
{
double th = MathMax(0.22, MathMin(0.92, baseTh));
double lead = GOM_GlobalGetForScript("SPIKE_LEAD_RAW", 0.0);
double cap = MathMax(0.0, MathMin(0.22, SpikeBlinkLeadThAdjMax));
double adj = MathMax(0.0, lead - 0.30) * 0.32;
if(adj > cap) adj = cap;
th -= adj;
if(th < 0.20) th = 0.20;
return th;
}

double GOM_ADXValue(const string sym, const ENUM_TIMEFRAMES tf, const int adxPeriod)
{
return GOM_IndicatorCopyRelease(iADX(sym, tf, adxPeriod), 0);
}

double GOM_StochMain(const string sym, const ENUM_TIMEFRAMES tf, const int k, const int d, const int slowing)
{
return GOM_IndicatorCopyRelease(iStochastic(sym, tf, k, d, slowing, MODE_SMA, STO_LOWHIGH), 0);
}

int GOM_SecondsToBarClose(const string sym, const ENUM_TIMEFRAMES tf)
{
datetime t0 = iTime(sym, tf, 0);
if(t0 <= 0) return 0;
int sec = (int)PeriodSeconds(tf);
return (int)(t0 + (datetime)sec - TimeCurrent());
}

double GOM_SpreadPoints(void)
{
double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
if(pt <= 0.0 || bid <= 0.0 || ask <= 0.0) return 0.0;
return (ask - bid) / pt;
}

string GOM_FormatSpreadForDash()
{
double sp = GOM_SpreadPoints();
if(sp <= 0.0) return "--";
if(sp >= 10000.0) return DoubleToString(sp / 1000.0, 1) + "k";
if(sp >= 1000.0)  return DoubleToString(sp, 0);
if(sp >= 100.0)   return DoubleToString(sp, 1);
return DoubleToString(sp, 2);
}

bool GOM_MACDMainAboveSignal(const string sym, const ENUM_TIMEFRAMES tf, bool &mainAboveSignal)
{
int h = iMACD(sym, tf, 12, 26, 9, PRICE_CLOSE);
if(h == INVALID_HANDLE) return false;
double m0[], m1[];
ArrayResize(m0, 1);
ArrayResize(m1, 1);
ArraySetAsSeries(m0, true);
ArraySetAsSeries(m1, true);
bool ok = (CopyBuffer(h, 0, 0, 1, m0) >= 1 && CopyBuffer(h, 1, 0, 1, m1) >= 1);
IndicatorRelease(h);
if(!ok) return false;
mainAboveSignal = (m0[0] >= m1[0]);
return true;
}

// Score technique identique a la couche Python "decision_simplified" (avant enhance_decision_with_ml).
void GOM_ComputeServerStyleTechScores(const double rsi,
   const double ef_m1, const double es_m1,
   const double ef_m5, const double es_m5,
   const double ef_h1, const double es_h1,
   double &buyScore, double &sellScore)
{
buyScore = 0.0;
sellScore = 0.0;
if(rsi > 0.0)
{
if(rsi < 30.0) buyScore += 0.15;
else if(rsi > 70.0) sellScore += 0.15;
else if(rsi >= 30.0 && rsi <= 40.0) buyScore += 0.08;
else if(rsi >= 60.0 && rsi <= 70.0) sellScore += 0.08;
}
if(es_m1 > 0.0 && ef_m1 > 0.0)
{
double d = ef_m1 - es_m1;
double st = MathAbs(d) / es_m1;
if(d > 0.0) buyScore += 0.20 * MathMin(1.0, st * 100.0);
else if(d < 0.0) sellScore += 0.20 * MathMin(1.0, st * 100.0);
}
if(es_h1 > 0.0 && ef_h1 > 0.0)
{
double d = ef_h1 - es_h1;
double st = MathAbs(d) / es_h1;
if(d > 0.0) buyScore += 0.35 * MathMin(1.0, st * 50.0);
else if(d < 0.0) sellScore += 0.35 * MathMin(1.0, st * 50.0);
}
if(es_m5 > 0.0 && ef_m5 > 0.0)
{
double d = ef_m5 - es_m5;
double st = MathAbs(d) / es_m5;
if(d > 0.0) buyScore += 0.25 * MathMin(1.0, st * 75.0);
else if(d < 0.0) sellScore += 0.25 * MathMin(1.0, st * 75.0);
}
}

string GOM_EmaBiasTag(const double ef, const double es)
{
if(ef <= 0.0 || es <= 0.0) return "--";
if(ef > es) return "bull";
if(ef < es) return "bear";
return "flat";
}

void GOM_PublishMLFeatureGlobals()
{
const string legacyBg = "GOM_MLFP_BG";
const string legacyTxt = "GOM_MLFP_TXT";
ObjectDelete(0, legacyBg);
ObjectDelete(0, legacyTxt);

double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
if(bid <= 0.0) bid = iClose(_Symbol, PERIOD_CURRENT, 0);
if(ask <= 0.0) ask = bid;

double rsi = GOM_RSIValue(_Symbol, PERIOD_M1, 14);
double atr = GOM_ATRValue(_Symbol, PERIOD_M1, 14);
double ef1 = GOM_EMAValue(_Symbol, PERIOD_M1, 9);
double es1 = GOM_EMAValue(_Symbol, PERIOD_M1, 21);
double ef5 = GOM_EMAValue(_Symbol, PERIOD_M5, 9);
double es5 = GOM_EMAValue(_Symbol, PERIOD_M5, 21);
double efh = GOM_EMAValue(_Symbol, PERIOD_H1, 9);
double esh = GOM_EMAValue(_Symbol, PERIOD_H1, 21);

double buySc = 0.0, sellSc = 0.0;
GOM_ComputeServerStyleTechScores(rsi, ef1, es1, ef5, es5, efh, esh, buySc, sellSc);

GOM_GlobalSetForScript("FEAT_BID", bid);
GOM_GlobalSetForScript("FEAT_ASK", ask);
GOM_GlobalSetForScript("FEAT_RSI_M1_14", rsi);
GOM_GlobalSetForScript("FEAT_ATR_M1_14", atr);
GOM_GlobalSetForScript("FEAT_EMA_FAST_M1", ef1);
GOM_GlobalSetForScript("FEAT_EMA_SLOW_M1", es1);
GOM_GlobalSetForScript("FEAT_EMA_FAST_M5", ef5);
GOM_GlobalSetForScript("FEAT_EMA_SLOW_M5", es5);
GOM_GlobalSetForScript("FEAT_EMA_FAST_H1", efh);
GOM_GlobalSetForScript("FEAT_EMA_SLOW_H1", esh);
GOM_GlobalSetForScript("TECH_SERVER_BUY_SCORE", buySc);
GOM_GlobalSetForScript("TECH_SERVER_SELL_SCORE", sellSc);
double hint = 0.0;
if(buySc > sellSc + 1e-8) hint = 1.0;
else if(sellSc > buySc + 1e-8) hint = -1.0;
GOM_GlobalSetForScript("TECH_SERVER_HINT_NUM", hint);
}

// Label multi-ligne bas-droite (si pas de cellules dédiées sur la grille).
void GOM_DrawMLInfoFloatingLabel()
{
const string brName = "GOM_MLINFO_BR";
if(!ShowMLFeatureInfo)
{
ObjectDelete(0, brName);
return;
}

double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
if(bid <= 0.0) bid = iClose(_Symbol, PERIOD_CURRENT, 0);
if(ask <= 0.0) ask = bid;
double rsi = GOM_RSIValue(_Symbol, PERIOD_M1, 14);
double atr = GOM_ATRValue(_Symbol, PERIOD_M1, 14);
double ef1 = GOM_EMAValue(_Symbol, PERIOD_M1, 9);
double es1 = GOM_EMAValue(_Symbol, PERIOD_M1, 21);
double ef5 = GOM_EMAValue(_Symbol, PERIOD_M5, 9);
double es5 = GOM_EMAValue(_Symbol, PERIOD_M5, 21);
double efh = GOM_EMAValue(_Symbol, PERIOD_H1, 9);
double esh = GOM_EMAValue(_Symbol, PERIOD_H1, 21);
double buySc = GOM_GlobalGetForScript("TECH_SERVER_BUY_SCORE", 0.0);
double sellSc = GOM_GlobalGetForScript("TECH_SERVER_SELL_SCORE", 0.0);
string biasFeat = "HOLD";
if(buySc > sellSc + 1e-8) biasFeat = "BUY";
else if(sellSc > buySc + 1e-8) biasFeat = "SELL";

double srvConf = ReadGVDirect("SMC_UNIVERSAL_" + _Symbol + "_SERVER_AI_CONF", 0.0);
double srvTs = ReadGVDirect("SMC_UNIVERSAL_" + _Symbol + "_SERVER_AI_LAST_TS", 0.0);
double srvAct = ReadGVDirect("SMC_UNIVERSAL_" + _Symbol + "_SERVER_AI_ACTION_NUM", 0.0);
double srvValid = ReadGVDirect("SMC_UNIVERSAL_" + _Symbol + "_SERVER_AI_VALID", 0.0);
if(srvConf > 1.0) srvConf /= 100.0;

string srvDir = (srvAct > 0.5 ? "BUY" : (srvAct < -0.5 ? "SELL" : "-"));

string srvAgeTxt = "--";
if(srvTs > 0.0) {
   int sa = (int)(TimeCurrent() - (datetime)srvTs);
   if(sa >= 0 && sa < 864000) srvAgeTxt = IntegerToString(sa) + "s";
}

int atrDg = (atr > 0.0 && atr < 1.0) ? 5 : _Digits;
string txt = "SRV /decision: " + srvDir + " " + DoubleToString(srvConf * 100.0, 1) + "%";
txt += (srvValid > 0.5 ? " OK " : " -- ");
txt += srvAgeTxt + "\n";
txt += "BA " + DoubleToString(bid, _Digits) + "/" + DoubleToString(ask, _Digits);
txt += "  RSI " + DoubleToString(rsi, 1) + " ATR " + DoubleToString(atr, atrDg) + "\n";
txt += "EMA M1:" + GOM_EmaBiasTag(ef1, es1) + " M5:" + GOM_EmaBiasTag(ef5, es5);
txt += " H1:" + GOM_EmaBiasTag(efh, esh) + "\n";
txt += "Pre-ML B/S " + DoubleToString(buySc, 2) + " / " + DoubleToString(sellSc, 2) + " => " + biasFeat;

if(ObjectFind(0, brName) < 0)
ObjectCreate(0, brName, OBJ_LABEL, 0, 0, 0);
ObjectSetInteger(0, brName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
ObjectSetInteger(0, brName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
ObjectSetInteger(0, brName, OBJPROP_XDISTANCE, MathMax(4, MLFeatureInfoMarginRight));
ObjectSetInteger(0, brName, OBJPROP_YDISTANCE, MathMax(4, MLFeatureInfoMarginBottom));
ObjectSetInteger(0, brName, OBJPROP_COLOR, clrGainsboro);
ObjectSetInteger(0, brName, OBJPROP_FONTSIZE, MathMax(7, MLFeatureFontSize));
ObjectSetString(0, brName, OBJPROP_FONT, "Consolas");
ObjectSetString(0, brName, OBJPROP_TEXT, txt);
ObjectSetInteger(0, brName, OBJPROP_BACK, false);
ObjectSetInteger(0, brName, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, brName, OBJPROP_HIDDEN, false);
ObjectSetInteger(0, brName, OBJPROP_ZORDER, MLFeatureInfoZOrder);
}

color GOM_VerdictCellColor(const string quality)
{
if(quality == "PERFECT BUY") return (color)0x1E7A3A;
if(quality == "PERFECT SELL") return (color)0x8B2020;
if(quality == "GOOD BUY") return (color)0x3FAE63;
if(quality == "GOOD SELL") return (color)0xB54552;
if(quality == "BUY") return (color)0x58B874;
if(quality == "SELL") return (color)0xC35A64;
return (color)0x4D4D4D;
}

double GOM_VerdictNumFromQuality(const string quality)
{
if(quality == "PERFECT BUY") return 3.0;
if(quality == "GOOD BUY") return 2.0;
if(quality == "BUY") return 1.0;
if(quality == "PERFECT SELL") return -3.0;
if(quality == "GOOD SELL") return -2.0;
if(quality == "SELL") return -1.0;
return 0.0;
}

void GOM_DeleteChartObjectsByPrefix(const string prefix)
{
const int total = ObjectsTotal(0, -1, -1);
for(int i = total - 1; i >= 0; i--)
{
string nm = ObjectName(0, i, -1, -1);
if(nm == "") continue;
if(StringFind(nm, prefix) != 0) continue;
ObjectDelete(0, nm);
}
}

bool GOM_PriceNearLevel(const double price, const double level, const double atrVal, const double atrMult)
{
if(price <= 0.0 || level <= 0.0 || atrVal <= 0.0) return false;
return (MathAbs(price - level) <= atrVal * atrMult);
}

// true si le prix touche la ligne M5 KOLA opposée à la direction (zone correction) — utilisé pour bloquer entrées et pour fermer positions.
bool GOM_IsPriceNearOppositeM5KolaLine(const string direction, const string sym, const double bid, const double ask, double atrHint)
{
   if(bid <= 0.0 || ask <= 0.0) return false;

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(sym);
   if(OppositeM5LineBlockBoomCrashOnly)
   {
      if(cat != SYM_BOOM_CRASH && !(OppositeM5LineBlockIncludeVolatility && cat == SYM_VOLATILITY))
         return false;
   }

   string d = direction;
   StringToUpper(d);
   if(d != "BUY" && d != "SELL") return false;

   if(atrHint <= 0.0 || !MathIsValidNumber(atrHint))
   {
      int h = iATR(sym, PERIOD_M15, 14);
      if(h != INVALID_HANDLE)
      {
         double ab[];
         ArraySetAsSeries(ab, true);
         if(CopyBuffer(h, 0, 0, 1, ab) >= 1)
            atrHint = ab[0];
         IndicatorRelease(h);
      }
   }
   if(atrHint <= 0.0 || !MathIsValidNumber(atrHint))
      atrHint = MathMax(bid * 0.0015, SymbolInfoDouble(sym, SYMBOL_POINT) * 100.0);

   const double m5Buy = ReadGVDirect("GOM_KOLA_" + sym + "_M5_BUY", 0.0);
   const double m5Sell = ReadGVDirect("GOM_KOLA_" + sym + "_M5_SELL", 0.0);
   const double mult = OppositeM5LineBlockMaxAtrMult;

   if(d == "BUY" && m5Sell > 0.0 && MathIsValidNumber(m5Sell) && GOM_PriceNearLevel(ask, m5Sell, atrHint, mult))
      return true;
   if(d == "SELL" && m5Buy > 0.0 && MathIsValidNumber(m5Buy) && GOM_PriceNearLevel(bid, m5Buy, atrHint, mult))
      return true;
   return false;
}

// true = ne pas ouvrir : entrée « correction » contre la ligne M5 KOLA opposée (épaisse sur graphique).
bool GOM_ShouldAbortEntryForOppositeM5Line(const string direction, const string sym, const double bid, const double ask, double atrHint)
{
   if(!BlockEntryIfNearOppositeM5KolaLine) return false;
   return GOM_IsPriceNearOppositeM5KolaLine(direction, sym, bid, ask, atrHint);
}

// Ferme les positions ouvertes si le prix rejoint la ligne M5 KOLA opposée (correction contre le sens du trade).
bool GOM_IsPriceNearOppositeM5FromChartObjects(const string sym, const string direction, const double bid, const double ask, double atrHint)
{
   if(!ClosePositionWhenTouchesDrawnM5EntryOpposite) return false;
   if(sym != _Symbol) return false;

   string d = direction;
   StringToUpper(d);
   if(d != "BUY" && d != "SELL") return false;

   if(atrHint <= 0.0 || !MathIsValidNumber(atrHint))
   {
      int h = iATR(sym, PERIOD_M15, 14);
      if(h != INVALID_HANDLE)
      {
         double ab[];
         ArraySetAsSeries(ab, true);
         if(CopyBuffer(h, 0, 0, 1, ab) >= 1)
            atrHint = ab[0];
         IndicatorRelease(h);
      }
   }
   if(atrHint <= 0.0 || !MathIsValidNumber(atrHint))
      atrHint = MathMax(bid * 0.0015, SymbolInfoDouble(sym, SYMBOL_POINT) * 100.0);

   const double mult = OppositeM5LineBlockMaxAtrMult;

   if(d == "BUY")
   {
      if(ObjectFind(0, "M5_ENTRY_SELL_LINE") < 0) return false;
      const double lv = ObjectGetDouble(0, "M5_ENTRY_SELL_LINE", OBJPROP_PRICE, 0);
      if(lv <= 0.0 || !MathIsValidNumber(lv)) return false;
      return GOM_PriceNearLevel(ask, lv, atrHint, mult);
   }
   if(ObjectFind(0, "M5_ENTRY_BUY_LINE") < 0) return false;
   const double lv = ObjectGetDouble(0, "M5_ENTRY_BUY_LINE", OBJPROP_PRICE, 0);
   if(lv <= 0.0 || !MathIsValidNumber(lv)) return false;
   return GOM_PriceNearLevel(bid, lv, atrHint, mult);
}

void GOM_ManageExitOpenPositionsNearOppositeM5Kola()
{
   if(!ClosePositionWhenPriceHitsOppositeM5KolaLine && !ClosePositionWhenTouchesDrawnM5EntryOpposite) return;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;

      const string sym = posInfo.Symbol();
      int ageSec = (int)(TimeCurrent() - posInfo.Time());
      if(ageSec < MathMax(0, OppositeM5LineExitMinHoldSec)) continue;

      const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      string dir = (posInfo.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";

      const bool nearOppKola = (ClosePositionWhenPriceHitsOppositeM5KolaLine &&
                                 GOM_IsPriceNearOppositeM5KolaLine(dir, sym, bid, ask, 0.0));
      const bool nearOppChart = GOM_IsPriceNearOppositeM5FromChartObjects(sym, dir, bid, ask, 0.0);
      if(!nearOppKola && !nearOppChart) continue;

      ulong ticket = posInfo.Ticket();
      double net = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionCloseWithLog(ticket, "Exit: prix sur M5 opposé (KOLA ou ENTRY — zone correction)"))
      {
         Print("?? FERMETURE zone correction M5 opposé | ", sym, " | ", dir, " | ticket=", ticket,
               " | net=", DoubleToString(net, 2), "$ | kola=", (nearOppKola ? "OUI" : "NON"),
               " | chartM5=", (nearOppChart ? "OUI" : "NON"));
         if(UseNotifications)
            SendNotification("Correction M5: fermé " + sym + " " + dir + " | " + DoubleToString(net, 2) + "$");
      }
   }
}

bool GOM_IsSpikeOpportunity(const bool isBoom, const bool isCrash, const string spikeDir, const double spikeProb)
{
if(spikeProb < MathMax(0.0, SpikeBypassMinProbability)) return false;
if(isBoom && spikeDir == "BUY") return true;
if(isCrash && spikeDir == "SELL") return true;
return false;
}

int GOM_CountSpikeNearM5Pending(const string sym, const long magic, const string commentKey)
{
int n = 0;
for(int i = OrdersTotal() - 1; i >= 0; i--)
{
ulong ticket = OrderGetTicket(i);
if(ticket == 0) continue;
if(!OrderSelect(ticket)) continue;
if(OrderGetString(ORDER_SYMBOL) != sym) continue;
if((long)OrderGetInteger(ORDER_MAGIC) != magic) continue;
if(StringFind(OrderGetString(ORDER_COMMENT), commentKey) < 0) continue;
const int t = (int)OrderGetInteger(ORDER_TYPE);
if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_SELL_LIMIT || t == ORDER_TYPE_SELL_STOP)
   n++;
}
return n;
}

int GOM_CountOpenPositionsByMagicComment(const string sym, const long magic, const string commentKey)
{
int n = 0;
const int total = PositionsTotal();
for(int i = 0; i < total; i++)
{
ulong ticket = PositionGetTicket(i);
if(ticket == 0) continue;
if(!PositionSelectByTicket(ticket)) continue;
if(PositionGetString(POSITION_SYMBOL) != sym) continue;
if(magic != 0 && PositionGetInteger(POSITION_MAGIC) != magic) continue;
if(StringFind(PositionGetString(POSITION_COMMENT), commentKey) < 0) continue;
n++;
}
return n;
}

void GOM_AdjustPendingStopsForBroker(const ENUM_ORDER_TYPE otype, const double openPrice,
                                    double &sl, double &tp1, const double pt, const int stopsPts)
{
if(stopsPts <= 0 || openPrice <= 0.0 || pt <= 0.0) return;
const double minD = (double)stopsPts * pt;
const int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
if(sl > 0.0)
{
if(otype == ORDER_TYPE_BUY_LIMIT || otype == ORDER_TYPE_BUY_STOP || otype == ORDER_TYPE_BUY)
{
if(openPrice - sl < minD)
   sl = NormalizeDouble(openPrice - minD, dg);
}
else
{
if(sl - openPrice < minD)
   sl = NormalizeDouble(openPrice + minD, dg);
}
}
if(tp1 > 0.0)
{
if(otype == ORDER_TYPE_BUY_LIMIT || otype == ORDER_TYPE_BUY_STOP || otype == ORDER_TYPE_BUY)
{
if(tp1 - openPrice < minD)
   tp1 = NormalizeDouble(openPrice + minD, dg);
}
else
{
if(openPrice - tp1 < minD)
   tp1 = NormalizeDouble(openPrice - minD, dg);
}
}
}

void GOM_MaybePlaceSpikeNearM5Pending(const bool isBoom, const bool isCrash,
                                     const string spikeDir, const double spikeProb, const bool spikeOpportunity,
                                     const bool blockBuySpike, const bool blockSellSpike,
                                     const double bid, const double ask, const double atr,
                                     const double m5Buy, const double m5Sell)
{
if(!EnableSpikeNearM5AutoPending) return;
if(SpikeNearM5DeferToArrowFirstPending && EnableSpikeImminentFirstAutoPending) return;
if(!EnableSpikePrediction) return;
if(!GOM_IsSyntheticBoomCrashFamily()) return;
if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return;
if(bid <= 0.0 || ask <= 0.0) return;

if(GomPlanArrowRespectSmcSweepConflict)
{
   if(isBoom && spikeDir == "BUY" && GOM_BoomBuyBlockedByOppositeSmcSweep(GomPlanArrowSweepConflictMaxAgeSec)) return;
   if(isCrash && spikeDir == "SELL" && GOM_CrashSellBlockedByOppositeSmcSweep(GomPlanArrowSweepConflictMaxAgeSec)) return;
}

const double minProb = (SpikeNearM5MinSpikeProb > 1e-9) ? SpikeNearM5MinSpikeProb : SpikeAlertMinProbability;
if(spikeProb + 1e-9 < minProb) return;

const int cd = MathMax(0, SpikeNearM5CooldownSec);
if(cd > 0 && g_gomLastSpikeM5PendingTime > 0 && (TimeCurrent() - g_gomLastSpikeM5PendingTime) < cd)
   return;

const string cmtKey = (SpikeNearM5Comment == "") ? "GOM_SKM5" : SpikeNearM5Comment;
if(GOM_CountSpikeNearM5Pending(_Symbol, SpikeNearM5Magic, cmtKey) >= MathMax(1, SpikeNearM5MaxSamePending))
   return;

double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
if(pt <= 0.0) pt = 0.1;
const int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
const int stopsPts = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
const double off = (double)MathMax(0, SpikeNearM5OffsetPoints) * pt;

double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
if(vmin <= 0.0) vmin = 0.01;
if(vmax <= 0.0) vmax = 100.0;
if(vstep <= 0.0) vstep = 0.01;
double vol = SpikeNearM5Lots;
vol = MathMax(vol, vmin);
vol = MathMin(vol, vmax);
vol = NormalizeDouble(MathFloor(vol / vstep + 1e-12) * vstep, 8);

g_gomSpikeTrade.SetExpertMagicNumber(SpikeNearM5Magic);
g_gomSpikeTrade.SetDeviationInPoints(120);
g_gomSpikeTrade.SetTypeFilling(ORDER_FILLING_IOC);

const double atrUse = (atr > 0.0) ? atr : bid * 0.0015;
const double slBuf = atrUse * 0.55;
const double tpScalp = atrUse * 0.88;
const datetime expGtc = (datetime)0;

if(isBoom && spikeDir == "BUY" && m5Buy > 0.0 && GOM_PriceNearLevel(bid, m5Buy, atrUse, 0.4))
{
bool dsHold = (GOM_GlobalGetForScript("DOUBLE_SPIKE_HOLD", 0.0) > 0.5 || GOM_GlobalGetForScript("DOUBLE_SPIKE_PHASE", 0.0) >= 1.0);
if(SpikeNearM5SkipIfSpikeExhausted && blockBuySpike && !(spikeOpportunity && SpikeModeBypassStrict) && !dsHold)
   return;
double px = NormalizeDouble(m5Buy + off, dg);
ENUM_ORDER_TYPE otype;
if(px < ask)
   otype = ORDER_TYPE_BUY_LIMIT;
else
{
otype = ORDER_TYPE_BUY_STOP;
if(px <= ask)
   px = NormalizeDouble(ask + MathMax(pt * 2.0, off > 0.0 ? off : pt * 2.0), dg);
}
double sl = m5Buy - MathMax(atrUse * 0.28, slBuf * 0.65);
double tp1 = px + MathMax(atrUse * 0.72, tpScalp);
GOM_AdjustPendingStopsForBroker(otype, px, sl, tp1, pt, stopsPts);
bool ok = false;
if(otype == ORDER_TYPE_BUY_LIMIT)
   ok = g_gomSpikeTrade.BuyLimit(vol, px, _Symbol, sl, tp1, ORDER_TIME_GTC, expGtc, cmtKey);
else
   ok = g_gomSpikeTrade.BuyStop(vol, px, _Symbol, sl, tp1, ORDER_TIME_GTC, expGtc, cmtKey);
if(ok)
{
g_gomLastSpikeM5PendingTime = TimeCurrent();
Print("GOM auto pending BUY ", EnumToString(otype), " @", DoubleToString(px, dg),
      " SL=", DoubleToString(sl, dg), " TP1=", DoubleToString(tp1, dg), " lot=", DoubleToString(vol, 2));
if(NotifyOnSpikeAutoPendingOk)
GOM_AlertPush("GOM spike pending OK", EnumToString(otype) + " BUY @" + DoubleToString(px, dg), NotifySoundSpike);
}
else
Print("GOM auto pending BUY échoué: ", g_gomSpikeTrade.ResultRetcodeDescription());
return;
}

if(isCrash && spikeDir == "SELL" && m5Sell > 0.0 && GOM_PriceNearLevel(bid, m5Sell, atrUse, 0.4))
{
bool dsHold = (GOM_GlobalGetForScript("DOUBLE_SPIKE_HOLD", 0.0) > 0.5 || GOM_GlobalGetForScript("DOUBLE_SPIKE_PHASE", 0.0) >= 1.0);
if(SpikeNearM5SkipIfSpikeExhausted && blockSellSpike && !(spikeOpportunity && SpikeModeBypassStrict) && !dsHold)
   return;
double px = NormalizeDouble(m5Sell - off, dg);
ENUM_ORDER_TYPE otype;
if(px > bid)
   otype = ORDER_TYPE_SELL_LIMIT;
else
{
otype = ORDER_TYPE_SELL_STOP;
if(px >= bid)
   px = NormalizeDouble(bid - MathMax(pt * 2.0, off > 0.0 ? off : pt * 2.0), dg);
}
double sl = m5Sell + MathMax(atrUse * 0.28, slBuf * 0.65);
double tp1 = px - MathMax(atrUse * 0.72, tpScalp);
GOM_AdjustPendingStopsForBroker(otype, px, sl, tp1, pt, stopsPts);
bool ok = false;
if(otype == ORDER_TYPE_SELL_LIMIT)
   ok = g_gomSpikeTrade.SellLimit(vol, px, _Symbol, sl, tp1, ORDER_TIME_GTC, expGtc, cmtKey);
else
   ok = g_gomSpikeTrade.SellStop(vol, px, _Symbol, sl, tp1, ORDER_TIME_GTC, expGtc, cmtKey);
if(ok)
{
g_gomLastSpikeM5PendingTime = TimeCurrent();
Print("GOM auto pending SELL ", EnumToString(otype), " @", DoubleToString(px, dg),
      " SL=", DoubleToString(sl, dg), " TP1=", DoubleToString(tp1, dg), " lot=", DoubleToString(vol, 2));
if(NotifyOnSpikeAutoPendingOk)
GOM_AlertPush("GOM spike pending OK", EnumToString(otype) + " SELL @" + DoubleToString(px, dg), NotifySoundSpike);
}
else
Print("GOM auto pending SELL échoué: ", g_gomSpikeTrade.ResultRetcodeDescription());
}
}

void GOM_TrySpikeImminentFirstPending(const bool isBoom, const bool isCrash,
                                      const string spikeDir, const double spikeProb,
                                      const double bid, const double ask, const double atr,
                                      const double m5Buy, const double m5Sell)
{
if(!EnableSpikeImminentFirstAutoPending) return;
if(!EnableSpikePrediction) return;
if(!GOM_IsSyntheticBoomCrashFamily()) return;
if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return;
if(bid <= 0.0 || ask <= 0.0) return;

if(SpikeImminentFirstSkipDoubleSpikePhase2 && EnableDoubleSpikeCapture)
{
const double phDs = GOM_GlobalGetForScript("DOUBLE_SPIKE_PHASE", 0.0);
if(phDs >= 2.0 - 1e-9) return;
}

double th = GOM_SpikeBlinkEffectiveTh(SpikeBlinkMinProbability);
if(spikeProb + 1e-12 < th) return;

if(isBoom && spikeDir != "BUY") return;
if(isCrash && spikeDir != "SELL") return;
if(!isBoom && !isCrash) return;

const int cdImm = MathMax(0, SpikeImminentFirstCooldownSec);
if(cdImm > 0 && g_gomLastSpikeImminentFirstTime > 0 &&
   (TimeCurrent() - g_gomLastSpikeImminentFirstTime) < cdImm)
   return;

const string cmtImm = (SpikeImminentFirstComment == "") ? "GOM_SKIM" : SpikeImminentFirstComment;
if(GOM_CountSpikeNearM5Pending(_Symbol, SpikeImminentFirstMagic, cmtImm) >= 1)
   return;
if(SpikeImminentFirstUseMarketOrder &&
   GOM_CountOpenPositionsByMagicComment(_Symbol, SpikeImminentFirstMagic, cmtImm) >= 1)
   return;

const double atrUse = (atr > 0.0) ? atr : bid * 0.0015;
if(SpikeImminentPendingRequireNearM5)
{
if(isBoom && (m5Buy <= 0.0 || !GOM_PriceNearLevel(bid, m5Buy, atrUse, 0.4))) return;
if(isCrash && (m5Sell <= 0.0 || !GOM_PriceNearLevel(bid, m5Sell, atrUse, 0.4))) return;
}

double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
if(pt <= 0.0) pt = 0.1;
const int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
const int stopsPts = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
const double off = (double)MathMax(0, SpikeNearM5OffsetPoints) * pt;
const double slBuf = atrUse * 0.55;
const double tpScalp = atrUse * 0.88;
const datetime expGtc = (datetime)0;

double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
if(vmin <= 0.0) vmin = 0.01;
if(vmax <= 0.0) vmax = 100.0;
if(vstep <= 0.0) vstep = 0.01;
double vol = SpikeNearM5Lots;
vol = MathMax(vol, vmin);
vol = MathMin(vol, vmax);
vol = NormalizeDouble(MathFloor(vol / vstep + 1e-12) * vstep, 8);

g_gomSpikeTrade.SetExpertMagicNumber(SpikeImminentFirstMagic);
g_gomSpikeTrade.SetDeviationInPoints(120);
g_gomSpikeTrade.SetTypeFilling(ORDER_FILLING_IOC);

if(isBoom && spikeDir == "BUY")
{
double px = 0.0, sl = 0.0, tp1 = 0.0;
ENUM_ORDER_TYPE otype = ORDER_TYPE_BUY_STOP;
if(m5Buy > 0.0)
{
px = NormalizeDouble(m5Buy + off, dg);
if(SpikeImminentFirstForceLimitOnly)
{
otype = ORDER_TYPE_BUY_LIMIT;
const double limMaxPx = ask - MathMax((double)stopsPts * pt, pt * 3.0);
if(px >= limMaxPx)
   px = NormalizeDouble(limMaxPx - pt, dg);
}
else if(px < ask)
   otype = ORDER_TYPE_BUY_LIMIT;
else
{
otype = ORDER_TYPE_BUY_STOP;
if(px <= ask)
   px = NormalizeDouble(ask + MathMax(pt * 2.0, off > 0.0 ? off : pt * 2.0), dg);
}
sl = m5Buy - MathMax(atrUse * 0.28, slBuf * 0.65);
tp1 = px + MathMax(atrUse * 0.72, tpScalp);
}
else
{
otype = ORDER_TYPE_BUY_STOP;
px = NormalizeDouble(ask + MathMax(off, pt * 3.0), dg);
if(px <= ask)
   px = NormalizeDouble(ask + pt * 3.0, dg);
sl = NormalizeDouble(bid - MathMax(atrUse * 0.35, slBuf * 0.75), dg);
tp1 = NormalizeDouble(px + MathMax(atrUse * 0.72, tpScalp), dg);
}
if(SpikeImminentFirstUseMarketOrder)
{
if(m5Buy > 0.0)
{
sl = m5Buy - MathMax(atrUse * 0.28, slBuf * 0.65);
tp1 = NormalizeDouble(ask + MathMax(atrUse * 0.72, tpScalp), dg);
}
else
{
sl = NormalizeDouble(bid - MathMax(atrUse * 0.35, slBuf * 0.75), dg);
tp1 = NormalizeDouble(ask + MathMax(atrUse * 0.72, tpScalp), dg);
}
GOM_AdjustPendingStopsForBroker(ORDER_TYPE_BUY, ask, sl, tp1, pt, stopsPts);
bool okM = g_gomSpikeTrade.Buy(vol, _Symbol, 0.0, sl, tp1, cmtImm);
if(okM)
{
g_gomLastSpikeImminentFirstTime = TimeCurrent();
Print("GOM spike-imminent MARKET BUY ask=", DoubleToString(ask, dg), " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp1, dg));
if(NotifyOnSpikeAutoPendingOk)
GOM_AlertPush("GOM spike imminent OK", "MARKET BUY @" + DoubleToString(ask, dg), NotifySoundSpike);
}
else
Print("GOM spike-imminent MARKET BUY échoué: ", g_gomSpikeTrade.ResultRetcodeDescription());
return;
}
GOM_AdjustPendingStopsForBroker(otype, px, sl, tp1, pt, stopsPts);
bool okImm = false;
if(otype == ORDER_TYPE_BUY_LIMIT)
   okImm = g_gomSpikeTrade.BuyLimit(vol, px, _Symbol, sl, tp1, ORDER_TIME_GTC, expGtc, cmtImm);
else
   okImm = g_gomSpikeTrade.BuyStop(vol, px, _Symbol, sl, tp1, ORDER_TIME_GTC, expGtc, cmtImm);
if(okImm)
{
g_gomLastSpikeImminentFirstTime = TimeCurrent();
Print("GOM spike-imminent 1er front BUY ", EnumToString(otype), " @", DoubleToString(px, dg));
if(NotifyOnSpikeAutoPendingOk)
GOM_AlertPush("GOM spike imminent OK", EnumToString(otype) + " BUY @" + DoubleToString(px, dg), NotifySoundSpike);
}
else
Print("GOM spike-imminent BUY échoué: ", g_gomSpikeTrade.ResultRetcodeDescription());
return;
}

if(isCrash && spikeDir == "SELL")
{
double px = 0.0, sl = 0.0, tp1 = 0.0;
ENUM_ORDER_TYPE otype = ORDER_TYPE_SELL_STOP;
if(m5Sell > 0.0)
{
px = NormalizeDouble(m5Sell - off, dg);
if(SpikeImminentFirstForceLimitOnly)
{
otype = ORDER_TYPE_SELL_LIMIT;
const double limMinPx = bid + MathMax((double)stopsPts * pt, pt * 3.0);
if(px <= limMinPx)
   px = NormalizeDouble(limMinPx + pt, dg);
}
else if(px > bid)
   otype = ORDER_TYPE_SELL_LIMIT;
else
{
otype = ORDER_TYPE_SELL_STOP;
if(px >= bid)
   px = NormalizeDouble(bid - MathMax(pt * 2.0, off > 0.0 ? off : pt * 2.0), dg);
}
sl = m5Sell + MathMax(atrUse * 0.28, slBuf * 0.65);
tp1 = px - MathMax(atrUse * 0.72, tpScalp);
}
else
{
otype = ORDER_TYPE_SELL_STOP;
px = NormalizeDouble(bid - MathMax(off, pt * 3.0), dg);
if(px >= bid)
   px = NormalizeDouble(bid - pt * 3.0, dg);
sl = NormalizeDouble(ask + MathMax(atrUse * 0.35, slBuf * 0.75), dg);
tp1 = NormalizeDouble(px - MathMax(atrUse * 0.72, tpScalp), dg);
}
if(SpikeImminentFirstUseMarketOrder)
{
if(m5Sell > 0.0)
{
sl = m5Sell + MathMax(atrUse * 0.28, slBuf * 0.65);
tp1 = NormalizeDouble(bid - MathMax(atrUse * 0.72, tpScalp), dg);
}
else
{
sl = NormalizeDouble(ask + MathMax(atrUse * 0.35, slBuf * 0.75), dg);
tp1 = NormalizeDouble(bid - MathMax(atrUse * 0.72, tpScalp), dg);
}
GOM_AdjustPendingStopsForBroker(ORDER_TYPE_SELL, bid, sl, tp1, pt, stopsPts);
bool okM2 = g_gomSpikeTrade.Sell(vol, _Symbol, 0.0, sl, tp1, cmtImm);
if(okM2)
{
g_gomLastSpikeImminentFirstTime = TimeCurrent();
Print("GOM spike-imminent MARKET SELL bid=", DoubleToString(bid, dg), " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp1, dg));
if(NotifyOnSpikeAutoPendingOk)
GOM_AlertPush("GOM spike imminent OK", "MARKET SELL @" + DoubleToString(bid, dg), NotifySoundSpike);
}
else
Print("GOM spike-imminent MARKET SELL échoué: ", g_gomSpikeTrade.ResultRetcodeDescription());
return;
}
GOM_AdjustPendingStopsForBroker(otype, px, sl, tp1, pt, stopsPts);
bool okImm2 = false;
if(otype == ORDER_TYPE_SELL_LIMIT)
   okImm2 = g_gomSpikeTrade.SellLimit(vol, px, _Symbol, sl, tp1, ORDER_TIME_GTC, expGtc, cmtImm);
else
   okImm2 = g_gomSpikeTrade.SellStop(vol, px, _Symbol, sl, tp1, ORDER_TIME_GTC, expGtc, cmtImm);
if(okImm2)
{
g_gomLastSpikeImminentFirstTime = TimeCurrent();
Print("GOM spike-imminent 1er front SELL ", EnumToString(otype), " @", DoubleToString(px, dg));
if(NotifyOnSpikeAutoPendingOk)
GOM_AlertPush("GOM spike imminent OK", EnumToString(otype) + " SELL @" + DoubleToString(px, dg), NotifySoundSpike);
}
else
Print("GOM spike-imminent SELL échoué: ", g_gomSpikeTrade.ResultRetcodeDescription());
}
}

//+------------------------------------------------------------------+
//| FILTRES DE CONFIRMATION DES SIGNAUX                              |
//+------------------------------------------------------------------+

// Structure pour stocker les résultats des filtres
struct FilterResults
{
bool volumePass;           // Filtre Volume
bool momentumPass;         // Filtre Momentum
bool rsiDivergencePass;   // Filtre Divergence RSI
bool mtfPass;             // Filtre Multi-Timeframe
bool structurePass;       // Filtre Structure
bool volatilityPass;      // Filtre Volatilité
int  passCount;           // Nombre de filtres passés
int  totalFilters;        // Nombre total de filtres actifs
string failReason;        // Raison de l'échec principal
};

// Filtre Volume: vérifie que le volume actuel est au-dessus de la moyenne
bool CheckVolumeFilter(const ENUM_TIMEFRAMES tf, const int lookback, double &avgVolOut)
{
if(!EnableVolumeFilter) return true;

MqlRates rates[];
ArraySetAsSeries(rates, true);
int copied = CopyRates(_Symbol, tf, 0, lookback + 1, rates);
if(copied < lookback + 1) return true; // Pas assez de données, on passe

double sumVol = 0.0;
for(int i = 1; i <= lookback; i++)
sumVol += (double)rates[i].tick_volume;

avgVolOut = sumVol / (double)lookback;
if(avgVolOut <= 0.0) return true;

double currentVol = (double)rates[0].tick_volume;
return (currentVol >= avgVolOut * VolumeMinRatio);
}

// Filtre Momentum: vérifie l'alignement EMA 9/21 et la direction
bool CheckMomentumFilter(const ENUM_TIMEFRAMES tf, const string direction)
{
if(!EnableMomentumFilter) return true;

double ema9 = GOM_EMAValue(_Symbol, tf, 9);
double ema21 = GOM_EMAValue(_Symbol, tf, 21);

if(ema9 <= 0.0 || ema21 <= 0.0) return true;

double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(bid <= 0.0) bid = iClose(_Symbol, tf, 0);

if(direction == "BUY")
return (ema9 >= ema21 && bid >= ema9);
else if(direction == "SELL")
return (ema9 <= ema21 && bid <= ema9);

return true;
}

// Filtre Divergence RSI: détecte les divergences prix/RSI
bool CheckRSIDivergenceFilter(const ENUM_TIMEFRAMES tf, const string direction, string &divergenceType)
{
if(!EnableRSIDivergenceFilter) return true;

divergenceType = "NONE";

MqlRates rates[];
ArraySetAsSeries(rates, true);
int copied = CopyRates(_Symbol, tf, 0, RSIDivergenceLookback + 5, rates);
if(copied < RSIDivergenceLookback + 3) return true;

double rsi[];
ArraySetAsSeries(rsi, true);
int hRSI = iRSI(_Symbol, tf, 14, PRICE_CLOSE);
if(hRSI == INVALID_HANDLE) return true;

if(CopyBuffer(hRSI, 0, 0, RSIDivergenceLookback + 5, rsi) < RSIDivergenceLookback + 3)
{
IndicatorRelease(hRSI);
return true;
}
IndicatorRelease(hRSI);

// Divergence haussière: prix fait un plus bas, RSI fait un plus haut
if(direction == "BUY")
{
double priceLow1 = rates[0].low;
double priceLow2 = rates[RSIDivergenceLookback].low;
double rsiLow1 = rsi[0];
double rsiLow2 = rsi[RSIDivergenceLookback];

// Prix plus bas mais RSI plus haut = divergence haussière
if(priceLow1 < priceLow2 && rsiLow1 > rsiLow2 + RSIDivergenceThreshold)
{
   divergenceType = "BULLISH";
   return true; // Divergence haussière confirme le BUY
}
}
// Divergence baissière: prix fait un plus haut, RSI fait un plus bas
else if(direction == "SELL")
{
double priceHigh1 = rates[0].high;
double priceHigh2 = rates[RSIDivergenceLookback].high;
double rsiHigh1 = rsi[0];
double rsiHigh2 = rsi[RSIDivergenceLookback];

// Prix plus haut mais RSI plus bas = divergence baissière
if(priceHigh1 > priceHigh2 && rsiHigh1 < rsiHigh2 - RSIDivergenceThreshold)
{
   divergenceType = "BEARISH";
   return true; // Divergence baissière confirme le SELL
}
}

// Pas de divergence, on ne bloque pas le signal
return true;
}

// Filtre Multi-Timeframe: vérifie l'alignement sur plusieurs TF
bool CheckMTFFilter(const string direction, string &mtfStatus)
{
if(!EnableMTFFilter) return true;

mtfStatus = "";

ENUM_TIMEFRAMES tfs[] = {PERIOD_M5, PERIOD_M15, PERIOD_H1};
string tfNames[] = {"M5", "M15", "H1"};
int alignedCount = 0;

for(int i = 0; i < 3; i++)
{
int bias = GetTFBias(tfs[i]);
bool aligned = (direction == "BUY" && bias > 0) || (direction == "SELL" && bias < 0);

if(aligned)
{
   alignedCount++;
   mtfStatus += tfNames[i] + "+ ";
}
else
{
   mtfStatus += tfNames[i] + "- ";
}
}

// Au moins 2 TF sur 3 alignés
return (alignedCount >= 2);
}

// Filtre Structure: vérifie la proximité des niveaux clés
bool CheckStructureFilter(const string direction, const double atrVal, string &structureStatus)
{
if(!EnableStructureFilter) return true;

structureStatus = "OK";

double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(bid <= 0.0) bid = iClose(_Symbol, PERIOD_CURRENT, 0);

double m5Buy = ReadGV("GOM_KOLA", "M5", "BUY");
double m5Sell = ReadGV("GOM_KOLA", "M5", "SELL");
double m15Buy = ReadGV("GOM_KOLA", "M15", "BUY");
double m15Sell = ReadGV("GOM_KOLA", "M15", "SELL");
double h1Buy = ReadGV("GOM_KOLA", "H1", "BUY");
double h1Sell = ReadGV("GOM_KOLA", "H1", "SELL");

double zone = atrVal * StructureATRMultiplier;
bool nearLevel = false;

if(direction == "BUY")
{
if(m5Buy > 0.0 && MathAbs(bid - m5Buy) <= zone) { nearLevel = true; structureStatus = "M5"; }
else if(m15Buy > 0.0 && MathAbs(bid - m15Buy) <= zone) { nearLevel = true; structureStatus = "M15"; }
else if(h1Buy > 0.0 && MathAbs(bid - h1Buy) <= zone) { nearLevel = true; structureStatus = "H1"; }
}
else if(direction == "SELL")
{
if(m5Sell > 0.0 && MathAbs(bid - m5Sell) <= zone) { nearLevel = true; structureStatus = "M5"; }
else if(m15Sell > 0.0 && MathAbs(bid - m15Sell) <= zone) { nearLevel = true; structureStatus = "M15"; }
else if(h1Sell > 0.0 && MathAbs(bid - h1Sell) <= zone) { nearLevel = true; structureStatus = "H1"; }
}

if(!nearLevel) structureStatus = "FAR";
return nearLevel;
}

// Filtre Volatilité: vérifie que l'ATR est suffisant
bool CheckVolatilityFilter(const double atrVal, const double bid)
{
if(!EnableVolatilityFilter) return true;

if(atrVal <= 0.0 || bid <= 0.0) return true;

double atrPct = (atrVal / bid) * 100.0;
return (atrPct >= VolatilityMinATRPct * 100.0);
}

// Fonction principale: applique tous les filtres et retourne les résultats
FilterResults ApplyAllFilters(const string direction, const double atrVal)
{
FilterResults result;
result.volumePass = true;
result.momentumPass = true;
result.rsiDivergencePass = true;
result.mtfPass = true;
result.structurePass = true;
result.volatilityPass = true;
result.passCount = 0;
result.totalFilters = 0;
result.failReason = "";

double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(bid <= 0.0) bid = iClose(_Symbol, PERIOD_CURRENT, 0);

// Filtre Volume
if(EnableVolumeFilter)
{
result.totalFilters++;
double avgVol = 0.0;
result.volumePass = CheckVolumeFilter(PERIOD_M1, VolumeLookback, avgVol);
if(result.volumePass) result.passCount++;
else result.failReason = "VOLUME";
}

// Filtre Momentum
if(EnableMomentumFilter)
{
result.totalFilters++;
result.momentumPass = CheckMomentumFilter(PERIOD_M1, direction);
if(result.momentumPass) result.passCount++;
else if(result.failReason == "") result.failReason = "MOMENTUM";
}

// Filtre Divergence RSI
if(EnableRSIDivergenceFilter)
{
result.totalFilters++;
string divType = "";
result.rsiDivergencePass = CheckRSIDivergenceFilter(PERIOD_M1, direction, divType);
if(result.rsiDivergencePass) result.passCount++;
else if(result.failReason == "") result.failReason = "RSI_DIV";
}

// Filtre Multi-Timeframe
if(EnableMTFFilter)
{
result.totalFilters++;
string mtfStatus = "";
result.mtfPass = CheckMTFFilter(direction, mtfStatus);
if(result.mtfPass) result.passCount++;
else if(result.failReason == "") result.failReason = "MTF";
}

// Filtre Structure
if(EnableStructureFilter)
{
result.totalFilters++;
string structStatus = "";
result.structurePass = CheckStructureFilter(direction, atrVal, structStatus);
if(result.structurePass) result.passCount++;
else if(result.failReason == "") result.failReason = "STRUCTURE";
}

// Filtre Volatilité
if(EnableVolatilityFilter)
{
result.totalFilters++;
result.volatilityPass = CheckVolatilityFilter(atrVal, bid);
if(result.volatilityPass) result.passCount++;
else if(result.failReason == "") result.failReason = "VOLATILITY";
}

return result;
}

// Fonction pour calculer le score de qualité basé sur les filtres
double CalculateFilterQualityScore(const FilterResults &filters)
{
if(filters.totalFilters == 0) return 1.0;

double ratio = (double)filters.passCount / (double)filters.totalFilters;

// Bonus si tous les filtres passent
if(filters.passCount == filters.totalFilters)
ratio += 0.2;

return MathMin(1.0, ratio);
}

// Fonction pour obtenir le texte de statut des filtres
string GetFilterStatusText(const FilterResults &filters)
{
string txt = "";
if(EnableVolumeFilter) txt += (filters.volumePass ? "VOL✓" : "VOL✗") + " ";
if(EnableMomentumFilter) txt += (filters.momentumPass ? "MOM✓" : "MOM✗") + " ";
if(EnableRSIDivergenceFilter) txt += (filters.rsiDivergencePass ? "RSI✓" : "RSI✗") + " ";
if(EnableMTFFilter) txt += (filters.mtfPass ? "MTF✓" : "MTF✗") + " ";
if(EnableStructureFilter) txt += (filters.structurePass ? "STR✓" : "STR✗") + " ";
if(EnableVolatilityFilter) txt += (filters.volatilityPass ? "ATR✓" : "ATR✗");

return txt;
}

// ---------- JSON minimal helpers (MQL5) ----------
string GOM_JsonExtractString(const string json, const string key, const string defVal = "")
{
string kq = "\"" + key + "\"";
int p = StringFind(json, kq);
if(p < 0) return defVal;
int c = StringFind(json, ":", p + StringLen(kq));
if(c < 0) return defVal;
int s = StringFind(json, "\"", c + 1);
if(s < 0) return defVal;
int e = StringFind(json, "\"", s + 1);
if(e < 0) return defVal;
return StringSubstr(json, s + 1, e - s - 1);
}

double GOM_JsonExtractNumber(const string json, const string key, const double defVal = 0.0)
{
string kq = "\"" + key + "\"";
int p = StringFind(json, kq);
if(p < 0) return defVal;
int c = StringFind(json, ":", p + StringLen(kq));
if(c < 0) return defVal;
int i = c + 1;
while(i < StringLen(json))
{
ushort ch = StringGetCharacter(json, i);
if(ch != ' ' && ch != '\t' && ch != '\r' && ch != '\n') break;
i++;
}
int j = i;
while(j < StringLen(json))
{
ushort ch = StringGetCharacter(json, j);
if((ch >= '0' && ch <= '9') || ch == '.' || ch == '-' || ch == '+') { j++; continue; }
break;
}
if(j <= i) return defVal;
string num = StringSubstr(json, i, j - i);
return StringToDouble(num);
}

string GOM_JsonQuote(const string s)
{
string t = s;
StringReplace(t, "\\", "\\\\");
StringReplace(t, "\"", "\\\"");
return "\"" + t + "\"";
}

string GOM_JsonNumberOrNull(const double v, const int digits = 8)
{
if(!MathIsValidNumber(v))
return "null";
if(v == DBL_MAX || v == -DBL_MAX)
return "null";
return DoubleToString(v, digits);
}

void GOM_UpdateExternalAI(const string symbol, const double bid, const double ask,
                     const double atrM15, const double rsiM1,
                     const double ema9M1, const double ema21M1,
                     const double ema9M5, const double ema21M5,
                     const double verdictNum,
                     const double spikeProb, const int spikeDirNum,
                     const double m5Buy, const double m5Sell,
                     const double m15Buy, const double m15Sell,
                     const double dtop, const double dbot)
{
if(!EnableExternalAIInterpretation) return;
if(ExternalAIUrl == "") return;

datetime now = TimeCurrent();
int throttleSec = MathMax(1, ExternalAIThrottleMs / 1000);
if(g_lastExtAiCall > 0 && (now - g_lastExtAiCall) < throttleSec)
return;
g_lastExtAiCall = now;

string payload =
"{" +
"\"symbol\":" + GOM_JsonQuote(symbol) + "," +
"\"bid\":" + GOM_JsonNumberOrNull(bid, _Digits) + "," +
"\"ask\":" + GOM_JsonNumberOrNull(ask, _Digits) + "," +
"\"atr_m15\":" + GOM_JsonNumberOrNull(atrM15, 8) + "," +
"\"rsi_m1\":" + GOM_JsonNumberOrNull(rsiM1, 2) + "," +
"\"ema9_m1\":" + GOM_JsonNumberOrNull(ema9M1, _Digits) + "," +
"\"ema21_m1\":" + GOM_JsonNumberOrNull(ema21M1, _Digits) + "," +
"\"ema9_m5\":" + GOM_JsonNumberOrNull(ema9M5, _Digits) + "," +
"\"ema21_m5\":" + GOM_JsonNumberOrNull(ema21M5, _Digits) + "," +
"\"verdict_num\":" + GOM_JsonNumberOrNull(verdictNum, 2) + "," +
"\"spike_prob\":" + GOM_JsonNumberOrNull(spikeProb, 4) + "," +
"\"spike_dir_num\":" + IntegerToString(spikeDirNum) + "," +
"\"m5_buy\":" + GOM_JsonNumberOrNull(m5Buy, _Digits) + "," +
"\"m5_sell\":" + GOM_JsonNumberOrNull(m5Sell, _Digits) + "," +
"\"m15_buy\":" + GOM_JsonNumberOrNull(m15Buy, _Digits) + "," +
"\"m15_sell\":" + GOM_JsonNumberOrNull(m15Sell, _Digits) + "," +
"\"sido_dtop\":" + GOM_JsonNumberOrNull(dtop, _Digits) + "," +
"\"sido_dbot\":" + GOM_JsonNumberOrNull(dbot, _Digits) +
"}";

char data[];
StringToCharArray(payload, data, 0, StringLen(payload), CP_UTF8);
char result[];
string headers = "Content-Type: application/json\r\n";
string result_headers = "";

ResetLastError();
int code = WebRequest("POST", ExternalAIUrl, headers, ExternalAITimeoutMs, data, result, result_headers);
if(code != 200)
{
string errBody = CharArrayToString(result, 0, -1, CP_UTF8);
int le = GetLastError();
Print("⚠️ GOM /gom/interpret url=", ExternalAIUrl, " http=", code, " lastError=", le, " | body=", errBody);
return;
}

string res = CharArrayToString(result, 0, -1, CP_UTF8);
string act = GOM_JsonExtractString(res, "action", "");
if(act == "") act = GOM_JsonExtractString(res, "ai_decision", "");
double conf = GOM_JsonExtractNumber(res, "confidence", 0.0);
if(conf <= 0.0) conf = GOM_JsonExtractNumber(res, "ai_confidence", 0.0);
string reason = GOM_JsonExtractString(res, "reason", "");
if(reason == "") reason = GOM_JsonExtractString(res, "ai_reasoning", "");

if(act != "")
{
StringToUpper(act);
g_lastExtAiAction = act;
g_lastExtAiConf = conf;
g_lastExtAiReason = reason;
GOM_GlobalSetForScript("EXT_AI_ACTION_NUM", (act == "BUY") ? 1.0 : ((act == "SELL") ? -1.0 : 0.0));
GOM_GlobalSetForScript("EXT_AI_CONF", conf);
}
}

double GOM_PredictSpikeProbabilityM1(const bool isBoom, const bool isCrash, string &spikeDirOut)
{
spikeDirOut = "NONE";
if(!EnableSpikePrediction || (!isBoom && !isCrash))
return 0.0;

int lb = MathMax(12, SpikeLookbackBarsM1);
MqlRates r[];
ArraySetAsSeries(r, true);
int copied = CopyRates(_Symbol, PERIOD_M1, 0, lb + 5, r);
if(copied < lb + 2)
return 0.0;

double sumRange = 0.0, sumVol = 0.0;
int n = 0;
for(int i = 2; i < copied && n < lb; i++, n++)
{
sumRange += MathMax(0.0, r[i].high - r[i].low);
sumVol += (double)r[i].tick_volume;
}
if(n <= 0) return 0.0;
double avgRange = sumRange / (double)n;
double avgVol = sumVol / (double)n;
if(avgRange <= 0.0) return 0.0;

double range0 = MathMax(0.0, r[0].high - r[0].low);
double range1 = MathMax(0.0, r[1].high - r[1].low);
double body0 = MathAbs(r[0].close - r[0].open);
double vol0 = (double)r[0].tick_volume;
double close0 = r[0].close;

// Moyenne des ranges « récents » (boucles 2..10) : phase compression avant spike
int compN = 0;
double compSum = 0.0;
for(int j = 2; j <= MathMin(10, copied - 1); j++)
{
compSum += MathMax(0.0, r[j].high - r[j].low);
compN++;
}
double avgRangeRecent = (compN > 0) ? compSum / (double)compN : avgRange;

double ema9 = GOM_EMAValue(_Symbol, PERIOD_M1, 9);
double ema21 = GOM_EMAValue(_Symbol, PERIOD_M1, 21);
double rsi = GOM_RSIValue(_Symbol, PERIOD_M1, 14);
double emaF = GOM_EMAValue(_Symbol, ScriptEmaTF, 9);
double emaS = GOM_EMAValue(_Symbol, ScriptEmaTF, 21);

double score = 0.0;

bool compressionZone = (avgRangeRecent < avgRange * 0.90);
bool stillQuiet = (range0 < avgRange * 1.02);
bool earlyStretch = compressionZone && (range0 >= avgRange * 0.82) && (range0 < avgRange * 1.15);

// --- Signal d’amorce (avant la grosse bougie) : évite la flèche seulement au pic ---
if(compressionZone && stillQuiet)
{
score += 0.20;
if(avgRangeRecent < avgRange * 0.76) score += 0.14;
if(avgVol > 0.0 && vol0 > avgVol * 0.92 && vol0 < avgVol * 1.55) score += 0.12;
}
if(earlyStretch)
score += 0.12;
if(range1 < avgRange * 0.88) score += 0.10;

// Confirmation tardive (moins pondérée qu’avant pour ne pas dominer)
if(range0 > avgRange * 1.18) score += 0.10;
if(body0 > avgRange * 0.52) score += 0.10;
if(avgVol > 0.0 && vol0 > avgVol * 1.22) score += 0.10;

bool bullMicro = (ema9 > 0.0 && ema21 > 0.0 && ema9 >= ema21 && rsi >= 50.0 && close0 >= ema9 * 0.9995);
bool bearMicro = (ema9 > 0.0 && ema21 > 0.0 && ema9 < ema21 && rsi <= 50.0 && close0 <= ema9 * 1.0005);
if(bullMicro) score += 0.12;
if(bearMicro) score += 0.12;

// Ruban EMA (même TF que les courbes affichées)
if(emaF > 0.0 && emaS > 0.0)
{
if(isBoom && emaF >= emaS && close0 >= emaF * 0.999) score += 0.14;
else if(isCrash && emaF < emaS && close0 <= emaF * 1.001) score += 0.14;
else if(isBoom && close0 > emaF) score += 0.06;
else if(isCrash && close0 < emaF) score += 0.06;
}

if(GOM_GlobalGetForScript("BB_SQUEEZE", 0.0) > 0.5)
score += 0.10;

double leadScore = score;
GOM_GlobalSetForScript("SPIKE_LEAD_RAW", leadScore);

if(isBoom)
{
score += 0.08;
spikeDirOut = "BUY";
if(bearMicro) score *= 0.90;
}
else if(isCrash)
{
score += 0.08;
spikeDirOut = "SELL";
if(bullMicro) score *= 0.90;
}

if(score > 1.0) score = 1.0;
if(score < 0.0) score = 0.0;
return score;
}

void UpdateScriptLastTs()
{
GOM_GlobalSetForScript("LAST_TS", (double)TimeCurrent());
}

void DrawScriptLiveLabel(const string labelName, const string text)
{
if(ObjectFind(0, labelName) < 0)
ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 140);
ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
ObjectSetString(0, labelName, OBJPROP_FONT, "Consolas");
ObjectSetString(0, labelName, OBJPROP_TEXT, text);
ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
}

void PublishLevel(const string moduleTag, const string tfTag, const string side, const double level)
{
GlobalVariableSet(GVKey(moduleTag, tfTag, side), level);
}

bool IsPivotHigh(const MqlRates &rates[], const int n, const int i, const int lb)
{
double v = rates[i].high;
for(int k = 1; k <= lb; k++)
if(i - k < 0 || i + k >= n || rates[i - k].high >= v || rates[i + k].high > v)
   return false;
return true;
}

bool IsPivotLow(const MqlRates &rates[], const int n, const int i, const int lb)
{
double v = rates[i].low;
for(int k = 1; k <= lb; k++)
if(i - k < 0 || i + k >= n || rates[i - k].low <= v || rates[i + k].low < v)
   return false;
return true;
}

int CalcTouches(const MqlRates &rates[], const int n, const double level, const double zone, const int barsLookback)
{
int touches = 0;
int lim = MathMin(n - 1, barsLookback);
for(int i = 0; i <= lim; i++)
{
double hi = rates[i].high;
double lo = rates[i].low;
if(MathAbs(hi - level) <= zone || MathAbs(lo - level) <= zone || (lo <= level && hi >= level))
   touches++;
}
return touches;
}

int WidthFromTouches(const int touches)
{
int tMax = MathMax(1, TouchesForMaxWidth);
double r = MathMin(1.0, (double)touches / (double)tMax);
int w = (int)MathRound(MinLineWidth + (MaxLineWidth - MinLineWidth) * r);
return (int)MathMax(MinLineWidth, MathMin(MaxLineWidth, w));
}

int EntryConfidencePercent(const int touches)
{
int tMax = MathMax(1, TouchesForMaxWidth);
double r = MathMin(1.0, (double)touches / (double)tMax);
int c = (int)MathRound(55.0 + r * 45.0); // 55..100%
return (int)MathMax(0, MathMin(100, c));
}

void DrawKolaLevel(const string tfTag, const string side, const double level, const int touches, const color clr, const ENUM_TIMEFRAMES tf)
{
string nm = "GOM_KOLA_" + side + "_" + tfTag;
if(ObjectFind(0, nm) < 0)
ObjectCreate(0, nm, OBJ_HLINE, 0, 0, level);

ObjectSetDouble(0, nm, OBJPROP_PRICE, level);
ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
ObjectSetInteger(0, nm, OBJPROP_WIDTH, WidthFromTouches(touches));
ObjectSetInteger(0, nm, OBJPROP_BACK, false);
ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, true);
ObjectSetInteger(0, nm, OBJPROP_HIDDEN, false);

string labelName = nm + "_LBL";
if(!ShowLabels)
{
ObjectDelete(0, labelName);
return;
}

int confPct = EntryConfidencePercent(MathMax(1, touches));
string txt = tfTag + " " + side + " Entry (" + IntegerToString(confPct) + "%)";
if(ShowTouchCount) txt += " (" + IntegerToString(touches) + ")";

int visShift = MathMax(0, LabelShiftBars);
datetime t = iTime(_Symbol, PERIOD_CURRENT, visShift);
if(t <= 0) t = iTime(_Symbol, PERIOD_CURRENT, 0);
if(ObjectFind(0, labelName) < 0)
ObjectCreate(0, labelName, OBJ_TEXT, 0, t, level);

ObjectMove(0, labelName, 0, t, level);
ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
}

void DrawSIDOPattern(const string tfTag, const string patternType, const int idxA, const int idxB, const double levelA, const double levelB, const color clr, const MqlRates &rates[])
{
string base = "GOM_SIDO_" + patternType + "_" + tfTag;
string line = base + "_LN";
string label = base + "_LBL";

datetime tA = rates[idxA].time;
datetime tB = rates[idxB].time;
double y = (levelA + levelB) * 0.5;
datetime tLabel = iTime(_Symbol, PERIOD_CURRENT, MathMax(0, LabelShiftBars));
if(tLabel <= 0) tLabel = tB;

if(ObjectFind(0, line) < 0)
ObjectCreate(0, line, OBJ_TREND, 0, tA, levelA, tB, levelB);

ObjectMove(0, line, 0, tA, levelA);
ObjectMove(0, line, 1, tB, levelB);
ObjectSetInteger(0, line, OBJPROP_COLOR, clr);
ObjectSetInteger(0, line, OBJPROP_WIDTH, 2);
ObjectSetInteger(0, line, OBJPROP_STYLE, STYLE_DASH);
ObjectSetInteger(0, line, OBJPROP_RAY_RIGHT, false);
ObjectSetInteger(0, line, OBJPROP_HIDDEN, false);

if(!ShowSIDOLabels)
{
ObjectDelete(0, label);
return;
}

if(ObjectFind(0, label) < 0)
ObjectCreate(0, label, OBJ_TEXT, 0, tLabel, y);

ObjectMove(0, label, 0, tLabel, y);
ObjectSetString(0, label, OBJPROP_TEXT, tfTag + " " + patternType);
ObjectSetString(0, label, OBJPROP_FONT, "Arial");
ObjectSetInteger(0, label, OBJPROP_COLOR, clr);
ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
ObjectSetInteger(0, label, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
ObjectSetInteger(0, label, OBJPROP_BACK, false);
}

void ClearTFObjects(const string tfTag)
{
ObjectDelete(0, "GOM_KOLA_BUY_" + tfTag);
ObjectDelete(0, "GOM_KOLA_SELL_" + tfTag);
ObjectDelete(0, "GOM_KOLA_BUY_" + tfTag + "_LBL");
ObjectDelete(0, "GOM_KOLA_SELL_" + tfTag + "_LBL");

ObjectDelete(0, "GOM_SIDO_DOUBLE_TOP_" + tfTag + "_LN");
ObjectDelete(0, "GOM_SIDO_DOUBLE_TOP_" + tfTag + "_LBL");
ObjectDelete(0, "GOM_SIDO_DOUBLE_BOTTOM_" + tfTag + "_LN");
ObjectDelete(0, "GOM_SIDO_DOUBLE_BOTTOM_" + tfTag + "_LBL");
}

void ProcessKolaTF(const ENUM_TIMEFRAMES tf, const MqlRates &rates[], const int copied, const double atrVal)
{
string tfTag = TFTag(tf);
if(tfTag == "UNK") return;

int lb = MathMax(1, LineBreakPeriod);
if(copied < (lb * 3 + 20))
{
PublishLevel("GOM_KOLA", tfTag, "BUY", 0.0);
PublishLevel("GOM_KOLA", tfTag, "SELL", 0.0);
return;
}

double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(bid <= 0.0) bid = rates[0].close;
double zone = EnableTouchDetection ? (atrVal * (TouchZoneATRPercent / 100.0)) : 0.0;

double bestBuy = 0.0, bestSell = 0.0;
int bestBuyTouches = -1, bestSellTouches = -1;
int maxIdx = MathMin(copied - lb - 1, MaxBarsToAnalyze);

for(int i = lb + 1; i <= maxIdx; i++)
{
if(IsPivotLow(rates, copied, i, lb))
{
   double lvl = rates[i].low;
   int touches = EnableTouchDetection ? CalcTouches(rates, copied, lvl, zone, BarsForTouchCount) : 1;
   bool better = (lvl < bid) ? ((touches > bestBuyTouches) || (touches == bestBuyTouches && lvl > bestBuy))
                              : (bestBuy <= 0.0 && touches > bestBuyTouches);
   if(better) { bestBuy = lvl; bestBuyTouches = touches; }
}

if(IsPivotHigh(rates, copied, i, lb))
{
   double lvl = rates[i].high;
   int touches = EnableTouchDetection ? CalcTouches(rates, copied, lvl, zone, BarsForTouchCount) : 1;
   bool better = (lvl > bid) ? ((touches > bestSellTouches) || (touches == bestSellTouches && (bestSell <= 0.0 || lvl < bestSell)))
                              : (bestSell <= 0.0 && touches > bestSellTouches);
   if(better) { bestSell = lvl; bestSellTouches = touches; }
}
}

// Guardrails symbole: pas de BUY sur Crash, pas de SELL sur Boom
if(!GOM_IsDirectionAllowedForSymbol("BUY")) bestBuy = 0.0;
if(!GOM_IsDirectionAllowedForSymbol("SELL")) bestSell = 0.0;

if(bestBuy > 0.0) DrawKolaLevel(tfTag, "BUY", bestBuy, MathMax(1, bestBuyTouches), BuyLevelColor, tf);
if(bestSell > 0.0) DrawKolaLevel(tfTag, "SELL", bestSell, MathMax(1, bestSellTouches), SellLevelColor, tf);

PublishLevel("GOM_KOLA", tfTag, "BUY", bestBuy);
PublishLevel("GOM_KOLA", tfTag, "SELL", bestSell);
}

void ProcessSIDOTF(const ENUM_TIMEFRAMES tf, const MqlRates &rates[], const int copied, const double atrVal)
{
string tfTag = TFTag(tf);
if(tfTag == "UNK") return;

if(!EnableSIDO)
{
PublishLevel("GOM_SIDO", tfTag, "DOUBLE_TOP", 0.0);
PublishLevel("GOM_SIDO", tfTag, "DOUBLE_BOTTOM", 0.0);
return;
}

int lb = MathMax(1, SIDOPivotLookback);
if(copied < (lb * 3 + 20))
{
PublishLevel("GOM_SIDO", tfTag, "DOUBLE_TOP", 0.0);
PublishLevel("GOM_SIDO", tfTag, "DOUBLE_BOTTOM", 0.0);
return;
}

double tol = atrVal * (SIDOToleranceATRPercent / 100.0);
int maxIdx = MathMin(copied - lb - 1, SIDOBarsToAnalyze);

int lastHigh1 = -1, lastHigh2 = -1, lastLow1 = -1, lastLow2 = -1;
for(int i = lb + 1; i <= maxIdx; i++)
{
if(IsPivotHigh(rates, copied, i, lb))
{
   lastHigh2 = lastHigh1;
   lastHigh1 = i;
}
if(IsPivotLow(rates, copied, i, lb))
{
   lastLow2 = lastLow1;
   lastLow1 = i;
}
}

bool hasDoubleTop = false, hasDoubleBottom = false;
double topLevel = 0.0, bottomLevel = 0.0;

if(lastHigh1 >= 0 && lastHigh2 >= 0)
{
int barsGap = MathAbs(lastHigh1 - lastHigh2);
double a = rates[lastHigh1].high;
double b = rates[lastHigh2].high;
if(barsGap <= SIDOMaxBarsBetweenSwings && MathAbs(a - b) <= tol)
{
   hasDoubleTop = true;
   topLevel = (a + b) * 0.5;
   DrawSIDOPattern(tfTag, "DOUBLE_TOP", lastHigh2, lastHigh1, b, a, SIDODoubleTopColor, rates);
}
}

if(lastLow1 >= 0 && lastLow2 >= 0)
{
int barsGap = MathAbs(lastLow1 - lastLow2);
double a = rates[lastLow1].low;
double b = rates[lastLow2].low;
if(barsGap <= SIDOMaxBarsBetweenSwings && MathAbs(a - b) <= tol)
{
   hasDoubleBottom = true;
   bottomLevel = (a + b) * 0.5;
   DrawSIDOPattern(tfTag, "DOUBLE_BOTTOM", lastLow2, lastLow1, b, a, SIDODoubleBottomColor, rates);
}
}

if(!hasDoubleTop)
{
ObjectDelete(0, "GOM_SIDO_DOUBLE_TOP_" + tfTag + "_LN");
ObjectDelete(0, "GOM_SIDO_DOUBLE_TOP_" + tfTag + "_LBL");
}
if(!hasDoubleBottom)
{
ObjectDelete(0, "GOM_SIDO_DOUBLE_BOTTOM_" + tfTag + "_LN");
ObjectDelete(0, "GOM_SIDO_DOUBLE_BOTTOM_" + tfTag + "_LBL");
}

PublishLevel("GOM_SIDO", tfTag, "DOUBLE_TOP", topLevel);
PublishLevel("GOM_SIDO", tfTag, "DOUBLE_BOTTOM", bottomLevel);
}

void ProcessTF(const ENUM_TIMEFRAMES tf)
{
int barsNeeded = MathMax(80, MathMax(MaxBarsToAnalyze, SIDOBarsToAnalyze) + MathMax(LineBreakPeriod, SIDOPivotLookback) * 4);
MqlRates rates[];
ArraySetAsSeries(rates, true);
int copied = CopyRates(_Symbol, tf, 0, barsNeeded, rates);
if(copied <= 0) return;

double atrVal = GOM_ATRValue(_Symbol, tf, 14);
if(atrVal <= 0.0)
{
double fallback = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(fallback <= 0.0) fallback = rates[0].close;
atrVal = fallback * 0.001;
}

ProcessKolaTF(tf, rates, copied, atrVal);
ProcessSIDOTF(tf, rates, copied, atrVal);
}

void ProcessOrClear(const ENUM_TIMEFRAMES tf, const bool enabled)
{
string tag = TFTag(tf);
if(enabled) ProcessTF(tf);
else
{
ClearTFObjects(tag);
PublishLevel("GOM_KOLA", tag, "BUY", 0.0);
PublishLevel("GOM_KOLA", tag, "SELL", 0.0);
PublishLevel("GOM_SIDO", tag, "DOUBLE_TOP", 0.0);
PublishLevel("GOM_SIDO", tag, "DOUBLE_BOTTOM", 0.0);
}
}

// Projection locale « 500 prochaines bougies M1 » : extrapolation linéaire (tendance récente) + plafond ; publiée en GOM_SCRIPT_*.
void GOM_UpdateM1Forecast500Globals(const double refPx)
{
GOM_GlobalSetForScript("M1_F500_VALID", 0.0);
GOM_GlobalSetForScript("M1_F500_PRED_PX", 0.0);
GOM_GlobalSetForScript("M1_F500_RET_PCT", 0.0);
GOM_GlobalSetForScript("M1_F500_DIR", 0.0);
GOM_GlobalSetForScript("M1_F500_SLOPE", 0.0);
GOM_GlobalSetForScript("M1_F500_REF_CLOSE", 0.0);
if(refPx <= 0.0) return;

MqlRates r[];
ArraySetAsSeries(r, true);
int n = CopyRates(_Symbol, PERIOD_M1, 0, 620, r);
int m = MathMin(MathMax(80, M1ForecastRegressionBars), n - 2);
if(m < 80) return;

double sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0;
int cnt = 0;
for(int i = 0; i < m; i++)
{
double yi = r[i].close;
if(yi <= 0.0) continue;
double xi = (double)i;
sumX += xi;
sumY += yi;
sumXY += xi * yi;
sumX2 += xi * xi;
cnt++;
}
if(cnt < 60) return;
double denom = (double)cnt * sumX2 - sumX * sumX;
if(MathAbs(denom) < 1e-24) return;
double b = ((double)cnt * sumXY - sumX * sumY) / denom;
double a = (sumY - b * sumX) / (double)cnt;
double predPx = a + b * (-500.0);
double retPct = ((predPx - refPx) / refPx) * 100.0;
if(retPct > M1ForecastMaxAbsPct) retPct = M1ForecastMaxAbsPct;
if(retPct < -M1ForecastMaxAbsPct) retPct = -M1ForecastMaxAbsPct;

double atr1 = GOM_ATRValue(_Symbol, PERIOD_M1, 14);
if(atr1 > 0.0 && MathAbs(predPx - refPx) > atr1 * 80.0)
{
predPx = refPx + ((predPx > refPx) ? 1.0 : -1.0) * atr1 * 80.0;
retPct = ((predPx - refPx) / refPx) * 100.0;
if(retPct > M1ForecastMaxAbsPct) retPct = M1ForecastMaxAbsPct;
if(retPct < -M1ForecastMaxAbsPct) retPct = -M1ForecastMaxAbsPct;
}

double dirNum = 0.0;
if(predPx > refPx * 1.0003) dirNum = 1.0;
else if(predPx < refPx * 0.9997) dirNum = -1.0;

GOM_GlobalSetForScript("M1_F500_PRED_PX", predPx);
GOM_GlobalSetForScript("M1_F500_RET_PCT", retPct);
GOM_GlobalSetForScript("M1_F500_DIR", dirNum);
GOM_GlobalSetForScript("M1_F500_SLOPE", b);
GOM_GlobalSetForScript("M1_F500_REF_CLOSE", r[0].close);
GOM_GlobalSetForScript("M1_F500_VALID", 1.0);
}

void GOM_DeleteM1ForecastChartOverlay(void)
{
int n = ObjectsTotal(0);
for(int i = n - 1; i >= 0; i--)
{
string nm = ObjectName(0, i);
if(StringFind(nm, GOM_F500V_PREFIX) == 0)
ObjectDelete(0, nm);
}
}

// Projection visuelle : rectangles M1 + ligne (même droite que le bandeau M1×500).
void GOM_DrawM1ForecastChartOverlay(const double bidFallback)
{
if(!ShowM1Forecast500ChartOverlay)
{
GOM_DeleteM1ForecastChartOverlay();
return;
}
if(GOM_GlobalGetForScript("M1_F500_VALID", 0.0) < 0.5)
{
GOM_DeleteM1ForecastChartOverlay();
return;
}
double predPx = GOM_GlobalGetForScript("M1_F500_PRED_PX", 0.0);
double refC = GOM_GlobalGetForScript("M1_F500_REF_CLOSE", 0.0);
if(refC <= 0.0) refC = iClose(_Symbol, PERIOD_M1, 0);
if(refC <= 0.0) refC = bidFallback;
if(refC <= 0.0 || predPx <= 0.0)
{
GOM_DeleteM1ForecastChartOverlay();
return;
}
MqlRates rr[];
ArraySetAsSeries(rr, true);
if(CopyRates(_Symbol, PERIOD_M1, 0, 2, rr) < 1)
{
GOM_DeleteM1ForecastChartOverlay();
return;
}
datetime t0 = rr[0].time;
int sec = (int)PeriodSeconds(PERIOD_M1);
if(sec < 1) sec = 60;
int nb = MathMax(4, MathMin(M1ForecastChartBarsDraw, 120));
double atr1 = GOM_ATRValue(_Symbol, PERIOD_M1, 14);
if(atr1 <= 0.0) atr1 = refC * 0.00015;
if(M1ForecastForceChartShift)
{
double shiftPct = M1ForecastChartShiftPct;
if(shiftPct < 8.0) shiftPct = 8.0;
if(shiftPct > 45.0) shiftPct = 45.0;
ChartSetInteger(0, CHART_SHIFT, true);
ChartSetDouble(0, CHART_SHIFT_SIZE, shiftPct / 100.0);
}

GOM_DeleteM1ForecastChartOverlay();

double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
if(pt <= 0.0) pt = 0.00001;
double minBody = MathMax(atr1 * 0.035, pt * 5.0);
double cPrev = refC;
for(int k = 1; k <= nb; k++)
{
double cNext = refC + (predPx - refC) * ((double)k / 500.0);
double o = cPrev;
double c = cNext;
double drift = MathAbs(c - o);
double wick = MathMax(atr1 * 0.09, drift * 0.45);
double hi = MathMax(o, c) + wick;
double lo = MathMin(o, c) - wick;
if(hi - lo < minBody)
{
double mid = (o + c) * 0.5;
hi = mid + minBody * 0.5;
lo = mid - minBody * 0.5;
}
datetime tOpen = t0 + (datetime)((k - 1) * sec);
datetime tClose = t0 + (datetime)(k * sec);
if(tClose <= tOpen) tClose = tOpen + (datetime)sec;
datetime tMid = tOpen + (datetime)(sec / 2);
if(tMid <= tOpen) tMid = tOpen + 1;
datetime tA = tOpen + (datetime)(sec / 5);
datetime tB = tClose - (datetime)(sec / 5);
if(tB <= tA) tB = tA + 1;
string nmW = GOM_F500V_PREFIX + "W_" + IntegerToString(k);
ObjectCreate(0, nmW, OBJ_TREND, 0, tMid, hi, tMid, lo);
color body = (c >= o) ? clrLimeGreen : clrTomato;
ObjectSetInteger(0, nmW, OBJPROP_COLOR, body);
ObjectSetInteger(0, nmW, OBJPROP_WIDTH, 1);
ObjectSetInteger(0, nmW, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, nmW, OBJPROP_BACK, false);
ObjectSetInteger(0, nmW, OBJPROP_HIDDEN, false);
ObjectSetInteger(0, nmW, OBJPROP_ZORDER, 28);

double bTop = MathMax(o, c);
double bBot = MathMin(o, c);
if(bTop - bBot < minBody * 0.55)
{
double bMid = (o + c) * 0.5;
bTop = bMid + minBody * 0.275;
bBot = bMid - minBody * 0.275;
}
string nmB = GOM_F500V_PREFIX + "B_" + IntegerToString(k);
ObjectCreate(0, nmB, OBJ_RECTANGLE, 0, tA, bTop, tB, bBot);
ObjectSetInteger(0, nmB, OBJPROP_COLOR, body);
ObjectSetInteger(0, nmB, OBJPROP_STYLE, STYLE_SOLID);
ObjectSetInteger(0, nmB, OBJPROP_WIDTH, 1);
ObjectSetInteger(0, nmB, OBJPROP_FILL, true);
ObjectSetInteger(0, nmB, OBJPROP_BACK, false);
ObjectSetInteger(0, nmB, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, nmB, OBJPROP_HIDDEN, false);
ObjectSetInteger(0, nmB, OBJPROP_ZORDER, 30);
cPrev = cNext;
}
}

int GetTFBias(const ENUM_TIMEFRAMES tf)
{
int hFast = iMA(_Symbol, tf, 20, 0, MODE_EMA, PRICE_CLOSE);
int hSlow = iMA(_Symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE)
{
if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
return 0;
}

double f[], s[];
ArrayResize(f, 1);
ArrayResize(s, 1);
ArraySetAsSeries(f, true);
ArraySetAsSeries(s, true);
int c1 = CopyBuffer(hFast, 0, 0, 1, f);
int c2 = CopyBuffer(hSlow, 0, 0, 1, s);
IndicatorRelease(hFast);
IndicatorRelease(hSlow);
if(c1 < 1 || c2 < 1) return 0;
if(f[0] > s[0]) return 1;
if(f[0] < s[0]) return -1;
return 0;
}

void GOM_PositionLabelInCell(const string txtName, const int x, const int y, const int w, const int h, const int fontPx, const string text)
{
ObjectSetInteger(0, txtName, OBJPROP_ANCHOR, ANCHOR_CENTER);
ObjectSetInteger(0, txtName, OBJPROP_XDISTANCE, x + w / 2);
ObjectSetInteger(0, txtName, OBJPROP_YDISTANCE, y + h / 2);
}

void DrawDashboardCellFont(const string name, const string text, const int x, const int y, const int w, const int h, const color bg, const color fg, const int fontPx, const bool useBold = false)
{
   string txtName = name + "_TXT";
   
   if(bg == clrNONE)
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
   }
   else
   {
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_COLOR, DashboardCellBorderColor);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetString(0, name, OBJPROP_TEXT, "");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, MathMax(100, DashboardLabelZOrder - 1));
   }

   if(ObjectFind(0, txtName) < 0)
      ObjectCreate(0, txtName, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, txtName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, txtName, OBJPROP_COLOR, clrWhite); // Texte en blanc sur les cellules colorées
   ObjectSetString(0, txtName, OBJPROP_FONT, "Segoe UI");
   ObjectSetString(0, txtName, OBJPROP_TEXT, text);
   int fsClamped = MathMax(9, fontPx);
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, fsClamped);
   GOM_PositionLabelInCell(txtName, x, y, w, h, fsClamped, text);
   ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, txtName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, txtName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, txtName, OBJPROP_BACK, false);
   ObjectSetInteger(0, txtName, OBJPROP_ZORDER, MathMax(101, DashboardLabelZOrder + 1));
}

void DrawDashboardCell(const string name, const string text, const int x, const int y, const int w, const int h, const color bg, const color fg)
{
int cellFs = MathMax(6, DashboardFontSize);
DrawDashboardCellFont(name, text, x, y, w, h, bg, fg, cellFs);
}

// Cellule verdict: plus haute, police plus grande, bordure contrastée.
void DrawDashboardVerdictCell(const string name, const string text, const int x, const int y, const int w, const int h, const color bg, const color borderClr, const color fg, const int fontPx)
{
   string txtName = name + "_TXT";
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, borderClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetString(0, name, OBJPROP_TEXT, "");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, MathMax(100, DashboardLabelZOrder - 1));

   if(ObjectFind(0, txtName) < 0)
      ObjectCreate(0, txtName, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, txtName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, txtName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, fontPx);
   ObjectSetString(0, txtName, OBJPROP_FONT, "Segoe UI Bold"); // Belle police robuste
   ObjectSetString(0, txtName, OBJPROP_TEXT, text);
   GOM_PositionLabelInCell(txtName, x, y, w, h, fontPx, text);
   ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, txtName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, txtName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, txtName, OBJPROP_BACK, false);
   ObjectSetInteger(0, txtName, OBJPROP_ZORDER, MathMax(101, DashboardLabelZOrder + 1));
}

void DrawDashboardPanel(const string name, const int x, const int y, const int w, const int h, const color bg)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (color)0x242424);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetString(0, name, OBJPROP_TEXT, "");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, MathMax(80, DashboardLabelZOrder - 3));
}

void GOM_DeleteDashboardFullStripObjects(void)
{
string tfs[6] = {"M5", "M15", "M30", "H1", "H4", "D1"};
for(int i = 0; i < 6; i++)
{
ObjectDelete(0, DASH_PREFIX + "TOP_" + tfs[i]);
ObjectDelete(0, DASH_PREFIX + "TOP_" + tfs[i] + "_TXT");
ObjectDelete(0, DASH_PREFIX + "COMPACT_TF_" + tfs[i]);
ObjectDelete(0, DASH_PREFIX + "COMPACT_TF_" + tfs[i] + "_TXT");
}
ObjectDelete(0, DASH_PREFIX + "TOP_VERDICT");
ObjectDelete(0, DASH_PREFIX + "TOP_VERDICT_TXT");
string botIds[] = {
"BOT_BRAND", "BOT_LVL", "BOT_VOL", "BOT_ATR", "BOT_SIDO", "BOT_KOLA", "BOT_RSIMACD", "BOT_FILTERS",
"BOT_EQ", "BOT_BB", "BOT_VWAP", "BOT_ADXST",
"BOT_META_DIR", "BOT_META_SRV", "BOT_META_LLM", "BOT_META_PX", "BOT_META_SPR", "BOT_META_VER",
"BOT_DIRMETA", "BOT_TV_SIDE", "BOT_TV_VER",
"BOTB_M5", "BOTB_M15", "BOTB_M30", "BOTB_H1", "BOTB_H4", "BOTB_D1", "BOTB_END",
"BOTF_FULL"
};
for(int j = 0; j < ArraySize(botIds); j++)
{
ObjectDelete(0, DASH_PREFIX + botIds[j]);
ObjectDelete(0, DASH_PREFIX + botIds[j] + "_TXT");
}
}

// Symboles direction / étoile : fallback ASCII si la police du terminal n’affiche pas le BMP.
string GOM_UnicodeChar(const ushort code)
{
if(code == 0x25B2) return "^";
if(code == 0x25BC) return "v";
if(code == 0x25CB) return "o";
if(code == 0x2605) return "*";
ushort u[1];
u[0] = code;
return ShortArrayToString(u, 0, 1);
}

string BiasArrowSymbol(const int bias)
{
if(bias > 0) return GOM_UnicodeChar(0x25B2);
if(bias < 0) return GOM_UnicodeChar(0x25BC);
return "-";
}

string BiasText(const string tfName, const int bias)
{
return tfName + " " + BiasArrowSymbol(bias);
}

double ReadGV(const string moduleTag, const string tfTag, const string sideTag)
{
string k = GVKey(moduleTag, tfTag, sideTag);
if(!GlobalVariableCheck(k)) return 0.0;
return GlobalVariableGet(k);
}

double ReadGVDirect(const string key, const double defValue = 0.0)
{
if(!GlobalVariableCheck(key)) return defValue;
return GlobalVariableGet(key);
}

string FmtPrice(const double v)
{
if(v <= 0.0) return "-";
return DoubleToString(v, _Digits);
}

void DrawPriceTag(const string name, const string txt, const double price, const color clr)
{
datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
if(t <= 0) t = TimeCurrent();
int shift = MathMax(1, LabelShiftBars);
datetime tx = t + (datetime)(shift * PeriodSeconds(PERIOD_CURRENT));

if(ObjectFind(0, name) < 0)
ObjectCreate(0, name, OBJ_TEXT, 0, tx, price);
ObjectMove(0, name, 0, tx, price);
ObjectSetString(0, name, OBJPROP_TEXT, txt);
ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void DrawOrUpdateHLine(const string name, const double price, const color clr, const ENUM_LINE_STYLE style, const int width)
{
if(price <= 0.0) return;
if(ObjectFind(0, name) < 0)
ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
ObjectSetDouble(0, name, OBJPROP_PRICE, price);
ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
ObjectSetInteger(0, name, OBJPROP_STYLE, style);
ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
ObjectSetInteger(0, name, OBJPROP_BACK, false);
ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

void DrawAndPublishScriptEMAs()
{
int periods[10] = {9, 21, 13, 50, 100, 200, 66, 75, 123, 34};
if(!ShowScriptEMAs)
{
GOM_DeleteChartObjectsByPrefix("GOM_EMAC_");
for(int j = 0; j < 10; j++)
ObjectDelete(0, "GOM_EMA_" + IntegerToString(periods[j]));
return;
}

GOM_DeleteChartObjectsByPrefix("GOM_EMAC_");
for(int j = 0; j < 10; j++)
ObjectDelete(0, "GOM_EMA_" + IntegerToString(periods[j]));

int barsTf = iBars(_Symbol, ScriptEmaTF);
if(barsTf < 3) return;
int nSeg = ScriptEmaCurveBars;
if(nSeg < 20) nSeg = 20;
if(nSeg > barsTf - 1) nSeg = barsTf - 1;
if(nSeg > 2000) nSeg = 2000;

color cols[10] = {clrDodgerBlue, clrOrange, clrDeepSkyBlue, clrLimeGreen, clrGold, clrRed, clrMagenta, clrMediumOrchid, clrAqua, clrSilver};

for(int i = 0; i < 10; i++)
{
int p = periods[i];
int h = iMA(_Symbol, ScriptEmaTF, p, 0, MODE_EMA, PRICE_CLOSE);
if(h == INVALID_HANDLE) continue;
double buf[];
ArraySetAsSeries(buf, true);
int need = nSeg + 1;
int nc = CopyBuffer(h, 0, 0, need, buf);
IndicatorRelease(h);
if(nc < 2) continue;

string gv = "GOM_SCRIPT_" + _Symbol + "_EMA_" + IntegerToString(p);
if(buf[0] > 0.0)
GlobalVariableSet(gv, buf[0]);

const string pfx = "GOM_EMAC_" + IntegerToString(p) + "_";
for(int k = 0; k < nc - 1; k++)
{
double vNew = buf[k];
double vOld = buf[k + 1];
if(vNew <= 0.0 || vOld <= 0.0) continue;
datetime tNew = iTime(_Symbol, ScriptEmaTF, k);
datetime tOld = iTime(_Symbol, ScriptEmaTF, k + 1);
if(tNew <= 0 || tOld <= 0) continue;

string segNm = pfx + IntegerToString(k);
if(ObjectFind(0, segNm) < 0)
ObjectCreate(0, segNm, OBJ_TREND, 0, tOld, vOld, tNew, vNew);
else
{
ObjectMove(0, segNm, 0, tOld, vOld);
ObjectMove(0, segNm, 1, tNew, vNew);
}
ObjectSetInteger(0, segNm, OBJPROP_COLOR, cols[i]);
ObjectSetInteger(0, segNm, OBJPROP_STYLE, STYLE_SOLID);
ObjectSetInteger(0, segNm, OBJPROP_WIDTH, 1);
ObjectSetInteger(0, segNm, OBJPROP_RAY_RIGHT, false);
ObjectSetInteger(0, segNm, OBJPROP_RAY_LEFT, false);
ObjectSetInteger(0, segNm, OBJPROP_BACK, true);
ObjectSetInteger(0, segNm, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, segNm, OBJPROP_SELECTED, false);
ObjectSetInteger(0, segNm, OBJPROP_HIDDEN, false);
}
}
}

void GOMScript_DrawSignalArrow(const string dir, const double entry)
{
   const string nm = "GOM_PLAN_ARROW";
   if(dir != "BUY" && dir != "SELL")
   {
      ObjectDelete(0, nm);
      return;
   }
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t <= 0) t = TimeCurrent();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) point = 0.1;
   double y = (dir == "BUY") ? (entry - 12.0 * point) : (entry + 12.0 * point);
   
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_ARROW, 0, t, y);
   ObjectMove(0, nm, 0, t, y);
   ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, (dir == "BUY") ? 241 : 242);
   
   // Logic clignotante pour signal actif
   bool blinkOn = (((int)(GetTickCount() / 380)) % 2) == 0;
   color cHi = (dir == "BUY") ? clrLime : clrTomato;
   color cLo = (dir == "BUY") ? clrGreen : clrFireBrick;
   ObjectSetInteger(0, nm, OBJPROP_COLOR, blinkOn ? cHi : cLo);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, blinkOn ? 6 : 2);
   ObjectSetInteger(0, nm, OBJPROP_BACK, false);
}

// Flèche clignotante « spike imminent » (Boom/Crash) quand le script est en WAIT mais probabilité élevée.
bool DrawSpikeImminentArrow(const double bid, const double spikeProb, const double spDirNum,
                            const bool isBoom, const bool isCrash, const string planDir)
{
const string nm = "GOM_SPIKE_IMMINENT";
if(!EnableSpikePrediction || (!isBoom && !isCrash) || planDir != "WAIT")
{
ObjectDelete(0, nm);
return false;
}
double th = GOM_SpikeBlinkEffectiveTh(SpikeBlinkMinProbability);
if(spikeProb + 1e-12 < th)
{
ObjectDelete(0, nm);
return false;
}
string sdir = "";
if(spDirNum > 0.5) sdir = "BUY";
else if(spDirNum < -0.5) sdir = "SELL";
if(sdir == "")
{
ObjectDelete(0, nm);
return false;
}
datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
if(t <= 0) t = TimeCurrent();
double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
if(point <= 0.0) point = 0.1;
double y = (sdir == "BUY") ? (bid - 22.0 * point) : (bid + 22.0 * point);

if(ObjectFind(0, nm) < 0)
ObjectCreate(0, nm, OBJ_ARROW, 0, t, y);
ObjectMove(0, nm, 0, t, y);
ObjectSetInteger(0, nm, OBJPROP_ARROWCODE, (sdir == "BUY") ? 241 : 242);
bool blinkOn = (((int)(GetTickCount() / 380)) % 2) == 0;
color cHi = (sdir == "BUY") ? clrLime : clrTomato;
color cLo = (sdir == "BUY") ? clrGreen : clrFireBrick;
ObjectSetInteger(0, nm, OBJPROP_COLOR, blinkOn ? cHi : cLo);
ObjectSetInteger(0, nm, OBJPROP_WIDTH, blinkOn ? 5 : 2);
ObjectSetInteger(0, nm, OBJPROP_BACK, false);
ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, nm, OBJPROP_HIDDEN, false);
return true;
}

// Indices « spike » : fermeture auto sur franchissement ligne GOM — pas Forex ni métaux.
bool GOM_IsSymSpikeStyleFamilyForGomAutoClose(const string symIn = "")
{
   string u;
   GOM_SymbolToUpperKey(symIn, u);
   if(GOM_IsSyntheticBoomCrashFamily(symIn)) return true;
   if(StringFind(u, "PINCH") >= 0 || StringFind(u, "GAS") >= 0) return true;
   if(StringFind(u, "STEP") >= 0) return true;
   if(StringFind(u, "JUMP") >= 0) return true;
   if(StringFind(u, "VOLATILITY") >= 0 || StringFind(u, "RANGE BREAK") >= 0 ||
      StringFind(u, "FX VOL") >= 0 || StringFind(u, "SFX VOL") >= 0 ||
      StringFind(u, "PAIN") >= 0 || StringFind(u, "GAIN") >= 0 || StringFind(u, "XEL") >= 0) return true;
   return false;
}

// Ferme au marché les positions alignées avec le spike capté (BUY si franchissement haussier, SELL si baissier).
int GOM_ClosePositionsAfterSpikeCapture(const bool buySpikeCaptured, const bool sellSpikeCaptured)
{
   if(!EnableAutoClosePositionsOnSpikeCaptured)
   {
      Print("⚠️ GOM_ClosePositionsAfterSpikeCapture: EnableAutoClosePositionsOnSpikeCaptured = false");
      return 0;
   }
   if(!buySpikeCaptured && !sellSpikeCaptured)
      return 0;

   if(!GOM_IsSymSpikeStyleFamilyForGomAutoClose())
   {
      Print("⚠️ GOM_ClosePositionsAfterSpikeCapture: Symbole ", _Symbol, " non reconnu comme famille spike (Boom/Crash/Volatility/etc.)");
      return 0;
   }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("⚠️ GOM_ClosePositionsAfterSpikeCapture: Trading non autorisé");
      return 0;
   }

   // ✅ NOUVEAU: Vérifier qu'il s'agit d'un vrai spike Boom/Crash (mouvement rapide négatif → positif)
   datetime now = TimeCurrent();
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool isRealSpike = false;

   // Détection spike rapide (5 dernières secondes max)
   if(g_gomLastSpikeDetectionTime > 0 && (now - g_gomLastSpikeDetectionTime) <= 5)
   {
      if(g_gomLastPriceForSpikeDetection > 0.0)
      {
         double priceChange = currentPrice - g_gomLastPriceForSpikeDetection;
         double priceChangePct = (priceChange / g_gomLastPriceForSpikeDetection) * 100.0;

         // Boom: mouvement haussier rapide (min 0.3%)
         if(buySpikeCaptured && StringFind(_Symbol, "Boom") >= 0 && priceChangePct >= 0.3)
         {
            isRealSpike = true;
            Print("✅ SPIKE BOOM RÉEL détecté: +", DoubleToString(priceChangePct, 2), "% en ", (now - g_gomLastSpikeDetectionTime), "s");
         }

         // Crash: mouvement baissier rapide (min -0.3%)
         if(sellSpikeCaptured && StringFind(_Symbol, "Crash") >= 0 && priceChangePct <= -0.3)
         {
            isRealSpike = true;
            Print("✅ SPIKE CRASH RÉEL détecté: ", DoubleToString(priceChangePct, 2), "% en ", (now - g_gomLastSpikeDetectionTime), "s");
         }

         // Volatility / Step / Jump (sans nom Boom/Crash) : mouvement aligné sur le sens capté (seuil plus souple)
         if(!isRealSpike && SMC_GetSymbolCategory(_Symbol) == SYM_VOLATILITY)
         {
            if(buySpikeCaptured && priceChangePct >= 0.15)
            {
               isRealSpike = true;
               Print("✅ SPIKE VOL RÉEL (BUY): +", DoubleToString(priceChangePct, 2), "% en ", (now - g_gomLastSpikeDetectionTime), "s");
            }
            if(sellSpikeCaptured && priceChangePct <= -0.15)
            {
               isRealSpike = true;
               Print("✅ SPIKE VOL RÉEL (SELL): ", DoubleToString(priceChangePct, 2), "% en ", (now - g_gomLastSpikeDetectionTime), "s");
            }
         }
      }
   }

   // Mettre à jour le prix de référence pour la prochaine détection
   g_gomLastPriceForSpikeDetection = currentPrice;
   g_gomLastSpikeDetectionTime = now;

   // Si pas de spike réel détecté ET qu'on exige un vrai spike, sortir
   if(SpikeCapturedRequireRealSpike && !isRealSpike)
   {
      static datetime lastNoSpikeLog = 0;
      if(now - lastNoSpikeLog >= 30)
      {
         Print("⚠️ Niveau GOM franchi mais pas de spike rapide détecté (variation < 0.3% en 5s) — fermeture annulée");
         lastNoSpikeLog = now;
      }
      return 0;
   }

   // Vérifier cooldown de fermeture (évite fermetures multiples rapides)
   if(g_gomLastSpikeCaptureCloseUtc > 0 && (now - g_gomLastSpikeCaptureCloseUtc) < 1)
      return 0;

   g_gomSpikeTrade.SetDeviationInPoints(SpikeCapturedCloseDeviation);
   g_gomSpikeTrade.SetAsyncMode(false);

   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      long mg = (long)PositionGetInteger(POSITION_MAGIC);
      if(SpikeCapturedCloseMagicFilter != 0 && mg != SpikeCapturedCloseMagicFilter)
         continue;

      datetime openT = (datetime)PositionGetInteger(POSITION_TIME);
      int ageSec = (openT > 0 ? (int)(now - openT) : 999999);
      if(ageSec < MathMax(0, SpikeCapturedMinPositionAgeSec))
         continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool wantClose = (buySpikeCaptured && ptype == POSITION_TYPE_BUY) ||
                       (sellSpikeCaptured && ptype == POSITION_TYPE_SELL);
      if(!wantClose)
         continue;

      double net = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) +
                   PositionGetDouble(POSITION_COMMISSION);
      bool profitOk = true;

      // LOGIQUE AMÉLIORÉE: Si GomEntryCrossCloseMinProfitUSD = 0, ferme même en perte légère (spike capté = sortie prioritaire)
      if(GomEntryCrossCloseMinProfitUSD <= 0.0)
      {
         // Ferme toute position alignée avec le spike, même en perte légère (max -1.0$)
         profitOk = (net >= -1.0);
      }
      else
      {
         // Si seuil > 0, utilise la logique existante
         if(GomSpikeCapturedCloseAnyProfit && net > 1e-8)
            profitOk = true;
         else
            profitOk = (net + 1e-9 >= GomEntryCrossCloseMinProfitUSD);
      }

      if(!profitOk)
      {
         Print("⚠️ GOM spike capté mais position #", ticket, " non fermée: P/L=", DoubleToString(net, 2),
               "$ < seuil=", DoubleToString(GomEntryCrossCloseMinProfitUSD, 2), "$");
         continue;
      }

      if(g_gomSpikeTrade.PositionClose(ticket))
      {
         closed++;
         Print("GOM niveau franchi → fermeture position #", ticket,
               " | ", (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " | magic=", mg, " | P/L=", DoubleToString(net, 2), "$");
      }
   }

   if(closed > 0)
   {
      g_gomLastSpikeCaptureCloseUtc = now;
      GOM_AlertPush("Spike capturé", IntegerToString(closed) + " position(s) fermée(s) au marché (GOM niveau franchi).", NotifySoundSpike);
   }
   return closed;
}

// Nettoyage automatique des flèches/signaux si le spike a été capturé (ou mouvement invalidé)
void GOM_CheckCaptureSpikeAndCleanup(void)
{
   string prefix = "GOM_SCRIPT_" + _Symbol;
   double buyE  = GlobalVariableGet(prefix + "_BUY_ENTRY");
   double sellE = GlobalVariableGet(prefix + "_SELL_ENTRY");

   if(buyE <= 0.0 && sellE <= 0.0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = _Point;

   const double capBufPts = 15.0;
   bool buyCaptured = (buyE > 0.0 && ask > buyE + capBufPts * point);
   bool sellCaptured = (sellE > 0.0 && bid < sellE - capBufPts * point);
   bool captured = buyCaptured || sellCaptured;

   // LOG DEBUG: Afficher l'état de la détection de spike
   static datetime lastSpikeDebugLog = 0;
   datetime nowDebug = TimeCurrent();
   if(captured || (nowDebug - lastSpikeDebugLog >= 120))
   {
      if(captured)
      {
         Print("🎯 SPIKE CAPTÉ DÉTECTÉ | BUY=", (buyCaptured ? "OUI" : "NON"),
               " | SELL=", (sellCaptured ? "OUI" : "NON"),
               " | buyEntry=", DoubleToString(buyE, _Digits),
               " | sellEntry=", DoubleToString(sellE, _Digits),
               " | ask=", DoubleToString(ask, _Digits),
               " | bid=", DoubleToString(bid, _Digits),
               " | positions=", PositionsTotal());
      }
      lastSpikeDebugLog = nowDebug;
   }

   if(captured)
   {
      int closedN = GOM_ClosePositionsAfterSpikeCapture(buyCaptured, sellCaptured);

      // ❌ CORRECTION: NE PAS notifier si aucune position fermée (pas de spike réel sur position ouverte)
      // L'ancienne logique notifiait même sans position, ce qui créait des fausses alertes
      if(closedN == 0)
      {
         // Log silencieux pour diagnostic, pas de notification push
         Print("⚠️ GOM niveau franchi mais aucune position fermée | BUY=", (buyCaptured ? "OUI" : "NON"),
               " | SELL=", (sellCaptured ? "OUI" : "NON"), " | positions=", PositionsTotal());
      }

      if(closedN > 0 || !GomEntryCrossKeepPlanIfNoClose)
      {
      GlobalVariableSet(prefix + "_BUY_ENTRY", 0.0);
      GlobalVariableSet(prefix + "_SELL_ENTRY", 0.0);
      GlobalVariableSet(prefix + "_VERDICT_NUM", 0.0);
      ObjectDelete(0, "GOM_PLAN_ARROW");
      ObjectDelete(0, "GOM_PLAN_ENTRY");
      ObjectDelete(0, "GOM_PLAN_SL");
      ObjectDelete(0, "GOM_PLAN_TP1");
      ObjectDelete(0, "GOM_PLAN_TP2");
      ObjectDelete(0, "GOM_PLAN_TP3");
      ObjectDelete(0, "GOM_PLAN_ENTRY_TXT");
      ObjectDelete(0, "GOM_PLAN_SL_TXT");
      ObjectDelete(0, "GOM_PLAN_TP1_TXT");
      ObjectDelete(0, "GOM_PLAN_TP2_TXT");
      ObjectDelete(0, "GOM_PLAN_TP3_TXT");
      }
   }
}

void GOM_DrawPastFutureZone(void)
{
const string nmRect = "GOM_FUTURE_ZONE_RECT";
const string nmV = "GOM_FUTURE_ZONE_VLINE";
const string nmTxtFutur = "GOM_FUTURE_ZONE_TXT";
const string nmTxtPasse = "GOM_PAST_ZONE_TXT";
if(!ShowPastFutureSeparator || ChartsShowOnlyOteAndFibo)
{
ObjectDelete(0, nmRect);
ObjectDelete(0, nmV);
ObjectDelete(0, nmTxtFutur);
ObjectDelete(0, nmTxtPasse);
return;
}

   int sec = (int)PeriodSeconds(PERIOD_CURRENT);
   if(sec < 1) sec = 60;
   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t0 <= 0) t0 = TimeCurrent();
   datetime tSep = t0 + (datetime)sec;
   
   // Calcul dynamique de la largeur zone future pour correspondre au shift (45%)
   int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   if(visibleBars < 20) visibleBars = 100;
   double shiftPct = ChartGetDouble(0, CHART_SHIFT_SIZE); // Devrait être 45.0
   if(shiftPct < 2.0) shiftPct = 45.0; // Fallback
   
   // nBars = visibleBars * shiftPct / (100 - shiftPct)
   int nBars = (int)(visibleBars * (shiftPct / (100.0 - shiftPct)));
   if(nBars < 40) nBars = 40;
   if(nBars > 1000) nBars = 1000;
   
   datetime tEnd = tSep + (datetime)(nBars * sec);
   
   double pMax = ChartGetDouble(0, CHART_PRICE_MAX);
   double pMin = ChartGetDouble(0, CHART_PRICE_MIN);
   if(pMax <= pMin)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) bid = iClose(_Symbol, PERIOD_CURRENT, 0);
      pMax = bid * 1.05; // Plus large pour sécurité
      pMin = bid * 0.95;
   }

   // Rectangle de la zone future: fond très sombre type TradingView
   ObjectCreate(0, nmRect, OBJ_RECTANGLE, 0, tSep, pMax, tEnd, pMin);
   ObjectSetInteger(0, nmRect, OBJPROP_COLOR, (color)0x303030); // Bordure discrète
   ObjectSetInteger(0, nmRect, OBJPROP_BGCOLOR, (FutureZoneFillColor == clrNONE) ? (color)0x101010 : FutureZoneFillColor);
   ObjectSetInteger(0, nmRect, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nmRect, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nmRect, OBJPROP_FILL, true);
   ObjectSetInteger(0, nmRect, OBJPROP_BACK, true);
   ObjectSetInteger(0, nmRect, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, nmRect, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nmRect, OBJPROP_ZORDER, 0); // Tout au fond

   // Ligne verticale de séparation (plus esthétique)
   ObjectCreate(0, nmV, OBJ_VLINE, 0, tSep, 0.0);
   ObjectSetInteger(0, nmV, OBJPROP_COLOR, (color)0x404040);
   ObjectSetInteger(0, nmV, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nmV, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nmV, OBJPROP_BACK, false);
   ObjectSetInteger(0, nmV, OBJPROP_SELECTABLE, false);

// Label ">>> FUTUR" en jaune bien visible
if(ObjectFind(0, nmTxtFutur) < 0)
ObjectCreate(0, nmTxtFutur, OBJ_TEXT, 0, tSep + (datetime)(sec * 2), pMax);
ObjectMove(0, nmTxtFutur, 0, tSep + (datetime)(sec * 2), pMax);
ObjectSetString(0, nmTxtFutur, OBJPROP_TEXT, ">>> FUTUR");
ObjectSetString(0, nmTxtFutur, OBJPROP_FONT, "Arial Black");
ObjectSetInteger(0, nmTxtFutur, OBJPROP_FONTSIZE, 12);
ObjectSetInteger(0, nmTxtFutur, OBJPROP_COLOR, clrLightGray);
ObjectSetInteger(0, nmTxtFutur, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
ObjectSetInteger(0, nmTxtFutur, OBJPROP_BACK, false);
ObjectSetInteger(0, nmTxtFutur, OBJPROP_HIDDEN, false);

// Label "PASSE <<<" en jaune bien visible
if(ObjectFind(0, nmTxtPasse) < 0)
ObjectCreate(0, nmTxtPasse, OBJ_TEXT, 0, t0 - (datetime)(sec * 2), pMax);
ObjectMove(0, nmTxtPasse, 0, t0 - (datetime)(sec * 2), pMax);
ObjectSetString(0, nmTxtPasse, OBJPROP_TEXT, "PASSE <<<");
ObjectSetString(0, nmTxtPasse, OBJPROP_FONT, "Arial Black");
ObjectSetInteger(0, nmTxtPasse, OBJPROP_FONTSIZE, 12);
ObjectSetInteger(0, nmTxtPasse, OBJPROP_COLOR, clrLightGray);
ObjectSetInteger(0, nmTxtPasse, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
ObjectSetInteger(0, nmTxtPasse, OBJPROP_BACK, false);
ObjectSetInteger(0, nmTxtPasse, OBJPROP_HIDDEN, false);
ObjectSetInteger(0, nmTxtPasse, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, nmTxtPasse, OBJPROP_ZORDER, 42);
ObjectSetInteger(0, nmTxtFutur, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, nmTxtFutur, OBJPROP_ZORDER, 42);
}

void GOM_UpdateDoubleSpikeState(const double bid, const double atr, const string spikeDir, const double spikeProb,
                                const double m5Buy, const double m5Sell, const double m15Buy, const double m15Sell,
                                const double h1Buy, const double h1Sell)
{
if(!EnableDoubleSpikeCapture)
{
GOM_GlobalSetForScript("DOUBLE_SPIKE_PHASE", 0.0);
GOM_GlobalSetForScript("DOUBLE_SPIKE_HOLD", 0.0);
GOM_GlobalSetForScript("DOUBLE_SPIKE_HOLD_UNTIL", 0.0);
g_doubleSpikeFirstTs = 0;
g_doubleSpikeDir = 0;
return;
}

const datetime nowTs = TimeCurrent();
const int winSec = MathMax(1, DoubleSpikeWindowBars) * 60;
const double nearAtr = MathMax(0.20, DoubleSpikeNearLevelAtr);
const bool dirBuy = (spikeDir == "BUY");
const bool dirSell = (spikeDir == "SELL");
const bool probOk = (spikeProb + 1e-9 >= MathMax(0.0, DoubleSpikeMinProb));
bool nearLevel = false;
if(atr > 0.0)
{
if(dirBuy)
nearLevel = (GOM_PriceNearLevel(bid, m5Buy, atr, nearAtr) || GOM_PriceNearLevel(bid, m15Buy, atr, nearAtr) || GOM_PriceNearLevel(bid, h1Buy, atr, nearAtr));
else if(dirSell)
nearLevel = (GOM_PriceNearLevel(bid, m5Sell, atr, nearAtr) || GOM_PriceNearLevel(bid, m15Sell, atr, nearAtr) || GOM_PriceNearLevel(bid, h1Sell, atr, nearAtr));
}

double holdUntil = GOM_GlobalGetForScript("DOUBLE_SPIKE_HOLD_UNTIL", 0.0);
bool holdNow = (holdUntil > (double)nowTs);
if(holdNow)
{
GOM_GlobalSetForScript("DOUBLE_SPIKE_PHASE", 2.0);
GOM_GlobalSetForScript("DOUBLE_SPIKE_HOLD", 1.0);
// Dessiner label "2nd SPIKE" sur le chart
string nm2s = "GOM_2ND_SPIKE_LABEL";
double bid2 = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(ObjectFind(0, nm2s) < 0)
ObjectCreate(0, nm2s, OBJ_TEXT, 0, TimeCurrent(), bid2);
ObjectMove(0, nm2s, 0, TimeCurrent(), bid2);
ObjectSetString(0, nm2s, OBJPROP_TEXT, "2nd SPIKE");
ObjectSetString(0, nm2s, OBJPROP_FONT, "Arial Bold");
ObjectSetInteger(0, nm2s, OBJPROP_FONTSIZE, 10);
ObjectSetInteger(0, nm2s, OBJPROP_COLOR, clrLime);
ObjectSetInteger(0, nm2s, OBJPROP_ANCHOR, ANCHOR_LEFT);
ObjectSetInteger(0, nm2s, OBJPROP_BACK, false);
ObjectSetInteger(0, nm2s, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, nm2s, OBJPROP_ZORDER, 50);
return;
}

if(g_doubleSpikeFirstTs > 0 && (nowTs - g_doubleSpikeFirstTs > winSec))
{
g_doubleSpikeFirstTs = 0;
g_doubleSpikeDir = 0;
}

int spikeDirNum = dirBuy ? 1 : (dirSell ? -1 : 0);
if(probOk && nearLevel && spikeDirNum != 0)
{
if(g_doubleSpikeFirstTs <= 0 || g_doubleSpikeDir != spikeDirNum)
{
g_doubleSpikeFirstTs = nowTs;
g_doubleSpikeDir = spikeDirNum;
GOM_GlobalSetForScript("DOUBLE_SPIKE_PHASE", 1.0);
GOM_GlobalSetForScript("DOUBLE_SPIKE_HOLD", 0.0);
GOM_GlobalSetForScript("DOUBLE_SPIKE_HOLD_UNTIL", 0.0);
// Dessiner label "1st SPIKE" sur le chart
string nm1s = "GOM_1ST_SPIKE_LABEL";
double bid1 = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(ObjectFind(0, nm1s) < 0)
ObjectCreate(0, nm1s, OBJ_TEXT, 0, TimeCurrent(), bid1);
ObjectMove(0, nm1s, 0, TimeCurrent(), bid1);
ObjectSetString(0, nm1s, OBJPROP_TEXT, "1st SPIKE");
ObjectSetString(0, nm1s, OBJPROP_FONT, "Arial Bold");
ObjectSetInteger(0, nm1s, OBJPROP_FONTSIZE, 10);
ObjectSetInteger(0, nm1s, OBJPROP_COLOR, clrGold);
ObjectSetInteger(0, nm1s, OBJPROP_ANCHOR, ANCHOR_LEFT);
ObjectSetInteger(0, nm1s, OBJPROP_BACK, false);
ObjectSetInteger(0, nm1s, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, nm1s, OBJPROP_ZORDER, 50);
}
else
{
datetime untilTs = nowTs + (datetime)MathMax(30, DoubleSpikeHoldSeconds);
GOM_GlobalSetForScript("DOUBLE_SPIKE_PHASE", 2.0);
GOM_GlobalSetForScript("DOUBLE_SPIKE_HOLD", 1.0);
GOM_GlobalSetForScript("DOUBLE_SPIKE_HOLD_UNTIL", (double)untilTs);
// Dessiner label "2nd SPIKE" et supprimer "1st SPIKE"
string nm2s2 = "GOM_2ND_SPIKE_LABEL";
double bid2b = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(ObjectFind(0, nm2s2) < 0)
ObjectCreate(0, nm2s2, OBJ_TEXT, 0, TimeCurrent(), bid2b);
ObjectMove(0, nm2s2, 0, TimeCurrent(), bid2b);
ObjectSetString(0, nm2s2, OBJPROP_TEXT, "2nd SPIKE");
ObjectSetString(0, nm2s2, OBJPROP_FONT, "Arial Bold");
ObjectSetInteger(0, nm2s2, OBJPROP_FONTSIZE, 10);
ObjectSetInteger(0, nm2s2, OBJPROP_COLOR, clrLime);
ObjectSetInteger(0, nm2s2, OBJPROP_ANCHOR, ANCHOR_LEFT);
ObjectSetInteger(0, nm2s2, OBJPROP_BACK, false);
ObjectSetInteger(0, nm2s2, OBJPROP_SELECTABLE, false);
ObjectSetInteger(0, nm2s2, OBJPROP_ZORDER, 50);
ObjectDelete(0, "GOM_1ST_SPIKE_LABEL");
}
}
else
{
double ph = GOM_GlobalGetForScript("DOUBLE_SPIKE_PHASE", 0.0);
if(ph < 1.0) GOM_GlobalSetForScript("DOUBLE_SPIKE_PHASE", 0.0);
GOM_GlobalSetForScript("DOUBLE_SPIKE_HOLD", 0.0);
// Nettoyer les labels spike quand plus en phase
ObjectDelete(0, "GOM_1ST_SPIKE_LABEL");
ObjectDelete(0, "GOM_2ND_SPIKE_LABEL");
}
}

void GOM_PreparePlanLevels(const string dir, const double bid, double &entry, double &sl, double &tp1, double &tp2, double &tp3)
{
double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
if(pt <= 0.0) pt = 0.00001;
int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
if(digits < 0) digits = _Digits;
double stopsPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
if(stopsPts < 0.0) stopsPts = 0.0;
double freezePts = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
if(freezePts < 0.0) freezePts = 0.0;
double minDist = MathMax((stopsPts + freezePts + 4.0) * pt, 12.0 * pt);
if(minDist <= 0.0) minDist = 12.0 * pt;

if(entry <= 0.0) entry = bid;
if(dir == "BUY")
{
if(sl <= 0.0 || sl >= entry - minDist) sl = entry - minDist;
if(tp1 <= 0.0 || tp1 <= entry + minDist) tp1 = entry + minDist;
if(tp2 <= 0.0 || tp2 <= tp1 + minDist * 0.40) tp2 = tp1 + minDist;
if(tp3 <= 0.0 || tp3 <= tp2 + minDist * 0.40) tp3 = tp2 + minDist;
}
else if(dir == "SELL")
{
if(sl <= 0.0 || sl <= entry + minDist) sl = entry + minDist;
if(tp1 <= 0.0 || tp1 >= entry - minDist) tp1 = entry - minDist;
if(tp2 <= 0.0 || tp2 >= tp1 - minDist * 0.40) tp2 = tp1 - minDist;
if(tp3 <= 0.0 || tp3 >= tp2 - minDist * 0.40) tp3 = tp2 - minDist;
}

entry = NormalizeDouble(entry, digits);
sl = NormalizeDouble(sl, digits);
tp1 = NormalizeDouble(tp1, digits);
tp2 = NormalizeDouble(tp2, digits);
tp3 = NormalizeDouble(tp3, digits);
}

void DrawTradePlanVisuals(string &dirOut, string &qualityOut)
{
double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(bid <= 0.0) bid = iClose(_Symbol, PERIOD_CURRENT, 0);
if(bid <= 0.0) return;
double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
if(ask <= 0.0) ask = bid;

double atr = GOM_ATRValue(_Symbol, PERIOD_M15, 14);
if(atr <= 0.0) atr = bid * 0.0015;

GOM_UpdateBollingerVwapMetrics(bid);
GOM_UpdateAdvancedTrendMetrics(bid);

double m15Buy = ReadGV("GOM_KOLA", "M15", "BUY");
double m15Sell = ReadGV("GOM_KOLA", "M15", "SELL");
double m30Buy = ReadGV("GOM_KOLA", "M30", "BUY");
double m30Sell = ReadGV("GOM_KOLA", "M30", "SELL");
double m5Buy = ReadGV("GOM_KOLA", "M5", "BUY");
double m5Sell = ReadGV("GOM_KOLA", "M5", "SELL");
double m1Buy = ReadGV("GOM_KOLA", "M1", "BUY");
double m1Sell = ReadGV("GOM_KOLA", "M1", "SELL");
double h1Buy = ReadGV("GOM_KOLA", "H1", "BUY");
double h1Sell = ReadGV("GOM_KOLA", "H1", "SELL");
double h4Buy = ReadGV("GOM_KOLA", "H4", "BUY");
double h4Sell = ReadGV("GOM_KOLA", "H4", "SELL");
double dtop = ReadGV("GOM_SIDO", "M15", "DOUBLE_TOP");
double dbot = ReadGV("GOM_SIDO", "M15", "DOUBLE_BOTTOM");

// Indicateur de "live" (preuve que le script recalcule en temps réel)
UpdateScriptLastTs();

// Score technique combiné (KOLA + SIDO + MTF bias)
double techBuy = 0.0;
double techSell = 0.0;

// Intégration SMC Hedge Fund
GOM_DetectSMCSwings();
if(m15Buy > 0.0 && bid <= m15Buy * 1.0010) techBuy += 1.2;
if(m30Buy > 0.0 && bid <= m30Buy * 1.0011) techBuy += 1.05;
if(h1Buy > 0.0 && bid <= h1Buy * 1.0015) techBuy += 1.1;
if(h4Buy > 0.0 && bid <= h4Buy * 1.0020) techBuy += 0.9;
if(m15Sell > 0.0 && bid >= m15Sell * 0.9990) techSell += 1.2;
if(m30Sell > 0.0 && bid >= m30Sell * 0.9989) techSell += 1.05;
if(h1Sell > 0.0 && bid >= h1Sell * 0.9985) techSell += 1.1;
if(h4Sell > 0.0 && bid >= h4Sell * 0.9980) techSell += 0.9;
if(dbot > 0.0) techBuy += 0.8;
if(dtop > 0.0) techSell += 0.8;

int bM15 = GetTFBias(PERIOD_M15), bM30 = GetTFBias(PERIOD_M30), bH1 = GetTFBias(PERIOD_H1), bH4 = GetTFBias(PERIOD_H4);
if(bM15 > 0) techBuy += 0.4; else if(bM15 < 0) techSell += 0.4;
if(bM30 > 0) techBuy += 0.38; else if(bM30 < 0) techSell += 0.38;
if(bH1 > 0) techBuy += 0.6; else if(bH1 < 0) techSell += 0.6;
if(bH4 > 0) techBuy += 0.5; else if(bH4 < 0) techSell += 0.5;

// Confluence "distance au niveau" (ATR): bonus quand le prix est proche des zones d'entrée
double atrZoneNear = atr * 0.35;
if(atrZoneNear > 0.0)
{
if(m5Buy > 0.0 && MathAbs(bid - m5Buy) <= atrZoneNear) techBuy += 0.45;
if(m15Buy > 0.0 && MathAbs(bid - m15Buy) <= atrZoneNear) techBuy += 0.30;
if(m30Buy > 0.0 && MathAbs(bid - m30Buy) <= atrZoneNear) techBuy += 0.28;
if(m5Sell > 0.0 && MathAbs(bid - m5Sell) <= atrZoneNear) techSell += 0.45;
if(m15Sell > 0.0 && MathAbs(bid - m15Sell) <= atrZoneNear) techSell += 0.30;
if(m30Sell > 0.0 && MathAbs(bid - m30Sell) <= atrZoneNear) techSell += 0.28;
}

if(ShowScriptEMAs)
GOM_AddEmaRibbonScriptTfBias(bid, techBuy, techSell);

// Renfort EMA complet (M1/M5): 9,21,13,50,100,200,66,75,123
int emaPeriods[9] = {9, 21, 13, 50, 100, 200, 66, 75, 123};
for(int e = 0; e < 9; e++)
{
int p = emaPeriods[e];
double eM1 = GOM_EMAValue(_Symbol, PERIOD_M1, p);
double eM5 = GOM_EMAValue(_Symbol, PERIOD_M5, p);
if(eM1 > 0.0)
{
   if(bid > eM1) techBuy += 0.05;
   else techSell += 0.05;
}
if(eM5 > 0.0)
{
   if(bid > eM5) techBuy += 0.08;
   else techSell += 0.08;
}
}

bool isBoom = GOM_IsBoomOrGainx();
bool isCrash = GOM_IsCrashOrPainx();

GOM_AddBollingerVwapVerdictBias(bid, isBoom, isCrash, techBuy, techSell);
GOM_AddAdvancedIndicatorsVerdictBias(techBuy, techSell);

string spikeDir = "NONE";
double spikeProb = GOM_PredictSpikeProbabilityM1(isBoom, isCrash, spikeDir);
bool spikeOpportunity = GOM_IsSpikeOpportunity(isBoom, isCrash, spikeDir, spikeProb);
if(spikeProb >= SpikeAlertMinProbability)
{
if(spikeDir == "BUY") techBuy += 0.55 * spikeProb;
else if(spikeDir == "SELL") techSell += 0.55 * spikeProb;
}
if(spikeOpportunity)
{
if(spikeDir == "BUY") techBuy += 0.90 * spikeProb;
else if(spikeDir == "SELL") techSell += 0.90 * spikeProb;
}
// Influencer le verdict avec SMC Hedge Fund
GOM_InfluenceVerdictWithSMC(techBuy, techSell);

g_lastTechBuyScore = techBuy;
g_lastTechSellScore = techSell;
GOM_GlobalSetForScript("TECH_BUY_SCORE", techBuy);
GOM_GlobalSetForScript("TECH_SELL_SCORE", techSell);
GOM_GlobalSetForScript("SPIKE_PROB", spikeProb);
GOM_GlobalSetForScript("SPIKE_DIR_NUM", (spikeDir == "BUY") ? 1.0 : ((spikeDir == "SELL") ? -1.0 : 0.0));
GOM_UpdateDoubleSpikeState(bid, atr, spikeDir, spikeProb, m5Buy, m5Sell, m15Buy, m15Sell, h1Buy, h1Sell);

// Appel IA externe (serveur) pour interprétation temps réel
double ema9m1 = GOM_EMAValue(_Symbol, PERIOD_M1, 9);
double ema21m1 = GOM_EMAValue(_Symbol, PERIOD_M1, 21);
double ema9m5 = GOM_EMAValue(_Symbol, PERIOD_M5, 9);
double ema21m5 = GOM_EMAValue(_Symbol, PERIOD_M5, 21);
double rsiM1 = GOM_RSIValue(_Symbol, PERIOD_M1, 14);
if(rsiM1 <= 0.0) rsiM1 = 50.0;
double verdictNumNow = GOM_GlobalGetForScript("VERDICT_NUM", 0.0);
GOM_UpdateExternalAI(_Symbol, bid, ask, atr, rsiM1, ema9m1, ema21m1, ema9m5, ema21m5,
                  verdictNumNow, spikeProb, (int)GOM_GlobalGetForScript("SPIKE_DIR_NUM", 0.0),
                  m5Buy, m5Sell, m15Buy, m15Sell, dtop, dbot);

string dir = "WAIT";
double gap = techBuy - techSell;
double gapTh = (isBoom || isCrash) ? 0.28 : 0.45;
if(gap >= gapTh) dir = "BUY";
else if(gap <= -gapTh) dir = "SELL";

// Micro-trend synthétiques (évite WAIT figé quand scores équilibrés)
double ema9_m1 = 0.0, ema21_m1 = 0.0;
double rsi_m1 = 50.0;
double mom_m1 = 0.0;
if(isBoom || isCrash)
{
ema9_m1 = GOM_EMAValue(_Symbol, PERIOD_M1, 9);
ema21_m1 = GOM_EMAValue(_Symbol, PERIOD_M1, 21);
rsi_m1 = GOM_RSIValue(_Symbol, PERIOD_M1, 14);
if(rsi_m1 <= 0.0) rsi_m1 = 50.0;
double o = iOpen(_Symbol, PERIOD_M1, 0);
double c = iClose(_Symbol, PERIOD_M1, 0);
if(o > 0.0 && c > 0.0) mom_m1 = (c - o);
}
if(dir == "WAIT")
{
if(isBoom && (techBuy >= techSell + 0.15) && (bM15 >= 0 || bH1 >= 0))
   dir = "BUY";
else if(isCrash && (techSell >= techBuy + 0.15) && (bM15 <= 0 || bH1 <= 0))
   dir = "SELL";
else if(techBuy >= techSell + 0.30)
   dir = "BUY";
else if(techSell >= techBuy + 0.30)
   dir = "SELL";

// Fallback directionnel pour synthétiques rapides (évite WAIT persistant)
if(dir == "WAIT")
{
   // 1) micro-trend EMA9/21 M1 + RSI + momentum
   if((isBoom || isCrash) && ema9_m1 > 0.0 && ema21_m1 > 0.0)
   {
      bool microBuy = (ema9_m1 >= ema21_m1) && (rsi_m1 >= 48.0 || mom_m1 > 0.0);
      bool microSell = (ema9_m1 <  ema21_m1) && (rsi_m1 <= 52.0 || mom_m1 < 0.0);
      if(isBoom && microBuy) dir = "BUY";
      else if(isCrash && microSell) dir = "SELL";
   }

   // 2) si toujours WAIT, préférer le biais "naturel" de l'instrument
   if(dir == "WAIT")
   {
      if(isBoom && (techSell - techBuy) < 0.85) dir = "BUY";
      else if(isCrash && (techBuy - techSell) < 0.85) dir = "SELL";
   }
}
}

// Filtre anti-spike: évite d'entrer en plein pic sur synthétiques
bool blockBuySpike = false, blockSellSpike = false;
if(isBoom || isCrash)
{
double o1 = iOpen(_Symbol, PERIOD_M1, 0);
double c1 = iClose(_Symbol, PERIOD_M1, 0);
double h1c = iHigh(_Symbol, PERIOD_M1, 0);
double l1c = iLow(_Symbol, PERIOD_M1, 0);
double body = MathAbs(c1 - o1);
double upW = h1c - MathMax(o1, c1);
double dnW = MathMin(o1, c1) - l1c;
double minBody = MathMax(body, atr * 0.02);
if(upW > minBody * 2.2 && upW > atr * 0.10) blockBuySpike = true;   // spike haussier épuisé
if(dnW > minBody * 2.2 && dnW > atr * 0.10) blockSellSpike = true;  // spike baissier épuisé
}
bool dsHoldNow = (GOM_GlobalGetForScript("DOUBLE_SPIKE_HOLD", 0.0) > 0.5 || GOM_GlobalGetForScript("DOUBLE_SPIKE_PHASE", 0.0) >= 1.0);
if(dir == "BUY" && isBoom && blockBuySpike && !(spikeOpportunity && SpikeModeBypassStrict) && !dsHoldNow) dir = "WAIT";
if(dir == "SELL" && isCrash && blockSellSpike && !(spikeOpportunity && SpikeModeBypassStrict) && !dsHoldNow) dir = "WAIT";

// Verrou final direction/symbole: interdit BUY sur Crash, SELL sur Boom
if(!GOM_IsDirectionAllowedForSymbol(dir)) dir = "WAIT";

// === APPLICATION DES FILTRES DE CONFIRMATION ===
string filterStatus = "";
double filterQuality = 1.0;
string filterFailReason = "";
bool strictMtfPass = true;
bool strictStructurePass = true;
// Portée fonction entière (utilisé aussi pour strength / MTF strict après les filtres).
bool hvSynth = (RelaxedFiltersHighVolSynth && GOM_IsVolatilityOrSimilarSynth());
bool passNearKola = false;

if(dir != "WAIT")
{
FilterResults filters = ApplyAllFilters(dir, atr);
filterStatus = GetFilterStatusText(filters);
filterQuality = CalculateFilterQualityScore(filters);
filterFailReason = filters.failReason;
strictMtfPass = filters.mtfPass;
strictStructurePass = filters.structurePass;

// Stocker les résultats des filtres dans les variables globales
GOM_GlobalSetForScript("FILTER_PASS_COUNT", (double)filters.passCount);
GOM_GlobalSetForScript("FILTER_TOTAL", (double)filters.totalFilters);
GOM_GlobalSetForScript("FILTER_QUALITY", filterQuality);

// Si trop de filtres échouent, on passe en WAIT (sauf mode assoupli synthèses volatiles).
double passRatioCfg = StrictConfluenceMode ? MinFilterPassRatio : 0.33;
if(hvSynth) passRatioCfg = MathMin(passRatioCfg, 0.34);
passRatioCfg = MathMax(0.10, MathMin(1.00, passRatioCfg));
int minPassFilters = MathMax(1, (int)MathRound(filters.totalFilters * passRatioCfg));
if(spikeOpportunity && SpikeModeBypassStrict)
   minPassFilters = MathMax(1, minPassFilters - 1);
if(hvSynth && filters.totalFilters >= 4)
   minPassFilters = MathMin(minPassFilters, MathMax(1, (int)MathCeil((double)filters.totalFilters * 0.25)));
if(hvSynth)
   minPassFilters = MathMin(minPassFilters, 2);
bool passFilterCount = (filters.passCount >= minPassFilters);
double qMin = hvSynth ? MinFilterQualityRelaxed : 0.50;
bool passFilterQuality = (filterQuality + 1e-9 >= qMin);
passNearKola = false;
if(hvSynth && (dir == "BUY" || dir == "SELL"))
{
double m5b = ReadGV("GOM_KOLA", "M5", "BUY");
double m5s = ReadGV("GOM_KOLA", "M5", "SELL");
double h1b = ReadGV("GOM_KOLA", "H1", "BUY");
double h1s = ReadGV("GOM_KOLA", "H1", "SELL");
double b = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(b <= 0.0) b = bid;
if(dir == "BUY" && ((m5b > 0.0 && MathAbs(b - m5b) <= atr * 0.55) || (h1b > 0.0 && MathAbs(b - h1b) <= atr * 0.65)))
   passNearKola = true;
if(dir == "SELL" && ((m5s > 0.0 && MathAbs(b - m5s) <= atr * 0.55) || (h1s > 0.0 && MathAbs(b - h1s) <= atr * 0.65)))
   passNearKola = true;
}
if(!passFilterCount && !passFilterQuality && !(hvSynth && filters.passCount >= 1 && passNearKola))
{
   dir = "WAIT";
   filterStatus += " | BLOCKED";
}
}
else
{
filterStatus = "N/A";
GOM_GlobalSetForScript("FILTER_PASS_COUNT", 0.0);
GOM_GlobalSetForScript("FILTER_TOTAL", 0.0);
GOM_GlobalSetForScript("FILTER_QUALITY", 0.0);
}

dirOut = dir;
if(dir == "WAIT")
{
qualityOut = "WAIT";
GOM_GlobalSetForScript("ENTRY_QUALITY", 0.0);
GOM_GlobalSetForScript("ENTRY_QUALITY_BLOCK", 0.0);
GOM_GlobalSetForScript("VERDICT_STRENGTH", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_BUY_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SELL_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_VERDICT_NUM", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SL", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP1", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP2", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP3", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_M1_ENTRY", 0.0);
g_lastPlanDir = "WAIT";
g_lastPlanQuality = "WAIT";
g_lastPlanEntry = 0.0;
g_lastPlanSL = 0.0;
g_lastPlanTP1 = 0.0;
g_lastPlanTP2 = 0.0;
g_lastPlanTP3 = 0.0;
GOMScript_DrawSignalArrow("WAIT", bid);

// Supprimer TOUS les dessins de plan (évite TP/SL figés si on repasse en WAIT)
ObjectDelete(0, "GOM_PLAN_ENTRY");
ObjectDelete(0, "GOM_PLAN_SL");
ObjectDelete(0, "GOM_PLAN_TP1");
ObjectDelete(0, "GOM_PLAN_TP2");
ObjectDelete(0, "GOM_PLAN_TP3");
ObjectDelete(0, "GOM_PLAN_ARROW");

ObjectDelete(0, "GOM_PLAN_ENTRY_TXT");
ObjectDelete(0, "GOM_PLAN_SL_TXT");
ObjectDelete(0, "GOM_PLAN_TP1_TXT");
ObjectDelete(0, "GOM_PLAN_TP2_TXT");
ObjectDelete(0, "GOM_PLAN_TP3_TXT");

GOM_MaybePlaceSpikeNearM5Pending(isBoom, isCrash, spikeDir, spikeProb, spikeOpportunity,
                                 blockBuySpike, blockSellSpike, bid, ask, atr, m5Buy, m5Sell);
string waitReason = (filterFailReason != "") ? (" | " + filterFailReason) : "";
DrawScriptLiveLabel("GOM_SCRIPT_LIVE_LABEL_" + _Symbol,
                     "LIVE WAIT | SPIKE=" + spikeDir + " " + DoubleToString(spikeProb * 100.0, 0) + "%" +
                     " | FILTERS=" + filterStatus + waitReason);
return;
}

double entry = bid;
double sl = 0.0, tp1 = 0.0, tp2 = 0.0, tp3 = 0.0;
double levelConfluence = 0.0;
if(dir == "BUY")
{
if(m5Buy > 0.0 && MathAbs(bid - m5Buy) <= atr * 0.35) levelConfluence += 0.35;
if(h1Buy > 0.0 && MathAbs(bid - h1Buy) <= atr * 0.40) levelConfluence += 0.28;
if(m30Buy > 0.0 && MathAbs(bid - m30Buy) <= atr * 0.42) levelConfluence += 0.24;
if(m15Buy > 0.0 && MathAbs(bid - m15Buy) <= atr * 0.45) levelConfluence += 0.20;
if(h4Buy > 0.0 && MathAbs(bid - h4Buy) <= atr * 0.50) levelConfluence += 0.18;
}
else if(dir == "SELL")
{
if(m5Sell > 0.0 && MathAbs(bid - m5Sell) <= atr * 0.35) levelConfluence += 0.35;
if(h1Sell > 0.0 && MathAbs(bid - h1Sell) <= atr * 0.40) levelConfluence += 0.28;
if(m30Sell > 0.0 && MathAbs(bid - m30Sell) <= atr * 0.42) levelConfluence += 0.24;
if(m15Sell > 0.0 && MathAbs(bid - m15Sell) <= atr * 0.45) levelConfluence += 0.20;
if(h4Sell > 0.0 && MathAbs(bid - h4Sell) <= atr * 0.50) levelConfluence += 0.18;
}

double gapThForQ = (isBoom || isCrash) ? 0.28 : 0.45;
double entryQuality = GOM_ComputeEntryQualityScore(dir, gap, gapThForQ, spikeDir, spikeProb, spikeOpportunity,
   filterQuality, levelConfluence, bM15, bM30, bH1, bH4);
GOM_GlobalSetForScript("ENTRY_QUALITY", entryQuality);
GOM_GlobalSetForScript("ENTRY_QUALITY_BLOCK", 0.0);
bool synthFamQ = GOM_IsSyntheticBoomCrashFamily();
bool applyEntryQGate = EnableEntryQualityGate && (MinEntryQualityScore > 1e-9) &&
   (!EntryQualityGateSynthOnly || synthFamQ);
if(applyEntryQGate &&
   !GOM_EntryQualityRelaxed(dir, spikeDir, spikeProb, spikeOpportunity, levelConfluence) &&
   entryQuality + 1e-9 < MinEntryQualityScore)
{
dirOut = "WAIT";
dir = "WAIT";
qualityOut = "WAIT";
GOM_GlobalSetForScript("VERDICT_STRENGTH", 0.0);
GOM_GlobalSetForScript("ENTRY_QUALITY_BLOCK", 1.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_BUY_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SELL_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_VERDICT_NUM", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SL", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP1", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP2", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP3", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_M1_ENTRY", 0.0);
g_lastPlanDir = "WAIT";
g_lastPlanQuality = "WAIT";
GOMScript_DrawSignalArrow("WAIT", bid);
ObjectDelete(0, "GOM_PLAN_ENTRY");
ObjectDelete(0, "GOM_PLAN_SL");
ObjectDelete(0, "GOM_PLAN_TP1");
ObjectDelete(0, "GOM_PLAN_TP2");
ObjectDelete(0, "GOM_PLAN_TP3");
ObjectDelete(0, "GOM_PLAN_ARROW");
ObjectDelete(0, "GOM_PLAN_ENTRY_TXT");
ObjectDelete(0, "GOM_PLAN_SL_TXT");
ObjectDelete(0, "GOM_PLAN_TP1_TXT");
ObjectDelete(0, "GOM_PLAN_TP2_TXT");
ObjectDelete(0, "GOM_PLAN_TP3_TXT");
GOM_MaybePlaceSpikeNearM5Pending(isBoom, isCrash, spikeDir, spikeProb, spikeOpportunity,
                                 blockBuySpike, blockSellSpike, bid, ask, atr, m5Buy, m5Sell);
DrawScriptLiveLabel("GOM_SCRIPT_LIVE_LABEL_" + _Symbol,
   "LIVE WAIT | ENTRY_Q " + DoubleToString(entryQuality * 100.0, 0) + "% < " +
   DoubleToString(MinEntryQualityScore * 100.0, 0) + "% | SPIKE=" + spikeDir +
   " | CONF lvl=" + DoubleToString(levelConfluence, 2));
return;
}

double strength = MathAbs(gap) + levelConfluence;
// Bonus synthèses bruitées près des niveaux KOLA (aligné passNearKola — évite WAIT « force faible » alors que prix est sur zone).
if(hvSynth && passNearKola)
   strength += 0.40;

// Ajuster la force selon qualité filtres : sur Step/Vol… ne pas écraser le score (ancien plancher 0.58 trop dur).
double fqW = filterQuality;
if(hvSynth)
{
fqW = MathMax(0.84, filterQuality + 0.10);
if(fqW > 1.0) fqW = 1.0;
}
strength *= fqW;

// Spike aligné (Boom+BUY / Crash+SELL) : le dash montre souvent SPIKE BUY mais la force restait sous MinStrength — assouplir.
bool spikeDirMatchesTrade =
   (isBoom && spikeDir == "BUY" && dir == "BUY") || (isCrash && spikeDir == "SELL" && dir == "SELL");
bool spikeStrictEase = SpikeModeBypassStrict && spikeDirMatchesTrade && dir != "WAIT" &&
   (spikeOpportunity || (spikeProb + 1e-9 >= SpikeAlertMinProbability));
if(spikeStrictEase)
   strength += 0.85;

bool nearKolaBuySpike = false;
bool nearKolaSellSpike = false;
if(RelaxStrengthBoomCrashSpikeKola && SpikeModeBypassStrict)
{
const double spThRel = SpikeBypassMinProbability;
if(isBoom && dir == "BUY" && spikeDir == "BUY" && (spikeOpportunity || spikeProb + 1e-9 >= spThRel))
{
if(m5Buy > 0.0 && GOM_PriceNearLevel(bid, m5Buy, atr, 0.52)) nearKolaBuySpike = true;
else if(m15Buy > 0.0 && GOM_PriceNearLevel(bid, m15Buy, atr, 0.52)) nearKolaBuySpike = true;
else if(m30Buy > 0.0 && GOM_PriceNearLevel(bid, m30Buy, atr, 0.55)) nearKolaBuySpike = true;
else if(h1Buy > 0.0 && GOM_PriceNearLevel(bid, h1Buy, atr, 0.58)) nearKolaBuySpike = true;
}
if(isCrash && dir == "SELL" && spikeDir == "SELL" && (spikeOpportunity || spikeProb + 1e-9 >= spThRel))
{
if(m5Sell > 0.0 && GOM_PriceNearLevel(bid, m5Sell, atr, 0.52)) nearKolaSellSpike = true;
else if(m15Sell > 0.0 && GOM_PriceNearLevel(bid, m15Sell, atr, 0.52)) nearKolaSellSpike = true;
else if(m30Sell > 0.0 && GOM_PriceNearLevel(bid, m30Sell, atr, 0.55)) nearKolaSellSpike = true;
else if(h1Sell > 0.0 && GOM_PriceNearLevel(bid, h1Sell, atr, 0.58)) nearKolaSellSpike = true;
}
}
if(nearKolaBuySpike || nearKolaSellSpike)
strength += RelaxStrengthSpikeKolaBonus;

GOM_GlobalSetForScript("VERDICT_STRENGTH", strength);
if(StrictConfluenceMode)
{
double minStrengthReq = MinStrengthForEntry;
if(hvSynth) minStrengthReq *= 0.56;
if(hvSynth && passNearKola) minStrengthReq *= 0.88;
if(spikeStrictEase)
   minStrengthReq = MathMin(minStrengthReq, 1.12);
else if(spikeOpportunity && SpikeModeBypassStrict)
   minStrengthReq = MathMax(1.35, minStrengthReq - 0.8);
if(nearKolaBuySpike || nearKolaSellSpike)
minStrengthReq = MathMin(minStrengthReq, RelaxStrengthSpikeKolaMinCap);
if(strength < minStrengthReq)
{
dirOut = "WAIT";
dir = "WAIT";
qualityOut = "WAIT";
GOM_GlobalSetForScript("VERDICT_STRENGTH", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_BUY_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SELL_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_VERDICT_NUM", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SL", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP1", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP2", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP3", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_M1_ENTRY", 0.0);
g_lastPlanDir = "WAIT";
g_lastPlanQuality = "WAIT";
GOMScript_DrawSignalArrow("WAIT", bid);
GOM_MaybePlaceSpikeNearM5Pending(isBoom, isCrash, spikeDir, spikeProb, spikeOpportunity,
                                 blockBuySpike, blockSellSpike, bid, ask, atr, m5Buy, m5Sell);
string kolaSpikeHint = "";
if(nearKolaBuySpike || nearKolaSellSpike) kolaSpikeHint = " | setup spike+KOLA (bonus actif)";
DrawScriptLiveLabel("GOM_SCRIPT_LIVE_LABEL_" + _Symbol,
                     "LIVE WAIT | STRICT: force " + DoubleToString(strength, 2) +
                     " < " + DoubleToString(minStrengthReq, 2) +
                     (spikeStrictEase ? " (bonus spike déjà inclus)" : "") + kolaSpikeHint);
return;
}
bool needMtfStruct = RequireMTFAndStructure && !(hvSynth && passNearKola);
if(needMtfStruct && (!strictMtfPass || !strictStructurePass) && !(spikeOpportunity && SpikeModeBypassStrict) && !spikeStrictEase)
{
dirOut = "WAIT";
dir = "WAIT";
qualityOut = "WAIT";
GOM_GlobalSetForScript("VERDICT_STRENGTH", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_BUY_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SELL_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_VERDICT_NUM", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SL", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP1", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP2", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP3", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_M1_ENTRY", 0.0);
g_lastPlanDir = "WAIT";
g_lastPlanQuality = "WAIT";
GOMScript_DrawSignalArrow("WAIT", bid);
GOM_MaybePlaceSpikeNearM5Pending(isBoom, isCrash, spikeDir, spikeProb, spikeOpportunity,
                                 blockBuySpike, blockSellSpike, bid, ask, atr, m5Buy, m5Sell);
DrawScriptLiveLabel("GOM_SCRIPT_LIVE_LABEL_" + _Symbol,
                     "LIVE WAIT | STRICT: MTF/STRUCT requis");
return;
}
}

int kolaAnchTag = 0;
double kolaAnchLvl = 0.0;
if(dir == "BUY")
GOM_ResolveKolaAnchorBuy(bid, atr, m5Buy, h1Buy, m30Buy, m15Buy, h4Buy, KolaClosestAnchorMaxAtr, kolaAnchTag, kolaAnchLvl);
else if(dir == "SELL")
GOM_ResolveKolaAnchorSell(bid, atr, m5Sell, h1Sell, m30Sell, m15Sell, h4Sell, KolaClosestAnchorMaxAtr, kolaAnchTag, kolaAnchLvl);
GOM_GlobalSetForScript("KOLA_ANCHOR_TAG", (double)kolaAnchTag);
GOM_GlobalSetForScript("KOLA_ANCHOR_PRICE", kolaAnchLvl);

if(RequireMinConfidenceForHtfEntry && MinConfidenceHtfEntryPct > 1e-9 && (dir == "BUY" || dir == "SELL"))
{
bool needHtfConf = (kolaAnchTag >= 2 && kolaAnchTag <= 5);
if(!needHtfConf && kolaAnchTag == -1)
needHtfConf = (dir == "BUY" && m5Buy <= 0.0) || (dir == "SELL" && m5Sell <= 0.0);
if(!needHtfConf && kolaAnchTag == 0)
needHtfConf = (dir == "BUY" && m5Buy <= 0.0) || (dir == "SELL" && m5Sell <= 0.0);

if(needHtfConf)
{
double ccomb = GOM_CombinedTradeConfidence(filterQuality, spikeProb);
double cneed = MinConfidenceHtfEntryPct / 100.0;
if(ccomb + 1e-9 < cneed)
{
dirOut = "WAIT";
dir = "WAIT";
qualityOut = "WAIT";
GOM_GlobalSetForScript("VERDICT_STRENGTH", 0.0);
GOM_GlobalSetForScript("COMBINED_CONF", ccomb);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_BUY_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SELL_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_VERDICT_NUM", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SL", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP1", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP2", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP3", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_M1_ENTRY", 0.0);
g_lastPlanDir = "WAIT";
g_lastPlanQuality = "WAIT";
GOMScript_DrawSignalArrow("WAIT", bid);
ObjectDelete(0, "GOM_PLAN_ENTRY");
ObjectDelete(0, "GOM_PLAN_SL");
ObjectDelete(0, "GOM_PLAN_TP1");
ObjectDelete(0, "GOM_PLAN_TP2");
ObjectDelete(0, "GOM_PLAN_TP3");
ObjectDelete(0, "GOM_PLAN_ARROW");
ObjectDelete(0, "GOM_PLAN_ENTRY_TXT");
ObjectDelete(0, "GOM_PLAN_SL_TXT");
ObjectDelete(0, "GOM_PLAN_TP1_TXT");
ObjectDelete(0, "GOM_PLAN_TP2_TXT");
ObjectDelete(0, "GOM_PLAN_TP3_TXT");
GOM_MaybePlaceSpikeNearM5Pending(isBoom, isCrash, spikeDir, spikeProb, spikeOpportunity,
                                 blockBuySpike, blockSellSpike, bid, ask, atr, m5Buy, m5Sell);
DrawScriptLiveLabel("GOM_SCRIPT_LIVE_LABEL_" + _Symbol,
   "LIVE WAIT | Zone " + GOM_KolaAnchorTagToStr(kolaAnchTag) +
   ": conf max " + DoubleToString(ccomb * 100.0, 1) + "% < " +
   DoubleToString(MinConfidenceHtfEntryPct, 0) + "% | SPIKE=" + spikeDir);
return;
}
}
}

double ccombOk = GOM_CombinedTradeConfidence(filterQuality, spikeProb);
GOM_GlobalSetForScript("COMBINED_CONF", ccombOk);

if(dir == "BUY")
{
// Niveau KOLA le plus proche du prix (dans KolaClosestAnchorMaxAtr×ATR) sinon ancienne prio M5>H1>M30>M15>H4.
if(kolaAnchTag >= 1 && kolaAnchTag <= 5 && kolaAnchLvl > 0.0)
entry = kolaAnchLvl;
else
{
if(m5Buy > 0.0) entry = m5Buy;
else if(h1Buy > 0.0) entry = h1Buy;
else if(m30Buy > 0.0) entry = m30Buy;
else if(m15Buy > 0.0) entry = m15Buy;
else if(h4Buy > 0.0) entry = h4Buy;
else entry = bid - atr * 0.15;
}
double m1Entry = (m1Buy > 0.0 ? m1Buy : (entry - atr * 0.05));
double slBuf = atr * 0.55;
double tpScalp = atr * 0.88;
if(m5Buy > 0.0 && MathAbs(entry - m5Buy) < atr * 0.02)
{
sl = m5Buy - MathMax(atr * 0.28, slBuf * 0.65);
tp1 = entry + MathMax(atr * 0.72, tpScalp);
}
else if(h1Buy > 0.0 && MathAbs(entry - h1Buy) < atr * 0.02)
{
sl = h1Buy - MathMax(atr * 0.38, slBuf * 0.85);
tp1 = entry + MathMax(atr * 0.92, tpScalp * 1.05);
}
else if(m30Buy > 0.0 && MathAbs(entry - m30Buy) < atr * 0.02)
{
sl = m30Buy - MathMax(atr * 0.35, slBuf * 0.80);
tp1 = entry + MathMax(atr * 0.88, tpScalp);
}
else if(m15Buy > 0.0 && MathAbs(entry - m15Buy) < atr * 0.02)
{
sl = m15Buy - MathMax(atr * 0.33, slBuf * 0.78);
tp1 = entry + MathMax(atr * 0.85, tpScalp);
}
else if(h4Buy > 0.0 && MathAbs(entry - h4Buy) < atr * 0.02)
{
sl = h4Buy - MathMax(atr * 0.42, slBuf * 0.90);
tp1 = entry + MathMax(atr * 0.95, tpScalp * 1.08);
}
else
{
double base = (h1Buy > 0.0) ? h1Buy : ((m5Buy > 0.0) ? m5Buy : ((m30Buy > 0.0) ? m30Buy : ((h4Buy > 0.0) ? h4Buy : (entry - atr))));
sl = MathMin(base, entry - atr * 0.75);
tp1 = entry + atr * 0.82;
}
tp2 = entry + atr * 1.6;
tp3 = entry + atr * 2.4;
GOM_PreparePlanLevels("BUY", bid, entry, sl, tp1, tp2, tp3);
if(m1Entry <= 0.0) m1Entry = entry;
if(m1Entry > entry) m1Entry = entry;
m1Entry = NormalizeDouble(m1Entry, _Digits);

// Qualité ajustée selon les filtres (sans Ollama)
if(strength >= 3.6 && filterQuality >= 0.8) qualityOut = "PERFECT BUY";
else if(strength >= 2.8 && filterQuality >= 0.6) qualityOut = "GOOD BUY";
else qualityOut = "BUY";
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_BUY_ENTRY", entry);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SELL_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SL", sl);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP1", tp1);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP2", tp2);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP3", tp3);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_M1_ENTRY", m1Entry);
GOM_GlobalSetForScript("VERDICT_NUM", GOM_VerdictNumFromQuality(qualityOut));
}
else
{
if(kolaAnchTag >= 1 && kolaAnchTag <= 5 && kolaAnchLvl > 0.0)
entry = kolaAnchLvl;
else
{
if(m5Sell > 0.0) entry = m5Sell;
else if(h1Sell > 0.0) entry = h1Sell;
else if(m30Sell > 0.0) entry = m30Sell;
else if(m15Sell > 0.0) entry = m15Sell;
else if(h4Sell > 0.0) entry = h4Sell;
else entry = bid + atr * 0.15;
}
double m1Entry = (m1Sell > 0.0 ? m1Sell : (entry + atr * 0.05));
double slBuf = atr * 0.55;
double tpScalp = atr * 0.88;
if(m5Sell > 0.0 && MathAbs(entry - m5Sell) < atr * 0.02)
{
sl = m5Sell + MathMax(atr * 0.28, slBuf * 0.65);
tp1 = entry - MathMax(atr * 0.72, tpScalp);
}
else if(h1Sell > 0.0 && MathAbs(entry - h1Sell) < atr * 0.02)
{
sl = h1Sell + MathMax(atr * 0.38, slBuf * 0.85);
tp1 = entry - MathMax(atr * 0.92, tpScalp * 1.05);
}
else if(m30Sell > 0.0 && MathAbs(entry - m30Sell) < atr * 0.02)
{
sl = m30Sell + MathMax(atr * 0.35, slBuf * 0.80);
tp1 = entry - MathMax(atr * 0.88, tpScalp);
}
else if(m15Sell > 0.0 && MathAbs(entry - m15Sell) < atr * 0.02)
{
sl = m15Sell + MathMax(atr * 0.33, slBuf * 0.78);
tp1 = entry - MathMax(atr * 0.85, tpScalp);
}
else if(h4Sell > 0.0 && MathAbs(entry - h4Sell) < atr * 0.02)
{
sl = h4Sell + MathMax(atr * 0.42, slBuf * 0.90);
tp1 = entry - MathMax(atr * 0.95, tpScalp * 1.08);
}
else
{
double base = (h1Sell > 0.0) ? h1Sell : ((m5Sell > 0.0) ? m5Sell : ((m30Sell > 0.0) ? m30Sell : ((h4Sell > 0.0) ? h4Sell : (entry + atr))));
sl = MathMax(base, entry + atr * 0.75);
tp1 = entry - atr * 0.82;
}
tp2 = entry - atr * 1.6;
tp3 = entry - atr * 2.4;
GOM_PreparePlanLevels("SELL", bid, entry, sl, tp1, tp2, tp3);
if(m1Entry <= 0.0) m1Entry = entry;
if(m1Entry < entry) m1Entry = entry;
m1Entry = NormalizeDouble(m1Entry, _Digits);

// Qualité ajustée selon les filtres (sans Ollama)
if(strength >= 3.6 && filterQuality >= 0.8) qualityOut = "PERFECT SELL";
else if(strength >= 2.8 && filterQuality >= 0.6) qualityOut = "GOOD SELL";
else qualityOut = "SELL";
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_BUY_ENTRY", 0.0);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SELL_ENTRY", entry);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_SL", sl);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP1", tp1);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP2", tp2);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_TP3", tp3);
GlobalVariableSet("GOM_SCRIPT_" + _Symbol + "_M1_ENTRY", m1Entry);
GOM_GlobalSetForScript("VERDICT_NUM", GOM_VerdictNumFromQuality(qualityOut));
}

bool verdictChanged = (dir != g_lastPlanDir || qualityOut != g_lastPlanQuality || g_lastPlanEntry <= 0.0);
if(verdictChanged)
{
g_lastPlanDir = dir;
g_lastPlanQuality = qualityOut;
g_lastPlanEntry = entry;
g_lastPlanSL = sl;
g_lastPlanTP1 = tp1;
g_lastPlanTP2 = tp2;
g_lastPlanTP3 = tp3;
}
else
{
// Garder plan stable tant que verdict inchangé (évite SL/TP qui bougent en permanence)
entry = g_lastPlanEntry;
sl = g_lastPlanSL;
tp1 = g_lastPlanTP1;
tp2 = g_lastPlanTP2;
tp3 = g_lastPlanTP3;
}

DrawOrUpdateHLine("GOM_PLAN_ENTRY", entry, (dir == "BUY") ? clrLime : clrTomato, STYLE_DOT, 1);
DrawOrUpdateHLine("GOM_PLAN_SL", sl, clrOrange, STYLE_SOLID, 1);
DrawOrUpdateHLine("GOM_PLAN_TP1", tp1, clrWhite, STYLE_SOLID, 1);
DrawOrUpdateHLine("GOM_PLAN_TP2", tp2, clrWhite, STYLE_SOLID, 1);
DrawOrUpdateHLine("GOM_PLAN_TP3", tp3, clrWhite, STYLE_SOLID, 1);

DrawPriceTag("GOM_PLAN_ENTRY_TXT", "Entry", entry, (dir == "BUY") ? clrLime : clrTomato);
DrawPriceTag("GOM_PLAN_SL_TXT", "SL SWING", sl, clrOrange);
DrawPriceTag("GOM_PLAN_TP1_TXT", "TP1", tp1, clrWhite);
DrawPriceTag("GOM_PLAN_TP2_TXT", "TP2", tp2, clrWhite);
DrawPriceTag("GOM_PLAN_TP3_TXT", "TP3", tp3, clrWhite);
GOMScript_DrawSignalArrow(dir, entry);

// Label live: prouve que le script calcule en continu + montre le verdict réel + statut des filtres
string filterQualityTxt = (filterQuality > 0.0) ? (" | FQ=" + DoubleToString(filterQuality * 100.0, 0) + "%") : "";
double vwapD = GOM_GlobalGetForScript("VWAP_DIST_PCT", 0.0);
double bbPctB100 = GOM_GlobalGetForScript("BB_PCTB", 0.5) * 100.0;
string bbBandTxt = " | VWAPΔ" + DoubleToString(vwapD, 2) + "% BB%" + DoubleToString(bbPctB100, 0) +
   ((GOM_GlobalGetForScript("BB_SQUEEZE", 0.0) > 0.5) ? " SQZ" : "");
double eqShow = GOM_GlobalGetForScript("ENTRY_QUALITY", 0.0);
string eqTxt = (eqShow > 1e-6) ? (" | EQ=" + DoubleToString(eqShow * 100.0, 0) + "%") : "";
DrawScriptLiveLabel("GOM_SCRIPT_LIVE_LABEL_" + _Symbol,
                  "LIVE " + qualityOut +
                  " | SPIKE=" + spikeDir + " " + DoubleToString(spikeProb * 100.0, 0) + "%" +
                  " | FILTERS=" + filterStatus +
                  filterQualityTxt + bbBandTxt + eqTxt +
                  " | Entry=" + DoubleToString(entry, _Digits));
}

void DrawBottomDashboard()
{
// Toujours recalculer le plan / publier GOM_SCRIPT_* (l’EA dépend de ces GV même si l’affichage est masqué).
string dirTxt = "WAIT";
string qualityTxt = "WAIT";
DrawTradePlanVisuals(dirTxt, qualityTxt);
if(StringLen(dirTxt) < 2) dirTxt = "WAIT";
if(StringLen(qualityTxt) < 2) qualityTxt = "WAIT";
GOM_PublishMLFeatureGlobals();
   if(EnableChartLeftShift)
   {
      double sh = ChartLeftShiftPct;
      if(sh < 2.0) sh = 2.0;
      if(sh > 50.0) sh = 50.0;
      ChartSetInteger(0, CHART_SHIFT, true);
      ChartSetDouble(0, CHART_SHIFT_SIZE, sh); // Utiliser la valeur brute (0-50%)
   }
   
   // Forcer l'état de l'auto-scroll (False par défaut pour garder la zone futur visible)
   ChartSetInteger(0, CHART_AUTOSCROLL, EnableChartAutoscroll);
GOM_DrawPastFutureZone();

int x0 = MathMax(2, DashboardLeftOffset - MathMax(0, DashboardNudgeLeftPx));
const int colsTv = 7;
   int y0 = MathMax(2, DashboardBottomOffset);
   int gap = MathMax(2, DashboardCellGap);
   int gapV = MathMax(2, DashboardTopRowExtraGap);
   int hRow = MathMax(20, MathMax(DashboardCellHeight, MathMax(DashboardMetaRowHeight, DashboardVerdictRowHeight)));
int chartPixW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
if(chartPixW < 200) chartPixW = 1200;
int mL = MathMax(2, DashboardBarMarginLeft);
int mR = MathMax(6, DashboardBarMarginRight);
int barInnerW = chartPixW - mL - mR;
if(barInnerW < colsTv * 40) barInnerW = colsTv * 40;
int cellW = (barInnerW - (colsTv - 1) * gap) / colsTv;
if(cellW < 34) cellW = 34;
int firstStripW = colsTv * cellW + (colsTv - 1) * gap;
int xBar = mL;
if(!DashboardTvFullWidthBar)
{
int wfix = MathMax(72, DashboardCellWidth);
cellW = wfix;
firstStripW = colsTv * cellW + (colsTv - 1) * gap;
int mrDash = MathMax(8, DashboardSecondaryRightMargin);
xBar = x0 + MathMax(0, DashboardTopRowShiftRightPx);
if(DashboardIndicatorsAnchorBottomRight)
{
const int xr = chartPixW - mrDash - firstStripW;
if(xr >= 2) xBar = xr;
}
}
int cw = MathMax(280, DashboardCompactWidth);
int mrDash = MathMax(8, DashboardSecondaryRightMargin);
int cx = x0 + MathMax(0, DashboardTopRowShiftRightPx);
int compactX = cx;
if(DashboardCompactVerdictOnly && DashboardCompactAnchorBottomRight && !DashboardCompactSpanChartWidth)
{
compactX = chartPixW - mrDash - cw;
if(compactX < 2) compactX = 2;
}
if(DashboardCompactVerdictOnly && DashboardCompactSpanChartWidth)
{
compactX = mL;
cw = barInnerW;
if(cw < 260) cw = 260;
}
   // Inversion du Y : y1 est la ligne du BAS (Indicateurs), y2 est la ligne du HAUT (Timeframes)
   int yInd = y0; // Ligne 1 : indicateurs (VOL, ATR, etc) en bas
   int yDir = y0 + hRow + gapV; // Ligne 2 : Timeframes et Verdict en haut (TradingView style)
   int yFc = y0 + 2 * (hRow + gapV);
int stripFs = MathMax(7, DashboardFontSize - MathMax(0, DashboardStripFontDelta));
int hMetaFull = MathMax(18, DashboardMetaRowHeight);
int hMetaCompact = MathMax(14, DashboardCompactBottomMetaHeight);
int hMeta = DashboardCompactVerdictOnly ? hMetaCompact : hMetaFull;
int hVerRowCompact = (int)MathMin(34, MathMax(22, DashboardVerdictRowHeight));
int compactMetaY = y0;
int row2Y = y0 + hMeta + gapV;

if(!ShowBottomDashboard)
{
ObjectDelete(0, "GOM_SPIKE_IMMINENT");
ObjectDelete(0, DASH_PREFIX + "TOP_AI");
ObjectDelete(0, DASH_PREFIX + "TOP_AI_TXT");
ObjectDelete(0, DASH_PREFIX + "BOT_WAIT");
ObjectDelete(0, DASH_PREFIX + "BOT_WAIT_TXT");
double bidN = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(bidN <= 0.0) bidN = iClose(_Symbol, PERIOD_CURRENT, 0);
GOM_UpdateM1Forecast500Globals(bidN);
GOM_DrawM1ForecastChartOverlay(bidN);
GOM_UpdateNotifyPositionAndSpike(bidN,
   GOM_GlobalGetForScript("SPIKE_PROB", 0.0),
   GOM_GlobalGetForScript("SPIKE_DIR_NUM", 0.0));
if(ShowMLFeatureInfo)
GOM_DrawMLInfoFloatingLabel();
else
ObjectDelete(0, "GOM_MLINFO_BR");
return;
}

ObjectDelete(0, DASH_PREFIX + "TOP_AI");
ObjectDelete(0, DASH_PREFIX + "TOP_AI_TXT");
ObjectDelete(0, DASH_PREFIX + "BOT_WAIT");
ObjectDelete(0, DASH_PREFIX + "BOT_WAIT_TXT");

if(DashboardCompactVerdictOnly)
GOM_DeleteDashboardFullStripObjects();

double atr = GOM_ATRValue(_Symbol, PERIOD_M15, 14);

double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(bid <= 0.0) bid = iClose(_Symbol, PERIOD_CURRENT, 0);
double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
if(ask <= 0.0) ask = bid;
GOM_UpdateM1Forecast500Globals(bid);
double atrPct = (bid > 0.0) ? (atr / bid) * 100.0 : 0.0;
double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
if(point <= 0.0) point = 0.1;
double atrPts = atr / point;
bool volOn = (atrPct + 1e-12 >= DashboardVolOnMinAtrPct);
bool atrOk = (atrPct + 1e-12 >= DashboardAtrOkMinAtrPct);
string volTxt = (volOn ? "VOL ON " : "VOL OFF ") + DoubleToString(atrPct, 2) + "%";
color volBg = volOn ? (color)0x2F5F3F : (color)0x484848;
string atrTxt = atrOk ? ("ATR OK " + DoubleToString(atrPts, 0) + "p") : ("ATR " + DoubleToString(atrPts, 0) + "p");
color atrBg = atrOk ? (color)0x3A8C5A : (color)0x2F607C;

color dirBg = (dirTxt == "BUY") ? (color)0x49A96B : ((dirTxt == "SELL") ? (color)0xB0303C : (color)0x666666);
color verdictBg = GOM_VerdictCellColor(qualityTxt);

double spProb = GOM_GlobalGetForScript("SPIKE_PROB", 0.0);
double spDirNum = GOM_GlobalGetForScript("SPIKE_DIR_NUM", 0.0);
string spTxt = "SPIKE --";
color spBg = (color)0x353535;
if(spProb > 0.0)
{
string sdir = (spDirNum > 0.5) ? "BUY" : ((spDirNum < -0.5) ? "SELL" : "WAIT");
spTxt = "SPIKE " + sdir + " " + DoubleToString(spProb * 100.0, 0) + "%";
if(spProb >= SpikeAlertMinProbability)
   spBg = (sdir == "BUY") ? (color)0x2F7A45 : ((sdir == "SELL") ? (color)0x7A2F37 : (color)0x505050);
else
   spBg = (color)0x4A4A4A;
}

// Statut des filtres de confirmation
double filterPassCount = GOM_GlobalGetForScript("FILTER_PASS_COUNT", 0.0);
double filterTotal = GOM_GlobalGetForScript("FILTER_TOTAL", 0.0);
double filterQuality = GOM_GlobalGetForScript("FILTER_QUALITY", 0.0);
string filterTxt = "FILTERS --";
color filterBg = (color)0x353535;
if(filterTotal > 0.0)
{
int pass = (int)filterPassCount;
int total = (int)filterTotal;
double quality = filterQuality * 100.0;
filterTxt = "FILT " + IntegerToString(pass) + "/" + IntegerToString(total) + " " + DoubleToString(quality, 0) + "%";

// Couleur selon la qualité des filtres
if(quality >= 80.0) filterBg = (color)0x2F7A45;      // Vert - Excellent
else if(quality >= 60.0) filterBg = (color)0x4A7A3A;  // Vert clair - Bon
else if(quality >= 40.0) filterBg = (color)0x6A6A2A;  // Jaune - Moyen
else filterBg = (color)0x7A2F37;                     // Rouge - Faible
}

double dt = ReadGV("GOM_SIDO", "M15", "DOUBLE_TOP");
double db = ReadGV("GOM_SIDO", "M15", "DOUBLE_BOTTOM");
string sidoTxt = "NONE";
if(dt > 0.0 && db > 0.0) sidoTxt = "DB+DT";
else if(dt > 0.0) sidoTxt = "DTOP";
else if(db > 0.0) sidoTxt = "DBOT";

double m5b = ReadGV("GOM_KOLA", "M5", "BUY");
double m5s = ReadGV("GOM_KOLA", "M5", "SELL");
double m15Buy = ReadGV("GOM_KOLA", "M15", "BUY");
double m15Sell = ReadGV("GOM_KOLA", "M15", "SELL");
double m30BuyDash = ReadGV("GOM_KOLA", "M30", "BUY");
double m30SellDash = ReadGV("GOM_KOLA", "M30", "SELL");
string kolaTxt = "KOLA --";
if(m5b > 0.0 && m5s > 0.0) kolaTxt = "K M5 B/S";
else if(m5b > 0.0) kolaTxt = "K M5 BUY";
else if(m5s > 0.0) kolaTxt = "K M5 SELL";
else if(m15Buy > 0.0 && m15Sell > 0.0) kolaTxt = "K M15 B/S";
else if(m15Buy > 0.0) kolaTxt = "K M15 BUY";
else if(m15Sell > 0.0) kolaTxt = "K M15 SELL";
else if(m30BuyDash > 0.0 && m30SellDash > 0.0) kolaTxt = "K M30 B/S";
else if(m30BuyDash > 0.0) kolaTxt = "K M30 BUY";
else if(m30SellDash > 0.0) kolaTxt = "K M30 SELL";

double rsi1 = GOM_RSIValue(_Symbol, PERIOD_M1, 14);
if(rsi1 <= 0.0) rsi1 = 50.0;
bool macdBull = false;
GOM_MACDMainAboveSignal(_Symbol, PERIOD_M5, macdBull);

string lvlTxt = "--";
double atrz = atr;
if(atrz <= 0.0 && bid > 0.0) atrz = bid * 0.0015;
if(atrz > 0.0)
{
if(m5b > 0.0 && GOM_PriceNearLevel(bid, m5b, atrz, 0.4)) lvlTxt = "NEAR M5+";
else if(m5s > 0.0 && GOM_PriceNearLevel(bid, m5s, atrz, 0.4)) lvlTxt = "NEAR M5-";
else if(m15Buy > 0.0 && GOM_PriceNearLevel(bid, m15Buy, atrz, 0.45)) lvlTxt = "NEAR M15+";
else if(m15Sell > 0.0 && GOM_PriceNearLevel(bid, m15Sell, atrz, 0.45)) lvlTxt = "NEAR M15-";
else if(m30BuyDash > 0.0 && GOM_PriceNearLevel(bid, m30BuyDash, atrz, 0.48)) lvlTxt = "NEAR M30+";
else if(m30SellDash > 0.0 && GOM_PriceNearLevel(bid, m30SellDash, atrz, 0.48)) lvlTxt = "NEAR M30-";
}

double rsi5d = GOM_RSIValue(_Symbol, PERIOD_M5, 14);
if(rsi5d <= 0.0) rsi5d = 50.0;
double adx5d = GOM_ADXValue(_Symbol, PERIOD_M5, 14);
double st5d = GOM_StochMain(_Symbol, PERIOD_M5, 5, 3, 3);
string rsiDualTxt = "RSI " + DoubleToString(rsi1, 0) + "/" + DoubleToString(rsi5d, 0);
color rsiDualBg = (rsi1 >= 50.0 && rsi5d >= 48.0) ? (color)0x3A5A8C : ((rsi1 <= 50.0 && rsi5d <= 52.0) ? (color)0x5A3A3A : (color)0x4B4B4B);
string adxStTxt = "ADX " + DoubleToString(adx5d, 0) + " St " + DoubleToString(st5d, 0) + " M" + (macdBull ? "+" : "-");
color adxStBg = (adx5d >= 22.0) ? (color)0x2B4A6E : (color)0x454545;

double entryQDash = GOM_GlobalGetForScript("ENTRY_QUALITY", 0.0);
string eqTxt = (entryQDash > 1e-6) ? ("EQ " + DoubleToString(entryQDash * 100.0, 0) + "%") : "EQ —";
color eqBg = (color)0x3A3A5C;
if(entryQDash + 1e-9 >= MinEntryQualityScore) eqBg = (color)0x2F5F4F;
else if(entryQDash > 0.35) eqBg = (color)0x5A5A2A;

double bbPctDash = GOM_GlobalGetForScript("BB_PCTB", 0.5) * 100.0;
bool bbSq = (GOM_GlobalGetForScript("BB_SQUEEZE", 0.0) > 0.5);
string bbTxt = "BB " + DoubleToString(bbPctDash, 0) + "%" + (bbSq ? " S" : "");
color bbBg = bbSq ? (color)0x4A3A6A : (color)0x3C3C3C;

double vwapDist = GOM_GlobalGetForScript("VWAP_DIST_PCT", 0.0);
string vwTxt = (MathAbs(vwapDist) > 1e-6) ? ("VW " + DoubleToString(vwapDist, 2) + "%") : "VW —";
color vwBg = (vwapDist > 0.02) ? (color)0x2F4F3F : ((vwapDist < -0.02) ? (color)0x5A3038 : (color)0x404040);

int panelW = DashboardCompactVerdictOnly ? (cw + 8) : (firstStripW + 8);
int panelH = 2 * hRow + gapV + 8;
if(!DashboardCompactVerdictOnly && ShowM1Forecast500Strip)
panelH = 3 * hRow + 2 * gapV + 8;
if(DashboardCompactVerdictOnly)
panelH = hMeta + gapV + hVerRowCompact + 8;
if(ShowDashboardBackgroundBand)
{
if(DashboardCompactVerdictOnly)
DrawDashboardPanel(DASH_PREFIX + "PANEL", compactX - 4, y0 - 4, cw + 8, panelH, clrNONE);
else
DrawDashboardPanel(DASH_PREFIX + "PANEL", xBar - 4, y0 - 4, firstStripW + 8, panelH, clrNONE);
}
else
ObjectDelete(0, DASH_PREFIX + "PANEL");

if(!DashboardCompactVerdictOnly)
{
string obsoleteStrip[] = {
"BOT_META_DIR", "BOT_META_SRV", "BOT_META_LLM", "BOT_META_PX", "BOT_META_SPR", "BOT_META_VER",
"BOT_DIRMETA", "BOT_SIDO", "BOT_KOLA", "BOT_RSIMACD", "BOT_FILTERS", "BOT_EQ", "BOT_BB", "BOT_VWAP", "BOT_ADXST",
"BOT_BRAND", "BOT_LVL", "BOT_VOL", "BOT_ATR", "BOT_STAR", "BOT_TV_SIDE", "BOT_TV_VER"
};
for(int ob = 0; ob < ArraySize(obsoleteStrip); ob++)
{
ObjectDelete(0, DASH_PREFIX + obsoleteStrip[ob]);
ObjectDelete(0, DASH_PREFIX + obsoleteStrip[ob] + "_TXT");
}

string topTf[6] = {"M5", "M15", "M30", "H1", "H4", "D1"};
ENUM_TIMEFRAMES tfs[6] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1};
color upBg = (color)0x23D18C;
color dnBg = (color)0xFF3B58;
color flatBg = (color)0x787B86;
for(int ti = 0; ti < 6; ti++)
{
int bb = GetTFBias(tfs[ti]);
color tbg = (bb > 0) ? upBg : ((bb < 0) ? dnBg : flatBg);
DrawDashboardCellFont(
   DASH_PREFIX + "TOP_" + topTf[ti],
   BiasText(topTf[ti], bb),
   xBar + ti * (cellW + gap),
   yDir,
   cellW,
   hRow,
   tbg,
   clrWhite,
   stripFs,
   true
);
}
DrawDashboardCellFont(
   DASH_PREFIX + "TOP_VERDICT",
   qualityTxt,
   xBar + 6 * (cellW + gap),
   yDir,
   cellW,
   hRow,
   verdictBg,
   clrWhite,
   stripFs + 1,
   true
);
}
else
{
int verX = compactX;
int fullW = cw;
int innerG = MathMax(2, gap);
int verW = (int)MathMax(72, (int)(fullW * 0.14));
if(verW > fullW / 2) verW = fullW / 2;
int rem = fullW - verW - innerG;
int tfCellW = (rem - 5 * innerG) / 6;
if(tfCellW < 26)
{
verW = fullW - 6 * 26 - 5 * innerG - innerG;
if(verW < 64) verW = 64;
tfCellW = (fullW - verW - innerG - 5 * innerG) / 6;
if(tfCellW < 24) tfCellW = 24;
}
int tfX0 = verX + verW + innerG;
int verFont = (int)MathMin(15, MathMax(9, DashboardFontSize + 1));
DrawDashboardVerdictCell(DASH_PREFIX + "TOP_VERDICT", qualityTxt, verX, row2Y, verW, hVerRowCompact, verdictBg, DashboardVerdictBorderColor, clrWhite, verFont);

string topTf[6] = {"M5", "M15", "M30", "H1", "H4", "D1"};
ENUM_TIMEFRAMES tfs[6] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1};
color upBg = (color)0x23D18C;
color dnBg = (color)0xFF3B58;
color flatBg = (color)0x787B86;
int tfFs = (int)MathMax(7, MathMin(9, stripFs));
for(int ti = 0; ti < 6; ti++)
{
int bb = GetTFBias(tfs[ti]);
color tbg = (bb > 0) ? upBg : ((bb < 0) ? dnBg : flatBg);
DrawDashboardCellFont(
   DASH_PREFIX + "COMPACT_TF_" + topTf[ti],
   topTf[ti] + ":" + (bb > 0 ? "↑" : (bb < 0 ? "↓" : "→")),
   tfX0 + ti * (tfCellW + innerG),
   row2Y,
   tfCellW,
   hVerRowCompact,
   tbg,
   clrWhite,
   tfFs,
   true
);
}
}

double srvConfDash = ReadGVDirect("SMC_UNIVERSAL_" + _Symbol + "_SERVER_AI_CONF", 0.0);
if(srvConfDash > 1.0) srvConfDash /= 100.0;
double confPctDash = srvConfDash * 100.0;
if(confPctDash < 0.5)
{
double extc = g_lastExtAiConf;
if(extc > 1.0) extc /= 100.0;
confPctDash = extc * 100.0;
}
if(confPctDash < 0.5 && filterQuality > 0.0)
confPctDash = filterQuality * 100.0;
double combG = GOM_GlobalGetForScript("COMBINED_CONF", 0.0);
if(combG > 1.0) combG /= 100.0;
if(combG > 0.0)
confPctDash = MathMax(confPctDash, combG * 100.0);

string extraInd = "";
if(ShowDashboardExtraIndicators)
{
int sec5d = GOM_SecondsToBarClose(_Symbol, PERIOD_M5);
if(sec5d < 0) sec5d = 0;
   extraInd = " | Sp:" + GOM_FormatSpreadForDash() + "pt ATR:" + DoubleToString(atrPct, 2) + "%";
   extraInd += " M5:" + IntegerToString(sec5d) + "s RSI5:" + DoubleToString(rsi5d, 0);
   extraInd += " ADX:" + DoubleToString(adx5d, 0) + " St:" + DoubleToString(st5d, 0);
double stDir = GOM_GlobalGetForScript("TV_SUPERTREND_DIR", 0.0);
double kcPos = GOM_GlobalGetForScript("TV_KELTNER_POS", 0.0);
double dcSig = GOM_GlobalGetForScript("TV_DONCHIAN_SIG", 0.0);
string stTxt = (stDir > 0.10) ? "UP" : ((stDir < -0.10) ? "DN" : "NEU");
string dcTxt = (dcSig > 0.10) ? "B" : ((dcSig < -0.10) ? "S" : "-");
extraInd += " | TV ST:" + stTxt + " KC:" + DoubleToString(kcPos, 2) + " DC:" + dcTxt;
}
if(DashboardCompactVerdictOnly && ShowDashboardExtraIndicators)
{
extraInd += " | " + spTxt + " SIDO " + sidoTxt + " " + kolaTxt + " " + filterTxt + " " + lvlTxt;
}

double srvCfW = ReadGVDirect("SMC_UNIVERSAL_" + _Symbol + "_SERVER_AI_CONF", 0.0);
if(srvCfW > 1.0) srvCfW /= 100.0;
double srvActW = ReadGVDirect("SMC_UNIVERSAL_" + _Symbol + "_SERVER_AI_ACTION_NUM", 0.0);
string srvDW = (srvActW > 0.5) ? "B" : ((srvActW < -0.5) ? "S" : "-");
string aiTail = " | SRV " + srvDW + " " + DoubleToString(srvCfW * 100.0, 0) + "%";
double dsPhase = GOM_GlobalGetForScript("DOUBLE_SPIKE_PHASE", 0.0);
double dsHold = GOM_GlobalGetForScript("DOUBLE_SPIKE_HOLD", 0.0);
string dsTxt = (dsHold > 0.5) ? " DS2 HOLD" : ((dsPhase >= 1.0) ? " DS1 ARM" : " DS0");

string botWideTxt =
   dirTxt + " | conf " + DoubleToString(confPctDash, 0) + "% | " + FmtPrice(bid) + " | " + DashboardScriptVersion + dsTxt + aiTail + extraInd;

if(!DashboardCompactVerdictOnly)
{
string volShort = volOn ? "VOL ON" : "VOL OFF";
string atrShort = atrOk ? "ATR OK" : ("ATR " + IntegerToString((int)atrPts) + "p");

double rM5 = GOM_RSIValue(_Symbol, PERIOD_M5, 14);
double rM15 = GOM_RSIValue(_Symbol, PERIOD_M15, 14);
double rM30 = GOM_RSIValue(_Symbol, PERIOD_M30, 14);
double rH1 = GOM_RSIValue(_Symbol, PERIOD_H1, 14);
double rH4 = GOM_RSIValue(_Symbol, PERIOD_H4, 14);
double rD1 = GOM_RSIValue(_Symbol, PERIOD_D1, 14);
if(rM5 <= 0.0) rM5 = 50.0;
if(rM15 <= 0.0) rM15 = 50.0;
if(rM30 <= 0.0) rM30 = 50.0;
if(rH1 <= 0.0) rH1 = 50.0;
if(rH4 <= 0.0) rH4 = 50.0;
if(rD1 <= 0.0) rD1 = 50.0;

   // Labels enrichis pour un dashboard plus complet
   string s0 = "SPK " + ((spProb > 0.0) ? (DoubleToString(spProb * 100.0, 0) + "%") : "--") + " | " + volShort;
   string s1 = "M15 RSI:" + DoubleToString(rM15, 0) + " | " + atrShort;
   string s2 = "M30 RSI:" + DoubleToString(rM30, 0) + " | " + StringSubstr(bbTxt, 0, 9);
   string s3 = "H1 RSI:" + DoubleToString(rH1, 0) + " | " + StringSubstr(vwTxt, 0, 9);
   string fqPct = (filterTotal > 0.0) ? (IntegerToString((int)filterPassCount) + "/" + IntegerToString((int)filterTotal)) : "--";
   string s4 = "H4 RSI:" + DoubleToString(rH4, 0) + " | FILT:" + fqPct;
   string sidoStat = (sidoTxt == "NONE") ? "--" : sidoTxt;
   string s5 = "D1 RSI:" + DoubleToString(rD1, 0) + " | SIDO:" + sidoStat;

   string sideTxt = "WAIT";
   color sideBg = (color)0x5A5A5A;
   if(dirTxt == "BUY") { sideTxt = "LONG"; sideBg = (color)0x49A96B; }
   else if(dirTxt == "SELL") { sideTxt = "SHORT"; sideBg = (color)0xB0303C; }

   double dailyProfit = GlobalVariableGet("SMC_UNIVERSAL_PROFIT_DAILY");
   string profitTxt = " | P/L:" + DoubleToString(dailyProfit, 1) + "$";
   string sprTxt = " | Sp:" + GOM_FormatSpreadForDash() + "pt";
   string end6 = sideTxt + " " + DoubleToString(confPctDash, 0) + "%" + sprTxt + profitTxt;

   color subBg = (color)0x353535;
   int fsSub = MathMax(6, stripFs - 1);
   DrawDashboardCellFont(DASH_PREFIX + "BOTB_M5", s0, xBar + 0 * (cellW + gap), yInd, cellW, hRow, subBg, clrWhite, fsSub, true);
   DrawDashboardCellFont(DASH_PREFIX + "BOTB_M15", s1, xBar + 1 * (cellW + gap), yInd, cellW, hRow, subBg, clrWhite, fsSub, true);
   DrawDashboardCellFont(DASH_PREFIX + "BOTB_M30", s2, xBar + 2 * (cellW + gap), yInd, cellW, hRow, subBg, clrWhite, fsSub, true);
   DrawDashboardCellFont(DASH_PREFIX + "BOTB_H1", s3, xBar + 3 * (cellW + gap), yInd, cellW, hRow, subBg, clrWhite, fsSub, true);
   DrawDashboardCellFont(DASH_PREFIX + "BOTB_H4", s4, xBar + 4 * (cellW + gap), yInd, cellW, hRow, subBg, clrWhite, fsSub, true);
   DrawDashboardCellFont(DASH_PREFIX + "BOTB_D1", s5, xBar + 5 * (cellW + gap), yInd, cellW, hRow, subBg, clrWhite, fsSub, true);
   DrawDashboardCellFont(DASH_PREFIX + "BOTB_END", end6, xBar + 6 * (cellW + gap), yInd, cellW, hRow, sideBg, clrWhite, fsSub, true);

if(ShowM1Forecast500Strip)
{
double fv = GOM_GlobalGetForScript("M1_F500_VALID", 0.0);
string fLine = "M1×500 projection — données insuffisantes";
color fbg = (color)0x3A3A50;
if(fv > 0.5)
{
double rp = GOM_GlobalGetForScript("M1_F500_RET_PCT", 0.0);
double dn = GOM_GlobalGetForScript("M1_F500_DIR", 0.0);
string fArrow = (dn > 0.5) ? GOM_UnicodeChar(0x25B2) : ((dn < -0.5) ? GOM_UnicodeChar(0x25BC) : GOM_UnicodeChar(0x25CB));
fLine = "M1×500 (extrap. tendance) " + fArrow + " " + (rp >= 0.0 ? "+" : "") + DoubleToString(rp, 2) + "% | régr. " + IntegerToString(MathMin(M1ForecastRegressionBars, 600)) + " clôtures";
fbg = (dn > 0.5) ? (color)0x2F4A3F : ((dn < -0.5) ? (color)0x5A3038 : (color)0x3A3A50);
}
DrawDashboardCellFont(DASH_PREFIX + "BOTF_FULL", fLine, xBar, yFc, firstStripW, hRow, fbg, clrWhite, MathMax(6, stripFs - 1), true);
}
else
{
ObjectDelete(0, DASH_PREFIX + "BOTF_FULL");
ObjectDelete(0, DASH_PREFIX + "BOTF_FULL_TXT");
}
}
else
{
DrawDashboardCell(DASH_PREFIX + "BOT_DIRMETA", botWideTxt, compactX, compactMetaY, cw, hMeta, dirBg, clrWhite);
string metaLbl2 = DASH_PREFIX + "BOT_DIRMETA_TXT";
if(ObjectFind(0, metaLbl2) >= 0)
{
ObjectSetString(0, metaLbl2, OBJPROP_FONT, "Arial Bold");
int metaFs2 = MathMax(10, DashboardFontSize + 1);
if(StringLen(botWideTxt) > 95) metaFs2 = MathMax(8, DashboardFontSize);
ObjectSetInteger(0, metaLbl2, OBJPROP_FONTSIZE, metaFs2);
ObjectSetInteger(0, metaLbl2, OBJPROP_ANCHOR, ANCHOR_CENTER);
ObjectSetInteger(0, metaLbl2, OBJPROP_XDISTANCE, compactX + cw / 2);
ObjectSetInteger(0, metaLbl2, OBJPROP_YDISTANCE, compactMetaY + hMeta / 2);
ObjectSetInteger(0, metaLbl2, OBJPROP_COLOR, clrWhite);
}
}

bool isBoomD = GOM_IsBoomOrGainx();
bool isCrashD = GOM_IsCrashOrPainx();
static bool g_prevSpikeImminentOn = false;
static bool g_prevPlanBlinkArrowActive = false;
bool imminentNow = DrawSpikeImminentArrow(bid, spProb, spDirNum, isBoomD, isCrashD, dirTxt);
if(EnableSpikeImminentFirstAutoPending && imminentNow && !g_prevSpikeImminentOn)
{
string sdImm = (spDirNum > 0.5) ? "BUY" : ((spDirNum < -0.5) ? "SELL" : "NONE");
if(sdImm != "NONE")
   GOM_TrySpikeImminentFirstPending(isBoomD, isCrashD, sdImm, spProb, bid, ask, atr, m5b, m5s);
}
g_prevSpikeImminentOn = imminentNow;

const bool planBlink = (dirTxt == "BUY" || dirTxt == "SELL");
const bool planArrowRise = planBlink && !g_prevPlanBlinkArrowActive;
if(planArrowRise)
{
   if(EnableAutoMarketOnGomPlanArrow)
      GOM_TryMarketEntryOnPlanArrowRise(isBoomD, isCrashD, dirTxt, bid, ask, atr);
   else if(SpikeImminentFirstTriggerOnPlanArrowRise && EnableSpikeImminentFirstAutoPending)
   {
      const string sdPl = (dirTxt == "BUY") ? "BUY" : "SELL";
      if((isBoomD && sdPl == "BUY") || (isCrashD && sdPl == "SELL"))
         GOM_TrySpikeImminentFirstPending(isBoomD, isCrashD, sdPl, spProb, bid, ask, atr, m5b, m5s);
   }
}
g_prevPlanBlinkArrowActive = planBlink;

GOM_DrawM1ForecastChartOverlay(bid);
GOM_UpdateNotifyPositionAndSpike(bid, spProb, spDirNum);

ObjectDelete(0, DASH_PREFIX + "TOP_D1MARK_TXT");
ObjectDelete(0, DASH_PREFIX + "TOP_D1MARK");
ObjectDelete(0, DASH_PREFIX + "TOP_WAIT_TXT");
ObjectDelete(0, DASH_PREFIX + "TOP_WAIT");

bool showMlFloat = ShowMLFeatureInfo && DashboardCompactVerdictOnly;
if(showMlFloat)
GOM_DrawMLInfoFloatingLabel();
else
ObjectDelete(0, "GOM_MLINFO_BR");
}

void GomKolaSidoEmbedded_RunOneShot()
{
   ProcessOrClear(PERIOD_M1, ShowM1Levels);
   ProcessOrClear(PERIOD_M5, ShowM5Levels);
   ProcessOrClear(PERIOD_M15, ShowM15Levels);
   ProcessOrClear(PERIOD_M30, ShowM30Levels);
   ProcessOrClear(PERIOD_H1, ShowH1Levels);
   ProcessOrClear(PERIOD_H4, ShowH4Levels);
   ProcessOrClear(PERIOD_D1, ShowD1Levels);
   ProcessOrClear(PERIOD_W1, ShowW1Levels);
   DrawAndPublishScriptEMAs();
   DrawAndPublishBollingerVWAP();
   GOM_CheckCaptureSpikeAndCleanup();
   DrawBottomDashboard();
   ChartRedraw(0);
}

// Appeler depuis l'EA (OnTick) : une passe par tick, throttles internes (pas de Sleep).
void GomKolaSidoEmbedded_ProcessFrame()
{
   static bool s_oneShotDone = false;
   if(!KeepScriptAttached)
   {
      if(s_oneShotDone)
         return;
      s_oneShotDone = true;
      GomKolaSidoEmbedded_RunOneShot();
      return;
   }

   datetime now = TimeCurrent();

   static datetime s_lastSmc = 0;
   if(GOM_ShouldRun(now, s_lastSmc, SMCProcessRefreshSeconds))
   {
      GOM_SMCProcess();
   }

   static datetime s_lastM1 = 0, s_lastM5 = 0, s_lastM15 = 0, s_lastM30 = 0, s_lastH1 = 0, s_lastH4 = 0, s_lastD1 = 0, s_lastW1 = 0;
   if(ShowM1Levels  && GOM_ShouldRun(now, s_lastM1,  TfRefreshSeconds_M1))  { ProcessOrClear(PERIOD_M1,  true); }
   if(ShowM5Levels  && GOM_ShouldRun(now, s_lastM5,  TfRefreshSeconds_M5))  { ProcessOrClear(PERIOD_M5,  true); }
   if(ShowM15Levels && GOM_ShouldRun(now, s_lastM15, TfRefreshSeconds_M15)) { ProcessOrClear(PERIOD_M15, true); }
   if(ShowM30Levels && GOM_ShouldRun(now, s_lastM30, TfRefreshSeconds_M30)) { ProcessOrClear(PERIOD_M30, true); }
   if(ShowH1Levels  && GOM_ShouldRun(now, s_lastH1,  TfRefreshSeconds_H1))  { ProcessOrClear(PERIOD_H1,  true); }
   if(ShowH4Levels  && GOM_ShouldRun(now, s_lastH4,  TfRefreshSeconds_H4))  { ProcessOrClear(PERIOD_H4,  true); }
   if(ShowD1Levels  && GOM_ShouldRun(now, s_lastD1,  TfRefreshSeconds_D1))  { ProcessOrClear(PERIOD_D1,  true); }
   if(ShowW1Levels  && GOM_ShouldRun(now, s_lastW1,  TfRefreshSeconds_W1))  { ProcessOrClear(PERIOD_W1,  true); }

   static datetime s_lastEma = 0;
   if(GOM_ShouldRun(now, s_lastEma, ScriptEmaRefreshSeconds))
   {
      DrawAndPublishScriptEMAs();
   }
   static datetime s_lastBbvwap = 0;
   if(GOM_ShouldRun(now, s_lastBbvwap, BollingerVwapRefreshSeconds))
   {
      DrawAndPublishBollingerVWAP();
   }

   static datetime s_lastDash = 0;
   if(GOM_ShouldRun(now, s_lastDash, DashboardRefreshSeconds))
   {
      GOM_CheckCaptureSpikeAndCleanup();
      DrawBottomDashboard();
      ChartRedraw(0);
   }
}

void GomKolaSidoEmbedded_OnDeinit()
{
   GOM_ReleaseAllCachedHandles();
}

#endif // GOM_KOLA_SIDO_CORE_MQH
