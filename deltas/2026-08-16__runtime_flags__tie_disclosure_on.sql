-- Delta: runtime_flags.tie_disclosure false -> true (ACTIVATION)
-- Applied: 2026-08-16 21:49:43 UTC via PostgREST guarded PATCH (service role),
--   project hrzpznlpmxxrbtwskacu. (Supabase MCP was 503ing; PATCH used the same
--   guard semantics: filter key=eq.tie_disclosure&enabled=eq.false,
--   Prefer: return=representation confirmed exactly one row.)
-- Authorized: Mike, in-session decision ("Flip now"), 1.0.3 release-execution
--   session — supersedes the plan's "Cowork preflight flips it later" sequencing.
-- Purpose: build-57 TestFlight tie QA (Mike holds two engineered 2-way ties).
-- Flip preconditions (migration 20260816185557 header) at flip time:
--   1. MET  - recommend-card-v2 v24 / recommend-here-v2 v23 deployed with the
--             API-016 code (2026-08-16, this session; stateless-v1 untouched at
--             v8 per D3 and never reads this flag).
--   2. MET  - mobile build parsing tie/value_tie live: 1.0.3 build 57 on
--             TestFlight (internal; no App Store users on 1.0.3 yet).
--   3. PART - production probe: flag-off half verified this session pre-flip
--             (authed v24 call: byte-equivalent pre-API-016 payload, no
--             tie/value_tie). Flag-on half: post-flip authed call HTTP 200,
--             healthy shape (single-card wallet at probe merchant, so no tie
--             group expected there); the constructed rounded-equal-pair
--             confirmation is Mike's on-device QA with his engineered ties.
-- Guard: WHERE enabled = false; RETURNING confirmed exactly one row.
-- Deno acceptance suite (flag-on tie semantics, D2 order, boundary cases):
--   green in verify:api-016 on the deployed commit 63a08be (283/283).

update public.runtime_flags
set enabled = true,
    note = 'API-016 tie detection + disclosure (rounded-cent tie groups, D2 within-tie order, value_tie explanation items). Seeded OFF 2026-08-16; FLIPPED ON 2026-08-16 by Mike (in-session decision, release-execution session) for build-57 TestFlight tie QA. Preconditions: v24/v23 deployed with API-016 code; build 57 (1.0.3) parsing tie/value_tie live on TestFlight. Delta: 2026-08-16__runtime_flags__tie_disclosure_on.sql',
    updated_at = now()
where key = 'tie_disclosure' and enabled = false
returning key, enabled, updated_at;

-- Rollback (the documented no-deploy rollback for this ranking-affecting
-- change; founder decision required, same discipline):
-- update public.runtime_flags set enabled = false, updated_at = now()
--   where key = 'tie_disclosure' and enabled = true;
