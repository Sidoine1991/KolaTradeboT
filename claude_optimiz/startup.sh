#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TradBOT v3.0 - STARTUP SCRIPT (Linux/Mac/Git Bash Windows)
# ═══════════════════════════════════════════════════════════════════════════════

echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║             TradBOT v3.0 - Démarrage MACHINE DE GUERRE                        ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"

# Vérifications
echo ""
echo "[1/4] Vérification Python..."
python --version || exit 1

echo ""
echo "[2/4] Vérification Ollama..."
curl -s http://127.0.0.1:11434/api/tags > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Ollama est online sur 127.0.0.1:11434"
else
    echo "❌ Ollama non trouvé sur 127.0.0.1:11434"
    echo "   Démarrer: ollama serve"
    exit 1
fi

echo ""
echo "[3/4] Installation dépendances Python..."
pip install --quiet fastapi uvicorn requests pydantic
echo "✅ Dépendances OK"

echo ""
echo "[4/4] Démarrage serveur IA..."
export TRADER_PORT=8000
python ai_server_v3_OPTIMIZED.py &
SERVER_PID=$!

sleep 2

# Vérifier que le serveur a démarré
curl -s http://127.0.0.1:8000/health > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Serveur IA démarré (PID: $SERVER_PID) sur port 8000"
else
    echo "❌ Serveur IA n'a pas démarré"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║                        ✅ MACHINE DE GUERRE PRÊTE!                            ║"
echo "╠═══════════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                                 ║"
echo "║  Ollama:       http://127.0.0.1:11434  ✅                                      ║"
echo "║  Serveur IA:   http://127.0.0.1:8000   ✅                                      ║"
echo "║                                                                                 ║"
echo "║  Étapes suivantes:                                                             ║"
echo "║  1. Lancer MT5                                                                 ║"
echo "║  2. Charger les robots compilés                                                ║"
echo "║  3. Vérifier \"✅ AI Server ONLINE\" dans le Comment                            ║"
echo "║  4. TRADER!                                                                    ║"
echo "║                                                                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"

# Garder le serveur actif
wait $SERVER_PID
