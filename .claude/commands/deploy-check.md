---
description: "Pre-deployment checklist: env vars, server health, git clean, Render readiness."
---

Run the TradBOT deployment readiness check:

1. **Git state**: Run `git status --short`. If there are uncommitted changes, list them and warn.
2. **Environment**: Check `.env` exists and contains all keys listed in `.env.example`. List any missing keys.
3. **Server health** (local): Attempt `curl -s http://localhost:8000/health` (or equivalent). Report response or failure.
4. **Render config**: Check if `USE_RENDER_AI_SERVER` and `RENDER_AI_SERVER_URL` are set in `.env`.
5. **Python deps**: Verify `.venv` exists and `pip list` includes `fastapi`, `uvicorn`, `pydantic`, `pandas`, `scikit-learn`.
6. Output a checklist:
   - [ ] Git clean / staged
   - [ ] All .env keys present
   - [ ] Local server healthy
   - [ ] Render URL configured
   - [ ] Dependencies installed
7. If all checks pass: "Prêt pour déploiement. Lance le serveur avec run_server.bat."
   If any check fails: "Blockers trouvés — règle les points ci-dessus avant de déployer."
