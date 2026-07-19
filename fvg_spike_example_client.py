#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Exemple client pour utiliser l'API FVG Spike Detector
Montrant le flux M5 → Alerte → M1 → Signal
"""

import asyncio
import aiohttp
import pandas as pd
from datetime import datetime, timedelta
from typing import List, Dict, Optional

# Configuration API
API_BASE = "http://localhost:8001"

async def fetch_price_data(symbol: str, timeframe: str, bars: int = 20) -> List[Dict]:
    """
    Récupère les données de prix (à adapter selon ta source: MT5, fichier CSV, API broker...)
    """
    # Exemple avec données simulées - A REMPLACER par ta source de données réelle
    candles = []
    base_time = datetime.now() - timedelta(minutes=bars if timeframe == "M1" else bars*5)
    
    for i in range(bars):
        if timeframe == "M1":
            t = base_time + timedelta(minutes=i)
            # Simulation données M1 très volatiles (Boom/Crash)
            base_price = 100.0 + (i * 0.02)  # Légère tendance haussière
            noise = 0.5 if i % 5 != 0 else 1.5  # Volatilité accrue toutes les 5 bougies
        else:  # M5
            t = base_time + timedelta(minutes=i*5)
            base_price = 100.0 + (i * 0.1)
            noise = 1.0 if i % 3 != 0 else 3.0  # Volatilité accrue
        
        o = base_price + (i * 0.01)
        h = o + noise
        l = o - noise * 0.3
        c = o + (noise * 0.5)
        
        candles.append({
            "timestamp": t.isoformat(),
            "open": round(o, 5),
            "high": round(h, 5),
            "low": round(l, 5),
            "close": round(c, 5),
            "volume": 100 + (i * 10)
        })
    
    return candles


async def check_m5_alert(symbol: str) -> Optional[Dict]:
    """
    Étape 1: Vérifier si un FVG Supply est apparu en M5
    Retourne l'alerte si détectée, sinon None
    """
    print(f"\n{'='*60}")
    print(f"🔍 ÉTAPE 1: Analyse M5 pour {symbol}")
    print(f"{'='*60}")
    
    data = await fetch_price_data(symbol, "M5", bars=20)
    
    payload = {
        "symbol": symbol,
        "timeframe": "M5",
        "candles": data
    }
    
    async with aiohttp.ClientSession() as session:
        async with session.post(f"{API_BASE}/fvg/detect", json=payload) as resp:
            result = await resp.json()
            
            if result and result.get("detected"):
                print(f"✅ ALERTE M5 détectée!")
                print(f"   Type: {result.get('fvg_type')}")
                print(f"   Confiance: {result.get('confidence', 0):.0%}")
                print(f"   Taille: {result.get('fvg_size', 0):.2f}")
                print(f"   ⏳ Surveillance M1 en cours...")
                return result
            else:
                print(f"❌ Pas de FVG Supply M5 détecté. Stand-by.")
                return None


async def check_m1_signal(symbol: str, m5_alert: Dict) -> Optional[Dict]:
    """
    Étape 2: Après alerte M5, surveiller le M1 pour confirmation
    """
    print(f"\n{'='*60}")
    print(f"🎯 ÉTAPE 2: Analyse M1 pour {symbol}")
    print(f"{'='*60}")
    
    data_m5 = await fetch_price_data(symbol, "M5", bars=20)
    data_m1 = await fetch_price_data(symbol, "M1", bars=5)  # Dernières 5 minutes
    
    payload = {
        "m5_data": {
            "symbol": symbol,
            "timeframe": "M5",
            "candles": data_m5
        },
        "m1_data": {
            "symbol": symbol,
            "timeframe": "M1",
            "candles": data_m1
        }
    }
    
    async with aiohttp.ClientSession() as session:
        async with session.post(f"{API_BASE}/fvg/analyze", json=payload) as resp:
            result = await resp.json()
            
            trade_rec = result.get("trade_recommandation", {})
            if trade_rec.get("action") == "EXECUTE":
                details = trade_rec.get("details", {})
                print(f"🚀 SIGNAL TRADE CONFIRMÉ!")
                print(f"   Direction: {details.get('direction')}")
                print(f"   Entry: {details.get('entry_price')}")
                print(f"   SL: {details.get('stop_loss')} (${details.get('risk_amount_usd')} max)")
                print(f"   TP: {details.get('take_profit')}")
                print(f"   Lot: {details.get('lot_size')}")
                print(f"   Confiance: {details.get('confidence', 0):.0%}")
                print(f"   R:R: {details.get('risk_reward_ratio', 0):.1f}")
                return trade_rec
            else:
                print(f"⏳ Confluence M5+M1 non confirmée. Continuation surveillance...")
                return None


async def calculate_position_size(symbol: str, entry: float, sl: float) -> Dict:
    """
    Calcule la taille de position pour respecter $2.50 de perte max
    """
    print(f"\n{'='*60}")
    print(f"💰 CALCUL RISK MANAGEMENT pour {symbol}")
    print(f"{'='*60}")
    
    payload = {
        "symbol": symbol,
        "entry_price": entry,
        "stop_loss": sl,
        "direction": "SELL",
        "max_risk_usd": 2.50
    }
    
    async with aiohttp.ClientSession() as session:
        async with session.post(f"{API_BASE}/trade/calculate-risk", json=payload) as resp:
            result = await resp.json()
            
            print(f"📊 Résultat Calcul:")
            print(f"   Lot calculé: {result.get('lot_size')}")
            print(f"   Risque max: ${result.get('max_risk_usd')}")
            print(f"   Risque réel: ${result.get('actual_risk_usd')}")
            print(f"   Distance SL: {result.get('sl_distance_pips'):.1f} pips")
            print(f"   Recommandé: {'✅ OUI' if result.get('recommended') else '❌ NON'}")
            
            return result


async def monitor_symbol(symbol: str, check_interval_seconds: int = 60):
    """
    Boucle de surveillance principale d'un symbole
    M5 Alerte → M1 Signal → Calcul Lot → Whatsapp Notif
    """
    print(f"\n{'='*80}")
    print(f"🚀 DÉMARRAGE SURVEILLANCE {symbol}")
    print(f"   Max Risk: $2.50 | Check Interval: {check_interval_seconds}s")
    print(f"   API: {API_BASE}")
    print(f"{'='*80}\n")
    
    m5_alert_active = None
    
    while True:
        try:
            # 1. Vérifier M5 (toutes les 5 minutes approx)
            if not m5_alert_active:
                m5_alert = await check_m5_alert(symbol)
                if m5_alert:
                    m5_alert_active = m5_alert
                    print(f"\n⏳ Alerte M5 active: surveillance M1 pendant 5 minutes max...")
            
            # 2. Si alerte M5 active, vérifier M1
            if m5_alert_active:
                m1_signal = await check_m1_signal(symbol, m5_alert_active)
                
                if m1_signal:
                    # 3. Calculer la taille de position
                    details = m1_signal.get("details", {})
                    await calculate_position_size(
                        symbol, 
                        details.get("entry_price"), 
                        details.get("stop_loss")
                    )
                    
                    print(f"\n📱 Notification WhatsApp envoyée!")
                    
                    # Réinitialiser l'alerte M5 après exécution
                    m5_alert_active = None
                else:
                    # Vérifier si l'alerte M5 n'est pas trop vieille (>5 min)
                    print(f"   ↳ Pas de signal M1, prochain check dans {check_interval_seconds}s...")
            
            await asyncio.sleep(check_interval_seconds)
            
        except KeyboardInterrupt:
            print(f"\n\n🛑 Surveillance arrêtée par l'utilisateur
        except Exception as e:
            print(f"❌ Erreur: {e}")
            await asyncio.sleep(check_interval_seconds)


# Exécution
if __name__ == "__main__":
    import sys
    
    # Symbole à surveiller
    SYMBOL = sys.argv[1] if len(sys.argv) > 1 else "Boom 500"
    INTERVAL = int(sys.argv[2]) if len(sys.argv) > 2 else 30  # Secondes
    
    print(f"\n🎯 FVG Spike Detector Client")
    print(f"   Symbole: {SYMBOL}")
    print(f"   Intervalle: {INTERVAL}s")
    print(f"   API: {API_BASE}\n")
    
    # Mode test rapide ou surveillance continue
    if "--test" in sys.argv:
        # Mode test: une seule passe
        print("Mode TEST - Passe unique\n")
        asyncio.run(check_m5_alert(SYMBOL))
    else:
        # Mode surveillance continue
        asyncio.run(monitor_symbol(SYMBOL, INTERVAL))
