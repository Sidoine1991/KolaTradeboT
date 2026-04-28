"""
Script de monitoring continu des pertes sur les positions MT5.
Ferme automatiquement toute position dès que la perte atteint 3 dollars.
"""
import time
import sys
import os
from datetime import datetime

# Ajouter le chemin du projet
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from backend.mt5_connector import connect, shutdown, monitor_positions_loss_limit, is_connected

# Configuration
MAX_LOSS_USD = 3.0  # Perte maximale autorisée par trade
CHECK_INTERVAL_SECONDS = 1  # Vérification toutes les 1 secondes
RECONNECT_INTERVAL = 30  # Tentative de reconnexion toutes les 30 secondes


def main():
    """
    Boucle principale de monitoring continu.
    """
    print("=" * 60)
    print("🛡️  SYSTÈME DE PROTECTION AUTOMATIQUE DES PERTES")
    print("=" * 60)
    print(f"⚙️  Configuration:")
    print(f"   • Perte maximale par trade: {MAX_LOSS_USD}$")
    print(f"   • Intervalle de vérification: {CHECK_INTERVAL_SECONDS}s")
    print("=" * 60)
    print()

    # Connexion initiale à MT5
    try:
        print("🔌 Connexion à MT5...")
        connect()
        print("✅ Connecté à MT5 avec succès")
        print()
    except Exception as e:
        print(f"❌ Erreur de connexion initiale à MT5: {e}")
        print("⚠️  Le monitoring continuera mais tentera de se reconnecter automatiquement")
        print()

    last_reconnect_attempt = time.time()
    consecutive_errors = 0
    max_consecutive_errors = 5

    print("🚀 Démarrage du monitoring continu...")
    print("🛑 Appuyez sur Ctrl+C pour arrêter")
    print()

    try:
        while True:
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            try:
                # Vérifier la connexion MT5
                if not is_connected():
                    if time.time() - last_reconnect_attempt >= RECONNECT_INTERVAL:
                        print(f"⚠️  [{current_time}] MT5 déconnecté, tentative de reconnexion...")
                        try:
                            connect()
                            print(f"✅ [{current_time}] Reconnexion réussie")
                            consecutive_errors = 0
                            last_reconnect_attempt = time.time()
                        except Exception as e:
                            print(f"❌ [{current_time}] Échec de reconnexion: {e}")
                            last_reconnect_attempt = time.time()
                    time.sleep(CHECK_INTERVAL_SECONDS)
                    continue

                # Surveiller les positions
                result = monitor_positions_loss_limit(max_loss_usd=MAX_LOSS_USD)

                if result["success"]:
                    consecutive_errors = 0

                    # Si des positions ont été fermées
                    if result["closed_positions"]:
                        print(f"⚠️  [{current_time}] ALERTE: {len(result['closed_positions'])} position(s) fermée(s)!")
                        print(f"   Message: {result['message']}")
                        print()

                        for pos_info in result["closed_positions"]:
                            print(f"   📊 Détails de la position fermée:")
                            print(f"      • Symbole: {pos_info['symbol']}")
                            print(f"      • Ticket: {pos_info.get('ticket', 'N/A')}")
                            print(f"      • Perte: {pos_info['loss']:.2f}$")
                            print(f"      • Fermée à: {pos_info.get('closed_at', 'N/A')}")
                            print(f"      • Statut: {pos_info['status']}")
                            if pos_info['status'] == 'FAILED':
                                print(f"      • Erreur: {pos_info.get('error', 'N/A')}")
                            print()
                    else:
                        # Mode silencieux: affichage uniquement toutes les 30 secondes
                        if int(time.time()) % 30 == 0:
                            print(f"✅ [{current_time}] {result['message']}")
                else:
                    print(f"⚠️  [{current_time}] Avertissement: {result.get('message', 'Erreur inconnue')}")

            except KeyboardInterrupt:
                raise  # Laisser passer l'interruption clavier
            except Exception as e:
                consecutive_errors += 1
                print(f"❌ [{current_time}] Erreur monitoring (#{consecutive_errors}): {e}")

                if consecutive_errors >= max_consecutive_errors:
                    print(f"⛔ Trop d'erreurs consécutives ({consecutive_errors}), arrêt du monitoring")
                    break

            # Attendre avant la prochaine vérification
            time.sleep(CHECK_INTERVAL_SECONDS)

    except KeyboardInterrupt:
        print()
        print("🛑 Arrêt du monitoring demandé par l'utilisateur")
    except Exception as e:
        print()
        print(f"❌ Erreur fatale: {e}")
    finally:
        print()
        print("🔌 Fermeture de la connexion MT5...")
        try:
            shutdown()
            print("✅ Déconnexion réussie")
        except Exception as e:
            print(f"⚠️  Erreur lors de la déconnexion: {e}")

        print()
        print("=" * 60)
        print("👋 Monitoring arrêté")
        print("=" * 60)


if __name__ == "__main__":
    main()
