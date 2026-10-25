import sys
import os
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import streamlit as st
from streamlit_autorefresh import st_autorefresh
import base64
import warnings
from dotenv import load_dotenv
load_dotenv()
import joblib
import time
import threading

# --- Initialisation des variables de sélection (doit être AVANT tout usage) ---
selected_symbol = st.session_state.get('current_symbol') or "EURUSD"
symbol = selected_symbol
actual_selected_timeframe = st.session_state.get('current_timeframe') or "1m"
spike_threshold = st.session_state.get('spike_threshold', 0.5)
candle_count = st.session_state.get('candle_count', 200)

# --- Configuration et Imports (Réel vs Factice) ---
st.set_page_config(page_title="TradBOT Avancé", page_icon="🤖", layout="wide", initial_sidebar_state="expanded")
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

try:
    # Essayer d'importer le VRAI backend
    from backend.mt5_connector import (
        connect, shutdown, get_ohlc, get_all_symbols, get_all_symbols_simple,
        get_symbols_by_category, get_symbol_info, test_connection, TIMEFRAME_MAPPING,
        get_open_positions, get_trade_history, is_connected,
        initialize_ml_supertrend, get_ml_supertrend_signals
    )
    from backend.spike_detector import detect_spikes, analyze_spike_pattern, predict_next_spike, predict_spike_ml, batch_predict_spike_ml
    from backend.technical_analysis import add_technical_indicators, detect_step_pattern, predict_next_step_pattern, detect_step_pattern_crash, predict_next_step_pattern_crash
    from backend.fundamental_analysis import get_fundamental_analysis, get_market_overview
    from backend.ai_analysis import analyze_with_gemini
    from backend.signal_generator import generate_signal
    from backend.chart_utils import add_technical_indicators_to_chart, create_spike_analysis_chart
    from backend.advanced_analysis import predict_trend_ml
except ImportError:
    get_all_symbols_simple = None
    # Fonctions dummy pour les cas d'import échoué
    def detect_spikes(df, threshold, method):
        return pd.DataFrame()
    
    def batch_predict_spike_ml(df):
        return np.random.random(len(df)) * 0.5
    
    def add_technical_indicators(df, indicators):
        return df
    
    def get_fundamental_analysis(symbol):
        return {"message": "Analyse fondamentale non disponible"}
    
    def create_candlestick_chart(df, title):
        import plotly.graph_objects as go
        from plotly.subplots import make_subplots
        if df is None or df.empty:
            return go.Figure()
        fig = make_subplots(
            rows=2, cols=1, shared_xaxes=True,
            vertical_spacing=0.03, row_heights=[0.7, 0.3]
        )
        fig.add_trace(
            go.Candlestick(
                x=df['timestamp'],
                open=df['open'],
                high=df['high'],
                low=df['low'],
                close=df['close'],
                name='OHLC',
                increasing_line_color='#26A69A',
                decreasing_line_color='#EF5350',
                showlegend=True
            ),
            row=1, col=1
        )
        vol_col = 'tick_volume' if 'tick_volume' in df.columns else 'volume' if 'volume' in df.columns else None
        if vol_col:
            fig.add_trace(
                go.Bar(
                    x=df['timestamp'],
                    y=df[vol_col],
                    name='Volume',
                    marker_color='#B0BEC5',
                    opacity=0.5
                ),
                row=2, col=1
            )
        fig.update_layout(
            title=title,
            xaxis_title='Date',
            yaxis_title='Prix',
            template='plotly_white',
            height=700,
            showlegend=True,
            xaxis_rangeslider_visible=False
        )
        fig.update_xaxes(rangeslider_visible=False, row=1, col=1)
        return fig
    
    def create_spike_analysis_chart(df, spikes_df, title):
        import plotly.graph_objects as go
        fig = go.Figure()
        fig.add_trace(go.Scatter(x=df['timestamp'], y=df['close'], mode='lines', name='Prix'))
        fig.update_layout(title=title)
        return fig
if 'spikes' not in locals():
    spikes = pd.DataFrame()
# --- UTILS TP/SL ADAPTATIF ---
def compute_tp_sl(symbol, entry, signal_type, symbol_info=None):
    try:
        if symbol_info is None:
            from backend.mt5_connector import get_symbol_info
            symbol_info = get_symbol_info(symbol)
    except Exception:
        symbol_info = None
    
    # Récupérer le prix actuel pour validation
    current_price = None
    if symbol_info:
        current_price = symbol_info.get('bid', symbol_info.get('ask'))
    
    # Fallback générique
    if symbol_info is None:
        if "BOOM" in symbol.upper() or "CRASH" in symbol.upper():
            tp = entry + 300 if signal_type == "BUY" else entry - 300
            sl = entry - 100 if signal_type == "BUY" else entry + 100
        else:
            tp = entry * 1.005 if signal_type == "BUY" else entry * 0.995
            sl = entry * 0.998 if signal_type == "BUY" else entry * 1.002
    else:
        # Pour Boom/Crash, points
        if "BOOM" in symbol.upper() or "CRASH" in symbol.upper():
            point = symbol_info.get('point', 1)
            tp = entry + 300 * point if signal_type == "BUY" else entry - 300 * point
            sl = entry - 100 * point if signal_type == "BUY" else entry + 100 * point
        # Pour Forex, pips
        elif symbol_info and symbol_info.get('currency_profit') in ["USD", "EUR", "GBP"] and symbol_info.get('digits', 5) >= 3:
            pip = 0.0001
            tp = entry + 20 * pip if signal_type == "BUY" else entry - 20 * pip
            sl = entry - 10 * pip if signal_type == "BUY" else entry + 10 * pip
        # Pour Crypto/Indices, %
        else:
            tp = entry * 1.01 if signal_type == "BUY" else entry * 0.99
            sl = entry * 0.995 if signal_type == "BUY" else entry * 1.005
    
    # VALIDATION DES PRIX PRÉDITS
    if current_price is not None and current_price > 0:
        # Limites de validation selon le type d'instrument
        if "BOOM" in symbol.upper() or "CRASH" in symbol.upper():
            # Pour les indices synthétiques, limite à ±5% du prix actuel
            max_deviation = current_price * 0.05
            if abs(tp - current_price) > max_deviation:
                tp = current_price + (max_deviation if signal_type == "BUY" else -max_deviation)
            if abs(sl - current_price) > max_deviation:
                sl = current_price - (max_deviation if signal_type == "BUY" else -max_deviation)
        elif symbol_info and symbol_info.get('currency_profit') in ["USD", "EUR", "GBP"]:
            # Pour le Forex, limite à ±2% du prix actuel
            max_deviation = current_price * 0.02
            if abs(tp - current_price) > max_deviation:
                tp = current_price + (max_deviation if signal_type == "BUY" else -max_deviation)
            if abs(sl - current_price) > max_deviation:
                sl = current_price - (max_deviation if signal_type == "BUY" else -max_deviation)
        else:
            # Pour les autres instruments, limite à ±3% du prix actuel
            max_deviation = current_price * 0.03
            if abs(tp - current_price) > max_deviation:
                tp = current_price + (max_deviation if signal_type == "BUY" else -max_deviation)
            if abs(sl - current_price) > max_deviation:
                sl = current_price - (max_deviation if signal_type == "BUY" else -max_deviation)
        
        # Vérification que TP et SL sont dans le bon ordre
        if signal_type == "BUY":
            if tp <= entry:
                tp = entry * 1.005  # TP minimum 0.5% au-dessus de l'entrée
            if sl >= entry:
                sl = entry * 0.995  # SL maximum 0.5% en-dessous de l'entrée
        else:  # SELL
            if tp >= entry:
                tp = entry * 0.995  # TP maximum 0.5% en-dessous de l'entrée
            if sl <= entry:
                sl = entry * 1.005  # SL minimum 0.5% au-dessus de l'entrée
    
    return tp, sl
# Ignorer les avertissements pour une sortie plus propre
warnings.filterwarnings("ignore")

# Ajout pour bip natif Windows
try:
    import winsound
    HAS_WINSOUND = True
except ImportError:
    HAS_WINSOUND = False

# Ajustement du chemin pour les imports locaux
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Préchargement de l'audio pour l'alerte
AUDIO_FILE_PATH = os.path.join(os.path.dirname(__file__), 'static', 'beep.wav')
if not os.path.exists(AUDIO_FILE_PATH):
    st.error(f"Erreur : Le fichier audio '{AUDIO_FILE_PATH}' est introuvable. Veuillez le placer dans le dossier 'frontend/static/'.")
    try:
        import wave
        import struct
        import math
        sample_rate = 44100
        duration = 0.5  # secondes
        frequency = 1000 # Hz
        num_samples = int(sample_rate * duration)

        with wave.open(AUDIO_FILE_PATH, 'w') as wf:
            wf.setnchannels(1) # mono
            wf.setsampwidth(2) # 16 bits
            wf.setframerate(sample_rate)

            for i in range(num_samples):
                value = int(32767 * math.sin(2 * math.pi * frequency * i / sample_rate))
                packed_value = struct.pack('<h', value)
                wf.writeframes(packed_value)
        st.warning(f"Fichier audio '{AUDIO_FILE_PATH}' créé car il était manquant. Il s'agit d'un simple bip.")
    except Exception as e:
        st.error(f"Impossible de créer un fichier audio de substitution : {e}. L'alerte sonore ne fonctionnera pas.")
        AUDIO_FILE_PATH = None

encoded_audio = None
if AUDIO_FILE_PATH and os.path.exists(AUDIO_FILE_PATH):
    with open(AUDIO_FILE_PATH, "rb") as f:
        encoded_audio = base64.b64encode(f.read()).decode()

# Import des modules existants
try:
    from backend.mt5_connector import (
        connect, shutdown, get_ohlc, get_all_symbols,
        get_symbols_by_category, get_symbol_info,
        get_available_timeframes, test_connection,
        TIMEFRAME_MAPPING, get_open_positions, get_trade_history,
        calculate_position_size
    )
    from backend.spike_detector import detect_spikes, analyze_spike_pattern, predict_next_spike, predict_spike_ml, fine_tune_spike_model, batch_predict_spike_ml
    from backend.technical_analysis import (
        add_technical_indicators,
        detect_step_pattern,
        predict_next_step_pattern,
        detect_step_pattern_crash,
        predict_next_step_pattern_crash
    )
    from backend.fundamental_analysis import get_fundamental_analysis, get_market_overview
    from backend.ai_analysis import analyze_with_gemini
    from backend.signal_generator import generate_signal
    from backend.chart_utils import (
        add_technical_indicators_to_chart,
        create_spike_analysis_chart,
    )
    from backend.advanced_analysis import predict_trend_ml
except ImportError as e:
    st.error(f"Erreur d'import des modules backend existants : {e}. Assurez-vous que le dossier 'backend' est correctement configuré et contient tous les fichiers.")

# DUMMY CLASSES IN CASE OF IMPORT FAILURE
class DummyMT5Connector:
    def connect(self):
        pass  # st.error("Dummy MT5: Not connected. Check .env and MT5 status.")
    def shutdown(self):
        st.info("Dummy MT5: Shutdown completed.")
    def get_ohlc(self, symbol, timeframe, count):
        # st.warning(f"Dummy MT5: No OHLC data for {symbol}.")
        data = {
            'timestamp': [datetime.now() - timedelta(minutes=(count - i - 1)) for i in range(count)],
            'open': [100 + np.random.randn() * 2 for i in range(count)],
            'high': [102 + np.random.randn() * 2 for i in range(count)],
            'low': [98 + np.random.randn() * 2 for i in range(count)],
            'close': [100.5 + np.random.randn() * 2 for i in range(count)],
            'tick_volume': [1000 + i * 10 for i in range(count)]
        }
        df_dummy = pd.DataFrame(data)
        df_dummy['timestamp'] = pd.to_datetime(df_dummy['timestamp'])
        return df_dummy
    def get_all_symbols(self):
        return ["EURUSD", "Boom 1000 Index", "Crash 1000 Index", "Volatility 75 Index"]
    def get_symbols_by_category(self):
        return {"FOREX": ["EURUSD"], "SYNTHETIC": ["Boom 1000 Index", "Crash 1000 Index", "Volatility 75 Index"], "STOCKS": ["TSLA"]}
    def get_symbol_info(self, symbol):
        price = 1.0 if "USD" in symbol else 10000.0 if "BTC" in symbol else 100.0
        return {"bid": price, "ask": price + 0.0001, "spread": 0.0001}
    def get_available_timeframes(self):
        return ["1m", "5m", "15m", "1h", "4h", "1d"]
    def test_connection(self):
        return False
    TIMEFRAME_MAPPING = {"1m": "M1", "5m": "M5", "15m": "M15", "1h": "H1", "4h": "H4", "1d": "D1"}

