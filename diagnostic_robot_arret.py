"""
Diagnostic pour Robot de Trading Arrêté
=======================================

Ce script aide à diagnostiquer pourquoi le robot s'est arrêté de prendre des trades.
"""

def diagnostic_robot_arret():
    """
    Diagnostic complet des causes possibles d'arrêt du robot.
    """
    print("[DIAGNOSTIC] ROBOT ARRETE - SpikeHunter EA")
    print("=" * 50)
    
    causes_possibles = [
        {
            "cause": "Cooldown Actif",
            "description": "Le robot est en période de cooldown après des pertes consécutives",
            "parametres": [
                "InpCooldownMinutes",
                "InpCooldownAfterLosses", 
                "InpCooldownLossMinutes",
                "g_inCooldown",
                "g_cooldownEndTime"
            ],
            "solution": "Vérifier les logs pour 'Cooldown terminé' ou attendre la fin du cooldown"
        },
        {
            "cause": "Trading Désactivé",
            "description": "Le paramètre InpEnableTrading est désactivé",
            "parametres": ["InpEnableTrading"],
            "solution": "Activer InpEnableTrading = true dans les paramètres"
        },
        {
            "cause": "Gestion des Risques Bloque",
            "description": "Le gestionnaire de risques bloque les nouveaux trades",
            "parametres": [
                "InpMaxTrades",
                "InpMaxDailyLoss",
                "InpMaxRiskPercent",
                "g_riskManager.CanOpenTrade()"
            ],
            "solution": "Vérifier les limites de trades et de pertes journalières"
        },
        {
            "cause": "Seuil de Confiance Trop Élevé",
            "description": "Les signaux ne passent pas le seuil de confiance minimum",
            "parametres": [
                "InpMinConfidenceThreshold",
                "InpUltraHighConfidence",
                "InpStableConfidenceMin"
            ],
            "solution": "Réduire les seuils de confiance ou améliorer la qualité des signaux"
        },
        {
            "cause": "Mode Ultra-Précis Trop Strict",
            "description": "Le mode ultra-précis est trop restrictif",
            "parametres": [
                "InpUltraPreciseMode",
                "InpSpikeConfirmationThreshold",
                "InpMinSpikeStrength",
                "InpUltraHighConfidence"
            ],
            "solution": "Désactiver le mode ultra-précis ou ajuster les seuils"
        },
        {
            "cause": "Fermeture Panier Activée",
            "description": "Le robot a atteint les seuils de profit/perte du panier",
            "parametres": [
                "InpEnableBasketClose",
                "InpBasketProfitCloseUSD",
                "InpBasketLossCloseUSD"
            ],
            "solution": "Vérifier les seuils de fermeture panier ou les désactiver"
        },
        {
            "cause": "API Externe Indisponible",
            "description": "Les signaux externes ne sont pas disponibles",
            "parametres": [
                "InpUseExternalSignals",
                "InpUseAPIPredictions",
                "InpAPIUrl"
            ],
            "solution": "Vérifier la connexion API ou désactiver les signaux externes"
        },
        {
            "cause": "Conditions de Marché Non Favorables",
            "description": "Les conditions de marché ne génèrent pas de signaux",
            "parametres": [
                "InpEnableICT",
                "InpICTMinScore",
                "InpSpikeZoneMinScore"
            ],
            "solution": "Ajuster les seuils de détection ou les conditions de trading"
        }
    ]
    
    print("\n[CAUSES POSSIBLES] :")
    print("-" * 30)
    
    for i, cause in enumerate(causes_possibles, 1):
        print(f"\n{i}. {cause['cause']}")
        print(f"   Description: {cause['description']}")
        print(f"   Paramètres à vérifier: {', '.join(cause['parametres'])}")
        print(f"   Solution: {cause['solution']}")
    
    print("\n[ACTIONS IMMEDIATES] :")
    print("-" * 25)
    
    actions = [
        "1. Vérifier les logs MT5 pour les messages d'erreur",
        "2. Contrôler que InpEnableTrading = true",
        "3. Vérifier les seuils de confiance (InpMinConfidenceThreshold)",
        "4. Désactiver temporairement le mode ultra-précis",
        "5. Vérifier les limites de trades et de pertes",
        "6. Contrôler l'état du cooldown dans les logs",
        "7. Tester avec des paramètres plus permissifs"
    ]
    
    for action in actions:
        print(f"   {action}")
    
    print("\n[PARAMETRES DE TEST RECOMMANDES] :")
    print("-" * 35)
    
    params_test = {
        "InpEnableTrading": "true",
        "InpMinConfidenceThreshold": "50",
        "InpUltraPreciseMode": "false",
        "InpEnableBasketClose": "false",
        "InpUseExternalSignals": "false",
        "InpUseAPIPredictions": "false",
        "InpMaxTrades": "5",
        "InpCooldownMinutes": "1"
    }
    
    for param, value in params_test.items():
        print(f"   {param} = {value}")
    
    print("\n[MESSAGES A RECHERCHER DANS LES LOGS] :")
    print("-" * 40)
    
    messages = [
        "[BLOQUE] Trade bloque par gestion des risques",
        "[COOLDOWN] Cooldown actif",
        "[ERREUR] Confiance insuffisante",
        "[BLOQUE] Trading desactive",
        "[EXPIRE] SIGNAL EXPIRE",
        "[ERREUR] SL/TP invalides",
        "[ERREUR] Taille de lot invalide"
    ]
    
    for message in messages:
        print(f"   '{message}'")
    
    print("\n[SOLUTION RAPIDE] :")
    print("-" * 20)
    print("1. Redémarrer l'EA avec les paramètres de test")
    print("2. Surveiller les logs pendant 10 minutes")
    print("3. Si aucun trade, réduire InpMinConfidenceThreshold à 30")
    print("4. Si toujours rien, désactiver InpUltraPreciseMode")
    print("5. Vérifier que le marché est ouvert et volatil")

if __name__ == "__main__":
    diagnostic_robot_arret()
