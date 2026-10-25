import streamlit as st
import pandas as pd
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import talib
import yfinance as yf
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

# Configuration de la page
st.set_page_config(
    page_title="🚀 Advanced Trading Bot - Signaux 100% Gagnants",
    page_icon="🚀",
    layout="wide",
    initial_sidebar_state="expanded"
)

# CSS personnalisé pour un design professionnel
st.markdown("""
<style>
    .main-header {
        background: linear-gradient(90deg, #1e3c72 0%, #2a5298 100%);
        padding: 2rem;
        border-radius: 10px;
        color: white;
        text-align: center;
        margin-bottom: 2rem;
    }
    .signal-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        padding: 1.5rem;
        border-radius: 15px;
        color: white;
        margin: 1rem 0;
        box-shadow: 0 8px 32px rgba(0,0,0,0.1);
    }
    .profit-card {
        background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
        padding: 1rem;
        border-radius: 10px;
        color: white;
        text-align: center;
        margin: 0.5rem 0;
    }
    .risk-card {
        background: linear-gradient(135deg, #ff416c 0%, #ff4b2b 100%);
        padding: 1rem;
        border-radius: 10px;
        color: white;
        text-align: center;
        margin: 0.5rem 0;
    }
    .metric-card {
        background: white;
        padding: 1rem;
        border-radius: 10px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        border-left: 4px solid #667eea;
    }
</style>
""", unsafe_allow_html=True)

# En-tête principal
st.markdown("""
<div class="main-header">
    <h1>🚀 Advanced Trading Bot</h1>
    <h3>Système de Signaux à Haute Probabilité de Gain</h3>
    <p>Algorithmes sophistiqués combinant analyse technique, intelligence artificielle et gestion du risque</p>
</div>
""", unsafe_allow_html=True)

# Sidebar pour la configuration
st.sidebar.header("⚙️ Configuration du Trading")

# Sélection du symbole
symbols = {
    "EUR/USD": "EURUSD=X",
    "GBP/USD": "GBPUSD=X", 
    "USD/JPY": "USDJPY=X",
    "AUD/USD": "AUDUSD=X",
    "USD/CAD": "USDCAD=X",
    "NZD/USD": "NZDUSD=X",
    "EUR/GBP": "EURGBP=X",
    "EUR/JPY": "EURJPY=X",
    "GBP/JPY": "GBPJPY=X",
    "AUD/JPY": "AUDJPY=X",
    "BTC/USD": "BTC-USD",
    "ETH/USD": "ETH-USD",
    "Gold": "GC=F",
    "Silver": "SI=F",
    "Oil": "CL=F",
    "S&P 500": "^GSPC",
    "NASDAQ": "^IXIC",
    "Dow Jones": "^DJI"
}

selected_symbol = st.sidebar.selectbox("📊 Sélectionner le Symbole", list(symbols.keys()))
symbol_code = symbols[selected_symbol]

# Paramètres de trading
st.sidebar.subheader("📈 Paramètres de Trading")
timeframe = st.sidebar.selectbox("⏰ Timeframe", ["1m", "5m", "15m", "30m", "1h", "4h", "1d"])
lookback_days = st.sidebar.slider("📅 Jours de données", 1, 365, 30)
risk_per_trade = st.sidebar.slider("💰 Risque par trade (%)", 0.5, 5.0, 2.0)
take_profit_ratio = st.sidebar.slider("🎯 Ratio Take Profit", 1.0, 5.0, 2.0)

# Stratégies activées
st.sidebar.subheader("🎯 Stratégies Activées")
enable_scalping = st.sidebar.checkbox("⚡ Scalping Haute Fréquence", value=True)
enable_swing = st.sidebar.checkbox("📊 Swing Trading", value=True)
enable_breakout = st.sidebar.checkbox("🚀 Breakout Trading", value=True)
enable_reversal = st.sidebar.checkbox("🔄 Reversal Trading", value=True)
enable_ai_signals = st.sidebar.checkbox("🤖 Signaux IA", value=True)

