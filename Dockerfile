# Python 3.12 : wheels mistralai / pydantic / xgboost cohérents avec PyPI (évite « No matching distribution » sur pip ancien)
FROM python:3.12-slim-bookworm

WORKDIR /app

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# pip récent : résolution correcte des Requires-Python (mistralai 1.12+ exige Python >=3.10)
RUN python -m pip install --no-cache-dir --upgrade "pip>=25.0" "setuptools>=75.0" wheel

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
