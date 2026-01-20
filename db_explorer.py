import asyncpg
import asyncio
import pandas as pd
import os
import sys

DATABASE_URL = "postgresql://koladb_user:wYkUIyTb53vWEygkyia3YZiJNIdonmOt@dpg-d5nje68gjchc739d0dug-a.oregon-postgres.render.com/koladb_rurl"

async def list_tables():
    conn = await asyncpg.connect(DATABASE_URL)
    tables = await conn.fetch("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public'
    """)
    print("Tables in database:")
    for row in tables:
        print(f"- {row['table_name']}")
    await conn.close()
    return [row['table_name'] for row in tables]

async def export_table_to_csv(table_name, filename):
    conn = await asyncpg.connect(DATABASE_URL)
    print(f"Exporting table {table_name} to {filename}...")
    rows = await conn.fetch(f'SELECT * FROM "{table_name}"')
    
    if not rows:
        print(f"No data found in table {table_name}")
        await conn.close()
        return

    # Convert to list of dicts for pandas
    data = [dict(row) for row in rows]
    df = pd.DataFrame(data)
    df.to_csv(filename, index=False)
    print(f"Successfully exported {len(rows)} rows to {filename}")
    await conn.close()

async def main():
    tables = await list_tables()
    if not tables:
        print("No tables found.")
        return
    
    # Identify the likely trade/feedback table
    trade_tables = [t for t in tables if 'trade' in t.lower() or 'feedback' in t.lower()]
    
    if trade_tables:
        for t in trade_tables:
            await export_table_to_csv(t, f"{t}_export.csv")
    else:
        # If no specific table found, export the first one found just in case
        await export_table_to_csv(tables[0], f"{tables[0]}_export.csv")

if __name__ == "__main__":
    asyncio.run(main())
