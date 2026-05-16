#!/bin/bash

# Script de déploiement PROPRE pour les deux terminaux MT5
# Supprime TOUJOURS l'ancien avant de copier le nouveau

TERM1="/c/Users/USER/AppData/Roaming/MetaQuotes/Terminal/E6E3D0917DD641581E4779524EB3B1AA/MQL5/Experts"
TERM2="/c/Users/USER/AppData/Roaming/MetaQuotes/Terminal/F016FF5B93786543B564E81A925D7066/MQL5/Experts"

SOURCE_MQ5="D:/Dev/TradBOT/SMC_Universal.mq5"
SOURCE_DASHBOARD="D:/Dev/TradBOT/SMC_Dashboard_Pro.mq5"

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║        🚀 DÉPLOIEMENT PROPRE - SUPPRIME ANCIEN + COPIE NOUVEAU    ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Fonction pour nettoyer et copier
deploy_to_terminal() {
    local term_path=$1
    local term_name=$2

    echo "📋 $term_name:"
    echo "   🧹 Suppression des anciens fichiers..."

    # Supprimer les anciens fichiers
    rm -f "$term_path/SMC_Universal.mq5"
    rm -f "$term_path/SMC_Universal.ex5"
    rm -f "$term_path/SMC_Dashboard_Pro.mq5"

    echo "   ✅ Anciens fichiers supprimés"
    echo "   📋 Copie des nouveaux fichiers..."

    # Copier les nouveaux fichiers
    cp "$SOURCE_MQ5" "$term_path/SMC_Universal.mq5"
    cp "$SOURCE_DASHBOARD" "$term_path/SMC_Dashboard_Pro.mq5"

    echo "   ✅ SMC_Universal.mq5 copié"
    echo "   ✅ SMC_Dashboard_Pro.mq5 copié"
    echo ""
}

# Déployer sur Terminal 1
deploy_to_terminal "$TERM1" "Terminal 1"

# Déployer sur Terminal 2
deploy_to_terminal "$TERM2" "Terminal 2"

echo "════════════════════════════════════════════════════════════════════"
echo "✅ DÉPLOIEMENT COMPLET - Fichiers frais sur les deux terminaux"
echo ""
echo "📌 PROCHAINES ÉTAPES:"
echo "   1. Recompiler dans chaque terminal (F5)"
echo "   2. Redémarrer les EAs"
echo "   3. Vérifier les logs"
echo "════════════════════════════════════════════════════════════════════"
