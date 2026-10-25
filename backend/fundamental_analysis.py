import requests
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import json


class FundamentalAnalyzer:
    """Analyseur d'analyse fondamentale avancé"""
    
    def __init__(self):
        self.economic_calendar = {}
        self.news_data = {}
        self.central_bank_rates = {}
        self.economic_indicators = {}
    
    def get_economic_calendar(self, days: int = 7) -> Dict:
        """
        Récupère le calendrier économique
        
        Args:
            days: Nombre de jours à récupérer
        
        Returns:
            Calendrier économique
        """
        try:
            # Simulation de données économiques (à remplacer par une vraie API)
            calendar_data = {
                'high_impact': [
                    {
                        'date': (datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d'),
                        'time': '14:30',
                        'currency': 'USD',
                        'event': 'Non-Farm Payrolls',
                        'impact': 'HIGH',
                        'forecast': '180K',
                        'previous': '175K'
                    },
                    {
                        'date': (datetime.now() + timedelta(days=2)).strftime('%Y-%m-%d'),
                        'time': '15:00',
                        'currency': 'EUR',
                        'event': 'ECB Interest Rate Decision',
                        'impact': 'HIGH',
                        'forecast': '4.50%',
                        'previous': '4.50%'
                    }
                ],
                'medium_impact': [
                    {
                        'date': (datetime.now() + timedelta(days=1)).strftime('%Y-%m-%d'),
                        'time': '13:30',
                        'currency': 'USD',
                        'event': 'Unemployment Claims',
                        'impact': 'MEDIUM',
                        'forecast': '220K',
                        'previous': '218K'
                    }
                ]
            }
            
            self.economic_calendar = calendar_data
            return calendar_data
            
        except Exception as e:
            print(f"Erreur lors de la récupération du calendrier économique: {e}")
            return {}
    
    def get_central_bank_rates(self) -> Dict:
        """Récupère les taux des banques centrales"""
        try:
            rates = {
                'FED': {
                    'rate': 5.50,
                    'next_meeting': '2024-01-31',
                    'expectation': 'HOLD'
                },
                'ECB': {
                    'rate': 4.50,
                    'next_meeting': '2024-01-25',
                    'expectation': 'HOLD'
                },
                'BOE': {
                    'rate': 5.25,
                    'next_meeting': '2024-02-01',
                    'expectation': 'HOLD'
                },
                'BOJ': {
                    'rate': -0.10,
                    'next_meeting': '2024-01-23',
                    'expectation': 'HOLD'
                }
            }
            
            self.central_bank_rates = rates
            return rates
            
        except Exception as e:
            print(f"Erreur lors de la récupération des taux: {e}")
            return {}
    
    def get_economic_indicators(self, currency: str = 'USD') -> Dict:
        """Récupère les indicateurs économiques principaux"""
        try:
            indicators = {
                'USD': {
                    'gdp_growth': 2.1,
                    'inflation': 3.1,
                    'unemployment': 3.7,
                    'consumer_confidence': 108.7,
                    'manufacturing_pmi': 47.1,
                    'services_pmi': 52.6
                },
                'EUR': {
                    'gdp_growth': 0.5,
                    'inflation': 2.4,
                    'unemployment': 6.5,
                    'consumer_confidence': -15.0,
                    'manufacturing_pmi': 44.4,
                    'services_pmi': 48.8
                },
                'GBP': {
                    'gdp_growth': 0.6,
                    'inflation': 3.9,
                    'unemployment': 4.2,
                    'consumer_confidence': -24.0,
                    'manufacturing_pmi': 46.2,
                    'services_pmi': 53.4
                }
            }
            
            self.economic_indicators = indicators.get(currency, {})
            return self.economic_indicators
            
        except Exception as e:
            print(f"Erreur lors de la récupération des indicateurs: {e}")
            return {}
    
    def get_market_sentiment(self, symbol: str) -> Dict:
        """Analyse le sentiment du marché pour un symbole"""
        try:
            # Simulation d'analyse de sentiment
            sentiment_data = {
                'overall_sentiment': 'BULLISH',
                'confidence': 75,
                'factors': {
                    'technical': 'NEUTRAL',
                    'fundamental': 'BULLISH',
                    'news': 'BULLISH',
                    'institutional': 'NEUTRAL'
                },
                'risk_level': 'MEDIUM',
                'recommendation': 'HOLD'
            }
            
            return sentiment_data
            
        except Exception as e:
            print(f"Erreur lors de l'analyse du sentiment: {e}")
            return {}
    
    def get_news_impact(self, symbol: str) -> Dict:
        """Analyse l'impact des news sur un symbole"""
        try:
            # Simulation d'analyse des news
            news_impact = {
                'recent_news': [
                    {
                        'title': 'Fed signals potential rate cuts in 2024',
                        'impact': 'POSITIVE',
                        'sentiment': 0.8,
                        'date': datetime.now().strftime('%Y-%m-%d')
                    },
                    {
                        'title': 'Strong economic data boosts market confidence',
                        'impact': 'POSITIVE',
                        'sentiment': 0.7,
                        'date': datetime.now().strftime('%Y-%m-%d')
                    }
                ],
                'overall_sentiment': 'POSITIVE',
                'sentiment_score': 0.75
            }
            
            return news_impact
            
        except Exception as e:
            print(f"Erreur lors de l'analyse des news: {e}")
            return {}
    
    def analyze_currency_pair(self, base_currency: str, quote_currency: str) -> Dict:
        """Analyse fondamentale complète d'une paire de devises"""
        try:
            analysis = {
                'base_currency': base_currency,
                'quote_currency': quote_currency,
                'analysis_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'economic_factors': {},
                'monetary_policy': {},
                'risk_factors': [],
                'recommendation': 'NEUTRAL',
                'confidence': 0
            }
            
            # Analyse économique
            base_indicators = self.get_economic_indicators(base_currency)
            quote_indicators = self.get_economic_indicators(quote_currency)
            
            analysis['economic_factors'] = {
                'base_currency': base_indicators,
                'quote_currency': quote_indicators
            }
            
            # Analyse de politique monétaire
            rates = self.get_central_bank_rates()
            analysis['monetary_policy'] = {
                'base_central_bank': self._get_central_bank_for_currency(base_currency, rates),
                'quote_central_bank': self._get_central_bank_for_currency(quote_currency, rates)
            }
            
            # Facteurs de risque
            analysis['risk_factors'] = self._identify_risk_factors(base_currency, quote_currency)
            
            # Recommandation
            analysis['recommendation'], analysis['confidence'] = self._generate_recommendation(analysis)
            
            return analysis
            
        except Exception as e:
            print(f"Erreur lors de l'analyse de la paire: {e}")
            return {}
    
    def _get_central_bank_for_currency(self, currency: str, rates: Dict) -> Dict:
        """Retourne la banque centrale pour une devise"""
        currency_to_bank = {
            'USD': 'FED',
            'EUR': 'ECB',
            'GBP': 'BOE',
            'JPY': 'BOJ'
        }
        
        bank = currency_to_bank.get(currency, 'UNKNOWN')
        return rates.get(bank, {})
    
    def _identify_risk_factors(self, base_currency: str, quote_currency: str) -> List[str]:
        """Identifie les facteurs de risque"""
        risk_factors = []
        
        # Facteurs économiques
        base_indicators = self.get_economic_indicators(base_currency)
        quote_indicators = self.get_economic_indicators(quote_currency)
        
        if base_indicators.get('inflation', 0) > 3.0:
            risk_factors.append(f"Inflation élevée en {base_currency}")
        
        if quote_indicators.get('inflation', 0) > 3.0:
            risk_factors.append(f"Inflation élevée en {quote_currency}")
        
        if base_indicators.get('unemployment', 0) > 5.0:
            risk_factors.append(f"Chômage élevé en {base_currency}")
        
        # Facteurs politiques
        risk_factors.append("Risques géopolitiques")
        risk_factors.append("Volatilité des marchés")
        
        return risk_factors
    
    def _generate_recommendation(self, analysis: Dict) -> tuple:
        """Génère une recommandation basée sur l'analyse"""
        confidence = 0
        recommendation = 'NEUTRAL'
        
        # Logique de recommandation basée sur les indicateurs
        base_indicators = analysis['economic_factors'].get('base_currency', {})
        quote_indicators = analysis['economic_factors'].get('quote_currency', {})
        
        # Comparaison des taux de croissance
        base_growth = base_indicators.get('gdp_growth', 0)
        quote_growth = quote_indicators.get('gdp_growth', 0)
        
        if base_growth > quote_growth:
            confidence += 20
            recommendation = 'BULLISH'
        elif quote_growth > base_growth:
            confidence += 20
            recommendation = 'BEARISH'
        
        # Comparaison des taux d'inflation
        base_inflation = base_indicators.get('inflation', 0)
        quote_inflation = quote_indicators.get('inflation', 0)
        
        if base_inflation < quote_inflation:
            confidence += 15
            if recommendation == 'BULLISH':
                confidence += 10
        elif quote_inflation < base_inflation:
            confidence += 15
            if recommendation == 'BEARISH':
                confidence += 10
        
        # Facteurs de risque
        risk_count = len(analysis['risk_factors'])
        confidence -= risk_count * 5
        
        confidence = max(0, min(100, confidence))
        
        return recommendation, confidence


def get_fundamental_analysis(symbol: str) -> Dict:
    """
    Fonction principale pour l'analyse fondamentale
    
    Args:
        symbol: Symbole à analyser (ex: 'EURUSD', 'BOOM1000')
    
    Returns:
        Analyse fondamentale complète
    """
    analyzer = FundamentalAnalyzer()
    
    # Déterminer le type de symbole
    if any(keyword in symbol.upper() for keyword in ['BOOM', 'CRASH']):
        # Analyse pour les indices synthétiques
        return _analyze_synthetic_index(symbol, analyzer)
    else:
        # Analyse pour les paires de devises
        return _analyze_currency_pair(symbol, analyzer)


def _analyze_synthetic_index(symbol: str, analyzer: FundamentalAnalyzer) -> Dict:
    """Analyse pour les indices synthétiques Boom/Crash"""
    analysis = {
        'symbol': symbol,
        'type': 'SYNTHETIC_INDEX',
        'analysis_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'market_conditions': {},
        'volatility_analysis': {},
        'risk_assessment': {},
        'recommendation': 'NEUTRAL',
        'confidence': 0
    }
    
    # Conditions de marché
    analysis['market_conditions'] = {
        'overall_trend': 'BULLISH',
        'market_sentiment': 'POSITIVE',
        'risk_appetite': 'HIGH',
        'volatility_level': 'HIGH'
    }
    
    # Analyse de volatilité
    analysis['volatility_analysis'] = {
        'current_volatility': 'HIGH',
        'volatility_trend': 'INCREASING',
        'spike_probability': 0.75,
        'risk_level': 'HIGH'
    }
    
    # Évaluation des risques
    analysis['risk_assessment'] = {
        'market_risk': 'HIGH',
        'liquidity_risk': 'MEDIUM',
        'volatility_risk': 'HIGH',
        'overall_risk': 'HIGH'
    }
    
    # Recommandation
    if 'BOOM' in symbol.upper():
        analysis['recommendation'] = 'BULLISH'
        analysis['confidence'] = 70
    else:
        analysis['recommendation'] = 'BEARISH'
        analysis['confidence'] = 70
    
    return analysis


def _analyze_currency_pair(symbol: str, analyzer: FundamentalAnalyzer) -> Dict:
    """Analyse pour les paires de devises"""
    # Extraire les devises de la paire
    if len(symbol) >= 6:
        base_currency = symbol[:3]
        quote_currency = symbol[3:6]
        return analyzer.analyze_currency_pair(base_currency, quote_currency)
    else:
        return {
            'error': 'Format de symbole invalide',
            'symbol': symbol
        }


def get_market_overview() -> Dict:
    """Vue d'ensemble du marché"""
    analyzer = FundamentalAnalyzer()
    
    overview = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'global_market_sentiment': 'BULLISH',
        'risk_appetite': 'HIGH',
        'major_events': [],
        'currency_strength': {},
        'market_volatility': 'HIGH'
    }
    
    # Événements majeurs
    calendar = analyzer.get_economic_calendar()
    overview['major_events'] = calendar.get('high_impact', [])
    
    # Force des devises
    currencies = ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'NZD']
    for currency in currencies:
        indicators = analyzer.get_economic_indicators(currency)
        if indicators:
            strength_score = _calculate_currency_strength(indicators)
            overview['currency_strength'][currency] = {
                'strength': strength_score,
                'trend': 'BULLISH' if strength_score > 0 else 'BEARISH',
                'indicators': indicators
            }
    
    return overview


def _calculate_currency_strength(indicators: Dict) -> float:
    """Calcule la force d'une devise basée sur ses indicateurs"""
    strength = 0
    
    # GDP Growth
    gdp = indicators.get('gdp_growth', 0)
    if gdp > 2.0:
        strength += 20
    elif gdp > 1.0:
        strength += 10
    elif gdp < 0:
        strength -= 20
    
    # Inflation
    inflation = indicators.get('inflation', 0)
    if 1.5 <= inflation <= 3.0:
        strength += 15
    elif inflation > 4.0:
        strength -= 15
    
    # Unemployment
    unemployment = indicators.get('unemployment', 0)
    if unemployment < 4.0:
        strength += 15
    elif unemployment > 6.0:
        strength -= 15
    
    # PMI
    manufacturing_pmi = indicators.get('manufacturing_pmi', 50)
    services_pmi = indicators.get('services_pmi', 50)
    
    if manufacturing_pmi > 50:
        strength += 10
    if services_pmi > 50:
        strength += 10
    
    return strength 