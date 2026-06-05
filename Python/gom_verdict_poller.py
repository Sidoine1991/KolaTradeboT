# -*- coding: utf-8 -*-
"""
GOM Verdict Poller — sans webhook TradingView payant
=====================================================

Lit les valeurs du Pine Script GOM KOLA directement depuis
TradingView Desktop via CDP (MCP tradingview-kola), puis pousse
le verdict vers l'AI server /gom-verdict toutes les N secondes.

Architecture :
    TradingView Desktop (CDP)
        → data_get_study_values  (valeurs Pine visibles)
        → quote_get              (prix live)
        ↓
    /gom-verdict  (AI server local)
        ↓
    xauusd_whatsapp_monitor.py  (lit /gom-verdict à chaque check)

Usage :
    python Python/gom_verdict_poller.py            # toutes les 60s
    python Python/gom_verdict_poller.py --interval 30
    python Python/gom_verdict_poller.py --once      # une seule fois
"""

from __future__ import annotations

import argparse
import json
import logging
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, Optional

import requests

try:
    from gom_path_prediction import apply_path_to_gom_record, infer_tv_setup_from_gom
except ImportError:
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    try:
        from gom_path_prediction import apply_path_to_gom_record, infer_tv_setup_from_gom
    except ImportError:
        apply_path_to_gom_record = None
        infer_tv_setup_from_gom = None

# ─────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────
AI_SERVER_URL = "http://127.0.0.1:8000"
SYMBOL        = "XAUUSD"
MCP_NODE_ROOT = Path(r"D:\Dev\Depot Github\tradingview-mcp_kola")
TV_CLI        = MCP_NODE_ROOT / "src" / "cli" / "index.js"
TV_BAT        = MCP_NODE_ROOT / "scripts" / "launch_tv_debug.bat"
POLL_INTERVAL = 5    # secondes — sync quasi temps réel (surclassé par --interval)

