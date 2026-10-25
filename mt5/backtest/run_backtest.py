#!/usr/bin/env python3
"""
Script de backtest automatique pour TradBOT
Utilise l'API MetaTrader 5 pour lancer des backtests sur plusieurs actifs
"""

import MetaTrader5 as mt5
import pandas as pd
import subprocess
import os
import shutil
from datetime import datetime
from pathlib import Path

# Configuration
MT5_TERMINAL_PATH = r"C:\Program Files\MetaTrader 5\terminal64.exe"
MT5_CONFIG_PATH = r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066"
EA_PATH = r"D:\Dev\TradBOT\mt5\SMC_Universal.mq5"
BACKTEST_DIR = r"D:\Dev\TradBOT\mt5\backtest"
HISTORY_DIR = r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066\MQL5\Files\Synthetic_History_Export"

# Paramètres par défaut
DEFAULT_PARAMS = {
    "InpMagicNumber": 123456,
    "UseGOMVerdictFilter": True,
    "MinGOMVerdictNumAbs": 2,
    "RequireGoodPerfectAlways": True,
    "BlockEntryWhenAIHold": False,
    "MaxLossPerTradeDollars": 2.5,
    "GeneralGiveBackMaxPct": 25.0,
    "GeneralGiveBackMinPeakUSD": 0.40,
    "FirstSpikeGiveBackMaxPct": 25.0,
    "FirstSpikeGiveBackMinPeakUSD": 0.25,
    "UseSecondSpikeCapture": True,
    "SpikeCloseMinProfitUSD": 0.25,
    "SpikeCloseKeepPct": 75.0,
    "UseStagnationTimeExit": True,
    "StagnationMaxAgeMinutes": 4,
}

# Paramètres spécifiques par actif
SYMBOL_PARAMS = {
    "GainX_400": DEFAULT_PARAMS,
    "GainX_600": DEFAULT_PARAMS,
    "GainX_800": DEFAULT_PARAMS,
    "PainX_400": DEFAULT_PARAMS,
    "PainX_600": DEFAULT_PARAMS,
    "PainX_800": DEFAULT_PARAMS,
    "PainX_999": {
        **DEFAULT_PARAMS,
        "MaxLossPerTradeDollars": 3.0,
        "GeneralGiveBackMaxPct": 30.0,
        "GeneralGiveBackMinPeakUSD": 0.50,
        "FirstSpikeGiveBackMaxPct": 30.0,
        "FirstSpikeGiveBackMinPeakUSD": 0.30,
        "SpikeCloseMinProfitUSD": 0.30,
        "SpikeCloseKeepPct": 70.0,
        "StagnationMaxAgeMinutes": 5,
    },
    "FlipX_1": {
        **DEFAULT_PARAMS,
        "MaxLossPerTradeDollars": 2.0,
        "GeneralGiveBackMaxPct": 30.0,
        "GeneralGiveBackMinPeakUSD": 0.50,
        "FirstSpikeGiveBackMaxPct": 30.0,
        "FirstSpikeGiveBackMinPeakUSD": 0.30,
        "SpikeCloseMinProfitUSD": 0.30,
        "SpikeCloseKeepPct": 70.0,
        "StagnationMaxAgeMinutes": 5,
    },
    "FlipX_2": {
        **DEFAULT_PARAMS,
        "MaxLossPerTradeDollars": 2.0,
        "GeneralGiveBackMaxPct": 30.0,
        "GeneralGiveBackMinPeakUSD": 0.50,
        "FirstSpikeGiveBackMaxPct": 30.0,
        "FirstSpikeGiveBackMinPeakUSD": 0.30,
        "SpikeCloseMinProfitUSD": 0.30,
        "SpikeCloseKeepPct": 70.0,
        "StagnationMaxAgeMinutes": 5,
    },
    "FlipX_3": {
        **DEFAULT_PARAMS,
        "MaxLossPerTradeDollars": 2.0,
        "GeneralGiveBackMaxPct": 30.0,
        "GeneralGiveBackMinPeakUSD": 0.50,
        "FirstSpikeGiveBackMaxPct": 30.0,
        "FirstSpikeGiveBackMinPeakUSD": 0.30,
        "SpikeCloseMinProfitUSD": 0.30,
        "SpikeCloseKeepPct": 70.0,
        "StagnationMaxAgeMinutes": 5,
    },
    "FlipX_4": {
        **DEFAULT_PARAMS,
        "MaxLossPerTradeDollars": 2.0,
        "GeneralGiveBackMaxPct": 30.0,
        "GeneralGiveBackMinPeakUSD": 0.50,
        "FirstSpikeGiveBackMaxPct": 30.0,
        "FirstSpikeGiveBackMinPeakUSD": 0.30,
        "SpikeCloseMinProfitUSD": 0.30,
        "SpikeCloseKeepPct": 70.0,
        "StagnationMaxAgeMinutes": 5,
    },
    "FlipX_5": {
        **DEFAULT_PARAMS,
        "MaxLossPerTradeDollars": 2.0,
        "GeneralGiveBackMaxPct": 30.0,
        "GeneralGiveBackMinPeakUSD": 0.50,
        "FirstSpikeGiveBackMaxPct": 30.0,
        "FirstSpikeGiveBackMinPeakUSD": 0.30,
        "SpikeCloseMinProfitUSD": 0.30,
        "SpikeCloseKeepPct": 70.0,
        "StagnationMaxAgeMinutes": 5,
    },
}


