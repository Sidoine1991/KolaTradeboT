#!/bin/bash
# Script shell pour activer l'environnement virtuel .venv
# Usage: source activate_venv.sh ou . activate_venv.sh

echo "🔍 Recherche de l'environnement virtuel..."

VENV_PATH="D:/Dev/TradBOT/.venv"

# Vérifier si le dossier .venv existe
if [ ! -d "$VENV_PATH" ]; then
    echo "❌ L'environnement virtuel n'existe pas à: $VENV_PATH"
    echo "📋 Création de l'environnement virtuel..."
    
    # Créer l'environnement virtuel
    python -m venv "$VENV_PATH"
    if [ $? -ne 0 ]; then
        echo "❌ Erreur lors de la création de l'environnement virtuel"
        echo "📋 Vérifiez que Python est installé et accessible"
        exit 1
    fi
    echo "✅ Environnement virtuel créé avec succès!"
fi

# Activer l'environnement virtuel
echo "🚀 Activation de l'environnement virtuel..."

ACTIVATE_SCRIPT="$VENV_PATH/Scripts/activate"

# Pour Git Bash ou WSL, essayer différents chemins
if [ ! -f "$ACTIVATE_SCRIPT" ]; then
    ACTIVATE_SCRIPT="$VENV_PATH/bin/activate"
fi

if [ -f "$ACTIVATE_SCRIPT" ]; then
    # Exécuter le script d'activation
    source "$ACTIVATE_SCRIPT"
    
    # Afficher les informations
    echo "✅ Environnement virtuel activé avec succès!"
    echo "📍 Chemin: $VENV_PATH"
    echo "🐍 Python: $(python --version)"
    echo "📦 Pip: $(pip --version)"
    
    # Afficher les packages installés
    echo ""
    echo "📦 Packages installés:"
    pip list
    
    echo ""
    echo "🎯 L'environnement est prêt!"
    echo "💡 Pour désactiver: deactivate"
else
    echo "❌ Script d'activation non trouvé: $ACTIVATE_SCRIPT"
    exit 1
fi
