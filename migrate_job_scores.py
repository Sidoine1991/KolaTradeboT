#!/usr/bin/env python3
"""
Migration script to add missing columns to job_scores table
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

# Use psycopg2 directly with SSL disabled
import psycopg2
from psycopg2 import sql

print('[INFO] Connecting to RDS PostgreSQL...')

try:
    conn = psycopg2.connect(
        host=os.getenv('AWS_RDS_HOST'),
        port=int(os.getenv('AWS_RDS_PORT', 5432)),
        database=os.getenv('AWS_RDS_DATABASE', 'psychobot'),
        user=os.getenv('AWS_RDS_USER'),
        password=os.getenv('AWS_RDS_PASSWORD'),
        sslmode='disable'  # Disable SSL for local testing
    )

    cursor = conn.cursor()
    print('[OK] Connected to RDS')
    print('')

    # Get existing columns
    cursor.execute('''
        SELECT column_name FROM information_schema.columns
        WHERE table_name='job_scores' AND table_schema='psychobot'
        ORDER BY column_name
    ''')

    existing_cols = {row[0] for row in cursor.fetchall()}
    print(f'[INFO] Found {len(existing_cols)} existing columns:')
    for col in sorted(existing_cols):
        print(f'       - {col}')

    print('')
    print('[ACTION] Adding missing columns...')

    # Define migrations
    migrations = [
        ('source', 'VARCHAR(50)'),
        ('job_url', 'TEXT'),
        ('posted_date', 'TIMESTAMP'),
        ('reviewed_date', 'TIMESTAMP'),
        ('status', "VARCHAR(50) DEFAULT 'PENDING_REVIEW'")
    ]

    added = 0
    for col, dtype in migrations:
        if col not in existing_cols:
            try:
                sql_stmt = f'ALTER TABLE psychobot.job_scores ADD COLUMN {col} {dtype}'
                cursor.execute(sql_stmt)
                print(f'       [+] {col} ({dtype})')
                added += 1
            except Exception as e:
                print(f'       [!] {col}: {str(e)[:60]}')
        else:
            print(f'       [~] {col} (already exists)')

    conn.commit()
    cursor.close()
    conn.close()

    print('')
    print(f'[OK] Migration complete! ({added} columns added)')

except Exception as e:
    print(f'[ERROR] {e}')
    import traceback
    traceback.print_exc()
