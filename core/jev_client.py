"""
Jev Client — TypeSafe AI decision API (Jev AI)
==============================================

Jev n'est PAS un LLM chat : c'est une API de decision structuree.
Un seul endpoint : ``POST {base_url}/systemone``.

Requete (3 champs top-level obligatoires) :
    {
      "model": "jev-latest",
      "state": "<texte | objet | tableau>",
      "questions": { "<cle>": Question, ... }
    }

Question (3 types) :
    - choice : ``criteria`` = map option -> description   (jusqu'a 255 options)
    - score  : ``criteria`` = tableau [{score, description}, ...]
    - noul   : ``criteria`` = optionnel {true, false}

Reponse : ``data.result.answers[<cle>]`` avec ``choice``/``score``/``noul``,
``probabilities`` et ``confidence``, plus ``data.creditsUsed``.

Configuration (variables d'environnement, jamais de cle en dur) :
    JEV_API_KEY   sk_...   (obligatoire)
    JEV_MODEL     jev-latest
    JEV_BASE_URL  https://thejevai.com/v1
    JEV_TIMEOUT   30
    JEV_MAX_RETRIES 2
"""

from __future__ import annotations

import json
import logging
import os
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Union

import requests

logger = logging.getLogger("tradbot.jev")

DEFAULT_BASE_URL = "https://thejevai.com/v1"
DEFAULT_ORIGIN = "https://thejevai.com"
DEFAULT_MODEL = "jev-latest"
DEFAULT_TIMEOUT = 30.0
DEFAULT_MAX_RETRIES = 2

# Cloudflare (1010) bloque les User-Agent par defaut de requests/urllib.
_BROWSER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json",
}

# Codes HTTP retentables (le "decision provider" peut echouer transitoirement).
_RETRYABLE_STATUS = {408, 425, 429, 500, 502, 503, 504}


class JevError(RuntimeError):
    """Erreur Jev (reseau, HTTP, schema ou configuration)."""

    def __init__(self, message: str, *, status: Optional[int] = None, payload: Any = None):
        super().__init__(message)
        self.status = status
        self.payload = payload


class JevNotConfigured(JevError):
    """JEV_API_KEY absente ou vide."""


# ──────────────────────────────────────────────────────────────
# Builders de questions
# ──────────────────────────────────────────────────────────────

State = Union[str, Dict[str, Any], List[Any]]
Instructions = Union[str, Dict[str, Any], List[Any]]


def choice(instructions: Instructions, options: Dict[str, Any]) -> Dict[str, Any]:
    """Question de classification. ``options`` map option -> description."""
    if not options:
        raise ValueError("choice() requiert au moins une option")
    if len(options) > 255:
        raise ValueError("choice() accepte au maximum 255 options")
    return {"type": "choice", "instructions": instructions, "criteria": options}


