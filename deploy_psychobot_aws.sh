#!/bin/bash
# PsychoBot AWS Transcribe Deployment Script
# Automates the migration to AWS Transcribe

set -e  # Exit on error

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         PSYCHOBOT AWS TRANSCRIBE DEPLOYMENT                          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
PSYCHOBOT_DIR="D:/Dev/Depot Github/Psychobot"
TRADBOT_DIR="D:/Dev/TradBOT"

echo "📍 PsychoBot Directory: $PSYCHOBOT_DIR"
echo "📍 TradBOT Directory: $TRADBOT_DIR"
echo ""

# Step 1: Check if PsychoBot directory exists
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Checking PsychoBot Directory"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -d "$PSYCHOBOT_DIR" ]; then
    echo -e "${RED}❌ PsychoBot directory not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ PsychoBot directory found${NC}"
echo ""

# Step 2: Copy AWS Transcribe solution
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Copying AWS Transcribe Solution"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SOURCE_FILE="$TRADBOT_DIR/psychobot_aws_transcribe_solution.js"
DEST_DIR="$PSYCHOBOT_DIR/src/services"
DEST_FILE="$DEST_DIR/aws-transcribe.js"

if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${RED}❌ Source file not found: $SOURCE_FILE${NC}"
    exit 1
fi

mkdir -p "$DEST_DIR"
cp "$SOURCE_FILE" "$DEST_FILE"

echo -e "${GREEN}✅ Copied: aws-transcribe.js${NC}"
echo "   → $DEST_FILE"
echo ""

# Step 3: Install AWS SDK dependencies
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Installing AWS SDK Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$PSYCHOBOT_DIR"

if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ package.json not found!${NC}"
    exit 1
fi

echo "📦 Installing @aws-sdk/client-transcribe-streaming..."
npm install @aws-sdk/client-transcribe-streaming --save

echo "📦 Installing @aws-sdk/client-bedrock-runtime..."
npm install @aws-sdk/client-bedrock-runtime --save

echo -e "${GREEN}✅ AWS SDK dependencies installed${NC}"
echo ""

# Step 4: Backup audioProcessor.js
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Backing Up audioProcessor.js"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

AUDIO_PROCESSOR="$PSYCHOBOT_DIR/src/services/audioProcessor.js"
BACKUP_FILE="$AUDIO_PROCESSOR.backup-$(date +%Y%m%d-%H%M%S)"

if [ -f "$AUDIO_PROCESSOR" ]; then
    cp "$AUDIO_PROCESSOR" "$BACKUP_FILE"
    echo -e "${GREEN}✅ Backup created${NC}"
    echo "   → $BACKUP_FILE"
else
    echo -e "${YELLOW}⚠️  audioProcessor.js not found (will be created)${NC}"
fi

echo ""

# Step 5: Show manual modification instructions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Manual Modification Required"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo -e "${YELLOW}⚠️  MANUAL ACTION REQUIRED${NC}"
echo ""
echo "Edit: $AUDIO_PROCESSOR"
echo ""
echo "Add at top (after other requires):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "const { transcribeAudioAWS } = require('./aws-transcribe');"
echo ""
echo "Find function: transcribeAudioOpenAI(wavPath)"
echo ""
echo "Add new function BEFORE it:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat << 'EOF'
async function transcribeAudio(wavPath) {
    console.log('[Transcribe] Trying AWS Transcribe...');

    // Try AWS Transcribe first
    if (process.env.AWS_ACCESS_KEY_ID) {
        try {
            const awsResult = await transcribeAudioAWS(wavPath, 'fr-FR');
            if (awsResult.success) {
                console.log('[Transcribe] AWS Success:', awsResult.text);
                return awsResult.text;
            }
        } catch (e) {
            console.log('[Transcribe] AWS failed:', e.message);
        }
    }

    // Fallback to OpenAI
    console.log('[Transcribe] Trying OpenAI fallback...');
    if (process.env.OPENAI_API_KEY) {
        return await transcribeAudioOpenAI(wavPath);
    }

    throw new Error('No transcription service available');
}
EOF

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Find line: const transcript = await transcribeAudioOpenAI(wavPath);"
echo "Replace with: const transcript = await transcribeAudio(wavPath);"
echo ""

# Step 6: Show Render configuration instructions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Configure Render Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "1. Go to: https://dashboard.render.com"
echo "2. Select service: psychobot-1si7"
echo "3. Click: Environment tab"
echo "4. Add these variables:"
echo ""
echo "   AWS_ACCESS_KEY_ID = YOUR_AWS_ACCESS_KEY_ID"
echo "   AWS_SECRET_ACCESS_KEY = YOUR_AWS_SECRET_ACCESS_KEY"
echo "   AWS_REGION = us-east-1"
echo ""
echo "5. Click: Save Changes"
echo "6. Wait for automatic redeploy (~3 minutes)"
echo ""

# Step 7: Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "DEPLOYMENT SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo -e "${GREEN}✅ Files copied${NC}"
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo -e "${YELLOW}⏳ Manual modifications required${NC}"
echo -e "${YELLOW}⏳ Render configuration required${NC}"
echo ""

echo "📋 CHECKLIST:"
echo "   [ ] Edit audioProcessor.js (add AWS transcribe function)"
echo "   [ ] Commit changes to git"
echo "   [ ] Push to GitHub"
echo "   [ ] Add AWS env vars in Render dashboard"
echo "   [ ] Wait for Render redeploy"
echo "   [ ] Test voice message: +229 01 96 91 13 46"
echo ""

echo "📚 DOCUMENTATION:"
echo "   → $TRADBOT_DIR/PSYCHOBOT_AWS_MIGRATION_GUIDE.md"
echo "   → $TRADBOT_DIR/PSYCHOBOT_FIX_INSTRUCTIONS.txt"
echo ""

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    DEPLOYMENT PREPARATION COMPLETE                   ║"
echo "║                Follow manual steps above to finish                   ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
