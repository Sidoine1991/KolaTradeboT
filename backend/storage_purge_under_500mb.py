#!/usr/bin/env python3
"""
Liste les buckets Supabase Storage, calcule l'espace utilisé et supprime des
objets (les plus anciens en priorité) jusqu'à ce que l'utilisation soit < 500 Mo.

Requiert la clé **service_role** (Dashboard Supabase → Settings → API → service_role).
Variables acceptées : SUPABASE_SERVICE_ROLE_KEY ou SUPABASE_SERVICE_KEY.
La clé **anon** ne permet pas de lister les buckets : le script refusera de continuer.

Exécution : depuis la racine du projet avec .venv activé :
  python backend/storage_purge_under_500mb.py
"""
from __future__ import annotations

import io
import os
import sys
from pathlib import Path

import base64
import json

import httpx

TARGET_BYTES = 500 * 1024 * 1024


def _jwt_role(key: str) -> str | None:
    try:
        parts = key.split(".")
        if len(parts) < 2:
            return None
        payload = parts[1] + "=" * (-len(parts[1]) % 4)
        data = json.loads(base64.urlsafe_b64decode(payload.encode("ascii")))
        return data.get("role")
    except Exception:
        return None


def _resolve_service_key() -> tuple[str, str]:
    """Retourne (clé, nom de variable utilisée)."""
    for var in (
        "SUPABASE_SERVICE_ROLE_KEY",
        "SUPABASE_SERVICE_KEY",
        "SUPABASE_KEY",
    ):
        k = (os.getenv(var) or "").strip()
        if not k:
            continue
        role = _jwt_role(k)
        if role == "service_role":
            return k, var
    return "", ""


def _load_env() -> None:
    root = Path(__file__).resolve().parents[1]
    env_path = root / ".env.supabase"
    if not env_path.is_file():
        print("Fichier .env.supabase introuvable.", file=sys.stderr)
        sys.exit(1)
    raw = env_path.read_bytes()
    for enc in ("utf-8", "cp1252"):
        try:
            text = raw.decode(enc)
            break
        except UnicodeDecodeError:
            text = None
    else:
        print("Encodage .env.supabase illisible.", file=sys.stderr)
        sys.exit(1)
    from dotenv import load_dotenv

    load_dotenv(stream=io.StringIO(text))


def _headers(key: str) -> dict[str, str]:
    return {"apikey": key, "Authorization": f"Bearer {key}"}


def _request_with_retries(
    method: str,
    client: httpx.Client,
    url: str,
    *,
    headers: dict[str, str],
    **kwargs: object,
) -> httpx.Response:
    import time

    last: Exception | None = None
    for attempt in range(5):
        try:
            r = client.request(method, url, headers=headers, timeout=180.0, **kwargs)
            r.raise_for_status()
            return r
        except (httpx.ConnectError, httpx.ReadTimeout, httpx.RemoteProtocolError) as e:
            last = e
            time.sleep(min(30.0, 2.0**attempt))
    assert last is not None
    raise last


def _list_buckets(client: httpx.Client, base: str, key: str) -> list[dict]:
    r = _request_with_retries(
        "GET", client, f"{base}/storage/v1/bucket", headers=_headers(key)
    )
    return r.json()


def _list_page(
    client: httpx.Client,
    base: str,
    key: str,
    bucket: str,
    prefix: str,
    offset: int,
) -> list[dict]:
    body = {
        "prefix": prefix,
        "limit": 1000,
        "offset": offset,
        "sortBy": {"column": "updated_at", "order": "desc"},
    }
    r = _request_with_retries(
        "POST",
        client,
        f"{base}/storage/v1/object/list/{bucket}",
        headers={**_headers(key), "Content-Type": "application/json"},
        json=body,
    )
    return r.json()


