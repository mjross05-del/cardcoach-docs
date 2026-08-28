-- =========================================================================
-- STATUS NOTE ADDED 2026-08-27 — THIS TEMPLATE IS SPENT. DO NOT USE.
-- tie_disclosure was flipped ON at 2026-08-16 21:49:43 UTC and the flip is
-- fully recorded in the sibling 2026-08-16__runtime_flags__tie_disclosure_on.sql.
-- Production reads enabled = TRUE, verified 2026-08-27.
-- This file's "DO NOT APPLY until every precondition is met" language and its
-- ____-__-__ date blanks make it read as a pending action to anyone who finds
-- it without the sibling. It is kept only as the shape to copy for a FUTURE
-- flag flip.
-- =========================================================================

-- Flip tie_disclosure ON (date: ____-__-__ — fill at flip time).
--
-- FOR cardcoach-docs/deltas/ — DO NOT APPLY until every precondition in
-- supabase/migrations/20260816180000_tie_disclosure_flag.sql is met:
--   1. recommend-card-v2 + recommend-here-v2 deployed with API-016,
--   2. APP-020 mobile release live (parses tie + value_tie),
--   3. production probe green (verify_api_016_tie_disclosure.mjs header).
--
-- Activates: rounded-cent tie groups on the authed paths, D2 within-tie
-- order (annual fee asc NULL-last, name, productId), tie objects +
-- value_tie explanation items. rank stays dense; the stateless web tool is
-- untouched in every flag state (it never reads the flag).
-- Rollback: set enabled = false — both endpoints revert on the next
-- request, no deploy.

update public.runtime_flags
set enabled = true,
    note = coalesce(note, '') || ' FLIPPED ON ____-__-__ (delta; Mike approval in chat).'
where key = 'tie_disclosure'
  and enabled = false;
