# mypy: disable-error-code=attr-defined
import MetaTrader5 as mt5  # type: ignore
import pandas as pd
import os
import sys
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Forcer l'encodage UTF-8 sur Windows pour éviter les erreurs cp1252 lors des impressions avec emoji
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

# Ajouter le répertoire racine du projet au PYTHONPATH
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)
    print(f"✅ Ajout du répertoire au PYTHONPATH: {project_root}")
else:
    print(f"ℹ️ Le répertoire est déjà dans PYTHONPATH: {project_root}")

# Vérifier les chemins d'importation
print("\n🔍 Chemins d'importation (sys.path):")
for i, path in enumerate(sys.path, 1):
    print(f"{i}. {path}")
print()

# Ajouter le dossier strategies au path
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'strategies'))

load_dotenv()

MT5_LOGIN = int(os.getenv('MT5_LOGIN', 0))
MT5_PASSWORD = os.getenv('MT5_PASSWORD', '')
MT5_SERVER = os.getenv('MT5_SERVER', '')

# Mapping des timeframes
TIMEFRAME_MAPPING = {
    '1m': mt5.TIMEFRAME_M1,
    '5m': mt5.TIMEFRAME_M5,
    '15m': mt5.TIMEFRAME_M15,
    '30m': mt5.TIMEFRAME_M30,
    '1h': mt5.TIMEFRAME_H1,
    '4h': mt5.TIMEFRAME_H4,
    '6h': mt5.TIMEFRAME_H6,
    '8h': mt5.TIMEFRAME_H8,
    '1d': mt5.TIMEFRAME_D1,
    '1w': mt5.TIMEFRAME_W1,
    '1M': mt5.TIMEFRAME_MN1
}

# Catégories d'instruments
INSTRUMENT_CATEGORIES = {
    'FOREX': ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD'],
    'SYNTHETIC': [
        'BOOM', 'CRASH', 'STEP', 'JUMP', 'RANGE', 'VOLATILITY', 'DRIFT', 'DEX', 
        'MULTI', 'DAILY', 'HYBRID', 'SKEWED', 'SYNTHETIC', 'INDEX', 'INDICES',
        'SYNTH', 'SYN', 'SYNTHETIC_INDEX', 'SYNTHETIC_INDICES'
    ],
    'COMMODITIES': ['GOLD', 'SILVER', 'OIL', 'COPPER', 'NATURAL_GAS', 'XAU', 'XAG', 'XPD', 'XPT'],
    'INDICES': ['SPX', 'NAS', 'DOW', 'FTSE', 'DAX', 'NIKKEI', 'WALL_STREET', 'US_500', 'US_TECH'],
    'CRYPTO': ['BTC', 'ETH', 'LTC', 'XRP', 'ADA', 'DOT', 'BCH', 'BAT', 'APE', 'ALG', 'XTZ']
}


def activate_all_symbols():
    """Active TOUS les symboles dans le Market Watch MT5 pour qu'ils soient accessibles via l'API."""
    print("🔄 Activation de tous les symboles MT5...")
    
    # Récupérer tous les symboles disponibles
    all_symbols = mt5.symbols_get()  # type: ignore
    if all_symbols is None:
        print("❌ Impossible de récupérer la liste des symboles")
        return 0
    
    print(f"📊 {len(all_symbols)} symboles trouvés sur le serveur MT5")
    
    # Activer tous les symboles un par un
    count = 0
    failed = 0
    
    for i, sym in enumerate(all_symbols):
        try:
            if mt5.symbol_select(sym.name, True):  # type: ignore
                count += 1
            else:
                failed += 1
                if failed <= 10:  # Afficher seulement les 10 premiers échecs
                    print(f"⚠️ Échec activation: {sym.name}")
        except Exception as e:
            failed += 1
            if failed <= 10:
                print(f"❌ Erreur activation {sym.name}: {e}")
        
        # Progress indicator pour les gros volumes
        if (i + 1) % 100 == 0:
            print(f"🔄 Progression: {i + 1}/{len(all_symbols)} symboles traités...")
    
    print(f"✅ {count} symboles activés avec succès dans le Market Watch MT5")
    if failed > 0:
        print(f"⚠️ {failed} symboles n'ont pas pu être activés")
    
    return count


