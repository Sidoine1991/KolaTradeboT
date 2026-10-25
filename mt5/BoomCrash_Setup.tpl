<?xml version="1.0" encoding="UTF-8"?>
<template>
   <name>Boom/Crash Trading Setup</name>
   <description>Configuration optimisée pour le trading sur indices Boom et Crash avec F_INX_robot4</description>
   
   <chart>
      <background_color>0</background_color>
      <foreground_color>16777215</foreground_color>
      <grid_color>6908265</grid_color>
      <bar_up_color>17948</bar_up_color>
      <bar_down_color>255</bar_down_color>
      <bull_candle_color>17948</bull_candle_color>
      <bear_candle_color>255</bear_candle_color>
      <chart_mode>0</chart_mode>
      <scale_fix>0</scale_fix>
      <scale_fix_min>0</scale_fix_min>
      <scale_fix_max>0</scale_fix_max>
      <scale_percent>1</scale_percent>
      <show_volume>1</show_volume>
      <show_object_descriptions>1</show_object_descriptions>
      <show_trade_levels>1</show_trade_levels>
      <show_grid>1</show_grid>
      <show_period_separators>1</show_period_separators>
      <show_dates>1</show_dates>
      <show_prices>1</show_prices>
      <show_ohlc>1</show_ohlc>
      <show_ask_line>1</show_ask_line>
      <show_bid_line>1</show_bid_line>
      <show_last_line>1</show_last_line>
      <show_session_ticker>1</show_session_ticker>
      <show_indicator_menu>1</show_indicator_menu>
      <show_period_selector>1</show_period_selector>
      <show_line_chart>0</show_line_chart>
      <show_candle_prices>1</show_candle_prices>
   </chart>
   
   <indicators>
      <!-- ATR_RSI_Ichimoku_Combined Indicator -->
      <indicator>
         <name>ATR_RSI_Ichimoku_Combined</name>
         <parameters>
            <parameter name="RSI_Period" value="14"/>
            <parameter name="RSI_Price" value="4"/>
            <parameter name="RSI_Overbought" value="70.0"/>
            <parameter name="RSI_Oversold" value="30.0"/>
            <parameter name="ATR_Period" value="14"/>
            <parameter name="Tenkan" value="9"/>
            <parameter name="Kijun" value="26"/>
            <parameter name="SenkouB" value="52"/>
            <parameter name="ShowRSI" value="true"/>
            <parameter name="ShowATR" value="true"/>
            <parameter name="ShowIchimoku" value="true"/>
            <parameter name="ShowSignals" value="true"/>
            <parameter name="SignalMultiplier" value="2.0"/>
            <parameter name="EnableAlerts" value="true"/>
            <parameter name="EnableSoundAlerts" value="true"/>
            <parameter name="SoundFile" value="alert.wav"/>
            <parameter name="EnablePushNotifications" value="true"/>
            <parameter name="AlertCooldownSeconds" value="30"/>
            <parameter name="ShowBoomCrashZones" value="true"/>
         </parameters>
      </indicator>
      
      <!-- Volume Indicator -->
      <indicator>
         <name>Volumes</name>
         <parameters>
            <parameter name="ShowVolumes" value="true"/>
         </parameters>
      </indicator>
      
      <!-- Moving Averages on Main Chart -->
      <indicator>
         <name>Moving Average</name>
         <parameters>
            <parameter name="MA_Period" value="10"/>
            <parameter name="MA_Shift" value="0"/>
            <parameter name="MA_Method" value="1"/>
            <parameter name="MA_Applied" value="1"/>
            <parameter name="color" value="255"/>
            <parameter name="style" value="0"/>
            <parameter name="width" value="2"/>
         </parameters>
      </indicator>
      
      <indicator>
         <name>Moving Average</name>
         <parameters>
            <parameter name="MA_Period" value="50"/>
            <parameter name="MA_Shift" value="0"/>
            <parameter name="MA_Method" value="1"/>
            <parameter name="MA_Applied" value="1"/>
            <parameter name="color" value="65535"/>
            <parameter name="style" value="0"/>
            <parameter name="width" value="2"/>
         </parameters>
      </indicator>
   </indicators>
   
   <objects>
      <!-- Support and Resistance Lines -->
      <object>
         <name>Support_Line</name>
         <type>2</type>
         <color>32768</color>
         <style>2</style>
         <width>2</width>
      </object>
      
      <object>
         <name>Resistance_Line</name>
         <type>2</type>
         <color>16711680</color>
         <style>2</style>
         <width>2</width>
      </object>
      
      <!-- Trading Session Highlight -->
      <object>
         <name>Trading_Session</name>
         <type>21</type>
         <background_color>12632256</background_color>
         <border_color>8421504</border_color>
      </object>
   </objects>
   
   <windows>
      <window>
         <height>300</height>
         <fixed_height>1</fixed_height>
         <visible>1</visible>
      </window>
   </windows>
</template>
