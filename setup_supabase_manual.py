#!/usr/bin/env python3
"""
Script final pour créer les tables Supabase via l'API REST standard
Utilise les endpoints REST pour créer les tables directement
"""

import os
import requests
import logging
from datetime import datetime

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration Supabase
SUPABASE_URL = "https://bpzqnooiisgadzicwupi.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4"
SUPABASE_PROJECT_ID = "bpzqnooiisgadzicwupi"
SUPABASE_PASSWORD = "Socrate2025@1991"

def create_tables_via_sql_editor():
    """Créer les tables via l'API SQL Editor de Supabase"""
    logger.info("🔧 Création des tables via API SQL Editor...")
    
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json"
    }
    
    # SQL pour créer les tables
    create_tables_sql = """
    -- Table trade_feedback
    CREATE TABLE IF NOT EXISTS trade_feedback (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        open_time TIMESTAMPTZ NOT NULL,
        close_time TIMESTAMPTZ,
        entry_price DECIMAL(15,5),
        exit_price DECIMAL(15,5),
        profit DECIMAL(15,5),
        ai_confidence DECIMAL(5,4),
        coherent_confidence DECIMAL(5,4),
        decision TEXT,
        is_win BOOLEAN,
        created_at TIMESTAMPTZ DEFAULT now(),
        timeframe TEXT DEFAULT 'M1',
        side TEXT
    );
    
    CREATE INDEX IF NOT EXISTS idx_trade_feedback_symbol ON trade_feedback(symbol);
    CREATE INDEX IF NOT EXISTS idx_trade_feedback_created_at ON trade_feedback(created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_trade_feedback_timeframe ON trade_feedback(timeframe);
    
    -- Table predictions
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        timeframe TEXT NOT NULL,
        prediction TEXT NOT NULL,
        confidence DECIMAL(5,4),
        reason TEXT,
        created_at TIMESTAMPTZ DEFAULT now(),
        model_used TEXT,
        metadata JSONB
    );
    
    CREATE INDEX IF NOT EXISTS idx_predictions_symbol ON predictions(symbol);
    CREATE INDEX IF NOT EXISTS idx_predictions_created_at ON predictions(created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_predictions_timeframe ON predictions(timeframe);
    
    -- Table symbol_calibration
    CREATE TABLE IF NOT EXISTS symbol_calibration (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        timeframe TEXT DEFAULT 'M1',
        wins INTEGER DEFAULT 0,
        total INTEGER DEFAULT 0,
        drift_factor DECIMAL(10,6) DEFAULT 1.0,
        last_updated TIMESTAMPTZ DEFAULT now(),
        metadata JSONB
    );
    
    CREATE INDEX IF NOT EXISTS idx_symbol_calibration_symbol ON symbol_calibration(symbol);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_symbol_calibration_unique ON symbol_calibration(symbol, timeframe);
    
    -- Table ai_decisions
    CREATE TABLE IF NOT EXISTS ai_decisions (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        action TEXT NOT NULL,
        confidence DECIMAL(5,4),
        reason TEXT,
        created_at TIMESTAMPTZ DEFAULT now(),
        model_used TEXT,
        metadata JSONB
    );
    
    CREATE INDEX IF NOT EXISTS idx_ai_decisions_symbol ON ai_decisions(symbol);
    CREATE INDEX IF NOT EXISTS idx_ai_decisions_created_at ON ai_decisions(created_at DESC);
    """
    
    try:
        # Utiliser l'endpoint SQL de Supabase
        url = f"{SUPABASE_URL}/rest/v1/rpc/sql"
        
        payload = {
            "query": create_tables_sql
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            logger.info("✅ Tables créées avec succès!")
            logger.info(f"📊 Résultat: {result}")
            return True
        else:
            logger.error(f"❌ Erreur création tables: {response.status_code}")
            logger.error(f"📝 Response: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur création tables: {e}")
        return False

def create_tables_via_direct_sql():
    """Créer les tables via l'endpoint direct SQL"""
    logger.info("🔧 Création des tables via endpoint SQL direct...")
    
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json"
    }
    
    # SQL simplifié
    create_tables_sql = """
    CREATE TABLE IF NOT EXISTS trade_feedback (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        open_time TIMESTAMPTZ NOT NULL,
        close_time TIMESTAMPTZ,
        entry_price DECIMAL(15,5),
        exit_price DECIMAL(15,5),
        profit DECIMAL(15,5),
        ai_confidence DECIMAL(5,4),
        coherent_confidence DECIMAL(5,4),
        decision TEXT,
        is_win BOOLEAN,
        created_at TIMESTAMPTZ DEFAULT now(),
        timeframe TEXT DEFAULT 'M1',
        side TEXT
    );
    
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        timeframe TEXT NOT NULL,
        prediction TEXT NOT NULL,
        confidence DECIMAL(5,4),
        reason TEXT,
        created_at TIMESTAMPTZ DEFAULT now(),
        model_used TEXT,
        metadata JSONB
    );
    
    CREATE TABLE IF NOT EXISTS symbol_calibration (
        id SERIAL PRIMARY KEY,
        symbol TEXT NOT NULL,
        timeframe TEXT DEFAULT 'M1',
        wins INTEGER DEFAULT 0,
        total INTEGER DEFAULT 0,
        drift_factor DECIMAL(10,6) DEFAULT 1.0,
        last_updated TIMESTAMPTZ DEFAULT now(),
        metadata JSONB
    );
    """
    
    try:
        # Essayer l'endpoint SQL
        url = f"{SUPABASE_URL}/sql"
        
        payload = {
            "query": create_tables_sql
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            logger.info("✅ Tables créées avec succès!")
            logger.info(f"📊 Résultat: {result}")
            return True
        else:
            logger.error(f"❌ Erreur création tables: {response.status_code}")
            logger.error(f"📝 Response: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur création tables: {e}")
        return False

def test_basic_connection():
    """Tester la connexion de base à Supabase"""
    logger.info("🔍 Test de connexion de base à Supabase...")
    
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json"
    }
    
    try:
        # Test simple
        url = f"{SUPABASE_URL}/rest/v1/"
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            logger.info("✅ Connexion de base réussie!")
            return True
        else:
            logger.error(f"❌ Erreur connexion: {response.status_code}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Erreur test connexion: {e}")
        return False