def _collect_files(
    client: httpx.Client,
    base: str,
    key: str,
    bucket: str,
    prefix: str,
) -> list[tuple[str, int, str | None]]:
    """Retourne (chemin relatif au bucket, taille, updated_at)."""
    out: list[tuple[str, int, str | None]] = []
    offset = 0
    while True:
        page = _list_page(client, base, key, bucket, prefix, offset)
        if not page:
            break
        for item in page:
            name = item.get("name") or ""
            rel = prefix + name
            meta = item.get("metadata") or {}
            size = meta.get("size")
            updated = item.get("updated_at")
            # Dossier : id souvent null, pas de taille fichier
            if item.get("id") is None and size is None:
                out.extend(_collect_files(client, base, key, bucket, rel + "/"))
            elif size is not None:
                out.append((rel, int(size), updated))
        if len(page) < 1000:
            break
        offset += 1000
    return out


def _delete_objects(
    client: httpx.Client,
    base: str,
    key: str,
    bucket: str,
    paths: list[str],
) -> None:
    """API Storage: DELETE /storage/v1/object/{bucket} body {\"paths\": [...]}"""
    if not paths:
        return
    _request_with_retries(
        "DELETE",
        client,
        f"{base}/storage/v1/object/{bucket}",
        headers={**_headers(key), "Content-Type": "application/json"},
        json={"paths": paths},
    )


def main() -> None:
    _load_env()
    url = (os.getenv("SUPABASE_URL") or "").rstrip("/")
    key, key_src = _resolve_service_key()
    if not url or not key:
        print(
            "SUPABASE_URL et une clé JWT avec role=service_role requis.\n"
            "Ajoutez dans .env.supabase par exemple :\n"
            "  SUPABASE_SERVICE_ROLE_KEY=<copie depuis Dashboard, Settings, API, secret service_role>",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"Clé utilisée: {key_src} (role=service_role)")

    with httpx.Client() as client:
        buckets = _list_buckets(client, url, key)
        print(f"Buckets: {len(buckets)}")
        all_files: list[tuple[str, str, int, str | None]] = []
        for b in buckets:
            bid = b.get("id") or b.get("name")
            name = b.get("name") or bid
            if not name:
                continue
            try:
                files = _collect_files(client, url, key, name, "")
            except httpx.HTTPStatusError as e:
                print(f"  [{name}] liste impossible: {e.response.status_code} {e.response.text[:200]}")
                continue
            total_b = sum(s for _, s, _ in files)
            print(f"  [{name}] fichiers={len(files)} ~ {total_b / 1e6:.2f} Mo")
            for path, size, upd in files:
                all_files.append((name, path, size, upd))

        total = sum(s for _, _, s, _ in all_files)
        print(f"\nTotal estimé: {total / 1e6:.2f} Mo ({total} octets)")

        if total <= TARGET_BYTES:
            print(f"Déjà <= {TARGET_BYTES // (1024 * 1024)} Mo. Rien à supprimer.")
            return

        to_free = total - TARGET_BYTES + 1024 * 1024  # marge 1 Mo
        print(f"Cible: < 500 Mo — à libérer ~ {to_free / 1e6:.2f} Mo")

        # Plus anciens en premier (updated_at asc ; None en dernier)
        def sort_key(x: tuple[str, str, int, str | None]):
            u = x[3]
            return (0, u or "9999") if u else (1, "")

        ordered = sorted(all_files, key=sort_key)
        freed = 0
        batch: list[tuple[str, str]] = []
        for bucket, path, size, _ in ordered:
            if freed >= to_free:
                break
            batch.append((bucket, path))
            freed += size
            if len(batch) >= 50:
                for buck, pth in batch:
                    try:
                        _delete_objects(client, url, key, buck, [pth])
                    except Exception as ex:
                        print(f"Erreur delete {buck}/{pth}: {ex}")
                batch = []
        for buck, pth in batch:
            try:
                _delete_objects(client, url, key, buck, [pth])
            except Exception as ex:
                print(f"Erreur delete {buck}/{pth}: {ex}")

        print(f"Suppression terminée (libéré ~ {freed / 1e6:.2f} Mo ciblé). Recomptez dans le dashboard.")


if __name__ == "__main__":
    main()
