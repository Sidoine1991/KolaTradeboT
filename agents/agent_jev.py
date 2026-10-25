"""
Agent 8 - Jev AI Decision Agent
Utilise l'API Jev (https://thejevai.com/v1/systemone) comme couche de d��cision
typ�e : on fournit un �tat de march� (verdicts GOM + contexte des agents pairs)
et Jev r�pond avec des questions typ�es (choice / score / noul) accompagn�es de
probabilit�s et de confiance.

Jev n'est pas un LLM de chat : il retourne des d�cisions structur�es que le code
peut consommer directement. Le contenu ex�cut� (SL/TP, lots, ex�cution) reste
contr�l� par les r�gles d�terministes de TradBOT.

Le transport HTTP, le parsing, les retries et la r�solution de configuration
viennent de ``core.jev_client`` (source de v��rit� unique). La cl� n'est jamais
lue au moment de l'import : elle est r�solue � chaque cycle.

Configuration (variables d'environnement):
    JEV_API_KEY      (requis) - cl�� API cr��e sur https://thejevai.com/settings/apikeys
    JEV_MODEL        (optionnel, d��faut jev-latest)
    JEV_BASE_URL     (optionnel, d��faut https://thejevai.com/v1)
    JEV_TIMEOUT      (optionnel, d��faut 30)
    JEV_MAX_RETRIES  (optionnel, d��faut 2)
"""

import os
import requests
from typing import Any, Dict, List, Optional

from core import jev_journal
from core.jev_client import JevError, JevNotConfigured, choice, get_jev_client, noul, score

from .agent_base import AgentBase

AI_SERVER = "http://127.0.0.1:8000"

# Cohérence minimale pour envoyer un signal à Jev (évite d'épuiser le quota)
_JEV_COH_THRESHOLD = 55.0
# Nombre max de symboles envoyés à Jev par cycle
_JEV_MAX_SYMBOLS = 3
# Confiance direction minimale requise pour marquer le signal comme actionnable
_JEV_MIN_CONFIDENCE = float((os.getenv("JEV_MIN_CONFIDENCE") or "0.55").strip())
# Probabilité "enter_now" minimale requise pour autoriser une entrée immédiate
_JEV_MIN_ENTER = float((os.getenv("JEV_MIN_ENTER_PROB") or "0.6").strip())

# ──────────────────────────────────────────────────────────────
# SMC (optionnel)
# ──────────────────────────────────────────────────────────────
# L'analyse SMC vient du Core Engine, qui a besoin de MT5. Si MT5 est off ou
# le moteur absent, l'agent fonctionne sans SMC plutot que de mourir.
_SMC_ENABLED = (os.getenv("JEV_SMC_ENABLED") or "true").strip().lower() in ("1", "true", "yes")
_SMC_MAX_PATTERNS = int((os.getenv("JEV_SMC_MAX_PATTERNS") or "5").strip())
_JEV_JOURNAL_ENABLED = (os.getenv("JEV_JOURNAL_ENABLED") or "true").strip().lower() in ("1", "true", "yes")
_smc_bridge_cache: Any = None
_smc_bridge_tried = False


def _enum_val(value: Any) -> Any:
    """Enum -> valeur brute (les str-enum se formatent sinon en 'PatternType.BOS')."""
    return getattr(value, "value", value)


def _smc_bridge() -> Any:
    """CoreBridge en singleton paresseux (evite de planter si core est absent)."""
    global _smc_bridge_cache, _smc_bridge_tried
    if _smc_bridge_tried:
        return _smc_bridge_cache
    _smc_bridge_tried = True
    try:
        from core.bridge import CoreBridge, get_engine
        _smc_bridge_cache = CoreBridge(get_engine())
    except Exception:
        _smc_bridge_cache = None
    return _smc_bridge_cache



