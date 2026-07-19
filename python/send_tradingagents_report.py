#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Envoie le rapport TradingAgents par WhatsApp
Converti depuis Word vers Markdown
"""

import sys
import io
import time
import requests
from pathlib import Path
try:
    import ssl_patch  # noqa: F401 — SSL Windows fix
except ImportError:
    pass

# Fix Windows encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

WHATSAPP_API_URL = "https://psychobot-1si7.onrender.com"
PHONE_NUMBER = "+2290196911346"
_MAX_RETRIES = 3
_RETRY_DELAYS = [5, 15, 30]  # secondes entre tentatives (wake-up Render ~15-30s)


def _wake_up_server() -> bool:
    """Ping /health pour réveiller le serveur Render avant un vrai appel."""
    try:
        r = requests.get(f"{WHATSAPP_API_URL}/health", timeout=35)
        return r.status_code < 500
    except Exception:
        return False


def _post_with_retry(url: str, payload: dict, timeout: int = 60) -> requests.Response | None:
    """POST avec retry automatique sur RemoteDisconnected / ConnectionError (Render sleep)."""
    for attempt in range(_MAX_RETRIES):
        try:
            return requests.post(url, json=payload, timeout=timeout)
        except (requests.exceptions.ConnectionError,
                requests.exceptions.ChunkedEncodingError) as e:
            if attempt < _MAX_RETRIES - 1:
                delay = _RETRY_DELAYS[attempt]
                print(f"⚠️  Serveur déconnecté (tentative {attempt+1}/{_MAX_RETRIES}) — réveil dans {delay}s…")
                time.sleep(delay)
                _wake_up_server()
                time.sleep(3)
            else:
                print(f"❌ Échec après {_MAX_RETRIES} tentatives: {e}")
                return None
    return None


def send_whatsapp_message(message: str) -> bool:
    """Envoie un message WhatsApp via PsychoBot (retry si Render dort)."""
    response = _post_with_retry(
        f"{WHATSAPP_API_URL}/send-message",
        {"phone": PHONE_NUMBER, "message": message},
        timeout=40
    )
    if response is None:
        return False
    try:
        if response.status_code == 200:
            result = response.json()
            if result.get("success"):
                print("✅ Message envoyé sur WhatsApp")
                return True
            print(f"❌ Erreur: {result.get('error')}")
        else:
            print(f"❌ HTTP {response.status_code}")
    except Exception as e:
        print(f"❌ Exception: {e}")
    return False


def send_whatsapp_file(file_path: str, caption: str = "") -> bool:
    """Envoie un fichier (Word) via PsychoBot — upload tmpfiles.org + retry Render."""
    try:
        # Réveiller le serveur Render avant l'upload pour éviter le délai en milieu de requête
        print("⏳ Wake-up PsychoBot…")
        _wake_up_server()
        time.sleep(2)

        # Upload vers tmpfiles.org (7 jours)
        with open(file_path, 'rb') as f:
            files = {'file': (Path(file_path).name, f, 'application/octet-stream')}
            upload_response = requests.post(
                'https://tmpfiles.org/api/v1/upload',
                files=files,
                timeout=60
            )

        if upload_response.status_code != 200:
            print(f"❌ Échec upload fichier: {upload_response.status_code}")
            return False

        upload_data = upload_response.json()
        if upload_data.get('status') != 'success':
            print(f"❌ Échec upload: {upload_data}")
            return False

        file_url = upload_data['data']['url'].replace('tmpfiles.org/', 'tmpfiles.org/dl/')
        print(f"✅ Fichier uploadé: {file_url}")

        # Envoyer via PsychoBot avec retry
        response = _post_with_retry(
            f"{WHATSAPP_API_URL}/send-file",
            {
                "phone": PHONE_NUMBER,
                "message": caption,
                "file_url": file_url,
                "file_name": Path(file_path).name,
                "mime_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            },
            timeout=60
        )
        if response is None:
            return False

        if response.status_code == 200:
            result = response.json()
            if result.get("success"):
                print("✅ Fichier envoyé sur WhatsApp")
                return True
            print(f"❌ Erreur: {result.get('error')}")
        else:
            print(f"❌ HTTP {response.status_code}")
        return False

    except Exception as e:
        print(f"❌ Exception: {e}")
        import traceback
        traceback.print_exc()
        return False


def format_report_markdown(symbol: str, decision: str, entry: float, sl: float, tp: float,
                          rating: str, summary: str, risk_reward: str) -> str:
    """Formate le rapport en Markdown WhatsApp-friendly."""

    message = f"""*SIGNAL TRADINGAGENTS - {symbol}*

━━━━━━━━━━━━━━━━━━━━
📊 *DECISION*
━━━━━━━━━━━━━━━━━━━━

Direction: *{decision}*
Rating: *{rating}*
Risk/Reward: *{risk_reward}*

━━━━━━━━━━━━━━━━━━━━
💰 *NIVEAUX*
━━━━━━━━━━━━━━━━━━━━

Entry: *${entry:.2f}*
Stop Loss: *${sl:.2f}*
Take Profit: *${tp:.2f}*

━━━━━━━━━━━━━━━━━━━━
📋 *RESUME EXECUTIF*
━━━━━━━━━━━━━━━━━━━━

