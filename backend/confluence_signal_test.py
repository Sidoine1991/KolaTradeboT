import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from backend.mt5_connector import get_ohlc
from backend.trend_summary import get_multi_timeframe_trend
from backend.advanced_technical_indicators import add_advanced_technical_indicators, generate_professional_signals
from datetime import datetime, timedelta


def generate_confluence_signal(symbol):
    # 1. Tendance M5
    trend_data = get_multi_timeframe_trend(symbol)
    trend_M5 = trend_data.get('M5', {}).get('trend', 'NEUTRAL')
    if trend_M5 not in ['BULLISH', 'BEARISH']:
        print(f"[INFO] Tendance M5 non exploitable pour {symbol}: {trend_M5}")
        return None

    # 2. Indicateurs avancés
    df = get_ohlc(symbol, timeframe='5m', count=500)
    if df is None or df.empty:
        print(f"[INFO] Pas de données OHLC pour {symbol}")
        return None
    df = add_advanced_technical_indicators(df)
    pro_signal = generate_professional_signals(df)
    print(f"[DEBUG] Détail des signaux avancés : {pro_signal}")
    if pro_signal['signal'] == 'INSUFFICIENT_DATA' or pro_signal['signal'] == 'NEUTRAL':
        print(f"[INFO] Signal avancé non exploitable pour {symbol}: {pro_signal['signal']}")
        return None

    # 3. Alignement souple : au moins 2 indicateurs alignés
    # On suppose que pro_signal['signals_detail'] contient les signaux individuels
    aligned = 0
    if 'signals_detail' in pro_signal and isinstance(pro_signal['signals_detail'], dict):
        for k, v in pro_signal['signals_detail'].items():
            if (trend_M5 == 'BULLISH' and v == 'BUY') or (trend_M5 == 'BEARISH' and v == 'SELL'):
                aligned += 1
    else:
        print(f"[DEBUG] Pas de signals_detail exploitable : {pro_signal.get('signals_detail')}")
        aligned = 0
    if aligned < 2:
        print(f"[INFO] Pas assez d'indicateurs alignés ({aligned}) pour {symbol}")
        return None

    # 4. Confiance plus souple
    if pro_signal.get('confidence', 0) < 0.5:
        print(f"[INFO] Confiance trop faible: {pro_signal.get('confidence', 0):.2f}")
        return None

    # 5. Génération du signal final
    signal = {
        'symbol': symbol,
        'direction': trend_M5,
        'signal': pro_signal['signal'],
        'confidence': pro_signal.get('confidence', 0),
        'valid_until': (datetime.now() + timedelta(minutes=3)).isoformat(),
        'reason': f'Confluence M5 ({trend_M5}) + indicateurs avancés ({pro_signal})'
    }
    print(f"[SIGNAL] {signal}")
    return signal

if __name__ == "__main__":
    if len(sys.argv) < 2:
        symbol = "Crash 1000 Index"
        print("[INFO] Aucun symbole passé en argument, test sur 'Crash 1000 Index'")
    else:
        symbol = sys.argv[1]
    generate_confluence_signal(symbol) 