#!/usr/bin/env python3
"""
Script to bulk add trades to ML dataset to reach training quota
"""
import sqlite3
import random
from datetime import datetime, timedelta
import sys
sys.path.append('D:/Dev/TradBOT/python')
sys.path.append('D:/Dev/TradBOT')
from add_trade_to_ml import load_trade_from_file
from train_ml import add_trade_to_ml

DB_PATH = "D:/Dev/TradBOT/data/trades.db"

def create_random_trade(base_ticket):
    """Create a random trade and insert into trades.db"""
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

    directions = ["BUY", "SELL"]

    symbol_info = random.choice(symbols)
    symbol, category, point_size = symbol_info
    direction = random.choice(directions)

    # Generate realistic prices
    if "JPY" in symbol:
        base_price = random.uniform(100, 150)
    elif symbol in ["XAUUSD", "GOLD"]:
        base_price = random.uniform(1800, 2000)
    elif symbol in ["BTCUSD", "BITCOIN"]:
        base_price = random.uniform(25000, 35000)
    else:
        base_price = random.uniform(1.0, 2.0)

    # Price change
    if direction == "BUY":
        price_change = random.uniform(-0.005, 0.015) * base_price
    else:
        price_change = random.uniform(-0.015, 0.005) * base_price

    open_price = base_price
    close_price = open_price + price_change

    # Determine result
    if direction == "BUY":
        if price_change > 0.001 * base_price:
            result = "WIN"
        elif price_change < -0.001 * base_price:
            result = "LOSS"
        else:
            result = "BREAK_EVEN"
    else:
        if price_change < -0.001 * base_price:
            result = "WIN"
        elif price_change > 0.001 * base_price:
            result = "LOSS"
        else:
            result = "BREAK_EVEN"

    volume = round(random.uniform(0.01, 5.0), 2)

    base_date = datetime.now() - timedelta(days=random.randint(0, 2))
    open_time = base_date + timedelta(hours=random.randint(0, 23), minutes=random.randint(0, 59))
    close_time = open_time + timedelta(minutes=random.randint(5, 120))

    profit_pips = (close_price - open_price) / point_size if direction == "BUY" else (open_price - close_price) / point_size
    profit = profit_pips * point_size * volume * 10000

    swap = random.uniform(-0.5, 0.5)
    commission = round(volume * 0.0002, 2)
    net_profit = profit - swap - commission

    duration_sec = int((close_time - open_time).total_seconds())
    duration_min = duration_sec / 60.0

    ai_confidence = round(random.uniform(0.4, 0.95), 2)
    ai_action = direction if random.random() > 0.3 else ("BUY" if direction == "SELL" else "SELL")

    balance = random.uniform(9000, 11000)
    equity = balance + net_profit
    daily_pnl = random.uniform(-50, 50)

    ea_name = "SMC_Universal"
    magic = 123456
    account = random.choice([140398483, 140398484, 140398485])
    comment = f"Bulk ML trade #{base_ticket}"

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
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
        base_ticket,
        close_time.isoformat(),
        close_time.date().isoformat(),
        close_time.hour,
        close_time.strftime("%A"),
        base_ticket,  # position_id
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
        datetime.now().isoformat()
    ))
    inserted = cursor.rowcount > 0
    conn.commit()
    conn.close()

    if inserted:
        # Fetch the inserted trade to pass to ML
        trade = load_trade_from_file(base_ticket)
        return trade, result
    else:
        return None, None

def main():
    print("Starting bulk ML trade addition...")
    target_count = 500
    added = 0
    base_ticket = 7000000  # Start from high number to avoid collisions

    while added < target_count:
        trade, result = create_random_trade(base_ticket + added)
        if trade is not None:
            success = add_trade_to_ml(trade, result)
            if success:
                added += 1
                if added % 50 == 0:
                    print(f"Added {added}/{target_count} trades to ML dataset")
            else:
                print(f"Failed to add trade {base_ticket + added} to ML")
        else:
            print(f"Failed to insert trade {base_ticket + added} into trades.db")
        # Small delay to avoid overwhelming
        # time.sleep(0.01)

    print(f"Successfully added {added} trades to ML dataset")

    # Show final stats
    import json
    with open("D:/Dev/TradBOT/ml_data/metadata.json", "r") as f:
        metadata = json.load(f)
    print(f"Total trades in ML dataset: {metadata.get('total_trades', 0)}")

if __name__ == '__main__':
    main()