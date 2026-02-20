#!/usr/bin/env python3
"""
Intégration du système ML dans ai_server.py
Modification de l'endpoint /decision pour utiliser l'apprentissage automatique
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from ml_trading_system import ml_enhancer

def enhance_ai_server_with_ml():
    """Ajouter le système ML à ai_server.py"""
    
    ml_integration_code = '''
# ===== SYSTÈME D'APPRENTISSAGE AUTOMATIQUE =====
# Importer le système ML
try:
    from ml_trading_system import ml_enhancer
    ML_AVAILABLE = True
    logger.info("🧠 Système ML chargé avec succès")
except ImportError as e:
    ML_AVAILABLE = False
    logger.warning(f"⚠️ Système ML non disponible: {e}")

# Fonction pour améliorer les décisions avec ML
def enhance_decision_with_ml(symbol: str, decision: str, confidence: float, market_data: dict = None) -> dict:
    """Améliorer une décision avec le système ML"""
    if not ML_AVAILABLE:
        return {
            "original_decision": decision,
            "original_confidence": confidence,
            "enhanced_decision": decision,
            "enhanced_confidence": confidence,
            "ml_reason": "ml_unavailable",
            "ml_applied": False
        }
    
    try:
        return ml_enhancer.enhance_decision(symbol, decision, confidence, market_data)
    except Exception as e:
        logger.error(f"❌ Erreur enhancement ML: {e}")
        return {
            "original_decision": decision,
            "original_confidence": confidence,
            "enhanced_decision": decision,
            "enhanced_confidence": confidence,
            "ml_reason": "error",
            "ml_applied": False
        }

# Modifier la fonction decision_simplified pour utiliser le ML
async def decision_simplified_ml_enhanced(request: DecisionRequest):
    """
    Fonction de décision simplifiée avec amélioration ML
    """
    global decision_count
    decision_count += 1
    
    logger.info(f"🎯 MODE SIMPLIFIÉ + ML - Requête décision pour {request.symbol}")
    logger.info(f"   Bid: {request.bid}, Ask: {request.ask}, RSI: {request.rsi}")
    
    # Analyse technique de base
    action = "hold"
    confidence = 0.5
    reason = "Analyse technique multi-timeframe"
    
    # Scores pondérés par timeframe
    buy_score = 0.0
    sell_score = 0.0
    
    # 1. Analyse RSI (poids: 15%)
    if request.rsi:
        if request.rsi < 30:
            buy_score += 0.15
            reason += f"RSI surventé ({request.rsi:.1f}). "
        elif request.rsi > 70:
            sell_score += 0.15
            reason += f"RSI surachat ({request.rsi:.1f}). "
        elif 30 <= request.rsi <= 40:
            buy_score += 0.08
            reason += f"RSI zone survente ({request.rsi:.1f}). "
        elif 60 <= request.rsi <= 70:
            sell_score += 0.08
            reason += f"RSI zone surachat ({request.rsi:.1f}). "
    
    # 2. Analyse EMA M1 (poids: 20%)
    if request.ema_fast_m1 and request.ema_slow_m1:
        ema_diff_m1 = request.ema_fast_m1 - request.ema_slow_m1
        ema_strength_m1 = abs(ema_diff_m1) / request.ema_slow_m1 if request.ema_slow_m1 > 0 else 0
        
        if ema_diff_m1 > 0:
            buy_score += 0.20 * min(1.0, ema_strength_m1 * 100)
            reason += f"EMA M1 haussière (+{ema_strength_m1*100:.1f}%). "
        else:
            sell_score += 0.20 * min(1.0, ema_strength_m1 * 100)
            reason += f"EMA M1 baissière ({ema_strength_m1*100:.1f}%). "
    
    # 3. Analyse EMA H1 (poids: 35%)
    if request.ema_fast_h1 and request.ema_slow_h1:
        ema_diff_h1 = request.ema_fast_h1 - request.ema_slow_h1
        ema_strength_h1 = abs(ema_diff_h1) / request.ema_slow_h1 if request.ema_slow_h1 > 0 else 0
        
        if ema_diff_h1 > 0:
            buy_score += 0.35 * min(1.0, ema_strength_h1 * 50)
            reason += f"EMA H1 haussière (+{ema_strength_h1*50:.1f}%). "
        else:
            sell_score += 0.35 * min(1.0, ema_strength_h1 * 50)
            reason += f"EMA H1 baissière ({ema_strength_h1*50:.1f}%). "
    
    # 4. Analyse EMA M5 (poids: 25%)
    if request.ema_fast_m5 and request.ema_slow_m5:
        ema_diff_m5 = request.ema_fast_m5 - request.ema_slow_m5
        ema_strength_m5 = abs(ema_diff_m5) / request.ema_slow_m5 if request.ema_slow_m5 > 0 else 0
        
        if ema_diff_m5 > 0:
            buy_score += 0.25 * min(1.0, ema_strength_m5 * 75)
            reason += f"EMA M5 haussière (+{ema_strength_m5*75:.1f}%). "
        else:
            sell_score += 0.25 * min(1.0, ema_strength_m5 * 75)
            reason += f"EMA M5 baissière ({ema_strength_m5*75:.1f}%). "
    
    # 5. Décision technique de base
    if buy_score > sell_score:
        base_action = "buy"
        base_confidence = 0.5 + (buy_score - sell_score) / 2
    elif sell_score > buy_score:
        base_action = "sell"
        base_confidence = 0.5 + (sell_score - buy_score) / 2
    else:
        base_action = "hold"
        base_confidence = 0.5
    
    # 6. AMÉLIORATION AVEC ML
    market_data = {
        "symbol": request.symbol,
        "bid": request.bid,
        "ask": request.ask,
        "rsi": request.rsi,
        "ema_fast_m1": request.ema_fast_m1,
        "ema_slow_m1": request.ema_slow_m1,
        "ema_fast_h1": request.ema_fast_h1,
        "ema_slow_h1": request.ema_slow_h1,
        "ema_fast_m5": request.ema_fast_m5,
        "ema_slow_m5": request.ema_slow_m5,
        "atr": request.atr,
        "timestamp": request.timestamp
    }
    
    ml_result = enhance_decision_with_ml(request.symbol, base_action, base_confidence, market_data)
    
    # Utiliser la décision améliorée par ML
    action = ml_result["enhanced_decision"]
    confidence = ml_result["enhanced_confidence"]
    
    # Ajouter la raison ML à la raison technique
    if ml_result["ml_applied"]:
        reason += f"[ML: {ml_result['ml_reason']}] "
        logger.info(f"🧠 ML Enhancement: {base_action} → {action} ({base_confidence:.2f} → {confidence:.2f})")
    
    # 7. Ajustements finaux
    if action == "hold":
        confidence = max(0.3, confidence - 0.2)
    
    # 8. Calcul SL/TP
    stop_loss = None
    take_profit = None
    
    if action == "buy" and request.bid:
        atr = request.atr if request.atr and request.atr > 0 else 0.0020
        stop_loss = request.bid - atr * 2
        take_profit = request.bid + atr * 3
    elif action == "sell" and request.ask:
        atr = request.atr if request.atr and request.atr > 0 else 0.0020
        stop_loss = request.ask + atr * 2
        take_profit = request.ask - atr * 3
    
    # 9. Créer la réponse enrichie
    response = DecisionResponse(
        action=action,
        confidence=confidence,
        reason=reason,
        stop_loss=stop_loss,
        take_profit=take_profit,
        timestamp=datetime.now().isoformat(),
        model_used="technical_ml_enhanced",
        metadata={
            "original_decision": ml_result["original_decision"],
            "original_confidence": ml_result["original_confidence"],
            "ml_enhanced": ml_result["ml_applied"],
            "ml_reason": ml_result["ml_reason"],
            "base_scores": {"buy": buy_score, "sell": sell_score},
            "market_data": market_data
        }
    )
    
    # 10. Sauvegarder la décision dans Supabase
    try:
        if RUNNING_ON_SUPABASE:
            await save_decision_to_supabase(request, response, ml_result)
    except Exception as e:
        logger.error(f"❌ Erreur sauvegarde décision Supabase: {e}")
    
    return response

async def save_decision_to_supabase(request: DecisionRequest, response: DecisionResponse, ml_result: dict):
    """Sauvegarder la décision améliorée dans Supabase"""
    import httpx
    
    supabase_url = os.getenv("SUPABASE_URL", "https://bpzqnooiisgadzicwupi.supabase.co")
    supabase_key = os.getenv("SUPABASE_ANON_KEY")
    
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }
    
    decision_data = {
        "symbol": request.symbol,
        "timeframe": "M1",
        "prediction": response.action,
        "confidence": response.confidence,
        "reason": response.reason,
        "model_used": "technical_ml_enhanced",
        "metadata": {
            "original_decision": ml_result["original_decision"],
            "original_confidence": ml_result["original_confidence"],
            "ml_enhanced": ml_result["ml_applied"],
            "ml_reason": ml_result["ml_reason"],
            "request_data": {
                "bid": request.bid,
                "ask": request.ask,
                "rsi": request.rsi,
                "ema_fast_m1": request.ema_fast_m1,
                "ema_slow_m1": request.ema_slow_m1,
                "ema_fast_h1": request.ema_fast_h1,
                "ema_slow_h1": request.ema_slow_h1,
                "ema_fast_m5": request.ema_fast_m5,
                "ema_slow_m5": request.ema_slow_m5,
                "atr": request.atr
            }
        }
    }
    
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(
                f"{supabase_url}/rest/v1/predictions",
                json=decision_data,
                headers=headers,
                timeout=10.0
            )
            
            if resp.status_code == 201:
                logger.info(f"✅ Décision ML sauvegardée dans Supabase pour {request.symbol}")
            else:
                logger.error(f"❌ Erreur sauvegarde décision: {resp.status_code} - {resp.text}")
                
        except Exception as e:
            logger.error(f"❌ Erreur connexion Supabase: {e}")

# Endpoint pour entraîner les modèles ML
@app.post("/train_ml_models")
async def train_ml_models():
    """Endpoint pour entraîner les modèles ML"""
    try:
        if not ML_AVAILABLE:
            return {"status": "error", "message": "ML system not available"}
        
        logger.info("🧪 Début entraînement modèles ML...")
        results = ml_enhancer.train_all_symbols()
        
        return {
            "status": "success",
            "message": "ML models training completed",
            "results": results,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Erreur entraînement ML: {e}")
        return {"status": "error", "message": str(e)}

# Endpoint pour obtenir les statistiques ML
@app.get("/ml_stats")
async def get_ml_stats():
    """Obtenir les statistiques des modèles ML"""
    try:
        if not ML_AVAILABLE:
            return {"status": "error", "message": "ML system not available"}
        
        stats = {}
        for symbol, model in ml_enhancer.ml_system.symbol_models.items():
            stats[symbol] = {
                "win_rate": model.get("win_rate", 0),
                "total_trades": model.get("total_trades", 0),
                "confidence_threshold": model.get("confidence_threshold", 0.7),
                "last_updated": model.get("last_updated"),
                "decision_weights": model.get("decision_weights", {}),
                "time_patterns": model.get("time_patterns", {})
            }
        
        return {
            "status": "success",
            "stats": stats,
            "total_models": len(stats),
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Erreur stats ML: {e}")
        return {"status": "error", "message": str(e)}

# Remplacer la fonction decision_simplified existante
# Dans ai_server.py, remplacer la fonction decision_simplified par decision_simplified_ml_enhanced
'''
    
    return ml_integration_code

def main():
    """Point d'entrée principal"""
    print("🚀 INTÉGRATION DU SYSTÈME ML DANS AI_SERVER.PY")
    print("=" * 60)
    
    # Générer le code d'intégration
    integration_code = enhance_ai_server_with_ml()
    
    # Sauvegarder dans un fichier
    with open("ml_integration_code.py", "w", encoding="utf-8") as f:
        f.write(integration_code)
    
    print("✅ Code d'intégration généré dans 'ml_integration_code.py'")
    print("\n📋 ÉTAPES D'INTÉGRATION:")
    print("1. Copier le code de 'ml_integration_code.py'")
    print("2. Ajouter au début de 'ai_server.py' après les imports")
    print("3. Remplacer la fonction decision_simplified par decision_simplified_ml_enhanced")
    print("4. Ajouter les nouveaux endpoints: /train_ml_models et /ml_stats")
    print("5. Redémarrer ai_server.py")
    
    print("\n🎯 Nouvelles fonctionnalités:")
    print("• Décisions améliorées par ML")
    print("• Apprentissage automatique continu")
    print("• Calibration adaptative par symbole")
    print("• Patterns temporels optimisés")
    print("• Seuils de confiance dynamiques")

if __name__ == "__main__":
    main()
