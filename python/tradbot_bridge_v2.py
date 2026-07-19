"""
TradBOT Bridge V2 - Enhanced with multi-language, report types, and account sizes

NOUVELLES FONCTIONNALITÉS:
- Choix de langue (FR, EN, ES, AR)
- Type de rapport (Résumé 5 pages / Complet sans limite)
- Signal de trade adapté au budget (10$, 50$, 200$+)
- Envoi automatique WhatsApp après sauvegarde
- Design Word amélioré

LANCEMENT:
  .\bridge.bat --wizard    # Mode interactif complet avec tous les choix
  .\bridge.bat --symbol XAUUSD --lang FR --report-type summary --account 50
"""

import sys
import os
from pathlib import Path

# Importer le bridge original
_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

# Import du bridge original pour réutiliser ses fonctions
from tradbot_bridge import *  # noqa: F403, F401

# Nouvelles constantes
SUPPORTED_LANGUAGES = {
    "FR": "Français",
    "EN": "English",
    "ES": "Español",
    "AR": "العربية"
}

ACCOUNT_SIZES = {
    "small": {"label": "Petit compte (10$)", "capital": 10, "risk_pct": 2},
    "medium": {"label": "Compte moyen (50$)", "capital": 50, "risk_pct": 2},
    "large": {"label": "Grand compte (200$+)", "capital": 200, "risk_pct": 1.5}
}

REPORT_TYPES = {
    "summary": {"label": "Résumé (5 pages)", "max_pages": 5},
    "full": {"label": "Complet (sans limite)", "max_pages": None}
}

# Traductions
TRANSLATIONS = {
    "FR": {
        "title": "Rapport d'Analyse",
        "date": "Date d'analyse",
        "generated": "Généré le",
        "signal": "Signal TradingAgents",
        "decision": "Décision",
        "current_price": "Prix actuel",
        "atr": "ATR (volatilité)",
        "signals_title": "Signaux de Trading Proposés",
        "signal_num": "Signal",
        "order_type": "Type d'ordre",
        "direction": "Direction",
        "entry": "Prix d'entrée",
        "stop_loss": "Stop Loss",
        "take_profit": "Take Profit",
        "risk_reward": "Ratio R/R",
        "risk": "de risque",
        "gain": "de gain",
        "account_size": "Taille de compte",
        "lot_size": "Taille de position",
        "risk_amount": "Risque",
        "analysis": "Analyse Détaillée",
        "conclusion": "Conclusion",
    },
    "EN": {
        "title": "Analysis Report",
        "date": "Analysis date",
        "generated": "Generated on",
        "signal": "TradingAgents Signal",
        "decision": "Decision",
        "current_price": "Current price",
        "atr": "ATR (volatility)",
        "signals_title": "Proposed Trading Signals",
        "signal_num": "Signal",
        "order_type": "Order type",
        "direction": "Direction",
        "entry": "Entry price",
        "stop_loss": "Stop Loss",
        "take_profit": "Take Profit",
        "risk_reward": "R/R Ratio",
        "risk": "risk",
        "gain": "gain",
        "account_size": "Account size",
        "lot_size": "Position size",
        "risk_amount": "Risk",
        "analysis": "Detailed Analysis",
        "conclusion": "Conclusion",
    },
    "ES": {
        "title": "Informe de Análisis",
        "date": "Fecha de análisis",
        "generated": "Generado el",
        "signal": "Señal TradingAgents",
        "decision": "Decisión",
        "current_price": "Precio actual",
        "atr": "ATR (volatilidad)",
        "signals_title": "Señales de Trading Propuestas",
        "signal_num": "Señal",
        "order_type": "Tipo de orden",
        "direction": "Dirección",
        "entry": "Precio de entrada",
        "stop_loss": "Stop Loss",
        "take_profit": "Take Profit",
        "risk_reward": "Ratio R/R",
        "risk": "de riesgo",
        "gain": "de ganancia",
        "account_size": "Tamaño de cuenta",
        "lot_size": "Tamaño de posición",
        "risk_amount": "Riesgo",
        "analysis": "Análisis Detallado",
        "conclusion": "Conclusión",
    },
    "AR": {
        "title": "تقرير التحليل",
        "date": "تاريخ التحليل",
        "generated": "تم إنشاؤه في",
        "signal": "إشارة TradingAgents",
        "decision": "القرار",
        "current_price": "السعر الحالي",
        "atr": "ATR (التقلب)",
        "signals_title": "إشارات التداول المقترحة",
        "signal_num": "إشارة",
        "order_type": "نوع الأمر",
        "direction": "الاتجاه",
        "entry": "سعر الدخول",
        "stop_loss": "وقف الخسارة",
        "take_profit": "جني الأرباح",
        "risk_reward": "نسبة المخاطرة/العائد",
        "risk": "مخاطرة",
        "gain": "ربح",
        "account_size": "حجم الحساب",
        "lot_size": "حجم الصفقة",
        "risk_amount": "المخاطرة",
        "analysis": "التحليل التفصيلي",
        "conclusion": "الخلاصة",
    }
}


