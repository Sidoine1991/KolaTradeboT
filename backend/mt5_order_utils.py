import MetaTrader5 as mt5  # type: ignore
import os
import math
from dotenv import load_dotenv

def connect_mt5():
    load_dotenv()
    login = int(os.getenv('MT5_LOGIN', '0'))
    password = os.getenv('MT5_PASSWORD', '')
    server = os.getenv('MT5_SERVER', '')
    path = os.getenv('MT5_PATH', None)
    if not mt5.initialize(path=path if path else None):  # type: ignore
        return False, "Connexion à MT5 impossible."
    if not mt5.login(login, password=password, server=server):  # type: ignore
        mt5.shutdown()  # type: ignore
        return False, "Login MT5 impossible."
    return True, "OK"

def place_order_mt5(symbol, order_type, lot, price=None, sl=None, tp=None, max_loss_usd=3.0):
    ok, msg = connect_mt5()
    if not ok:
        return False, msg
    # Bloquer l'ouverture d'ordres dupliqués pour le même symbole
    try:
        existing_positions = mt5.positions_get(symbol=symbol)  # type: ignore
        if existing_positions and len(existing_positions) > 0:
            mt5.shutdown()  # type: ignore
            return False, f"Ordre refusé: une position est déjà ouverte sur {symbol}."
    except Exception:
        # Si l'appel échoue, on continue, mais ce cas est improbable
        pass
    info = mt5.symbol_info(symbol)  # type: ignore
    if info is None:
        mt5.shutdown()  # type: ignore
        return False, f"Symbole '{symbol}' introuvable."
    if not info.visible:
        if not mt5.symbol_select(symbol, True):  # type: ignore
            mt5.shutdown()  # type: ignore
            return False, f"Impossible de rendre le symbole '{symbol}' visible."
    if lot is None:
        lot = info.volume_min if info else 0.01
    if price is None:
        price = info.last if hasattr(info, 'last') else info.bid
    if sl == 0.0:
        sl = None
    if tp == 0.0:
        tp = None
    # Détermination du type d'ordre
    if order_type == "BUY":
        order_type_mt5 = mt5.ORDER_TYPE_BUY  # type: ignore
    elif order_type == "SELL":
        order_type_mt5 = mt5.ORDER_TYPE_SELL  # type: ignore
    else:
        mt5.shutdown()  # type: ignore
        return False, f"Type d'ordre non supporté: {order_type}"

    # --- Validation/ajustement SL/TP vs stop-level broker ---
    # Les brokers rejettent fréquemment "Invalid stops" si SL/TP ne respectent pas:
    # - la distance minimale (SYMBOL_TRADE_STOPS_LEVEL / stops_level)
    # - le tick size de l'instrument
    # - le bon prix de référence (BUY -> ask, SELL -> bid) pour les ordres au marché
    reference_price = price
    try:
        tick = mt5.symbol_info_tick(symbol)  # type: ignore
        if tick is not None:
            reference_price = float(tick.ask) if order_type == "BUY" else float(tick.bid)
    except Exception:
        pass

    price = reference_price

    point = float(getattr(info, "point", 0.0) or 0.0)
    digits = int(getattr(info, "digits", 0) or 0)
    tick_size = float(
        getattr(info, "trade_tick_size", 0.0)
        or getattr(info, "tick_size", 0.0)
        or 0.0
    )
    if tick_size <= 0.0:
        tick_size = point if point > 0.0 else 0.0

    stops_level_points = getattr(info, "trade_stops_level", None)
    if stops_level_points is None:
        stops_level_points = getattr(info, "stops_level", 0)
    try:
        stops_level_points = float(stops_level_points or 0)
    except Exception:
        stops_level_points = 0.0

    min_dist_price = stops_level_points * point if point > 0.0 else 0.0
    buffer_price = tick_size if tick_size > 0.0 else point
    if buffer_price < 0.0:
        buffer_price = 0.0

    # --- Politique: toujours démarrer avec SL + TP ---
    # Si l'appelant ne fournit pas SL/TP, on les calcule.
    default_sl_points = float(os.getenv("MT5_DEFAULT_SL_POINTS", "300") or "300")
    default_tp_rr = float(os.getenv("MT5_DEFAULT_TP_RR", "2.0") or "2.0")
    default_tp_rr = max(0.5, min(20.0, default_tp_rr))
    base_dist = 0.0
    if point > 0.0:
        base_dist = max(min_dist_price + buffer_price, default_sl_points * point)

    # Calculer le SL maximum autorisé pour ne pas dépasser max_loss_usd
    # Formule: max_loss = lot * contract_size * point_value * distance_points
    # Donc: distance_max = max_loss / (lot * contract_size * point_value)
    max_sl_distance = 0.0
    if info and lot > 0.0 and point > 0.0:
        contract_size = float(getattr(info, "trade_contract_size", 1.0) or 1.0)
        tick_value = float(getattr(info, "trade_tick_value", point) or point)
        if contract_size > 0.0 and tick_value > 0.0:
            # Distance maximale en points pour respecter la perte max
            max_sl_points = max_loss_usd / (lot * contract_size * tick_value / point)
            max_sl_distance = max_sl_points * point
            print(f"🛡️ Protection perte: max {max_loss_usd}$ = max {max_sl_points:.1f} points pour lot {lot}")

    if base_dist > 0.0 and reference_price:
        if order_type == "BUY":
            if sl is None:
                sl = reference_price - base_dist
                # Limiter le SL selon la perte max autorisée
                if max_sl_distance > 0.0:
                    min_sl_allowed = reference_price - max_sl_distance
                    if sl < min_sl_allowed:
                        sl = min_sl_allowed
                        print(f"⚠️ SL ajusté à {sl:.5f} pour respecter la perte max de {max_loss_usd}$")
            if tp is None:
                tp = reference_price + (abs(reference_price - sl) * default_tp_rr)
        else:  # SELL
            if sl is None:
                sl = reference_price + base_dist
                # Limiter le SL selon la perte max autorisée
                if max_sl_distance > 0.0:
                    max_sl_allowed = reference_price + max_sl_distance
                    if sl > max_sl_allowed:
                        sl = max_sl_allowed
                        print(f"⚠️ SL ajusté à {sl:.5f} pour respecter la perte max de {max_loss_usd}$")
            if tp is None:
                tp = reference_price - (abs(reference_price - sl) * default_tp_rr)

    def align_to_tick(val: float, mode: str) -> float:
        """Aligner au tick de manière directionnelle (ceil/floor)."""
        if tick_size <= 0.0:
            return val
        ticks = val / tick_size
        if mode == "UP":
            return math.ceil(ticks) * tick_size
        if mode == "DOWN":
            return math.floor(ticks) * tick_size
        return round(ticks) * tick_size

    # Ajuste SL/TP uniquement si fournis; sinon on laisse None.
    if min_dist_price > 0.0 and reference_price:
        if order_type == "BUY":
            if sl is not None:
                if sl >= reference_price:
                    sl = reference_price - (min_dist_price + buffer_price)
                if (reference_price - sl) < min_dist_price:
                    sl = reference_price - (min_dist_price + buffer_price)
                sl = align_to_tick(sl, "DOWN")
                if digits > 0:
                    sl = round(sl, digits)
            if tp is not None:
                if tp <= reference_price:
                    tp = reference_price + (min_dist_price + buffer_price)
                if (tp - reference_price) < min_dist_price:
                    tp = reference_price + (min_dist_price + buffer_price)
                tp = align_to_tick(tp, "UP")
                if digits > 0:
                    tp = round(tp, digits)
        else:  # SELL
            if sl is not None:
                if sl <= reference_price:
                    sl = reference_price + (min_dist_price + buffer_price)
                if (sl - reference_price) < min_dist_price:
                    sl = reference_price + (min_dist_price + buffer_price)
                sl = align_to_tick(sl, "UP")
                if digits > 0:
                    sl = round(sl, digits)
            if tp is not None:
                if tp >= reference_price:
                    tp = reference_price - (min_dist_price + buffer_price)
                if (reference_price - tp) < min_dist_price:
                    tp = reference_price - (min_dist_price + buffer_price)
                tp = align_to_tick(tp, "DOWN")
                if digits > 0:
                    tp = round(tp, digits)
    # --- Sélection dynamique du filling mode ---
    tried = []
    filling = None
    if info.filling_mode & mt5.ORDER_FILLING_FOK:  # type: ignore
        filling = mt5.ORDER_FILLING_FOK  # type: ignore
        tried.append("FOK (bitmask)")
    elif info.filling_mode & mt5.ORDER_FILLING_IOC:  # type: ignore
        filling = mt5.ORDER_FILLING_IOC  # type: ignore
        tried.append("IOC (bitmask)")
    elif info.filling_mode & mt5.ORDER_FILLING_RETURN:  # type: ignore
        filling = mt5.ORDER_FILLING_RETURN  # type: ignore
        tried.append("RETURN (bitmask)")
    # Brute force si aucun mode détecté
    filling_modes = [
        (mt5.ORDER_FILLING_FOK, "FOK"),
        (mt5.ORDER_FILLING_IOC, "IOC"),
        (mt5.ORDER_FILLING_RETURN, "RETURN")
    ]
    tried_brute = []
    original_sl = sl
    original_tp = tp
    invalid_stops_seen = False

    def try_send(filling_mode, label, sl_value, tp_value):
        request = {
            "action": mt5.TRADE_ACTION_DEAL,  # type: ignore
            "symbol": symbol,
            "volume": lot,
            "type": order_type_mt5,
            "price": price,
            "sl": sl_value,
            "tp": tp_value,
            "deviation": 20,
            "magic": 123456,
            "comment": f"Order WhatsApp {order_type} ({label})",
            "type_time": mt5.ORDER_TIME_GTC,  # type: ignore
            "type_filling": filling_mode,
        }
        result = mt5.order_send(request)  # type: ignore
        return result
    result = None
    if filling is not None:
        result = try_send(filling, tried[-1], sl, tp)
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:  # type: ignore
            mt5.shutdown()  # type: ignore
            return True, f"Ordre {order_type} {symbol} exécuté (lot {lot}) à {price}. (mode: {tried[-1]})"
        else:
            invalid_stops_seen = invalid_stops_seen or ("Invalid stops" in str(getattr(result, "comment", "") or ""))
            tried_brute.append(f"{tried[-1]} (échec)")
    # Brute force si pas de succès
    for mode, label in filling_modes:
        if filling is not None and mode == filling:
            continue  # déjà testé
        result = try_send(mode, label, sl, tp)
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:  # type: ignore
            mt5.shutdown()  # type: ignore
            return True, f"Ordre {order_type} {symbol} exécuté (lot {lot}) à {price}. (mode: {label} - brute force)"
        else:
            invalid_stops_seen = invalid_stops_seen or ("Invalid stops" in str(getattr(result, "comment", "") or ""))
            tried_brute.append(f"{label} (échec)")
    mt5.shutdown()  # type: ignore
    # Logger la valeur de filling_mode
    filling_mode_val = getattr(info, 'filling_mode', 'N/A')
    retcode = getattr(result, 'retcode', None)
    comment = getattr(result, 'comment', '')
    return False, (
        f"Erreur MT5. Code: {retcode} - {comment}\n"
        f"Aucun filling mode n'a fonctionné (bitmask: {filling_mode_val}).\n"
        f"Essayé: {', '.join(tried + tried_brute)}.\n"
        f"Vérifie la spécification du symbole dans MT5 ou contacte ton broker."
    )

