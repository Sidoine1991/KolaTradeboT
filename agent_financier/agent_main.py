import logging
from scanner.symbol_scanner import SymbolScanner
from analyzer.smc_analyzer import SMC_Analyzer

logging.basicConfig(level=LOGgING.INFO)
logger = logging.getLogger(__name__)

class AgentFinancier:
    def __init__(self):
        self.scanner = SymbolScanner()
        self.analyzer = SMC_Analyzer()

    def run(self):
        logger.info("Agent financier SMC demarre")
        symbols = self.scanner.get_all_symbols()
        logger.info(f"Symboles: {len(symbols)}")
        return symbols

if __name__ == '__main__':
    agent = AgentFinancier()
    agent.run()
