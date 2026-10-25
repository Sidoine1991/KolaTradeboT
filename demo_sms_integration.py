#!/usr/bin/env python3
"""
Démonstration de l'intégration des notifications SMS dans TradBOT
"""

import streamlit as st
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import time

# Import du service SMS
from src.simple_sms_service import send_trading_signal, send_spike_alert, get_simple_sms_service

def main():
    st.set_page_config(
        page_title="TradBOT - Notifications SMS",
        page_icon="📱",
        layout="wide"
    )
    
    st.title("📱 TradBOT - Notifications SMS")
    st.markdown("---")
    
    # Configuration
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("🔧 Configuration SMS")
        phone_number = st.text_input("Numéro de téléphone", value="+22996911346", disabled=True)
        st.info(f"📞 Notifications configurées pour : {phone_number}")
        
        # Test du service SMS
        if st.button("🧪 Test Service SMS"):
            sms_service = get_simple_sms_service()
            if sms_service.test_sms_notification():
                st.success("✅ SMS de test envoyé avec succès!")
            else:
                st.error("❌ Erreur lors de l'envoi du SMS de test")
    
    with col2:
        st.subheader("📊 Statut du Service")
        sms_service = get_simple_sms_service()
        st.metric("Service SMS", "✅ Actif" if sms_service.enabled else "❌ Inactif")
        st.metric("Numéro configuré", phone_number)
        st.metric("Mode", "Simulation + Sauvegarde locale")
    
    st.markdown("---")
    
    # Simulation de signaux de trading
    st.subheader("🎯 Simulation de Signaux de Trading")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        if st.button("🟢 Signal BUY EURUSD", type="primary"):
            success = send_trading_signal(
                symbol="EURUSD",
                action="BUY",
                price=1.0850,
                confidence=0.85,
                timeframe="M5",
                indicators={
                    'rsi': 35.2,
                    'macd': 'bullish',
                    'sma_20': 1.0840
                }
            )
            if success:
                st.success("✅ Signal BUY envoyé!")
            else:
                st.error("❌ Erreur lors de l'envoi")
    
    with col2:
        if st.button("🔴 Signal SELL Boom 1000"):
            success = send_trading_signal(
                symbol="Boom 1000 Index",
                action="SELL",
                price=17965.28,
                confidence=0.92,
                timeframe="M15",
                indicators={
                    'rsi': 75.8,
                    'macd': 'bearish',
                    'supertrend': 'down'
                }
            )
            if success:
                st.success("✅ Signal SELL envoyé!")
            else:
                st.error("❌ Erreur lors de l'envoi")
    
    with col3:
        if st.button("🚨 Alerte Spike"):
            success = send_spike_alert(
                symbol="Boom 1000 Index",
                price=17965.28,
                spike_percentage=2.5
            )
            if success:
                st.success("✅ Alerte spike envoyée!")
            else:
                st.error("❌ Erreur lors de l'envoi")
    
    st.markdown("---")
    
    # Simulation de données de marché
    st.subheader("📈 Simulation de Données de Marché")
    
    # Générer des données simulées
    dates = pd.date_range(start=datetime.now() - timedelta(hours=1), end=datetime.now(), freq='1min')
    prices = 1.0850 + np.cumsum(np.random.randn(len(dates)) * 0.0001)
    
    df = pd.DataFrame({
        'Timestamp': dates,
        'EURUSD': prices,
        'RSI': np.random.uniform(20, 80, len(dates)),
        'MACD': np.random.uniform(-0.001, 0.001, len(dates))
    })
    
    # Afficher le graphique
    st.line_chart(df.set_index('Timestamp')['EURUSD'])
    
    # Simulation automatique de signaux
    st.subheader("🤖 Simulation Automatique")
    
    if st.button("▶️ Démarrer Simulation Automatique"):
        progress_bar = st.progress(0)
        status_text = st.empty()
        
        for i in range(10):
            # Simuler l'analyse de données
            current_price = df['EURUSD'].iloc[-1]
            current_rsi = df['RSI'].iloc[-1]
            
            # Détection de signal basée sur RSI
            if current_rsi < 30:
                signal_sent = send_trading_signal(
                    symbol="EURUSD",
                    action="BUY",
                    price=current_price,
                    confidence=0.85,
                    timeframe="M1"
                )
                if signal_sent:
                    status_text.text(f"🟢 Signal BUY détecté à {current_price:.4f} (RSI: {current_rsi:.1f})")
            
            elif current_rsi > 70:
                signal_sent = send_trading_signal(
                    symbol="EURUSD",
                    action="SELL",
                    price=current_price,
                    confidence=0.80,
                    timeframe="M1"
                )
                if signal_sent:
                    status_text.text(f"🔴 Signal SELL détecté à {current_price:.4f} (RSI: {current_rsi:.1f})")
            
            # Détection de spike
            if i > 0:
                price_change = abs(current_price - df['EURUSD'].iloc[-2]) / df['EURUSD'].iloc[-2]
                if price_change > 0.001:  # 0.1% de variation
                    spike_sent = send_spike_alert(
                        symbol="EURUSD",
                        price=current_price,
                        spike_percentage=price_change * 100
                    )
                    if spike_sent:
                        status_text.text(f"🚨 Spike détecté: {price_change*100:.2f}%")
            
            progress_bar.progress((i + 1) / 10)
            time.sleep(1)
        
        st.success("✅ Simulation terminée! Vérifiez le dossier 'notifications' pour voir les messages.")
    
    st.markdown("---")
    
    # Afficher les notifications récentes
    st.subheader("📁 Notifications Récentes")
    
    import os
    import json
    from pathlib import Path
    
    notifications_dir = Path("notifications")
    if notifications_dir.exists():
        notification_files = list(notifications_dir.glob("sms_*.json"))
        notification_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
        
        if notification_files:
            st.info(f"📊 {len(notification_files)} notifications trouvées")
            
            # Afficher les 5 dernières notifications
            for i, file_path in enumerate(notification_files[:5]):
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        notification = json.load(f)
                    
                    with st.expander(f"📱 {notification['title']} - {notification['timestamp'][:19]}"):
                        st.text(f"📞 Numéro: {notification['phone_number']}")
                        st.text(f"📝 Message:")
                        st.code(notification['message'])
                        st.text(f"🕐 Timestamp: {notification['timestamp']}")
                
                except Exception as e:
                    st.error(f"Erreur lors de la lecture de {file_path}: {e}")
        else:
            st.warning("Aucune notification trouvée. Lancez des tests pour générer des notifications.")
    else:
        st.warning("Dossier 'notifications' non trouvé.")
    
    st.markdown("---")
    
    # Instructions
    st.subheader("📋 Instructions")
    st.markdown("""
    ### Comment utiliser les notifications SMS :
    
    1. **Test du service** : Cliquez sur "Test Service SMS" pour vérifier la configuration
    2. **Signaux manuels** : Utilisez les boutons pour envoyer des signaux de test
    3. **Simulation automatique** : Lancez la simulation pour voir les signaux automatiques
    4. **Consulter les notifications** : Vérifiez le dossier 'notifications' pour voir les messages
    
    ### Intégration dans votre code :
    ```python
    from src.simple_sms_service import send_trading_signal, send_spike_alert
    
    # Envoyer un signal
    send_trading_signal("EURUSD", "BUY", 1.0850, 0.85)
    
    # Envoyer une alerte de spike
    send_spike_alert("Boom 1000 Index", 17965.28, 2.5)
    ```
    """)

if __name__ == "__main__":
    main()