def close_order_mt5(symbol):
    ok, msg = connect_mt5()
    if not ok:
        return False, msg
    positions = mt5.positions_get(symbol=symbol)  # type: ignore
    if not positions:
        mt5.shutdown()  # type: ignore
        return False, f"Aucune position ouverte sur {symbol}."
    results = []
    for pos in positions:
        volume = pos.volume
        price = pos.price_current
        if pos.type == mt5.POSITION_TYPE_BUY:  # type: ignore
            order_type = mt5.ORDER_TYPE_SELL  # type: ignore
        else:
            order_type = mt5.ORDER_TYPE_BUY  # type: ignore
        info = mt5.symbol_info(pos.symbol)  # type: ignore
        tried = []
        filling = None
        if info and info.filling_mode & mt5.ORDER_FILLING_FOK:  # type: ignore
            filling = mt5.ORDER_FILLING_FOK  # type: ignore
            tried.append("FOK (bitmask)")
        elif info and info.filling_mode & mt5.ORDER_FILLING_IOC:  # type: ignore
            filling = mt5.ORDER_FILLING_IOC  # type: ignore
            tried.append("IOC (bitmask)")
        elif info and info.filling_mode & mt5.ORDER_FILLING_RETURN:  # type: ignore
            filling = mt5.ORDER_FILLING_RETURN  # type: ignore
            tried.append("RETURN (bitmask)")
        filling_modes = [
            (mt5.ORDER_FILLING_FOK, "FOK"),
            (mt5.ORDER_FILLING_IOC, "IOC"),
            (mt5.ORDER_FILLING_RETURN, "RETURN")
        ]
        tried_brute = []
        def try_send(filling_mode, label):
            request = {
                "action": mt5.TRADE_ACTION_DEAL,  # type: ignore
                "symbol": pos.symbol,
                "volume": volume,
                "type": order_type,
                "position": pos.ticket,
                "price": price,
                "deviation": 20,
                "magic": 123456,
                "comment": "Clôture WhatsApp",
                "type_time": mt5.ORDER_TIME_GTC,  # type: ignore
                "type_filling": filling_mode,
            }
            result = mt5.order_send(request)  # type: ignore
            return result
        result = None
        if filling is not None:
            result = try_send(filling, tried[-1])
            if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:  # type: ignore
                results.append(f"Position {pos.symbol} clôturée. (mode: {tried[-1]})")
                continue
            else:
                tried_brute.append(f"{tried[-1]} (échec)")
        for mode, label in filling_modes:
            if filling is not None and mode == filling:
                continue
            result = try_send(mode, label)
            if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:  # type: ignore
                results.append(f"Position {pos.symbol} clôturée. (mode: {label} - brute force)")
                break
            else:
                tried_brute.append(f"{label} (échec)")
        else:
            filling_mode_val = getattr(info, 'filling_mode', 'N/A')
            retcode = getattr(result, 'retcode', None)
            comment = getattr(result, 'comment', '')
            results.append(
                f"Erreur clôture {pos.symbol}. Code: {retcode} - {comment}\n"
                f"Aucun filling mode n'a fonctionné (bitmask: {filling_mode_val}).\n"
                f"Essayé: {', '.join(tried + tried_brute)}.\n"
                f"Vérifie la spécification du symbole dans MT5 ou contacte ton broker."
            )
    mt5.shutdown()  # type: ignore
    return True, "\n".join(results)

