"""
Apply Career-Ops migrations to AWS RDS PostgreSQL
Uses existing DATABASE_URL from .env
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent.parent / ".env")

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    print("[ERROR] DATABASE_URL not found in .env")
    print("[ACTION] Add to .env: DATABASE_URL=postgresql://user:pass@host:5432/tradbot")
    sys.exit(1)

print("[INFO] Found DATABASE_URL (AWS RDS)")
print(f"      Host: {DATABASE_URL.split('@')[1].split(':')[0] if '@' in DATABASE_URL else 'unknown'}")


def apply_migration():
    """Execute migration on AWS RDS"""

    try:
        import psycopg2
    except ImportError:
        print("[ERROR] psycopg2 not installed")
        print("[ACTION] Run: pip install psycopg2-binary")
        return False

    migration_file = Path(__file__).parent / "migrations" / "001_career_ops_schema_rds.sql"

    if not migration_file.exists():
        print(f"[ERROR] Migration file not found: {migration_file}")
        return False

    # Read migration SQL
    with open(migration_file, 'r') as f:
        sql = f.read()

    print(f"[INFO] Applying migration from: {migration_file.name}")
    print()

    try:
        # Connect to RDS
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()

        print("[ACTION] Executing SQL statements...")

        # Split by semicolon and execute
        statements = [s.strip() for s in sql.split(';') if s.strip()]

        for i, stmt in enumerate(statements, 1):
            print(f"  [{i}/{len(statements)}] {stmt[:60]}...")
            cursor.execute(stmt)

        conn.commit()
        cursor.close()
        conn.close()

        print()
        print("[SUCCESS] Migration completed!")
        print()

        # Verify tables
        verify_connection = psycopg2.connect(DATABASE_URL)
        verify_cursor = verify_connection.cursor()

        verify_cursor.execute("""
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = 'career_ops'
            ORDER BY table_name
        """)

        tables = verify_cursor.fetchall()
        verify_cursor.close()
        verify_connection.close()

        print("[VERIFICATION] Tables created in career_ops schema:")
        for (table_name,) in tables:
            print(f"  - {table_name}")

        if len(tables) == 5:
            print("\n[OK] All 5 Career-Ops tables created successfully! ✅")
            return True
        else:
            print(f"\n[WARNING] Only {len(tables)}/5 tables created")
            return False

    except Exception as e:
        print(f"[ERROR] Migration failed: {str(e)}")
        return False


if __name__ == "__main__":
    print("=" * 70)
    print("Career-Ops AWS RDS Migration")
    print("=" * 70)
    print()

    success = apply_migration()

    print()
    print("=" * 70)
    if success:
        print("MIGRATION COMPLETE [OK]")
    else:
        print("MIGRATION FAILED [ERROR]")
    print("=" * 70)

    sys.exit(0 if success else 1)