def connect():
    """Connexion à MT5 avec gestion d'erreurs"""
    # D'abord initialiser MT5 sans paramètres
    if not mt5.initialize():  # type: ignore
        error = mt5.last_error()  # type: ignore
        raise RuntimeError(f"MT5 initialization failed: {error}")
    
    # Vérifier si on a des identifiants configurés
    if MT5_LOGIN and MT5_PASSWORD and MT5_SERVER:
        # Se connecter avec les identifiants fournis
        if not mt5.login(login=MT5_LOGIN, password=MT5_PASSWORD, server=MT5_SERVER):  # type: ignore
            error = mt5.last_error()  # type: ignore
            raise RuntimeError(f"MT5 login failed: {error}")
        print(f"✅ Connecté à MT5 avec identifiants - Serveur: {MT5_SERVER}")
    else:
        # Utiliser la connexion automatique (compte déjà connecté dans MT5)
        account_info = mt5.account_info()
        if account_info is None:
            raise RuntimeError("MT5 login failed: No account connected. Please connect to MT5 terminal first.")
        print(f"✅ Connecté à MT5 automatiquement - Login: {account_info.login}, Serveur: {account_info.server}")
    
    activate_all_symbols() # Appel automatique après l'initialisation MT5
    return True


def shutdown():
    """Déconnexion de MT5"""
    mt5.shutdown()  # type: ignore
    print("🔌 Déconnecté de MT5")


def get_ticks(symbol, from_time, to_time):
    """Récupérer les ticks pour un symbole"""
    return mt5.copy_ticks_range(symbol, from_time, to_time, mt5.COPY_TICKS_ALL)  # type: ignore


def get_ohlc(symbol, timeframe='1h', count=1000, start_pos=0):
    """
    Récupérer les données OHLC pour un symbole
    
    Args:
        symbol: Nom du symbole (ex: 'BOOM1000')
        timeframe: Timeframe ('1m', '5m', '15m', '1h', etc.)
        count: Nombre de bougies à récupérer
        start_pos: Position de départ (0 = dernières bougies)
    
    Returns:
        DataFrame avec les données OHLC
    """
    if not is_connected():
        raise RuntimeError("MT5 n'est pas connecté")
    
    # Vérifier si le symbole existe
    symbol_info = mt5.symbol_info(symbol)  # type: ignore
    if symbol_info is None:
        print(f"❌ Symbole '{symbol}' non trouvé sur MT5")
        return None
    
    if not symbol_info.visible:
        print(f"⚠️ Symbole '{symbol}' non visible, tentative d'ajout...")
        if not mt5.symbol_select(symbol, True):  # type: ignore
            print(f"❌ Impossible d'ajouter le symbole '{symbol}'")
            return None
    
    # Convertir le timeframe string en constante MT5
    mt5_timeframe = TIMEFRAME_MAPPING.get(timeframe, mt5.TIMEFRAME_H1)
    print(f"🔍 Tentative de récupération: {symbol} sur {timeframe} (MT5: {mt5_timeframe})")
    
    # Récupérer les données
    rates = mt5.copy_rates_from_pos(symbol, mt5_timeframe, start_pos, count)  # type: ignore
    
    if rates is None:
        print(f"❌ MT5 a retourné None pour {symbol} sur {timeframe}")
        # Vérifier l'erreur MT5
        error = mt5.last_error()  # type: ignore
        if error[0] != 0:
            print(f"❌ Erreur MT5: {error}")
        return None
    
    if len(rates) == 0:
        print(f"⚠️ Aucune donnée trouvée pour {symbol} sur {timeframe}")
        return None
    
    # Convertir en DataFrame
    df = pd.DataFrame(rates)
    df['time'] = pd.to_datetime(df['time'], unit='s')
    
    # Renommer les colonnes pour plus de clarté
    df = df.rename(columns={
        'time': 'timestamp',
        'open': 'open',
        'high': 'high', 
        'low': 'low',
        'close': 'close',
        'tick_volume': 'volume',
        'spread': 'spread',
        'real_volume': 'real_volume'
    })
    
    print(f"✅ Récupéré {len(df)} bougies pour {symbol} ({timeframe})")
    return df


