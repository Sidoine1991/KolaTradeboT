fp = r'd:\Dev\TradBOT\ai_server.py'
with open(fp, 'r', encoding='utf-8') as f:
    s = f.read()
# Replace literal backslash-n sequences with real newlines
s2 = s.replace('\\n', '\n')
if s2 != s:
    with open(fp, 'w', encoding='utf-8', newline='') as f:
        f.write(s2)
    print('Repaired literal\\n to newlines.')
else:
    print('No literal \\n sequences found.')
