"""Parse MT5 Strategy Tester Excel reports (French format)."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import openpyxl


def _parse_dd_pct(val: str | None) -> tuple[float | None, float | None]:
    if not val or not isinstance(val, str):
        return None, None
    m = re.search(r"([\d.]+)\s*\(([\d.]+)%\)", val)
    if m:
        return float(m.group(1)), float(m.group(2))
    m = re.search(r"([\d.]+)%\s*\(([\d.]+)\)", val)
    if m:
        return float(m.group(2)), float(m.group(1))
    return None, None


def parse_mt5_excel(path: str | Path) -> dict[str, Any]:
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))

    params: dict[str, Any] = {}
    for row in rows:
        v = row[3] if len(row) > 3 else None
        if v and isinstance(v, str) and "=" in v and not v.startswith("==="):
            k, val = v.split("=", 1)
            val = val.strip()
            if val.lower() in ("true", "false"):
                params[k.strip()] = val.lower() == "true"
            else:
                try:
                    params[k.strip()] = int(val)
                except ValueError:
                    try:
                        params[k.strip()] = float(val)
                    except ValueError:
                        params[k.strip()] = val

    for row in rows:
        a, d = row[0], row[3] if len(row) > 3 else None
        if not a or not d:
            continue
        s = str(a)
        if "Courtier" in s:
            params["Broker"] = d
        elif "Devise" in s:
            params["Currency"] = d
        elif "initial" in s.lower() and ("p" in s.lower() or "d" in s.lower()):
            params["InitialDeposit"] = float(d) if isinstance(d, (int, float)) else d
        elif "Levier" in s:
            params["Leverage"] = d
        elif "riode" in s:
            params["Period"] = d
        elif "Symbole" in s:
            params["Symbol"] = d
        elif "Expert" in s:
            params["Expert"] = d

    metrics: dict[str, Any] = {}
    for row in rows:
        a = row[0]
        s_a = str(a) if a else ""
        col4 = row[3] if len(row) > 3 else None
        col7 = row[7] if len(row) > 7 else None
        col10 = row[10] if len(row) > 10 else None
        col5 = row[4] if len(row) > 4 else None

        if "Net" in s_a and col4 is not None and not isinstance(col4, str):
            metrics["NetProfit"] = float(col4)
        if "Profit brut" in s_a and col4 is not None:
            metrics["GrossProfit"] = float(col4)
            abs_v, pct_v = _parse_dd_pct(str(col7) if col7 else None)
            if pct_v is not None:
                metrics["BalanceDrawdownMax_pct"] = pct_v
                metrics["BalanceDrawdownMax_abs"] = abs_v
            abs_v, pct_v = _parse_dd_pct(str(col10) if col10 else None)
            if pct_v is not None:
                metrics["FundsDrawdownMax_pct"] = pct_v
                metrics["FundsDrawdownMax_abs"] = abs_v
        if "Perte brut" in s_a and col4 is not None:
            metrics["GrossLoss"] = float(col4)
        if "Facteur de profit" in s_a:
            if col4 is not None:
                metrics["ProfitFactor"] = float(col4)
            if col7 is not None:
                metrics["ExpectedPayoff"] = float(col7)
        if "cup" in s_a and "Facteur" in s_a:
            if col4 is not None:
                metrics["RecoveryFactor"] = float(col4)
            if col7 is not None:
                metrics["SharpeRatio"] = float(col7)
        if "Nb trades" in s_a and col4 is not None:
            metrics["TotalTrades"] = int(col4)
        if "rations au Total" in s_a:
            if col7:
                m = re.search(r"(\d+)\s*\(([\d.]+)%\)", str(col7))
                if m:
                    metrics["WinCount"] = int(m.group(1))
                    metrics["WinRate_pct"] = float(m.group(2))
            if col10:
                m = re.search(r"(\d+)\s*\(([\d.]+)%\)", str(col10))
                if m:
                    metrics["LossCount"] = int(m.group(1))
        if col5 and "Moyenne position gagnante" in str(col5):
            if col7 is not None:
                metrics["AvgWin"] = float(col7)
            if col10 is not None:
                metrics["AvgLoss"] = float(col10)
        if col5 and "Maximum Pertes cons" in str(col5) and "cutives ($)" in str(col5):
            metrics["MaxConsecLoss_str"] = str(col10)

    deposit = float(params.get("InitialDeposit", 100))
    metrics["InitialDeposit"] = deposit
    if "NetProfit" in metrics:
        metrics["FinalBalance"] = deposit + metrics["NetProfit"]
        metrics["ROI_pct"] = metrics["NetProfit"] / deposit * 100

    wb.close()
    return {"params": params, "metrics": metrics, "source_file": str(Path(path).name)}


def analyze_weaknesses(parsed: dict[str, Any]) -> list[dict[str, str]]:
    m = parsed.get("metrics", {})
    weaknesses = []
    total = m.get("TotalTrades", 0)
    if total < 25:
        weaknesses.append(
            {
                "id": "low_sample",
                "severity": "high",
                "title": "Échantillon de trades insuffisant",
                "detail": f"Seulement {total} trades — robustesse statistique limitée.",
            }
        )
    dd = m.get("FundsDrawdownMax_pct") or m.get("BalanceDrawdownMax_pct") or 0
    if dd > 20:
        weaknesses.append(
            {
                "id": "high_dd",
                "severity": "high",
                "title": "Drawdown maximal élevé",
                "detail": f"DD fonds {dd:.1f}% > 20% pour compte $100.",
            }
        )
    deposit = m.get("InitialDeposit", 100)
    if m.get("AvgLoss") and abs(m["AvgLoss"]) > deposit * 0.4:
        weaknesses.append(
            {
                "id": "avg_loss_size",
                "severity": "medium",
                "title": "Perte moyenne disproportionnée",
                "detail": f"Perte moyenne ${abs(m['AvgLoss']):.2f} vs capital ${deposit:.0f}.",
            }
        )
    if m.get("MaxConsecLoss_str") and "-" in str(m["MaxConsecLoss_str"]):
        weaknesses.append(
            {
                "id": "consec_loss",
                "severity": "medium",
                "title": "Séquence de pertes consécutives",
                "detail": str(m["MaxConsecLoss_str"]),
            }
        )
    params = parsed.get("params", {})
    if params.get("BuyBiasOnly"):
        weaknesses.append(
            {
                "id": "buy_only",
                "severity": "low",
                "title": "Biais BUY uniquement",
                "detail": "Pas de couverture baissière — sensible aux corrections.",
            }
        )
    return weaknesses
