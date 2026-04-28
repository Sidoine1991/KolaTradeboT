import argparse
import csv
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Mapping, Optional, Tuple

import httpx
import pandas as pd
from dotenv import load_dotenv

# Excel limite ~1 048 576 lignes ; on reste en dessous pour les feuilles.
_EXCEL_MAX_ROWS = 1_040_000
# Au-delà : export CSV incrémental (évite la RAM pour prediction_candles, etc.).

# Timeouts / retries : grandes tables ou réseau instable (erreur "Server disconnected").
_HTTPX_TIMEOUT = httpx.Timeout(180.0, connect=60.0)
_GET_MAX_ATTEMPTS = 6
_DELETE_MAX_ATTEMPTS = 4


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


def _sanitize_sheet_name(name: str) -> str:
    sanitized = re.sub(r"[:\\/?*\[\]]", "_", name)
    if not sanitized:
        sanitized = "Sheet"
    return sanitized[:31]


def _get_headers(key: str) -> Dict[str, str]:
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
    }


def _get_with_retry(
    client: httpx.Client,
    url: str,
    *,
    headers: Dict[str, str],
    params: Optional[Mapping[str, Any]] = None,
    max_attempts: int = _GET_MAX_ATTEMPTS,
) -> httpx.Response:
    last_exc: Optional[BaseException] = None
    for attempt in range(max_attempts):
        try:
            r = client.get(url, headers=headers, params=params, timeout=_HTTPX_TIMEOUT)
            r.raise_for_status()
            return r
        except httpx.HTTPStatusError as e:
            code = e.response.status_code
            if code in (502, 503, 504, 522) and attempt < max_attempts - 1:
                last_exc = e
                wait = min(60.0, 2.0 ** attempt)
                print(
                    f"[RETRY] {url} HTTP {code} — nouvel essai dans {wait:.0f}s ({attempt + 1}/{max_attempts})",
                    flush=True,
                )
                time.sleep(wait)
                continue
            raise
        except (
            httpx.RemoteProtocolError,
            httpx.ConnectError,
            httpx.ReadTimeout,
            httpx.ConnectTimeout,
        ) as e:
            last_exc = e
            if attempt < max_attempts - 1:
                wait = min(60.0, 2.0 ** attempt)
                print(
                    f"[RETRY] {url} {type(e).__name__} — attente {wait:.0f}s ({attempt + 1}/{max_attempts})",
                    flush=True,
                )
                time.sleep(wait)
                continue
            raise
    if last_exc:
        raise last_exc
    raise RuntimeError("_get_with_retry: aucune tentative")


def _delete_with_retry(
    client: httpx.Client,
    url: str,
    *,
    headers: Dict[str, str],
    params: Mapping[str, Any],
    max_attempts: int = _DELETE_MAX_ATTEMPTS,
) -> httpx.Response:
    last_exc: Optional[BaseException] = None
    for attempt in range(max_attempts):
        try:
            r = client.delete(url, headers=headers, params=params, timeout=_HTTPX_TIMEOUT)
            if r.status_code in (200, 204):
                return r
            if r.status_code in (502, 503, 504, 522) and attempt < max_attempts - 1:
                wait = min(60.0, 2.0 ** attempt)
                print(
                    f"[RETRY] DELETE {url} HTTP {r.status_code} — attente {wait:.0f}s",
                    flush=True,
                )
                time.sleep(wait)
                continue
            return r
        except (
            httpx.RemoteProtocolError,
            httpx.ConnectError,
            httpx.ReadTimeout,
            httpx.ConnectTimeout,
        ) as e:
            last_exc = e
            if attempt < max_attempts - 1:
                wait = min(60.0, 2.0 ** attempt)
                print(
                    f"[RETRY] DELETE {type(e).__name__} — attente {wait:.0f}s",
                    flush=True,
                )
                time.sleep(wait)
                continue
            raise
    if last_exc:
        raise last_exc
    raise RuntimeError("_delete_with_retry: aucune tentative")


def _extract_total_count(resp: httpx.Response) -> int:
    content_range = resp.headers.get("content-range", "")
    # format: "0-0/123" or "*/0"
    if "/" in content_range:
        tail = content_range.split("/")[-1].strip()
        if tail.isdigit():
            return int(tail)
    return 0


