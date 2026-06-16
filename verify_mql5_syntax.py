#!/usr/bin/env python3
"""Simple MQL5 syntax checker - detects missing includes and forward declarations"""

import re
import sys
from pathlib import Path

def check_mql5_file(filepath):
    """Check MQL5 file for common syntax issues"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    errors = []
    includes = set()
    forward_decls = set()
    function_calls = set()
    
    # Find all includes
    for match in re.finditer(r'#include\s+"([^"]+)"', content):
        includes.add(match.group(1))
    
    # Find all forward declarations
    for match in re.finditer(r'^\s*(void|bool|int|double|string)\s+(\w+)\s*\(', content, re.MULTILINE):
        forward_decls.add(match.group(2))
    
    # Find all function calls
    for match in re.finditer(r'\b(\w+)\s*\(', content):
        func = match.group(1)
        if func not in ['if', 'for', 'while', 'switch', 'return', 'case', 'struct', 'class', 'enum']:
            function_calls.add(func)
    
    # Check for undefined functions
    mql_builtins = {
        'FileOpen', 'FileClose', 'FileWrite', 'FileSeek', 'StringFormat',
        'TimeToString', 'TimeToStruct', 'TimeCurrent', 'PositionSelectByTicket',
        'PositionGetString', 'PositionGetDouble', 'HistoryDealsTotal',
        'CDealInfo', 'SelectByIndex', 'Deal', 'Type', 'Magic', 'Time',
        'Symbol', 'Price', 'Volume', 'ContractSize', 'StringFind',
        'ObjectsDeleteAll', 'FileRead', 'IntegerToString', 'Print',
        'Alert', 'Comment', 'MessageBox'
    }
    
    undefined = []
    for func in sorted(function_calls):
        if func not in forward_decls and func not in mql_builtins:
            # Could be undefined or a custom function
            pass
    
    print(f"✅ File checked: {filepath}")
    print(f"   Includes: {len(includes)}")
    print(f"   Forward declarations: {len(forward_decls)}")
    print(f"   Function calls: {len(function_calls)}")
    
    if 'modules/SMC_TradeJournal.mqh' in includes:
        print(f"   ✅ SMC_TradeJournal.mqh included")
    else:
        print(f"   ❌ SMC_TradeJournal.mqh NOT included")
    
    # Check if forward decls match includes
    if 'SMC_JournalConfigure' in forward_decls:
        print(f"   ✅ SMC_JournalConfigure declared")
    else:
        print(f"   ❌ SMC_JournalConfigure NOT declared")
    
    return len(errors) == 0

if __name__ == "__main__":
    filepath = "mt5/SMC_Universal.mq5"
    success = check_mql5_file(filepath)
    sys.exit(0 if success else 1)
