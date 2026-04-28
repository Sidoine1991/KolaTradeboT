"""
API pour récupérer les actualités économiques et calendrier financier
Sources: API publiques (Alpha Vantage, Financial Modeling Prep, etc.)
"""
from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from datetime import datetime, timedelta
from pydantic import BaseModel
import httpx
import logging
import os

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/economic", tags=["economic-news"])

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION API (Clés gratuites)
# ═══════════════════════════════════════════════════════════════════

# Alpha Vantage (gratuit: 25 requêtes/jour)
ALPHA_VANTAGE_KEY = os.getenv("ALPHA_VANTAGE_API_KEY", "demo")

# Financial Modeling Prep (gratuit: 250 requêtes/jour)
FMP_API_KEY = os.getenv("FMP_API_KEY", "demo")

# Trading Economics (gratuit avec limite)
TRADING_ECONOMICS_KEY = os.getenv("TRADING_ECONOMICS_KEY", "guest:guest")


# ═══════════════════════════════════════════════════════════════════
# MODÈLES DE DONNÉES
# ═══════════════════════════════════════════════════════════════════

class EconomicNews(BaseModel):
    """Actualité économique"""
    title: str
    description: Optional[str] = None
    source: str
    published_at: datetime
    category: str  # "FOREX", "CRYPTO", "COMMODITIES", "INDICES"
    impact: str  # "HIGH", "MEDIUM", "LOW"
    related_symbols: List[str] = []
    url: Optional[str] = None


class EconomicEvent(BaseModel):
    """Événement du calendrier économique"""
    time: datetime
    country: str
    event_name: str
    impact: str  # "HIGH", "MEDIUM", "LOW"
    forecast: Optional[str] = None
    previous: Optional[str] = None
    actual: Optional[str] = None
    currency: str


class NewsTicker(BaseModel):
    """Données pour le ticker défilant"""
    symbol: str
    news: List[EconomicNews]
    events: List[EconomicEvent]
    last_update: datetime
    ticker_text: str  # Texte formaté pour affichage


# ═══════════════════════════════════════════════════════════════════
# SOURCES D'ACTUALITÉS
# ═══════════════════════════════════════════════════════════════════

async def fetch_forex_news() -> List[EconomicNews]:
    """
    Récupérer actualités Forex depuis Financial Modeling Prep

    API gratuite: https://financialmodelingprep.com/api/v3/stock_news
    """
    news_list = []

    try:
        url = f"https://financialmodelingprep.com/api/v3/stock_news"
        params = {
            "limit": 20,
            "apikey": FMP_API_KEY
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, params=params)

            if response.status_code == 200:
                data = response.json()

                for item in data[:10]:  # Limiter à 10
                    news = EconomicNews(
                        title=item.get("title", "No title"),
                        description=item.get("text", "")[:200],  # Tronquer
                        source="FMP",
                        published_at=datetime.fromisoformat(item.get("publishedDate", datetime.now().isoformat()).replace("Z", "+00:00")),
                        category="FOREX",
                        impact="MEDIUM",
                        related_symbols=item.get("symbol", "").split(",")[:3],
                        url=item.get("url", None)
                    )
                    news_list.append(news)

            else:
                logger.warning(f"FMP API error: {response.status_code}")

    except Exception as e:
        logger.error(f"Error fetching forex news: {e}")

    return news_list


async def fetch_crypto_news() -> List[EconomicNews]:
    """
    Récupérer actualités Crypto depuis CoinGecko (gratuit)

    API: https://api.coingecko.com/api/v3/news
    """
    news_list = []

    try:
        # CoinGecko news (gratuit, pas de clé requise)
        url = "https://api.coingecko.com/api/v3/news"

        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url)

            if response.status_code == 200:
                data = response.json()

                for item in data.get("data", [])[:5]:
                    news = EconomicNews(
                        title=item.get("title", "Crypto news"),
                        description=item.get("description", "")[:200],
                        source="CoinGecko",
                        published_at=datetime.fromisoformat(item.get("created_at", datetime.now().isoformat()).replace("Z", "+00:00")),
                        category="CRYPTO",
                        impact="LOW",
                        related_symbols=["BTC", "ETH"],
                        url=item.get("url", None)
                    )
                    news_list.append(news)

    except Exception as e:
        logger.error(f"Error fetching crypto news: {e}")

    return news_list


async def fetch_economic_calendar_today() -> List[EconomicEvent]:
    """
    Récupérer calendrier économique du jour

    Source: Trading Economics (gratuit avec limite)
    """
    events = []

    try:
        # Pour démo, créer quelques événements fictifs
        # TODO: Intégrer une vraie API calendrier économique

        now = datetime.now()

        # Événements de démo
        demo_events = [
            {
                "time": now.replace(hour=14, minute=30),
                "country": "US",
                "event": "Fed Interest Rate Decision",
                "impact": "HIGH",
                "currency": "USD"
            },
            {
                "time": now.replace(hour=10, minute=0),
                "country": "EU",
                "event": "ECB Press Conference",
                "impact": "HIGH",
                "currency": "EUR"
            },
            {
                "time": now.replace(hour=8, minute=30),
                "country": "UK",
                "event": "GDP Growth Rate",
                "impact": "MEDIUM",
                "currency": "GBP"
            }
        ]

        for item in demo_events:
            event = EconomicEvent(
                time=item["time"],
                country=item["country"],
                event_name=item["event"],
                impact=item["impact"],
                currency=item["currency"],
                forecast=None,
                previous=None,
                actual=None
            )
            events.append(event)

    except Exception as e:
        logger.error(f"Error fetching economic calendar: {e}")

    return events


