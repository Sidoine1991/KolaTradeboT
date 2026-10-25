"""
Onglet Streamlit pour le Pipeline ML Automatisé.
Intégré dans l'interface principale du trading bot.
"""

import sys
import os
import time
import streamlit as st
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
from pathlib import Path
import json
import joblib
from datetime import datetime
import numpy as np

# Ajout du répertoire racine au path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Custom imports
try:
    from backend.automated_ml_pipeline_simple import AutomatedMLPipeline
    ML_PIPELINE_AVAILABLE = True
except ImportError:
    ML_PIPELINE_AVAILABLE = False
    st.warning("⚠️ Module ML Pipeline non disponible. Vérifiez l'installation.")

def render_ml_pipeline_tab():
    """Rendu de l'onglet Pipeline ML."""
    
    st.header("🚀 Pipeline ML Automatisé")
    st.markdown("""
    Ce système analyse automatiquement vos données de trading et entraîne des modèles de prédiction 
    pour générer des signaux Strong Buy/Sell avec paramètres SL/TP optimaux.
    """)
    
    if not ML_PIPELINE_AVAILABLE:
        st.error("❌ Module ML Pipeline non disponible")
        st.info("💡 Installez les dépendances : `pip install scikit-learn pandas numpy ta`")
        return
    
    # Sidebar pour la configuration
    with st.sidebar:
        st.subheader("⚙️ Configuration")
        
        # Sélection du mode
        mode = st.selectbox(
            "Mode d'analyse",
            ["Test Rapide", "Symbole Unique", "Multiples Symboles", "Tous les Symboles"],
            help="Choisissez le mode d'analyse"
        )
        
        # Paramètres avancés
        with st.expander("🔧 Paramètres Avancés"):
            data_points = st.slider("Nombre de bougies", 1000, 10000, 3000, 500)
            timeframe = st.selectbox("Timeframe", ["1m", "5m", "15m", "30m", "1h", "4h", "1d"], index=4)
            confidence_threshold = st.slider("Seuil de confiance", 0.5, 0.95, 0.7, 0.05)
            
            # Options d'optimisation
            use_feature_selection = st.checkbox("Sélection automatique des features", True)
            use_cross_validation = st.checkbox("Validation croisée", True)
            cv_folds = st.slider("Folds CV", 3, 10, 5, 1) if use_cross_validation else 5
    
    # Contenu principal
    if mode == "Test Rapide":
        render_quick_test_section()
    elif mode == "Symbole Unique":
        render_single_symbol_section()
    elif mode == "Multiples Symboles":
        render_multiple_symbols_section()
    elif mode == "Tous les Symboles":
        render_all_symbols_section()
    
    # Section des modèles entraînés
    render_trained_models_section()
    
    # Section des performances
    render_performance_section()

def render_quick_test_section():
    """Section de test rapide sur 3 symboles."""
    st.subheader("🧪 Test Rapide sur 3 Symboles")
    
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.info("""
        **Test rapide recommandé pour débuter :**
        - Analyse de EURUSD, GBPUSD, USDJPY
        - Temps estimé : 15-30 minutes
        - Validation du système complet
        """)
    
    with col2:
        if st.button("🚀 Lancer le Test Rapide", type="primary", use_container_width=True):
            run_quick_test()

def render_single_symbol_section():
    """Section d'analyse d'un symbole unique."""
    st.subheader("🎯 Analyse d'un Symbole Spécifique")
    
    # Initialisation du pipeline
    try:
        pipeline = AutomatedMLPipeline()
        symbols = pipeline.symbols
        
        col1, col2 = st.columns([2, 1])
        
        with col1:
            # Sélection du symbole
            symbol = st.selectbox(
                "Sélectionnez le symbole",
                symbols,
                index=symbols.index('EURUSD') if 'EURUSD' in symbols else 0,
                help="Choisissez le symbole à analyser"
            )
            
            # Informations sur le symbole
            if symbol:
                st.info(f"**Symbole sélectionné :** {symbol}")
                st.info(f"**Symboles disponibles :** {len(symbols)}")
        
        with col2:
            # Bouton de lancement
            if st.button("📊 Analyser le Symbole", type="primary", use_container_width=True):
                run_single_symbol_analysis(symbol, pipeline)
    
    except Exception as e:
        st.error(f"❌ Erreur d'initialisation : {e}")

