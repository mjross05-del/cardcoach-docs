-- =========================================================================
-- STATUS NOTE ADDED 2026-08-27 — THIS FILE NO LONGER DESCRIBES PRODUCTION.
-- This delta seeds receipt_scanner OFF and asserts a post-state of
-- enabled = false ("Ships DARK"). Production now reads:
--     receipt_scanner  enabled = TRUE   (updated_at 2026-08-17 02:42:50 UTC)
-- The flip happened the same day this was applied and NO "ON" delta was ever
-- filed, so this file is currently the only record of the flag and it states
-- the opposite of the truth. Its own header asks for that ON delta: "The ON
-- delta belongs beside this file when flipped, per the tie_disclosure /
-- loyalty_offer_stacking pattern." That is still outstanding.
-- Do not re-run this file to "restore" the documented state — it would turn a
-- live feature off.
-- =========================================================================

-- DELTA 2026-08-17 — seed runtime_flags.receipt_scanner = false (rule 9(b)).
--
-- APPLIED 2026-08-17 02:42:50 UTC via MCP apply_migration, remote version
-- 20260817024250. Local migration: mobile_app_codebase/supabase/migrations/
-- 20260817024250_api_017_receipt_scanner_flag.sql.
--
-- Ships DARK. Global gate for API-017 / APP-021; per-user access additionally
-- requires the ENT-001 receipt_scanner entitlement. Both must pass.
--
-- Pre-state asserted: 4 rows in runtime_flags, no receipt_scanner row.
-- Post-state asserted: receipt_scanner present, enabled = false.
-- Snapshot: runtime_flags_snapshot_20260817 (secured in the same transaction).
--
-- Flip preconditions are recorded in the migration header. The ON delta belongs
-- beside this file when flipped, per the tie_disclosure / loyalty_offer_stacking
-- pattern.

INSERT INTO public.runtime_flags (key, enabled, note)
VALUES (
  'receipt_scanner',
  false,
  'API-017/APP-021 receipt scanner. Global gate; per-user access additionally requires the ENT-001 receipt_scanner entitlement. Flip only after an APP-021 store build ships — the capture flow needs a native OCR module and cannot reach existing installs over EAS Update.'
)
ON CONFLICT (key) DO NOTHING;
