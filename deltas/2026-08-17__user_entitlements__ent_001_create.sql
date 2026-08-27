-- DELTA 2026-08-17 — ENT-001 per-user entitlements (rule 9(b) file record).
--
-- APPLIED 2026-08-17 02:42:43 UTC via MCP apply_migration, remote version
-- 20260817024243. Local migration: mobile_app_codebase/supabase/migrations/
-- 20260817024243_ent_001_user_entitlements.sql (filename matched to the remote
-- version so db push / db reset stay aligned, rule 9(e)).
--
-- Sign-off: Mike, 2026-08-16 ("2. signed off"), after the per-change proposal in
-- docs/planning/specs/ENT-001_entitlements.md (reasoning, read-path impact,
-- rollback). Applied 2026-08-17 once the entitlement-design collision with the
-- online-merchant lane was resolved — see PIPELINE_AND_DECISIONS 2026-08-17.
--
-- Pre-state asserted: user_entitlements absent, v_active_user_entitlements
-- absent, profiles carried no plan column, no entitlement storage anywhere.
-- Post-state asserted: table + view present, RLS enabled AND forced, exactly one
-- policy (select_own), zero INSERT/UPDATE/DELETE grants to anon/authenticated,
-- zero grants issued.
--
-- Shared primitive: gates BOTH API-017 (receipt_scanner) and API-018
-- (online_merchant). Two independently grantable keys, never an is_pro boolean.
--
-- Snapshot: not required — this creates a new table and writes no existing rows.
-- runtime_flags, the one existing table this session wrote, was snapshotted to
-- runtime_flags_snapshot_20260817 (RLS enabled + REVOKE ALL in the same
-- transaction, per rule 9(a) and the 2026-07-29 unsecured-snapshot incident).
--
-- Rollback: mobile_app_codebase/supabase/rollback/ent_001_down.sql. Safe while
-- grants are manual-only; NOT safe once billing writes real grants.
--
-- DDL as applied — see the migration file for the full commented version.

CREATE TABLE IF NOT EXISTS public.user_entitlements (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entitlement_key text NOT NULL,
  source          text NOT NULL,
  granted_at      timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz,
  revoked_at      timestamptz,
  note            text,
  created_at      timestamptz NOT NULL DEFAULT now()
);
-- + CHECK constraints: key_format ^[a-z0-9_]{3,64}$, source IN
--   ('manual','app_store','play','promo','grandfather'), expires_at > granted_at
-- + indexes: (user_id, entitlement_key); partial WHERE revoked_at IS NULL
-- + VIEW v_active_user_entitlements WITH (security_invoker = true)
-- + RLS ENABLE + FORCE, policy user_entitlements_select_own
-- + REVOKE INSERT, UPDATE, DELETE FROM anon, authenticated
-- + GRANT SELECT on table and view TO authenticated
