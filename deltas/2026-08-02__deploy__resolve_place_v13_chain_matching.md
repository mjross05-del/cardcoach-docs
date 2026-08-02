# Deploy record: resolve-place v13 (chain-aware entity matching)
- Applied: 2026-08-02 via Supabase MCP (merge b13595f concluded in Mike's tree; migration
  chain_entity_matching applied via apply_migration with schema_migrations version
  reconciled to 20260802160000 to match the local file; 48 entities flagged is_chain).
- resolve-place deployed v13 (verify_jwt=false preserved, import map deno.json, 10 files).
  Boot verified: GET 405 probe + live POST 200s on v13 within seconds of deploy.
- NOT yet deployed: recommend-here-v2 (import closure 40 files / 287KB exceeds the MCP
  deploy channel). Its chain-matching code is on main; ship with:
    cd ~/dev/CardCoachv2/mobile_app_codebase && npx supabase functions deploy recommend-here-v2
  Until then, the nearby flow may still mint location-suffixed orphan entities; the
  resolve path (store tap / Find Stores) is fixed. Orphans repair the same way as the
  2026-08-02 re-pointing delta.
- Rollback: redeploy prior content from git (v12 files = commit 702407f state).
