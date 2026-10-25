"""Fabrique d'event loop asyncio pour uvicorn sur Windows.

Uvicorn >= 0.34 force ProactorEventLoop sur Windows via son loop_factory
(uvicorn/loops/asyncio.py), en IGNORANT WindowsSelectorEventLoopPolicy.
Le Proactor est fragile sur les déconnexions clients pendant AcceptEx
(WinError 64 "network name no longer available") : le listener meurt et le
processus reste vivant mais sourd (plus aucun socket d'écoute).

Cette fabrique est passée à uvicorn.run(loop="selector_loop:selector_loop_factory")
pour imposer une boucle Selector, robuste pour un serveur HTTP long-lived.
"""

import asyncio


def selector_loop_factory(use_subprocess: bool = False):
    """Retourne une instance de SelectorEventLoop (signature exigée par uvicorn)."""
    return asyncio.SelectorEventLoop()