class DummySpikeDetector:
    def detect_spikes(self, df, threshold, method):
        if df.empty:
            return pd.DataFrame()
        spikes_data = []
        for _ in range(np.random.randint(1, 5)):
            spike_idx = np.random.randint(len(df) // 2, len(df) - 1)
            spike_row = df.iloc[spike_idx].copy()
            spike_type = 'BOOM' if np.random.rand() > 0.5 else 'CRASH'
            pct_change = np.random.uniform(threshold, threshold + 1.0) * (1 if spike_type == 'BOOM' else -1)
            spike_row['spike_type'] = spike_type
            spike_row['pct_change'] = pct_change
            spike_row['intensity'] = abs(pct_change)
            spike_row['confidence'] = 0.8
            spikes_data.append(spike_row)
        return pd.DataFrame(spikes_data)

    def analyze_spike_pattern(self, spikes_df, df_full):
        return {
            'total_spikes': len(spikes_df),
            'boom_count': (spikes_df['spike_type'] == 'BOOM').sum(),
            'crash_count': (spikes_df['spike_type'] == 'CRASH').sum(),
            'avg_average_intensity': spikes_df['intensity'].abs().mean() if not spikes_df.empty else 0
        }

    def predict_next_spike(self, spikes_df, df_full):
        if not spikes_df.empty:
            last_spike_time = spikes_df['timestamp'].iloc[-1]
            expected_time = last_spike_time + timedelta(minutes=np.random.randint(5, 60))
            return {
                'probability': 0.7,
                'type': 'BOOM' if 'BOOM' in spikes_df['spike_type'].values else 'CRASH',
                'expected_time': expected_time,
                'message': 'Prediction context.',
                'context': {}
            }
        return {
            'probability': 0.0,
            'type': 'UNKNOWN',
            'expected_time': None,
            'message': 'Not enough data',
            'context': {}
        }

    def predict_spike_ml(self, df):
        return float(np.random.rand())

    def batch_predict_spike_ml(self, df):
        return pd.Series(np.random.rand(len(df)), index=df.index).to_numpy()

class DummyTechnicalAnalysis:
    def add_technical_indicators(self, df, indicators):
        df_copy = df.copy()
        if df_copy.empty:
            return df_copy
        if 'rsi' in indicators:
            df_copy['rsi_14'] = np.random.rand(len(df_copy)) * 100
        if 'macd' in indicators:
            df_copy['macd'] = np.random.rand(len(df_copy))
            df_copy['macd_signal'] = np.random.rand(len(df_copy))
            df_copy['macd_histogram'] = df_copy['macd'] - df_copy['macd_signal']
        if 'atr' in indicators:
            df_copy['atr_14'] = np.random.rand(len(df_copy))
        if 'bollinger' in indicators:
            df_copy['bb_upper'] = df_copy['close'] * 1.005
            df_copy['bb_middle'] = df_copy['close']
            df_copy['bb_lower'] = df_copy['close'] * 0.995
        if 'sma' in indicators:
            df_copy['sma_20'] = df_copy['close'].rolling(window=20).mean()
        if 'ema' in indicators:
            df_copy['ema_50'] = df_copy['close'].ewm(span=50, adjust=False).mean()
        return df_copy

class DummyFundamentalAnalysis:
    def get_fundamental_analysis(self, symbol):
        return {
            "overview_summary": f"Dummy summary for {symbol}. Market sentiment is currently mixed.",
            "news_sentiment": "Neutral",
            "economic_events": [
                {"date": "2023-10-27", "time": "14:30", "event": "Dummy CPI Data", "impact": "High", "country": "US"},
                {"date": "2023-10-28", "time": "09:00", "event": "Dummy Manufacturing PMI", "impact": "Medium", "country": "EU"}
            ]
        }

    def get_market_overview(self):
        return "Dummy market overview."

class DummyAIAnalysis:
    def analyze_with_gemini(self, prompt):
        return "Dummy AI analysis: Model did not provide a real-time analysis."

class DummySignalGenerator:
    def generate_signal(self, df, trend_strength):
        if df.empty:
            return {'signal': 'HOLD', 'confidence': 0.0, 'reasoning': ['No data']}
        last_close = df['close'].iloc[-1]
        prev_close = df['close'].iloc[-2] if len(df) > 1 else last_close
        if last_close > prev_close:
            return {'signal': 'BUY', 'confidence': 0.7 + np.random.rand() * 0.2, 'reasoning': ['Price rising']}
        return {'signal': 'SELL', 'confidence': 0.7 + np.random.rand() * 0.2, 'reasoning': ['Price falling']}

class DummyCharts:
    def _get_mt5_style(self):
        """Retourne le style visuel proche de MT5 avec des améliorations de lisibilité"""
        return {
            'bg_color': '#1E1E1E',
            'plot_bg_color': '#1A1A1A',
            'text_color': '#E0E0E0',
            'grid_color': '#2D2D2D',
            'up_color': '#26A69A',  # Vert MT5
            'down_color': '#EF5350',  # Rouge MT5
            'volume_up': 'rgba(38, 166, 154, 0.6)',
            'volume_down': 'rgba(239, 83, 80, 0.6)',
            'candle_width': 0.8,
            'font_family': 'Roboto, Arial, sans-serif',
            'font_size': 12,
            'hover_bg_color': 'rgba(50, 50, 50, 0.9)',
            'hover_font_color': '#FFFFFF',
            'border_color': '#3A3A3A',
            'highlight_color': '#FFA500',
            'tooltip_bg': 'rgba(40, 40, 40, 0.95)',
            'tooltip_border': '#444444',
            'tooltip_font': '12px Roboto, Arial, sans-serif'
        }

    def _create_figure_layout(self, title, height=700):
        """Crée la mise en page de base du graphique avec un style amélioré"""
        style = self._get_mt5_style()
        layout = go.Layout(
            title=dict(
                text=title,
                x=0.5,
                xanchor='center',
                y=0.98,
                yanchor='top',
                font=dict(
                    family=style['font_family'],
                    size=18,
                    color=style['text_color'],
                    weight='bold'
                ),
                pad=dict(t=10, b=5)
            ),
            plot_bgcolor=style['plot_bg_color'],
            paper_bgcolor=style['bg_color'],
            font=dict(
                family=style['font_family'],
                size=style['font_size'],
                color=style['text_color']
            ),
            margin=dict(l=60, r=60, t=80, b=80, pad=5),
            height=height,
            hovermode='x unified',
            hoverlabel=dict(
                bgcolor=style['tooltip_bg'],
                bordercolor=style['tooltip_border'],
                font_size=12,
                font_family=style['font_family'],
                align='left',
                namelength=-1  # Affiche le nom complet de la série
            ),
            hoverdistance=50,
            spikedistance=1000,
            legend=dict(
                orientation='h',
                yanchor='bottom',
                y=1.02,
                xanchor='right',
                x=1,
                bgcolor='rgba(30, 30, 30, 0.7)',
                bordercolor=style['border_color'],
                borderwidth=1,
                font=dict(
                    size=11,
                    color=style['text_color'],
                    family=style['font_family']
                ),
                itemsizing='constant',
                itemclick='toggleothers',
                itemdoubleclick='toggle'
            )
        )
        return layout

    def create_price_chart(self, df, title, chart_type='candlestick'):
        """
        Crée un graphique de prix selon le type spécifié
        
        Args:
            df (DataFrame): Données OHLCV
            title (str): Titre du graphique
            chart_type (str): Type de graphique ('candlestick' ou 'line')
            
        Returns:
            plotly.graph_objs.Figure: Figure Plotly
        """
        if df.empty:
            return go.Figure()
            
        style = self._get_mt5_style()
        
        # Créer la figure avec la mise en page personnalisée
        fig = make_subplots(
            rows=2, 
            cols=1, 
            shared_xaxes=True, 
            vertical_spacing=0.03,
            row_heights=[0.7, 0.3],
            specs=[[{"secondary_y": True}], [{"secondary_y": False}]]
        )
        
        if chart_type == 'candlestick':
            # Ajouter les chandeliers
            fig.add_trace(
                go.Candlestick(
                    x=df['timestamp'],
                    open=df['open'],
                    high=df['high'],
                    low=df['low'],
                    close=df['close'],
                    name='Prix',
                    increasing=dict(
                        line=dict(color=style['up_color'], width=1.2),
                        fillcolor=style['up_color']
                    ),
                    decreasing=dict(
                        line=dict(color=style['down_color'], width=1.2),
                        fillcolor=style['down_color']
                    ),
                    line=dict(width=1.5),
                    whiskerwidth=0.7,
                    opacity=1.0,
                    showlegend=True,
                    hoverinfo='all'
                ),
                row=1, col=1, secondary_y=False
            )
        elif chart_type == 'line':
            # Ajouter une courbe de prix
            fig.add_trace(
                go.Scatter(
                    x=df['timestamp'],
                    y=df['close'],
                    name='Prix de clôture',
                    line=dict(color='#2196F3', width=2),
                    mode='lines',
                    showlegend=True,
                    hovertext=[f'{y:.5f}' for y in df['close']]
                ),
                row=1, col=1, secondary_y=False
            )
            
            # Ajouter une zone d'ombre pour la fourchette de prix
            fig.add_trace(
                go.Scatter(
                    x=pd.concat([df['timestamp'], df['timestamp'][::-1]]),
                    y=pd.concat([df['high'], df['low'][::-1]]),
                    fill='toself',
                    fillcolor='rgba(33, 150, 243, 0.1)',
                    line=dict(width=0),
                    hoverinfo='skip',
                    showlegend=False
                ),
                row=1, col=1, secondary_y=False
            )
        
        # Ajouter le volume si disponible
        if 'tick_volume' in df.columns:
            if chart_type == 'candlestick':
                colors = [style['volume_up'] if df['close'].iloc[i] >= df['open'].iloc[i] 
                         else style['volume_down'] for i in range(len(df))]
            else:
                # Pour le graphique en ligne, on utilise une couleur unie
                colors = '#2196F3'
                
            fig.add_trace(
                go.Bar(
                    x=df['timestamp'],
                    y=df['tick_volume'],
                    name='Volume',
                    marker_color=colors,
                    opacity=0.7,
                    marker_line_width=0,
                    showlegend=chart_type != 'candlestick'  # On affiche la légende uniquement pour le graphique en ligne
                ),
                row=2, col=1
            )
        
        # Mise à jour du layout
        layout = self._create_figure_layout(title)
        fig.update_layout(layout)
        
        # Configuration des axes X et Y principaux (graphique des prix)
        fig.update_xaxes(
            row=1, col=1,
            showgrid=True,
            gridcolor=style['grid_color'],
            showline=True,
            linecolor=style['grid_color'],
            rangeslider=dict(visible=False),
            type='date',
            title='Date/Heure',
            tickformat='%d %b %H:%M',
            nticks=10,
            showspikes=True,
            spikemode='across',
            spikesnap='cursor',
            spikethickness=1,
            spikedash='solid',
            spikecolor='#666666',
            rangeselector=dict(
                bgcolor=style['bg_color'],
                bordercolor=style['border_color'],
                borderwidth=1,
                buttons=list([
                    dict(count=1, label='1h', step='hour', stepmode='backward'),
                    dict(count=6, label='6h', step='hour', stepmode='backward'),
                    dict(count=1, label='1j', step='day', stepmode='backward'),
                    dict(count=7, label='1s', step='day', stepmode='backward'),
                    dict(step='all', label='Tout')
                ]),
                font=dict(
                    family=style['font_family'],
                    size=10,
                    color=style['text_color']
                ),
                activecolor=style['highlight_color'],
                y=1.1
            )
        )
        
        fig.update_yaxes(
            row=1, col=1,
            title='Prix',
            title_standoff=10,
            side='right',
            showgrid=True,
            gridcolor=style['grid_color'],
            showline=True,
            linecolor=style['grid_color'],
            fixedrange=False,
            tickformat=".5f",  # Affiche 5 décimales pour les paires de devises
            showspikes=True,
            spikemode='across',
            spikesnap='cursor',
            spikethickness=1,
            spikedash='solid',
            spikecolor='#666666'
        )
        
        # Configuration des axes pour le volume (sous-graphique)
        fig.update_xaxes(
            row=2, col=1,
            showgrid=True,
            gridcolor=style['grid_color'],
            showline=True,
            linecolor=style['grid_color'],
            title='Date/Heure',
            tickformat='%H:%M',
            tickangle=-45,
            nticks=10
        )
        
        fig.update_yaxes(
            row=2, col=1,
            title='Volume',
            title_standoff=10,
            side='right',
            showgrid=True,
            gridcolor=style['grid_color'],
            showline=True,
            linecolor=style['grid_color']
        )
        
        # La configuration du sélecteur de plage est déjà incluse dans la configuration des axes X
        
        # Configuration du mode hover et des infobulles
        # Configuration des infobulles pour les chandeliers
        if chart_type == 'candlestick':
            hover_texts = []
            for i in range(len(df)):
                hover_text = (
                    f"<b>{df['timestamp'].iloc[i].strftime('%d %b %Y %H:%M:%S')}</b><br>"
                    f"O: {df['open'].iloc[i]:.5f}<br>"
                    f"H: {df['high'].iloc[i]:.5f}<br>"
                    f"L: {df['low'].iloc[i]:.5f}<br>"
                    f"C: {df['close'].iloc[i]:.5f}"
                )
                hover_texts.append(hover_text)
            
            fig.update_traces(
                hovertext=hover_texts,
                hoverinfo='text',
                selector=dict(type='candlestick')
            )
        else:
            # Configuration des infobulles pour le graphique en ligne
            hover_texts = [
                f"<b>{ts.strftime('%d %b %Y %H:%M:%S')}</b><br>Prix: {p:.5f}" 
                for ts, p in zip(df['timestamp'], df['close'])
            ]
            
            fig.update_traces(
                hovertext=hover_texts,
                hoverinfo='text',
                selector=dict(type='scatter', mode='lines')
            )
        
        # Amélioration des infobulles pour le volume
        if 'tick_volume' in df.columns:
            hover_texts = [f"Volume: {v:,.0f}" for v in df['tick_volume']]
            fig.update_traces(
                hovertext=hover_texts,
                hoverinfo='text',
                selector=dict(type='bar')
            )
        
        # Ajouter la ligne de prix actuelle et les statistiques
        if not df.empty:
            last_close = df['close'].iloc[-1]
            last_high = df['high'].iloc[-1]
            last_low = df['low'].iloc[-1]
            
            # Ligne de prix actuelle
            fig.add_hline(
                y=last_close,
                line=dict(
                    color=style['highlight_color'],
                    width=1,
                    dash='dash'
                ),
                opacity=0.8,
                annotation=dict(
                    text=f"Clôture: {last_close:.5f}",
                    font=dict(
                        size=11,
                        color=style['highlight_color']
                    ),
                    bgcolor=style['bg_color'],
                    borderpad=4,
                    borderwidth=1,
                    bordercolor=style['border_color'],
                    showarrow=False,
                    x=1.02,
                    xanchor='left',
                    xref='paper',
                    yanchor='middle'
                ),
                row=1, col=1
            )
            
            # Afficher plus d'informations pour le graphique en ligne
            if chart_type == 'line':
                # Ligne du plus haut récent
                fig.add_hline(
                    y=last_high,
                    line=dict(
                        color=style['up_color'],
                        width=0.8,
                        dash='dot'
                    ),
                    opacity=0.6,
                    annotation=dict(
                        text=f"Max: {last_high:.5f}",
                        font=dict(
                            size=10,
                            color=style['up_color']
                        ),
                        bgcolor=style['bg_color'],
                        borderpad=2,
                        borderwidth=1,
                        bordercolor=style['border_color'],
                        showarrow=False,
                        x=1.02,
                        xanchor='left',
                        xref='paper',
                        yanchor='middle',
                        yshift=30
                    ),
                    row=1, col=1
                )
                
                # Ligne du plus bas récent
                fig.add_hline(
                    y=last_low,
                    line=dict(
                        color=style['down_color'],
                        width=0.8,
                        dash='dot'
                    ),
                    opacity=0.6,
                    annotation=dict(
                        text=f"Min: {last_low:.5f}",
                        font=dict(
                            size=10,
                            color=style['down_color']
                        ),
                        bgcolor=style['bg_color'],
                        borderpad=2,
                        borderwidth=1,
                        bordercolor=style['border_color'],
                        showarrow=False,
                        x=1.02,
                        xanchor='left',
                        xref='paper',
                        yanchor='middle',
                        yshift=-30
                    ),
                    row=1, col=1
                )
        
        return fig

    def add_technical_indicators_to_chart(self, fig, df, indicators):
        style = self._get_mt5_style()
        
        # Couleurs des indicateurs
        indicator_colors = {
            'sma_20': '#FF6D00',  # Orange
            'ema_50': '#2962FF',   # Bleu
            'bb_upper': '#26A69A', # Vert
            'bb_middle': '#B0BEC5',# Gris clair
            'bb_lower': '#EF5350', # Rouge
            'rsi': '#9C27B0',      # Violet
            'macd': '#2196F3',     # Bleu clair
            'signal': '#FF9800',   # Orange
            'hist': '#4CAF50'      # Vert clair
        }
        
        # Largeurs de ligne
        line_width = 1.2
        
        # Ajouter les indicateurs techniques
        if 'sma' in indicators and 'sma_20' in df.columns:
            fig.add_trace(
                go.Scatter(
                    x=df['timestamp'],
                    y=df['sma_20'],
                    mode='lines',
                    name='SMA 20',
                    line=dict(
                        color=indicator_colors['sma_20'],
                        width=line_width
                    ),
                    opacity=0.9
                ),
                row=1, col=1, secondary_y=False
            )
            
        if 'ema' in indicators and 'ema_50' in df.columns:
            fig.add_trace(
                go.Scatter(
                    x=df['timestamp'],
                    y=df['ema_50'],
                    mode='lines',
                    name='EMA 50',
                    line=dict(
                        color=indicator_colors['ema_50'],
                        width=line_width
                    ),
                    opacity=0.9
                ),
                row=1, col=1, secondary_y=False
            )
            
        if 'bollinger' in indicators and all(col in df.columns for col in ['bb_upper', 'bb_middle', 'bb_lower']):
            # Bande supérieure
            fig.add_trace(
                go.Scatter(
                    x=df['timestamp'],
                    y=df['bb_upper'],
                    name='BB Upper',
                    mode='lines',
                    line=dict(
                        color=indicator_colors['bb_upper'],
                        width=line_width
                    ),
                    opacity=0.7,
                    showlegend=True
                ),
                row=1, col=1, secondary_y=False
            )
            
            # Ligne médiane
            fig.add_trace(
                go.Scatter(
                    x=df['timestamp'],
                    y=df['bb_middle'],
                    name='BB Middle',
                    mode='lines',
                    line=dict(
                        color=indicator_colors['bb_middle'],
                        width=line_width,
                        dash='dash'
                    ),
                    opacity=0.7,
                    showlegend=True
                ),
                row=1, col=1, secondary_y=False
            )
            
            # Bande inférieure
            fig.add_trace(
                go.Scatter(
                    x=df['timestamp'],
                    y=df['bb_lower'],
                    name='BB Lower',
                    mode='lines',
                    line=dict(
                        color=indicator_colors['bb_lower'],
                        width=line_width
                    ),
                    opacity=0.7,
                    showlegend=True,
                    fill='tonexty',
                    fillcolor='rgba(38, 166, 154, 0.1)'
                ),
                row=1, col=1, secondary_y=False
            )
            
        # Mettre à jour la légende
        fig.update_layout(
            legend=dict(
                orientation='h',
                yanchor='bottom',
                y=1.02,
                xanchor='right',
                x=1,
                bgcolor='rgba(0,0,0,0)',
                font=dict(
                    size=11,
                    color=style['text_color']
                )
            )
        )
        
        return fig

    def create_spike_analysis_chart(self, df, spikes_df, title):
        """Crée un graphique d'analyse de spikes avec les chandeliers et les spikes détectés"""
        # Créer le graphique en chandeliers de base
        fig = self.create_price_chart(df, title, chart_type='candlestick')
        
        # Ajouter les marqueurs de spikes
        if not spikes_df.empty:
            boom_spikes = spikes_df[spikes_df['spike_type'] == 'BOOM']
            crash_spikes = spikes_df[spikes_df['spike_type'] == 'CRASH']
            
            if not boom_spikes.empty:
                fig.add_trace(
                    go.Scatter(
                        x=boom_spikes['timestamp'],
                        y=boom_spikes['close'],
                        mode='markers+text',
                        name='BOOM',
                        marker=dict(
                            color='#00C853',
                            size=10,
                            symbol='triangle-up',
                            line=dict(width=1, color='white')
                        ),
                        text='BOOM',
                        textposition='top center',
                        textfont=dict(
                            family='Arial, sans-serif',
                            size=10,
                            color='#00C853'
                        ),
                        hoverinfo='text',
                        hovertext=[f"BOOM<br>Prix: {p:.5f}<br>Date: {d}" 
                                 for p, d in zip(boom_spikes['close'], boom_spikes['timestamp'])]
                    ),
                    row=1, col=1, secondary_y=False
                )
                
            if not crash_spikes.empty:
                fig.add_trace(
                    go.Scatter(
                        x=crash_spikes['timestamp'],
                        y=crash_spikes['close'],
                        mode='markers+text',
                        name='CRASH',
                        marker=dict(
                            color='#FF3D00',
                            size=10,
                            symbol='triangle-down',
                            line=dict(width=1, color='white')
                        ),
                        text='CRASH',
                        textposition='bottom center',
                        textfont=dict(
                            family='Arial, sans-serif',
                            size=10,
                            color='#FF3D00'
                        ),
                        hoverinfo='text',
                        hovertext=[f"CRASH<br>Prix: {p:.5f}<br>Date: {d}" 
                                 for p, d in zip(crash_spikes['close'], crash_spikes['timestamp'])]
                    ),
                    row=1, col=1, secondary_y=False
                )
        
        # Mettre à jour le layout pour le graphique d'analyse de spike
        fig.update_layout(
            title=dict(
                text=f"{title} - Analyse des Spikes",
                font=dict(
                    family='Arial, sans-serif',
                    size=18,
                    color='#D6D6D6'
                ),
                x=0.5,
                xanchor='center'
            ),
            hovermode='x unified',
            hoverlabel=dict(
                bgcolor='rgba(30, 30, 30, 0.9)',
                font_size=12,
                font_family='Arial, sans-serif'
            )
        )
        
        return fig
        return fig

# Assign dummy chart functions after DummyCharts is defined
create_price_chart = DummyCharts().create_price_chart
add_technical_indicators_to_chart = DummyCharts().add_technical_indicators_to_chart
create_spike_analysis_chart = DummyCharts().create_spike_analysis_chart

# Assign dummy classes
connect = DummyMT5Connector().connect
shutdown = DummyMT5Connector().shutdown
get_ohlc = DummyMT5Connector().get_ohlc
get_all_symbols = DummyMT5Connector().get_all_symbols
get_symbols_by_category = DummyMT5Connector().get_symbols_by_category
get_symbol_info = DummyMT5Connector().get_symbol_info
get_available_timeframes = DummyMT5Connector().get_available_timeframes
test_connection = DummyMT5Connector().test_connection
TIMEFRAME_MAPPING = DummyMT5Connector().TIMEFRAME_MAPPING
detect_spikes = DummySpikeDetector().detect_spikes
analyze_spike_pattern = DummySpikeDetector().analyze_spike_pattern
predict_next_spike = DummySpikeDetector().predict_next_spike
predict_spike_ml = DummySpikeDetector().predict_spike_ml
batch_predict_spike_ml = DummySpikeDetector().batch_predict_spike_ml
add_technical_indicators = DummyTechnicalAnalysis().add_technical_indicators
generate_signal = DummySignalGenerator().generate_signal
get_fundamental_analysis = DummyFundamentalAnalysis().get_fundamental_analysis
get_market_overview = DummyFundamentalAnalysis().get_market_overview
try:
    from backend.ai_analysis import analyze_with_gemini
except ImportError:
    analyze_with_gemini = DummyAIAnalysis().analyze_with_gemini
# Import des nouveaux modules
try:
    from backend.cache_manager import cache_manager
    from backend.alert_system import alert_system
    from backend.advanced_analysis import advanced_analysis
    from backend.trading_agent import trading_agent
except ImportError as e:
    st.warning(f"Certains modules avancés ne sont pas disponibles: {e}. Ils seront remplacés par des versions factices.")

    class DummyCacheManager:
        def get_cached_mt5_data(self, *args, **kwargs):
            return None
        def get_cached_indicators(self, *args, **kwargs):
            return None
        def get_cached_signals(self, *args, **kwargs):
            return None
        def clear_cache(self):
            st.info("Cache vidé (factice)")

    class DummyAlertSystem:
        def __init__(self):
            if 'alerts' not in st.session_state:
                st.session_state.alerts = []
        def add_alert(self, message, message_type="info"):
            st.session_state.alerts.append({"message": message, "message_type": message_type, "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")})
            st.session_state.alerts = st.session_state.alerts[-50:]
        def display_alerts(self):
            if st.session_state.alerts:
                st.subheader("Alertes actives:")
                for alert in reversed(st.session_state.alerts):
                    if alert['message_type'] == "error":
                        st.error(f"[{alert['timestamp']}] {alert['message']}")
                    elif alert['message_type'] == "warning":
                        st.warning(f"[{alert['timestamp']}] {alert['message']}")
                    elif alert['message_type'] == "success":
                        st.success(f"[{alert['timestamp']}] {alert['message']}")
                    else:
                        st.info(f"[{alert['timestamp']}] {alert['message']}")
                if st.button("Effacer toutes les alertes", key="clear_all_alerts"):
                    st.session_state.alerts = []
                    st.rerun()
            else:
                st.info("Aucune alerte active.")

        def check_spike_alert_ml(self, df, symbol, ml_proba, context, ml_threshold):
            if pd.notna(ml_proba) and ml_proba > ml_threshold and context.get('favorable_context', False):
                self.add_alert(f"⚠️ POTENTIEL SPIKE détecté sur {symbol} (Proba ML: {ml_proba*100:.1f}%!). Contexte: {context.get('message', 'N/A')}", message_type="warning")

        def check_price_alert(self, current_price, target_price, symbol, direction):
            alert_triggered = False
            message = ""
            if direction == "above" and current_price >= target_price:
                message = f"✅ PRIX ALERTE: {symbol} est AU-DESSUS de {target_price:.5f} (actuel: {current_price:.5f})"
                alert_triggered = True
            elif direction == "below" and current_price <= target_price:
                message = f"✅ PRIX ALERTE: {symbol} est EN-DESSOUS de {target_price:.5f} (actuel: {current_price:.5f})"
                alert_triggered = True

            if alert_triggered:
                self.add_alert(message, message_type="success")

    class DummyAdvancedAnalysis:
        def detect_divergences(self, df, *args, **kwargs):
            return {
                'rsi_bullish': [],
                'rsi_bearish': [],
                'macd_bullish': [],
                'macd_bearish': []
            }

        def calculate_fibonacci_levels(self, df, *args, **kwargs):
            if not df.empty:
                last_close = df['close'].iloc[-1]
                return {
                    '0.0%': last_close * 1.05 + 0.001,
                    '23.6%': last_close * 1.03,
                    '38.2%': last_close * 1.01,
                    '50.0%': last_close,
                    '61.8%': last_close * 0.99,
                    '78.6%': last_close * 0.97,
                    '100.0%': last_close * 0.95 - 0.001
                }
            return {}

        def calculate_trendlines(self, df, *args, **kwargs):
            return {'resistance': [], 'support': []}

        def identify_liquidity_levels(self, df, *args, **kwargs):
            if not df.empty:
                now = datetime.now()
                return {
                    'high_volume': [
                        {'start_time': now - timedelta(hours=3), 'end_time': now - timedelta(hours=2), 'volume': 15000},
                        {'start_time': now - timedelta(minutes=30), 'end_time': now - timedelta(minutes=15), 'volume': 20000}
                    ],
                    'price_clusters': [{'avg_price': df['close'].mean(), 'count': 10, 'volume_sum': 100000}],
                    'gap_levels': [{'price': df['close'].max() * 1.01, 'type': 'Up Gap'}]
                }
            return {'high_volume': [], 'price_clusters': [], 'gap_levels': []}

    class DummyTradingAgent:
        def __init__(self):
            if 'total_trades' not in st.session_state:
                st.session_state.total_trades = 0
                st.session_state.total_wins = 0
                st.session_state.total_losses = 0
                st.session_state.total_pnl_value = 0.0
                st.session_state.open_positions_list = []
                st.session_state.closed_positions_list = []

        def get_performance_summary(self):
            open_count = len(st.session_state.open_positions_list)
            unrealized_pnl = sum([pos.get('unrealized_pnl', 0) for pos in st.session_state.open_positions_list])
            total_pnl_str = f"${st.session_state.total_pnl_value + unrealized_pnl:.2f}"

            win_rate_str = f"{(st.session_state.total_wins / st.session_state.total_trades * 100):.1f}%" if st.session_state.total_trades > 0 else "0.0%"

            avg_win = 0.0
            avg_loss = 0.0
            winning_trades_pnl = [p['realized_pnl'] for p in st.session_state.closed_positions_list if p['realized_pnl'] > 0]
            losing_trades_pnl = [p['realized_pnl'] for p in st.session_state.closed_positions_list if p['realized_pnl'] < 0]

            if winning_trades_pnl:
                avg_win = sum(winning_trades_pnl) / len(winning_trades_pnl)
            if losing_trades_pnl:
                avg_loss = sum(losing_trades_pnl) / len(losing_trades_pnl)
            return {
                'total_trades': st.session_state.total_trades,
                'win_rate': win_rate_str,
                'total_pnl': total_pnl_str,
                'open_positions': open_count,
                'avg_win': f"${avg_win:.2f}",
                'avg_loss': f"${avg_loss:.2f}",
                'total_positions': len(st.session_state.closed_positions_list) + open_count
            }

        def get_open_positions(self):
            return st.session_state.open_positions_list

        def get_closed_positions(self):
            return st.session_state.closed_positions_list

        def reset_agent(self):
            st.session_state.total_trades = 0
            st.session_state.total_wins = 0
            st.session_state.total_losses = 0
            st.session_state.total_pnl_value = 0.0
            st.session_state.open_positions_list = []
            st.session_state.closed_positions_list = []
            DummyAlertSystem().add_alert("Agent réinitialisé! (dummy)", message_type="info")

        def execute_order(self, signal, symbol, current_price, capital):
            if not signal or signal.get('confidence', 0) < 0.7:
                DummyAlertSystem().add_alert(f"Ordre sur {symbol} non exécuté (dummy): Confiance trop faible ({signal.get('confidence',0):.2f})", message_type="warning")
                return None

            order_type = signal['signal']
            order_volume = (capital * 0.01) / current_price
            order_volume = max(0.01, round(order_volume, 2))

            if "BOOM" in symbol.upper() or "CRASH" in symbol.upper():
                if order_type == 'BUY':
                    sl = current_price * 0.998
                    tp = current_price * 1.005
                else:
                    sl = current_price * 1.002
                    tp = current_price * 0.995
            else:
                if order_type == 'BUY':
                    sl = current_price * 0.99
                    tp = current_price * 1.015
                else:
                    sl = current_price * 1.01
                    tp = current_price * 0.985

            new_position = {
                'id': st.session_state.total_trades + 1,
                'symbol': symbol,
                'type': order_type,
                'volume': order_volume,
                'entry_price': current_price,
                'open_time': datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                'stop_loss': sl,
                'take_profit': tp,
                'unrealized_pnl': 0.0
            }
            st.session_state.open_positions_list.append(new_position)
            st.session_state.total_trades += 1
            DummyAlertSystem().add_alert(f"✅ EXÉCUTÉ (dummy): {order_type} {order_volume:.2f} {symbol} @ {current_price:.5f}", message_type="success")
            return new_position

        def update_positions_pnl(self, current_prices):
            for pos in list(st.session_state.open_positions_list):
                if pos['symbol'] in current_prices:
                    price = current_prices[pos['symbol']]

                    if pos['type'] == 'BUY':
                        pos['unrealized_pnl'] = (price - pos['entry_price']) * pos['volume']
                    else:
                        pos['unrealized_pnl'] = (pos['entry_price'] - price) * pos['volume']

                    if (pos['type'] == 'BUY' and (price <= pos['stop_loss'] or price >= pos['take_profit'])) or \
                       (pos['type'] == 'SELL' and (price >= pos['stop_loss'] or price <= pos['take_profit'])):
                        realized_pnl = pos['unrealized_pnl']
                        pos['close_price'] = price
                        pos['close_time'] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        pos['realized_pnl'] = realized_pnl

                        st.session_state.closed_positions_list.append(pos)
                        st.session_state.open_positions_list.remove(pos)
                        st.session_state.total_pnl_value += realized_pnl

                        if realized_pnl >= 0:
                            st.session_state.total_wins += 1
                            DummyAlertSystem().add_alert(f"POSITION FERMÉE (dummy, GAIN): {pos['symbol']} | PnL: ${realized_pnl:.2f}", message_type="success")
                        else:
                            st.session_state.total_losses += 1
                            DummyAlertSystem().add_alert(f"POSITION FERMÉE (dummy, PERTE): {pos['symbol']} | PnL: ${realized_pnl:.2f}", message_type="error")

    cache_manager = DummyCacheManager()
    alert_system = DummyAlertSystem()
    advanced_analysis = DummyAdvancedAnalysis()
    trading_agent = DummyTradingAgent()

