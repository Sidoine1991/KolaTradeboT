import argparse
import csv
import os
import re
import sys
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

import pandas as pd
import psycopg2
from dotenv import load_dotenv
from urllib.parse import urlparse, urlunparse

# Excel limite ~1 048 576 lignes ; marge pour en-têtes / robustesse.
_EXCEL_MAX_ROWS = 1_040_000


def _load_env() -> None:
    project_root = os.path.abspath(os.path.dirname(__file__))
    env_default = os.path.join(project_root, ".env")
    env_supabase = os.path.join(project_root, ".env.supabase")
    if os.path.exists(env_default):
        try:
            load_dotenv(env_default, encoding="utf-8")
        except UnicodeDecodeError:
            load_dotenv(env_default, encoding="cp1252")
    if os.path.exists(env_supabase):
        try:
            load_dotenv(env_supabase, encoding="utf-8")
        except UnicodeDecodeError:
            load_dotenv(env_supabase, encoding="cp1252")
    load_dotenv()


def _safe_filename(name: str) -> str:
    s = re.sub(r'[<>:"/\\|?*]', "_", name)
    return s[:120] if s else "table"


def _get_conn():
    db_url = os.getenv("DATABASE_URL") or os.getenv("SUPABASE_DB_URL") or ""
    if not db_url:
        raise RuntimeError("DATABASE_URL manquant (.env)")
    # psycopg2 accepte une DSN url "postgresql://..."
    try:
        return psycopg2.connect(db_url)
    except psycopg2.OperationalError as e:
        # Certains endpoints Supabase (pooler) exigent:
        # - user "postgres.<project_ref>"
        # - et parfois le port 6543 (transaction pooler)
        # Si DATABASE_URL est partiel, on tente quelques variantes sûres.
        msg = str(e).lower()
        p = urlparse(db_url)
        host = p.hostname or ""
        project_ref = os.getenv("SUPABASE_PROJECT_ID") or os.getenv("SUPABASE_REF") or ""
        user = p.username or ""
        pw = p.password or ""
        path = p.path or "/postgres"

        candidates: List[str] = []
        # 1) Essai pooler user tenant (même port)
        if project_ref and user == "postgres" and "pooler.supabase.com" in host:
            fixed_user = f"postgres.{project_ref}"
            port = p.port or 5432
            candidates.append(
                urlunparse(
                    (p.scheme, f"{fixed_user}:{pw}@{host}:{port}", path, p.params, p.query, p.fragment)
                )
            )
            # 2) Essai pooler sur port 6543
            candidates.append(
                urlunparse(
                    (p.scheme, f"{fixed_user}:{pw}@{host}:6543", path, p.params, p.query, p.fragment)
                )
            )

        # 3) Essai direct DB host db.<ref>.supabase.co
        if project_ref:
            direct_host = f"db.{project_ref}.supabase.co"
            direct_user = "postgres"
            candidates.append(
                urlunparse((p.scheme, f"{direct_user}:{pw}@{direct_host}:5432", path, p.params, p.query, p.fragment))
            )

        last_err: Optional[BaseException] = e
        if "tenant or user not found" in msg and candidates:
            for cand in candidates:
                try:
                    return psycopg2.connect(cand)
                except psycopg2.OperationalError as ee:
                    last_err = ee
        if last_err:
            raise last_err
        raise


def _list_public_tables(cur) -> List[str]:
    cur.execute(
        """
        select table_name
        from information_schema.tables
        where table_schema = 'public'
          and table_type = 'BASE TABLE'
        order by table_name
        """
    )
    return [r[0] for r in cur.fetchall()]


def _table_rowcount(cur, table: str) -> int:
    cur.execute(f'SELECT COUNT(*) FROM "public"."{table}"')
    return int(cur.fetchone()[0])


def _export_table_copy_csv(cur, table: str, out_path: str) -> Tuple[int, Optional[str]]:
    """
    Export rapide côté serveur via COPY TO STDOUT.
    Retourne (rows_estimated, error). Le nombre exact de lignes est calculé via compteur simple.
    """
    try:
        with open(out_path, "w", newline="", encoding="utf-8") as fp:
            cur.copy_expert(f'COPY "public"."{table}" TO STDOUT WITH CSV HEADER', fp)
        # compter lignes (hors header)
        with open(out_path, "r", encoding="utf-8") as fp:
            reader = csv.reader(fp)
            _ = next(reader, None)
            n = sum(1 for _ in reader)
        return n, None
    except Exception as e:
        return 0, repr(e)


def _export_table_xlsx(conn, table: str, out_path: str) -> Tuple[int, Optional[str]]:
    try:
        df = pd.read_sql_query(f'SELECT * FROM "public"."{table}"', conn)
        df.to_excel(out_path, index=False, engine="openpyxl")
        return int(df.shape[0]), None
    except Exception as e:
        return 0, repr(e)


