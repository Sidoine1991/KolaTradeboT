#!/bin/bash
# Prepare Career-Ops for Render deployment

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Career-Ops Service - Render Deployment Preparation      ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Check required files
echo ""
echo "[1/5] Checking required files..."

files=(
    "career_ops_service.py"
    "career_ops_api_rds.py"
    "career_ops_scheduler_rds.py"
    "career_ops/repositories/rds_repositories.py"
    "requirements-career-ops.txt"
    "Procfile-career-ops"
)

all_exist=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "  [OK] $file"
    else
        echo "  [ERROR] $file NOT FOUND"
        all_exist=false
    fi
done

if [ "$all_exist" = false ]; then
    echo ""
    echo "[ERROR] Some files are missing. Aborting."
    exit 1
fi

echo ""
echo "[2/5] Verifying Python dependencies..."

# Check if requirements file is valid
if grep -q "fastapi" requirements-career-ops.txt; then
    echo "  [OK] FastAPI dependency found"
else
    echo "  [ERROR] FastAPI not in requirements"
    exit 1
fi

if grep -q "psycopg2" requirements-career-ops.txt; then
    echo "  [OK] PostgreSQL driver found"
else
    echo "  [ERROR] psycopg2 not in requirements"
    exit 1
fi

echo ""
echo "[3/5] Checking Procfile..."

if [ -f "Procfile-career-ops" ]; then
    echo "  [OK] Procfile-career-ops exists"
    echo ""
    echo "  Content:"
    cat Procfile-career-ops | sed 's/^/    /'
else
    echo "  [ERROR] Procfile-career-ops not found"
    exit 1
fi

echo ""
echo "[4/5] Preparing git..."

echo "  Files to commit:"
echo "    - career_ops_service.py"
echo "    - career_ops_api_rds.py"
echo "    - career_ops_scheduler_rds.py"
echo "    - requirements-career-ops.txt"
echo "    - Procfile-career-ops"

echo ""
echo "[5/5] Next steps..."

echo ""
echo "✓ All files ready for Render deployment!"
echo ""
echo "To deploy on Render:"
echo ""
echo "  1. Push code to GitHub:"
echo "     git add career_ops_service.py career_ops_api_rds.py ..."
echo "     git commit -m 'feat: Career-Ops service for Render'"
echo "     git push"
echo ""
echo "  2. Create Web Service on Render:"
echo "     - Connect GitHub repo (TradBOT)"
echo "     - Build Command: pip install -r requirements-career-ops.txt"
echo "     - Start Command: python career_ops_service.py"
echo ""
echo "  3. Set environment variables in Render:"
echo "     DATABASE_URL=..."
echo "     PSYCHOBOT_URL=..."
echo "     WHATSAPP_PHONE=..."
echo "     EMAIL_ADDRESS=..."
echo "     PORT=8001"
echo ""
echo "  4. Deploy (Render auto-deploys from GitHub)"
echo ""
echo "  5. Verify:"
echo "     curl https://career-ops-xxxxx.onrender.com/health"
echo ""
echo "✓ See DEPLOY_CAREEROPS_RENDER.md for detailed instructions"
echo ""
