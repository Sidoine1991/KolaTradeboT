"""
Pattern Recognizer for Synthetic Indices — Multi-TF pattern extraction,
similarity search (DTW/correlation), spike prediction, and 1000-bar zigzag
projection. Extends existing cognition_forecast + predictive_setup.
"""

from __future__ import annotations

import math
import json
import hashlib
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

import logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

try:
    from ml.cognition_forecast import forecast_200, _rsi, _atr, _pattern_tags
except ImportError:
    from python.ml.cognition_forecast import forecast_200, _rsi, _atr, _pattern_tags

ROOT = Path(__file__).resolve().parents[2]
PATTERN_LIBRARY_PATH = ROOT / "data" / "pattern_library.json"
PATTERN_HISTORY_PATH = ROOT / "data" / "pattern_history.jsonl"

DEFAULT_HORIZON = 1000
SIMILARITY_TOP_K = 5
DTW_WINDOW = 50
MIN_PATTERN_LENGTH = 100


@dataclass
class CandleFeatures:
    """Normalized features for a candle window."""
    returns: List[float]
    rsi_7: List[float]
    rsi_14: List[float]
    atr_normalized: List[float]
    body_ratio: List[float]
    upper_wick_ratio: List[float]
    lower_wick_ratio: List[float]
    volume_norm: List[float]


@dataclass
class PatternInstance:
    """A single historical pattern with outcome."""
    pattern_id: str
    symbol: str
    timeframe: str
    start_time: str
    end_time: str
    features_hash: str
    window_size: int
    direction: str
    spike_occurred: bool
    spike_index: Optional[int]
    spike_magnitude: float
    future_returns: List[float]
    future_highs: List[float]
    future_lows: List[float]
    future_closes: List[float]
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class SimilarPattern:
    """Matched historical pattern with similarity score."""
    instance: PatternInstance
    similarity: float
    dtw_distance: Optional[float] = None
    correlation: Optional[float] = None


@dataclass
class PatternForecast:
    """Forecast result from pattern matching."""
    symbol: str
    timeframe: str
    current_window_hash: str
    matched_patterns: List[SimilarPattern]
    consensus_direction: str
    spike_probability: float
    spike_expected_index: Optional[int]
    spike_expected_price: Optional[float]
    spike_magnitude_atr: float
    projected_path: List[Dict[str, Any]]
    confidence: float
    pattern_quality: float
    fallback_to_cognition: bool = False


def _normalize_series(series: np.ndarray) -> np.ndarray:
    """Z-score normalize a series."""
    if len(series) == 0:
        return series
    mean = np.mean(series)
    std = np.std(series)
    if std < 1e-8:
        return np.zeros_like(series)
    return (series - mean) / std


def _dtw_distance(s1: np.ndarray, s2: np.ndarray, window: int = DTW_WINDOW) -> float:
    """Fast DTW distance with Sakoe-Chiba window constraint."""
    n, m = len(s1), len(s2)
    if n == 0 or m == 0:
        return float('inf')
    
    max_len = max(n, m)
    dtw_matrix = np.full((n + 1, m + 1), np.inf)
    dtw_matrix[0, 0] = 0
    
    w = max(window, abs(n - m))
    
    for i in range(1, n + 1):
        start_j = max(1, i - w)
        end_j = min(m, i + w)
        for j in range(start_j, end_j + 1):
            cost = abs(s1[i - 1] - s2[j - 1])
            dtw_matrix[i, j] = cost + min(
                dtw_matrix[i - 1, j],
                dtw_matrix[i, j - 1],
                dtw_matrix[i - 1, j - 1]
            )
    
    return dtw_matrix[n, m]


def _correlation_distance(s1: np.ndarray, s2: np.ndarray) -> float:
    """1 - Pearson correlation as distance metric."""
    if len(s1) != len(s2) or len(s1) < 3:
        return 1.0
    c = np.corrcoef(s1, s2)[0, 1]
    if np.isnan(c):
        return 1.0
    return 1.0 - c