class JevDecisionAgent(AgentBase):
    agent_id = "jev_ai"
    agent_name = "Jev AI Decision Agent"
    description = (
        "Couche de décision typée Jev : direction (BUY/SELL/HOLD), qualité de setup "
        "et validation d'entrée immédiate à partir des verdicts GOM + contexte des autres agents."
    )
    version = "1.0.0"
    interval_seconds = 90

    def __init__(self) -> None:
        super().__init__()
        self.last_answer: Dict = {}
        self._last_error: Optional[str] = None

    # ------------------------------------------------------------------
    # Cycle d'analyse
    # ------------------------------------------------------------------

    def analyze(self) -> Dict[str, Any]:
        if not self._jev_available():
            return {
                "enabled": False,
                "reason": "JEV_API_KEY manquant — agent inactif",
                "answers": {},
            }

        verdicts = self._fetch_verdicts()
        candidates = [
            v for v in verdicts
            if float(v.get("coherence_pct", 0)) >= _JEV_COH_THRESHOLD
        ][:_JEV_MAX_SYMBOLS]

        if not candidates:
            return {
                "enabled": True,
                "symbol": "",
                "decision": "HOLD",
                "reason": "Aucun signal GOM avec coherence >= {:.0f}%".format(_JEV_COH_THRESHOLD),
                "answers": {},
            }

        state = self._build_state(candidates)
        questions = self._build_questions(candidates[0])
        result = self._query_jev(state, questions)

        if result is None:
            return {
                "enabled": True,
                "symbol": candidates[0].get("symbol", ""),
                "decision": "HOLD",
                "reason": self._last_error or "Réponse Jev vide ou erreur API",
                "answers": {},
            }

        self.last_answer = result.to_dict()["answers"]

        # Mapping typé → signal utilisable
        ans_direction = result.answer("direction")
        ans_quality = result.answer("setup_quality")
        ans_enter = result.answer("enter_now")

        direction = (ans_direction.choice if ans_direction else None) or "HOLD"
        direction_prob = dict(ans_direction.probabilities) if ans_direction else {}
        direction_conf = float(ans_direction.confidence) if ans_direction and ans_direction.confidence is not None else 0.0
        quality = ans_quality.score if ans_quality else None
        quality_conf = float(ans_quality.confidence) if ans_quality and ans_quality.confidence is not None else 0.0
        enter_now = ans_enter.noul if ans_enter and ans_enter.noul is not None else 0.5

        actionable = (
            direction != "HOLD"
            and direction_conf >= _JEV_MIN_CONFIDENCE
            and enter_now > _JEV_MIN_ENTER
            and quality_conf > 0.5
        )

        top = candidates[0]
        smc_block = state.get("smc") or {}
        smc_for_top = smc_block.get(top.get("symbol", ""), {})
        smc_labels = [
            f"{_enum_val(p.get('type'))}:{_enum_val(p.get('dir'))}"
            for p in (smc_for_top.get("patterns") or [])
        ]

        # Journalise AVANT de retourner : c'est ce qui permet de mesurer le
        # hit-rate et de decider (ou non) le branchement sur l'EA.
        self._journal_decision(
            symbol=top.get("symbol", ""),
            direction=direction,
            confidence=direction_conf,
            probabilities=direction_prob,
            setup_quality=quality,
            setup_confidence=quality_conf,
            enter_now=enter_now,
            actionable=actionable,
            coherence=float(top.get("coherence_pct", 0)),
            smc_patterns=smc_labels,
            model=result.model,
        )

        return {
            "enabled": True,
            "provider": "jev",
            "model": result.model,
            "symbol": top.get("symbol", ""),
            "decision": direction,
            "confidence": round(direction_conf, 3),
            "probabilities": direction_prob,
            "smc": smc_for_top,
            "setup_quality": quality,
            "setup_quality_legend": dict(ans_quality.legend) if ans_quality else {},
            "setup_confidence": round(quality_conf, 3),
            "enter_now_probability": round(enter_now, 3),
            "actionable": actionable,
            "answers": self.last_answer,
            "usage": {
                "input_tokens": result.input_tokens,
                "output_tokens": result.output_tokens,
                "credits_used": result.credits_used,
            },
            "elapsed_ms": result.elapsed_ms,
        }

    # ------------------------------------------------------------------
    # État envoyé à Jev
    # ------------------------------------------------------------------

    def _build_state(self, candidates: List[Dict]) -> Dict[str, Any]:
        """Contexte marché : verdicts GOM + SMC + sorties des agents pairs."""
        regime_out = self.get_peer("regime")
        news_out = self.get_peer("news")
        risk_out = self.get_peer("risk")
        timing_out = self.get_peer("timing")

        symbols_state = []
        for v in candidates:
            sym = v.get("symbol", "")
            symbols_state.append({
                "symbol": sym,
                "verdict": v.get("verdict", "WAIT"),
                "coherence_pct": float(v.get("coherence_pct", 0)),
                "verdict_gap": float(v.get("verdict_gap", 0)),
                "score_buy": float(v.get("score_buy", 0)),
                "score_sell": float(v.get("score_sell", 0)),
                "entry": v.get("entry", 0),
                "sl": v.get("sl", 0),
                "tp": v.get("tp", 0),
            })

        state = {
            "symbols": symbols_state,
            "global_regime": regime_out.get("global_regime", {}).get("regime", "UNKNOWN"),
            "symbol_regimes": {
                s: (regime_out.get("symbol_regimes", {}).get(s, {}) or {}).get("regime", "UNKNOWN")
                for s in [x["symbol"] for x in symbols_state]
            },
            "news_impact": news_out.get("current_impact", "NONE"),
            "news_blocked": news_out.get("news_blocked", False),
            "session": news_out.get("session", {}),
            "risk_level": risk_out.get("risk_level", "NORMAL"),
            "can_trade": risk_out.get("can_trade", True),
            "daily_budget_remaining": risk_out.get("daily_budget_remaining", 999),
            "best_entries": timing_out.get("best_entries", [])[:3],
        }

        smc = self._smc_context(symbols_state)
        if smc:
            # On n'envoie le bloc que s'il porte de l'information : inutile de
            # brûler des tokens sur "aucun pattern".
            state["smc"] = smc
        return state

    # ------------------------------------------------------------------
    # Contexte SMC (optionnel : MT5 peut être indisponible)
    # ------------------------------------------------------------------

    def _smc_context(self, symbols_state: List[Dict]) -> Dict[str, Any]:
        """Patterns SMC actifs (BOS/CHoCH/FVG/OB) par symbole.

        Retourne {} si le Core Engine ou MT5 sont indisponibles : l'agent
        doit continuer à fonctionner sans SMC (degradation, jamais d'exception).
        """
        if not _SMC_ENABLED:
            return {}
        if _smc_bridge() is None:
            return {}

        out: Dict[str, Any] = {}
        for entry in symbols_state:
            sym = entry.get("symbol", "")
            if not sym:
                continue
            # GOM renvoie "EURMXN.C", MT5 expose "EURMXN" : on tente les deux.
            lookup = sym
            if lookup not in out:
                try:
                    resolved = jev_journal.resolve_symbol(sym)
                except Exception:
                    resolved = None
                if resolved:
                    lookup = resolved
            try:
                summary = _smc_bridge().get_pattern_context(lookup) or {}
            except Exception as exc:
                self.logger.debug("SMC indisponible pour %s: %s", sym, exc)
                continue

            patterns = summary.get("patterns") or []
            if not patterns:
                continue

            # On ne garde que les patterns les plus forts et recent pour
            # rester sous control du budget de tokens Jev.
            strongest = sorted(
                patterns,
                key=lambda p: float(p.get("confidence") or 0.0),
                reverse=True,
            )[:_SMC_MAX_PATTERNS]

            out[sym] = {
                "bias": summary.get("bias"),
                "bullish": summary.get("bullish_count", 0),
                "bearish": summary.get("bearish_count", 0),
                "patterns": [
                    {
                        # .value : les enums.PatternType/PatternDirection sont
                        # des str-enum, __format__ renverrait "PatternType.BOS".
                        "type": _enum_val(p.get("pattern_type")),
                        "dir": _enum_val(p.get("direction")),
                        "price": p.get("price"),
                        "confidence": p.get("confidence"),
                        "strength": p.get("strength"),
                    }
                    for p in strongest
                ],
            }

        return out

    def _build_questions(self, top: Dict) -> Dict[str, Any]:
        """Questions typées (choice + score + noul) sur le même état."""
        sym = top.get("symbol", "the strongest signal")
        return {
            "direction": choice(
                (
                    "Choose the single best trade direction for {sym}. "
                    "Respect the law: Boom/PAINX indices are BUY-only, Crash/GAINX indices are "
                    "SELL-only. Prefer HOLD unless the setup is clearly aligned across regime, "
                    "timing and risk."
                ).format(sym=sym),
                {
                    "BUY": "Strong long setup, aligned with regime and timing",
                    "SELL": "Strong short setup, aligned with regime and timing",
                    "HOLD": "No reliable edge; wait or skip",
                },
            ),
            "setup_quality": score(
                (
                    "Rate the overall quality of the strongest setup in the state "
                    "considering coherence, verdict gap, alignment and risk."
                ),
                [
                    {"score": 1, "description": "Very weak setup"},
                    {"score": 2, "description": "Weak setup"},
                    {"score": 3, "description": "Average setup"},
                    {"score": 4, "description": "Good setup, needs confirmation"},
                    {"score": 5, "description": "Exceptional setup"},
                ],
            ),
            "enter_now": noul(
                (
                    "Given the state, is it safe to enter this signal immediately "
                    "without waiting for a retest or better confirmation?"
                ),
                {
                    "true": "Enter now with full confidence",
                    "false": "Wait, skip, or reduce risk",
                },
            ),
        }

    # ------------------------------------------------------------------
    # Appel API Jev
    # ------------------------------------------------------------------

    def _jev_available(self) -> bool:
        """Clé résolue à la demande (jamais figée à l'import)."""
        return bool((os.getenv("JEV_API_KEY") or "").strip())

    def _journal_decision(self, **kw: Any) -> None:
        """Ecrit la decision dans le journal forward (silencieux si indisponible)."""
        if not _JEV_JOURNAL_ENABLED:
            return
        try:
            jev_journal.record(**kw)
        except Exception as exc:  # le journaling ne doit jamais casser le cycle
            self.logger.warning("Journal Jev indisponible: %s", exc)

    def _query_jev(self, state: Dict, questions: Dict) -> Optional[Any]:
        """POST /v1/systemone via core.jev_client. None sur toute erreur."""
        self._last_error = None
        try:
            with get_jev_client() as client:
                return client.decide(state, questions)
        except JevNotConfigured as exc:
            self._last_error = str(exc)
            self.logger.warning("Jev non configuré: %s", exc)
        except JevError as exc:
            self._last_error = str(exc)
            self.logger.warning("Jev API error: %s", exc)
        except ValueError as exc:
            self._last_error = str(exc)
            self.logger.warning("Jev questions invalides: %s", exc)
        return None

    # ------------------------------------------------------------------
    # Sources de données
    # ------------------------------------------------------------------

    _FALLBACK_SYMBOLS = [
        "XAUUSD", "EURUSD", "GBPUSD", "USDJPY", "BTCUSD", "ETHUSD",
        "Boom 500 Index", "Boom 300 Index", "Boom 1000 Index",
        "Crash 500 Index", "Crash 300 Index", "Crash 1000 Index",
    ]

    def _fetch_verdicts(self) -> List[Dict]:
        try:
            r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=6)
            if r.status_code == 200:
                verdicts = r.json().get("verdicts", [])
                if verdicts:
                    return verdicts
        except Exception:
            pass
        return self._fetch_verdicts_individually()

    def _fetch_verdicts_individually(self) -> List[Dict]:
        results = []
        for sym in self._FALLBACK_SYMBOLS:
            try:
                r = requests.get(
                    f"{AI_SERVER}/gom-verdict",
                    params={"symbol": sym},
                    timeout=4,
                )
                if r.status_code == 200:
                    data = r.json()
                    if data.get("ok"):
                        results.append(data)
            except Exception:
                pass
        return results