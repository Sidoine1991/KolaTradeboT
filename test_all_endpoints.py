#!/usr/bin/env python3
"""
Test de tous les endpoints de l'API
"""
import requests
import json
from datetime import datetime

def test_endpoint(url, method="GET", payload=None):
    """Test un endpoint et retourne le résultat"""
    try:
        if method == "GET":
            response = requests.get(url, timeout=10)
        elif method == "POST":
            headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
            
            # Pour l'endpoint /analysis, on envoie le payload directement dans le corps
            if 'analysis' in url and not url.endswith('raw_request'):
                response = requests.post(
                    url,
                    headers=headers,
                    json=payload if payload else {},
                    timeout=10
                )
            else:
                # Pour les autres endpoints, on utilise le format standard
                response = requests.post(
                    url, 
                    headers=headers, 
                    json=payload if payload else {},
                    timeout=10
                )
        
        return {
            "status": "✅" if 200 <= response.status_code < 300 else "❌",
            "code": response.status_code,
            "response": response.json() if response.content else {}
        }
    except Exception as e:
        return {
            "status": "❌",
            "error": str(e),
            "code": None
        }

def main():
    print("🔍 Test de tous les endpoints")
    print("=" * 50)
    
    # Configuration
    base_url = "http://localhost:8000"
    trend_url = "http://localhost:8001"
    
    # Liste des endpoints à tester
    endpoints = [
        # API Principale (8000)
        {"name": "Health Check", "url": f"{base_url}/health", "method": "GET"},
        
        # Test 1: Analyse avec paramètre GET
        {"name": "Analysis (GET)", "url": f"{base_url}/analysis?symbol=EURUSD", "method": "GET"},
        
        # Test 2: Analyse avec payload JSON
        # On utilise le même format que raw_request pour la compatibilité
        {"name": "Analysis (POST - JSON)", 
         "url": f"{base_url}/analysis", 
         "method": "POST", 
         "payload": {
             "raw_request": {
                 "symbol": "EURUSD",
                 "request_type": "fibonacci_analysis"
             }
         }},
        
        # Test 3: Analyse avec raw_request (format MT5)
        {"name": "Analysis (POST - Raw)", 
         "url": f"{base_url}/analysis", 
         "method": "POST",
         "payload": {
             "raw_request": {
                 "symbol": "EURUSD",
                 "request_type": "fibonacci_analysis"
             }
         }},
        
        # API Trend (8001)
        {"name": "Trend API Health", "url": f"{trend_url}/health", "method": "GET"},
        {"name": "Trend Data", "url": f"{trend_url}/trend?symbol=EURUSD&timeframe=M1", "method": "GET"},
        {"name": "Trend Status", "url": f"{trend_url}/status", "method": "GET"}
    ]
    
    # Exécution des tests
    results = []
    for endpoint in endpoints:
        print(f"Testing {endpoint['name']}...")
        result = test_endpoint(
            endpoint['url'],
            endpoint['method'],
            endpoint.get('payload')
        )
        results.append({
            "endpoint": endpoint['name'],
            "url": endpoint['url'],
            **result
        })
    
    # Affichage des résultats
    print("\n📊 Résultats des tests")
    print("=" * 50)
    for result in results:
        status = result["status"]
        print(f"{status} {result['endpoint']} ({result.get('code', 'N/A')})")
        print(f"   URL: {result['url']}")
        if "error" in result:
            print(f"   Erreur: {result['error']}")
        if "response" in result and result["response"]:
            print("   Réponse:")
            print(f"   {json.dumps(result['response'], indent=2, ensure_ascii=False)}")
        print()
    
    print("\n✅ Tests terminés")

if __name__ == "__main__":
    main()