def score(instructions: Instructions, rubric: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Question d'echelle ordonnee. ``rubric`` = [{"score": 1, ...}, ...]."""
    if not rubric:
        raise ValueError("score() requiert au moins un palier")
    return {"type": "score", "instructions": instructions, "criteria": rubric}


def noul(instructions: Instructions, criteria: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Question booleenne : probabilite que la reponse soit "oui"."""
    q: Dict[str, Any] = {"type": "noul", "instructions": instructions}
    if criteria:
        q["criteria"] = criteria
    return q


# ──────────────────────────────────────────────────────────────
# Resultat
# ──────────────────────────────────────────────────────────────


@dataclass
class JevAnswer:
    """Reponse typée pour une question."""

    id: str
    type: str
    choice: Optional[str] = None
    score: Optional[float] = None
    noul: Optional[float] = None
    legend: Dict[str, Any] = field(default_factory=dict)
    probabilities: Dict[str, float] = field(default_factory=dict)
    confidence: Optional[float] = None

    @property
    def yes_probability(self) -> Optional[float]:
        """Alias semantique pour une question noul."""
        return self.noul

    def top_choice(self) -> Optional[str]:
        """Option la plus probable (tie-break : ordre d'insertion)."""
        if not self.probabilities:
            return self.choice
        return max(self.probabilities.items(), key=lambda kv: kv[1])[0]

    def to_dict(self) -> Dict[str, Any]:
        out: Dict[str, Any] = {"id": self.id, "type": self.type}
        if self.choice is not None:
            out["choice"] = self.choice
        if self.score is not None:
            out["score"] = self.score
        if self.noul is not None:
            out["noul"] = self.noul
        if self.legend:
            out["legend"] = self.legend
        if self.probabilities:
            out["probabilities"] = self.probabilities
        if self.confidence is not None:
            out["confidence"] = self.confidence
        return out

    @classmethod
    def from_payload(cls, key: str, raw: Dict[str, Any]) -> "JevAnswer":
        probs_raw = raw.get("probabilities") or {}
        probabilities: Dict[str, float] = {}
        for k, v in probs_raw.items():
            try:
                probabilities[str(k)] = float(v)
            except (TypeError, ValueError):
                continue

        def _f(name: str) -> Optional[float]:
            v = raw.get(name)
            if v is None:
                return None
            try:
                return float(v)
            except (TypeError, ValueError):
                return None

        return cls(
            id=key,
            type=str(raw.get("type") or "unknown"),
            choice=raw.get("choice") if isinstance(raw.get("choice"), str) else None,
            score=_f("score"),
            noul=_f("noul"),
            legend=raw.get("legend") if isinstance(raw.get("legend"), dict) else {},
            probabilities=probabilities,
            confidence=_f("confidence"),
        )


@dataclass
class JevResult:
    """Resultat complet d'un appel /v1/systemone."""

    answers: Dict[str, JevAnswer] = field(default_factory=dict)
    model: str = DEFAULT_MODEL
    credits_used: int = 0
    input_tokens: Optional[int] = None
    output_tokens: Optional[int] = None
    elapsed_ms: Optional[int] = None

    def answer(self, key: str) -> Optional[JevAnswer]:
        return self.answers.get(key)

    def choice(self, key: str) -> Optional[str]:
        a = self.answers.get(key)
        return a.choice if a else None

    def noul(self, key: str) -> Optional[float]:
        a = self.answers.get(key)
        return a.noul if a else None

    def score(self, key: str) -> Optional[float]:
        a = self.answers.get(key)
        return a.score if a else None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "model": self.model,
            "answers": {k: v.to_dict() for k, v in self.answers.items()},
            "credits_used": self.credits_used,
            "usage": {"input_tokens": self.input_tokens, "output_tokens": self.output_tokens},
            "elapsed_ms": self.elapsed_ms,
        }


# ──────────────────────────────────────────────────────────────
# Client
# ──────────────────────────────────────────────────────────────


class JevClient:
    """Client HTTP minimal pour l'API de decision Jev."""

    def __init__(
        self,
        api_key: str,
        model: str = DEFAULT_MODEL,
        base_url: str = DEFAULT_BASE_URL,
        timeout: float = DEFAULT_TIMEOUT,
        max_retries: int = DEFAULT_MAX_RETRIES,
    ):
        if not (api_key or "").strip():
            raise JevNotConfigured("JEV_API_KEY absente ou vide")
        self.api_key = api_key.strip()
        self.model = (model or DEFAULT_MODEL).strip()
        self.base_url = (base_url or DEFAULT_BASE_URL).strip().rstrip("/")
        self.timeout = float(timeout)
        self.max_retries = max(0, int(max_retries))
        self.endpoint = f"{self.base_url}/systemone"
        self._session = requests.Session()
        self._session.headers.update(_BROWSER_HEADERS)
        self._session.headers["Authorization"] = f"Bearer {self.api_key}"

    # -- core -----------------------------------------------------------

    def decide(self, state: State, questions: Dict[str, Any], model: Optional[str] = None) -> JevResult:
        """Evalue ``state`` contre ``questions`` et retourne les reponses typees.

        Leve JevError en cas d'echec (reseau, HTTP, schema).
        """
        if not questions:
            raise ValueError("decide() requiert au moins une question")

        payload = {
            "model": (model or self.model),
            "state": state,
            "questions": questions,
        }

        last_exc: Optional[Exception] = None
        for attempt in range(self.max_retries + 1):
            if attempt:
                backoff = min(2.0 ** attempt, 8.0)
                logger.warning("[jev] retry %d/%d dans %.1fs", attempt, self.max_retries, backoff)
                time.sleep(backoff)
            try:
                return self._post(payload)
            except JevError as exc:
                last_exc = exc
                retryable = exc.status is None or exc.status in _RETRYABLE_STATUS
                if not retryable:
                    raise
                logger.warning("[jev] echec retryable (status=%s): %s", exc.status, exc)

        raise last_exc if last_exc else JevError("[jev] echec inconnu")

    def _post(self, payload: Dict[str, Any]) -> JevResult:
        try:
            resp = self._session.post(
                self.endpoint,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                timeout=self.timeout,
            )
        except requests.RequestException as exc:
            raise JevError(f"[jev] erreur reseau: {type(exc).__name__}: {exc}") from exc

        if resp.status_code != 200:
            body = _safe_text(resp)
            raise JevError(
                f"[jev] HTTP {resp.status_code}: {body[:400]}",
                status=resp.status_code,
                payload=_safe_json(resp),
            )

        try:
            data = resp.json()
        except ValueError as exc:
            raise JevError(f"[jev] reponse non JSON: {_safe_text(resp)[:400]}", status=200) from exc

        return self._parse(data, str(payload.get("model") or self.model))

    def _parse(self, data: Dict[str, Any], model: str) -> JevResult:
        if not isinstance(data, dict):
            raise JevError("[jev] payload inattendu (objet attendu)", status=200, payload=data)
        if data.get("code") not in (0, None):
            raise JevError(
                f"[jev] code={data.get('code')} message={data.get('message')}",
                status=200,
                payload=data,
            )

        result = ((data.get("data") or {}).get("result")) or {}
        raw_answers = result.get("answers")
        if not isinstance(raw_answers, dict):
            raise JevError("[jev] champ 'answers' absent ou invalide", status=200, payload=data)

        answers = {str(k): JevAnswer.from_payload(str(k), v) for k, v in raw_answers.items() if isinstance(v, dict)}
        usage = result.get("usage") or {}

        def _i(v: Any) -> Optional[int]:
            try:
                return int(v)
            except (TypeError, ValueError):
                return None

        return JevResult(
            answers=answers,
            model=model,
            credits_used=_i((data.get("data") or {}).get("creditsUsed")) or 0,
            input_tokens=_i(usage.get("input_tokens")),
            output_tokens=_i(usage.get("output_tokens")),
            elapsed_ms=_i(result.get("elapsedMs")),
        )

    # -- metadonnees ----------------------------------------------------

    def health(self) -> Dict[str, Any]:
        """Etat de la configuration (aucun appel reseau, aucune fuite de cle)."""
        return {
            "configured": True,
            "endpoint": self.endpoint,
            "model": self.model,
            "timeout": self.timeout,
            "max_retries": self.max_retries,
            "api_key_preview": _mask(self.api_key),
            "note": "Jev est une API de decision (/v1/systemone), pas un LLM chat.",
        }

    def close(self) -> None:
        try:
            self._session.close()
        except Exception:
            pass

    def __enter__(self) -> "JevClient":
        return self

    def __exit__(self, *exc_info: Any) -> None:
        self.close()


# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────


def _mask(key: str) -> str:
    if len(key) <= 8:
        return "***"
    return f"{key[:5]}...{key[-4:]}"


def _safe_text(resp: "requests.Response") -> str:
    try:
        return resp.text or ""
    except Exception:
        return "<unreadable>"


def _safe_json(resp: "requests.Response") -> Any:
    try:
        return resp.json()
    except Exception:
        return _safe_text(resp)[:400]


def is_configured() -> bool:
    """Vrai si JEV_API_KEY est presente dans l'environnement."""
    return bool((os.getenv("JEV_API_KEY") or "").strip())


def resolve_base_url() -> str:
    """Resout l'origin de l'API.

    JEV_BASE_URL prime (base complete, ex. https://thejevai.com/v1).
    Sinon JEV_API_BASE_URL (origine, convention du skill officiel jev-agent)
    est completee par /v1 si necessaire.
    """
    explicit = (os.getenv("JEV_BASE_URL") or "").strip()
    if explicit:
        return explicit.rstrip("/")
    origin = (os.getenv("JEV_API_BASE_URL") or DEFAULT_ORIGIN).strip().rstrip("/")
    return origin if origin.endswith("/v1") else f"{origin}/v1"


def get_jev_client(**overrides: Any) -> JevClient:
    """Construit un client depuis l'environnement (lazy singleton)."""
    key = (os.getenv("JEV_API_KEY") or "").strip()
    if not key:
        raise JevNotConfigured(
            "JEV_API_KEY absente. Ajoutez-la dans .env (https://thejevai.com/settings/apikeys)"
        )
    params: Dict[str, Any] = {
        "api_key": key,
        "model": (os.getenv("JEV_MODEL") or DEFAULT_MODEL).strip(),
        "base_url": resolve_base_url(),
        "timeout": float(os.getenv("JEV_TIMEOUT") or DEFAULT_TIMEOUT),
        "max_retries": int(os.getenv("JEV_MAX_RETRIES") or DEFAULT_MAX_RETRIES),
    }
    params.update(overrides)
    return JevClient(**params)


# ──────────────────────────────────────────────────────────────
# Helpers metier TradBOT
# ──────────────────────────────────────────────────────────────

TRADING_DIRECTION_QUESTION = "direction"
TRADING_CONVICTION_QUESTION = "conviction"
TRADING_TRADEABLE_QUESTION = "is_tradeable"

_BUY_TOKENS = ("buy", "long", "bull", "call", "hausse", "achat")
_SELL_TOKENS = ("sell", "short", "bear", "put", "baisse", "vente")


def _normalize_direction(value: Optional[str]) -> str:
    v = (value or "").strip().upper()
    if not v:
        return "HOLD"
    for tok in _BUY_TOKENS:
        if tok in v:
            return "BUY"
    for tok in _SELL_TOKENS:
        if tok in v:
            return "SELL"
    return "HOLD"


def build_trading_questions() -> Dict[str, Any]:
    """Trame de questions standard pour un setup de trading."""
    return {
        TRADING_DIRECTION_QUESTION: choice(
            "Which trading direction, if any, for this setup?",
            {
                "BUY": "Long setup justified by the evidence",
                "SELL": "Short setup justified by the evidence",
                "HOLD": "No tradable edge, stand aside",
            },
        ),
        TRADING_CONVICTION_QUESTION: score(
            "How strong is this setup, from no edge to very strong?",
            [
                {"score": 1, "description": "No edge, conflicting signals"},
                {"score": 2, "description": "Weak edge"},
                {"score": 3, "description": "Moderate edge"},
                {"score": 4, "description": "Strong edge"},
                {"score": 5, "description": "Very strong, multi-factor confluence"},
            ],
        ),
        TRADING_TRADEABLE_QUESTION: noul(
            "Is this a valid trade entry right now?",
            {"true": "Confluence present and entry valid", "false": "Missing confluence or bad entry"},
        ),
    }


def to_trading_verdict(
    result: JevResult,
    min_confidence: float = 0.55,
) -> Dict[str, Any]:
    """Traduit un JevResult en verdict compatible /decision (BUY/SELL/HOLD).

    ``min_confidence`` : seuil de confiance Jev en dessous duquel on degrade
    systematiquement en HOLD (Jev est deja calibrate, on ne fait pas confiance
    aveuglément a une decision unique).
    """
    direction = result.choice(TRADING_DIRECTION_QUESTION)
    action = _normalize_direction(direction)
    conf = 0.0
    ans = result.answer(TRADING_DIRECTION_QUESTION)
    if ans and ans.confidence is not None:
        conf = max(0.0, min(1.0, float(ans.confidence)))

    tradeable = result.noul(TRADING_TRADEABLE_QUESTION)
    conviction = result.score(TRADING_CONVICTION_QUESTION)

    trade_allowed = action != "HOLD"
    if conf < min_confidence:
        trade_allowed = False
    if tradeable is not None and tradeable < 0.5:
        trade_allowed = False

    if not trade_allowed:
        action = "HOLD"

    return {
        "decision": action,
        "confidence": round(conf, 4),
        "trade_allowed": trade_allowed,
        "jev_direction": direction,
        "jev_probabilities": dict(ans.probabilities) if ans else {},
        "jev_conviction": conviction,
        "jev_tradeable": tradeable,
        "min_confidence": min_confidence,
        "source": "JEV_DECISION_API",
    }
