import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import streamlit as st
import pandas as pd
from datetime import datetime
from backend.mt5_connector import get_ohlc, get_all_symbols, TIMEFRAME_MAPPING, get_symbols_by_category
from backend.spike_detector import predict_spike_ml
from backend.advanced_analysis import predict_trend_ml
from backend.adaptive_predict import predict_adaptive, MODEL_CONFIGS, predict_multi_horizon, predict_spike_scientifique
import glob
from backend.technical_analysis import detect_step_pattern, detect_step_pattern_crash, add_support_resistance
import numpy as np
import joblib
from backend.technical_analysis import add_stair_pattern_features
from backend.advanced_analysis import get_confluence_prediction
import ta  # pip install ta
from ta.momentum import RSIIndicator

# Pour le diagramme dynamique, installer d'abord : pip install streamlit-mermaid
try:
    from streamlit_mermaid import st_mermaid
    mermaid_available = True
except Exception:
    mermaid_available = False
import os
from dotenv import load_dotenv
# --- Ajout des supports/résistances horizontaux et trendlines confirmées ---
import backend.technical_analysis as ta
import backend.advanced_analysis as adv

# --- SIDEBAR ---
st.sidebar.markdown("# 📈 TradBOT")
st.sidebar.caption("Trading Bot Avancé - IA en temps réel avec Google Gemini")

# Catégorie et symbole
symbol_categories = ['TOUS', 'FOREX', 'SYNTHETIC', 'CRYPTO', 'INDICES', 'COMMODITIES', 'STOCKS', 'OTHER']
category = st.sidebar.selectbox("Catégorie", symbol_categories, index=0)
if category == 'TOUS':
    symbols = get_all_symbols()
else:
    symbols = get_symbols_by_category(category)
symbol_search = st.sidebar.text_input("🔍 Rechercher un symbole", "", key="sidebar_symbol_search")
filtered_symbols = [s for s in symbols if symbol_search.upper() in s.upper()] if symbol_search else symbols
symbol = st.sidebar.selectbox("Symbole", filtered_symbols, index=0 if filtered_symbols else None)