def get_ohlc_range(symbol, timeframe='1h', from_date=None, to_date=None):
    """
    Récupérer les données OHLC pour une période spécifique
    
    Args:
        symbol: Nom du symbole
        timeframe: Timeframe
        from_date: Date de début (datetime)
        to_date: Date de fin (datetime)
    
    Returns:
        DataFrame avec les données OHLC
    """
    if not is_connected():
        raise RuntimeError("MT5 n'est pas connecté")
    
    # Dates par défaut
    if from_date is None:
        from_date = datetime.now() - timedelta(days=7)
    if to_date is None:
        to_date = datetime.now()
    
    # Convertir le timeframe
    mt5_timeframe = TIMEFRAME_MAPPING.get(timeframe, mt5.TIMEFRAME_H1)
    
    # Récupérer les données
    rates = mt5.copy_rates_range(symbol, mt5_timeframe, from_date, to_date)  # type: ignore
    
    if rates is None or len(rates) == 0:
        print(f"⚠️ Aucune donnée trouvée pour {symbol} entre {from_date} et {to_date}")
        return None
    
    # Convertir en DataFrame
    df = pd.DataFrame(rates)
    df['time'] = pd.to_datetime(df['time'], unit='s')
    
    # Renommer les colonnes
    df = df.rename(columns={
        'time': 'timestamp',
        'open': 'open',
        'high': 'high', 
        'low': 'low',
        'close': 'close',
        'tick_volume': 'volume',
        'spread': 'spread',
        'real_volume': 'real_volume'
    })
    
    print(f"✅ Récupéré {len(df)} bougies pour {symbol} ({timeframe}) du {from_date.date()} au {to_date.date()}")
    return df


def get_all_symbols():
    """
    Récupérer TOUS les symboles disponibles sur MT5 (exactement comme dans le Market Watch)
    
    Returns:
        Liste complète de tous les symboles avec leurs détails
    """
    if not is_connected():
        raise RuntimeError("MT5 n'est pas connecté")
    
    # Récupérer tous les symboles avec leurs informations complètes
    symbols = mt5.symbols_get()  # type: ignore
    if symbols is None:
        print("❌ Aucun symbole trouvé")
        return []
    
    # Extraire les noms exacts des symboles
    symbol_names = [symbol.name for symbol in symbols]
    
    # Afficher des statistiques détaillées
    print(f"📊 Total symboles récupérés: {len(symbol_names)}")
    
    # Compter par type d'instrument
    forex_count = len([s for s in symbol_names if len(s) == 6 and s[:3] in INSTRUMENT_CATEGORIES['FOREX'] and s[3:6] in INSTRUMENT_CATEGORIES['FOREX']])
    synthetic_count = len([s for s in symbol_names if any(keyword in s.upper() for keyword in INSTRUMENT_CATEGORIES['SYNTHETIC'])])
    crypto_count = len([s for s in symbol_names if any(keyword in s.upper() for keyword in INSTRUMENT_CATEGORIES['CRYPTO'])])
    commodities_count = len([s for s in symbol_names if any(keyword in s.upper() for keyword in INSTRUMENT_CATEGORIES['COMMODITIES'])])
    indices_count = len([s for s in symbol_names if any(keyword in s.upper() for keyword in INSTRUMENT_CATEGORIES['INDICES'])])
    
    print(f"   💱 Forex: {forex_count}")
    print(f"   🎯 Synthétiques: {synthetic_count}")
    print(f"   🪙 Crypto: {crypto_count}")
    print(f"   🥇 Commodités: {commodities_count}")
    print(f"   📈 Indices: {indices_count}")
    
    return symbol_names


def get_symbols_by_category(category=None):
    """
    Récupérer les symboles par catégorie
    
    Args:
        category: Catégorie spécifique ('FOREX', 'SYNTHETIC', 'COMMODITIES', etc.)
    
    Returns:
        Dictionnaire avec symboles par catégorie ou liste pour une catégorie spécifique
    """
    all_symbols = get_all_symbols()
    
    if category:
        return _filter_symbols_by_category(all_symbols, category)
    else:
        return _categorize_all_symbols(all_symbols)


