"""
Interface utilisateur pour lancer le pipeline ML automatisé.
Permet de sélectionner les symboles et de lancer l'analyse complète.
"""

import sys
import os
import time
from pathlib import Path
sys.path.append(os.path.abspath('.'))

from backend.automated_ml_pipeline import AutomatedMLPipeline
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def display_menu():
    """Affiche le menu principal."""
    print("\n" + "="*60)
    print("🚀 PIPELINE ML AUTOMATISÉ - TRADING BOT")
    print("="*60)
    print("1. 🔍 Voir les symboles disponibles")
    print("2. 📊 Lancer l'analyse sur un symbole spécifique")
    print("3. 🌍 Lancer l'analyse sur tous les symboles")
    print("4. 🎯 Lancer l'analyse sur plusieurs symboles")
    print("5. 📈 Voir les paramètres de prédiction d'un symbole")
    print("6. 📁 Voir les modèles entraînés")
    print("7. 🧪 Test rapide sur 3 symboles")
    print("0. ❌ Quitter")
    print("="*60)

def get_symbols_available():
    """Affiche les symboles disponibles."""
    try:
        pipeline = AutomatedMLPipeline()
        symbols = pipeline.symbols
        
        print(f"\n📊 Symboles disponibles ({len(symbols)}):")
        print("-" * 40)
        
        # Groupement par catégorie
        categories = {}
        for symbol in symbols:
            if 'USD' in symbol or 'EUR' in symbol or 'GBP' in symbol or 'JPY' in symbol:
                cat = 'Forex'
            elif 'Index' in symbol:
                cat = 'Indices'
            elif 'XAU' in symbol:
                cat = 'Métaux'
            elif 'BTC' in symbol:
                cat = 'Crypto'
            else:
                cat = 'Autres'
            
            if cat not in categories:
                categories[cat] = []
            categories[cat].append(symbol)
        
        for cat, syms in categories.items():
            print(f"\n🔸 {cat}:")
            for i, sym in enumerate(syms):
                print(f"   {sym}", end="  ")
                if (i + 1) % 5 == 0:
                    print()
            print()
        
        return symbols
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return []

def analyze_single_symbol():
    """Analyse un symbole spécifique."""
    try:
        pipeline = AutomatedMLPipeline()
        symbols = pipeline.symbols
        
        print(f"\n🎯 Analyse d'un symbole spécifique")
        print(f"Symboles disponibles: {len(symbols)}")
        
        # Suggestion de symboles populaires
        popular_symbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD', 'BTCUSD', 'US30', 'NAS100']
        available_popular = [s for s in popular_symbols if s in symbols]
        
        print(f"\n💡 Symboles populaires: {', '.join(available_popular)}")
        
        symbol = input("\nEntrez le symbole à analyser: ").strip().upper()
        
        if symbol not in symbols:
            print(f"❌ Symbole {symbol} non trouvé")
            return
        
        print(f"\n🚀 Lancement de l'analyse pour {symbol}...")
        print("⏳ Cette opération peut prendre plusieurs minutes...")
        
        start_time = time.time()
        result = pipeline.run_complete_pipeline(symbol)
        end_time = time.time()
        
        duration = end_time - start_time
        
        if result.get('status') == 'success':
            print(f"\n✅ Analyse terminée pour {symbol} en {duration:.1f} secondes")
            print(f"📈 Modèle: {result['training_results']['best_model_info']['best_model_name']}")
            print(f"🎯 Précision: {result['training_results']['best_model_info']['best_performance']['accuracy']:.3f}")
            print(f"💾 Résultats sauvegardés dans: D:/Dev/TradBOT/data/{symbol.replace('/', '_')}")
        else:
            print(f"\n❌ Échec de l'analyse pour {symbol}: {result.get('error', 'Erreur inconnue')}")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")