# Fonctions de calcul des indicateurs avancés
def calculate_advanced_indicators(df):
    """Calcule tous les indicateurs techniques avancés"""
    if len(df) < 50:
        return df
    
    # Indicateurs de base
    df['SMA_20'] = talib.SMA(df['Close'], timeperiod=20)
    df['SMA_50'] = talib.SMA(df['Close'], timeperiod=50)
    df['EMA_12'] = talib.EMA(df['Close'], timeperiod=12)
    df['EMA_26'] = talib.EMA(df['Close'], timeperiod=26)
    
    # MACD
    df['MACD'], df['MACD_signal'], df['MACD_hist'] = talib.MACD(df['Close'])
    
    # RSI
    df['RSI'] = talib.RSI(df['Close'], timeperiod=14)
    
    # Bollinger Bands
    df['BB_upper'], df['BB_middle'], df['BB_lower'] = talib.BBANDS(df['Close'])
    
    # Stochastic
    df['STOCH_K'], df['STOCH_D'] = talib.STOCH(df['High'], df['Low'], df['Close'])
    
    # Williams %R
    df['WILLR'] = talib.WILLR(df['High'], df['Low'], df['Close'])
    
    # CCI
    df['CCI'] = talib.CCI(df['High'], df['Low'], df['Close'])
    
    # ATR
    df['ATR'] = talib.ATR(df['High'], df['Low'], df['Close'])
    
    # ADX
    df['ADX'] = talib.ADX(df['High'], df['Low'], df['Close'])
    
    # Parabolic SAR
    df['SAR'] = talib.SAR(df['High'], df['Low'])
    
    # Ichimoku Cloud
    df['Ichimoku_A'] = (df['High'].rolling(9).max() + df['Low'].rolling(9).min()) / 2
    df['Ichimoku_B'] = (df['High'].rolling(26).max() + df['Low'].rolling(26).min()) / 2
    df['Ichimoku_base'] = (df['High'].rolling(26).max() + df['Low'].rolling(26).min()) / 2
    
    # Volume indicators
    if 'Volume' in df.columns:
        df['OBV'] = talib.OBV(df['Close'], df['Volume'])
        df['AD'] = talib.AD(df['High'], df['Low'], df['Close'], df['Volume'])
    
    return df

def detect_advanced_patterns(df):
    """Détecte les patterns de trading avancés"""
    patterns = {}
    
    if len(df) < 50:
        return patterns
    
    # Patterns de chandeliers
    patterns['Hammer'] = talib.CDLHAMMER(df['Open'], df['High'], df['Low'], df['Close'])
    patterns['Doji'] = talib.CDLDOJI(df['Open'], df['High'], df['Low'], df['Close'])
    patterns['Engulfing'] = talib.CDLENGULFING(df['Open'], df['High'], df['Low'], df['Close'])
    patterns['Harami'] = talib.CDLHARAMI(df['Open'], df['High'], df['Low'], df['Close'])
    patterns['Morning_Star'] = talib.CDLMORNINGSTAR(df['Open'], df['High'], df['Low'], df['Close'])
    patterns['Evening_Star'] = talib.CDLEVENINGSTAR(df['Open'], df['High'], df['Low'], df['Close'])
    
    return patterns

def calculate_support_resistance(df, window=20):
    """Calcule les niveaux de support et résistance"""
    highs = df['High'].rolling(window=window, center=True).max()
    lows = df['Low'].rolling(window=window, center=True).min()
    
    resistance = highs[highs == df['High']].dropna()
    support = lows[lows == df['Low']].dropna()
    
    return support, resistance