def categorize_symbol(symbol: str) -> str:
    """Déterminer la catégorie d'un symbole"""
    symbol_upper = symbol.upper()

    if "BTC" in symbol_upper or "ETH" in symbol_upper or "CRYPTO" in symbol_upper:
        return "CRYPTO"
    elif "USD" in symbol_upper or "EUR" in symbol_upper or "GBP" in symbol_upper:
        return "FOREX"
    elif "GOLD" in symbol_upper or "XAU" in symbol_upper or "OIL" in symbol_upper:
        return "COMMODITIES"
    elif "BOOM" in symbol_upper or "CRASH" in symbol_upper or "VOLATILITY" in symbol_upper:
        return "INDICES"
    else:
        return "FOREX"  # Par défaut


def format_ticker_text(news: List[EconomicNews], events: List[EconomicEvent], symbol: str) -> str:
    """
    Formater le texte du ticker défilant

    Format: 🔴 [HIGH] Fed Rate Decision 14:30 | 📰 EUR/USD climbs on ECB news | ⚡ BTC breaks $50k ...
    """
    ticker_parts = []

    # Ajouter événements importants (HIGH impact)
    for event in events:
        if event.impact == "HIGH":
            icon = "🔴"
            time_str = event.time.strftime("%H:%M")
            ticker_parts.append(f"{icon} [{event.impact}] {event.event_name} {time_str}")

    # Ajouter actualités pertinentes
    category = categorize_symbol(symbol)
    relevant_news = [n for n in news if n.category == category or category in n.related_symbols]

    for n in relevant_news[:3]:  # Max 3 news
        icon = "📰" if n.impact == "MEDIUM" else "⚡"
        ticker_parts.append(f"{icon} {n.title[:60]}")

    # Joindre avec séparateur
    if ticker_parts:
        return " | ".join(ticker_parts)
    else:
        return f"📊 Trading {symbol} | 💹 Market analysis in progress | 🌐 Stay informed"


# ═══════════════════════════════════════════════════════════════════
# ENDPOINTS API
# ═══════════════════════════════════════════════════════════════════

@router.get("/news/ticker", response_model=NewsTicker)
async def get_news_ticker(
    symbol: str = Query(..., description="Symbole (ex: EURUSD, Boom 500 Index)")
):
    """
    Récupérer le ticker d'actualités pour un symbole

    Combine:
    - Actualités Forex/Crypto
    - Calendrier économique
    - Événements à impact élevé

    Returns:
        Ticker formaté prêt pour affichage défilant
    """
    try:
        # Récupérer actualités en parallèle
        forex_news = await fetch_forex_news()
        crypto_news = await fetch_crypto_news()
        economic_events = await fetch_economic_calendar_today()

        # Combiner toutes les actualités
        all_news = forex_news + crypto_news

        # Trier par date (plus récentes d'abord)
        all_news.sort(key=lambda x: x.published_at, reverse=True)

        # Filtrer événements futurs uniquement
        now = datetime.now()
        future_events = [e for e in economic_events if e.time >= now]
        future_events.sort(key=lambda x: x.time)

        # Formater texte ticker
        ticker_text = format_ticker_text(all_news, future_events, symbol)

        ticker = NewsTicker(
            symbol=symbol,
            news=all_news[:10],  # Max 10 news
            events=future_events[:5],  # Max 5 events
            last_update=datetime.now(),
            ticker_text=ticker_text
        )

        logger.info(f"Ticker généré pour {symbol}: {len(all_news)} news, {len(future_events)} events")

        return ticker

    except Exception as e:
        logger.error(f"Error generating ticker: {e}")

        # Retourner ticker de secours
        return NewsTicker(
            symbol=symbol,
            news=[],
            events=[],
            last_update=datetime.now(),
            ticker_text=f"📊 Trading {symbol} | 💹 Market open | 🌐 Real-time analysis"
        )


@router.get("/news/list", response_model=List[EconomicNews])
async def get_news_list(
    category: Optional[str] = Query(None, description="FOREX, CRYPTO, COMMODITIES, INDICES"),
    limit: int = Query(20, ge=1, le=100, description="Nombre max de news")
):
    """
    Obtenir liste complète des actualités
    """
    try:
        forex_news = await fetch_forex_news()
        crypto_news = await fetch_crypto_news()

        all_news = forex_news + crypto_news

        # Filtrer par catégorie si spécifié
        if category:
            all_news = [n for n in all_news if n.category == category.upper()]

        # Trier et limiter
        all_news.sort(key=lambda x: x.published_at, reverse=True)
        all_news = all_news[:limit]

        return all_news

    except Exception as e:
        logger.error(f"Error fetching news list: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/calendar/today", response_model=List[EconomicEvent])
async def get_economic_calendar_today():
    """
    Calendrier économique du jour
    """
    try:
        events = await fetch_economic_calendar_today()
        return events
    except Exception as e:
        logger.error(f"Error fetching calendar: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/health")
async def health_check():
    """Vérifier connexion aux APIs"""
    status = {
        "fmp_api": "unknown",
        "coingecko_api": "unknown",
        "timestamp": datetime.now().isoformat()
    }

    try:
        # Test FMP
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"https://financialmodelingprep.com/api/v3/quote/AAPL?apikey={FMP_API_KEY}")
            status["fmp_api"] = "ok" if resp.status_code == 200 else f"error_{resp.status_code}"
    except:
        status["fmp_api"] = "offline"

    try:
        # Test CoinGecko
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get("https://api.coingecko.com/api/v3/ping")
            status["coingecko_api"] = "ok" if resp.status_code == 200 else f"error_{resp.status_code}"
    except:
        status["coingecko_api"] = "offline"

    return status