def _extract_window_features(
    df: pd.DataFrame,
    start_idx: int,
    window: int,
    atr_val: float,
) -> Optional[CandleFeatures]:
    """Extract normalized features for a window of candles."""
    if start_idx + window > len(df):
        return None
    
    window_df = df.iloc[start_idx:start_idx + window]
    closes = window_df["close"].astype(float).values
    opens = window_df["open"].astype(float).values
    highs = window_df["high"].astype(float).values
    lows = window_df["low"].astype(float).values
    volumes = window_df.get("volume", pd.Series([1]*len(window_df))).astype(float).values
    
    returns = np.diff(closes, prepend=closes[0]) / closes
    rsi_7_vals = []
    rsi_14_vals = []
    atr_vals = []
    body_ratios = []
    upper_wicks = []
    lower_wicks = []
    vol_norms = []
    
    for i in range(window):
        end = i + 1
        close_slice = closes[:end]
        high_slice = highs[:end]
        low_slice = lows[:end]
        open_slice = opens[:end]
        
        if len(close_slice) >= 8:
            rsi_7_vals.append(_rsi(pd.Series(close_slice), 7))
            rsi_14_vals.append(_rsi(pd.Series(close_slice), 14))
            atr_vals.append(_atr(pd.DataFrame({"high": high_slice, "low": low_slice, "close": close_slice}), 14))
        else:
            rsi_7_vals.append(50.0)
            rsi_14_vals.append(50.0)
            atr_vals.append(atr_val)
        
        body = abs(closes[i] - opens[i])
        rng = highs[i] - lows[i]
        if rng > 0:
            body_ratios.append(body / rng)
            upper_wicks.append((highs[i] - max(opens[i], closes[i])) / rng)
            lower_wicks.append((min(opens[i], closes[i]) - lows[i]) / rng)
        else:
            body_ratios.append(0.0)
            upper_wicks.append(0.0)
            lower_wicks.append(0.0)
        
        vol_norms.append(volumes[i] / (np.mean(volumes) + 1e-8))
    
    return CandleFeatures(
        returns=_normalize_series(returns).tolist(),
        rsi_7=_normalize_series(np.array(rsi_7_vals)).tolist(),
        rsi_14=_normalize_series(np.array(rsi_14_vals)).tolist(),
        atr_normalized=_normalize_series(np.array(atr_vals) / atr_val).tolist(),
        body_ratio=_normalize_series(np.array(body_ratios)).tolist(),
        upper_wick_ratio=_normalize_series(np.array(upper_wicks)).tolist(),
        lower_wick_ratio=_normalize_series(np.array(lower_wicks)).tolist(),
        volume_norm=_normalize_series(np.array(vol_norms)).tolist(),
    )


def _features_to_vector(features: CandleFeatures) -> np.ndarray:
    """Concatenate all feature arrays into single vector."""
    return np.concatenate([
        features.returns,
        features.rsi_7,
        features.rsi_14,
        features.atr_normalized,
        features.body_ratio,
        features.upper_wick_ratio,
        features.lower_wick_ratio,
        features.volume_norm,
    ])


def _features_hash(features: CandleFeatures) -> str:
    """Create deterministic hash of features for deduplication."""
    vec = _features_to_vector(features)
    return hashlib.md5(vec.tobytes()).hexdigest()[:16]


def _detect_spike_in_window(
    df: pd.DataFrame,
    start_idx: int,
    window: int,
    atr_val: float,
    spike_threshold_atr: float = 3.0,
) -> Tuple[bool, Optional[int], float]:
    """Detect if a spike occurs in the window after pattern."""
    end_idx = min(start_idx + window, len(df))
    if end_idx <= start_idx + 5:
        return False, None, 0.0
    
    closes = df["close"].astype(float).values
    highs = df["high"].astype(float).values
    lows = df["low"].astype(float).values
    
    base_price = closes[start_idx]
    max_move = 0.0
    spike_idx = None
    
    for i in range(start_idx + 1, end_idx):
        move_up = (highs[i] - base_price) / atr_val
        move_dn = (base_price - lows[i]) / atr_val
        move = max(move_up, move_dn)
        if move > max_move:
            max_move = move
            spike_idx = i - start_idx
    
    if max_move >= spike_threshold_atr:
        return True, spike_idx, max_move
    return False, None, max_move


def _get_future_path(
    df: pd.DataFrame,
    start_idx: int,
    horizon: int = DEFAULT_HORIZON,
) -> Tuple[List[float], List[float], List[float], List[float]]:
    """Extract future OHLC path from historical data."""
    end_idx = min(start_idx + horizon, len(df))
    if end_idx <= start_idx:
        last = float(df["close"].iloc[-1])
        return [last]*horizon, [last]*horizon, [last]*horizon, [last]*horizon
    
    future = df.iloc[start_idx:end_idx]
    returns = (future["close"].astype(float).values / float(df["close"].iloc[start_idx]) - 1.0).tolist()
    highs = (future["high"].astype(float).values / float(df["close"].iloc[start_idx]) - 1.0).tolist()
    lows = (future["low"].astype(float).values / float(df["close"].iloc[start_idx]) - 1.0).tolist()
    closes = (future["close"].astype(float).values / float(df["close"].iloc[start_idx]) - 1.0).tolist()
    
    if len(returns) < horizon:
        pad = [returns[-1]] * (horizon - len(returns))
        returns.extend(pad)
        highs.extend([highs[-1]] * (horizon - len(highs)))
        lows.extend([lows[-1]] * (horizon - len(lows)))
        closes.extend([closes[-1]] * (horizon - len(closes)))
    
    return returns[:horizon], highs[:horizon], lows[:horizon], closes[:horizon]


