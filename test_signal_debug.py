#!/usr/bin/env python3
"""
Script de test pour diagnostiquer les signaux rejetés
"""
import sys
import os
sys.path.insert(0, os.path.abspath('.'))

from backend.multi_timeframe_signal_generator import MultiTimeframeSignalGenerator
from backend.mt5_connector import get_ohlc, get_current_price
from backend.technical_analysis import add_technical_indicators
from backend.signal_generator import generate_signal
from backend.trend_summary import get_multi_timeframe_trend

def test_signal_quality(symbol):
    """Test détaillé de la qualité d'un signal"""
    print(f"🔍 [TEST] Analyse détaillée pour {symbol}")
    print("=" * 60)
    
    # Récupérer les données
    df = get_ohlc(symbol, timeframe="5m", count=200)
    if df is None or df.empty:
        print(f"❌ Pas de données pour {symbol}")
        return
    
    # Ajouter les indicateurs techniques
    df = add_technical_indicators(df)
    
    # Générer le signal technique
    technical_signal = generate_signal(df)
    print(f"📊 Signal technique: {technical_signal}")
    
    # Récupérer la tendance multi-timeframe
    trend_data = get_multi_timeframe_trend(symbol)
    print(f"📈 Tendance multi-timeframe: {trend_data}")
    
    # Créer l'instance du générateur
    generator = MultiTimeframeSignalGenerator()
    
    # Analyser le consensus de tendance
    trend_consensus = generator.analyze_trend_consensus(trend_data)
    print(f"🎯 Consensus tendance: {trend_consensus}")
    
    # Prix actuel
    current_price = get_current_price(symbol) or df['close'].iloc[-1]
    print(f"💰 Prix actuel: {current_price}")
    
    # Calculs de confiance
    technical_confidence_raw = technical_signal.get('confidence', 0)
    if isinstance(technical_confidence_raw, (int, float)):
        technical_confidence = float(technical_confidence_raw) / 100
    else:
        technical_confidence = 0.5
        
    trend_confidence = float(trend_consensus.get('confidence', 0))
    combined_confidence = (technical_confidence * 0.7) + (trend_confidence * 0.3)
    
    print(f"📊 Confiance technique: {technical_confidence:.2f} ({technical_confidence_raw}%)")
    print(f"📊 Confiance tendance: {trend_confidence:.2f}")
    print(f"📊 Confiance combinée: {combined_confidence:.2f}")
    
    # Validation de l'alignement
    signal_direction = technical_signal['signal']
    dominant_trend = trend_consensus['dominant_trend']
    
    is_aligned = False
    if signal_direction == 'HAUSSE' and dominant_trend == 'BULLISH':
        is_aligned = True
    elif signal_direction == 'BAISSE' and dominant_trend == 'BEARISH':
        is_aligned = True
    
    print(f"🔄 Alignement: Signal {signal_direction} vs Tendance {dominant_trend} = {is_aligned}")
    
    # Critères de validation
    print("\n🔍 CRITÈRES DE VALIDATION:")
    print("-" * 40)
    
    min_confidence_met = combined_confidence >= generator.min_confidence
    print(f"✅ Confiance combinée ≥ {generator.min_confidence}: {combined_confidence:.2f} >= {generator.min_confidence} = {min_confidence_met}")
    
    technical_confidence_met = technical_confidence >= 0.65
    print(f"✅ Confiance technique ≥ 0.65: {technical_confidence:.2f} >= 0.65 = {technical_confidence_met}")
    
    trend_confidence_met = trend_confidence >= 0.5
    print(f"✅ Confiance tendance ≥ 0.5: {trend_confidence:.2f} >= 0.5 = {trend_confidence_met}")
    
    print(f"✅ Alignement signal/tendance: {is_aligned}")
    
    not_neutral_signal = signal_direction != 'NEUTRE'
    print(f"✅ Signal non neutre: {signal_direction} != 'NEUTRE' = {not_neutral_signal}")
    
    not_neutral_trend = dominant_trend != 'NEUTRAL'
    print(f"✅ Tendance non neutre: {dominant_trend} != 'NEUTRAL' = {not_neutral_trend}")
    
    # Résultat global
    all_criteria = [
        min_confidence_met,
        technical_confidence_met,
        trend_confidence_met,
        is_aligned,
        not_neutral_signal,
        not_neutral_trend
    ]
    
    all_criteria_met = all(all_criteria)
    print(f"\n🎯 RÉSULTAT FINAL: {'✅ SIGNAL APPROUVÉ' if all_criteria_met else '❌ SIGNAL REJETÉ'}")
    
    if not all_criteria_met:
        failed_criteria = []
        if not min_confidence_met:
            failed_criteria.append("Confiance combinée insuffisante")
        if not technical_confidence_met:
            failed_criteria.append("Confiance technique insuffisante")
        if not trend_confidence_met:
            failed_criteria.append("Confiance tendance insuffisante")
        if not is_aligned:
            failed_criteria.append("Signal non aligné avec la tendance")
        if not not_neutral_signal:
            failed_criteria.append("Signal neutre")
        if not not_neutral_trend:
            failed_criteria.append("Tendance neutre")
        
        print(f"❌ Raisons du rejet: {', '.join(failed_criteria)}")

if __name__ == "__main__":
    symbols_to_test = ["EURUSD", "Crash 500 Index", "GBPUSD"]
    
    for symbol in symbols_to_test:
        try:
            test_signal_quality(symbol)
            print("\n" + "="*80 + "\n")
        except Exception as e:
            print(f"❌ Erreur pour {symbol}: {e}")
            print("\n" + "="*80 + "\n") 