# Catégorie du symbole sélectionné
def get_symbol_category(symbol):
    symbol_upper = symbol.upper()
    if "BOOM" in symbol_upper or "CRASH" in symbol_upper:
        return "synthetic_special"
    elif any(keyword in symbol_upper for keyword in ['VOLATILITY', 'STEP', 'JUMP', 'RANGE BREAK', 'DEX', 'DRIFT', 'TREK', 'VOLSWITCH', 'SKEW', 'MULTI STEP']):
        return "synthetic_general"
    elif any(crypto in symbol_upper for crypto in ['BTC', 'ETH', 'ADA', 'DOT', 'LNK', 'LTC', 'BCH', 'XRP', 'XLM', 'XMR', 'ZEC', 'XTZ', 'NEO', 'MKR', 'SOL', 'TRX', 'UNI', 'SHB', 'TON', 'FET', 'APT', 'COM', 'IMX', 'SAN', 'TRU', 'MLN', 'NER']):
        return "crypto"
    elif any(pair in symbol_upper for pair in ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD', 'SEK', 'NOK', 'PLN', 'ZAR', 'SGD', 'HKD', 'THB', 'MXN', 'CNH']):
        return "forex"
    elif any(stock in symbol_upper for stock in ['AAPL', 'MSFT', 'GOOG', 'AMZN', 'TSLA', 'META', 'NVDA', 'NFLX', 'JPM', 'BAC', 'WMT', 'PG', 'JNJ', 'V', 'HD', 'MA', 'PYPL', 'DIS', 'CRM', 'NKE', 'PFE', 'KO', 'MCD', 'ABNB', 'UBER', 'ZM', 'AAL', 'DAL', 'GM', 'F', 'BA', 'IBM', 'INTC', 'CSCO', 'ORCL', 'ADBE', 'NFLX', 'AMD', 'BABA', 'AIG', 'GS', 'C', 'DBK', 'EBAY', 'FDX', 'FOX', 'HPQ', 'SONY', 'TEVA', 'AIR', 'AIRF', 'BAY', 'BMW', 'BIIB', 'CONG', 'ADS']):
        return "stocks"
    else:
        return "universal"
symbol_category = get_symbol_category(symbol) if symbol else None

# Timeframe et bougies
timeframes = list(TIMEFRAME_MAPPING.keys())
timeframe = st.sidebar.selectbox("Timeframe", timeframes, index=0)
candle_count = st.sidebar.slider("Nombre de bougies", min_value=50, max_value=1000, value=200, step=10)
horizon_options_all = [
    ("1 min", 1), ("5 min", 5), ("15 min", 15), ("30 min", 30),
    ("1 h", 60), ("4 h", 240), ("1D", 1440), ("1W", 10080)
]
current_tf_min = TIMEFRAME_MAPPING[timeframe]

def is_number(x):
    try:
        float(x)
        return True
    except Exception:
        return False

# Horizons dynamiques selon symbole et timeframe
category_to_horizons = {
    "forex": ["1 min", "5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"],
    "crypto": ["1 min", "5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"],
    "synthetic_special": ["1 min", "5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"],
    "synthetic_general": ["5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"],
    "stocks": ["15 min", "30 min", "1 h", "4 h", "1D", "1W"],
    "universal": ["1 min", "5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"]
}
category_horizons = category_to_horizons.get(symbol_category or "universal", [l for l, _ in horizon_options_all])
horizon_options = [
    (label, mins)
    for label, mins in horizon_options_all
    if label in category_horizons and is_number(mins) and is_number(current_tf_min) and float(mins) >= float(current_tf_min)
]
horizon_labels = [opt[0] for opt in horizon_options]
def def_label_to_minutes(label):
    for l, m in horizon_options:
        if l == label:
            return m
    return current_tf_min
def label_to_model_filename(label):
    return label.replace(' ', '').lower()
selected_horizons = st.sidebar.multiselect(
    "Horizons de prédiction compatibles",
    horizon_labels,
    default=[horizon_labels[0]] if horizon_labels else []
)
if not selected_horizons:
    st.sidebar.warning("Aucun horizon compatible avec le symbole et le timeframe sélectionnés.")

# Détection dynamique et enrichie des modèles ML
def get_model_info(path):
    stat = os.stat(path)
    size_mb = stat.st_size / 1024 / 1024
    mtime = datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M')
    name = os.path.basename(path)
    # Type de modèle (simple heuristique)
    if 'xgb' in name.lower():
        model_type = 'XGBoost'
    elif 'rf' in name.lower():
        model_type = 'RandomForest'
    elif 'lstm' in name.lower():
        model_type = 'LSTM'
    else:
        model_type = 'Autre'
    return {
        'name': name,
        'type': model_type,
        'size': f"{size_mb:.1f} Mo",
        'mtime': mtime,
        'path': path
    }

model_files = glob.glob('backend/*_model.pkl')
model_infos = [get_model_info(f) for f in model_files]
if not model_infos:
    st.sidebar.warning("Aucun modèle ML détecté dans backend/.")
# Modèles pertinents pour la catégorie
category_to_model = {
    "forex": ["forex_xgb_model", "universal_xgb_model"],
    "crypto": ["crypto_xgb_model", "universal_xgb_model"],
    "synthetic_special": ["synthetic_special_xgb_model", "universal_xgb_model"],
    "synthetic_general": ["synthetic_general_xgb_model", "universal_xgb_model"],
    "stocks": ["stocks_xgb_model", "universal_xgb_model"],
    "universal": ["universal_xgb_model"]
}
default_models = []
if symbol_category:
    for m in model_infos:
        for cat_model in category_to_model.get(symbol_category or 'universal', []):
            if cat_model in m['name']:
                default_models.append(f"{m['name']} ({m['type']}, {m['size']}, {m['mtime']})")
# Forcer la sélection automatique des modèles XGBoost pour la catégorie du symbole
if symbol_category:
    cat_key = symbol_category.lower()
    xgb_models = [
        m for m in model_infos
        if 'xgb' in m['name'].lower() and (
            cat_key in m['name'].lower() or 'universal' in m['name'].lower()
        )
    ]
    if xgb_models:
        default_models = [f"{m['name']} ({m['type']}, {m['size']}, {m['mtime']})" for m in xgb_models]

model_select_options = [f"{m['name']} ({m['type']}, {m['size']}, {m['mtime']})" for m in model_infos]
selected_model_names = st.sidebar.multiselect(
    "Modèles ML à utiliser (XGBoost auto)",
    model_select_options,
    default=default_models if default_models else model_select_options
)
selected_models = [m['name'].replace('_model.pkl', '') for m in model_infos if f"{m['name']} ({m['type']}, {m['size']}, {m['mtime']})" in selected_model_names]

# Génération du diagramme Mermaid dynamique
mermaid_code = f'''
flowchart TD
    A["symbol_category.lower(): {symbol_category.lower() if symbol_category else ''}"] --> B["xgb_models filtered"]
'''
if 'xgb_models' in locals() and xgb_models:
    for i, m in enumerate(xgb_models):
        mermaid_code += f'    B -->|"{m["name"]}"| C{i}["{m["name"]} ({m["type"]}, {m["size"]}, {m["mtime"]})"]\n'
mermaid_code += '    A --> D["model_select_options"]\n'
for i, opt in enumerate(model_select_options):
    mermaid_code += f'    D --> D{i}["{opt}"]\n'
if 'default_models' in locals() and default_models:
    for i, m in enumerate(default_models):
        mermaid_code += f'    B --> G{i}["default_models: {m}"]\n'
if 'selected_model_names' in locals() and selected_model_names:
    for i, m in enumerate(selected_model_names):
        mermaid_code += f'    C{i} --> E["selected_model_names: {m}"]\n'
if 'selected_models' in locals() and selected_models:
    mermaid_code += f'    E --> F["selected_models: {selected_models}"]\n'
mermaid_code += '    D --> H["model_infos (détail complet)"]\n'
# Affichage dynamique du diagramme Mermaid (plus grand)
# Ajout d'un bouton pour zoomer/dézoomer le diagramme Mermaid
zoom = st.sidebar.radio('Diagramme :', ['Normal', 'Plein écran'], index=0)
diagram_height = "1200" if zoom == 'Plein écran' else "600"
if mermaid_available:
    try:
        st_mermaid(mermaid_code, height=diagram_height)
    except Exception as e:
        st.error(f"Erreur lors de l'affichage du diagramme Mermaid : {e}")
else:
    st.warning("Le composant Mermaid n'est pas disponible. Installez-le avec : pip install streamlit-mermaid.\nLe diagramme ne peut pas être affiché.")

# Sélection des modèles ML
st.sidebar.markdown("## Modèles ML à utiliser")
use_spike = st.sidebar.checkbox("Spike ML", value=True)
use_trend = st.sidebar.checkbox("Trend ML", value=True)
use_adaptive = st.sidebar.checkbox("Adaptive ML", value=True)

# Réglages des modèles
st.sidebar.markdown("## Réglages des modèles")
if use_spike:
    spike_threshold = st.sidebar.slider("Seuil Spike ML", min_value=0.5, max_value=0.99, value=0.8, step=0.01)
else:
    spike_threshold = None
if use_trend:
    trend_horizon = st.sidebar.selectbox("Horizon Trend ML", ["1h", "4h", "1j"], index=0)
else:
    trend_horizon = None
if use_adaptive:
    adaptive_horizon = st.sidebar.selectbox("Horizon Adaptive ML", ["1h", "4h", "1j"], index=0)
else:
    adaptive_horizon = None

# --- Auto-refresh ---
auto_refresh = st.sidebar.toggle("🔄 Rafraîchissement automatique", value=False)
refresh_interval = st.sidebar.selectbox("Intervalle de rafraîchissement (s)", [5, 10, 30, 60], index=1, disabled=not auto_refresh)
if auto_refresh:
    from streamlit_autorefresh import st_autorefresh
    st_autorefresh(interval=refresh_interval * 1000, key="autorefresh")

# --- Réglages des paramètres ---
# timeframes = list(TIMEFRAME_MAPPING.keys()) # Moved up
# timeframe = st.sidebar.selectbox("Timeframe", timeframes, index=0) # Moved up
# candle_count = st.sidebar.slider("Nombre de bougies", min_value=50, max_value=1000, value=200, step=10) # Moved up
# horizon_options_all = [ # Moved up
#     ("1 min", 1), ("5 min", 5), ("15 min", 15), ("30 min", 30),
#     ("1 h", 60), ("4 h", 240), ("1D", 1440), ("1W", 10080)
# ] # Moved up
# current_tf_min = TIMEFRAME_MAPPING[timeframe] # Moved up

# --- Sélection des modèles ML ---
# st.sidebar.markdown("## Modèles ML à utiliser") # Moved up
# use_spike = st.sidebar.checkbox("Spike ML", value=True) # Moved up
# use_trend = st.sidebar.checkbox("Trend ML", value=True) # Moved up
# use_adaptive = st.sidebar.checkbox("Adaptive ML", value=True) # Moved up

# --- Réglages des modèles ---
# st.sidebar.markdown("## Réglages des modèles") # Moved up
# if use_spike: # Moved up
#     spike_threshold = st.sidebar.slider("Seuil Spike ML", min_value=0.5, max_value=0.99, value=0.8, step=0.01) # Moved up
# else: # Moved up
#     spike_threshold = None # Moved up
# if use_trend: # Moved up
#     trend_horizon = st.sidebar.selectbox("Horizon Trend ML", ["1h", "4h", "1j"], index=0) # Moved up
# else: # Moved up
#     trend_horizon = None # Moved up
# if use_adaptive: # Moved up
#     adaptive_horizon = st.sidebar.selectbox("Horizon Adaptive ML", ["1h", "4h", "1j"], index=0) # Moved up
# else: # Moved up
#     adaptive_horizon = None # Moved up

# --- Horizons dynamiques selon symbole et timeframe ---
# category_to_horizons = { # Moved up
#     "forex": ["1 min", "5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"], # Moved up
#     "crypto": ["1 min", "5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"], # Moved up
#     "synthetic_special": ["1 min", "5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"], # Moved up
#     "synthetic_general": ["5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"], # Moved up
#     "stocks": ["15 min", "30 min", "1 h", "4 h", "1D", "1W"], # Moved up
#     "universal": ["1 min", "5 min", "15 min", "30 min", "1 h", "4 h", "1D", "1W"] # Moved up
# } # Moved up
# On ne propose que les horizons compatibles avec la catégorie ET >= timeframe # Moved up
# category_horizons = category_to_horizons.get(symbol_category, [l for l, _ in horizon_options_all]) # Moved up
# horizon_options = [(label, mins) for label, mins in horizon_options_all if label in category_horizons and mins >= current_tf_min] # Moved up
# horizon_labels = [opt[0] for opt in horizon_options] # Moved up
# def def_label_to_minutes(label): # Moved up
#     for l, m in horizon_options: # Moved up
#         if l == label: # Moved up
#             return m # Moved up
#     return current_tf_min # Moved up
# def label_to_model_filename(label): # Moved up
#     # Exemples : '1 h' -> '1h', '1D' -> '1d', '1W' -> '1w', '15 min' -> '15min' # Moved up
#     return label.replace(' ', '').lower() # Moved up
# selected_horizons = st.sidebar.multiselect( # Moved up
#     "Horizons de prédiction compatibles", # Moved up
#     horizon_labels, # Moved up
#     default=[horizon_labels[0]] if horizon_labels else [] # Moved up
# ) # Moved up
# if not selected_horizons: # Moved up
#     st.sidebar.warning("Aucun horizon compatible avec le symbole et le timeframe sélectionnés.") # Moved up

# analyze = st.sidebar.button("🔎 Analyser", use_container_width=True) # Moved up

# st.sidebar.markdown("---") # Moved up
# st.sidebar.caption("© TradBOT 2024 | IA Gemini | v2.0") # Moved up

# --- MAIN ---
st.title("TradBOT - Trading Bot Avancé")
st.subheader("Analyse IA en temps réel avec Google Gemini")

# Add analyze button before main logic
analyze = st.sidebar.button("🔎 Analyser", use_container_width=True)

# --- Tabs principaux ---
tabs = st.tabs([
    "Signaux & Prédiction",
    "Indicateurs avancés",
    "Export",
    "Diagramme sélection modèles ML",
    "Corrélation & Heatmap",
    "Backtest rapide",
    "Aide & Glossaire"
])

# --- Analyse (auto ou bouton) ---
run_analysis = analyze or auto_refresh
if run_analysis:
    @st.cache_data(ttl=60)
    def load_data(symbol, timeframe, count):
        return get_ohlc(symbol, timeframe, count)
    with st.spinner("Chargement des données OHLC..."):
        df = load_data(symbol, timeframe, candle_count)

    # --- Centralisation de la prédiction Spike ML (confluence) ---
    spike_ml_pred = None
    spike_ml_error = None
    spike_threshold_safe = spike_threshold if isinstance(spike_threshold, float) else 0.8
    if use_spike and df is not None and not df.empty:
        try:
            df_features = add_stair_pattern_features(df)
            model_path = 'backend/spike_xgb_model.pkl'
            scaler_path = 'backend/spike_xgb_model_scaler.pkl'
            features_path = 'backend/spike_xgb_model_features.pkl'
            import os
            if not (os.path.exists(model_path) and os.path.exists(scaler_path) and os.path.exists(features_path)):
                spike_ml_error = "Modèle, scaler ou features manquants dans backend/. Lance l'entraînement ou vérifie les fichiers."
            else:
                spike_ml_pred = get_confluence_prediction(df_features, model_path, scaler_path, features_path, proba_threshold=spike_threshold_safe)
        except Exception as e:
            spike_ml_error = str(e)

    # --- Tab 1 : Signaux & Prédiction ---
    with tabs[0]:
        with st.spinner("Calcul des signaux et graphiques..."):
            st.markdown("## Résumé des signaux IA")
            col1, col2, col3 = st.columns(3)
            with col1:
                last_close = df['close'].iloc[-1] if df is not None and not df.empty and 'close' in df.columns else None
                st.metric("Dernier prix", f"{last_close:.4f}" if last_close is not None else "N/A")
            with col2:
                proba_spike = predict_spike_scientifique(df) if (use_spike and df is not None and not df.empty) else None
                st.metric("Proba Spike (scientifique)", f"{proba_spike:.1%}" if isinstance(proba_spike, float) else "N/A")
                # Affichage des critères déclencheurs
                if use_spike and df is not None and not df.empty:
                    # Calcul des bandes de Bollinger et du bandwidth
                    ma = df['close'].rolling(window=20).mean()
                    std = df['close'].rolling(window=20).std()
                    upper = ma + 2 * std
                    lower = ma - 2 * std
                    try:
                        band_width = (upper - lower) / ma
                    except Exception:
                        band_width = np.nan
                    returns = df['close'].pct_change()
                    mean_ret = returns.rolling(window=20).mean()
                    std_ret = returns.rolling(window=20).std()
                    zscore = (returns - mean_ret) / std_ret
                    # Conversion explicite juste avant l'accès .iloc
                    if not isinstance(band_width, pd.Series):
                        try:
                            band_width = pd.Series(band_width, index=df.index if hasattr(df, 'index') else range(len(df)))
                        except Exception:
                            band_width = pd.Series(band_width)
                    if not isinstance(zscore, pd.Series):
                        try:
                            zscore = pd.Series(zscore, index=df.index if hasattr(df, 'index') else range(len(df)))
                        except Exception:
                            zscore = pd.Series(zscore)
                    last_z = zscore.iloc[-1]
                    recent_bandwidth = band_width.iloc[-20:].mean()
                    st.caption(f"Z-score dernière bougie : {last_z:.2f} | Bandwidth Bollinger (20) : {recent_bandwidth:.3f}")
                    if 'volume' in df.columns:
                        vol_series = pd.Series(df['volume']) if not isinstance(df['volume'], pd.Series) else df['volume']
                        vol_arr = np.asarray(vol_series)
                        vol = vol_arr[-1] if len(vol_arr) > 0 else float('nan')
                        vol_mean_arr = np.asarray(pd.Series(vol_series).rolling(window=20).mean())
                        vol_mean = vol_mean_arr[-1] if len(vol_mean_arr) > 0 else float('nan')
                        st.caption(f"Volume actuel : {vol:.0f} | Moyenne(20) : {vol_mean:.0f}")
            with col3:
                trend_df = predict_trend_ml(df) if (use_trend and df is not None and not df.empty) else None
                last_trend = trend_df['trend_pred'].dropna().iloc[-1] if trend_df is not None and not trend_df.empty and 'trend_pred' in trend_df.columns else None
                st.metric("Tendance ML", "Hausse" if last_trend == 1 else "Baisse" if last_trend == -1 else "Neutre" if last_trend == 0 else "N/A")
            # --- Ajout Spike ML ---
            st.markdown("### Signal Spike ML (confluence escalier + ML)")
            if spike_ml_error:
                st.error(spike_ml_error)
            elif spike_ml_pred:
                st.write(f"**Signal :** {spike_ml_pred['signal']}")
                st.write(f"**Confiance :** {spike_ml_pred['confidence']:.2%}")
                st.write(f"**Raison :** {spike_ml_pred['reasoning']}")
                if spike_ml_pred['signal'] == 'PREDICTED_SPIKE' and df is not None and not df.empty:
                    import plotly.graph_objects as go
                    fig = go.Figure()
                    fig.add_trace(go.Candlestick(x=df.index if hasattr(df, 'index') else range(len(df)), open=df['open'], high=df['high'], low=df['low'], close=df['close'], name='Prix'))
                    y_val = df['high'].iloc[-1] if 'high' in df.columns and not isinstance(df['high'], np.ndarray) else None
                    if y_val is not None:
                        fig.add_trace(go.Scatter(x=[df.index[-1] if hasattr(df, 'index') else len(df)-1], y=[y_val], mode='markers', marker=dict(color='blue', size=16, symbol='arrow-bar-up'), name='Spike ML'))
                    st.plotly_chart(fig, use_container_width=True)

        st.markdown("## Probabilité de hausse par horizon")
        if df is not None and not df.empty and selected_horizons:
            proba_table = []
            proba_values = []
            spike_arrows = []
            debug_infos = []
            min_bougies = 20  # Nombre minimal de bougies requis pour les features
            for label in selected_horizons:
                minutes = def_label_to_minutes(label)
                n_bougies = max(min_bougies, int(minutes / current_tf_min))
                if not isinstance(df, (pd.DataFrame, pd.Series)) or (hasattr(df, '__len__') and n_bougies > len(df)):
                    msg = f"Pas assez de données pour calculer les indicateurs ({n_bougies} bougies requises, {len(df) if hasattr(df, '__len__') else 'N/A'} disponibles)."
                    proba_table.append({
                        "Horizon": label,
                        "Probabilité de hausse": None,
                        "Prix actuel": None,
                        "Info": msg
                    })
                    proba_values.append((label, None, "Technique"))
                    debug_infos.append(f"[{label}] {msg}")
                    continue
                df_h = df.tail(n_bougies).copy()
                if not isinstance(df_h, pd.DataFrame):
                    df_h = pd.DataFrame(df_h)
                # Sécurisation des colonnes utilisées
                for col in ['close', 'bb_upper', 'bb_lower', 'macd', 'macd_signal', 'adx', 'atr_14', 'volume', 'stair_strength', 'rsi_14']:
                    if col in df_h.columns and not isinstance(df_h[col], pd.Series):
                        df_h[col] = pd.Series(df_h[col])
                # Vérification données valides
                close_valid = 'close' in df_h.columns and isinstance(df_h['close'], pd.Series) and (df_h['close'].notna().sum() >= 15)
                if not close_valid:
                    msg = "Pas assez de données valides"
                    proba_table.append({
                        "Horizon": label,
                        "Probabilité de hausse": None,
                        "Prix actuel": None,
                        "Info": msg
                    })
                    proba_values.append((label, None, "Technique"))
                    debug_infos.append(f"[{label}] {msg}")
                    continue
                df_h['close'] = pd.to_numeric(df_h['close'], errors='coerce')
                ma_short = pd.Series(df_h['close']).rolling(window=5).mean()
                ma_long = pd.Series(df_h['close']).rolling(window=15).mean()
                ma_short_val = ma_short.iloc[-1] if isinstance(ma_short, pd.Series) and not ma_short.isna().all() else None
                ma_long_val = ma_long.iloc[-1] if isinstance(ma_long, pd.Series) and not ma_long.isna().all() else None
                price_change = (pd.Series(df_h['close']).iloc[-1] - pd.Series(df_h['close']).iloc[0]) / pd.Series(df_h['close']).iloc[0] if pd.Series(df_h['close']).iloc[0] != 0 else 0
                rsi = None
                if 'rsi_14' in df_h.columns and isinstance(df_h['rsi_14'], pd.Series) and (df_h['rsi_14'].notna().sum() > 0):
                    rsi = pd.Series(df_h['rsi_14']).iloc[-1]
                # Calcul dynamique
                proba = 0.5
                info = []
                if ma_short_val is not None and ma_long_val is not None:
                    if ma_short_val > ma_long_val:
                        proba += 0.2
                        info.append(f"MA5>MA15 ({ma_short_val:.2f}>{ma_long_val:.2f})")
                    else:
                        info.append(f"MA5<=MA15 ({ma_short_val:.2f}<={ma_long_val:.2f})")
                if price_change > 0.01:
                    proba += 0.1
                    info.append(f"Δprix>1% ({price_change*100:.2f}%)")
                elif price_change < -0.01:
                    proba -= 0.1
                    info.append(f"Δprix<-1% ({price_change*100:.2f}%)")
                if rsi is not None:
                    if rsi > 60:
                        proba += 0.1
                        info.append(f"RSI>60 ({rsi:.1f})")
                    elif rsi < 40:
                        proba -= 0.1
                        info.append(f"RSI<40 ({rsi:.1f})")
                    else:
                        info.append(f"RSI neutre ({rsi:.1f})")
                # --- Indicateurs avancés ---
                bb_width = None
                if 'bb_upper' in df_h.columns and 'bb_lower' in df_h.columns:
                    bb_upper = pd.Series(df_h['bb_upper'])
                    bb_lower = pd.Series(df_h['bb_lower'])
                    close = pd.Series(df_h['close'])
                    bb_width = bb_upper.iloc[-1] - bb_lower.iloc[-1]
                    price = close.iloc[-1]
                    if price > bb_upper.iloc[-1]:
                        proba -= 0.1
                        info.append("Prix > BB Upper")
                    elif price < bb_lower.iloc[-1]:
                        proba += 0.1
                        info.append("Prix < BB Lower")
                    if bb_width < 0.01 * price:
                        proba -= 0.05
                        info.append("Bollinger squeeze")
                macd = macd_signal = None
                if 'macd' in df_h.columns and 'macd_signal' in df_h.columns:
                    macd = pd.Series(df_h['macd'])
                    macd_signal = pd.Series(df_h['macd_signal'])
                    if macd.iloc[-1] > macd_signal.iloc[-1]:
                        proba += 0.05
                        info.append("MACD haussier")
                    elif macd.iloc[-1] < macd_signal.iloc[-1]:
                        proba -= 0.05
                        info.append("MACD baissier")
                adx = None
                if 'adx' in df_h.columns:
                    adx = pd.Series(df_h['adx'])
                    if adx.iloc[-1] > 25:
                        proba += 0.05
                        info.append("ADX fort")
                    elif adx.iloc[-1] < 15:
                        proba -= 0.05
                        info.append("ADX faible")
                atr = None
                if 'atr_14' in df_h.columns:
                    atr = pd.Series(df_h['atr_14'])
                    close = pd.Series(df_h['close'])
                    if atr.iloc[-1] > close.iloc[-1] * 0.01:
                        proba += 0.05
                        info.append("Volatilité élevée")
                vol = vol_mean = None
                if 'volume' in df_h.columns:
                    vol_series = pd.Series(df_h['volume']) if not isinstance(df_h['volume'], pd.Series) else df_h['volume']
                    vol_arr = np.asarray(vol_series)
                    last_vol = vol_arr[-1] if len(vol_arr) > 0 else float('nan')
                    vol_mean_arr = np.asarray(pd.Series(vol_series).rolling(20).mean())
                    vol_mean = vol_mean_arr[-1] if len(vol_mean_arr) > 0 else float('nan')
                    if last_vol > 1.5 * vol_mean:
                        proba += 0.05
                        info.append("Volume anormalement élevé")
                stair = None
                if 'stair_strength' in df_h.columns:
                    stair = pd.Series(df_h['stair_strength'])
                    if stair.iloc[-1] >= 3:
                        proba += 0.05
                        info.append(f"Escalier détecté ({stair.iloc[-1]:.0f})")
                proba = min(max(proba, 0), 1)
                debug_infos.append(f"[{label}] MA5={ma_short_val}, MA15={ma_long_val}, Δprix={price_change:.3f}, RSI={rsi}, BB_Width={bb_width if bb_width is not None else 'N/A'}, MACD={macd.iloc[-1] if macd is not None else 'N/A'}, ADX={adx.iloc[-1] if adx is not None else 'N/A'}, ATR={atr.iloc[-1] if atr is not None else 'N/A'}, Vol={vol_series.iloc[-1] if vol_series is not None else 'N/A'}, Stair={stair.iloc[-1] if stair is not None else 'N/A'} | Info: {', '.join(info) if info else 'Logique technique (MA, variation, RSI)'}")
                proba_table.append({
                    "Horizon": label,
                    "Probabilité de hausse": proba,
                    "Prix actuel": df_h['close'].iloc[-1],
                    "Info": ", ".join(info) if info else "Logique technique (MA, variation, RSI)"
                })
                proba_values.append((label, proba, "Technique"))
                if proba >= 0.8:
                    spike_arrows.append({
                        'label': f'Technique {label}',
                        'x': df['timestamp'].iloc[-1] if 'timestamp' in df.columns else None,
                        'y': df['close'].iloc[-1],
                        'proba': proba
                    })
            # Affichage graphique dynamique
            import plotly.express as px
            plot_labels = [row['Horizon'] for row in proba_table if row['Probabilité de hausse'] is not None]
            plot_values = [row['Probabilité de hausse']*100 for row in proba_table if row['Probabilité de hausse'] is not None]
            plot_colors = ["#2ecc71" if v >= 70 else "#f1c40f" if v >= 50 else "#e74c3c" for v in plot_values]
            fig_proba = px.bar(x=plot_labels, y=plot_values, color=plot_colors, labels={'x': 'Horizon', 'y': 'Proba de hausse (%)'}, title='Probabilité de hausse par horizon (technique)', color_discrete_sequence=plot_colors)
            st.plotly_chart(fig_proba, use_container_width=True)
            # Affichage infos debug
            with st.expander("Détails des calculs par horizon (debug)"):
                for info in debug_infos:
                    st.caption(info)
            # Affichage graphique principal (bougies + proba + flèches spike)
            import plotly.graph_objects as go
            fig = go.Figure()
            fig.add_trace(go.Candlestick(x=df['timestamp'], open=df['open'], high=df['high'], low=df['low'], close=df['close'], name='Prix'))
            # Step pattern (Boom/Crash)
            boom_steps = detect_step_pattern(df)
            crash_steps = detect_step_pattern_crash(df)
            for ts in boom_steps:
                fig.add_trace(go.Scatter(x=[ts], y=[df.loc[df['timestamp'] == ts, 'close'].values[0]], mode='markers', marker=dict(symbol='triangle-up', color='green', size=16), name='Step Boom'))
            for ts in crash_steps:
                fig.add_trace(go.Scatter(x=[ts], y=[df.loc[df['timestamp'] == ts, 'close'].values[0]], mode='markers', marker=dict(symbol='triangle-down', color='red', size=16), name='Step Crash'))
            # --- Ajout des supports/résistances horizontaux et trendlines confirmées ---
            import backend.technical_analysis as ta
            import backend.advanced_analysis as adv
            levels = ta.get_support_resistance_levels(df)
            for s in levels.get('support', []):
                fig.add_hline(y=s, line_dash="dot", line_color="green", annotation_text="Support", annotation_position="bottom left")
            for r in levels.get('resistance', []):
                fig.add_hline(y=r, line_dash="dash", line_color="red", annotation_text="Résistance", annotation_position="top left")
            adv_analysis = adv.AdvancedAnalysis()
            trendlines = adv_analysis.calculate_trendlines(df)
            for tl in trendlines['support']:
                if tl['confirmations'] >= 1:
                    fig.add_shape(type="line",
                        x0=df['timestamp'].iloc[tl['start_index']], y0=tl['start_price'],
                        x1=df['timestamp'].iloc[tl['end_index']], y1=tl['end_price'],
                        line=dict(color="green", width=2, dash="dot"),
                    )
            for tl in trendlines['resistance']:
                if tl['confirmations'] >= 1:
                    fig.add_shape(type="line",
                        x0=df['timestamp'].iloc[tl['start_index']], y0=tl['start_price'],
                        x1=df['timestamp'].iloc[tl['end_index']], y1=tl['end_price'],
                        line=dict(color="red", width=2, dash="dash"),
                    )
            # Supports/résistances multi-timeframes (inchangé)
            tf_colors = {'1h': 'blue', '15m': 'orange', '5m': 'purple', '1m': 'gray'}
            tf_labels = {'1h': 'H1', '15m': 'M15', '5m': 'M5', '1m': 'M1'}
            for tf, color in tf_colors.items():
                try:
                    tf_df = get_ohlc(symbol, tf, 500)
                    if tf_df is not None and hasattr(tf_df, 'columns'):
                        tf_df = add_support_resistance(tf_df)
                        if 'support' in tf_df.columns and 'resistance' in tf_df.columns:
                            last_supports = tf_df['support'].dropna().unique()[-3:]
                            last_resistances = tf_df['resistance'].dropna().unique()[-3:]
                            for s in last_supports:
                                fig.add_hline(y=s, line_dash="dot", line_color=color, annotation_text=f"Support {tf_labels[tf]}", annotation_position="bottom left")
                            for r in last_resistances:
                                fig.add_hline(y=r, line_dash="dash", line_color=color, annotation_text=f"Résistance {tf_labels[tf]}", annotation_position="top left")
                except Exception as e:
                    pass
            # Annotation de la dernière proba de l'horizon sélectionné
            if proba_values:
                last_label, last_proba, last_model = proba_values[-1]
                if last_proba is not None:
                    fig.add_trace(go.Scatter(x=[df['timestamp'].iloc[-1]], y=[df['close'].iloc[-1]], mode='markers+text', marker=dict(size=14, color='red'), text=[f"{last_proba*100:.1f}%"], name=f'Proba {last_label} (Technique)'))
            # Flèches pour les spikes annoncés
            df = df.reset_index(drop=True)
            df['timestamp'] = pd.Series(df['timestamp'])
            df['close'] = pd.Series(df['close'])
            for spike in spike_arrows:
                spike_idx = df.index[df['timestamp'] == spike['x']]
                if not spike_idx.empty:
                    idx = spike_idx[0]
                    if isinstance(idx, (int, np.integer)):
                        idx_int = int(idx)
                        for offset in range(5, 0, -1):
                            pos = int(idx_int - offset)
                            if pos >= 0 and pos < len(df):
                                x_val = df['timestamp'].iloc[int(pos)]
                                y_val = df['close'].iloc[int(pos)]
                                if hasattr(x_val, 'item'):
                                    x_val = x_val.item()
                                if hasattr(y_val, 'item'):
                                    y_val = y_val.item()
                                x_val = str(x_val)
                                y_val = float(y_val)
                                fig.add_annotation(
                                    x=x_val,
                                    y=y_val,
                                    text=f"⬆️ {spike['label']}\n{spike['proba']*100:.1f}%",
                                    showarrow=True,
                                    arrowhead=2,
                                    arrowsize=1,
                                    arrowwidth=2,
                                    arrowcolor="orange",
                                    ax=0,
                                    ay=-40,
                                    font=dict(color="orange", size=12),
                                    bgcolor="rgba(255,255,255,0.7)",
                                    bordercolor="orange",
                                    borderwidth=2,
                                    opacity=0.9,
                                    captureevents=True
                                )
            # Après la création du graphique principal (fig = ...)
            if 'prediction_proba' in st.session_state and st.session_state['prediction_proba'] > 0.7 and df is not None and not df.empty:
                last_candle_timestamp = df['timestamp'].iloc[-1]
                last_candle_low = df['low'].iloc[-1]
                fig.add_trace(go.Scatter(
                    x=[last_candle_timestamp],
                    y=[last_candle_low * 0.999],
                    mode='markers+text',
                    name='Prédiction Spike',
                    marker=dict(
                        symbol='arrow-up',
                        color='blue',
                        size=15,
                        line=dict(width=2, color='DarkSlateGrey')
                    ),
                    text=[f"Proba: {st.session_state['prediction_proba']*100:.0f}%"],
                    textposition="bottom center",
                    textfont=dict(color="blue", size=12),
                    hoverinfo='text'
                ))
                st.success(f"🚨 PRÉDICTION FORTE : Spike haussier probable détecté avec une probabilité de {st.session_state['prediction_proba']*100:.1f}% !")

            # Explication UI
            st.info("\n- Flèches **vertes** : spikes historiques (détection passée)\n- Flèche **bleue** : prédiction sur la dernière bougie (signal actionnable, proba > 70%)\n")
            st.plotly_chart(fig, use_container_width=True)
            # Alertes/signaux par horizon
            for (label, proba, model_display) in proba_values:
                if proba is not None and spike_threshold is not None and isinstance(proba, (int, float)) and isinstance(spike_threshold, (int, float)) and proba >= spike_threshold:
                    buy_price = df['close'].iloc[-1]
                    tp = buy_price * 1.02
                    sl = buy_price * 0.99
                    st.error(f"🚨 SIGNAL ({label}) : Proba = {proba:.2f} >= seuil ({spike_threshold})\n**Prix d'entrée :** {buy_price:.4f} | **TP :** {tp:.4f} | **SL :** {sl:.4f}")
                    st.audio("frontend/static/beep.wav", format="audio/wav")
        elif not selected_horizons:
            st.info("Aucun horizon compatible avec le timeframe sélectionné.")
        else:
            st.info("Aucune donnée disponible pour ce symbole/timeframe.")

    # --- Tab 2 : Indicateurs avancés ---
    with tabs[1]:
        with st.spinner("Calcul des indicateurs avancés et graphiques..."):
            st.markdown("## Indicateurs avancés utilisés pour la décision")
            st.info("La probabilité de hausse par horizon est calculée à partir d'indicateurs techniques simples :\n- Moyenne mobile courte vs longue\n- Variation du prix sur l'horizon\n- RSI (s'il est disponible)\n\nAucun modèle de Machine Learning n'est utilisé pour cette estimation.")
            # Calcul et affichage des indicateurs avancés
            if df is not None and not df.empty and selected_horizons:
                label = selected_horizons[0]
                minutes = def_label_to_minutes(label)
                n_bougies = max(50, int(minutes / current_tf_min))
                if n_bougies > len(df):
                    df_h = df.copy()
                else:
                    df_h = df.tail(n_bougies).copy()
                # Calcul des indicateurs avancés
                df_h['ma_5'] = df_h['close'].rolling(window=5).mean()
                df_h['ma_15'] = df_h['close'].rolling(window=15).mean()
                df_h['ma_20'] = df_h['close'].rolling(window=20).mean()
                df_h['ma_50'] = df_h['close'].rolling(window=50).mean()
                # Bollinger
                ma = df_h['close'].rolling(window=20).mean()
                std = df_h['close'].rolling(window=20).std()
                df_h['bb_upper'] = ma + 2 * std
                df_h['bb_lower'] = ma - 2 * std
                # RSI
                delta = df_h['close'].diff()
                gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
                loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
                rs = gain / loss
                df_h['rsi_14'] = 100 - (100 / (1 + rs))
                # MACD
                ema12 = df_h['close'].ewm(span=12, adjust=False).mean()
                ema26 = df_h['close'].ewm(span=26, adjust=False).mean()
                df_h['macd'] = ema12 - ema26
                df_h['macd_signal'] = df_h['macd'].ewm(span=9, adjust=False).mean()
                df_h['macd_histogram'] = df_h['macd'] - df_h['macd_signal']
                # --- Graphique Plotly ---
                import plotly.graph_objects as go
                from plotly.subplots import make_subplots
                # Sécurise les Series
                ts_series = df_h['timestamp']
                if not isinstance(ts_series, pd.Series):
                    ts_series = pd.Series(ts_series)
                if not isinstance(df_h['close'], pd.Series):
                    df_h['close'] = pd.Series(df_h['close'])
                if not isinstance(df_h['open'], pd.Series):
                    df_h['open'] = pd.Series(df_h['open'])
                fig = make_subplots(rows=4, cols=1, shared_xaxes=True, vertical_spacing=0.03, row_heights=[0.5,0.15,0.15,0.2], subplot_titles=(f'Prix {symbol}', 'RSI', 'MACD', 'Volume'))
                # Chandeliers
                fig.add_trace(go.Candlestick(x=ts_series, open=df_h['open'], high=df_h['high'], low=df_h['low'], close=df_h['close'], name='Prix'), row=1, col=1)
                # MA
                fig.add_trace(go.Scatter(x=ts_series, y=df_h['ma_5'], name='MA 5', line=dict(color='blue', width=1)), row=1, col=1)
                fig.add_trace(go.Scatter(x=ts_series, y=df_h['ma_15'], name='MA 15', line=dict(color='orange', width=1)), row=1, col=1)
                fig.add_trace(go.Scatter(x=ts_series, y=df_h['ma_20'], name='MA 20', line=dict(color='red', width=1)), row=1, col=1)
                fig.add_trace(go.Scatter(x=ts_series, y=df_h['ma_50'], name='MA 50', line=dict(color='purple', width=1)), row=1, col=1)
                # Bollinger
                if 'bb_upper' in df_h.columns:
                    fig.add_trace(go.Scatter(x=ts_series, y=df_h['bb_upper'], name='BB Upper', line=dict(color='gray', width=1, dash='dash')), row=1, col=1)
                    fig.add_trace(go.Scatter(x=ts_series, y=df_h['bb_lower'], name='BB Lower', line=dict(color='gray', width=1, dash='dash'), fill='tonexty'), row=1, col=1)
                # RSI
                if 'rsi_14' in df_h.columns:
                    fig.add_trace(go.Scatter(x=ts_series, y=df_h['rsi_14'], name='RSI', line=dict(color='purple')), row=2, col=1)
                    # Ajout des lignes horizontales avec add_shape (plotly v5+)
                    fig.add_shape(type="line", x0=ts_series.iloc[0], x1=ts_series.iloc[-1], y0=70, y1=70, line=dict(dash="dash", color="red"), row=2, col=1)
                    fig.add_shape(type="line", x0=ts_series.iloc[0], x1=ts_series.iloc[-1], y0=30, y1=30, line=dict(dash="dash", color="green"), row=2, col=1)
                    fig.add_shape(type="line", x0=ts_series.iloc[0], x1=ts_series.iloc[-1], y0=50, y1=50, line=dict(dash="dot", color="gray"), row=2, col=1)
                # MACD
                if 'macd' in df_h.columns:
                    fig.add_trace(go.Scatter(x=ts_series, y=df_h['macd'], name='MACD', line=dict(color='blue')), row=3, col=1)
                    fig.add_trace(go.Scatter(x=ts_series, y=df_h['macd_signal'], name='Signal', line=dict(color='red')), row=3, col=1)
                    if 'macd_histogram' in df_h.columns:
                        colors = ['green' if val >= 0 else 'red' for val in df_h['macd_histogram']]
                        fig.add_trace(go.Bar(x=ts_series, y=df_h['macd_histogram'], name='Histogram', marker_color=colors), row=3, col=1)
                # Volume
                if 'volume' in df_h.columns:
                    colors = ['green' if close >= open_ else 'red' for close, open_ in zip(df_h['close'], df_h['open'])]
                    fig.add_trace(go.Bar(x=ts_series, y=df_h['volume'], name='Volume', marker_color=colors), row=4, col=1)
                # --- Probabilité technique de hausse (calculée dynamiquement) ---
                # Calcul identique à la table, mais pour la dernière bougie
                proba_technique = None
                proba_vente = None
                if len(df_h['close']) > 15:
                    ma_short_val = df_h['ma_5'].iloc[-1]
                    ma_long_val = df_h['ma_15'].iloc[-1]
                    price_change = (pd.Series(df_h['close']).iloc[-1] - pd.Series(df_h['close']).iloc[0]) / pd.Series(df_h['close']).iloc[0] if pd.Series(df_h['close']).iloc[0] != 0 else 0
                    rsi = None
                    proba = 0.5
                    proba_sell = 0.5
                    if ma_short_val > ma_long_val:
                        proba += 0.2
                    else:
                        proba_sell += 0.2
                    if price_change > 0.01:
                        proba += 0.1
                    elif price_change < -0.01:
                        proba_sell += 0.1
                    if rsi is not None:
                        if rsi > 60:
                            proba += 0.1
                        elif rsi < 40:
                            proba_sell += 0.1
                    proba_technique = min(max(proba, 0), 1)
                    proba_vente = min(max(proba_sell, 0), 1)
                    # Ajout d'une annotation sur la dernière bougie
                    fig.add_trace(go.Scatter(
                        x=[ts_series.iloc[-1]],
                        y=[df_h['close'].iloc[-1]],
                        mode='markers+text',
                        marker=dict(symbol='circle', color='blue', size=12),
                        text=[f"Proba: {proba_technique*100:.1f}%"],
                        textposition="top center",
                        name="Proba technique"
                    ))
                    # Ajout d'un bouton/annotation rouge si proba_vente > 80%
                    if proba_vente is not None and proba_vente >= 0.8:
                        fig.add_trace(go.Scatter(
                            x=[ts_series.iloc[-1]],
                            y=[df_h['close'].iloc[-1]],
                            mode='markers+text',
                            marker=dict(symbol='circle', color='red', size=16),
                            text=[f"Vente: {proba_vente*100:.1f}%"],
                            textposition="bottom center",
                            name="Proba vente"
                        ))
                        st.error(f"🚨 SIGNAL VENTE : Proba = {proba_vente:.2f} >= 80%\n**Prix d'entrée :** {df_h['close'].iloc[-1]:.4f}")
                fig.update_layout(title=f'Indicateurs avancés - {symbol}', xaxis_rangeslider_visible=False, height=800, showlegend=True)
                st.plotly_chart(fig, use_container_width=True)
            # --- Tableau des dernières valeurs ---
            st.markdown("### Dernières valeurs des indicateurs avancés")
            cols_to_show = ['ma_5','ma_15','ma_20','ma_50','bb_upper','bb_lower','rsi_14','macd','macd_signal','macd_histogram']
            available_cols = [c for c in cols_to_show if c in df_h.columns]
            if available_cols:
                display_df = df_h[available_cols].tail(10).copy()
                if 'timestamp' in df_h.columns:
                    display_df["timestamp"] = ts_series.tail(10).values
                    display_df.set_index("timestamp", inplace=True)
                st.dataframe(display_df, use_container_width=True)
            # --- Explication IA (Gemini) ---
            indics = {
                "MA 5": f"{df_h['ma_5'].iloc[-1]:.4f}",
                "MA 15": f"{df_h['ma_15'].iloc[-1]:.4f}",
                "RSI 14": f"{df_h['rsi_14'].iloc[-1]:.2f}" if 'rsi_14' in df_h.columns else "N/A",
                "MACD": f"{df_h['macd'].iloc[-1]:.4f}" if 'macd' in df_h.columns else "N/A",
                "MACD Signal": f"{df_h['macd_signal'].iloc[-1]:.4f}" if 'macd_signal' in df_h.columns else "N/A",
                "Bollinger Upper": f"{df_h['bb_upper'].iloc[-1]:.4f}" if 'bb_upper' in df_h.columns else "N/A",
                "Bollinger Lower": f"{df_h['bb_lower'].iloc[-1]:.4f}" if 'bb_lower' in df_h.columns else "N/A",
            }
            price_change = pd.Series(df_h['close']).iloc[-1] - pd.Series(df_h['close']).iloc[0]
            prompt = (
                "Voici les valeurs récentes des indicateurs techniques d'un actif financier :\n"
                + "\n".join([f"{k} : {v}" for k, v in indics.items()])
                + f"\nVariation du prix sur la période : {price_change:.2f}\n"
                "Donne-moi une analyse synthétique de la situation du marché (tendance, momentum, volatilité, surachat/survente, etc.) en langage simple pour un trader.\n"
                "Ensuite, si tu es certain à 90% ou plus, donne UN SEUL signal de trade clair (BUY ou SELL), avec un niveau de certitude (en %). "
                "Donne aussi un Stop Loss (SL) et un Take Profit (TP) en considérant une perte maximale de 2 dollars (SL) et un gain de 5 dollars (TP) par rapport au prix actuel. "
                "Présente la réponse sous ce format :\n"
                "Signal : BUY ou SELL\n"
                "Certitude : XX%\n"
                "Prix actuel : XX.XX\n"
                "SL : XX.XX\n"
                "TP : XX.XX\n"
                "Explication : ...\n"
                "Si tu n'es pas certain à 90%, indique simplement 'Pas de signal certain'."
            )
            # Explication IA (Gemini) : affichage uniquement sur clic, reset à chaque rerun
            st.session_state['show_gemini_explication'] = False
            if st.button("Explication IA (Gemini)"):
                st.session_state['show_gemini_explication'] = True
            if st.session_state['show_gemini_explication']:
                with st.spinner("Analyse IA en cours..."):
                    import google.generativeai as genai
                    api_key = os.getenv("GEMINI_API_KEY")
                    if not api_key:
                        st.error("Clé API Gemini manquante dans .env (GEMINI_API_KEY).")
                    else:
                        genai.configure(api_key=api_key)
                        try:
                            model = genai.GenerativeModel("models/gemini-1.5-flash")
                            response = model.generate_content(prompt)
                            explication = response.text
                            st.success(explication)
                        except Exception as e:
                            st.error(f"Erreur Gemini : {e}")
            # --- Explication IA (OpenAI) ---
            if st.button("Explication IA (OpenAI)"):
                with st.spinner("Analyse IA OpenAI en cours..."):
                    import openai
                    import os
                    openai_api_key = os.getenv("OPENAI_API_KEY")
                    if not openai_api_key:
                        st.error("Clé API OpenAI manquante dans .env (OPENAI_API_KEY).\n\nAjoute une ligne OPENAI_API_KEY=sk-... dans le fichier .env à la racine du projet, puis relance l'application.")
                    else:
                        openai.api_key = openai_api_key
                        openai_prompt = (
                            "Voici les valeurs récentes des indicateurs techniques d'un actif financier :\n"
                            + "\n".join([f"{k} : {v}" for k, v in indics.items()])
                            + f"\nVariation du prix sur la période : {price_change:.2f}\n"
                            "Donne-moi une analyse synthétique de la situation du marché (tendance, momentum, volatilité, surachat/survente, etc.) en langage simple pour un trader.\n"
                            "Ensuite, si tu es certain à 90% ou plus, donne UN SEUL signal de trade clair (BUY ou SELL), avec un niveau de certitude (en %). "
                            "Donne aussi un Stop Loss (SL) et un Take Profit (TP) en considérant une perte maximale de 2 dollars (SL) et un gain de 5 dollars (TP) par rapport au prix actuel. "
                            "Présente la réponse sous ce format :\n"
                            "Signal : BUY ou SELL\n"
                            "Certitude : XX%\n"
                            "Prix actuel : XX.XX\n"
                            "SL : XX.XX\n"
                            "TP : XX.XX\n"
                            "Explication : ...\n"
                            "Si tu n'es pas certain à 90%, indique simplement 'Pas de signal certain'."
                        )
                        try:
                            response = openai.ChatCompletion.create(
                                model="gpt-4",
                                messages=[{"role": "user", "content": openai_prompt}],
                                max_tokens=500,
                                temperature=0.2
                            )
                            openai_explication = response.choices[0].message.content.strip()
                            st.success(openai_explication)
                        except Exception as e:
                            st.error(f"Erreur OpenAI : {e}")
            else:
                st.info("Aucune donnée disponible pour afficher les indicateurs avancés.")
            # --- Proba Spike ML (confluence) ---
        st.markdown("### Proba Spike ML (confluence)")
        if spike_ml_error:
            st.error(spike_ml_error)
        elif spike_ml_pred:
            # N'affiche pas si signal HOLD ou confiance nulle
            if str(spike_ml_pred.get('signal', '')).upper() not in ["HOLD", "NONE", ""] and spike_ml_pred.get('confidence', 0) > 0:
                st.write(f"**Signal :** {spike_ml_pred['signal']}")
                st.write(f"**Confiance :** {spike_ml_pred['confidence']:.2%}")
                st.write(f"**Raison :** {spike_ml_pred['reasoning']}")

    # --- Tab 3 : Export ---
    with tabs[2]:
        st.markdown("## Export des résultats")
        if df is not None and not df.empty:
            if use_adaptive and selected_horizons:
                label = selected_horizons[0]
                minutes = def_label_to_minutes(label)
                n_bougies = max(50, int(minutes / current_tf_min))
                if n_bougies > len(df):
                    df_h = df.copy()
                else:
                    df_h = df.tail(n_bougies).copy()
                if not isinstance(df_h, pd.DataFrame):
                    df_h = pd.DataFrame(df_h)
                result = predict_multi_horizon(symbol, df_h, label)
                json_data = str(pd.Series(result).to_json()) if result is not None else "{}"
                features_csv = str(pd.DataFrame([result['input_row']]).to_csv(index=False)) if result is not None and 'input_row' in result and isinstance(result['input_row'], dict) else ""
            else:
                json_data = "{}"
                features_csv = ""
            ohlc_csv = str(df.to_csv(index=False)) if df is not None and not df.empty else ""
            st.download_button("Exporter prédiction (JSON)", data=json_data, file_name=f"{symbol}_prediction.json")
            st.download_button("Exporter features (CSV)", data=features_csv, file_name=f"{symbol}_features.csv")
            st.download_button("Exporter historique OHLC (CSV)", data=ohlc_csv, file_name=f"{symbol}_{timeframe}_ohlc.csv")
            st.markdown("### Export prédiction Spike ML")
            if spike_ml_pred:
                import json
                st.download_button("Exporter prédiction Spike ML (JSON)", data=json.dumps(spike_ml_pred, ensure_ascii=False, indent=2), file_name=f"{symbol}_spike_ml_prediction.json")
        else:
            st.info("Sélectionnez vos paramètres et cliquez sur 'Analyser' pour lancer l'analyse IA.")

# --- FOOTER ---
st.markdown("---")
st.caption("TradBOT - Dashboard IA moderne | Analyse IA en temps réel avec Google Gemini | v2.0")

# Affichage du diagramme Mermaid dans le nouvel onglet
with tabs[3]:
    st.header("Diagramme dynamique de sélection des modèles ML")
    zoom = st.radio('Diagramme :', ['Normal', 'Plein écran'], index=0)
    diagram_height = "1200" if zoom == 'Plein écran' else "600"
    if mermaid_available:
        try:
            st_mermaid(mermaid_code, height=diagram_height, key="mermaid_diagram_tab")
        except Exception as e:
            st.error(f"Erreur lors de l'affichage du diagramme Mermaid : {e}")
    else:
        st.warning("Le composant Mermaid n'est pas disponible. Installez-le avec : pip install streamlit-mermaid.\nLe diagramme ne peut pas être affiché.")

# Onglet Corrélation & Heatmap
with tabs[4]:
    st.header("Corrélation & Heatmap")
    if st.button("Actualiser la heatmap"):
        st.rerun()
    # Si plusieurs symboles sélectionnés, calcule la corrélation
    compare_symbols = locals().get('compare_symbols', [])
    if compare_symbols is not None and isinstance(compare_symbols, list) and len(compare_symbols) > 1 and all(isinstance(s, str) for s in compare_symbols):
        import plotly.express as px
        dfs = []
        for symb in compare_symbols:
            df_symb = get_ohlc(symb, timeframe, candle_count)
            if df_symb is not None and not df_symb.empty:
                dfs.append(df_symb['close'].rename(symb))
        if len(dfs) > 1:
            df_corr = pd.concat(dfs, axis=1).corr()
            fig_corr = px.imshow(df_corr, text_auto=True, color_continuous_scale='RdBu', title='Heatmap de corrélation')
            st.plotly_chart(fig_corr, use_container_width=True)
        else:
            st.info("Pas assez de données pour la heatmap.")
    else:
        st.info("Sélectionnez plusieurs symboles pour voir la heatmap de corrélation.")

# Onglet Backtest rapide
with tabs[5]:
    st.header("Backtest rapide")
    if st.button("Actualiser le backtest"):
        st.rerun()
    # Backtest simple : buy si MA5 > MA15, sell sinon
    if df is not None and not df.empty and 'ma_5' in df.columns and 'ma_15' in df.columns:
        signals = (df['ma_5'] > df['ma_15']).astype(int).diff().fillna(0)
        buy_idx = signals[signals == 1].index
        sell_idx = signals[signals == -1].index
        trades = []
        for b, s in zip(buy_idx, sell_idx):
            entry = df.loc[b, 'close']
            exit = df.loc[s, 'close']
            trades.append(exit - entry)
        pnl = sum(trades)
        winrate = sum([1 for t in trades if t > 0]) / len(trades) * 100 if trades else 0
        st.metric("PnL total", f"{pnl:.2f}")
        st.metric("Winrate", f"{winrate:.1f}%")
        st.metric("Nombre de trades", f"{len(trades)}")
    else:
        st.info("Pas assez de données pour le backtest.")

# Onglet Aide & Glossaire
with tabs[6]:
    st.header("Aide & Glossaire")
    st.markdown("""
    - **MA** : Moyenne mobile
    - **RSI** : Relative Strength Index
    - **MACD** : Moving Average Convergence Divergence
    - **Bollinger Bands** : Bandes de volatilité
    - **Spike** : Mouvement brutal du prix
    - **Proba technique** : Probabilité calculée à partir d'indicateurs simples
    - **Proba ML** : Probabilité issue d'un modèle de Machine Learning
    - ...
    """)

# Ajouter la fonction de probabilité robuste
def proba_hausse(df):
    if df is None or df.empty or not hasattr(df['close'], 'iloc') or df['close'].isna().all():
        return 0.5, np.nan, "Données manquantes"
    close = df['close']
    if not isinstance(close, pd.Series):
        close = pd.Series(close)
    ma_fast = pd.Series(close.rolling(5).mean())
    ma_slow = pd.Series(close.rolling(15).mean())
    try:
        rsi = pd.Series(RSIIndicator(close, window=14).rsi())
    except Exception:
        rsi = pd.Series([np.nan]*len(close))
    prix = pd.Series(close).iloc[-1]
    if safe_series(ma_fast).iloc[-1] > safe_series(ma_slow).iloc[-1] and safe_series(rsi).iloc[-1] > 55:
        return 0.7, prix, "MA5>MA15 & RSI>55"
    elif safe_series(ma_fast).iloc[-1] < safe_series(ma_slow).iloc[-1] and safe_series(rsi).iloc[-1] < 45:
        return 0.3, prix, "MA5<MA15 & RSI<45"
    else:
        return 0.5, prix, "Neutre (MA/RSI)"

# Correction linter : forcer pd.Series avant .iloc/len, et sécuriser compare_symbols
def safe_series(obj):
    return obj if isinstance(obj, pd.Series) else pd.Series(obj)

# Initialiser compare_symbols avant tout usage
compare_symbols = locals().get('compare_symbols', [])

# Ajouter un onglet Prédiction Spike
with st.sidebar:
    selected_tab = st.radio("Onglet", ["Signaux & Prédiction", "Indicateurs avancés", "Export", "Diagramme sélection modèles ML", "Corrélation & Heatmap", "Backtest rapide", "Aide & Glossaire", "Prédiction Spike"])

if selected_tab == "Prédiction Spike":
    st.header("Prédiction Spike (Confluence Escalier + ML)")
    # 1. Préparer les données
    df = get_ohlc(symbol, timeframe, count=500)
    if df is not None and not df.empty:
        df_features = add_stair_pattern_features(df)
        # 2. Charger les artefacts du modèle spike
        model_path = 'backend/spike_xgb_model.pkl'
        scaler_path = 'backend/spike_xgb_model_scaler.pkl'
        features_path = 'backend/spike_xgb_model_features.pkl'
        import os
        if not (os.path.exists(model_path) and os.path.exists(scaler_path) and os.path.exists(features_path)):
            st.error("Modèle, scaler ou features manquants dans backend/. Lance l'entraînement ou vérifie les fichiers.")
        else:
            prediction = get_confluence_prediction(df_features, model_path, scaler_path, features_path)
            st.subheader(f"Signal : {prediction['signal']}")
            st.write(f"Confiance : {prediction['confidence']:.2%}")
            st.write(f"Raison : {prediction['reasoning']}")
            # Affichage graphique (exemple)
            import plotly.graph_objs as go
            fig = go.Figure()
            fig.add_trace(go.Candlestick(x=df.index, open=df['open'], high=df['high'], low=df['low'], close=df['close'], name='Prix'))
            if prediction['signal'] == 'SPIKE_PREDICTED':
                fig.add_trace(go.Scatter(x=[df.index[-1]], y=[safe_series(df['high']).iloc[-1]], mode='markers', marker=dict(color='blue', size=16, symbol='arrow-bar-up'), name='Spike Prédit'))
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.warning("Pas de données OHLC disponibles pour ce symbole/timeframe.")

# Ajout d'un expander pour le guide MT5 Mobile
with st.expander("Guide Configuration MT5 Mobile (3 Fenêtres)"):
    st.markdown("""
# Configuration Proposée pour MT5 Mobile (3 Fenêtres)

**Objectif** : Combiner la détection de tendance, du momentum, de la volatilité et de la force de la tendance pour une confirmation solide.

---

## 1. Analyse Multi-Périodes
- **Toujours regarder plusieurs timeframes** :  
  - D1 : Tendance lourde  
  - H4 : Tendance intermédiaire  
  - H1/M30 : Entrée/sortie

## 2. Fenêtre Principale (Graphique des Prix)
### **Moyennes Mobiles (Moving Average)**
- **MA 20 (Exponential, Close, Bleu, fin)**
- **MA 50 (Exponential, Close, Vert, moyen)**
- **MA 200 (Exponential, Close, Rouge, épais)**
- **Interprétation** :
  - Haussier : Prix > MAs, MA20 > MA50 > MA200
  - Baissier : Prix < MAs, MA20 < MA50 < MA200
  - Croisements = signaux potentiels

### **Bandes de Bollinger**
- Période 20, Déviation 2.0, Close
- Largeur = volatilité, prix hors bandes = sur-achat/sur-vente

---

## 3. Fenêtre Indicateur 1 (Momentum)
### **MACD**
- Fast EMA 12, Slow EMA 26, Signal 9
- Croisements, histogramme, divergences

### **RSI**
- Période 14, Close, Niveaux 30/70 (ajouter 20/80 pour extrêmes)
- Sur-achat/Sur-vente, divergences

---

## 4. Fenêtre Indicateur 2 (Force de Tendance & Volume)
### **ADX**
- Période 14, +DI (vert), -DI (rouge), ADX (noir/bleu)
- ADX > 25 = forte tendance, +DI > -DI = haussier, -DI > +DI = baissier

### **Volumes**
- Barres de volume, confirmation des cassures/rebonds

---

## 5. **Stratégie de Confirmation**

### **Entrée ACHAT**
- Prix > EMA200, EMA20 > EMA50 > EMA200 (H4/D1)
- MACD croise vers le haut, histogramme > 0 (H1/M30)
- RSI sort de <30, divergence haussière
- ADX > 25, +DI > -DI
- Cassure/résistance ou rebond sur support, volume élevé

### **Entrée VENTE**
- Prix < EMA200, EMA20 < EMA50 < EMA200 (H4/D1)
- MACD croise vers le bas, histogramme < 0 (H1/M30)
- RSI sort de >70, divergence baissière
- ADX > 25, -DI > +DI
- Cassure/support ou rebond sur résistance, volume élevé

---

## Conseils
- Utilisez des couleurs distinctes pour chaque indicateur
- Pratiquez sur compte démo
- Toujours utiliser stop-loss et take-profit

---
    """)

# Fonction de détection des signaux d'achat/vente

def detect_signaux(df):
    """
    Détecte les signaux de trading avec une logique stricte pour les tendances haussières.
    
    Args:
        df: DataFrame contenant les données OHLCV et indicateurs techniques
        
    Returns:
        DataFrame avec les signaux ajoutés
    """
    if df.empty or len(df) < 20:  # Pas assez de données pour une analyse fiable
        df['signal'] = 'HOLD'
        df['confidence'] = 0.0
        df['reason'] = 'Pas assez de données pour analyse'
        df['entry_price'] = 0.0
        df['take_profit'] = 0.0
        df['stop_loss'] = 0.0
        return df
    
    # Initialisation des colonnes de résultat
    df['signal'] = 'HOLD'
    df['confidence'] = 0.0
    df['reason'] = ''
    df['entry_price'] = 0.0
    df['take_profit'] = 0.0
    df['stop_loss'] = 0.0
    
    # Calcul des conditions de tendance haussière stricte
    for i in range(1, len(df)):
        # Conditions pour une tendance haussière forte
        trend_conditions = [
            df['close'].iloc[i] > df['ema200'].iloc[i],
            df['ema20'].iloc[i] > df['ema50'].iloc[i] > df['ema200'].iloc[i],
            df['macd'].iloc[i] > df['macd_signal'].iloc[i],
            df['macd_hist'].iloc[i] > 0,
            df['rsi'].iloc[i] > 60,
            df['adx'].iloc[i] > 30,
            df['volume'].iloc[i] > df['volume_moyen'].iloc[i],
            # Vérification de la tendance sur les 5 dernières bougies
            all(df['close'].iloc[max(0, i-4):i+1] > df['open'].iloc[max(0, i-4):i+1]),  # 5 bougies vertes consécutives
        ]
        
        # Si toutes les conditions sont remplies avec une confiance de 100%
        if all(trend_conditions):
            df.at[df.index[i], 'signal'] = 'BUY'
            df.at[df.index[i], 'confidence'] = 1.0
            df.at[df.index[i], 'reason'] = 'Tendance haussière forte confirmée sur 5 bouches consécutives'
            
            # Calcul des niveaux de prix
            current_price = df['close'].iloc[i]
            atr = df['atr'].iloc[i] if 'atr' in df.columns else current_price * 0.01  # 1% par défaut si ATR non disponible
            
            # Définition des niveaux de sortie
            df.at[df.index[i], 'entry_price'] = current_price
            df.at[df.index[i], 'take_profit'] = round(current_price + (atr * 2), 5)  # TP à 2x ATR
            df.at[df.index[i], 'stop_loss'] = round(current_price - (atr * 1), 5)    # SL à 1x ATR
    
    return df
    return df

# Exemple d'utilisation dans Streamlit (à adapter selon ton flux de données)
# Supposons que tu as un DataFrame 'df_signaux' déjà calculé avec les colonnes nécessaires
# df_signaux = detect_signaux(df_signaux)
# st.write("Signaux détectés :")
# st.dataframe(df_signaux[['prix','ema20','ema50','ema200','macd','macd_signal','macd_hist','rsi','adx','plus_di','minus_di','volume','volume_moyen','signal_achat','signal_vente']].tail(20))

# Pour afficher un message si un signal est détecté sur la dernière ligne :
# if df_signaux['signal_achat'].iloc[-1]:
#     st.success("Signal d'ACHAT détecté !")
# if df_signaux['signal_vente'].iloc[-1]:
#     st.error("Signal de VENTE détecté !")

