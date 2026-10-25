import os
from dotenv import load_dotenv
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import google.generativeai as genai


class RecommendRequest(BaseModel):
    symbol: str
    timeframe: str
    context: dict
    prompt: str | None = None


class RecommendResponse(BaseModel):
    recommendation: str
    confidence: int | None = None


def _get_api_key_candidates() -> list[str]:
    candidates: list[str] = []
    # Canonical names
    for name in [
        "GEMINI_API_KEY",
        "GEMINI_API_KEY_1",
        "GEMINI_API_KEY_2",
        "GEMINI_API_KEY_3",
        "GEMINI_API_KEY_4",
        "GEMINI_API_KEY_5",
    ]:
        val = os.getenv(name)
        if val:
            candidates.append(val)
    # Common typos (GEMNI_*) provided by user
    for typo_name in [
        "GEMNI_API_KEY_3",
        "GEMNI_API_KEY_4",
    ]:
        val = os.getenv(typo_name)
        if val:
            candidates.append(val)
    # Deduplicate while preserving order
    seen = set()
    unique: list[str] = []
    for k in candidates:
        if k not in seen:
            seen.add(k)
            unique.append(k)
    return unique


def _is_quota_error(err: Exception) -> bool:
    txt = str(err).lower()
    return any(kw in txt for kw in ["quota", "rate limit", "429", "resource exhausted"])  # best-effort


def configure_genai() -> None:
    keys = _get_api_key_candidates()
    if not keys:
        raise RuntimeError("Missing GEMINI_API_KEY in environment (try GEMINI_API_KEY or GEMINI_API_KEY_1/_2/_3/_4)")
    # Configure with the first key; rotation happens in request if needed
    genai.configure(api_key=keys[0])


load_dotenv()
app = FastAPI(title="AI Proxy", version="1.0")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/recommend", response_model=RecommendResponse)
def recommend(req: dict):
    # Mode mock pour contourner les quotas
    mock_mode = os.getenv("MOCK_MODE", "false").lower() == "true"
    print(f"🔍 MOCK_MODE env: {os.getenv('MOCK_MODE')}, mock_mode: {mock_mode}")
    if mock_mode:
        import random
        symbol = req.get("symbol", "")
        ctx = req.get("context", {}) or {}
        bid = float(ctx.get("bid", 0) or 0)
        ask = float(ctx.get("ask", 0) or 0)
        # Fallback to mid if missing
        mid = (bid + ask) / 2.0 if (bid and ask) else (bid or ask)

        is_boom = "boom" in symbol.lower()
        is_crash = "crash" in symbol.lower()

        # Absolutes: ENTRY/SL/TP en prix, pas en pips
        # Offsets (simples) pour mock: 0.20% pour SL, 0.30% pour TP
        def fmt_price(x: float) -> str:
            try:
                return f"{x:.6f}"
            except Exception:
                return str(x)

        if is_boom and ask:
            entry = ask
            # Set SL as 0.20% and TP at 1.5x SL distance
            sl = entry * (1.0 - 0.0020)
            tp = entry + 1.5 * (entry - sl)
            reco = (
                f"BUY; ENTRY={fmt_price(entry)}; SL={fmt_price(sl)}; TP={fmt_price(tp)}; "
                f"CONF=85; NOTE=Mock Boom signal"
            )
            return RecommendResponse(recommendation=reco, confidence=85)
        elif is_crash and bid:
            entry = bid
            sl = entry * (1.0 + 0.0020)
            tp = entry - 1.5 * (sl - entry)
            reco = (
                f"SELL; ENTRY={fmt_price(entry)}; SL={fmt_price(sl)}; TP={fmt_price(tp)}; "
                f"CONF=85; NOTE=Mock Crash signal"
            )
            return RecommendResponse(recommendation=reco, confidence=85)
        else:
            # Autres symboles: BUY/SELL/WAIT avec ENTRY/SL/TP absolus à partir du mid
            direction = random.choice(["BUY", "SELL", "WAIT"]) if mid else "WAIT"
            conf = random.randint(60, 95) if direction != "WAIT" else 0
            if direction == "BUY" and mid:
                entry = mid
                sl = entry * (1.0 - 0.0020)
                tp = entry + 1.5 * (entry - sl)
                reco = (
                    f"BUY; ENTRY={fmt_price(entry)}; SL={fmt_price(sl)}; TP={fmt_price(tp)}; "
                    f"CONF={conf}; NOTE=Mock generic"
                )
            elif direction == "SELL" and mid:
                entry = mid
                sl = entry * (1.0 + 0.0020)
                tp = entry - 1.5 * (sl - entry)
                reco = (
                    f"SELL; ENTRY={fmt_price(entry)}; SL={fmt_price(sl)}; TP={fmt_price(tp)}; "
                    f"CONF={conf}; NOTE=Mock generic"
                )
            else:
                reco = "WAIT; NOTE=Insufficient context"
            return RecommendResponse(recommendation=reco, confidence=conf)
    
    try:
        # Try with first key, and rotate on quota errors
        keys = _get_api_key_candidates()
        last_err: Exception | None = None
        for idx, key in enumerate(keys):
            try:
                genai.configure(api_key=key)
                model = genai.GenerativeModel("gemini-1.5-flash")
                break
            except Exception as e:
                last_err = e
                if not _is_quota_error(e) and idx == 0:
                    # Non-quota error on first attempt → bubble up
                    raise
                # Otherwise, continue to next key
        else:
            # If loop completed without break, re-raise last error
            raise last_err or RuntimeError("No valid Gemini API key available")
        base_prompt = (
            "Tu es un assistant de trading. Donne une recommandation concise (BUY/SELL/WAIT), "
            "un SL/TP en points si possible, et un court raisonnement en une phrase. "
            "Format: RECO=BUY|SELL|WAIT; SL=..; TP=..; CONF=0-100; NOTE=..."
        )
        # Extract fields permissively to avoid 422 from strict validation
        symbol = (req.get("symbol") if isinstance(req, dict) else None) or "UNKNOWN"
        timeframe = (req.get("timeframe") if isinstance(req, dict) else None) or "M1"
        context = (req.get("context") if isinstance(req, dict) else None) or {}
        user_prompt = (req.get("prompt") if isinstance(req, dict) else None) or ""
        full = (
            f"SYMBOL={symbol} TF={timeframe}\n"
            f"CONTEXT={context}\n\n"
            f"{base_prompt}\n{user_prompt}"
        )
        resp = model.generate_content(full)
        text = resp.text.strip() if hasattr(resp, "text") and resp.text else "WAIT"
        conf = None
        for tok in text.split(";"):
            t = tok.strip().upper()
            if t.startswith("CONF="):
                try:
                    conf = int(t.split("=", 1)[1].strip().split()[0])
                except Exception:
                    conf = None
        return RecommendResponse(recommendation=text, confidence=conf)
    except Exception as e:
        # graceful fallback instead of 500
        msg = f"WAIT; NOTE={str(e)[:120]}"
        return RecommendResponse(recommendation=msg, confidence=None)


if __name__ == "__main__":
    port = int(os.getenv("AI_PROXY_PORT", "8099"))
    uvicorn.run(app, host="127.0.0.1", port=port)


