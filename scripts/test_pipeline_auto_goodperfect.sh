#!/bin/bash
# Test pipeline auto Good/Perfect

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST: Pipeline Auto Good/Perfect"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$(dirname "$0")/.."

# Vérifier ai_server
echo "1️⃣  Vérification ai_server..."
if ! curl -s http://127.0.0.1:8000/health > /dev/null; then
    echo "❌ ai_server non accessible sur http://127.0.0.1:8000"
    echo "   Lancer: python Python/ai_server.py"
    exit 1
fi
echo "✅ ai_server OK"
echo ""

# Vérifier GOM verdicts
echo "2️⃣  Vérification GOM verdicts..."
if ! curl -s http://127.0.0.1:8000/gom-verdicts > /dev/null; then
    echo "❌ /gom-verdicts non accessible"
    exit 1
fi
echo "✅ GOM verdicts OK"
echo ""

# Test dry-run
echo "3️⃣  Lancement pipeline en DRY-RUN..."
python Python/pipeline_auto_goodperfect.py --top-n 3 --dry-run
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Tests complétés"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Pour lancer en mode PRODUCTION (placement ordres réels):"
echo "  python Python/pipeline_auto_goodperfect.py --top-n 3"
