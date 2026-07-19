# Session 2026-07-10 — Setup Qwen 2.5 Coder via Ollama

## Résumé

Configuration de **qwen2.5-coder:7b** comme modèle local principal pour OpenCode et le serveur IA TradBOT.

## Actions effectuées

### 1. Vérification Ollama
- Ollama v0.31.2 installé et fonctionnel
- Modèles disponibles : `qwen2.5-coder:7b`, `qwen2.5-coder:1.5b`, `qwen3.5:4b`, `gemini-3-flash-preview`, `s80982708/ZINI-LOCAL:latest`, `glm-ocr:latest`

### 2. Test inférence
```
Modèle: qwen2.5-coder:7b
Prompt: "Bonjour"
Réponse: "Bonjour! Comment puis-je vous aider aujourd'hui?"
Latence: ~8.8s (580ms load + 1.2s prompt eval + 6.8s generation)
Tokens: 30 prompt → 36 réponse
```

### 3. Fichiers modifiés

**`.env`** — Ajout variables Ollama :
```
OLLAMA_MODEL=qwen2.5-coder:7b
OLLAMA_URL=http://localhost:11434/api/generate
```

**`.opencode/opencode.json`** — Switch modèle par défaut :
- `model` : `cerebras/qwen-3-coder-480b` → `ollama/qwen2.5-coder:7b`
- `small_model` : `cloudflare-workers-ai/...` → `ollama/qwen2.5-coder:1.5b`
- Agent `build` : `ollama/qwen2.5-coder:7b`
- Agent `explore` : `ollama/qwen2.5-coder:1.5b`
- Agent `plan` : garde `cerebras/qwen-3-coder-480b` (cloud, plus puissant)

### 4. Points importants
- Le provider Ollama était déjà configuré dans `opencode.json` avec `@ai-sdk/openai-compatible` sur `http://127.0.0.1:11434/v1`
- Le serveur IA (`ai_server.py`) utilise la variable `OLLAMA_MODEL` pour choisir le modèle (défaut reste `qwen3.5:4b` dans le code, mais `.env` override)
- Pour Claude Code : `export OPENAI_API_BASE=http://localhost:11434/v1 && export OPENAI_API_KEY=ollama`

## État
- ✅ Ollama fonctionnel
- ✅ qwen2.5-coder:7b répond
- ✅ OpenCode configuré avec le modèle local
- ⏳ Test tool-calling dans OpenCode en attente (utilisateur)