def close_all_mt5():
    ok, msg = connect_mt5()
    if not ok:
        return False, msg
    positions = mt5.positions_get()  # type: ignore
    if not positions:
        mt5.shutdown()  # type: ignore
        return False, "Aucune position ouverte."
    results = []
    for pos in positions:
        symbol = pos.symbol
        volume = pos.volume
        price = pos.price_current
        if pos.type == mt5.POSITION_TYPE_BUY:  # type: ignore
            order_type = mt5.ORDER_TYPE_SELL  # type: ignore
        else:
            order_type = mt5.ORDER_TYPE_BUY  # type: ignore
        info = mt5.symbol_info(pos.symbol)  # type: ignore
        # --- Sélection dynamique du filling mode ---
        filling = None
        if info and info.filling_mode & mt5.ORDER_FILLING_FOK:  # type: ignore
            filling = mt5.ORDER_FILLING_FOK  # type: ignore
        elif info and info.filling_mode & mt5.ORDER_FILLING_IOC:  # type: ignore
            filling = mt5.ORDER_FILLING_IOC  # type: ignore
        elif info and info.filling_mode & mt5.ORDER_FILLING_RETURN:  # type: ignore
            filling = mt5.ORDER_FILLING_RETURN  # type: ignore
        if filling is None:
            results.append(f"Aucun filling mode supporté pour {pos.symbol}. Impossible de clôturer.")
            continue
        request = {
            "action": mt5.TRADE_ACTION_DEAL,  # type: ignore
            "symbol": symbol,
            "volume": volume,
            "type": order_type,
            "position": pos.ticket,
            "price": price,
            "deviation": 20,
            "magic": 123456,
            "comment": "Clôture WhatsApp",
            "type_time": mt5.ORDER_TIME_GTC,  # type: ignore
            "type_filling": filling,
        }
        result = mt5.order_send(request)  # type: ignore
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:  # type: ignore
            results.append(f"Position {symbol} clôturée.")
        else:
            retcode = getattr(result, 'retcode', None)
            comment = getattr(result, 'comment', '')
            results.append(f"Erreur clôture {symbol}. Code: {retcode} - {comment}")
    mt5.shutdown()  # type: ignore
    return True, "\n".join(results)

def modify_order_mt5(symbol, sl=None, tp=None):
    ok, msg = connect_mt5()
    if not ok:
        return False, msg
    positions = mt5.positions_get(symbol=symbol)  # type: ignore
    if not positions:
        mt5.shutdown()  # type: ignore
        return False, f"Aucune position ouverte sur {symbol}."
    results = []
    for pos in positions:
        request = {
            "action": mt5.TRADE_ACTION_SLTP,  # type: ignore
            "position": pos.ticket,
            "sl": sl if sl else pos.sl,
            "tp": tp if tp else pos.tp,
        }
        result = mt5.order_send(request)  # type: ignore
        if result and hasattr(result, 'retcode') and result.retcode == mt5.TRADE_RETCODE_DONE:  # type: ignore
            results.append(f"SL/TP modifiés pour {symbol}.")
        else:
            retcode = getattr(result, 'retcode', None)
            comment = getattr(result, 'comment', '')
            results.append(f"Erreur modification {symbol}. Code: {retcode} - {comment}")
    mt5.shutdown()  # type: ignore
    return True, "\n".join(results) 