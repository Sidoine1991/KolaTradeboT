"""
Module d'exécution des ordres pour l'application de trading
Gère l'interaction avec le courtier (MT5) pour l'exécution des ordres
"""
import MetaTrader5 as mt5
import pandas as pd
from typing import Dict, List, Optional, Tuple, Union
import logging
from datetime import datetime
from enum import Enum, auto
import time
import pytz

# Configuration du logger
logger = logging.getLogger(__name__)

class OrderType(Enum):
    """Types d'ordres supportés"""
    MARKET = auto()
    LIMIT = auto()
    STOP = auto()
    STOP_LIMIT = auto()
    MARKET_CLOSE = auto()
    STOP_LOSS = auto()
    TAKE_PROFIT = auto()

class OrderSide(Enum):
    """Côté de l'ordre (achat/vente)"""
    BUY = auto()
    SELL = auto()

class OrderStatus(Enum):
    """Statuts possibles d'un ordre"""
    NEW = auto()
    FILLED = auto()
    PARTIALLY_FILLED = auto()
    CANCELED = auto()
    REJECTED = auto()
    EXPIRED = auto()

class OrderExecutor:
    """Gestionnaire d'exécution des ordres pour MT5"""
    
    # Mappage des types d'ordres MT5
    MT5_ORDER_TYPE = {
        (OrderSide.BUY, OrderType.MARKET): mt5.ORDER_TYPE_BUY,
        (OrderSide.SELL, OrderType.MARKET): mt5.ORDER_TYPE_SELL,
        (OrderSide.BUY, OrderType.LIMIT): mt5.ORDER_TYPE_BUY_LIMIT,
        (OrderSide.SELL, OrderType.LIMIT): mt5.ORDER_TYPE_SELL_LIMIT,
        (OrderSide.BUY, OrderType.STOP): mt5.ORDER_TYPE_BUY_STOP,
        (OrderSide.SELL, OrderType.STOP): mt5.ORDER_TYPE_SELL_STOP,
        (OrderSide.BUY, OrderType.STOP_LIMIT): mt5.ORDER_TYPE_BUY_STOP_LIMIT,
        (OrderSide.SELL, OrderType.STOP_LIMIT): mt5.ORDER_TYPE_SELL_STOP_LIMIT,
    }
    
    # Mappage des types de fermeture MT5
    MT5_CLOSE_TYPE = {
        OrderSide.BUY: mt5.ORDER_TYPE_SELL,
        OrderSide.SELL: mt5.ORDER_TYPE_BUY,
    }
    
    def __init__(self, account: int = None, server: str = None, password: str = None):
        """
        Initialise l'exécuteur d'ordres avec les informations de connexion MT5
        
        Args:
            account: Numéro de compte MT5
            server: Nom du serveur MT5
            password: Mot de passe du compte MT5
        """
        self.account = account
        self.server = server
        self.password = password
        self.connected = False
        self.initialize_mt5()
    
    def initialize_mt5(self) -> bool:
        """Initialise la connexion à MT5"""
        try:
            # Si déjà connecté, on ne fait rien
            if mt5.terminal_info() is not None:
                self.connected = True
                return True
                
            # Initialisation de MT5
            if not mt5.initialize():
                logger.error(f"Échec de l'initialisation de MT5: {mt5.last_error()}")
                self.connected = False
                return False
            
            # Si des informations de connexion sont fournies, on se connecte au compte
            if self.account and self.server and self.password:
                if not mt5.login(
                    login=self.account,
                    server=self.server,
                    password=self.password
                ):
                    logger.error(f"Échec de la connexion au compte {self.account}: {mt5.last_error()}")
                    self.connected = False
                    return False
            
            self.connected = True
            logger.info("Connexion à MT5 établie avec succès")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de l'initialisation de MT5: {e}")
            self.connected = False
            return False
    
    def check_connection(self) -> bool:
        """Vérifie si la connexion à MT5 est active"""
        if not self.connected:
            return self.initialize_mt5()
        return True
    
    def get_account_info(self) -> Optional[dict]:
        """
        Récupère les informations du compte
        
        Returns:
            Dictionnaire contenant les informations du compte ou None en cas d'erreur
        """
        if not self.check_connection():
            return None
            
        try:
            account_info = mt5.account_info()
            if account_info is None:
                logger.error(f"Impossible de récupérer les informations du compte: {mt5.last_error()}")
                return None
                
            return account_info._asdict()
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des informations du compte: {e}")
            return None
    
    def get_symbol_info(self, symbol: str) -> Optional[dict]:
        """
        Récupère les informations d'un symbole
        
        Args:
            symbol: Symbole (ex: 'EURUSD')
            
        Returns:
            Dictionnaire contenant les informations du symbole ou None en cas d'erreur
        """
        if not self.check_connection():
            return None
            
        try:
            # Sélection du symbole
            if not mt5.symbol_select(symbol, True):
                logger.error(f"Impossible de sélectionner le symbole {symbol}: {mt5.last_error()}")
                return None
                
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is None:
                logger.error(f"Impossible de récupérer les informations du symbole {symbol}: {mt5.last_error()}")
                return None
                
            return symbol_info._asdict()
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des informations du symbole {symbol}: {e}")
            return None
    
    def get_market_price(self, symbol: str) -> Optional[float]:
        """
        Récupère le prix actuel du marché pour un symbole
        
        Args:
            symbol: Symbole (ex: 'EURUSD')
            
        Returns:
            Prix actuel ou None en cas d'erreur
        """
        if not self.check_connection():
            return None
            
        try:
            # Sélection du symbole
            if not mt5.symbol_select(symbol, True):
                logger.error(f"Impossible de sélectionner le symbole {symbol}: {mt5.last_error()}")
                return None
                
            # Récupération du dernier tick
            tick = mt5.symbol_info_tick(symbol)
            if tick is None:
                logger.error(f"Impossible de récupérer le tick pour {symbol}: {mt5.last_error()}")
                return None
                
            return (tick.bid + tick.ask) / 2  # Prix moyen entre l'achat et la vente
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération du prix pour {symbol}: {e}")
            return None
    
    def calculate_position_size(
        self, 
        symbol: str, 
        risk_amount: float, 
        entry_price: float, 
        stop_loss: float
    ) -> Optional[float]:
        """
        Calcule la taille de position en fonction du montant à risquer
        
        Args:
            symbol: Symbole (ex: 'EURUSD')
            risk_amount: Montant à risquer dans la devise du compte
            entry_price: Prix d'entrée
            stop_loss: Niveau de stop loss
            
        Returns:
            Taille de position en lots ou None en cas d'erreur
        """
        if not self.check_connection():
            return None
            
        try:
            # Récupération des informations du symbole
            symbol_info = self.get_symbol_info(symbol)
            if not symbol_info:
                return None
            
            # Calcul du risque par unité dans la devise de cotation
            risk_per_unit = abs(entry_price - stop_loss)
            
            # Si le risque par unité est nul, on ne peut pas calculer
            if risk_per_unit <= 0:
                logger.error("Le risque par unité doit être supérieur à zéro")
                return None
            
            # Calcul de la taille de position en unités
            position_size_units = risk_amount / risk_per_unit
            
            # Conversion en lots
            lot_size = symbol_info.get('trade_contract_size', 100000)  # Taille standard d'un lot (100 000 unités)
            position_size_lots = position_size_units / lot_size
            
            # Arrondi à la taille de lot minimale
            lot_step = symbol_info.get('volume_step', 0.01)
            position_size_lots = round(position_size_lots / lot_step) * lot_step
            
            # Vérification de la taille de lot minimale et maximale
            min_lot = symbol_info.get('volume_min', 0.01)
            max_lot = symbol_info.get('volume_max', 100.0)
            
            if position_size_lots < min_lot:
                logger.warning(f"Taille de lot trop petite, utilisation du minimum: {min_lot}")
                position_size_lots = min_lot
            elif position_size_lots > max_lot:
                logger.warning(f"Taille de lot trop grande, utilisation du maximum: {max_lot}")
                position_size_lots = max_lot
            
            return position_size_lots
            
        except Exception as e:
            logger.error(f"Erreur lors du calcul de la taille de position: {e}")
            return None
    
    def place_order(
        self,
        symbol: str,
        order_type: OrderType,
        side: OrderSide,
        volume: float,
        price: Optional[float] = None,
        stop_loss: Optional[float] = None,
        take_profit: Optional[float] = None,
        comment: str = "",
        magic: int = 0,
        expiration: Optional[datetime] = None
    ) -> Optional[dict]:
        """
        Place un nouvel ordre
        
        Args:
            symbol: Symbole (ex: 'EURUSD')
            order_type: Type d'ordre (MARKET, LIMIT, STOP, etc.)
            side: Côté de l'ordre (BUY/SELL)
            volume: Taille de la position en lots
            price: Prix d'entrée (obligatoire pour les ordres en attente)
            stop_loss: Niveau de stop loss
            take_profit: Niveau de take profit
            comment: Commentaire pour l'ordre
            magic: Identifiant magique pour le suivi des ordres
            expiration: Date d'expiration pour les ordres en attente
            
        Returns:
            Dictionnaire contenant les informations de l'ordre exécuté ou None en cas d'erreur
        """
        if not self.check_connection():
            return None
            
        try:
            # Interdire les doublons: si une position est déjà ouverte sur ce symbole, on refuse
            try:
                existing = mt5.positions_get(symbol=symbol)
                if existing and len(existing) > 0:
                    logger.warning(f"Ordre refusé: position déjà ouverte sur {symbol}")
                    return None
            except Exception:
                pass
            # Vérification du symbole
            if not mt5.symbol_select(symbol, True):
                logger.error(f"Impossible de sélectionner le symbole {symbol}: {mt5.last_error()}")
                return None
            
            # Préparation de la requête d'ordre
            request = {
                'action': mt5.TRADE_ACTION_DEAL if order_type == OrderType.MARKET else mt5.TRADE_ACTION_PENDING,
                'symbol': symbol,
                'volume': float(volume),
                'type': self.MT5_ORDER_TYPE.get((side, order_type)),
                'magic': magic,
                'comment': comment,
                'type_time': mt5.ORDER_TIME_GTC,  # Good Till Cancel
                'type_filling': mt5.ORDER_FILLING_RETURN,
            }
            
            # Prix pour les ordres en attente
            if order_type != OrderType.MARKET:
                if price is None:
                    logger.error("Un prix doit être spécifié pour les ordres en attente")
                    return None
                request['price'] = float(price)
            
            # Stop Loss et Take Profit
            if stop_loss is not None:
                request['sl'] = float(stop_loss)
            if take_profit is not None:
                request['tp'] = float(take_profit)
            
            # Expiration pour les ordres en attente
            if expiration is not None and order_type != OrderType.MARKET:
                request['expiration'] = int(expiration.timestamp())
            
            # Envoi de l'ordre
            result = mt5.order_send(request)
            if result is None:
                logger.error(f"Échec de l'envoi de l'ordre: {mt5.last_error()}")
                return None
            
            # Vérification du résultat
            result_dict = result._asdict()
            
            if result.retcode != mt5.TRADE_RETCODE_DONE:
                logger.error(f"Erreur lors de l'exécution de l'ordre: {result.comment} (code: {result.retcode})")
                return None
            
            logger.info(f"Ordre exécuté avec succès: {result.order} - {result.comment}")
            return result_dict
            
        except Exception as e:
            logger.error(f"Erreur lors du placement de l'ordre: {e}")
            return None
    
    def close_position(self, position_id: int, volume: Optional[float] = None, comment: str = "") -> bool:
        """
        Ferme une position existante
        
        Args:
            position_id: Identifiant de la position à fermer
            volume: Volume à fermer (None pour fermer toute la position)
            comment: Commentaire pour l'ordre de fermeture
            
        Returns:
            True si la position a été fermée avec succès, False sinon
        """
        if not self.check_connection():
            return False
            
        try:
            # Récupération de la position
            position = mt5.positions_get(ticket=position_id)
            if position is None or len(position) == 0:
                logger.error(f"Position non trouvée: {position_id}")
                return False
                
            position = position[0]
            
            # Détermination du type d'ordre de fermeture (inverse de la position)
            if position.type == mt5.POSITION_TYPE_BUY:
                order_type = mt5.ORDER_TYPE_SELL
                price = mt5.symbol_info_tick(position.symbol).bid
            else:
                order_type = mt5.ORDER_TYPE_BUY
                price = mt5.symbol_info_tick(position.symbol).ask
            
            # Volume à fermer
            close_volume = float(volume) if volume is not None else position.volume
            
            # Préparation de la requête de fermeture
            request = {
                'action': mt5.TRADE_ACTION_DEAL,
                'position': position.ticket,
                'symbol': position.symbol,
                'volume': close_volume,
                'type': order_type,
                'price': price,
                'magic': position.magic,
                'comment': comment,
                'type_time': mt5.ORDER_TIME_GTC,
                'type_filling': mt5.ORDER_FILLING_RETURN,
            }
            
            # Envoi de l'ordre de fermeture
            result = mt5.order_send(request)
            
            if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
                error = mt5.last_error() if result is None else result.comment
                logger.error(f"Échec de la fermeture de la position {position_id}: {error}")
                return False
            
            logger.info(f"Position {position_id} fermée avec succès")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de la fermeture de la position {position_id}: {e}")
            return False
    
    def modify_position(
        self, 
        position_id: int, 
        stop_loss: Optional[float] = None, 
        take_profit: Optional[float] = None,
        comment: str = ""
    ) -> bool:
        """
        Modifie les niveaux de stop loss et/ou take profit d'une position existante
        
        Args:
            position_id: Identifiant de la position à modifier
            stop_loss: Nouveau niveau de stop loss (None pour ne pas le modifier)
            take_profit: Nouveau niveau de take profit (None pour ne pas le modifier)
            comment: Nouveau commentaire pour la position
            
        Returns:
            True si la position a été modifiée avec succès, False sinon
        """
        if not self.check_connection():
            return False
            
        try:
            # Récupération de la position
            position = mt5.positions_get(ticket=position_id)
            if position is None or len(position) == 0:
                logger.error(f"Position non trouvée: {position_id}")
                return False
                
            position = position[0]
            
            # Préparation de la requête de modification
            request = {
                'action': mt5.TRADE_ACTION_SLTP,
                'position': position.ticket,
                'symbol': position.symbol,
                'sl': float(stop_loss) if stop_loss is not None else position.sl,
                'tp': float(take_profit) if take_profit is not None else position.tp,
                'magic': position.magic,
                'comment': comment if comment else position.comment,
            }
            
            # Envoi de la requête de modification
            result = mt5.order_send(request)
            
            if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
                error = mt5.last_error() if result is None else result.comment
                logger.error(f"Échec de la modification de la position {position_id}: {error}")
                return False
            
            logger.info(f"Position {position_id} modifiée avec succès")
            return True
            
        except Exception as e:
            logger.error(f"Erreur lors de la modification de la position {position_id}: {e}")
            return False
    
    def get_open_positions(self, symbol: Optional[str] = None, magic: Optional[int] = None) -> List[dict]:
        """
        Récupère la liste des positions ouvertes
        
        Args:
            symbol: Filtre par symbole (optionnel)
            magic: Filtre par identifiant magique (optionnel)
            
        Returns:
            Liste des positions ouvertes (sous forme de dictionnaires)
        """
        if not self.check_connection():
            return []
            
        try:
            # Récupération des positions
            if symbol is not None:
                positions = mt5.positions_get(symbol=symbol)
            else:
                positions = mt5.positions_get()
            
            if positions is None:
                return []
            
            # Filtrage par magic si spécifié
            if magic is not None:
                positions = [p for p in positions if p.magic == magic]
            
            # Conversion en dictionnaires
            return [p._asdict() for p in positions]
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des positions: {e}")
            return []
    
    def get_order_history(
        self, 
        from_date: Optional[datetime] = None, 
        to_date: Optional[datetime] = None,
        symbol: Optional[str] = None,
        magic: Optional[int] = None
    ) -> List[dict]:
        """
        Récupère l'historique des ordres
        
        Args:
            from_date: Date de début (optionnel)
            to_date: Date de fin (optionnel, par défaut maintenant)
            symbol: Filtre par symbole (optionnel)
            magic: Filtre par identifiant magique (optionnel)
            
        Returns:
            Liste des ordres (sous forme de dictionnaires)
        """
        if not self.check_connection():
            return []
            
        try:
            # Conversion des dates en timestamp
            from_timestamp = int(from_date.timestamp()) if from_date else 0
            to_timestamp = int((to_date or datetime.now()).timestamp())
            
            # Récupération de l'historique
            orders = mt5.history_orders_get(from_timestamp, to_timestamp)
            if orders is None:
                return []
            
            # Conversion en liste de dictionnaires
            orders_list = [o._asdict() for o in orders]
            
            # Filtrage
            if symbol is not None:
                orders_list = [o for o in orders_list if o['symbol'] == symbol]
            if magic is not None:
                orders_list = [o for o in orders_list if o['magic'] == magic]
            
            return orders_list
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération de l'historique des ordres: {e}")
            return []
    
    def get_deal_history(
        self, 
        from_date: Optional[datetime] = None, 
        to_date: Optional[datetime] = None,
        symbol: Optional[str] = None,
        magic: Optional[int] = None
    ) -> List[dict]:
        """
        Récupère l'historique des deals
        
        Args:
            from_date: Date de début (optionnel)
            to_date: Date de fin (optionnel, par défaut maintenant)
            symbol: Filtre par symbole (optionnel)
            magic: Filtre par identifiant magique (optionnel)
            
        Returns:
            Liste des deals (sous forme de dictionnaires)
        """
        if not self.check_connection():
            return []
            
        try:
            # Conversion des dates en timestamp
            from_timestamp = int(from_date.timestamp()) if from_date else 0
            to_timestamp = int((to_date or datetime.now()).timestamp())
            
            # Récupération de l'historique
            deals = mt5.history_deals_get(from_timestamp, to_timestamp)
            if deals is None:
                return []
            
            # Conversion en liste de dictionnaires
            deals_list = [d._asdict() for d in deals]
            
            # Filtrage
            if symbol is not None:
                deals_list = [d for d in deals_list if d['symbol'] == symbol]
            if magic is not None:
                deals_list = [d for d in deals_list if d['magic'] == magic]
            
            return deals_list
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération de l'historique des deals: {e}")
            return []
    
    def shutdown(self):
        """Ferme la connexion à MT5"""
        if self.connected:
            mt5.shutdown()
            self.connected = False
            logger.info("Connexion à MT5 fermée")
