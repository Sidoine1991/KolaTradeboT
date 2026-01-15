import streamlit as st
import time
from datetime import datetime
from typing import Dict, List, Optional
import json
import os
import pandas as pd

class AlertSystem:
    """Système d'alertes pour les événements de trading"""
    
    def __init__(self):
        self.alerts = []
        self.alert_types = {
            'spike_detected': {
                'icon': '🚨',
                'color': 'red',
                'sound': 'alert',
                'priority': 'high'
            },
            'signal_generated': {
                'icon': '📊',
                'color': 'blue',
                'sound': 'notification',
                'priority': 'medium'
            },
            'price_alert': {
                'icon': '💰',
                'color': 'green',
                'sound': 'chime',
                'priority': 'low'
            },
            'error': {
                'icon': '❌',
                'color': 'red',
                'sound': 'error',
                'priority': 'high'
            }
        }
    
    def add_alert(self, alert_type: str, message: str, data: Dict = None):
        """Ajoute une nouvelle alerte"""
        if alert_type in self.alert_types:
            alert = {
                'type': alert_type,
                'message': message,
                'timestamp': datetime.now(),
                'data': data or {},
                'read': False
            }
            self.alerts.append(alert)
            
            # Limiter le nombre d'alertes stockées
            if len(self.alerts) > 100:
                self.alerts = self.alerts[-50:]
    
    def get_unread_alerts(self) -> List[Dict]:
        """Récupère les alertes non lues"""
        return [alert for alert in self.alerts if not alert['read']]
    
    def mark_as_read(self, alert_index: int):
        """Marque une alerte comme lue"""
        if 0 <= alert_index < len(self.alerts):
            self.alerts[alert_index]['read'] = True
    
    def clear_alerts(self):
        """Efface toutes les alertes"""
        self.alerts.clear()
    
    def display_alerts(self):
        """Affiche les alertes dans l'interface Streamlit"""
        if not self.alerts:
            return
        
        st.subheader("🔔 Alertes récentes")
        
        # Afficher les 5 dernières alertes
        recent_alerts = self.alerts[-5:]
        
        for i, alert in enumerate(recent_alerts):
            alert_config = self.alert_types.get(alert['type'], {})
            icon = alert_config.get('icon', '📢')
            color = alert_config.get('color', 'gray')
            
            # Créer un conteneur pour l'alerte
            with st.container():
                col1, col2, col3 = st.columns([1, 8, 1])
                
                with col1:
                    st.write(icon)
                
                with col2:
                    st.write(f"**{alert['message']}**")
                    st.caption(f"📅 {alert['timestamp'].strftime('%H:%M:%S')}")
                
                with col3:
                    if not alert['read']:
                        st.write("🆕")
        
        # Bouton pour effacer les alertes
        if st.button("🗑️ Effacer toutes les alertes"):
            self.clear_alerts()
            st.rerun()
    
    def check_spike_alert(self, spikes_df: pd.DataFrame, symbol: str):
        """Vérifie et alerte pour les nouveaux spikes"""
        if not spikes_df.empty:
            latest_spike = spikes_df.iloc[-1]
            spike_type = latest_spike.get('spike_type', 'UNKNOWN')
            pct_change = latest_spike.get('pct_change', 0)
            
            if abs(pct_change) > 1.0:  # Seuil de 1%
                message = f"🚨 {spike_type} détecté sur {symbol}: {pct_change:.2f}%"
                self.add_alert('spike_detected', message, {
                    'symbol': symbol,
                    'spike_type': spike_type,
                    'pct_change': pct_change
                })
    
    def check_price_alert(self, current_price: float, target_price: float, symbol: str, direction: str):
        """Vérifie et alerte pour les niveaux de prix"""
        if direction == 'above' and current_price >= target_price:
            message = f"💰 {symbol} a atteint {target_price:.2f} (actuel: {current_price:.2f})"
            self.add_alert('price_alert', message, {
                'symbol': symbol,
                'current_price': current_price,
                'target_price': target_price
            })
        elif direction == 'below' and current_price <= target_price:
            message = f"💰 {symbol} a atteint {target_price:.2f} (actuel: {current_price:.2f})"
            self.add_alert('price_alert', message, {
                'symbol': symbol,
                'current_price': current_price,
                'target_price': target_price
            })
    
    def check_spike_alert_ml(self, df: pd.DataFrame, symbol: str, ml_proba: float, context: dict, ml_threshold: float = 0.6):
        """Alerte intelligente : déclenche uniquement si proba ML > seuil ET contexte favorable."""
        if ml_proba is not None and ml_proba > ml_threshold and context.get('favorable_context', False):
            message = f"🚨 Spike probable sur {symbol} (proba ML: {ml_proba*100:.1f}%, contexte favorable)"
            self.add_alert('spike_detected', message, {
                'symbol': symbol,
                'ml_proba': ml_proba,
                'context': context
            })

# Instance globale du système d'alertes
alert_system = AlertSystem() 