{summary}

━━━━━━━━━━━━━━━━━━━━
Generated by TradingAgents
"""

    return message


def format_full_analysis(analysis_text: str, max_length: int = 4000) -> list:
    """
    Découpe une analyse complète en plusieurs messages WhatsApp.
    WhatsApp a une limite de ~4096 caractères par message.
    """
    messages = []
    lines = analysis_text.split('\n')
    current_message = ""

    for line in lines:
        if len(current_message) + len(line) + 1 > max_length:
            messages.append(current_message)
            current_message = line + "\n"
        else:
            current_message += line + "\n"

    if current_message:
        messages.append(current_message)

    return messages


def send_quick_signal(symbol: str = "XAUUSD", decision: str = "SELL",
                     entry: float = 4569.8, sl: float = 4590.0, tp: float = 4549.0,
                     rating: str = "Underweight", summary: str = "Momentum baissier confirmé",
                     risk_reward: str = "1:1.03") -> bool:
    """
    Envoie un signal rapide.

    Usage:
        python send_tradingagents_report.py --quick --symbol XAUUSD --decision SELL --entry 4570 --sl 4590 --tp 4550
    """
    message = format_report_markdown(symbol, decision, entry, sl, tp, rating, summary, risk_reward)
    return send_whatsapp_message(message)


def send_full_report(report_file: str, send_file: bool = False) -> bool:
    """
    Envoie un rapport complet depuis un fichier markdown OU Word.

    Args:
        report_file: Chemin vers le fichier .md, .txt ou .docx
        send_file: Si True, envoie aussi le fichier Word en pièce jointe

    Usage:
        python send_tradingagents_report.py --file "rapport_xauusd.md"
        python send_tradingagents_report.py --file "rapport.docx" --send-file
    """
    report_path = Path(report_file)

    if not report_path.exists():
        print(f"❌ Fichier introuvable: {report_file}")
        return False

    try:
        # Vérifier si c'est un fichier Word
        if report_path.suffix.lower() == '.docx':
            # Envoyer le fichier Word en pièce jointe
            if send_file:
                print(f"📤 Envoi du fichier Word: {report_path.name}")
                caption = f"📊 *RAPPORT TRADINGAGENTS*\n\n{report_path.stem}\n\nVoir le résumé ci-dessous ↓"
                if not send_whatsapp_file(str(report_path), caption):
                    print(f"⚠️ Échec envoi fichier, envoi résumé seulement")

            # Extraire le résumé depuis le Word (simplification: envoyer un message)
            summary_msg = (
                f"📊 *RAPPORT TRADINGAGENTS*\n\n"
                f"Fichier: *{report_path.name}*\n\n"
                f"Le rapport complet a été envoyé en pièce jointe.\n"
                f"Consultez le document Word pour l'analyse détaillée."
            )
            return send_whatsapp_message(summary_msg)

        # Si c'est un fichier texte/markdown
        else:
            with open(report_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Découper en plusieurs messages si nécessaire
            messages = format_full_analysis(content)

            print(f"📤 Envoi de {len(messages)} message(s)...")

            for i, msg in enumerate(messages, 1):
                header = f"*[{i}/{len(messages)}]* " if len(messages) > 1 else ""
                full_msg = header + msg

                if send_whatsapp_message(full_msg):
                    print(f"  ✅ Message {i}/{len(messages)} envoyé")
                else:
                    print(f"  ❌ Échec message {i}/{len(messages)}")
                    return False

            return True

    except Exception as e:
        print(f"❌ Erreur lecture fichier: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Envoyer rapport TradingAgents par WhatsApp")

    parser.add_argument("--quick", action="store_true", help="Envoyer signal rapide")
    parser.add_argument("--file", type=str, help="Fichier markdown/Word du rapport complet")
    parser.add_argument("--send-file", action="store_true", help="Envoyer le fichier Word en pièce jointe")

    # Paramètres signal rapide
    parser.add_argument("--symbol", type=str, default="XAUUSD")
    parser.add_argument("--decision", type=str, default="SELL")
    parser.add_argument("--entry", type=float, default=4570.0)
    parser.add_argument("--sl", type=float, default=4590.0)
    parser.add_argument("--tp", type=float, default=4550.0)
    parser.add_argument("--rating", type=str, default="Underweight")
    parser.add_argument("--summary", type=str, default="Analyse technique baissière")
    parser.add_argument("--rr", type=str, default="1:2", help="Risk/Reward ratio")

    args = parser.parse_args()

    if args.quick:
        success = send_quick_signal(
            args.symbol, args.decision, args.entry, args.sl, args.tp,
            args.rating, args.summary, args.rr
        )
        sys.exit(0 if success else 1)

    elif args.file:
        success = send_full_report(args.file, send_file=args.send_file)
        sys.exit(0 if success else 1)

    else:
        parser.print_help()
        print("\nExemples:")
        print("\n  Signal rapide:")
        print("    python send_tradingagents_report.py --quick --symbol XAUUSD --decision SELL --entry 4570 --sl 4590 --tp 4550")
        print("\n  Rapport complet:")
        print("    python send_tradingagents_report.py --file rapport_xauusd.md")
        sys.exit(1)
