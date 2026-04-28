from pathlib import Path


def main() -> None:
    p = Path(__file__).resolve().parent.parent / "SMC_Universal.mq5"
    text = p.read_text(encoding="utf-8")

    ote_anchor = (
        '   Print("   \U0001f3af TP: ", DoubleToString(takeProfit, _Digits));\n'
        "}\n\n"
        "// Dessiner un setup escalier synthétique M1 (style OTE, affichage seulement — pas d’ordre ici)."
    )
    ote_insert = (
        '   Print("   \U0001f3af TP: ", DoubleToString(takeProfit, _Digits));\n\n'
        "   if(NotifyOnOteChartSetupDrawn)\n"
        "   {\n"
        "      string d = direction;\n"
        "      StringToUpper(d);\n"
        '      string msg = "OTE SETUP (chart) | " + d + " " + _Symbol +\n'
        '                   " @ " + DoubleToString(entryPrice, _Digits) +\n'
        '                   " | SL " + DoubleToString(stopLoss, _Digits) +\n'
        '                   " | TP " + DoubleToString(takeProfit, _Digits);\n'
        '      NotifyRobotEventOncePerBar("OTE_CHART_SETUP_" + _Symbol + "_" + d + "_" + DoubleToString(entryPrice, _Digits),\n'
        "                                 msg,\n"
        "                                 EntryTradeSoundFile,\n"
        "                                 PERIOD_M1);\n"
        "   }\n"
        "}\n\n"
        "// Dessiner un setup escalier synthétique M1 (style OTE, affichage seulement — pas d’ordre ici)."
    )

    if ote_anchor not in text:
        raise SystemExit("DrawOTESetup anchor not found (file changed?)")
    if "OTE_CHART_SETUP_" not in text:
        text = text.replace(ote_anchor, ote_insert, 1)

    stair_anchor = (
        "   DrawStairSetupLikeOTE(entry, sl, tp, dir);\n"
        "}\n\n"
        "//+------------------------------------------------------------------+\n"
        "//| Mode escalier : helpers (niveau A = même logique que stair marché) |"
    )
    stair_insert = (
        "   DrawStairSetupLikeOTE(entry, sl, tp, dir);\n\n"
        "   if(NotifyOnStairChartSetupDrawn)\n"
        "   {\n"
        '      string msg = "STAIR SETUP (chart) | " + dir + " " + _Symbol +\n'
        '                   " @ " + DoubleToString(entry, _Digits) +\n'
        '                   " | SL " + DoubleToString(sl, _Digits) +\n'
        '                   " | TP " + DoubleToString(tp, _Digits);\n'
        '      NotifyRobotEventOncePerBar("STAIR_CHART_SETUP_" + _Symbol + "_" + dir + "_" + DoubleToString(entry, _Digits),\n'
        "                                 msg,\n"
        "                                 EntryTradeSoundFile,\n"
        "                                 PERIOD_M1);\n"
        "   }\n"
        "}\n\n"
        "//+------------------------------------------------------------------+\n"
        "//| Mode escalier : helpers (niveau A = même logique que stair marché) |"
    )

    if stair_anchor not in text:
        raise SystemExit("UpdateStairSetupChartDisplay anchor not found (file changed?)")
    if "STAIR_CHART_SETUP_" not in text:
        text = text.replace(stair_anchor, stair_insert, 1)

    p.write_text(text, encoding="utf-8")
    print("patched:", p)


if __name__ == "__main__":
    main()