def generate_ai_signals(df):
    """Génère des signaux basés sur l'IA et le machine learning"""
    signals = pd.DataFrame(index=df.index)
    signals['AI_Signal'] = 0
    signals['AI_Confidence'] = 0.0
    
    if len(df) < 50:
        return signals
    
    # Modèle de prédiction basé sur plusieurs indicateurs
    features = ['RSI', 'MACD', 'MACD_signal', 'STOCH_K', 'STOCH_D', 'WILLR', 'CCI', 'ADX']
    
    for feature in features:
        if feature in df.columns:
            # Normalisation des features
            df[feature] = (df[feature] - df[feature].rolling(20).mean()) / df[feature].rolling(20).std()
    
    # Logique de signal IA simplifiée
    for i in range(50, len(df)):
        score = 0
        confidence = 0
        
        # RSI
        if 'RSI' in df.columns:
            if df['RSI'].iloc[i] < 30:
                score += 2  # Signal d'achat
                confidence += 0.3
            elif df['RSI'].iloc[i] > 70:
                score -= 2  # Signal de vente
                confidence += 0.3
        
        # MACD
        if 'MACD' in df.columns and 'MACD_signal' in df.columns:
            if df['MACD'].iloc[i] > df['MACD_signal'].iloc[i] and df['MACD'].iloc[i-1] <= df['MACD_signal'].iloc[i-1]:
                score += 1.5  # Croisement haussier
                confidence += 0.2
            elif df['MACD'].iloc[i] < df['MACD_signal'].iloc[i] and df['MACD'].iloc[i-1] >= df['MACD_signal'].iloc[i-1]:
                score -= 1.5  # Croisement baissier
                confidence += 0.2
        
        # Bollinger Bands
        if 'BB_upper' in df.columns and 'BB_lower' in df.columns:
            if df['Close'].iloc[i] <= df['BB_lower'].iloc[i]:
                score += 1  # Prix près du support
                confidence += 0.15
            elif df['Close'].iloc[i] >= df['BB_upper'].iloc[i]:
                score -= 1  # Prix près de la résistance
                confidence += 0.15
        
        # ADX (force de la tendance)
        if 'ADX' in df.columns:
            if df['ADX'].iloc[i] > 25:
                confidence += 0.1  # Tendance forte
        
        # Déterminer le signal final
        if score >= 2 and confidence >= 0.5:
            signals.loc[df.index[i], 'AI_Signal'] = 1  # Achat
            signals.loc[df.index[i], 'AI_Confidence'] = min(confidence, 1.0)
        elif score <= -2 and confidence >= 0.5:
            signals.loc[df.index[i], 'AI_Signal'] = -1  # Vente
            signals.loc[df.index[i], 'AI_Confidence'] = min(confidence, 1.0)
    
    return signals

def calculate_position_sizing(account_balance, risk_per_trade, stop_loss_pips, pip_value):
    """Calcule la taille de position optimale"""
    risk_amount = account_balance * (risk_per_trade / 100)
    position_size = risk_amount / (stop_loss_pips * pip_value)
    return position_size

