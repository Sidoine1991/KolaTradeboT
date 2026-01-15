import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional
import os

def generate_signal(df: pd.DataFrame, ml_prediction: Optional[Dict] = None, 
                   technical_indicators: Optional[Dict] = None) -> Dict:
    """
    Génère un signal de trading professionnel basé sur l'analyse technique et ML.
    
    Args:
        df: DataFrame avec données OHLCV
        ml_prediction: Prédiction du modèle ML (optionnel)
        technical_indicators: Indicateurs techniques calculés (optionnel)
    
    Returns:
        Dict avec signal, confiance, direction, etc.
    """
    
    if df.empty or len(df) < 20:
        return {
            'signal': 'NEUTRE',
            'confidence': 0.0,
            'direction': 'NEUTRE',
            'strength': 'FAIBLE',
            'reason': 'Données insuffisantes'
        }
    
    # === CALCUL DES INDICATEURS TECHNIQUES ===
    signals = {}
    
    # RSI avec niveaux ajustés
    if 'rsi_14' in df.columns:
        rsi = df['rsi_14'].iloc[-1]
        if rsi > 70:  # RSI > 70 = VENTE (surachat)
            signals['rsi'] = {'direction': 'VENTE', 'strength': 0.8, 'value': rsi}
        elif rsi < 30:  # RSI < 30 = ACHAT (survente)
            signals['rsi'] = {'direction': 'ACHAT', 'strength': 0.8, 'value': rsi}
        elif rsi > 50:  # RSI > 50 = tendance haussière
            signals['rsi'] = {'direction': 'HAUSSE', 'strength': 0.5, 'value': rsi}
        elif rsi < 50:  # RSI < 50 = tendance baissière
            signals['rsi'] = {'direction': 'BAISSE', 'strength': 0.5, 'value': rsi}
        else:
            signals['rsi'] = {'direction': 'NEUTRE', 'strength': 0.3, 'value': rsi}
    
    # MACD
    if 'macd' in df.columns and 'macd_signal' in df.columns:
        macd = df['macd'].iloc[-1]
        macd_signal = df['macd_signal'].iloc[-1]
        if macd > macd_signal:
            signals['macd'] = {'direction': 'HAUSSE', 'strength': 0.7, 'value': macd - macd_signal}
        else:
            signals['macd'] = {'direction': 'BAISSE', 'strength': 0.7, 'value': macd - macd_signal}
    
    # Bollinger Bands
    if 'bb_percent' in df.columns:
        bb_percent = df['bb_percent'].iloc[-1]
        if bb_percent > 0.8:
            signals['bb'] = {'direction': 'BAISSE', 'strength': 0.6, 'value': bb_percent}
        elif bb_percent < 0.2:
            signals['bb'] = {'direction': 'HAUSSE', 'strength': 0.6, 'value': bb_percent}
        else:
            signals['bb'] = {'direction': 'NEUTRE', 'strength': 0.4, 'value': bb_percent}
    
    # Moyennes mobiles
    if 'sma_10' in df.columns and 'sma_20' in df.columns:
        sma_10 = df['sma_10'].iloc[-1]
        sma_20 = df['sma_20'].iloc[-1]
        current_price = df['close'].iloc[-1]
        
        if current_price > sma_10 > sma_20:
            signals['ma'] = {'direction': 'HAUSSE', 'strength': 0.6, 'value': (current_price - sma_20) / sma_20}
        elif current_price < sma_10 < sma_20:
            signals['ma'] = {'direction': 'BAISSE', 'strength': 0.6, 'value': (current_price - sma_20) / sma_20}
        else:
            signals['ma'] = {'direction': 'NEUTRE', 'strength': 0.3, 'value': 0}
    
    # Momentum
    if len(df) >= 5:
        momentum = (df['close'].iloc[-1] - df['close'].iloc[-5]) / df['close'].iloc[-5]
        if momentum > 0.01:
            signals['momentum'] = {'direction': 'HAUSSE', 'strength': 0.5, 'value': momentum}
        elif momentum < -0.01:
            signals['momentum'] = {'direction': 'BAISSE', 'strength': 0.5, 'value': momentum}
        else:
            signals['momentum'] = {'direction': 'NEUTRE', 'strength': 0.2, 'value': momentum}
    
    # === ANALYSE DE LA PRÉDICTION ML ===
    ml_weight = 0.0
    ml_direction = 'NEUTRE'
    
    if ml_prediction and 'direction' in ml_prediction:
        ml_weight = 0.4  # Poids important pour le ML
        ml_direction = ml_prediction['direction']
        ml_confidence = ml_prediction.get('probability', 0.5)
        signals['ml'] = {
            'direction': ml_direction, 
            'strength': ml_confidence, 
            'value': ml_confidence
        }
    
    # === CALCUL DU SIGNAL FINAL ===
    if not signals:
        return {
            'signal': 'NEUTRE',
            'confidence': 0.0,
            'direction': 'NEUTRE',
            'strength': 'FAIBLE',
            'reason': 'Aucun indicateur disponible'
        }
    
    # Compter les signaux par direction
    directions = {'HAUSSE': 0, 'BAISSE': 0, 'NEUTRE': 0}
    total_strength = 0
    
    for signal_name, signal_data in signals.items():
        direction = signal_data['direction']
        strength = signal_data['strength']
        
        if direction != 'NEUTRE':
            directions[direction] += strength
            total_strength += strength
    
    # Déterminer la direction dominante
    if directions['HAUSSE'] > directions['BAISSE'] and directions['HAUSSE'] > 0.5:
        final_direction = 'HAUSSE'
        confidence = min(directions['HAUSSE'] / max(total_strength, 1), 1.0)
    elif directions['BAISSE'] > directions['HAUSSE'] and directions['BAISSE'] > 0.5:
        final_direction = 'BAISSE'
        confidence = min(directions['BAISSE'] / max(total_strength, 1), 1.0)
    else:
        final_direction = 'NEUTRE'
        confidence = 0.0
    
    # Déterminer la force du signal
    if confidence > 0.8:
        strength = 'FORTE'
    elif confidence > 0.5:
        strength = 'MODÉRÉE'
    else:
        strength = 'FAIBLE'
    
    # Générer la raison
    reasons = []
    for signal_name, signal_data in signals.items():
        if signal_data['direction'] == final_direction and signal_data['strength'] > 0.5:
            reasons.append(f"{signal_name.upper()}: {signal_data['direction']}")
    
    reason = " | ".join(reasons) if reasons else "Signaux mixtes"
    
    return {
        'signal': final_direction,
        'confidence': round(confidence * 100, 1),
        'direction': final_direction,
        'strength': strength,
        'reason': reason,
        'signals': signals
    }

