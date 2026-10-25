#!/usr/bin/env python3
"""
Script de test simple pour vérifier que toutes les tables Supabase sont utilisées par l'AI server
Version sans dépendances externes (utilise urllib)
"""

import os
import json
import urllib.request
import urllib.parse
from datetime import datetime, timedelta

class SupabaseTablesTester:
    """Testeur pour vérifier l'utilisation des tables Supabase"""
    
    def __init__(self):
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
        
        if not self.supabase_url or not self.supabase_key:
            print("❌ Variables Supabase manquantes")
            print("   Vérifiez que .env.supabase contient:")
            print("   - SUPABASE_URL")
            print("   - SUPABASE_SERVICE_KEY ou SUPABASE_ANON_KEY")
            return
        
        print(f"✅ Connexion à Supabase: {self.supabase_url}")
    
    def _make_request(self, method, url, data=None, params=None):
        """Effectue une requête HTTP avec urllib"""
        try:
            # Préparer l'URL
            if params:
                query_string = urllib.parse.urlencode(params)
                url = f"{url}?{query_string}"
            
            # Préparer les headers
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            }
            
            # Créer la requête
            req = urllib.request.Request(url, headers=headers)
            
            if method == "POST" and data:
                req.data = json.dumps(data).encode('utf-8')
                req.add_header('Content-Length', len(req.data))
            
            # Exécuter la requête
            with urllib.request.urlopen(req, timeout=10) as response:
                status_code = response.getcode()
                content = response.read().decode('utf-8')
                
                return status_code, content
                
        except Exception as e:
            return None, str(e)
    
    def test_training_runs_table(self):
        """Test la table training_runs"""
        print("\n📊 Test table training_runs")
        
        # Test d'insertion
        test_payload = {
            "symbol": "TEST_SYMBOL",
            "timeframe": "M1",
            "status": "running",
            "samples_used": 100,
            "accuracy": 0.85,
            "f1_score": 0.82,
            "duration_sec": 120,
            "metadata": {
                "model_type": "random_forest",
                "test": True
            }
        }
        
        # Insertion
        status, content = self._make_request(
            "POST", 
            f"{self.supabase_url}/rest/v1/training_runs",
            data=test_payload
        )
        
        if status in (200, 201):
            print("✅ training_runs: Insertion réussie")
            
            # Lecture
            status, content = self._make_request(
                "GET",
                f"{self.supabase_url}/rest/v1/training_runs",
                params={"symbol": "eq.TEST_SYMBOL", "limit": 1}
            )
            
            if status == 200:
                data = json.loads(content)
                if data:
                    print("✅ training_runs: Lecture réussie")
                    
                    # Nettoyage
                    status, _ = self._make_request(
                        "DELETE",
                        f"{self.supabase_url}/rest/v1/training_runs",
                        params={"id": f"eq.{data[0]['id']}"}
                    )
                    if status in (200, 204):
                        print("✅ training_runs: Nettoyage réussie")
                    else:
                        print(f"⚠️ training_runs: Nettoyage échoué (status: {status})")
                else:
                    print("⚠️ training_runs: Aucune donnée trouvée après insertion")
            else:
                print(f"❌ training_runs: Erreur lecture {status}")
        else:
            print(f"❌ training_runs: Erreur insertion {status}")
            if content:
                print(f"   Détail: {content[:200]}")
    
    def test_feature_importance_table(self):
        """Test la table feature_importance"""
        print("\n📊 Test table feature_importance")
        
        test_payload = [{
            "symbol": "TEST_SYMBOL",
            "timeframe": "M1",
            "model_type": "random_forest",
            "feature_name": "rsi",
            "importance": 0.25,
            "rank": 1
        }]
        
        # Insertion
        status, content = self._make_request(
            "POST",
            f"{self.supabase_url}/rest/v1/feature_importance",
            data=test_payload
        )
        
        if status in (200, 201):
            print("✅ feature_importance: Insertion réussie")
            
            # Lecture
            status, content = self._make_request(
                "GET",
                f"{self.supabase_url}/rest/v1/feature_importance",
                params={"symbol": "eq.TEST_SYMBOL", "limit": 1}
            )
            
            if status == 200:
                data = json.loads(content)
                if data:
                    print("✅ feature_importance: Lecture réussie")
                    
                    # Nettoyage
                    status, _ = self._make_request(
                        "DELETE",
                        f"{self.supabase_url}/rest/v1/feature_importance",
                        params={"id": f"eq.{data[0]['id']}"}
                    )
                    if status in (200, 204):
                        print("✅ feature_importance: Nettoyage réussie")
                    else:
                        print(f"⚠️ feature_importance: Nettoyage échoué (status: {status})")
                else:
                    print("⚠️ feature_importance: Aucune donnée trouvée après insertion")
            else:
                print(f"❌ feature_importance: Erreur lecture {status}")
        else:
            print(f"❌ feature_importance: Erreur insertion {status}")
            if content:
                print(f"   Détail: {content[:200]}")
    
    def test_symbol_calibration_table(self):
        """Test la table symbol_calibration"""
        print("\n📊 Test table symbol_calibration")
        
        test_payload = {
            "symbol": "TEST_SYMBOL",
            "timeframe": "M1",
            "wins": 85,
            "total": 100,
            "drift_factor": 0.95,
            "last_updated": datetime.now().isoformat(),
            "metadata": {
                "model_type": "random_forest",
                "accuracy": 0.85
            }
        }
        
        # Insertion
        status, content = self._make_request(
            "POST",
            f"{self.supabase_url}/rest/v1/symbol_calibration",
            data=test_payload
        )
        
        if status in (200, 201):
            print("✅ symbol_calibration: Insertion réussie")
            
            # Lecture
            status, content = self._make_request(
                "GET",
                f"{self.supabase_url}/rest/v1/symbol_calibration",
                params={"symbol": "eq.TEST_SYMBOL", "limit": 1}
            )
            
            if status == 200:
                data = json.loads(content)
                if data:
                    print("✅ symbol_calibration: Lecture réussie")
                    
                    # Nettoyage
                    status, _ = self._make_request(
                        "DELETE",
                        f"{self.supabase_url}/rest/v1/symbol_calibration",
                        params={"id": f"eq.{data[0]['id']}"}
                    )
                    if status in (200, 204):
                        print("✅ symbol_calibration: Nettoyage réussie")
                    else:
                        print(f"⚠️ symbol_calibration: Nettoyage échoué (status: {status})")
                else:
                    print("⚠️ symbol_calibration: Aucune donnée trouvée après insertion")
            else:
                print(f"❌ symbol_calibration: Erreur lecture {status}")
        else:
            print(f"❌ symbol_calibration: Erreur insertion {status}")
            if content:
                print(f"   Détail: {content[:200]}")
    
    def test_symbol_correction_patterns_table(self):
        """Test la table symbol_correction_patterns"""
        print("\n📊 Test table symbol_correction_patterns")
        
        test_payload = {
            "symbol": "TEST_SYMBOL",
            "pattern_type": "mean_reversion",
            "avg_retracement_percentage": 2.5,
            "typical_duration_bars": 15,
            "success_rate": 75.0,
            "min_trend_strength": 0.8,
            "max_volatility_level": 0.05,
            "best_timeframes": "M1,M5",
            "occurrences_count": 25,
            "last_updated": datetime.now().isoformat()
        }
        
        # Insertion
        status, content = self._make_request(
            "POST",
            f"{self.supabase_url}/rest/v1/symbol_correction_patterns",
            data=test_payload
        )
        
        if status in (200, 201):
            print("✅ symbol_correction_patterns: Insertion réussie")
            
            # Lecture
            status, content = self._make_request(
                "GET",
                f"{self.supabase_url}/rest/v1/symbol_correction_patterns",
                params={"symbol": "eq.TEST_SYMBOL", "limit": 1}
            )
            
            if status == 200:
                data = json.loads(content)
                if data:
                    print("✅ symbol_correction_patterns: Lecture réussie")
                    
                    # Nettoyage
                    status, _ = self._make_request(
                        "DELETE",
                        f"{self.supabase_url}/rest/v1/symbol_correction_patterns",
                        params={"id": f"eq.{data[0]['id']}"}
                    )
                    if status in (200, 204):
                        print("✅ symbol_correction_patterns: Nettoyage réussie")
                    else:
                        print(f"⚠️ symbol_correction_patterns: Nettoyage échoué (status: {status})")
                else:
                    print("⚠️ symbol_correction_patterns: Aucune donnée trouvée après insertion")
            else:
                print(f"❌ symbol_correction_patterns: Erreur lecture {status}")
        else:
            print(f"❌ symbol_correction_patterns: Erreur insertion {status}")
            if content:
                print(f"   Détail: {content[:200]}")
    
    def test_correction_summary_stats_table(self):
        """Test la table correction_summary_stats"""
        print("\n📊 Test table correction_summary_stats")
        
        test_payload = {
            "symbol": "TEST_SYMBOL",
            "timeframe": "M1",
            "period_start": (datetime.now() - timedelta(days=7)).isoformat(),
            "period_end": datetime.now().isoformat(),
            "total_corrections": 10,
            "successful_predictions": 8,
            "avg_retracement_pct": 2.2,
            "avg_duration_bars": 12.5,
            "success_rate": 80.0,
            "dominant_pattern": "mean_reversion",
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
            "metadata": {
                "category": "BOOM_CRASH",
                "analysis_period": "7d"
            }
        }
        
        # Insertion
        status, content = self._make_request(
            "POST",
            f"{self.supabase_url}/rest/v1/correction_summary_stats",
            data=test_payload
        )
        
        if status in (200, 201):
            print("✅ correction_summary_stats: Insertion réussie")
            
            # Lecture
            status, content = self._make_request(
                "GET",
                f"{self.supabase_url}/rest/v1/correction_summary_stats",
                params={"symbol": "eq.TEST_SYMBOL", "limit": 1}
            )
            
            if status == 200:
                data = json.loads(content)
                if data:
                    print("✅ correction_summary_stats: Lecture réussie")
                    
                    # Nettoyage
                    status, _ = self._make_request(
                        "DELETE",
                        f"{self.supabase_url}/rest/v1/correction_summary_stats",
                        params={"id": f"eq.{data[0]['id']}"}
                    )
                    if status in (200, 204):
                        print("✅ correction_summary_stats: Nettoyage réussie")
                    else:
                        print(f"⚠️ correction_summary_stats: Nettoyage échoué (status: {status})")
                else:
                    print("⚠️ correction_summary_stats: Aucune donnée trouvée après insertion")
            else:
                print(f"❌ correction_summary_stats: Erreur lecture {status}")
        else:
            print(f"❌ correction_summary_stats: Erreur insertion {status}")
            if content:
                print(f"   Détail: {content[:200]}")
    
    def test_support_resistance_levels_table(self):
        """Test la table support_resistance_levels (déjà utilisée)"""
        print("\n📊 Test table support_resistance_levels")
        
        test_payload = {
            "symbol": "TEST_SYMBOL",
            "support": 1000.50,
            "resistance": 1002.00,
            "timeframe": "M1",
            "strength_score": 75.5,
            "touch_count": 5,
            "last_touch": datetime.now().isoformat()
        }
        
        # Insertion
        status, content = self._make_request(
            "POST",
            f"{self.supabase_url}/rest/v1/support_resistance_levels",
            data=test_payload
        )
        
        if status in (200, 201):
            print("✅ support_resistance_levels: Insertion réussie")
            
            # Lecture
            status, content = self._make_request(
                "GET",
                f"{self.supabase_url}/rest/v1/support_resistance_levels",
                params={"symbol": "eq.TEST_SYMBOL", "limit": 1}
            )
            
            if status == 200:
                data = json.loads(content)
                if data:
                    print("✅ support_resistance_levels: Lecture réussie")
                    
                    # Nettoyage
                    status, _ = self._make_request(
                        "DELETE",
                        f"{self.supabase_url}/rest/v1/support_resistance_levels",
                        params={"id": f"eq.{data[0]['id']}"}
                    )
                    if status in (200, 204):
                        print("✅ support_resistance_levels: Nettoyage réussie")
                    else:
                        print(f"⚠️ support_resistance_levels: Nettoyage échoué (status: {status})")
                else:
                    print("⚠️ support_resistance_levels: Aucune donnée trouvée après insertion")
            else:
                print(f"❌ support_resistance_levels: Erreur lecture {status}")
        else:
            print(f"❌ support_resistance_levels: Erreur insertion {status}")
            if content:
                print(f"   Détail: {content[:200]}")
    
    def run_all_tests(self):
        """Exécute tous les tests"""
        print("🚀 Démarrage des tests de tables Supabase")
        print("=" * 60)
        
        # Charger les variables d'environnement
        try:
            with open('.env.supabase', 'r') as f:
                for line in f:
                    if '=' in line and not line.startswith('#'):
                        key, value = line.strip().split('=', 1)
                        os.environ[key] = value
        except FileNotFoundError:
            print("⚠️ Fichier .env.supabase non trouvé")
        except Exception as e:
            print(f"⚠️ Erreur lecture .env.supabase: {e}")
        
        # Vérifier les variables
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")
        
        if not self.supabase_url or not self.supabase_key:
            print("❌ Configuration Supabase manquante")
            return
        
        self.test_training_runs_table()
        self.test_feature_importance_table()
        self.test_symbol_calibration_table()
        self.test_symbol_correction_patterns_table()
        self.test_correction_summary_stats_table()
        self.test_support_resistance_levels_table()
        
        print("\n" + "=" * 60)
        print("✅ Tests terminés")
        print("\n📋 Résumé des tables testées:")
        print("  • training_runs - Logs d'entraînement des modèles")
        print("  • feature_importance - Importance des features par modèle")
        print("  • symbol_calibration - Calibration des symboles")
        print("  • symbol_correction_patterns - Patterns de correction")
        print("  • correction_summary_stats - Statistiques des corrections")
        print("  • support_resistance_levels - Niveaux S/R (déjà utilisée)")

if __name__ == "__main__":
    tester = SupabaseTablesTester()
    tester.run_all_tests()