def render_multiple_symbols_section():
    """Section d'analyse de plusieurs symboles."""
    st.subheader("🌍 Analyse de Plusieurs Symboles")
    
    try:
        pipeline = AutomatedMLPipeline()
        symbols = pipeline.symbols
        
        # Suggestions de catégories
        st.info("💡 **Suggestions de catégories :**")
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.write("**Forex :**")
            forex_symbols = [s for s in symbols if any(currency in s for currency in ['USD', 'EUR', 'GBP', 'JPY'])]
            for sym in forex_symbols[:5]:
                st.write(f"• {sym}")
        
        with col2:
            st.write("**Indices :**")
            index_symbols = [s for s in symbols if 'Index' in s or any(idx in s for idx in ['US30', 'NAS100', 'SPX500'])]
            for sym in index_symbols[:5]:
                st.write(f"• {sym}")
        
        with col3:
            st.write("**Crypto/Métaux :**")
            crypto_metal_symbols = [s for s in symbols if any(asset in s for asset in ['BTC', 'XAU', 'XAG'])]
            for sym in crypto_metal_symbols[:5]:
                st.write(f"• {sym}")
        
        # Sélection des symboles
        selected_symbols = st.multiselect(
            "Sélectionnez les symboles à analyser",
            symbols,
            default=['EURUSD', 'GBPUSD', 'USDJPY'] if all(s in symbols for s in ['EURUSD', 'GBPUSD', 'USDJPY']) else [],
            help="Sélectionnez plusieurs symboles pour l'analyse"
        )
        
        if selected_symbols:
            st.info(f"**Symboles sélectionnés :** {len(selected_symbols)}")
            st.write(f"**Liste :** {', '.join(selected_symbols)}")
            
            # Estimation du temps
            estimated_minutes = len(selected_symbols) * 6
            st.warning(f"⏱️ **Temps estimé :** {estimated_minutes} minutes ({estimated_minutes/60:.1f} heures)")
            
            # Bouton de lancement
            if st.button("🚀 Lancer l'Analyse Multiple", type="primary", use_container_width=True):
                run_multiple_symbols_analysis(selected_symbols, pipeline)
    
    except Exception as e:
        st.error(f"❌ Erreur : {e}")

def render_all_symbols_section():
    """Section d'analyse de tous les symboles."""
    st.subheader("🌍 Analyse de TOUS les Symboles")
    
    try:
        pipeline = AutomatedMLPipeline()
        symbols = pipeline.symbols
        
        st.warning("⚠️ **ATTENTION :** Cette opération peut prendre plusieurs heures !")
        
        # Statistiques
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric("Total Symboles", len(symbols))
        
        with col2:
            estimated_hours = len(symbols) * 0.1
            st.metric("Temps Estimé", f"{estimated_hours:.1f}h")
        
        with col3:
            st.metric("Mémoire Estimée", f"{len(symbols) * 0.5:.1f}GB")
        
        # Répartition par catégorie
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
                categories[cat] = 0
            categories[cat] += 1
        
        # Graphique de répartition
        fig = px.pie(
            values=list(categories.values()),
            names=list(categories.keys()),
            title="Répartition des Symboles par Catégorie"
        )
        st.plotly_chart(fig, use_container_width=True)
        
        # Confirmation
        if st.button("🚀 Lancer l'Analyse Complète", type="primary", use_container_width=True):
            confirm = st.checkbox("✅ Je confirme vouloir analyser TOUS les symboles")
            if confirm:
                run_all_symbols_analysis(pipeline)
    
    except Exception as e:
        st.error(f"❌ Erreur : {e}")

