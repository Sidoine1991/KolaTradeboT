#!/usr/bin/env python3
"""chart_generator.py – Génération des charts."""
import logging
from pathlib import Path
from typing import List
from mcp_bridge import TradingViewSetup

logger = logging.getLogger(__name__)


class ChartGenerator:
    def __init__(self, output_dir: str = "./agent_financier/charts"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def generate_all_charts(self, setups: List[TradingViewSetup]) -> List[str]:
        paths = []
        for setup in setups:
            # Placeholder: création d'un fichier vide pour démonstration
            path = self.output_dir / f"{setup.symbol}.png"
            path.touch()
            paths.append(str(path))
            logger.info("Chart placeholder pour %s", setup.symbol)
        return paths