# Initialisation robuste de toutes les variables de session utilisées
session_defaults = {
    'open_positions_list': [],
    'closed_positions_list': [],
    'alerts': [],
    'total_trades': 0,
    'total_wins': 0,
    'total_losses': 0,
    'total_pnl_value': 0.0,
    'mt5_connected': False,
    'current_data': None,
    'current_spikes': None,
    'technical_analysis': None,
    'fundamental_analysis_data': None,
    'fundamental_analysis_summary': None,
    'last_fundamental_symbol': None,
    'ai_analysis': None,
    'trading_signals': None,
    'all_symbols': None,
    'categorized_symbols': None,
    'current_symbol': None,
    'current_timeframe': None,
    'auto_refresh': False,
    'refresh_interval': 10,
    'capital': 10000,
    'auto_trading': False,
    'spike_alert_enabled': False,
    'is_spike_alert_active': False,
    'last_actual_spike_timestamp': None,
}

for k, v in session_defaults.items():
    if k not in st.session_state:
        st.session_state[k] = v

st.set_page_config(
    page_title="TradBOT - Trading Bot Avancé",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)

# --- HEADER MODERNE ---
st.markdown('''
<style>
.tradbot-header {
    background: linear-gradient(90deg, #264653 0%, #2a9d8f 100%);
    color: white;
    padding: 2rem 0 1rem 0;
    border-radius: 0.7rem;
    text-align: center;
    margin-bottom: 2rem;
    box-shadow: 0 4px 16px rgba(44,62,80,0.08);
}
.tradbot-header h1 {
    font-size: 2.7rem;
    font-weight: 800;
    margin-bottom: 0.2em;
    letter-spacing: 0.03em;
}
.tradbot-header .subtitle {
    font-size: 1.25rem;
    font-weight: 400;
    color: #e0f2f1;
    margin-bottom: 0.5em;
}
.tradbot-metrics {
    display: flex;
    gap: 1.5rem;
    justify-content: center;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
}
.tradbot-metric-card {
    background: #f0f2f6;
    border-radius: 0.7rem;
    padding: 1.2rem 2.2rem;
    box-shadow: 0 2px 8px rgba(44,62,80,0.07);
    min-width: 180px;
    text-align: center;
    font-size: 1.1rem;
    font-weight: 600;
    color: #264653;
    display: flex;
    flex-direction: column;
    align-items: center;
}
.tradbot-metric-card .icon {
    font-size: 2.1rem;
    margin-bottom: 0.2em;
}
.tradbot-success {
    background: linear-gradient(90deg, #43e97b 0%, #38f9d7 100%);
    color: #1b5e20;
    border-radius: 0.7rem;
    padding: 1.2rem 2rem;
    font-size: 1.1rem;
    font-weight: 600;
    margin-bottom: 1.5rem;
    box-shadow: 0 2px 8px rgba(44,62,80,0.07);
    text-align: center;
}
.tradbot-progress {
    width: 100%;
    background: #e0e0e0;
    border-radius: 0.5rem;
    margin: 1.2rem 0 1.5rem 0;
    height: 18px;
    overflow: hidden;
}
.tradbot-progress-bar {
    height: 100%;
    background: linear-gradient(90deg, #2a9d8f 0%, #43e97b 100%);
    border-radius: 0.5rem;
    transition: width 0.5s;
}
</style>
<div class="tradbot-header">
    <span style="font-size:2.5rem;vertical-align:middle;">🤖</span>
    <h1>TradBOT - Trading Bot Avancé</h1>
    <div class="subtitle">Analyse IA en temps réel avec Google Gemini</div>
</div>
''', unsafe_allow_html=True)

# --- METRICS MODERNES ---
metrics = [
    {"label": "Symbole", "value": st.session_state.get('current_symbol') or "EURUSD", "icon": "💱"},
    {"label": "Timeframe", "value": st.session_state.get('current_timeframe') or "1m", "icon": "⏱️"},
    {"label": "Seuil Spike", "value": f"{st.session_state.get('spike_threshold', 0.5):.1f}%", "icon": "📈"},
    {"label": "Statut MT5", "value": "🟢 Connecté" if st.session_state.get('mt5_connected', False) else "🔴 Déconnecté", "icon": "🔌"},
]
metrics_html = '<div class="tradbot-metrics">'
for m in metrics:
    metrics_html += f'''<div class="tradbot-metric-card"><span class="icon">{m['icon']}</span>{m['label']}<br><span style="font-size:1.3rem;font-weight:700;">{m['value']}</span></div>'''
metrics_html += '</div>'
st.markdown(metrics_html, unsafe_allow_html=True)

# --- BARRE DE PROGRESSION ---
if st.session_state.current_data is not None:
    total = st.session_state.get('candle_count', 200)
    loaded = len(st.session_state.current_data)
    pct = int(100 * loaded / total) if total > 0 else 100
    st.markdown(f'''<div class="tradbot-progress"><div class="tradbot-progress-bar" style="width:{pct}%"></div></div>''', unsafe_allow_html=True)

# --- MESSAGE DE SUCCÈS MODERNE ---
if st.session_state.current_data is not None and loaded > 0:
    st.markdown(f'''<div class="tradbot-success">✅ {loaded} bougies chargées, analysées ({len(st.session_state.current_spikes) if st.session_state.current_spikes is not None else 0} spikes détectés) pour <b>{st.session_state.get('current_symbol') or 'EURUSD'}</b> (<b>{st.session_state.get('current_timeframe') or '1m'}</b>).</div>''', unsafe_allow_html=True)

# CSS personnalisé
st.markdown("""
<style>
    .main-header {
        font-size: 3rem;
        font-weight: bold;
        text-align: center;
        color: #1f77b4;
        margin-bottom: 2rem;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
    .alert-box {
        background-color: #fff3cd;
        border: 1px solid #ffeaa7;
        border-radius: 0.5rem;
        padding: 1rem;
        margin: 1rem 0;
    }
    .success-box {
        background-color: #d4edda;
        border: 1px solid #c3e6cb;
        border-radius: 0.5rem;
        padding: 1rem;
        margin: 1rem 0;
    }
    .spike-boom {
        background-color: #e9faef;
        border-left-color: #2a9d8f;
    }
    .spike-crash {
        background-color: #ffe9e9;
        border-left-color: #e76f51;
    }
    .category-card {
        background-color: #e3f2fd;
        padding: 0.5rem;
        border-radius: 0.3rem;
        margin: 0.2rem 0;
        box-shadow: 0 1px 2px rgba(0,0,0,0.05);
    }
    .stTabs [data-baseweb="tab-list"] {
        gap: 1rem;
    }
    .stTabs [data-baseweb="tab"] {
        padding: 0.75rem 1.5rem;
        border-radius: 0.5rem;
        font-weight: bold;
        transition: background-color 0.2s ease-in-out;
    }
    .stTabs [aria-selected="true"] {
        background-color: #264653 !important;
        color: white !important;
    }
</style>
""", unsafe_allow_html=True)

# CSS personnalisé pour un design professionnel
st.markdown("""
<style>
    .main-header {
        background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 1rem;
        border-radius: 10px;
        text-align: center;
        margin-bottom: 2rem;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .metric-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 1rem;
        border-radius: 10px;
        text-align: center;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .success-box {
        background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%);
        color: white;
        padding: 1rem;
        border-radius: 10px;
        margin: 1rem 0;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .warning-box {
        background: linear-gradient(135deg, #ff9800 0%, #f57c00 100%);
        color: white;
        padding: 1rem;
        border-radius: 10px;
        margin: 1rem 0;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .error-box {
        background: linear-gradient(135deg, #f44336 0%, #d32f2f 100%);
        color: white;
        padding: 1rem;
        border-radius: 10px;
        margin: 1rem 0;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .info-box {
        background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%);
        color: white;
        padding: 1rem;
        border-radius: 10px;
        margin: 1rem 0;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
    
    .tab-content {
        background: #f8f9fa;
        padding: 1rem;
        border-radius: 10px;
        margin: 1rem 0;
        border: 1px solid #e9ecef;
    }
    
    .stButton > button {
        background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
        color: white;
        border: none;
        border-radius: 25px;
        padding: 0.5rem 2rem;
        font-weight: bold;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        transition: all 0.3s ease;
    }
    
    .stButton > button:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 12px rgba(0, 0, 0, 0.15);
    }
    
    .stSelectbox > div > div {
        border-radius: 10px;
        border: 2px solid #e9ecef;
    }
    
    .stSlider > div > div > div > div {
        background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
    }
</style>
""", unsafe_allow_html=True)

# --- Initialisation des variables de sélection (doit être AVANT le header) ---
# (copie la logique de sélection depuis la sidebar, mais AVANT le header visuel)

