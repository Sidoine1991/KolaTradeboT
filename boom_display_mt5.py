#!/usr/bin/env python3
"""
Système d'Affichage Dynamique des Résultats d'Analyse Boom
Cadran en bas à droite du graphique MT5 pour afficher les prédictions en temps réel
"""

import MetaTrader5 as mt5
import time
import json
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import threading
import logging

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('boom_display.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class BoomAnalysisDisplay:
    """Affichage dynamique des résultats d'analyse Boom sur le graphique MT5"""
    
    def __init__(self):
        self.api_url = "http://localhost:8002/angelofspike/trend"
        self.symbol = "Boom 1000 Index"
        self.timeframe = "M1"
        self.update_interval = 5  # secondes
        self.display_enabled = True
        self.last_analysis = None
        self.display_thread = None
        self.stop_display = False
        
        # Configuration de l'affichage
        self.display_config = {
            'position_x': 0.75,  # Position X (0-1)
            'position_y': 0.15,  # Position Y (0-1)
            'width': 0.23,       # Largeur (0-1)
            'height': 0.25,      # Hauteur (0-1)
            'background_color': 0x1E1E1E,  # Couleur de fond
            'text_color': 0xFFFFFF,       # Couleur du texte
            'border_color': 0x00FF00,      # Couleur de bordure
            'font_size': 8,               # Taille de police
            'font_name': "Arial"          # Nom de police
        }
        
        # Initialiser MT5
        self._initialize_mt5()
    
    def _initialize_mt5(self):
        """Initialise la connexion MT5"""
        try:
            if not mt5.initialize():
                logger.error("Échec de l'initialisation MT5")
                return False
            
            logger.info("✅ MT5 initialisé pour l'affichage dynamique")
            return True
            
        except Exception as e:
            logger.error(f"Erreur d'initialisation MT5: {e}")
            return False
    
    def get_boom_analysis(self) -> Optional[Dict]:
        """Récupère l'analyse Boom depuis l'API"""
        try:
            url = f"{self.api_url}?symbol={self.symbol}&timeframe={self.timeframe}"
            response = requests.get(url, timeout=5)
            
            if response.status_code == 200:
                data = response.json()
                logger.info(f"📊 Analyse Boom récupérée: {data.get('direction', 'N/A')}")
                return data
            else:
                logger.warning(f"Erreur API: {response.status_code}")
                return None
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Erreur requête API: {e}")
            return None
        except Exception as e:
            logger.error(f"Erreur récupération analyse: {e}")
            return None
    
    def create_display_object(self, analysis: Dict):
        """Crée l'objet d'affichage sur le graphique MT5"""
        try:
            # Supprimer l'ancien objet s'il existe
            self.remove_display_object()
            
            # Créer le texte d'affichage
            display_text = self._format_analysis_text(analysis)
            
            # Créer l'objet rectangle de fond
            rect_request = {
                "action": mt5.OBJECT_CREATE,
                "chart_id": 0,
                "objname": "BoomAnalysisDisplay",
                "objtype": mt5.OBJ_RECTANGLE_LABEL,
                "subwindow": 0,
                "time1": datetime.now(),
                "price1": 0,
                "time2": datetime.now() + timedelta(minutes=1),
                "price2": 0,
                "x_distance": int(self.display_config['position_x'] * 1000),
                "y_distance": int(self.display_config['position_y'] * 1000),
                "x_size": int(self.display_config['width'] * 1000),
                "y_size": int(self.display_config['height'] * 1000),
                "bgcolor": self.display_config['background_color'],
                "border_color": self.display_config['border_color'],
                "border_width": 2,
                "style": mt5.DRAW_LINE_SOLID,
                "width": 1,
                "back": True,
                "selection": False,
                "hidden": False,
                "zorder": 1000
            }
            
            # Créer l'objet texte
            text_request = {
                "action": mt5.OBJECT_CREATE,
                "chart_id": 0,
                "objname": "BoomAnalysisText",
                "objtype": mt5.OBJ_LABEL,
                "subwindow": 0,
                "time1": datetime.now(),
                "price1": 0,
                "x_distance": int(self.display_config['position_x'] * 1000) + 10,
                "y_distance": int(self.display_config['position_y'] * 1000) + 10,
                "text": display_text,
                "font": self.display_config['font_name'],
                "font_size": self.display_config['font_size'],
                "color": self.display_config['text_color'],
                "anchor": mt5.ANCHOR_LEFT_UPPER,
                "back": False,
                "selection": False,
                "hidden": False,
                "zorder": 1001
            }
            
            # Envoyer les requêtes
            result_rect = mt5.object_send(rect_request)
            result_text = mt5.object_send(text_request)
            
            if result_rect and result_text:
                logger.info("✅ Objet d'affichage Boom créé sur le graphique")
                return True
            else:
                logger.error("❌ Échec création objet d'affichage")
                return False
                
        except Exception as e:
            logger.error(f"Erreur création objet d'affichage: {e}")
            return False
    
    def update_display_object(self, analysis: Dict):
        """Met à jour l'objet d'affichage existant"""
        try:
            # Mettre à jour le texte
            display_text = self._format_analysis_text(analysis)
            
            text_request = {
                "action": mt5.OBJECT_MODIFY,
                "chart_id": 0,
                "objname": "BoomAnalysisText",
                "text": display_text,
                "color": self._get_text_color(analysis)
            }
            
            # Mettre à jour la couleur de bordure du rectangle
            border_color = self._get_border_color(analysis)
            
            rect_request = {
                "action": mt5.OBJECT_MODIFY,
                "chart_id": 0,
                "objname": "BoomAnalysisDisplay",
                "border_color": border_color
            }
            
            # Envoyer les requêtes
            mt5.object_send(text_request)
            mt5.object_send(rect_request)
            
            logger.info("✅ Objet d'affichage Boom mis à jour")
            return True
            
        except Exception as e:
            logger.error(f"Erreur mise à jour objet d'affichage: {e}")
            return False
    
    def remove_display_object(self):
        """Supprime l'objet d'affichage du graphique"""
        try:
            # Supprimer le rectangle
            mt5.object_delete(0, "BoomAnalysisDisplay")
            # Supprimer le texte
            mt5.object_delete(0, "BoomAnalysisText")
            logger.info("✅ Objet d'affichage Boom supprimé")
            return True
            
        except Exception as e:
            logger.error(f"Erreur suppression objet d'affichage: {e}")
            return False
    
    def _format_analysis_text(self, analysis: Dict) -> str:
        """Formate le texte d'analyse pour l'affichage"""
        try:
            direction = analysis.get('direction', 'N/A')
            strength = analysis.get('strength', 0)
            confidence = analysis.get('confidence', 0)
            signal = analysis.get('signal', 'N/A')
            spike_prob = analysis.get('spike_probability', 0)
            time_to_spike = analysis.get('time_to_spike', 0)
            ema_proximity = analysis.get('ema_proximity', 'N/A')
            channel_pos = analysis.get('channel_position', 'N/A')
            current_price = analysis.get('current_price', 0)
            channel_strength = analysis.get('channel_strength', 0)
            breakout_prob = analysis.get('breakout_probability', 0)
            
            # Formatage du texte
            text_lines = [
                "🚀 BOOM RISING CHANNEL",
                "━━━━━━━━━━━━━━━━━━━━━━",
                f"Direction: {direction}",
                f"Force: {strength}%",
                f"Confiance: {confidence}%",
                f"Signal: {signal}",
                f"Spike Prob: {spike_prob:.1%}",
                f"Temps: {time_to_spike}s",
                f"EMA: {ema_proximity}",
                f"Canal: {channel_pos}",
                f"Prix: {current_price:.2f}",
                f"Canal Force: {channel_strength:.1%}",
                f"Breakout: {breakout_prob:.1%}",
                f"⏰ {datetime.now().strftime('%H:%M:%S')}"
            ]
            
            return "\\n".join(text_lines)
            
        except Exception as e:
            logger.error(f"Erreur formatage texte: {e}")
            return "Erreur formatage"
    
    def _get_text_color(self, analysis: Dict) -> int:
        """Détermine la couleur du texte selon l'analyse"""
        direction = analysis.get('direction', 'NEUTRAL')
        confidence = analysis.get('confidence', 0)
        
        if direction == 'BUY':
            return 0x00FF00  # Vert
        elif direction == 'SELL':
            return 0xFF0000  # Rouge
        else:
            return 0xFFFF00  # Jaune
    
    def _get_border_color(self, analysis: Dict) -> int:
        """Détermine la couleur de bordure selon l'analyse"""
        direction = analysis.get('direction', 'NEUTRAL')
        confidence = analysis.get('confidence', 0)
        
        if confidence >= 80:
            if direction == 'BUY':
                return 0x00FF00  # Vert vif
            elif direction == 'SELL':
                return 0xFF0000  # Rouge vif
            else:
                return 0xFFFF00  # Jaune vif
        elif confidence >= 60:
            if direction == 'BUY':
                return 0x00AA00  # Vert moyen
            elif direction == 'SELL':
                return 0xAA0000  # Rouge moyen
            else:
                return 0xAAAA00  # Jaune moyen
        else:
            return 0x666666  # Gris
    
    def start_display(self):
        """Démarre l'affichage dynamique"""
        if not self.display_enabled:
            logger.warning("Affichage désactivé")
            return
        
        self.stop_display = False
        self.display_thread = threading.Thread(target=self._display_loop)
        self.display_thread.daemon = True
        self.display_thread.start()
        
        logger.info("🚀 Affichage dynamique Boom démarré")
    
    def stop_display(self):
        """Arrête l'affichage dynamique"""
        self.stop_display = True
        if self.display_thread:
            self.display_thread.join()
        
        # Supprimer l'objet d'affichage
        self.remove_display_object()
        
        logger.info("⏹️ Affichage dynamique Boom arrêté")
    
    def _display_loop(self):
        """Boucle principale d'affichage"""
        while not self.stop_display:
            try:
                # Récupérer l'analyse
                analysis = self.get_boom_analysis()
                
                if analysis:
                    # Vérifier si l'analyse a changé
                    if self.last_analysis != analysis:
                        self.last_analysis = analysis
                        
                        # Créer ou mettre à jour l'objet d'affichage
                        if not self._object_exists("BoomAnalysisDisplay"):
                            self.create_display_object(analysis)
                        else:
                            self.update_display_object(analysis)
                
                # Attendre avant la prochaine mise à jour
                time.sleep(self.update_interval)
                
            except Exception as e:
                logger.error(f"Erreur dans la boucle d'affichage: {e}")
                time.sleep(self.update_interval)
    
    def _object_exists(self, object_name: str) -> bool:
        """Vérifie si un objet existe sur le graphique"""
        try:
            # Essayer de récupérer l'objet
            obj_info = mt5.object_get(0, object_name)
            return obj_info is not None
        except:
            return False
    
    def set_symbol(self, symbol: str):
        """Change le symbole analysé"""
        self.symbol = symbol
        logger.info(f"📊 Symbole changé: {symbol}")
    
    def set_timeframe(self, timeframe: str):
        """Change le timeframe analysé"""
        self.timeframe = timeframe
        logger.info(f"⏰ Timeframe changé: {timeframe}")
    
    def set_update_interval(self, interval: int):
        """Change l'intervalle de mise à jour"""
        self.update_interval = interval
        logger.info(f"🔄 Intervalle de mise à jour: {interval}s")
    
    def set_display_position(self, x: float, y: float, width: float, height: float):
        """Change la position et la taille de l'affichage"""
        self.display_config['position_x'] = x
        self.display_config['position_y'] = y
        self.display_config['width'] = width
        self.display_config['height'] = height
        logger.info(f"📍 Position d'affichage: ({x}, {y}) - Taille: ({width}, {height})")
    
    def get_display_status(self) -> Dict:
        """Retourne le statut de l'affichage"""
        return {
            "enabled": self.display_enabled,
            "running": not self.stop_display,
            "symbol": self.symbol,
            "timeframe": self.timeframe,
            "update_interval": self.update_interval,
            "last_analysis": self.last_analysis,
            "position": {
                "x": self.display_config['position_x'],
                "y": self.display_config['position_y'],
                "width": self.display_config['width'],
                "height": self.display_config['height']
            }
        }

# Instance globale
boom_display = BoomAnalysisDisplay()

def start_boom_display():
    """Démarre l'affichage dynamique Boom"""
    boom_display.start_display()

def stop_boom_display():
    """Arrête l'affichage dynamique Boom"""
    boom_display.stop_display()

def set_boom_symbol(symbol: str):
    """Change le symbole analysé"""
    boom_display.set_symbol(symbol)

def set_boom_timeframe(timeframe: str):
    """Change le timeframe analysé"""
    boom_display.set_timeframe(timeframe)

def get_boom_display_status():
    """Retourne le statut de l'affichage"""
    return boom_display.get_display_status()

if __name__ == "__main__":
    # Test de l'affichage dynamique
    print("🚀 Test de l'Affichage Dynamique Boom Rising Channel")
    print("=" * 60)
    
    try:
        # Démarrer l'affichage
        start_boom_display()
        
        print("✅ Affichage dynamique démarré")
        print("📊 Le cadran d'analyse apparaîtra en bas à droite du graphique")
        print("⏹️ Appuyez sur Ctrl+C pour arrêter")
        
        # Attendre
        while True:
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\n⏹️ Arrêt de l'affichage...")
        stop_boom_display()
        print("✅ Affichage arrêté")
    
    except Exception as e:
        print(f"❌ Erreur: {e}")
    
    finally:
        # Nettoyage
        mt5.shutdown()
        print("🔚 MT5 fermé")
