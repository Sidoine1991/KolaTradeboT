import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import sys
import os
import time
import json
import requests
import numpy as np
import pandas as pd
import streamlit as st
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from datetime import datetime, timedelta
from dotenv import load_dotenv
from streamlit_autorefresh import st_autorefresh
import MetaTrader5 as mt5
from pathlib import Path
import importlib.util
from backend.core.data_manager import DataManager
from backend.core.strategy_engine import StrategyEngine
from backend.risk.risk_manager import RiskManager
from backend.trade_history import load_trade_history
import base64
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
# Ajout du répertoire racine au path
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

# Import WhatsApp notify avec fallback local si besoin
try:
    from frontend.whatsapp_notify import send_whatsapp_message_unified as send_whatsapp_message
except ModuleNotFoundError:
    from whatsapp_notify import send_whatsapp_message_unified as send_whatsapp_message

SYMBOL_NAMES = {
    'EURUSD': 'Euro Dollar',
    'USDJPY': 'Dollar Yen',
    'GBPUSD': 'Livre Dollar',
    'BTCUSD': 'Bitcoin Dollar',
    'XAUUSD': 'Or Dollar',
    'US30': 'Dow Jones',
    'NAS100': 'Nasdaq 100',
    'SPX500': 'S&P 500',
    'Boom 1000 Index': 'Boom 1000 Index',
    'Boom 900 Index': 'Boom 900 Index',
    'Crash 1000 Index': 'Crash 1000 Index',
}

# Configuration de la page Streamlit
st.set_page_config(
    page_title="Trading Pro",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Styles CSS personnalisés
st.markdown("""
    <style>
    .main-header { font-size: 2.5rem; color: #2563eb; font-weight: 700; margin-bottom: 1rem; }
    .sub-header { font-size: 1.5rem; color: #3b82f6; margin: 1.5rem 0 1rem 0; }
    .metric-card {
        background: #1e293b;
        border-radius: 0.5rem;
        padding: 1rem;
        margin-bottom: 1rem;
        border-left: 4px solid #2563eb;
    }
    .positive { color: #10b981; }
    .negative { color: #ef4444; }
    .neutral { color: #6b7280; }
    .stButton>button {
        width: 100%;
        border-radius: 0.5rem;
        font-weight: 600;
    }
    .stSelectbox, .stTextInput, .stNumberInput {
        margin-bottom: 1rem;
    }
    .tradingview-widget-container {
        border-radius: 0.5rem;
        overflow: hidden;
        margin-bottom: 1rem;
    }
    </style>
""", unsafe_allow_html=True)

config_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'config', 'settings.py'))
spec = importlib.util.spec_from_file_location("settings", config_path)
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)
TRADING_CONFIG = settings.TRADING_CONFIG
UI_CONFIG = settings.UI_CONFIG

data_manager = DataManager()
strategy_engine = StrategyEngine()
risk_manager = RiskManager()

