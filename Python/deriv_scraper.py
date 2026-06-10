#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Scraper Deriv Web Platform — Récupère les candles depuis demo.deriv.com
Utilise Playwright pour naviguer la plateforme publique Deriv
"""

import sys
import json
import asyncio
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
import pandas as pd

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

try:
    from playwright.async_api import async_playwright, Browser
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False
    print("⚠️ Playwright not installed. Install: pip install playwright")


class DerivWebScraper:
    """Scrape candles depuis la plateforme web Deriv"""

    def __init__(self):
        self.browser: Optional[Browser] = None
        self.demo_url = "https://app.deriv.com/trade/synthetic"  # Synthetics (Boom/Crash)
        self.forex_url = "https://app.deriv.com/trade/forex"      # Forex (EURUSD, etc)

    async def launch(self):
        """Lance le navigateur Playwright"""
        if not PLAYWRIGHT_AVAILABLE:
            print("❌ Playwright required")
            return False

        try:
            p = await async_playwright().start()
            self.browser = await p.chromium.launch(headless=True)
            print("✅ Browser launched")
            return True
        except Exception as e:
            print(f"❌ Error: {e}")
            return False

    async def fetch_candles_web(
        self, symbol: str, timeframe: str = "15m"
    ) -> Optional[pd.DataFrame]:
        """
        Récupère les candles via navigation web Deriv

        Args:
            symbol: "Boom 500", "Crash 500", "EURUSD", etc
            timeframe: "1m", "5m", "15m", "1h", "4h", "1d"

        Returns:
            DataFrame avec candles [time, open, high, low, close, volume]
        """
        if not self.browser:
            if not await self.launch():
                return None

        try:
            # Détermine l'URL basée sur le symbole
            if "Boom" in symbol or "Crash" in symbol:
                url = self.demo_url
            else:
                url = self.forex_url

            # Crée une page
            page = await self.browser.new_page()
            await page.goto(url, wait_until="networkidle", timeout=30000)

            print(f"✓ Loaded {symbol} chart from Deriv")

            # Cherche les candles dans le DOM (dépend de la structure HTML Deriv)
            # Cherche les éléments candlestick ou données OHLC
            candles_data = await page.evaluate("""() => {
                // Cherche les données de candles dans le contexte de page
                // (Deriv charge les données via JavaScript/API)

                // Essai 1: Cherche dans window.__data ou variables globales
                if (window.__chartData) return window.__chartData;
                if (window.__ohlcData) return window.__ohlcData;

                // Essai 2: Cherche les éléments SVG candlestick
                const candles = document.querySelectorAll('[data-testid*="candle"]');
                if (candles.length > 0) {
                    return Array.from(candles).map(c => ({
                        time: c.dataset.time,
                        open: parseFloat(c.dataset.open),
                        high: parseFloat(c.dataset.high),
                        low: parseFloat(c.dataset.low),
                        close: parseFloat(c.dataset.close),
                        volume: parseInt(c.dataset.volume) || 0
                    }));
                }

                // Essai 3: Cherche dans TradingView widget (si embed)
                if (window.TVChart) {
                    return window.TVChart.getCandles?.();
                }

                return null;
            }""")

            if not candles_data:
                print(f"⚠️ No candles found in DOM for {symbol}")
                await page.close()
                return None

            # Convertir en DataFrame
            df = pd.DataFrame(candles_data)
            if 'time' in df.columns:
                df['time'] = pd.to_datetime(df['time'])
                df.set_index('time', inplace=True)

            await page.close()
            print(f"✅ Got {len(df)} candles for {symbol}")
            return df

        except Exception as e:
            print(f"❌ Scraping error: {e}")
            return None

    async def close(self):
        """Ferme le navigateur"""
        if self.browser:
            await self.browser.close()


async def get_deriv_candles_web(
    symbol: str, timeframe: str = "15m", bars: int = 100
) -> Optional[pd.DataFrame]:
    """Récupère candles depuis Deriv web"""
    scraper = DerivWebScraper()
    df = await scraper.fetch_candles_web(symbol, timeframe)
    await scraper.close()
    return df


if __name__ == "__main__":
    async def test():
        print("Testing Deriv Web Scraper...")
        df = await get_deriv_candles_web("Boom 500", "15m")
        if df is not None:
            print("\nSUCCESS!")
            print(df.tail(5))
        else:
            print("\nFAILED")

    asyncio.run(test())
