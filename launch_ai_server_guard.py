#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Watchdog ai_server — surveille /health et relance uvicorn en cas de gel.

ai_server.py gèle parfois l'event loop (appels MT5 synchrones quand un
terminal pend) : le port 8000 reste ouvert mais aucune requete ne repond,
l'EA MT5 voit alors "Code 1003" (timeout WebRequest 5s).

Ce wrapper :
  1. libere le port 8000 (tue toute instance zombie au demarrage)
  2. lance `python ai_server.py` (cwd = racine TradBOT)
  3. sonde /health toutes les 3s ; apres 3 echecs consecutifs => kill /F
     du processus gelee puis relance
  4. relance aussi si le processus sort abnormalement
  5. backoff 2s->30s entre relances (reinitialise apres 10 min saines)
  6. garde-fou anti double instance (pid file)
"""
import datetime
import os
import signal
import socket
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.abspath(__file__))
LOGS = os.path.join(ROOT, "logs")
PID_FILE = os.path.join(LOGS, "ai_server_guard.pid")
GUARD_LOG = os.path.join(LOGS, "ai_server_guard.log")

HOST = "127.0.0.1"
PORT = 8000
HEALTH_URL = "http://127.0.0.1:%d/health" % PORT

PYTHON = r"C:\Users\Power Informatique\AppData\Local\Programs\Python\Python311\python.exe"
if not os.path.isfile(PYTHON):
    PYTHON = sys.executable

HEALTH_TIMEOUT = 4.0
MAX_CONSECUTIVE_FAIL = 3
CHECK_INTERVAL = 3.0


def _log(msg):
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = "[%s] %s" % (ts, msg)
    try:
        print(line, flush=True)
    except Exception:
        pass
    try:
        with open(GUARD_LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def _port_free():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(1)
    try:
        return s.connect_ex((HOST, PORT)) != 0
    finally:
        s.close()


def _kill_stale_on_port():
    try:
        out = subprocess.run(
            ["netstat", "-ano", "-p", "TCP"], capture_output=True, timeout=15
        ).stdout
        if isinstance(out, (bytes, bytearray)):
            out = out.decode("latin-1", errors="replace")
        for raw in out.splitlines():
            if (":%d" % PORT) in raw and "LISTENING" in raw:
                parts = raw.split()
                pid = parts[-1].strip()
                if pid.isdigit() and pid != str(os.getpid()):
                    _log("[!] Port %d occupe par PID %s -> taskkill /F" % (PORT, pid))
                    os.system("taskkill /F /PID %s >nul 2>&1" % pid)
                    time.sleep(3)
                    return
    except Exception as e:
        _log("[!] kill_stale_on_port: %s" % e)


def _check_alive(proc):
    if proc.poll() is not None:
        return False
    try:
        s = socket.create_connection((HOST, PORT), timeout=HEALTH_TIMEOUT)
        s.close()
        return True
    except Exception:
        return False


def _launch(out_log, err_log):
    log_dir = os.path.dirname(out_log)
    if not os.path.isdir(log_dir):
        os.makedirs(log_dir, exist_ok=True)
    out_f = open(out_log, "a", encoding="utf-8", errors="replace")
    err_f = open(err_log, "a", encoding="utf-8", errors="replace")
    out_f.write("\n===== AI SERVER LAUNCH %s =====\n" % datetime.datetime.now().isoformat())
    out_f.flush()
    proc = subprocess.Popen(
        [PYTHON, "ai_server.py"],
        cwd=ROOT,
        stdout=out_f,
        stderr=err_f,
    )
    return proc, out_f, err_f


def main():
    if not os.path.isdir(LOGS):
        os.makedirs(LOGS, exist_ok=True)

    # Anti double watchdog
    if os.path.isfile(PID_FILE):
        try:
            old = int(open(PID_FILE).read().strip())
            try:
                os.kill(old, 0)
                _log("[X] Un autre watchdog tourne deja (PID %d), je m'arrete." % old)
                return
            except OSError:
                pass
        except Exception:
            pass
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    _log("Watchdog ai_server demarre (watchdog PID %d, python=%s)" % (os.getpid(), PYTHON))
    _log("Zones de logs: %s" % LOGS)

    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_log = os.path.join(LOGS, "ai_server_guard_%s.out.log" % stamp)
    err_log = os.path.join(LOGS, "ai_server_guard_%s.err.log" % stamp)

    backoff = 2.0
    healthy_since = None
    fail_count = 0
    restarts = 0

    while True:
        if not _port_free():
            _log("[!] Port %d occupe -> kill instance zombie" % PORT)
            _kill_stale_on_port()

        restarts += 1
        _log(">> Lancement ai_server (tentative #%d, backoff=%ds)" % (restarts, int(backoff)))
        proc, out_f, err_f = _launch(out_log, err_log)

        # Attente warmup (jusqu'a ~40s : ML/db init)
        ok = False
        for _ in range(20):
            time.sleep(2)
            if _check_alive(proc):
                ok = True
                break
            if proc.poll() is not None:
                break

        if not ok:
            if proc.poll() is not None:
                _log("[X] ai_server s'est arrete pendant le warmup (code %s)." % proc.returncode)
            else:
                _log("[X] ai_server ne repond pas au /health apres le warmup -> kill /F")
                os.system("taskkill /F /PID %d >nul 2>&1" % proc.pid)
            time.sleep(backoff)
            backoff = min(backoff * 2, 30.0)
            healthy_since = None
            fail_count = 0
            continue

        _log("OK ai_server repond sur /health.")
        healthy_since = time.time()
        fail_count = 0
        backoff = 2.0

        # Supervision tant que le process vit
        while proc.poll() is None:
            time.sleep(CHECK_INTERVAL)
            if _check_alive(proc):
                fail_count = 0
                if time.time() - healthy_since > 600:
                    backoff = 2.0
                continue
            fail_count += 1
            if fail_count >= MAX_CONSECUTIVE_FAIL:
                _log("[!] /health muet %d fois de suite -> serveur GELE, taskkill /F" % fail_count)
                os.system("taskkill /F /PID %d >nul 2>&1" % proc.pid)
                try:
                    out_f.close()
                    err_f.close()
                except Exception:
                    pass
                break

        if proc.poll() is not None:
            _log("[X] ai_server arrete (code %s) -> relance" % proc.returncode)
            try:
                out_f.close()
                err_f.close()
            except Exception:
                pass
        time.sleep(backoff)
        backoff = min(backoff * 2, 30.0)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        _log("Interruption manuelle (Ctrl+C) - arret du watchdog")
        try:
            os.remove(PID_FILE)
        except Exception:
            pass
        sys.exit(0)