def render_trained_models_section():
    """Section d'affichage des modèles entraînés."""
    st.subheader("📁 Modèles Entraînés")
    
    try:
        data_dir = Path("D:/Dev/TradBOT/data")
        
        if not data_dir.exists():
            st.info("📁 Aucun dossier de données trouvé")
            return
        
        symbol_dirs = [d for d in data_dir.iterdir() if d.is_dir()]
        
        if not symbol_dirs:
            st.info("📁 Aucun modèle entraîné trouvé")
            return
        
        # Affichage des modèles
        for symbol_dir in symbol_dirs:
            symbol_name = symbol_dir.name
            metadata_path = symbol_dir / "metadata.json"
            
            with st.expander(f"🔸 {symbol_name}"):
                if metadata_path.exists():
                    try:
                        with open(metadata_path, 'r') as f:
                            metadata = json.load(f)
                        
                        col1, col2 = st.columns(2)
                        
                        with col1:
                            st.write(f"**📅 Entraîné le :** {metadata.get('training_date', 'N/A')}")
                            st.write(f"**🏆 Meilleur modèle :** {metadata.get('best_model', 'N/A')}")
                        
                        with col2:
                            st.write(f"**📊 Modèles :** {', '.join(metadata.get('models_trained', []))}")
                            
                            # Bouton pour voir les paramètres
                            if st.button(f"📈 Voir Paramètres {symbol_name}", key=f"params_{symbol_name}"):
                                show_symbol_parameters(symbol_name)
                    
                    except Exception as e:
                        st.error(f"❌ Erreur lecture métadonnées : {e}")
                else:
                    st.write("Métadonnées non trouvées")
    
    except Exception as e:
        st.error(f"❌ Erreur : {e}")

def render_performance_section():
    """Section d'affichage des performances."""
    st.subheader("📊 Performances et Statistiques")
    
    try:
        data_dir = Path("D:/Dev/TradBOT/data")
        global_summary_path = data_dir / "global_pipeline_summary.json"
        
        if global_summary_path.exists():
            with open(global_summary_path, 'r') as f:
                summary = json.load(f)
            
            # Métriques globales
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                st.metric("Total Symboles", summary.get('total_symbols', 0))
            
            with col2:
                st.metric("Succès", summary.get('successful', 0))
            
            with col3:
                st.metric("Échecs", summary.get('failed', 0))
            
            with col4:
                success_rate = summary.get('success_rate', 0)
                st.metric("Taux de Succès", f"{success_rate:.1f}%")
            
            # Graphique des performances par symbole
            if 'results' in summary:
                performance_data = []
                for symbol, result in summary['results'].items():
                    if result.get('status') == 'success':
                        try:
                            accuracy = result['training_results']['best_model_info']['best_performance']['accuracy']
                            performance_data.append({
                                'Symbol': symbol,
                                'Accuracy': accuracy,
                                'Model': result['training_results']['best_model_info']['best_model_name']
                            })
                        except:
                            pass
                
                if performance_data:
                    df_perf = pd.DataFrame(performance_data)
                    
                    # Graphique des précisions
                    fig = px.bar(
                        df_perf,
                        x='Symbol',
                        y='Accuracy',
                        color='Model',
                        title="Précision des Modèles par Symbole",
                        labels={'Accuracy': 'Précision', 'Symbol': 'Symbole', 'Model': 'Modèle'}
                    )
                    fig.update_layout(xaxis_tickangle=-45)
                    st.plotly_chart(fig, use_container_width=True)
                    
                    # Tableau des performances
                    st.dataframe(df_perf.sort_values('Accuracy', ascending=False), use_container_width=True)
        
        else:
            st.info("📊 Aucun résumé global trouvé")
    
    except Exception as e:
        st.error(f"❌ Erreur : {e}")

