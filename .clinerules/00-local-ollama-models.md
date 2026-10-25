# Règles modèles locaux (Ollama) — Cline

## Modèle à utiliser par défaut
- **Toujours utiliser `qwen2.5-coder-fast:7b`** pour l'agent Cline (Coder/Plan/Act).
- Base URL Ollama locale : `http://localhost:11434` (jamais `https://`).
- Context window : `32768`.

## Modèles INTERDITS pour l'agent
- **`gemma3n-e2b:latest`** : ne supporte PAS les *tools* (`Capabilities: completion` uniquement).
  Cline exige un modèle tool-capable → erreur « does not support tools ».
  Ne jamais le sélectionner dans le picker Cline.
- Tout modèle dont l'ID n'apparaît pas dans `ollama list` (ex. `gpt-oss:20b`, `gpt-5.6-sol`, `que`) : inexistant → erreur « model not found ».

## Modèles locaux tool-capables autorisés (vérifiés)
- `qwen2.5-coder-fast:7b`  (recommandé)
- `qwen2.5-coder:7b`
- `qwen2.5-coder:1.5b`     (léger, chat)
- `qwen3.5:4b`
- `s80982708/ZINI-LOCAL:latest`

## Rappels de configuration
- Le champ « Model ID » doit correspondre EXACTEMENT au tag de `ollama list`.
- Ne pas mettre `https://` pour Ollama local (sinon `ERR_SSL_WRONG_VERSION_NUMBER`).
- Laisse les champs modèles des autres providers vides pour éviter les IDs invalides.
