import os
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, isnan, count, when, to_timestamp, hour, dayofweek
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

# 1. Préparation du dossier de résultats
RESULTS_DIR = 'resultats'
os.makedirs(RESULTS_DIR, exist_ok=True)

# 2. Initialisation Spark
spark = SparkSession.builder.appName('EDA TradBOT').getOrCreate()

# 3. Chargement du CSV
csv_path = 'data/february_merged_cleaned.csv'
df = spark.read.option('header', True).option('inferSchema', True).csv(csv_path)

# 4. Infos générales
info_path = os.path.join(RESULTS_DIR, 'info.txt')
with open(info_path, 'w', encoding='utf-8') as f:
    f.write(f"Nombre de lignes : {df.count()}\n")
    f.write(f"Nombre de colonnes : {len(df.columns)}\n")
    f.write(f"Colonnes : {df.columns}\n")
    f.write(f"Schéma :\n{df.printSchema()}\n")

# 5. Valeurs manquantes
na_counts = df.select([count(when(col(c).isNull() | isnan(c), c)).alias(c) for c in df.columns])
na_pd = na_counts.toPandas().T
na_pd.columns = ['nb_na']
na_pd.to_csv(os.path.join(RESULTS_DIR, 'missing_values.csv'))

# 6. Statistiques descriptives
stats = df.describe()
stats_pd = stats.toPandas()
stats_pd.to_csv(os.path.join(RESULTS_DIR, 'describe.csv'), index=False)

# 7. Distributions (histogrammes)
numeric_cols = [f.name for f in df.schema.fields if str(f.dataType) in ['IntegerType', 'DoubleType', 'FloatType', 'LongType', 'ShortType']]
if numeric_cols:
    sample_pd = df.select(numeric_cols).sample(False, 0.1, seed=42).toPandas() if df.count() > 100000 else df.select(numeric_cols).toPandas()
    for colname in numeric_cols:
        plt.figure(figsize=(6,4))
        sns.histplot(sample_pd[colname].dropna().values, kde=True, bins=50)
        plt.title(f'Distribution de {colname}')
        plt.savefig(os.path.join(RESULTS_DIR, f'hist_{colname}.png'))
        plt.close()

# 8. Corrélations
if len(numeric_cols) > 1:
    corr = sample_pd.corr()
    corr.to_csv(os.path.join(RESULTS_DIR, 'correlation_matrix.csv'))
    plt.figure(figsize=(10,8))
    sns.heatmap(corr, annot=True, fmt='.2f', cmap='coolwarm')
    plt.title('Matrice de corrélation')
    plt.tight_layout()
    plt.savefig(os.path.join(RESULTS_DIR, 'correlation_heatmap.png'))
    plt.close()

# 9. Outliers (z-score > 3)
if numeric_cols:
    zscores = np.abs((sample_pd[numeric_cols] - sample_pd[numeric_cols].mean()) / sample_pd[numeric_cols].std())
    outlier_counts = (zscores > 3).sum()
    outlier_counts.to_csv(os.path.join(RESULTS_DIR, 'outliers_zscore.csv'))

# 10. Analyse temporelle si colonne date
date_cols = [c for c in df.columns if 'date' in c.lower() or 'time' in c.lower()]
if date_cols:
    date_col = date_cols[0]
    df = df.withColumn('datetime', to_timestamp(col(date_col)))
    df = df.withColumn('hour', hour(col('datetime')))
    df = df.withColumn('dayofweek', dayofweek(col('datetime')))
    time_pd = df.select('hour', 'dayofweek').dropna().toPandas()
    plt.figure(figsize=(6,4))
    sns.countplot(x='hour', data=time_pd)
    plt.title('Répartition par heure')
    plt.savefig(os.path.join(RESULTS_DIR, 'count_hour.png'))
    plt.close()
    plt.figure(figsize=(6,4))
    sns.countplot(x='dayofweek', data=time_pd)
    plt.title('Répartition par jour de la semaine')
    plt.savefig(os.path.join(RESULTS_DIR, 'count_dayofweek.png'))
    plt.close()

# 11. Analyse de la cible si présente
for target_col in ['is_spike', 'target', 'label']:
    if target_col in df.columns:
        target_pd = df.groupBy(target_col).count().toPandas()
        target_pd.to_csv(os.path.join(RESULTS_DIR, f'{target_col}_distribution.csv'), index=False)
        plt.figure(figsize=(5,4))
        sns.barplot(x=target_col, y='count', data=target_pd)
        plt.title(f'Distribution de {target_col}')
        plt.savefig(os.path.join(RESULTS_DIR, f'{target_col}_distribution.png'))
        plt.close()
        break

print(f"EDA terminée. Résultats sauvegardés dans {RESULTS_DIR}/") 