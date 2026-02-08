import shutil

# Backup
shutil.copy('ai_server.py', 'ai_server_backup.py')

# Read and fix basic indentation
with open('ai_server.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the main indentation issue
content = content.replace('for i in range(periods):\nif np.random.random()', 'for i in range(periods):\n            if np.random.random()')

# Save fixed version
with open('ai_server.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("Basic indentation fix applied")
