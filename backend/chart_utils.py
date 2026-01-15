import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import pandas as pd
import numpy as np


def create_realtime_candlestick_chart(df, title="Graphique en chandeliers temps réel"):
    """
    Créer un graphique en chandeliers optimisé pour l'affichage temps réel
    """
    if df is None or df.empty:
        return None

    from plotly.subplots import make_subplots
    import plotly.graph_objects as go

    # Vérifier et préparer les colonnes
    required_cols = ['open', 'high', 'low', 'close']
    if not all(col in df.columns for col in required_cols):
        print(f"❌ Colonnes manquantes: {required_cols}")
        print(f"📊 Colonnes disponibles: {list(df.columns)}")
        return None
    
    # Gérer la colonne timestamp
    if 'timestamp' in df.columns:
        x_data = df['timestamp']
    elif 'time' in df.columns:
        x_data = df['time']
    else:
        x_data = df.index
        print("⚠️ Utilisation de l'index comme timestamp")

    # Créer le graphique avec proportions optimisées
    fig = make_subplots(rows=2, cols=1, shared_xaxes=True,
                        vertical_spacing=0.03, row_heights=[0.90, 0.10])
    
    # Chandeliers optimisés pour la visibilité
    fig.add_trace(
        go.Candlestick(
            x=x_data,
            open=df['open'],
            high=df['high'],
            low=df['low'],
            close=df['close'],
            name='OHLC',
            increasing_line_color='#00ff88',
            decreasing_line_color='#ff4444',
            increasing_fillcolor='rgba(0, 255, 136, 0.9)',
            decreasing_fillcolor='rgba(255, 68, 68, 0.9)',
            line=dict(width=2),
            showlegend=True
        ),
        row=1, col=1
    )
    
    # Volume compact
    if 'volume' in df.columns:
        fig.add_trace(
            go.Bar(
                x=x_data,
                y=df['volume'],
                name='Volume',
                marker_color='#4a5568',
                opacity=0.7,
                showlegend=False
            ),
            row=2, col=1
        )
    
    # Layout optimisé pour temps réel
    fig.update_layout(
        title=dict(
            text=title,
            font=dict(size=20, color='white'),
            x=0.5,
            pad=dict(t=20, b=10)
        ),
        template='plotly_dark',
        height=800,
        width=1400,
        showlegend=True,
        xaxis_rangeslider_visible=False,
        plot_bgcolor='#1a1a1a',
        paper_bgcolor='#1a1a1a',
        font=dict(color='white', size=12),
        margin=dict(l=60, r=30, t=50, b=30),
        autosize=False
    )
    
    # Configuration des axes
    fig.update_xaxes(
        rangeslider_visible=False,
        gridcolor='#374151',
        showgrid=True,
        zeroline=False,
        showline=True,
        linecolor='#6b7280',
        row=1, col=1
    )
    
    fig.update_yaxes(
        gridcolor='#374151',
        showgrid=True,
        zeroline=False,
        showline=True,
        linecolor='#6b7280',
        tickformat='.5f',
        row=1, col=1
    )
    
    # Volume axes
    fig.update_xaxes(
        gridcolor='#374151',
        showgrid=True,
        zeroline=False,
        showline=True,
        linecolor='#6b7280',
        row=2, col=1
    )
    
    fig.update_yaxes(
        gridcolor='#374151',
        showgrid=True,
        zeroline=False,
        showline=True,
        linecolor='#6b7280',
        title_text='Volume',
        row=2, col=1
    )
    
    return fig

