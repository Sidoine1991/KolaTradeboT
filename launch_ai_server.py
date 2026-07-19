#!/usr/bin/env python3
"""AI Server launcher — redémarrage automatique (24/7).

Si uvicorn s'arrête (crash, exception non gérée, timeout MT5, etc.),
on le relance automatiquement au lieu de laisser le serveur mort.
"""
import sys
import time
import subprocess
import datetime
import socket
import os
import signal

# Forcer l'encodage UTF-8 pour stdout/stderr (évite UnicodeEncodeError sur
# console Windows cp1252 avec les emojis du log).
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

HOST = "127.0.0.1"
PORT = 8000

# Interpréteur forcé sur le venv du projet (Python 3.11) pour éviter les
# conflits d'ABI avec un python global différent (ex: 3.14).
import os as _os
_THIS_DIR = _os.path.dirname(_os.path.abspath(__file__))
_VENV_PY = _os.path.join(_THIS_DIR, ".venv", "Scripts", "python.exe")
PYTHON_EXE = _VENV_PY if _os.path.isfile(_VENV_PY) else sys.executable

def log(msg):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    try:
        with open("D:/Dev/TradBOT/ai_server_launcher.log", "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass

def port_in_use(host, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(1)
    try:
        return s.connect_ex((host, port)) == 0
    finally:
        s.close()

def kill_stale_on_port(host, port):
    """Tue tout process écoutant déjà sur le port (instance zombie / précédente)."""
    try:
        import subprocess as _sp
        out = _sp.run(
            ["netstat", "-ano", "-p", "TCP"],
            capture_output=True, timeout=15
        ).stdout
        # Décoder en latin-1 pour éviter UnicodeDecodeError (caractères cp850/cp1252)
        if isinstance(out, (bytes, bytearray)):
            out = out.decode("latin-1", errors="replace")
        for raw in out.splitlines():
            if f":{port}" in raw and "LISTENING" in raw:
                parts = raw.split()
                pid = parts[-1].strip()
                if pid.isdigit() and pid != str(os.getpid()):
                    log(f"[!] Port {port} occupé par PID {pid} — tentative de fermeture")
                    try:
                        os.kill(int(pid), signal.SIGTERM)
                    except Exception:
                        os.system(f"taskkill /F /PID {pid} >nul")
                    time.sleep(3)
                    return True
    except Exception as e:
        log(f"[!] Impossible de vérifier/lier le port: {e}")
    return False

def main():
    log("Launcher démarré — boucle de redémarrage 24/7 active (Ctrl+C pour arrêter)")
    restart_delay = 2
    attempts = 0
    while True:
        # Libérer le port si une instance zombie traîne
        if port_in_use(HOST, PORT):
            kill_stale_on_port(HOST, PORT)

        attempts += 1
        log(f">> Lancement uvicorn (tentative #{attempts})")
        try:
            result = subprocess.run([
                PYTHON_EXE, "-u", "-m", "uvicorn",
                "ai_server:app",
                "--host", HOST,
                "--port", str(PORT),
                "--log-level", "info",
                "--timeout-keep-alive", "30",
                "--timeout-graceful-shutdown", "10",
            ], cwd="D:/Dev/TradBOT")
            code = result.returncode
        except Exception as e:
            code = -1
            log(f"[X] Exception lançant uvicorn: {e}")

        if code == 0:
            log("uvicorn terminé proprement (code 0) — on relance pour 24/7")
        else:
            log(f"[X] uvicorn arrêté (code {code}) — redémarrage dans {restart_delay}s")

        time.sleep(restart_delay)
        # backoff double pour éviter une boucle trop agressive en cas d'erreur persistante
        if restart_delay < 30:
            restart_delay = min(restart_delay * 2, 30)

    log("Launcher terminé.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("Interruption manuelle (Ctrl+C) — arrêt du launcher")
        sys.exit(0)
