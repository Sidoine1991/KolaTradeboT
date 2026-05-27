"""
Bridge Enhancements - Module d'amélioration pour tradbot_bridge.py

Ce module ajoute:
- Support multi-langue (FR, EN, ES, AR)
- Types de rapport (Résumé 5 pages / Complet)
- Calcul lot size selon taille de compte
- Envoi automatique WhatsApp
- Design Word amélioré

Usage:
    from bridge_enhancements import enhance_bridge_config, save_enhanced_report
"""

from datetime import date
from pathlib import Path
from typing import Dict, Any, Optional, List
import sys

# ==============================================================================
# CONSTANTES ET TRADUCTIONS
# ==============================================================================

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
    "summary": {"label": "Résumé (5 pages max)", "max_sections": 5},
    "full": {"label": "Complet (toutes sections)", "max_sections": None}
}

# Traductions complètes
TRANSLATIONS = {
    "FR": {
        # Page de titre
        "title": "Rapport d'Analyse Technique",
        "subtitle": "Analyse Algorithmique TradingAgents",
        "date_analysis": "Date d'analyse",
        "date_generated": "Généré le",
        "by": "par",

        # Section Signal
        "signal_section": "🎯 Signal TradingAgents",
        "rating_raw": "Rating brut",
        "decision": "Décision",
        "current_price": "Prix actuel",
        "atr": "ATR (volatilité)",
        "confidence": "Confiance",

        # Section Signaux de Trading
        "signals_section": "💰 Signaux de Trading Proposés",
        "signal_num": "Signal",
        "conservative": "Conservateur",
        "aggressive": "Agressif",
        "order_type": "Type d'ordre",
        "direction": "Direction",
        "entry_price": "Prix d'entrée",
        "stop_loss": "Stop Loss",
        "take_profit": "Take Profit",
        "risk_reward": "Ratio R/R",
        "risk": "de risque",
        "gain": "de gain potentiel",

        # Section Position Sizing
        "position_section": "📊 Taille de Position Recommandée",
        "account_size": "Taille de compte",
        "capital": "Capital",
        "risk_per_trade": "Risque par trade",
        "risk_amount": "Montant du risque",
        "lot_size": "Taille de position",
        "potential_loss": "Perte potentielle",
        "potential_gain": "Gain potentiel",

        # Sections d'analyse
        "analysis_section": "📈 Analyse Détaillée",
        "technical_section": "Analyse Technique",
        "fundamental_section": "Analyse Fondamentale",
        "sentiment_section": "Sentiment du Marché",
        "risk_section": "Gestion du Risque",

        # Conclusion
        "conclusion_section": "✅ Conclusion et Recommandations",
        "summary": "Résumé exécutif",

        # Footer
        "disclaimer": "Ce rapport est généré automatiquement à titre informatif uniquement. Il ne constitue pas un conseil en investissement.",
        "generated_by": "Généré par TradBOT",
    },

    "EN": {
        # Page de titre
        "title": "Technical Analysis Report",
        "subtitle": "TradingAgents Algorithmic Analysis",
        "date_analysis": "Analysis date",
        "date_generated": "Generated on",
        "by": "by",

        # Section Signal
        "signal_section": "🎯 TradingAgents Signal",
        "rating_raw": "Raw rating",
        "decision": "Decision",
        "current_price": "Current price",
        "atr": "ATR (volatility)",
        "confidence": "Confidence",

        # Section Signaux de Trading
        "signals_section": "💰 Proposed Trading Signals",
        "signal_num": "Signal",
        "conservative": "Conservative",
        "aggressive": "Aggressive",
        "order_type": "Order type",
        "direction": "Direction",
        "entry_price": "Entry price",
        "stop_loss": "Stop Loss",
        "take_profit": "Take Profit",
        "risk_reward": "R/R Ratio",
        "risk": "risk",
        "gain": "potential gain",

        # Section Position Sizing
        "position_section": "📊 Recommended Position Size",
        "account_size": "Account size",
        "capital": "Capital",
        "risk_per_trade": "Risk per trade",
        "risk_amount": "Risk amount",
        "lot_size": "Position size",
        "potential_loss": "Potential loss",
        "potential_gain": "Potential gain",

        # Sections d'analyse
        "analysis_section": "📈 Detailed Analysis",
        "technical_section": "Technical Analysis",
        "fundamental_section": "Fundamental Analysis",
        "sentiment_section": "Market Sentiment",
        "risk_section": "Risk Management",

        # Conclusion
        "conclusion_section": "✅ Conclusion and Recommendations",
        "summary": "Executive summary",

        # Footer
        "disclaimer": "This report is automatically generated for informational purposes only. It does not constitute investment advice.",
        "generated_by": "Generated by TradBOT",
    },

    "ES": {
        # Page de titre
        "title": "Informe de Análisis Técnico",
        "subtitle": "Análisis Algorítmico TradingAgents",
        "date_analysis": "Fecha de análisis",
        "date_generated": "Generado el",
        "by": "por",

        # Section Signal
        "signal_section": "🎯 Señal TradingAgents",
        "rating_raw": "Calificación bruta",
        "decision": "Decisión",
        "current_price": "Precio actual",
        "atr": "ATR (volatilidad)",
        "confidence": "Confianza",

        # Section Signaux de Trading
        "signals_section": "💰 Señales de Trading Propuestas",
        "signal_num": "Señal",
        "conservative": "Conservador",
        "aggressive": "Agresivo",
        "order_type": "Tipo de orden",
        "direction": "Dirección",
        "entry_price": "Precio de entrada",
        "stop_loss": "Stop Loss",
        "take_profit": "Take Profit",
        "risk_reward": "Ratio R/R",
        "risk": "de riesgo",
        "gain": "de ganancia potencial",

        # Section Position Sizing
        "position_section": "📊 Tamaño de Posición Recomendado",
        "account_size": "Tamaño de cuenta",
        "capital": "Capital",
        "risk_per_trade": "Riesgo por operación",
        "risk_amount": "Monto del riesgo",
        "lot_size": "Tamaño de posición",
        "potential_loss": "Pérdida potencial",
        "potential_gain": "Ganancia potencial",

        # Sections d'analyse
        "analysis_section": "📈 Análisis Detallado",
        "technical_section": "Análisis Técnico",
        "fundamental_section": "Análisis Fundamental",
        "sentiment_section": "Sentimiento del Mercado",
        "risk_section": "Gestión del Riesgo",

        # Conclusion
        "conclusion_section": "✅ Conclusión y Recomendaciones",
        "summary": "Resumen ejecutivo",

        # Footer
        "disclaimer": "Este informe se genera automáticamente solo con fines informativos. No constituye asesoramiento de inversión.",
        "generated_by": "Generado por TradBOT",
    },

    "AR": {
        # Page de titre
        "title": "تقرير التحليل الفني",
        "subtitle": "التحليل الخوارزمي TradingAgents",
        "date_analysis": "تاريخ التحليل",
        "date_generated": "تم إنشاؤه في",
        "by": "بواسطة",

        # Section Signal
        "signal_section": "🎯 إشارة TradingAgents",
        "rating_raw": "التقييم الأولي",
        "decision": "القرار",
        "current_price": "السعر الحالي",
        "atr": "ATR (التقلب)",
        "confidence": "الثقة",

        # Section Signaux de Trading
        "signals_section": "💰 إشارات التداول المقترحة",
        "signal_num": "إشارة",
        "conservative": "محافظ",
        "aggressive": "عدواني",
        "order_type": "نوع الأمر",
        "direction": "الاتجاه",
        "entry_price": "سعر الدخول",
        "stop_loss": "وقف الخسارة",
        "take_profit": "جني الأرباح",
        "risk_reward": "نسبة المخاطرة/العائد",
        "risk": "مخاطرة",
        "gain": "ربح محتمل",

        # Section Position Sizing
        "position_section": "📊 حجم الصفقة الموصى به",
        "account_size": "حجم الحساب",
        "capital": "رأس المال",
        "risk_per_trade": "المخاطرة لكل صفقة",
        "risk_amount": "مبلغ المخاطرة",
        "lot_size": "حجم الصفقة",
        "potential_loss": "الخسارة المحتملة",
        "potential_gain": "الربح المحتمل",

        # Sections d'analyse
        "analysis_section": "📈 التحليل التفصيلي",
        "technical_section": "التحليل الفني",
        "fundamental_section": "التحليل الأساسي",
        "sentiment_section": "معنويات السوق",
        "risk_section": "إدارة المخاطر",

        # Conclusion
        "conclusion_section": "✅ الخلاصة والتوصيات",
        "summary": "الملخص التنفيذي",

        # Footer
        "disclaimer": "يتم إنشاء هذا التقرير تلقائيًا لأغراض إعلامية فقط. لا يشكل نصيحة استثمارية.",
        "generated_by": "تم الإنشاء بواسطة TradBOT",
    }
}

