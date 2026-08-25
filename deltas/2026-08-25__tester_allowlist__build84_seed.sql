-- ENT-002 seed · the build-84 tester round (2026-08-25).
--
-- STATUS: APPLIED 2026-08-25. Ran after 20260825022114_ent_002_tester_allowlist.
-- Result: 5 accounts allowlisted, 5 users written, 25 grant rows (5 users x 5
-- pro keys), all expiring 2026-11-23. The backfill was then run a SECOND time
-- and wrote 0 additional rows — the WHERE NOT EXISTS idempotency is proven in
-- production rather than argued.
--
-- Five addresses. Three are Mike's list; two are Mike's own accounts, added
-- because he is the only device tester the project has and because the reason
-- this mechanism exists is that his last comp disappeared (see below). Remove
-- either line if that is wrong.
--
-- ---------------------------------------------------------------------------
-- WHY THE 2026-08-21 GRANT VANISHED — solved 2026-08-25, and it was not a wipe.
--
-- RELEASE_1.2.0_PREMIUM_TESTFLIGHT.md records all six keys granted to
-- `13249fa5-6a8f-4d7c-ae25-200df2d851ec` on 2026-08-21, source='manual',
-- expiring 2026-11-19. That user id **does not exist in auth.users** and has no
-- row in public.profiles. `user_entitlements.user_id` is
-- `REFERENCES auth.users(id) ON DELETE CASCADE` (ent_001 §1), so when the
-- account went away every grant went with it, silently and correctly.
--
-- Most likely cause: the account-deletion flow was exercised on that account
-- during a device round (delete-account v6 was deployed the same day, and
-- Settings offers "Delete account (immediate, server-side)").
--
-- This is exactly the failure the allowlist fixes. A hand-typed INSERT is
-- destroyed by a delete-account test and nothing notices. An allowlist keyed on
-- EMAIL plus an AFTER INSERT trigger on auth.users re-comps the same person the
-- moment they sign up again — including after they delete and recreate.
-- ---------------------------------------------------------------------------

INSERT INTO public.tester_allowlist (email, note, added_by) VALUES
  ('jamie.k.lee@gmail.com',  'build-84 tester round',            'mike'),
  ('brianross530@gmail.com', 'build-84 tester round',            'mike'),
  ('diross636@gmail.com',    'build-84 tester round',            'mike'),
  ('mike@card.coach',        'owner - primary device tester',    'mike'),
  ('mjross05@gmail.com',     'owner - second account',           'mike')
ON CONFLICT (email) DO NOTHING;

-- Backfill the four that already have accounts. The fifth (if any) is picked up
-- by the signup trigger. Safe to re-run: grant_tester_pro writes nothing while a
-- comp still has more than 14 days left, and renews one that does not.
SELECT
  count(*)                            AS allowlisted_users_seen,
  count(*) FILTER (WHERE granted > 0) AS users_written,
  COALESCE(sum(granted), 0)           AS rows_written
FROM (
  SELECT public.grant_tester_pro(u.id) AS granted
  FROM auth.users u
  JOIN public.tester_allowlist a ON a.email = lower(btrim(u.email))
  WHERE u.email IS NOT NULL
) s;

-- Expected on first run: 5 accounts seen, 5 written, 25 rows
-- (5 users x 5 pro keys). All five accounts existed as of 2026-08-25:
--   jamie.k.lee@gmail.com  2a3046dd-...  created 2026-08-16
--   brianross530@gmail.com 6c5257e8-...  created 2026-08-18
--   diross636@gmail.com    bb99da96-...  created 2026-08-24
--   mike@card.coach        1d79eb69-...  created 2026-08-08
--   mjross05@gmail.com     ced1615b-...  created 2026-08-24

-- Verification:
--   SELECT u.email, count(*) AS active_keys, min(e.expires_at) AS earliest_expiry
--   FROM public.user_entitlements e
--   JOIN auth.users u ON u.id = e.user_id
--   WHERE e.source = 'manual' AND e.note = 'tester_allowlist'
--     AND e.revoked_at IS NULL
--     AND (e.expires_at IS NULL OR e.expires_at > now())
--   GROUP BY u.email ORDER BY u.email;
