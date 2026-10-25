#!/usr/bin/env python3
"""
Script de test pour ajouter des trades factices à la base ML
"""

import sqlite3
import random
from datetime import datetime, timedelta
import json

# Connexion à la base de données
DB_PATH = "D:/Dev/TradBOT/data/trades.db"

def create_test_trades():
    """Créer des trades de test pour valider le système ML"""

    # Symboles de test variés
    symbols = [
        ("EURUSD", "forex", 0.0001),
        ("GBPUSD", "forex", 0.0001),
        ("USDJPY", "forex", 0.001),
        ("BOOM1000", "volatility", 0.001),
        ("CRASH500", "volatility", 0.001),
        ("PAINX", "volatility", 0.001),
        ("GAINX", "volatility", 0.001),
        ("XAUUSD", "commodities", 0.01),
        ("XAGUSD", "commodities", 0.001),
        ("BTCUSD", "crypto", 0.1)
    ]

    # Directions possibles
    directions = ["BUY", "SELL"]

    # Résultats possibles
    results = ["WIN", "LOSS", "BREAK_EVEN"]

    # Connexion à la base
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Vérifier la structure de la table
    cursor.execute("PRAGMA table_info(trades)")
    columns = [info[1] for info in cursor.fetchall()]
    print("Colonnes disponibles dans la table trades:", columns)

    # Nombre de trades de test à créer
    num_trades = 15

    # Date de base (il y a 3 jours)
    base_date = datetime.now() - timedelta(days=3)

    inserted_count = 0

    for i in range(num_trades):
        # Sélection aléatoire des paramètres
        symbol_info = random.choice(symbols)
        symbol, category, point_size = symbol_info
        direction = random.choice(directions)

        # Générer des prix réalistes selon le symbole
        if "JPY" in symbol:
            base_price = random.uniform(100, 150)  # Pour JPY
        elif symbol in ["XAUUSD", "GOLD"]:
            base_price = random.uniform(1800, 2000)  # Pour l'or
        elif symbol in ["BTCUSD", "BITCOIN"]:
            base_price = random.uniform(25000, 35000)  # Pour Bitcoin
        else:
            base_price = random.uniform(1.0, 2.0)  # Pour les paires forex standards

        # Calculer le mouvement de prix
        if direction == "BUY":
            # Pour un BUY gagnant, le prix de clôture > prix d'ouverture
            price_change = random.uniform(-0.005, 0.015) * base_price  # -0.5% à +1.5%
        else:  # SELL
            price_change = random.uniform(-0.015, 0.005) * base_price  # -1.5% à +0.5%

        open_price = base_price
        close_price = open_price + price_change

        # Calculer le résultat basé sur le mouvement
        if direction == "BUY":
            if price_change > 0.001 * base_price:  # Mouvement significatif à la hausse
                result = "WIN"
            elif price_change < -0.001 * base_price:  # Mouvement significatif à la baisse
                result = "LOSS"
            else:
                result = "BREAK_EVEN"
        else:  # SELL
            if price_change < -0.001 * base_price:  # Mouvement significatif à la baisse
                result = "WIN"
            elif price_change > 0.001 * base_price:  # Mouvement significatif à la hausse
                result = "LOSS"
            else:
                result = "BREAK_EVEN"

        # Volume réaliste
        volume = round(random.uniform(0.01, 5.0), 2)

        # Temps
        open_time = base_date + timedelta(hours=random.randint(0, 23), minutes=random.randint(0, 59))
        close_time = open_time + timedelta(minutes=random.randint(5, 120))  # Trades de 5 min à 2h

        # Calculer le profit en pips
        profit_pips = (close_price - open_price) / point_size if direction == "BUY" else (open_price - close_price) / point_size
        profit = profit_pips * point_size * volume * 10000  # Approximation simplifiée

        # Autres champs
        swap = random.uniform(-0.5, 0.5)
        commission = round(volume * 0.0002, 2)  # 0.02% de commission
        net_profit = profit - swap - commission

        duration_sec = int((close_time - open_time).total_seconds())
        duration_min = duration_sec / 60.0

        # Champs IA/GOM (valeurs factices mais réalistes)
        ai_confidence = round(random.uniform(0.4, 0.95), 2)
        ai_action = direction if random.random() > 0.3 else ("BUY" if direction == "SELL" else "SELL")  # 30% d'erreur IA

        balance = random.uniform(9000, 11000)
        equity = balance + net_profit
        daily_pnl = random.uniform(-50, 50)

        ea_name = "SMC_Universal"
        magic = 123456
        account = random.choice([140398483, 140398484, 140398485])
        comment = "Test trade #" + str(i+1)

        # Insérer dans la base de données
        try:
            cursor.execute("""
                INSERT OR IGNORE INTO trades (
                    deal_ticket, close_time, trade_date, hour_utc, day_of_week,
                    position_id, symbol, category, direction, volume,
                    open_time, open_price, close_price, profit, swap, commission,
                    net_profit, duration_sec, duration_min, result,
                    ai_confidence, ai_action, balance, equity, daily_pnl,
                    ea_name, magic, account, comment, imported_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                1000000 + i,  # deal_ticket unique
                close_time.isoformat(),
                close_time.date().isoformat(),
                close_time.hour,
                close_time.strftime("%A"),
                i + 1,  # position_id
                symbol,
                category,
                direction,
                volume,
                open_time.isoformat(),
                open_price,
                close_price,
                profit,
                swap,
                commission,
                net_profit,
                duration_sec,
                duration_min,
                result,
                ai_confidence,
                ai_action,
                balance,
                equity,
                daily_pnl,
                ea_name,
                magic,
                account,
                comment,
                datetime.now().isoformat(),
                result,  # ml_result même que result pour le test
                datetime.now().isoformat()
            ))

            if cursor.rowcount > 0:
                inserted_count += 1
                print("Trade {} ajoute: {} {} {} lots @ {:.5f} -> {:.5f} ({})".format(
                    i+1, symbol, direction, volume, open_price, close_price, result))
            else:
                print("Trade {} deja present (deal_ticket duplication)".format(i+1))

        except Exception as e:
            print("Erreur lors de l'insertion du trade {}: {}".format(i+1, e))

    conn.commit()
    conn.close()

    print("\n{} nouveaux trades de test ajoutes a la base de donnees".format(inserted_count))
    return inserted_count

def verify_trades():
    """Verifier les trades ajoutes"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM trades WHERE comment LIKE 'Test trade%'")
    count = cursor.fetchone()[0]

    cursor.execute("""
        SELECT symbol, direction, result, ai_confidence
        FROM trades
        WHERE comment LIKE 'Test trade%'
        ORDER BY deal_ticket DESC
        LIMIT 5
    """)
    recent_trades = cursor.fetchall()

    conn.close()

    print("\nVerification: {} trades de test presents dans la base".format(count))
    print("Derniers 5 trades ajoutes:")
    for trade in recent_trades:
        print("  {} {} -> {} (IA conf: {})".format(trade[0], trade[1], trade[2], trade[3]))

    return count

if __name__ == '__main__':
    print("Generation de trades de test pour le systeme ML...")
    print("=" * 50)

    # Creer les trades de test
    nb_trades = create_test_trades()

    # Verifier
    verify_trades()

    print("\n" + "=" * 50)
    print("Test termine! Vous pouvez maintenant:")
    print("1. Executer le processeur de trades pour traiter ces donnees")
    print("2. Ou lancer directement l'ajout ML avec: python python/add_trade_to_ml.py --deal-ticket <ID> --result WIN")
    print("3. Ou attendre l'entrainement automatique quotidien")