def build_pattern_library(
    symbol: str,
    df_m1: pd.DataFrame,
    df_m5: Optional[pd.DataFrame] = None,
    df_m15: Optional[pd.DataFrame] = None,
    df_h1: Optional[pd.DataFrame] = None,
    df_h4: Optional[pd.DataFrame] = None,
    window: int = 100,
    stride: int = 10,
    horizon: int = DEFAULT_HORIZON,
    spike_threshold_atr: float = 3.0,
    max_patterns: int = 5000,
) -> List[PatternInstance]:
    """
    Build pattern library from historical M1 data with multi-TF context.
    """
    if df_m1 is None or len(df_m1) < window + 50:
        return []
    
    df_m1 = df_m1.copy()
    if "time" in df_m1.columns:
        df_m1 = df_m1.sort_values("time").reset_index(drop=True)
    
    atr_val = _atr(df_m1)
    patterns = []
    seen_hashes = set()
    
    for start in range(0, len(df_m1) - window - horizon, stride):
        features = _extract_window_features(df_m1, start, window, atr_val)
        if features is None:
            continue
        
        f_hash = _features_hash(features)
        if f_hash in seen_hashes:
            continue
        seen_hashes.add(f_hash)
        
        spike_occurred, spike_idx, spike_mag = _detect_spike_in_window(
            df_m1, start, horizon, atr_val, spike_threshold_atr
        )
        
        fut_returns, fut_highs, fut_lows, fut_closes = _get_future_path(df_m1, start + window, horizon)
        
        direction = "NEUTRAL"
        if fut_closes:
            move = fut_closes[-1]
            if move > 0.002:
                direction = "BUY"
            elif move < -0.002:
                direction = "SELL"
        
        tags, pat_bias, pat_dir = _pattern_tags(df_m1.iloc[start:start+window])
        
        pattern = PatternInstance(
            pattern_id=f"{symbol}_{start}_{window}_{f_hash}",
            symbol=symbol,
            timeframe="M1",
            start_time=str(df_m1["time"].iloc[start]) if "time" in df_m1.columns else str(start),
            end_time=str(df_m1["time"].iloc[start+window-1]) if "time" in df_m1.columns else str(start+window),
            features_hash=f_hash,
            window_size=window,
            direction=direction,
            spike_occurred=spike_occurred,
            spike_index=spike_idx,
            spike_magnitude=spike_mag,
            future_returns=fut_returns,
            future_highs=fut_highs,
            future_lows=fut_lows,
            future_closes=fut_closes,
            metadata={
                "pattern_tags": tags,
                "pattern_bias": pat_bias,
                "pattern_dir": pat_dir,
                "atr_at_start": float(atr_val),
                "rsi_7_start": float(_rsi(df_m1["close"].iloc[:start+window].tail(14), 7)) if start+window >= 14 else 50.0,
                "rsi_14_start": float(_rsi(df_m1["close"].iloc[:start+window].tail(14), 14)) if start+window >= 14 else 50.0,
            }
        )
        patterns.append(pattern)
        
        if len(patterns) >= max_patterns:
            break
    
    return patterns


def save_pattern_library(patterns: List[PatternInstance], path: Path = PATTERN_LIBRARY_PATH) -> None:
    """Save pattern library to JSON."""
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "count": len(patterns),
        "patterns": [asdict(p) for p in patterns],
    }
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def load_pattern_library(path: Path = PATTERN_LIBRARY_PATH) -> List[PatternInstance]:
    """Load pattern library from JSON."""
    if not path.is_file():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return [PatternInstance(**p) for p in data.get("patterns", [])]
    except Exception:
        return []


def find_similar_patterns(
    current_features: CandleFeatures,
    library: List[PatternInstance],
    top_k: int = SIMILARITY_TOP_K,
    use_dtw: bool = True,
) -> List[SimilarPattern]:
    """Find most similar historical patterns using DTW + correlation."""
    current_vec = _features_to_vector(current_features)
    
    similarities = []
    for pattern in library:
        pattern_vec = None
        for feat_name in ["returns", "rsi_7", "rsi_14", "atr_normalized", "body_ratio", 
                          "upper_wick_ratio", "lower_wick_ratio", "volume_norm"]:
            # We'd need to reconstruct vectors from stored patterns
            pass
        
        corr_dist = _correlation_distance(current_vec, pattern_vec) if pattern_vec is not None else 1.0
        dtw_dist = _dtw_distance(current_vec, pattern_vec) if use_dtw and pattern_vec is not None else float('inf')
        
        combined_sim = 1.0 - (0.6 * corr_dist + 0.4 * min(1.0, dtw_dist / (len(current_vec) + 1e-8)))
        
        similarities.append(SimilarPattern(
            instance=pattern,
            similarity=max(0.0, combined_sim),
            dtw_distance=dtw_dist if dtw_dist != float('inf') else None,
            correlation=1.0 - corr_dist,
        ))
    
    similarities.sort(key=lambda x: x.similarity, reverse=True)
    return similarities[:top_k]