# Valeurs par défaut si jamais la logique n'est pas encore passée
selected_symbol = st.session_state.get('current_symbol') or "EURUSD"
actual_selected_timeframe = st.session_state.get('current_timeframe') or "1m"
spike_threshold = st.session_state.get('spike_threshold', 0.5)
candle_count = st.session_state.get('candle_count', 200)

# (La logique complète de sélection du symbole/timeframe peut être raffinée ici si besoin)

# Initialisation des variables de session
if 'mt5_connected' not in st.session_state:
    st.session_state.mt5_connected = False
    st.session_state.current_data = None
    st.session_state.current_spikes = None
    st.session_state.technical_analysis = None
    st.session_state.fundamental_analysis_data = None
    st.session_state.fundamental_analysis_summary = None
    st.session_state.last_fundamental_symbol = None
    st.session_state.ai_analysis = None
    st.session_state.trading_signals = None
    st.session_state.all_symbols = None
    st.session_state.categorized_symbols = None
    st.session_state.current_symbol = None
    st.session_state.current_timeframe = None
    st.session_state.auto_refresh = False
    st.session_state.refresh_interval = 10
    st.session_state.capital = 10000
    st.session_state.auto_trading = False
    st.session_state.spike_alert_enabled = False
    st.session_state.is_spike_alert_active = False
    st.session_state.last_actual_spike_timestamp = None

# --- Connexion automatique à MT5 au démarrage si non connectée ---
# Vérifier d'abord la vraie connexion MT5
mt5_actually_connected = callable(is_connected) and is_connected()

if not mt5_actually_connected and not st.session_state.get('mt5_connected', False):
    if callable(connect):
        try:
            st.info("🔄 Tentative de connexion automatique à MT5...")
            connect()
            st.session_state.mt5_connected = True
            mt5_actually_connected = True
            st.success("✅ Connecté automatiquement à MT5!")
        except Exception as e:
            st.session_state.mt5_connected = False
            st.error(f"❌ Connexion automatique à MT5 échouée : {e}")
            st.error(f"🔍 Détails de l'erreur : {repr(e)}")
            # Vérification des variables d'environnement
            import os
            mt5_login = os.getenv('MT5_LOGIN', 'Non défini')
            mt5_server = os.getenv('MT5_SERVER', 'Non défini')
            mt5_password = os.getenv('MT5_PASSWORD', 'Non défini')
            st.warning(f"📋 Configuration MT5 : Login={mt5_login}, Server={mt5_server}, Password={'***' if mt5_password != 'Non défini' else 'Non défini'}")
    else:
        st.session_state.mt5_connected = False
        st.error("❌ La fonction connect() n'est pas disponible.")

# Sidebar pour la configuration et la sélection du symbole
with st.sidebar:
    st.header("⚙️ Configuration")
    # Ajout : Sélection du symbole en tout premier dans le panneau de réglages
    st.subheader("Sélection du symbole")
    try:
        if mt5_actually_connected and callable(get_all_symbols_simple):
            available_symbols = get_all_symbols_simple()
            if available_symbols and len(available_symbols) > 0:
                current_index = 0
                if st.session_state.get('current_symbol') in available_symbols:
                    current_index = available_symbols.index(st.session_state.get('current_symbol'))
                elif "Boom 1000 Index" in available_symbols:
                    current_index = available_symbols.index("Boom 1000 Index")
                selected_symbol_sidebar = st.selectbox(
                    "Symbole MT5",
                    available_symbols,
                    index=current_index,
                    key="sidebar_symbol_select"
                )
                if selected_symbol_sidebar != st.session_state.get('current_symbol'):
                    st.session_state.current_symbol = selected_symbol_sidebar
                    st.rerun()
            else:
                st.info("Aucun symbole MT5 disponible.")
        else:
            fallback_symbols = ["Boom 1000 Index", "Crash 1000 Index", "EURUSD", "GBPUSD", "USDJPY"]
            selected_symbol_sidebar = st.selectbox(
                "Symbole MT5",
                fallback_symbols,
                index=0,
                key="sidebar_symbol_select_fallback"
            )
            if selected_symbol_sidebar != st.session_state.get('current_symbol'):
                st.session_state.current_symbol = selected_symbol_sidebar
                st.rerun()
    except Exception as e:
        st.warning(f"Erreur lors de la récupération des symboles : {e}")
    # Ensuite seulement, afficher la connexion MT5 et le reste
    st.subheader("Connexion MT5")
    
    # Vérifier la vraie connexion MT5
    mt5_actually_connected = callable(is_connected) and is_connected()
    
    if mt5_actually_connected:
        st.success("✅ MT5 connecté")
        # Synchroniser l'état de session
        st.session_state.mt5_connected = True
    else:
        st.error("❌ MT5 non connecté. Vérifiez le fichier .env et relancez l'application.")
        # Synchroniser l'état de session
        st.session_state.mt5_connected = False
    # (On garde le bouton manuel si besoin de forcer une reconnexion)
    if st.button("🔌 Reconnecter", help="Forcer une reconnexion à MT5"):
        if callable(connect):
            try:
                st.info("🔄 Reconnexion en cours...")
                connect()
                st.session_state.mt5_connected = True
                mt5_actually_connected = True
                st.success("✅ Reconnecté à MT5!")
            except Exception as e:
                st.session_state.mt5_connected = False
                st.error(f"❌ Erreur de reconnexion : {e}")
                st.error(f"🔍 Détails : {repr(e)}")
        else:
            st.session_state.mt5_connected = False
            st.error("❌ La fonction connect() n'est pas disponible.")
    
    # Section de diagnostic MT5
    with st.expander("🔧 Diagnostic MT5"):
        st.subheader("État de la connexion")
        
        # Vérifier la vraie connexion MT5
        mt5_actually_connected = callable(is_connected) and is_connected()
        
        if mt5_actually_connected:
            st.success("✅ MT5 connecté")
            if callable(test_connection):
                if st.button("🧪 Tester la connexion"):
                    try:
                        result = test_connection()
                        if result:
                            st.success("✅ Test de connexion réussi")
                        else:
                            st.error("❌ Test de connexion échoué")
                    except Exception as e:
                        st.error(f"❌ Erreur lors du test : {e}")
        else:
            st.error("❌ MT5 non connecté")
            st.info("💡 Utilisez le bouton 'Reconnecter' pour tenter une nouvelle connexion")
        
        st.subheader("Configuration")
        import os
        mt5_login = os.getenv('MT5_LOGIN', 'Non défini')
        mt5_server = os.getenv('MT5_SERVER', 'Non défini')
        mt5_password = os.getenv('MT5_PASSWORD', 'Non défini')
        
        st.write(f"**Login:** {mt5_login}")
        st.write(f"**Server:** {mt5_server}")
        st.write(f"**Password:** {'***' if mt5_password != 'Non défini' else 'Non défini'}")
        
        if st.button("🔄 Vérifier les imports"):
            try:
                import MetaTrader5 as mt5
                st.success("✅ MetaTrader5 importé avec succès")
                st.write(f"**Version MT5:** {mt5.__version__ if hasattr(mt5, '__version__') else 'Version inconnue'}")
            except ImportError as e:
                st.error(f"❌ Erreur import MetaTrader5 : {e}")
            except Exception as e:
                st.error(f"❌ Erreur inattendue : {e}")
        
        if st.button("🔍 Diagnostic détaillé MT5"):
            try:
                import MetaTrader5 as mt5  # type: ignore
                st.subheader("📊 État du terminal MT5")
                # Vérifier si MT5 est initialisé
                if mt5.initialize():  # type: ignore
                    st.success("✅ MT5 initialisé avec succès")
                    # Vérifier les informations du terminal
                    terminal_info = mt5.terminal_info()  # type: ignore
                    if terminal_info:
                        st.write(f"**Terminal:** {terminal_info.name}")
                        st.write(f"**Version:** {terminal_info.version}")
                        st.write(f"**Chemin:** {terminal_info.path}")
                        st.write(f"**Connecté:** {terminal_info.connected}")
                        st.write(f"**Trade autorisé:** {terminal_info.trade_allowed}")
                    else:
                        st.error("❌ Impossible de récupérer les infos du terminal")
                    # Vérifier la connexion au serveur
                    st.subheader("🌐 Connexion au serveur")
                    try:
                        # Tenter la connexion avec les identifiants
                        import os
                        mt5_login = int(os.getenv('MT5_LOGIN', 0))
                        mt5_password = os.getenv('MT5_PASSWORD', '')
                        mt5_server = os.getenv('MT5_SERVER', '')
                        if mt5.login(login=mt5_login, password=mt5_password, server=mt5_server):  # type: ignore
                            st.success("✅ Connexion au serveur réussie")
                            # Récupérer les infos du compte
                            account_info = mt5.account_info()  # type: ignore
                            if account_info:
                                st.write(f"**Compte:** {account_info.login}")
                                st.write(f"**Serveur:** {account_info.server}")
                                st.write(f"**Balance:** {account_info.balance}")
                                st.write(f"**Devise:** {account_info.currency}")
                            else:
                                st.error("❌ Impossible de récupérer les infos du compte")
                        else:
                            st.error("❌ Échec de connexion au serveur")
                            st.error("Vérifiez vos identifiants MT5")
                    except Exception as e:
                        st.error(f"❌ Erreur lors de la connexion : {e}")
                    # Fermer la connexion de test
                    mt5.shutdown()  # type: ignore
                else:
                    st.error("❌ Échec d'initialisation MT5")
                    st.error("Vérifiez que MT5 est installé et accessible")
            except Exception as e:
                st.error(f"❌ Erreur lors du diagnostic : {e}")
                st.error(f"**Détails:** {repr(e)}")
    # La sélection du symbole se fait maintenant directement dans l'onglet principal

# Section Symboles (liste brute)
# st.header("📑 Tous les symboles MT5 (liste brute)")
# if mt5_actually_connected:
#     if callable(get_all_symbols_simple):
#         try:
#             st.info("🔄 Récupération des symboles MT5...")
#             all_symbols_simple = get_all_symbols_simple()
#             if all_symbols_simple:
#                 st.success(f"✅ {len(all_symbols_simple)} symboles récupérés")
#         except Exception as e:
#             all_symbols_simple = []
#             st.error(f"❌ Erreur récupération symboles : {e}")
#             st.error(f"🔍 Détails : {repr(e)}")
#             st.info("💡 Vérifiez que MT5 est bien connecté et que les symboles sont disponibles")
#     else:
#         all_symbols_simple = []
#         st.error("❌ La fonction get_all_symbols_simple() n'est pas disponible.")
#     
#     if all_symbols_simple:
#         selected_symbol_tab = st.selectbox(
#             "Choisir un symbole MT5 (liste brute)",
#             all_symbols_simple,
#             index=0 if st.session_state.get('current_symbol') not in all_symbols_simple else all_symbols_simple.index(st.session_state.get('current_symbol')),
#             key="tab_symbol_select"
#         )
#         if selected_symbol_tab != st.session_state.get('current_symbol'):
#             st.session_state.current_symbol = selected_symbol_tab
#             st.rerun()
#         st.success(f"{len(all_symbols_simple)} symboles récupérés.")
#         st.markdown(f"<div style='max-height:300px;overflow:auto;border:1px solid #eee;padding:0.5em;background:#fafbfc'>{', '.join(all_symbols_simple)}</div>", unsafe_allow_html=True)
#     else:
#         st.warning("Aucun symbole MT5 disponible.")
# else:
#     st.info("Connectez-vous à MT5 pour afficher les symboles.")

# Fonction pour charger les données d'un symbole
@st.cache_data(ttl=60) # Cache MT5 data for 60 seconds
def load_symbol_data_func(symbol, timeframe, count, selected_indicators):
  """Charge les données OHLC d'un symbole spécifique et y ajoute des indicateurs techniques avancés."""
  try:
    if mt5_actually_connected:
      df = get_ohlc(symbol, timeframe, count)
      if df is not None and not df.empty:
        # Ajouter les indicateurs techniques de base
        df = add_technical_indicators(df, selected_indicators)
        
        # Ajouter les indicateurs techniques avancés
        try:
          from backend.advanced_technical_indicators import add_advanced_technical_indicators
          df = add_advanced_technical_indicators(df, selected_indicators)
        except ImportError:
          st.warning("⚠️ Module d'indicateurs avancés non disponible")
        
        return df
      else:
        st.warning(f"Aucune donnée OHLC trouvée pour {symbol} sur {timeframe}.")
        return pd.DataFrame() # Return empty DataFrame instead of None
  except Exception as e:
    st.error(f"Erreur lors du chargement des données OHLC pour {symbol}: {e}")
    return pd.DataFrame()

# Fonction pour intégrer le lecteur audio
def _embed_audio_player(audio_base64, is_active):
    if audio_base64 is None:
        return
    audio_active_state = "true" if is_active else "false"
    st.markdown(f"""
        <audio id='spike_alert_audio' src='data:audio/wav;base64,{audio_base64}' preload='auto'></audio>
        <div id='spike_alert_status' data-active='{audio_active_state}' style='display:none;'></div>
        <script>
            var audioEl = document.getElementById('spike_alert_audio');
            var alertDiv = document.getElementById('spike_alert_status');

            if (audioEl && alertDiv) {{
                if (alertDiv.dataset.active === 'true') {{
                    if (audioEl.paused) {{
                        audioEl.loop = true;
                        audioEl.play().catch(e => console.log("Audio play failed:", e));
                    }}
                }} else {{
                    if (!audioEl.paused) {{
                        audioEl.pause();
                        audioEl.currentTime = 0;
                    }}
                }}
            }}
        </script>
    """, unsafe_allow_html=True)

# Intégration du lecteur audio au début de l'application
_embed_audio_player(encoded_audio, st.session_state.is_spike_alert_active)

# =============================================================================
# 🎯 INTERFACE PRINCIPALE - TRADBOT AVANCÉ
# =============================================================================

# Métriques rapides en haut de page
col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("💱 Symbole", selected_symbol, delta=None)

with col2:
    st.metric("⏱️ Timeframe", actual_selected_timeframe, delta=None)

with col3:
    st.metric("📈 Seuil Spike", f"{spike_threshold:.1f}%", delta=None)

with col4:
    status = "🟢 Connecté" if mt5_actually_connected else "🔴 Déconnecté"
    st.metric("🔌 Statut MT5", status, delta=None)

# Étape 1 : Modifier la liste des tabs pour retirer '📈 Graphique & Analyse'
tabs = st.tabs([
    "🚨 Spikes & Signaux", 
    "🤖 ML-SuperTrend",
    "🔍 Analyse Avancée",
    "🤖 Trading Agent",
    "📊 Performance",
    "🔔 Alertes",
    "📚 Analyse Fondamentale",
    "🔮 Prédiction Spike 24h"
])
(tab2, tab_ml_supertrend, tab3, tab4, tab5, tab6, tab7, tab_spike24h) = tabs

# =============================================================================
# 🚨 ONGLET 2: SPIKES & SIGNAUX
# =============================================================================
with tab2:
    st.header("🚨 Détection de Spikes & Signaux")
    
    if mt5_actually_connected:
        # Configuration de détection
        col1, col2 = st.columns(2)
        with col1:
            spike_threshold_config = st.slider("Seuil de spike (%)", 0.1, 5.0, spike_threshold, 0.1)
        with col2:
            detection_method = st.selectbox("Méthode de détection", ["percentage", "std", "volume_spike"])
        
        if st.button("🔍 Détecter les spikes", type="primary"):
            with st.spinner("Détection en cours..."):
                try:
                    df = load_symbol_data_func(selected_symbol, actual_selected_timeframe, candle_count, [])
                    if df is not None and not df.empty:
                        spikes_df = detect_spikes(df, spike_threshold_config, detection_method)
                        if not spikes_df.empty:
                            st.success(f"✅ {len(spikes_df)} spikes détectés")
                            
                            # Afficher les spikes détectés
                            st.subheader("📊 Spikes détectés")
                            expected_cols = ['timestamp', 'close', 'spike_type', 'magnitude']
                            missing_cols = [col for col in expected_cols if col not in spikes_df.columns]
                            if 'magnitude' not in spikes_df.columns:
                                import numpy as np
                                spikes_df['magnitude'] = np.nan
                                missing_cols = [col for col in expected_cols if col not in spikes_df.columns]
                            if missing_cols:
                                st.error(f"Colonnes manquantes dans le résultat de detect_spikes : {missing_cols}")
                                st.dataframe(spikes_df)
                            else:
                                st.dataframe(spikes_df[expected_cols])
                            
                        else:
                            st.info("ℹ️ Aucun spike détecté avec les paramètres actuels")
                except Exception as e:
                    st.error(f"❌ Erreur lors de la détection : {e}")
    else:
        st.warning("⚠️ Connectez-vous à MT5 pour détecter les spikes")

