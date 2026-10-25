"""
Test des symboles étendus du pipeline ML.
"""

import sys
import os
sys.path.append(os.path.abspath('.'))

try:
    from backend.automated_ml_pipeline_simple import AutomatedMLPipeline
    print("✅ Import réussi du pipeline ML")
    
    # Initialisation du pipeline
    pipeline = AutomatedMLPipeline()
    print(f"📊 Pipeline initialisé avec {len(pipeline.symbols)} symboles")
    
    # Affichage des symboles par catégorie
    print("\n🔍 Symboles disponibles par catégorie :")
    print("=" * 60)
    
    # Catégorisation des symboles
    categories = {
        'Forex': [],
        'Indices': [],
        'Crypto': [],
        'Métaux': [],
        'Commodités': [],
        'Actions': [],
        'Synthétiques': [],
        'Autres': []
    }
    
    for symbol in pipeline.symbols:
        if any(currency in symbol for currency in ['USD', 'EUR', 'GBP', 'JPY', 'CHF', 'AUD', 'NZD', 'CAD']):
            if len(symbol) == 6:  # Format standard forex
                categories['Forex'].append(symbol)
            else:
                categories['Autres'].append(symbol)
        elif any(idx in symbol for idx in ['US30', 'NAS100', 'SPX500', 'NDX100', 'DJI', 'SPY', 'QQQ', 'GER30', 'FRA40', 'ITA40', 'ESP35', 'NLD25', 'SWE30', 'JPN225', 'AUS200', 'CAN60', 'BRA50', 'MEX35', 'IND50']):
            categories['Indices'].append(symbol)
        elif any(crypto in symbol for crypto in ['BTC', 'ETH', 'LTC', 'XRP', 'ADA', 'DOT', 'LINK', 'BCH', 'XLM', 'EOS', 'TRX', 'VET', 'MATIC', 'SOL', 'AVAX', 'ATOM', 'NEAR', 'FTM']):
            categories['Crypto'].append(symbol)
        elif any(metal in symbol for metal in ['XAU', 'XAG', 'XPT', 'XPD']):
            categories['Métaux'].append(symbol)
        elif any(commodity in symbol for commodity in ['WTI', 'BRENT', 'NATGAS', 'HEATOIL', 'CORN', 'WHEAT', 'SOYBEAN', 'SUGAR', 'COFFEE', 'COCOA', 'COTTON', 'LUMBER']):
            categories['Commodités'].append(symbol)
        elif any(stock in symbol for stock in ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA', 'META', 'NVDA', 'NFLX', 'ADBE', 'CRM', 'PYPL', 'INTC', 'AMD', 'ORCL']):
            categories['Actions'].append(symbol)
        elif 'Boom' in symbol or 'Crash' in symbol:
            categories['Synthétiques'].append(symbol)
        else:
            categories['Autres'].append(symbol)
    
    # Affichage des résultats
    total_symbols = 0
    for category, symbols in categories.items():
        if symbols:
            print(f"\n🔸 {category} ({len(symbols)} symboles):")
            # Affichage par groupes de 5
            for i in range(0, len(symbols), 5):
                group = symbols[i:i+5]
                print(f"   {', '.join(group)}")
            total_symbols += len(symbols)
    
    print(f"\n📊 Total des symboles catégorisés : {total_symbols}")
    print(f"📊 Total des symboles dans le pipeline : {len(pipeline.symbols)}")
    
    # Test de récupération des paramètres pour un symbole
    print("\n🧪 Test de récupération des paramètres :")
    test_symbol = 'EURUSD'
    if test_symbol in pipeline.symbols:
        print(f"✅ {test_symbol} trouvé dans la liste")
        
        # Test d'initialisation du pipeline (sans lancer l'analyse complète)
        try:
            # Test de création de données simulées
            df = pipeline.download_data_for_symbol(test_symbol, count=100)
            print(f"✅ Données simulées créées : {df.shape}")
            
            # Test de l'EDA
            eda_results = pipeline.perform_eda(df, test_symbol)
            print(f"✅ EDA terminé : {len(eda_results['recommendations'])} recommandations")
            
            print("🎉 Pipeline ML fonctionne correctement !")
            
        except Exception as e:
            print(f"❌ Erreur lors du test : {e}")
    else:
        print(f"❌ {test_symbol} non trouvé dans la liste")
    
except ImportError as e:
    print(f"❌ Erreur d'import : {e}")
except Exception as e:
    print(f"❌ Erreur générale : {e}")

print("\n🏁 Test terminé")
