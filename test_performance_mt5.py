"""
Script de test pour le système de performance MT5
================================================

Ce script simule des données de trading et calcule les scores de performance
pour tester le système intégré dans l'EA MT5.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import matplotlib.pyplot as plt

def simulate_trading_data(days=30, initial_capital=1000.0):
    """
    Simule des données de trading réalistes pour tester le système de performance.
    
    Args:
        days: Nombre de jours de données à générer
        initial_capital: Capital initial du compte
        
    Returns:
        DataFrame avec les données de trading simulées
    """
    np.random.seed(42)  # Pour la reproductibilité
    
    data = []
    current_equity = initial_capital
    
    for i in range(days):
        date = datetime.now() - timedelta(days=days-i-1)
        
        # Simulation de trades journaliers
        num_trades = np.random.poisson(3)  # Nombre moyen de trades par jour
        
        winning_trades = 0
        losing_trades = 0
        daily_profit = 0.0
        daily_loss = 0.0
        
        # Simuler les trades du jour
        for _ in range(num_trades):
            # Probabilité de gain basée sur la performance récente
            win_probability = 0.6 + (current_equity - initial_capital) / initial_capital * 0.1
            win_probability = max(0.3, min(0.8, win_probability))  # Limiter entre 30% et 80%
            
            if np.random.random() < win_probability:
                # Trade gagnant
                profit = np.random.exponential(15)  # Profit moyen de 15$
                winning_trades += 1
                daily_profit += profit
                current_equity += profit
            else:
                # Trade perdant
                loss = np.random.exponential(10)  # Perte moyenne de 10$
                losing_trades += 1
                daily_loss += loss
                current_equity -= loss
        
        # Ajouter une petite variation aléatoire à l'équité
        current_equity += np.random.normal(0, 5)
        current_equity = max(current_equity, initial_capital * 0.1)  # Éviter les valeurs négatives
        
        data.append({
            'date': date.strftime('%Y-%m-%d'),
            'equity': round(current_equity, 2),
            'winning_trades': winning_trades,
            'losing_trades': losing_trades,
            'daily_profit': round(daily_profit, 2),
            'daily_loss': round(daily_loss, 2)
        })
    
    return pd.DataFrame(data)

def calculate_performance_metrics(df, initial_capital):
    """
    Calcule les métriques de performance pour chaque jour.
    
    Args:
        df: DataFrame avec les données de trading
        initial_capital: Capital initial
        
    Returns:
        DataFrame avec les métriques calculées
    """
    df = df.copy()
    
    # Calculer les métriques
    df['net_profit'] = df['daily_profit'] - df['daily_loss']
    df['roe'] = (df['equity'] - initial_capital) / initial_capital
    df['win_rate'] = df['winning_trades'] / (df['winning_trades'] + df['losing_trades'])
    df['win_rate'] = df['win_rate'].fillna(0)
    
    # Profit Factor
    df['profit_factor'] = 0.0
    mask = df['daily_loss'] > 0
    df.loc[mask, 'profit_factor'] = df.loc[mask, 'daily_profit'] / df.loc[mask, 'daily_loss']
    df.loc[~mask & (df['daily_profit'] > 0), 'profit_factor'] = df.loc[~mask & (df['daily_profit'] > 0), 'daily_profit']
    
    # Score de performance synthétique
    df['pf_normalized'] = df['profit_factor'] / (1 + df['profit_factor'])
    df['performance_score'] = 100 * (0.4 * df['roe'] + 0.3 * df['win_rate'] + 0.3 * df['pf_normalized'])
    df['performance_score'] = df['performance_score'].round(2)
    
    return df

def analyze_performance_trend(df):
    """
    Analyse la tendance de performance du robot.
    
    Args:
        df: DataFrame avec les métriques de performance
        
    Returns:
        Dict avec l'analyse de tendance
    """
    if len(df) < 7:
        return {"status": "Données insuffisantes", "trend": "Inconnu"}
    
    # Moyennes sur 7 jours
    recent_7d = df['performance_score'].tail(7).mean()
    recent_14d = df['performance_score'].tail(14).mean() if len(df) >= 14 else recent_7d
    
    # Calculer la tendance
    if len(df) >= 14:
        older_7d = df['performance_score'].iloc[-14:-7].mean()
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
    
    return {
        "status": status,
        "trend": trend,
        "current_score": recent_7d,
        "improvement": recent_7d - recent_14d if len(df) >= 14 else 0
    }

def create_performance_dashboard(df):
    """
    Crée un tableau de bord de performance.
    
    Args:
        df: DataFrame avec les métriques de performance
    """
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle('Tableau de Bord de Performance - Robot de Trading', fontsize=16, fontweight='bold')
    
    # Conversion des dates
    df['date_dt'] = pd.to_datetime(df['date'])
    
    # 1. Évolution du score de performance
    ax1.plot(df['date_dt'], df['performance_score'], 'b-', linewidth=2, marker='o', markersize=4)
    ax1.axhline(y=50, color='r', linestyle='--', alpha=0.7, label='Seuil de performance')
    ax1.set_title('Évolution du Score de Performance')
    ax1.set_ylabel('Score (0-100)')
    ax1.grid(True, alpha=0.3)
    ax1.legend()
    ax1.tick_params(axis='x', rotation=45)
    
    # 2. ROE
    ax2.plot(df['date_dt'], df['roe'] * 100, 'g-', linewidth=2, marker='s', markersize=4)
    ax2.axhline(y=0, color='r', linestyle='--', alpha=0.7)
    ax2.set_title('Return on Equity (ROE)')
    ax2.set_ylabel('ROE (%)')
    ax2.grid(True, alpha=0.3)
    ax2.tick_params(axis='x', rotation=45)
    
    # 3. Win Rate
    ax3.plot(df['date_dt'], df['win_rate'] * 100, 'orange', linewidth=2, marker='^', markersize=4)
    ax3.axhline(y=50, color='r', linestyle='--', alpha=0.7, label='Seuil 50%')
    ax3.set_title('Taux de Réussite (Win Rate)')
    ax3.set_ylabel('Win Rate (%)')
    ax3.grid(True, alpha=0.3)
    ax3.legend()
    ax3.tick_params(axis='x', rotation=45)
    
    # 4. Distribution des scores
    ax4.hist(df['performance_score'], bins=10, alpha=0.7, color='purple', edgecolor='black')
    ax4.axvline(x=df['performance_score'].mean(), color='r', linestyle='--', linewidth=2, 
                label=f'Moyenne: {df["performance_score"].mean():.1f}')
    ax4.set_title('Distribution des Scores')
    ax4.set_xlabel('Score')
    ax4.set_ylabel('Fréquence')
    ax4.grid(True, alpha=0.3)
    ax4.legend()
    
    plt.tight_layout()
    plt.show()

def generate_mt5_test_data(df, filename="mt5_performance_test.csv"):
    """
    Génère un fichier CSV avec les données de test pour MT5.
    
    Args:
        df: DataFrame avec les données de performance
        filename: Nom du fichier de sortie
    """
    # Sélectionner les colonnes pertinentes pour MT5
    mt5_data = df[['date', 'equity', 'winning_trades', 'losing_trades', 
                   'daily_profit', 'daily_loss', 'net_profit', 'roe', 
                   'win_rate', 'profit_factor', 'performance_score']].copy()
    
    # Sauvegarder en CSV
    mt5_data.to_csv(filename, index=False)
    print(f"✅ Données de test générées: {filename}")
    
    return filename

def main():
    """
    Fonction principale pour tester le système de performance.
    """
    print("=== Test du Système de Performance MT5 ===\n")
    
    # Paramètres de test
    initial_capital = 1000.0
    days = 30
    
    print(f"Génération de {days} jours de données de trading...")
    print(f"Capital initial: ${initial_capital}")
    
    # Générer les données de trading
    df = simulate_trading_data(days, initial_capital)
    
    # Calculer les métriques de performance
    df = calculate_performance_metrics(df, initial_capital)
    
    # Afficher les statistiques
    print("\n=== STATISTIQUES DE PERFORMANCE ===")
    print(f"Période: {df['date'].iloc[0]} à {df['date'].iloc[-1]}")
    print(f"Capital final: ${df['equity'].iloc[-1]:.2f}")
    print(f"Profit total: ${df['net_profit'].sum():.2f}")
    print(f"Score moyen: {df['performance_score'].mean():.2f}")
    print(f"Score maximum: {df['performance_score'].max():.2f}")
    print(f"Score minimum: {df['performance_score'].min():.2f}")
    print(f"Win Rate moyen: {df['win_rate'].mean()*100:.1f}%")
    print(f"ROE final: {df['roe'].iloc[-1]*100:.2f}%")
    
    # Analyser la tendance
    trend_analysis = analyze_performance_trend(df)
    print(f"\nStatut: {trend_analysis['status']}")
    print(f"Tendance: {trend_analysis['trend']}")
    
    # Créer le tableau de bord
    print("\nGénération du tableau de bord...")
    create_performance_dashboard(df)
    
    # Générer les données de test pour MT5
    test_file = generate_mt5_test_data(df)
    
    # Afficher les dernières données
    print("\n=== DERNIÈRES DONNÉES ===")
    print(df.tail().to_string(index=False))
    
    print(f"\n✅ Test terminé - Données sauvegardées dans {test_file}")

if __name__ == "__main__":
    main()