def create_candlestick_chart(df, title="Graphique en chandeliers"):
    """
    Créer un graphique en chandeliers avec Plotly (style professionnel)
    """
    if df is None or df.empty:
        return None

    from plotly.subplots import make_subplots
    import plotly.graph_objects as go

    # Vérifier et préparer les colonnes
    required_cols = ['open', 'high', 'low', 'close']
    if not all(col in df.columns for col in required_cols):
        print(f"❌ Colonnes manquantes: {required_cols}")
        print(f"📊 Colonnes disponibles: {list(df.columns)}")
        return None
    
    # Gérer la colonne timestamp
    if 'timestamp' in df.columns:
        x_data = df['timestamp']
    elif 'time' in df.columns:
        x_data = df['time']
    else:
        x_data = df.index
        print("⚠️ Utilisation de l'index comme timestamp")

    fig = make_subplots(rows=2, cols=1, shared_xaxes=True,
                        vertical_spacing=0.03, row_heights=[0.90, 0.10])
    
    # Chandeliers avec style professionnel et bien visibles
    fig.add_trace(
        go.Candlestick(
            x=x_data,
            open=df['open'],
            high=df['high'],
            low=df['low'],
            close=df['close'],
            name='OHLC',
            increasing_line_color='#00ff88',  # Vert vif pour les hausses
            decreasing_line_color='#ff4444',  # Rouge vif pour les baisses
            increasing_fillcolor='rgba(0, 255, 136, 0.9)',
            decreasing_fillcolor='rgba(255, 68, 68, 0.9)',
            line=dict(width=4),  # Ligne encore plus épaisse pour chandeliers plus gros
            showlegend=True,
            hoverlabel=dict(
                bgcolor="rgba(0,0,0,0.8)",
                font_size=12,
                font_family="Arial"
            )
        ),
        row=1, col=1
    )
    
    # Volume avec style professionnel
    if 'volume' in df.columns:
        fig.add_trace(
            go.Bar(
                x=x_data,
                y=df['volume'],
                name='Volume',
                marker_color='#4a5568',
                opacity=0.7
            ),
            row=2, col=1
        )
    
    # Layout optimisé pour graphique large et bien proportionné
    fig.update_layout(
        title=dict(
            text=title,
            font=dict(size=20, color='white'),
            x=0.5,
            pad=dict(t=20, b=10)
        ),
        xaxis_title='',
        yaxis_title='Prix',
        template='plotly_dark',
        height=800,  # Hauteur ajustée pour le zoom 79%
        width=1600,  # Largeur maintenue
        showlegend=True,
        xaxis_rangeslider_visible=False,
        plot_bgcolor='#1a1a1a',
        paper_bgcolor='#1a1a1a',
        font=dict(color='white', size=12),
        margin=dict(l=80, r=20, t=60, b=50),  # Marges augmentées pour décaler vers la droite
        autosize=False,  # Désactiver l'auto-resize pour éviter la compression
        yaxis=dict(
            type='linear',
            autorange=True,
            fixedrange=False,
            showgrid=True,
            gridwidth=1,
            gridcolor='rgba(128,128,128,0.3)',
            zeroline=False,
            tickformat='.5f',
            showspikes=True,
            spikemode='across',
            spikesnap='cursor',
            spikethickness=1,
            spikedash='solid',
            spikecolor='#666666',
            tickfont=dict(size=12),
            title=dict(font=dict(size=16)),
            scaleanchor="x",  # Maintenir les proportions
            scaleratio=1
        )
    )
    
    # Style des axes par défaut
    fig.update_xaxes(
        rangeslider_visible=False,
        gridcolor='#374151',
        showgrid=True,
        zeroline=False,
        showline=True,
        linecolor='#6b7280',
        row=1, col=1
    )
    
    fig.update_yaxes(
        gridcolor='#374151',
        showgrid=True,
        zeroline=False,
        showline=True,
        linecolor='#6b7280',
        tickformat='.5f',
        showspikes=True,
        spikemode='across',
        spikesnap='cursor',
        spikethickness=1,
        spikedash='solid',
        spikecolor='#666666',
        row=1, col=1
    )
    
    # Volume axes
    fig.update_xaxes(
        gridcolor='#374151',
        showgrid=True,
        zeroline=False,
        showline=True,
        linecolor='#6b7280',
        row=2, col=1
    )
    
    fig.update_yaxes(
        gridcolor='#374151',
        showgrid=True,
        zeroline=False,
        showline=True,
        linecolor='#6b7280',
        title_text='Volume',
        row=2, col=1
    )
    
    # Configuration par défaut MT5 - autorange pour tous les symboles
    # Pas de configuration manuelle de l'échelle Y
    
    return fig


