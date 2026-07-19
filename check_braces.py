import re

# Comprehensive check: find any identifier 'ge' standing alone (not in string/comment/char)
filepath = r'd:\Dev\TradBOT\mt5\SMC_Universal.mq5'
lines = open(filepath, 'r', encoding='utf-8', errors='replace').readlines()

for i, line in enumerate(lines, 1):
    clean = re.sub(r'//.*$', '', line)
    clean = re.sub(r'"[^"]*"', '""', clean)
    clean = re.sub(r"'[^']*'", "''", clean)
    # Find standalone 'ge' as identifier (word boundary)
    if re.search(r'\bge\b', clean) and not re.search(r'\bge[a-zA-Z_0-9]', clean):
        # Make sure 'ge' is actually standalone and not part of larger word
        matches = re.finditer(r'\bge\b', clean)
        for m in matches:
            # Verify it's a true standalone token
            print(f'Line {i}: col {m.start()} | {line.strip()[:120]}')

# Also check for lines where a variable name might be broken
# e.g., g_e without the rest
print("\n--- Checking for broken variable names ---")
for i, line in enumerate(lines, 1):
    clean = re.sub(r'//.*$', '', line)
    clean = re.sub(r'"[^"]*"', '""', clean)
    if re.search(r'\bge\s*$', clean.rstrip()):
        print(f'Line {i}: LINE ENDS WITH ge | {line.strip()[:120]}')