def create_manual_setup_instructions():
    """Créer des instructions manuelles pour la configuration"""
    logger.info("📝 Création des instructions manuelles...")
    
    instructions = f"""# INSTRUCTIONS MANUELLES POUR CONFIGURATION SUPABASE
# KolaTradeBoT - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## ÉTAPE 1: Accéder au dashboard Supabase
1. Allez sur: https://supabase.com/dashboard
2. Connectez-vous avec votre compte
3. Sélectionnez le projet: KolaTradeBoT (bpzqnooiisgadzicwupi)

## ÉTAPE 2: Créer les tables manuellement
1. Cliquez sur "SQL Editor" dans le menu de gauche
2. Copiez et collez le SQL ci-dessous:

```sql
-- Table trade_feedback
CREATE TABLE IF NOT EXISTS trade_feedback (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    open_time TIMESTAMPTZ NOT NULL,
    close_time TIMESTAMPTZ,
    entry_price DECIMAL(15,5),
    exit_price DECIMAL(15,5),
    profit DECIMAL(15,5),
    ai_confidence DECIMAL(5,4),
    coherent_confidence DECIMAL(5,4),
    decision TEXT,
    is_win BOOLEAN,
    created_at TIMESTAMPTZ DEFAULT now(),
    timeframe TEXT DEFAULT 'M1',
    side TEXT
);

CREATE INDEX IF NOT EXISTS idx_trade_feedback_symbol ON trade_feedback(symbol);
CREATE INDEX IF NOT EXISTS idx_trade_feedback_created_at ON trade_feedback(created_at DESC);

-- Table predictions
CREATE TABLE IF NOT EXISTS predictions (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    prediction TEXT NOT NULL,
    confidence DECIMAL(5,4),
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    model_used TEXT,
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_predictions_symbol ON predictions(symbol);
CREATE INDEX IF NOT EXISTS idx_predictions_created_at ON predictions(created_at DESC);

-- Table symbol_calibration
CREATE TABLE IF NOT EXISTS symbol_calibration (
    id SERIAL PRIMARY KEY,
    symbol TEXT NOT NULL,
    timeframe TEXT DEFAULT 'M1',
    wins INTEGER DEFAULT 0,
    total INTEGER DEFAULT 0,
    drift_factor DECIMAL(10,6) DEFAULT 1.0,
    last_updated TIMESTAMPTZ DEFAULT now(),
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_symbol_calibration_symbol ON symbol_calibration(symbol);
CREATE UNIQUE INDEX IF NOT EXISTS idx_symbol_calibration_unique ON symbol_calibration(symbol, timeframe);
```

3. Cliquez sur "Run" pour exécuter le SQL

## ÉTAPE 3: Configurer l'environnement
1. Copiez .env.supabase vers .env:
   ```
   cp .env.supabase .env
   ```

2. Modifiez .env pour utiliser votre configuration

## ÉTAPE 4: Mettre à jour le serveur
1. Lancez la mise à jour:
   ```
   python update_ai_server_supabase.py
   ```

2. Démarrez le serveur:
   ```
   python ai_server.py
   ```

## ÉTAPE 5: Vérification
1. Testez le serveur:
   ```
   curl http://localhost:8000/health
   ```

## URL de connexion à utiliser:
- **URL**: {SUPABASE_URL}
- **Project ID**: {SUPABASE_PROJECT_ID}
- **Password**: {SUPABASE_PASSWORD}
- **Database**: postgres
- **Port**: 5432
- **Host**: aws-0-eu-central-1.pooler.supabase.com

## Format DATABASE_URL final:
```
postgresql://postgres:{SUPABASE_PASSWORD}@aws-0-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require
```
"""
    
    with open("MANUAL_SETUP_SUPABASE.md", "w", encoding="utf-8") as f:
        f.write(instructions)
    
    logger.info("✅ Instructions manuelles créées: MANUAL_SETUP_SUPABASE.md")
    return "MANUAL_SETUP_SUPABASE.md"