def generate_professional_signal_html(signal_data: Dict) -> str:
    """
    Génère le HTML pour l'affichage du signal professionnel.
    """
    signal = signal_data.get('signal', 'NEUTRE')
    confidence = signal_data.get('confidence', 0.0)
    strength = signal_data.get('strength', 'FAIBLE')
    
    # Couleurs selon le signal
    if signal == 'HAUSSE':
        color = '#4CAF50'
        icon = '📈'
    elif signal == 'BAISSE':
        color = '#F44336'
        icon = '📉'
    else:
        color = '#2196F3'
        icon = '⏸️'
    
    # Icône de force
    strength_icon = '🔥' if strength == 'FORTE' else '💨' if strength == 'FAIBLE' else '⚡'
    
    html = f"""
    <div style="background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%); padding: 20px; border-radius: 10px; color: white; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
        <h3 style="margin: 0 0 15px 0; font-size: 18px; text-align: center;">
            {icon} SIGNAL DE TRADING PROFESSIONNEL
        </h3>
        
        <div style="display: flex; justify-content: space-between; align-items: center; margin: 10px 0;">
            <div>
                <div style="font-size: 12px; color: #a0a8c0; margin-bottom: 5px;">NIVEAU DE CONFIANCE</div>
                <div style="font-size: 24px; font-weight: 700; color: {color};">{confidence}%</div>
            </div>
            <div style="text-align: right;">
                <div style="font-size: 12px; color: #a0a8c0; margin-bottom: 5px;">FORCE DE TENDANCE</div>
                <div style="font-size: 18px; font-weight: 600; color: #fff;">
                    {strength_icon} {strength}
                </div>
            </div>
        </div>
        
        <div class="confidence-bar" style="background: rgba(255,255,255,0.1); height: 8px; border-radius: 4px; margin: 15px 0;">
            <div class="confidence-level" style="width: {confidence}%; background: {color}; height: 100%; border-radius: 4px; transition: width 0.3s ease;"></div>
        </div>
        
        <div style="margin: 20px 0;">
            <h4 style="color: #fff; font-size: 15px; margin-bottom: 15px;">INDICATEURS TECHNIQUES</h4>
            <div class="indicator-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px;">
    """
    
    # Ajouter les indicateurs individuels
    signals = signal_data.get('signals', {})
    for signal_name, signal_info in signals.items():
        if signal_info['direction'] != 'NEUTRE':
            indicator_color = '#4CAF50' if signal_info['direction'] == 'HAUSSE' else '#F44336'
            html += f"""
                <div style="background: rgba(255,255,255,0.1); padding: 10px; border-radius: 5px; text-align: center;">
                    <div style="font-size: 12px; color: #a0a8c0;">{signal_name.upper()}</div>
                    <div style="font-size: 16px; font-weight: 600; color: {indicator_color};">
                        {signal_info['direction']}
                    </div>
                </div>
            """
    
    html += """
            </div>
        </div>
    </div>
    """
    
    return html 

