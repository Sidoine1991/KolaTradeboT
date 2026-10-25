import pandas as pd

# Lecture en chunks pour gros fichiers
chunks = pd.read_csv('data/february_merged.csv', chunksize=100_000)

# Colonnes critiques à vérifier
critical_cols = ['close', 'high', 'low', 'open']

# Écriture du fichier nettoyé
with open('data/february_merged_clean.csv', 'w', newline='') as f_out:
    header_written = False
    for chunk in chunks:
        # Nettoyage des noms de colonnes
        chunk.columns = [col.strip().lower() for col in chunk.columns]
        # Vérifie la présence des colonnes critiques
        if all(col in chunk.columns for col in critical_cols):
            chunk = chunk.dropna(subset=critical_cols)
            for col in critical_cols:
                if chunk[col].dtype == object:
                    chunk = chunk[chunk[col].astype(str).str.strip() != '']
            if not header_written:
                chunk.to_csv(f_out, index=False, header=True)
                header_written = True
            else:
                chunk.to_csv(f_out, index=False, header=False)
        else:
            print("Colonnes critiques manquantes dans ce chunk, chunk ignoré.")

print("Nettoyage terminé. Fichier : data/february_merged_clean.csv") 