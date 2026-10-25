"""
journal_advisor.py — Conseiller basé sur le journal de trades de l'EA (v1.36)

L'EA (SMC_Universal.mq5 v1.35+) écrit chaque trade fermé dans SMC_TradeJournal.csv
(dossier MetaTrader Common\\Files) avec le contexte d'ouverture : verdict GOM,
direction des timeframes, ER, heure, spread, et le résultat.

Ce module lit ce journal, mesure l'espérance de gain par situation, puis répond à
l'EA, AVANT chaque entrée : « GET /journal/decision?symbol=..&side=..&er=.. »
  → {"allow": true|false, "reason": "...", ...}

v1.37 : et, UNE fois à l'ouverture de chaque position : « GET /journal/manage?... »
  → {"tighten": true|false, "why": "..."} : true = la situation d'entrée a une espérance
  négative prouvée, l'EA resserre alors les gardes de GAIN (peak-lock, stagnation) de cette
  position. Il ne relâche jamais rien et ne touche à aucune coupe de PERTE.

Principes (pour ne pas remplacer une intuition par du bruit) :
  * Apprentissage : tant qu'un symbole a moins de JOURNAL_MIN_TOTAL_TRADES trades
    dans la fenêtre, tout est autorisé.
  * Un veto exige assez de trades dans la situation (JOURNAL_MIN_BUCKET_TRADES) ET
    que l'espérance soit NÉGATIVE avec confiance : moyenne + Z x erreur-type < 0
    (Z = 1.64 ≈ 95 % unilatéral). Sinon : autorisé.
  * Fenêtre glissante (JOURNAL_WINDOW_DAYS) : une situation vétoée ne l'est pas
    pour toujours — ses vieux trades sortent de la fenêtre et elle est retestée.
  * Toute erreur (fichier absent, illisible...) = ENTRÉE AUTORISÉE (fail-open).
  * Mode « shadow » : calcule et journalise sans jamais bloquer.

Variables d'environnement (toutes optionnelles) :
  SMC_JOURNAL_PATH / TRADBOT_JOURNAL_CSV  chemin du CSV
    (défaut : %APPDATA%\\MetaQuotes\\Terminal\\Common\\Files\\TradBOT\\trade_journal.csv)
  JOURNAL_ADVISOR_ENABLED       true|false          (défaut true)
  JOURNAL_ADVISOR_MODE          enforce|shadow      (défaut enforce)
  JOURNAL_MIN_TOTAL_TRADES      défaut 30
  JOURNAL_MIN_BUCKET_TRADES     défaut 25
  JOURNAL_VETO_Z                défaut 1.64
  JOURNAL_WINDOW_DAYS           défaut 21
  JOURNAL_MAX_TRADES_PER_SYMBOL défaut 400
"""
import csv
import math
import os
import threading
import time
from collections import defaultdict, deque
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple


def _env_bool(name: str, default: bool) -> bool:
    v = os.getenv(name)
    if v is None:
        return default
    return v.strip().lower() in ("1", "true", "yes", "on")


def _env_num(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, "") or default)
    except ValueError:
        return default


ENABLED = _env_bool("JOURNAL_ADVISOR_ENABLED", True)
MODE = (os.getenv("JOURNAL_ADVISOR_MODE", "enforce") or "enforce").strip().lower()
MIN_TOTAL = int(_env_num("JOURNAL_MIN_TOTAL_TRADES", 30))
MIN_BUCKET = int(_env_num("JOURNAL_MIN_BUCKET_TRADES", 25))
VETO_Z = _env_num("JOURNAL_VETO_Z", 1.64)
WINDOW_DAYS = int(_env_num("JOURNAL_WINDOW_DAYS", 21))
MAX_PER_SYMBOL = int(_env_num("JOURNAL_MAX_TRADES_PER_SYMBOL", 400))
RELOAD_MIN_INTERVAL_S = 10.0


