"""
Deploy ONNX spike models to MT5 terminal data directories.
Copies all model files to MQL5/Files/Models/<symbol>/ for each terminal.
"""
import os
import shutil

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, "models")

TERMINAL_DATA_DIRS = [
    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\415DD75DEF29D458F52EB44204841A9C",
    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\62DE0881527B5F589A310F71C9C0578C",
    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA",
    r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\F016FF5B93786543B564E81A925D7066",
]

# Verify valid terminal dirs
valid_terminals = [d for d in TERMINAL_DATA_DIRS if os.path.isdir(d)]
print(f"Valid terminals: {len(valid_terminals)}/{len(TERMINAL_DATA_DIRS)}")
for d in TERMINAL_DATA_DIRS:
    exists = os.path.isdir(d)
    print(f"  {os.path.basename(d)}: {'OK' if exists else 'MISSING'}")

for term_dir in valid_terminals:
    files_dir = os.path.join(term_dir, r"MQL5\Files\Models")
    os.makedirs(files_dir, exist_ok=True)

    copied = 0
    for sym_folder in os.listdir(MODELS_DIR):
        src = os.path.join(MODELS_DIR, sym_folder)
        dst = os.path.join(files_dir, sym_folder)
        if not os.path.isdir(src):
            continue

        os.makedirs(dst, exist_ok=True)
        for fname in os.listdir(src):
            if fname.endswith(".onnx"):
                shutil.copy2(os.path.join(src, fname), os.path.join(dst, fname))
                copied += 1

    print(f"  -> {os.path.basename(term_dir)}: {copied} ONNX files deployed")

print("Done.")
