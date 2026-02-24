"""
Système de Recommandation ML pour Robot MT5
==========================================

Ce module transforme les métriques ML en recommandations intelligentes pour le robot de trading.

Fonctionnalités:
- Analyse des métriques ML en temps réel
- Recommandations de trading (quand trader, quels symboles, ordres limites)
- Logique de clôture et trailing stop
- Scoring des opportunités par symbole
- Intégration avec le système de décision ML existant
"""

import asyncio
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)

class TradingAction(Enum):
    """Actions de trading recommandées"""
    STRONG_BUY = "strong_buy"
    BUY = "buy"
    WEAK_BUY = "weak_buy"
    HOLD = "hold"
    WEAK_SELL = "weak_sell"
    SELL = "sell"
    STRONG_SELL = "strong_sell"
    CLOSE_POSITION = "close_position"
    TRAILING_STOP = "trailing_stop"

class OpportunityLevel(Enum):
    """Niveau d'opportunité"""
    EXCELLENT = "excellent"
    GOOD = "good"
    MODERATE = "moderate"
    POOR = "poor"
    AVOID = "avoid"

@dataclass
class MLRecommendation:
    """Recommandation ML complète"""
    symbol: str
    action: TradingAction
    confidence: float
    opportunity_score: float
    opportunity_level: OpportunityLevel
    reason: str
    should_trade: bool
    should_limit_order: bool
    limit_order_price: Optional[float]
    should_close: bool
    trailing_stop_distance: Optional[float]
    timeframe_priority: str
    risk_level: str
    timestamp: datetime
    ml_metrics: Dict[str, Any]

@dataclass
class SymbolOpportunity:
    """Opportunité par symbole"""
    symbol: str
    total_score: float
    buy_opportunity: float
    sell_opportunity: float
    hold_opportunity: float
    volatility_risk: float
    trend_strength: float
    ml_confidence: float
    last_updated: datetime

