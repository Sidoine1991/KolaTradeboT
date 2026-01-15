FROM python:3.11.7-slim

WORKDIR /app

# Copier les fichiers de configuration
COPY requirements-cloud.txt .
COPY pyproject.toml .
COPY .python-version .

# Installer les dépendances
RUN pip install --no-cache-dir -r requirements-cloud.txt

# Copier le code source
COPY . .

# Exposer le port
EXPOSE 10000

# Commande de démarrage
CMD ["uvicorn", "ai_server_cloud:app", "--host", "0.0.0.0", "--port", "10000"]