def journal_path() -> str:
    for env in ("SMC_JOURNAL_PATH", "TRADBOT_JOURNAL_CSV"):
        p = os.getenv(env, "").strip()
        if p:
            return p
    appdata = os.environ.get("APPDATA", "")
    candidates: List[str] = []
    if appdata:
        common = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files")
        candidates.extend([
            os.path.join(common, "TradBOT", "trade_journal.csv"),
            os.path.join(common, "SMC_TradeJournal.csv"),
            os.path.join(common, "TradBOT", "daily"),  # dir — handled below
        ])
    # repo fallbacks
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    candidates.extend([
        os.path.join(root, "data", "trade_journal.csv"),
        os.path.join(os.getcwd(), "TradBOT", "trade_journal.csv"),
        os.path.join(os.getcwd(), "SMC_TradeJournal.csv"),
    ])
    for cand in candidates:
        if os.path.isfile(cand):
            return cand
    # daily folder: pick newest trade_journal_YYYY-MM-DD.csv
    if appdata:
        daily = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files", "TradBOT", "daily")
        if os.path.isdir(daily):
            files = sorted(
                (f for f in os.listdir(daily) if f.startswith("trade_journal_") and f.endswith(".csv")),
                reverse=True,
            )
            if files:
                return os.path.join(daily, files[0])
    return os.path.join(appdata or os.getcwd(), "MetaQuotes", "Terminal", "Common", "Files",
                        "TradBOT", "trade_journal.csv") if appdata else os.path.join(os.getcwd(), "trade_journal.csv")


# ── Parsing ──────────────────────────────────────────────────────────────────
def _num(x: Any, default: float = 0.0) -> float:
    try:
        return float(str(x).strip().replace(",", "."))
    except (TypeError, ValueError):
        return default


def _dt(s: str) -> Optional[datetime]:
    raw = str(s or "").strip()
    if not raw:
        return None
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y.%m.%d", "%Y-%m-%d"):
        try:
            return datetime.strptime(raw[:19] if len(raw) >= 19 and " " in raw else raw, fmt)
        except ValueError:
            continue
    return None


def _norm_sym(s: str) -> str:
    return "".join(str(s or "").upper().split())


def _detect_delimiter(sample: str) -> str:
    # EA TradeJournal = comma ; ancien format = semicolon
    if sample.count(";") > sample.count(","):
        return ";"
    return ","