def check_history_files(symbol):
    """Vérifie si les fichiers historiques existent pour le symbole"""
    history_path = Path(HISTORY_DIR)
    required_files = [f"{symbol}_M1.csv", f"{symbol}_M5.csv"]
    
    for file in required_files:
        if not (history_path / file).exists():
            print(f"❌ Fichier manquant: {file}")
            return False
    print(f"✅ Fichiers historiques OK pour {symbol}")
    return True


def copy_history_to_mt5(symbol):
    """Copie les fichiers historiques vers MT5"""
    history_path = Path(HISTORY_DIR)
    mt5_files_path = Path(MT5_CONFIG_PATH) / "MQL5" / "Files"
    
    # Créer le dossier si nécessaire
    mt5_files_path.mkdir(parents=True, exist_ok=True)
    
    # Copier les fichiers CSV
    for file in history_path.glob(f"{symbol}_*.csv"):
        dest = mt5_files_path / file.name
        shutil.copy2(file, dest)
        print(f"📋 Copié: {file.name}")
    
    return True


def run_backtest(symbol, params, start_date, end_date):
    """
    Lance un backtest pour un symbole donné
    
    Note: Cette fonction nécessite l'installation de MT5 et l'EA compilé
    Pour l'instant, c'est un template - l'implémentation complète nécessite
    soit l'API MT5 Python, soit l'automatisation du Strategy Tester
    """
    print(f"\n{'='*60}")
    print(f"🚀 Backtest: {symbol}")
    print(f"{'='*60}")
    print(f"📅 Période: {start_date} à {end_date}")
    print(f"⚙️  Paramètres:")
    for key, value in params.items():
        print(f"   {key}: {value}")
    
    # Vérifier les fichiers historiques
    if not check_history_files(symbol):
        print(f"⚠️  Fichiers historiques manquants pour {symbol}")
        return False
    
    # Copier les fichiers vers MT5
    copy_history_to_mt5(symbol)
    
    # TODO: Implémenter le lancement du backtest
    # Options:
    # 1. Utiliser MetaTrader5.tester() (si disponible)
    # 2. Automatiser le Strategy Tester via subprocess
    # 3. Utiliser une librairie tierce comme mt5-backtest
    
    print(f"\n⚠️  Lancement du backtest nécessite:")
    print(f"   1. Compilation de SMC_Universal.mq5 dans MetaEditor")
    print(f"   2. Configuration manuelle dans Strategy Tester")
    print(f"   3. Ou implémentation complète de l'API MT5 Python")
    
    return True


def main():
    """Fonction principale"""
    print("🎯 TradBOT Backtest Automator")
    print("=" * 60)
    
    # Initialiser MT5
    if not mt5.initialize():
        print(f"❌ Échec initialisation MT5: {mt5.last_error()}")
        return
    
    print("✅ MT5 initialisé")
    
    # Lister les symboles à tester
    symbols_to_test = [
        "GainX_400",
        "GainX_600",
        "GainX_800",
        "PainX_400",
        "PainX_600",
        "PainX_800",
        "PainX_999",
        "FlipX_1",
        "FlipX_2",
        "FlipX_3",
        "FlipX_4",
        "FlipX_5",
    ]
    
    # Période de backtest (à ajuster selon vos données)
    start_date = "2024-01-01"
    end_date = "2024-12-31"
    
    # Lancer les backtests
    results = {}
    for symbol in symbols_to_test:
        params = SYMBOL_PARAMS.get(symbol, DEFAULT_PARAMS)
        success = run_backtest(symbol, params, start_date, end_date)
        results[symbol] = success
    
    # Résumé
    print(f"\n{'='*60}")
    print("📊 RÉSUMÉ")
    print(f"{'='*60}")
    for symbol, success in results.items():
        status = "✅" if success else "❌"
        print(f"{status} {symbol}")
    
    # Fermer MT5
    mt5.shutdown()
    print("\n✅ MT5 fermé")


if __name__ == "__main__":
    main()