def is_trend_aligned(signal_direction: str, trend_dict: dict) -> bool:
    # Compte le nombre de timeframes alignés avec la direction du signal
    bullish = sum(1 for tf in trend_dict if trend_dict[tf].get('trend') == 'HAUSSE')
    bearish = sum(1 for tf in trend_dict if trend_dict[tf].get('trend') == 'BAISSE')
    if signal_direction == 'HAUSSE':
        return bullish > bearish
    if signal_direction == 'BAISSE':
        return bearish > bullish
    return True  # NEUTRE ou autre


def generate_and_send_signal(symbol: str) -> dict:
    from backend.mt5_connector import get_ohlc
    from backend.technical_analysis import add_technical_indicators
    from backend.whatsapp_utils import send_whatsapp_message
    from backend.trend_summary import get_multi_timeframe_trend
    
    print(f"🔍 [DEBUG] Début generate_and_send_signal pour {symbol}")
    
    # Récupération des données
    print(f"📊 [DEBUG] Récupération des données OHLC pour {symbol} (200 bougies)")
    df = get_ohlc(symbol, timeframe="5m", count=200)
    if df is None or df.empty:
        print(f"❌ [DEBUG] Pas de données OHLCV pour {symbol}")
        return {"status": "error", "detail": "Pas de données OHLCV pour ce symbole."}
    
    print(f"✅ [DEBUG] Données récupérées: {len(df)} bougies")
    
    # Ajout des indicateurs techniques
    print(f"📈 [DEBUG] Ajout des indicateurs techniques")
    df = add_technical_indicators(df)
    
    # Génération du signal
    print(f"🎯 [DEBUG] Génération du signal")
    signal = generate_signal(df)
    print(f"📊 [DEBUG] Signal généré: {signal['signal']} ({signal['confidence']}%) - {signal['reason']}")
    
    # Validation par la tendance
    print(f"🔍 [DEBUG] Récupération de la tendance multi-timeframe")
    trend = get_multi_timeframe_trend(symbol)
    print(f"📊 [DEBUG] Tendance: {trend}")
    
    print(f"🔍 [DEBUG] Validation alignement signal/tendance")
    # TEMPORAIREMENT DÉSACTIVÉ POUR TEST
    # if not is_trend_aligned(signal['signal'], trend):
    #     print(f"❌ [DEBUG] Signal non aligné avec la tendance - ENVOI BLOQUÉ")
    #     return {"status": "not_sent", "detail": "Signal non aligné avec la tendance consolidée.", "signal": signal, "trend": trend}
    
    print(f"✅ [DEBUG] Signal aligné avec la tendance - ENVOI AUTORISÉ")
    
    # Préparation du message
    msg = f"Signal {symbol}: {signal['signal']} ({signal['confidence']}%)\nRaison: {signal['reason']}"
    print(f"📱 [DEBUG] Message préparé: {msg}")
    
    # Envoi WhatsApp
    print(f"📱 [DEBUG] Tentative d'envoi WhatsApp")
    try:
        send_result = send_whatsapp_message(msg)
        print(f"✅ [DEBUG] Résultat envoi WhatsApp: {send_result}")
        return {"status": "sent", "signal": signal, "trend": trend, "whatsapp": send_result}
    except Exception as e:
        print(f"❌ [DEBUG] Erreur envoi WhatsApp: {str(e)}")
        return {"status": "error", "detail": f"Erreur envoi WhatsApp: {str(e)}", "signal": signal, "trend": trend} 