def _categorize_all_symbols(symbols):
    """Catégorise tous les symboles"""
    categorized = {
        'FOREX': [],
        'SYNTHETIC': [],
        'COMMODITIES': [],
        'INDICES': [],
        'CRYPTO': [],
        'STOCKS': [],
        'OTHER': []
    }
    
    for symbol in symbols:
        category = _get_symbol_category(symbol)
        if category in categorized:
            categorized[category].append(symbol)
        else:
            categorized['OTHER'].append(symbol)
    
    return categorized


def _filter_symbols_by_category(symbols, category):
    """Filtre les symboles par catégorie"""
    if category == 'SYNTHETIC':
        return [s for s in symbols if any(keyword in s.upper() for keyword in INSTRUMENT_CATEGORIES['SYNTHETIC'])]
    elif category == 'FOREX':
        return [s for s in symbols if len(s) == 6 and s[:3] in INSTRUMENT_CATEGORIES['FOREX'] and s[3:6] in INSTRUMENT_CATEGORIES['FOREX']]
    elif category == 'COMMODITIES':
        return [s for s in symbols if any(keyword in s.upper() for keyword in INSTRUMENT_CATEGORIES['COMMODITIES'])]
    elif category == 'INDICES':
        return [s for s in symbols if any(keyword in s.upper() for keyword in INSTRUMENT_CATEGORIES['INDICES'])]
    elif category == 'CRYPTO':
        return [s for s in symbols if any(keyword in s.upper() for keyword in INSTRUMENT_CATEGORIES['CRYPTO'])]
    else:
        return []