# Ports CDP à tester dans l'ordre
CDP_PORTS_CANDIDATES = [9222, 9223, 9224, 9225, 9229]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-Poller] %(message)s",
    handlers=[
        logging.StreamHandler(open(sys.stdout.fileno(), mode="w", encoding="utf-8", closefd=False)),
        logging.FileHandler("gom_poller.log", encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────
# Détection CDP — trouve le port sur lequel TradingView écoute
# ─────────────────────────────────────────────────────────────

import urllib.request as _urllib_req
import os as _os

# Ne pas relancer TV (avec taskkill) plus souvent que ce délai
_LAUNCH_COOLDOWN_SEC = float(_os.environ.get("GOM_TV_LAUNCH_COOLDOWN_SEC", "300"))
_last_launch_attempt: float = 0.0
_no_auto_launch_tv: bool = False

_active_cdp_port: Optional[int] = None   # mis en cache dès qu'on trouve


def _probe_cdp_port(port: int, timeout: float = 2.0) -> bool:
    """Retourne True si http://localhost:{port}/json/version répond."""
    try:
        with _urllib_req.urlopen(f"http://localhost:{port}/json/version", timeout=timeout) as r:
            return r.status == 200
    except Exception:
        return False


def detect_cdp_port(force: bool = False) -> Optional[int]:
    """
    Cherche le premier port CDP actif parmi CDP_PORTS_CANDIDATES.
    Met le résultat en cache. Retourne None si aucun port répond.
    """
    global _active_cdp_port
    if _active_cdp_port and not force:
        if _probe_cdp_port(_active_cdp_port, timeout=1.5):
            return _active_cdp_port
        # Port mis en cache plus disponible — force re-scan
        _active_cdp_port = None
        log.warning("Port CDP mis en cache ne répond plus — re-scan...")

    for port in CDP_PORTS_CANDIDATES:
        if _probe_cdp_port(port):
            _active_cdp_port = port
            log.info(f"✅ Port CDP TradingView trouvé : {port}")
            return port

    return None


def _auto_launch_tv_enabled() -> bool:
    if _no_auto_launch_tv:
        return False
    v = _os.environ.get("GOM_TV_AUTO_LAUNCH", "1").strip().lower()
    return v not in ("0", "false", "no", "off")


def _tv_process_running() -> bool:
    try:
        proc = subprocess.run(
            ["tasklist", "/FI", "IMAGENAME eq TradingView.exe", "/NH"],
            capture_output=True,
            text=True,
            timeout=8,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        return "TradingView.exe" in (proc.stdout or "")
    except Exception:
        return False


def _find_tradingview_exe() -> Optional[Path]:
    """Préfère la version Microsoft Store (CDP fiable) puis AppData Local."""
    for key in ("GOM_TRADINGVIEW_EXE", "TRADINGVIEW_EXE"):
        raw = _os.environ.get(key, "").strip().strip('"')
        if raw:
            p = Path(raw)
            if p.is_file():
                return p

    pf = _os.environ.get("ProgramFiles", r"C:\Program Files")
    store_root = Path(pf) / "WindowsApps"
    if store_root.is_dir():
        try:
            for exe in sorted(store_root.glob("TradingView*/TradingView.exe")):
                if exe.is_file():
                    return exe
        except OSError:
            pass

    candidates = [
        Path(_os.environ.get("LOCALAPPDATA", "")) / "TradingView" / "TradingView.exe",
        Path(r"C:\Program Files\TradingView\TradingView.exe"),
        Path(r"C:\Program Files (x86)\TradingView\TradingView.exe"),
    ]
    for exe in candidates:
        if exe.is_file():
            return exe
    return None


def _start_tv_cdp_process(exe: Path, port: int) -> None:
    """Démarre TV avec CDP sans hériter stdin/stdout (évite crash ICU Electron)."""
    wd = str(exe.parent)
    ps_cmd = (
        "$psi = New-Object System.Diagnostics.ProcessStartInfo; "
        f"$psi.FileName = '{str(exe).replace(chr(39), chr(39)+chr(39))}'; "
        f"$psi.Arguments = '--remote-debugging-port={port}'; "
        f"$psi.WorkingDirectory = '{wd.replace(chr(39), chr(39)+chr(39))}'; "
        "$psi.UseShellExecute = $true; "
        "[void][System.Diagnostics.Process]::Start($psi)"
    )
    subprocess.Popen(
        ["powershell", "-NoProfile", "-Command", ps_cmd],
        creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _wait_cdp_ready(port: int, attempts: int = 25, delay_sec: float = 2.0) -> bool:
    global _active_cdp_port
    for _ in range(attempts):
        time.sleep(delay_sec)
        if _probe_cdp_port(port):
            _active_cdp_port = port
            log.info(f"✅ TradingView CDP prêt sur port {port}")
            return True
    return False


def _launch_tv_debug(port: int = 9222, *, force_kill: bool = False) -> bool:
    """
    Démarre TradingView en mode CDP.
    Par défaut : ne tue PAS TradingView (évite la fermeture en boucle).
    force_kill=True : utilise launch_tv_debug.bat (taskkill + relance).
    """
    global _last_launch_attempt

    if not _auto_launch_tv_enabled():
        log.warning(
            "Auto-launch TV désactivé. Lance TradingView à la main :\n"
            "  .\\scripts\\Start-TradingViewCDP.ps1\n"
            "  puis vérifie : curl http://localhost:9222/json/version"
        )
        return False

    now = time.time()
    if now - _last_launch_attempt < _LAUNCH_COOLDOWN_SEC:
        left = int(_LAUNCH_COOLDOWN_SEC - (now - _last_launch_attempt))
        log.warning(
            f"Relance TV ignorée (cooldown {left}s). "
            "Si CDP ne répond pas, fermez TV puis lancez scripts\\Start-TradingViewCDP.ps1"
        )
        return _probe_cdp_port(port)

    _last_launch_attempt = now

    if _tv_process_running() and not force_kill:
        log.warning(
            "TradingView est ouvert mais le port CDP %s ne répond pas.\n"
            "   → L'exe dans AppData\\Local ignore souvent --remote-debugging-port.\n"
            "   → Fermez TV, puis : .\\scripts\\Start-TradingViewCDP.ps1\n"
            "   → Ou définissez GOM_TRADINGVIEW_EXE vers la version Microsoft Store.",
            port,
        )
        return False

    exe = _find_tradingview_exe()
    if exe and not force_kill:
        log.info(f"🚀 Lancement TradingView CDP (sans taskkill) : {exe}")
        try:
            _start_tv_cdp_process(exe, port)
        except Exception as e:
            log.error(f"Impossible de lancer TradingView : {e}")
            return False
        if _wait_cdp_ready(port):
            return True
        log.error(
            f"TradingView démarré mais CDP absent sur {port}. "
            "Essayez la version Microsoft Store (WindowsApps) ou Start-TradingViewCDP.ps1"
        )
        return False

    if not TV_BAT.exists():
        log.error(f"Script .bat introuvable : {TV_BAT}")
        return False

    log.info(f"🚀 Lancement via {TV_BAT.name} (ferme les instances TV existantes)...")
    try:
        subprocess.Popen(
            ["cmd", "/c", str(TV_BAT), str(port)],
            cwd=str(MCP_NODE_ROOT),
            creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP,
        )
    except Exception as e:
        log.error(f"Impossible de lancer TradingView : {e}")
        return False

    if _wait_cdp_ready(port, attempts=18):
        return True
    log.error(f"TradingView n'a pas répondu sur le port {port} après ~36s")
    return False


def _ensure_tv_ready() -> Optional[int]:
    """
    Garantit que TradingView est lancé avec CDP.
    Retourne le port actif, ou None si impossible.
    """
    port = detect_cdp_port()
    if port:
        return port

    log.warning("⚠️ Aucun port CDP détecté — TradingView n'est pas en mode debug.")
    if _auto_launch_tv_enabled():
        log.warning("   → Tentative de lancement doux (sans fermer TV)...")
        if _launch_tv_debug(9222, force_kill=False):
            return detect_cdp_port(force=True) or 9222
    log.error("❌ Impossible de démarrer TradingView en mode CDP.")
    log.error("   Lance : .\\scripts\\Start-TradingViewCDP.ps1")
    log.error("   Puis : curl http://localhost:9222/json/version")
    return None


# ─────────────────────────────────────────────────────────────
# Appel CLI Node.js avec CDP_PORT injecté dans l'environnement
# ─────────────────────────────────────────────────────────────

def _run_tv_cli(command: list[str], cdp_port: Optional[int] = None) -> Optional[Dict[str, Any]]:
    """
    Appelle : node src/cli/index.js <commande>
    Injecte CDP_PORT dans l'environnement du subprocess.
    """
    global _active_cdp_port
    port = cdp_port or _active_cdp_port or 9222
    env = {**_os.environ, "CDP_PORT": str(port)}
    try:
        proc = subprocess.run(
            ["node", str(TV_CLI)] + command,
            capture_output=True, text=True, timeout=30,
            cwd=str(MCP_NODE_ROOT),
            env=env,
        )
        stdout = proc.stdout.strip()
        if not stdout:
            stderr_preview = proc.stderr.strip()[:300] if proc.stderr else ""
            log.warning(f"tv {' '.join(command)} — sortie vide. stderr: {stderr_preview}")
            # Si l'erreur est CDP, invalider le cache
            if "CDP connection failed" in stderr_preview or "fetch failed" in stderr_preview:
                _active_cdp_port = None
            return None
        return json.loads(stdout)
    except json.JSONDecodeError as e:
        log.warning(f"tv {' '.join(command)} — JSON invalide: {e}")
        return None
    except Exception as e:
        log.warning(f"tv {' '.join(command)} — erreur: {e}")
        return None


# ─────────────────────────────────────────────────────────────
# Parse des valeurs Pine Script
# ─────────────────────────────────────────────────────────────

def _parse_fr_float(s) -> Optional[float]:
    """Convertit tout format numerique (FR/EN, espaces, virgules) en float.
    Gere le tiret unicode U+2212 (−) retourné par TradingView data_window.
    """
    if s is None:
        return None
    try:
        import re as _re
        # Normaliser le tiret Unicode − (U+2212) en tiret ASCII - avant tout traitement
        text = str(s).replace('−', '-').replace('–', '-').replace('—', '-')
        cleaned = _re.sub(r'[^\d,.\-]', '', text)
        if '.' in cleaned and ',' in cleaned:
            cleaned = cleaned.replace(',', '')
        else:
            cleaned = cleaned.replace(',', '.')
        return float(cleaned) if cleaned else None
    except (ValueError, TypeError):
        return None
def _val_from_study(vals: Dict[str, Any], *keys: str) -> Optional[float]:
    """Cherche une clé plot Pine (data_window) avec alias."""
    for k in keys:
        if k in vals:
            v = _parse_fr_float(vals[k])
            if v is not None:
                return v
        for vk, vv in vals.items():
            if vk.lower() == k.lower():
                v = _parse_fr_float(vv)
                if v is not None:
                    return v
    return None


def _verdict_text_from_num(verdict_num: int) -> str:
    n = int(round(verdict_num))
    if n >= 3:
        return "PERFECT BUY"
    if n == 2:
        return "GOOD BUY"
    if n == 1:
        return "BUY"
    if n == 0:
        return "WAIT"
    if n == -1:
        return "SELL"
    if n == -2:
        return "GOOD SELL"
    if n <= -3:
        return "PERFECT SELL"
    return "WAIT"


def parse_gom_study(raw: Dict[str, Any], symbol: str = SYMBOL) -> Optional[Dict[str, Any]]:
    """
    Lit les plots data_window de GOM_KOLA_SIDO.pine (score_buy, verdict_num, …).
    Fallback : ancien calcul simplifié si plots absents.
    """
    studies_payload = raw.get("studies") or raw
    studies: list = []

    if isinstance(studies_payload, dict):
        studies = studies_payload.get("studies", [])
        if not studies and studies_payload.get("study_count"):
            studies = [studies_payload]
    elif isinstance(studies_payload, list):
        studies = studies_payload

    gom_study = None
    for s in studies:
        name = (s.get("name") or s.get("title") or "").lower()
        if "gom" in name or "kola" in name or "sido" in name:
            gom_study = s
            break

    if not gom_study:
        # Logger les noms d'études disponibles pour aider au diagnostic
        available = [s.get("name") or s.get("title") or "?" for s in studies]
        log.warning(
            "Indicateur GOM KOLA SIDO non trouvé parmi [%s] — "
            "chart TV XAUUSD avec GOM actif ? (TV a peut-être basculé sur un autre tab)",
            ", ".join(available) if available else "aucune étude visible"
        )
        return None

    vals = gom_study.get("values") or gom_study.get("plots") or {}

    score_buy = _val_from_study(vals, "score_buy", "Score Buy", "BUY score")
    score_sell = _val_from_study(vals, "score_sell", "Score Sell", "SELL score")
    verdict_num = _val_from_study(vals, "verdict_num", "verdict_num")
    spike_pct = _val_from_study(vals, "spike_pct", "Spike %", "spike_pct")
    rsi = _val_from_study(vals, "rsi", "RSI")
    st_dir = _val_from_study(vals, "st_dir", "st_dir")
    entry_quality = _val_from_study(vals, "entry_quality", "Quality", "entry_quality")
    coherence_pct = _val_from_study(vals, "coherence_pct", "Coherence", "coherence_pct")
    kola_buy = _val_from_study(vals, "kola_buy", "kola_buy")
    kola_sell = _val_from_study(vals, "kola_sell", "kola_sell")
    verdict_gap = _val_from_study(vals, "verdict_gap", "Force", "verdict_gap")

    vwap = _val_from_study(vals, "vwap", "VWAP")
    bb_up = _val_from_study(vals, "bb_up", "BB Sup")
    bb_mid = _val_from_study(vals, "bb_mid", "BB Mid")
    bb_dn = _val_from_study(vals, "bb_dn", "BB Inf")
    st_line = _val_from_study(vals, "st_line", "Supertrend")

    # TF Global — exportés depuis Pine via plot() data_window
    tf_global_dir_raw = _val_from_study(vals, "tf_global_dir")   # -1/0/1
    tf_global_strength = _val_from_study(vals, "tf_global_strength")  # max(tb,ts) 0-7
    tf_bull_count = _val_from_study(vals, "tf_bull_count")
    tf_bear_count = _val_from_study(vals, "tf_bear_count")
    pred_bull = _val_from_study(vals, "pred_bull", "pred_bull")
    pred_bear = _val_from_study(vals, "pred_bear", "pred_bear")
    pred_neut = _val_from_study(vals, "pred_neut", "pred_neut")
    pred_net = _val_from_study(vals, "pred_net", "pred_net")
    setup_dir = _val_from_study(vals, "setup_dir", "setup_dir")
    setup_entry = _val_from_study(vals, "setup_entry", "setup_entry")
    setup_sl = _val_from_study(vals, "setup_sl", "setup_sl")
    setup_tp1 = _val_from_study(vals, "setup_tp1", "setup_tp1")
    setup_tp2 = _val_from_study(vals, "setup_tp2", "setup_tp2")
    setup_rr = _val_from_study(vals, "setup_rr", "setup_rr")
    setup_confirm_code = _val_from_study(vals, "setup_confirm_code", "setup_confirm_code")
    setup_confirm = ""
    if setup_confirm_code is not None:
        c = int(round(setup_confirm_code))
        if c == 1:
            setup_confirm = "PIN_BAR_BULL"
        elif c == -1:
            setup_confirm = "PIN_BAR_BEAR"
    # Convertir gd (-1/0/1) en label BULL/BEAR/NEUT
    if tf_global_dir_raw is not None:
        _gd = int(round(tf_global_dir_raw))
        tf_global_dir_label = "BULL" if _gd == 1 else "BEAR" if _gd == -1 else "NEUT"
    else:
        tf_global_dir_label = ""
    # Convertir 0-7 votes → 0-100%
    tf_global_strength_pct = int(round((tf_global_strength or 0) / 7.0 * 100))

    quote_payload = raw.get("quote") or {}
    price = None
    if isinstance(quote_payload, dict):
        price = _parse_fr_float(
            str(quote_payload.get("last") or quote_payload.get("close") or 0)
        )

    # ── Mode exact : plots Pine (identique au tableau TV) ──
    if score_buy is not None and score_sell is not None:
        vnum = int(verdict_num) if verdict_num is not None else 0
        verdict = _verdict_text_from_num(vnum)
        gap = verdict_gap if verdict_gap is not None else abs(score_buy - score_sell)
        kola_state = "---"
        if kola_buy and price and abs(price - kola_buy) <= abs(price) * 0.002:
            kola_state = "NEAR BUY"
        elif kola_sell and price and abs(price - kola_sell) <= abs(price) * 0.002:
            kola_state = "NEAR SELL"

        payload = {
            "symbol": symbol,
            "verdict": verdict,
            "verdict_num": vnum,
            "score_buy": round(score_buy, 1),
            "score_sell": round(score_sell, 1),
            "spike_pct": round(spike_pct or 0, 1),
            "rsi": int(rsi or 50),
            "st_dir": int(st_dir or 0),
            "entry_quality": round(entry_quality or 0, 1),
            "coherence_pct": round(coherence_pct or 0, 1),
            "kola_buy": kola_buy or 0,
            "kola_sell": kola_sell or 0,
            "kola_state": kola_state,
            "verdict_gap": round(gap, 2),
            "vwap": vwap,
            "bb_up": bb_up,
            "bb_mid": bb_mid,
            "bb_dn": bb_dn,
            "st_line": st_line,
            "price": price,
            # TF Global — fixe la confiance à 0% dans TradeManager/dashboard
            "tf_global_dir": tf_global_dir_label,
            "tf_global_strength": tf_global_strength_pct,
            "tf_bull_count": int(tf_bull_count or 0),
            "tf_bear_count": int(tf_bear_count or 0),
            "pred_bull": int(pred_bull or 0),
            "pred_bear": int(pred_bear or 0),
            "pred_neut": int(pred_neut or 0),
            "pred_net": int(pred_net or 0),
            "setup_dir": int(setup_dir or 0),
            "setup_entry": setup_entry or 0,
            "setup_sl": setup_sl or 0,
            "setup_tp1": setup_tp1 or 0,
            "setup_tp2": setup_tp2 or 0,
            "setup_rr": setup_rr or 0,
            "setup_type": "OB_BULL" if setup_dir and int(setup_dir) > 0 else ("OB_BEAR" if setup_dir and int(setup_dir) < 0 else ""),
            "setup_confirm": setup_confirm,
            "setup_confirm_code": int(setup_confirm_code or 0),
            "source": "tradingview",
        }
        if infer_tv_setup_from_gom:
            try:
                payload = infer_tv_setup_from_gom(payload)
            except Exception as e:
                log.warning(f"setup infer skipped: {e}")
        if apply_path_to_gom_record:
            try:
                payload = apply_path_to_gom_record(payload)
            except Exception as e:
                log.warning(f"path guide skipped: {e}")
        payload["setup_valid"] = bool(
            int(payload.get("setup_dir") or 0) != 0
            and float(payload.get("setup_entry") or 0) > 0
        )
        return payload

    # ── Fallback ancien calcul ──
    fib_0 = _val_from_study(vals, "fib_0", "Fib 0%")
    f236 = _val_from_study(vals, "fib_236", "Fib 23.6%")
    score_buy = 0.0
    score_sell = 0.0
    st = st_line
    if st and price:
        if price > st:
            score_buy += 1.5
        else:
            score_sell += 1.5
    if vwap and price:
        if price > vwap:
            score_buy += 1.0
        else:
            score_sell += 1.0
    if bb_mid and price:
        if price > bb_mid:
            score_buy += 0.5
        else:
            score_sell += 0.5
    gap = abs(score_buy - score_sell)
    verdict = "WAIT"
    if score_buy > score_sell and gap >= 1.2:
        verdict = "BUY"
    elif score_sell > score_buy and gap >= 1.2:
        verdict = "SELL"
    st_dir_i = 1 if (st and price and price > st) else -1 if st and price else 0

    return {
        "symbol": symbol,
        "verdict": verdict,
        "verdict_num": 1 if verdict == "BUY" else -1 if verdict == "SELL" else 0,
        "score_buy": round(score_buy, 1),
        "score_sell": round(score_sell, 1),
        "spike_pct": 0,
        "vwap": vwap,
        "bb_up": bb_up,
        "bb_mid": bb_mid,
        "bb_dn": bb_dn,
        "st_line": st,
        "st_dir": st_dir_i,
        "fib_0": fib_0,
        "fib_236": f236,
        "price": price,
        "source": "tradingview_fallback",
    }


# ─────────────────────────────────────────────────────────────
# Push vers AI server
# ─────────────────────────────────────────────────────────────

def _persist_gom_signal_file(payload: Dict[str, Any]) -> None:
    """Écrit data/gom_signal.json pour deriv_ea_pro.html (/gom/latest) et MT5."""
    try:
        from datetime import datetime, timezone
        root = Path(__file__).resolve().parents[1]
        out = root / "data" / "gom_signal.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        slim = {
            "symbol": payload.get("symbol", SYMBOL),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "verdict": payload.get("verdict", "WAIT"),
            "verdict_num": payload.get("verdict_num", 0),
            "buy_score": payload.get("score_buy", payload.get("buy_score", 0)),
            "sell_score": payload.get("score_sell", payload.get("sell_score", 0)),
            "spike_pct": payload.get("spike_pct", 0),
            "quality": payload.get("entry_quality", payload.get("quality", 0)),
            "coherence": payload.get("coherence_pct", payload.get("coherence", 0)),
            "kola_state": payload.get("kola_state", "---"),
            "rsi": payload.get("rsi"),
            "st_direction": "UP" if payload.get("st_dir", 0) == 1 else "DN",
            "verdict_gap": payload.get("verdict_gap"),
            "tf_global_dir": payload.get("tf_global_dir"),
            "tf_bull_count": payload.get("tf_bull_count"),
            "tf_bear_count": payload.get("tf_bear_count"),
            "pred_bull": payload.get("pred_bull"),
            "pred_bear": payload.get("pred_bear"),
            "pred_neut": payload.get("pred_neut"),
            "pred_net": payload.get("pred_net"),
            "setup_type": payload.get("setup_type"),
            "setup_confirm": payload.get("setup_confirm"),
            "setup_entry": payload.get("setup_entry"),
            "setup_sl": payload.get("setup_sl"),
            "setup_tp1": payload.get("setup_tp1"),
            "setup_tp2": payload.get("setup_tp2"),
            "setup_rr": payload.get("setup_rr"),
            "setup_dir": payload.get("setup_dir"),
        }
        out.write_text(json.dumps(slim, indent=2), encoding="utf-8")
    except Exception as e:
        log.warning("gom_signal.json: %s", e)


def push_gom_verdict(payload: Dict[str, Any]) -> bool:
    try:
        r = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=payload,
            timeout=10,   # 10s — POST rapide via BackgroundTasks (ne plus bloquer)
        )
        if r.ok and r.json().get("ok"):
            log.info(
                f"✅ /gom-verdict OK → {payload['symbol']} "
                f"verdict={payload['verdict']} "
                f"buy={payload['score_buy']} sell={payload['score_sell']} "
                f"prix={payload.get('price')}"
            )
            return True
        log.error(f"❌ /gom-verdict HTTP {r.status_code}: {r.text[:200]}")
        return False
    except Exception as e:
        log.error(f"❌ Push /gom-verdict: {e}")
        return False


# ─────────────────────────────────────────────────────────────
# Lecture TV : CLI Node.js avec port CDP injecté
# ─────────────────────────────────────────────────────────────

def _ensure_tv_m1(cdp_port: Optional[int]) -> None:
    """Ramène le graphique TradingView actif sur M1."""
    try:
        _run_tv_cli(["timeframe", "1"], cdp_port=cdp_port)
        log.debug("TV timeframe → M1")
    except Exception:
        pass


def _refocus_tv_chart(cdp_port: Optional[int]) -> None:
    """Force TradingView à revenir sur XAUUSD — best-effort."""
    try:
        result = _run_tv_cli(["chart", "set-symbol", "OANDA:XAUUSD"], cdp_port=cdp_port)
        if result:
            log.info("🔄 Re-focus TV sur OANDA:XAUUSD OK")
    except Exception:
        pass


def _read_via_mcp_bridge() -> Optional[Dict[str, Any]]:
    """
    Lit les study values via le MCP TradingView (kola) directement depuis Python.
    Plus fiable que le CLI Node — lit directement le chart actif.
    """
    try:
        # Appel direct à l'endpoint MCP via l'AI server bridge
        import requests as _req
        # Essai 1 : endpoint bridge dédié
        r = _req.post(f"{AI_SERVER_URL}/bridge/mcp-study-values",
                      json={"study_filter": "GOM"}, timeout=15)
        if r.status_code == 200:
            return r.json()
        # Essai 2 : endpoint watchlist scan qui appelle le MCP
        r2 = _req.post(f"{AI_SERVER_URL}/bridge/mcp-watchlist-scan",
                       json={"symbols": ["XAUUSD"]}, timeout=30)
        if r2.status_code == 200:
            data = r2.json()
            # Extraire les study values si présentes
            studies = data.get("studies") or data.get("all_results")
            if studies:
                return {"studies": studies, "success": True}
    except Exception as e:
        log.debug(f"MCP bridge non disponible: {e}")
    return None


def read_and_push(symbol: str = SYMBOL) -> bool:
    """
    1. Vérifie que TradingView est actif en mode CDP (lance si besoin).
    2. Lit study values via MCP bridge (prioritaire) ou CLI Node.js.
    3. Pousse le verdict vers /gom-verdict.
    Retry une fois si GOM absent (re-focus TV).
    """
    # ── Étape 1 : s'assurer que CDP est disponible ──
    cdp_port = _ensure_tv_ready()
    if not cdp_port:
        log.error(
            "❌ TradingView CDP introuvable — lance TradingView via :\n"
            f"   {TV_BAT}\n"
            "   ou : TradingView.exe --remote-debugging-port=9222"
        )
        return False

    _ensure_tv_m1(cdp_port)

    # ── Étape 2 : lire les données — MCP bridge prioritaire ──
    # Essayer d'abord via MCP bridge (données directes du chart actif, plus fiables)
    mcp_data = _read_via_mcp_bridge()
    if mcp_data:
        log.debug("✅ Données via MCP bridge")
        quote_raw = _run_tv_cli(["quote"], cdp_port=cdp_port) or {}
        combined  = {"studies": mcp_data, "quote": quote_raw, "success": True}
        payload = parse_gom_study(combined, symbol=symbol)
        if payload:
            _persist_gom_signal_file(payload)
            ok = push_gom_verdict(payload)
            log.info(f"✅ MCP bridge → verdict={payload['verdict']} buy={payload['score_buy']} sell={payload['score_sell']}")
            return ok

    # Fallback : CLI Node.js (2 essais)
    for attempt in range(2):
        studies_raw = _run_tv_cli(["values"], cdp_port=cdp_port)
        if not studies_raw:
            log.warning(
                "⚠️ 'tv values' a échoué.\n"
                f"   Port CDP : {cdp_port} — TradingView ouvert avec GOM KOLA SIDO visible ?"
            )
            if attempt == 0:
                detect_cdp_port(force=True)
            return False

        quote_raw = _run_tv_cli(["quote"], cdp_port=cdp_port)
        combined  = {"studies": studies_raw, "quote": quote_raw or {}, "success": True}

        payload = parse_gom_study(combined, symbol=symbol)
        if payload:
            _persist_gom_signal_file(payload)
            ok = push_gom_verdict(payload)
            _ensure_tv_m1(cdp_port)
            return ok

        # GOM absent — re-focus TV sur XAUUSD + retry
        if attempt == 0:
            log.info("⟳ GOM absent — re-focus TV sur XAUUSD puis retry...")
            _refocus_tv_chart(cdp_port)
            time.sleep(2)

    _ensure_tv_m1(cdp_port)
    return False


# ─────────────────────────────────────────────────────────────
# Point d'entrée
# ─────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Poller GOM KOLA → /gom-verdict sans webhook payant"
    )
    parser.add_argument(
        "--interval", type=int, default=POLL_INTERVAL,
        help=f"Intervalle entre lectures en secondes (défaut={POLL_INTERVAL})"
    )
    parser.add_argument(
        "--once", action="store_true",
        help="Lire une seule fois et quitter"
    )
    parser.add_argument(
        "--symbol", type=str, default=SYMBOL,
        help="Symbole MT5/TV pour le store serveur (ex. XAUUSD, XAUEUR)"
    )
    parser.add_argument(
        "--no-launch-tv", action="store_true",
        help="Ne jamais lancer/relancer TradingView (CDP doit déjà être actif)",
    )
    parser.add_argument(
        "--force-relaunch-tv", action="store_true",
        help="Utilise launch_tv_debug.bat (taskkill) si CDP absent",
    )
    args = parser.parse_args()
    global _no_auto_launch_tv
    _no_auto_launch_tv = bool(args.no_launch_tv)
    sym = args.symbol.upper().strip()
    if sym == "XAUEUR":
        sym = "XAUUSD"

    if args.once:
        success = read_and_push(sym)
        sys.exit(0 if success else 1)

    log.info(f"🚀 GOM Poller démarré — {sym} — intervalle {args.interval}s")
    log.info(f"   Flux: TradingView CDP → /gom-verdict → TradeManager MT5")

    # Diagnostic CDP au démarrage
    port = detect_cdp_port()
    if port:
        log.info(f"✅ TradingView CDP détecté sur port {port} — prêt.")
    else:
        log.warning(
            "⚠️  TradingView n'est PAS en mode CDP.\n"
            "   → .\\scripts\\Start-TradingViewCDP.ps1\n"
            "   → curl http://localhost:9222/json/version\n"
            "   Le poller ne fermera plus TV en boucle ; relance douce au prochain poll."
        )
    if args.force_relaunch_tv and not port:
        _launch_tv_debug(9222, force_kill=True)
        port = detect_cdp_port(force=True)
        if port:
            log.info(f"✅ CDP actif sur port {port} après force-relaunch.")

    while True:
        try:
            read_and_push(sym)
        except KeyboardInterrupt:
            log.info("⏹️ Arrêt")
            break
        except Exception as e:
            log.error(f"❌ Erreur inattendue: {e}")
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
