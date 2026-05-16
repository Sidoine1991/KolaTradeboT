# Python 3.12 : wheels mistralai / pydantic / xgboost cohérents avec PyPI (évite « No matching distribution » sur pip ancien)
FROM python:3.12-slim-bookworm

WORKDIR /app

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# LightGBM / XGBoost : libgomp requis sur python:slim (sinon libgomp.so.1 manquant au démarrage)
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# pip récent : résolution correcte des Requires-Python (mistralai 1.12+ exige Python >=3.10)
RUN python -m pip install --no-cache-dir --upgrade "pip>=25.0" "setuptools>=75.0" wheel

# CACHE BUSTER - Force full rebuild 2026-05-16T22:30:00Z
RUN echo "Invalidating Docker layer cache for clean ai_server deployment"

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

# Commande de démarrage — lancer ai_server.py directement (gère ses propres arguments --host et --port)
# Render injecte PORT ; défaut 10000 pour build local.
ENV PORT=10000
CMD ["sh", "-c", "exec python ai_server.py --host 0.0.0.0 --port ${PORT:-10000}"]