def _list_public_tables(client: httpx.Client, base_url: str, headers: Dict[str, str]) -> List[str]:
    # Supabase expose l'OpenAPI de PostgREST sur /rest/v1/ ; on en déduit les tables exposées.
    r = _get_with_retry(client, f"{base_url}/", headers=headers)
    spec = r.json()
    paths = spec.get("paths", {}) if isinstance(spec, dict) else {}
    tables: List[str] = []
    for raw_path, methods in paths.items():
        if not isinstance(raw_path, str) or not raw_path.startswith("/"):
            continue
        name = raw_path[1:]
        if not name or "/" in name:
            continue
        if name.startswith("rpc/"):
            continue
        if not isinstance(methods, dict):
            continue
        # Ne garder que les ressources lisibles (GET) qui ressemblent à des tables.
        if "get" not in methods:
            continue
        if name:
            tables.append(name)
    return sorted(set(tables))


def _get_table_columns(
    client: httpx.Client, base_url: str, headers: Dict[str, str], table: str
) -> List[str]:
    # Sans accès information_schema, on déduit les colonnes depuis une ligne exemple.
    try:
        r = _get_with_retry(
            client,
            f"{base_url}/{table}",
            headers=headers,
            params={"select": "*", "limit": "1"},
        )
    except httpx.HTTPStatusError as e:
        if e.response.status_code >= 400:
            return []
        raise
    data = r.json()
    if not data or not isinstance(data, list) or not isinstance(data[0], dict):
        return []
    return list(data[0].keys())


def _table_count(client: httpx.Client, base_url: str, headers: Dict[str, str], table: str) -> int:
    url = f"{base_url}/{table}"
    h = {
        **headers,
        "Prefer": "count=exact",
        "Range-Unit": "items",
        "Range": "0-0",
    }
    try:
        r = _get_with_retry(client, url, headers=h, params={"select": "*"})
    except httpx.HTTPStatusError as e:
        if e.response.status_code >= 400:
            return 0
        raise
    return _extract_total_count(r)


def _json_safe_cell(v: Any) -> Any:
    if v is None:
        return ""
    if isinstance(v, (dict, list)):
        return json.dumps(v, ensure_ascii=False)
    return v


def _safe_filename(name: str) -> str:
    s = re.sub(r'[<>:"/\\|?*]', "_", name)
    return s[:120] if s else "table"


def _fetch_all_rows(
    client: httpx.Client, base_url: str, headers: Dict[str, str], table: str, batch_size: int = 500
) -> List[Dict]:
    rows: List[Dict] = []
    start = 0
    while True:
        end = start + batch_size - 1
        h = {
            **headers,
            "Range-Unit": "items",
            "Range": f"{start}-{end}",
        }
        r = _get_with_retry(
            client,
            f"{base_url}/{table}",
            headers=h,
            params={"select": "*"},
        )
        chunk = r.json()
        if not chunk:
            break
        rows.extend(chunk)
        if len(chunk) < batch_size:
            break
        start += batch_size
    return rows


def _export_table_to_csv_streaming(
    client: httpx.Client,
    base_url: str,
    headers: Dict[str, str],
    table: str,
    out_path: str,
    batch_size: int = 2000,
) -> Tuple[int, Optional[str]]:
    """Exporte toute la table en CSV sans tout charger en RAM. Retourne (lignes, erreur)."""
    fieldnames: Optional[List[str]] = None
    total = 0
    start = 0
    try:
        with open(out_path, "w", newline="", encoding="utf-8") as fp:
            writer: Optional[csv.DictWriter] = None
            while True:
                end = start + batch_size - 1
                h = {
                    **headers,
                    "Range-Unit": "items",
                    "Range": f"{start}-{end}",
                }
                r = _get_with_retry(
                    client,
                    f"{base_url}/{table}",
                    headers=h,
                    params={"select": "*"},
                )
                chunk = r.json()
                if not chunk:
                    break
                if not isinstance(chunk, list):
                    return 0, f"réponse inattendue pour {table}"
                for raw in chunk:
                    row = {k: _json_safe_cell(raw.get(k)) for k in raw}
                    if fieldnames is None:
                        fieldnames = list(raw.keys())
                        writer = csv.DictWriter(
                            fp,
                            fieldnames=fieldnames,
                            extrasaction="ignore",
                            lineterminator="\n",
                        )
                        writer.writeheader()
                    assert writer is not None
                    writer.writerow({k: row.get(k, "") for k in fieldnames})
                    total += 1
                if len(chunk) < batch_size:
                    break
                start += batch_size
                if total % (batch_size * 50) == 0:
                    print(f"[EXPORT CSV] {table}: {total} lignes ...", flush=True)
    except OSError as e:
        return total, str(e)
    return total, None