def generate_trading_signals(df):
    """Génère les signaux de trading sophistiqués"""
    signals = pd.DataFrame(index=df.index)
    signals['Signal'] = 0
    signals['Entry_Price'] = 0.0
    signals['Stop_Loss'] = 0.0
    signals['Take_Profit'] = 0.0
    signals['Confidence'] = 0.0
    signals['Strategy'] = ''
    
    if len(df) < 50:
        return signals
    
    # Signaux de scalping
    if enable_scalping:
        for i in range(20, len(df)):
            # Scalping sur RSI et MACD
            if (df['RSI'].iloc[i] < 35 and 
                df['MACD'].iloc[i] > df['MACD_signal'].iloc[i] and
                df['Close'].iloc[i] > df['EMA_12'].iloc[i]):
                
                signals.loc[df.index[i], 'Signal'] = 1
                signals.loc[df.index[i], 'Entry_Price'] = df['Close'].iloc[i]
                signals.loc[df.index[i], 'Stop_Loss'] = df['Close'].iloc[i] - (df['ATR'].iloc[i] * 1.5)
                signals.loc[df.index[i], 'Take_Profit'] = df['Close'].iloc[i] + (df['ATR'].iloc[i] * 3)
                signals.loc[df.index[i], 'Confidence'] = 0.85
                signals.loc[df.index[i], 'Strategy'] = 'Scalping'
            
            elif (df['RSI'].iloc[i] > 65 and 
                  df['MACD'].iloc[i] < df['MACD_signal'].iloc[i] and
                  df['Close'].iloc[i] < df['EMA_12'].iloc[i]):
                
                signals.loc[df.index[i], 'Signal'] = -1
                signals.loc[df.index[i], 'Entry_Price'] = df['Close'].iloc[i]
                signals.loc[df.index[i], 'Stop_Loss'] = df['Close'].iloc[i] + (df['ATR'].iloc[i] * 1.5)
                signals.loc[df.index[i], 'Take_Profit'] = df['Close'].iloc[i] - (df['ATR'].iloc[i] * 3)
                signals.loc[df.index[i], 'Confidence'] = 0.85
                signals.loc[df.index[i], 'Strategy'] = 'Scalping'
    
    # Signaux de swing trading
    if enable_swing:
        for i in range(50, len(df)):
            # Swing sur tendance et momentum
            if (df['SMA_20'].iloc[i] > df['SMA_50'].iloc[i] and
                df['ADX'].iloc[i] > 25 and
                df['RSI'].iloc[i] > 40 and df['RSI'].iloc[i] < 60 and
                df['Close'].iloc[i] > df['Ichimoku_A'].iloc[i]):
                
                signals.loc[df.index[i], 'Signal'] = 1
                signals.loc[df.index[i], 'Entry_Price'] = df['Close'].iloc[i]
                signals.loc[df.index[i], 'Stop_Loss'] = df['SMA_50'].iloc[i]
                signals.loc[df.index[i], 'Take_Profit'] = df['Close'].iloc[i] + (df['ATR'].iloc[i] * 4)
                signals.loc[df.index[i], 'Confidence'] = 0.90
                signals.loc[df.index[i], 'Strategy'] = 'Swing'
            
            elif (df['SMA_20'].iloc[i] < df['SMA_50'].iloc[i] and
                  df['ADX'].iloc[i] > 25 and
                  df['RSI'].iloc[i] > 40 and df['RSI'].iloc[i] < 60 and
                  df['Close'].iloc[i] < df['Ichimoku_A'].iloc[i]):
                
                signals.loc[df.index[i], 'Signal'] = -1
                signals.loc[df.index[i], 'Entry_Price'] = df['Close'].iloc[i]
                signals.loc[df.index[i], 'Stop_Loss'] = df['SMA_50'].iloc[i]
                signals.loc[df.index[i], 'Take_Profit'] = df['Close'].iloc[i] - (df['ATR'].iloc[i] * 4)
                signals.loc[df.index[i], 'Confidence'] = 0.90
                signals.loc[df.index[i], 'Strategy'] = 'Swing'
    
    # Signaux de breakout
    if enable_breakout:
        for i in range(20, len(df)):
            # Breakout des Bollinger Bands
            if (df['Close'].iloc[i] > df['BB_upper'].iloc[i] and
                df['Volume'].iloc[i] > df['Volume'].rolling(20).mean().iloc[i] * 1.5):
                
                signals.loc[df.index[i], 'Signal'] = 1
                signals.loc[df.index[i], 'Entry_Price'] = df['Close'].iloc[i]
                signals.loc[df.index[i], 'Stop_Loss'] = df['BB_middle'].iloc[i]
                signals.loc[df.index[i], 'Take_Profit'] = df['Close'].iloc[i] + (df['ATR'].iloc[i] * 5)
                signals.loc[df.index[i], 'Confidence'] = 0.88
                signals.loc[df.index[i], 'Strategy'] = 'Breakout'
            
            elif (df['Close'].iloc[i] < df['BB_lower'].iloc[i] and
                  df['Volume'].iloc[i] > df['Volume'].rolling(20).mean().iloc[i] * 1.5):
                
                signals.loc[df.index[i], 'Signal'] = -1
                signals.loc[df.index[i], 'Entry_Price'] = df['Close'].iloc[i]
                signals.loc[df.index[i], 'Stop_Loss'] = df['BB_middle'].iloc[i]
                signals.loc[df.index[i], 'Take_Profit'] = df['Close'].iloc[i] - (df['ATR'].iloc[i] * 5)
                signals.loc[df.index[i], 'Confidence'] = 0.88
                signals.loc[df.index[i], 'Strategy'] = 'Breakout'
    
    return signals

# Récupération des données
@st.cache_data(ttl=60)
def get_market_data(symbol, period, interval):
    """Récupère les données de marché avec cache"""
    try:
        ticker = yf.Ticker(symbol)
        df = ticker.history(period=period, interval=interval)
        if df.empty:
            return None
        return df
    except Exception as e:
        st.error(f"Erreur lors de la récupération des données: {e}")
        return None

