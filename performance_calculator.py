"""
Calculateur de Performance pour Robot de Trading
==============================================

Ce module calcule un score de performance synthétique basé sur :
- Capital initial et équité actuelle
- Nombre de trades gagnants/perdants
- Profit et perte journaliers

Le score combine rentabilité, régularité et gestion du risque.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
import json
import os

class PerformanceCalculator:
    """
    Calculateur de score de performance pour robot de trading.
    
    Formule du score :
    Score = 100 × (0.4 × ROE + 0.3 × WR + 0.3 × PF_normalized)
    
    Où :
    - ROE = Return on Equity (rendement sur capital)
    - WR = Win Rate (taux de réussite)
    - PF_normalized = Profit Factor normalisé entre 0 et 1
    """
    
    def __init__(self, initial_capital: float = 1000.0):
        """
        Initialise le calculateur de performance.
        
        Args:
            initial_capital: Capital initial du compte
        """
        self.initial_capital = initial_capital
        self.daily_data = []
        self.performance_history = []
        
    def add_daily_data(self, 
                      date: str,
                      equity: float,
                      winning_trades: int,
                      losing_trades: int,
                      daily_profit: float,
                      daily_loss: float) -> Dict:
        """
        Ajoute les données d'un jour et calcule le score de performance.
        
        Args:
            date: Date au format 'YYYY-MM-DD'
            equity: Équité actuelle du compte
            winning_trades: Nombre de trades gagnants
            losing_trades: Nombre de trades perdants
            daily_profit: Profit total du jour
            daily_loss: Perte totale du jour
            
        Returns:
            Dict contenant tous les calculs et le score final
        """
        # Calculs de base
        roe = self._calculate_roe(equity)
        win_rate = self._calculate_win_rate(winning_trades, losing_trades)
        profit_factor = self._calculate_profit_factor(daily_profit, daily_loss)
        net_profit = daily_profit - daily_loss
        
        # Score de performance
        score = self._calculate_performance_score(roe, win_rate, profit_factor)
        
        # Données du jour
        daily_data = {
            'date': date,
            'equity': equity,
            'winning_trades': winning_trades,
            'losing_trades': losing_trades,
            'daily_profit': daily_profit,
            'daily_loss': daily_loss,
            'net_profit': net_profit,
            'roe': roe,
            'win_rate': win_rate,
            'profit_factor': profit_factor,
            'performance_score': score
        }
        
        self.daily_data.append(daily_data)
        self.performance_history.append(score)
        
        return daily_data
    
    def _calculate_roe(self, equity: float) -> float:
        """Calcule le Return on Equity (ROE)."""
        return (equity - self.initial_capital) / self.initial_capital
    
    def _calculate_win_rate(self, winning_trades: int, losing_trades: int) -> float:
        """Calcule le taux de réussite (Win Rate)."""
        total_trades = winning_trades + losing_trades
        if total_trades == 0:
            return 0.0
        return winning_trades / total_trades
    
    def _calculate_profit_factor(self, daily_profit: float, daily_loss: float) -> float:
        """Calcule le Profit Factor."""
        if daily_loss == 0:
            return daily_profit if daily_profit > 0 else 0.0
        return daily_profit / daily_loss
    
    def _calculate_performance_score(self, roe: float, win_rate: float, profit_factor: float) -> float:
        """
        Calcule le score de performance synthétique.
        
        Formule : Score = 100 × (0.4 × ROE + 0.3 × WR + 0.3 × PF_normalized)
        """
        # Normalisation du profit factor entre 0 et 1
        pf_normalized = profit_factor / (1 + profit_factor) if profit_factor >= 0 else 0.0
        
        # Score pondéré
        score = 100 * (0.4 * roe + 0.3 * win_rate + 0.3 * pf_normalized)
        
        return round(score, 2)
    
    def get_performance_summary(self, days: int = 30) -> Dict:
        """
        Retourne un résumé de performance sur les N derniers jours.
        
        Args:
            days: Nombre de jours à analyser (par défaut 30)
            
        Returns:
            Dict avec statistiques de performance
        """
        if not self.daily_data:
            return {"error": "Aucune donnée disponible"}
        
        recent_data = self.daily_data[-days:] if len(self.daily_data) >= days else self.daily_data
        
        scores = [d['performance_score'] for d in recent_data]
        roes = [d['roe'] for d in recent_data]
        win_rates = [d['win_rate'] for d in recent_data]
        net_profits = [d['net_profit'] for d in recent_data]
        
        summary = {
            'period_days': len(recent_data),
            'current_score': scores[-1] if scores else 0,
            'average_score': round(np.mean(scores), 2),
            'score_std': round(np.std(scores), 2),
            'score_trend': self._calculate_trend(scores),
            'average_roe': round(np.mean(roes), 4),
            'average_win_rate': round(np.mean(win_rates), 4),
            'total_net_profit': round(sum(net_profits), 2),
            'best_score': round(max(scores), 2),
            'worst_score': round(min(scores), 2),
            'improvement_status': self._get_improvement_status(scores)
        }
        
        return summary
    
    def _calculate_trend(self, scores: List[float], window: int = 7) -> str:
        """Calcule la tendance des scores (amélioration/dégradation/stable)."""
        if len(scores) < window:
            return "Données insuffisantes"
        
        recent_scores = scores[-window:]
        older_scores = scores[-window*2:-window] if len(scores) >= window*2 else scores[:-window]
        
        if not older_scores:
            return "Données insuffisantes"
        
        recent_avg = np.mean(recent_scores)
        older_avg = np.mean(older_scores)
        
        diff = recent_avg - older_avg
        
        if diff > 2:
            return "Amélioration significative"
        elif diff > 0.5:
            return "Amélioration légère"
        elif diff < -2:
            return "Dégradation significative"
        elif diff < -0.5:
            return "Dégradation légère"
        else:
            return "Stable"
    
    def _get_improvement_status(self, scores: List[float]) -> str:
        """Détermine le statut d'amélioration du robot."""
        if len(scores) < 7:
            return "Évaluation en cours"
        
        recent_avg = np.mean(scores[-7:])
        overall_avg = np.mean(scores)
        
        if recent_avg > overall_avg + 2:
            return "🟢 Robot s'améliore"
        elif recent_avg < overall_avg - 2:
            return "🔴 Robot se dégrade"
        else:
            return "🟡 Performance stable"
    
    def plot_performance_evolution(self, days: int = 30, save_path: Optional[str] = None):
        """
        Crée un graphique de l'évolution du score de performance.
        
        Args:
            days: Nombre de jours à afficher
            save_path: Chemin pour sauvegarder le graphique
        """
        if not self.daily_data:
            print("Aucune donnée à afficher")
            return
        
        recent_data = self.daily_data[-days:] if len(self.daily_data) >= days else self.daily_data
        
        dates = [datetime.strptime(d['date'], '%Y-%m-%d') for d in recent_data]
        scores = [d['performance_score'] for d in recent_data]
        roes = [d['roe'] * 100 for d in recent_data]  # Conversion en pourcentage
        win_rates = [d['win_rate'] * 100 for d in recent_data]  # Conversion en pourcentage
        
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))
        fig.suptitle('Analyse de Performance du Robot de Trading', fontsize=16, fontweight='bold')
        
        # Score de performance
        ax1.plot(dates, scores, 'b-', linewidth=2, marker='o', markersize=4)
        ax1.axhline(y=50, color='r', linestyle='--', alpha=0.7, label='Seuil de performance')
        ax1.set_title('Évolution du Score de Performance')
        ax1.set_ylabel('Score (0-100)')
        ax1.grid(True, alpha=0.3)
        ax1.legend()
        ax1.tick_params(axis='x', rotation=45)
        
        # ROE
        ax2.plot(dates, roes, 'g-', linewidth=2, marker='s', markersize=4)
        ax2.axhline(y=0, color='r', linestyle='--', alpha=0.7)
        ax2.set_title('Return on Equity (ROE)')
        ax2.set_ylabel('ROE (%)')
        ax2.grid(True, alpha=0.3)
        ax2.tick_params(axis='x', rotation=45)
        
        # Win Rate
        ax3.plot(dates, win_rates, 'orange', linewidth=2, marker='^', markersize=4)
        ax3.axhline(y=50, color='r', linestyle='--', alpha=0.7, label='Seuil 50%')
        ax3.set_title('Taux de Réussite (Win Rate)')
        ax3.set_ylabel('Win Rate (%)')
        ax3.grid(True, alpha=0.3)
        ax3.legend()
        ax3.tick_params(axis='x', rotation=45)
        
        # Distribution des scores
        ax4.hist(scores, bins=10, alpha=0.7, color='purple', edgecolor='black')
        ax4.axvline(x=np.mean(scores), color='r', linestyle='--', linewidth=2, label=f'Moyenne: {np.mean(scores):.1f}')
        ax4.set_title('Distribution des Scores')
        ax4.set_xlabel('Score')
        ax4.set_ylabel('Fréquence')
        ax4.grid(True, alpha=0.3)
        ax4.legend()
        
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
            print(f"Graphique sauvegardé: {save_path}")
        
        plt.show()
    
    def export_data(self, filename: str = None):
        """
        Exporte les données de performance en CSV et JSON.
        
        Args:
            filename: Nom de base du fichier (sans extension)
        """
        if not self.daily_data:
            print("Aucune donnée à exporter")
            return
        
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"performance_data_{timestamp}"
        
        # Export CSV
        df = pd.DataFrame(self.daily_data)
        csv_path = f"{filename}.csv"
        df.to_csv(csv_path, index=False)
        print(f"Données exportées en CSV: {csv_path}")
        
        # Export JSON
        json_path = f"{filename}.json"
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(self.daily_data, f, indent=2, ensure_ascii=False)
        print(f"Données exportées en JSON: {json_path}")
        
        return csv_path, json_path
    
    def load_data(self, filepath: str):
        """
        Charge des données de performance depuis un fichier CSV ou JSON.
        
        Args:
            filepath: Chemin vers le fichier de données
        """
        if filepath.endswith('.csv'):
            df = pd.read_csv(filepath)
            self.daily_data = df.to_dict('records')
        elif filepath.endswith('.json'):
            with open(filepath, 'r', encoding='utf-8') as f:
                self.daily_data = json.load(f)
        else:
            raise ValueError("Format de fichier non supporté. Utilisez .csv ou .json")
        
        # Recalculer l'historique des scores
        self.performance_history = [d['performance_score'] for d in self.daily_data]
        print(f"Données chargées: {len(self.daily_data)} jours de données")


