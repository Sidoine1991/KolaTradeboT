<chart>
id=134057058716473277
symbol=Crash 1000 Index
description=Template optimisé pour AngelOfSpike - Kola Gold Angel
period_type=0
period_size=5
digits=4
tick_size=0.000000
scale=32
mode=1
fore=0
grid=1
volume=1
scroll=1
shift=1
ohlc=1
one_click=0
bidline=1
askline=0
lastline=0
days=1
descriptions=0
tradelines=1
tradehistory=1
background_color=0
foreground_color=16777215
barup_color=65280
bardown_color=17919
bullcandle_color=64636
bearcandle_color=17919
chartline_color=65280
volumes_color=3329330
grid_color=10061943
bidline_color=10061943
askline_color=255
lastline_color=49152
stops_color=255

<expert>
name=AngelOfSpike
path=Experts\AngelOfSpike.ex5
expertmode=5
<inputs>
=
; === CONFIGURATION GÉNÉRALE ===
InpEnableTrading=true
InpMagicNumber=880011
InpAllowedSymbols=Boom 300 Index,Crash 300 Index,Boom 500 Index,Crash 500 Index,Boom 1000 Index,Crash 1000 Index
InpAutoDetectAllBoomCrash=true
InpAutoDetectOtherIndices=true
=
; === GESTION DU CAPITAL ===
InpLotSize=0.01
InpMaxLotSize=0.5
InpMaxTotalLoss=3.5
InpSpikeCapturePoints=10
InpOtherIndicesGainUSD=2.0
InpRiskPerTrade=1.0
InpUseDynamicLots=true
InpMaxRiskPerTrade=50.0
InpMinRiskReward=2.0
InpUseEquityProtection=true
InpEquityProtectionPct=5.0
=
; === ORDRES LIMITE ===
InpUseLimitOrders=true
InpMaxLimitOrders=2
InpLimitOffsetPoints=20
InpLimitExpiryMinutes=5
=
; === HORAIRES DE TRADING ===
Inp24HourTrading=true
InpSkipWeekends=false
InpSessionStartHour=0
InpSessionEndHour=23
InpUseTimeFilter=false
InpUseVolatilityFilter=true
InpMaxVolatility=200.0
=
; === PRÉDICTION ET SIGNAUX ===
InpEnablePrediction=true
InpShowBlinkingArrows=true
InpPredictionPeriods=10
InpSpikeProbabilityThreshold=75.0
InpStepPatternThreshold=40.0
InpBlinkIntervalMs=500
InpExecuteOnArrowSignal=true
InpShowStepPatterns=true
=
; === DÉBOGAGE ET NOTIFICATIONS ===
InpDebug=true
InpSendNotifications=true
InpNotifyTag=KolaGoldAngel
</inputs>
</expert>

; === INDICATEURS ===
<indicator>
name=Moving Average
period=20
method=0
apply=0
color=16776960
width=2
style=0
</indicator>

<indicator>
name=Moving Average
period=50
method=0
apply=0
color=65535
width=2
style=0
</indicator>

<indicator>
name=ATR
period=14
color=255
width=1
style=0
</indicator>

; === NIVEAUX CLÉS ===
<object>
type=21
name=DailyPivot
description=Pivot Quotidien
style=2
width=1
color=16776960
back=0
selectable=0
hidden=1
time1=0
price1=0.0000
</object>

<object>
type=21
name=Support1
description=Support 1
style=2
width=1
color=65280
back=0
selectable=0
hidden=1
time1=0
price1=0.0000
</object>

<object>
type=21
name=Resistance1
description=Résistance 1
style=2
width=1
color=255
back=0
selectable=0
hidden=1
time1=0
price1=0.0000
</object>

; === ZONES DE PRIX IMPORTANTES ===
<object>
type=23
name=KeyZone1
description=Zone Clé 1
style=2
width=1
color=16711935
back=0
selectable=0
hidden=1
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

; === TEXTE INFORMATIF ===
<object>
type=1
name=InfoPanel
corner=0
x=10
y=20
color=0
style=0
size=9
font=Arial
back=0
selectable=0
hidden=1
zorder=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

; === LIGNES DE TENDANCE ===
<object>
type=22
name=TrendLine1
description=Ligne de tendance 1
style=0
width=1
color=65280
back=0
selectable=1
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

<object>
type=22
name=TrendLine2
description=Ligne de tendance 2
style=0
width=1
color=255
back=0
selectable=1
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

; === MÉDIAS MOBILES ===
<object>
type=26
name=EMA_Fast
description=EMA Rapide
style=0
width=1
color=16711935
back=0
selectable=0
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

<object>
type=26
name=EMA_Slow
description=EMA Lente
style=0
width=1
color=65535
back=0
selectable=0
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

; === ZONES D'ACCUMULATION/DISTRIBUTION ===
<object>
type=24
name=AccumulationZone
description=Zone d'Accumulation
style=0
width=1
color=32768
back=1
selectable=1
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

<object>
type=24
name=DistributionZone
description=Zone de Distribution
style=0
width=1
color=255
back=1
selectable=1
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

; === LIGNES HORIZONTALES POUR LES ORDRES ===
<object>
type=21
name=Buy_Order
description=Ordre d'Achat
style=0
width=1
color=65280
back=0
selectable=1
hidden=1
time1=0
price1=0.0000
</object>

<object>
type=21
name=Sell_Order
description=Ordre de Vente
style=0
width=1
color=255
back=0
selectable=1
hidden=1
time1=0
price1=0.0000
</object>

; === ZONES DE STOP LOSS ET TAKE PROFIT ===
<object>
type=24
name=SL_Zone
description=Zone de Stop Loss
style=2
width=1
color=255
back=1
selectable=1
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

<object>
type=24
name=TP_Zone
description=Zone de Take Profit
style=2
width=1
color=32768
back=1
selectable=1
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

; === ZONES DE VOLATILITÉ ===
<object>
type=24
name=Volatility_High
description=Haute Volatilité
style=2
width=1
color=255
back=1
selectable=1
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

<object>
type=24
name=Volatility_Low
description=Basse Volatilité
style=2
width=1
color=32768
back=1
selectable=1
ray=0
time1=0
price1=0.0000
time2=0
price2=0.0000
</object>

; === LÉGENDE DU TEMPLATE ===
<object>
type=1
name=Template_Legend
corner=0
x=10
y=40
color=16777215
style=0
size=9
font=Arial Bold
back=0
selectable=0
hidden=1
zorder=0
time1=0
price1=0.0000
time2=0
price2=0.0000
text=--- KOLA GOLD ANGEL TEMPLATE ---
</object>
</chart>
