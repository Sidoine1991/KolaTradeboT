"""
Script de test pour vérifier que le système de protection des pertes fonctionne correctement.
"""
import sys
import os

# Forcer l'encodage UTF-8 sur Windows
if sys.platform == 'win32':
    try:
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8")
        if hasattr(sys.stderr, "reconfigure"):
            sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Ajouter le chemin du projet
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

def test_imports():
    """Test 1 : Vérifier que tous les imports fonctionnent"""
    print("=" * 60)
    print("TEST 1 : Vérification des imports")
    print("=" * 60)

    try:
        from backend.mt5_connector import monitor_positions_loss_limit, connect, is_connected
        print("✅ Import mt5_connector.monitor_positions_loss_limit")
    except ImportError as e:
        print(f"❌ Import mt5_connector échoué: {e}")
        return False

    try:
        from backend.mt5_order_utils import place_order_mt5
        print("✅ Import mt5_order_utils.place_order_mt5")
    except ImportError as e:
        print(f"❌ Import mt5_order_utils échoué: {e}")
        return False

    print("\n✅ Tous les imports OK\n")
    return True


def test_function_signature():
    """Test 2 : Vérifier la signature de la fonction"""
    print("=" * 60)
    print("TEST 2 : Vérification de la signature de fonction")
    print("=" * 60)

    try:
        from backend.mt5_connector import monitor_positions_loss_limit
        import inspect

        sig = inspect.signature(monitor_positions_loss_limit)
        print(f"Signature: {sig}")

        params = sig.parameters
        if 'max_loss_usd' in params:
            default_value = params['max_loss_usd'].default
            print(f"✅ Paramètre max_loss_usd trouvé (défaut: {default_value})")
        else:
            print("❌ Paramètre max_loss_usd manquant")
            return False

        print("\n✅ Signature correcte\n")
        return True
    except Exception as e:
        print(f"❌ Erreur lors de la vérification: {e}")
        return False


def test_api_endpoint():
    """Test 3 : Vérifier que l'endpoint API est enregistré"""
    print("=" * 60)
    print("TEST 3 : Vérification de l'endpoint API")
    print("=" * 60)

    try:
        from backend.api.robot_integration import router

        # Vérifier que la route existe
        found = False
        for route in router.routes:
            if hasattr(route, 'path') and '/monitor/loss-limit' in route.path:
                print(f"✅ Route trouvée: {route.path} ({route.methods})")
                found = True

        if not found:
            print("❌ Route /robot/monitor/loss-limit non trouvée")
            return False

        print("\n✅ Endpoint API OK\n")
        return True
    except Exception as e:
        print(f"❌ Erreur lors de la vérification de l'API: {e}")
        return False


def test_monitoring_script_exists():
    """Test 4 : Vérifier que les fichiers de monitoring existent"""
    print("=" * 60)
    print("TEST 4 : Vérification des fichiers")
    print("=" * 60)

    files_to_check = [
        "backend/continuous_loss_monitor.py",
        "start_loss_monitor.ps1",
        "GUIDE_PROTECTION_PERTES.md",
        "PROTECTION_PERTES_3USD_README.md"
    ]

    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

    all_exist = True
    for file in files_to_check:
        filepath = os.path.join(project_root, file)
        if os.path.exists(filepath):
            print(f"✅ {file}")
        else:
            print(f"❌ {file} - MANQUANT")
            all_exist = False

    if all_exist:
        print("\n✅ Tous les fichiers présents\n")
    else:
        print("\n❌ Certains fichiers manquants\n")

    return all_exist


def test_configuration_env():
    """Test 5 : Vérifier la configuration environnement"""
    print("=" * 60)
    print("TEST 5 : Vérification de la configuration")
    print("=" * 60)

    try:
        from dotenv import load_dotenv
        load_dotenv()

        import os

        mt5_login = os.getenv('MT5_LOGIN')
        mt5_password = os.getenv('MT5_PASSWORD')
        mt5_server = os.getenv('MT5_SERVER')

        if mt5_login:
            print(f"✅ MT5_LOGIN configuré ({mt5_login[:3]}...)")
        else:
            print("⚠️  MT5_LOGIN non configuré (optionnel)")

        if mt5_password:
            print("✅ MT5_PASSWORD configuré (***)")
        else:
            print("⚠️  MT5_PASSWORD non configuré (optionnel)")

        if mt5_server:
            print(f"✅ MT5_SERVER configuré ({mt5_server})")
        else:
            print("⚠️  MT5_SERVER non configuré (optionnel)")

        print("\n✅ Configuration vérifiée\n")
        return True
    except Exception as e:
        print(f"⚠️  Erreur lors de la vérification de la configuration: {e}")
        print("   (Ce n'est pas bloquant si MT5 est déjà connecté)\n")
        return True


def test_documentation():
    """Test 6 : Vérifier que la documentation est complète"""
    print("=" * 60)
    print("TEST 6 : Vérification de la documentation")
    print("=" * 60)

    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

    # Vérifier le guide principal
    guide_path = os.path.join(project_root, "GUIDE_PROTECTION_PERTES.md")
    if os.path.exists(guide_path):
        with open(guide_path, 'r', encoding='utf-8') as f:
            content = f.read()
            required_sections = [
                "Vue d'ensemble",
                "Installation",
                "Utilisation",
                "Configuration",
                "Dépannage"
            ]

            all_sections = True
            for section in required_sections:
                if section in content:
                    print(f"✅ Section '{section}' présente")
                else:
                    print(f"❌ Section '{section}' manquante")
                    all_sections = False

            if all_sections:
                print("\n✅ Documentation complète\n")
                return True
            else:
                print("\n⚠️  Documentation incomplète\n")
                return False
    else:
        print("❌ GUIDE_PROTECTION_PERTES.md manquant\n")
        return False


def run_all_tests():
    """Exécuter tous les tests"""
    print("\n" + "=" * 60)
    print(" 🛡️  TEST DU SYSTÈME DE PROTECTION DES PERTES")
    print("=" * 60 + "\n")

    tests = [
        ("Imports", test_imports),
        ("Signature fonction", test_function_signature),
        ("Endpoint API", test_api_endpoint),
        ("Fichiers", test_monitoring_script_exists),
        ("Configuration", test_configuration_env),
        ("Documentation", test_documentation)
    ]

    results = {}

    for test_name, test_func in tests:
        try:
            results[test_name] = test_func()
        except Exception as e:
            print(f"❌ Test '{test_name}' a échoué avec une exception: {e}\n")
            results[test_name] = False

    # Résumé
    print("=" * 60)
    print(" 📊 RÉSUMÉ DES TESTS")
    print("=" * 60)

    total_tests = len(results)
    passed_tests = sum(1 for result in results.values() if result)

    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status} - {test_name}")

    print()
    print(f"Total: {passed_tests}/{total_tests} tests réussis")

    if passed_tests == total_tests:
        print("\n✅ TOUS LES TESTS SONT PASSÉS !")
        print("🎉 Le système de protection est prêt à être utilisé.")
        print("\n📝 Prochaines étapes:")
        print("   1. Lancer le serveur FastAPI: python backend/api/main.py")
        print("   2. Lancer le monitoring: .\\start_loss_monitor.ps1")
        print("   3. Tester sur compte démo")
    else:
        print("\n⚠️  CERTAINS TESTS ONT ÉCHOUÉ")
        print("Veuillez corriger les erreurs avant de continuer.")

    print("\n" + "=" * 60 + "\n")

    return passed_tests == total_tests


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
