import MetaTrader5 as mt5
import os
from dotenv import load_dotenv

load_dotenv()
login = int(os.getenv('MT5_LOGIN', '0'))
password = os.getenv('MT5_PASSWORD', '')
server = os.getenv('MT5_SERVER', '')
path = os.getenv('MT5_PATH', None)

print("Initialisation MT5...")
if not mt5.initialize(path=path if path else None):
    print("Erreur d'initialisation MT5")
    quit()

print("Login...")
if not mt5.login(login, password=password, server=server):
    print("Erreur de login MT5")
    mt5.shutdown()
    quit()

account_info = mt5.account_info()
print("Compte connecté :", account_info.login if account_info else "Aucun")

positions = mt5.positions_get()
if positions:
    print(f"{len(positions)} position(s) ouverte(s) :")
    for pos in positions:
        print(f"Ticket: {pos.ticket}, Symbole: {pos.symbol}, Type: {'BUY' if pos.type==0 else 'SELL'}, Volume: {pos.volume}, Prix: {pos.price_open}")
else:
    print("Aucune position ouverte détectée.")

mt5.shutdown()