def analyze_multiple_symbols():
    """Analyse plusieurs symboles."""
    try:
        pipeline = AutomatedMLPipeline()
        symbols = pipeline.symbols
        
        print(f"\n🌍 Analyse de plusieurs symboles")
        print(f"Symboles disponibles: {len(symbols)}")
        
        # Suggestion de catégories
        print("\n💡 Suggestions de catégories:")
        print("   - forex: EURUSD, GBPUSD, USDJPY, AUDUSD")
        print("   - indices: US30, NAS100, SPX500")
        print("   - crypto: BTCUSD, ETHUSD")
        print("   - metals: XAUUSD, XAGUSD")
        
        symbols_input = input("\nEntrez les symboles séparés par des virgules: ").strip()
        selected_symbols = [s.strip().upper() for s in symbols_input.split(',')]
        
        # Validation
        valid_symbols = [s for s in selected_symbols if s in symbols]
        invalid_symbols = [s for s in selected_symbols if s not in symbols]
        
        if invalid_symbols:
            print(f"⚠️ Symboles invalides ignorés: {', '.join(invalid_symbols)}")
        
        if not valid_symbols:
            print("❌ Aucun symbole valide sélectionné")
            return
        
        print(f"\n🎯 Analyse de {len(valid_symbols)} symboles: {', '.join(valid_symbols)}")
        print("⏳ Cette opération peut prendre plusieurs heures...")
        
        confirm = input("\nConfirmer le lancement? (y/N): ").strip().lower()
        if confirm != 'y':
            print("❌ Opération annulée")
            return
        
        start_time = time.time()
        results = pipeline.run_pipeline_for_all_symbols(valid_symbols)
        end_time = time.time()
        
        duration = end_time - start_time
        
        print(f"\n🎉 Pipeline terminé en {duration:.1f} secondes")
        print(f"📊 Résultats: {results['successful']}/{results['total_symbols']} succès")
        print(f"📈 Taux de succès: {results['success_rate']:.1f}%")
        
        # Détails des succès
        if results['successful'] > 0:
            print("\n✅ Symboles traités avec succès:")
            for symbol, result in results['results'].items():
                if result.get('status') == 'success':
                    accuracy = result['training_results']['best_model_info']['best_performance']['accuracy']
                    print(f"   {symbol}: {accuracy:.3f}")
        
        # Détails des échecs
        if results['failed'] > 0:
            print("\n❌ Symboles en échec:")
            for symbol, result in results['results'].items():
                if result.get('status') != 'success':
                    error = result.get('error', 'Erreur inconnue')
                    print(f"   {symbol}: {error}")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")

def analyze_all_symbols():
    """Analyse tous les symboles disponibles."""
    try:
        pipeline = AutomatedMLPipeline()
        symbols = pipeline.symbols
        
        print(f"\n🌍 Analyse de TOUS les symboles")
        print(f"Nombre total: {len(symbols)}")
        print("⚠️ ATTENTION: Cette opération peut prendre plusieurs heures!")
        
        # Estimation du temps
        estimated_hours = len(symbols) * 0.1  # ~6 minutes par symbole
        print(f"⏱️ Temps estimé: {estimated_hours:.1f} heures")
        
        confirm = input("\nÊtes-vous sûr de vouloir continuer? (y/N): ").strip().lower()
        if confirm != 'y':
            print("❌ Opération annulée")
            return
        
        print(f"\n🚀 Lancement du pipeline complet...")
        print("💡 Vous pouvez surveiller la progression dans les logs")
        
        start_time = time.time()
        results = pipeline.run_pipeline_for_all_symbols()
        end_time = time.time()
        
        duration = end_time - start_time
        
        print(f"\n🎉 Pipeline complet terminé en {duration:.1f} secondes")
        print(f"📊 Résultats: {results['successful']}/{results['total_symbols']} succès")
        print(f"📈 Taux de succès: {results['success_rate']:.1f}%")
        
        # Sauvegarde du résumé
        summary_path = Path("D:/Dev/TradBOT/data/global_pipeline_summary.json")
        if summary_path.exists():
            print(f"📁 Résumé global sauvegardé: {summary_path}")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")