def calculate_lot_size_for_account(entry_price: float, stop_loss: float,
                                   account_size: str, symbol: str) -> dict:
    """
    Calcule la taille de lot optimale selon la taille du compte.

    Returns:
        dict avec lot, risk_usd, risk_pct
    """
    acc = ACCOUNT_SIZES[account_size]
    capital = acc["capital"]
    risk_pct = acc["risk_pct"]
    risk_usd = capital * (risk_pct / 100)

    # Calculer la distance SL en pips
    pip_size = 0.0001
    if "JPY" in symbol:
        pip_size = 0.01
    elif "XAU" in symbol or "GOLD" in symbol:
        pip_size = 0.1

    sl_distance_pips = abs(entry_price - stop_loss) / pip_size

    # Valeur du pip par lot standard
    pip_value_per_lot = 10  # USD pour la plupart des paires
    if "XAU" in symbol or "GOLD" in symbol:
        pip_value_per_lot = 1  # 1$ par 0.01 lot pour l'or

    # Calculer lot size
    lot_size = risk_usd / (sl_distance_pips * pip_value_per_lot)

    # Limites MT5
    min_lot = 0.01
    max_lot = capital / 1000  # Levier approximatif
    lot_size = max(min_lot, min(lot_size, max_lot))
    lot_size = round(lot_size / 0.01) * 0.01  # Arrondir à 0.01

    return {
        "lot": lot_size,
        "risk_usd": risk_usd,
        "risk_pct": risk_pct,
        "capital": capital
    }


def select_preferences_interactive() -> dict:
    """
    Wizard interactif pour sélectionner langue, type de rapport et taille de compte.
    """
    print("\n" + "="*60)
    print("  CONFIGURATION DU RAPPORT")
    print("="*60)

    # Langue
    print("\n📝 Langue du rapport:")
    for i, (code, name) in enumerate(SUPPORTED_LANGUAGES.items(), 1):
        print(f"  {i}. {name} ({code})")

    lang_choice = input("\nChoisissez (1-4, défaut: 1): ").strip() or "1"
    lang_code = list(SUPPORTED_LANGUAGES.keys())[int(lang_choice) - 1]

    # Type de rapport
    print("\n📄 Type de rapport:")
    for i, (key, info) in enumerate(REPORT_TYPES.items(), 1):
        print(f"  {i}. {info['label']}")

    report_choice = input("\nChoisissez (1-2, défaut: 1): ").strip() or "1"
    report_type = list(REPORT_TYPES.keys())[int(report_choice) - 1]

    # Taille de compte
    print("\n💰 Taille de compte:")
    for i, (key, info) in enumerate(ACCOUNT_SIZES.items(), 1):
        print(f"  {i}. {info['label']} (risque {info['risk_pct']}%)")

    account_choice = input("\nChoisissez (1-3, défaut: 1): ").strip() or "1"
    account_size = list(ACCOUNT_SIZES.keys())[int(account_choice) - 1]

    # Envoi WhatsApp
    print("\n📱 Envoi automatique sur WhatsApp après génération?")
    whatsapp_choice = input("  (O/n, défaut: O): ").strip().lower() or "o"
    send_whatsapp = whatsapp_choice == "o"

    return {
        "language": lang_code,
        "report_type": report_type,
        "account_size": account_size,
        "send_whatsapp": send_whatsapp
    }