def _delete_all_rows(
    client: httpx.Client, base_url: str, headers: Dict[str, str], table: str, column_for_filter: str
) -> Tuple[bool, str]:
    # Condition toujours vraie: col IS NULL OR col IS NOT NULL
    # Cela évite d'avoir besoin de connaître une PK spécifique.
    params = {"or": f"({column_for_filter}.is.null,{column_for_filter}.not.is.null)"}
    h = {**headers, "Prefer": "return=minimal"}
    r = _delete_with_retry(client, f"{base_url}/{table}", headers=h, params=params)
    if r.status_code in (200, 204):
        return True, "ok"
    return False, f"HTTP {r.status_code}: {r.text[:300]}"


def main(argv: List[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Exporte les tables exposées par PostgREST : dossier avec manifest Excel, "
            "un .xlsx par table (taille modérée) ou .csv en flux pour les très grosses tables, "
            "puis optionnellement purge (clé service role requise pour DELETE)."
        )
    )
    parser.add_argument(
        "--export-only",
        action="store_true",
        help="N'exécute que l'export, sans purge des tables.",
    )
    parser.add_argument(
        "--output-dir",
        default="",
        help="Dossier parent pour backups/supabase_backup_<date>/ (défaut: racine du projet).",
    )
    args = parser.parse_args(argv)
    _load_env()
    supabase_url = (os.getenv("SUPABASE_URL") or "").rstrip("/")
    supabase_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_SERVICE_KEY")
        or os.getenv("SUPABASE_ANON_KEY")
        or ""
    )
    if not supabase_url or not supabase_key:
        raise RuntimeError("SUPABASE_URL ou clé Supabase manquante")

    base_url = f"{supabase_url}/rest/v1"
    headers = _get_headers(supabase_key)

    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    parent = args.output_dir.strip() or project_root
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = os.path.abspath(os.path.join(parent, "backups", f"supabase_backup_{stamp}"))
    os.makedirs(backup_dir, exist_ok=True)
    manifest_path = os.path.join(backup_dir, "00_manifest.xlsx")

    export_counts: Dict[str, int] = {}
    export_files: Dict[str, str] = {}
    export_errors: Dict[str, str] = {}
    purge_results: Dict[str, Dict[str, str]] = {}

    with httpx.Client(timeout=_HTTPX_TIMEOUT) as client:
        tables = _list_public_tables(client, base_url, headers)
        if not tables:
            raise RuntimeError("Aucune table public trouvée")
        print(f"Tables détectées ({len(tables)}): {', '.join(tables)}", flush=True)
        print(f"Dossier de sauvegarde: {backup_dir}", flush=True)

        # 1) Export : manifest + fichier par table (xlsx ou csv)
        manifest_rows: List[Dict[str, Any]] = []
        for table in tables:
            print(f"[EXPORT] {table} ...", flush=True)
            try:
                n = _table_count(client, base_url, headers, table)
            except Exception as e:
                export_errors[table] = repr(e)
                manifest_rows.append(
                    {
                        "table": table,
                        "rows_reported": None,
                        "format": "error",
                        "file": "",
                        "error": repr(e),
                    }
                )
                continue

            base_fn = _safe_filename(table)
            if n == 0:
                export_counts[table] = 0
                empty_xlsx = os.path.join(backup_dir, f"{base_fn}.xlsx")
                pd.DataFrame({"_empty": []}).to_excel(empty_xlsx, index=False, engine="openpyxl")
                export_files[table] = os.path.basename(empty_xlsx)
                manifest_rows.append(
                    {
                        "table": table,
                        "rows_reported": 0,
                        "format": "xlsx",
                        "file": os.path.basename(empty_xlsx),
                        "error": "",
                    }
                )
                print(f"[EXPORT] {table}: vide -> {empty_xlsx}", flush=True)
                continue

            if n > _EXCEL_MAX_ROWS:
                csv_path = os.path.join(backup_dir, f"{base_fn}.csv")
                print(
                    f"[EXPORT] {table}: {n} lignes (> limite Excel) -> CSV streaming ...",
                    flush=True,
                )
                got, err = _export_table_to_csv_streaming(
                    client, base_url, headers, table, csv_path
                )
                export_counts[table] = got
                export_files[table] = os.path.basename(csv_path)
                manifest_rows.append(
                    {
                        "table": table,
                        "rows_reported": n,
                        "format": "csv",
                        "file": os.path.basename(csv_path),
                        "rows_exported": got,
                        "error": err or "",
                    }
                )
                if err:
                    export_errors[table] = err
                print(f"[EXPORT] {table}: {got} lignes -> {csv_path}", flush=True)
                continue

            try:
                rows = _fetch_all_rows(client, base_url, headers, table, batch_size=1000)
                export_counts[table] = len(rows)
                df = pd.DataFrame(rows)
                xlsx_path = os.path.join(backup_dir, f"{base_fn}.xlsx")
                df.to_excel(xlsx_path, index=False, engine="openpyxl")
                export_files[table] = os.path.basename(xlsx_path)
                manifest_rows.append(
                    {
                        "table": table,
                        "rows_reported": n,
                        "format": "xlsx",
                        "file": os.path.basename(xlsx_path),
                        "rows_exported": len(rows),
                        "error": "",
                    }
                )
                print(f"[EXPORT] {table}: {len(rows)} lignes -> {xlsx_path}", flush=True)
            except Exception as e:
                print(f"[EXPORT] {table} ERREUR: {e}", flush=True)
                export_errors[table] = repr(e)
                export_counts[table] = 0
                manifest_rows.append(
                    {
                        "table": table,
                        "rows_reported": n,
                        "format": "failed",
                        "file": "",
                        "error": repr(e),
                    }
                )

        with pd.ExcelWriter(manifest_path, engine="openpyxl") as mw:
            pd.DataFrame(
                [
                    {
                        "started_utc": datetime.now(timezone.utc).isoformat(),
                        "supabase_url": supabase_url,
                        "tables": len(tables),
                        "export_only": args.export_only,
                        "backup_dir": backup_dir,
                        "note": (
                            "Tables > "
                            f"{_EXCEL_MAX_ROWS} lignes en .csv ; "
                            "les autres en un fichier .xlsx par table."
                        ),
                    }
                ]
            ).to_excel(mw, sheet_name="info", index=False)
            pd.DataFrame(manifest_rows).to_excel(mw, sheet_name="tables", index=False)

        # 2) Purge du contenu (plusieurs passes pour gérer les dépendances FK)
        if not args.export_only:
            columns_map = {t: _get_table_columns(client, base_url, headers, t) for t in tables}
            max_passes = 6
            for _ in range(max_passes):
                progress = False
                for table in tables:
                    before = _table_count(client, base_url, headers, table)
                    if before == 0:
                        purge_results.setdefault(
                            table, {"before": "0", "after": "0", "status": "already_empty"}
                        )
                        continue
                    print(f"[PURGE] {table}: before={before}", flush=True)

                    cols = columns_map.get(table) or []
                    if not cols:
                        purge_results[table] = {
                            "before": str(before),
                            "after": str(before),
                            "status": "no_columns",
                        }
                        continue

                    ok, detail = _delete_all_rows(client, base_url, headers, table, cols[0])
                    after = _table_count(client, base_url, headers, table)
                    status = "deleted" if ok and after == 0 else f"partial_or_failed ({detail})"
                    purge_results[table] = {"before": str(before), "after": str(after), "status": status}
                    print(f"[PURGE] {table}: after={after} status={status}", flush=True)
                    if after < before:
                        progress = True
                if not progress:
                    break
        else:
            print("[PURGE] ignoré (--export-only)", flush=True)
            for table in tables:
                purge_results[table] = {
                    "before": "n/a",
                    "after": "n/a",
                    "status": "skipped (--export-only)",
                }

    total_exported = sum(export_counts.values())
    non_empty_after: Dict[str, Dict[str, str]] = {}
    for t, r in purge_results.items():
        after_str = str(r.get("after", "0"))
        if after_str.isdigit() and int(after_str) > 0:
            non_empty_after[t] = r

    print(f"BACKUP_DIR={backup_dir}")
    print(f"MANIFEST_FILE={manifest_path}")
    print(f"TABLE_COUNT={len(export_counts)}")
    print(f"TOTAL_ROWS_EXPORTED={total_exported}")
    print("PURGE_SUMMARY_START")
    for table in sorted(purge_results):
        r = purge_results[table]
        print(f"{table}\tbefore={r['before']}\tafter={r['after']}\tstatus={r['status']}")
    print("PURGE_SUMMARY_END")
    print(f"TABLES_NOT_EMPTY_AFTER_PURGE={len(non_empty_after)}")


if __name__ == "__main__":
    main(sys.argv[1:])
