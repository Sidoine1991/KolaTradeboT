path = r'D:\Dev\TradBOT\mt5\modules\SMC_GOM_Pipeline.mqh'
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    c = f.read()

# 1. Add Weltrade volatility helper and SMCGP_TradingTfLabel after SMCGP_ChartTfLabel closing brace
old1 = '''    }
}

string SMCGP_EncodeSym'''

new1 = '''    }
}

bool SMCGP_IsWeltradeVolSymbol(const string sym)
{
    string s = sym;
    StringToUpper(s);
    return (StringFind(s, "FXVOL") >= 0 || StringFind(s, "SFXVOL") >= 0 ||
            StringFind(s, "SFVVOL") >= 0 || StringFind(s, "FX VOL") >= 0 ||
            (StringFind(s, "VOL ") >= 0 && StringFind(s, "BOOM") < 0 && StringFind(s, "CRASH") < 0));
}

string SMCGP_TradingTfLabel()
{
    if(SMCGP_IsWeltradeVolSymbol(_Symbol))
       return "M15";
    return SMCGP_ChartTfLabel();
}

string SMCGP_EncodeSym'''

c = c.replace(old1, new1)

# 2. In poll: replace chartTf label for Weltrade volatility
# Find the poll function's chartTf assignment
old2 = 'string chartTf = SMCGP_ChartTfLabel();\n    string srcParam = "local";\n    if(GOMVerdictSource == GOM_SRC_TRADINGVIEW)'
new2 = 'string chartTf = SMCGP_TradingTfLabel();\n    string srcParam = "local";\n    if(GOMVerdictSource == GOM_SRC_TRADINGVIEW)'
c = c.replace(old2, new2)

with open(path, 'w', encoding='utf-8') as f:
    f.write(c)

print('OK')