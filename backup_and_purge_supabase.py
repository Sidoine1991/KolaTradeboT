import argparse
import os
import re
import sys
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Mapping, Optional, Tuple

import httpx
import pandas as pd
from dotenv import load_dotenv

# Timeouts / retries : grandes tables ou réseau instable (erreur "Server disconnected").
_HTTPX_TIMEOUT = httpx.Timeout(180.0, connect=60.0)
_GET_MAX_ATTEMPTS = 6
_DELETE_MAX_ATTEMPTS = 4


def _load_env() -> None:
    project_root = os.path.abspath(os.path.dirname(__file__))
    env_supabase = os.path.join(project_root, ".env.supabase")
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
            if code in (502, 503, 504) and attempt < max_attempts - 1:
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
            if r.status_code in (502, 503, 504) and attempt < max_attempts - 1:
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
            "Exporte toutes les tables exposées par PostgREST vers un fichier Excel, "
            "puis purge leur contenu (clé service role requise pour DELETE)."
        )
    )
    parser.add_argument(
        "--export-only",
        action="store_true",
        help="N'exécute que l'export Excel, sans purge des tables.",
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

    backup_name = f"supabase_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
    backup_path = os.path.abspath(os.path.join(os.path.dirname(__file__), backup_name))

    export_counts: Dict[str, int] = {}
    purge_results: Dict[str, Dict[str, str]] = {}

    with httpx.Client(timeout=_HTTPX_TIMEOUT) as client:
        tables = _list_public_tables(client, base_url, headers)
        if not tables:
            raise RuntimeError("Aucune table public trouvée")
        print(f"Tables détectées ({len(tables)}): {', '.join(tables)}", flush=True)

        # 1) Export vers Excel
        with pd.ExcelWriter(backup_path, engine="openpyxl") as writer:
            pd.DataFrame(
                [
                    {
                        "started_utc": datetime.now(timezone.utc).isoformat(),
                        "supabase_url": supabase_url,
                        "tables": len(tables),
                        "export_only": args.export_only,
                    }
                ]
            ).to_excel(writer, sheet_name=_sanitize_sheet_name("_backup_meta"), index=False)

            for table in tables:
                print(f"[EXPORT] {table} ...", flush=True)
                try:
                    rows = _fetch_all_rows(client, base_url, headers, table)
                    export_counts[table] = len(rows)
                    print(f"[EXPORT] {table}: {len(rows)} lignes", flush=True)
                    df = pd.DataFrame(rows)
                    if df.empty:
                        df = pd.DataFrame({"_empty_table": []})
                except Exception as e:
                    print(f"[EXPORT] {table} ERREUR: {e}", flush=True)
                    export_counts[table] = 0
                    df = pd.DataFrame([{"_export_error": repr(e)}])
                df.to_excel(writer, sheet_name=_sanitize_sheet_name(table), index=False)

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

    print(f"BACKUP_FILE={backup_path}")
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