def add_technical_indicators_to_chart(fig, df, indicators=None):
    """
    Ajouter des indicateurs techniques au graphique avec canaux de trading confirmés
    
    Args:
        fig: Figure Plotly existante
        df: DataFrame avec les données
        indicators: Liste des indicateurs à ajouter ['sma', 'ema', 'bollinger', 'channels']
    
    Returns:
        Figure Plotly mise à jour
    """
    if indicators is None:
        indicators = ['sma', 'ema', 'bollinger', 'channels']
    
    # Moyennes mobiles importantes
    if 'sma' in indicators:
        # SMA 20
        sma_20 = df['close'].rolling(window=20).mean()
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=sma_20,
                mode='lines',
                name='SMA 20',
                line=dict(color='#FF9800', width=2.5),
                opacity=0.8
            ),
            row=1, col=1
        )
        
        # SMA 50
        sma_50 = df['close'].rolling(window=50).mean()
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=sma_50,
                mode='lines',
                name='SMA 50',
                line=dict(color='#2196F3', width=3)
            ),
            row=1, col=1
        )
    
    # Moyennes mobiles exponentielles importantes
    if 'ema' in indicators:
        # EMA 5 (très courte) - Orange
        ema_5 = df['close'].ewm(span=5).mean()
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=ema_5,
                mode='lines',
                name='EMA 5',
                line=dict(color='#FF9800', width=2.5)
            ),
            row=1, col=1
        )
        
        # EMA 8 (courte) - Vert
        ema_8 = df['close'].ewm(span=8).mean()
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=ema_8,
                mode='lines',
                name='EMA 8',
                line=dict(color='#4CAF50', width=2.5)
            ),
            row=1, col=1
        )
        
        # EMA 20 (moyenne) - Bleu clair
        ema_20 = df['close'].ewm(span=20).mean()
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=ema_20,
                mode='lines',
                name='EMA 20',
                line=dict(color='#03A9F4', width=2.5)
            ),
            row=1, col=1
        )
        
        # EMA 50 (longue) - Bleu
        ema_50 = df['close'].ewm(span=50).mean()
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=ema_50,
                mode='lines',
                name='EMA 50',
                line=dict(color='#2196F3', width=3)
            ),
            row=1, col=1
        )
        
        # EMA 100 (très longue) - Gris
        ema_100 = df['close'].ewm(span=100).mean()
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=ema_100,
                mode='lines',
                name='EMA 100',
                line=dict(color='#9E9E9E', width=3)
            ),
            row=1, col=1
        )
        
        # EMA 200 (très longue) - Violet
        ema_200 = df['close'].ewm(span=200).mean()
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=ema_200,
                mode='lines',
                name='EMA 200',
                line=dict(color='#9C27B0', width=3.5)
            ),
            row=1, col=1
        )
    
    # Bollinger Bands (canal de volatilité)
    if 'bollinger' in indicators:
        # Calculer les bandes de Bollinger
        sma_20 = df['close'].rolling(window=20).mean()
        std_20 = df['close'].rolling(window=20).std()
        
        bb_upper = sma_20 + (std_20 * 2)
        bb_lower = sma_20 - (std_20 * 2)
        
        # Bande supérieure
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=bb_upper,
                mode='lines',
                name='BB Upper',
                line=dict(color='#E91E63', width=2, dash='dash'),
                showlegend=True
            ),
            row=1, col=1
        )
        
        # Bande moyenne
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=sma_20,
                mode='lines',
                name='BB Middle',
                line=dict(color='#E91E63', width=2),
                showlegend=True
            ),
            row=1, col=1
        )
        
        # Bande inférieure
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=bb_lower,
                mode='lines',
                name='BB Lower',
                line=dict(color='#E91E63', width=2, dash='dash'),
                showlegend=True,
                fill='tonexty',
                fillcolor='rgba(233, 30, 99, 0.1)'
            ),
            row=1, col=1
        )
    
    # Canaux de trading confirmés
    if 'channels' in indicators:
        # Canal de Donchian (High/Low sur 20 périodes)
        donchian_high = df['high'].rolling(window=20).max()
        donchian_low = df['low'].rolling(window=20).min()
        
        # Canal supérieur
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=donchian_high,
                mode='lines',
                name='Donchian High',
                line=dict(color='#FFC107', width=2, dash='dot'),
                showlegend=True
            ),
            row=1, col=1
        )
        
        # Canal inférieur
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=donchian_low,
                mode='lines',
                name='Donchian Low',
                line=dict(color='#FFC107', width=2, dash='dot'),
                showlegend=True,
                fill='tonexty',
                fillcolor='rgba(255, 193, 7, 0.1)'
            ),
            row=1, col=1
        )
        
        # Canal de Keltner (EMA + ATR)
        ema_20 = df['close'].ewm(span=20).mean()
        atr_20 = df['high'].rolling(20).max() - df['low'].rolling(20).min()
        
        keltner_upper = ema_20 + (atr_20 * 2)
        keltner_lower = ema_20 - (atr_20 * 2)
        
        # Canal Keltner supérieur
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=keltner_upper,
                mode='lines',
                name='Keltner Upper',
                line=dict(color='#795548', width=1, dash='dash'),
                showlegend=True
            ),
            row=1, col=1
        )
        
        # Canal Keltner inférieur
        fig.add_trace(
            go.Scatter(
                x=df['timestamp'],
                y=keltner_lower,
                mode='lines',
                name='Keltner Lower',
                line=dict(color='#795548', width=1, dash='dash'),
                showlegend=True,
                fill='tonexty',
                fillcolor='rgba(121, 85, 72, 0.05)'
            ),
            row=1, col=1
        )
    
    return fig


def create_spike_analysis_chart(df, spikes, title="Analyse des Spikes"):
    """
    Créer un graphique spécial pour l'analyse des spikes (sans volume)
    """
    fig = go.Figure()
    # Graphique en chandeliers principal
    candlestick = go.Candlestick(
        x=df['timestamp'],
        open=df['open'],
        high=df['high'],
        low=df['low'],
        close=df['close'],
        name='OHLC',
        increasing_line_color='#26A69A',
        decreasing_line_color='#EF5350'
    )
    fig.add_trace(candlestick)
    # Marquer les spikes sur le graphique (décalées 2 ticks avant)
    if not spikes.empty:
        boom_x, boom_y, boom_text = [], [], []
        crash_x, crash_y, crash_text = [], [], []
        for _, spike in spikes.iterrows():
            idx = df.index[df['timestamp'] == spike['timestamp']]
            if len(idx) > 0:
                i = idx[0]
                if i >= 2:
                    prev_idx = i - 2
                    if spike['spike_type'] == 'BOOM':
                        boom_x.append(df['timestamp'].iloc[prev_idx])
                        boom_y.append(df['high'].iloc[prev_idx])
                        boom_text.append(f"BOOM: {spike['pct_change']:.2f}%")
                    elif spike['spike_type'] == 'CRASH':
                        crash_x.append(df['timestamp'].iloc[prev_idx])
                        crash_y.append(df['low'].iloc[prev_idx])
                        crash_text.append(f"CRASH: {spike['pct_change']:.2f}%")
        if boom_x:
            fig.add_trace(
                go.Scatter(
                    x=boom_x,
                    y=boom_y,
                    mode='markers',
                    name='Spikes BOOM',
                    marker=dict(
                        symbol='triangle-up',
                        size=12,
                        color='#4CAF50',
                        line=dict(color='white', width=2)
                    ),
                    text=boom_text,
                    hovertemplate='<b>%{text}</b><br>Prix: %{y:.2f}<extra></extra>'
                )
            )
        if crash_x:
            fig.add_trace(
                go.Scatter(
                    x=crash_x,
                    y=crash_y,
                    mode='markers',
                    name='Spikes CRASH',
                    marker=dict(
                        symbol='triangle-down',
                        size=12,
                        color='#F44336',
                        line=dict(color='white', width=2)
                    ),
                    text=crash_text,
                    hovertemplate='<b>%{text}</b><br>Prix: %{y:.2f}<extra></extra>'
                )
            )
    # Mise en forme
    fig.update_layout(
        title=title,
        template='plotly_dark',
        height=700,
        showlegend=True
    )
    return fig


