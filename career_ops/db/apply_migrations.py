"""
Apply database migrations for Career-Ops
Displays SQL to execute manually in Supabase console
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Load environment
load_dotenv(Path(__file__).parent.parent.parent / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("[ERROR] Missing SUPABASE_URL or SUPABASE_KEY in .env")
    sys.exit(1)


def get_migration_sql(migration_file):
    """Read migration SQL file"""
    try:
        with open(migration_file, 'r') as f:
            return f.read()
    except Exception as e:
        print(f"[ERROR] Could not read migration: {str(e)}")
        return None


def main():
    """Display migration instructions"""

    print("=" * 70)
    print("Career-Ops Database Migration")
    print("=" * 70)
    print()

    # Get migration SQL
    migration_dir = Path(__file__).parent / "migrations"
    migrations = sorted(migration_dir.glob("*.sql"))

    if not migrations:
        print("[ERROR] No migrations found in", migration_dir)
        return

    print(f"[INFO] Found {len(migrations)} migration(s)")
    print()

    # Display instructions
    print("STEP 1: Go to Supabase Console")
    print("-" * 70)
    print(f"  URL: {SUPABASE_URL}")
    print()

    print("STEP 2: Execute Migration SQL")
    print("-" * 70)

    for mig in migrations:
        print(f"\n>>> File: {mig.name}")
        sql_content = get_migration_sql(mig)
        if not sql_content:
            continue

        print("\nOption A: Supabase Web Console (Easiest)")
        print("  1. Go to SQL Editor tab")
        print("  2. Click '+ New Query'")
        print("  3. Paste SQL below")
        print("  4. Click 'Run' button")
        print()
        print("Option B: Save to file and run via pgAdmin/psql")
        print()
        print("[SQL]")
        print("-" * 70)
        print(sql_content)
        print("-" * 70)

    print()
    print("STEP 3: Verify")
    print("-" * 70)
    print("  Check Supabase console for:")
    print("    ✓ career_profile table")
    print("    ✓ jobs table")
    print("    ✓ job_matches table")
    print("    ✓ scraper_runs table")
    print("    ✓ applications table")
    print()

    # Save to file for convenience
    output_file = migration_dir.parent / "migration_manual.sql"
    try:
        with open(output_file, 'w') as f:
            for mig in migrations:
                sql_content = get_migration_sql(mig)
                if sql_content:
                    f.write(sql_content)
                    f.write("\n\n")
        print(f"[SAVED] All migrations exported to: {output_file}")
    except Exception as e:
        print(f"[WARNING] Could not save: {str(e)}")

    print()


if __name__ == "__main__":
    main()
