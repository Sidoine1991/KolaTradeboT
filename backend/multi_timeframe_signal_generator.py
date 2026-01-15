"""
Générateur de signaux multi-timeframe avec validation de tendance globale
Génère des signaux en tenant compte de la tendance consolidée sur tous les timeframes
"""
import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Tuple
from datetime import datetime, timedelta
import time
import threading
import redis
import os
from dotenv import load_dotenv

from backend.mt5_connector import get_ohlc, get_current_price
from backend.technical_analysis import (
    add_technical_indicators,
    get_trend_analysis,
    get_support_resistance_zones,
    predict_next_step_pattern,
    predict_next_step_pattern_crash,
)
from backend.trend_summary import get_multi_timeframe_trend
from backend.whatsapp_utils import send_whatsapp_message
from backend.signal_generator import generate_signal

load_dotenv()

class MultiTimeframeSignalGenerator:
    """Générateur de signaux intelligent basé sur l'analyse multi-timeframe"""
    
    def __init__(self):
        self.redis_host = os.getenv('REDIS_HOST', 'localhost')
        self.redis_port = int(os.getenv('REDIS_PORT', 6379))
        self.redis_db = int(os.getenv('REDIS_DB', 0))
        self.r = redis.Redis(host=self.redis_host, port=self.redis_port, db=self.redis_db)
        
        # Configuration des seuils - STANDARDS PROFESSIONNELS OPTIMISÉS
        self.min_confidence = 0.58  # 58% minimum pour un signal valide (abaissé)
        self.trend_alignment_threshold = 0.5  # 50% minimum pour l'alignement de tendance
        self.signal_cooldown = 300  # 5 minutes entre les signaux pour le même symbole
        self.mode_turbo_bullish = False  # Activation du mode turbo bullish
        self.mode_turbo_bearish = False  # Activation du mode turbo bearish

    def enable_turbo_bullish(self):
        self.mode_turbo_bullish = True
    def disable_turbo_bullish(self):
        self.mode_turbo_bullish = False
    def is_turbo_bullish_enabled(self):
        return getattr(self, 'mode_turbo_bullish', False)
    def enable_turbo_bearish(self):
        self.mode_turbo_bearish = True
    def disable_turbo_bearish(self):
        self.mode_turbo_bearish = False
    def is_turbo_bearish_enabled(self):
        return getattr(self, 'mode_turbo_bearish', False)
    
    def analyze_trend_consensus(self, trend_data: Dict) -> Dict:
        """
        Analyse le consensus de tendance en privilégiant H1, M30, M15
        et utilise M5 pour la décision finale (analyse technique)
        """
        # Timeframes prioritaires avec pondération
        priority_timeframes = {
            60: 0.45,    # H1 - 45% du poids
            30: 0.30,    # M30 - 30% du poids
            15: 0.25     # M15 - 25% du poids
        }
        # Plus de M5 ni M1 dans la tendance
        # Timeframes secondaires (optionnel, ici on les ignore ou on peut garder D1/H4 si besoin)
        secondary_timeframes = {}
        
        bullish_weight = 0
        bearish_weight = 0
        neutral_weight = 0
        total_weight = 0.0    
        trend_details = {}
        priority_consensus = {'bullish': 0, 'bearish': 0, 'neutral': 0}
        
        # Analyser les timeframes prioritaires
        for timeframe, weight in priority_timeframes.items():
            if timeframe in trend_data:
                trend = trend_data[timeframe].get('trend', 'NEUTRAL')
                trend_details[timeframe] = trend
                
                if trend == 'BULLISH':
                    bullish_weight += weight
                    priority_consensus['bullish'] += 1
                elif trend == 'BEARISH':
                    bearish_weight += weight
                    priority_consensus['bearish'] += 1
                else:
                    neutral_weight += weight
                    priority_consensus['neutral'] += 1
                
                total_weight += weight
        
        # Analyser les timeframes secondaires
        for timeframe, weight in secondary_timeframes.items():
            if timeframe in trend_data:
                trend = trend_data[timeframe].get('trend', 'NEUTRAL')
                trend_details[timeframe] = trend
                
                if trend == 'BULLISH':
                    bullish_weight += weight
                elif trend == 'BEARISH':
                    bearish_weight += weight
                else:
                    neutral_weight += weight
                
                total_weight += weight
        
        # Normaliser les poids
        if total_weight > 0:
            bullish_ratio = bullish_weight / total_weight
            bearish_ratio = bearish_weight / total_weight
            neutral_ratio = neutral_weight / total_weight
        else:
            bullish_ratio = bearish_ratio = neutral_ratio = 0.0        
        # Décision basée sur les timeframes prioritaires (H1, M30, M15)
        priority_total = priority_consensus['bullish'] + priority_consensus['bearish'] + priority_consensus['neutral']
        if priority_total > 0:
            priority_bullish_ratio = priority_consensus['bullish'] / priority_total
            priority_bearish_ratio = priority_consensus['bearish'] / priority_total
        else:
            priority_bullish_ratio = priority_bearish_ratio = 0.0        
        # Détermination de la tendance dominante
        if priority_bullish_ratio >= 0.6: # Au moins 3/5 timeframes prioritaires
            dominant_trend = 'BULLISH'
            confidence = bullish_ratio
        elif priority_bearish_ratio >= 0.6: # Au moins 3/5 timeframes prioritaires
            dominant_trend = 'BEARISH'
            confidence = bearish_ratio
        else:
            dominant_trend = 'NEUTRAL'
            confidence = max(bullish_ratio, bearish_ratio)
        
        return {
            'dominant_trend': dominant_trend,
            'confidence': confidence,
            'bullish_ratio': bullish_ratio,
            'bearish_ratio': bearish_ratio,
            'neutral_ratio': neutral_ratio,
            'trend_details': trend_details,
            'priority_consensus': priority_consensus,
            'priority_bullish_ratio': priority_bullish_ratio,
            'priority_bearish_ratio': priority_bearish_ratio,
            'bullish_count': priority_consensus['bullish'],
            'bearish_count': priority_consensus['bearish'],
            'neutral_count': priority_consensus['neutral']
        }
    
    def generate_mtf_signal(self, symbol: str) -> Optional[Dict]:
        """
        Génère un signal basé sur l'analyse multi-timeframe
        """
        try:
            print(f"🔍 [MTF] Analyse multi-timeframe pour {symbol}")
            
            # Vérifier le cooldown
            cooldown_key = f"signal_cooldown:{symbol}"
            if self.r.exists(cooldown_key):
                remaining = self.r.ttl(cooldown_key)
                print(f"⏰ [MTF] Cooldown actif pour {symbol}, reste {remaining}s")
                return None
            
            # Récupérer les données 5m pour l'analyse technique
            df = get_ohlc(symbol, timeframe="5m", count=200)
            if df is None or df.empty:
                print(f"❌ [MTF] Pas de données pour {symbol}")
                return None
            
            # Ajouter les indicateurs techniques
            df = add_technical_indicators(df)

            # Récupérer M15 pour supports/résistances de contexte
            df_m15 = get_ohlc(symbol, timeframe="15m", count=300)
            if df_m15 is None or df_m15.empty:
                print("⚠️ [MTF] Données M15 indisponibles, confluence SR réduite")
            else:
                df_m15 = add_technical_indicators(df_m15)
            
            # Générer le signal technique
            technical_signal = generate_signal(df)
            
            # Récupérer la tendance multi-timeframe
            trend_data = get_multi_timeframe_trend(symbol)
            
            # Analyser le consensus de tendance
            trend_consensus = self.analyze_trend_consensus(trend_data)
            
            # === LOGIQUE TURBO BULLISH ===
            if self.mode_turbo_bullish:
                all_bullish = all(
                    tf.get('trend') == 'BULLISH' for tf in trend_data.values()
                )
                last = df.iloc[-1]
                ma5 = last['ma5'] if 'ma5' in last else None
                ma20 = last['ma20'] if 'ma20' in last else None
                ma50 = last['ma50'] if 'ma50' in last else None
                price = last['close']
                if all_bullish and ma5 and ma20 and ma50 and price > ma5 and price > ma20 and price > ma50:
                    # SL sous la MA50, TP +2% par défaut
                    sl = ma50 * 0.995
                    tp = price * 1.02
                    signal = {
                        'symbol': symbol,
                        'recommendation': 'BUY',
                        'confidence': 1.0,
                        'technical_confidence': 1.0,
                        'trend_confidence': 1.0,
                        'price': price,
                        'sl': sl,
                        'tp': tp,
                        'signal_direction': 'HAUSSE',
                        'dominant_trend': 'BULLISH',
                        'is_aligned': True,
                        'trend_consensus': trend_consensus,
                        'technical_reason': 'Turbo bullish: toutes les tendances BULLISH et prix > MA5/20/50',
                        'timestamp': datetime.now().isoformat(),
                        'validity_minutes': 30,
                        'turbo_bullish': True
                    }
                    print(f"🚀 [MTF] TURBO BULLISH ACTIVÉ : Signal BUY envoyé d'office pour {symbol}")
                    return signal
            
            # === LOGIQUE TURBO BEARISH ===
            if getattr(self, 'mode_turbo_bearish', False):
                all_bearish = all(
                    tf.get('trend') == 'BEARISH' for tf in trend_data.values()
                )
                last = df.iloc[-1]
                ma5 = last['ma5'] if 'ma5' in last else None
                ma20 = last['ma20'] if 'ma20' in last else None
                ma50 = last['ma50'] if 'ma50' in last else None
                price = last['close']
                if all_bearish and ma5 and ma20 and ma50 and price < ma5 and price < ma20 and price < ma50:
                    # SL au-dessus de la MA50, TP -2% par défaut
                    sl = ma50 * 1.005
                    tp = price * 0.98
                    signal = {
                        'symbol': symbol,
                        'recommendation': 'SELL',
                        'confidence': 1.0,
                        'technical_confidence': 1.0,
                        'trend_confidence': 1.0,
                        'price': price,
                        'sl': sl,
                        'tp': tp,
                        'signal_direction': 'BAISSE',
                        'dominant_trend': 'BEARISH',
                        'is_aligned': True,
                        'trend_consensus': trend_consensus,
                        'technical_reason': 'Turbo bearish: toutes les tendances BEARISH et prix < MA5/20/50',
                        'timestamp': datetime.now().isoformat(),
                        'validity_minutes': 30,
                        'turbo_bearish': True
                    }
                    print(f"🚨 [MTF] TURBO BEARISH ACTIVÉ : Signal SELL envoyé d'office pour {symbol}")
                    return signal
            
            # En cas de consolidation, pas de signal (trop risqué)
            if trend_consensus['dominant_trend'] == 'NEUTRAL':
                print("🔍 [MTF] Consolidation détectée - PAS DE SIGNAL (trop risqué)")
                return None
            
            # Prix actuel
            current_price_raw = get_current_price(symbol) or df['close'].iloc[-1]
            print(f"🔍 [MTF] Prix brut: {current_price_raw} (type: {type(current_price_raw)})")
            
            # Conversion sécurisée du prix
            if isinstance(current_price_raw, (int, float)) and not pd.isna(current_price_raw):
                current_price = float(current_price_raw)
            else:
                print(f"❌ [MTF] Prix invalide: {current_price_raw}")
                return None
            
            print(f"🔍 [MTF] Prix final: {current_price} (type: {type(current_price)})")

            # === Confluence Support/Résistance M15 + M5 ===
            nearest_support = None
            nearest_resistance = None
            def _nearest_sr(zones: List[Dict], price: float, typ: str) -> Optional[Dict]:
                if not zones:
                    return None
                candidates = [z for z in zones if z.get('type') == typ]
                if not candidates:
                    return None
                return min(candidates, key=lambda z: abs((z.get('price', price) - price) / price))

            # Extraire SR M5
            try:
                sr_m5 = get_support_resistance_zones(df)
            except Exception:
                sr_m5 = []
            # Extraire SR M15
            try:
                sr_m15 = get_support_resistance_zones(df_m15) if df_m15 is not None and not df_m15.empty else []
            except Exception:
                sr_m15 = []

            # Fusionner pour proximité
            sr_all = []
            if isinstance(sr_m15, list):
                sr_all.extend(sr_m15)
            elif isinstance(sr_m15, dict):
                sr_all.extend(sr_m15.get('supports', []))
                sr_all.extend(sr_m15.get('resistances', []))
            if isinstance(sr_m5, list):
                sr_all.extend(sr_m5)
            elif isinstance(sr_m5, dict):
                sr_all.extend(sr_m5.get('supports', []))
                sr_all.extend(sr_m5.get('resistances', []))

            # Normaliser structure {price, type}
            normalized = []
            for z in sr_all:
                if isinstance(z, dict) and 'price' in z and 'type' in z:
                    normalized.append({'price': float(z['price']), 'type': z['type']})

            nearest_support = _nearest_sr(normalized, current_price, 'support')
            nearest_resistance = _nearest_sr(normalized, current_price, 'resistance')

            dist_to_support = (
                abs(current_price - nearest_support['price']) / current_price if nearest_support else 1.0
            )
            dist_to_resistance = (
                abs(current_price - nearest_resistance['price']) / current_price if nearest_resistance else 1.0
            )
            
            # Validation de l'alignement signal/tendance
            signal_direction = technical_signal['signal']
            dominant_trend = trend_consensus['dominant_trend']
            
            # Logique de validation initiale
            is_aligned = False
            if signal_direction == 'HAUSSE' and dominant_trend == 'BULLISH':
                is_aligned = True
            elif signal_direction == 'BAISSE' and dominant_trend == 'BEARISH':
                is_aligned = True
            elif signal_direction == 'NEUTRE':
                print(f"❌ [MTF] Signal neutre détecté - PAS DE SIGNAL")
                return None  # Pas de signal neutre
            elif dominant_trend == 'NEUTRAL':
                print(f"⚠️ [MTF] Tendance neutre détectée - validation technique requise")
                # La validation technique sera faite plus tard dans le code
            
            # Calcul de la confiance combinée
            # Debug des valeurs
            print(f"🔍 [MTF] Signal technique: {technical_signal}")
            print(f"🔍 [MTF] Consensus tendance: {trend_consensus}")
            
            # La confiance technique est déjà en pourcentage (0-100)
            technical_confidence_raw = technical_signal.get('confidence', 0)
            
            # Debug pour identifier le type
            print(f"🔍 [MTF] Type de technical_confidence_raw: {type(technical_confidence_raw)}")
            print(f"🔍 [MTF] Valeur de technical_confidence_raw: {technical_confidence_raw}")
            
            # Gestion sécurisée de la conversion
            if isinstance(technical_confidence_raw, (int, float)):
                technical_confidence = float(technical_confidence_raw) / 100  # Convertir en 0-1
            elif isinstance(technical_confidence_raw, dict):
                # Si c'est un dict, essayer d'extraire une valeur numérique
                technical_confidence = 0.5  # Valeur par défaut
                print(f"⚠️ [MTF] technical_confidence_raw est un dict, utilisation de la valeur par défaut")
            else:
                technical_confidence = 0.5  # Valeur par défaut
                print(f"⚠️ [MTF] Type inattendu pour technical_confidence_raw, utilisation de la valeur par défaut")
            
            trend_confidence = float(trend_consensus.get('confidence', 0))
            
            print(f"🔍 [MTF] Confiance technique: {technical_confidence_raw} -> {technical_confidence}")
            print(f"🔍 [MTF] Confiance tendance: {trend_confidence}")
            
            # Pondération : 70% technique + 30% tendance (plus d'importance à l'analyse technique)
            combined_confidence = (technical_confidence * 0.7) + (trend_confidence * 0.3)
            
            # Validation avancée - Accepte UNIQUEMENT les signaux techniques très forts (80%+) même si opposés à la tendance
            if not is_aligned and technical_confidence > 0.8:
                is_aligned = True
                print(f"🔍 [MTF] Signal technique très fort ({technical_confidence:.2f}) accepté malgré tendance opposée")
            elif not is_aligned and dominant_trend == 'NEUTRAL' and technical_confidence >= 0.8:
                # En tendance neutre, accepter les signaux techniques très forts
                is_aligned = True
                print(f"✅ [MTF] Signal technique très fort ({technical_confidence:.2f}) accepté en tendance neutre")
            elif not is_aligned:
                print(f"❌ [MTF] Signal non aligné avec la tendance - REJETÉ")
                return None
            
            print(f"🔍 [MTF] Alignement signal/tendance: {is_aligned} (Signal: {signal_direction}, Tendance: {dominant_trend})")
            
            # Vérifier si le signal est suffisamment fort
            print(f"🔍 [MTF] Confiance combinée finale: {combined_confidence:.2f}")
            if combined_confidence < self.min_confidence:
                print(f"❌ [MTF] Confiance insuffisante: {combined_confidence:.2f} < {self.min_confidence}")
                # Ajout log détaillé
                import logging
                logging.info(f"[REJET] Raison: confiance combinée insuffisante | Valeur: {combined_confidence:.2f} | Seuil: {self.min_confidence} | Signal: {technical_signal} | Trend: {trend_consensus}")
                return None
            
            # Exiger proximité aux niveaux SR: BUY près d'un support, SELL près d'une résistance
            sr_tolerance = 0.002  # 0.2%
            if signal_direction == 'HAUSSE':
                if dist_to_support > sr_tolerance:
                    print(f"❌ [MTF] Pas assez près d'un support M15/M5 ({dist_to_support:.3%} > {sr_tolerance:.2%})")
                    return None
            elif signal_direction == 'BAISSE':
                if dist_to_resistance > sr_tolerance:
                    print(f"❌ [MTF] Pas assez près d'une résistance M15/M5 ({dist_to_resistance:.3%} > {sr_tolerance:.2%})")
                    return None

            # Vérifier imminence du spike (pattern step consolidé) sur M5
            is_spike_imminent = False
            try:
                if signal_direction == 'HAUSSE':
                    is_spike_imminent = bool(predict_next_step_pattern(df))
                elif signal_direction == 'BAISSE':
                    is_spike_imminent = bool(predict_next_step_pattern_crash(df))
            except Exception:
                is_spike_imminent = False

            if not is_spike_imminent:
                print("❌ [MTF] Spike non imminent selon l'analyse de consolidation - REJET")
                return None

            # Validation supplémentaire : confiance technique minimum
            if technical_confidence < 0.65:  # 65% minimum pour la confiance technique
                print(f"❌ [MTF] Confiance technique insuffisante: {technical_confidence:.2f} < 0.65")
                return None
            
            # Validation supplémentaire : confiance tendance minimum
            if trend_confidence < 0.3:  # 30% minimum pour la confiance de tendance (plus réaliste)
                print(f"❌ [MTF] Confiance tendance insuffisante: {trend_confidence:.2f} < 0.3")
                return None
            
            # Calcul des niveaux SL/TP
            print(f"🔍 [MTF] Calcul des niveaux SL/TP pour {symbol}")
            print(f"🔍 [MTF] Prix actuel: {current_price} (type: {type(current_price)})")
            
            # Récupération sécurisée de l'ATR
            if 'atr_14' in df.columns:
                atr_raw = df['atr_14'].iloc[-1]
                print(f"🔍 [MTF] ATR brut: {atr_raw} (type: {type(atr_raw)})")
                
                if isinstance(atr_raw, (int, float)) and not pd.isna(atr_raw):
                    atr_value = float(atr_raw)
                else:
                    atr_value = current_price * 0.01
                    print(f"⚠️ [MTF] ATR invalide, utilisation de {atr_value}")
            else:
                atr_value = current_price * 0.01
                print(f"⚠️ [MTF] ATR non disponible, utilisation de {atr_value}")
            
            print(f"🔍 [MTF] ATR final: {atr_value} (type: {type(atr_value)})")
            
            # Calcul sécurisé des niveaux
            try:
                # SL près du niveau SR opposé, TP serré pour capturer le spike immédiat
                atr_for_tp = float(atr_value)
                if signal_direction == 'HAUSSE':
                    # SL: sous le support le plus proche, sinon 2*ATR
                    sl_candidate = (nearest_support['price'] * 0.999) if nearest_support else (current_price - 2 * atr_for_tp)
                    sl = float(sl_candidate)
                    # TP: serré (1.0*ATR)
                    tp = float(current_price + 1.0 * atr_for_tp)
                    recommendation = 'BUY'
                elif signal_direction == 'BAISSE':
                    sl_candidate = (nearest_resistance['price'] * 1.001) if nearest_resistance else (current_price + 2 * atr_for_tp)
                    sl = float(sl_candidate)
                    tp = float(current_price - 1.0 * atr_for_tp)
                    recommendation = 'SELL'
                else:
                    sl = tp = None
                    recommendation = 'HOLD'
                
                print(f"🔍 [MTF] Niveaux calculés - SL: {sl}, TP: {tp}")
                
            except Exception as e:
                print(f"❌ [MTF] Erreur calcul niveaux: {e}")
                # Valeurs par défaut en cas d'erreur
                sl = current_price * 0.99 if signal_direction == 'HAUSSE' else current_price * 1.01
                tp = current_price * 1.02 if signal_direction == 'HAUSSE' else current_price * 0.98
                recommendation = 'HOLD'
            
            # Créer le signal final
            signal = {
                'symbol': symbol,
                'recommendation': recommendation,
                'confidence': combined_confidence,
                'technical_confidence': technical_confidence,
                'trend_confidence': trend_confidence,
                'price': current_price,
                'sl': sl,
                'tp': tp,
                'signal_direction': signal_direction,
                'dominant_trend': dominant_trend,
                'is_aligned': is_aligned,
                'trend_consensus': trend_consensus,
                'technical_reason': technical_signal['reason'],
                'timestamp': datetime.now().isoformat(),
                'validity_minutes': 15,
                'sr_near_support': nearest_support['price'] if nearest_support else None,
                'sr_near_resistance': nearest_resistance['price'] if nearest_resistance else None,
                'sr_distance_pct': {
                    'to_support': float(dist_to_support),
                    'to_resistance': float(dist_to_resistance)
                },
                'spike_imminent': True
            }
            
            print(f"✅ [MTF] Signal généré pour {symbol}: {recommendation} (confiance: {combined_confidence:.2f})")
            return signal
            
        except Exception as e:
            print(f"❌ [MTF] Erreur lors de la génération du signal pour {symbol}: {e}")
            return None
    
    def send_mtf_signal_whatsapp(self, signal: Dict) -> bool:
        """
        Envoie le signal multi-timeframe par WhatsApp
        """
        try:
            # Formatage du message
            msg = self.format_mtf_signal_message(signal)
            
            # Envoi WhatsApp
            success = send_whatsapp_message(msg)
            
            if success:
                # Définir le cooldown
                cooldown_key = f"signal_cooldown:{signal['symbol']}"
                self.r.setex(cooldown_key, self.signal_cooldown, "1")
                
                print(f"✅ [MTF] Signal WhatsApp envoyé pour {signal['symbol']}")
                return True
            else:
                print(f"❌ [MTF] Échec envoi WhatsApp pour {signal['symbol']}")
                return False
                
        except Exception as e:
            print(f"❌ [MTF] Erreur lors de l'envoi WhatsApp: {e}")
            return False
    
    def format_mtf_signal_message(self, signal: Dict) -> str:
        """
        Formate le message WhatsApp du signal multi-timeframe avec lien MT5
        """
        symbol = signal['symbol']
        recommendation = signal['recommendation']
        confidence = signal['confidence']
        price = signal['price']
        sl = signal['sl']
        tp = signal['tp']
        dominant_trend = signal['dominant_trend']
        trend_consensus = signal['trend_consensus']
        
        # Icônes selon la recommandation
        if recommendation == 'BUY':
            icon = "🟢"
            action = "ACHAT"
            mt5_action = "OP_BUY"
        elif recommendation == 'SELL':
            icon = "🔴"
            action = "VENTE"
            mt5_action = "OP_SELL"
        else:
            icon = "🟡"
            action = "ATTENTE"
            mt5_action = "OP_BUY"  # Par défaut
        
        # Générer le lien MT5
        mt5_link = self.generate_mt5_link(symbol, mt5_action, price, sl, tp)
        
        # Formatage du message
        msg = f"{icon} *SIGNAL MTF - {symbol}*\n\n"
        msg += f"🎯 *Action:* {action}\n"
        msg += f"💰 *Prix:* {price:.4f}\n"
        msg += f"📊 *Confiance:* {confidence:.1%}\n"
        
        if sl and tp:
            msg += f"🛑 *Stop Loss:* {sl:.4f}\n"
            msg += f"🎯 *Take Profit:* {tp:.4f}\n"
        
        msg += f"\n📈 *Tendance Globale:* {dominant_trend}\n"
        msg += f"📊 *Consensus:* {trend_consensus['bullish_count']}H/{trend_consensus['bearish_count']}B/{trend_consensus['neutral_count']}N\n"
        
        # Détails par timeframe
        msg += "\n*Détails par Timeframe:*\n"
        for tf, trend in trend_consensus['trend_details'].items():
            if trend == 'BULLISH':
                tf_icon = "📈"
            elif trend == 'BEARISH':
                tf_icon = "📉"
            else:
                tf_icon = "➡️"
            msg += f"{tf_icon} {tf}: {trend}\n"
        
        msg += f"\n⏰ *Validité:* {signal['validity_minutes']} minutes\n"
        msg += f"🔄 *Alignement:* {'✅' if signal['is_aligned'] else '❌'}\n\n"
        
        # Lien MT5 interactif
        msg += f"📱 *EXÉCUTER L'ORDRE:*\n"
        msg += f"🔗 {mt5_link}\n\n"
        msg += f"💡 *Instructions:*\n"
        msg += f"1️⃣ Cliquez sur le lien ci-dessus\n"
        msg += f"2️⃣ Confirmez l'ordre dans MT5\n"
        msg += f"3️⃣ L'ordre sera exécuté automatiquement"
        
        return msg
    
    def generate_mt5_link(self, symbol: str, action: str, price: float, sl: Optional[float] = None, tp: Optional[float] = None) -> str:
        """
        Génère un lien MT5 pour ouvrir l'ordre automatiquement
        """
        try:
            # Encoder les paramètres pour l'URL
            encoded_symbol = symbol.replace(" ", "%20")
            
            # Construire l'URL MT5
            mt5_url = f"mt5://order?symbol={encoded_symbol}&type={action}&price={price:.4f}"
            
            if sl:
                mt5_url += f"&sl={sl:.4f}"
            if tp:
                mt5_url += f"&tp={tp:.4f}"
            
            # Ajouter des paramètres supplémentaires
            mt5_url += "&volume=0.1&comment=Signal_MTF_Auto"
            
            return mt5_url
            
        except Exception as e:
            print(f"❌ [MTF] Erreur génération lien MT5: {e}")
            # Lien de fallback
            return f"mt5://order?symbol={symbol.replace(' ', '%20')}&type={action}"
    
    def generate_and_send_signal(self, symbol: str) -> Dict:
        """
        Génère et envoie un signal multi-timeframe
        """
        print(f"🚀 [MTF] Début génération/envoi signal pour {symbol}")
        
        # Générer le signal
        signal = self.generate_mtf_signal(symbol)
        
        if not signal:
            return {
                'status': 'no_signal',
                'detail': 'Aucun signal valide généré',
                'symbol': symbol
            }
        
        # Envoyer par WhatsApp
        whatsapp_sent = self.send_mtf_signal_whatsapp(signal)
        
        if whatsapp_sent:
            return {
                'status': 'sent',
                'signal': signal,
                'symbol': symbol,
                'whatsapp_sent': True
            }
        else:
            return {
                'status': 'whatsapp_error',
                'signal': signal,
                'symbol': symbol,
                'whatsapp_sent': False
            }

# Instance globale
mtf_signal_generator = MultiTimeframeSignalGenerator()

def generate_mtf_signal_for_symbol(symbol: str) -> Dict:
    """Fonction d'interface pour générer un signal multi-timeframe"""
    return mtf_signal_generator.generate_and_send_signal(symbol) 