def create_price_evolution_chart(df, title="Évolution des prix"):
    """
    Créer un graphique simple d'évolution des prix
    
    Args:
        df: DataFrame avec les données
        title: Titre du graphique
    
    Returns:
        Figure Plotly
    """
    fig = go.Figure()
    
    fig.add_trace(
        go.Scatter(
            x=df['timestamp'],
            y=df['close'],
            mode='lines',
            name='Prix de clôture',
            line=dict(color='#2196F3', width=2)
        )
    )
    
    fig.update_layout(
        title=title,
        xaxis_title='Date',
        yaxis_title='Prix',
        template='plotly_dark',
        height=400
    )
    
    return fig


def create_volume_analysis_chart(df, title="Analyse du volume"):
    """
    Créer un graphique d'analyse du volume
    
    Args:
        df: DataFrame avec les données
        title: Titre du graphique
    
    Returns:
        Figure Plotly
    """
    fig = go.Figure()
    
    # Volume moyen mobile
    volume_sma = df['volume'].rolling(window=20).mean()
    
    fig.add_trace(
        go.Bar(
            x=df['timestamp'],
            y=df['volume'],
            name='Volume',
            marker_color='#26A69A',
            opacity=0.7
        )
    )
    
    fig.add_trace(
        go.Scatter(
            x=df['timestamp'],
            y=volume_sma,
            mode='lines',
            name='Volume moyen (20)',
            line=dict(color='#FF9800', width=2)
        )
    )
    
    fig.update_layout(
        title=title,
        xaxis_title='Date',
        yaxis_title='Volume',
        template='plotly_dark',
        height=400
    )
    
    return fig