def _get_symbol_category(symbol):
    """Détermine la catégorie d'un symbole"""
    symbol_upper = symbol.upper()
    
    # Synthétiques - Détection améliorée pour Deriv
    if any(keyword in symbol_upper for keyword in INSTRUMENT_CATEGORIES['SYNTHETIC']):
        return 'SYNTHETIC'
    
    # Détection spécifique des indices synthétiques de Deriv
    if any(pattern in symbol_upper for pattern in [
        'BOOM_', 'CRASH_', 'VOLATILITY_', 'STEP_', 'JUMP_', 'RANGE_',
        'DRIFT_', 'DEX_', 'MULTI_', 'DAILY_', 'HYBRID_', 'SKEWED_',
        'SYNTHETIC_', 'SYNTH_', 'SYN_'
    ]):
        return 'SYNTHETIC'
    
    # Détection des indices avec nombres (ex: Boom 1000, Crash 500, etc.)
    if any(pattern in symbol_upper for pattern in [
        'BOOM ', 'CRASH ', 'VOLATILITY ', 'STEP ', 'JUMP ', 'RANGE ',
        'DRIFT ', 'DEX ', 'MULTI ', 'DAILY ', 'HYBRID ', 'SKEWED '
    ]):
        return 'SYNTHETIC'
    
    # Forex (paires de devises)
    if len(symbol) == 6 and symbol[:3] in INSTRUMENT_CATEGORIES['FOREX'] and symbol[3:6] in INSTRUMENT_CATEGORIES['FOREX']:
        return 'FOREX'
    
    # Commodités
    if any(keyword in symbol_upper for keyword in INSTRUMENT_CATEGORIES['COMMODITIES']):
        return 'COMMODITIES'
    
    # Indices
    if any(keyword in symbol_upper for keyword in INSTRUMENT_CATEGORIES['INDICES']):
        return 'INDICES'
    
    # Crypto
    if any(keyword in symbol_upper for keyword in INSTRUMENT_CATEGORIES['CRYPTO']):
        return 'CRYPTO'
    
    # Actions (si contient des mots-clés d'actions)
    if any(keyword in symbol_upper for keyword in ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA']):
        return 'STOCKS'
    
    return 'OTHER'


def get_symbols(filter_pattern=None):
    """
    Récupérer la liste des symboles disponibles
    
    Args:
        filter_pattern: Pattern pour filtrer les symboles (ex: 'BOOM' pour ne garder que les BOOM)
    
    Returns:
        Liste des symboles
    """
    if not is_connected():
        raise RuntimeError("MT5 n'est pas connecté")
    
    symbols = mt5.symbols_get()  # type: ignore
    if symbols is None:
        return []
    
    symbol_names = [symbol.name for symbol in symbols]
    
    # Filtrer si un pattern est spécifié
    if filter_pattern:
        symbol_names = [s for s in symbol_names if filter_pattern.upper() in s.upper()]
    
    return symbol_names


def get_boom_crash_symbols():
    """Récupérer spécifiquement les symboles Boom/Crash"""
    return get_symbols_by_category('SYNTHETIC')


def get_forex_pairs():
    """Récupérer les paires de devises"""
    return get_symbols_by_category('FOREX')


def get_commodities():
    """Récupérer les matières premières"""
    return get_symbols_by_category('COMMODITIES')


def get_indices():
    """Récupérer les indices"""
    return get_symbols_by_category('INDICES')


def get_crypto_pairs():
    """Récupérer les paires crypto"""
    return get_symbols_by_category('CRYPTO')


def initialize_ml_supertrend(symbol='EURUSD', timeframe='H1', risk_percent=1.0, max_positions=3):
    """
    Initialise la stratégie ML-SuperTrend
    
    Args:
        symbol: Symbole à trader (ex: 'EURUSD')
        timeframe: Timeframe ('M1', 'M5', 'M15', 'H1', 'H4', 'D1')
        risk_percent: Pourcentage du capital à risquer par trade (défaut: 1.0%)
        max_positions: Nombre maximum de positions simultanées (défaut: 3)
        
    Returns:
        Instance de la stratégie ML-SuperTrend
    """
    try:
        print(f"⚙️ Initialisation de ML-SuperTrend avec les paramètres:")
        print(f"- Symbole: {symbol}")
        print(f"- Timeframe: {timeframe}")
        print(f"- Pourcentage de risque: {risk_percent}%")
        print(f"- Positions max: {max_positions}")
        
        import sys
        import os
        
        # Chemin absolu vers le dossier backend
        backend_path = os.path.dirname(os.path.abspath(__file__))
        
        # Ajouter le dossier backend au PYTHONPATH s'il n'y est pas déjà
        if backend_path not in sys.path:
            sys.path.insert(0, backend_path)
            print(f"✅ Ajout du dossier backend au PYTHONPATH: {backend_path}")
        
        # Importer avec le chemin absolu
        print("🔍 Tentative d'import de MLSuperTrendStrategy...")
        
        # Ajouter le chemin racine du projet au PYTHONPATH
        project_root = os.path.dirname(backend_path)
        if project_root not in sys.path:
            sys.path.insert(0, project_root)
            print(f"✅ Ajout du dossier racine au PYTHONPATH: {project_root}")
        
        # Importer avec le chemin absolu complet
        from backend.strategies.ml_supertrend import MLSuperTrendStrategy, MLSuperTrendConfig
        print("✅ Import de MLSuperTrendStrategy réussi")
        
        # Configuration de la stratégie
        print("🔧 Création de la configuration...")
        config = MLSuperTrendConfig(
            symbol=symbol,
            timeframe=timeframe,
            risk_percent=risk_percent,
            max_positions=max_positions
        )
        
        # Initialisation de la stratégie
        print("🚀 Création de l'instance de la stratégie...")
        strategy = MLSuperTrendStrategy(config)
        
        print("🔄 Initialisation de la stratégie...")
        if strategy.initialize():
            print("✅ Stratégie ML-SuperTrend initialisée avec succès")
            return strategy
        else:
            print("❌ Échec de l'initialisation de la stratégie (retourné False)")
            return None
        
    except ImportError as ie:
        print(f"❌ Erreur d'importation: {ie}")
        print("Vérifiez que le module strategies.ml_supertrend existe et est correctement installé")
        import traceback
        return f"ImportError: {ie}\n{traceback.format_exc()}"
    except Exception as e:
        import traceback
        print(f"❌ Erreur inattendue lors de l'initialisation de ML-SuperTrend: {e}")
        print("Stack trace complète:")
        traceback.print_exc()
        return f"Exception: {e}\n{traceback.format_exc()}"


def get_ml_supertrend_signals(strategy, data):
    """
    Obtient les signaux de trading de la stratégie ML-SuperTrend
    
    Args:
        strategy: Instance de la stratégie ML-SuperTrend
        data: Données OHLCV au format DataFrame
        
    Returns:
        Dictionnaire contenant les signaux et indicateurs
    """
    if strategy is None:
        return {"error": "Stratégie non initialisée"}
        
    try:
        return strategy.get_signals(data)
    except Exception as e:
        return {"error": f"Erreur lors de la génération des signaux: {str(e)}"}


def get_symbol_info(symbol):
    """Récupérer les informations d'un symbole"""
    if not is_connected():
        return None
        
    symbol_info = mt5.symbol_info(symbol)  # type: ignore
    if symbol_info is None:
        return None
    
    return {
        'name': symbol_info.name,
        'bid': symbol_info.bid,
        'ask': symbol_info.ask,
        'point': symbol_info.point,
        'digits': symbol_info.digits,
        'spread': symbol_info.spread,
        'trade_mode': symbol_info.trade_mode,
        'volume_min': symbol_info.volume_min,
        'volume_max': symbol_info.volume_max,
        'volume_step': symbol_info.volume_step,
        'swap_long': symbol_info.swap_long,
        'swap_short': symbol_info.swap_short,
        'margin_initial': symbol_info.margin_initial,
        'margin_maintenance': symbol_info.margin_maintenance,
        'category': _get_symbol_category(symbol_info.name)
    }


def send_order_to_mt5(symbol, order_type, volume, price=None, sl=None, tp=None):
    """
    Envoie un ordre réel (achat ou vente) sur MT5.
    Args:
        symbol: Nom du symbole (ex: 'BOOM1000')
        order_type: 'BUY' ou 'SELL'
        volume: volume à trader (float)
        price: prix d'entrée (None = au marché)
        sl: stop loss (None = pas de SL)
        tp: take profit (None = pas de TP)
    Returns:
        Dictionnaire résultat de l'ordre MT5
    """
    if not is_connected():
        raise RuntimeError("MT5 n'est pas connecté")
    # Bloquer l'ouverture d'ordres dupliqués pour le même symbole
    try:
        open_pos = mt5.positions_get(symbol=symbol)  # type: ignore
        if open_pos and len(open_pos) > 0:
            raise RuntimeError(f"Dupliqué interdit: position déjà ouverte sur {symbol}")
    except Exception:
        pass
    # Sélectionner le type d'ordre
    if order_type.upper() == 'BUY':
        mt5_type = mt5.ORDER_TYPE_BUY
    elif order_type.upper() == 'SELL':
        mt5_type = mt5.ORDER_TYPE_SELL
    else:
        raise ValueError(f"Type d'ordre non supporté: {order_type}")
    # Préparer la requête
    request = {
        'action': mt5.TRADE_ACTION_DEAL,
        'symbol': symbol,
        'volume': float(volume),
        'type': mt5_type,
        'price': price if price is not None else mt5.symbol_info_tick(symbol).ask if mt5_type == mt5.ORDER_TYPE_BUY else mt5.symbol_info_tick(symbol).bid,  # type: ignore
        'sl': sl,
        'tp': tp,
        'deviation': 10,
        'magic': 123456,
        'comment': 'Order from TradBOT',
        'type_time': mt5.ORDER_TIME_GTC,
        'type_filling': mt5.ORDER_FILLING_IOC,
    }
    # Nettoyer les None
    request = {k: v for k, v in request.items() if v is not None}
    result = mt5.order_send(request)  # type: ignore
    return result._asdict() if hasattr(result, '_asdict') else result


def get_current_price(symbol):
    """Récupérer le prix actuel d'un symbole"""
    if not is_connected():
        return None
        
    symbol_info = mt5.symbol_info(symbol)  # type: ignore
    if symbol_info is None:
        return None
    
    return {
        'bid': symbol_info.bid,
        'ask': symbol_info.ask,
        'last': symbol_info.last,
        'volume': symbol_info.volume,
        'category': _get_symbol_category(symbol)
    }


def is_connected():
    """Vérifier si MT5 est connecté"""
    try:
        # Vérifier d'abord si MT5 est déjà initialisé
        terminal_info = mt5.terminal_info()
        if terminal_info is None:
            # MT5 n'est pas initialisé, essayer de l'initialiser
            if not mt5.initialize():
                return False
        else:
            # MT5 est déjà initialisé, vérifier si le terminal est connecté
            if not terminal_info.connected:
                return False
        
        # Vérifier la connexion en testant une opération simple
        account_info = mt5.account_info()
        return account_info is not None
    except Exception as e:
        print(f"❌ Erreur lors de la vérification de la connexion MT5: {e}")
        return False


def get_account_info():
    """Récupérer les informations du compte"""
    if not is_connected():
        return None
        
    account_info = mt5.account_info()  # type: ignore
    if account_info is None:
        return None
    
    return {
        'login': account_info.login,
        'server': account_info.server,
        'balance': account_info.balance,
        'equity': account_info.equity,
        'margin': account_info.margin,
        'profit': account_info.profit,
        'currency': account_info.currency,
        'leverage': account_info.leverage,
        'margin_level': account_info.margin_level
    }


def get_available_timeframes():
    """Récupérer la liste des timeframes disponibles"""
    return list(TIMEFRAME_MAPPING.keys())


def get_market_overview():
    """Vue d'ensemble du marché avec tous les instruments"""
    if not is_connected():
        return None
    
    overview = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'total_symbols': 0,
        'categories': {},
        'active_symbols': [],
        'market_status': 'OPEN'
    }
    
    # Récupérer tous les symboles
    all_symbols = get_all_symbols()
    overview['total_symbols'] = len(all_symbols)
    
    # Catégoriser
    categorized = _categorize_all_symbols(all_symbols)
    overview['categories'] = {k: len(v) for k, v in categorized.items()}
    
    # Symboles actifs (avec prix)
    active_symbols = []
    for symbol in all_symbols[:50]:  # Limiter pour les performances
        price_info = get_current_price(symbol)
        if price_info and price_info['bid'] > 0:
            active_symbols.append({
                'symbol': symbol,
                'category': _get_symbol_category(symbol),
                'bid': price_info['bid'],
                'ask': price_info['ask'],
                'spread': price_info['ask'] - price_info['bid'] if price_info['ask'] > 0 else 0
            })
    
    overview['active_symbols'] = active_symbols
    
    return overview


