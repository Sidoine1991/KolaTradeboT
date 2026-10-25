<chart>
id=132232144715528963
symbol=Boom 1000 Index
period_type=0
period_size=1
digits=4
tick_size=0.000000
position_time=0
scale_fix=0
scale_fixed_min=10640.537000
scale_fixed_max=10686.537000
scale_fix11=0
scale_bar=0
scale_bar_val=1.000000
scale=8
mode=1
fore=0
grid=0
volume=0
scroll=1
shift=1
shift_size=19.948018
fixed_pos=0.000000
ohlc=0
one_click=0
one_click_btn=1
bidline=1
askline=0
lastline=0
days=0
descriptions=0
tradelines=1
window_left=0
window_top=0
window_right=0
window_bottom=0
window_type=1
floating=0
floating_left=0
floating_top=0
floating_right=0
floating_bottom=0
floating_type=1
floating_tbstate=
background_color=0
foreground_color=16777215
barup_color=13749760
bardown_color=42495
bullcandle_color=11186720
bearcandle_color=36095
chartline_color=65280
volumes_color=3329330
grid_color=10061943
bidline_color=10061943
askline_color=255
lastline_color=49152
stops_color=255
windows_total=3

<window>
height=100.000000
objects=0

<indicator>
name=Main
path=
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\SpikeDetector.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1

<graph>
name=Spike Detection
draw=1
style=0
width=2
color=65280
</graph>

<graph>
name=Spike Strength
draw=2
style=0
width=1
color=255
</graph>

<graph>
name=Reversal Signal
draw=3
style=0
width=3
arrow=233
color=65535
</graph>
<inputs>
InpPeriod=20
InpThreshold=0.5
InpSmoothing=3
InpShowArrows=true
InpBuyColor=65280
InpSellColor=255
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\Digi-Trend.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1

<graph>
name=PTL slow line up
draw=1
style=0
width=2
color=-1
</graph>

<graph>
name=PTL slow line down
draw=1
style=0
width=2
color=-1
</graph>

<graph>
name=PTL fast line
draw=10
style=4
width=1
color=-1,0
</graph>

<graph>
name=PTL trend start
draw=12
style=0
width=2
arrow=159
color=16711680,255
</graph>
<inputs>
inpFastLength=15
inpSlowLength=25
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\Digi-window.ex5
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1

<graph>
name=TRIX(14)
draw=1
style=0
width=1
color=255
</graph>

<graph>
name=Signal(8)
draw=1
style=2
width=1
color=16711680
</graph>

<graph>
name=Arrows Up
draw=3
style=0
width=1
arrow=233
shift_y=5
color=16711680
</graph>

<graph>
name=Arrows Down
draw=3
style=0
width=1
arrow=234
shift_y=5
color=255
</graph>
<inputs>
InpPeriodEMA=14
InpSignalPeriod=8
InpCodeUp=233
InpCodeDown=234
</inputs>
</indicator>

<indicator>
name=Expert Advisor
path=Experts\SpikeHunter_EA.ex5
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=1
fixed_height=-1

<inputs>
InpEnableTrading=true
InpTimeframe=0
InpMagicNumber=123456
InpTradeBoom=true
InpTradeCrash=true
InpMaxTrades=3
InpLotSize=0.01
InpStopLoss=50
InpTakeProfit=150
InpSpikeDetectionPeriod=20
InpSpikeThreshold=0.5
InpReversalDetection=10
InpReversalThreshold=0.3
InpUseTrailing=true
InpTrailingStart=30
InpTrailingStep=10
InpSendNotifications=true
InpWebhookURL=
</inputs>
</indicator>

<object>
type=102
name=Label1
hidden=1
descr=SpikeHunter EA - Trades actifs: 0 | Profit: 0.00
color=2237106
selectable=0
angle=0
pos_x=7
pos_y=80
fontsz=1
fontnm=Arial Bold
anchorpos=0
refpoint=0
</object>

<object>
type=102
name=Label2
hidden=1
descr=Spike Detection: 0.0%
color=65535
selectable=0
angle=0
pos_x=7
pos_y=94
fontsz=1
fontnm=Arial Bold
anchorpos=0
refpoint=0
</object>

<object>
type=102
name=Label3
hidden=1
descr=Spike Strength: 0.0
color=3329330
selectable=0
angle=0
pos_x=7
pos_y=108
fontsz=10
fontnm=Arial Bold
anchorpos=0
refpoint=0
</object>

<object>
type=102
name=Label4
hidden=1
descr=Reversal Signal: NONE
color=3329330
selectable=0
angle=0
pos_x=7
pos_y=122
fontsz=10
fontnm=Arial Bold
anchorpos=0
refpoint=0
</object>

</window>

<window>
height=50.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\SpikeDetector.ex5
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1

<graph>
name=Spike Detection
draw=1
style=0
width=2
color=65280
</graph>

<graph>
name=Spike Strength
draw=2
style=0
width=1
color=255
</graph>

<graph>
name=Reversal Signal
draw=3
style=0
width=3
arrow=233
color=65535
</graph>
<inputs>
InpPeriod=20
InpThreshold=0.5
InpSmoothing=3
InpShowArrows=true
InpBuyColor=65280
InpSellColor=255
</inputs>
</indicator>
</window>

<window>
height=50.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\Digi-window.ex5
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1

<graph>
name=TRIX(14)
draw=1
style=0
width=1
color=255
</graph>

<graph>
name=Signal(8)
draw=1
style=2
width=1
color=16711680
</graph>

<graph>
name=Arrows Up
draw=3
style=0
width=1
arrow=233
shift_y=5
color=16711680
</graph>

<graph>
name=Arrows Down
draw=3
style=0
width=1
arrow=234
shift_y=5
color=255
</graph>
<inputs>
InpPeriodEMA=14
InpSignalPeriod=8
InpCodeUp=233
InpCodeDown=234
</inputs>
</indicator>
</window>
</chart>
