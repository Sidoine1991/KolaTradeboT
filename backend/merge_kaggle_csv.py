import os
import glob
import pandas as pd

# Dossier où sont les CSV à fusionner
# Adapter pour Windows et chemin absolu
csv_dir = r'D:/Dev/TradBOT/February'
output_csv = 'data/tes_donnees.csv'

os.makedirs('data', exist_ok=True)

csv_files = glob.glob(os.path.join(csv_dir, '*.csv'))
if not csv_files:
    raise FileNotFoundError(f"Aucun fichier CSV trouvé dans {csv_dir}. Vérifie le chemin et le nom des fichiers.")

all_dfs = []
for csv_path in csv_files:
    filename = os.path.basename(csv_path)
    # Extraire le symbole/devise du nom de fichier (avant le 1er _ ou .)
    symbol = filename.split('_')[0].split('.')[0]
    try:
        df = pd.read_csv(csv_path, sep=None, engine='python')
        # Ajouter la colonne 'symbol' ou 'devise'
        df['symbol'] = symbol
        all_dfs.append(df)
        print(f"OK : {csv_path} ({len(df)} lignes, symbol : {symbol})")
    except Exception as e:
        print(f"Erreur lors de la lecture de {csv_path} : {e}")

if not all_dfs:
    raise ValueError(f"Aucun DataFrame valide n'a été chargé depuis les CSV de {csv_dir}.")

# Fusionner tous les DataFrames
merged = pd.concat(all_dfs, ignore_index=True)

# Sauvegarder le CSV fusionné
merged.to_csv(output_csv, index=False)
print(f"Fichier fusionné sauvegardé dans {output_csv} ({len(merged)} lignes)") 