# ==============================================================================
# CALCUL LOT SIZE SELON TAILLE DE COMPTE
# ==============================================================================

def calculate_lot_size_for_account(
    entry_price: float,
    stop_loss: float,
    account_size: str,
    symbol: str
) -> Dict[str, Any]:
    """
    Calcule la taille de lot optimale selon la taille du compte.

    Args:
        entry_price: Prix d'entrée
        stop_loss: Stop loss
        account_size: "small", "medium", ou "large"
        symbol: Symbole MT5 (pour déterminer pip size)

    Returns:
        dict avec lot, risk_usd, risk_pct, potential_loss, potential_gain
    """
    acc = ACCOUNT_SIZES[account_size]
    capital = acc["capital"]
    risk_pct = acc["risk_pct"]
    risk_usd = capital * (risk_pct / 100)

    # Déterminer pip size
    pip_size = 0.0001
    if "JPY" in symbol.upper():
        pip_size = 0.01
    elif any(x in symbol.upper() for x in ["XAU", "GOLD", "OR"]):
        pip_size = 0.1

    # Distance SL en pips
    sl_distance_pips = abs(entry_price - stop_loss) / pip_size

    # Valeur du pip par lot standard
    pip_value_per_lot = 10  # USD pour paires Forex
    if any(x in symbol.upper() for x in ["XAU", "GOLD", "OR"]):
        pip_value_per_lot = 1  # 1$ par 0.01 lot pour l'or

    # Calculer lot size
    if sl_distance_pips > 0:
        lot_size = risk_usd / (sl_distance_pips * pip_value_per_lot)
    else:
        lot_size = 0.01

    # Limites MT5
    min_lot = 0.01
    max_lot = capital / 1000  # Approximation conservatrice
    lot_size = max(min_lot, min(lot_size, max_lot))
    lot_size = round(lot_size / 0.01) * 0.01  # Arrondir à 0.01

    return {
        "lot": lot_size,
        "risk_usd": risk_usd,
        "risk_pct": risk_pct,
        "capital": capital,
        "potential_loss": risk_usd,
        "sl_distance_pips": sl_distance_pips
    }