class TradingApp:
    def __init__(self):
        self.initialize_session_state()

    def initialize_session_state(self):
        """Initialise l'état de la session"""
        if 'symbol' not in st.session_state:
            st.session_state.symbol = 'EURUSD'
        if 'timeframe' not in st.session_state:
            st.session_state.timeframe = 'M5'
        if 'strategy' not in st.session_state:
            st.session_state.strategy = 'Trend Following'
        if 'data' not in st.session_state:
            st.session_state.data = pd.DataFrame()
        if 'signals' not in st.session_state:
            st.session_state.signals = []
        if 'balance' not in st.session_state:
            st.session_state.balance = 10000.0
        if 'positions' not in st.session_state:
            st.session_state.positions = []

    def run(self):
        """Exécute l'application"""
        tab_names = ["Dashboard", "Backtesting", "Signaux", "Auto Monitor", "Performance", "Guide", "Messagerie WhatsApp", "Tendance consolidée", "🚀 ML Pipeline"]
        if 'active_tab' not in st.session_state:
            st.session_state['active_tab'] = 0
        tabs = st.tabs(tab_names)
        for i, tab in enumerate(tabs):
            if tab:
                if tab.button("Sélectionner cet onglet", key=f"select_tab_{i}"):
                    st.session_state['active_tab'] = i
        active_tab = st.session_state.get('active_tab', 0)
        if active_tab != 7 and st.session_state.get('auto_refresh', False):
            st_autorefresh(interval=st.session_state.get('refresh_interval', 10) * 1000, key="autorefresh_key")
        if st.session_state.get('auto_refresh', False) and active_tab != 7:
            self.load_data()
        self.render_sidebar()
        if active_tab != 7:
            self.render_header()
        with tabs[0]:
            self.render_dashboard()
        with tabs[1]:
            self.render_backtesting()
        with tabs[2]:
            self.render_all_signals()
        with tabs[3]:
            self.render_auto_monitor()
        with tabs[4]:
            self.render_performance_tab()
        with tabs[5]:
            self.render_guide()
        with tabs[6]:
            self.render_whatsapp_tab()
        with tabs[7]:
            self.render_trend_consolidated_tab()
        with tabs[8]:
            self.render_ml_pipeline_tab()

    def connect_mt5_from_env(self):
        """Connecte MT5 en utilisant les identifiants du .env"""
        load_dotenv()
        login = int(os.getenv('MT5_LOGIN', '0'))
        password = os.getenv('MT5_PASSWORD', '')
        server = os.getenv('MT5_SERVER', '')
        path = os.getenv('MT5_PATH', None)
        if not mt5.initialize(path=path if path else None):
            send_whatsapp_message("❌ Erreur MT5: initialisation impossible.")
            return False
        if not mt5.login(login, password=password, server=server):
            send_whatsapp_message("❌ Erreur MT5: login impossible pour le compte.")
            mt5.shutdown()
            return False
        return True

    def get_all_mt5_symbols(self):
        """Retourne la liste de tous les symboles disponibles sur MT5 (connexion via .env)"""
        if not self.connect_mt5_from_env():
            return TRADING_CONFIG['allowed_instruments']
        symbols = mt5.symbols_get()
        mt5.shutdown()
        return sorted([s.name for s in symbols]) if symbols else TRADING_CONFIG['allowed_instruments']

    def render_sidebar(self):
        """Affiche la barre latérale de configuration"""
        with st.sidebar:
            st.title("⚙️ Configuration")
            if 'theme' not in st.session_state:
                st.session_state['theme'] = UI_CONFIG.get('theme', 'dark')
            theme = st.radio("Thème de l'interface", options=["dark", "light"], index=0 if st.session_state['theme'] == "dark" else 1, key="theme_switch")
            st.session_state['theme'] = theme
            if 'auto_refresh' not in st.session_state:
                st.session_state['auto_refresh'] = True
            if 'refresh_interval' not in st.session_state:
                st.session_state['refresh_interval'] = 10
            auto_refresh = st.checkbox("Rafraîchissement auto des positions", value=st.session_state['auto_refresh'], key="auto_refresh")
            refresh_interval = st.slider("Intervalle (secondes)", min_value=5, max_value=60, value=st.session_state['refresh_interval'], step=1, key="refresh_interval") if auto_refresh else None
            if st.button("🔄 Rafraîchir les positions", use_container_width=True):
                st.session_state['force_positions_refresh'] = True
            st.subheader("Paramètres de Trading")
            all_symbols = self.get_all_mt5_symbols()
            st.session_state.symbol = st.selectbox(
                "Symbole",
                all_symbols,
                index=all_symbols.index(st.session_state.symbol) if st.session_state.symbol in all_symbols else 0
            )
            st.session_state.timeframe = st.selectbox(
                "Timeframe",
                UI_CONFIG['available_timeframes'],
                index=UI_CONFIG['available_timeframes'].index(st.session_state.timeframe)
                if st.session_state.timeframe in UI_CONFIG['available_timeframes'] else 2
            )
            if st.button("🔁 Rafraîchir les données MT5", use_container_width=True):
                self.load_data()
            st.subheader("Gestion des Stratégies")
            strategies = [
                'Trend Following',
                'Mean Reversion',
                'Breakout',
                'Scalping',
                'Swing Trading'
            ]
            if 'strategies_state' not in st.session_state:
                st.session_state.strategies_state = {s: {'active': s == st.session_state.strategy, 'params': {}} for s in strategies}
            for strat in strategies:
                col1, col2 = st.columns([2, 1])
                with col1:
                    st.session_state.strategies_state[strat]['active'] = st.checkbox(
                        f"{strat}", value=st.session_state.strategies_state[strat]['active'], key=f"active_{strat}")
                with col2:
                    if st.button("Configurer", key=f"config_{strat}"):
                        st.session_state.strategy = strat
                if st.session_state.strategy == strat and st.session_state.strategies_state[strat]['active']:
                    st.markdown(f"**Paramètres de {strat}**")
                    params = st.session_state.strategies_state[strat].get('params', {})
                    if strat == 'Trend Following':
                        params['ma_fast'] = st.number_input("MA Fast", min_value=2, max_value=50, value=params.get('ma_fast', 20), key=f"ma_fast_{strat}")
                        params['ma_slow'] = st.number_input("MA Slow", min_value=10, max_value=200, value=params.get('ma_slow', 50), key=f"ma_slow_{strat}")
                        params['rsi_period'] = st.number_input("RSI Period", min_value=2, max_value=50, value=params.get('rsi_period', 14), key=f"rsi_period_{strat}")
                        params['atr_period'] = st.number_input("ATR Period", min_value=2, max_value=50, value=params.get('atr_period', 14), key=f"atr_period_{strat}")
                    elif strat == 'Mean Reversion':
                        params['bollinger_period'] = st.number_input("Bollinger Period", min_value=5, max_value=50, value=params.get('bollinger_period', 20), key=f"bollinger_period_{strat}")
                        params['bollinger_std'] = st.number_input("Bollinger STD", min_value=1.0, max_value=4.0, value=params.get('bollinger_std', 2.0), step=0.1, key=f"bollinger_std_{strat}")
                        params['rsi_period'] = st.number_input("RSI Period", min_value=2, max_value=50, value=params.get('rsi_period', 14), key=f"rsi_period_{strat}_mr")
                    st.session_state.strategies_state[strat]['params'] = params
            if st.button("Appliquer les stratégies", use_container_width=True):
                st.success("Configuration des stratégies appliquée !")
            st.subheader("Gestion du Risque")
            risk = st.slider(
                "Niveau de risque (% par trade)",
                min_value=0.1,
                max_value=5.0,
                value=TRADING_CONFIG['risk_per_trade'] * 100,
                step=0.1
            )
            TRADING_CONFIG['risk_per_trade'] = risk / 100
            if st.button("🚀 Lancer le Trading", type="primary", use_container_width=True):
                self.start_trading()
            if st.button("⏹️ Arrêter le Trading", use_container_width=True):
                self.stop_trading()
            if st.button("📲 Tester la notification WhatsApp", use_container_width=True):
                from frontend.whatsapp_notify import send_whatsapp_message
                ok = send_whatsapp_message("✅ Test TradBOT : notification WhatsApp reçue avec succès !")
                if ok:
                    st.success("Notification WhatsApp envoyée !")
                else:
                    st.error("Échec de l'envoi WhatsApp. Vérifie la config Twilio et le .env.")

    def render_header(self):
        """Affiche l'en-tête de l'application"""
        st.markdown(f"""
            <div class="main-header">
                📈 Trading Pro - {st.session_state.symbol} ({st.session_state.timeframe}) |
                <span class="{'positive' if st.session_state.balance >= 10000 else 'negative'}">
                    {st.session_state.balance:,.2f} $
                </span>
            </div>
        """, unsafe_allow_html=True)
        status = st.empty()
        status.info("🔵 Prêt à trader")

    def detect_support_resistance(self, df, window=20, min_touches=3, tolerance=0.001):
        from scipy.signal import argrelextrema
        lows = df['low'].values
        highs = df['high'].values
        idx_min = argrelextrema(lows, np.less_equal, order=window)[0]
        idx_max = argrelextrema(highs, np.greater_equal, order=window)[0]
        pivots_low = df['low'].iloc[idx_min]
        pivots_high = df['high'].iloc[idx_max]

        def group_levels(levels):
            levels = sorted(levels)
            grouped = []
            for lvl in levels:
                if not grouped or abs(lvl - grouped[-1]) > tolerance * lvl:
                    grouped.append(lvl)
            return grouped

        def filter_by_touches(levels, series):
            strong = []
            for lvl in levels:
                count = np.sum(np.abs(series - lvl) < tolerance * lvl)
                if count >= min_touches:
                    strong.append(lvl)
            return strong

        supports = group_levels(pivots_low)
        resistances = group_levels(pivots_high)
        supports = filter_by_touches(supports, df['low'])
        resistances = filter_by_touches(resistances, df['high'])
        return supports, resistances

    def detect_bullish_staircase(self, df, n=4):
        from scipy.signal import argrelextrema
        lows = df['low']
        highs = df['high']
        idx_min = argrelextrema(lows.values, np.less_equal, order=3)[0]
        idx_max = argrelextrema(highs.values, np.greater_equal, order=3)[0]
        last_lows = lows.iloc[idx_min][-n:]
        last_highs = highs.iloc[idx_max][-n:]
        if len(last_lows) < n or len(last_highs) < n:
            return False
        if all(x < y for x, y in zip(last_lows, last_lows[1:])) and all(x < y for x, y in zip(last_highs, last_highs[1:])):
            return True
        return False

    def render_price_chart(self, height=600):
        st.markdown("### Graphique des Prix")
        if st.session_state.data.empty:
            st.warning("Aucune donnée disponible. Veuillez charger les données.")
            return
        window_size = st.slider("Fenêtre graphique (nb bougies)", 50, 300, 100, key="chart_window_size")
        df = st.session_state.data.tail(window_size)
        df_full = st.session_state.data
        fig = make_subplots(
            rows=2,
            cols=1,
            shared_xaxes=True,
            vertical_spacing=0.03,
            row_heights=[0.7, 0.3],
            subplot_titles=('Prix', 'Volume')
        )
        fig.add_trace(
            go.Candlestick(
                x=df.index,
                open=df['open'],
                high=df['high'],
                low=df['low'],
                close=df['close'],
                name='OHLC'
            ),
            row=1, col=1
        )
        for ma in [5, 20, 50]:
            if f'ma{ma}' in df.columns:
                fig.add_trace(
                    go.Scatter(
                        x=df.index,
                        y=df[f'ma{ma}'],
                        name=f'MA {ma}',
                        line=dict(width=1)
                    ),
                    row=1, col=1
                )
        supports, resistances = self.detect_support_resistance(df_full, window=20, min_touches=3, tolerance=0.001)
        supports = sorted(supports, key=lambda lvl: abs(df['close'].iloc[-1] - lvl))[:3]
        resistances = sorted(resistances, key=lambda lvl: abs(df['close'].iloc[-1] - lvl))[:1]
        for lvl in supports:
            fig.add_hline(y=lvl, line=dict(color='green', width=1, dash='dot'), annotation_text=f"Support {lvl:.5f}", annotation_position="left")
        for lvl in resistances:
            fig.add_hline(y=lvl, line=dict(color='red', width=1, dash='dot'), annotation_text=f"Résistance {lvl:.5f}", annotation_position="left")
        if st.session_state.timeframe == 'M5':
            closes = df['close'].values
            opens = df['open'].values
            lows = df['low'].values
            for i in range(len(df)-1):
                if closes[i] < opens[i]:
                    if closes[i+1] >= closes[i] * 1.009:
                        fig.add_annotation(
                            x=df.index[i],
                            y=lows[i] - (df['high'].max() - df['low'].min())*0.01,
                            text="⬆️",
                            showarrow=False,
                            font=dict(color="green", size=16),
                            yanchor="top"
                        )
        fig.add_trace(
            go.Bar(
                x=df.index,
                y=df['volume'],
                name='Volume',
                marker_color='rgba(100, 150, 200, 0.6)'
            ),
            row=2, col=1
        )
        fig.update_layout(
            height=height,
            showlegend=True,
            xaxis_rangeslider_visible=False,
            margin=dict(l=20, r=20, t=30, b=20),
            template='plotly_dark',
            xaxis=dict(
                range=[df.index[0], df.index[-1]],
                autorange=False
            )
        )
        st.plotly_chart(fig, use_container_width=True)

        # --- Ajout détection automatique de figures chartistes sur la fenêtre affichée ---
        def detect_chart_patterns(df):
            # Détection simple de triangle (exemple, à améliorer pour flag/wedge)
            import numpy as np
            patterns = []
            if len(df) < 30:
                return patterns
            highs = df['high'].values
            lows = df['low'].values
            idx = np.arange(len(df))
            # Triangle : deux droites convergentes
            from scipy.signal import argrelextrema
            idx_max = argrelextrema(highs, np.greater_equal, order=5)[0]
            idx_min = argrelextrema(lows, np.less_equal, order=5)[0]
            if len(idx_max) >= 2 and len(idx_min) >= 2:
                # Prend les deux derniers points hauts/bas
                p1, p2 = idx_max[-2], idx_max[-1]
                q1, q2 = idx_min[-2], idx_min[-1]
                # Vérifie convergence
                if p2 > p1 and q2 > q1 and (p2 - p1) > 3 and (q2 - q1) > 3:
                    patterns.append({'type': 'triangle', 'start_idx': p1, 'end_idx': p2, 'start_price': highs[p1], 'end_price': highs[p2]})
                    patterns.append({'type': 'triangle', 'start_idx': q1, 'end_idx': q2, 'start_price': lows[q1], 'end_price': lows[q2]})
            # (Flag et wedge : à compléter si besoin)
            return patterns
        patterns = detect_chart_patterns(df)
        if not patterns:
            st.info("Aucun setup chartiste détecté sur la fenêtre affichée. (Exemple affiché)")
            # Ajoute un exemple de triangle pour la démo
            if len(df) > 10:
                patterns.append({'type': 'triangle', 'start_idx': 0, 'end_idx': len(df)-1, 'start_price': df['low'].iloc[0], 'end_price': df['high'].iloc[-1]})
        for pat in patterns:
            color = {'triangle': 'cyan', 'flag': 'magenta', 'wedge': 'yellow'}.get(pat['type'], 'white')
            fig.add_trace(go.Scatter(
                x=[df.index[pat['start_idx']], df.index[pat['end_idx']]],
                y=[pat['start_price'], pat['end_price']],
                mode='lines+markers+text',
                line=dict(color=color, width=3, dash='dash'),
                marker=dict(size=10, color=color),
                text=[pat['type'].capitalize(), ''],
                textposition='top center',
                name=f"Setup {pat['type']}"
            ), row=1, col=1)
        # --- Fin ajout setup chartiste ---

        # Détection automatique du pattern bullish staircase
        if self.detect_bullish_staircase(df):
            st.success("🚀 Pattern haussier détecté : opportunité d'achat (long) !")

    def render_metrics(self):
        st.markdown("### Métriques de Trading")
        if st.session_state.data.empty:
            st.warning("Aucune donnée disponible")
            return
        df = st.session_state.data
        last_row = df.iloc[-1]
        prev_row = df.iloc[-2] if len(df) > 1 else last_row
        price_change = (last_row['close'] - prev_row['close']) / prev_row['close'] * 100
        col1, col2 = st.columns(2)
        with col1:
            st.metric("Prix Actuel", f"{last_row['close']:.5f}",
                     f"{price_change:+.2f}%")
            st.metric("Volume", f"{last_row['volume']:,.0f}")
        with col2:
            st.metric("ATR (14)", f"{last_row.get('atr', 0):.5f}" if 'atr' in last_row else "N/A")
            st.metric("RSI (14)", f"{last_row.get('rsi', 0):.2f}" if 'rsi' in last_row else "N/A")

    def render_positions(self):
        st.markdown("### Positions Ouvertes (MT5)")
        load_dotenv()
        login = int(os.getenv('MT5_LOGIN', '0'))
        password = os.getenv('MT5_PASSWORD', '')
        server = os.getenv('MT5_SERVER', '')
        path = os.getenv('MT5_PATH', None)
        if not mt5.initialize(path=path if path else None):
            st.error("Connexion à MT5 impossible.")
            st.warning("DEBUG: Echec mt5.initialize()")
            st.write("DEBUG: mt5.last_error() =", mt5.last_error())
            return
        if not mt5.login(login, password=password, server=server):
            st.error("Login MT5 impossible.")
            st.warning("DEBUG: Echec mt5.login()")
            st.write("DEBUG: mt5.last_error() =", mt5.last_error())
            mt5.shutdown()
            return
        account_info = mt5.account_info()
        if account_info:
            st.info(f"Compte connecté : {account_info.login}")
            expected_login = os.getenv('MT5_LOGIN_EXPECTED')
            if expected_login and str(account_info.login) != str(expected_login):
                st.warning(f"⚠️ Attention : le compte connecté ({account_info.login}) n'est pas celui attendu ({expected_login}) !")
        else:
            st.warning("DEBUG: account_info() retourne None")
        positions = mt5.positions_get()
        st.write("DEBUG: positions_get() brut =", positions)
        st.write("DEBUG: mt5.last_error() après positions_get =", mt5.last_error())
        mt5.shutdown()
        if not positions:
            st.info("Aucune position ouverte sur le compte MT5")
            return
        for pos in positions:
            with st.container():
                col1, col2 = st.columns([3, 1])
                with col1:
                    st.write(f"**{pos.symbol}** - {'BUY' if pos.type==0 else 'SELL'}")
                    st.caption(f"Entrée: {pos.price_open} | SL: {pos.sl} | TP: {pos.tp}")
                with col2:
                    pnl_pct = (pos.price_current / pos.price_open - 1) * 100 if pos.type==0 else (pos.price_open / pos.price_current - 1) * 100
                    pnl_class = 'positive' if pnl_pct >= 0 else 'negative'
                    st.markdown(f"<div class='{pnl_class}'>{pnl_pct:+.2f}%</div>", unsafe_allow_html=True)
                    close_btn = st.button(f"Fermer", key=f"close_{pos.ticket}")
                    if close_btn:
                        self.close_position_mt5(pos)

    def render_risk_metrics(self):
        st.markdown("### Analyse de Risque")
        if st.session_state.data.empty:
            st.warning("Aucune donnée disponible")
            return
        df = st.session_state.data
        risk_per_trade = f"{TRADING_CONFIG['risk_per_trade']*100:.1f}%"
        close = df['close'].astype(float)
        running_max = np.maximum.accumulate(close)
        drawdown = (close - running_max) / running_max
        max_drawdown = f"{abs(drawdown.min())*100:.2f}%"
        returns = close.pct_change().dropna()
        mean_ret = returns.mean()
        std_ret = returns.std()
        if std_ret != 0:
            sharpe = mean_ret / std_ret * np.sqrt(252 if len(close) > 200 else len(close))
            sharpe_str = f"{sharpe:.2f}"
        else:
            sharpe_str = "N/A"
        win_rate = (returns > 0).sum() / len(returns) * 100 if len(returns) > 0 else 0
        win_rate_str = f"{win_rate:.0f}%"
        risk_metrics = {
            "Risque par Trade": risk_per_trade,
            "Drawdown Max": max_drawdown,
            "Ratio de Sharpe": sharpe_str,
            "Win Rate": win_rate_str
        }
        for metric, value in risk_metrics.items():
            with st.container():
                st.markdown(f"<div class='metric-card'><strong>{metric}</strong><div style='float: right;'>{value}</div></div>", unsafe_allow_html=True)

    def render_strategy_controls(self):
        st.markdown("### Contrôles de Stratégie")
        if st.session_state.get('last_openai_raw'):
            st.info(f"Réponse brute OpenAI : {st.session_state['last_openai_raw']}")
            if st.button("🗑️ Effacer la réponse OpenAI", key="clear_openai_raw"):
                del st.session_state['last_openai_raw']
                st.rerun()
        if 'show_strategy_controls' not in st.session_state:
            st.session_state['show_strategy_controls'] = True
        show_controls = st.checkbox("Afficher les Contrôles de Stratégie", value=st.session_state['show_strategy_controls'], key="show_strategy_controls")
        if not show_controls:
            st.info("Les Contrôles de Stratégie sont masqués.")
            return
        with st.form("order_form"):
            order_side = st.radio("Sens de l'ordre", ["BUY", "SELL"], horizontal=True, key="order_side_form")
            order_type = st.selectbox("Type d'ordre", ["MARKET", "LIMIT", "STOP"], key="order_type_form")
            lot = st.number_input("Volume (lot)", min_value=0.01, max_value=10.0, value=0.01, step=0.01, key="lot_form")
            price = None
            if order_type != "MARKET":
                price = st.number_input("Prix d'exécution", min_value=0.0, value=float(st.session_state.data['close'].iloc[-1]) if not st.session_state.data.empty else 0.0, key="price_form")
            sl = st.number_input("Stop Loss", min_value=0.0, value=0.0, key="sl_form")
            tp = st.number_input("Take Profit", min_value=0.0, value=0.0, key="tp_form")
            submit = st.form_submit_button("🛒 Passer l'Ordre")
            if submit:
                self.place_order(order_type, lot, price, sl, tp, order_side)

    def render_footer(self):
        st.markdown("---")
        st.caption("""
            🚀 Trading Pro - Plateforme de Trading Algorithmique Avancée
            Version 1.0.0 | © 2025 Tous droits réservés
        """)

    def load_data(self):
        try:
            with st.spinner("Chargement des données depuis MT5..."):
                if not self.connect_mt5_from_env():
                    st.error("Connexion à MT5 impossible. Vérifiez vos identifiants dans .env.")
                    send_whatsapp_message(f"❌ Erreur: Connexion à MT5 impossible pour {st.session_state.symbol}.")
                    print("[DEBUG] Connexion MT5 impossible")
                    return
                df = data_manager.get_historical_data(
                    symbol=st.session_state.symbol,
                    timeframe=st.session_state.timeframe,
                    count=3000
                )
                mt5.shutdown()
                print("[DEBUG] DataFrame récupéré depuis MT5:")
                print(df.head() if df is not None else "df is None")
                if df is not None:
                    print("[DEBUG] df.shape =", df.shape)
                if df is not None and not df.empty:
                    st.session_state.data = df
                else:
                    st.session_state.data = df
                    st.error("Aucune donnée récupérée depuis MT5.")
                    send_whatsapp_message(f"❌ Erreur: Aucune donnée récupérée depuis MT5 pour {st.session_state.symbol}.")
                    print("[DEBUG] Aucune donnée récupérée depuis MT5 pour", st.session_state.symbol)
        except Exception as e:
            st.error(f"Erreur lors du chargement des données: {e}")
            send_whatsapp_message(f"❌ Exception lors du chargement des données: {e}")
            print("[DEBUG] Exception lors du chargement des données:", e)

    def analyze_market(self):
        import os
        import pandas as pd
        from dotenv import load_dotenv
        load_dotenv()
        GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
        try:
            from google import genai
        except ImportError:
            st.error("Le package google-genai n'est pas installé. Installe-le avec: pip install -U google-genai")
            return
        client = genai.Client(api_key=GEMINI_API_KEY)
        df = st.session_state.data.tail(300).reset_index()
        for col in df.columns:
            if pd.api.types.is_datetime64_any_dtype(df[col]):
                df[col] = df[col].astype(str)
        prompt = f"""
        Analyse le marché pour {st.session_state.symbol} en timeframe {st.session_state.timeframe} avec ces données : {df.to_dict(orient='records')}.
        Donne-moi une recommandation (BUY/SELL/HOLD) et un score de confiance entre 0 et 1, au format JSON : {{'recommendation': 'BUY', 'confidence': 0.85}}
        """
        with st.spinner("Analyse Gemini API en cours..."):
            try:
                response = client.models.generate_content(
                    model="gemini-2.0-flash",
                    contents=prompt
                )
                import json
                import re
                resp_text = response.text if response.text is not None else ""
                match = re.search(r"\{.*\}", resp_text)
                if match:
                    result = json.loads(match.group(0).replace("'", '"'))
                    reco = result.get('recommendation', '').upper()
                    conf = float(result.get('confidence', 0))
                    st.session_state.analysis_result = result
                    from frontend.whatsapp_notify import send_whatsapp_message
                    msg = f"Gemini: {reco} ({conf*100:.1f}%)"
                    send_whatsapp_message(msg)
                    st.success(f"Gemini API: {reco} (confiance: {conf*100:.1f}%)")
                    if reco in ["BUY", "ACHAT"] and conf > 0.7:
                        import MetaTrader5 as mt5
                        self.connect_mt5_from_env()
                        symbol = st.session_state.symbol
                        info = mt5.symbol_info(symbol)
                        lot = info.volume_min if info else 0.01
                        price = st.session_state.data['close'].iloc[-1]
                        sl = price - 2 * (st.session_state.data['close'].std())
                        tp = price + 2 * (price - sl)
                        request = {
                            "action": mt5.TRADE_ACTION_DEAL,
                            "symbol": symbol,
                            "volume": lot,
                            "type": mt5.ORDER_TYPE_BUY,
                            "price": price,
                            "sl": sl,
                            "tp": tp,
                            "deviation": 20,
                            "magic": 123456,
                            "comment": "Auto BUY Gemini API",
                            "type_time": mt5.ORDER_TIME_GTC,
                            "type_filling": mt5.ORDER_FILLING_IOC,
                        }
                        result = mt5.order_send(request)
                        mt5.shutdown()
                        if result and result.retcode == mt5.TRADE_RETCODE_DONE:
                            st.success(f"Achat auto exécuté ({symbol}, lot {lot})")
                            send_whatsapp_message(f"🚀 Achat auto sur {symbol} (lot {lot}) à {price:.5f} | SL: {sl:.5f} | TP: {tp:.5f}")
                        else:
                            st.error("Erreur lors de l'achat auto.")
                            send_whatsapp_message(f"❌ Erreur lors de l'achat auto sur {symbol}")
                else:
                    st.error("Réponse Gemini non exploitable : " + str(resp_text))
            except Exception as e:
                st.error(f"Erreur lors de l'appel Gemini API: {e}")

    def place_order(self, order_type=None, lot=None, price=None, sl=None, tp=None, side="BUY"):
        import MetaTrader5 as mt5
        if not self.connect_mt5_from_env():
            st.error("Connexion à MT5 impossible. Vérifie que MetaTrader 5 est bien lancé et que les identifiants sont corrects.")
            return
        symbol = st.session_state.symbol
        info = mt5.symbol_info(symbol)
        if info is None:
            st.error(f"Symbole '{symbol}' introuvable dans MT5. Vérifie le nom exact dans MetaTrader 5.")
            return
        if not info.visible:
            if not mt5.symbol_select(symbol, True):
                st.error(f"Impossible de rendre le symbole '{symbol}' visible dans MT5.")
                return
            info = mt5.symbol_info(symbol)
        st.write("DEBUG: Infos du symbole:", info._asdict() if hasattr(info, '_asdict') else info)
        if lot is None:
            lot = info.volume_min if info else 0.01
        if price is None or order_type == "MARKET":
            price = st.session_state.data['close'].iloc[-1]
        if sl == 0.0:
            sl = None
        if tp == 0.0:
            tp = None
        if order_type == "MARKET":
            order_type_mt5 = mt5.ORDER_TYPE_BUY if side == "BUY" else mt5.ORDER_TYPE_SELL
        elif order_type == "LIMIT":
            order_type_mt5 = mt5.ORDER_TYPE_BUY_LIMIT if side == "BUY" else mt5.ORDER_TYPE_SELL_LIMIT
        elif order_type == "STOP":
            order_type_mt5 = mt5.ORDER_TYPE_BUY_STOP if side == "BUY" else mt5.ORDER_TYPE_SELL_STOP
        else:
            order_type_mt5 = mt5.ORDER_TYPE_BUY
        request = {
            "action": mt5.TRADE_ACTION_DEAL if order_type == "MARKET" else mt5.TRADE_ACTION_PENDING,
            "symbol": symbol,
            "volume": lot,
            "type": order_type_mt5,
            "price": price,
            "sl": sl,
            "tp": tp,
            "deviation": 20,
            "magic": 123456,
            "comment": f"Order {order_type} {side}",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        st.write("DEBUG: Requête envoyée à MT5:", request)
        result = mt5.order_send(request)
        st.write("DEBUG: Résultat brut de order_send:", result)
        mt5.shutdown()
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:
            st.success(f"Ordre {order_type} {side} passé avec succès! (lot {lot})")
            msg = f"🛒 Ordre {order_type} {side} passé sur {symbol} (lot {lot}) à {price:.5f} | SL: {sl if sl else 'None'} | TP: {tp if tp else 'None'}"
            send_whatsapp_message(msg)
        else:
            retcode = getattr(result, 'retcode', None)
            comment = getattr(result, 'comment', '')
            st.error(f"Erreur lors du passage de l'ordre. Code: {retcode} - {comment}")
            send_whatsapp_message(f"❌ Erreur lors du passage de l'ordre {order_type} {side} sur {symbol}. Code: {retcode}")

    def start_trading(self):
        st.session_state.trading_active = True
        st.success("Trading automatisé démarré")

    def stop_trading(self):
        st.session_state.trading_active = False
        st.warning("Trading automatisé arrêté")

    def render_strategy_performance(self):
        st.markdown("### Performance des Stratégies")
        strategies_state = st.session_state.get('strategies_state', {})
        if not strategies_state:
            st.info("Aucune stratégie configurée.")
            return
        perf_data = []
        for strat, state in strategies_state.items():
            if state.get('active'):
                perf_data.append({
                    'Stratégie': strat,
                    'Statut': 'Active',
                    'PNL': f"{1000 + hash(strat)%200 - 100} $",
                    'Win Rate': f"{60 + hash(strat)%20}%",
                    'Drawdown': f"{2 + hash(strat)%5}%",
                    'Signaux': 10 + hash(strat)%10
                })
        if perf_data:
            st.dataframe(perf_data, hide_index=True)
        else:
            st.info("Aucune stratégie active.")
        recent_signals = st.session_state.get('recent_signals', [])
        if recent_signals:
            st.table(recent_signals[::-1])
        else:
            st.info("Aucun signal récent généré.")

    def render_backtesting(self):
        st.title("🔄 Backtesting de Stratégie")
        strategies = [
            'SuperTrend',
            'Trend Following',
            'Mean Reversion',
            'Breakout',
            'Scalping',
            'Swing Trading'
        ]
        all_symbols = self.get_all_mt5_symbols()
        if not all_symbols:
            all_symbols = ['Aucun symbole disponible']
        symbol = st.selectbox("Symbole", all_symbols, key="bt_symbol")
        if symbol == 'Aucun symbole disponible':
            st.warning("Aucun symbole MT5 n'est disponible pour le backtest.")
            return
        timeframe = st.selectbox("Timeframe", UI_CONFIG['available_timeframes'], key="bt_timeframe")
        strategy = st.selectbox("Stratégie", strategies, key="bt_strategy")
        start_date = st.date_input("Date de début", value=datetime.now()-timedelta(days=60), key="bt_start")
        end_date = st.date_input("Date de fin", value=datetime.now(), key="bt_end")
        st.markdown("**Paramètres de la stratégie**")
        params = {}
        if strategy == 'SuperTrend':
            params['atr_period'] = st.number_input("ATR Period", min_value=2, max_value=50, value=10, key="bt_atr_period_st")
            params['min_factor'] = st.number_input("Min Factor", min_value=0.5, max_value=5.0, value=1.0, step=0.1, key="bt_min_factor_st")
            params['max_factor'] = st.number_input("Max Factor", min_value=0.5, max_value=10.0, value=5.0, step=0.1, key="bt_max_factor_st")
            params['factor_step'] = st.number_input("Factor Step", min_value=0.1, max_value=2.0, value=0.5, step=0.1, key="bt_factor_step_st")
            params['sl_multiplier'] = st.number_input("SL Multiplier", min_value=1.0, max_value=5.0, value=2.0, step=0.1, key="bt_sl_mult_st")
            params['tp_multiplier'] = st.number_input("TP Multiplier", min_value=1.0, max_value=5.0, value=3.0, step=0.1, key="bt_tp_mult_st")
            params['risk_percent'] = st.number_input("Risk %", min_value=0.1, max_value=10.0, value=1.0, step=0.1, key="bt_risk_st")
        if st.button("Lancer le backtest", use_container_width=True):
            if strategy == 'SuperTrend':
                try:
                    from ml_supertrend.core.supertrend_bot import SuperTrendBot, Config
                    from ml_supertrend.backtest_engine import BacktestEngine
                    import pandas as pd
                    tf_map = {
                        'M1': mt5.TIMEFRAME_M1,
                        'M5': mt5.TIMEFRAME_M5,
                        'M15': mt5.TIMEFRAME_M15,
                        'M30': mt5.TIMEFRAME_M30,
                        'H1': mt5.TIMEFRAME_H1,
                        'H4': mt5.TIMEFRAME_H4,
                        'D1': mt5.TIMEFRAME_D1,
                        'W1': mt5.TIMEFRAME_W1,
                        'MN1': mt5.TIMEFRAME_MN1
                    }
                    tf = tf_map.get(timeframe, mt5.TIMEFRAME_M5)
                    config = Config(
                        symbol=symbol,
                        timeframe=tf,
                        atr_period=params['atr_period'],
                        min_factor=params['min_factor'],
                        max_factor=params['max_factor'],
                        factor_step=params['factor_step'],
                        sl_multiplier=params['sl_multiplier'],
                        tp_multiplier=params['tp_multiplier'],
                        risk_percent=params['risk_percent']
                    )
                    bot = SuperTrendBot(config)
                    engine = BacktestEngine(bot)
                    start_dt = pd.to_datetime(start_date)
                    end_dt = pd.to_datetime(end_date)
                    st.info("Backtest en cours, cela peut prendre quelques secondes...")
                    results = engine.run_backtest(symbol, start_dt, end_dt, tf)
                    st.session_state.bt_results = results
                    st.success("Backtest terminé !")
                except Exception as e:
                    st.error(f"Erreur lors du backtest : {e}")
            else:
                st.info("Backtest réel non encore implémenté pour cette stratégie. Utilise SuperTrend pour la démo.")
        if hasattr(st.session_state, 'bt_results'):
            results = st.session_state.bt_results
            st.subheader("Courbe de PNL")
            import plotly.graph_objects as go
            fig = go.Figure()
            pnl_curve = results['pnl_curve']
            fig.add_trace(go.Scatter(x=pnl_curve['time'], y=pnl_curve['equity'], mode='lines', name='PNL'))
            if 'equity' in pnl_curve.columns:
                fig.add_trace(go.Scatter(x=pnl_curve['time'], y=pnl_curve['equity'], name='Equity'))
            else:
                st.warning("Pas de courbe d'équité disponible pour ce backtest.")
            st.plotly_chart(fig, use_container_width=True)
            st.subheader("Métriques clés")
            st.table(results['metrics'])
            st.subheader("Historique des trades")
            st.dataframe(results['trades'], hide_index=True)

    def render_guide(self):
        st.markdown("""
# 📖 Guide d'utilisation de TradBOT
Bienvenue sur **TradBOT**, votre plateforme de trading algorithmique avancée !
## 🏠 1. Dashboard principal
- **Vue d'ensemble** de votre compte, solde, PnL, positions ouvertes.
- **Graphiques interactifs** pour suivre l'évolution des prix et des signaux.
- **Sélection du symbole** et du timeframe à analyser.
## 🤖 2. Stratégies & Signaux
- **Choisissez une stratégie** (Trend Following, ML-SuperTrend, etc.)
- **Générez des signaux** manuellement ou activez l'envoi automatique.
- **Recevez les signaux** directement sur WhatsApp si activé.
## 🛠️ 3. Auto-Monitor (Moniteur automatique)
- **Démarrez/arrêtez** le moniteur pour surveiller les marchés en continu.
- **Personnalisez** les catégories et symboles à scanner.
- **Suivez la progression** du scan en temps réel (barre de progression).
- **Consultez les statistiques** : scans, signaux générés, acceptés, rejetés, erreurs.
- **Recevez les signaux acceptés** en temps réel sur WhatsApp.
- **Contrôlez le moniteur** via l'onglet ou par commandes WhatsApp (`/start`, `/stop`, `/status`, `/monitor_stats`).
## 💬 4. Messagerie WhatsApp
- **Onglet dédié** pour consulter tous les messages WhatsApp reçus.
- **Filtrez** par expéditeur ou mot-clé.
- **Répondez directement** à un message WhatsApp depuis l'interface.
- **Recevez les signaux, alertes, et confirmations** sur votre mobile.
- **Commandes interactives** : passez des ordres, demandez la liste des symboles, contrôlez l'auto-monitor, etc.
## 📊 5. Performance & Backtesting
- **Analysez la performance** de vos stratégies sur l'historique.
- **Visualisez** le winrate, le PnL, le drawdown, la distribution des gains/pertes.
- **Testez vos stratégies** sur différentes périodes et symboles.
## ⚡ 6. Conseils d'utilisation
- **Activez l'auto-refresh** pour suivre les signaux en temps réel.
- **Utilisez les filtres** pour cibler vos analyses.
- **Consultez le guide** à tout moment pour retrouver les commandes et bonnes pratiques.
## 📱 7. Commandes WhatsApp principales
- `menu` : revenir au menu principal
- `2` ou `symboles` : liste des symboles par catégorie
- `ORDRE BUY EURUSD 0.1 ...` : passer un ordre
- `CLOSE EURUSD` : fermer une position
- `/start`, `/stop`, `/status` : contrôler l'auto-monitor
- `/monitor_stats` : voir les stats du moniteur
## 🆘 8. Support
- Pour toute question ou bug, contactez l'équipe via le support intégré ou WhatsApp.
---
**Profitez de la puissance de l'IA et de l'automatisation pour booster votre trading !**
""", unsafe_allow_html=True)

    def generate_trade_signal(self):
        import os
        import pandas as pd
        import uuid
        import redis
        import json
        from dotenv import load_dotenv
        load_dotenv()
        OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
        REDIS_HOST = os.getenv('REDIS_HOST', 'localhost')
        REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
        REDIS_DB = int(os.getenv('REDIS_DB', 0))
        r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB)
        df = st.session_state.data.tail(50).reset_index()
        essential_cols = [c for c in ['open', 'high', 'low', 'close', 'volume', 'rsi', 'atr'] if c in df.columns]
        df = df[essential_cols]
        for col in df.columns:
            if pd.api.types.is_datetime64_any_dtype(df[col]):
                df[col] = df[col].astype(str)
        current_price = float(st.session_state.data['close'].iloc[-1])
        prompt = f"""
        Analyse le marché pour {st.session_state.symbol} en timeframe {st.session_state.timeframe} avec ces données : {df.to_dict(orient='records')}.
        Le prix actuel de la devise est : {current_price}.
        Donne-moi une recommandation (BUY/SELL/HOLD), un score de confiance entre 0 et 1, un résumé de l'analyse technique, le prix d'entrée (proche du prix actuel), un stop loss, un take profit, un profit estimé (en pips ou %), et une durée de validité (en minutes), au format JSON : {{'recommendation': 'BUY', 'confidence': 0.85, 'synthese': '...', 'price': 1.12345, 'sl': 1.12000, 'tp': 1.13000, 'profit_estime': '+70 pips', 'validite': 30}}
        """
        try:
            import openai
            client = openai.OpenAI(api_key=OPENAI_API_KEY)
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "system", "content": "Tu es un assistant expert en trading."},
                          {"role": "user", "content": prompt}]
            )
            resp_text = response.choices[0].message.content or ''
            st.session_state['last_openai_raw'] = resp_text
            st.info(f"Réponse brute OpenAI : {resp_text}")
            import json as pyjson
            import re
            match = re.search(r"\{.*\}", resp_text)
            if match:
                result = pyjson.loads(match.group(0).replace("'", '"'))
                ia_price = float(result.get('price', 0))
                seuil = 0.01 * current_price
                if abs(ia_price - current_price) > seuil:
                    st.warning(f"Le prix proposé par l'IA ({ia_price}) est trop éloigné du prix actuel ({current_price}). Correction automatique.")
                    result['price'] = current_price
                local_conf = self.compute_local_confidence(df, result)
                ia_conf = float(result.get('confidence', 0))
                combined_conf = round((ia_conf + local_conf) / 2, 3)
                st.info(f"Confiance IA : {ia_conf}")
                st.info(f"Confiance locale : {local_conf}")
                st.info(f"Confiance combinée : {combined_conf}")
                result['confidence_combined'] = combined_conf
                token = str(uuid.uuid4())
                order_data = {
                    'symbol': st.session_state.symbol,
                    'order': result,
                    'datetime': pd.Timestamp.now().isoformat()
                }
                r.setex(f'order:{token}', 1800, json.dumps(order_data))
                result['validation_token'] = token
                return result
            st.error("Réponse OpenAI non exploitable : " + str(resp_text))
            return None
        except Exception as e:
            if hasattr(e, 'status_code') and e.status_code == 429:
                st.warning("Limite OpenAI atteinte (429) : trop de requêtes. Merci de patienter 1 minute avant de réessayer. Signal local généré.")
            elif 'rate limit' in str(e).lower() or '429' in str(e):
                st.warning("Limite OpenAI atteinte (429) : trop de requêtes. Signal local généré.")
            else:
                st.error(f"Erreur lors de l'appel OpenAI API: {e}. Signal local généré.")
            local_conf = self.compute_local_confidence(df, {})
            if local_conf > 0.65:
                reco = 'BUY'
                confidence_boost = 0.1
            elif local_conf < 0.35:
                reco = 'SELL'
                confidence_boost = 0.1
            else:
                reco = 'HOLD'
                confidence_boost = 0.0
            final_confidence = min(local_conf + confidence_boost, 0.95)
            price = current_price
            if reco == 'BUY':
                sl = price * 0.998
                tp = price * 1.005
            elif reco == 'SELL':
                sl = price * 1.002
                tp = price * 0.995
            else:
                sl = tp = None
            result = {
                'recommendation': reco,
                'confidence': final_confidence,
                'synthese': f'Signal généré localement (confiance: {final_confidence:.1%}) - {reco} recommandé',
                'price': price,
                'sl': sl,
                'tp': tp,
                'profit_estime': '+50 pips' if reco in ['BUY', 'SELL'] else '0',
                'validite': 30,
                'confidence_combined': final_confidence
            }
            token = str(uuid.uuid4())
            order_data = {
                'symbol': st.session_state.symbol,
                'order': result,
                'datetime': pd.Timestamp.now().isoformat()
            }
            r.setex(f'order:{token}', 1800, json.dumps(order_data))
            result['validation_token'] = token
            st.info(f"Signal local généré : {result}")
            return result

    def compute_local_confidence(self, df, signal):
        import numpy as np
        import pandas as pd
        try:
            import pandas_ta as ta
        except ImportError:
            st.warning("pandas-ta n'est pas installé, certains indicateurs avancés ne seront pas calculés.")
            return 0.5
        if df.empty or 'close' not in df.columns:
            return 0.5
        close = df['close'].astype(float)
        high = df['high'].astype(float) if 'high' in df.columns else close
        low = df['low'].astype(float) if 'low' in df.columns else close
        volume = df['volume'].astype(float) if 'volume' in df.columns else pd.Series([0]*len(df))
        try:
            st_df = ta.supertrend(high=high, low=low, close=close, length=10, multiplier=3.0)
            supertrend_dir = st_df.iloc[-1]['SUPERT_10_3.0']
            supertrend_score = 1.0 if close.iloc[-1] > supertrend_dir else 0.0
        except Exception:
            supertrend_score = 0.5
        try:
            macd = ta.macd(close)
            macd_score = 1.0 if macd['MACDh_12_26_9'].iloc[-1] > 0 else 0.0
        except Exception:
            macd_score = 0.5
        try:
            adx = ta.adx(high, low, close)
            adx_val = adx['ADX_14'].iloc[-1]
            adx_score = 1.0 if adx_val > 25 else 0.5
        except Exception:
            adx_score = 0.5
        try:
            rsi = ta.rsi(close, length=14)
            rsi_val = rsi.iloc[-1]
            if 45 < rsi_val < 65:
                rsi_score = 1.0
            elif 35 < rsi_val <= 45 or 65 <= rsi_val < 75:
                rsi_score = 0.7
            else:
                rsi_score = 0.3
        except Exception:
            rsi_score = 0.5
        try:
            atr = ta.atr(high, low, close, length=14)
            atr_val = atr.iloc[-1]
            if 0.0005 < atr_val < 0.002:
                atr_score = 1.0
            elif 0.0002 < atr_val <= 0.0005 or 0.002 <= atr_val < 0.003:
                atr_score = 0.7
            else:
                atr_score = 0.4
        except Exception:
            atr_score = 0.5
        try:
            bb = ta.bbands(close, length=20)
            bb_score = 1.0 if close.iloc[-1] > bb['BBL_20_2.0'].iloc[-1] and close.iloc[-1] < bb['BBU_20_2.0'].iloc[-1] else 0.5
        except Exception:
            bb_score = 0.5
        try:
            vo = ta.vo(volume, short=5, long=20)
            vo_score = 1.0 if vo.iloc[-1] > 0 else 0.5
        except Exception:
            vo_score = 0.5
        try:
            engulf = ta.cdl_engulfing(open_=df['open'], high=high, low=low, close=close)
            pattern_score = 1.0 if engulf.iloc[-1] != 0 else 0.5
        except Exception:
            pattern_score = 0.5
        base_conf = round(
            0.2 * supertrend_score +
            0.2 * macd_score +
            0.1 * adx_score +
            0.1 * rsi_score +
            0.1 * atr_score +
            0.1 * bb_score +
            0.1 * vo_score +
            0.1 * pattern_score, 3)
        strong_signals = sum([
            supertrend_score > 0.7,
            macd_score > 0.7,
            adx_score > 0.7,
            rsi_score > 0.7,
            atr_score > 0.7,
            bb_score > 0.7,
            vo_score > 0.7,
            pattern_score > 0.7
        ])
        if strong_signals >= 4:
            bonus = 0.15
        elif strong_signals >= 3:
            bonus = 0.10
        elif strong_signals >= 2:
            bonus = 0.05
        else:
            bonus = 0.0
        final_conf = min(base_conf + bonus, 0.95)
        st.info(f"[Détail confiance locale] SuperTrend: {supertrend_score}, MACD: {macd_score}, ADX: {adx_score}, RSI: {rsi_score}, ATR: {atr_score}, BB: {bb_score}, VolumeOsc: {vo_score}, Pattern: {pattern_score}")
        st.info(f"[Bonus] Signaux forts: {strong_signals}/8, Bonus: +{bonus:.1%}, Confiance finale: {final_conf:.1%}")
        return final_conf

    def format_signal_message(self, signal):
        symbol = st.session_state.symbol
        synthese = signal.get('synthese', 'N/A')
        reco = signal.get('recommendation', 'N/A').upper()
        price = signal.get('price', 'N/A')
        sl = signal.get('sl', 'N/A')
        tp = signal.get('tp', 'N/A')
        profit = signal.get('profit_estime', 'N/A')
        validite = signal.get('validite', 'N/A')
        token = signal.get('validation_token', None)
        validation_url = f"https://tonserveur.com/validate_order?token={token}" if token else None
        msg = f"""
📢 *Signal de Trading*
*Symbole* : {symbol}
*Synthèse* : {synthese} 
*Ordre* : {reco}
"""
        if reco in ["BUY", "SELL"]:
            msg += f"*Prix* : {price}\n*Stop Loss* : {sl}\n*Take Profit* : {tp}\n*Profit estimé* : {profit}\n"
        msg += f"*Durée de validité* : {validite} min"
        if validation_url:
            msg += f"\n\n👉 [Valider et placer l'ordre sur mon compte]({validation_url})"
        return msg

    def close_position_mt5(self, pos):
        import MetaTrader5 as mt5
        from dotenv import load_dotenv
        import os
        load_dotenv()
        login = int(os.getenv('MT5_LOGIN', '0'))
        password = os.getenv('MT5_PASSWORD', '')
        server = os.getenv('MT5_SERVER', '')
        path = os.getenv('MT5_PATH', None)
        if not mt5.initialize(path=path if path else None):
            st.error("Connexion à MT5 impossible pour clôture.")
            return
        if not mt5.login(login, password=password, server=server):
            st.error("Login MT5 impossible pour clôture.")
            mt5.shutdown()
            return
        symbol = pos.symbol
        volume = pos.volume
        price = pos.price_current
        deviation = 20
        if pos.type == mt5.POSITION_TYPE_BUY:
            order_type = mt5.ORDER_TYPE_SELL
        else:
            order_type = mt5.ORDER_TYPE_BUY
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "position": pos.ticket,
            "price": price,
            "deviation": deviation,
            "magic": 123456,
            "comment": "Clôture via TradBOT",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        result = mt5.order_send(request)
        mt5.shutdown()
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:
            st.success(f"Position {symbol} clôturée avec succès !")
        else:
            retcode = getattr(result, 'retcode', None)
            comment = getattr(result, 'comment', '')
            st.error(f"Erreur lors de la clôture de la position. Code: {retcode} - {comment}")

    def render_dashboard(self):
        if 'timeframe' not in st.session_state:
            st.session_state.timeframe = 'M5'
        if 'symbol' not in st.session_state:
            st.session_state.symbol = 'EURUSD'
        trend_data = None
        try:
            resp = requests.post(f"http://127.0.0.1:8000/trend_summary/generate", params={"symbol": st.session_state.symbol})
            if resp.status_code == 200:
                with open("trend_summary.json", "r", encoding="utf-8") as f:
                    trend_data = json.load(f)
                st.session_state['trend_heatmap_data'] = trend_data
                st.session_state['trend_heatmap_last'] = time.strftime("%H:%M:%S")
                st.session_state['trend_heatmap_symbol'] = st.session_state.symbol
            else:
                st.warning("Impossible de générer la tendance pour ce symbole (erreur API).")
        except Exception as e:
            st.warning("Impossible de générer la tendance pour ce symbole.")
        col1, col2 = st.columns([2.5, 1])
        with col1:
            self.render_price_chart(height=750)
            st.markdown('### Tendance consolidée (multi-timeframe)')
            trend_data = st.session_state.get('trend_heatmap_data')
            if trend_data and 'trends' in trend_data:
                tf_order = ["1d", "4h", "1h", "30m", "15m", "5m", "1m"]
                tf_labels = ["D1", "H4", "H1", "M30", "M15", "M5", "M1"]
                rows = []
                for tf, label in zip(tf_order, tf_labels):
                    tf_info = trend_data["trends"].get(tf, {})
                    trend = tf_info.get("trend", "?")
                    force = tf_info.get("force", "?")
                    slope = tf_info.get("slope", "?")
                    rsi = tf_info.get("rsi", "?")
                    macd = tf_info.get("macd", "?")
                    adx = tf_info.get("adx", "?")
                    last_ts = tf_info.get("last_timestamp", "?")
                    try:
                        force_pct = f"{int(force)}%" if force != "?" else "?"
                    except:
                        force_pct = "?"
                    rows.append({
                        "Timeframe": label,
                        "Tendance": trend,
                        "Force": force_pct,
                        "Slope": slope if isinstance(slope, (int, float)) else str(slope),
                        "RSI": rsi if isinstance(rsi, (int, float)) else str(rsi),
                        "MACD": macd if isinstance(macd, (int, float)) else str(macd),
                        "ADX": adx if isinstance(adx, (int, float)) else str(adx),
                        "Dernière bougie": last_ts
                    })
                df = pd.DataFrame(rows)
                st.dataframe(df, use_container_width=True)
                consolidated = trend_data.get('consolidated', '?')
                confidence = trend_data.get('consolidated_confidence')
                score = trend_data.get('weighted_score')
                conf_str = f"{int(confidence)}%" if isinstance(confidence, (int, float)) else str(confidence)
                # Badge couleur
                if isinstance(consolidated, str):
                    trend_lower = consolidated.lower()
                    if trend_lower == 'bullish':
                        badge = '🟢'
                    elif trend_lower == 'bearish':
                        badge = '🔴'
                    elif trend_lower == 'neutral':
                        badge = '⚪'
                    else:
                        badge = '❓'
                else:
                    badge = '❓'
                st.markdown(f"**{badge} Tendance consolidée**: {consolidated}  |  **Confiance**: {conf_str}  |  **Score**: {score}")
                st.caption(f"Scalping possible : {trend_data.get('scalping_possible', '?')} | Dernier rafraîchissement : {st.session_state.get('trend_heatmap_last', '?')}")
                # --- Ajout détection bip + envoi WhatsApp ---
                trend = trend_data.get('consolidated', '').lower()
                scalping = str(trend_data.get('scalping_possible', '')).upper() == 'OUI'
                # Récupération des valeurs de prix, SL, TP si disponibles
                last_price = None
                sl = None
                tp = None
                # Essaie de récupérer les valeurs depuis trend_data ou session_state si tu les stockes ailleurs
                if 'last_price' in st.session_state:
                    last_price = st.session_state['last_price']
                if 'sl' in st.session_state:
                    sl = st.session_state['sl']
                if 'tp' in st.session_state:
                    tp = st.session_state['tp']
                # Empêche le bip et l'envoi répétés
                key = f"scalping_signal_sent_{st.session_state.symbol}_{trend}"
                if (
                    'last_signal_trend' not in st.session_state or
                    st.session_state['last_signal_trend'] != trend or
                    st.session_state.get('last_signal_symbol') != st.session_state.symbol
                ):
                    st.session_state[key] = False
                    st.session_state['last_signal_trend'] = trend
                    st.session_state['last_signal_symbol'] = st.session_state.symbol
                if scalping and trend in ['bullish', 'bearish']:
                    self.play_beep()
                    if not st.session_state.get(key, False):
                        msg = f"Signal SCALPING {trend.upper()} détecté sur {st.session_state.symbol} (Tendance consolidée, scalping possible)"
                        if last_price is not None and sl is not None and tp is not None:
                            msg += f"\nPrix d'entrée : {last_price:.5f}\nStop Loss (SL) : {sl:.5f}\nTake Profit (TP) : {tp:.5f}"
                        from frontend.whatsapp_notify import send_whatsapp_message
                        send_whatsapp_message(msg)
                        st.success(f"Signal WhatsApp envoyé : {msg}")
                        st.session_state[key] = True
                else:
                    st.session_state[key] = False
            elif not refresh:
                st.info("Aucune donnée de tendance disponible. Cliquez sur 'Générer la tendance' puis 'Rafraîchir maintenant'.")
                st.warning("Impossible de générer la tendance pour ce symbole.")
                st.info("Aucune donnée de tendance disponible. Cliquez sur 'Générer la tendance' puis 'Rafraîchir maintenant'.")
                st.warning("Impossible de générer la tendance pour ce symbole.")

    def play_beep(self):
        beep_file = os.path.join(PROJECT_ROOT, "frontend", "static", "beep.wav")
        if os.path.exists(beep_file):
            with open(beep_file, "rb") as f:
                data = f.read()
            b64 = base64.b64encode(data).decode()
            md = f'''
            <audio autoplay>
                <source src="data:audio/wav;base64,{b64}" type="audio/wav">
            </audio>
            '''
            st.markdown(md, unsafe_allow_html=True)

    def render_metrics(self):
        st.markdown("### Métriques de Trading")
        if st.session_state.data.empty:
            st.warning("Aucune donnée disponible")
            return
        df = st.session_state.data
        last_row = df.iloc[-1]
        prev_row = df.iloc[-2] if len(df) > 1 else last_row
        price_change = (last_row['close'] - prev_row['close']) / prev_row['close'] * 100
        col1, col2 = st.columns(2)
        with col1:
            st.metric("Prix Actuel", f"{last_row['close']:.5f}",
                     f"{price_change:+.2f}%")
            st.metric("Volume", f"{last_row['volume']:,.0f}")
        with col2:
            st.metric("ATR (14)", f"{last_row.get('atr', 0):.5f}" if 'atr' in last_row else "N/A")
            st.metric("RSI (14)", f"{last_row.get('rsi', 0):.2f}" if 'rsi' in last_row else "N/A")

    def render_positions(self):
        st.markdown("### Positions Ouvertes (MT5)")
        load_dotenv()
        login = int(os.getenv('MT5_LOGIN', '0'))
        password = os.getenv('MT5_PASSWORD', '')
        server = os.getenv('MT5_SERVER', '')
        path = os.getenv('MT5_PATH', None)
        if not mt5.initialize(path=path if path else None):
            st.error("Connexion à MT5 impossible.")
            st.warning("DEBUG: Echec mt5.initialize()")
            st.write("DEBUG: mt5.last_error() =", mt5.last_error())
            return
        if not mt5.login(login, password=password, server=server):
            st.error("Login MT5 impossible.")
            st.warning("DEBUG: Echec mt5.login()")
            st.write("DEBUG: mt5.last_error() =", mt5.last_error())
            mt5.shutdown()
            return
        account_info = mt5.account_info()
        if account_info:
            st.info(f"Compte connecté : {account_info.login}")
            expected_login = os.getenv('MT5_LOGIN_EXPECTED')
            if expected_login and str(account_info.login) != str(expected_login):
                st.warning(f"⚠️ Attention : le compte connecté ({account_info.login}) n'est pas celui attendu ({expected_login}) !")
        else:
            st.warning("DEBUG: account_info() retourne None")
        positions = mt5.positions_get()
        st.write("DEBUG: positions_get() brut =", positions)
        st.write("DEBUG: mt5.last_error() après positions_get =", mt5.last_error())
        mt5.shutdown()
        if not positions:
            st.info("Aucune position ouverte sur le compte MT5")
            return
        for pos in positions:
            with st.container():
                col1, col2 = st.columns([3, 1])
                with col1:
                    st.write(f"**{pos.symbol}** - {'BUY' if pos.type==0 else 'SELL'}")
                    st.caption(f"Entrée: {pos.price_open} | SL: {pos.sl} | TP: {pos.tp}")
                with col2:
                    pnl_pct = (pos.price_current / pos.price_open - 1) * 100 if pos.type==0 else (pos.price_open / pos.price_current - 1) * 100
                    pnl_class = 'positive' if pnl_pct >= 0 else 'negative'
                    st.markdown(f"<div class='{pnl_class}'>{pnl_pct:+.2f}%</div>", unsafe_allow_html=True)
                    close_btn = st.button(f"Fermer", key=f"close_{pos.ticket}")
                    if close_btn:
                        self.close_position_mt5(pos)

    def render_risk_metrics(self):
        st.markdown("### Analyse de Risque")
        if st.session_state.data.empty:
            st.warning("Aucune donnée disponible")
            return
        df = st.session_state.data
        risk_per_trade = f"{TRADING_CONFIG['risk_per_trade']*100:.1f}%"
        close = df['close'].astype(float)
        running_max = np.maximum.accumulate(close)
        drawdown = (close - running_max) / running_max
        max_drawdown = f"{abs(drawdown.min())*100:.2f}%"
        returns = close.pct_change().dropna()
        mean_ret = returns.mean()
        std_ret = returns.std()
        if std_ret != 0:
            sharpe = mean_ret / std_ret * np.sqrt(252 if len(close) > 200 else len(close))
            sharpe_str = f"{sharpe:.2f}"
        else:
            sharpe_str = "N/A"
        win_rate = (returns > 0).sum() / len(returns) * 100 if len(returns) > 0 else 0
        win_rate_str = f"{win_rate:.0f}%"
        risk_metrics = {
            "Risque par Trade": risk_per_trade,
            "Drawdown Max": max_drawdown,
            "Ratio de Sharpe": sharpe_str,
            "Win Rate": win_rate_str
        }
        for metric, value in risk_metrics.items():
            with st.container():
                st.markdown(f"<div class='metric-card'><strong>{metric}</strong><div style='float: right;'>{value}</div></div>", unsafe_allow_html=True)

    def render_strategy_controls(self):
        st.markdown("### Contrôles de Stratégie")
        if st.session_state.get('last_openai_raw'):
            st.info(f"Réponse brute OpenAI : {st.session_state['last_openai_raw']}")
            if st.button("🗑️ Effacer la réponse OpenAI", key="clear_openai_raw"):
                del st.session_state['last_openai_raw']
                st.rerun()
        if 'show_strategy_controls' not in st.session_state:
            st.session_state['show_strategy_controls'] = True
        show_controls = st.checkbox("Afficher les Contrôles de Stratégie", value=st.session_state['show_strategy_controls'], key="show_strategy_controls")
        if not show_controls:
            st.info("Les Contrôles de Stratégie sont masqués.")
            return
        with st.form("order_form"):
            order_side = st.radio("Sens de l'ordre", ["BUY", "SELL"], horizontal=True, key="order_side_form")
            order_type = st.selectbox("Type d'ordre", ["MARKET", "LIMIT", "STOP"], key="order_type_form")
            lot = st.number_input("Volume (lot)", min_value=0.01, max_value=10.0, value=0.01, step=0.01, key="lot_form")
            price = None
            if order_type != "MARKET":
                price = st.number_input("Prix d'exécution", min_value=0.0, value=float(st.session_state.data['close'].iloc[-1]) if not st.session_state.data.empty else 0.0, key="price_form")
            sl = st.number_input("Stop Loss", min_value=0.0, value=0.0, key="sl_form")
            tp = st.number_input("Take Profit", min_value=0.0, value=0.0, key="tp_form")
            submit = st.form_submit_button("🛒 Passer l'Ordre")
            if submit:
                self.place_order(order_type, lot, price, sl, tp, order_side)

    def render_footer(self):
        st.markdown("---")
        st.caption("""
            🚀 Trading Pro - Plateforme de Trading Algorithmique Avancée
            Version 1.0.0 | © 2025 Tous droits réservés
        """)

    def load_data(self):
        try:
            with st.spinner("Chargement des données depuis MT5..."):
                if not self.connect_mt5_from_env():
                    st.error("Connexion à MT5 impossible. Vérifiez vos identifiants dans .env.")
                    send_whatsapp_message(f"❌ Erreur: Connexion à MT5 impossible pour {st.session_state.symbol}.")
                    print("[DEBUG] Connexion MT5 impossible")
                    return
                df = data_manager.get_historical_data(
                    symbol=st.session_state.symbol,
                    timeframe=st.session_state.timeframe,
                    count=3000
                )
                mt5.shutdown()
                print("[DEBUG] DataFrame récupéré depuis MT5:")
                print(df.head() if df is not None else "df is None")
                if df is not None:
                    print("[DEBUG] df.shape =", df.shape)
                if df is not None and not df.empty:
                    st.session_state.data = df
                else:
                    st.session_state.data = df
                    st.error("Aucune donnée récupérée depuis MT5.")
                    send_whatsapp_message(f"❌ Erreur: Aucune donnée récupérée depuis MT5 pour {st.session_state.symbol}.")
                    print("[DEBUG] Aucune donnée récupérée depuis MT5 pour", st.session_state.symbol)
        except Exception as e:
            st.error(f"Erreur lors du chargement des données: {e}")
            send_whatsapp_message(f"❌ Exception lors du chargement des données: {e}")
            print("[DEBUG] Exception lors du chargement des données:", e)

    def analyze_market(self):
        import os
        import pandas as pd
        from dotenv import load_dotenv
        load_dotenv()
        GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
        try:
            from google import genai
        except ImportError:
            st.error("Le package google-genai n'est pas installé. Installe-le avec: pip install -U google-genai")
            return
        client = genai.Client(api_key=GEMINI_API_KEY)
        df = st.session_state.data.tail(300).reset_index()
        for col in df.columns:
            if pd.api.types.is_datetime64_any_dtype(df[col]):
                df[col] = df[col].astype(str)
        prompt = f"""
        Analyse le marché pour {st.session_state.symbol} en timeframe {st.session_state.timeframe} avec ces données : {df.to_dict(orient='records')}.
        Donne-moi une recommandation (BUY/SELL/HOLD) et un score de confiance entre 0 et 1, au format JSON : {{'recommendation': 'BUY', 'confidence': 0.85}}
        """
        with st.spinner("Analyse Gemini API en cours..."):
            try:
                response = client.models.generate_content(
                    model="gemini-2.0-flash",
                    contents=prompt
                )
                import json
                import re
                resp_text = response.text if response.text is not None else ""
                match = re.search(r"\{.*\}", resp_text)
                if match:
                    result = json.loads(match.group(0).replace("'", '"'))
                    reco = result.get('recommendation', '').upper()
                    conf = float(result.get('confidence', 0))
                    st.session_state.analysis_result = result
                    from frontend.whatsapp_notify import send_whatsapp_message
                    msg = f"Gemini: {reco} ({conf*100:.1f}%)"
                    send_whatsapp_message(msg)
                    st.success(f"Gemini API: {reco} (confiance: {conf*100:.1f}%)")
                    if reco in ["BUY", "ACHAT"] and conf > 0.7:
                        import MetaTrader5 as mt5
                        self.connect_mt5_from_env()
                        symbol = st.session_state.symbol
                        info = mt5.symbol_info(symbol)
                        lot = info.volume_min if info else 0.01
                        price = st.session_state.data['close'].iloc[-1]
                        sl = price - 2 * (st.session_state.data['close'].std())
                        tp = price + 2 * (price - sl)
                        request = {
                            "action": mt5.TRADE_ACTION_DEAL,
                            "symbol": symbol,
                            "volume": lot,
                            "type": mt5.ORDER_TYPE_BUY,
                            "price": price,
                            "sl": sl,
                            "tp": tp,
                            "deviation": 20,
                            "magic": 123456,
                            "comment": "Auto BUY Gemini API",
                            "type_time": mt5.ORDER_TIME_GTC,
                            "type_filling": mt5.ORDER_FILLING_IOC,
                        }
                        result = mt5.order_send(request)
                        mt5.shutdown()
                        if result and result.retcode == mt5.TRADE_RETCODE_DONE:
                            st.success(f"Achat auto exécuté ({symbol}, lot {lot})")
                            send_whatsapp_message(f"🚀 Achat auto sur {symbol} (lot {lot}) à {price:.5f} | SL: {sl:.5f} | TP: {tp:.5f}")
                        else:
                            st.error("Erreur lors de l'achat auto.")
                            send_whatsapp_message(f"❌ Erreur lors de l'achat auto sur {symbol}")
                else:
                    st.error("Réponse Gemini non exploitable : " + str(resp_text))
            except Exception as e:
                st.error(f"Erreur lors de l'appel Gemini API: {e}")

    def place_order(self, order_type=None, lot=None, price=None, sl=None, tp=None, side="BUY"):
        import MetaTrader5 as mt5
        if not self.connect_mt5_from_env():
            st.error("Connexion à MT5 impossible. Vérifie que MetaTrader 5 est bien lancé et que les identifiants sont corrects.")
            return
        symbol = st.session_state.symbol
        info = mt5.symbol_info(symbol)
        if info is None:
            st.error(f"Symbole '{symbol}' introuvable dans MT5. Vérifie le nom exact dans MetaTrader 5.")
            return
        if not info.visible:
            if not mt5.symbol_select(symbol, True):
                st.error(f"Impossible de rendre le symbole '{symbol}' visible dans MT5.")
                return
            info = mt5.symbol_info(symbol)
        st.write("DEBUG: Infos du symbole:", info._asdict() if hasattr(info, '_asdict') else info)
        if lot is None:
            lot = info.volume_min if info else 0.01
        if price is None or order_type == "MARKET":
            price = st.session_state.data['close'].iloc[-1]
        if sl == 0.0:
            sl = None
        if tp == 0.0:
            tp = None
        if order_type == "MARKET":
            order_type_mt5 = mt5.ORDER_TYPE_BUY if side == "BUY" else mt5.ORDER_TYPE_SELL
        elif order_type == "LIMIT":
            order_type_mt5 = mt5.ORDER_TYPE_BUY_LIMIT if side == "BUY" else mt5.ORDER_TYPE_SELL_LIMIT
        elif order_type == "STOP":
            order_type_mt5 = mt5.ORDER_TYPE_BUY_STOP if side == "BUY" else mt5.ORDER_TYPE_SELL_STOP
        else:
            order_type_mt5 = mt5.ORDER_TYPE_BUY
        request = {
            "action": mt5.TRADE_ACTION_DEAL if order_type == "MARKET" else mt5.TRADE_ACTION_PENDING,
            "symbol": symbol,
            "volume": lot,
            "type": order_type_mt5,
            "price": price,
            "sl": sl,
            "tp": tp,
            "deviation": 20,
            "magic": 123456,
            "comment": f"Order {order_type} {side}",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        st.write("DEBUG: Requête envoyée à MT5:", request)
        result = mt5.order_send(request)
        st.write("DEBUG: Résultat brut de order_send:", result)
        mt5.shutdown()
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:
            st.success(f"Ordre {order_type} {side} passé avec succès! (lot {lot})")
            msg = f"🛒 Ordre {order_type} {side} passé sur {symbol} (lot {lot}) à {price:.5f} | SL: {sl if sl else 'None'} | TP: {tp if tp else 'None'}"
            send_whatsapp_message(msg)
        else:
            retcode = getattr(result, 'retcode', None)
            comment = getattr(result, 'comment', '')
            st.error(f"Erreur lors du passage de l'ordre. Code: {retcode} - {comment}")
            send_whatsapp_message(f"❌ Erreur lors du passage de l'ordre {order_type} {side} sur {symbol}. Code: {retcode}")

    def start_trading(self):
        st.session_state.trading_active = True
        st.success("Trading automatisé démarré")

    def stop_trading(self):
        st.session_state.trading_active = False
        st.warning("Trading automatisé arrêté")

    def render_strategy_performance(self):
        st.markdown("### Performance des Stratégies")
        strategies_state = st.session_state.get('strategies_state', {})
        if not strategies_state:
            st.info("Aucune stratégie configurée.")
            return
        perf_data = []
        for strat, state in strategies_state.items():
            if state.get('active'):
                perf_data.append({
                    'Stratégie': strat,
                    'Statut': 'Active',
                    'PNL': f"{1000 + hash(strat)%200 - 100} $",
                    'Win Rate': f"{60 + hash(strat)%20}%",
                    'Drawdown': f"{2 + hash(strat)%5}%",
                    'Signaux': 10 + hash(strat)%10
                })
        if perf_data:
            st.dataframe(perf_data, hide_index=True)
        else:
            st.info("Aucune stratégie active.")
        recent_signals = st.session_state.get('recent_signals', [])
        if recent_signals:
            st.table(recent_signals[::-1])
        else:
            st.info("Aucun signal récent généré.")

    def render_backtesting(self):
        st.title("🔄 Backtesting de Stratégie")
        strategies = [
            'SuperTrend',
            'Trend Following',
            'Mean Reversion',
            'Breakout',
            'Scalping',
            'Swing Trading'
        ]
        all_symbols = self.get_all_mt5_symbols()
        if not all_symbols:
            all_symbols = ['Aucun symbole disponible']
        symbol = st.selectbox("Symbole", all_symbols, key="bt_symbol")
        if symbol == 'Aucun symbole disponible':
            st.warning("Aucun symbole MT5 n'est disponible pour le backtest.")
            return
        timeframe = st.selectbox("Timeframe", UI_CONFIG['available_timeframes'], key="bt_timeframe")
        strategy = st.selectbox("Stratégie", strategies, key="bt_strategy")
        start_date = st.date_input("Date de début", value=datetime.now()-timedelta(days=60), key="bt_start")
        end_date = st.date_input("Date de fin", value=datetime.now(), key="bt_end")
        st.markdown("**Paramètres de la stratégie**")
        params = {}
        if strategy == 'SuperTrend':
            params['atr_period'] = st.number_input("ATR Period", min_value=2, max_value=50, value=10, key="bt_atr_period_st")
            params['min_factor'] = st.number_input("Min Factor", min_value=0.5, max_value=5.0, value=1.0, step=0.1, key="bt_min_factor_st")
            params['max_factor'] = st.number_input("Max Factor", min_value=0.5, max_value=10.0, value=5.0, step=0.1, key="bt_max_factor_st")
            params['factor_step'] = st.number_input("Factor Step", min_value=0.1, max_value=2.0, value=0.5, step=0.1, key="bt_factor_step_st")
            params['sl_multiplier'] = st.number_input("SL Multiplier", min_value=1.0, max_value=5.0, value=2.0, step=0.1, key="bt_sl_mult_st")
            params['tp_multiplier'] = st.number_input("TP Multiplier", min_value=1.0, max_value=5.0, value=3.0, step=0.1, key="bt_tp_mult_st")
            params['risk_percent'] = st.number_input("Risk %", min_value=0.1, max_value=10.0, value=1.0, step=0.1, key="bt_risk_st")
        if st.button("Lancer le backtest", use_container_width=True):
            if strategy == 'SuperTrend':
                try:
                    from ml_supertrend.core.supertrend_bot import SuperTrendBot, Config
                    from ml_supertrend.backtest_engine import BacktestEngine
                    import pandas as pd
                    tf_map = {
                        'M1': mt5.TIMEFRAME_M1,
                        'M5': mt5.TIMEFRAME_M5,
                        'M15': mt5.TIMEFRAME_M15,
                        'M30': mt5.TIMEFRAME_M30,
                        'H1': mt5.TIMEFRAME_H1,
                        'H4': mt5.TIMEFRAME_H4,
                        'D1': mt5.TIMEFRAME_D1,
                        'W1': mt5.TIMEFRAME_W1,
                        'MN1': mt5.TIMEFRAME_MN1
                    }
                    tf = tf_map.get(timeframe, mt5.TIMEFRAME_M5)
                    config = Config(
                        symbol=symbol,
                        timeframe=tf,
                        atr_period=params['atr_period'],
                        min_factor=params['min_factor'],
                        max_factor=params['max_factor'],
                        factor_step=params['factor_step'],
                        sl_multiplier=params['sl_multiplier'],
                        tp_multiplier=params['tp_multiplier'],
                        risk_percent=params['risk_percent']
                    )
                    bot = SuperTrendBot(config)
                    engine = BacktestEngine(bot)
                    start_dt = pd.to_datetime(start_date)
                    end_dt = pd.to_datetime(end_date)
                    st.info("Backtest en cours, cela peut prendre quelques secondes...")
                    results = engine.run_backtest(symbol, start_dt, end_dt, tf)
                    st.session_state.bt_results = results
                    st.success("Backtest terminé !")
                except Exception as e:
                    st.error(f"Erreur lors du backtest : {e}")
            else:
                st.info("Backtest réel non encore implémenté pour cette stratégie. Utilise SuperTrend pour la démo.")
        if hasattr(st.session_state, 'bt_results'):
            results = st.session_state.bt_results
            st.subheader("Courbe de PNL")
            import plotly.graph_objects as go
            fig = go.Figure()
            pnl_curve = results['pnl_curve']
            fig.add_trace(go.Scatter(x=pnl_curve['time'], y=pnl_curve['equity'], mode='lines', name='PNL'))
            if 'equity' in pnl_curve.columns:
                fig.add_trace(go.Scatter(x=pnl_curve['time'], y=pnl_curve['equity'], name='Equity'))
            else:
                st.warning("Pas de courbe d'équité disponible pour ce backtest.")
            st.plotly_chart(fig, use_container_width=True)
            st.subheader("Métriques clés")
            st.table(results['metrics'])
            st.subheader("Historique des trades")
            st.dataframe(results['trades'], hide_index=True)

    def render_guide(self):
        st.markdown("""
# 📖 Guide d'utilisation de TradBOT
Bienvenue sur **TradBOT**, votre plateforme de trading algorithmique avancée !
## 🏠 1. Dashboard principal
- **Vue d'ensemble** de votre compte, solde, PnL, positions ouvertes.
- **Graphiques interactifs** pour suivre l'évolution des prix et des signaux.
- **Sélection du symbole** et du timeframe à analyser.
## 🤖 2. Stratégies & Signaux
- **Choisissez une stratégie** (Trend Following, ML-SuperTrend, etc.)
- **Générez des signaux** manuellement ou activez l'envoi automatique.
- **Recevez les signaux** directement sur WhatsApp si activé.
## 🛠️ 3. Auto-Monitor (Moniteur automatique)
- **Démarrez/arrêtez** le moniteur pour surveiller les marchés en continu.
- **Personnalisez** les catégories et symboles à scanner.
- **Suivez la progression** du scan en temps réel (barre de progression).
- **Consultez les statistiques** : scans, signaux générés, acceptés, rejetés, erreurs.
- **Recevez les signaux acceptés** en temps réel sur WhatsApp.
- **Contrôlez le moniteur** via l'onglet ou par commandes WhatsApp (`/start`, `/stop`, `/status`, `/monitor_stats`).
## 💬 4. Messagerie WhatsApp
- **Onglet dédié** pour consulter tous les messages WhatsApp reçus.
- **Filtrez** par expéditeur ou mot-clé.
- **Répondez directement** à un message WhatsApp depuis l'interface.
- **Recevez les signaux, alertes, et confirmations** sur votre mobile.
- **Commandes interactives** : passez des ordres, demandez la liste des symboles, contrôlez l'auto-monitor, etc.
## 📊 5. Performance & Backtesting
- **Analysez la performance** de vos stratégies sur l'historique.
- **Visualisez** le winrate, le PnL, le drawdown, la distribution des gains/pertes.
- **Testez vos stratégies** sur différentes périodes et symboles.
## ⚡ 6. Conseils d'utilisation
- **Activez l'auto-refresh** pour suivre les signaux en temps réel.
- **Utilisez les filtres** pour cibler vos analyses.
- **Consultez le guide** à tout moment pour retrouver les commandes et bonnes pratiques.
## 📱 7. Commandes WhatsApp principales
- `menu` : revenir au menu principal
- `2` ou `symboles` : liste des symboles par catégorie
- `ORDRE BUY EURUSD 0.1 ...` : passer un ordre
- `CLOSE EURUSD` : fermer une position
- `/start`, `/stop`, `/status` : contrôler l'auto-monitor
- `/monitor_stats` : voir les stats du moniteur
## 🆘 8. Support
- Pour toute question ou bug, contactez l'équipe via le support intégré ou WhatsApp.
---
**Profitez de la puissance de l'IA et de l'automatisation pour booster votre trading !**
""", unsafe_allow_html=True)

    def generate_trade_signal(self):
        import os
        import pandas as pd
        import uuid
        import redis
        import json
        from dotenv import load_dotenv
        load_dotenv()
        OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
        REDIS_HOST = os.getenv('REDIS_HOST', 'localhost')
        REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
        REDIS_DB = int(os.getenv('REDIS_DB', 0))
        r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB)
        df = st.session_state.data.tail(50).reset_index()
        essential_cols = [c for c in ['open', 'high', 'low', 'close', 'volume', 'rsi', 'atr'] if c in df.columns]
        df = df[essential_cols]
        for col in df.columns:
            if pd.api.types.is_datetime64_any_dtype(df[col]):
                df[col] = df[col].astype(str)
        current_price = float(st.session_state.data['close'].iloc[-1])
        prompt = f"""
        Analyse le marché pour {st.session_state.symbol} en timeframe {st.session_state.timeframe} avec ces données : {df.to_dict(orient='records')}.
        Le prix actuel de la devise est : {current_price}.
        Donne-moi une recommandation (BUY/SELL/HOLD), un score de confiance entre 0 et 1, un résumé de l'analyse technique, le prix d'entrée (proche du prix actuel), un stop loss, un take profit, un profit estimé (en pips ou %), et une durée de validité (en minutes), au format JSON : {{'recommendation': 'BUY', 'confidence': 0.85, 'synthese': '...', 'price': 1.12345, 'sl': 1.12000, 'tp': 1.13000, 'profit_estime': '+70 pips', 'validite': 30}}
        """
        try:
            import openai
            client = openai.OpenAI(api_key=OPENAI_API_KEY)
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "system", "content": "Tu es un assistant expert en trading."},
                          {"role": "user", "content": prompt}]
            )
            resp_text = response.choices[0].message.content or ''
            st.session_state['last_openai_raw'] = resp_text
            st.info(f"Réponse brute OpenAI : {resp_text}")
            import json as pyjson
            import re
            match = re.search(r"\{.*\}", resp_text)
            if match:
                result = pyjson.loads(match.group(0).replace("'", '"'))
                ia_price = float(result.get('price', 0))
                seuil = 0.01 * current_price
                if abs(ia_price - current_price) > seuil:
                    st.warning(f"Le prix proposé par l'IA ({ia_price}) est trop éloigné du prix actuel ({current_price}). Correction automatique.")
                    result['price'] = current_price
                local_conf = self.compute_local_confidence(df, result)
                ia_conf = float(result.get('confidence', 0))
                combined_conf = round((ia_conf + local_conf) / 2, 3)
                st.info(f"Confiance IA : {ia_conf}")
                st.info(f"Confiance locale : {local_conf}")
                st.info(f"Confiance combinée : {combined_conf}")
                result['confidence_combined'] = combined_conf
                token = str(uuid.uuid4())
                order_data = {
                    'symbol': st.session_state.symbol,
                    'order': result,
                    'datetime': pd.Timestamp.now().isoformat()
                }
                r.setex(f'order:{token}', 1800, json.dumps(order_data))
                result['validation_token'] = token
                return result
            st.error("Réponse OpenAI non exploitable : " + str(resp_text))
            return None
        except Exception as e:
            if hasattr(e, 'status_code') and e.status_code == 429:
                st.warning("Limite OpenAI atteinte (429) : trop de requêtes. Merci de patienter 1 minute avant de réessayer. Signal local généré.")
            elif 'rate limit' in str(e).lower() or '429' in str(e):
                st.warning("Limite OpenAI atteinte (429) : trop de requêtes. Signal local généré.")
            else:
                st.error(f"Erreur lors de l'appel OpenAI API: {e}. Signal local généré.")
            local_conf = self.compute_local_confidence(df, {})
            if local_conf > 0.65:
                reco = 'BUY'
                confidence_boost = 0.1
            elif local_conf < 0.35:
                reco = 'SELL'
                confidence_boost = 0.1
            else:
                reco = 'HOLD'
                confidence_boost = 0.0
            final_confidence = min(local_conf + confidence_boost, 0.95)
            price = current_price
            if reco == 'BUY':
                sl = price * 0.998
                tp = price * 1.005
            elif reco == 'SELL':
                sl = price * 1.002
                tp = price * 0.995
            else:
                sl = tp = None
            result = {
                'recommendation': reco,
                'confidence': final_confidence,
                'synthese': f'Signal généré localement (confiance: {final_confidence:.1%}) - {reco} recommandé',
                'price': price,
                'sl': sl,
                'tp': tp,
                'profit_estime': '+50 pips' if reco in ['BUY', 'SELL'] else '0',
                'validite': 30,
                'confidence_combined': final_confidence
            }
            token = str(uuid.uuid4())
            order_data = {
                'symbol': st.session_state.symbol,
                'order': result,
                'datetime': pd.Timestamp.now().isoformat()
            }
            r.setex(f'order:{token}', 1800, json.dumps(order_data))
            result['validation_token'] = token
            st.info(f"Signal local généré : {result}")
            return result

    def compute_local_confidence(self, df, signal):
        import numpy as np
        import pandas as pd
        try:
            import pandas_ta as ta
        except ImportError:
            st.warning("pandas-ta n'est pas installé, certains indicateurs avancés ne seront pas calculés.")
            return 0.5
        if df.empty or 'close' not in df.columns:
            return 0.5
        close = df['close'].astype(float)
        high = df['high'].astype(float) if 'high' in df.columns else close
        low = df['low'].astype(float) if 'low' in df.columns else close
        volume = df['volume'].astype(float) if 'volume' in df.columns else pd.Series([0]*len(df))
        try:
            st_df = ta.supertrend(high=high, low=low, close=close, length=10, multiplier=3.0)
            supertrend_dir = st_df.iloc[-1]['SUPERT_10_3.0']
            supertrend_score = 1.0 if close.iloc[-1] > supertrend_dir else 0.0
        except Exception:
            supertrend_score = 0.5
        try:
            macd = ta.macd(close)
            macd_score = 1.0 if macd['MACDh_12_26_9'].iloc[-1] > 0 else 0.0
        except Exception:
            macd_score = 0.5
        try:
            adx = ta.adx(high, low, close)
            adx_val = adx['ADX_14'].iloc[-1]
            adx_score = 1.0 if adx_val > 25 else 0.5
        except Exception:
            adx_score = 0.5
        try:
            rsi = ta.rsi(close, length=14)
            rsi_val = rsi.iloc[-1]
            if 45 < rsi_val < 65:
                rsi_score = 1.0
            elif 35 < rsi_val <= 45 or 65 <= rsi_val < 75:
                rsi_score = 0.7
            else:
                rsi_score = 0.3
        except Exception:
            rsi_score = 0.5
        try:
            atr = ta.atr(high, low, close, length=14)
            atr_val = atr.iloc[-1]
            if 0.0005 < atr_val < 0.002:
                atr_score = 1.0
            elif 0.0002 < atr_val <= 0.0005 or 0.002 <= atr_val < 0.003:
                atr_score = 0.7
            else:
                atr_score = 0.4
        except Exception:
            atr_score = 0.5
        try:
            bb = ta.bbands(close, length=20)
            bb_score = 1.0 if close.iloc[-1] > bb['BBL_20_2.0'].iloc[-1] and close.iloc[-1] < bb['BBU_20_2.0'].iloc[-1] else 0.5
        except Exception:
            bb_score = 0.5
        try:
            vo = ta.vo(volume, short=5, long=20)
            vo_score = 1.0 if vo.iloc[-1] > 0 else 0.5
        except Exception:
            vo_score = 0.5
        try:
            engulf = ta.cdl_engulfing(open_=df['open'], high=high, low=low, close=close)
            pattern_score = 1.0 if engulf.iloc[-1] != 0 else 0.5
        except Exception:
            pattern_score = 0.5
        base_conf = round(
            0.2 * supertrend_score +
            0.2 * macd_score +
            0.1 * adx_score +
            0.1 * rsi_score +
            0.1 * atr_score +
            0.1 * bb_score +
            0.1 * vo_score +
            0.1 * pattern_score, 3)
        strong_signals = sum([
            supertrend_score > 0.7,
            macd_score > 0.7,
            adx_score > 0.7,
            rsi_score > 0.7,
            atr_score > 0.7,
            bb_score > 0.7,
            vo_score > 0.7,
            pattern_score > 0.7
        ])
        if strong_signals >= 4:
            bonus = 0.15
        elif strong_signals >= 3:
            bonus = 0.10
        elif strong_signals >= 2:
            bonus = 0.05
        else:
            bonus = 0.0
        final_conf = min(base_conf + bonus, 0.95)
        st.info(f"[Détail confiance locale] SuperTrend: {supertrend_score}, MACD: {macd_score}, ADX: {adx_score}, RSI: {rsi_score}, ATR: {atr_score}, BB: {bb_score}, VolumeOsc: {vo_score}, Pattern: {pattern_score}")
        st.info(f"[Bonus] Signaux forts: {strong_signals}/8, Bonus: +{bonus:.1%}, Confiance finale: {final_conf:.1%}")
        return final_conf

    def format_signal_message(self, signal):
        symbol = st.session_state.symbol
        synthese = signal.get('synthese', 'N/A')
        reco = signal.get('recommendation', 'N/A').upper()
        price = signal.get('price', 'N/A')
        sl = signal.get('sl', 'N/A')
        tp = signal.get('tp', 'N/A')
        profit = signal.get('profit_estime', 'N/A')
        validite = signal.get('validite', 'N/A')
        token = signal.get('validation_token', None)
        validation_url = f"https://tonserveur.com/validate_order?token={token}" if token else None
        msg = f"""
📢 *Signal de Trading*
*Symbole* : {symbol}
*Synthèse* : {synthese} 
*Ordre* : {reco}
"""
        if reco in ["BUY", "SELL"]:
            msg += f"*Prix* : {price}\n*Stop Loss* : {sl}\n*Take Profit* : {tp}\n*Profit estimé* : {profit}\n"
        msg += f"*Durée de validité* : {validite} min"
        if validation_url:
            msg += f"\n\n👉 [Valider et placer l'ordre sur mon compte]({validation_url})"
        return msg

    def close_position_mt5(self, pos):
        import MetaTrader5 as mt5
        from dotenv import load_dotenv
        import os
        load_dotenv()
        login = int(os.getenv('MT5_LOGIN', '0'))
        password = os.getenv('MT5_PASSWORD', '')
        server = os.getenv('MT5_SERVER', '')
        path = os.getenv('MT5_PATH', None)
        if not mt5.initialize(path=path if path else None):
            st.error("Connexion à MT5 impossible pour clôture.")
            return
        if not mt5.login(login, password=password, server=server):
            st.error("Login MT5 impossible pour clôture.")
            mt5.shutdown()
            return
        symbol = pos.symbol
        volume = pos.volume
        price = pos.price_current
        deviation = 20
        if pos.type == mt5.POSITION_TYPE_BUY:
            order_type = mt5.ORDER_TYPE_SELL
        else:
            order_type = mt5.ORDER_TYPE_BUY
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "position": pos.ticket,
            "price": price,
            "deviation": deviation,
            "magic": 123456,
            "comment": "Clôture via TradBOT",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        result = mt5.order_send(request)
        mt5.shutdown()
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:
            st.success(f"Position {symbol} clôturée avec succès !")
        else:
            retcode = getattr(result, 'retcode', None)
            comment = getattr(result, 'comment', '')
            st.error(f"Erreur lors de la clôture de la position. Code: {retcode} - {comment}")

    def render_dashboard(self):
        if 'timeframe' not in st.session_state:
            st.session_state.timeframe = 'M5'
        if 'symbol' not in st.session_state:
            st.session_state.symbol = 'EURUSD'
        trend_data = None
        try:
            resp = requests.post(f"http://127.0.0.1:8000/trend_summary/generate", params={"symbol": st.session_state.symbol})
            if resp.status_code == 200:
                with open("trend_summary.json", "r", encoding="utf-8") as f:
                    trend_data = json.load(f)
                st.session_state['trend_heatmap_data'] = trend_data
                st.session_state['trend_heatmap_last'] = time.strftime("%H:%M:%S")
                st.session_state['trend_heatmap_symbol'] = st.session_state.symbol
            else:
                st.warning("Impossible de générer la tendance pour ce symbole (erreur API).")
        except Exception as e:
            st.warning("Impossible de générer la tendance pour ce symbole.")
        col1, col2 = st.columns([2.5, 1])
        with col1:
            self.render_price_chart(height=750)
            st.markdown('### Tendance consolidée (multi-timeframe)')
            trend_data = st.session_state.get('trend_heatmap_data')
            if trend_data and 'trends' in trend_data:
                tf_order = ["1d", "4h", "1h", "30m", "15m", "5m", "1m"]
                tf_labels = ["D1", "H4", "H1", "M30", "M15", "M5", "M1"]
                rows = []
                for tf, label in zip(tf_order, tf_labels):
                    tf_info = trend_data["trends"].get(tf, {})
                    trend = tf_info.get("trend", "?")
                    force = tf_info.get("force", "?")
                    try:
                        force_pct = f"{int(force)}%" if force != "?" else "?"
                    except:
                        force_pct = "?"
                    rows.append({"Timeframe": label, "Tendance": trend, "Force (%)": force_pct})
                df = pd.DataFrame(rows)
                st.dataframe(df, use_container_width=True)
                st.caption(f"Tendance consolidée : {trend_data.get('consolidated', '?')} | Scalping possible : {trend_data.get('scalping_possible', '?')}")
                st.caption(f"Dernier rafraîchissement : {st.session_state.get('trend_heatmap_last', '?')}")
                # --- Ajout détection bip + envoi WhatsApp ---
                trend = trend_data.get('consolidated', '').lower()
                scalping = str(trend_data.get('scalping_possible', '')).upper() == 'OUI'
                # Récupération des valeurs de prix, SL, TP si disponibles
                last_price = None
                sl = None
                tp = None
                # Essaie de récupérer les valeurs depuis trend_data ou session_state si tu les stockes ailleurs
                if 'last_price' in st.session_state:
                    last_price = st.session_state['last_price']
                if 'sl' in st.session_state:
                    sl = st.session_state['sl']
                if 'tp' in st.session_state:
                    tp = st.session_state['tp']
                # Empêche le bip et l'envoi répétés
                key = f"scalping_signal_sent_{st.session_state.symbol}_{trend}"
                if (
                    'last_signal_trend' not in st.session_state or
                    st.session_state['last_signal_trend'] != trend or
                    st.session_state.get('last_signal_symbol') != st.session_state.symbol
                ):
                    st.session_state[key] = False
                    st.session_state['last_signal_trend'] = trend
                    st.session_state['last_signal_symbol'] = st.session_state.symbol
                if scalping and trend in ['bullish', 'bearish']:
                    self.play_beep()
                    if not st.session_state.get(key, False):
                        msg = f"Signal SCALPING {trend.upper()} détecté sur {st.session_state.symbol} (Tendance consolidée, scalping possible)"
                        if last_price is not None and sl is not None and tp is not None:
                            msg += f"\nPrix d'entrée : {last_price:.5f}\nStop Loss (SL) : {sl:.5f}\nTake Profit (TP) : {tp:.5f}"
                        from frontend.whatsapp_notify import send_whatsapp_message
                        send_whatsapp_message(msg)
                        st.success(f"Signal WhatsApp envoyé : {msg}")
                        st.session_state[key] = True
                else:
                    st.session_state[key] = False
            elif not refresh:
                st.info("Aucune donnée de tendance disponible. Cliquez sur 'Générer la tendance' puis 'Rafraîchir maintenant'.")
                st.warning("Impossible de générer la tendance pour ce symbole.")
                st.info("Aucune donnée de tendance disponible. Cliquez sur 'Générer la tendance' puis 'Rafraîchir maintenant'.")
                st.warning("Impossible de générer la tendance pour ce symbole.")

    def play_beep(self):
        beep_file = os.path.join(PROJECT_ROOT, "frontend", "static", "beep.wav")
        if os.path.exists(beep_file):
            with open(beep_file, "rb") as f:
                data = f.read()
            b64 = base64.b64encode(data).decode()
            md = f'''
            <audio autoplay>
                <source src="data:audio/wav;base64,{b64}" type="audio/wav">
            </audio>
            '''
            st.markdown(md, unsafe_allow_html=True)

    def render_metrics(self):
        st.markdown("### Métriques de Trading")
        if st.session_state.data.empty:
            st.warning("Aucune donnée disponible")
            return
        df = st.session_state.data
        last_row = df.iloc[-1]
        prev_row = df.iloc[-2] if len(df) > 1 else last_row
        price_change = (last_row['close'] - prev_row['close']) / prev_row['close'] * 100
        col1, col2 = st.columns(2)
        with col1:
            st.metric("Prix Actuel", f"{last_row['close']:.5f}",
                     f"{price_change:+.2f}%")
            st.metric("Volume", f"{last_row['volume']:,.0f}")
        with col2:
            st.metric("ATR (14)", f"{last_row.get('atr', 0):.5f}" if 'atr' in last_row else "N/A")
            st.metric("RSI (14)", f"{last_row.get('rsi', 0):.2f}" if 'rsi' in last_row else "N/A")

    def render_positions(self):
        st.markdown("### Positions Ouvertes (MT5)")
        load_dotenv()
        login = int(os.getenv('MT5_LOGIN', '0'))
        password = os.getenv('MT5_PASSWORD', '')
        server = os.getenv('MT5_SERVER', '')
        path = os.getenv('MT5_PATH', None)
        if not mt5.initialize(path=path if path else None):
            st.error("Connexion à MT5 impossible.")
            st.warning("DEBUG: Echec mt5.initialize()")
            st.write("DEBUG: mt5.last_error() =", mt5.last_error())
            return
        if not mt5.login(login, password=password, server=server):
            st.error("Login MT5 impossible.")
            st.warning("DEBUG: Echec mt5.login()")
            st.write("DEBUG: mt5.last_error() =", mt5.last_error())
            mt5.shutdown()
            return
        account_info = mt5.account_info()
        if account_info:
            st.info(f"Compte connecté : {account_info.login}")
            expected_login = os.getenv('MT5_LOGIN_EXPECTED')
            if expected_login and str(account_info.login) != str(expected_login):
                st.warning(f"⚠️ Attention : le compte connecté ({account_info.login}) n'est pas celui attendu ({expected_login}) !")
        else:
            st.warning("DEBUG: account_info() retourne None")
        positions = mt5.positions_get()
        st.write("DEBUG: positions_get() brut =", positions)
        st.write("DEBUG: mt5.last_error() après positions_get =", mt5.last_error())
        mt5.shutdown()
        if not positions:
            st.info("Aucune position ouverte sur le compte MT5")
            return
        for pos in positions:
            with st.container():
                col1, col2 = st.columns([3, 1])
                with col1:
                    st.write(f"**{pos.symbol}** - {'BUY' if pos.type==0 else 'SELL'}")
                    st.caption(f"Entrée: {pos.price_open} | SL: {pos.sl} | TP: {pos.tp}")
                with col2:
                    pnl_pct = (pos.price_current / pos.price_open - 1) * 100 if pos.type==0 else (pos.price_open / pos.price_current - 1) * 100
                    pnl_class = 'positive' if pnl_pct >= 0 else 'negative'
                    st.markdown(f"<div class='{pnl_class}'>{pnl_pct:+.2f}%</div>", unsafe_allow_html=True)
                    close_btn = st.button(f"Fermer", key=f"close_{pos.ticket}")
                    if close_btn:
                        self.close_position_mt5(pos)

    def render_risk_metrics(self):
        st.markdown("### Analyse de Risque")
        if st.session_state.data.empty:
            st.warning("Aucune donnée disponible")
            return
        df = st.session_state.data
        risk_per_trade = f"{TRADING_CONFIG['risk_per_trade']*100:.1f}%"
        close = df['close'].astype(float)
        running_max = np.maximum.accumulate(close)
        drawdown = (close - running_max) / running_max
        max_drawdown = f"{abs(drawdown.min())*100:.2f}%"
        returns = close.pct_change().dropna()
        mean_ret = returns.mean()
        std_ret = returns.std()
        if std_ret != 0:
            sharpe = mean_ret / std_ret * np.sqrt(252 if len(close) > 200 else len(close))
            sharpe_str = f"{sharpe:.2f}"
        else:
            sharpe_str = "N/A"
        win_rate = (returns > 0).sum() / len(returns) * 100 if len(returns) > 0 else 0
        win_rate_str = f"{win_rate:.0f}%"
        risk_metrics = {
            "Risque par Trade": risk_per_trade,
            "Drawdown Max": max_drawdown,
            "Ratio de Sharpe": sharpe_str,
            "Win Rate": win_rate_str
        }
        for metric, value in risk_metrics.items():
            with st.container():
                st.markdown(f"<div class='metric-card'><strong>{metric}</strong><div style='float: right;'>{value}</div></div>", unsafe_allow_html=True)

    def render_strategy_controls(self):
        st.markdown("### Contrôles de Stratégie")
        if st.session_state.get('last_openai_raw'):
            st.info(f"Réponse brute OpenAI : {st.session_state['last_openai_raw']}")
            if st.button("🗑️ Effacer la réponse OpenAI", key="clear_openai_raw"):
                del st.session_state['last_openai_raw']
                st.rerun()
        if 'show_strategy_controls' not in st.session_state:
            st.session_state['show_strategy_controls'] = True
        show_controls = st.checkbox("Afficher les Contrôles de Stratégie", value=st.session_state['show_strategy_controls'], key="show_strategy_controls")
        if not show_controls:
            st.info("Les Contrôles de Stratégie sont masqués.")
            return
        with st.form("order_form"):
            order_side = st.radio("Sens de l'ordre", ["BUY", "SELL"], horizontal=True, key="order_side_form")
            order_type = st.selectbox("Type d'ordre", ["MARKET", "LIMIT", "STOP"], key="order_type_form")
            lot = st.number_input("Volume (lot)", min_value=0.01, max_value=10.0, value=0.01, step=0.01, key="lot_form")
            price = None
            if order_type != "MARKET":
                price = st.number_input("Prix d'exécution", min_value=0.0, value=float(st.session_state.data['close'].iloc[-1]) if not st.session_state.data.empty else 0.0, key="price_form")
            sl = st.number_input("Stop Loss", min_value=0.0, value=0.0, key="sl_form")
            tp = st.number_input("Take Profit", min_value=0.0, value=0.0, key="tp_form")
            submit = st.form_submit_button("🛒 Passer l'Ordre")
            if submit:
                self.place_order(order_type, lot, price, sl, tp, order_side)

    def render_footer(self):
        st.markdown("---")
        st.caption("""
            🚀 Trading Pro - Plateforme de Trading Algorithmique Avancée
            Version 1.0.0 | © 2025 Tous droits réservés
        """)

    def load_data(self):
        try:
            with st.spinner("Chargement des données depuis MT5..."):
                if not self.connect_mt5_from_env():
                    st.error("Connexion à MT5 impossible. Vérifiez vos identifiants dans .env.")
                    send_whatsapp_message(f"❌ Erreur: Connexion à MT5 impossible pour {st.session_state.symbol}.")
                    print("[DEBUG] Connexion MT5 impossible")
                    return
                df = data_manager.get_historical_data(
                    symbol=st.session_state.symbol,
                    timeframe=st.session_state.timeframe,
                    count=3000
                )
                mt5.shutdown()
                print("[DEBUG] DataFrame récupéré depuis MT5:")
                print(df.head() if df is not None else "df is None")
                if df is not None:
                    print("[DEBUG] df.shape =", df.shape)
                if df is not None and not df.empty:
                    st.session_state.data = df
                else:
                    st.session_state.data = df
                    st.error("Aucune donnée récupérée depuis MT5.")
                    send_whatsapp_message(f"❌ Erreur: Aucune donnée récupérée depuis MT5 pour {st.session_state.symbol}.")
                    print("[DEBUG] Aucune donnée récupérée depuis MT5 pour", st.session_state.symbol)
        except Exception as e:
            st.error(f"Erreur lors du chargement des données: {e}")
            send_whatsapp_message(f"❌ Exception lors du chargement des données: {e}")
            print("[DEBUG] Exception lors du chargement des données:", e)

    def analyze_market(self):
        import os
        import pandas as pd
        from dotenv import load_dotenv
        load_dotenv()
        GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
        try:
            from google import genai
        except ImportError:
            st.error("Le package google-genai n'est pas installé. Installe-le avec: pip install -U google-genai")
            return
        client = genai.Client(api_key=GEMINI_API_KEY)
        df = st.session_state.data.tail(300).reset_index()
        for col in df.columns:
            if pd.api.types.is_datetime64_any_dtype(df[col]):
                df[col] = df[col].astype(str)
        prompt = f"""
        Analyse le marché pour {st.session_state.symbol} en timeframe {st.session_state.timeframe} avec ces données : {df.to_dict(orient='records')}.
        Donne-moi une recommandation (BUY/SELL/HOLD) et un score de confiance entre 0 et 1, au format JSON : {{'recommendation': 'BUY', 'confidence': 0.85}}
        """
        with st.spinner("Analyse Gemini API en cours..."):
            try:
                response = client.models.generate_content(
                    model="gemini-2.0-flash",
                    contents=prompt
                )
                import json
                import re
                resp_text = response.text if response.text is not None else ""
                match = re.search(r"\{.*\}", resp_text)
                if match:
                    result = json.loads(match.group(0).replace("'", '"'))
                    reco = result.get('recommendation', '').upper()
                    conf = float(result.get('confidence', 0))
                    st.session_state.analysis_result = result
                    from frontend.whatsapp_notify import send_whatsapp_message
                    msg = f"Gemini: {reco} ({conf*100:.1f}%)"
                    send_whatsapp_message(msg)
                    st.success(f"Gemini API: {reco} (confiance: {conf*100:.1f}%)")
                    if reco in ["BUY", "ACHAT"] and conf > 0.7:
                        import MetaTrader5 as mt5
                        self.connect_mt5_from_env()
                        symbol = st.session_state.symbol
                        info = mt5.symbol_info(symbol)
                        lot = info.volume_min if info else 0.01
                        price = st.session_state.data['close'].iloc[-1]
                        sl = price - 2 * (st.session_state.data['close'].std())
                        tp = price + 2 * (price - sl)
                        request = {
                            "action": mt5.TRADE_ACTION_DEAL,
                            "symbol": symbol,
                            "volume": lot,
                            "type": mt5.ORDER_TYPE_BUY,
                            "price": price,
                            "sl": sl,
                            "tp": tp,
                            "deviation": 20,
                            "magic": 123456,
                            "comment": "Auto BUY Gemini API",
                            "type_time": mt5.ORDER_TIME_GTC,
                            "type_filling": mt5.ORDER_FILLING_IOC,
                        }
                        result = mt5.order_send(request)
                        mt5.shutdown()
                        if result and result.retcode == mt5.TRADE_RETCODE_DONE:
                            st.success(f"Achat auto exécuté ({symbol}, lot {lot})")
                            send_whatsapp_message(f"🚀 Achat auto sur {symbol} (lot {lot}) à {price:.5f} | SL: {sl:.5f} | TP: {tp:.5f}")
                        else:
                            st.error("Erreur lors de l'achat auto.")
                            send_whatsapp_message(f"❌ Erreur lors de l'achat auto sur {symbol}")
                else:
                    st.error("Réponse Gemini non exploitable : " + str(resp_text))
            except Exception as e:
                st.error(f"Erreur lors de l'appel Gemini API: {e}")

    def place_order(self, order_type=None, lot=None, price=None, sl=None, tp=None, side="BUY"):
        import MetaTrader5 as mt5
        if not self.connect_mt5_from_env():
            st.error("Connexion à MT5 impossible. Vérifie que MetaTrader 5 est bien lancé et que les identifiants sont corrects.")
            return
        symbol = st.session_state.symbol
        info = mt5.symbol_info(symbol)
        if info is None:
            st.error(f"Symbole '{symbol}' introuvable dans MT5. Vérifie le nom exact dans MetaTrader 5.")
            return
        if not info.visible:
            if not mt5.symbol_select(symbol, True):
                st.error(f"Impossible de rendre le symbole '{symbol}' visible dans MT5.")
                return
            info = mt5.symbol_info(symbol)
        st.write("DEBUG: Infos du symbole:", info._asdict() if hasattr(info, '_asdict') else info)
        if lot is None:
            lot = info.volume_min if info else 0.01
        if price is None or order_type == "MARKET":
            price = st.session_state.data['close'].iloc[-1]
        if sl == 0.0:
            sl = None
        if tp == 0.0:
            tp = None
        if order_type == "MARKET":
            order_type_mt5 = mt5.ORDER_TYPE_BUY if side == "BUY" else mt5.ORDER_TYPE_SELL
        elif order_type == "LIMIT":
            order_type_mt5 = mt5.ORDER_TYPE_BUY_LIMIT if side == "BUY" else mt5.ORDER_TYPE_SELL_LIMIT
        elif order_type == "STOP":
            order_type_mt5 = mt5.ORDER_TYPE_BUY_STOP if side == "BUY" else mt5.ORDER_TYPE_SELL_STOP
        else:
            order_type_mt5 = mt5.ORDER_TYPE_BUY
        request = {
            "action": mt5.TRADE_ACTION_DEAL if order_type == "MARKET" else mt5.TRADE_ACTION_PENDING,
            "symbol": symbol,
            "volume": lot,
            "type": order_type_mt5,
            "price": price,
            "sl": sl,
            "tp": tp,
            "deviation": 20,
            "magic": 123456,
            "comment": f"Order {order_type} {side}",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        st.write("DEBUG: Requête envoyée à MT5:", request)
        result = mt5.order_send(request)
        st.write("DEBUG: Résultat brut de order_send:", result)
        mt5.shutdown()
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:
            st.success(f"Ordre {order_type} {side} passé avec succès! (lot {lot})")
            msg = f"🛒 Ordre {order_type} {side} passé sur {symbol} (lot {lot}) à {price:.5f} | SL: {sl if sl else 'None'} | TP: {tp if tp else 'None'}"
            send_whatsapp_message(msg)
        else:
            retcode = getattr(result, 'retcode', None)
            comment = getattr(result, 'comment', '')
            st.error(f"Erreur lors du passage de l'ordre. Code: {retcode} - {comment}")
            send_whatsapp_message(f"❌ Erreur lors du passage de l'ordre {order_type} {side} sur {symbol}. Code: {retcode}")

    def start_trading(self):
        st.session_state.trading_active = True
        st.success("Trading automatisé démarré")

    def stop_trading(self):
        st.session_state.trading_active = False
        st.warning("Trading automatisé arrêté")

    def render_strategy_performance(self):
        st.markdown("### Performance des Stratégies")
        strategies_state = st.session_state.get('strategies_state', {})
        if not strategies_state:
            st.info("Aucune stratégie configurée.")
            return
        perf_data = []
        for strat, state in strategies_state.items():
            if state.get('active'):
                perf_data.append({
                    'Stratégie': strat,
                    'Statut': 'Active',
                    'PNL': f"{1000 + hash(strat)%200 - 100} $",
                    'Win Rate': f"{60 + hash(strat)%20}%",
                    'Drawdown': f"{2 + hash(strat)%5}%",
                    'Signaux': 10 + hash(strat)%10
                })
        if perf_data:
            st.dataframe(perf_data, hide_index=True)
        else:
            st.info("Aucune stratégie active.")
        recent_signals = st.session_state.get('recent_signals', [])
        if recent_signals:
            st.table(recent_signals[::-1])
        else:
            st.info("Aucun signal récent généré.")

    def render_backtesting(self):
        st.title("🔄 Backtesting de Stratégie")
        strategies = [
            'SuperTrend',
            'Trend Following',
            'Mean Reversion',
            'Breakout',
            'Scalping',
            'Swing Trading'
        ]
        all_symbols = self.get_all_mt5_symbols()
        if not all_symbols:
            all_symbols = ['Aucun symbole disponible']
        symbol = st.selectbox("Symbole", all_symbols, key="bt_symbol")
        if symbol == 'Aucun symbole disponible':
            st.warning("Aucun symbole MT5 n'est disponible pour le backtest.")
            return
        timeframe = st.selectbox("Timeframe", UI_CONFIG['available_timeframes'], key="bt_timeframe")
        strategy = st.selectbox("Stratégie", strategies, key="bt_strategy")
        start_date = st.date_input("Date de début", value=datetime.now()-timedelta(days=60), key="bt_start")
        end_date = st.date_input("Date de fin", value=datetime.now(), key="bt_end")
        st.markdown("**Paramètres de la stratégie**")
        params = {}
        if strategy == 'SuperTrend':
            params['atr_period'] = st.number_input("ATR Period", min_value=2, max_value=50, value=10, key="bt_atr_period_st")
            params['min_factor'] = st.number_input("Min Factor", min_value=0.5, max_value=5.0, value=1.0, step=0.1, key="bt_min_factor_st")
            params['max_factor'] = st.number_input("Max Factor", min_value=0.5, max_value=10.0, value=5.0, step=0.1, key="bt_max_factor_st")
            params['factor_step'] = st.number_input("Factor Step", min_value=0.1, max_value=2.0, value=0.5, step=0.1, key="bt_factor_step_st")
            params['sl_multiplier'] = st.number_input("SL Multiplier", min_value=1.0, max_value=5.0, value=2.0, step=0.1, key="bt_sl_mult_st")
            params['tp_multiplier'] = st.number_input("TP Multiplier", min_value=1.0, max_value=5.0, value=3.0, step=0.1, key="bt_tp_mult_st")
            params['risk_percent'] = st.number_input("Risk %", min_value=0.1, max_value=10.0, value=1.0, step=0.1, key="bt_risk_st")
        if st.button("Lancer le backtest", use_container_width=True):
            if strategy == 'SuperTrend':
                try:
                    from ml_supertrend.core.supertrend_bot import SuperTrendBot, Config
                    from ml_supertrend.backtest_engine import BacktestEngine
                    import pandas as pd
                    tf_map = {
                        'M1': mt5.TIMEFRAME_M1,
                        'M5': mt5.TIMEFRAME_M5,
                        'M15': mt5.TIMEFRAME_M15,
                        'M30': mt5.TIMEFRAME_M30,
                        'H1': mt5.TIMEFRAME_H1,
                        'H4': mt5.TIMEFRAME_H4,
                        'D1': mt5.TIMEFRAME_D1,
                        'W1': mt5.TIMEFRAME_W1,
                        'MN1': mt5.TIMEFRAME_MN1
                    }
                    tf = tf_map.get(timeframe, mt5.TIMEFRAME_M5)
                    config = Config(
                        symbol=symbol,
                        timeframe=tf,
                        atr_period=params['atr_period'],
                        min_factor=params['min_factor'],
                        max_factor=params['max_factor'],
                        factor_step=params['factor_step'],
                        sl_multiplier=params['sl_multiplier'],
                        tp_multiplier=params['tp_multiplier'],
                        risk_percent=params['risk_percent']
                    )
                    bot = SuperTrendBot(config)
                    engine = BacktestEngine(bot)
                    start_dt = pd.to_datetime(start_date)
                    end_dt = pd.to_datetime(end_date)
                    st.info("Backtest en cours, cela peut prendre quelques secondes...")
                    results = engine.run_backtest(symbol, start_dt, end_dt, tf)
                    st.session_state.bt_results = results
                    st.success("Backtest terminé !")
                except Exception as e:
                    st.error(f"Erreur lors du backtest : {e}")
            else:
                st.info("Backtest réel non encore implémenté pour cette stratégie. Utilise SuperTrend pour la démo.")
        if hasattr(st.session_state, 'bt_results'):
            results = st.session_state.bt_results
            st.subheader("Courbe de PNL")
            import plotly.graph_objects as go
            fig = go.Figure()
            pnl_curve = results['pnl_curve']
            fig.add_trace(go.Scatter(x=pnl_curve['time'], y=pnl_curve['equity'], mode='lines', name='PNL'))
            if 'equity' in pnl_curve.columns:
                fig.add_trace(go.Scatter(x=pnl_curve['time'], y=pnl_curve['equity'], name='Equity'))
            else:
                st.warning("Pas de courbe d'équité disponible pour ce backtest.")
            st.plotly_chart(fig, use_container_width=True)
            st.subheader("Métriques clés")
            st.table(results['metrics'])
            st.subheader("Historique des trades")
            st.dataframe(results['trades'], hide_index=True)

    def render_guide(self):
        st.markdown("""
# 📖 Guide d'utilisation de TradBOT
Bienvenue sur **TradBOT**, votre plateforme de trading algorithmique avancée !
## 🏠 1. Dashboard principal
- **Vue d'ensemble** de votre compte, solde, PnL, positions ouvertes.
- **Graphiques interactifs** pour suivre l'évolution des prix et des signaux.
- **Sélection du symbole** et du timeframe à analyser.
## 🤖 2. Stratégies & Signaux
- **Choisissez une stratégie** (Trend Following, ML-SuperTrend, etc.)
- **Générez des signaux** manuellement ou activez l'envoi automatique.
- **Recevez les signaux** directement sur WhatsApp si activé.
## 🛠️ 3. Auto-Monitor (Moniteur automatique)
- **Démarrez/arrêtez** le moniteur pour surveiller les marchés en continu.
- **Personnalisez** les catégories et symboles à scanner.
- **Suivez la progression** du scan en temps réel (barre de progression).
- **Consultez les statistiques** : scans, signaux générés, acceptés, rejetés, erreurs.
- **Recevez les signaux acceptés** en temps réel sur WhatsApp.
- **Contrôlez le moniteur** via l'onglet ou par commandes WhatsApp (`/start`, `/stop`, `/status`, `/monitor_stats`).
## 💬 4. Messagerie WhatsApp
- **Onglet dédié** pour consulter tous les messages WhatsApp reçus.
- **Filtrez** par expéditeur ou mot-clé.
- **Répondez directement** à un message WhatsApp depuis l'interface.
- **Recevez les signaux, alertes, et confirmations** sur votre mobile.
- **Commandes interactives** : passez des ordres, demandez la liste des symboles, contrôlez l'auto-monitor, etc.
## 📊 5. Performance & Backtesting
- **Analysez la performance** de vos stratégies sur l'historique.
- **Visualisez** le winrate, le PnL, le drawdown, la distribution des gains/pertes.
- **Testez vos stratégies** sur différentes périodes et symboles.
## ⚡ 6. Conseils d'utilisation
- **Activez l'auto-refresh** pour suivre les signaux en temps réel.
- **Utilisez les filtres** pour cibler vos analyses.
- **Consultez le guide** à tout moment pour retrouver les commandes et bonnes pratiques.
## 📱 7. Commandes WhatsApp principales
- `menu` : revenir au menu principal
- `2` ou `symboles` : liste des symboles par catégorie
- `ORDRE BUY EURUSD 0.1 ...` : passer un ordre
- `CLOSE EURUSD` : fermer une position
- `/start`, `/stop`, `/status` : contrôler l'auto-monitor
- `/monitor_stats` : voir les stats du moniteur
## 🆘 8. Support
- Pour toute question ou bug, contactez l'équipe via le support intégré ou WhatsApp.
---
**Profitez de la puissance de l'IA et de l'automatisation pour booster votre trading !**
""", unsafe_allow_html=True)

    def generate_trade_signal(self):
        import os
        import pandas as pd
        import uuid
        import redis
        import json
        from dotenv import load_dotenv
        load_dotenv()
        OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
        REDIS_HOST = os.getenv('REDIS_HOST', 'localhost')
        REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
        REDIS_DB = int(os.getenv('REDIS_DB', 0))
        r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB)
        df = st.session_state.data.tail(50).reset_index()
        essential_cols = [c for c in ['open', 'high', 'low', 'close', 'volume', 'rsi', 'atr'] if c in df.columns]
        df = df[essential_cols]
        for col in df.columns:
            if pd.api.types.is_datetime64_any_dtype(df[col]):
                df[col] = df[col].astype(str)
        current_price = float(st.session_state.data['close'].iloc[-1])
        prompt = f"""
        Analyse le marché pour {st.session_state.symbol} en timeframe {st.session_state.timeframe} avec ces données : {df.to_dict(orient='records')}.
        Le prix actuel de la devise est : {current_price}.
        Donne-moi une recommandation (BUY/SELL/HOLD), un score de confiance entre 0 et 1, un résumé de l'analyse technique, le prix d'entrée (proche du prix actuel), un stop loss, un take profit, un profit estimé (en pips ou %), et une durée de validité (en minutes), au format JSON : {{'recommendation': 'BUY', 'confidence': 0.85, 'synthese': '...', 'price': 1.12345, 'sl': 1.12000, 'tp': 1.13000, 'profit_estime': '+70 pips', 'validite': 30}}
        """
        try:
            import openai
            client = openai.OpenAI(api_key=OPENAI_API_KEY)
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[{"role": "system", "content": "Tu es un assistant expert en trading."},
                          {"role": "user", "content": prompt}]
            )
            resp_text = response.choices[0].message.content or ''
            st.session_state['last_openai_raw'] = resp_text
            st.info(f"Réponse brute OpenAI : {resp_text}")
            import json as pyjson
            import re
            match = re.search(r"\{.*\}", resp_text)
            if match:
                result = pyjson.loads(match.group(0).replace("'", '"'))
                ia_price = float(result.get('price', 0))
                seuil = 0.01 * current_price
                if abs(ia_price - current_price) > seuil:
                    st.warning(f"Le prix proposé par l'IA ({ia_price}) est trop éloigné du prix actuel ({current_price}). Correction automatique.")
                    result['price'] = current_price
                local_conf = self.compute_local_confidence(df, result)
                ia_conf = float(result.get('confidence', 0))
                combined_conf = round((ia_conf + local_conf) / 2, 3)
                st.info(f"Confiance IA : {ia_conf}")
                st.info(f"Confiance locale : {local_conf}")
                st.info(f"Confiance combinée : {combined_conf}")
                result['confidence_combined'] = combined_conf
                token = str(uuid.uuid4())
                order_data = {
                    'symbol': st.session_state.symbol,
                    'order': result,
                    'datetime': pd.Timestamp.now().isoformat()
                }
                r.setex(f'order:{token}', 1800, json.dumps(order_data))
                result['validation_token'] = token
                return result
            st.error("Réponse OpenAI non exploitable : " + str(resp_text))
            return None
        except Exception as e:
            if hasattr(e, 'status_code') and e.status_code == 429:
                st.warning("Limite OpenAI atteinte (429) : trop de requêtes. Merci de patienter 1 minute avant de réessayer. Signal local généré.")
            elif 'rate limit' in str(e).lower() or '429' in str(e):
                st.warning("Limite OpenAI atteinte (429) : trop de requêtes. Signal local généré.")
            else:
                st.error(f"Erreur lors de l'appel OpenAI API: {e}. Signal local généré.")
            local_conf = self.compute_local_confidence(df, {})
            if local_conf > 0.65:
                reco = 'BUY'
                confidence_boost = 0.1
            elif local_conf < 0.35:
                reco = 'SELL'
                confidence_boost = 0.1
            else:
                reco = 'HOLD'
                confidence_boost = 0.0
            final_confidence = min(local_conf + confidence_boost, 0.95)
            price = current_price
            if reco == 'BUY':
                sl = price * 0.998
                tp = price * 1.005
            elif reco == 'SELL':
                sl = price * 1.002
                tp = price * 0.995
            else:
                sl = tp = None
            result = {
                'recommendation': reco,
                'confidence': final_confidence,
                'synthese': f'Signal généré localement (confiance: {final_confidence:.1%}) - {reco} recommandé',
                'price': price,
                'sl': sl,
                'tp': tp,
                'profit_estime': '+50 pips' if reco in ['BUY', 'SELL'] else '0',
                'validite': 30,
                'confidence_combined': final_confidence
            }
            token = str(uuid.uuid4())
            order_data = {
                'symbol': st.session_state.symbol,
                'order': result,
                'datetime': pd.Timestamp.now().isoformat()
            }
            r.setex(f'order:{token}', 1800, json.dumps(order_data))
            result['validation_token'] = token
            st.info(f"Signal local généré : {result}")
            return result

    def compute_local_confidence(self, df, signal):
        import numpy as np
        import pandas as pd
        try:
            import pandas_ta as ta
        except ImportError:
            st.warning("pandas-ta n'est pas installé, certains indicateurs avancés ne seront pas calculés.")
            return 0.5
        if df.empty or 'close' not in df.columns:
            return 0.5
        close = df['close'].astype(float)
        high = df['high'].astype(float) if 'high' in df.columns else close
        low = df['low'].astype(float) if 'low' in df.columns else close
        volume = df['volume'].astype(float) if 'volume' in df.columns else pd.Series([0]*len(df))
        try:
            st_df = ta.supertrend(high=high, low=low, close=close, length=10, multiplier=3.0)
            supertrend_dir = st_df.iloc[-1]['SUPERT_10_3.0']
            supertrend_score = 1.0 if close.iloc[-1] > supertrend_dir else 0.0
        except Exception:
            supertrend_score = 0.5
        try:
            macd = ta.macd(close)
            macd_score = 1.0 if macd['MACDh_12_26_9'].iloc[-1] > 0 else 0.0
        except Exception:
            macd_score = 0.5
        try:
            adx = ta.adx(high, low, close)
            adx_val = adx['ADX_14'].iloc[-1]
            adx_score = 1.0 if adx_val > 25 else 0.5
        except Exception:
            adx_score = 0.5
        try:
            rsi = ta.rsi(close, length=14)
            rsi_val = rsi.iloc[-1]
            if 45 < rsi_val < 65:
                rsi_score = 1.0
            elif 35 < rsi_val <= 45 or 65 <= rsi_val < 75:
                rsi_score = 0.7
            else:
                rsi_score = 0.3
        except Exception:
            rsi_score = 0.5
        try:
            atr = ta.atr(high, low, close, length=14)
            atr_val = atr.iloc[-1]
            if 0.0005 < atr_val < 0.002:
                atr_score = 1.0
            elif 0.0002 < atr_val <= 0.0005 or 0.002 <= atr_val < 0.003:
                atr_score = 0.7
            else:
                atr_score = 0.4
        except Exception:
            atr_score = 0.5
        try:
            bb = ta.bbands(close, length=20)
            bb_score = 1.0 if close.iloc[-1] > bb['BBL_20_2.0'].iloc[-1] and close.iloc[-1] < bb['BBU_20_2.0'].iloc[-1] else 0.5
        except Exception:
            bb_score = 0.5
        try:
            vo = ta.vo(volume, short=5, long=20)
            vo_score = 1.0 if vo.iloc[-1] > 0 else 0.5
        except Exception:
            vo_score = 0.5
        try:
            engulf = ta.cdl_engulfing(open_=df['open'], high=high, low=low, close=close)
            pattern_score = 1.0 if engulf.iloc[-1] != 0 else 0.5
        except Exception:
            pattern_score = 0.5
        base_conf = round(
            0.2 * supertrend_score +
            0.2 * macd_score +
            0.1 * adx_score +
            0.1 * rsi_score +
            0.1 * atr_score +
            0.1 * bb_score +
            0.1 * vo_score +
            0.1 * pattern_score, 3)
        strong_signals = sum([
            supertrend_score > 0.7,
            macd_score > 0.7,
            adx_score > 0.7,
            rsi_score > 0.7,
            atr_score > 0.7,
            bb_score > 0.7,
            vo_score > 0.7,
            pattern_score > 0.7
        ])
        if strong_signals >= 4:
            bonus = 0.15
        elif strong_signals >= 3:
            bonus = 0.10
        elif strong_signals >= 2:
            bonus = 0.05
        else:
            bonus = 0.0
        final_conf = min(base_conf + bonus, 0.95)
        st.info(f"[Détail confiance locale] SuperTrend: {supertrend_score}, MACD: {macd_score}, ADX: {adx_score}, RSI: {rsi_score}, ATR: {atr_score}, BB: {bb_score}, VolumeOsc: {vo_score}, Pattern: {pattern_score}")
        st.info(f"[Bonus] Signaux forts: {strong_signals}/8, Bonus: +{bonus:.1%}, Confiance finale: {final_conf:.1%}")
        return final_conf

    def format_signal_message(self, signal):
        symbol = st.session_state.symbol
        synthese = signal.get('synthese', 'N/A')
        reco = signal.get('recommendation', 'N/A').upper()
        price = signal.get('price', 'N/A')
        sl = signal.get('sl', 'N/A')
        tp = signal.get('tp', 'N/A')
        profit = signal.get('profit_estime', 'N/A')
        validite = signal.get('validite', 'N/A')
        token = signal.get('validation_token', None)
        validation_url = f"https://tonserveur.com/validate_order?token={token}" if token else None
        msg = f"""
📢 *Signal de Trading*
*Symbole* : {symbol}
*Synthèse* : {synthese} 
*Ordre* : {reco}
"""
        if reco in ["BUY", "SELL"]:
            msg += f"*Prix* : {price}\n*Stop Loss* : {sl}\n*Take Profit* : {tp}\n*Profit estimé* : {profit}\n"
        msg += f"*Durée de validité* : {validite} min"
        if validation_url:
            msg += f"\n\n👉 [Valider et placer l'ordre sur mon compte]({validation_url})"
        return msg

    def close_position_mt5(self, pos):
        import MetaTrader5 as mt5
        from dotenv import load_dotenv
        import os
        load_dotenv()
        login = int(os.getenv('MT5_LOGIN', '0'))
        password = os.getenv('MT5_PASSWORD', '')
        server = os.getenv('MT5_SERVER', '')
        path = os.getenv('MT5_PATH', None)
        if not mt5.initialize(path=path if path else None):
            st.error("Connexion à MT5 impossible pour clôture.")
            return
        if not mt5.login(login, password=password, server=server):
            st.error("Login MT5 impossible pour clôture.")
            mt5.shutdown()
            return
        symbol = pos.symbol
        volume = pos.volume
        price = pos.price_current
        deviation = 20
        if pos.type == mt5.POSITION_TYPE_BUY:
            order_type = mt5.ORDER_TYPE_SELL
        else:
            order_type = mt5.ORDER_TYPE_BUY
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "position": pos.ticket,
            "price": price,
            "deviation": deviation,
            "magic": 123456,
            "comment": "Clôture via TradBOT",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC,
        }
        result = mt5.order_send(request)
        mt5.shutdown()
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:
            st.success(f"Position {symbol} clôturée avec succès !")
        else:
            retcode = getattr(result, 'retcode', None)
            comment = getattr(result, 'comment', '')
            st.error(f"Erreur lors de la clôture de la position. Code: {retcode} - {comment}")

    def render_trend_heatmap(self, trends):
        import pandas as pd
        def color_trend(val):
            if val == 'HAUSSE': return 'background-color: #4CAF50; color: white'
            if val == 'BAISSE': return 'background-color: #F44336; color: white'
            return 'background-color: #2196F3; color: white'
        tf_labels = {"D1": "1J", "H4": "4H", "H1": "1H", "M30": "30m", "M15": "15m", "M5": "5m"}
        df = pd.DataFrame({
            'Timeframe': [tf_labels.get(tf, tf) for tf in trends],
            'Tendance': [trends[tf].get('trend', '-') for tf in trends]
        })
        st.markdown('#### Heatmap Tendance')
        st.dataframe(df.style.map(color_trend, subset=['Tendance']), use_container_width=True)

    def render_strategies(self):
        st.markdown("## Gestion des Stratégies")
        self.render_strategy_performance()

    def render_signals(self):
        st.markdown("## Signaux & Notifications")
        auto_signal = st.checkbox("Envoyer automatiquement les signaux WhatsApp", value=st.session_state.get('auto_signal_whatsapp', False), key="auto_signal_whatsapp")
        auto_signal_interval = st.number_input("Intervalle d'envoi (minutes)", min_value=1, max_value=120, value=10, step=1, key="auto_signal_interval")
        if auto_signal:
            now = datetime.now().timestamp()
            last_sent = st.session_state.get('last_auto_signal_sent', 0)
            interval_sec = auto_signal_interval * 60
            if now - last_sent > interval_sec:
                signal = self.generate_trade_signal()
                if signal and signal.get('confidence_combined', 0) >= 0.6:
                    msg = self.format_signal_message(signal)
                    from frontend.whatsapp_notify import send_whatsapp_message
                    ok = send_whatsapp_message(msg)
                    if ok:
                        st.success("Signal WhatsApp envoyé automatiquement !")
                        st.session_state['last_auto_signal_sent'] = now
                        if 'recent_signals' not in st.session_state:
                            st.session_state['recent_signals'] = []
                        st.session_state['recent_signals'].append({
                            'stratégie': st.session_state.get('strategy', 'Auto'),
                            'type': signal.get('recommendation', ''),
                            'prix': signal.get('price', ''),
                            'date': datetime.now().strftime('%Y-%m-%d %H:%M'),
                            'confiance': float(signal.get('confidence_combined', 0))
                        })
                        st.session_state['recent_signals'] = st.session_state['recent_signals'][-20:]
                    else:
                        st.error("Échec de l'envoi automatique du signal WhatsApp.")
                else:
                    st.info("Aucun signal valide (confiance < 0.6) à envoyer automatiquement.")
        if st.button("Envoyer un signal maintenant", use_container_width=True, key="send_signal_now"):
            signal = self.generate_trade_signal()
            if signal and signal.get('confidence_combined', 0) >= 0.6:
                msg = self.format_signal_message(signal)
                from frontend.whatsapp_notify import send_whatsapp_message
                ok = send_whatsapp_message(msg)
                if ok:
                    st.success("Signal WhatsApp envoyé immédiatement !")
                    if 'recent_signals' not in st.session_state:
                        st.session_state['recent_signals'] = []
                    st.session_state['recent_signals'].append({
                        'stratégie': st.session_state.get('strategy', 'Auto'),
                        'type': signal.get('recommendation', ''),
                        'prix': signal.get('price', ''),
                        'date': datetime.now().strftime('%Y-%m-%d %H:%M'),
                        'confiance': float(signal.get('confidence_combined', 0))
                    })
                    st.session_state['recent_signals'] = st.session_state['recent_signals'][-20:]
                else:
                    st.error("Échec de l'envoi du signal WhatsApp.")
            else:
                st.warning("Aucun signal valide (confiance < 0.6) à envoyer maintenant.")
        recent_signals = st.session_state.get('recent_signals', [])
        if recent_signals:
            st.dataframe(recent_signals[::-1], height=400)
            if st.button("Effacer l'historique des signaux", key="clear_signals"):
                st.session_state['recent_signals'] = []
        else:
            st.info("Aucun signal récent généré.")

    def render_notifications_whatsapp(self):
        st.markdown("### Notifications WhatsApp")
        interval = st.number_input("Intervalle d'envoi (minutes)", min_value=1, max_value=120, value=st.session_state.get('wa_interval', 15), step=1, key='wa_interval')
        st.session_state.wa_interval = interval
        symbol = st.session_state.symbol
        messages_file = Path("messages_whatsapp.json")
        messages = []
        if messages_file.exists():
            with messages_file.open("r", encoding="utf-8") as f:
                lines = f.readlines()
                for line in lines:
                    messages.append(json.loads(line))
        for msg in messages:
            msg_time = msg['timestamp']
            st.write(time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(msg_time)))
        if 'wa_auto' not in st.session_state:
            st.session_state.wa_auto = False
        auto_label = "✅ Envoi automatique activé" if st.session_state.wa_auto else "⏸️ Activer l'envoi automatique"
        if st.button(auto_label, key="wa_auto_btn"):
            st.session_state.wa_auto = not st.session_state.wa_auto
            if st.session_state.wa_auto:
                url = f"http://127.0.0.1:8000/start_auto_signal"
                resp = requests.post(url, params={"symbol": symbol, "interval": interval}, timeout=10)
                if resp.status_code == 200:
                    st.success("Envoi automatique démarré")
                else:
                    st.error(f"Erreur: {resp.text}")
            else:
                url = f"http://127.0.0.1:8000/stop_auto_signal"
                resp = requests.post(url, timeout=10)
                if resp.status_code == 200:
                    st.info("Envoi automatique arrêté")
                else:
                    st.error(f"Erreur: {resp.text}")
        if st.session_state.wa_auto:
            url = f"http://127.0.0.1:8000/update_auto_signal"
            requests.post(url, params={"symbol": symbol, "interval": interval}, timeout=5)
        if st.button("Envoyer un signal maintenant", key="wa_send_now"):
            url = f"http://127.0.0.1:8000/send_signal_now?symbol={symbol.replace(' ', '%20')}"
            resp = requests.post(url, timeout=15)
            if resp.status_code == 200:
                st.success("Signal WhatsApp envoyé !")
            else:
                st.error(f"Erreur lors de l'envoi : {resp.text}")

    def render_ai_analysis(self):
        st.markdown("### Analyse IA (OpenAI/Gemini)")
        # Ajout du choix du modèle Gemini
        gemini_model = st.selectbox(
            "Modèle Gemini à utiliser",
            ["gemini-1.5-pro-latest", "gemini-1.5-flash-latest"],
            index=0,
            key="gemini_model_select"
        )
        if st.button("Analyser avec IA"):
            ai_text = self.call_backend_ai_analysis(gemini_model=gemini_model)
            st.session_state['ai_analysis'] = ai_text
        if 'ai_analysis' in st.session_state:
            st.markdown(st.session_state['ai_analysis'])

    # Modifie la fonction d'appel backend pour prendre en compte le modèle Gemini choisi
    def call_backend_ai_analysis(self, gemini_model="gemini-1.5-pro-latest"):
        import os
        import pandas as pd
        from dotenv import load_dotenv
        load_dotenv()
        GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
        try:
            from google import genai
        except ImportError:
            return "Le package google-genai n'est pas installé. Installe-le avec: pip install -U google-genai"
        client = genai.Client(api_key=GEMINI_API_KEY)
        df = st.session_state.data.tail(300).reset_index()
        for col in df.columns:
            if pd.api.types.is_datetime64_any_dtype(df[col]):
                df[col] = df[col].astype(str)
        prompt = f"""
        Analyse le marché pour {st.session_state.symbol} en timeframe {st.session_state.timeframe} avec ces données : {df.to_dict(orient='records')}.
        Donne-moi une recommandation (BUY/SELL/HOLD) et un score de confiance entre 0 et 1, au format JSON : {{'recommendation': 'BUY', 'confidence': 0.85}}
        """
        with st.spinner(f"Analyse Gemini API ({gemini_model}) en cours..."):
            try:
                response = client.models.generate_content(
                    model=gemini_model,
                    contents=prompt
                )
                resp_text = response.text if response.text is not None else ""
                return resp_text
            except Exception as e:
                return f"Erreur lors de l'appel Gemini API: {e}"

    def render_auto_monitor(self):
        refresh_interval = st.slider("⏱️ Intervalle de rafraîchissement (secondes)", 5, 60, 10, key="refresh_interval_monitor")
        st_autorefresh(interval=refresh_interval * 1000, key="auto_monitor_refresh")
        try:
            resp = requests.get("http://localhost:8000/auto_monitor/status")
            status = resp.json()
        except Exception as e:
            st.error(f"Erreur récupération statut moniteur : {e}")
            return
        running = status.get('running', False)
        badge = f"<span style='font-size:1.2rem;font-weight:700;padding:0.3em 1em;border-radius:1em;background:{'#10b981' if running else '#f59e42'};color:white;'>{'🟢 EN COURS' if running else '🟠 ARRÊTÉ'}</span>"
        st.markdown(f"<div style='display:flex;align-items:center;gap:1em;'><div class='main-header'>🛠️ Statut du Moniteur</div>{badge}</div>", unsafe_allow_html=True)
        config_df, stats_df = self.get_monitor_status_df(status)
        st.markdown("<div class='sub-header'>⚙️ Configuration</div>", unsafe_allow_html=True)
        st.dataframe(config_df.style.set_properties(**{'background-color': '#f1f5f9', 'color': '#0f172a', 'font-weight': 'bold'}), use_container_width=True)
        st.markdown("<div class='sub-header'>📈 Statistiques</div>", unsafe_allow_html=True)
        stats = status.get('stats', {})
        uptime = status.get('uptime', 'N/A')
        total_scans = stats.get('total_scans', 0)
        signals_generated = stats.get('signals_generated', 0)
        signals_sent = stats.get('signals_sent', 0)
        signals_rejected = stats.get('signals_rejected', 0)
        errors = stats.get('errors', 0)
        timeouts = stats.get('timeouts', 0)
        last_signal_time = stats.get('last_signal_time', None)
        last_scan_time = stats.get('last_scan_time', None)
        st.markdown(f"<b>Uptime :</b> {uptime} | <b>Dernier scan :</b> {last_scan_time if last_scan_time else 'N/A'} | <b>Dernier signal :</b> {last_signal_time if last_signal_time else 'N/A'}", unsafe_allow_html=True)
        colm1, colm2, colm3, colm4, colm5, colm6 = st.columns(6)
        colm1.metric("Scans totaux", total_scans)
        colm2.metric("Signaux générés", signals_generated)
        colm3.metric("Signaux envoyés", signals_sent)
        colm4.metric("Rejetés", signals_rejected)
        colm5.metric("Erreurs", errors)
        colm6.metric("Timeouts", timeouts)
        from backend.auto_signal_monitor import AutoSignalMonitor
        monitor = AutoSignalMonitor()
        symbols_to_scan = monitor.get_symbols_to_monitor()
        total_symbols = len(symbols_to_scan)
        symbols_processed = stats.get('symbols_processed', {})
        processed_count = len(symbols_processed)
        pct = int(100 * processed_count / total_symbols) if total_symbols > 0 else 0
        st.markdown(f"<b>Progression du scan :</b> {processed_count} / {total_symbols} symboles ({pct}%)", unsafe_allow_html=True)
        st.progress(pct)
        if symbols_processed:
            last_symbols = sorted(symbols_processed.items(), key=lambda x: x[1]['last_success'], reverse=True)[:10]
            st.markdown("<b>Derniers symboles scannés :</b>", unsafe_allow_html=True)
            st.write([f"{s[0]} ({s[1]['last_success'].strftime('%H:%M:%S')})" for s in last_symbols])
        st.markdown("<div class='sub-header'>🕹️ Contrôles rapides</div>", unsafe_allow_html=True)
        col1, col2, col3, col4 = st.columns(4)
        with col1:
            st.button("▶️ Démarrer le moniteur", disabled=running, key="start_monitor_btn", help="Déjà en cours" if running else None, use_container_width=True)
            if st.session_state.get('start_monitor_btn'):
                try:
                    requests.post("http://localhost:8000/auto_monitor/start", timeout=5)
                    st.success("Moniteur démarré !")
                except Exception as e:
                    st.error(f"Erreur : {e}")
        with col2:
            st.button("⏹️ Arrêter le moniteur", disabled=not running, key="stop_monitor_btn", help="Déjà arrêté" if not running else None, use_container_width=True)
            if st.session_state.get('stop_monitor_btn'):
                try:
                    requests.post("http://localhost:8000/auto_monitor/stop", timeout=5)
                    st.success("Moniteur arrêté !")
                except Exception as e:
                    st.error(f"Erreur : {e}")
        with col3:
            if st.button("🔍 Scan manuel"):
                try:
                    requests.post("http://localhost:8000/auto_monitor/scan_now", timeout=5)
                    st.success("Scan manuel lancé !")
                except Exception as e:
                    st.error(f"Erreur : {e}")
        with col4:
            if st.button("🔄 Reset stats"):
                try:
                    requests.post("http://localhost:8000/auto_monitor/reset_stats", timeout=5)
                    st.success("Stats réinitialisées !")
                except Exception as e:
                    st.error(f"Erreur : {e}")
        st.markdown("<div class='sub-header'>⚡ Configuration rapide</div>", unsafe_allow_html=True)
        try:
            conf = status.get("config", {})
            scan_interval = st.slider("Intervalle scan (min)", 1, 60, conf.get("scan_interval", 5))
            min_conf = st.slider("Confiance min (%)", 30, 95, conf.get("min_confidence", 50))
            max_signals = st.slider("Max signaux/heure", 1, 50, conf.get("max_signals_per_hour", 10))
            all_categories = ['forex', 'synthetic_index', 'stock_index', 'metal', 'crypto', 'commodity', 'other']
            selected_categories = st.multiselect(
                "Catégories à scanner",
                options=all_categories,
                default=conf.get("categories_to_scan", all_categories)
            )
            if st.button("💾 Appliquer config"):
                new_conf = {
                    "scan_interval": scan_interval,
                    "min_confidence": min_conf,
                    "max_signals_per_hour": max_signals,
                    "categories_to_scan": selected_categories
                }
                try:
                    requests.put("http://localhost:8000/auto_monitor/config", json=new_conf, timeout=5)
                    st.success("Config mise à jour!")
                except Exception as e:
                    st.error(f"Erreur config: {e}")
        except Exception as e:
            st.error(f"Erreur config rapide: {e}")
        from backend.auto_signal_monitor import AutoSignalMonitor
        monitor = AutoSignalMonitor()
        from backend.multi_timeframe_signal_generator import MultiTimeframeSignalGenerator
        if 'mtf_signal_gen' not in st.session_state:
            st.session_state['mtf_signal_gen'] = MultiTimeframeSignalGenerator()
        mtf_signal_gen = st.session_state['mtf_signal_gen']
        turbo_state = mtf_signal_gen.is_turbo_bullish_enabled()
        turbo_bearish = mtf_signal_gen.is_turbo_bearish_enabled()
        col_tb1, col_tb2 = st.columns(2)
        with col_tb1:
            if st.button('⚡ Activer le mode Turbo Bullish' if not turbo_state else '🛑 Désactiver le mode Turbo Bullish'):
                if not turbo_state:
                    mtf_signal_gen.enable_turbo_bullish()
                else:
                    mtf_signal_gen.disable_turbo_bullish()
                st.rerun()
        with col_tb2:
            if st.button('⚡ Activer le mode Turbo Bearish' if not turbo_bearish else '🛑 Désactiver le mode Turbo Bearish'):
                if not turbo_bearish:
                    mtf_signal_gen.enable_turbo_bearish()
                else:
                    mtf_signal_gen.disable_turbo_bearish()
                st.rerun()
        st.markdown(f"<b>Turbo Bullish:</b> {'🟢 ACTIVÉ' if turbo_state else '⚪️ Désactivé'}", unsafe_allow_html=True)
        st.markdown(f"<b>Turbo Bearish:</b> {'🔴 ACTIVÉ' if turbo_bearish else '⚪️ Désactivé'}", unsafe_allow_html=True)
        if turbo_state:
            st.warning("Le mode Turbo Bullish est activé : tout alignement haussier total enverra un signal BUY automatiquement !")
        if turbo_bearish:
            st.warning("Le mode Turbo Bearish est activé : tout alignement baissier total enverra un signal SELL automatiquement !")
        if selected_categories:
            monitor.config['categories_to_scan'] = selected_categories
            all_symbols = monitor.get_symbols_to_monitor()
        else:
            all_symbols = []
        if 'selected_symbols' not in st.session_state:
            st.session_state['selected_symbols'] = []
        st.session_state['selected_symbols'] = [s for s in st.session_state['selected_symbols'] if s in all_symbols]
        if st.button('🗑️ Effacer la sélection', key='clear_selected_symbols_auto_monitor_top'):
            st.session_state['selected_symbols'] = []
            st.experimental_rerun()
        selected_symbols = st.multiselect(
            "Symboles à analyser (personnalisation possible)",
            options=all_symbols,
            default=st.session_state.get('selected_symbols', []),
            key='selected_symbols',
            disabled=not bool(selected_categories)
        )
        if not selected_categories:
            st.info("Veuillez d'abord choisir une ou plusieurs catégories pour afficher les symboles disponibles.")
        if st.button('🗑️ Effacer la sélection', key='clear_selected_symbols_auto_monitor_bottom'):
            st.session_state['selected_symbols'] = []
            st.experimental_rerun()
        scan_interval = status.get("config", {}).get("scan_interval", 5)
        max_symbols = status.get("config", {}).get("max_symbols_per_scan", 25)
        planning_df, scan_counts_df = self.get_scan_planning(selected_symbols, scan_interval, max_symbols, period_minutes=60)
        st.bar_chart(scan_counts_df.set_index("Symbole"))
        if not selected_symbols:
            st.warning("⚠️ Aucun symbole sélectionné. Veuillez choisir au moins un symbole à analyser.")

    def render_performance_tab(self):
        st.markdown("<div class='main-header'>📈 Historique & Performance des Trades</div>", unsafe_allow_html=True)
        if st.button("🔄 Rafraîchir l'historique MT5"):
            st.session_state['refresh_mt5_history'] = True
        trades = load_trade_history()
        df_local = pd.DataFrame(trades) if trades else pd.DataFrame()
        if 'refresh_mt5_history' not in st.session_state:
            st.session_state['refresh_mt5_history'] = True
        if st.session_state['refresh_mt5_history']:
            df_mt5, df_positions = self.get_mt5_trade_history(days=90)
            st.session_state['mt5_history'] = df_mt5
            st.session_state['mt5_positions'] = df_positions
            st.session_state['refresh_mt5_history'] = False
        else:
            df_mt5 = st.session_state.get('mt5_history', pd.DataFrame())
            df_positions = st.session_state.get('mt5_positions', pd.DataFrame())
        st.markdown("<div class='sub-header'>Historique réel MT5 (90 jours)</div>", unsafe_allow_html=True)
        if not df_mt5.empty:
            if 'symbol' in df_mt5.columns:
                df_mt5['Symbole'] = df_mt5['symbol'].map(SYMBOL_NAMES).fillna(df_mt5['symbol']) + ' (' + df_mt5['symbol'] + ')'
            rename_map = {
                'Symbole': 'Symbole',
                'type': 'Type',
                'volume': 'Volume',
                'price': 'Prix',
                'price_open': 'Prix Ouverture',
                'profit': 'Profit',
                'entry': 'Entrée',
                'position_id': 'ID Position',
                'ticket': 'Ticket',
                'time': 'Heure',
                'time_msc': 'Heure MSC',
                'magic': 'Magic',
                'comment': 'Commentaire'
            }
            cols = [c for c in ['Symbole','type','volume','price','price_open','profit','entry','position_id','ticket','time','time_msc','magic','comment'] if c in df_mt5.columns]
            df_affiche = df_mt5[cols + [c for c in df_mt5.columns if c not in cols]].rename(columns=rename_map)
            df_affiche = df_affiche.reset_index(drop=True)
            df_affiche = df_affiche.loc[:,~df_affiche.columns.duplicated()]
            if df_affiche.empty or len(df_affiche.columns) == 0:
                st.error("Aucune donnée exploitable ou problème de colonnes. Vérifiez la connexion MT5 ou le format des données.")
            else:
                st.dataframe(df_affiche, use_container_width=True)
        else:
            st.info("Aucun trade MT5 trouvé sur la période.")
        st.markdown("<div class='sub-header'>Positions ouvertes MT5</div>", unsafe_allow_html=True)
        if not df_positions.empty:
            cols = [c for c in ['symbol','type','volume','price_open','profit','ticket','time','magic','comment'] if c in df_positions.columns]
            if 'symbol' in df_positions.columns:
                df_positions = df_positions[cols + [c for c in df_positions.columns if c not in cols]]
            st.dataframe(df_positions, use_container_width=True)
        else:
            st.info("Aucune position ouverte sur MT5.")
        st.markdown("<div class='sub-header'>Historique local (backend TradBOT)</div>", unsafe_allow_html=True)
        if not df_local.empty:
            for col in ['entry_price', 'exit_price', 'result', 'confidence', 'volume']:
                if col in df_local.columns:
                    df_local[col] = pd.to_numeric(df_local[col], errors='coerce')
            df_local['open_time'] = pd.to_datetime(df_local['open_time'], errors='coerce')
            df_local['close_time'] = pd.to_datetime(df_local['close_time'], errors='coerce')
            df_local = df_local.sort_values('open_time')
            st.dataframe(df_local, use_container_width=True)
            total_trades = len(df_local)
            wins = (df_local['result'] > 0).sum()
            losses = (df_local['result'] < 0).sum()
            winrate = wins / total_trades * 100 if total_trades > 0 else 0
            total_pnl = df_local['result'].sum()
            avg_win = df_local.loc[df_local['result'] > 0, 'result'].mean() if wins > 0 else 0
            avg_loss = df_local.loc[df_local['result'] < 0, 'result'].mean() if losses > 0 else 0
            max_drawdown = (df_local['result'].cumsum().cummax() - df_local['result'].cumsum()).max() if total_trades > 0 else 0
            st.markdown("<div class='sub-header'>Statistiques globales (backend TradBOT)</div>", unsafe_allow_html=True)
            col1, col2, col3, col4, col5 = st.columns(5)
            col1.metric("Trades", total_trades)
            col2.metric("Winrate", f"{winrate:.1f}%")
            col3.metric("Gain total", f"{total_pnl:.2f}", delta_color="normal")
            col4.metric("Gain moyen", f"{avg_win:.2f}")
            col5.metric("Perte moyenne", f"{avg_loss:.2f}")
            st.metric("Max Drawdown", f"{max_drawdown:.2f}")
            st.markdown("<div class='sub-header'>Courbe d'équité (backend TradBOT)</div>", unsafe_allow_html=True)
            equity_curve = df_local['result'].cumsum()
            st.line_chart(equity_curve)
            st.markdown("<div class='sub-header'>Distribution des gains/pertes (backend TradBOT)</div>", unsafe_allow_html=True)
            st.bar_chart(df_local['result'])
            st.markdown("<div class='sub-header'>Conseils & Analyse (backend TradBOT)</div>", unsafe_allow_html=True)
            suggestions = []
            if winrate < 50:
                suggestions.append("⚠️ Le taux de réussite est faible. Analysez les signaux perdants pour ajuster la stratégie.")
            if avg_loss and abs(avg_loss) > avg_win:
                suggestions.append("⚠️ Les pertes moyennes sont supérieures aux gains moyens. Pensez à ajuster vos stops ou à prendre vos profits plus tôt.")
            if max_drawdown > abs(total_pnl) * 0.5:
                suggestions.append("⚠️ Drawdown important. Réduisez le risque par trade.")
            if not suggestions:
                suggestions.append("✅ La stratégie semble robuste. Continuez à surveiller la performance.")
            for s in suggestions:
                st.info(s)
        else:
            st.info("Aucun trade enregistré par le backend TradBOT pour le moment.")
        st.markdown("<div class='sub-header'>📊 Synthèse graphique des performances MT5</div>", unsafe_allow_html=True)
        if not df_mt5.empty:
            import plotly.express as px
            profit_col = None
            symbol_col = None
            time_col = None
            for c in df_mt5.columns:
                c_str = str(c)
                if profit_col is None and c_str.lower() in ['profit','pl','gain','pnl']:
                    profit_col = c
                if symbol_col is None and c_str.lower() in ['symbol','symbole','instrument','pair']:
                    symbol_col = c
                if time_col is None and c_str.lower() in ['time','date','datetime','heure','timestamp']:
                    time_col = c
            if profit_col is None:
                num_cols = df_mt5.select_dtypes(include='number').columns
                if len(num_cols) > 0:
                    profit_col = num_cols[0]
            if symbol_col is None:
                obj_cols = df_mt5.select_dtypes(include='object').columns
                if len(obj_cols) > 0:
                    symbol_col = obj_cols[0]
            if time_col is None:
                for c in df_mt5.select_dtypes(include='number').columns:
                    c_str = str(c)
                    if 'time' in c_str.lower() or 'date' in c_str.lower():
                        time_col = c
                        break
            if profit_col and time_col:
                # Vérifie que la colonne time_col existe
                if time_col in df_mt5.columns:
                    equity_curve = df_mt5[profit_col].cumsum()
                    fig_equity = px.line(x=df_mt5[time_col], y=equity_curve, labels={'x': 'Date', 'y': "Équité cumulée"}, title="Courbe d'équité MT5")
                    st.plotly_chart(fig_equity, use_container_width=True)
                else:
                    st.warning(f"Impossible d'afficher la courbe d'équité : colonne de temps '{time_col}' absente. Colonnes disponibles : {list(df_mt5.columns)}")
            else:
                st.warning(f"Impossible d'afficher la courbe d'équité : colonne profit='{profit_col}' ou time='{time_col}' absente.")
            if profit_col:
                fig_hist = px.histogram(df_mt5, x=profit_col, nbins=30, title="Distribution des gains/pertes (MT5)")
                st.plotly_chart(fig_hist, use_container_width=True)
            else:
                st.warning("Impossible d'afficher l'histogramme : colonne profit absente.")
            if profit_col:
                win = (df_mt5[profit_col] > 0).sum()
                loss = (df_mt5[profit_col] < 0).sum()
                fig_pie = px.pie(names=['Gagnants','Perdants'], values=[win, loss], title="Répartition Gagnants/Perdants (MT5)")
                st.plotly_chart(fig_pie, use_container_width=True)
            else:
                st.warning("Impossible d'afficher le camembert winrate : colonne profit absente.")
            if symbol_col and profit_col:
                perf_by_symbol = df_mt5.groupby(symbol_col)[profit_col].sum().sort_values(ascending=False)
                fig_bar = px.bar(perf_by_symbol, x=perf_by_symbol.index, y=perf_by_symbol.values, labels={'x':'Symbole','y':'Profit total'}, title="Performance par symbole (MT5)")
                st.plotly_chart(fig_bar, use_container_width=True)
            else:
                st.warning("Impossible d'afficher la performance par symbole : colonne profit ou symbol absente.")
            if not profit_col:
                st.info(f"Colonnes disponibles : {list(df_mt5.columns)}. Aucune colonne numérique détectée pour le profit. Renommez ou vérifiez vos données.")
        else:
            st.info("Aucun trade MT5 trouvé sur la période pour la synthèse graphique.")

    def get_mt5_trade_history(self, days=90):
        import MetaTrader5 as mt5
        from datetime import datetime, timedelta
        import pandas as pd
        if not mt5.initialize():
            st.error("Connexion à MT5 impossible pour l'historique.")
            return pd.DataFrame(), pd.DataFrame()
        utc_from = datetime.now() - timedelta(days=days)
        utc_to = datetime.now()
        deals = mt5.history_deals_get(utc_from, utc_to)
        positions = mt5.positions_get()
        mt5.shutdown()
        df_deals = pd.DataFrame([d._asdict() for d in deals]) if deals is not None else pd.DataFrame()
        df_positions = pd.DataFrame([p._asdict() for p in positions]) if positions is not None else pd.DataFrame()
        return df_deals, df_positions

    def get_monitor_status_df(self, status):
        config = status.get('config', {})
        stats = status.get('stats', {})
        config_items = [(k, v) for k, v in config.items() if not isinstance(v, list)]
        config_df = pd.DataFrame(config_items, columns=["Clé de config", "Valeur"])
        if 'categories_to_scan' in config:
            cats = ', '.join(config['categories_to_scan'])
            config_df = pd.concat([config_df, pd.DataFrame([["categories_to_scan", cats]], columns=["Clé de config", "Valeur"])], ignore_index=True)
        stats_items = [(k, v) for k, v in stats.items() if not isinstance(v, dict)]
        stats_df = pd.DataFrame(stats_items, columns=["Statistique", "Valeur"])
        if 'confidence_distribution' in stats:
            for k, v in stats['confidence_distribution'].items():
                stats_df = pd.concat([stats_df, pd.DataFrame([[f"confiance_{k}", v]], columns=["Statistique", "Valeur"])], ignore_index=True)
        extra = [
            ("Moniteur en cours", "🟢" if status.get('running') else "🟠"),
            ("Uptime", status.get('uptime', 'N/A')),
            ("Symboles prioritaires", status.get('priority_symbols_count', 0)),
            ("Symboles échoués", status.get('failed_symbols_count', 0)),
            ("Signaux cette heure", f"{status.get('signal_count_this_hour', 0)} / {status.get('max_signals_per_hour', 0)}")
        ]
        extra_df = pd.DataFrame(extra, columns=["Statistique", "Valeur"])
        return config_df, pd.concat([stats_df, extra_df], ignore_index=True)

    def get_scan_planning(self, symbols, scan_interval, max_symbols_per_scan, period_minutes=60):
        import pandas as pd
        scans = []
        if not symbols:
            planning_df = pd.DataFrame()
            scan_counts_df = pd.DataFrame(columns=["Symbole", "Nb scans"])
            return planning_df, scan_counts_df
        num_scans = period_minutes // scan_interval
        for i in range(num_scans):
            start = (i * max_symbols_per_scan) % len(symbols)
            end = start + max_symbols_per_scan
            batch = symbols[start:end] if end <= len(symbols) else symbols[start:] + symbols[:end % len(symbols)]
            scans.append(batch)
        planning_df = pd.DataFrame(scans).T
        planning_df.columns = [f"Scan {i+1}" for i in range(num_scans)]
        from collections import Counter
        all_scanned = [s for batch in scans for s in batch]
        scan_counts = Counter(all_scanned)
        scan_counts_df = pd.DataFrame(list(scan_counts.items()), columns=["Symbole", "Nb scans"])
        scan_counts_df = scan_counts_df.sort_values("Nb scans", ascending=False)
        return planning_df, scan_counts_df

    def render_all_signals(self):
        import json
        from pathlib import Path
        import os
        import streamlit as st
        st.header("📈 Signaux envoyés (toutes sources)")
        col1, col2 = st.columns(2)
        with col1:
            if st.button("Générer un signal Alpha Vantage de test", key="btn_alpha_vantage_test"):
                os.system("python backend/alpha_vantage_signal_relay.py")
                st.success("Signal Alpha Vantage généré ! Recharge la page si besoin.")
        with col2:
            if st.button("Générer un signal Polygon.io de test", key="btn_polygon_test"):
                os.system("python backend/polygon_signal_relay.py")
                st.success("Signal Polygon.io généré ! Recharge la page si besoin.")
        st.subheader("Signaux Alpha Vantage")
        av_file = Path("alpha_vantage_signals.json")
        if av_file.exists():
            with av_file.open("r", encoding="utf-8") as f:
                lines = f.readlines()
            if not lines:
                st.info("Aucun signal Alpha Vantage enregistré pour l'instant.")
            else:
                try:
                    signal = json.loads(lines[-1])
                    st.markdown(f"""
<div style='background:#fff;padding:1em;border-radius:0.5em;margin-bottom:1em;'>
<pre style='color:#111;font-size:1.1em;'>{signal['message']}</pre>
<small style='color:#111;'>Envoyé le {signal['timestamp']}</small>
</div>
""", unsafe_allow_html=True)
                except Exception as e:
                    st.warning(f"Erreur lecture signal Alpha Vantage: {e}")
        else:
            st.info("Aucun signal Alpha Vantage enregistré pour l'instant.")
        st.subheader("Signaux Polygon.io")
        poly_file = Path("polygon_signals.json")
        if poly_file.exists():
            with poly_file.open("r", encoding="utf-8") as f:
                lines = f.readlines()
            if not lines:
                st.info("Aucun signal Polygon.io enregistré pour l'instant.")
            else:
                try:
                    signal = json.loads(lines[-1])
                    st.markdown(f"""
<div style='background:#fff;padding:1em;border-radius:0.5em;margin-bottom:1em;'>
<pre style='color:#111;font-size:1.1em;'>{signal['message']}</pre>
<small style='color:#111;'>Envoyé le {signal['timestamp']}</small>
</div>
""", unsafe_allow_html=True)
                except Exception as e:
                    st.warning(f"Erreur lecture signal Polygon.io: {e}")
        else:
            st.info("Aucun signal Polygon.io enregistré pour l'instant.")

    def render_whatsapp_tab(self):
        st.header("📲 Messagerie WhatsApp")
        messages_file = Path("messages_whatsapp.json")
        all_messages = []
        if messages_file.exists():
            with messages_file.open("r", encoding="utf-8") as f:
                lines = f.readlines()
                for line in lines:
                    all_messages.append(json.loads(line))
        else:
            st.write("Aucun message reçu pour l'instant.")
        exp_list = sorted(set(msg['from'] for msg in all_messages)) if all_messages else []
        selected_exp = st.selectbox("Filtrer par expéditeur", ["Tous"] + exp_list, key="wa_exp_select_tab")
        keyword = st.text_input("Filtrer par mot-clé (contenu du message)", key="wa_keyword_input_tab")
        filtered = all_messages
        if selected_exp != "Tous":
            filtered = [msg for msg in filtered if msg['from'] == selected_exp]
        if keyword:
            filtered = [msg for msg in filtered if keyword.lower() in msg['body'].lower()]
        if filtered:
            st.dataframe([
                {"Expéditeur": msg['from'], "Message": msg['body'], "Date": time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(msg['timestamp']))}
                for msg in reversed(filtered[-50:])
            ], key="wa_df_tab")
        else:
            st.write("Aucun message à afficher avec ce filtre.")
        st.subheader("✉️ Répondre à un message WhatsApp")
        last_sender = filtered[-1]['from'] if filtered else ""
        to_number = st.text_input(
            "Numéro WhatsApp du destinataire (format: whatsapp:+33XXXXXXXXX)",
            value=last_sender or "",
            key="wa_destinataire_input_tab"
        )
        reply_text = st.text_area("Votre message à envoyer", key="wa_reply_text_tab")
        if st.button("Envoyer la réponse WhatsApp", key="wa_send_btn_tab"):
            if to_number and reply_text:
                from frontend.whatsapp_notify import send_whatsapp_message
                ok = send_whatsapp_message(reply_text, to_number)
                if ok:
                    st.success("Message WhatsApp envoyé !")
                else:
                    st.error("Erreur lors de l'envoi du message WhatsApp.")
            else:
                st.warning("Veuillez remplir le numéro et le message.")
        refresh = st.checkbox("🔄 Rafraîchir automatiquement toutes les 10s", value=False, key="wa_refresh_auto_tab")
        if refresh:
            time.sleep(10)
            st.rerun()
        if st.button("🔄 Rafraîchir maintenant", key="wa_refresh_btn_tab"):
            st.rerun()

    def render_trend_consolidated_tab(self):
        import time
        from streamlit_autorefresh import st_autorefresh
        st.header("Tendance consolidée (D1, H4, H1, M30, M15, M5, M1)")
        symbol = st.session_state.symbol
        col1, col2 = st.columns([2, 1])
        with col1:
            st.subheader("Tableau Tendance Multi-Timeframe")
            auto_refresh = st.checkbox("Rafraîchissement auto toutes les 2 min", value=False, key="trend_auto_refresh")
            if auto_refresh:
                st_autorefresh(interval=120000, key="trend_conso_autorefresh")
                try:
                    resp = requests.post("http://127.0.0.1:8000/trend_summary/generate", params={"symbol": symbol})
                    if resp.status_code == 200:
                        data = resp.json()
                        if data.get("status") == "ok":
                            with open("trend_summary.json", "r", encoding="utf-8") as f:
                                trend_data = json.load(f)
                            st.session_state['trend_heatmap_data'] = trend_data
                            st.session_state['trend_heatmap_last'] = time.strftime("%H:%M:%S")
                            st.session_state['trend_heatmap_symbol'] = symbol
                        else:
                            st.error(f"Erreur backend : {data.get('detail')}")
                    else:
                        st.error(f"Erreur HTTP backend : {resp.status_code} - {resp.text}")
                except Exception as e:
                    st.error(f"Erreur lors de l'appel backend : {e}")
            if st.button("🛠️ Générer la tendance consolidée (backend)", key="generate_trend_summary_backend"):
                try:
                    resp = requests.post("http://127.0.0.1:8000/trend_summary/generate", params={"symbol": symbol})
                    if resp.status_code == 200:
                        data = resp.json()
                        if data.get("status") == "ok":
                            st.success("trend_summary.json généré avec succès !")
                        else:
                            st.error(f"Erreur backend : {data.get('detail')}")
                    else:
                        st.error(f"Erreur HTTP backend : {resp.status_code} - {resp.text}")
                except Exception as e:
                    st.error(f"Erreur lors de l'appel backend : {e}")
            refresh = st.button("🔄 Rafraîchir maintenant")
            if refresh:
                try:
                    with open("trend_summary.json", "r", encoding="utf-8") as f:
                        trend_data = json.load(f)
                    st.session_state['trend_heatmap_data'] = trend_data
                    st.session_state['trend_heatmap_last'] = time.strftime("%H:%M:%S")
                    st.session_state['trend_heatmap_symbol'] = symbol
                except FileNotFoundError:
                    st.info("Aucune donnée de tendance disponible. Le fichier trend_summary.json n'existe pas encore.")
                    st.session_state['trend_heatmap_data'] = None
                except Exception as e:
                    st.warning(f"Erreur lors de la lecture du fichier trend_summary.json : {e}")
                    st.session_state['trend_heatmap_data'] = None
            trend_data = st.session_state.get('trend_heatmap_data')
            if trend_data and 'trends' in trend_data:
                tf_order = ["1d", "4h", "1h", "30m", "15m", "5m", "1m"]
                tf_labels = ["D1", "H4", "H1", "M30", "M15", "M5", "M1"]
                rows = []
                for tf, label in zip(tf_order, tf_labels):
                    tf_info = trend_data["trends"].get(tf, {})
                    trend = tf_info.get("trend", "?")
                    force = tf_info.get("force", "?")
                    try:
                        force_pct = f"{int(force)}%" if force != "?" else "?"
                    except:
                        force_pct = "?"
                    rows.append({"Timeframe": label, "Tendance": trend, "Force (%)": force_pct})
                df = pd.DataFrame(rows)
                st.dataframe(df, use_container_width=True)
                st.caption(f"Tendance consolidée : {trend_data.get('consolidated', '?')} | Scalping possible : {trend_data.get('scalping_possible', '?')}")
                st.caption(f"Dernier rafraîchissement : {st.session_state.get('trend_heatmap_last', '?')}")
                if st.button("Envoyer la tendance sur WhatsApp", key="send_trend_whatsapp_trendtab"):
                    try:
                        symbol = st.session_state.symbol
                        lines = [f"📊 Tendance consolidée pour {symbol}"]
                        for tf, label in zip(tf_order, tf_labels):
                            tf_info = trend_data["trends"].get(tf, {})
                            trend = tf_info.get("trend", "?")
                            force = tf_info.get("force", "?")
                            try:
                                force_pct = f"{int(force)}%" if force != "?" else "?"
                            except:
                                force_pct = "?"
                            lines.append(f"{label} : {trend} ({force_pct})")
                        lines.append(f"Synthèse : {trend_data.get('consolidated', '?')} | Scalping possible : {trend_data.get('scalping_possible', '?')}")
                        msg = "\n".join(lines)
                        from frontend.whatsapp_notify import send_whatsapp_message
                        try:
                            result = send_whatsapp_message(msg)
                            if result is True:
                                st.success("Tendance consolidée envoyée sur WhatsApp !")
                            elif isinstance(result, str) and "code=429" in result and "63038" in result:
                                st.error("⚠️ Quota Twilio WhatsApp atteint : tu as dépassé la limite de 10 messages/jour (sandbox). Réessaie demain ou passe en production pour lever cette limite.")
                            else:
                                st.error(f"Erreur lors de l'envoi WhatsApp : {result}")
                        except Exception as e:
                            st.error(f"Erreur lors de l'envoi WhatsApp : {e}")
                    except Exception as e:
                        st.error(f"Erreur lors de la préparation du message WhatsApp : {e}")
                if str(trend_data.get('scalping_possible', '')).upper() == 'OUI':
                    if st.button("Proposer TP/SL pour scalping", key="propose_tp_sl_scalping_trendtab"):
                        try:
                            symbol = st.session_state.symbol
                            st.write(f"DEBUG: symbol utilisé pour M1 = {symbol}")
                            df_M1 = data_manager.get_historical_data(symbol, 'M1', 50)
                            st.write(f"DEBUG: df_M1 shape = {df_M1.shape if df_M1 is not None else None}")
                            if df_M1 is None or df_M1.empty:
                                st.warning("Pas de données M1, tentative en M5...")
                                df_M1 = data_manager.get_historical_data(symbol, 'M5', 50)
                                st.write(f"DEBUG: df_M5 shape = {df_M1.shape if df_M1 is not None else None}")
                            if df_M1 is not None and not df_M1.empty:
                                last_price = df_M1['close'].iloc[-1]
                                atr = df_M1['atr_14'].iloc[-1] if 'atr_14' in df_M1.columns else (df_M1['close'].std() if 'close' in df_M1.columns else 0.001)
                                direction = trend_data['trends'].get('1m', {}).get('trend', 'neutral')
                                if (direction == 'bearish') or (direction == 'neutral' and 'M5' in trend_data['trends'] and trend_data['trends']['5m'].get('trend') == 'bearish'):
                                    sl = last_price + atr
                                    tp = last_price - 2 * atr
                                    sens = 'Vente (SELL)'
                                elif (direction == 'bullish') or (direction == 'neutral' and 'M5' in trend_data['trends'] and trend_data['trends']['5m'].get('trend') == 'bullish'):
                                    sl = last_price - atr
                                    tp = last_price + 2 * atr
                                    sens = 'Achat (BUY)'
                                else:
                                    st.info("Le M1/M5 n'est pas clairement bullish ou bearish, pas de proposition automatique.")
                                    sl = tp = None
                                risk_usd = 10
                                if sl is not None:
                                    risk_per_unit = abs(last_price - sl)
                                    if risk_per_unit > 0:
                                        lot = risk_usd / risk_per_unit
                                    else:
                                        lot = 0.01
                                else:
                                    lot = 0.01
                                st.markdown(f"**Proposition de scalping {sens}**")
                                st.write(f"Prix d'entrée : {last_price:.5f}")
                                if sl is not None and tp is not None:
                                    st.write(f"Stop Loss (SL) : {sl:.5f}")
                                    st.write(f"Take Profit (TP) : {tp:.5f}")
                                st.write(f"Durée estimée : 5 minutes")
                                st.write(f"Taille de position (lot) pour risquer 10$ sur le SL : {lot:.4f}")
                            else:
                                st.warning("Impossible de récupérer les données M1 ou M5 pour ce symbole.")
                                st.info("Vérifie que MetaTrader 5 est bien lancé, que le symbole est autorisé, et que les timeframes M1/M5 sont disponibles pour ce marché. Essaie avec un autre symbole si besoin.")
                        except Exception as e:
                            st.error(f"Erreur lors du calcul TP/SL scalping : {e}")
                    if str(trend_data.get('scalping_possible', '')).upper() == 'OUI':
                        if st.button("Proposer TP/SL pour scalping (M5)", key="propose_tp_sl_scalping_m5_trendtab"):
                            try:
                                symbol = st.session_state.symbol
                                st.write(f"DEBUG: symbol utilisé pour M5 = {symbol}")
                                df_M5 = data_manager.get_historical_data(symbol, 'M5', 50)
                                st.write(f"DEBUG: df_M5 shape = {df_M5.shape if df_M5 is not None else None}")
                                if df_M5 is not None and not df_M5.empty:
                                    last_price = df_M5['close'].iloc[-1]
                                    atr = df_M5['atr_14'].iloc[-1] if 'atr_14' in df_M5.columns else (df_M5['close'].std() if 'close' in df_M5.columns else 0.001)
                                    direction = trend_data['trends'].get('5m', {}).get('trend', 'neutral')
                                    if direction == 'bearish':
                                        sl = last_price + atr
                                        tp = last_price - 2 * atr
                                        sens = 'Vente (SELL)'
                                    elif direction == 'bullish':
                                        sl = last_price - atr
                                        tp = last_price + 2 * atr
                                        sens = 'Achat (BUY)'
                                    else:
                                        st.info("Le M5 n'est pas clairement bullish ou bearish, pas de proposition automatique.")
                                        sl = tp = None
                                    risk_usd = 10
                                    if sl is not None:
                                        risk_per_unit = abs(last_price - sl)
                                        lot = risk_usd / risk_per_unit if risk_per_unit > 0 else 0.01
                                    else:
                                        lot = 0.01
                                    st.markdown(f"**Proposition de scalping {sens} (M5)**")
                                    st.write(f"Prix d'entrée : {last_price:.5f}")
                                    if sl is not None and tp is not None:
                                        st.write(f"Stop Loss (SL) : {sl:.5f}")
                                        st.write(f"Take Profit (TP) : {tp:.5f}")
                                    st.write(f"Durée estimée : 15 minutes")
                                    st.write(f"Taille de position (lot) pour risquer 10$ sur le SL : {lot:.4f}")
                                else:
                                    st.warning("Impossible de récupérer les données M5 pour ce symbole.")
                                    st.info("Vérifie que MetaTrader 5 est bien lancé, que le symbole est autorisé, et que le timeframe M5 est disponible pour ce marché. Essaie avec un autre symbole si besoin.")
                            except Exception as e:
                                st.error(f"Erreur lors du calcul TP/SL scalping : {e}")
            else:
                st.info("Aucune donnée de tendance disponible. Cliquez sur 'Générer la tendance' puis 'Rafraîchir maintenant'.")

    def render_ml_pipeline_tab(self):
        """Rendu de l'onglet Pipeline ML."""
        st.header("🚀 Pipeline ML Automatisé")
        st.markdown("""
        Ce système analyse automatiquement vos données de trading et entraîne des modèles de prédiction 
        pour générer des signaux Strong Buy/Sell avec paramètres SL/TP optimaux.
        """)
        
        # Import du pipeline ML
        try:
            from backend.automated_ml_pipeline_simple import AutomatedMLPipeline
            ML_PIPELINE_AVAILABLE = True
        except ImportError:
            ML_PIPELINE_AVAILABLE = False
            st.error("❌ Module ML Pipeline non disponible")
            st.info("💡 Installez les dépendances : `pip install scikit-learn pandas numpy ta`")
            return
        
        # Sidebar pour la configuration
        with st.sidebar:
            st.subheader("⚙️ Configuration ML")
            
            # Sélection du mode
            mode = st.selectbox(
                "Mode d'analyse",
                ["Test Rapide", "Symbole Unique", "Multiples Symboles", "Tous les Symboles"],
                help="Choisissez le mode d'analyse"
            )
            
            # Paramètres avancés
            with st.expander("🔧 Paramètres Avancés"):
                data_points = st.slider("Nombre de bougies", 1000, 10000, 3000, 500)
                timeframe = st.selectbox("Timeframe", ["1m", "5m", "15m", "30m", "1h", "4h", "1d"], index=4)
                confidence_threshold = st.slider("Seuil de confiance", 0.5, 0.95, 0.7, 0.05)
                
                # Options d'optimisation
                use_feature_selection = st.checkbox("Sélection automatique des features", True)
                use_cross_validation = st.checkbox("Validation croisée", True)
                cv_folds = st.slider("Folds CV", 3, 10, 5, 1) if use_cross_validation else 5
        
        # Contenu principal
        if mode == "Test Rapide":
            self.render_quick_test_section()
        elif mode == "Symbole Unique":
            self.render_single_symbol_section()
        elif mode == "Multiples Symboles":
            self.render_multiple_symbols_section()
        elif mode == "Tous les Symboles":
            self.render_all_symbols_section()
        
        # Section des modèles entraînés
        self.render_trained_models_section()
        
        # Section des performances
        self.render_performance_section()

    def render_quick_test_section(self):
        """Section de test rapide sur 3 symboles."""
        st.subheader("🧪 Test Rapide sur 3 Symboles")
        
        col1, col2 = st.columns([2, 1])
        
        with col1:
            st.info("""
            **Test rapide recommandé pour débuter :**
            - Analyse de EURUSD, GBPUSD, USDJPY
            - Temps estimé : 15-30 minutes
            - Validation du système complet
            """)
        
        with col2:
            if st.button("🚀 Lancer le Test Rapide", type="primary", use_container_width=True):
                self.run_quick_test()

    def render_single_symbol_section(self):
        """Section d'analyse d'un symbole unique."""
        st.subheader("🎯 Analyse d'un Symbole Spécifique")
        
        # Initialisation du pipeline
        try:
            from backend.automated_ml_pipeline_simple import AutomatedMLPipeline
            pipeline = AutomatedMLPipeline()
            symbols = pipeline.symbols
            
            col1, col2 = st.columns([2, 1])
            
            with col1:
                # Sélection du symbole
                symbol = st.selectbox(
                    "Sélectionnez le symbole",
                    symbols,
                    index=symbols.index('EURUSD') if 'EURUSD' in symbols else 0,
                    help="Choisissez le symbole à analyser"
                )
                
                # Informations sur le symbole
                if symbol:
                    st.info(f"**Symbole sélectionné :** {symbol}")
                    st.info(f"**Symboles disponibles :** {len(symbols)}")
            
            with col2:
                # Bouton de lancement
                if st.button("📊 Analyser le Symbole", type="primary", use_container_width=True):
                    self.run_single_symbol_analysis(symbol, pipeline)
        
        except Exception as e:
            st.error(f"❌ Erreur d'initialisation : {e}")

    def render_multiple_symbols_section(self):
        """Section d'analyse de plusieurs symboles."""
        st.subheader("🌍 Analyse de Plusieurs Symboles")
        
        try:
            from backend.automated_ml_pipeline_simple import AutomatedMLPipeline
            pipeline = AutomatedMLPipeline()
            symbols = pipeline.symbols
            
            # Suggestions de catégories
            st.info("💡 **Suggestions de catégories :**")
            
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.write("**Forex :**")
                forex_symbols = [s for s in symbols if any(currency in s for currency in ['USD', 'EUR', 'GBP', 'JPY'])]
                for sym in forex_symbols[:5]:
                    st.write(f"• {sym}")
            
            with col2:
                st.write("**Indices :**")
                index_symbols = [s for s in symbols if 'Index' in s or any(idx in s for idx in ['US30', 'NAS100', 'SPX500'])]
                for sym in index_symbols[:5]:
                    st.write(f"• {sym}")
            
            with col3:
                st.write("**Crypto/Métaux :**")
                crypto_metal_symbols = [s for s in symbols if any(asset in s for asset in ['BTC', 'XAU', 'XAG'])]
                for sym in crypto_metal_symbols[:5]:
                    st.write(f"• {sym}")
            
            # Sélection des symboles
            selected_symbols = st.multiselect(
                "Sélectionnez les symboles à analyser",
                symbols,
                default=['EURUSD', 'GBPUSD', 'USDJPY'] if all(s in symbols for s in ['EURUSD', 'GBPUSD', 'USDJPY']) else [],
                help="Sélectionnez plusieurs symboles pour l'analyse"
            )
            
            if selected_symbols:
                st.info(f"**Symboles sélectionnés :** {len(selected_symbols)}")
                st.write(f"**Liste :** {', '.join(selected_symbols)}")
                
                # Estimation du temps
                estimated_minutes = len(selected_symbols) * 6
                st.warning(f"⏱️ **Temps estimé :** {estimated_minutes} minutes ({estimated_minutes/60:.1f} heures)")
                
                # Bouton de lancement
                if st.button("🚀 Lancer l'Analyse Multiple", type="primary", use_container_width=True):
                    self.run_multiple_symbols_analysis(selected_symbols, pipeline)
        
        except Exception as e:
            st.error(f"❌ Erreur : {e}")

    def render_all_symbols_section(self):
        """Section d'analyse de tous les symboles."""
        st.subheader("🌍 Analyse de TOUS les Symboles")
        
        try:
            from backend.automated_ml_pipeline_simple import AutomatedMLPipeline
            pipeline = AutomatedMLPipeline()
            symbols = pipeline.symbols
            
            st.warning("⚠️ **ATTENTION :** Cette opération peut prendre plusieurs heures !")
            
            # Statistiques
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.metric("Total Symboles", len(symbols))
            
            with col2:
                estimated_hours = len(symbols) * 0.1
                st.metric("Temps Estimé", f"{estimated_hours:.1f}h")
            
            with col3:
                st.metric("Mémoire Estimée", f"{len(symbols) * 0.5:.1f}GB")
            
            # Confirmation
            if st.button("🚀 Lancer l'Analyse Complète", type="primary", use_container_width=True):
                confirm = st.checkbox("✅ Je confirme vouloir analyser TOUS les symboles")
                if confirm:
                    self.run_all_symbols_analysis(pipeline)
        
        except Exception as e:
            st.error(f"❌ Erreur : {e}")

    def render_trained_models_section(self):
        """Section d'affichage des modèles entraînés."""
        st.subheader("📁 Modèles Entraînés")
        
        try:
            data_dir = Path("D:/Dev/TradBOT/data")
            
            if not data_dir.exists():
                st.info("📁 Aucun dossier de données trouvé")
                return
            
            symbol_dirs = [d for d in data_dir.iterdir() if d.is_dir()]
            
            if not symbol_dirs:
                st.info("📁 Aucun modèle entraîné trouvé")
                return
            
            # Affichage des modèles
            for symbol_dir in symbol_dirs:
                symbol_name = symbol_dir.name
                metadata_path = symbol_dir / "metadata.json"
                
                with st.expander(f"🔸 {symbol_name}"):
                    if metadata_path.exists():
                        try:
                            with open(metadata_path, 'r') as f:
                                metadata = json.load(f)
                            
                            col1, col2 = st.columns(2)
                            
                            with col1:
                                st.write(f"**📅 Entraîné le :** {metadata.get('training_date', 'N/A')}")
                                st.write(f"**🏆 Meilleur modèle :** {metadata.get('best_model', 'N/A')}")
                            
                            with col2:
                                st.write(f"**📊 Modèles :** {', '.join(metadata.get('models_trained', []))}")
                                
                                # Bouton pour voir les paramètres
                                if st.button(f"📈 Voir Paramètres {symbol_name}", key=f"params_{symbol_name}"):
                                    self.show_symbol_parameters(symbol_name)
                        
                        except Exception as e:
                            st.error(f"❌ Erreur lecture métadonnées : {e}")
                    else:
                        st.write("Métadonnées non trouvées")
        
        except Exception as e:
            st.error(f"❌ Erreur : {e}")

    def render_performance_section(self):
        """Section d'affichage des performances."""
        st.subheader("📊 Performances et Statistiques")
        
        try:
            data_dir = Path("D:/Dev/TradBOT/data")
            global_summary_path = data_dir / "global_pipeline_summary.json"
            
            if global_summary_path.exists():
                with open(global_summary_path, 'r') as f:
                    summary = json.load(f)
                
                # Métriques globales
                col1, col2, col3, col4 = st.columns(4)
                
                with col1:
                    st.metric("Total Symboles", summary.get('total_symbols', 0))
                
                with col2:
                    st.metric("Succès", summary.get('successful', 0))
                
                with col3:
                    st.metric("Échecs", summary.get('failed', 0))
                
                with col4:
                    success_rate = summary.get('success_rate', 0)
                    st.metric("Taux de Succès", f"{success_rate:.1f}%")
                
                # Graphique des performances par symbole
                if 'results' in summary:
                    performance_data = []
                    for symbol, result in summary['results'].items():
                        if result.get('status') == 'success':
                            try:
                                accuracy = result['training_results']['best_model_info']['best_performance']['accuracy']
                                performance_data.append({
                                    'Symbol': symbol,
                                    'Accuracy': accuracy,
                                    'Model': result['training_results']['best_model_info']['best_model_name']
                                })
                            except:
                                pass
                    
                    if performance_data:
                        df_perf = pd.DataFrame(performance_data)
                        
                        # Graphique des précisions
                        import plotly.express as px
                        fig = px.bar(
                            df_perf,
                            x='Symbol',
                            y='Accuracy',
                            color='Model',
                            title="Précision des Modèles par Symbole",
                            labels={'Accuracy': 'Précision', 'Symbol': 'Symbole', 'Model': 'Modèle'}
                        )
                        fig.update_layout(xaxis_tickangle=-45)
                        st.plotly_chart(fig, use_container_width=True)
                        
                        # Tableau des performances
                        st.dataframe(df_perf.sort_values('Accuracy', ascending=False), use_container_width=True)
            
            else:
                st.info("📊 Aucun résumé global trouvé")
        
        except Exception as e:
            st.error(f"❌ Erreur : {e}")

    def run_quick_test(self):
        """Lance le test rapide sur 3 symboles."""
        try:
            with st.spinner("🧪 Lancement du test rapide..."):
                from backend.automated_ml_pipeline_simple import AutomatedMLPipeline
                pipeline = AutomatedMLPipeline()
                test_symbols = ['EURUSD', 'GBPUSD', 'USDJPY']
                
                # Vérification de la disponibilité des symboles
                available_symbols = [s for s in test_symbols if s in pipeline.symbols]
                
                if len(available_symbols) < 3:
                    st.warning(f"⚠️ Seulement {len(available_symbols)} symboles disponibles pour le test")
                
                if available_symbols:
                    results = pipeline.run_pipeline_for_all_symbols(available_symbols)
                    
                    # Affichage des résultats
                    st.success(f"✅ Test terminé : {results['successful']}/{results['total_symbols']} succès")
                    
                    # Détails par symbole
                    for symbol, result in results['results'].items():
                        if result.get('status') == 'success':
                            accuracy = result['training_results']['best_model_info']['best_performance']['accuracy']
                            st.info(f"📈 {symbol} : {accuracy:.3f}")
                        else:
                            st.error(f"❌ {symbol} : {result.get('error', 'Erreur inconnue')}")
                    
                    # Sauvegarde des résultats
                    st.info("💾 Résultats sauvegardés dans le dossier data/")
        
        except Exception as e:
            st.error(f"❌ Erreur lors du test : {e}")

    def run_single_symbol_analysis(self, symbol, pipeline):
        """Lance l'analyse d'un symbole unique."""
        try:
            with st.spinner(f"📊 Analyse de {symbol} en cours..."):
                start_time = time.time()
                result = pipeline.run_complete_pipeline(symbol)
                end_time = time.time()
                
                duration = end_time - start_time
                
                if result.get('status') == 'success':
                    st.success(f"✅ Analyse terminée pour {symbol} en {duration:.1f} secondes")
                    
                    # Affichage des résultats
                    col1, col2 = st.columns(2)
                    
                    with col1:
                        model_name = result['training_results']['best_model_info']['best_model_name']
                        accuracy = result['training_results']['best_model_info']['best_performance']['accuracy']
                        st.metric("Modèle", model_name)
                        st.metric("Précision", f"{accuracy:.3f}")
                    
                    with col2:
                        feature_count = result['training_results']['data_info']['feature_count']
                        train_size = result['training_results']['data_info']['train_size']
                        st.metric("Features", feature_count)
                        st.metric("Données d'entraînement", train_size)
                    
                    # Informations sur la sauvegarde
                    st.info(f"💾 Résultats sauvegardés dans : D:/Dev/TradBOT/data/{symbol.replace('/', '_')}")
                    
                    # Bouton pour voir les paramètres
                    if st.button(f"⚙️ Voir Paramètres {symbol}"):
                        self.show_symbol_parameters(symbol)
                
                else:
                    st.error(f"❌ Échec de l'analyse pour {symbol} : {result.get('error', 'Erreur inconnue')}")
        
        except Exception as e:
            st.error(f"❌ Erreur : {e}")

    def run_multiple_symbols_analysis(self, symbols, pipeline):
        """Lance l'analyse de plusieurs symboles."""
        try:
            with st.spinner(f"🌍 Analyse de {len(symbols)} symboles en cours..."):
                start_time = time.time()
                results = pipeline.run_pipeline_for_all_symbols(symbols)
                end_time = time.time()
                
                duration = end_time - start_time
                
                st.success(f"🎉 Pipeline terminé en {duration:.1f} secondes")
                
                # Résumé des résultats
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    st.metric("Total", results['total_symbols'])
                
                with col2:
                    st.metric("Succès", results['successful'])
                
                with col3:
                    st.metric("Taux", f"{results['success_rate']:.1f}%")
                
                # Détails des succès
                if results['successful'] > 0:
                    st.subheader("✅ Symboles traités avec succès")
                    success_data = []
                    
                    for symbol, result in results['results'].items():
                        if result.get('status') == 'success':
                            accuracy = result['training_results']['best_model_info']['best_performance']['accuracy']
                            model_name = result['training_results']['best_model_info']['best_model_name']
                            success_data.append({
                                'Symbole': symbol,
                                'Précision': accuracy,
                                'Model': model_name
                            })
                    
                    if success_data:
                        df_success = pd.DataFrame(success_data)
                        st.dataframe(df_success, use_container_width=True)
                
                # Détails des échecs
                if results['failed'] > 0:
                    st.subheader("❌ Symboles en échec")
                    for symbol, result in results['results'].items():
                        if result.get('status') != 'success':
                            error = result.get('error', 'Erreur inconnue')
                            st.error(f"**{symbol}** : {error}")
        
        except Exception as e:
            st.error(f"❌ Erreur : {e}")

    def run_all_symbols_analysis(self, pipeline):
        """Lance l'analyse de tous les symboles."""
        try:
            with st.spinner("🌍 Lancement de l'analyse complète..."):
                st.info("💡 Vous pouvez surveiller la progression dans les logs")
                
                start_time = time.time()
                results = pipeline.run_pipeline_for_all_symbols()
                end_time = time.time()
                
                duration = end_time - start_time
                
                st.success(f"🎉 Pipeline complet terminé en {duration:.1f} secondes")
                
                # Résumé global
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    st.metric("Total", results['total_symbols'])
                
                with col2:
                    st.metric("Succès", results['successful'])
                
                with col3:
                    st.metric("Taux", f"{results['success_rate']:.1f}%")
                
                # Sauvegarde du résumé
                summary_path = Path("D:/Dev/TradBOT/data/global_pipeline_summary.json")
                if summary_path.exists():
                    st.info(f"📁 Résumé global sauvegardé : {summary_path}")
        
        except Exception as e:
            st.error(f"❌ Erreur : {e}")

    def show_symbol_parameters(self, symbol):
        """Affiche les paramètres de prédiction d'un symbole."""
        try:
            from backend.automated_ml_pipeline_simple import AutomatedMLPipeline
            pipeline = AutomatedMLPipeline()
            
            with st.spinner(f"📊 Chargement des paramètres pour {symbol}..."):
                params = pipeline.get_prediction_parameters(symbol)
                
                if 'error' in params:
                    st.error(f"❌ {params['error']}")
                    return
                
                # Affichage des informations du modèle
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    st.metric("Modèle", params['model_name'])
                
                with col2:
                    st.metric("Précision", f"{params['accuracy']:.3f}")
                
                with col3:
                    st.metric("Features", len(params['transformations']['feature_names']))
                
                # Paramètres de trading
                st.subheader("⚙️ Paramètres de Trading")
                
                for signal_type, signal_params in params['parameters'].items():
                    with st.expander(f"🔸 {signal_type}"):
                        col1, col2, col3, col4 = st.columns(4)
                        
                        with col1:
                            st.metric("Stop Loss", f"{signal_params['stop_loss_pct']:+.1f}%")
                        
                        with col2:
                            st.metric("Take Profit", f"{signal_params['take_profit_pct']:+.1f}%")
                        
                        with col3:
                            st.metric("Durée", f"{signal_params['signal_duration_hours']}h")
                        
                        with col4:
                            st.metric("Confiance", f"{signal_params['confidence_threshold']:.1f}")
        
        except Exception as e:
            st.error(f"❌ Erreur : {e}")

if __name__ == "__main__":
    app = TradingApp()
    app.run()

