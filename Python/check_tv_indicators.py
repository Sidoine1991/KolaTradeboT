#!/usr/bin/env python3
"""
Check quel indicateurs sont chargés sur TradingView XAUUSD
"""
import sys
import logging

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# Configuration
try:
    from gom_verdict_poller import _ensure_tv_ready, _read_via_mcp_reader_mjs

    log.info("🔍 Vérification des indicateurs TradingView...")

    # Connecter à TradingView
    _ensure_tv_ready()

    # Lire les données MCP (qui inclut les noms d'indicateurs)
    data = _read_via_mcp_reader_mjs("XAUUSD")

    if data:
        studies = data.get("studies", [])
        log.info(f"✅ {len(studies)} indicateurs trouvés sur XAUUSD:")
        for study in studies:
            name = study.get("name") or study.get("title") or "?"
            log.info(f"   - {name}")

        # Chercher GOM
        gom_found = any("GOM" in (s.get("name") or s.get("title") or "") for s in studies)
        if gom_found:
            log.info("✅ Indicateur GOM trouvé!")
        else:
            log.warning("❌ Indicateur GOM KOLA SIDO NOT FOUND")
            log.warning("   Solution: Charger manuellement l'indicateur sur TradingView")
    else:
        log.error("❌ Erreur lecture MCP — TradingView pas accessible?")

except Exception as e:
    log.error(f"Erreur: {e}", exc_info=True)