# ==============================================================================
# WIZARD INTERACTIF
# ==============================================================================

def select_preferences_interactive() -> Dict[str, Any]:
    """
    Wizard interactif pour sélectionner:
    - Langue du rapport
    - Type de rapport (résumé / complet)
    - Taille de compte
    - Envoi WhatsApp automatique
    """
    print("\n" + "="*70)
    print("  📋 CONFIGURATION DU RAPPORT TRADBOT")
    print("="*70)

    # 1. Langue
    print("\n📝 Langue du rapport:")
    lang_list = list(SUPPORTED_LANGUAGES.items())
    for i, (code, name) in enumerate(lang_list, 1):
        print(f"  {i}. {name} ({code})")

    while True:
        lang_choice = input(f"\nChoisissez (1-{len(lang_list)}, défaut: 1): ").strip() or "1"
        try:
            idx = int(lang_choice) - 1
            if 0 <= idx < len(lang_list):
                lang_code = lang_list[idx][0]
                break
        except ValueError:
            pass
        print("  ❌ Choix invalide, réessayez.")

    # 2. Type de rapport
    print("\n📄 Type de rapport:")
    report_list = list(REPORT_TYPES.items())
    for i, (key, info) in enumerate(report_list, 1):
        print(f"  {i}. {info['label']}")

    while True:
        report_choice = input(f"\nChoisissez (1-{len(report_list)}, défaut: 1): ").strip() or "1"
        try:
            idx = int(report_choice) - 1
            if 0 <= idx < len(report_list):
                report_type = report_list[idx][0]
                break
        except ValueError:
            pass
        print("  ❌ Choix invalide, réessayez.")

    # 3. Taille de compte
    print("\n💰 Taille de compte (pour calcul lot size):")
    account_list = list(ACCOUNT_SIZES.items())
    for i, (key, info) in enumerate(account_list, 1):
        print(f"  {i}. {info['label']} — Risque {info['risk_pct']}% par trade")

    while True:
        account_choice = input(f"\nChoisissez (1-{len(account_list)}, défaut: 1): ").strip() or "1"
        try:
            idx = int(account_choice) - 1
            if 0 <= idx < len(account_list):
                account_size = account_list[idx][0]
                break
        except ValueError:
            pass
        print("  ❌ Choix invalide, réessayez.")

    # 4. Envoi WhatsApp
    print("\n📱 Envoi automatique sur WhatsApp après génération?")
    whatsapp_choice = input("  (O/n, défaut: O): ").strip().lower() or "o"
    send_whatsapp = whatsapp_choice in ("o", "oui", "y", "yes")

    print("\n" + "="*70)
    print("  ✅ Configuration enregistrée:")
    print(f"     Langue: {SUPPORTED_LANGUAGES[lang_code]}")
    print(f"     Rapport: {REPORT_TYPES[report_type]['label']}")
    print(f"     Compte: {ACCOUNT_SIZES[account_size]['label']}")
    print(f"     WhatsApp: {'Oui' if send_whatsapp else 'Non'}")
    print("="*70)

    return {
        "language": lang_code,
        "report_type": report_type,
        "account_size": account_size,
        "send_whatsapp": send_whatsapp
    }