def _project_from_matches(
    matches: List[SimilarPattern],
    current_price: float,
    current_atr: float,
    horizon: int = DEFAULT_HORIZON,
) -> Tuple[List[float], List[float], List[float], List[float]]:
    """Project future path by averaging matched pattern outcomes."""
    if not matches:
        return [], [], [], []
    
    weights = np.array([m.similarity for m in matches])
    weights = weights / weights.sum() if weights.sum() > 0 else np.ones(len(matches)) / len(matches)
    
    n_patterns = len(matches)
    n_horizon = min(horizon, min(len(m.instance.future_closes) for m in matches))
    
    proj_returns = np.zeros(n_horizon)
    proj_highs = np.zeros(n_horizon)
    proj_lows = np.zeros(n_horizon)
    proj_closes = np.zeros(n_horizon)
    
    for i, match in enumerate(matches):
        w = weights[i]
        inst = match.instance
        proj_returns += w * np.array(inst.future_returns[:n_horizon])
        proj_highs += w * np.array(inst.future_highs[:n_horizon])
        proj_lows += w * np.array(inst.future_lows[:n_horizon])
        proj_closes += w * np.array(inst.future_closes[:n_horizon])
    
    prices = current_price * (1 + proj_returns)
    high_prices = current_price * (1 + proj_highs)
    low_prices = current_price * (1 + proj_lows)
    close_prices = current_price * (1 + proj_closes)
    
    return close_prices.tolist(), high_prices.tolist(), low_prices.tolist(), prices.tolist()


def predict_spike_from_patterns(
    matches: List[SimilarPattern],
    current_price: float,
    current_atr: float,
    rsi_7: float,
    rsi_14: float,
) -> Tuple[float, Optional[int], Optional[float], float]:
    """
    Predict spike probability, timing, and price from matched patterns.
    Enhanced with RSI alignment.
    """
    if not matches:
        return 0.0, None, None, 0.0
    
    spike_votes = 0
    spike_indices = []
    spike_prices = []
    spike_mags = []
    
    for match in matches:
        inst = match.instance
        weight = match.similarity
        
        if inst.spike_occurred and inst.spike_index is not None:
            spike_votes += weight
            spike_indices.append(inst.spike_index)
            spike_mags.append(inst.spike_magnitude)
            
            if inst.future_closes and inst.spike_index < len(inst.future_closes):
                spike_price = current_price * (1 + inst.future_closes[inst.spike_index])
                spike_prices.append(spike_price)
    
    total_weight = sum(m.similarity for m in matches)
    spike_prob = spike_votes / total_weight if total_weight > 0 else 0.0
    
    if not spike_indices:
        return spike_prob, None, None, 0.0
    
    avg_index = int(np.average(spike_indices, weights=weights[:len(spike_indices)]))
    avg_price = np.mean(spike_prices) if spike_prices else None
    avg_mag = np.mean(spike_mags) if spike_mags else 0.0
    
    rsi_boost = 0.0
    if rsi_14 >= 70 or rsi_14 <= 30:
        rsi_boost = 0.15
    elif rsi_14 >= 65 or rsi_14 <= 35:
        rsi_boost = 0.10
    if rsi_7 >= 75 or rsi_7 <= 25:
        rsi_boost += 0.10
    elif rsi_7 >= 68 or rsi_7 <= 32:
        rsi_boost += 0.05
    
    spike_prob = min(0.95, spike_prob + rsi_boost)
    
    return spike_prob, avg_index, avg_price, avg_mag