def add_ml_predictions_to_chart(fig, df, ml_signals, setups):
    """
    Ajouter les prédictions ML et setups sur le graphique principal (superposé)
    Utilise les données en temps réel pour les prédictions
    """
    if df is None or df.empty or not ml_signals or not setups:
        return fig
    
    # Obtenir les dernières données en temps réel
    last_timestamp = df['timestamp'].iloc[-1]
    last_price = df['close'].iloc[-1]
    
    # Debug: afficher les informations de prédiction
    spike_prob = ml_signals.get('spike_probability', 0)
    print(f"📊 Prédiction ML temps réel - Prix: {last_price:.5f}, Spike prob: {spike_prob:.3f}")
    
    # Créer des prédictions futures (5 périodes) - plus petites pour ne pas comprimer
    future_periods = 3  # Réduit de 5 à 3 pour moins de compression
    future_timestamps = pd.date_range(
        start=last_timestamp, 
        periods=future_periods + 1, 
        freq='1min'
    )[1:]  # Exclure le timestamp actuel
    
    # Prédictions de direction
    direction = ml_signals.get('direction', 'HOLD')
    direction_strength = ml_signals.get('direction_strength', 0.5)
    
    if direction == 'BUY':
        # Projeter une tendance haussière - plus petite amplitude
        price_change = last_price * 0.005 * direction_strength  # Réduit de 1% à 0.5% par période
        future_prices = [last_price + (i + 1) * price_change for i in range(future_periods)]
        
        # Ajouter la ligne de prédiction haussière (temps réel)
        fig.add_trace(
            go.Scatter(
                x=future_timestamps,
                y=future_prices,
                name=f'🤖 Prédiction BUY Temps Réel (Force: {direction_strength:.2f})',
                line=dict(color='#00FF00', width=3, dash='dot'),
                mode='lines+markers',
                marker=dict(size=8, symbol='triangle-up'),
                yaxis='y',  # Utilise l'axe Y principal
                hovertemplate='<b>Prédiction ML Temps Réel</b><br>Direction: BUY<br>Force: %{customdata[0]:.2f}<br>Spike Prob: %{customdata[1]:.3f}<extra></extra>',
                customdata=[[direction_strength, spike_prob]] * len(future_prices)
            ),
            row=1, col=1
        )
        
        # Ajouter des annotations plus petites
        for i, (ts, price) in enumerate(zip(future_timestamps, future_prices)):
            fig.add_annotation(
                x=ts,
                y=price,
                text=f"BUY+{i+1}",
                showarrow=True,
                arrowhead=2,
                arrowcolor='#00FF00',
                ax=0,
                ay=-20,
                font=dict(color='#00FF00', size=8)
            )
    
    elif direction == 'SELL':
        # Projeter une tendance baissière - plus petite amplitude
        price_change = last_price * 0.005 * direction_strength  # Réduit de 1% à 0.5% par période
        future_prices = [last_price - (i + 1) * price_change for i in range(future_periods)]
        
        # Ajouter la ligne de prédiction baissière (temps réel)
        fig.add_trace(
            go.Scatter(
                x=future_timestamps,
                y=future_prices,
                name=f'🤖 Prédiction SELL Temps Réel (Force: {direction_strength:.2f})',
                line=dict(color='#FF0000', width=3, dash='dot'),
                mode='lines+markers',
                marker=dict(size=8, symbol='triangle-down'),
                yaxis='y',  # Utilise l'axe Y principal
                hovertemplate='<b>Prédiction ML Temps Réel</b><br>Direction: SELL<br>Force: %{customdata[0]:.2f}<br>Spike Prob: %{customdata[1]:.3f}<extra></extra>',
                customdata=[[direction_strength, spike_prob]] * len(future_prices)
            ),
            row=1, col=1
        )
        
        # Ajouter des annotations plus petites
        for i, (ts, price) in enumerate(zip(future_timestamps, future_prices)):
            fig.add_annotation(
                x=ts,
                y=price,
                text=f"SELL-{i+1}",
                showarrow=True,
                arrowhead=2,
                arrowcolor='#FF0000',
                ax=0,
                ay=20,
                font=dict(color='#FF0000', size=8)
            )
    
    # Ajouter les signaux de spike - zone plus petite
    spike = ml_signals.get('spike', 'LOW_SPIKE_RISK')
    spike_strength = ml_signals.get('spike_strength', 0.5)
    
    if spike in ['HIGH_SPIKE_RISK', 'MEDIUM_SPIKE_RISK']:
        # Ajouter une zone de risque de spike - plus petite
        spike_color = '#FFA500' if spike == 'HIGH_SPIKE_RISK' else '#FFD700'
        spike_text = 'HIGH SPIKE RISK' if spike == 'HIGH_SPIKE_RISK' else 'MEDIUM SPIKE RISK'
        
        # Zone de volatilité plus petite (1% au lieu de 2%)
        fig.add_shape(
            type="rect",
            x0=last_timestamp,
            y0=last_price * 0.995,
            x1=future_timestamps[-1],
            y1=last_price * 1.005,
            fillcolor=spike_color,
            opacity=0.15,
            line=dict(width=0),
            row=1, col=1
        )
        
        # Annotation de risque de spike plus petite
        fig.add_annotation(
            x=future_timestamps[1],
            y=last_price * 1.002,
            text=f"⚠️ {spike_text}",
            showarrow=True,
            arrowhead=2,
            arrowcolor=spike_color,
            ax=0,
            ay=-30,
            font=dict(color=spike_color, size=10, family="Arial Black")
        )
    
    # Ajouter les zones de support/résistance
    support_resistance = setups.get('support_resistance_zones', {})
    if support_resistance:
        support_zones = support_resistance.get('support_zones', [])
        resistance_zones = support_resistance.get('resistance_zones', [])
        
        # Ajouter les zones de support (zones très serrées pour précision)
        for i, zone in enumerate(support_zones[:3]):  # Limiter à 3 zones les plus fortes
            # Calculer la largeur de la zone en pips pour l'affichage
            zone_range = zone['upper'] - zone['lower']
            zone_pips = zone_range / (df['close'].iloc[-1] * 0.0001)  # Approximation en pips
            
            # Déterminer le style selon la confiance
            is_high_confidence = zone.get('is_high_confidence', False)
            confidence = zone.get('confidence', 0.0)
            
            if is_high_confidence:
                # Zone haute confiance : blanc et gras
                fillcolor = "rgba(255, 255, 255, 0.3)"  # Blanc semi-transparent
                line_color = "white"
                line_width = 4
                line_dash = "solid"
                font_color = "white"
                font_size = 11
                font_weight = "bold"
            else:
                # Zone normale : vert
                fillcolor = "rgba(0, 255, 0, 0.15)"
                line_color = "green"
                line_width = 2
                line_dash = "solid"
                font_color = "green"
                font_size = 9
                font_weight = "normal"
            
            fig.add_shape(
                type="rect",
                x0=df['timestamp'].iloc[0],  # Début du graphique
                x1=df['timestamp'].iloc[-1],  # Fin du graphique
                y0=zone['lower'],
                y1=zone['upper'],
                fillcolor=fillcolor,
                line=dict(color=line_color, width=line_width, dash=line_dash),
                row=1, col=1
            )
            
            # Annotation simplifiée pour la zone de support
            if is_high_confidence:
                # Zone haute confiance : affichage complet
                fig.add_annotation(
                    x=df['timestamp'].iloc[-1],
                    y=zone['level'],
                    text=f"SUPPORT {zone['level']:.5f}<br>{confidence:.0%}",
                    showarrow=True,
                    arrowhead=2,
                    arrowcolor=line_color,
                    ax=0,
                    ay=-30,
                    font=dict(color=font_color, size=font_size, family="Arial Black"),
                    row=1, col=1
                )
            else:
                # Zone normale : affichage minimal
                fig.add_annotation(
                    x=df['timestamp'].iloc[-1],
                    y=zone['level'],
                    text=f"S{zone['level']:.5f}",
                    showarrow=False,
                    font=dict(color=font_color, size=8),
                    row=1, col=1
                )
        
        # Ajouter les zones de résistance (zones très serrées pour précision)
        for i, zone in enumerate(resistance_zones[:3]):  # Limiter à 3 zones les plus fortes
            # Calculer la largeur de la zone en pips pour l'affichage
            zone_range = zone['upper'] - zone['lower']
            zone_pips = zone_range / (df['close'].iloc[-1] * 0.0001)  # Approximation en pips
            
            # Déterminer le style selon la confiance
            is_high_confidence = zone.get('is_high_confidence', False)
            confidence = zone.get('confidence', 0.0)
            
            if is_high_confidence:
                # Zone haute confiance : blanc et gras
                fillcolor = "rgba(255, 255, 255, 0.3)"  # Blanc semi-transparent
                line_color = "white"
                line_width = 4
                line_dash = "solid"
                font_color = "white"
                font_size = 11
                font_weight = "bold"
            else:
                # Zone normale : rouge
                fillcolor = "rgba(255, 0, 0, 0.15)"
                line_color = "red"
                line_width = 2
                line_dash = "solid"
                font_color = "red"
                font_size = 9
                font_weight = "normal"
            
            fig.add_shape(
                type="rect",
                x0=df['timestamp'].iloc[0],  # Début du graphique
                x1=df['timestamp'].iloc[-1],  # Fin du graphique
                y0=zone['lower'],
                y1=zone['upper'],
                fillcolor=fillcolor,
                line=dict(color=line_color, width=line_width, dash=line_dash),
                row=1, col=1
            )
            
            # Annotation simplifiée pour la zone de résistance
            if is_high_confidence:
                # Zone haute confiance : affichage complet
                fig.add_annotation(
                    x=df['timestamp'].iloc[-1],
                    y=zone['level'],
                    text=f"RÉSISTANCE {zone['level']:.5f}<br>{confidence:.0%}",
                    showarrow=True,
                    arrowhead=2,
                    arrowcolor=line_color,
                    ax=0,
                    ay=30,
                    font=dict(color=font_color, size=font_size, family="Arial Black"),
                    row=1, col=1
                )
            else:
                # Zone normale : affichage minimal
                fig.add_annotation(
                    x=df['timestamp'].iloc[-1],
                    y=zone['level'],
                    text=f"R{zone['level']:.5f}",
                    showarrow=False,
                    font=dict(color=font_color, size=8),
                    row=1, col=1
                )
    
    # Ajouter les points prédictifs d'entrée/sortie basés sur les zones et Bollinger Bands
    _add_predictive_entry_exit_points(fig, df, setups, ml_signals)
    
    # Ajouter les signaux de momentum Boom/Crash
    momentum_setup = setups.get('boom_crash_momentum', {})
    if momentum_setup:
        momentum_signal = momentum_setup.get('signal', 'HOLD')
        is_spike = momentum_setup.get('is_spike', False)
        
        if momentum_signal == 'BUY' and is_spike:
            # Signal de spike haussier simplifié
            fig.add_annotation(
                x=last_timestamp,
                y=last_price,
                text="🚀",
                showarrow=False,
                font=dict(color='#00FF00', size=16),
                row=1, col=1
            )
        elif momentum_signal == 'SELL' and is_spike:
            # Signal de spike baissier simplifié
            fig.add_annotation(
                x=last_timestamp,
                y=last_price,
                text="💥",
                showarrow=False,
                font=dict(color='#FF0000', size=16),
                row=1, col=1
            )
    
    # Ajouter les prédictions de spikes avancées
    spike_prediction = ml_signals.get('spike_prediction', {})
    if spike_prediction:
        prediction_level = spike_prediction.get('spike_prediction', 'NO_SPIKE')
        spike_direction = spike_prediction.get('spike_direction', 'NEUTRAL')
        confidence = spike_prediction.get('confidence', 0.0)
        
        if prediction_level == 'HIGH_PROBABILITY':
            if spike_direction == 'UP':
                # Zone de prédiction de spike haussier
                fig.add_shape(
                    type="rect",
                    x0=last_timestamp,
                    y0=last_price * 0.98,
                    x1=future_timestamps[-1],
                    y1=last_price * 1.05,
                    fillcolor='rgba(0, 255, 0, 0.2)',
                    line=dict(width=2, color='#00FF00'),
                    row=1, col=1
                )
                # Prix d'entrée prédit (proportionnel à la confiance)
                predicted_entry_price = last_price * (1 + 0.002 * max(min(confidence, 1.0), 0.0))
                # Flèche/repère vert au prix d'entrée
                fig.add_trace(
                    go.Scatter(
                        x=[future_timestamps[0]],
                        y=[predicted_entry_price],
                        mode='markers+text',
                        name='Achat prévu',
                        marker=dict(symbol='triangle-up', color='#00FF00', size=12),
                        text=['BUY'],
                        textposition='bottom center'
                    ),
                    row=1, col=1
                )
                fig.add_annotation(
                    x=future_timestamps[1],
                    y=last_price * 1.02,
                    text=f"🚀 SPIKE UP PRÉDIT! ({confidence:.0%})",
                    showarrow=True,
                    arrowhead=2,
                    arrowcolor='#00FF00',
                    ax=0,
                    ay=-40,
                    font=dict(color='#00FF00', size=14, family="Arial Black")
                )
            elif spike_direction == 'DOWN':
                # Zone de prédiction de spike baissier
                fig.add_shape(
                    type="rect",
                    x0=last_timestamp,
                    y0=last_price * 0.95,
                    x1=future_timestamps[-1],
                    y1=last_price * 1.02,
                    fillcolor='rgba(255, 0, 0, 0.2)',
                    line=dict(width=2, color='#FF0000'),
                    row=1, col=1
                )
                # Prix d'entrée prédit (proportionnel à la confiance)
                predicted_entry_price = last_price * (1 - 0.002 * max(min(confidence, 1.0), 0.0))
                # Flèche/repère rouge au prix d'entrée
                fig.add_trace(
                    go.Scatter(
                        x=[future_timestamps[0]],
                        y=[predicted_entry_price],
                        mode='markers+text',
                        name='Vente prévue',
                        marker=dict(symbol='triangle-down', color='#FF0000', size=12),
                        text=['SELL'],
                        textposition='top center'
                    ),
                    row=1, col=1
                )
                fig.add_annotation(
                    x=future_timestamps[1],
                    y=last_price * 0.98,
                    text=f"💥 SPIKE DOWN PRÉDIT! ({confidence:.0%})",
                    showarrow=True,
                    arrowhead=2,
                    arrowcolor='#FF0000',
                    ax=0,
                    ay=40,
                    font=dict(color='#FF0000', size=14, family="Arial Black")
                )
        elif prediction_level == 'MEDIUM_PROBABILITY':
            # Zone de prédiction moyenne
            fig.add_shape(
                type="rect",
                x0=last_timestamp,
                y0=last_price * 0.99,
                x1=future_timestamps[-1],
                y1=last_price * 1.03,
                fillcolor='rgba(255, 165, 0, 0.1)',
                line=dict(width=1, color='#FFA500'),
                row=1, col=1
            )
            fig.add_annotation(
                x=future_timestamps[1],
                y=last_price * 1.01,
                text=f"⚠️ SPIKE POSSIBLE ({confidence:.0%})",
                showarrow=True,
                arrowhead=2,
                arrowcolor='#FFA500',
                ax=0,
                ay=-20,
                font=dict(color='#FFA500', size=12, family="Arial Black")
            )
            # Placer un repère discret au prix d'entrée estimé
            entry_adjust = 0.001 * max(min(confidence, 1.0), 0.0)
            up_entry = last_price * (1 + entry_adjust)
            down_entry = last_price * (1 - entry_adjust)
            fig.add_trace(
                go.Scatter(
                    x=[future_timestamps[0], future_timestamps[0]],
                    y=[up_entry, down_entry],
                    mode='markers',
                    name='Entrées possibles',
                    marker=dict(symbol=['triangle-up','triangle-down'], color=['#00FF00','#FF0000'], size=9)
                ),
                row=1, col=1
            )
    
    return fig


