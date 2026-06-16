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
    POST /gom-verdict  (ai_server local :8000)
        ↓
    SMC_Universal.mq5  (GET /gom-verdict + /pending-order via SMC_GOM_Pipeline.mqh)

Usage :
    python python/gom_verdict_poller.py            # suit SMC_Universal (heartbeat MT5)
    python python/gom_verdict_poller.py --symbol "Boom 500 Index"  # symbole fixe
    python python/gom_verdict_poller.py --once
"""

from __future__ import annotations

import argparse
import json
import logging
import math
import subprocess
import sys
import time
import traceback
from pathlib import Path
from typing import Any, Dict, Optional

import requests

_TRADBOT_ROOT = Path(__file__).resolve().parent.parent
if str(_TRADBOT_ROOT) not in sys.path:
    sys.path.insert(0, str(_TRADBOT_ROOT))
from symbol_mapper import resolve_mt5_symbol, mt5_to_tv_cdp_ticker

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

_last_tv_ticker: Optional[str] = None
_TV_SWITCH_PAUSE_SEC = 2.5


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
    """Préfère 31178TradingViewInc (Store) — CDP fiable. Évite TradingView.Desktop en doublon."""
    for key in ("GOM_TRADINGVIEW_EXE", "TRADINGVIEW_EXE"):
        raw = _os.environ.get(key, "").strip().strip('"')
        if raw:
            p = Path(raw)
            if p.is_file():
                return p

    try:
        proc = subprocess.run(
            [
                "powershell", "-NoProfile", "-Command",
                "Get-AppxPackage *TradingView* | "
                "Where-Object { $_.InstallLocation } | "
                "Sort-Object { if ($_.Name -eq '31178TradingViewInc.TradingView') {0} else {1} }, "
                "{ [version]$_.Version } -Descending | "
                "ForEach-Object { Join-Path $_.InstallLocation 'TradingView.exe' } | "
                "Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1",
            ],
            capture_output=True,
            text=True,
            timeout=15,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        line = (proc.stdout or "").strip().splitlines()
        if line and line[0]:
            p = Path(line[0].strip())
            if p.is_file():
                return p
    except Exception:
        pass

    pf = _os.environ.get("ProgramFiles", r"C:\Program Files")
    store_root = Path(pf) / "WindowsApps"
    if store_root.is_dir():
        try:
            preferred = list(store_root.glob("31178TradingViewInc.TradingView*/TradingView.exe"))
            if preferred:
                return preferred[0]
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
    exe_esc = str(exe).replace("'", "''")
    wd_esc = wd.replace("'", "''")
    ps_cmd = (
        f"Start-Process -FilePath '{exe_esc}' "
        f"-ArgumentList '--remote-debugging-port={port}' "
        f"-WorkingDirectory '{wd_esc}'"
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


def _safe_int(v, default: int = 0) -> int:
    """int() safe against infinity/NaN from Pine Script outputs."""
    if v is None:
        return default
    try:
        f = float(v)
        if not math.isfinite(f):
            return default
        return int(round(f))
    except (ValueError, TypeError, OverflowError):
        return default


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
            if v is not None and math.isfinite(v):
                return v
        for vk, vv in vals.items():
            if vk.lower() == k.lower():
                v = _parse_fr_float(vv)
                if v is not None and math.isfinite(v):
                    return v
    return None


def apply_spike_bc_override(payload: Dict[str, Any], vals: Dict[str, Any]) -> Dict[str, Any]:
    """Enrichit les métadonnées spike Boom/Crash depuis les plots Pine (sans écraser le verdict GOM)."""
    imminence = _val_from_study(vals, "imminence_pct", "imminence_pct")
    spike_level = _val_from_study(vals, "spike_level", "spike_level")
    pre_spike = _val_from_study(vals, "pre_spike_pct", "pre_spike_pct")
    spike_progress = _val_from_study(vals, "spike_progress_pct", "spike_progress_pct")
    bars_since = _val_from_study(vals, "bars_since_spike", "bars_since_spike")
    spike_freq = _val_from_study(vals, "spike_freq_bars", "spike_freq_bars")
    spike_trad = _val_from_study(vals, "spike_tradable", "spike_tradable")

    if spike_level is not None:
        payload["spike_level"] = _safe_int(spike_level)
    if imminence is not None:
        payload["imminence_pct"] = round(imminence, 1)
    if pre_spike is not None:
        payload["pre_spike_pct"] = round(pre_spike, 1)
    if spike_progress is not None:
        payload["spike_progress_pct"] = round(spike_progress, 1)
    if bars_since is not None:
        payload["bars_since_spike"] = _safe_int(bars_since)
    if spike_freq is not None:
        payload["spike_freq_bars"] = _safe_int(spike_freq)
    payload["spike_tradable"] = spike_trad is not None and _safe_int(spike_trad) >= 1
    return payload


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
    symbol = resolve_mt5_symbol(symbol)
    studies_payload = raw.get("studies") or raw
    studies: list = []

    if isinstance(studies_payload, dict):
        studies = studies_payload.get("studies", [])
        if not studies and studies_payload.get("study_count"):
            studies = [studies_payload]
    elif isinstance(studies_payload, list):
        studies = studies_payload

    gom_study = None
    ghost_study = None
    for s in studies:
        name = (s.get("name") or s.get("title") or "").lower()
        if "gom" in name or "kola" in name or "sido" in name:
            gom_study = s
        elif "ghost" in name:
            ghost_study = s

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
    ghost_vals = (ghost_study.get("values") or ghost_study.get("plots") or {}) if ghost_study else {}

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
    spike_tradable_raw = _val_from_study(vals, "spike_tradable", "spike_tradable")
    imminence_pct = _val_from_study(vals, "imminence_pct", "imminence_pct")
    spike_level_raw = _val_from_study(vals, "spike_level", "spike_level")
    pre_spike_pct = _val_from_study(vals, "pre_spike_pct", "pre_spike_pct")
    spike_progress_pct = _val_from_study(vals, "spike_progress_pct", "spike_progress_pct")
    bars_since_spike = _val_from_study(vals, "bars_since_spike", "bars_since_spike")
    spike_freq_bars = _val_from_study(vals, "spike_freq_bars", "spike_freq_bars")
    ob_bull_top = _val_from_study(vals, "ob_bull_top")
    ob_bull_bot = _val_from_study(vals, "ob_bull_bot")
    ob_bear_top = _val_from_study(vals, "ob_bear_top")
    ob_bear_bot = _val_from_study(vals, "ob_bear_bot")

    # GHOST OrderFlow — indicateur séparé "GHOST — OrderFlow Intelligence"
    ghost_delta   = _val_from_study(ghost_vals, "ghost_delta")
    ghost_cvd     = _val_from_study(ghost_vals, "ghost_cvd")
    ghost_buypct  = _val_from_study(ghost_vals, "ghost_buypct")
    ghost_compass = _val_from_study(ghost_vals, "ghost_compass")

    setup_confirm = ""
    if setup_confirm_code is not None:
        c = _safe_int(setup_confirm_code)
        if c == 1:
            setup_confirm = "PIN_BAR_BULL"
        elif c == -1:
            setup_confirm = "PIN_BAR_BEAR"
    # Convertir gd (-1/0/1) en label BULL/BEAR/NEUT
    if tf_global_dir_raw is not None:
        _gd = _safe_int(tf_global_dir_raw)
        tf_global_dir_label = "BULL" if _gd == 1 else "BEAR" if _gd == -1 else "NEUT"
    else:
        tf_global_dir_label = ""
    # Convertir 0-7 votes → 0-100%
    _str_raw = float(tf_global_strength or 0)
    tf_global_strength_pct = _safe_int(_str_raw / 7.0 * 100 if math.isfinite(_str_raw) else 0)

    quote_payload = raw.get("quote") or {}
    price = None
    if isinstance(quote_payload, dict):
        price = _parse_fr_float(
            str(quote_payload.get("last") or quote_payload.get("close") or 0)
        )

    # ── Mode exact : plots Pine (identique au tableau TV) ──
    if score_buy is not None and score_sell is not None:
        vnum = _safe_int(verdict_num)
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
            "rsi": _safe_int(rsi, 50),
            "st_dir": _safe_int(st_dir),
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
            # TF Global — fixe la confiance à 0% dans le dashboard SMC_Universal
            "tf_global_dir": tf_global_dir_label,
            "tf_global_strength": tf_global_strength_pct,
            "tf_bull_count": _safe_int(tf_bull_count),
            "tf_bear_count": _safe_int(tf_bear_count),
            "pred_bull": _safe_int(pred_bull),
            "pred_bear": _safe_int(pred_bear),
            "pred_neut": _safe_int(pred_neut),
            "pred_net": _safe_int(pred_net),
            "setup_dir": _safe_int(setup_dir),
            "setup_entry": setup_entry or 0,
            "setup_sl": setup_sl or 0,
            "setup_tp1": setup_tp1 or 0,
            "setup_tp2": setup_tp2 or 0,
            "setup_rr": setup_rr or 0,
            "setup_type": "OB_BULL" if setup_dir and _safe_int(setup_dir) > 0 else ("OB_BEAR" if setup_dir and _safe_int(setup_dir) < 0 else ""),
            "setup_confirm": setup_confirm,
            "setup_confirm_code": _safe_int(setup_confirm_code),
            "ob_bull_top": ob_bull_top or 0,
            "ob_bull_bot": ob_bull_bot or 0,
            "ob_bear_top": ob_bear_top or 0,
            "ob_bear_bot": ob_bear_bot or 0,
            "source": "tradingview",
            # GHOST OrderFlow — None si indicateur absent du chart
            "ghost_delta":   round(ghost_delta,   2) if ghost_delta   is not None else None,
            "ghost_cvd":     round(ghost_cvd,     2) if ghost_cvd     is not None else None,
            "ghost_buypct":  round(ghost_buypct,  1) if ghost_buypct  is not None else None,
            "ghost_compass": round(ghost_compass, 1) if ghost_compass is not None else None,
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
        payload = apply_spike_bc_override(payload, vals)
        payload["setup_valid"] = bool(
            _safe_int(payload.get("setup_dir")) != 0
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
    """
    Accumule data/gom_signal.json par symbole pour support multi-symbole MT5.
    Format: {"XAUUSD": {...}, "Boom 500 Index": {...}}
    """
    try:
        from datetime import datetime, timezone
        root = Path(__file__).resolve().parents[1]
        out = root / "data" / "gom_signal.json"
        out.parent.mkdir(parents=True, exist_ok=True)

        # Créer l'objet pour ce symbole
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
            "spike_tradable": payload.get("spike_tradable"),
            "imminence_pct": payload.get("imminence_pct"),
            "spike_level": payload.get("spike_level"),
            "pre_spike_pct": payload.get("pre_spike_pct"),
            "spike_progress_pct": payload.get("spike_progress_pct"),
            "bars_since_spike": payload.get("bars_since_spike"),
            "spike_freq_bars": payload.get("spike_freq_bars"),
            "bb_up": payload.get("bb_up", 0.0),
            "bb_mid": payload.get("bb_mid", 0.0),
            "bb_dn": payload.get("bb_dn", 0.0),
            "kola_buy": payload.get("kola_buy", 0.0),
            "kola_sell": payload.get("kola_sell", 0.0),
        }

        # Charger les données existantes (dict par symbole)
        existing = {}
        if out.is_file():
            try:
                existing = json.loads(out.read_text(encoding="utf-8"))
                if not isinstance(existing, dict):
                    existing = {}
            except Exception:
                existing = {}

        # Accumuler par symbole
        symbol_key = slim.get("symbol", "UNKNOWN")
        existing[symbol_key] = slim

        # Écrire le dict accumulé
        out.write_text(json.dumps(existing, indent=2), encoding="utf-8")
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

def _mt5_tf_to_tv_cli(chart_tf: str) -> str:
    return {
        "M1": "1", "M5": "5", "M15": "15", "M30": "30",
        "H1": "60", "H4": "240", "D1": "D", "W1": "W",
    }.get((chart_tf or "M15").upper(), "15")


def _ensure_tv_chart_tf(cdp_port: Optional[int], chart_tf: str = "M15") -> None:
    """Aligne le graphique TradingView sur le TF du graphique MT5 (heartbeat)."""
    try:
        tf = _mt5_tf_to_tv_cli(chart_tf)
        _run_tv_cli(["timeframe", tf], cdp_port=cdp_port)
        log.debug("TV timeframe → %s (MT5 %s)", tf, chart_tf)
    except Exception:
        pass


def _ensure_tv_m1(cdp_port: Optional[int]) -> None:
    """Compat — délègue au TF heartbeat."""
    _ensure_tv_chart_tf(cdp_port, "M15")


def _switch_tv_to_mt5_symbol(mt5_symbol: str, cdp_port: Optional[int]) -> str:
    """Bascule le graphique TV sur le symbole MT5 (mapping orthographe MT5/TV)."""
    global _last_tv_ticker
    canon = resolve_mt5_symbol(mt5_symbol)
    tv_ticker = mt5_to_tv_cdp_ticker(canon)
    if tv_ticker == _last_tv_ticker:
        return tv_ticker
    try:
        result = _run_tv_cli(["symbol", tv_ticker], cdp_port=cdp_port)
        if result is not None:
            log.info("TV chart -> %s (MT5: %s)", tv_ticker, canon)
            time.sleep(_TV_SWITCH_PAUSE_SEC)
            _last_tv_ticker = tv_ticker
    except Exception as e:
        log.warning("set-symbol %s: %s", tv_ticker, e)
    return tv_ticker


def fetch_poll_targets() -> Optional[Dict[str, Any]]:
    """Lit /gom/poll-targets — symbole prioritaire envoyé par SMC_Universal."""
    try:
        r = requests.get(f"{AI_SERVER_URL}/gom/poll-targets", timeout=5)
        if r.ok:
            data = r.json()
            if data.get("ok"):
                return data
    except Exception as e:
        log.debug("poll-targets: %s", e)
    return None


def resolve_poll_symbol(fixed_symbol: Optional[str], follow_mt5: bool) -> str:
    """Symbole à poller : fixe (--symbol) ou heartbeat MT5 (--follow-mt5)."""
    if fixed_symbol:
        return resolve_mt5_symbol(fixed_symbol)
    if follow_mt5:
        data = fetch_poll_targets()
        primary = (data or {}).get("primary")
        if primary:
            raw = primary.get("mt5_raw") or primary.get("mt5_canon") or primary.get("symbol")
            if raw:
                sym = resolve_mt5_symbol(str(raw))
                log.debug("Follow MT5: %s (TV %s)", sym, primary.get("tv_ticker"))
                return sym
    return "XAUUSD"


def _read_via_mcp_bridge(symbol: str = SYMBOL) -> Optional[Dict[str, Any]]:
    """
    Lit les study values GOM depuis /bridge/mcp-study-values (store en mémoire AI server).
    Ne retourne des données que si le store contient un verdict récent (< 5 min).
    """
    try:
        import requests as _req
        r = _req.post(f"{AI_SERVER_URL}/bridge/mcp-study-values",
                      json={"symbol": resolve_mt5_symbol(symbol)}, timeout=10)
        if r.status_code != 200:
            return None
        data = r.json()
        if not data.get("success"):
            return None
        # Vérifier fraîcheur du timestamp (< 60s) — timezone-aware
        ts = data.get("timestamp")
        if ts:
            try:
                from datetime import datetime, timezone, timedelta
                ts_str = ts.replace("Z", "+00:00")
                ts_dt = datetime.fromisoformat(ts_str)
                # Normaliser en UTC: si naïf, supposer heure locale (UTC+1/+2)
                if ts_dt.tzinfo is None:
                    import time as _time
                    utc_offset = timedelta(seconds=-_time.timezone)
                    ts_dt = ts_dt.replace(tzinfo=timezone(utc_offset))
                age = (datetime.now(timezone.utc) - ts_dt).total_seconds()
                if age > 60:
                    log.debug(f"MCP bridge stale ({int(age)}s) — ignorer, forcer lecture CLI directe")
                    return None
            except Exception:
                pass
        studies = data.get("studies", [])
        if not studies:
            return None
        return {"studies": studies, "success": True}
    except Exception as e:
        log.debug(f"MCP bridge non disponible: {e}")
    return None


def _read_via_mcp_reader_mjs(cdp_port: Optional[int] = None) -> Optional[Dict[str, Any]]:
    """
    Lit les study values directement via gom_mcp_reader.mjs (appel MCP natif).
    Contourne le CLI Node index.js dont les études retournent un nom vide/?.
    """
    mjs_path = Path(__file__).parent / "gom_mcp_reader.mjs"
    if not mjs_path.exists():
        return None
    port = cdp_port or _active_cdp_port or 9222
    env = {**_os.environ, "CDP_PORT": str(port)}
    try:
        proc = subprocess.run(
            ["node", str(mjs_path)],
            capture_output=True, text=True, timeout=20,
            cwd=str(Path(__file__).parent),
            env=env,
        )
        stdout = proc.stdout.strip()
        if not stdout:
            return None
        data = json.loads(stdout)
        if not data.get("success"):
            return None
        return data
    except Exception as e:
        log.debug(f"gom_mcp_reader.mjs: {e}")
    return None


def read_and_push(symbol: str = SYMBOL) -> bool:
    """
    1. Vérifie que TradingView est actif en mode CDP (lance si besoin).
    2. Bascule TV sur le symbole MT5 (mapping Boom_500_Index etc.).
    3. Lit study values via MCP bridge (prioritaire) ou CLI Node.js.
    4. Pousse le verdict vers /gom-verdict.
    Retry une fois si GOM absent (re-focus TV).
    """
    symbol = resolve_mt5_symbol(symbol)

    # ── Étape 1 : s'assurer que CDP est disponible ──
    cdp_port = _ensure_tv_ready()
    if not cdp_port:
        log.error(
            "❌ TradingView CDP introuvable — lance TradingView via :\n"
            f"   {TV_BAT}\n"
            "   ou : TradingView.exe --remote-debugging-port=9222"
        )
        return False

    targets = fetch_poll_targets()
    chart_tf = "M15"
    if targets and targets.get("primary"):
        chart_tf = targets["primary"].get("chart_tf") or chart_tf

    _switch_tv_to_mt5_symbol(symbol, cdp_port)
    _ensure_tv_chart_tf(cdp_port, chart_tf)

    # ── Étape 2a : lire via gom_mcp_reader.mjs (MCP natif, plus fiable que CLI) ──
    mjs_data = _read_via_mcp_reader_mjs(cdp_port)
    if mjs_data:
        payload = parse_gom_study(mjs_data, symbol=symbol)
        if payload:
            _persist_gom_signal_file(payload)
            ok = push_gom_verdict(payload)
            log.info(f"✅ MJS reader → verdict={payload['verdict']} buy={payload['score_buy']} sell={payload['score_sell']}")
            return ok

    # ── Étape 2b : lire les données — MCP bridge (store en mémoire, frais < 5 min) ──
    mcp_data = _read_via_mcp_bridge(symbol)
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
            _ensure_tv_chart_tf(cdp_port, chart_tf)
            return ok

        # GOM absent — re-bascule TV sur le symbole MT5 + retry
        if attempt == 0:
            log.info("GOM absent — re-bascule TV sur %s puis retry...", symbol)
            global _last_tv_ticker
            _last_tv_ticker = None
            _switch_tv_to_mt5_symbol(symbol, cdp_port)
            time.sleep(2)

    _ensure_tv_chart_tf(cdp_port, chart_tf)
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
        "--symbol", type=str, default=None,
        help="Symbole MT5 fixe (ex. 'Boom 500 Index'). Omis = suit SMC_Universal via heartbeat.",
    )
    parser.add_argument(
        "--follow-mt5", action="store_true", default=True,
        help="Suit le symbole du graphique SMC_Universal (defaut: actif)",
    )
    parser.add_argument(
        "--no-follow-mt5", dest="follow_mt5", action="store_false",
        help="Ne pas suivre MT5 — utiliser XAUUSD ou --symbol",
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
    fixed_sym = resolve_mt5_symbol(args.symbol) if args.symbol else None

    if args.once:
        sym = resolve_poll_symbol(fixed_sym, args.follow_mt5)
        success = read_and_push(sym)
        sys.exit(0 if success else 1)

    mode = f"fixe={fixed_sym}" if fixed_sym else ("follow MT5" if args.follow_mt5 else "XAUUSD")
    log.info("GOM Poller demarre — mode %s — intervalle %ss", mode, args.interval)
    log.info("   Flux: TV CDP -> /gom-verdict -> SMC_Universal (symbole auto MT5/TV)")

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
            sym = resolve_poll_symbol(fixed_sym, args.follow_mt5)
            read_and_push(sym)
        except KeyboardInterrupt:
            log.info("⏹️ Arrêt")
            break
        except Exception as e:
            log.error(f"❌ Erreur inattendue: {e}\n{traceback.format_exc()}")
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
