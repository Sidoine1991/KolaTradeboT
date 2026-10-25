"""
Script de test pour le système de performance MT5 avec données réelles
====================================================================

Ce script simule les données réelles d'un compte MT5 connecté
et teste le système de calcul de performance intégré.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import matplotlib.pyplot as plt

def simulate_mt5_account_data(days=30, initial_capital=1000.0):
    """
    Simule les données réelles d'un compte MT5.
    
    Args:
        days: Nombre de jours de données à générer
        initial_capital: Capital initial du compte
        
    Returns:
        DataFrame avec les données du compte MT5
    """
    np.random.seed(42)  # Pour la reproductibilité
    
    data = []
    current_equity = initial_capital
    current_balance = initial_capital
    
    # Informations du compte MT5 simulées
    account_number = 12345678
    account_server = "MetaQuotes-Demo"
    account_name = "Demo Account"
    account_currency = 0  # USD
    
    for i in range(days):
        date = datetime.now() - timedelta(days=days-i-1)
        
        # Simulation de trading journalier réaliste
        num_trades = np.random.poisson(2.5)  # Nombre moyen de trades par jour
        
        winning_trades = 0
        losing_trades = 0
        daily_profit = 0.0
        daily_loss = 0.0
        daily_commission = 0.0
        daily_swap = 0.0
        
        # Simuler les trades du jour
        for _ in range(num_trades):
            # Probabilité de gain basée sur la performance récente
            win_probability = 0.55 + (current_equity - initial_capital) / initial_capital * 0.05
            win_probability = max(0.35, min(0.75, win_probability))
            
            # Taille du trade (lot)
            lot_size = np.random.uniform(0.01, 0.1)
            
            if np.random.random() < win_probability:
                # Trade gagnant
                profit = np.random.exponential(12) * lot_size
                commission = lot_size * 0.5  # Commission par lot
                swap = np.random.normal(0, 0.1) * lot_size
                
                winning_trades += 1
                daily_profit += profit
                daily_commission += commission
                daily_swap += swap
                
                current_equity += profit - commission + swap
            else:
                # Trade perdant
                loss = np.random.exponential(8) * lot_size
                commission = lot_size * 0.5
                swap = np.random.normal(0, 0.1) * lot_size
                
                losing_trades += 1
                daily_loss += loss
                daily_commission += commission
                daily_swap += swap
                
                current_equity -= loss + commission - swap
        
        # Mettre à jour le balance (équité fermée)
        if daily_profit > daily_loss:
            current_balance += daily_profit - daily_loss
        
        # Ajouter une petite variation aléatoire
        current_equity += np.random.normal(0, 2)
        current_equity = max(current_equity, initial_capital * 0.1)
        
        # Calculer les métriques du compte MT5
        margin = current_equity * np.random.uniform(0.1, 0.3)  # 10-30% de marge
        free_margin = current_equity - margin
        margin_level = (current_equity / margin) * 100 if margin > 0 else 0
        
        # Profit net incluant commission et swap
        net_profit = daily_profit - daily_loss - daily_commission + daily_swap
        
        data.append({
            'AccountNumber': account_number,
            'AccountServer': account_server,
            'AccountName': account_name,
            'Currency': account_currency,
            'Date': date.strftime('%Y-%m-%d'),
            'Equity': round(current_equity, 2),
            'Balance': round(current_balance, 2),
            'Margin': round(margin, 2),
            'FreeMargin': round(free_margin, 2),
            'MarginLevel': round(margin_level, 2),
            'WinningTrades': winning_trades,
            'LosingTrades': losing_trades,
            'DailyProfit': round(daily_profit, 2),
            'DailyLoss': round(daily_loss, 2),
            'NetProfit': round(net_profit, 2),
            'Commission': round(daily_commission, 2),
            'Swap': round(daily_swap, 2)
        })
    
    return pd.DataFrame(data)

def calculate_performance_metrics_mt5(df, initial_capital):
    """
    Calcule les métriques de performance pour les données MT5.
    
    Args:
        df: DataFrame avec les données du compte MT5
        initial_capital: Capital initial
        
    Returns:
        DataFrame avec les métriques calculées
    """
    df = df.copy()
    
    # Calculer les métriques de performance
    df['ROE'] = (df['Equity'] - initial_capital) / initial_capital
    df['WinRate'] = df['WinningTrades'] / (df['WinningTrades'] + df['LosingTrades'])
    df['WinRate'] = df['WinRate'].fillna(0)
    
    # Profit Factor
    df['ProfitFactor'] = 0.0
    mask = df['DailyLoss'] > 0
    df.loc[mask, 'ProfitFactor'] = df.loc[mask, 'DailyProfit'] / df.loc[mask, 'DailyLoss']
    df.loc[~mask & (df['DailyProfit'] > 0), 'ProfitFactor'] = df.loc[~mask & (df['DailyProfit'] > 0), 'DailyProfit']
    
    # Score de performance synthétique
    df['PF_Normalized'] = df['ProfitFactor'] / (1 + df['ProfitFactor'])
    df['PerformanceScore'] = 100 * (0.4 * df['ROE'] + 0.3 * df['WinRate'] + 0.3 * df['PF_Normalized'])
    df['PerformanceScore'] = df['PerformanceScore'].round(2)
    
    # Métriques supplémentaires MT5
    df['Drawdown'] = ((df['Balance'] - df['Equity']) / df['Balance']) * 100
    df['MarginUtilization'] = (df['Margin'] / df['Equity']) * 100
    df['ProfitPerTrade'] = df['NetProfit'] / (df['WinningTrades'] + df['LosingTrades'])
    df['ProfitPerTrade'] = df['ProfitPerTrade'].fillna(0)
    
    return df

def analyze_mt5_performance(df):
    """
    Analyse la performance du compte MT5.
    
    Args:
        df: DataFrame avec les métriques de performance
        
    Returns:
        Dict avec l'analyse de performance
    """
    if len(df) < 7:
        return {"status": "Données insuffisantes", "trend": "Inconnu"}
    
    # Moyennes sur 7 jours
    recent_7d = df['PerformanceScore'].tail(7).mean()
    recent_14d = df['PerformanceScore'].tail(14).mean() if len(df) >= 14 else recent_7d
    
    # Calculer la tendance
    if len(df) >= 14:
        older_7d = df['PerformanceScore'].iloc[-14:-7].mean()
        diff = recent_7d - older_7d
        
        if diff > 2:
            trend = "[+] Amélioration significative"
        elif diff > 0.5:
            trend = "[+] Amélioration légère"
        elif diff < -2:
            trend = "[-] Dégradation significative"
        elif diff < -0.5:
            trend = "[-] Dégradation légère"
        else:
            trend = "[=] Stable"
    else:
        trend = "[?] Évaluation en cours"
    
    # Statut général
    if recent_7d > 60:
        status = "[EXCELLENT] Excellent"
    elif recent_7d > 40:
        status = "[CORRECT] Correct"
    else:
        status = "[FAIBLE] À améliorer"
    
    # Métriques du compte MT5
    current_equity = df['Equity'].iloc[-1]
    current_balance = df['Balance'].iloc[-1]
    current_drawdown = df['Drawdown'].iloc[-1]
    current_margin_level = df['MarginLevel'].iloc[-1]
    
    return {
        "status": status,
        "trend": trend,
        "current_score": recent_7d,
        "improvement": recent_7d - recent_14d if len(df) >= 14 else 0,
        "current_equity": current_equity,
        "current_balance": current_balance,
        "current_drawdown": current_drawdown,
        "current_margin_level": current_margin_level
    }

def create_mt5_dashboard(df):
    """
    Crée un tableau de bord pour le compte MT5.
    
    Args:
        df: DataFrame avec les métriques de performance
    """
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle('Tableau de Bord Performance - Compte MT5', fontsize=16, fontweight='bold')
    
    # Conversion des dates
    df['date_dt'] = pd.to_datetime(df['Date'])
    
    # 1. Évolution du score de performance
    ax1.plot(df['date_dt'], df['PerformanceScore'], 'b-', linewidth=2, marker='o', markersize=4)
    ax1.axhline(y=50, color='r', linestyle='--', alpha=0.7, label='Seuil de performance')
    ax1.set_title('Évolution du Score de Performance')
    ax1.set_ylabel('Score (0-100)')
    ax1.grid(True, alpha=0.3)
    ax1.legend()
    ax1.tick_params(axis='x', rotation=45)
    
    # 2. Évolution de l'équité et du balance
    ax2.plot(df['date_dt'], df['Equity'], 'g-', linewidth=2, label='Équité', marker='s', markersize=4)
    ax2.plot(df['date_dt'], df['Balance'], 'b-', linewidth=2, label='Balance', marker='o', markersize=4)
    ax2.set_title('Évolution du Capital')
    ax2.set_ylabel('Capital ($)')
    ax2.grid(True, alpha=0.3)
    ax2.legend()
    ax2.tick_params(axis='x', rotation=45)
    
    # 3. Drawdown et utilisation de marge
    ax3.plot(df['date_dt'], df['Drawdown'], 'r-', linewidth=2, label='Drawdown (%)', marker='^', markersize=4)
    ax3.plot(df['date_dt'], df['MarginUtilization'], 'orange', linewidth=2, label='Utilisation Marge (%)', marker='s', markersize=4)
    ax3.set_title('Gestion des Risques')
    ax3.set_ylabel('Pourcentage (%)')
    ax3.grid(True, alpha=0.3)
    ax3.legend()
    ax3.tick_params(axis='x', rotation=45)
    
    # 4. Profit par trade
    ax4.bar(df['date_dt'], df['ProfitPerTrade'], alpha=0.7, color='purple', edgecolor='black')
    ax4.axhline(y=0, color='r', linestyle='-', alpha=0.7)
    ax4.set_title('Profit par Trade')
    ax4.set_ylabel('Profit ($)')
    ax4.grid(True, alpha=0.3)
    ax4.tick_params(axis='x', rotation=45)
    
    plt.tight_layout()
    plt.show()

def generate_mt5_csv(df, filename="mt5_performance_real.csv"):
    """
    Génère un fichier CSV avec les données de performance MT5.
    
    Args:
        df: DataFrame avec les données de performance
        filename: Nom du fichier de sortie
    """
    df.to_csv(filename, index=False)
    print(f"✅ Données de performance MT5 générées: {filename}")
    return filename

def main():
    """
    Fonction principale pour tester le système de performance MT5.
    """
    print("=== Test du Système de Performance MT5 avec Données Réelles ===\n")
    
    # Paramètres de test
    initial_capital = 1000.0
    days = 30
    
    print(f"Génération de {days} jours de données de compte MT5...")
    print(f"Capital initial: ${initial_capital}")
    
    # Générer les données du compte MT5
    df = simulate_mt5_account_data(days, initial_capital)
    
    # Calculer les métriques de performance
    df = calculate_performance_metrics_mt5(df, initial_capital)
    
    # Afficher les statistiques
    print("\n=== STATISTIQUES DU COMPTE MT5 ===")
    print(f"Compte: #{df['AccountNumber'].iloc[0]} ({df['AccountServer'].iloc[0]})")
    print(f"Période: {df['Date'].iloc[0]} à {df['Date'].iloc[-1]}")
    print(f"Équité finale: ${df['Equity'].iloc[-1]:.2f}")
    print(f"Balance finale: ${df['Balance'].iloc[-1]:.2f}")
    print(f"Profit total: ${df['NetProfit'].sum():.2f}")
    print(f"Score moyen: {df['PerformanceScore'].mean():.2f}")
    print(f"Score maximum: {df['PerformanceScore'].max():.2f}")
    print(f"Score minimum: {df['PerformanceScore'].min():.2f}")
    print(f"Win Rate moyen: {df['WinRate'].mean()*100:.1f}%")
    print(f"ROE final: {df['ROE'].iloc[-1]*100:.2f}%")
    print(f"Drawdown maximum: {df['Drawdown'].max():.2f}%")
    print(f"Niveau de marge moyen: {df['MarginLevel'].mean():.2f}%")
    
    # Analyser la performance
    performance_analysis = analyze_mt5_performance(df)
    print(f"\nStatut: {performance_analysis['status']}")
    print(f"Tendance: {performance_analysis['trend']}")
    print(f"Drawdown actuel: {performance_analysis['current_drawdown']:.2f}%")
    print(f"Niveau de marge actuel: {performance_analysis['current_margin_level']:.2f}%")
    
    # Créer le tableau de bord
    print("\nGénération du tableau de bord MT5...")
    create_mt5_dashboard(df)
    
    # Générer les données de test pour MT5
    test_file = generate_mt5_csv(df)
    
    # Afficher les dernières données
    print("\n=== DERNIÈRES DONNÉES MT5 ===")
    print(df[['Date', 'Equity', 'Balance', 'WinningTrades', 'LosingTrades', 'NetProfit', 'PerformanceScore']].tail().to_string(index=False))
    
    print(f"\n✅ Test terminé - Données sauvegardées dans {test_file}")

if __name__ == "__main__":
    main()