def test_connection():
    """Test complet de la connexion MT5"""
    try:
        connect()
        
        # Test des symboles
        print("\n📊 Récupération de tous les instruments...")
        all_symbols = get_all_symbols()
        categorized = _categorize_all_symbols(all_symbols)
        
        print(f"📈 Total instruments: {len(all_symbols)}")
        for category, symbols in categorized.items():
            if symbols:
                print(f"  {category}: {len(symbols)} instruments")
                if category == 'SYNTHETIC':
                    print(f"    Exemples: {symbols[:5]}")
        
        # Test des données
        if categorized['SYNTHETIC']:
            test_symbol = categorized['SYNTHETIC'][0]
            print(f"\n🧪 Test données pour {test_symbol}:")
            
            df = get_ohlc(test_symbol, '1h', 10)
            if df is not None:
                print(f"  ✅ {len(df)} bougies récupérées")
                print(f"  📈 Dernier prix: {df['close'].iloc[-1]:.2f}")
                print(f"  📅 Période: {df['timestamp'].iloc[0]} à {df['timestamp'].iloc[-1]}")
        
        # Test des paires Forex
        if categorized['FOREX']:
            test_forex = categorized['FOREX'][0]
            print(f"\n💱 Test Forex pour {test_forex}:")
            
            df = get_ohlc(test_forex, '1h', 5)
            if df is not None:
                print(f"  ✅ {len(df)} bougies récupérées")
                print(f"  💰 Dernier prix: {df['close'].iloc[-1]:.5f}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur de test: {e}")
        return False
    # Suppression de shutdown() ici pour garder la connexion active