def create_sample_data(days: int = 30) -> List[Dict]:
    """
    Crée des données d'exemple pour tester le calculateur.
    
    Args:
        days: Nombre de jours de données à générer
        
    Returns:
        Liste de dictionnaires avec les données d'exemple
    """
    np.random.seed(42)  # Pour la reproductibilité
    
    sample_data = []
    base_equity = 1000.0
    
    for i in range(days):
        date = (datetime.now() - timedelta(days=days-i-1)).strftime('%Y-%m-%d')
        
        # Simulation de données réalistes
        equity_change = np.random.normal(0.02, 0.05)  # Changement d'équité
        base_equity *= (1 + equity_change)
        
        winning_trades = np.random.poisson(3)  # Nombre de trades gagnants
        losing_trades = np.random.poisson(2)   # Nombre de trades perdants
        
        daily_profit = np.random.exponential(50) * winning_trades
        daily_loss = np.random.exponential(30) * losing_trades
        
        sample_data.append({
            'date': date,
            'equity': round(base_equity, 2),
            'winning_trades': winning_trades,
            'losing_trades': losing_trades,
            'daily_profit': round(daily_profit, 2),
            'daily_loss': round(daily_loss, 2)
        })
    
    return sample_data


if __name__ == "__main__":
    # Exemple d'utilisation
    print("=== Calculateur de Performance pour Robot de Trading ===\n")
    
    # Créer le calculateur
    calculator = PerformanceCalculator(initial_capital=1000.0)
    
    # Générer des données d'exemple
    print("Génération de données d'exemple...")
    sample_data = create_sample_data(days=30)
    
    # Ajouter les données jour par jour
    for data in sample_data:
        calculator.add_daily_data(
            date=data['date'],
            equity=data['equity'],
            winning_trades=data['winning_trades'],
            losing_trades=data['losing_trades'],
            daily_profit=data['daily_profit'],
            daily_loss=data['daily_loss']
        )
    
    # Afficher le résumé de performance
    print("\n=== RÉSUMÉ DE PERFORMANCE ===")
    summary = calculator.get_performance_summary()
    for key, value in summary.items():
        print(f"{key}: {value}")
    
    # Créer les graphiques
    print("\nGénération des graphiques...")
    calculator.plot_performance_evolution(days=30)
    
    # Exporter les données
    print("\nExport des données...")
    calculator.export_data("performance_robot_trading")
    
    print("\n=== Analyse terminée ===")
