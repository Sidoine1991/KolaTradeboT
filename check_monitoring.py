#!/usr/bin/env python3
"""
Script de vérification des endpoints de monitoring ML
"""
import json
import urllib.request
import urllib.error
from datetime import datetime

BASE_URL = "http://localhost:8000"

def print_header(title):
    print("\n" + "="*60)
    print(f"  {title}")
    print("="*60)

def print_section(title):
    print(f"\n[*] {title}")
    print("-" * 60)

def check_endpoint(endpoint, description):
    """Vérifie un endpoint et affiche le résultat"""
    try:
        url = f"{BASE_URL}{endpoint}"
        print(f"\n[TEST] {endpoint}")
        print(f"   Description: {description}")
        
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=5) as response:
            status_code = response.getcode()
            if status_code == 200:
                data = json.loads(response.read().decode('utf-8'))
                print(f"   [OK] Statut: {status_code}")
                print(f"   [INFO] Reponse:")
                print(json.dumps(data, indent=2, ensure_ascii=False))
                return True, data
            else:
                print(f"   [ERREUR] Statut: {status_code}")
                return False, None
    except urllib.error.URLError as e:
        if isinstance(e.reason, ConnectionRefusedError) or "Connection refused" in str(e):
            print(f"   [ERREUR] Impossible de se connecter au serveur")
            print(f"   [INFO] Verifiez que le serveur est demarre sur {BASE_URL}")
        else:
            print(f"   [ERREUR] Connexion: {str(e)}")
        return False, None
    except Exception as e:
        print(f"   [ERREUR] {str(e)}")
        return False, None

def main():
    print_header("VERIFICATION DES ENDPOINTS DE MONITORING ML")
    print(f"\n[+] Debut des verifications: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    results = {}
    
    # 1. Vérifier la santé du serveur
    print_section("1. Vérification de la santé du serveur")
    success, health_data = check_endpoint("/health", "Vérification de santé du serveur")
    results["health"] = success
    
    if not success:
        print("\n[WARN] Le serveur ne repond pas. Veuillez demarrer le serveur avec:")
        print("   python ai_server.py")
        return
    
    # 2. Vérifier le statut de la base de données trade_feedback
    print_section("2. Vérification du statut de la base de données trade_feedback")
    success, feedback_data = check_endpoint("/ml/feedback/status", 
                                             "Statut de la base de données trade_feedback")
    results["feedback_status"] = success
    
    if success and feedback_data:
        stats = feedback_data.get("statistics", {})
        print(f"\n[STATS] Statistiques recapitulatives:")
        print(f"   - Total trades: {stats.get('total_trades', 0)}")
        print(f"   - Wins: {stats.get('total_wins', 0)}")
        print(f"   - Losses: {stats.get('total_losses', 0)}")
        print(f"   - Win Rate: {stats.get('win_rate', 0):.2f}%")
        print(f"   - Profit total: ${stats.get('total_profit', 0):.2f}")
        print(f"   - Trades recents (7j): {stats.get('recent_trades_7d', 0)}")
        
        # Vérifier si on a assez de données
        min_samples = stats.get("min_samples_for_retraining", 50)
        print(f"\n[CONFIG] Seuil minimum pour reentrainement: {min_samples} trades")
        
        trades_by_cat = feedback_data.get("trades_by_category", {})
        if trades_by_cat:
            print(f"\n[CATEGORIES] Trades par categorie:")
            for cat, data in trades_by_cat.items():
                ready = "[OK]" if data.get("ready_for_retraining") else "[WAIT]"
                print(f"   {ready} {cat}: {data.get('count', 0)} trades "
                      f"(Wins: {data.get('wins', 0)}, "
                      f"Pret: {data.get('ready_for_retraining', False)})")
    
    # 3. Vérifier les statistiques de réentraînement
    print_section("3. Vérification des statistiques de réentraînement")
    success, retrain_data = check_endpoint("/ml/retraining/stats",
                                           "Statistiques de réentraînement")
    results["retraining_stats"] = success
    
    if success and retrain_data:
        config = retrain_data.get("config", {})
        print(f"\n[CONFIG] Configuration:")
        print(f"   - Minimum d'echantillons: {config.get('min_new_samples', 50)}")
        print(f"   - Intervalle de reentrainement: {config.get('retrain_interval_days', 1)} jours")
        
        status = retrain_data.get("retraining_status", {})
        if status:
            print(f"\n[HISTORY] Derniers reentrainements:")
            for cat, data in status.items():
                last = data.get("last_retrained")
                if last:
                    days = data.get("days_since", 0)
                    should = "[READY]" if data.get("should_retrain") else "[WAIT]"
                    print(f"   {should} {cat}:")
                    print(f"      - Dernier: {last}")
                    print(f"      - Il y a: {days} jours")
                    print(f"      - Reentrainement necessaire: {data.get('should_retrain', False)}")
                else:
                    print(f"   [WARN] {cat}: Jamais reentraine")
    
    # 4. Résumé
    print_header("RESUME DES VERIFICATIONS")
    print(f"\n[+] Fin des verifications: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    total = len(results)
    passed = sum(1 for v in results.values() if v)
    
    print(f"\n[OK] Tests reussis: {passed}/{total}")
    print(f"[ERREUR] Tests echoues: {total - passed}/{total}")
    
    if all(results.values()):
        print("\n[SUCCESS] Tous les tests sont passes! Le systeme de monitoring fonctionne correctement.")
    else:
        print("\n[WARN] Certains tests ont echoue. Veuillez verifier les erreurs ci-dessus.")
    
    print("\n" + "="*60)
    print("[INFO] Pour plus d'informations, consultez MONITORING_ML.md")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
