#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Lecteur de fichier deals_2026.05.dat de MetaTrader 5
Décode les deals/ordres en attente
"""

import struct
import sys
import io
from datetime import datetime
from pathlib import Path

# Fix Windows encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def read_mt5_deals(file_path):
    """
    Lit le fichier binaire deals de MT5.

    Structure approximative d'un deal MT5:
    - Deal ticket (8 bytes, long long)
    - Order ticket (8 bytes, long long)
    - Time (8 bytes, long long) - timestamp Unix
    - Type (4 bytes, int)
    - Entry (4 bytes, int)
    - Magic (8 bytes, long long)
    - Position ID (8 bytes, long long)
    - Volume (8 bytes, double)
    - Price (8 bytes, double)
    - Commission (8 bytes, double)
    - Swap (8 bytes, double)
    - Profit (8 bytes, double)
    - Symbol (variable length string)
    - Comment (variable length string)
    """

    print("=" * 80)
    print("📊 LECTURE FICHIER MT5 DEALS")
    print("=" * 80)
    print(f"Fichier: {file_path}")
    print()

    try:
        with open(file_path, 'rb') as f:
            data = f.read()

        print(f"Taille fichier: {len(data):,} bytes")
        print()

        # Essayer de trouver des patterns
        print("🔍 RECHERCHE PATTERNS XAUUSD...")
        print()

        # Chercher "XAUUSD" dans les données
        xauusd_positions = []
        search_bytes = b'XAUUSD'
        pos = 0
        while True:
            pos = data.find(search_bytes, pos)
            if pos == -1:
                break
            xauusd_positions.append(pos)
            pos += 1

        print(f"Trouvé {len(xauusd_positions)} occurrences de 'XAUUSD'")
        print()

        if not xauusd_positions:
            print("❌ Aucun trade XAUUSD trouvé dans le fichier")
            return

        # Analyser chaque occurrence
        print("📋 DEALS XAUUSD:")
        print("-" * 80)

        for idx, pos in enumerate(xauusd_positions[-10:], 1):  # Derniers 10 trades
            try:
                # Essayer de lire les données autour du symbole
                start = max(0, pos - 100)
                end = min(len(data), pos + 100)
                chunk = data[start:end]

                print(f"\nDeal #{idx} (Position dans fichier: {pos}):")
                print(f"  Symbole: XAUUSD")

                # Essayer de décoder des doubles (prix) autour du symbole
                # Rechercher dans les 50 bytes avant le symbole
                before_symbol = data[max(0, pos-50):pos]

                # Essayer de lire des doubles (8 bytes)
                doubles = []
                for i in range(0, len(before_symbol)-8, 8):
                    try:
                        val = struct.unpack('<d', before_symbol[i:i+8])[0]
                        # Filtrer les valeurs qui ressemblent à des prix XAUUSD (2000-5000)
                        if 2000 < val < 6000:
                            doubles.append(val)
                    except:
                        pass

                if doubles:
                    print(f"  Prix potentiels: {', '.join([f'${v:.2f}' for v in doubles[-3:]])}")

                # Essayer de lire des timestamps (8 bytes, Unix timestamp)
                timestamps = []
                for i in range(0, len(before_symbol)-8, 8):
                    try:
                        ts = struct.unpack('<Q', before_symbol[i:i+8])[0]
                        # Filtrer les timestamps valides (2020-2030)
                        if 1577836800 < ts < 1893456000:  # 2020-01-01 to 2030-01-01
                            timestamps.append(ts)
                    except:
                        pass

                if timestamps:
                    for ts in timestamps[-2:]:
                        dt = datetime.fromtimestamp(ts)
                        print(f"  Date: {dt.strftime('%Y-%m-%d %H:%M:%S')}")

                # Afficher quelques bytes en hex pour debug
                print(f"  Context (hex): {chunk[90:110].hex()}")

            except Exception as e:
                print(f"  Erreur lecture: {e}")

        print()
        print("=" * 80)
        print("ℹ️  NOTE: Format binaire MT5 propriétaire - décodage partiel")
        print("   Pour voir tous les détails, utilisez MT5 → Toolbox → Trade → Save Report")
        print("=" * 80)

    except Exception as e:
        print(f"❌ Erreur: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    deals_file = r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\bases\Deriv-Demo\trades\5775742\deals_2026.05.dat"

    if not Path(deals_file).exists():
        print(f"❌ Fichier introuvable: {deals_file}")
        sys.exit(1)

    read_mt5_deals(deals_file)