# =============================================================================
# 🔍 ONGLET 3: ANALYSE AVANCÉE
# =============================================================================
with tab3:
    st.header("🔍 Analyse Avancée & IA")
    
    if mt5_actually_connected:
        # Sélection des indicateurs techniques
        st.subheader("📊 Indicateurs techniques avancés")
        
        # Catégories d'indicateurs
        indicator_categories = {
            "🎯 Indicateurs de tendance": ["sma", "ema", "keltner", "donchian", "starc", "adx"],
            "📈 Indicateurs de momentum": ["rsi", "macd", "williams_r", "cmo", "aroon", "vortex"],
            "📊 Indicateurs de volatilité": ["bollinger", "atr", "gator"],
            "💰 Indicateurs de volume": ["vwap", "force_index", "chaikin"],
            "🎪 Patterns avancés": ["hikkake", "heikin_ashi", "coppock"]
        }
        
        # Sélection par catégorie
        selected_categories = st.multiselect(
            "Sélectionner les catégories d'indicateurs",
            list(indicator_categories.keys()),
            default=["🎯 Indicateurs de tendance", "📈 Indicateurs de momentum"]
        )
        
        # Construire la liste des indicateurs sélectionnés
        technical_indicators = []
        for category in selected_categories:
            technical_indicators.extend(indicator_categories[category])
        
        # Affichage des indicateurs sélectionnés
        if technical_indicators:
            st.info(f"📋 Indicateurs sélectionnés: {', '.join(technical_indicators)}")
        else:
            st.warning("⚠️ Veuillez sélectionner au moins une catégorie d'indicateurs")
            technical_indicators = ["sma", "rsi", "macd", "bollinger"]  # Fallback
        
        # Analyse IA - Modèles adaptatifs
        st.subheader("🧠 Analyse IA - Modèles Adaptatifs")
        
        # Détection automatique du type de symbole
        def get_symbol_category(symbol):
            symbol_upper = symbol.upper()
            if "BOOM" in symbol_upper or "CRASH" in symbol_upper:
                return "SYNTHETIC_SPECIAL"  # Boom/Crash spécifiques
            elif any(keyword in symbol_upper for keyword in ['VOLATILITY', 'STEP', 'JUMP', 'RANGE BREAK', 'DEX', 'DRIFT', 'TREK', 'VOLSWITCH', 'SKEW', 'MULTI STEP']):
                return "SYNTHETIC_GENERAL"  # Autres indices synthétiques
            elif any(crypto in symbol_upper for crypto in ['BTC', 'ETH', 'ADA', 'DOT', 'LNK', 'LTC', 'BCH', 'XRP', 'XLM', 'XMR', 'ZEC', 'XTZ', 'NEO', 'MKR', 'SOL', 'TRX', 'UNI', 'SHB', 'TON', 'FET', 'APT', 'COM', 'IMX', 'SAN', 'TRU', 'MLN', 'NER']):
                return "CRYPTO"
            elif any(pair in symbol_upper for pair in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD', 'SEK', 'NOK', 'PLN', 'ZAR', 'SGD', 'HKD', 'THB', 'MXN', 'CNH']):
                return "FOREX"
            elif any(stock in symbol_upper for stock in ['AAPL', 'MSFT', 'GOOG', 'AMZN', 'TSLA', 'META', 'NVDA', 'NFLX', 'JPM', 'BAC', 'WMT', 'PG', 'JNJ', 'V', 'HD', 'MA', 'PYPL', 'DIS', 'CRM', 'NKE', 'PFE', 'KO', 'MCD', 'ABNB', 'UBER', 'ZM', 'AAL', 'DAL', 'GM', 'F', 'BA', 'IBM', 'INTC', 'CSCO', 'ORCL', 'ADBE', 'NFLX', 'AMD', 'BABA', 'AIG', 'GS', 'C', 'DBK', 'EBAY', 'FDX', 'FOX', 'HPQ', 'SONY', 'TEVA', 'AIR', 'AIRF', 'BAY', 'BMW', 'BIIB', 'CONG', 'ADS']):
                return "STOCKS"
            else:
                return "UNIVERSAL"  # Modèle universel pour tous les autres
        
        symbol_category = get_symbol_category(selected_symbol)
        st.info(f"📊 Catégorie détectée: {symbol_category}")
        
        # Section des modèles disponibles
        st.markdown("**🎯 Modèles disponibles:**")
        
        # Configuration des modèles par catégorie
        model_configs = {
            'SYNTHETIC_SPECIAL': {
                'name': 'Boom/Crash Spécialisé',
                'model_path': 'synthetic_special_xgb_model.pkl',
                'scaler_path': 'synthetic_special_xgb_model_scaler.pkl',
                'description': 'Modèle optimisé pour Boom/Crash 1000, 500, 300 Index',
                'symbols_trained': ['Boom 1000 Index', 'Boom 500 Index', 'Crash 1000 Index', 'Crash 500 Index', 'Boom 300 Index']
            },
            'SYNTHETIC_GENERAL': {
                'name': 'Indices Synthétiques',
                'model_path': 'synthetic_general_xgb_model.pkl',
                'scaler_path': 'synthetic_general_xgb_model_scaler.pkl',
                'description': 'Modèle pour Volatility, Step, Jump, Range Break Index',
                'symbols_trained': ['Volatility 10 Index', 'Volatility 25 Index', 'Volatility 50 Index', 'Volatility 75 Index', 'Volatility 100 Index']
            },
            'CRYPTO': {
                'name': 'Cryptomonnaies',
                'model_path': 'crypto_xgb_model.pkl',
                'scaler_path': 'crypto_xgb_model_scaler.pkl',
                'description': 'Modèle pour Bitcoin, Ethereum, ADA, BCH, etc.',
                'symbols_trained': ['ADAUSD', 'BCHUSD', 'BTCETH', 'BTCLTC', 'BTCUSD']
            },
            'FOREX': {
                'name': 'Forex',
                'model_path': 'forex_xgb_model.pkl',
                'scaler_path': 'forex_xgb_model_scaler.pkl',
                'description': 'Modèle pour paires de devises (AUD, EUR, USD, etc.)',
                'symbols_trained': ['AUDCAD', 'AUDCHF', 'AUDNZD', 'AUDJPY', 'AUDUSD']
            },
            'STOCKS': {
                'name': 'Actions',
                'model_path': 'stocks_xgb_model.pkl',
                'scaler_path': 'stocks_xgb_model_scaler.pkl',
                'description': 'Modèle pour actions US (AAPL, TSLA, etc.)',
                'symbols_trained': ['AAL', 'AAPL', 'ADS', 'ABNB', 'AIG']
            },
            'UNIVERSAL': {
                'name': 'Universel',
                'model_path': 'universal_xgb_model.pkl',
                'scaler_path': 'universal_xgb_model_scaler.pkl',
                'description': 'Modèle pour tous les autres instruments',
                'symbols_trained': ['MRNA', 'PEP', 'AGG.US', 'ARKK.US', 'DIA.US']
            }
        }
        
        # Affichage des modèles avec boutons
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown("**📊 Modèles par catégorie:**")
            for category, config in model_configs.items():
                # Vérifier si le modèle existe
                model_exists = os.path.exists(os.path.join(os.path.dirname(__file__), '..', 'backend', config['model_path']))
                status_icon = "✅" if model_exists else "❌"
                
                with st.expander(f"{status_icon} {config['name']} ({category})"):
                    st.write(f"**Description:** {config['description']}")
                    st.write(f"**Symboles entraînés:** {', '.join(config['symbols_trained'])}")
                    st.write(f"**Statut:** {'Disponible' if model_exists else 'Non disponible'}")
                    
                    if model_exists:
                        if st.button(f"🤖 Analyser avec {config['name']}", key=f"btn_{category}"):
                            st.session_state.selected_model = category
                            st.rerun()
        
        with col2:
            st.markdown("**🎯 Modèle recommandé:**")
            recommended_config = model_configs.get(symbol_category, model_configs['UNIVERSAL'])
            model_exists = os.path.exists(os.path.join(os.path.dirname(__file__), '..', 'backend', recommended_config['model_path']))
            
            if model_exists:
                st.success(f"✅ {recommended_config['name']} - Recommandé pour {selected_symbol}")
                st.write(f"**Raison:** Modèle spécialisé pour cette catégorie")
                st.write(f"**Symboles d'entraînement:** {', '.join(recommended_config['symbols_trained'])}")
                
                if st.button("🚀 Analyser avec le modèle recommandé", type="primary", key="btn_recommended"):
                    st.session_state.selected_model = symbol_category
                    st.rerun()
            else:
                st.warning(f"⚠️ Modèle {recommended_config['name']} non disponible")
                st.info("Utilisez le modèle universel ou un autre modèle disponible")
            
            # Afficher le modèle actuellement sélectionné
            current_model = st.session_state.get('selected_model')
            if current_model and current_model in model_configs:
                st.markdown("**🎯 Modèle actuellement sélectionné:**")
                current_config = model_configs[current_model]
                st.info(f"✅ {current_config['name']}")
                st.write(f"**Symboles d'entraînement:** {', '.join(current_config['symbols_trained'])}")
                
                if st.button("🔄 Réinitialiser la sélection", key="btn_reset"):
                    if 'selected_model' in st.session_state:
                        del st.session_state.selected_model
                    st.rerun()
        
        # Informations sur l'entraînement
        st.markdown("---")
        st.markdown("**📊 Informations sur l'entraînement:**")
        
        # Lire le fichier de résumé d'entraînement
        training_summary_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'training_summary.txt')
        if os.path.exists(training_summary_path):
            with open(training_summary_path, 'r', encoding='utf-8') as f:
                summary_content = f.read()
            
            with st.expander("📋 Détails de l'entraînement"):
                st.text(summary_content)
        else:
            st.info("📋 Aucun résumé d'entraînement disponible")
        
        # Bouton d'analyse générale
        if st.button("🤖 Lancer l'analyse IA (Modèle automatique)", type="primary"):
            with st.spinner("Analyse IA en cours..."):
                try:
                    # Charger les données OHLC
                    df_pred = load_symbol_data_func(selected_symbol, actual_selected_timeframe, candle_count, [])
                    
                    if df_pred is None or df_pred.empty:
                        st.error("Aucune donnée disponible pour l'analyse IA.")
                    else:
                        # Vérifier le prix actuel
                        try:
                            from backend.mt5_connector import get_symbol_info
                            symbol_info = get_symbol_info(selected_symbol)
                            current_price = symbol_info.get('bid', symbol_info.get('ask')) if symbol_info else None
                            if current_price:
                                st.info(f"💰 Prix actuel {selected_symbol}: {current_price:.2f}")
                            else:
                                st.warning("⚠️ Impossible de récupérer le prix actuel")
                        except Exception as e:
                            st.warning(f"⚠️ Erreur récupération prix actuel: {e}")
                            current_price = None
                        
                        # Sélection du modèle selon la catégorie
                        model_path = None
                        scaler_path = None
                        
                        if symbol_category == "SYNTHETIC_SPECIAL" and selected_symbol == "Boom 1000 Index":
                            # Modèle spécialisé Boom 1000
                            model_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'boom1000_xgb_model.pkl')
                            scaler_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'boom1000_xgb_model_scaler.pkl')
                            model_name = "XGBoost Boom 1000 (Spécialisé)"
                        elif symbol_category == "SYNTHETIC_SPECIAL":
                            # Modèle pour Boom/Crash spécialisés
                            model_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'synthetic_special_xgb_model.pkl')
                            scaler_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'synthetic_special_xgb_model_scaler.pkl')
                            model_name = "XGBoost Boom/Crash Spécialisé"
                        elif symbol_category == "SYNTHETIC_GENERAL":
                            # Modèle pour indices synthétiques génériques
                            model_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'synthetic_general_xgb_model.pkl')
                            scaler_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'synthetic_general_xgb_model_scaler.pkl')
                            model_name = "XGBoost Indices Synthétiques"
                        elif symbol_category == "CRYPTO":
                            # Modèle pour crypto
                            model_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'crypto_xgb_model.pkl')
                            scaler_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'crypto_xgb_model_scaler.pkl')
                            model_name = "XGBoost Crypto"
                        elif symbol_category == "FOREX":
                            # Modèle pour forex
                            model_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'forex_xgb_model.pkl')
                            scaler_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'forex_xgb_model_scaler.pkl')
                            model_name = "XGBoost Forex"
                        elif symbol_category == "STOCKS":
                            # Modèle pour actions
                            model_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'stocks_xgb_model.pkl')
                            scaler_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'stocks_xgb_model_scaler.pkl')
                            model_name = "XGBoost Actions"
                        else:
                            # Modèle universel
                            model_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'universal_xgb_model.pkl')
                            scaler_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'universal_xgb_model_scaler.pkl')
                            model_name = "XGBoost Universel"
                        
                        # Vérifier si un modèle spécifique a été sélectionné
                        selected_model = st.session_state.get('selected_model')
                        if selected_model and selected_model in model_configs:
                            # Utiliser le modèle sélectionné par l'utilisateur
                            config = model_configs[selected_model]
                            model_path = os.path.join(os.path.dirname(__file__), '..', 'backend', config['model_path'])
                            scaler_path = os.path.join(os.path.dirname(__file__), '..', 'backend', config['scaler_path'])
                            model_name = f"XGBoost {config['name']} (Sélectionné)"
                            st.success(f"🎯 Utilisation du modèle sélectionné: {config['name']}")
                        
                        # Vérifier si le modèle existe
                        if not os.path.exists(model_path) or not os.path.exists(scaler_path):
                            st.warning(f"⚠️ Modèle {model_name} non trouvé. Utilisation du modèle universel...")
                            # Fallback vers modèle universel
                            model_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'universal_xgb_model.pkl')
                            scaler_path = os.path.join(os.path.dirname(__file__), '..', 'backend', 'universal_xgb_model_scaler.pkl')
                            model_name = "XGBoost Universel (Fallback)"
                            
                            if not os.path.exists(model_path) or not os.path.exists(scaler_path):
                                st.error("❌ Aucun modèle XGBoost disponible. Veuillez entraîner au moins un modèle.")
                                st.info("💡 Pour entraîner un modèle universel, utilisez le script d'entraînement avec tous les symboles.")
                        else:
                            st.success(f"✅ Modèle {model_name} trouvé et chargé")
                        
                        # Charger le modèle
                        import joblib
                        try:
                            model = joblib.load(model_path)
                            scaler = joblib.load(scaler_path)
                        except Exception as e:
                            st.error(f"❌ Erreur lors du chargement du modèle : {e}")
                            st.stop()
                        
                        # Créer les features adaptatives
                        def create_adaptive_features(df, symbol_category):
                            df_features = df.copy()
                            
                            # Features de base communes
                            df_features['return'] = df_features['close'].pct_change()
                            df_features['return_1'] = df_features['return'].shift(1)
                            df_features['return_2'] = df_features['return'].shift(2)
                            df_features['return_3'] = df_features['return'].shift(3)
                            df_features['volatility'] = df_features['return'].rolling(window=20).std()
                            df_features['volatility_5'] = df_features['return'].rolling(window=5).std()
                            df_features['volatility_10'] = df_features['return'].rolling(window=10).std()
                            
                            # Moyennes mobiles
                            df_features['ma_5'] = df_features['close'].rolling(window=5).mean()
                            df_features['ma_10'] = df_features['close'].rolling(window=10).mean()
                            df_features['ma_20'] = df_features['close'].rolling(window=20).mean()
                            df_features['ma_50'] = df_features['close'].rolling(window=50).mean()
                            df_features['ma_ratio_5_20'] = df_features['ma_5'] / df_features['ma_20']
                            df_features['ma_ratio_10_50'] = df_features['ma_10'] / df_features['ma_50']
                            
                            # RSI
                            delta = df_features['close'].diff()
                            gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
                            loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
                            rs = gain / loss
                            df_features['rsi'] = 100 - (100 / (1 + rs))
                            
                            # MACD
                            ema_12 = df_features['close'].ewm(span=12).mean()
                            ema_26 = df_features['close'].ewm(span=26).mean()
                            df_features['macd'] = ema_12 - ema_26
                            df_features['macd_signal'] = df_features['macd'].ewm(span=9).mean()
                            df_features['macd_histogram'] = df_features['macd'] - df_features['macd_signal']
                            
                            # Bollinger Bands
                            df_features['bb_middle'] = df_features['close'].rolling(window=20).mean()
                            bb_std = df_features['close'].rolling(window=20).std()
                            df_features['bb_upper'] = df_features['bb_middle'] + (bb_std * 2)
                            df_features['bb_lower'] = df_features['bb_middle'] - (bb_std * 2)
                            df_features['bb_position'] = (df_features['close'] - df_features['bb_lower']) / (df_features['bb_upper'] - df_features['bb_lower'])
                            
                            # ATR
                            high_low = df_features['high'] - df_features['low']
                            high_close = np.abs(df_features['high'] - df_features['close'].shift())
                            low_close = np.abs(df_features['low'] - df_features['close'].shift())
                            true_range = np.maximum(high_low, np.maximum(high_close, low_close))
                            df_features['atr'] = true_range.rolling(window=14).mean()
                            
                            # Volume (si disponible)
                            if 'tick_volume' in df_features.columns:
                                df_features['volume_ma'] = df_features['tick_volume'].rolling(window=20).mean()
                                df_features['volume_ratio'] = df_features['tick_volume'] / df_features['volume_ma']
                            else:
                                df_features['volume_ma'] = 1000
                                df_features['volume_ratio'] = 1.0
                            
                            # Features de prix
                            df_features['price_range'] = (df_features['high'] - df_features['low']) / df_features['close']
                            df_features['body_size'] = abs(df_features['close'] - df_features['open']) / df_features['close']
                            df_features['upper_shadow'] = (df_features['high'] - np.maximum(df_features['open'], df_features['close'])) / df_features['close']
                            df_features['lower_shadow'] = (np.minimum(df_features['open'], df_features['close']) - df_features['low']) / df_features['close']
                            
                            # Features temporelles
                            df_features['hour'] = df_features['timestamp'].dt.hour
                            df_features['minute'] = df_features['timestamp'].dt.minute
                            df_features['day_of_week'] = df_features['timestamp'].dt.dayofweek
                            
                            # Momentum
                            df_features['momentum_5'] = df_features['close'] / df_features['close'].shift(5) - 1
                            df_features['momentum_10'] = df_features['close'] / df_features['close'].shift(10) - 1
                            df_features['momentum_20'] = df_features['close'] / df_features['close'].shift(20) - 1
                            
                            # Features spécifiques par catégorie
                            if symbol_category in ["SYNTHETIC_SPECIAL", "SYNTHETIC_GENERAL"]:
                                # Features pour indices synthétiques
                                df_features['spike_detection'] = (df_features['high'] - df_features['low']) / df_features['close'] > 0.05
                                df_features['volatility_regime'] = df_features['volatility'].rolling(50).mean()
                            elif symbol_category == "CRYPTO":
                                # Features pour crypto
                                df_features['crypto_volatility'] = df_features['volatility'] * 100  # Crypto plus volatile
                                df_features['btc_correlation'] = 1.0  # Placeholder pour corrélation BTC
                            elif symbol_category == "FOREX":
                                # Features pour forex
                                df_features['pip_movement'] = df_features['return'] * 10000  # Mouvement en pips
                                df_features['spread_impact'] = 0.0001  # Placeholder pour impact du spread
                            elif symbol_category == "STOCKS":
                                # Features pour actions
                                df_features['stock_volatility'] = df_features['volatility'] * 252  # Volatilité annualisée
                                df_features['market_hours'] = ((df_features['hour'] >= 9) & (df_features['hour'] <= 16)).astype(int)
                            
                            return df_features
                        
                        # Créer les features adaptatives
                        df_feat = create_adaptive_features(df_pred, symbol_category)
                        
                        # Features communes (30 features attendues par le modèle)
                        common_features = [
                            'return', 'return_1', 'return_2', 'return_3',
                            'volatility', 'volatility_5', 'volatility_10',
                            'ma_5', 'ma_10', 'ma_20', 'ma_50',
                            'ma_ratio_5_20', 'ma_ratio_10_50',
                            'rsi', 'macd', 'macd_signal',
                            'bb_position', 'atr', 'volume_ratio',
                            'price_range', 'body_size', 'upper_shadow',
                            'hour', 'minute', 'day_of_week',
                            'momentum_5', 'momentum_10', 'momentum_20'
                        ]
                        
                        # Vérifier et ajuster le nombre de features si nécessaire
                        if len(common_features) != 30:
                            st.warning(f"⚠️ Attention: Le modèle attend 30 caractéristiques, mais {len(common_features)} sont définies.")
                            # Ajuster dynamiquement si possible
                            common_features = common_features[:30]  # Garder les 30 premières caractéristiques
                        
                        # Ajouter features spécifiques selon la catégorie
                        if symbol_category in ["SYNTHETIC_SPECIAL", "SYNTHETIC_GENERAL"]:
                            common_features.extend(['spike_detection', 'volatility_regime'])
                        elif symbol_category == "CRYPTO":
                            common_features.extend(['crypto_volatility', 'btc_correlation'])
                        elif symbol_category == "FOREX":
                            common_features.extend(['pip_movement', 'spread_impact'])
                        elif symbol_category == "STOCKS":
                            common_features.extend(['stock_volatility', 'market_hours'])
                        
                        # Filtrer les features disponibles
                        available_features = [f for f in common_features if f in df_feat.columns]
                        
                        if len(available_features) < 10:
                            st.error(f"❌ Features insuffisantes disponibles: {len(available_features)}")
                            st.stop()
                        
                        # Vérifier que nous avons exactement 30 features
                        if len(available_features) != 30:
                            st.warning(f"⚠️ Attention: Le modèle attend 30 caractéristiques, mais {len(available_features)} sont disponibles.")
                            st.warning(f"Disponibles: {available_features}")
                            
                            # Ajuster pour avoir exactement 30 features si possible
                            if len(available_features) > 30:
                                available_features = available_features[:30]
                                st.warning(f"Réduction à 30 caractéristiques: {available_features}")
                            else:
                                st.error("❌ Nombre de caractéristiques insuffisant. Impossible de procéder.")
                                st.stop()
                        
                        last = df_feat.iloc[-1]
                        X_pred = last[available_features].values.reshape(1, -1)
                        
                        try:
                            X_pred_scaled = scaler.transform(X_pred)
                        except Exception as e:
                            st.error(f"❌ Erreur lors de la mise à l'échelle des données: {e}")
                            st.error(f"Dimensions des données: {X_pred.shape}, Nombre de features attendu: {scaler.n_features_in_ if hasattr(scaler, 'n_features_in_') else 'inconnu'}")
                            st.error(f"Features disponibles: {available_features}")
                            st.stop()
                        pred = model.predict(X_pred_scaled)[0]
                        proba = model.predict_proba(X_pred_scaled)[0][1]
                        
                        # Prix actuel pour les calculs
                        entry_price = current_price if current_price else df_pred['close'].iloc[-1]
                        
                        # Calcul des prix de déclenchement et objectifs
                        atr = last['atr'] if not pd.isna(last['atr']) else entry_price * 0.01
                        
                        if pred == 1:  # HAUSSE
                            direction = "📈 HAUSSE"
                            recommendation = "🟢 ACHETER"
                            trigger_price = entry_price
                            target_price = entry_price + (atr * 2)  # Objectif 2x ATR
                            stop_loss = entry_price - (atr * 1)     # Stop 1x ATR
                            risk_reward = 2.0
                        else:  # BAISSE
                            direction = "📉 BAISSE"
                            recommendation = "🔴 VENDRE"
                            trigger_price = entry_price
                            target_price = entry_price - (atr * 2)  # Objectif 2x ATR
                            stop_loss = entry_price + (atr * 1)     # Stop 1x ATR
                            risk_reward = 2.0
                        
                        # Force de la prédiction
                        if proba > 0.8 or proba < 0.2:
                            prediction_strength = "🔥 FORTE"
                            alert_color = "success"
                        elif proba > 0.7 or proba < 0.3:
                            prediction_strength = "⚡ MODÉRÉE"
                            alert_color = "warning"
                        else:
                            prediction_strength = "💡 FAIBLE"
                            alert_color = "info"
                        
                        # Timing estimé basé sur l'historique
                        recent_moves = df_pred['close'].pct_change().abs()
                        avg_move_time = recent_moves.rolling(20).mean()
                        if isinstance(avg_move_time, pd.Series):
                            if not avg_move_time.empty:
                                avg_move_value = avg_move_time.iloc[-1]
                            else:
                                avg_move_value = 0.01
                        elif isinstance(avg_move_time, np.ndarray):
                            if avg_move_time.size > 0:
                                avg_move_value = avg_move_time[-1]
                            else:
                                avg_move_value = 0.01
                        else:
                            avg_move_value = 0.01
                        estimated_time = "2-5 minutes" if avg_move_value > 0.01 else "5-15 minutes"
                        
                        # Affichage du résultat complet
                        st.markdown(f"""
                        <div class='{alert_color}-box'>
                        <h3>🎯 PRÉDICTION {model_name.upper()}</h3>
                        <p><b>Symbole:</b> {selected_symbol}</p>
                        <p><b>Direction:</b> {direction}</p>
                        <p><b>Probabilité:</b> {proba*100:.1f}%</p>
                        <p><b>Force:</b> {prediction_strength}</p>
                        <p><b>Recommandation:</b> {recommendation}</p>
                        </div>
                        """, unsafe_allow_html=True)
                        
                        # Détails techniques
                        col1, col2 = st.columns(2)
                        with col1:
                            st.markdown("**💰 NIVEAUX DE PRIX**")
                            st.write(f"Prix actuel: {entry_price:.2f}")
                            st.write(f"Prix déclenchement: {trigger_price:.2f}")
                            st.write(f"Objectif: {target_price:.2f}")
                            st.write(f"Stop Loss: {stop_loss:.2f}")
                        
                        with col2:
                            st.markdown("**⏱️ TIMING & RISQUE**")
                            st.write(f"Timing estimé: {estimated_time}")
                            st.write(f"Ratio Risque/Récompense: 1:{risk_reward}")
                            st.write(f"ATR actuel: {atr:.2f}")
                        
                        # Alerte automatique pour les prédictions fortes
                        if proba > 0.8 or proba < 0.2:
                            st.markdown(f"""
                            <div class='success-box'>
                            <h4>🚨 ALERTE AUTOMATIQUE</h4>
                            <p><b>Prédiction forte détectée!</b></p>
                            <p>Action recommandée: {recommendation}</p>
                            <p>Entrée: {trigger_price:.2f} | Objectif: {target_price:.2f}</p>
                            <p>Stop: {stop_loss:.2f} | Timing: {estimated_time}</p>
                            </div>
                            """, unsafe_allow_html=True)
                            
                            # Ajouter l'alerte au système d'alertes
                            if 'alert_system' in locals():
                                alert_message = f"🚨 PRÉDICTION FORTE {model_name}: {direction} sur {selected_symbol} (Proba: {proba*100:.1f}%) - {recommendation}"
                                alert_system.add_alert(alert_message, "success")
                        
                        # Interprétation intelligente
                        st.markdown("**🧠 INTERPRÉTATION**")
                        if pred == 1:
                            if proba > 0.7:
                                interpretation = f"Le modèle {model_name} détecte une forte probabilité de hausse sur {selected_symbol}. Les indicateurs techniques confirment un momentum haussier. Recommandation: Position longue avec stop serré."
                            else:
                                interpretation = f"Le modèle {model_name} suggère une légère tendance haussière sur {selected_symbol}, mais la confiance est modérée. Surveillez les niveaux de support et résistance."
                        else:
                            if proba < 0.3:
                                interpretation = f"Le modèle {model_name} détecte une forte probabilité de baisse sur {selected_symbol}. Les indicateurs techniques montrent un momentum baissier. Recommandation: Position courte ou attente."
                            else:
                                interpretation = f"Le modèle {model_name} suggère une légère tendance baissière sur {selected_symbol}, mais la confiance est modérée. Évitez les positions risquées."
                        
                        st.info(interpretation)
                        
                        # Section signaux professionnels
                        st.markdown("---")
                        st.subheader("🎯 Signaux Professionnels - Confluence d'Indicateurs")
                        
                        try:
                            from backend.advanced_technical_indicators import generate_professional_signals
                            
                            # Générer les signaux professionnels
                            professional_signals = generate_professional_signals(df_feat)
                            
                            if professional_signals and professional_signals.get('signal') != 'INSUFFICIENT_DATA':
                                # Affichage du signal principal
                                signal = professional_signals['signal']
                                confidence = professional_signals['confidence']
                                trend_strength = professional_signals['trend_strength']
                                
                                if signal == 'BUY':
                                    signal_color = "success"
                                    signal_icon = "🟢"
                                    signal_text = "ACHETER"
                                elif signal == 'SELL':
                                    signal_color = "error"
                                    signal_icon = "🔴"
                                    signal_text = "VENDRE"
                                else:
                                    signal_color = "warning"
                                    signal_icon = "🟡"
                                    signal_text = "ATTENDRE"
                                
                                # Style CSS personnalisé pour les signaux
                                st.markdown("""
                                <style>
                                    .signal-card {
                                        background: #1e2130;
                                        border-radius: 12px;
                                        padding: 20px;
                                        margin: 15px 0;
                                        box-shadow: 0 8px 30px rgba(0, 0, 0, 0.2);
                                        border: 1px solid rgba(255, 255, 255, 0.05);
                                    }
                                    .signal-header {
                                        display: flex;
                                        justify-content: space-between;
                                        align-items: center;
                                        margin-bottom: 15px;
                                        padding-bottom: 15px;
                                        border-bottom: 1px solid rgba(255, 255, 255, 0.1);
                                    }
                                    .signal-title {
                                        font-size: 18px;
                                        font-weight: 600;
                                        color: #fff;
                                        margin: 0;
                                    }
                                    .signal-badge {
                                        padding: 5px 12px;
                                        border-radius: 20px;
                                        font-weight: 600;
                                        font-size: 14px;
                                    }
                                    .buy-badge {
                                        background: rgba(76, 175, 80, 0.2);
                                        color: #4CAF50;
                                    }
                                    .sell-badge {
                                        background: rgba(244, 67, 54, 0.2);
                                        color: #f44336;
                                    }
                                    .neutral-badge {
                                        background: rgba(33, 150, 243, 0.2);
                                        color: #2196F3;
                                    }
                                    .confidence-bar {
                                        height: 8px;
                                        background: rgba(255, 255, 255, 0.1);
                                        border-radius: 4px;
                                        margin: 15px 0;
                                        overflow: hidden;
                                    }
                                    .confidence-level {
                                        height: 100%;
                                        border-radius: 4px;
                                    }
                                    .indicator-grid {
                                        display: grid;
                                        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
                                        gap: 10px;
                                        margin: 15px 0;
                                    }
                                    .indicator-card {
                                        background: rgba(255, 255, 255, 0.03);
                                        border-radius: 8px;
                                        padding: 12px 15px;
                                        border-left: 3px solid #4CAF50;
                                        transition: all 0.3s ease;
                                    }
                                    .indicator-card.sell {
                                        border-left-color: #f44336;
                                    }
                                    .indicator-card.neutral {
                                        border-left-color: #2196F3;
                                    }
                                    .indicator-name {
                                        font-size: 13px;
                                        color: #a0a8c0;
                                        margin-bottom: 5px;
                                    }
                                    .indicator-value {
                                        font-weight: 600;
                                        font-size: 14px;
                                        color: #fff;
                                    }
                                    .stats-card {
                                        background: rgba(255, 255, 255, 0.03);
                                        border-radius: 8px;
                                        padding: 15px;
                                        text-align: center;
                                    }
                                    .stat-value {
                                        font-size: 24px;
                                        font-weight: 700;
                                        margin: 5px 0;
                                    }
                                    .stat-label {
                                        font-size: 12px;
                                        color: #a0a8c0;
                                        text-transform: uppercase;
                                        letter-spacing: 0.5px;
                                    }
                                    .interpretation-box {
                                        background: rgba(33, 150, 243, 0.1);
                                        border-left: 4px solid #2196F3;
                                        border-radius: 0 8px 8px 0;
                                        padding: 15px;
                                        margin: 20px 0;
                                    }
                                </style>
                                """, unsafe_allow_html=True)
                                
                                # Déterminer la classe CSS en fonction du signal
                                badge_class = 'buy-badge' if signal == 'BUY' else 'sell-badge' if signal == 'SELL' else 'neutral-badge'
                                signal_text = 'ACHAT' if signal == 'BUY' else 'VENTE' if signal == 'SELL' else 'NEUTRE'
                                signal_emoji = '📈' if signal == 'BUY' else '📉' if signal == 'SELL' else '⏸️'
                                confidence_color = '#4CAF50' if signal == 'BUY' else '#f44336' if signal == 'SELL' else '#2196F3'
                                
                                # Afficher la carte de signal principale
                                st.markdown(f"""
                                <div class="signal-card">
                                    <div class="signal-header">
                                        <h3 class="signal-title">SIGNAL DE TRADING PROFESSIONNEL</h3>
                                        <span class="signal-badge {badge_class}">
                                            {signal_emoji} {signal_text}
                                        </span>
                                    </div>
                                    
                                    <div style="display: flex; justify-content: space-between; align-items: center; margin: 10px 0;">
                                        <div>
                                            <div style="font-size: 12px; color: #a0a8c0; margin-bottom: 5px;">NIVEAU DE CONFIANCE</div>
                                            <div style="font-size: 24px; font-weight: 700; color: {confidence_color};">{confidence*100:.1f}%</div>
                                        </div>
                                        <div style="text-align: right;">
                                            <div style="font-size: 12px; color: #a0a8c0; margin-bottom: 5px;">FORCE DE TENDANCE</div>
                                            <div style="font-size: 18px; font-weight: 600; color: #fff;">
                                                {'🔥 FORTE' if trend_strength else '💨 FAIBLE'}
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="confidence-bar">
                                        <div class="confidence-level" style="width: {confidence*100}%; background: {confidence_color};"></div>
                                    </div>
                                    
                                    <div style="margin: 20px 0;">
                                        <h4 style="color: #fff; font-size: 15px; margin-bottom: 15px;">INDICATEURS TECHNIQUES</h4>
                                        <div class="indicator-grid">
                                """, unsafe_allow_html=True)
                                
                                # Afficher les indicateurs techniques
                                signals_detail = professional_signals.get('signals_detail', {})
                                if isinstance(signals_detail, dict):
                                    for indicator, signal_value in signals_detail.items():
                                        if signal_value == 'BUY':
                                            indicator_class = ''
                                            value_emoji = '✅'
                                            value_text = 'ACHAT'
                                        elif signal_value == 'SELL':
                                            indicator_class = 'sell'
                                            value_emoji = '❌'
                                            value_text = 'VENTE'
                                        elif signal_value == 'Strong':
                                            indicator_class = ''
                                            value_emoji = '🔥'
                                            value_text = 'FORTE'
                                        elif signal_value == 'Weak':
                                            indicator_class = 'sell'
                                            value_emoji = '💨'
                                            value_text = 'FAIBLE'
                                        else:
                                            indicator_class = 'neutral'
                                            value_emoji = '⚪'
                                            value_text = 'NEUTRE'
                                            
                                        st.markdown(f"""
                                        <div class="indicator-card {indicator_class}">
                                            <div class="indicator-name">{indicator.upper()}</div>
                                            <div class="indicator-value">{value_emoji} {value_text}</div>
                                        </div>
                                        """, unsafe_allow_html=True)
                                
                                # Afficher les statistiques
                                buy_count = professional_signals.get('buy_count', 0)
                                sell_count = professional_signals.get('sell_count', 0)
                                
                                st.markdown(f"""
                                        </div>
                                    </div>
                                    
                                    <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: 20px 0;">
                                        <div class="stats-card">
                                            <div class="stat-label">SIGNAUX ACHAT</div>
                                            <div class="stat-value" style="color: #4CAF50;">{buy_count}</div>
                                        </div>
                                        <div class="stats-card">
                                            <div class="stat-label">SIGNAUX VENTE</div>
                                            <div class="stat-value" style="color: #f44336;">{sell_count}</div>
                                        </div>
                                        <div class="stats-card">
                                            <div class="stat-label">TENDANCE</div>
                                            <div class="stat-value" style="color: #2196F3;">{'HAUSSIÈRE' if buy_count > sell_count else 'BAISSIÈRE' if sell_count > buy_count else 'NEUTRE'}</div>
                                        </div>
                                    </div>
                                    
                                    <div class="interpretation-box">
                                        <h4 style="margin: 0 0 10px 0; color: #fff; font-size: 15px;">ANALYSE ET RECOMMANDATION</h4>
                                """, unsafe_allow_html=True)
                                
                                # Générer l'interprétation
                                if signal == 'BUY' and float(confidence) > 0.6:
                                    interpretation_pro = f"""
                                    <p style="margin: 0; color: #e0e0e0; line-height: 1.6; font-size: 14px;">
                                        <span style="color: #4CAF50; font-weight: 600;">CONFIRMATION D'ACHAT</span><br>
                                        La confluence de {buy_count} indicateurs techniques confirme un fort potentiel haussier. 
                                        Les indicateurs de tendance, momentum et volume convergent vers un signal d'achat. 
                                        <span style="color: #4CAF50; font-weight: 600;">Recommandation : Position longue avec un stop serré.</span>
                                    </p>
                                    """
                                elif signal == 'SELL' and float(confidence) > 0.6:
                                    interpretation_pro = f"""
                                    <p style="margin: 0; color: #e0e0e0; line-height: 1.6; font-size: 14px;">
                                        <span style="color: #f44336; font-weight: 600;">CONFIRMATION DE VENTE</span><br>
                                        La confluence de {sell_count} indicateurs techniques indique un fort potentiel baissier. 
                                        Les indicateurs montrent un momentum vendeur soutenu. 
                                        <span style="color: #f44336; font-weight: 600;">Recommandation : Position courte ou sortie des positions longues.</span>
                                    </p>
                                    """
                                else:
                                    interpretation_pro = """
                                    <p style="margin: 0; color: #e0e0e0; line-height: 1.6; font-size: 14px;">
                                        <span style="color: #2196F3; font-weight: 600;">SIGNAL MITIGÉ</span><br>
                                        Les indicateurs ne montrent pas de consensus clair. Le marché semble incertain ou en phase de consolidation. 
                                        <span style="color: #2196F3; font-weight: 600;">Recommandation : Attendre une confirmation plus forte ou réduire la taille des positions.</span>
                                    </p>
                                    """
                                
                                st.markdown(interpretation_pro + "</div></div>", unsafe_allow_html=True)
                                
                                # Ajouter un effet visuel pour les signaux forts
                                if confidence > 0.7 and signal in ['BUY', 'SELL']:
                                    st.balloons()
                                
                            else:
                                st.warning("⚠️ Données insuffisantes pour générer des signaux professionnels")
                                
                        except ImportError:
                            st.warning("⚠️ Module de signaux professionnels non disponible")
                        except Exception as e:
                            st.error(f"❌ Erreur lors de la génération des signaux professionnels: {e}")
                            import traceback
                            st.error(f"Détails: {traceback.format_exc()}")
                        
                except Exception as e:
                    st.error(f"Erreur lors de la prédiction IA : {e}")
                    import traceback
                    st.error(f"Détails: {traceback.format_exc()}")
    else:
        st.warning("⚠️ Connectez-vous à MT5 pour l'analyse avancée")

