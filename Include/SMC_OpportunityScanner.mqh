//+------------------------------------------------------------------+
//| SMC_OpportunityScanner.mqh - Multi-symbol Opportunity Scanner   |
//+------------------------------------------------------------------+
#ifndef SMC_OPPORTUNITY_SCANNER_MQH
#define SMC_OPPORTUNITY_SCANNER_MQH

class COpportunityScanner
{
public:
   COpportunityScanner() {}
   ~COpportunityScanner() {}

   void SetScanInterval(int seconds) {}
   void SetPanelPosition(int x, int y) {}
   void SetPanelWidth(int width) {}
   void SetRowHeight(int height) {}
   void ShowPanel(bool show) {}

   void EnableAutoTrading(bool enable, double riskDollars, double tp, double sl,
                         bool trailing, double trailingPoints, double trailingStep) {}
};

#endif
