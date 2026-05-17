#!/usr/bin/env python3
"""
ML Feature Engineering - Convert raw market snapshots to ML-ready features
Normalizes, scales, and prepares data for model training and inference
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass


@dataclass
class FeatureNormalization:
    """Parameters for feature normalization and scaling"""
    mean: float = 0.0
    std: float = 1.0
    min_val: float = 0.0
    max_val: float = 1.0
    scale: str = "standard"  # standard, minmax, log


class FeatureEngineer:
    """Convert market snapshots to ML features"""

    def __init__(self):
        self.feature_names: List[str] = []
        self.feature_stats: Dict[str, Dict[str, float]] = {}

    def prepare_features_from_snapshot(self, snapshot: Dict[str, Any]) -> np.ndarray:
        """Convert a single indicator snapshot dict to ML feature vector"""

        features = []

        # === PRICE & SPREAD (normalized by bid) ===
        bid = float(snapshot.get('bid', 0))
        ask = float(snapshot.get('ask', 0))
        spread = float(snapshot.get('spread_pips', 0))

        if bid > 0:
            features.append(spread / bid * 10000)  # Spread as fraction
        else:
            features.append(0.0)

        # === MOMENTUM (normalized to 0-100) ===
        features.append(float(snapshot.get('rsi_m1', 50)) / 100.0)  # 0-1
        features.append(float(snapshot.get('rsi_m5', 50)) / 100.0)
        features.append(float(snapshot.get('rsi_m15', 50)) / 100.0)
        features.append(float(snapshot.get('rsi_h1', 50)) / 100.0)

        # === VOLATILITY RATIOS ===
        atr_m1 = float(snapshot.get('atr_m1', 0))
        atr_m5 = float(snapshot.get('atr_m5', 0))
        atr_m15 = float(snapshot.get('atr_m15', 0))
        atr_h1 = float(snapshot.get('atr_h1', 0))
        atr_ratio = float(snapshot.get('atr_ratio', 1.0))

        features.append(min(atr_ratio, 3.0) / 3.0)  # Cap at 3.0
        features.append(atr_m1 / max(atr_m5, 0.00001))  # M1 vs M5
        features.append(atr_m5 / max(atr_m15, 0.00001))  # M5 vs M15
        features.append(atr_m15 / max(atr_h1, 0.00001))  # M15 vs H1

        # === TREND STRENGTH (EMA distance) ===
        ema_fast_m1 = float(snapshot.get('ema_fast_m1', bid))
        ema_slow_m1 = float(snapshot.get('ema_slow_m1', bid))
        ema_fast_m5 = float(snapshot.get('ema_fast_m5', bid))
        ema_slow_m5 = float(snapshot.get('ema_slow_m5', bid))
        ema_fast_m15 = float(snapshot.get('ema_fast_m15', bid))
        ema_slow_m15 = float(snapshot.get('ema_slow_m15', bid))
        ema_fast_h1 = float(snapshot.get('ema_fast_h1', bid))
        ema_slow_h1 = float(snapshot.get('ema_slow_h1', bid))

        if bid > 0:
            m1_trend = (ema_fast_m1 - ema_slow_m1) / bid
            m5_trend = (ema_fast_m5 - ema_slow_m5) / bid
            m15_trend = (ema_fast_m15 - ema_slow_m15) / bid
            h1_trend = (ema_fast_h1 - ema_slow_h1) / bid
        else:
            m1_trend = m5_trend = m15_trend = h1_trend = 0.0

        # Tanh to bound [-1, 1]
        features.append(np.tanh(m1_trend))
        features.append(np.tanh(m5_trend))
        features.append(np.tanh(m15_trend))
        features.append(np.tanh(h1_trend))

        # === SMC STRUCTURES (binary + proximity) ===
        features.append(1.0 if snapshot.get('fvg_detected', False) else 0.0)
        features.append(float(snapshot.get('fvg_direction', 0)))
        features.append(1.0 if snapshot.get('bos_detected', False) else 0.0)
        features.append(float(snapshot.get('bos_direction', 0)))

        ob_proximity = float(snapshot.get('ob_proximity_atr', 0))
        features.append(min(ob_proximity / 2.0, 1.0))  # Normalize to [0, 1]

        features.append(1.0 if snapshot.get('sweep_detected', False) else 0.0)

        # === KOLA LEVELS (proximity to price) ===
        m5_buy = float(snapshot.get('m5_buy_level', bid))
        m5_sell = float(snapshot.get('m5_sell_level', bid))
        m5_touches = float(snapshot.get('m5_buy_touches', 0) + snapshot.get('m5_sell_touches', 0))

        if bid > 0:
            features.append(abs(bid - m5_buy) / bid)
            features.append(abs(bid - m5_sell) / bid)
        else:
            features.append(0.0)
            features.append(0.0)

        features.append(min(m5_touches / 5.0, 1.0))  # Normalize touches

        # === CONFLUENCE SCORES (0-5 range to 0-1) ===
        buy_score = float(snapshot.get('tech_buy_score', 0))
        sell_score = float(snapshot.get('tech_sell_score', 0))

        features.append(min(buy_score / 5.0, 1.0))
        features.append(min(sell_score / 5.0, 1.0))
        features.append(float(snapshot.get('entry_quality', 0)) / 100.0)

        # === SPIKE PROBABILITY ===
        features.append(float(snapshot.get('spike_probability', 0)))

        # === BOLLINGER BANDS ===
        features.append(1.0 if snapshot.get('bb_squeeze', False) else 0.0)
        features.append(float(snapshot.get('vwap_distance_pct', 0)) / 100.0)
        features.append(float(snapshot.get('bb_pctb', 0.5)))  # Usually 0-1
        features.append(float(snapshot.get('bb_width_pct', 0)))

        # === VOLUME ===
        volume_ratio = float(snapshot.get('volume_ratio', 1.0))
        features.append(min(volume_ratio / 2.0, 1.0))

        # === SIDO PATTERNS ===
        features.append(1.0 if snapshot.get('sido_double_top', False) else 0.0)
        features.append(1.0 if snapshot.get('sido_double_bottom', False) else 0.0)

        # === MULTI-TIMEFRAME COHERENCE ===
        coherence = float(snapshot.get('coherence_score', 0.5))
        features.append(min(coherence, 1.0))

        # === CURRENT SIGNAL ===
        action = str(snapshot.get('signal_action', 'HOLD')).upper()
        features.append(1.0 if action == 'BUY' else (-1.0 if action == 'SELL' else 0.0))
        features.append(float(snapshot.get('signal_confidence', 0)))

        return np.array(features, dtype=np.float32)

    def prepare_feature_matrix(self, snapshots: List[Dict[str, Any]]) -> np.ndarray:
        """Convert list of snapshots to feature matrix (n_samples x n_features)"""
        features_list = []

        for snapshot in snapshots:
            try:
                features = self.prepare_features_from_snapshot(snapshot)
                features_list.append(features)
            except Exception as e:
                print(f"Warning: Failed to process snapshot: {e}")
                continue

        if not features_list:
            raise ValueError("No valid snapshots could be processed")

        return np.array(features_list, dtype=np.float32)

    def prepare_labels_from_outcome(self,
                                   actual_direction: Optional[int],
                                   actual_profit: Optional[float]) -> np.ndarray:
        """Convert outcome data to labels for ML (direction and profitability)"""

        labels = []

        # Direction label: -1 (down), 0 (neutral), 1 (up)
        if actual_direction is not None:
            labels.append(int(actual_direction))
        else:
            labels.append(0)

        # Profitability: 1 (profitable), 0 (breakeven), -1 (loss)
        if actual_profit is not None:
            if actual_profit > 0:
                labels.append(1)
            elif actual_profit < 0:
                labels.append(-1)
            else:
                labels.append(0)
        else:
            labels.append(0)

        return np.array(labels, dtype=np.int8)

    def normalize_features(self, features: np.ndarray,
                          method: str = 'standard') -> np.ndarray:
        """Normalize feature vector using standard or minmax scaling"""

        if method == 'standard':
            # Z-score normalization
            mean = np.mean(features, axis=0)
            std = np.std(features, axis=0)
            # Avoid division by zero
            std[std == 0] = 1.0
            return (features - mean) / std

        elif method == 'minmax':
            # Min-max scaling to [0, 1]
            min_val = np.min(features, axis=0)
            max_val = np.max(features, axis=0)
            # Avoid division by zero
            range_val = max_val - min_val
            range_val[range_val == 0] = 1.0
            return (features - min_val) / range_val

        elif method == 'robust':
            # Robust scaling using median and IQR
            median = np.median(features, axis=0)
            q75 = np.percentile(features, 75, axis=0)
            q25 = np.percentile(features, 25, axis=0)
            iqr = q75 - q25
            iqr[iqr == 0] = 1.0
            return (features - median) / iqr

        else:
            raise ValueError(f"Unknown normalization method: {method}")

    def get_feature_importance_names(self) -> List[str]:
        """Return list of feature names for model interpretation"""
        return [
            'spread_pct', 'rsi_m1', 'rsi_m5', 'rsi_m15', 'rsi_h1',
            'atr_ratio', 'atr_m1_m5', 'atr_m5_m15', 'atr_m15_h1',
            'trend_m1', 'trend_m5', 'trend_m15', 'trend_h1',
            'fvg_detected', 'fvg_direction', 'bos_detected', 'bos_direction',
            'ob_proximity', 'sweep_detected',
            'm5_buy_dist', 'm5_sell_dist', 'm5_touches_norm',
            'confluence_buy', 'confluence_sell', 'entry_quality', 'spike_prob',
            'bb_squeeze', 'vwap_dist', 'bb_pctb', 'bb_width',
            'volume_ratio',
            'sido_top', 'sido_bottom',
            'coherence',
            'signal_action', 'signal_confidence'
        ]

    @staticmethod
    def create_training_dataset(snapshots_df: pd.DataFrame,
                               engineer: 'FeatureEngineer') -> Tuple[np.ndarray, np.ndarray]:
        """Create training dataset from snapshots DataFrame

        Args:
            snapshots_df: DataFrame of market_data_snapshots from database
            engineer: FeatureEngineer instance

        Returns:
            Tuple of (X: features, y: labels) for training
        """
        snapshots = snapshots_df.to_dict('records')
        X = engineer.prepare_feature_matrix(snapshots)

        # Create labels from outcome columns
        labels = []
        for _, row in snapshots_df.iterrows():
            direction = row.get('direction_5min')
            profit = row.get('profit_5min')
            label = engineer.prepare_labels_from_outcome(direction, profit)
            labels.append(label)

        y = np.array(labels, dtype=np.int8)

        return X, y

    @staticmethod
    def create_prediction_input(snapshot: Dict[str, Any],
                               engineer: 'FeatureEngineer') -> np.ndarray:
        """Prepare a single snapshot for model prediction

        Args:
            snapshot: Dict with indicator data from EA
            engineer: FeatureEngineer instance

        Returns:
            Feature vector ready for model.predict()
        """
        features = engineer.prepare_features_from_snapshot(snapshot)
        # Reshape to (1, n_features) for sklearn compatibility
        return features.reshape(1, -1)


# ============================================================================
# Convenience functions
# ============================================================================

def engineer_features(snapshot: Dict[str, Any]) -> np.ndarray:
    """Quick feature engineering without creating Engineer instance"""
    engineer = FeatureEngineer()
    return engineer.prepare_features_from_snapshot(snapshot)


def engineer_batch(snapshots: List[Dict[str, Any]]) -> np.ndarray:
    """Quick batch feature engineering"""
    engineer = FeatureEngineer()
    return engineer.prepare_feature_matrix(snapshots)


if __name__ == "__main__":
    # Test example
    engineer = FeatureEngineer()

    # Sample snapshot
    test_snapshot = {
        'symbol': 'Boom 500 Index',
        'bid': 15750.0,
        'ask': 15751.0,
        'spread_pips': 10.0,
        'rsi_m1': 55.0,
        'rsi_m5': 60.0,
        'rsi_m15': 65.0,
        'rsi_h1': 70.0,
        'atr_m1': 50.0,
        'atr_m5': 45.0,
        'atr_m15': 40.0,
        'atr_h1': 35.0,
        'atr_ratio': 1.2,
        'ema_fast_m1': 15760.0,
        'ema_slow_m1': 15750.0,
        'ema_fast_m5': 15755.0,
        'ema_slow_m5': 15740.0,
        'ema_fast_m15': 15758.0,
        'ema_slow_m15': 15745.0,
        'ema_fast_h1': 15760.0,
        'ema_slow_h1': 15740.0,
        'fvg_detected': True,
        'fvg_direction': 1,
        'bos_detected': False,
        'bos_direction': 0,
        'tech_buy_score': 4.5,
        'tech_sell_score': 1.5,
        'entry_quality': 75,
        'spike_probability': 0.85,
        'signal_action': 'BUY',
        'signal_confidence': 0.82,
    }

    features = engineer.prepare_features_from_snapshot(test_snapshot)
    print(f"Feature vector shape: {features.shape}")
    print(f"Features: {features}")
    print(f"Feature names: {engineer.get_feature_importance_names()}")

