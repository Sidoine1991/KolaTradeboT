from __future__ import annotations

import re
from pathlib import Path


def insert_after_last_tp_print(fn_text: str, block: str) -> str:
    lines = fn_text.splitlines(True)  # keepends
    insert_at = None
    for i in range(len(lines) - 1, -1, -1):
        if "DoubleToString(takeProfit, _Digits)" in lines[i] and "TP" in lines[i] and lines[i].lstrip().startswith("Print("):
            insert_at = i + 1
            break
    if insert_at is None:
        raise SystemExit("could not find TP Print line")
    return "".join(lines[:insert_at]) + block + "".join(lines[insert_at:])


def insert_before_function_closing_brace(fn_text: str, block: str) -> str:
    # Insert just before the final '}' of the function body (last line)
    lines = fn_text.splitlines(True)
    if not lines or not lines[-1].lstrip().startswith("}"):
        raise SystemExit("expected function to end with '}'")
    return "".join(lines[:-1]) + block + lines[-1]


def extract_function(text: str, name: str) -> tuple[int, int, str]:
    sig = "void " + name + "("
    i = text.find(sig)
    if i < 0:
        raise SystemExit(f"{name} not found")
    j = text.find("{", i)
    if j < 0:
        raise SystemExit("opening brace not found")
    depth = 0
    for k in range(j, len(text)):
        ch = text[k]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i, k + 1, text[i : k + 1]
    raise SystemExit("unterminated function")


def replace_function(text: str, name: str, new_fn: str) -> str:
    start, end, _old = extract_function(text, name)
    return text[:start] + new_fn + text[end:]


def main() -> None:
    p = Path(__file__).resolve().parent.parent / "SMC_Universal.mq5"
    text = p.read_text(encoding="utf-8")

    _, _, ote_fn = extract_function(text, "DrawOTESetup")
    ote_block = (
        "\n"
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
    )
    if "NotifyOnOteChartSetupDrawn" not in ote_fn:
        ote_fn2 = insert_after_last_tp_print(ote_fn, ote_block)
        text = replace_function(text, "DrawOTESetup", ote_fn2)

    m = re.search(r"void UpdateStairSetupChartDisplay\(\)\s*\{([\s\S]*?)\n\}", text)
    if not m:
        raise SystemExit("UpdateStairSetupChartDisplay not found")
    # Re-extract using brace matching (regex above is fragile); use function extractor
    _, _, stair_fn = extract_function(text, "UpdateStairSetupChartDisplay")
    stair_block = (
        "\n"
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
    )
    if "NotifyOnStairChartSetupDrawn" not in stair_fn:
        stair_fn2 = insert_before_function_closing_brace(stair_fn, stair_block)
        text = replace_function(text, "UpdateStairSetupChartDisplay", stair_fn2)

    p.write_text(text, encoding="utf-8")
    print("inserted chart setup notifies:", p)


if __name__ == "__main__":
    main()
