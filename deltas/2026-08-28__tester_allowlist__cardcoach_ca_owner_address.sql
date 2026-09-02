-- ENT-002 · add Mike's post-migration address to the tester allowlist (2026-08-28).
--
-- STATUS: APPLIED 2026-08-28 via Supabase MCP against card_coach_advanced.
-- Result: 1 row inserted. public.tester_allowlist now carries BOTH of Mike's
-- CardCoach addresses.
--
-- CONTEXT. The Google Workspace primary domain moved card.coach -> cardcoach.ca
-- the same day and Mike was renamed mike@card.coach -> mike@cardcoach.ca
-- (decision record: PIPELINE_AND_DECISIONS.md 2026-08-28; WORKING_NOTES #37).
--
-- WHY ADDITIVE RATHER THAN A RENAME. Mike's ruling. The existing row is tied to
-- a live auth.users account (1d79eb69-22be-4f9f-9dee-77e847e497d7, created
-- 2026-08-08) that carries a wallet and transactions. mike@card.coach survives
-- as a Workspace alias and still receives, so that account keeps working
-- untouched; this row only ensures that if Mike ever signs up on the NEW
-- address it is comped on signup like any other allowlisted tester. Nothing
-- existing changes. No auth.users row was modified.
--
-- IDEMPOTENT: ON CONFLICT DO NOTHING on the email primary key. Safe to re-run.

insert into public.tester_allowlist (email, note, added_by)
values (
  'mike@cardcoach.ca',
  'owner - primary device tester (cardcoach.ca migration 2026-08-28)',
  'mike'
)
on conflict (email) do nothing;

-- Verification actually run after apply:
--   select email, note, added_at from public.tester_allowlist where email like 'mike@%';
-- ->  mike@card.coach     owner - primary device tester                              2026-08-25
--     mike@cardcoach.ca   owner - primary device tester (cardcoach.ca migration ...)  2026-08-28
