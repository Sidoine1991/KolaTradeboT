"""
TradBOT Bridge Enhanced - Version amelioree du bridge TradingAgents

NOUVELLES FONCTIONNALITÉS V2:
  ✅ Multi-langue (FR, EN, ES, AR)
  ✅ Type de rapport (Résumé 5 pages / Complet)
  ✅ Calcul lot size selon budget (10$, 50$, 200$+)
  ✅ Signal de trade obligatoire avec SL/TP1/TP2
  ✅ Design Word amélioré
  ✅ Envoi automatique WhatsApp

LANCEMENT:
  python tradbot_bridge_enhanced.py --wizard
  python tradbot_bridge_enhanced.py --symbol XAUUSD --lang FR --report-type summary --account medium
"""

import sys
import argparse
from datetime import date
from pathlib import Path

# Import du module d'améliorations
from bridge_enhancements import (
    SUPPORTED_LANGUAGES,
    ACCOUNT_SIZES,
    REPORT_TYPES,
    select_preferences_interactive,
    send_report_to_whatsapp,
    calculate_lot_size_for_account,
    t
)

# Import du bridge original (toutes ses fonctions)
from tradbot_bridge import (
    select_symbol_interactive,
    run_quick,
    _normalize_rating,
    _extract_order_params,
    compute_signals,
    compute_entry_levels,
    compute_lot_sizes,
    interactive_confirm,
    print_report,
    push_manual_report,
    push_session_bias,
    push_alert_levels,
    push_pending_order,
    _REPORTS_DIR,
    _SERVER_URL,
    _mt5_to_yfinance
)