class MLRecommendationSystem:
    """
    Système de recommandation ML qui transforme les métriques en décisions de trading
    """

    def __init__(self, ml_trainer):
        self.ml_trainer = ml_trainer
        self.symbol_opportunities: Dict[str, SymbolOpportunity] = {}
        self.last_analysis = None
        self.min_confidence_threshold = 0.65  # Seuil minimum de confiance pour trader
        self.high_confidence_threshold = 0.80  # Seuil pour actions fortes
        self.max_risk_tolerance = 0.7  # Tolérance maximale au risque

    def analyze_ml_metrics(self) -> Dict[str, Any]:
        """
        Analyse les métriques ML et génère des recommandations complètes
        """
        try:
            # Récupérer les métriques ML actuelles
            ml_metrics = self.ml_trainer.get_current_metrics()
            if not ml_metrics:
                logger.warning("Aucune métrique ML disponible pour l'analyse")
                return self._get_empty_recommendations()

            recommendations = []
            symbol_opportunities = []

            # Analyser chaque symbole
            for symbol_key, symbol_data in ml_metrics.get("symbols", {}).items():
                symbol = symbol_key.split("_")[0]  # Extraire le symbole (EURUSD_M1 -> EURUSD)
                timeframe = symbol_key.split("_")[1] if "_" in symbol_key else "M1"

                recommendation = self._analyze_symbol_metrics(symbol, timeframe, symbol_data)
                if recommendation:
                    recommendations.append(recommendation)

                    # Calculer l'opportunité globale du symbole
                    opportunity = self._calculate_symbol_opportunity(symbol, recommendations)
                    if opportunity:
                        symbol_opportunities.append(opportunity)

            # Trier par opportunité
            symbol_opportunities.sort(key=lambda x: x.total_score, reverse=True)
            recommendations.sort(key=lambda x: x.opportunity_score, reverse=True)

            # Générer le résumé global
            summary = self._generate_trading_summary(recommendations, symbol_opportunities)

            result = {
                "timestamp": datetime.now().isoformat(),
                "total_symbols_analyzed": len(set(r.symbol for r in recommendations)),
                "recommendations": [self._recommendation_to_dict(r) for r in recommendations],
                "symbol_opportunities": [self._opportunity_to_dict(o) for o in symbol_opportunities],
                "trading_summary": summary,
                "market_sentiment": self._calculate_market_sentiment(recommendations),
                "risk_assessment": self._assess_overall_risk(recommendations)
            }

            self.last_analysis = result
            return result

        except Exception as e:
            logger.error(f"Erreur lors de l'analyse des métriques ML: {e}")
            return self._get_empty_recommendations()

    def _analyze_symbol_metrics(self, symbol: str, timeframe: str, metrics: Dict[str, Any]) -> Optional[MLRecommendation]:
        """
        Analyse les métriques d'un symbole spécifique et génère une recommandation
        """
        try:
            # Extraire les métriques clés
            accuracy = metrics.get("accuracy", 0.5)
            f1_score = metrics.get("f1_score", 0.5)
            feature_importance = metrics.get("feature_importance", {})
            sample_count = metrics.get("sample_count", 0)

            # Calculer le score de confiance ML composite
            ml_confidence = (accuracy + f1_score) / 2.0

            # Analyser l'importance des features pour la direction
            trend_direction = self._analyze_trend_direction(feature_importance, metrics)

            # Calculer le score d'opportunité
            opportunity_score = self._calculate_opportunity_score(
                ml_confidence, trend_direction, sample_count, timeframe
            )

            # Déterminer le niveau d'opportunité
            opportunity_level = self._determine_opportunity_level(opportunity_score, ml_confidence)

            # Générer l'action recommandée
            action, confidence = self._determine_trading_action(
                trend_direction, ml_confidence, opportunity_level
            )

            # Décisions spécifiques
            should_trade = self._should_trade(confidence, opportunity_level)
            should_limit_order = self._should_use_limit_order(action, confidence, opportunity_level)
            limit_order_price = self._calculate_limit_order_price(symbol, action, confidence) if should_limit_order else None
            should_close = self._should_close_position(action, confidence)
            trailing_stop_distance = self._calculate_trailing_stop(action, confidence, opportunity_level)

            # Déterminer la priorité du timeframe
            timeframe_priority = self._get_timeframe_priority(timeframe, opportunity_score)

            # Évaluer le niveau de risque
            risk_level = self._assess_risk_level(symbol, action, confidence, opportunity_level)

            # Construire la recommandation
            recommendation = MLRecommendation(
                symbol=symbol,
                action=action,
                confidence=confidence,
                opportunity_score=opportunity_score,
                opportunity_level=opportunity_level,
                reason=self._generate_reason(action, confidence, opportunity_score, ml_confidence),
                should_trade=should_trade,
                should_limit_order=should_limit_order,
                limit_order_price=limit_order_price,
                should_close=should_close,
                trailing_stop_distance=trailing_stop_distance,
                timeframe_priority=timeframe_priority,
                risk_level=risk_level,
                timestamp=datetime.now(),
                ml_metrics=metrics
            )

            return recommendation

        except Exception as e:
            logger.error(f"Erreur analyse métriques pour {symbol}: {e}")
            return None

    def _analyze_trend_direction(self, feature_importance: Dict, metrics: Dict) -> str:
        """
        Analyse la direction de tendance basée sur l'importance des features
        """
        # Analyser les patterns dans les features importantes
        bullish_indicators = ['rsi_oversold', 'ema_cross_up', 'support_near', 'bullish_candle']
        bearish_indicators = ['rsi_overbought', 'ema_cross_down', 'resistance_near', 'bearish_candle']

        bullish_score = sum(feature_importance.get(indicator, 0) for indicator in bullish_indicators)
        bearish_score = sum(feature_importance.get(indicator, 0) for indicator in bearish_indicators)

        if bullish_score > bearish_score * 1.2:
            return "bullish"
        elif bearish_score > bullish_score * 1.2:
            return "bearish"
        else:
            return "neutral"

    def _calculate_opportunity_score(self, ml_confidence: float, trend_direction: str,
                                   sample_count: int, timeframe: str) -> float:
        """
        Calcule le score d'opportunité global
        """
        # Base score sur la confiance ML
        base_score = ml_confidence

        # Bonus pour la taille d'échantillon (plus de données = meilleure fiabilité)
        sample_bonus = min(0.2, sample_count / 10000)  # Max 0.2 bonus pour 10k+ échantillons

        # Bonus/malus selon la direction de tendance
        direction_multiplier = 1.0
        if trend_direction == "neutral":
            direction_multiplier = 0.8  # Légère pénalité pour neutralité
        elif trend_direction in ["bullish", "bearish"]:
            direction_multiplier = 1.1  # Bonus pour tendance claire

        # Bonus selon le timeframe (H1 > M5 > M1 pour stabilité)
        timeframe_multiplier = 1.0
        if timeframe == "H1":
            timeframe_multiplier = 1.15
        elif timeframe == "M5":
            timeframe_multiplier = 1.05
        elif timeframe == "M1":
            timeframe_multiplier = 0.95  # Pénalité légère pour M1 (plus de bruit)

        opportunity_score = base_score * direction_multiplier * timeframe_multiplier + sample_bonus
        return min(1.0, max(0.0, opportunity_score))  # Bornes [0, 1]

    def _determine_opportunity_level(self, opportunity_score: float, ml_confidence: float) -> OpportunityLevel:
        """
        Détermine le niveau d'opportunité
        """
        combined_score = (opportunity_score + ml_confidence) / 2.0

        if combined_score >= 0.85:
            return OpportunityLevel.EXCELLENT
        elif combined_score >= 0.75:
            return OpportunityLevel.GOOD
        elif combined_score >= 0.65:
            return OpportunityLevel.MODERATE
        elif combined_score >= 0.55:
            return OpportunityLevel.POOR
        else:
            return OpportunityLevel.AVOID

    def _determine_trading_action(self, trend_direction: str, ml_confidence: float,
                                opportunity_level: OpportunityLevel) -> Tuple[TradingAction, float]:
        """
        Détermine l'action de trading recommandée
        """
        # Ajuster la confiance selon l'opportunité
        adjusted_confidence = ml_confidence
        if opportunity_level == OpportunityLevel.EXCELLENT:
            adjusted_confidence = min(1.0, ml_confidence * 1.1)
        elif opportunity_level == OpportunityLevel.POOR:
            adjusted_confidence = max(0.0, ml_confidence * 0.9)

        # Déterminer l'action selon la direction et confiance
        if trend_direction == "bullish":
            if adjusted_confidence >= self.high_confidence_threshold:
                return TradingAction.STRONG_BUY, adjusted_confidence
            elif adjusted_confidence >= self.min_confidence_threshold:
                return TradingAction.BUY, adjusted_confidence
            else:
                return TradingAction.WEAK_BUY, adjusted_confidence
        elif trend_direction == "bearish":
            if adjusted_confidence >= self.high_confidence_threshold:
                return TradingAction.STRONG_SELL, adjusted_confidence
            elif adjusted_confidence >= self.min_confidence_threshold:
                return TradingAction.SELL, adjusted_confidence
            else:
                return TradingAction.WEAK_SELL, adjusted_confidence
        else:  # neutral
            if adjusted_confidence < 0.6:
                return TradingAction.HOLD, adjusted_confidence
            else:
                # Pour neutral avec bonne confiance, recommander selon momentum récent
                return TradingAction.HOLD, adjusted_confidence * 0.8

    def _should_trade(self, confidence: float, opportunity_level: OpportunityLevel) -> bool:
        """
        Détermine si on devrait trader
        """
        if opportunity_level in [OpportunityLevel.AVOID, OpportunityLevel.POOR]:
            return False

        return confidence >= self.min_confidence_threshold

    def _should_use_limit_order(self, action: TradingAction, confidence: float,
                              opportunity_level: OpportunityLevel) -> bool:
        """
        Détermine si on devrait utiliser un ordre limite
        """
        # Ordres limites pour actions fortes avec haute confiance
        if action in [TradingAction.STRONG_BUY, TradingAction.STRONG_SELL]:
            return confidence >= self.high_confidence_threshold

        # Ordres limites pour bonnes opportunités
        if opportunity_level in [OpportunityLevel.EXCELLENT, OpportunityLevel.GOOD]:
            return confidence >= self.min_confidence_threshold

        return False

    def _calculate_limit_order_price(self, symbol: str, action: TradingAction, confidence: float) -> Optional[float]:
        """
        Calcule le prix pour un ordre limite
        """
        # Cette fonction nécessiterait l'accès aux prix actuels MT5
        # Pour l'instant, retourner None (sera calculé côté robot)
        return None

    def _should_close_position(self, action: TradingAction, confidence: float) -> bool:
        """
        Détermine si on devrait clôturer une position existante
        """
        # Clôturer si signal opposé fort
        if action in [TradingAction.STRONG_SELL, TradingAction.STRONG_BUY]:
            return confidence >= self.high_confidence_threshold

        return False

    def _calculate_trailing_stop(self, action: TradingAction, confidence: float,
                               opportunity_level: OpportunityLevel) -> Optional[float]:
        """
        Calcule la distance du trailing stop
        """
        if action == TradingAction.HOLD:
            return None

        # Distance de base selon le symbole (simplifié)
        base_distance = 0.0020  # 20 pips par défaut

        # Ajuster selon la confiance
        confidence_multiplier = confidence

        # Ajuster selon l'opportunité
        opportunity_multiplier = 1.0
        if opportunity_level == OpportunityLevel.EXCELLENT:
            opportunity_multiplier = 1.2
        elif opportunity_level == OpportunityLevel.GOOD:
            opportunity_multiplier = 1.1
        elif opportunity_level == OpportunityLevel.POOR:
            opportunity_multiplier = 0.8

        trailing_distance = base_distance * confidence_multiplier * opportunity_multiplier

        # Limiter entre 10 et 50 pips
        return max(0.0010, min(0.0050, trailing_distance))

    def _get_timeframe_priority(self, timeframe: str, opportunity_score: float) -> str:
        """
        Détermine la priorité du timeframe
        """
        priorities = {
            "H1": "high" if opportunity_score > 0.7 else "medium",
            "M5": "medium" if opportunity_score > 0.6 else "low",
            "M1": "low"
        }
        return priorities.get(timeframe, "low")

    def _assess_risk_level(self, symbol: str, action: TradingAction, confidence: float,
                          opportunity_level: OpportunityLevel) -> str:
        """
        Évalue le niveau de risque
        """
        risk_score = 0.5  # Base neutre

        # Ajuster selon l'action
        if action in [TradingAction.STRONG_BUY, TradingAction.STRONG_SELL]:
            risk_score += 0.2
        elif action == TradingAction.HOLD:
            risk_score -= 0.1

        # Ajuster selon la confiance
        if confidence > 0.8:
            risk_score -= 0.1
        elif confidence < 0.6:
            risk_score += 0.2

        # Ajuster selon l'opportunité
        if opportunity_level == OpportunityLevel.EXCELLENT:
            risk_score -= 0.1
        elif opportunity_level in [OpportunityLevel.POOR, OpportunityLevel.AVOID]:
            risk_score += 0.2

        # Classifier le risque
        if risk_score < 0.4:
            return "low"
        elif risk_score < 0.7:
            return "medium"
        else:
            return "high"

    def _generate_reason(self, action: TradingAction, confidence: float,
                        opportunity_score: float, ml_confidence: float) -> str:
        """
        Génère une raison explicative pour la recommandation
        """
        confidence_pct = confidence * 100
        opportunity_pct = opportunity_score * 100
        ml_pct = ml_confidence * 100

        reasons = []

        if action in [TradingAction.STRONG_BUY, TradingAction.BUY, TradingAction.WEAK_BUY]:
            reasons.append(f"Achat recommandé ({confidence_pct:.1f}% confiance)")
        elif action in [TradingAction.STRONG_SELL, TradingAction.SELL, TradingAction.WEAK_SELL]:
            reasons.append(f"Vente recommandée ({confidence_pct:.1f}% confiance)")
        else:
            reasons.append(f"Attendre ({confidence_pct:.1f}% confiance)")

        reasons.append(f"Opportunité: {opportunity_pct:.1f}%")
        reasons.append(f"Fiabilité ML: {ml_pct:.1f}%")

        return " | ".join(reasons)

    def _calculate_symbol_opportunity(self, symbol: str, recommendations: List[MLRecommendation]) -> Optional[SymbolOpportunity]:
        """
        Calcule l'opportunité globale d'un symbole
        """
        symbol_recs = [r for r in recommendations if r.symbol == symbol]
        if not symbol_recs:
            return None

        # Moyennes pondérées
        total_score = sum(r.opportunity_score * r.confidence for r in symbol_recs) / sum(r.confidence for r in symbol_recs)

        # Calculer les opportunités par direction
        buy_recs = [r for r in symbol_recs if r.action in [TradingAction.STRONG_BUY, TradingAction.BUY, TradingAction.WEAK_BUY]]
        sell_recs = [r for r in symbol_recs if r.action in [TradingAction.STRONG_SELL, TradingAction.SELL, TradingAction.WEAK_SELL]]
        hold_recs = [r for r in symbol_recs if r.action == TradingAction.HOLD]

        buy_opportunity = sum(r.opportunity_score for r in buy_recs) / len(buy_recs) if buy_recs else 0
        sell_opportunity = sum(r.opportunity_score for r in sell_recs) / len(sell_recs) if sell_recs else 0
        hold_opportunity = sum(r.opportunity_score for r in hold_recs) / len(hold_recs) if hold_recs else 0

        # Évaluer le risque de volatilité (simplifié)
        volatility_risk = 0.5  # Valeur par défaut

        # Évaluer la force de tendance
        trend_strength = max(buy_opportunity, sell_opportunity)

        # Confiance ML moyenne
        ml_confidence = sum(r.confidence for r in symbol_recs) / len(symbol_recs)

        return SymbolOpportunity(
            symbol=symbol,
            total_score=total_score,
            buy_opportunity=buy_opportunity,
            sell_opportunity=sell_opportunity,
            hold_opportunity=hold_opportunity,
            volatility_risk=volatility_risk,
            trend_strength=trend_strength,
            ml_confidence=ml_confidence,
            last_updated=datetime.now()
        )

    def _generate_trading_summary(self, recommendations: List[MLRecommendation],
                                opportunities: List[SymbolOpportunity]) -> Dict[str, Any]:
        """
        Génère un résumé du contexte de trading
        """
        if not recommendations:
            return {"message": "Aucune recommandation disponible", "action_count": 0}

        # Compter les actions
        action_counts = {}
        for rec in recommendations:
            action_counts[rec.action.value] = action_counts.get(rec.action.value, 0) + 1

        # Symboles les plus opportuns
        top_symbols = sorted(opportunities, key=lambda x: x.total_score, reverse=True)[:3]
        top_symbols_names = [s.symbol for s in top_symbols]

        # Sentiment général
        buy_signals = sum(1 for r in recommendations if r.action in [TradingAction.STRONG_BUY, TradingAction.BUY])
        sell_signals = sum(1 for r in recommendations if r.action in [TradingAction.STRONG_SELL, TradingAction.SELL])
        hold_signals = sum(1 for r in recommendations if r.action == TradingAction.HOLD)

        total_signals = len(recommendations)
        bullish_ratio = buy_signals / total_signals if total_signals > 0 else 0.5

        sentiment = "neutre"
        if bullish_ratio > 0.6:
            sentiment = "haussier"
        elif bullish_ratio < 0.4:
            sentiment = "baissier"

        # Recommandations d'actions immédiates
        immediate_actions = []
        for rec in recommendations:
            if rec.should_trade and rec.opportunity_level in [OpportunityLevel.EXCELLENT, OpportunityLevel.GOOD]:
                immediate_actions.append({
                    "symbol": rec.symbol,
                    "action": rec.action.value,
                    "priority": "high" if rec.opportunity_level == OpportunityLevel.EXCELLENT else "medium"
                })

        return {
            "total_recommendations": len(recommendations),
            "action_distribution": action_counts,
            "market_sentiment": sentiment,
            "bullish_ratio": bullish_ratio,
            "top_opportunities": top_symbols_names,
            "immediate_actions": immediate_actions[:5],  # Top 5 actions immédiates
            "should_trade_now": len(immediate_actions) > 0,
            "risk_warnings": self._generate_risk_warnings(recommendations)
        }

    def _calculate_market_sentiment(self, recommendations: List[MLRecommendation]) -> Dict[str, Any]:
        """
        Calcule le sentiment général du marché
        """
        if not recommendations:
            return {"sentiment": "unknown", "strength": 0.0}

        # Calculer le ratio haussier/baissier
        bullish_count = sum(1 for r in recommendations if r.action in [TradingAction.STRONG_BUY, TradingAction.BUY, TradingAction.WEAK_BUY])
        bearish_count = sum(1 for r in recommendations if r.action in [TradingAction.STRONG_SELL, TradingAction.SELL, TradingAction.WEAK_SELL])
        neutral_count = sum(1 for r in recommendations if r.action == TradingAction.HOLD)

        total = len(recommendations)

        bullish_ratio = bullish_count / total
        bearish_ratio = bearish_count / total
        neutral_ratio = neutral_count / total

        # Déterminer le sentiment dominant
        if bullish_ratio > bearish_ratio and bullish_ratio > 0.5:
            sentiment = "bullish"
            strength = bullish_ratio
        elif bearish_ratio > bullish_ratio and bearish_ratio > 0.5:
            sentiment = "bearish"
            strength = bearish_ratio
        else:
            sentiment = "neutral"
            strength = neutral_ratio

        return {
            "sentiment": sentiment,
            "strength": strength,
            "bullish_ratio": bullish_ratio,
            "bearish_ratio": bearish_ratio,
            "neutral_ratio": neutral_ratio
        }

    def _assess_overall_risk(self, recommendations: List[MLRecommendation]) -> Dict[str, Any]:
        """
        Évalue le risque global
        """
        if not recommendations:
            return {"level": "unknown", "score": 0.5}

        # Calculer le score de risque moyen
        risk_scores = []
        for rec in recommendations:
            risk_score = 0.5  # Base
            if rec.risk_level == "high":
                risk_score = 0.8
            elif rec.risk_level == "low":
                risk_score = 0.3
            elif rec.risk_level == "medium":
                risk_score = 0.5

            risk_scores.append(risk_score)

        avg_risk = sum(risk_scores) / len(risk_scores)

        # Classifier le risque global
        if avg_risk < 0.4:
            risk_level = "low"
        elif avg_risk < 0.7:
            risk_level = "medium"
        else:
            risk_level = "high"

        # Générer des avertissements
        warnings = []
        high_risk_count = sum(1 for r in recommendations if r.risk_level == "high")
        if high_risk_count > len(recommendations) * 0.3:
            warnings.append("Risque élevé sur plus de 30% des symboles")

        low_confidence_count = sum(1 for r in recommendations if r.confidence < 0.6)
        if low_confidence_count > len(recommendations) * 0.5:
            warnings.append("Plus de 50% des recommandations ont une faible confiance")

        return {
            "level": risk_level,
            "score": avg_risk,
            "warnings": warnings
        }

    def _generate_risk_warnings(self, recommendations: List[MLRecommendation]) -> List[str]:
        """
        Génère des avertissements de risque
        """
        warnings = []

        # Vérifier la distribution des risques
        high_risk = sum(1 for r in recommendations if r.risk_level == "high")
        if high_risk > len(recommendations) * 0.4:
            warnings.append("Risque élevé détecté sur plus de 40% des opportunités")

        # Vérifier la volatilité
        volatile_symbols = [r.symbol for r in recommendations if "Boom" in r.symbol or "Crash" in r.symbol]
        if len(volatile_symbols) > len(recommendations) * 0.5:
            warnings.append("Prédominance de symboles volatiles (Boom/Crash)")

        # Vérifier les conflits de signal
        conflicting_signals = 0
        symbols = set(r.symbol for r in recommendations)
        for symbol in symbols:
            symbol_recs = [r for r in recommendations if r.symbol == symbol]
            if len(symbol_recs) > 1:
                actions = set(r.action for r in symbol_recs)
                if len(actions) > 2:  # Plus de 2 actions différentes = conflit
                    conflicting_signals += 1

        if conflicting_signals > 0:
            warnings.append(f"Signaux conflictuels détectés pour {conflicting_signals} symbole(s)")

        return warnings

    def _get_empty_recommendations(self) -> Dict[str, Any]:
        """
        Retourne une structure vide en cas d'erreur
        """
        return {
            "timestamp": datetime.now().isoformat(),
            "total_symbols_analyzed": 0,
            "recommendations": [],
            "symbol_opportunities": [],
            "trading_summary": {"message": "Aucune donnée ML disponible", "action_count": 0},
            "market_sentiment": {"sentiment": "unknown", "strength": 0.0},
            "risk_assessment": {"level": "unknown", "score": 0.5}
        }

    def _recommendation_to_dict(self, rec: MLRecommendation) -> Dict[str, Any]:
        """
        Convertit une recommandation en dictionnaire
        """
        return {
            "symbol": rec.symbol,
            "action": rec.action.value,
            "confidence": rec.confidence,
            "opportunity_score": rec.opportunity_score,
            "opportunity_level": rec.opportunity_level.value,
            "reason": rec.reason,
            "should_trade": rec.should_trade,
            "should_limit_order": rec.should_limit_order,
            "limit_order_price": rec.limit_order_price,
            "should_close": rec.should_close,
            "trailing_stop_distance": rec.trailing_stop_distance,
            "timeframe_priority": rec.timeframe_priority,
            "risk_level": rec.risk_level,
            "timestamp": rec.timestamp.isoformat()
        }

    def _opportunity_to_dict(self, opp: SymbolOpportunity) -> Dict[str, Any]:
        """
        Convertit une opportunité en dictionnaire
        """
        return {
            "symbol": opp.symbol,
            "total_score": opp.total_score,
            "buy_opportunity": opp.buy_opportunity,
            "sell_opportunity": opp.sell_opportunity,
            "hold_opportunity": opp.hold_opportunity,
            "volatility_risk": opp.volatility_risk,
            "trend_strength": opp.trend_strength,
            "ml_confidence": opp.ml_confidence,
            "last_updated": opp.last_updated.isoformat()
        }

    def get_recommendation_for_symbol(self, symbol: str) -> Optional[MLRecommendation]:
        """
        Récupère la recommandation pour un symbole spécifique
        """
        if not self.last_analysis:
            return None

        for rec_dict in self.last_analysis["recommendations"]:
            if rec_dict["symbol"] == symbol:
                # Reconvertir en objet MLRecommendation
                return MLRecommendation(
                    symbol=rec_dict["symbol"],
                    action=TradingAction(rec_dict["action"]),
                    confidence=rec_dict["confidence"],
                    opportunity_score=rec_dict["opportunity_score"],
                    opportunity_level=OpportunityLevel(rec_dict["opportunity_level"]),
                    reason=rec_dict["reason"],
                    should_trade=rec_dict["should_trade"],
                    should_limit_order=rec_dict["should_limit_order"],
                    limit_order_price=rec_dict["limit_order_price"],
                    should_close=rec_dict["should_close"],
                    trailing_stop_distance=rec_dict["trailing_stop_distance"],
                    timeframe_priority=rec_dict["timeframe_priority"],
                    risk_level=rec_dict["risk_level"],
                    timestamp=datetime.fromisoformat(rec_dict["timestamp"]),
                    ml_metrics={}
                )

        return None

    def get_top_opportunities(self, limit: int = 5) -> List[SymbolOpportunity]:
        """
        Récupère les meilleures opportunités
        """
        if not self.last_analysis:
            return []

        opportunities = []
        for opp_dict in self.last_analysis["symbol_opportunities"][:limit]:
            opportunities.append(SymbolOpportunity(
                symbol=opp_dict["symbol"],
                total_score=opp_dict["total_score"],
                buy_opportunity=opp_dict["buy_opportunity"],
                sell_opportunity=opp_dict["sell_opportunity"],
                hold_opportunity=opp_dict["hold_opportunity"],
                volatility_risk=opp_dict["volatility_risk"],
                trend_strength=opp_dict["trend_strength"],
                ml_confidence=opp_dict["ml_confidence"],
                last_updated=datetime.fromisoformat(opp_dict["last_updated"])
            ))

        return opportunities
