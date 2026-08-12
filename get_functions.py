import os
import sys

def get_function_lines(filepath, func_name, lines_after=40):
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
        
        for i, line in enumerate(lines):
            if f'{func_name}(' in line or f'{func_name} :' in line:
                print('\n=== ' + func_name + ' in ' + filepath + ' ===')
                for j in range(i, min(i+lines_after, len(lines))):
                    print(str(j+1) + ': ' + lines[j].rstrip())
                return
        print('Function ' + func_name + ' not found in ' + filepath)
    except Exception as e:
        print('Error reading ' + filepath + ': ' + str(e))

# Get the actual implementations
get_function_lines('D:/Dev/TradBOT/mt5/SMC_Universal.mq5', 'GetAISignalData', 50)
get_function_lines('D:/Dev/TradBOT/mt5/SMC_Universal.mq5', 'GOM_GetATRValue', 50)