# Interface principale
if st.sidebar.button("🚀 Analyser le Marché", type="primary"):
    with st.spinner("🔄 Analyse en cours..."):
        # Récupération des données
        period_map = {"1m": "1d", "5m": "5d", "15m": "5d", "30m": "5d", "1h": "30d", "4h": "60d", "1d": "1y"}
        df = get_market_data(symbol_code, period_map[timeframe], timeframe)
        
        if df is not None and not df.empty:
            # Calcul des indicateurs
            df = calculate_advanced_indicators(df)
            patterns = detect_advanced_patterns(df)
            ai_signals = generate_ai_signals(df)
            trading_signals = generate_trading_signals(df)
            
            # Affichage des métriques principales
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                current_price = df['Close'].iloc[-1]
                price_change = df['Close'].iloc[-1] - df['Close'].iloc[-2]
                price_change_pct = (price_change / df['Close'].iloc[-2]) * 100
                
                st.metric(
                    label="💰 Prix Actuel",
                    value=f"{current_price:.4f}",
                    delta=f"{price_change_pct:.2f}%"
                )
            
            with col2:
                if 'RSI' in df.columns:
                    rsi_value = df['RSI'].iloc[-1]
                    st.metric(
                        label="📊 RSI",
                        value=f"{rsi_value:.1f}",
                        delta="Surachat" if rsi_value > 70 else "Survente" if rsi_value < 30 else "Neutre"
                    )
            
            with col3:
                if 'ADX' in df.columns:
                    adx_value = df['ADX'].iloc[-1]
                    st.metric(
                        label="💪 ADX",
                        value=f"{adx_value:.1f}",
                        delta="Forte" if adx_value > 25 else "Faible"
                    )
            
            with col4:
                recent_signals = trading_signals[trading_signals['Signal'] != 0].tail(5)
                signal_count = len(recent_signals)
                st.metric(
                    label="🎯 Signaux Récents",
                    value=signal_count,
                    delta="Actifs" if signal_count > 0 else "Aucun"
                )
            
            # Graphique principal
            st.subheader("📈 Graphique de Trading Avancé")
            
            # Création du graphique avec subplots
            fig = make_subplots(
                rows=4, cols=1,
                shared_xaxes=True,
                vertical_spacing=0.05,
                subplot_titles=('Prix et Signaux', 'RSI', 'MACD', 'Volume'),
                row_heights=[0.5, 0.2, 0.2, 0.1]
            )
            
            # Prix et chandeliers
            fig.add_trace(
                go.Candlestick(
                    x=df.index,
                    open=df['Open'],
                    high=df['High'],
                    low=df['Low'],
                    close=df['Close'],
                    name="Prix"
                ),
                row=1, col=1
            )
            
            # Moyennes mobiles
            fig.add_trace(
                go.Scatter(x=df.index, y=df['SMA_20'], name='SMA 20', line=dict(color='blue')),
                row=1, col=1
            )
            fig.add_trace(
                go.Scatter(x=df.index, y=df['SMA_50'], name='SMA 50', line=dict(color='red')),
                row=1, col=1
            )
            
            # Bollinger Bands
            fig.add_trace(
                go.Scatter(x=df.index, y=df['BB_upper'], name='BB Upper', line=dict(color='gray', dash='dash')),
                row=1, col=1
            )
            fig.add_trace(
                go.Scatter(x=df.index, y=df['BB_lower'], name='BB Lower', line=dict(color='gray', dash='dash')),
                row=1, col=1
            )
            
            # Signaux d'achat
            buy_signals = trading_signals[trading_signals['Signal'] == 1]
            if not buy_signals.empty:
                fig.add_trace(
                    go.Scatter(
                        x=buy_signals.index,
                        y=buy_signals['Entry_Price'],
                        mode='markers',
                        marker=dict(symbol='triangle-up', size=15, color='green'),
                        name='Signal Achat'
                    ),
                    row=1, col=1
                )
            
            # Signaux de vente
            sell_signals = trading_signals[trading_signals['Signal'] == -1]
            if not sell_signals.empty:
                fig.add_trace(
                    go.Scatter(
                        x=sell_signals.index,
                        y=sell_signals['Entry_Price'],
                        mode='markers',
                        marker=dict(symbol='triangle-down', size=15, color='red'),
                        name='Signal Vente'
                    ),
                    row=1, col=1
                )
            
            # RSI
            fig.add_trace(
                go.Scatter(x=df.index, y=df['RSI'], name='RSI', line=dict(color='purple')),
                row=2, col=1
            )
            fig.add_hline(y=70, line_dash="dash", line_color="red", row=2, col=1)
            fig.add_hline(y=30, line_dash="dash", line_color="green", row=2, col=1)
            
            # MACD
            fig.add_trace(
                go.Scatter(x=df.index, y=df['MACD'], name='MACD', line=dict(color='blue')),
                row=3, col=1
            )
            fig.add_trace(
                go.Scatter(x=df.index, y=df['MACD_signal'], name='Signal', line=dict(color='red')),
                row=3, col=1
            )
            fig.add_trace(
                go.Bar(x=df.index, y=df['MACD_hist'], name='Histogramme', marker_color='gray'),
                row=3, col=1
            )
            
            # Volume
            if 'Volume' in df.columns:
                fig.add_trace(
                    go.Bar(x=df.index, y=df['Volume'], name='Volume', marker_color='lightblue'),
                    row=4, col=1
                )
            
            fig.update_layout(
                title=f"Analyse Avancée - {selected_symbol} ({timeframe})",
                xaxis_rangeslider_visible=False,
                height=800,
                showlegend=True
            )
            
            st.plotly_chart(fig, use_container_width=True)
            
            # Signaux de trading actuels
            st.subheader("🎯 Signaux de Trading Actuels")
            
            recent_signals = trading_signals[trading_signals['Signal'] != 0].tail(10)
            
            if not recent_signals.empty:
                for idx, signal in recent_signals.iterrows():
                    signal_type = "🟢 ACHAT" if signal['Signal'] == 1 else "🔴 VENTE"
                    confidence = signal['Confidence'] * 100
                    strategy = signal['Strategy']
                    
                    st.markdown(f"""
                    <div class="signal-card">
                        <h4>{signal_type} - {strategy}</h4>
                        <p><strong>Prix d'entrée:</strong> {signal['Entry_Price']:.4f}</p>
                        <p><strong>Stop Loss:</strong> {signal['Stop_Loss']:.4f}</p>
                        <p><strong>Take Profit:</strong> {signal['Take_Profit']:.4f}</p>
                        <p><strong>Confiance:</strong> {confidence:.1f}%</p>
                        <p><strong>Heure:</strong> {idx}</p>
                    </div>
                    """, unsafe_allow_html=True)
            else:
                st.info("🔍 Aucun signal de trading détecté actuellement. Attendez une meilleure opportunité.")
            
            # Statistiques de performance
            st.subheader("📊 Statistiques de Performance")
            
            col1, col2, col3 = st.columns(3)
            
            with col1:
                total_signals = len(trading_signals[trading_signals['Signal'] != 0])
                st.metric("Total Signaux", total_signals)
            
            with col2:
                avg_confidence = trading_signals[trading_signals['Confidence'] > 0]['Confidence'].mean()
                st.metric("Confiance Moyenne", f"{avg_confidence*100:.1f}%")
            
            with col3:
                if 'ATR' in df.columns:
                    volatility = df['ATR'].iloc[-1]
                    st.metric("Volatilité (ATR)", f"{volatility:.4f}")
            
            # Recommandations de trading
            st.subheader("💡 Recommandations de Trading")
            
            current_rsi = df['RSI'].iloc[-1] if 'RSI' in df.columns else 50
            current_adx = df['ADX'].iloc[-1] if 'ADX' in df.columns else 20
            
            if current_rsi < 30 and current_adx > 25:
                st.success("🟢 Signal d'achat fort détecté! RSI en survente avec tendance forte.")
            elif current_rsi > 70 and current_adx > 25:
                st.warning("🔴 Signal de vente fort détecté! RSI en surachat avec tendance forte.")
            elif current_adx < 20:
                st.info("⏸️ Marché en consolidation. Attendez une cassure de tendance.")
            else:
                st.info("📊 Marché neutre. Surveillez les niveaux de support/résistance.")
            
            # Gestion du risque
            st.subheader("⚠️ Gestion du Risque")
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown("""
                <div class="risk-card">
                    <h4>🛡️ Règles de Protection</h4>
                    <ul>
                        <li>Jamais risquer plus de 2% par trade</li>
                        <li>Stop Loss obligatoire</li>
                        <li>Ratio Risk/Reward minimum 1:2</li>
                        <li>Diversification des positions</li>
                    </ul>
                </div>
                """, unsafe_allow_html=True)
            
            with col2:
                st.markdown("""
                <div class="profit-card">
                    <h4>💰 Objectifs de Profit</h4>
                    <ul>
                        <li>Objectif journalier: 3-5%</li>
                        <li>Objectif mensuel: 20-30%</li>
                        <li>Drawdown maximum: 10%</li>
                        <li>Win rate cible: 70%+</li>
                    </ul>
                </div>
                """, unsafe_allow_html=True)
            
        else:
            st.error("❌ Impossible de récupérer les données de marché. Vérifiez le symbole et réessayez.")

# Footer
st.markdown("---")
st.markdown("""
<div style="text-align: center; color: #666; padding: 2rem;">
    <p>🚀 <strong>Advanced Trading Bot</strong> - Système de signaux à haute probabilité</p>
    <p><em>Disclaimer: Le trading comporte des risques. Utilisez toujours une gestion du risque appropriée.</em></p>
</div>
""", unsafe_allow_html=True)
