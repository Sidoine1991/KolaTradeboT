"""
TradBOT Core Engine
===================
Architecture centralisée pour le trading automatisé sur MT5.

Modules:
  order_manager.py     — Exécution des ordres avec validation SL/TP stricte
  chart_patterns.py    — Détection temps réel des patterns SMC (BOS, CHoCH, FVG, OB)
  gom_handler.py       — Intégration des verdicts GOM avec exploitation des patterns
  risk_manager.py      — Gestion des risques, sizing, daily budget, position limits
  notification.py      — Alertes WhatsApp/Telegram pour tous les événements
  engine.py            — Orchestrateur central liant tous les modules

Dépendances:
  - MT5 terminal (MetaTrader5)
  - FastAPI server (ai_server.py)
  - Agents (agents/)
"""