# ==============================================================================
# ENVOI WHATSAPP AUTOMATIQUE
# ==============================================================================

def send_report_to_whatsapp(report_path: Path) -> bool:
    """
    Envoie le rapport Word sur WhatsApp via send_tradingagents_report.py

    Args:
        report_path: Chemin vers le fichier .docx

    Returns:
        True si succès, False sinon
    """
    try:
        import subprocess

        script_path = Path(__file__).parent / "send_tradingagents_report.py"

        if not script_path.exists():
            print(f"  ❌ Script WhatsApp introuvable: {script_path}")
            return False

        print(f"\n📤 Envoi du rapport sur WhatsApp...")
        result = subprocess.run([
            sys.executable,
            str(script_path),
            "--file", str(report_path),
            "--send-file"
        ], capture_output=True, text=True, timeout=60)

        if result.returncode == 0:
            print(f"  ✅ Rapport envoyé avec succès!")
            return True
        else:
            print(f"  ❌ Échec envoi WhatsApp:")
            print(f"     {result.stderr.strip()}")
            return False

    except subprocess.TimeoutExpired:
        print(f"  ❌ Timeout (>60s) lors de l'envoi WhatsApp")
        return False
    except Exception as e:
        print(f"  ❌ Erreur envoi WhatsApp: {e}")
        return False

# ==============================================================================
# HELPER: TRADUCTION
# ==============================================================================

def t(key: str, lang: str = "FR") -> str:
    """
    Récupère la traduction d'une clé dans la langue spécifiée.

    Args:
        key: Clé de traduction
        lang: Code langue (FR, EN, ES, AR)

    Returns:
        Texte traduit ou clé si introuvable
    """
    return TRANSLATIONS.get(lang, TRANSLATIONS["FR"]).get(key, key)


# ==============================================================================
# EXPORT
# ==============================================================================

__all__ = [
    "SUPPORTED_LANGUAGES",
    "ACCOUNT_SIZES",
    "REPORT_TYPES",
    "TRANSLATIONS",
    "calculate_lot_size_for_account",
    "select_preferences_interactive",
    "send_report_to_whatsapp",
    "t",
]