# =============================================================================
# 🤖 ONGLET 4: TRADING AGENT
# =============================================================================
with tab4:
    st.header("🤖 Agent de Trading Automatique")
    
    # Configuration du trading
    col1, col2 = st.columns(2)
    with col1:
        auto_trading = st.checkbox("Activer le trading automatique", value=st.session_state.get('auto_trading', False))
        st.session_state.auto_trading = auto_trading
    with col2:
        capital = st.number_input("Capital virtuel ($)", value=st.session_state.get('capital', 10000), min_value=1000, step=1000)
        st.session_state.capital = capital
    
    if auto_trading:
        st.success("✅ Trading automatique activé")
        
        # Paramètres de trading
        st.subheader("⚙️ Paramètres de trading")
        risk_percent = st.slider("Risque par trade (%)", 1, 10, 2)
        ml_threshold = st.slider("Seuil ML pour trade (%)", 50, 90, 70)
        
        if mt5_actually_connected:
            if st.button("📊 Voir les positions", type="primary"):
                st.info("Fonctionnalité de positions en cours de développement")
        else:
            st.warning("⚠️ Connectez-vous à MT5 pour le trading automatique")
    else:
        st.info("ℹ️ Trading automatique désactivé")

# =============================================================================
# 📊 ONGLET 5: PERFORMANCE
# =============================================================================
with tab5:
    st.header("📊 Performance & Statistiques")
    
    # Métriques de performance
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Trades gagnants", "0", delta="0%")
    with col2:
        st.metric("Trades perdants", "0", delta="0%")
    with col3:
        st.metric("Win Rate", "0%", delta="0%")
    
    # Graphique de performance
    st.subheader("📈 Évolution du capital")
    st.info("Graphique de performance en cours de développement")

