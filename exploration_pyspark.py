# Analyse exploratoire avancée avec PySpark, Pandas et Plotly
# Ce script explore le fichier data/february_merged.csv et exporte les résultats dans le dossier eda_exports
# Prérequis : pip install pyspark pandas plotly

from pyspark.sql import SparkSession
import os
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.figure_factory as ff
from pyspark.sql.functions import col, isnan, when, count, hour, dayofmonth, to_timestamp
from pyspark.ml.stat import Correlation
from pyspark.ml.feature import VectorAssembler

# 1. Initialisation de la SparkSession
spark = SparkSession.builder.appName("EDA TradBOT").getOrCreate()
spark.sparkContext.setLogLevel("WARN")

# 2. Chargement du CSV fusionné
df = spark.read.option('header', True).option('inferSchema', True).csv('data/february_merged.csv')
df.cache()
print(f'Nombre de lignes : {df.count()}')
df.printSchema()
df.show(5)

# 3. Statistiques descriptives de base et export
os.makedirs('eda_exports', exist_ok=True)
desc = df.describe().toPandas()
desc.to_csv('eda_exports/stats_descriptives.csv', index=False)
print(desc)

# Compter les valeurs nulles par colonne et export
nulls = df.select([count(when(col(c).isNull() | isnan(c), c)).alias(c) for c in df.columns])
nulls_pd = nulls.toPandas()
nulls_pd.to_csv('eda_exports/nulls_count.csv', index=False)
print(nulls_pd)

# 4. Analyse des doublons et export
nb_doublons = df.count() - df.dropDuplicates().count()
with open('eda_exports/nb_doublons.txt', 'w') as f:
    f.write(str(nb_doublons))
print(f'Nombre de doublons : {nb_doublons}')

# 5. Valeurs uniques et distribution (symbol/time) + export
symbol_dist = df.groupBy('symbol').count().orderBy('count', ascending=False).toPandas()
symbol_dist.to_csv('eda_exports/distribution_symbol.csv', index=False)
print(symbol_dist)
time_dist = df.groupBy('time').count().orderBy('count', ascending=False).toPandas()
time_dist.to_csv('eda_exports/distribution_time.csv', index=False)
print(time_dist.head())

# 6. Matrice de corrélation (colonnes numériques) + export
num_cols = [f.name for f in df.schema.fields if str(f.dataType) in ['DoubleType', 'IntegerType', 'LongType', 'FloatType'] and f.name not in ['digits', 'direction']]
assembler = VectorAssembler(inputCols=num_cols, outputCol='features')
df_vec = assembler.transform(df).select('features')
corr_matrix = Correlation.corr(df_vec, 'features', 'pearson').head()[0].toArray()
pd.set_option('display.max_columns', None)
corr_df = pd.DataFrame(corr_matrix, columns=num_cols, index=num_cols)
corr_df.to_csv('eda_exports/correlation_matrix.csv')
print(corr_df)

# 7. Visualisation de distributions (histogrammes interactifs Plotly) + export
sample_pd = df.select(num_cols).sample(False, 0.01, seed=42).toPandas()
for col in num_cols:
    fig = px.histogram(sample_pd, x=col, nbins=50, title=f'Histogramme interactif de {col}')
    fig.write_image(f'eda_exports/hist_{col}.png')
    fig.show()

# 8. Heatmap de corrélation interactive (Plotly) + export
fig = ff.create_annotated_heatmap(z=corr_df.values, x=list(corr_df.columns), y=list(corr_df.index), colorscale='Viridis')
fig.write_image('eda_exports/heatmap_correlation.png')
fig.show()

# 9. Détection d'outliers (z-score, IQR) + export
outlier_report = []
for col in num_cols:
    vals = sample_pd[col].dropna()
    z = (vals - vals.mean()) / vals.std()
    outliers = (np.abs(z) > 3).sum()
    outlier_report.append({'col': col, 'outliers': int(outliers), 'total': int(len(vals))})
outlier_df = pd.DataFrame(outlier_report)
outlier_df.to_csv('eda_exports/outliers_report.csv', index=False)
print(outlier_df)

# 10. Analyse temporelle (heure/jour) + export
if 'time' in df.columns:
    df_time = df.withColumn('time_ts', to_timestamp('time'))
    hour_dist = df_time.groupBy(hour('time_ts').alias('heure')).count().orderBy('heure').toPandas()
    hour_dist.to_csv('eda_exports/distribution_heure.csv', index=False)
    print(hour_dist)
    day_dist = df_time.groupBy(dayofmonth('time_ts').alias('jour')).count().orderBy('jour').toPandas()
    day_dist.to_csv('eda_exports/distribution_jour.csv', index=False)
    print(day_dist)

# 11. Analyse de la target (is_spike) + export
if 'is_spike' in df.columns:
    target_dist = df.groupBy('is_spike').count().toPandas()
    target_dist.to_csv('eda_exports/distribution_is_spike.csv', index=False)
    print(target_dist)
    for col in num_cols:
        mean_df = df.groupBy('is_spike').agg({col: 'mean'}).toPandas()
        mean_df.to_csv(f'eda_exports/mean_{col}_by_is_spike.csv', index=False)
        print(mean_df)
else:
    print("Colonne 'is_spike' absente du dataset.") 