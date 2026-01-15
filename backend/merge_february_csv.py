import os
import glob
import pandas as pd

# Dossier source et fichier de sortie
SOURCE_DIR = r'D:/Dev/TradBOT/February'
OUTPUT_FILE = 'data/february_merged.csv'

# Créer le dossier data/ si besoin
os.makedirs('data', exist_ok=True)

# Lister tous les CSV
csv_files = glob.glob(os.path.join(SOURCE_DIR, '*.csv'))
print(f"{len(csv_files)} fichiers CSV trouvés dans {SOURCE_DIR}")

all_dfs = []
for file in csv_files:
    try:
        df = pd.read_csv(file)
        # Ajouter une colonne symbol si possible
        symbol = os.path.splitext(os.path.basename(file))[0]
        if 'symbol' not in df.columns:
            df['symbol'] = symbol
        all_dfs.append(df)
        print(f"OK: {file} ({len(df)} lignes)")
    except Exception as e:
        print(f"Erreur lecture {file}: {e}")

if all_dfs:
    merged = pd.concat(all_dfs, ignore_index=True)
    merged.to_csv(OUTPUT_FILE, index=False)
    print(f"Fusion terminée: {OUTPUT_FILE} ({len(merged)} lignes)")
else:
    print("Aucun fichier fusionné.") 