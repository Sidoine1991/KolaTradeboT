#!/usr/bin/env python3
"""
Test d'Intégration AngelOfSpike avec Boom Rising Channel Predictor
Vérifie que l'API est compatible avec le robot AngelOfSpike
"""

import requests
import time
import json
from datetime import datetime
import sys

def test_api_availability():
    """Teste la disponibilité de l'API"""
    print("🧪 Test de disponibilité de l'API...")
    
    try:
        response = requests.get("http://localhost:8002/health", timeout=5)
        if response.status_code == 200:
            print("✅ API Boom Rising Channel Predictor accessible")
            return True
        else:
            print(f"❌ API non accessible: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur connexion API: {e}")
        return False

def test_angelofspike_endpoint():
    """Teste l'endpoint AngelOfSpike"""
    print("\n🧪 Test de l'endpoint AngelOfSpike...")
    
    try:
        url = "http://localhost:8002/angelofspike/trend?symbol=Boom 1000 Index&timeframe=M1"
        response = requests.get(url, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Endpoint AngelOfSpike fonctionnel")
            print(f"   Direction: {data.get('direction', 'N/A')}")
            print(f"   Force: {data.get('strength', 0)}")
            print(f"   Confiance: {data.get('confidence', 0)}")
            print(f"   Signal: {data.get('signal', 'N/A')}")
            print(f"   Trend: {data.get('trend', 'N/A')}")
            
            # Vérifier les champs requis pour AngelOfSpike
            required_fields = ['direction', 'strength', 'confidence', 'signal', 'trend']
            missing_fields = [field for field in required_fields if field not in data]
            
            if missing_fields:
                print(f"⚠️ Champs manquants: {missing_fields}")
                return False
            else:
                print("✅ Tous les champs requis sont présents")
                return True
        else:
            print(f"❌ Endpoint non accessible: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur endpoint AngelOfSpike: {e}")
        return False

def test_boom_prediction_endpoint():
    """Teste l'endpoint de prédiction Boom"""
    print("\n🧪 Test de l'endpoint de prédiction Boom...")
    
    try:
        url = "http://localhost:8002/predict?symbol=Boom 1000 Index&timeframe=M1"
        response = requests.get(url, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Endpoint de prédiction Boom fonctionnel")
            print(f"   Action: {data.get('action', 'N/A')}")
            print(f"   Direction: {data.get('direction', 'N/A')}")
            print(f"   Confiance: {data.get('confidence', 0):.2f}")
            print(f"   Probabilité Spike: {data.get('spike_probability', 0):.2f}")
            print(f"   Temps estimé: {data.get('time_to_spike', 0)}s")
            print(f"   Proximité EMA: {data.get('ema_proximity', 'N/A')}")
            print(f"   Position Canal: {data.get('channel_position', 'N/A')}")
            return True
        else:
            print(f"❌ Endpoint non accessible: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur endpoint prédiction: {e}")
        return False

def test_status_endpoint():
    """Teste l'endpoint de statut"""
    print("\n🧪 Test de l'endpoint de statut...")
    
    try:
        response = requests.get("http://localhost:8002/status", timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Endpoint de statut fonctionnel")
            print(f"   Statut: {data.get('status', 'N/A')}")
            print(f"   Prédictions actives: {data.get('active_predictions', 0)}")
            print(f"   Canaux actifs: {data.get('active_channels', 0)}")
            print(f"   Taux de réussite: {data.get('success_rate', 0):.1%}")
            return True
        else:
            print(f"❌ Endpoint non accessible: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur endpoint statut: {e}")
        return False

def test_config_endpoint():
    """Teste l'endpoint de configuration"""
    print("\n🧪 Test de l'endpoint de configuration...")
    
    try:
        response = requests.get("http://localhost:8002/config", timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Endpoint de configuration fonctionnel")
            
            config = data.get('config', {})
            boom_config = config.get('boom', {})
            ema_config = config.get('ema', {})
            
            print(f"   Symbole: {boom_config.get('symbol', 'N/A')}")
            print(f"   Timeframe: {boom_config.get('timeframe', 'N/A')}")
            print(f"   Périodes EMA: {ema_config.get('periods', [])}")
            return True
        else:
            print(f"❌ Endpoint non accessible: {response.status_code}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur endpoint configuration: {e}")
        return False

def test_multiple_requests():
    """Teste plusieurs requêtes consécutives"""
    print("\n🧪 Test de requêtes multiples...")
    
    try:
        success_count = 0
        total_requests = 5
        
        for i in range(total_requests):
            url = "http://localhost:8002/angelofspike/trend?symbol=Boom 1000 Index&timeframe=M1"
            response = requests.get(url, timeout=5)
            
            if response.status_code == 200:
                success_count += 1
                print(f"   Requête {i+1}/{total_requests}: ✅")
            else:
                print(f"   Requête {i+1}/{total_requests}: ❌ ({response.status_code})")
            
            time.sleep(1)  # Attendre 1 seconde entre les requêtes
        
        success_rate = success_count / total_requests
        print(f"✅ Taux de réussite: {success_rate:.1%} ({success_count}/{total_requests})")
        
        return success_rate >= 0.8  # 80% de réussite minimum
        
    except Exception as e:
        print(f"❌ Erreur requêtes multiples: {e}")
        return False

def test_response_format():
    """Teste le format de réponse pour AngelOfSpike"""
    print("\n🧪 Test du format de réponse AngelOfSpike...")
    
    try:
        url = "http://localhost:8002/angelofspike/trend?symbol=Boom 1000 Index&timeframe=M1"
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            
            # Vérifier le format exact attendu par AngelOfSpike
            expected_format = {
                'direction': str,
                'strength': int,
                'confidence': int,
                'signal': str,
                'trend': str
            }
            
            format_valid = True
            for field, expected_type in expected_format.items():
                if field not in data:
                    print(f"❌ Champ manquant: {field}")
                    format_valid = False
                elif not isinstance(data[field], expected_type):
                    print(f"❌ Type incorrect pour {field}: {type(data[field])} au lieu de {expected_type}")
                    format_valid = False
            
            if format_valid:
                print("✅ Format de réponse compatible avec AngelOfSpike")
                
                # Vérifier les valeurs
                direction = data.get('direction')
                if direction in ['BUY', 'SELL', 'NEUTRAL']:
                    print(f"✅ Direction valide: {direction}")
                else:
                    print(f"⚠️ Direction non standard: {direction}")
                
                strength = data.get('strength')
                if 0 <= strength <= 100:
                    print(f"✅ Force valide: {strength}")
                else:
                    print(f"⚠️ Force hors plage: {strength}")
                
                confidence = data.get('confidence')
                if 0 <= confidence <= 100:
                    print(f"✅ Confiance valide: {confidence}")
                else:
                    print(f"⚠️ Confiance hors plage: {confidence}")
                
                return True
            else:
                print("❌ Format de réponse incompatible avec AngelOfSpike")
                return False
        else:
            print(f"❌ Endpoint non accessible: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Erreur test format: {e}")
        return False

def test_performance():
    """Teste les performances de l'API"""
    print("\n🧪 Test de performance...")
    
    try:
        start_time = time.time()
        
        url = "http://localhost:8002/angelofspike/trend?symbol=Boom 1000 Index&timeframe=M1"
        response = requests.get(url, timeout=10)
        
        end_time = time.time()
        response_time = end_time - start_time
        
        if response.status_code == 200:
            print(f"✅ Temps de réponse: {response_time:.3f}s")
            
            if response_time < 1.0:
                print("✅ Performance excellente")
            elif response_time < 2.0:
                print("✅ Performance bonne")
            elif response_time < 5.0:
                print("⚠️ Performance acceptable")
            else:
                print("❌ Performance à améliorer")
            
            return response_time < 5.0
        else:
            print(f"❌ Erreur de réponse: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Erreur test performance: {e}")
        return False

def generate_angelofspike_config():
    """Génère un fichier de configuration pour AngelOfSpike"""
    print("\n📝 Génération de la configuration AngelOfSpike...")
    
    config = {
        "api_url": "http://localhost:8002/angelofspike/trend",
        "symbol": "Boom 1000 Index",
        "timeframe": "M1",
        "update_interval": 30,
        "timeout": 10,
        "retry_attempts": 3,
        "retry_delay": 5,
        "min_confidence": 70,
        "min_strength": 60,
        "trading_enabled": True,
        "log_level": "INFO"
    }
    
    config_file = "angelofspike_config.json"
    try:
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Configuration AngelOfSpike créée: {config_file}")
        
        # Afficher la configuration
        print("\n📋 Configuration générée:")
        for key, value in config.items():
            print(f"   {key}: {value}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur création configuration: {e}")
        return False

def main():
    """Fonction principale de test"""
    print("🧪 Test d'Intégration AngelOfSpike avec Boom Rising Channel Predictor")
    print("=" * 80)
    print(f"📅 Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    # Liste des tests
    tests = [
        ("Disponibilité API", test_api_availability),
        ("Endpoint AngelOfSpike", test_angelofspike_endpoint),
        ("Endpoint Prédiction Boom", test_boom_prediction_endpoint),
        ("Endpoint Statut", test_status_endpoint),
        ("Endpoint Configuration", test_config_endpoint),
        ("Requêtes Multiples", test_multiple_requests),
        ("Format Réponse", test_response_format),
        ("Performance", test_performance)
    ]
    
    results = []
    
    # Exécuter les tests
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ Erreur critique dans {test_name}: {e}")
            results.append((test_name, False))
    
    # Résumé des résultats
    print("\n📊 Résumé des Tests d'Intégration")
    print("=" * 50)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name:25} {status}")
        if result:
            passed += 1
    
    print(f"\nRésultat: {passed}/{total} tests réussis")
    
    # Générer la configuration AngelOfSpike
    generate_angelofspike_config()
    
    # Conclusion
    if passed == total:
        print("\n🎉 Tous les tests d'intégration sont passés!")
        print("✅ L'API est prête pour AngelOfSpike")
        
        print("\n🤖 Configuration AngelOfSpike:")
        print("   URL: http://localhost:8002/angelofspike/trend")
        print("   Symbole: Boom 1000 Index")
        print("   Timeframe: M1")
        print("   Format: JSON")
        
        print("\n📋 Prochaines étapes:")
        print("   1. Configurer AngelOfSpike avec l'URL ci-dessus")
        print("   2. Utiliser le fichier angelofspike_config.json")
        print("   3. Surveiller les logs pour vérifier le fonctionnement")
        print("   4. Ajuster les paramètres selon les résultats")
        
    else:
        print("\n⚠️ Certains tests ont échoué")
        print("   Vérifiez les erreurs ci-dessus avant de continuer")
        print("   Assurez-vous que l'API Boom est démarrée: python boom_api.py")
    
    print(f"\n📚 Documentation complète: README_BOOM_RISING_CHANNEL.md")
    print(f"🔧 Instructions d'intégration: INTEGRATION_BOOM_API.md")

if __name__ == "__main__":
    main()