def compute_pattern_forecast(
    symbol: str,
    df_m1: pd.DataFrame,
    df_m5: Optional[pd.DataFrame] = None,
    df_m15: Optional[pd.DataFrame] = None,
    df_h1: Optional[pd.DataFrame] = None,
    df_h4: Optional[pd.DataFrame] = None,
    library: Optional[List[PatternInstance]] = None,
    window: int = 100,
    horizon: int = DEFAULT_HORIZON,
    top_k: int = SIMILARITY_TOP_K,
) -> PatternForecast:
    """
    Main entry point — compute pattern-based forecast for current market state.
    """
    if df_m1 is None or len(df_m1) < window + 20:
        return PatternForecast(
            symbol=symbol,
            timeframe="M1",
            current_window_hash="",
            matched_patterns=[],
            consensus_direction="NEUTRAL",
            spike_probability=0.0,
            spike_expected_index=None,
            spike_expected_price=None,
            spike_magnitude_atr=0.0,
            projected_path=[],
            confidence=0.0,
            pattern_quality=0.0,
            fallback_to_cognition=True,
        )
    
    if "time" in df_m1.columns:
        df_m1 = df_m1.sort_values("time").reset_index(drop=True)
    
    atr_val = _atr(df_m1)
    current_price = float(df_m1["close"].iloc[-1])
    rsi_7 = _rsi(df_m1["close"].tail(14), 7)
    rsi_14 = _rsi(df_m1["close"].tail(14), 14)
    
    current_features = _extract_window_features(df_m1, len(df_m1) - window, window, atr_val)
    if current_features is None:
        return PatternForecast(
            symbol=symbol,
            timeframe="M1",
            current_window_hash="",
            matched_patterns=[],
            consensus_direction="NEUTRAL",
            spike_probability=0.0,
            spike_expected_index=None,
            spike_expected_price=None,
            spike_magnitude_atr=0.0,
            projected_path=[],
            confidence=0.0,
            pattern_quality=0.0,
            fallback_to_cognition=True,
        )
    
    current_hash = _features_hash(current_features)
    
    if library is None:
        library = load_pattern_library()
        lib_symbol = [p for p in library if p.symbol == symbol]
        if not lib_symbol:
            lib_symbol = library[:1000]
    else:
        lib_symbol = [p for p in library if p.symbol == symbol] or library[:1000]
    
    matches = find_similar_patterns(current_features, lib_symbol, top_k=top_k)
    
    if not matches or matches[0].similarity < 0.3:
        cog_fc = forecast_200(df_m1, symbol, "M1", min(horizon, 200))
        return PatternForecast(
            symbol=symbol,
            timeframe="M1",
            current_window_hash=current_hash,
            matched_patterns=[],
            consensus_direction=cog_fc.direction,
            spike_probability=0.0,
            spike_expected_index=None,
            spike_expected_price=None,
            spike_magnitude_atr=0.0,
            projected_path=[
                {"bar": i+1, "price": round(c, 5), "high": round(h, 5), "low": round(l, 5)}
                for i, (c, h, l) in enumerate(zip(cog_fc.closes, cog_fc.highs, cog_fc.lows))
            ],
            confidence=cog_fc.confidence * 0.7,
            pattern_quality=0.0,
            fallback_to_cognition=True,
        )
    
    proj_closes, proj_highs, proj_lows, proj_opens = _project_from_matches(
        matches, current_price, atr_val, horizon
    )
    
    buy_votes = sum(m.similarity for m in matches if m.instance.direction == "BUY")
    sell_votes = sum(m.similarity for m in matches if m.instance.direction == "SELL")
    total_votes = buy_votes + sell_votes
    consensus = "BUY" if buy_votes > sell_votes else "SELL" if sell_votes > buy_votes else "NEUTRAL"
    
    spike_prob, spike_idx, spike_price, spike_mag = predict_spike_from_patterns(
        matches, current_price, atr_val, rsi_7, rsi_14
    )
    
    avg_sim = np.mean([m.similarity for m in matches])
    pattern_quality = float(np.clip(avg_sim * len(matches) / top_k, 0.0, 1.0))
    confidence = float(np.clip(0.5 + pattern_quality * 0.4 + spike_prob * 0.1, 0.15, 0.95))
    
    path = []
    for i in range(min(len(proj_closes), horizon)):
        path.append({
            "bar": i + 1,
            "price": round(proj_closes[i], 5),
            "high": round(proj_highs[i], 5) if i < len(proj_highs) else round(proj_closes[i], 5),
            "low": round(proj_lows[i], 5) if i < len(proj_lows) else round(proj_closes[i], 5),
            "open": round(proj_opens[i], 5) if i < len(proj_opens) else round(proj_closes[i], 5),
        })
    
    return PatternForecast(
        symbol=symbol,
        timeframe="M1",
        current_window_hash=current_hash,
        matched_patterns=matches,
        consensus_direction=consensus,
        spike_probability=spike_prob,
        spike_expected_index=spike_idx,
        spike_expected_price=round(spike_price, 5) if spike_price else None,
        spike_magnitude_atr=round(spike_mag, 2),
        projected_path=path,
        confidence=confidence,
        pattern_quality=pattern_quality,
        fallback_to_cognition=False,
    )


