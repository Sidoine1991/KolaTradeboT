#!/usr/bin/env python3
"""
sync_ml_stats_to_mt5.py
Synchronise les stats ML depuis AWS RDS vers MT5 GlobalVariables
"""
import os
import time
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
except ImportError:
    MT5_AVAILABLE = False
    print("[WARN] MetaTrader5 pas installé - mode simulation")

try:
    from aws_rds_helper import aws_rds_client
    AWS_RDS_AVAILABLE = True
except ImportError:
    AWS_RDS_AVAILABLE = False
    print("[ERROR] aws_rds_helper non disponible")


def set_global_variable(name: str, value: float) -> bool:
    """Définir une GlobalVariable dans MT5"""
    if not MT5_AVAILABLE:
        print(f"  [SIMUL] {name} = {value}")
        return True

    try:
        mt5.global_variable_set(name, value)
        return True
    except Exception as e:
        print(f"[ERROR] Impossible de définir {name}: {e}")
        return False


def get_ml_stats_from_rds():
    """Récupérer les stats ML depuis AWS RDS"""
    if not AWS_RDS_AVAILABLE:
        return None

    stats = {
        'total_predictions': 0,
        'accurate_predictions': 0,
        'trades_total': 0,
        'trades_win': 0,
        'avg_profit': 0.0,
        'last_training': 0,
        'last_prediction': 0,
        'models_loaded': 0
    }

    try:
        # Récupérer les prédictions
        predictions = aws_rds_client.select(
            "predictions",
            order_by="created_at DESC",
            limit=1000
        )
        stats['total_predictions'] = len(predictions)

        # Compter les prédictions correctes (accuracy > 0.7)
        stats['accurate_predictions'] = sum(
            1 for p in predictions
            if p.get('confidence', 0) > 0.7
        )

        # Dernière prédiction
        if predictions:
            last_pred_str = predictions[0].get('created_at', '')
            try:
                last_pred_dt = datetime.fromisoformat(last_pred_str.replace('Z', '+00:00'))
                stats['last_prediction'] = int(last_pred_dt.timestamp())
            except:
                stats['last_prediction'] = int(time.time())

        # Récupérer les trades
        trades = aws_rds_client.select(
            "trade_feedback",
            order_by="executed_at DESC",
            limit=500
        )
        stats['trades_total'] = len(trades)

        # Compter les trades gagnants
        stats['trades_win'] = sum(
            1 for t in trades
            if t.get('profit_usd', 0) > 0
        )

        # Profit moyen
        profits = [t.get('profit_usd', 0) for t in trades if 'profit_usd' in t]
        if profits:
            stats['avg_profit'] = sum(profits) / len(profits)

        # Récupérer les métriques modèles
        metrics = aws_rds_client.select(
            "model_metrics",
            order_by="timestamp DESC",
            limit=1
        )

        if metrics:
            # Dernier entraînement
            last_train_str = metrics[0].get('timestamp', '')
            try:
                last_train_dt = datetime.fromisoformat(last_train_str.replace('Z', '+00:00'))
                stats['last_training'] = int(last_train_dt.timestamp())
            except:
                stats['last_training'] = int(time.time())

            # Nombre de modèles
            stats['models_loaded'] = metrics[0].get('models_loaded', 0)

        return stats

    except Exception as e:
        print(f"[ERROR] Erreur lors de la récupération des stats: {e}")
        return None


def sync_ml_stats():
    """Synchroniser les stats ML vers MT5"""
    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Synchronisation stats ML...")

    if not AWS_RDS_AVAILABLE:
        print("[ERROR] AWS RDS non disponible - arrêt")
        return False

    # Récupérer les stats
    stats = get_ml_stats_from_rds()
    if not stats:
        print("[ERROR] Impossible de récupérer les stats")
        return False

    # Calculer les métriques
    accuracy = 0.0
    if stats['total_predictions'] > 0:
        accuracy = (stats['accurate_predictions'] / stats['total_predictions']) * 100.0

    win_rate = 0.0
    if stats['trades_total'] > 0:
        win_rate = (stats['trades_win'] / stats['trades_total']) * 100.0

    # Afficher les stats
    print(f"  Prédictions: {stats['total_predictions']} (précision: {accuracy:.1f}%)")
    print(f"  Trades: {stats['trades_total']} (win rate: {win_rate:.1f}%)")
    print(f"  Profit moyen: ${stats['avg_profit']:.2f}")
    print(f"  Modèles chargés: {stats['models_loaded']}")

    # Envoyer vers MT5
    if MT5_AVAILABLE:
        if not mt5.initialize():
            print("[ERROR] Impossible d'initialiser MT5")
            return False

    set_global_variable("ML_TOTAL_PREDICTIONS", float(stats['total_predictions']))
    set_global_variable("ML_ACCURATE_PREDICTIONS", float(stats['accurate_predictions']))
    set_global_variable("ML_TRADES_TOTAL", float(stats['trades_total']))
    set_global_variable("ML_TRADES_WIN", float(stats['trades_win']))
    set_global_variable("ML_AVG_PROFIT_USD", stats['avg_profit'])
    set_global_variable("ML_LAST_TRAINING", float(stats['last_training']))
    set_global_variable("ML_LAST_PREDICTION", float(stats['last_prediction']))
    set_global_variable("ML_MODELS_LOADED", float(stats['models_loaded']))

    # Stats robot (exemples - à adapter selon votre logique)
    set_global_variable("ROBOT_ACTIVE", 1.0)
    set_global_variable("ROBOT_PAUSED", 0.0)
    set_global_variable("ROBOT_PAUSE_UNTIL", 0.0)
    set_global_variable("ROBOT_PAUSE_REASON", 0.0)
    set_global_variable("ROBOT_DAILY_PROFIT", stats['avg_profit'])
    set_global_variable("ROBOT_TARGET_PCT", 0.0)

    if MT5_AVAILABLE:
        mt5.shutdown()

    print("  ✅ Synchronisation terminée")
    return True


def main():
    """Boucle principale"""
    print("=== Synchronisation ML Stats vers MT5 ===")
    print("Connexion AWS RDS...")

    if not AWS_RDS_AVAILABLE:
        print("[ERROR] Module aws_rds_helper non disponible")
        print("Vérifiez que le fichier aws_rds_helper.py existe")
        return

    refresh_interval = 30  # Secondes

    print(f"Rafraîchissement toutes les {refresh_interval}s")
    print("Appuyez sur Ctrl+C pour arrêter\n")

    try:
        while True:
            sync_ml_stats()
            time.sleep(refresh_interval)

    except KeyboardInterrupt:
        print("\n[INFO] Arrêt demandé par l'utilisateur")
    except Exception as e:
        print(f"\n[ERROR] Erreur fatale: {e}")


if __name__ == "__main__":
    main()