def show_prediction_parameters():
    """Affiche les paramètres de prédiction d'un symbole."""
    try:
        pipeline = AutomatedMLPipeline()
        
        symbol = input("\n🎯 Entrez le symbole pour voir les paramètres: ").strip().upper()
        
        print(f"\n📊 Chargement des paramètres pour {symbol}...")
        params = pipeline.get_prediction_parameters(symbol)
        
        if 'error' in params:
            print(f"❌ {params['error']}")
            return
        
        print(f"\n✅ Modèle chargé: {params['model_name']}")
        print(f"📈 Précision: {params['accuracy']:.3f}")
        print(f"🔧 Transformations: {len(params['transformations']['feature_names'])} features")
        
        print(f"\n⚙️ Paramètres de trading:")
        for signal_type, signal_params in params['parameters'].items():
            print(f"\n🔸 {signal_type}:")
            print(f"   Stop Loss: {signal_params['stop_loss_pct']:+.1f}%")
            print(f"   Take Profit: {signal_params['take_profit_pct']:+.1f}%")
            print(f"   Durée du signal: {signal_params['signal_duration_hours']} heures")
            print(f"   Seuil de confiance: {signal_params['confidence_threshold']:.1f}")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")

def show_trained_models():
    """Affiche les modèles entraînés."""
    try:
        data_dir = Path("D:/Dev/TradBOT/data")
        
        if not data_dir.exists():
            print("❌ Aucun dossier de données trouvé")
            return
        
        print(f"\n📁 Modèles entraînés dans {data_dir}")
        print("-" * 50)
        
        symbol_dirs = [d for d in data_dir.iterdir() if d.is_dir()]
        
        if not symbol_dirs:
            print("❌ Aucun modèle entraîné trouvé")
            return
        
        for symbol_dir in symbol_dirs:
            symbol_name = symbol_dir.name
            metadata_path = symbol_dir / "metadata.json"
            
            if metadata_path.exists():
                try:
                    import json
                    with open(metadata_path, 'r') as f:
                        metadata = json.load(f)
                    
                    print(f"\n🔸 {symbol_name}:")
                    print(f"   📅 Entraîné le: {metadata.get('training_date', 'N/A')}")
                    print(f"   🏆 Meilleur modèle: {metadata.get('best_model', 'N/A')}")
                    print(f"   📊 Modèles: {', '.join(metadata.get('models_trained', []))}")
                    
                except Exception as e:
                    print(f"   ❌ Erreur lecture métadonnées: {e}")
            else:
                print(f"\n🔸 {symbol_name}: Métadonnées non trouvées")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")

def quick_test():
    """Test rapide sur 3 symboles."""
    try:
        print("\n🧪 Test rapide sur 3 symboles")
        print("=" * 40)
        
        from test_automated_pipeline import test_pipeline
        results = test_pipeline()
        
        if results:
            print(f"\n✅ Test terminé: {results['successful']}/{results['total_symbols']} succès")
        else:
            print("\n❌ Test échoué")
        
    except Exception as e:
        print(f"❌ Erreur lors du test: {e}")

def main():
    """Fonction principale."""
    print("🚀 Bienvenue dans le Pipeline ML Automatisé!")
    print("Ce système va analyser vos données et entraîner des modèles de prédiction.")
    
    while True:
        try:
            display_menu()
            choice = input("\nVotre choix (0-7): ").strip()
            
            if choice == '0':
                print("\n👋 Au revoir!")
                break
            elif choice == '1':
                get_symbols_available()
            elif choice == '2':
                analyze_single_symbol()
            elif choice == '3':
                analyze_all_symbols()
            elif choice == '4':
                analyze_multiple_symbols()
            elif choice == '5':
                show_prediction_parameters()
            elif choice == '6':
                show_trained_models()
            elif choice == '7':
                quick_test()
            else:
                print("❌ Choix invalide")
            
            input("\nAppuyez sur Entrée pour continuer...")
            
        except KeyboardInterrupt:
            print("\n\n👋 Interruption utilisateur. Au revoir!")
            break
        except Exception as e:
            print(f"\n❌ Erreur inattendue: {e}")
            input("Appuyez sur Entrée pour continuer...")

if __name__ == "__main__":
    main()