def run_quick_test():
    """Lance le test rapide sur 3 symboles."""
    try:
        with st.spinner("🧪 Lancement du test rapide..."):
            pipeline = AutomatedMLPipeline()
            test_symbols = ['EURUSD', 'GBPUSD', 'USDJPY']
            
            # Vérification de la disponibilité des symboles
            available_symbols = [s for s in test_symbols if s in pipeline.symbols]
            
            if len(available_symbols) < 3:
                st.warning(f"⚠️ Seulement {len(available_symbols)} symboles disponibles pour le test")
            
            if available_symbols:
                results = pipeline.run_pipeline_for_all_symbols(available_symbols)
                
                # Affichage des résultats
                st.success(f"✅ Test terminé : {results['successful']}/{results['total_symbols']} succès")
                
                # Détails par symbole
                for symbol, result in results['results'].items():
                    if result.get('status') == 'success':
                        accuracy = result['training_results']['best_model_info']['best_performance']['accuracy']
                        st.info(f"📈 {symbol} : {accuracy:.3f}")
                    else:
                        st.error(f"❌ {symbol} : {result.get('error', 'Erreur inconnue')}")
                
                # Sauvegarde des résultats
                st.info("💾 Résultats sauvegardés dans le dossier data/")
    
    except Exception as e:
        st.error(f"❌ Erreur lors du test : {e}")

def run_single_symbol_analysis(symbol, pipeline):
    """Lance l'analyse d'un symbole unique."""
    try:
        with st.spinner(f"📊 Analyse de {symbol} en cours..."):
            start_time = time.time()
            result = pipeline.run_complete_pipeline(symbol)
            end_time = time.time()
            
            duration = end_time - start_time
            
            if result.get('status') == 'success':
                st.success(f"✅ Analyse terminée pour {symbol} en {duration:.1f} secondes")
                
                # Affichage des résultats
                col1, col2 = st.columns(2)
                
                with col1:
                    model_name = result['training_results']['best_model_info']['best_model_name']
                    accuracy = result['training_results']['best_model_info']['best_performance']['accuracy']
                    st.metric("Modèle", model_name)
                    st.metric("Précision", f"{accuracy:.3f}")
                
                with col2:
                    feature_count = result['training_results']['data_info']['feature_count']
                    train_size = result['training_results']['data_info']['train_size']
                    st.metric("Features", feature_count)
                    st.metric("Données d'entraînement", train_size)
                
                # Informations sur la sauvegarde
                st.info(f"💾 Résultats sauvegardés dans : D:/Dev/TradBOT/data/{symbol.replace('/', '_')}")
                
                # Bouton pour voir les paramètres
                if st.button(f"⚙️ Voir Paramètres {symbol}"):
                    show_symbol_parameters(symbol)
            
            else:
                st.error(f"❌ Échec de l'analyse pour {symbol} : {result.get('error', 'Erreur inconnue')}")
    
    except Exception as e:
        st.error(f"❌ Erreur : {e}")

def run_multiple_symbols_analysis(symbols, pipeline):
    """Lance l'analyse de plusieurs symboles."""
    try:
        with st.spinner(f"🌍 Analyse de {len(symbols)} symboles en cours..."):
            start_time = time.time()
            results = pipeline.run_pipeline_for_all_symbols(symbols)
            end_time = time.time()
            
            duration = end_time - start_time
            
            st.success(f"🎉 Pipeline terminé en {duration:.1f} secondes")
            
            # Résumé des résultats
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.metric("Total", results['total_symbols'])
            
            with col2:
                st.metric("Succès", results['successful'])
            
            with col3:
                st.metric("Taux", f"{results['success_rate']:.1f}%")
            
            # Détails des succès
            if results['successful'] > 0:
                st.subheader("✅ Symboles traités avec succès")
                success_data = []
                
                for symbol, result in results['results'].items():
                    if result.get('status') == 'success':
                        accuracy = result['training_results']['best_model_info']['best_performance']['accuracy']
                        model_name = result['training_results']['best_model_info']['best_model_name']
                        success_data.append({
                            'Symbole': symbol,
                            'Précision': accuracy,
                            'Modèle': model_name
                        })
                
                if success_data:
                    df_success = pd.DataFrame(success_data)
                    st.dataframe(df_success, use_container_width=True)
            
            # Détails des échecs
            if results['failed'] > 0:
                st.subheader("❌ Symboles en échec")
                for symbol, result in results['results'].items():
                    if result.get('status') != 'success':
                        error = result.get('error', 'Erreur inconnue')
                        st.error(f"**{symbol}** : {error}")
    
    except Exception as e:
        st.error(f"❌ Erreur : {e}")

