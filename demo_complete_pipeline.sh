#!/bin/bash
echo "=========================================="
echo "🚀 TradBOT COMPLETE AUTONOMOUS PIPELINE"
echo "=========================================="
echo ""

cd D:/Dev/TradBOT

# Step 1: GOM Sync with WhatsApp Report
echo "[STEP 1/2] 📊 GOM Sync + WhatsApp Report"
echo "Command: python Python/gom_sync_with_report.py --report"
python Python/gom_sync_with_report.py --report 2>&1 | tail -10
echo ""

# Step 2: Pipeline Hourly with Word Report
echo "[STEP 2/2] 🎯 Pipeline Hourly + Word Report Generation"
echo "Command: python Python/pipeline_hourly_autonomous.py --once"
python Python/pipeline_hourly_autonomous.py --once 2>&1 | grep -E "Order|REPORT|Success|Error|docx|WhatsApp" | tail -15
echo ""

# Show generated files
echo "=========================================="
echo "📁 Generated Reports:"
ls -lh logs/*.docx logs/*.log 2>/dev/null | tail -5
echo "=========================================="