def _add_predictive_entry_exit_points(fig, df, setups, ml_signals):
    """
    Ajouter des points prédictifs d'entrée/sortie basés sur les zones et Bollinger Bands
    """
    if df is None or df.empty:
        return
    
    last_timestamp = df['timestamp'].iloc[-1]
    last_price = df['close'].iloc[-1]
    
    # Obtenir les zones de support/résistance
    support_resistance = setups.get('support_resistance_zones', {})
    support_zones = support_resistance.get('support_zones', [])
    resistance_zones = support_resistance.get('resistance_zones', [])
    
    # Analyser les signaux ML
    direction = ml_signals.get('direction', 'HOLD')
    direction_strength = ml_signals.get('direction_strength', 0.5)
    
    # Calculer les points d'entrée/sortie prédictifs
    entry_points = []
    exit_points = []
    
    # 1. Points basés sur les zones de support/résistance
    if support_zones:
        for zone in support_zones[:2]:  # Top 2 zones
            if zone.get('is_high_confidence', False):
                # Point d'entrée ACHAT près du support confirmé
                entry_price = zone['level'] + (zone['upper'] - zone['level']) * 0.1
                entry_points.append({
                    'price': entry_price,
                    'type': 'BUY_ENTRY',
                    'reason': f"Support confirmé {zone['confidence']:.0%}",
                    'confidence': zone['confidence']
                })
    
    if resistance_zones:
        for zone in resistance_zones[:2]:  # Top 2 zones
            if zone.get('is_high_confidence', False):
                # Point d'entrée VENTE près de la résistance confirmée
                entry_price = zone['level'] - (zone['level'] - zone['lower']) * 0.1
                entry_points.append({
                    'price': entry_price,
                    'type': 'SELL_ENTRY',
                    'reason': f"Résistance confirmée {zone['confidence']:.0%}",
                    'confidence': zone['confidence']
                })
    
    # 2. Points basés sur les Bollinger Bands
    if 'bb_upper' in df.columns and 'bb_lower' in df.columns:
        bb_upper = df['bb_upper'].iloc[-1]
        bb_lower = df['bb_lower'].iloc[-1]
        bb_middle = (bb_upper + bb_lower) / 2
        
        # Si le prix est près de la bande inférieure
        if last_price <= bb_lower * 1.002:
            entry_points.append({
                'price': bb_lower * 1.001,
                'type': 'BUY_ENTRY',
                'reason': "Bollinger Lower Band",
                'confidence': 0.7
            })
            
            exit_points.append({
                'price': bb_middle,
                'type': 'BUY_EXIT',
                'reason': "TP Bollinger Middle",
                'confidence': 0.7
            })
        
        # Si le prix est près de la bande supérieure
        elif last_price >= bb_upper * 0.998:
            entry_points.append({
                'price': bb_upper * 0.999,
                'type': 'SELL_ENTRY',
                'reason': "Bollinger Upper Band",
                'confidence': 0.7
            })
            
            exit_points.append({
                'price': bb_middle,
                'type': 'SELL_EXIT',
                'reason': "TP Bollinger Middle",
                'confidence': 0.7
            })
    
    # 3. Points basés sur les signaux ML
    if direction == 'BUY' and direction_strength > 0.6:
        entry_price = last_price * 1.0005
        entry_points.append({
            'price': entry_price,
            'type': 'BUY_ENTRY',
            'reason': f"ML Signal {direction_strength:.0%}",
            'confidence': direction_strength
        })
        
        exit_price = last_price * 1.002
        exit_points.append({
            'price': exit_price,
            'type': 'BUY_EXIT',
            'reason': f"ML TP {direction_strength:.0%}",
            'confidence': direction_strength
        })
    
    elif direction == 'SELL' and direction_strength > 0.6:
        entry_price = last_price * 0.9995
        entry_points.append({
            'price': entry_price,
            'type': 'SELL_ENTRY',
            'reason': f"ML Signal {direction_strength:.0%}",
            'confidence': direction_strength
        })
        
        exit_price = last_price * 0.998
        exit_points.append({
            'price': exit_price,
            'type': 'SELL_EXIT',
            'reason': f"ML TP {direction_strength:.0%}",
            'confidence': direction_strength
        })
    
    # Afficher les points d'entrée (boutons verts/rouges)
    for point in entry_points:
        if point['confidence'] > 0.6:
            future_timestamp = last_timestamp + pd.Timedelta(minutes=5)
            
            if point['type'] == 'BUY_ENTRY':
                color = '#00FF00'
                symbol = 'triangle-up'
                text = f"🟢 ENTRÉE ACHAT<br>{point['reason']}<br>Confiance: {point['confidence']:.0%}"
            else:
                color = '#FF0000'
                symbol = 'triangle-down'
                text = f"🔴 ENTRÉE VENTE<br>{point['reason']}<br>Confiance: {point['confidence']:.0%}"
            
            fig.add_trace(
                go.Scatter(
                    x=[future_timestamp],
                    y=[point['price']],
                    mode='markers',
                    name=f"Entrée {point['type']}",
                    marker=dict(
                        symbol=symbol,
                        size=15,
                        color=color,
                        line=dict(color='white', width=2)
                    ),
                    text=text,
                    hovertemplate='<b>%{text}</b><br>Prix: %{y:.5f}<extra></extra>',
                    showlegend=False
                ),
                row=1, col=1
            )
            
            # Annotation simplifiée pour les points d'entrée
            fig.add_annotation(
                x=future_timestamp,
                y=point['price'],
                text=f"{point['price']:.5f}",
                showarrow=False,
                font=dict(color='white', size=8, family="Arial Black"),
                bgcolor=color,
                bordercolor='white',
                borderwidth=1,
                row=1, col=1
            )
    
    # Afficher les points de sortie (boutons blancs)
    for point in exit_points:
        if point['confidence'] > 0.6:
            future_timestamp = last_timestamp + pd.Timedelta(minutes=10)
            
            color = '#FFFFFF'
            symbol = 'circle'
            text = f"⚪ SORTIE<br>{point['reason']}<br>Confiance: {point['confidence']:.0%}"
            
            fig.add_trace(
                go.Scatter(
                    x=[future_timestamp],
                    y=[point['price']],
                    mode='markers',
                    name=f"Sortie {point['type']}",
                    marker=dict(
                        symbol=symbol,
                        size=12,
                        color=color,
                        line=dict(color='black', width=2)
                    ),
                    text=text,
                    hovertemplate='<b>%{text}</b><br>Prix: %{y:.5f}<extra></extra>',
                    showlegend=False
                ),
                row=1, col=1
            )
            
            # Annotation simplifiée pour les points de sortie
            fig.add_annotation(
                x=future_timestamp,
                y=point['price'],
                text=f"{point['price']:.5f}",
                showarrow=False,
                font=dict(color='black', size=7, family="Arial"),
                bgcolor='white',
                bordercolor='black',
                borderwidth=1,
                row=1, col=1
            ) 