# =============================================================================
# 🔔 ONGLET 6: ALERTES
# =============================================================================
with tab6:
    st.header("🔔 Système d'Alertes")
    
    # Configuration des alertes
    col1, col2 = st.columns(2)
    with col1:
        spike_alert = st.checkbox("Alerte spikes", value=st.session_state.get('spike_alert_enabled', False))
        st.session_state.spike_alert_enabled = spike_alert
    with col2:
        price_alert = st.checkbox("Alerte prix", value=False)
    
    if spike_alert:
        st.success("✅ Alertes spikes activées")
        st.info("🔊 Les alertes sonores sont configurées")
    else:
        st.info("ℹ️ Alertes désactivées")

# =============================================================================
# 📚 ONGLET 7: ANALYSE FONDAMENTALE
# =============================================================================
with tab7:
    st.header("📚 Analyse Fondamentale")
    
    if mt5_actually_connected:
        if st.button("📊 Récupérer l'analyse fondamentale", type="primary"):
            with st.spinner("Analyse fondamentale en cours..."):
                try:
                    analysis = get_fundamental_analysis(selected_symbol)
                    if analysis:
                        st.success("✅ Analyse fondamentale récupérée")
                        st.json(analysis)
                    else:
                        st.warning("⚠️ Aucune analyse fondamentale disponible")
                except Exception as e:
                    st.error(f"❌ Erreur lors de l'analyse fondamentale : {e}")
    else:
        st.warning("⚠️ Connectez-vous à MT5 pour l'analyse fondamentale")

# =============================================================================
# 🤖 ONGLET ML-SUPERTREND
# =============================================================================
with tab_ml_supertrend:
    st.header("🤖 Stratégie ML-SuperTrend")
    
    if mt5_actually_connected:
        st.info("""
        La stratégie ML-SuperTrend combine l'indicateur SuperTrend avec une optimisation dynamique 
        des paramètres via K-means et un money management avancé pour générer des signaux de trading.
        """)
        
        # Configuration de la stratégie
        with st.expander("⚙️ Paramètres de la stratégie", expanded=True):
            col1, col2 = st.columns(2)
            with col1:
                ml_symbol = st.selectbox(
                    "Symbole",
                    get_all_symbols_simple() if callable(get_all_symbols_simple) else ["EURUSD", "GBPUSD", "USDJPY"],
                    index=0,
                    key="ml_symbol"
                )
                ml_timeframe = st.selectbox(
                    "Timeframe",
                    ["M1", "M5", "M15", "H1", "H4", "D1"],
                    index=3,  # H1 par défaut
                    key="ml_timeframe"
                )
            
            with col2:
                ml_risk = st.slider(
                    "Risque par trade (%)",
                    min_value=0.1,
                    max_value=5.0,
                    value=1.0,
                    step=0.1,
                    key="ml_risk"
                )
                ml_max_positions = st.number_input(
                    "Nombre maximum de positions",
                    min_value=1,
                    max_value=10,
                    value=3,
                    step=1,
                    key="ml_max_positions"
                )
        
        # Bouton pour lancer l'analyse
        if st.button("🚀 Analyser avec ML-SuperTrend", type="primary"):
            with st.spinner("Analyse en cours avec ML-SuperTrend..."):
                try:
                    # Forcer le rechargement du module pour éviter les problèmes de cache
                    import importlib
                    import sys
                    if 'backend.mt5_connector' in sys.modules:
                        importlib.reload(sys.modules['backend.mt5_connector'])
                    
                    from backend.mt5_connector import initialize_ml_supertrend, get_ml_supertrend_signals
                    
                    # Charger les données
                    df = load_symbol_data_func(ml_symbol, ml_timeframe, 1000, [])
                    
                    if df is None or df.empty:
                        st.error("❌ Impossible de charger les données pour l'analyse")
                    else:
                        # Vérifier et formater les paramètres
                        try:
                            risk = float(ml_risk) if ml_risk is not None else 1.0
                            max_pos = int(ml_max_positions) if ml_max_positions is not None else 3
                            
                            # Afficher des informations de débogage
                            st.write("🔍 Débogage - Paramètres d'appel:")
                            st.write(f"- symbol: {ml_symbol}")
                            st.write(f"- timeframe: {ml_timeframe}")
                            st.write(f"- risk_percent: {risk} (type: {type(risk)})")
                            st.write(f"- max_positions: {max_pos} (type: {type(max_pos)})")
                            
                            # Afficher la signature de la fonction
                            import inspect
                            sig = inspect.signature(initialize_ml_supertrend)
                            st.write(f"🔍 Signature de la fonction: {sig}")
                            
                            # Initialiser la stratégie avec les paramètres nommés
                            try:
                                strategy = initialize_ml_supertrend(
                                    symbol=ml_symbol,
                                    timeframe=ml_timeframe,
                                    risk_percent=risk,
                                    max_positions=max_pos
                                )
                                if not strategy or isinstance(strategy, str):
                                    st.error("❌ La fonction initialize_ml_supertrend a retourné None, un objet vide ou une erreur.")
                                    if isinstance(strategy, str):
                                        st.error(f"Détail de l'erreur :\n{strategy}")
                                    st.info("Vérifiez que le symbole et le timeframe sont bien supportés par la stratégie ML-SuperTrend.")
                                    st.info("Essayez avec un symbole courant comme 'EURUSD' ou 'Boom 1000 Index'.")
                                    st.stop()
                            except Exception as e:
                                st.error(f"❌ Erreur lors de l'appel à initialize_ml_supertrend: {e}")
                                st.error(f"Type d'erreur: {type(e).__name__}")
                                import traceback
                                st.error("Stack trace:")
                                st.code(traceback.format_exc())
                                strategy = None
                        except Exception as e:
                            st.error(f"❌ Erreur lors de l'initialisation de la stratégie: {e}")
                            st.error(f"Valeurs des paramètres - Risque: {ml_risk}, Positions max: {ml_max_positions}")
                            strategy = None
                        
                        if strategy:
                            # Obtenir les signaux
                            signals = get_ml_supertrend_signals(strategy, df)
                            
                            # Afficher les résultats
                            if signals and "error" not in signals:
                                st.success("✅ Analyse ML-SuperTrend terminée avec succès !")
                                
                                # Afficher le signal principal
                                if "signal" in signals:
                                    signal = signals["signal"]
                                    signal_color = "#4CAF50" if signal == "BUY" else "#F44336" if signal == "SELL" else "#FFC107"
                                    st.markdown(f"""
                                    <div style="background-color:#1E1E1E;padding:20px;border-radius:10px;margin:10px 0;">
                                        <h3 style="color:{signal_color};text-align:center;">
                                            Signal: <strong>{signal}</strong>
                                        </h3>
                                    </div>
                                    """, unsafe_allow_html=True)
                                
                                # Afficher les indicateurs
                                if "indicators" in signals:
                                    indicators = signals["indicators"]
                                    st.subheader("📊 Indicateurs techniques")
                                    
                                    # Afficher les indicateurs dans des colonnes
                                    cols = st.columns(3)
                                    for i, (name, value) in enumerate(indicators.items()):
                                        with cols[i % 3]:
                                            st.metric(name, f"{value:.4f}" if isinstance(value, (int, float)) else str(value))
                            else:
                                error_msg = signals.get("error", "Erreur inconnue lors de l'analyse")
                                st.error(f"❌ {error_msg}")
                        else:
                            st.error("❌ Échec de l'initialisation de la stratégie ML-SuperTrend")
                            
                except Exception as e:
                    st.error(f"❌ Erreur lors de l'exécution de ML-SuperTrend: {str(e)}")
                    import traceback
                    st.text(traceback.format_exc())
    else:
        st.warning("⚠️ Veuillez vous connecter à MT5 pour utiliser la stratégie ML-SuperTrend")