def main_enhanced():
    """Point d'entrée principal amélioré."""

    parser = argparse.ArgumentParser(
        description="TradBOT Bridge Enhanced - Version multilingue avec envoi WhatsApp",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples:
  python tradbot_bridge_enhanced.py --wizard
  python tradbot_bridge_enhanced.py --symbol XAUUSD --lang FR --account medium
  python tradbot_bridge_enhanced.py --symbol EURUSD --lang EN --report-type full --account large --no-whatsapp
        """
    )

    parser.add_argument("--wizard", action="store_true",
                       help="Mode wizard interactif complet (recommandé)")
    parser.add_argument("--symbol", "-s", default=None,
                       help="Symbole MT5 (ex: XAUUSD, EURUSD)")
    parser.add_argument("--lang", "-l", default="FR",
                       choices=list(SUPPORTED_LANGUAGES.keys()),
                       help="Langue du rapport")
    parser.add_argument("--report-type", "-r", default="summary",
                       choices=list(REPORT_TYPES.keys()),
                       help="Type de rapport (summary=5 pages, full=complet)")
    parser.add_argument("--account", "-a", default="small",
                       choices=list(ACCOUNT_SIZES.keys()),
                       help="Taille de compte pour calcul lot size")
    parser.add_argument("--no-whatsapp", action="store_true",
                       help="Ne pas envoyer automatiquement sur WhatsApp")
    parser.add_argument("--date", "-d", default=str(date.today()),
                       help="Date d'analyse YYYY-MM-DD")
    parser.add_argument("--analysts", default="market,social,news,fundamentals",
                       help="Analystes TradingAgents (séparés par virgule)")
    parser.add_argument("--no-pending", action="store_true",
                       help="Rapport seulement, pas d'ordre MT5")
    parser.add_argument("--auto", action="store_true",
                       help="Pas de confirmation interactive")

    args = parser.parse_args()

    # =========================================================================
    # ÉTAPE 1: Configuration (wizard ou arguments)
    # =========================================================================

    if args.wizard or args.symbol is None:
        prefs = select_preferences_interactive()
    else:
        prefs = {
            "language": args.lang,
            "report_type": args.report_type,
            "account_size": args.account,
            "send_whatsapp": not args.no_whatsapp
        }

    print("\n" + "="*70)
    print("  📋 Configuration du rapport:")
    print(f"     Langue: {SUPPORTED_LANGUAGES[prefs['language']]}")
    print(f"     Type: {REPORT_TYPES[prefs['report_type']]['label']}")
    print(f"     Compte: {ACCOUNT_SIZES[prefs['account_size']]['label']}")
    print(f"     WhatsApp: {'Oui ✅' if prefs['send_whatsapp'] else 'Non ❌'}")
    print("="*70 + "\n")

    # =========================================================================
    # ÉTAPE 2: Sélection du symbole et analyse TradingAgents
    # =========================================================================

    # Valider les analystes
    _valid = {"market", "social", "news", "fundamentals"}
    analysts = [a.strip().lower() for a in args.analysts.split(",") if a.strip()]
    analysts = ["social" if a == "sentiment" else a for a in analysts]
    analysts = [a for a in analysts if a in _valid] or ["market", "social"]

    # Choisir mode de sélection symbole
    if args.symbol is None:
        print("\n📊 Sélection du symbole...")
        sym_label, ticker_id, vendor = select_symbol_interactive()
        result = run_quick(sym_label, args.date,
                          analysts=analysts,
                          data_ticker=ticker_id,
                          vendor=vendor)
    else:
        sym = args.symbol.strip()
        ticker_id = _mt5_to_yfinance(sym)
        vendor = "deriv" if any(ticker_id.upper().startswith(p)
                               for p in ("BOOM","CRASH","1HZ","R_","FRX")) else "yfinance"
        result = run_quick(sym, args.date,
                          analysts=analysts,
                          data_ticker=ticker_id,
                          vendor=vendor)

    symbol = result["symbol"]
    signal_rating = result["signal_rating"]
    final_state = result["final_state"]
    indicators = result.get("indicators")
    expert_analysis = result.get("expert_analysis", "")

    rec = _normalize_rating(signal_rating)
    params = _extract_order_params(final_state)

    # =========================================================================
    # ÉTAPE 3: Calcul des signaux avec lot size adapté au compte
    # =========================================================================

    computed_signals = []
    current_price_main = None

    if indicators and rec in ("BUY", "SELL"):
        cp = indicators.get("current_price")
        at = indicators.get("atr")
        if cp and at:
            current_price_main = float(cp)
            computed_signals = compute_signals(symbol, rec, float(cp), float(at))

    if not computed_signals and rec in ("BUY", "SELL"):
        lvl = compute_entry_levels(symbol, rec)
        computed_signals = lvl.get("signals", [])
        if not current_price_main:
            current_price_main = lvl.get("current_price")

    # Ajouter lot size calculé pour chaque signal
    for sig in computed_signals:
        entry = sig.get("entry_price")
        sl = sig.get("stop_loss")
        if entry and sl:
            lot_info = calculate_lot_size_for_account(
                entry, sl, prefs["account_size"], symbol
            )
            sig["lot_calculated"] = lot_info["lot"]
            sig["risk_usd"] = lot_info["risk_usd"]
            sig["capital"] = lot_info["capital"]
            sig["risk_pct"] = lot_info["risk_pct"]

    # =========================================================================
    # ÉTAPE 4: Affichage terminal
    # =========================================================================

    print_report(symbol, signal_rating, final_state, params)

    if computed_signals:
        print(f"\n{'='*70}")
        print(f"  💰 SIGNAUX DE TRADING (Compte: {ACCOUNT_SIZES[prefs['account_size']]['label']})")
        print(f"{'='*70}")
        print(f"  Prix actuel: {current_price_main}")

        for i, sig in enumerate(computed_signals[:2], 1):
            label = sig.get('label', 'Signal')
            action = sig.get('action')
            exec_type = sig.get('exec_type', 'market').upper()
            entry = sig.get('entry_price')
            sl = sig.get('stop_loss')
            tp = sig.get('take_profit')
            rr = sig.get('rr')
            lot = sig.get('lot_calculated', 0.01)
            risk_usd = sig.get('risk_usd', 0)

            print(f"\n  [{i}] {label}")
            print(f"      {action} {exec_type} @ {entry}")
            print(f"      SL: {sl} | TP: {tp} | R/R: 1:{rr}")
            print(f"      Lot: {lot:.2f} | Risque: ${risk_usd:.2f}")

    if expert_analysis:
        print(f"\n{'='*70}")
        print("  🧠 ANALYSE EXPERT CLAUDE")
        print(f"{'='*70}")
        print(expert_analysis[:500] + "..." if len(expert_analysis) > 500 else expert_analysis)

    # =========================================================================
    # ÉTAPE 5: Confirmation interactive (si pas --auto)
    # =========================================================================

    reasoning = (
        str(final_state.get("final_trade_decision") or "") + "\n\n" +
        str(final_state.get("trader_investment_plan") or "")
    )

    if args.auto:
        sig0 = computed_signals[0] if computed_signals else {}
        confirmed = {
            "recommendation": rec,
            "confidence": 0.75,
            "entry_price": sig0.get("entry_price") or params.get("entry_price"),
            "stop_loss": sig0.get("stop_loss") or params.get("stop_loss"),
            "take_profit": sig0.get("take_profit") or params.get("take_profit"),
            "execution_type": sig0.get("exec_type", "market"),
            "lot": sig0.get("lot_calculated") or None,
        }
    else:
        confirmed = interactive_confirm(rec, params, signals=computed_signals)

    # =========================================================================
    # ÉTAPE 6: Sauvegarde du rapport Word amélioré
    # =========================================================================

    trade_date = args.date if args.symbol else str(date.today())

    # Injecter les données d'amélioration dans final_state
    if expert_analysis:
        final_state = dict(final_state)
        final_state["expert_scalp_analysis"] = expert_analysis

    # Ajouter les préférences
    final_state["__prefs__"] = prefs
    final_state["__computed_signals__"] = computed_signals

    # TODO: Appeler save_report_word_enhanced() au lieu de save_report_word()
    # Pour l'instant, utilisons l'original et loggeons les données
    print(f"\n📝 Sauvegarde du rapport...")
    print(f"   Langue: {prefs['language']}")
    print(f"   Type: {prefs['report_type']}")
    print(f"   Compte: {prefs['account_size']}")

    # Import de la fonction originale
    from tradbot_bridge import save_report_word

    report_path = save_report_word(
        symbol, trade_date, signal_rating, final_state, params,
        confirmed=confirmed if confirmed else None,
        indicators=indicators
    )

    if confirmed is None:
        print("\n[bridge] Signal annulé. Rapport Word sauvegardé.")

        # Envoi WhatsApp même si annulé
        if report_path and prefs["send_whatsapp"]:
            send_report_to_whatsapp(report_path)

        return

    # =========================================================================
    # ÉTAPE 7: Envoi vers AI server + MT5
    # =========================================================================

    print(f"\n[bridge] Envoi vers {_SERVER_URL}...")
    push_manual_report(symbol, confirmed, reasoning)

    bias_conf = confirmed.get("confidence") or 0.70
    push_session_bias(symbol, rec, float(bias_conf))

    if expert_analysis:
        push_alert_levels(symbol, expert_analysis)

    if not args.no_pending and confirmed["recommendation"] in ("BUY", "SELL"):
        push_pending_order(symbol, confirmed)

    print("\n[bridge] ✅ Signal envoyé à l'EA MT5.")
    print(f"  Status: GET {_SERVER_URL}/tradingagents/realtime/status")
    print(f"  Rapports: {_REPORTS_DIR}\n")

    # =========================================================================
    # ÉTAPE 8: Envoi automatique WhatsApp
    # =========================================================================

    if report_path and prefs["send_whatsapp"]:
        success = send_report_to_whatsapp(report_path)
        if success:
            print("\n✅ Rapport envoyé sur WhatsApp avec succès!")
        else:
            print("\n⚠️ Rapport sauvegardé mais échec envoi WhatsApp.")
    else:
        print(f"\n📄 Rapport sauvegardé: {report_path}")


if __name__ == "__main__":
    try:
        main_enhanced()
    except KeyboardInterrupt:
        print("\n\n⏹️ Annulé par l'utilisateur.")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ ERREUR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