def send_report_whatsapp(report_path: Path) -> bool:
    """
    Envoie le rapport Word sur WhatsApp via send_tradingagents_report.py
    """
    try:
        import subprocess

        script_path = _HERE / "send_tradingagents_report.py"
        result = subprocess.run([
            sys.executable,
            str(script_path),
            "--file", str(report_path),
            "--send-file"
        ], capture_output=True, text=True, timeout=60)

        if result.returncode == 0:
            print(f"\n✅ Rapport envoyé sur WhatsApp!")
            return True
        else:
            print(f"\n❌ Échec envoi WhatsApp: {result.stderr}")
            return False

    except Exception as e:
        print(f"\n❌ Erreur envoi WhatsApp: {e}")
        return False


def main_v2():
    """Point d'entrée amélioré avec wizard de préférences."""
    import argparse

    parser = argparse.ArgumentParser(
        description="TradBOT Bridge V2 - Enhanced multi-language reports",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument("--wizard", action="store_true",
                       help="Mode wizard complet (recommandé)")
    parser.add_argument("--symbol", "-s", default=None,
                       help="Symbole MT5 (ex: XAUUSD)")
    parser.add_argument("--lang", "-l", default="FR",
                       choices=list(SUPPORTED_LANGUAGES.keys()),
                       help="Langue du rapport")
    parser.add_argument("--report-type", "-r", default="summary",
                       choices=list(REPORT_TYPES.keys()),
                       help="Type de rapport")
    parser.add_argument("--account", "-a", default="small",
                       choices=list(ACCOUNT_SIZES.keys()),
                       help="Taille de compte")
    parser.add_argument("--no-whatsapp", action="store_true",
                       help="Ne pas envoyer sur WhatsApp")
    parser.add_argument("--date", "-d", default=str(date.today()),
                       help="Date YYYY-MM-DD")

    args = parser.parse_args()

    # Mode wizard ou préférences en arguments
    if args.wizard or args.symbol is None:
        prefs = select_preferences_interactive()
    else:
        prefs = {
            "language": args.lang,
            "report_type": args.report_type,
            "account_size": args.account,
            "send_whatsapp": not args.no_whatsapp
        }

    print("\n" + "="*60)
    print(f"  Configuration:")
    print(f"    Langue: {SUPPORTED_LANGUAGES[prefs['language']]}")
    print(f"    Rapport: {REPORT_TYPES[prefs['report_type']]['label']}")
    print(f"    Compte: {ACCOUNT_SIZES[prefs['account_size']]['label']}")
    print(f"    WhatsApp: {'Oui' if prefs['send_whatsapp'] else 'Non'}")
    print("="*60)

    # TODO: Intégrer avec le bridge original
    # Pour l'instant, afficher les préférences
    print("\n[bridge_v2] Préférences enregistrées.")
    print("[bridge_v2] Intégration complète en cours de développement...")

    # La prochaine étape sera de:
    # 1. Modifier save_report_word() pour accepter language, report_type, account_size
    # 2. Appliquer les traductions dans le document
    # 3. Limiter les sections si report_type=summary
    # 4. Calculer lot size selon account_size
    # 5. Envoyer sur WhatsApp si prefs['send_whatsapp']=True


if __name__ == "__main__":
    main_v2()
