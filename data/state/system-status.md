# System Status

**Last updated**: 2026-05-19

## Deployment

| Component | Status | Notes |
|---|---|---|
| AI Server (local) | Unknown | Run `run_server.bat` to start |
| AI Server (Render) | Unknown | Check `USE_RENDER_AI_SERVER` in `.env` |
| Supabase / PostgreSQL | Unknown | Verify `DATABASE_URL` in `.env` |
| MT5 EA (SMC_Universal) | Unknown | Compile in MetaEditor before attaching |

## Last Known Issues

- Compilation errors resolved as of commit `82a25e54`
- Auto-entry gates lowered/removed in recent commits

## Health Check

Run `/deploy-check` to get a live status report.