def main():
    """Fonction principale"""
    logger.info("🚀 CONFIGURATION SUPABASE - SOLUTION MANUELLE")
    logger.info("=" * 60)
    
    # Étape 1: Tester la connexion
    if test_basic_connection():
        logger.info("✅ Connexion API Supabase fonctionnelle!")
        
        # Étape 2: Essayer de créer les tables automatiquement
        logger.info("🔧 Tentative de création automatique des tables...")
        
        # Essayer différentes méthodes
        if create_tables_via_sql_editor():
            logger.info("✅ Tables créées automatiquement!")
        elif create_tables_via_direct_sql():
            logger.info("✅ Tables créées via SQL direct!")
        else:
            logger.info("ℹ️ Création automatique échouée - Instructions manuelles requises")
    
    # Étape 3: Créer les instructions manuelles
    manual_file = create_manual_setup_instructions()
    
    logger.info("🎉 CONFIGURATION PRÊTE!")
    logger.info("📋 Résumé:")
    logger.info("   • Connexion API: ✅")
    logger.info(f"   • Instructions: {manual_file}")
    
    logger.info("📝 Prochaines étapes:")
    logger.info("1. Suivez les instructions dans MANUAL_SETUP_SUPABASE.md")
    logger.info("2. Configurez le serveur pour Supabase")
    logger.info("3. Démarrez le serveur")

if __name__ == "__main__":
    main()