# --- FONCTION DE CATÉGORISATION DES SYMBOLES ---
def categorize_symbols(symbols_list):
    """
    Catégorise automatiquement les symboles MT5
    """
    categories = {
        'FOREX': [],
        'INDICES_SYNTHETIQUES': [],
        'CRYPTO': [],
        'ACTIONS_US': [],
        'ACTIONS_EU': [],
        'MATIERES_PREMIERES': [],
        'ETF': [],
        'AUTRES': []
    }
    
    for symbol in symbols_list:
        symbol_upper = symbol.upper()
        
        # Forex (paires de devises)
        if any(pair in symbol_upper for pair in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD', 'SEK', 'NOK', 'PLN', 'ZAR', 'SGD', 'HKD', 'THB', 'MXN', 'CNH']):
            if 'INDEX' not in symbol_upper and 'BASKET' not in symbol_upper and 'DFX' not in symbol_upper:
                categories['FOREX'].append(symbol)
        
        # Indices synthétiques (Boom, Crash, Volatility, etc.)
        elif any(keyword in symbol_upper for keyword in ['BOOM', 'CRASH', 'VOLATILITY', 'STEP', 'JUMP', 'RANGE BREAK', 'DEX', 'DRIFT', 'TREK', 'VOLSWITCH', 'SKEW', 'MULTI STEP']):
            categories['INDICES_SYNTHETIQUES'].append(symbol)
        
        # Crypto
        elif any(crypto in symbol_upper for crypto in ['BTC', 'ETH', 'ADA', 'DOT', 'LNK', 'LTC', 'BCH', 'XRP', 'XLM', 'XMR', 'ZEC', 'XTZ', 'NEO', 'MKR', 'SOL', 'TRX', 'UNI', 'SHB', 'TON', 'FET', 'APT', 'COM', 'IMX', 'SAN', 'TRU', 'MLN', 'NER']):
            categories['CRYPTO'].append(symbol)
        
        # Actions US
        elif any(stock in symbol_upper for stock in ['AAPL', 'MSFT', 'GOOG', 'AMZN', 'TSLA', 'META', 'NVDA', 'NFLX', 'JPM', 'BAC', 'WMT', 'PG', 'JNJ', 'V', 'HD', 'MA', 'PYPL', 'DIS', 'CRM', 'NKE', 'PFE', 'KO', 'MCD', 'ABNB', 'UBER', 'ZM', 'AAL', 'DAL', 'GM', 'F', 'BA', 'IBM', 'INTC', 'CSCO', 'ORCL', 'ADBE', 'NFLX', 'AMD', 'BABA', 'AIG', 'GS', 'C', 'DBK', 'EBAY', 'FDX', 'FOX', 'HPQ', 'SONY', 'TEVA', 'AIR', 'AIRF', 'BAY', 'BMW', 'BIIB', 'CONG', 'ADS']):
            categories['ACTIONS_US'].append(symbol)
        
        # ETF
        elif any(etf in symbol_upper for etf in ['.US', 'AGG', 'ARKK', 'DIA', 'EEM', 'EFA', 'ERX', 'GDX', 'GLD', 'HYG', 'IEMG', 'IJR', 'IVV', 'IVW', 'IWM', 'LQD', 'QID', 'SDS', 'SLV', 'SPXS', 'SPY', 'TBT', 'TQQQ', 'UNG', 'VEA', 'VNQ', 'VOO', 'VTI', 'VWO', 'XLE', 'XLF', 'XLK']):
            categories['ETF'].append(symbol)
        
        # Matières premières
        elif any(commodity in symbol_upper for commodity in ['XAU', 'XAG', 'XPD', 'XPT', 'OIL', 'BRENT', 'COFFEE', 'COCOA', 'SUGAR', 'COTTON', 'NGAS', 'XAUEUR', 'XAGEUR', 'XALUSD', 'XCUUSD', 'XNIUSD', 'XPBUSD', 'XZNUSD']):
            categories['MATIERES_PREMIERES'].append(symbol)
        
        # Actions européennes et indices
        elif any(european in symbol_upper for european in ['UK', 'GERMANY', 'FRANCE', 'SPAIN', 'NETHERLANDS', 'SWISS', 'AUSTRALIA', 'CHINA', 'JAPAN', 'HONG KONG', 'US SP', 'US TECH', 'WALL STREET', 'US MID CAP', 'US SMALL CAP']):
            categories['ACTIONS_EU'].append(symbol)
        
        # Autres
        else:
            categories['AUTRES'].append(symbol)
    
    return categories

# --- RÉCUPÉRATION ET CATÉGORISATION DES SYMBOLES ---
@st.cache_data(ttl=300)  # Cache pour 5 minutes
def get_categorized_symbols():
    """
    Récupère et catégorise tous les symboles MT5
    """
    try:
        if mt5_actually_connected and callable(get_all_symbols_simple):
            all_symbols = get_all_symbols_simple()
            if all_symbols:
                categories = categorize_symbols(all_symbols)
                return all_symbols, categories
    except Exception as e:
        st.error(f"Erreur lors de la récupération des symboles : {e}")
    
    # Fallback avec les symboles de base
    fallback_symbols = [
        "Boom 1000 Index", "Crash 1000 Index", "EURUSD", "GBPUSD", "USDJPY",
        "XAUUSD", "BTCUSD", "AAPL", "TSLA", "SPY.US"
    ]
    fallback_categories = {
        'INDICES_SYNTHETIQUES': ["Boom 1000 Index", "Crash 1000 Index"],
        'FOREX': ["EURUSD", "GBPUSD", "USDJPY"],
        'MATIERES_PREMIERES': ["XAUUSD"],
        'CRYPTO': ["BTCUSD"],
        'ACTIONS_US': ["AAPL", "TSLA"],
        'ETF': ["SPY.US"],
        'ACTIONS_EU': [],
        'AUTRES': []
    }
    return fallback_symbols, fallback_categories

# Récupération des symboles
try:
    all_symbols_list, categorized_symbols_dict = get_categorized_symbols()
except:
    all_symbols_list = []
    categorized_symbols_dict = {}

# Ajout pour chandeliers modernes avec streamlit-lightweight-charts
try:
    from streamlit_lightweight_charts import renderLightweightCharts
    HAS_LIGHTWEIGHT = True
except ImportError:
    HAS_LIGHTWEIGHT = False

# --- NOUVEL ONGLET : Prédiction Spike 24h ---
with tab_spike24h:
    st.header("🔮 Prédiction de Spike à Venir (24h)")
    st.markdown("<div style='color:#888;font-size:1.1rem;margin-bottom:1.5em;'>Analyse la probabilité d'un spike (BOOM/CRASH) à venir sur les 24 dernières heures pour le symbole sélectionné.<br><b>Données utilisées :</b> OHLC du symbole sélectionné sur les 24 dernières heures.</div>", unsafe_allow_html=True)
    if mt5_actually_connected:
        if st.button("Analyser la probabilité de spike à venir (24h)", type="primary"):
            with st.spinner("Analyse en cours sur les 24 dernières heures..."):
                try:
                    df = load_symbol_data_func(selected_symbol, actual_selected_timeframe, 1500, [])
                    if df is None or df.empty:
                        st.info("Aucune donnée disponible pour ce symbole/timeframe.")
                    else:
                        now = pd.Timestamp.now()
                        df_24h = df[df['timestamp'] > now - pd.Timedelta(hours=24)]
                        if df_24h.empty:
                            st.info("Aucune donnée sur les 24 dernières heures.")
                        else:
                            from backend.spike_detector import detect_spikes, predict_next_spike
                            spikes_24h = detect_spikes(df_24h, threshold=spike_threshold, method="percentage")
                            result = predict_next_spike(spikes_24h, df_24h, lookback_hours=24)
                            # Correction du timing estimé
                            timing_str = 'N/A'
                            if result['expected_time']:
                                delta = (result['expected_time'] - now).total_seconds() / 60
                                if 0 < delta < 24*60:
                                    timing_str = result['expected_time'].strftime('%Y-%m-%d %H:%M')
                                else:
                                    timing_str = 'Pas de spike attendu prochainement'
                            # Carte moderne de résultat
                            st.markdown(f"""
                            <div style='background:linear-gradient(90deg,#43e97b 0%,#38f9d7 100%);border-radius:1rem;padding:2rem 2rem 1.5rem 2rem;margin:1.5em 0;box-shadow:0 4px 16px rgba(44,62,80,0.08);color:#1b5e20;'>
                                <h2 style='margin-top:0;font-size:2.2rem;'>🔮 Probabilité de Spike à venir</h2>
                                <div style='font-size:1.5rem;font-weight:700;margin:1em 0;'>
                                    {result['probability']*100:.1f}%
                                </div>
                                <div style='font-size:1.2rem;margin-bottom:0.5em;'>
                                    <b>Type attendu :</b> {result['type']}<br>
                                    <b>Timing estimé :</b> {timing_str}
                                </div>
                                <div style='font-size:1.1rem;color:#0a3d62;'>
                                    <b>Minutes depuis le dernier spike :</b> {result['context'].get('minutes_since_last_spike','N/A'):.1f}<br>
                                    <b>Volatilité récente :</b> {result['context'].get('recent_volatility','N/A'):.5f}<br>
                                    <b>Contexte favorable :</b> {'✅' if result['context'].get('favorable_context') else '❌'}
                                </div>
                            </div>
                            """, unsafe_allow_html=True)
                            if result['probability'] > 0.7 and not result['context'].get('favorable_context'):
                                st.warning("⚠️ Probabilité élevée mais le contexte n'est pas jugé favorable (volatilité élevée ou trop peu de temps depuis le dernier spike). Interprétez avec prudence.")
                            # Graphique OHLC MT5 + indicateurs techniques
                            selected_indicators = ["sma", "ema", "bollinger"]
                            fig = create_price_chart(df_24h, f"{selected_symbol} - 24h", chart_type='candlestick')
                            fig = add_technical_indicators_to_chart(fig, df_24h, selected_indicators)
                            st.plotly_chart(fig, use_container_width=True)
                except Exception as e:
                    st.error(f"Erreur lors de l'analyse spike 24h : {e}")
    else:
        st.info("Connectez-vous à MT5 pour utiliser la prédiction spike 24h.")

# === IMPORTS POUR INDICATEURS TECHNIQUES ===
try:
    from backend.features import compute_features
    from backend.technical_analysis import add_rsi, add_macd, add_bollinger_bands, add_atr, INDICATOR_PARAMS
except ImportError as e:
    st.error(f"Erreur d'import des modules backend: {e}")
    # Fonctions de fallback
    def compute_features(df):
        return pd.DataFrame()
    def add_rsi(df):
        return df
    def add_macd(df, params):
        return df
    def add_bollinger_bands(df, params):
        return df
    def add_atr(df, periods):
        return df
    INDICATOR_PARAMS = {'macd': {}, 'bollinger': {}}

# === ONGLET INDICATEURS TECHNIQUES ===
def show_indicators_tab(df, symbol):
    import plotly.graph_objects as go
    st.subheader("📊 Chandeliers Japonais (style MT5)")
    if df is None or df.empty:
        st.warning("Aucune donnée disponible pour ce symbole.")
        return
    
    # Récupération du prix actuel depuis MT5
    try:
        from backend.mt5_connector import get_symbol_info
        symbol_info = get_symbol_info(symbol)
        if symbol_info and 'bid' in symbol_info and 'ask' in symbol_info:
            current_bid = symbol_info['bid']
            current_ask = symbol_info['ask']
            current_price = (current_bid + current_ask) / 2  # Prix moyen
            spread = current_ask - current_bid
        else:
            current_price = df['close'].iloc[-1]  # Fallback sur la dernière valeur historique
            spread = 0
    except Exception:
        current_price = df['close'].iloc[-1]  # Fallback sur la dernière valeur historique
        spread = 0
    
    # Graphique chandelier pur MT5
    fig = go.Figure(data=[
        go.Candlestick(
            x=df['timestamp'],
            open=df['open'],
            high=df['high'],
            low=df['low'],
            close=df['close'],
            increasing_line_color='blue',  # haussier
            decreasing_line_color='red',   # baissier
            increasing_fillcolor='white',  # corps blanc haussier
            decreasing_fillcolor='red',    # corps rouge baissier
            line_width=1.5,
            name='Chandeliers'
        )
    ])
    fig.update_layout(
        title=f'Chandeliers Japonais - {symbol}',
        xaxis_title='Date',
        yaxis_title='Prix',
        template='plotly_white',
        xaxis_rangeslider_visible=False,
        font=dict(family='Arial', size=12),
        plot_bgcolor='white',
        yaxis=dict(showgrid=True, gridcolor='#e5e5e5'),
        xaxis=dict(showgrid=True, gridcolor='#e5e5e5')
    )
    st.plotly_chart(fig, use_container_width=True)
    
    # Statistiques avec prix actuel MT5
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Prix Actuel (MT5)", f"{current_price:.5f}")
    with col2:
        if spread > 0:
            st.metric("Spread", f"{spread:.5f}")
        else:
            st.metric("Variation", f"{((current_price / df['close'].iloc[-2] - 1) * 100):.2f}%")
    with col3:
        st.metric("Dernière MAJ", f"{datetime.now().strftime('%H:%M:%S')}")
    
    # Section détection de spike en temps réel
    st.subheader("🚨 Détection de Spike en Temps Réel")
    
    try:
        from backend.spike_detector import get_realtime_spike_analysis
        
        # Analyse en temps réel
        realtime_analysis = get_realtime_spike_analysis(symbol, df, threshold=spike_threshold)
        
        if realtime_analysis:
            # Affichage de l'alerte principale
            if realtime_analysis['alert_level'] == 'HIGH':
                st.error(realtime_analysis['alert_message'])
            elif realtime_analysis['alert_level'] == 'MEDIUM':
                st.warning(realtime_analysis['alert_message'])
            else:
                st.success(realtime_analysis['alert_message'])
            
            # Détails de l'analyse
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.metric("Prix MT5", f"{realtime_analysis['current_price']:.5f}")
                st.metric("Spread", f"{realtime_analysis['spread']:.5f}")
            
            with col2:
                if realtime_analysis['spike_detection']:
                    spike = realtime_analysis['spike_detection']
                    st.metric("Type Spike", spike['spike_type'])
                    st.metric("Intensité", f"{spike['intensity']:.2f}%")
                    st.metric("Confiance", f"{spike['confidence']:.2f}")
                else:
                    st.info("Aucun spike détecté")
            
            with col3:
                if realtime_analysis['ml_prediction']:
                    ml = realtime_analysis['ml_prediction']
                    st.metric("Prédiction ML", ml['prediction'])
                    st.metric("Probabilité", f"{ml['spike_probability']:.1%}")
                else:
                    st.info("Prédiction ML non disponible")
            
            # Statut du marché
            st.info(f"Statut du marché: {realtime_analysis['market_status']}")
            
        else:
            st.warning("Impossible de récupérer l'analyse en temps réel")
            
    except Exception as e:
        st.error(f"Erreur lors de l'analyse en temps réel: {e}")

    # === GRAPHIQUE DES FEATURES ML ===
    try:
        from backend.features import compute_features
        features = compute_features(df)
        if 'price_trend' in features.columns and 'relative_strength' in features.columns:
            st.subheader("📊 Features ML : Price Trend & Relative Strength")
            fig_feat = go.Figure()
            fig_feat.add_trace(go.Scatter(
                x=df['timestamp'],
                y=features['price_trend'],
                mode='lines+markers',
                name='Price Trend',
                line=dict(color='blue', width=2)
            ))
            fig_feat.add_trace(go.Scatter(
                x=df['timestamp'],
                y=features['relative_strength'],
                mode='lines',
                name='Relative Strength',
                line=dict(color='orange', width=2)
            ))
            fig_feat.update_layout(
                title="Features ML : Price Trend & Relative Strength",
                xaxis_title="Date",
                yaxis_title="Valeur",
                legend=dict(orientation="h"),
                template="plotly_white"
            )
            st.plotly_chart(fig_feat, use_container_width=True)
    except Exception as e:
        st.warning(f"Impossible d'afficher le graphique des features ML : {e}")

# === AJOUT DANS LA NAVIGATION PRINCIPALE ===
tabs = st.tabs(["Vue générale", "Indicateurs techniques"])
with tabs[0]:
    # ... logique existante de la vue générale ...
    pass
with tabs[1]:
    # Récupérer les données OHLC du symbole sélectionné
    # (adapter selon votre logique de récupération de df)
    df = None
    try:
        df = get_ohlc(selected_symbol, actual_selected_timeframe, candle_count)
        # Correction volume : copie tick_volume en volume si besoin
        if df is not None and 'tick_volume' in df.columns and 'volume' not in df.columns:
            df['volume'] = df['tick_volume']
    except Exception:
        st.warning("Impossible de charger les données du symbole.")
    show_indicators_tab(df, selected_symbol)
# ... code existant ...

# --- Sidebar avancée ---
st.sidebar.header('🛠️ Navigation & Fonctions avancées')

# 1. Liste dynamique de tous les symboles MT5
all_symbols = get_all_symbols()
search_query = st.sidebar.text_input('🔍 Rechercher un symbole', '', key='sidebar_search_query')
filtered_symbols = [s for s in all_symbols if search_query.upper() in s.upper()]

# 2. Favoris
if 'favorite_symbols' not in st.session_state:
    st.session_state.favorite_symbols = []
fav_col1, fav_col2 = st.sidebar.columns([3,1])
with fav_col1:
    symbol = st.selectbox('Symbole MT5', filtered_symbols, index=0 if not st.session_state.get('current_symbol') else filtered_symbols.index(st.session_state['current_symbol']) if st.session_state['current_symbol'] in filtered_symbols else 0)
with fav_col2:
    if symbol not in st.session_state.favorite_symbols:
        if st.button('⭐', help='Ajouter aux favoris'):
            st.session_state.favorite_symbols.append(symbol)
    else:
        if st.button('❌', help='Retirer des favoris'):
            st.session_state.favorite_symbols.remove(symbol)
if st.session_state.favorite_symbols:
    st.sidebar.markdown('**Favoris :**')
    for fav in st.session_state.favorite_symbols:
        if st.sidebar.button(fav, key=f'fav_{fav}'):
            symbol = fav

# 3. Multi-sélection pour comparaison
compare_symbols = st.sidebar.multiselect('Comparer plusieurs symboles', filtered_symbols, default=[symbol])
if len(compare_symbols) > 1:
    st.sidebar.info('Plusieurs graphiques seront affichés dans la vue principale.')

# 4. Export CSV
if st.sidebar.button('⬇️ Exporter historique CSV'):
    df = get_ohlc(symbol, actual_selected_timeframe, candle_count)
    csv = df.to_csv(index=False).encode('utf-8')
    st.sidebar.download_button('Télécharger CSV', csv, file_name=f'{symbol}_{actual_selected_timeframe}.csv', mime='text/csv')

# 5. Alertes personnalisées
st.sidebar.subheader('🔔 Alertes personnalisées')
alert_price = st.sidebar.number_input('Alerte prix', value=0.0, format='%.2f')
alert_vol = st.sidebar.number_input('Alerte volume', value=0.0, format='%.0f')
alert_vola = st.sidebar.number_input('Alerte volatilité (%)', value=0.0, format='%.2f')
if st.sidebar.button('Activer alertes'):
    st.session_state['alert_price'] = alert_price
    st.session_state['alert_vol'] = alert_vol
    st.session_state['alert_vola'] = alert_vola
    st.sidebar.success('Alertes activées !')

# 6. Heatmap volatilité
import plotly.express as px
vola_data = []
for s in filtered_symbols[:50]:
    try:
        df_tmp = get_ohlc(s, actual_selected_timeframe, 100)
        vola = df_tmp['close'].pct_change().std() * 100 if not df_tmp.empty else 0
    except Exception:
        vola = 0
    vola_data.append({'Symbole': s, 'Volatilité (%)': vola})
if vola_data:
    vola_df = pd.DataFrame(vola_data)
    st.sidebar.subheader('🔥 Heatmap volatilité')
    fig_vola = px.imshow([vola_df['Volatilité (%)'].values], labels=dict(x='Symbole', color='Volatilité (%)'), x=vola_df['Symbole'], y=['Volatilité'], color_continuous_scale='RdBu')
    st.sidebar.plotly_chart(fig_vola, use_container_width=True)

# 7. Vue portefeuille
if st.session_state.get('mt5_connected', False):
    st.sidebar.subheader('💼 Portefeuille MT5')
    positions = get_open_positions()
    if positions:
        for pos in positions:
            st.sidebar.write(f"{pos['symbol']} | {pos['type']} | {pos['volume']} | PnL: {pos['profit']}")
    else:
        st.sidebar.info('Aucune position ouverte.')
    st.sidebar.write('---')
    st.sidebar.write('Historique récent :')
    # Correction: fetch last 30 days of trade history and filter by symbol
    to_date = datetime.now()
    from_date = to_date - timedelta(days=30)
    trades = get_trade_history(from_date, to_date)
    # Filter trades by symbol if possible
    if trades:
        trades = [t for t in trades if hasattr(t, 'symbol') and t.symbol == symbol]
    for t in trades[-5:]:
        st.sidebar.write(f"{getattr(t, 'symbol', '')} | {getattr(t, 'type', '')} | {getattr(t, 'volume', '')} | {getattr(t, 'profit', '')}")

# 8. Backtest rapide
if st.sidebar.button('⚡ Backtest rapide'):
    st.session_state['run_backtest'] = True
    st.sidebar.success('Backtest lancé (voir résultats dans la vue principale)')

# 9. Horaires de marché et statut
try:
    info = get_symbol_info(symbol)
    st.sidebar.write(f"Heures marché : {info.get('session_deals', 'N/A')}")
    st.sidebar.write(f"Statut : {'Ouvert' if info.get('trade_mode', 0) == 0 else 'Fermé'}")
except Exception:
    st.sidebar.write('Infos marché indisponibles')

# === VUE PRINCIPALE : Affichage multi-graphiques si plusieurs symboles sélectionnés ===
if len(compare_symbols) > 1:
    st.subheader('📊 Comparaison multi-symboles')
    cols = st.columns(len(compare_symbols))
    for i, symb in enumerate(compare_symbols):
        with cols[i]:
            st.markdown(f"### {symb}")
            try:
                df = get_ohlc(symb, actual_selected_timeframe, candle_count)
                if df is not None and not df.empty:
                    fig = create_candlestick_chart(df, f"{symb} - {actual_selected_timeframe}")
                    fig = add_technical_indicators_to_chart(fig, df, ['RSI', 'MACD', 'BB'])
                    st.plotly_chart(fig, use_container_width=True)
                    # Prédiction de spike
                    from backend.spike_detector import get_realtime_spike_analysis
                    analysis = get_realtime_spike_analysis(symb, df, threshold=spike_threshold)
                    if analysis:
                        if analysis['alert_level'] == 'HIGH':
                            st.error(analysis['alert_message'])
                        elif analysis['alert_level'] == 'MEDIUM':
                            st.warning(analysis['alert_message'])
                        else:
                            st.success(analysis['alert_message'])
                        st.metric('Prix MT5', f"{analysis['current_price']:.5f}")
                        st.metric('Spread', f"{analysis['spread']:.5f}")
                        if analysis['spike_detection']:
                            st.metric('Type Spike', analysis['spike_detection']['spike_type'])
                            st.metric('Intensité', f"{analysis['spike_detection']['intensity']:.2f}%")
                            st.metric('Confiance', f"{analysis['spike_detection']['confidence']:.2f}")
                        if analysis['ml_prediction']:
                            st.metric('Prédiction ML', analysis['ml_prediction']['prediction'])
                            st.metric('Probabilité', f"{analysis['ml_prediction']['spike_probability']:.1%}")
                        st.info(f"Statut du marché: {analysis['market_status']}")
                else:
                    st.warning('Aucune donnée pour ce symbole.')
            except Exception as e:
                st.error(f"Erreur pour {symb}: {e}")
else:
    # Affichage classique pour un seul symbole (logique existante)
    # ... code existant ...
    pass
# ... existing code ...

# === Choix de la catégorie de symboles ===
symbol_categories = ['SYNTHETIC', 'COMMODITIES', 'STOCKS', 'INDICES', 'FOREX', 'CRYPTO']
selected_category = st.sidebar.selectbox('Catégorie de symboles', symbol_categories, index=0)

# === Récupération dynamique des symboles de la catégorie ===
from backend.mt5_connector import get_symbols_by_category
symbols_in_category = get_symbols_by_category(selected_category)

# === Filtre/recherche de symbole ===
symbol_search = st.sidebar.text_input('🔍 Rechercher un symbole', '', key='sidebar_symbol_search')
filtered_symbols = [s for s in symbols_in_category if symbol_search.lower() in s.lower()]

# === Affichage de la liste des symboles avec catégorie ===
st.sidebar.markdown(f"**Symboles ({selected_category})**")
for symb in filtered_symbols:
    st.sidebar.write(f"{symb} [{selected_category}]")

# ... (garder la logique de sélection de symbole, favoris, etc. en utilisant filtered_symbols)

# === Section Algorithmes de détection de spikes ===
spike_algos = {
    'ML (XGBoost)': 'Détection par modèle ML XGBoost entraîné sur les spikes.',
    'Random Forest': 'Détection par modèle Random Forest.',
    'Seuil dynamique': 'Détection par seuil de variation de prix.',
    'Hybrid ML+Seuil': 'Détection hybride ML + seuil.',
}
selected_spike_algo = st.sidebar.radio('Algorithme de détection de spikes', list(spike_algos.keys()), index=0)
st.sidebar.caption(spike_algos[selected_spike_algo])

# === Affichage dans la vue principale ===
st.markdown(f"### Algorithme de détection de spikes sélectionné : {selected_spike_algo}")
st.info(spike_algos[selected_spike_algo])