def get_open_positions():
    """Récupère les positions ouvertes sur MT5"""
    return mt5.positions_get()  # type: ignore 


def get_trade_history(from_date, to_date):
    """Récupère l'historique des trades sur MT5 pour une période donnée"""
    return mt5.history_deals_get(from_date, to_date)  # type: ignore 


def calculate_position_size(capital, risk_percent, stop_loss_points, symbol):
    """
    Calcule la taille de position optimale selon le capital, le risque accepté (%) et le stop loss (en points).
    Args:
        capital: Capital total (float)
        risk_percent: Pourcentage du capital à risquer (ex: 1.0 pour 1%)
        stop_loss_points: Distance du stop loss en points (ex: 100)
        symbol: Nom du symbole (ex: 'BOOM1000')
    Returns:
        Taille de position recommandée (float)
    """
    if not is_connected():
        raise RuntimeError("MT5 n'est pas connecté")
    symbol_info = mt5.symbol_info(symbol)  # type: ignore
    if symbol_info is None:
        raise ValueError(f"Symbole {symbol} non trouvé sur MT5")
    point_value = symbol_info.point
    lot_step = symbol_info.volume_step
    min_lot = symbol_info.volume_min
    max_lot = symbol_info.volume_max
    # Risque en valeur absolue
    risk_amount = capital * (risk_percent / 100.0)
    # Valeur d'un point pour 1 lot
    tick_value = symbol_info.trade_tick_value if hasattr(symbol_info, 'trade_tick_value') and symbol_info.trade_tick_value > 0 else point_value
    # Taille de position (lots)
    if stop_loss_points * tick_value == 0:
        return min_lot
    position_size = risk_amount / (stop_loss_points * tick_value)
    # Arrondir à l'incrément du broker
    position_size = max(min_lot, min(max_lot, round(position_size / lot_step) * lot_step))
    return position_size

