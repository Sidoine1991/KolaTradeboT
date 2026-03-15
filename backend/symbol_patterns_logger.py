#!/usr/bin/env python3
"""
Module pour logger les patterns de correction et les résumés dans Supabase
Utilisé par l'AI server pour enregistrer les patterns détectés
"""

import os
import logging
import httpx
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv('.env.supabase')

logger = logging.getLogger("tradbot_patterns")

class SymbolPatternsLogger:
    """Logger pour les patterns de correction et résumés"""
    
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL", "https://your-project.supabase.co")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
        
        if not self.supabase_key:
            logger.warning("⚠️ Clé Supabase non configurée - logging désactivé")
    
    async def log_correction_pattern(self, symbol: str, pattern_data: Dict[str, Any]):
        """Log un pattern de correction dans la table symbol_correction_patterns"""
        if not self.supabase_key:
            return
        
        try:
            payload = {
                "symbol": symbol,
                "pattern_type": pattern_data.get("pattern_type", "unknown"),
                "avg_retracement_percentage": pattern_data.get("avg_retracement_pct"),
                "typical_duration_bars": pattern_data.get("typical_duration_bars"),
                "success_rate": pattern_data.get("success_rate"),
                "min_trend_strength": pattern_data.get("min_trend_strength"),
                "max_volatility_level": pattern_data.get("max_volatility"),
                "best_timeframes": pattern_data.get("best_timeframes"),
                "occurrences_count": pattern_data.get("occurrences_count", 1),
                "last_updated": datetime.now().isoformat()
            }
            
            async with httpx.AsyncClient() as client:
                r = await client.post(
                    f"{self.supabase_url}/rest/v1/symbol_correction_patterns",
                    json=payload,
                    headers={
                        "apikey": self.supabase_key,
                        "Authorization": f"Bearer {self.supabase_key}",
                        "Content-Type": "application/json",
                        "Prefer": "return=minimal",
                    },
                    timeout=10.0,
                )
                if r.status_code in (200, 201):
                    logger.info(f"✅ Correction pattern logged: {symbol} - {pattern_data.get('pattern_type')}")
                else:
                    logger.warning(f"⚠️ correction_patterns POST {r.status_code}: {r.text[:200]}")
        except Exception as e:
            logger.warning(f"❌ correction_patterns error: {e}")
    
    async def log_correction_summary(self, symbol: str, timeframe: str, summary_data: Dict[str, Any]):
        """Log un résumé de corrections dans la table correction_summary_stats"""
        if not self.supabase_key:
            return
        
        try:
            period_start = summary_data.get("period_start", datetime.now() - timedelta(days=7))
            period_end = summary_data.get("period_end", datetime.now())
            
            payload = {
                "symbol": symbol,
                "timeframe": timeframe,
                "period_start": period_start.isoformat() if isinstance(period_start, datetime) else period_start,
                "period_end": period_end.isoformat() if isinstance(period_end, datetime) else period_end,
                "total_corrections": summary_data.get("total_corrections", 0),
                "successful_predictions": summary_data.get("successful_predictions", 0),
                "avg_retracement_pct": summary_data.get("avg_retracement_pct"),
                "avg_duration_bars": summary_data.get("avg_duration_bars"),
                "success_rate": summary_data.get("success_rate"),
                "dominant_pattern": summary_data.get("dominant_pattern"),
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
                "metadata": {
                    "category": self._get_symbol_category(symbol),
                    "analysis_period": summary_data.get("analysis_period", "7d"),
                    "model_version": summary_data.get("model_version", "latest")
                }
            }
            
            async with httpx.AsyncClient() as client:
                r = await client.post(
                    f"{self.supabase_url}/rest/v1/correction_summary_stats",
                    json=payload,
                    headers={
                        "apikey": self.supabase_key,
                        "Authorization": f"Bearer {self.supabase_key}",
                        "Content-Type": "application/json",
                        "Prefer": "return=minimal",
                    },
                    timeout=10.0,
                )
                if r.status_code in (200, 201):
                    logger.info(f"✅ Correction summary logged: {symbol} {timeframe}")
                else:
                    logger.warning(f"⚠️ correction_summary POST {r.status_code}: {r.text[:200]}")
        except Exception as e:
            logger.warning(f"❌ correction_summary error: {e}")
    
    def _get_symbol_category(self, symbol: str) -> str:
        """Détermine la catégorie du symbole"""
        s = (symbol or "").upper()
        if "BOOM" in s or "CRASH" in s:
            return "BOOM_CRASH"
        if "VOLATILITY" in s or "RANGE BREAK" in s:
            return "VOLATILITY"
        if "STEP" in s:
            return "STEP"
        if "JUMP" in s:
            return "JUMP"
        if any(p in s for p in ["USD", "EUR", "GBP", "JPY", "AUD", "CAD"]):
            return "FOREX"
        return "OTHER"
    
    async def get_symbol_correction_patterns(self, symbol: str) -> List[Dict[str, Any]]:
        """Récupère les patterns de correction pour un symbole"""
        if not self.supabase_key:
            return []
        
        try:
            async with httpx.AsyncClient() as client:
                r = await client.get(
                    f"{self.supabase_url}/rest/v1/symbol_correction_patterns",
                    params={"symbol": f"eq.{symbol}", "order": "success_rate.desc"},
                    headers={
                        "apikey": self.supabase_key,
                        "Authorization": f"Bearer {self.supabase_key}",
                    },
                    timeout=10.0,
                )
                if r.status_code == 200:
                    return r.json()
                else:
                    logger.warning(f"⚠️ GET correction_patterns {r.status_code}")
                    return []
        except Exception as e:
            logger.warning(f"❌ GET correction_patterns error: {e}")
            return []

# Instance globale pour utilisation dans l'AI server
patterns_logger = SymbolPatternsLogger()
