"""Smart brace counter for MQL5 files.
Handles string literals, char literals, and line comments."""
import re, sys

def count_braces(filepath):
    lines = open(filepath, 'r', encoding='utf-8').readlines()
    total = 0
    first_negative = None
    # Track balance at every line
    balances = []

    in_block_comment = False

    for i, line in enumerate(lines, 1):
        old_total = total

        # Process character by character to handle strings/comments properly
        j = 0
        raw = line
        cleaned = []
        while j < len(raw):
            ch = raw[j]

            # Block comment
            if in_block_comment:
                if ch == '*' and j+1 < len(raw) and raw[j+1] == '/':
                    in_block_comment = False
                    j += 2
                    continue
                j += 1
                continue

            # Start of block comment
            if ch == '/' and j+1 < len(raw) and raw[j+1] == '*':
                in_block_comment = True
                j += 2
                continue

            # Line comment
            if ch == '/' and j+1 < len(raw) and raw[j+1] == '/':
                break  # rest of line is comment

            # Double-quoted string
            if ch == '"':
                j += 1
                while j < len(raw):
                    if raw[j] == '\\' and j+1 < len(raw):
                        j += 2  # skip escaped char
                        continue
                    if raw[j] == '"':
                        j += 1
                        break
                    j += 1
                continue

            # Single-quoted char
            if ch == "'":
                j += 1
                while j < len(raw):
                    if raw[j] == '\\' and j+1 < len(raw):
                        j += 2
                        continue
                    if raw[j] == "'":
                        j += 1
                        break
                    j += 1
                continue

            cleaned.append(ch)
            j += 1

        clean_line = ''.join(cleaned)
        opens = clean_line.count('{')
        closes = clean_line.count('}')
        total += opens - closes
        balances.append((i, old_total, total, line.rstrip()[:150], clean_line.rstrip()[:150]))

        if first_negative is None and total < 0:
            first_negative = i

    return total, first_negative, balances

if __name__ == '__main__':
    filepath = sys.argv[1] if len(sys.argv) > 1 else 'mt5/SMC_Universal.mq5'
    total, first_neg, balances = count_braces(filepath)
    print(f'Final balance: {total}')
    print(f'First negative at line: {first_neg}')

    # Show context around first negative
    if first_neg:
        for i, old, new, raw, clean in balances:
            if first_neg - 5 <= i <= first_neg + 5:
                print(f'  L{i:5d} [{old:+3d}->{new:+3d}] RAW: {raw[:120]}')