def download_all_symbols():
    """
    Télécharge les données OHLC pour TOUS les symboles disponibles sur MT5.
    Pour chaque symbole, télécharge les données pour tous les timeframes disponibles
    sur les 7 derniers jours.
    """
    try:
        connect()
        all_symbols = get_all_symbols()
        timeframes = list(TIMEFRAME_MAPPING.keys())
        
        today = datetime.now()
        from_date = today - timedelta(days=7)

        # Crée un dossier pour stocker les données
        data_folder = "mt5_data"
        if not os.path.exists(data_folder):
            os.makedirs(data_folder)

        for symbol in all_symbols:
            print(f"🔄 Téléchargement des données pour le symbole: {symbol}")
            
            # Crée un sous-dossier pour chaque symbole
            symbol_folder = os.path.join(data_folder, symbol)
            if not os.path.exists(symbol_folder):
                os.makedirs(symbol_folder)

            for timeframe in timeframes:
                print(f"  ⏳ Timeframe: {timeframe}")
                try:
                    df = get_ohlc_range(symbol, timeframe, from_date, today)
                    
                    if df is not None and not df.empty:
                        # Enregistre le DataFrame dans un fichier CSV
                        filename = f"{symbol}_{timeframe}.csv"
                        filepath = os.path.join(symbol_folder, filename)
                        df.to_csv(filepath, index=False)
                        print(f"    ✅ Données enregistrées dans: {filepath}")
                    else:
                        print(f"    ⚠️ Aucune donnée à enregistrer pour {symbol} ({timeframe})")
                
                except Exception as e:
                    print(f"    ❌ Erreur lors du téléchargement pour {symbol} ({timeframe}): {e}")

        print("✅ Téléchargement terminé pour tous les symboles.")

    except Exception as e:
        print(f"❌ Erreur générale: {e}")
    finally:
        shutdown()

def get_all_symbols_simple():
    """Retourne la liste brute de tous les symboles disponibles sur MT5 (aucune catégorisation)."""
    if not is_connected():
        raise RuntimeError("MT5 n'est pas connecté")
    symbols = mt5.symbols_get()  # type: ignore
    if symbols is None:
        return []
    return [symbol.name for symbol in symbols]

# Exemple d'utilisation
if __name__ == '__main__':
    download_all_symbols()
