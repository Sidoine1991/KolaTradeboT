import codecs
with codecs.open(r'd:\Dev\TradBOT\SMC_Universal.mq5', 'r', 'utf-8', errors='ignore') as f:
    lines = f.readlines()
with open(r'd:\Dev\TradBOT\grep_out.txt', 'w', encoding='utf-8') as out:
    for i, line in enumerate(lines):
        if 'CheckAndExecuteSpikeTrade' in line or 'OnTick' in line or 'CheckImminentSpike' in line or 'IsVolatility' in line or 'CheckAndExecuteDerivArrowTrade' in line or 'ExecuteOTEImbalanceTrade' in line:
            out.write(f'{i+1}: {line.strip()}\n')