def _truncate_all(cur, tables: List[str]) -> None:
    if not tables:
        return
    # TRUNCATE multi-table + CASCADE gère les FK ; RESTART IDENTITY remet les sequences.
    quoted = ", ".join([f'"public"."{t}"' for t in tables])
    cur.execute(f"TRUNCATE TABLE {quoted} RESTART IDENTITY CASCADE;")


def main(argv: List[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Export des tables public via connexion DB (DATABASE_URL), puis purge via TRUNCATE."
    )
    parser.add_argument("--export-only", action="store_true", help="Export uniquement (pas de purge).")
    parser.add_argument(
        "--output-dir",
        default="",
        help="Dossier parent pour backups/supabase_backup_<date>/ (défaut: racine du projet).",
    )
    args = parser.parse_args(argv)

    _load_env()

    project_root = os.path.abspath(os.path.dirname(__file__))
    parent = args.output_dir.strip() or project_root
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = os.path.abspath(os.path.join(parent, "backups", f"supabase_backup_{stamp}"))
    os.makedirs(backup_dir, exist_ok=True)
    manifest_path = os.path.join(backup_dir, "00_manifest.xlsx")

    export_rows: Dict[str, int] = {}
    export_format: Dict[str, str] = {}
    export_file: Dict[str, str] = {}
    export_error: Dict[str, str] = {}

    with _get_conn() as conn:
        conn.autocommit = False
        with conn.cursor() as cur:
            tables = _list_public_tables(cur)
            if not tables:
                raise RuntimeError("Aucune table public trouvée")

            print(f"Tables détectées ({len(tables)}): {', '.join(tables)}", flush=True)
            print(f"Dossier de sauvegarde: {backup_dir}", flush=True)

            for table in tables:
                print(f"[EXPORT] {table} ...", flush=True)
                try:
                    n = _table_rowcount(cur, table)
                except Exception as e:
                    export_rows[table] = 0
                    export_error[table] = repr(e)
                    export_format[table] = "error"
                    export_file[table] = ""
                    continue

                base_fn = _safe_filename(table)
                if n == 0:
                    empty_xlsx = os.path.join(backup_dir, f"{base_fn}.xlsx")
                    pd.DataFrame({"_empty": []}).to_excel(empty_xlsx, index=False, engine="openpyxl")
                    export_rows[table] = 0
                    export_format[table] = "xlsx"
                    export_file[table] = os.path.basename(empty_xlsx)
                    continue

                if n > _EXCEL_MAX_ROWS:
                    csv_path = os.path.join(backup_dir, f"{base_fn}.csv")
                    got, err = _export_table_copy_csv(cur, table, csv_path)
                    export_rows[table] = got
                    export_format[table] = "csv"
                    export_file[table] = os.path.basename(csv_path)
                    if err:
                        export_error[table] = err
                    continue

                xlsx_path = os.path.join(backup_dir, f"{base_fn}.xlsx")
                got, err = _export_table_xlsx(conn, table, xlsx_path)
                export_rows[table] = got
                export_format[table] = "xlsx"
                export_file[table] = os.path.basename(xlsx_path)
                if err:
                    export_error[table] = err

            # manifest
            info = {
                "started_utc": datetime.now(timezone.utc).isoformat(),
                "tables": len(tables),
                "export_only": args.export_only,
                "backup_dir": backup_dir,
                "note": f"Tables > {_EXCEL_MAX_ROWS} lignes en .csv (COPY), autres en .xlsx",
            }
            rows = []
            for t in tables:
                rows.append(
                    {
                        "table": t,
                        "format": export_format.get(t, ""),
                        "file": export_file.get(t, ""),
                        "rows_exported": export_rows.get(t, 0),
                        "error": export_error.get(t, ""),
                    }
                )
            with pd.ExcelWriter(manifest_path, engine="openpyxl") as mw:
                pd.DataFrame([info]).to_excel(mw, sheet_name="info", index=False)
                pd.DataFrame(rows).to_excel(mw, sheet_name="tables", index=False)

            # purge
            if not args.export_only:
                print("[PURGE] TRUNCATE public.* (RESTART IDENTITY CASCADE) ...", flush=True)
                _truncate_all(cur, tables)
                conn.commit()
                print("[PURGE] OK", flush=True)
            else:
                conn.rollback()
                print("[PURGE] ignoré (--export-only)", flush=True)

    print(f"BACKUP_DIR={backup_dir}")
    print(f"MANIFEST_FILE={manifest_path}")


if __name__ == "__main__":
    main(sys.argv[1:])

