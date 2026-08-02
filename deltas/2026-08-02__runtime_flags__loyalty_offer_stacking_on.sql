-- Delta: runtime_flags.loyalty_offer_stacking false -> true (ACTIVATION)
-- Applied: 2026-08-02 13:41:30 UTC via Supabase MCP execute_sql, project hrzpznlpmxxrbtwskacu
-- Authorized: Mike, in-session founder decision ("Flip it now"), Cowork loyalty-offers session
-- Gates closed before flip:
--   1. WS-1 Tier-1 verification — all 10 loyalty_stack offers issuer_confirmed (0.95-0.97)
--   2. APP-017 TestFlight build pushed; audience is Mike's circle only (founder ruling 2026-08-01:
--      adoption a non-issue until GA)
--   3. Founder flip (this delta) + PROJECT_RULES rule 5 update (same commit)
-- Pre-state verified in the same session: enabled=false; 10 offers / 7 issuer scopes /
--   7 loyalty scopes / 3 excluded cards / 9 programs / fuel 165.00 on cloud.
-- Guard: WHERE enabled = false; RETURNING confirmed exactly one row.
-- Note: the in-DB note field says "ACTIVATED 2026-08-01" (authored date); the authoritative
--   application timestamp is updated_at = 2026-08-02 13:41:30 UTC. This file carries the landing date.

update public.runtime_flags
set enabled = true,
    note = 'ACTIVATED 2026-08-01 by Mike (founder decision, in-session). Gates closed: WS-1 Tier-1 verification (all offers issuer_confirmed 0.95+), APP-017 TestFlight build pushed (circle-only audience, Mike ruling 2026-08-01). Delta: 2026-08-01__runtime_flags__loyalty_offer_stacking_on.sql',
    updated_at = now()
where key = 'loyalty_offer_stacking' and enabled = false
returning key, enabled, updated_at;

-- Rollback (founder decision required, same discipline):
-- update public.runtime_flags set enabled = false, updated_at = now()
--   where key = 'loyalty_offer_stacking' and enabled = true;