def run_all_symbols_analysis(pipeline):
    """Lance l'analyse de tous les symboles."""
    try:
        with st.spinner("🌍 Lancement de l'analyse complète..."):
            st.info("💡 Vous pouvez surveiller la progression dans les logs")
            
            start_time = time.time()
            results = pipeline.run_pipeline_for_all_symbols()
            end_time = time.time()
            
            duration = end_time - start_time
            
            st.success(f"🎉 Pipeline complet terminé en {duration:.1f} secondes")
            
            # Résumé global
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.metric("Total", results['total_symbols'])
            
            with col2:
                st.metric("Succès", results['successful'])
            
            with col3:
                st.metric("Taux", f"{results['success_rate']:.1f}%")
            
            # Sauvegarde du résumé
            summary_path = Path("D:/Dev/TradBOT/data/global_pipeline_summary.json")
            if summary_path.exists():
                st.info(f"📁 Résumé global sauvegardé : {summary_path}")
    
    except Exception as e:
        st.error(f"❌ Erreur : {e}")

def show_symbol_parameters(symbol):
    """Affiche les paramètres de prédiction d'un symbole."""
    try:
        pipeline = AutomatedMLPipeline()
        
        with st.spinner(f"📊 Chargement des paramètres pour {symbol}..."):
            params = pipeline.get_prediction_parameters(symbol)
            
            if 'error' in params:
                st.error(f"❌ {params['error']}")
                return
            
            # Affichage des informations du modèle
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.metric("Modèle", params['model_name'])
            
            with col2:
                st.metric("Précision", f"{params['accuracy']:.3f}")
            
            with col3:
                st.metric("Features", len(params['transformations']['feature_names']))
            
            # Paramètres de trading
            st.subheader("⚙️ Paramètres de Trading")
            
            for signal_type, signal_params in params['parameters'].items():
                with st.expander(f"🔸 {signal_type}"):
                    col1, col2, col3, col4 = st.columns(4)
                    
                    with col1:
                        st.metric("Stop Loss", f"{signal_params['stop_loss_pct']:+.1f}%")
                    
                    with col2:
                        st.metric("Take Profit", f"{signal_params['take_profit_pct']:+.1f}%")
                    
                    with col3:
                        st.metric("Durée", f"{signal_params['signal_duration_hours']}h")
                    
                    with col4:
                        st.metric("Confiance", f"{signal_params['confidence_threshold']:.1f}")
    
    except Exception as e:
        st.error(f"❌ Erreur : {e}")

# Fonction principale pour l'onglet
def main():
    """Fonction principale de l'onglet ML Pipeline."""
    st.set_page_config(
        page_title="ML Pipeline - Trading Bot",
        page_icon="🚀",
        layout="wide"
    )
    
    # Styles CSS personnalisés
    st.markdown("""
        <style>
        .main-header { font-size: 2.5rem; color: #2563eb; font-weight: 700; margin-bottom: 1rem; }
        .metric-card { background: #1e293b; border-radius: 0.5rem; padding: 1rem; margin-bottom: 1rem; border-left: 4px solid #2563eb; }
        .stButton>button { width: 100%; border-radius: 0.5rem; font-weight: 600; }
        </style>
    """, unsafe_allow_html=True)
    
    render_ml_pipeline_tab()

if __name__ == "__main__":
    main()
