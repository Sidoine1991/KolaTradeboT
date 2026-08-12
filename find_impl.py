import os

def find_implementation(filepath, func_name, max_lines_after=80):
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
        
        # Look for the actual function implementation (not just declaration)
        # Function implementations in MQL5 typically look like: return_type func_name(params) {
        for i, line in enumerate(lines):
            stripped = line.strip()
            # Match function implementation start
            if (stripped.startswith('bool ' + func_name) or stripped.startswith('string ' + func_name) or 
                stripped.startswith('double ' + func_name) or stripped.startswith('int ' + func_name) or
                stripped.startswith('void ' + func_name)) and '{' in stripped and ';' not in stripped:
                print('\n=== ' + func_name + ' implementation in ' + filepath + ' ===')
                for j in range(i, min(i+max_lines_after, len(lines))):
                    print(str(j+1) + ': ' + lines[j].rstrip())
                return
        print('Function implementation ' + func_name + ' not found in ' + filepath)
    except Exception as e:
        print('Error: ' + str(e))

find_implementation('D:/Dev/TradBOT/mt5/SMC_Universal.mq5', 'GetAISignalData', 80)
find_implementation('D:/Dev/TradBOT/mt5/SMC_Universal.mq5', 'GOM_GetATRValue', 80)