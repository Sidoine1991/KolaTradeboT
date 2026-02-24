# Importation des bibliothèques nécessaires
import dash
from dash import dcc  # dash_core_components
from dash import html # dash_html_components
from dash.dependencies import Input, Output
import plotly.graph_objs as go
from collections import deque
import random
import datetime

# Initialisation de l'application Dash
app = dash.Dash(__name__)

# File d'attente pour stocker les données en temps réel (limitée à 20 points)
X = deque(maxlen=20)
Y = deque(maxlen=20)

# Données initiales
X.append(1)
Y.append(1)

# Définition de la mise en page (layout) de l'application
app.layout = html.Div(
    [
        html.H1("Tableau de Bord en Temps Réel", style={'textAlign': 'center'}),
        dcc.Graph(id='live-graph', animate=True),
        dcc.Interval(
            id='graph-update',
            interval=1*1000,  # Mise à jour toutes les secondes (en millisecondes)
            n_intervals=0
        ),
    ]
)

# Définition du 'callback' pour mettre à jour le graphique
@app.callback(
    Output('live-graph', 'figure'),
    [Input('graph-update', 'n_intervals')]
)
def update_graph_scatter(n):
    # Ajout de nouvelles données à la file d'attente
    X.append(X[-1] + 1)
    Y.append(Y[-1] + (Y[-1] * random.uniform(-0.1, 0.1)))

    # Création de la figure du graphique
    data = go.Scatter(
        x=list(X),
        y=list(Y),
        name='Scatter',
        mode='lines+markers'
    )

    # Mise à jour de la mise en page du graphique
    return {'data': [data], 'layout': go.Layout(
        xaxis=dict(range=[min(X), max(X)]),
        yaxis=dict(range=[min(Y), max(Y)]),
        title='Graphique en Temps Réel'
    )}

# Point d'entrée pour exécuter l'application
if __name__ == '__main__':
    app.run_server(debug=True)