def _parse_rows(path: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    with open(path, "r", newline="", encoding="utf-8", errors="replace") as fh:
        head = fh.read(4096)
        fh.seek(0)
        delim = _detect_delimiter(head)
        for r in csv.DictReader(fh, delimiter=delim):
            sym = (r.get("symbol") or "").strip()
            if not sym or sym.lower() == "symbol":
                continue
            close_raw = r.get("close_time_full") or r.get("close_time") or ""
            open_raw = r.get("open_time") or ""
            close_dt = _dt(close_raw)
            open_dt = _dt(open_raw)
            if close_dt is None and open_dt is None:
                continue
            if close_dt is None:
                close_dt = open_dt
            side = (r.get("side") or r.get("direction") or "").strip().upper()
            if side in ("LONG", "BULL"):
                side = "BUY"
            elif side in ("SHORT", "BEAR"):
                side = "SELL"
            if r.get("net_profit") not in (None, ""):
                profit = _num(r.get("net_profit"))
            else:
                profit = _num(r.get("profit"))
            hour = None
            if open_dt:
                hour = open_dt.hour
            elif r.get("hour_utc") not in (None, ""):
                hour = int(_num(r.get("hour_utc"), -1))
                if hour < 0:
                    hour = None
            rows.append({
                "symbol": _norm_sym(sym),
                "side": side,
                "close_dt": close_dt,
                "open_dt": open_dt,
                "profit": float(profit or 0.0),
                "vn": int(_num(r.get("gom_vn") or r.get("vn"), 0)),
                "er": _num(r.get("er20") or r.get("er"), -1.0),
                "tfs": [(r.get(k) or "").strip().upper() for k in ("tf_m1", "tf_m5", "tf_m15", "tf_h1")],
                "hour": hour,
            })
    return rows


# ── Découpage en situations (« buckets ») ───────────────────────────────────
def er_bucket(er: float) -> Optional[str]:
    if er is None or er < 0:
        return None
    return "ER<0.20" if er < 0.20 else ("ER0.20-0.35" if er < 0.35 else "ER>=0.35")


def align_bucket(side: str, tfs: List[str]) -> Optional[str]:
    known = [t for t in tfs if t and t not in ("NONE",)]
    if not known:
        return None
    want = "BULL" if side == "BUY" else "BEAR"
    return f"TF {sum(1 for t in known if t == want)}/{len(known)}"


def vn_bucket(vn: int) -> Optional[str]:
    return None if vn == 0 else f"|vn|={min(3, abs(vn))}"


def hour_bucket(h: Optional[int]) -> Optional[str]:
    if h is None or h < 0 or h > 23:
        return None
    lo = (h // 3) * 3
    return f"H{lo:02d}-{lo + 2:02d}"


def buckets_for(side: str, vn: int, er: float, tfs: List[str], hour: Optional[int]) -> List[Tuple[str, str]]:
    out: List[Tuple[str, str]] = [("base", "tous")]
    for dim, b in (("er", er_bucket(er)), ("align", align_bucket(side, tfs)),
                   ("vn", vn_bucket(vn)), ("hour", hour_bucket(hour))):
        if b:
            out.append((dim, b))
    return out


# ── Statistiques ─────────────────────────────────────────────────────────────
def stat_of(vals: List[float]) -> Dict[str, Any]:
    n = len(vals)
    mean = sum(vals) / n if n else 0.0
    if n > 1:
        var = sum((v - mean) ** 2 for v in vals) / (n - 1)
        se = math.sqrt(var) / math.sqrt(n)
    else:
        se = 0.0
    wins = [v for v in vals if v > 0.05]
    losses = [v for v in vals if v < -0.05]
    gl = -sum(losses)
    return {
        "n": n,
        "exp": round(mean, 4),
        "se": round(se, 4),
        "ub": round(mean + VETO_Z * se, 4),
        "lb": round(mean - VETO_Z * se, 4),
        "win_pct": round(100.0 * len(wins) / (len(wins) + len(losses)), 1) if (wins or losses) else 0.0,
        "pf": round(sum(wins) / gl, 2) if gl > 0 else None,
        "total": round(sum(vals), 2),
    }


class JournalAdvisor:
    def __init__(self, logger=None):
        self.logger = logger
        self._lock = threading.Lock()
        self._sig: Optional[Tuple[float, int]] = None
        self._last_check = 0.0
        self._index: Dict[Tuple[str, str, str, str], Dict[str, Any]] = {}
        self._sym_count: Dict[str, int] = {}
        self._total_rows = 0
        self._loaded_path = ""
        self._error = ""
        self.recent: deque = deque(maxlen=100)

    # -- chargement (relit seulement si le fichier a changé) --
    def _log(self, level: str, msg: str) -> None:
        if self.logger:
            getattr(self.logger, level)(msg)

    def reload_if_needed(self, force: bool = False) -> None:
        now = time.time()
        if not force and now - self._last_check < RELOAD_MIN_INTERVAL_S:
            return
        with self._lock:
            self._last_check = now
            path = journal_path()
            try:
                stt = os.stat(path)
            except OSError:
                self._error = f"journal introuvable: {path}"
                self._loaded_path = path
                return
            sig = (stt.st_mtime, stt.st_size)
            if not force and sig == self._sig:
                return
            try:
                rows = _parse_rows(path)
            except Exception as exc:                       # fail-open
                self._error = f"lecture impossible: {exc}"
                self._log("warning", f"[JOURNAL-ADVISOR] {self._error}")
                return
            self._build_index(rows)
            self._sig = sig
            self._loaded_path = path
            self._error = ""
            self._log("info", f"[JOURNAL-ADVISOR] journal rechargé: {self._total_rows} trades "
                              f"(fenêtre {WINDOW_DAYS} j) depuis {path}")

    def _build_index(self, rows: List[Dict[str, Any]]) -> None:
        if not rows:
            self._index, self._sym_count, self._total_rows = {}, {}, 0
            return
        ref = max(r["close_dt"] for r in rows)
        cutoff = ref - timedelta(days=WINDOW_DAYS)
        rows = [r for r in rows if r["close_dt"] >= cutoff]
        rows.sort(key=lambda r: r["close_dt"])

        per_sym: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
        for r in rows:
            per_sym[r["symbol"]].append(r)

        idx: Dict[Tuple[str, str, str, str], List[float]] = defaultdict(list)
        counts: Dict[str, int] = {}
        total = 0
        for sym, lst in per_sym.items():
            lst = lst[-MAX_PER_SYMBOL:]
            counts[sym] = len(lst)
            total += len(lst)
            for r in lst:
                if r["side"] not in ("BUY", "SELL"):
                    continue
                for dim, b in buckets_for(r["side"], r["vn"], r["er"], r["tfs"], r["hour"]):
                    idx[(sym, r["side"], dim, b)].append(r["profit"])
        self._index = {k: stat_of(v) for k, v in idx.items()}
        self._sym_count = counts
        self._total_rows = total

    # -- décision --
    def decide(self, symbol: str, side: str, vn: int = 0, er: float = -1.0,
               tfs: Optional[List[str]] = None, hour: Optional[int] = None,
               remember: bool = True) -> Dict[str, Any]:
        side = (side or "").strip().upper()
        sym = _norm_sym(symbol)
        base_resp = {"ok": True, "symbol": symbol, "side": side, "mode": MODE}
        if not ENABLED:
            return {**base_resp, "allow": True, "reason": "advisor désactivé", "checks": []}
        try:
            self.reload_if_needed()
            if self._error and not self._index:
                return {**base_resp, "allow": True, "reason": f"pas de journal ({self._error})", "checks": []}
            n_sym = self._sym_count.get(sym, 0)
            if n_sym < MIN_TOTAL:
                resp = {**base_resp, "allow": True, "n_symbol": n_sym, "checks": [],
                        "reason": f"apprentissage: {n_sym}/{MIN_TOTAL} trades sur {symbol}"}
                if remember:
                    self._remember(resp)
                return resp

            checks: List[Dict[str, Any]] = []
            vetoes: List[str] = []
            favs = 0
            for dim, b in buckets_for(side, int(vn), float(er), tfs or [], hour):
                st = self._index.get((sym, side, dim, b))
                if st is None or st["n"] < MIN_BUCKET:
                    status = "insuffisant"
                elif st["ub"] < 0:
                    status = "veto"
                    vetoes.append(f"{dim}={b} n={st['n']} esp={st['exp']:+.2f} (borne haute {st['ub']:+.2f})")
                elif st["lb"] > 0:
                    status = "favorable"
                    favs += 1
                else:
                    status = "neutre"
                checks.append({"dim": dim, "bucket": b, "status": status,
                               **({"n": st["n"], "exp": st["exp"], "ub": st["ub"], "win_pct": st["win_pct"]} if st else {"n": 0})})

            would_block = bool(vetoes)
            allow = (not would_block) or MODE == "shadow"
            reason = ("VETO " + " | ".join(vetoes)) if would_block else (
                f"OK ({favs} situation(s) favorable(s))" if favs else "OK (aucune situation défavorable prouvée)")
            resp = {**base_resp, "allow": allow, "would_block": would_block, "n_symbol": n_sym,
                    "reason": reason, "checks": checks}
            if remember:
                self._remember(resp)
            if would_block and remember:
                self._log("info", f"[JOURNAL-ADVISOR] {'VETO' if not allow else 'SHADOW-VETO'} {symbol} {side}: {reason}")
            return resp
        except Exception as exc:                            # fail-open
            self._log("warning", f"[JOURNAL-ADVISOR] erreur decide: {exc}")
            return {**base_resp, "allow": True, "reason": f"erreur advisor ({exc})", "checks": []}

    # -- gestion d'une position OUVERTE (v1.37) --
    def manage(self, symbol: str, side: str, vn: int = 0, er: float = -1.0,
               tfs: Optional[List[str]] = None, hour: Optional[int] = None) -> Dict[str, Any]:
        """Dit à l'EA s'il faut RESSERRER les gardes de gain d'une position ouverte.

        tighten=True seulement si la situation d'entrée de la position a, dans le journal,
        une espérance négative prouvée (mêmes règles que le veto d'entrée : n suffisant et
        borne haute < 0). Sinon False. Jamais de « relâchement » : l'EA ne fait que resserrer.
        Aucun effet de bord (n'alimente pas l'historique des décisions d'entrée).
        """
        resp = self.decide(symbol, side, vn=vn, er=er, tfs=tfs, hour=hour, remember=False)
        vetoes = [c for c in resp.get("checks", []) if c.get("status") == "veto"]
        # `why` : court, sans virgule ni espace (l'EA le lit avec un parseur JSON minimal)
        why = "|".join(f"{c['dim']}={c['bucket']}_n{c.get('n', 0)}_esp{c.get('exp', 0.0):+.2f}"
                       for c in vetoes).replace(",", ".").replace(" ", "_")
        return {"ok": True, "symbol": symbol, "side": resp.get("side"),
                "tighten": bool(resp.get("would_block")), "why": why,
                "n_symbol": resp.get("n_symbol", 0), "reason": resp.get("reason", "")}

    def _remember(self, resp: Dict[str, Any]) -> None:
        self.recent.appendleft({"t": datetime.now().strftime("%H:%M:%S"), "symbol": resp.get("symbol"),
                                "side": resp.get("side"), "allow": resp.get("allow"),
                                "would_block": resp.get("would_block", False), "reason": resp.get("reason")})

    # -- rapport lisible --
    def report(self, symbol: str = "") -> Dict[str, Any]:
        self.reload_if_needed(force=False)
        want = _norm_sym(symbol) if symbol else ""
        tables: Dict[str, Any] = {}
        for (sym, side, dim, b), st in sorted(self._index.items()):
            if want and sym != want:
                continue
            flag = ("veto" if st["ub"] < 0 else "favorable" if st["lb"] > 0 else "neutre") if st["n"] >= MIN_BUCKET else "insuffisant"
            tables.setdefault(sym, {}).setdefault(side, []).append({"dim": dim, "bucket": b, "flag": flag, **st})
        return {
            "ok": True, "enabled": ENABLED, "mode": MODE, "path": self._loaded_path or journal_path(),
            "error": self._error, "trades_in_window": self._total_rows, "trades_per_symbol": self._sym_count,
            "params": {"min_total": MIN_TOTAL, "min_bucket": MIN_BUCKET, "veto_z": VETO_Z,
                       "window_days": WINDOW_DAYS},
            "situations": tables, "recent_decisions": list(self.recent)[:30],
        }


_ADVISOR: Optional[JournalAdvisor] = None


def get_advisor(logger=None) -> JournalAdvisor:
    global _ADVISOR
    if _ADVISOR is None:
        _ADVISOR = JournalAdvisor(logger)
    return _ADVISOR


def register_journal_routes(app, logger=None) -> None:
    """Branche /journal/decision, /journal/report, /journal/reload sur l'app FastAPI."""
    from fastapi import Query

    adv = get_advisor(logger)

    @app.get("/journal/decision")
    def journal_decision(symbol: str = Query(...), side: str = Query(...),
                         vn: int = Query(0), er: float = Query(-1.0),
                         m1: str = Query(""), m5: str = Query(""), m15: str = Query(""), h1: str = Query(""),
                         hour: int = Query(-1), coh: float = Query(0.0), spread: int = Query(0)):
        tfs = [m1.strip().upper(), m5.strip().upper(), m15.strip().upper(), h1.strip().upper()]
        return adv.decide(symbol, side, vn=vn, er=er, tfs=tfs, hour=hour if hour >= 0 else None)

    @app.get("/journal/manage")
    def journal_manage(symbol: str = Query(...), side: str = Query(...),
                       vn: int = Query(0), er: float = Query(-1.0),
                       m1: str = Query(""), m5: str = Query(""), m15: str = Query(""), h1: str = Query(""),
                       hour: int = Query(-1)):
        """Appelé UNE fois par l'EA à l'ouverture d'une position (voir SMC_JrnResolveTight)."""
        tfs = [m1.strip().upper(), m5.strip().upper(), m15.strip().upper(), h1.strip().upper()]
        return adv.manage(symbol, side, vn=vn, er=er, tfs=tfs, hour=hour if hour >= 0 else None)

    @app.get("/journal/report")
    def journal_report(symbol: str = Query("")):
        return adv.report(symbol)

    @app.api_route("/journal/reload", methods=["GET", "POST"])
    def journal_reload():
        adv.reload_if_needed(force=True)
        return {"ok": True, "trades_in_window": adv._total_rows, "error": adv._error}

    if logger:
        logger.info(f"[JOURNAL-ADVISOR] routes /journal/* actives | mode={MODE} | min_total={MIN_TOTAL} "
                    f"min_bucket={MIN_BUCKET} z={VETO_Z} fenêtre={WINDOW_DAYS}j | {journal_path()}")