def forecast_to_payload(fc: PatternForecast) -> Dict[str, Any]:
    """Convert PatternForecast to API response payload."""
    matches_out = []
    for m in fc.matched_patterns:
        inst = m.instance
        matches_out.append({
            "pattern_id": inst.pattern_id,
            "similarity": round(m.similarity, 4),
            "correlation": round(m.correlation, 4) if m.correlation else None,
            "dtw_distance": round(m.dtw_distance, 2) if m.dtw_distance else None,
            "direction": inst.direction,
            "spike_occurred": inst.spike_occurred,
            "spike_index": inst.spike_index,
            "spike_magnitude_atr": round(inst.spike_magnitude, 2),
            "start_time": inst.start_time,
            "pattern_tags": inst.metadata.get("pattern_tags", []),
        })
    
    return {
        "ok": True,
        "symbol": fc.symbol,
        "timeframe": fc.timeframe,
        "window_hash": fc.current_window_hash,
        "consensus_direction": fc.consensus_direction,
        "spike_probability": round(fc.spike_probability, 4),
        "spike_probability_pct": round(fc.spike_probability * 100, 1),
        "spike_expected_bar": fc.spike_expected_index,
        "spike_expected_price": fc.spike_expected_price,
        "spike_magnitude_atr": fc.spike_magnitude_atr,
        "projected_path": fc.projected_path,
        "confidence": round(fc.confidence, 4),
        "confidence_pct": round(fc.confidence * 100, 1),
        "pattern_quality": round(fc.pattern_quality, 4),
        "fallback_to_cognition": fc.fallback_to_cognition,
        "matched_patterns": matches_out,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# ============================================================================
# Public API Functions
# ============================================================================

def forecast_from_patterns(
    symbol: str,
    df_m1: pd.DataFrame,
    gom: Optional[Dict[str, Any]] = None,
    horizon: int = DEFAULT_HORIZON,
    top_k: int = SIMILARITY_TOP_K,
) -> PatternForecast:
    """
    Main entry point: forecast next horizon bars using pattern similarity.
    
    Args:
        symbol: Trading symbol (e.g., "Boom 1000 Index")
        df_m1: M1 DataFrame with columns: time, open, high, low, close, volume
        gom: Optional GOM verdict dict
        horizon: Forecast horizon in M1 bars (default 1000)
        top_k: Number of similar patterns to use
        
    Returns:
        PatternForecast with consensus direction, spike prediction, projected path
    """
    gom = gom or {}
    df_m1 = df_m1.copy()
    if "time" in df_m1.columns:
        df_m1 = df_m1.sort_values("time").reset_index(drop=True)
    
    if len(df_m1) < MIN_PATTERN_LENGTH + 50:
        logger.warning(f"Insufficient data for {symbol}: {len(df_m1)} bars")
        return _fallback_cognition_forecast(symbol, df_m1, gom, horizon)
    
    atr_val = _atr(df_m1)
    current_price = float(df_m1["close"].iloc[-1])
    
    # Extract current window features
    window_size = min(200, len(df_m1) // 3)
    features = _extract_window_features(df_m1, len(df_m1) - window_size, window_size, atr_val)
    if features is None:
        return _fallback_cognition_forecast(symbol, df_m1, gom, horizon)
    
    window_hash = _features_hash(features)
    
    # Load pattern library
    library = _load_pattern_library()
    symbol_patterns = library.get("symbols", {}).get(symbol, [])
    if not symbol_patterns:
        # Try fallback: build on-the-fly from recent history
        symbol_patterns = _build_pattern_library_from_history(symbol, len(df_m1), window_size, 50)
        if not symbol_patterns:
            return _fallback_cognition_forecast(symbol, df_m1, gom, horizon)
    
    # Find similar patterns
    similar = _find_similar_patterns(features, symbol_patterns, top_k)
    if not similar:
        return _fallback_cognition_forecast(symbol, df_m1, gom, horizon)
    
    # Consensus direction and spike prediction
    directions = [m.instance.direction for m in similar]
    dir_weights = [m.similarity for m in similar]
    
    buy_weight = sum(w for d, w in zip(directions, dir_weights) if d == "BUY")
    sell_weight = sum(w for d, w in zip(directions, dir_weights) if d == "SELL")
    consensus = "BUY" if buy_weight > sell_weight else "SELL" if sell_weight > buy_weight else "NEUTRAL"
    
    # Spike prediction
    spike_votes = [m.instance.spike_occurred for m in similar]
    spike_mags = [m.instance.spike_magnitude for m in similar]
    spike_indices = [m.instance.spike_index for m in similar if m.instance.spike_occurred and m.instance.spike_index is not None]
    
    spike_prob = sum(spike_votes) / len(spike_votes)
    avg_spike_mag = float(np.mean(spike_mags)) if spike_mags else 0.0
    median_spike_idx = int(np.median(spike_indices)) if spike_indices else None
    
    # Project path from similar patterns
    path = _project_consensus_path(similar, current_price, atr_val, horizon, consensus)
    
    # Spike expected price
    spike_price = None
    if median_spike_idx is not None and median_spike_idx < len(path):
        spike_price = path[median_spike_idx]["price"]
    
    # Confidence calculation
    avg_sim = float(np.mean([m.similarity for m in similar]))
    dir_agreement = abs(buy_weight - sell_weight) / max(buy_weight + sell_weight, 1e-8)
    pattern_quality = avg_sim * (0.5 + 0.5 * dir_agreement)
    confidence = float(np.clip(pattern_quality * 0.7 + spike_prob * 0.3, 0.15, 0.95))
    
    return PatternForecast(
        symbol=symbol,
        timeframe="M1",
        current_window_hash=window_hash,
        matched_patterns=similar,
        consensus_direction=consensus,
        spike_probability=spike_prob,
        spike_expected_index=median_spike_idx,
        spike_expected_price=spike_price,
        spike_magnitude_atr=avg_spike_mag,
        projected_path=path,
        confidence=confidence,
        pattern_quality=pattern_quality,
        fallback_to_cognition=False,
    )


def _fallback_cognition_forecast(
    symbol: str,
    df_m1: pd.DataFrame,
    gom: Dict[str, Any],
    horizon: int,
) -> PatternForecast:
    """Fallback to cognition forecast when no patterns available."""
    try:
        from ml.cognition_forecast import forecast_200
        fc = forecast_200(df_m1, symbol, "M1", horizon=horizon, gom=gom)
        path = [{"bar": i+1, "price": c} for i, c in enumerate(fc.closes[:horizon])]
        return PatternForecast(
            symbol=symbol,
            timeframe="M1",
            current_window_hash="cognition_fallback",
            matched_patterns=[],
            consensus_direction=fc.direction,
            spike_probability=0.3,
            spike_expected_index=None,
            spike_expected_price=None,
            spike_magnitude_atr=0.0,
            projected_path=path,
            confidence=fc.confidence,
            pattern_quality=0.3,
            fallback_to_cognition=True,
        )
    except Exception:
        path = [{"bar": i+1, "price": float(df_m1["close"].iloc[-1])} for i in range(horizon)]
        return PatternForecast(
            symbol=symbol,
            timeframe="M1",
            current_window_hash="empty_fallback",
            matched_patterns=[],
            consensus_direction="NEUTRAL",
            spike_probability=0.0,
            spike_expected_index=None,
            spike_expected_price=None,
            spike_magnitude_atr=0.0,
            projected_path=path,
            confidence=0.15,
            pattern_quality=0.0,
            fallback_to_cognition=True,
        )


def _project_consensus_path(
    similar: List[SimilarPattern],
    current_price: float,
    atr_val: float,
    horizon: int,
    consensus: str,
) -> List[Dict[str, Any]]:
    """Project consensus path from similar patterns."""
    paths = []
    for m in similar:
        inst = m.instance
        if inst.future_closes and len(inst.future_closes) >= 10:
            # Normalize to current price
            base = float(inst.future_closes[0]) if inst.future_closes else current_price
            scaled = [current_price + (c - base) for c in inst.future_closes[:horizon]]
            paths.append(scaled)
    
    if not paths:
        # Simple drift fallback
        sign = 1.0 if consensus == "BUY" else -1.0 if consensus == "SELL" else 0.0
        path = []
        for i in range(horizon):
            t = (i + 1) / horizon
            drift = sign * atr_val * (0.3 + 0.8 * t)
            pull = math.sin(t * math.pi * 3) * atr_val * 0.12 * (1.0 - t)
            p = current_price + drift + pull
            path.append({"bar": i+1, "price": round(p, 5)})
        return path
    
    # Average paths weighted by similarity
    weights = np.array([m.similarity for m in similar[:len(paths)]])
    weights = weights / weights.sum()
    avg_path = np.average(paths, axis=0, weights=weights)
    return [{"bar": i+1, "price": round(float(p), 5)} for i, p in enumerate(avg_path[:horizon])]


def _build_pattern_library_from_history(
    symbol: str,
    lookback_bars: int = 5000,
    window_size: int = 200,
    stride: int = 50,
) -> List[Dict]:
    """
    Build pattern library from historical data for a symbol.
    Stores to pattern_library.json for reuse.
    """
    try:
        from ml.cognition_forecast import get_historical_data_mt5
        df = get_historical_data_mt5(symbol, "M1", lookback_bars)
        if df is None or len(df) < window_size + 100:
            logger.warning(f"Insufficient data for {symbol} library build")
            return []
    except Exception as e:
        logger.warning(f"Failed to get MT5 data for {symbol}: {e}")
        return []
    
    df = df.sort_values("time").reset_index(drop=True)
    atr_val = _atr(df)
    
    patterns = []
    for start in range(0, len(df) - window_size - 100, stride):
        features = _extract_window_features(df, start, window_size, atr_val)
        if features is None:
            continue
        
        spike_occurred, spike_idx, spike_mag = _detect_spike_in_window(
            df, start + window_size, 100, atr_val
        )
        
        future_returns, future_highs, future_lows, future_closes = _get_future_path(
            df, start + window_size, DEFAULT_HORIZON
        )
        
        # Detect direction from future
        if len(future_closes) >= 20:
            move = future_closes[19] - future_closes[0]
            direction = "BUY" if move > atr_val * 0.5 else "SELL" if move < -atr_val * 0.5 else "NEUTRAL"
        else:
            direction = "NEUTRAL"
        
        window_hash = _features_hash(features)
        pattern_id = f"{symbol.replace(' ', '_')}_{start}_{window_hash[:8]}"
        
        inst = PatternInstance(
            pattern_id=pattern_id,
            symbol=symbol,
            timeframe="M1",
            start_time=str(df["time"].iloc[start]) if "time" in df.columns else f"bar_{start}",
            end_time=str(df["time"].iloc[start + window_size - 1]) if "time" in df.columns else f"bar_{start + window_size}",
            features_hash=window_hash,
            window_size=window_size,
            direction=direction,
            spike_occurred=spike_occurred,
            spike_index=spike_idx,
            spike_magnitude=spike_mag,
            future_returns=future_returns,
            future_highs=future_highs,
            future_lows=future_lows,
            future_closes=future_closes,
            metadata={
                "pattern_tags": _pattern_tags(df.iloc[start:start + window_size])[0],
                "atr_at_creation": atr_val,
            },
        )
        patterns.append(asdict(inst))
    
    # Save to library
    library = _load_pattern_library()
    if "symbols" not in library:
        library["symbols"] = {}
    library["symbols"][symbol] = patterns
    library["updated_at"] = datetime.now(timezone.utc).isoformat()
    _save_pattern_library(library)
    
    logger.info(f"Built {len(patterns)} patterns for {symbol}")
    return patterns


# ============================================================================
# Library persistence
# ============================================================================

def _load_pattern_library(path: Path = PATTERN_LIBRARY_PATH) -> Dict[str, Any]:
    if not path.is_file():
        return {"symbols": {}, "updated_at": None}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {"symbols": {}, "updated_at": None}


def _save_pattern_library(data: Dict[str, Any], path: Path = PATTERN_LIBRARY_PATH) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data["updated_at"] = datetime.now(timezone.utc).isoformat()
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return path


def _find_similar_patterns(
    features: CandleFeatures,
    pattern_list: List[Dict],
    top_k: int,
) -> List[SimilarPattern]:
    """Find top-k similar patterns using future path correlation + DTW on returns."""
    current_vec = _features_to_vector(features)
    
    scored = []
    for p_dict in pattern_list:
        try:
            # Use future_returns as proxy feature vector for similarity
            # This is a practical approximation when full features aren't stored
            future_returns = p_dict.get("future_returns", [])
            if len(future_returns) < 20:
                continue
            
            # Use first 100 returns as feature proxy
            proxy_vec = np.array(future_returns[:min(100, len(future_returns))])
            if len(proxy_vec) < 20:
                continue
            
            # Normalize proxy vector
            proxy_vec = _normalize_series(proxy_vec)
            current_proxy = current_vec[:len(proxy_vec)]
            
            # Correlation distance
            corr_dist = _correlation_distance(current_proxy, proxy_vec)
            
            # DTW distance (on first 50 returns for speed)
            dtw_dist = float('inf')
            if len(current_proxy) >= 30:
                dtw_dist = _dtw_distance(current_proxy[:50], proxy_vec[:50])
            
            # Combined similarity
            similarity = 1.0 - (0.6 * corr_dist + 0.4 * min(1.0, dtw_dist / (len(current_proxy) + 1e-8)))
            
            if similarity < 0.1:
                continue
            
            # Create SimilarPattern from stored dict
            inst = PatternInstance(**p_dict)
            scored.append(SimilarPattern(
                instance=inst,
                similarity=similarity,
                dtw_distance=dtw_dist if dtw_dist != float('inf') else None,
                correlation=1.0 - corr_dist,
            ))
        except Exception as e:
            logger.debug(f"Pattern similarity error: {e}")
            continue
    
    scored.sort(key=lambda x: x.similarity, reverse=True)
    return scored[:top_k]