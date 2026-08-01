# CardCoach — Session Rules (2026-07-02)

Last updated: 2026-07-31 · Owner: Mike (rule 10 clarification authored 2026-07-29, landed 2026-07-31)

Read SOURCE_OF_TRUTH.md first. It governs what's real; this file governs how to behave.

1. Canada-only, issuer-verified. Every asserted card fact traces to Tier 1 / Tier 1b sources.
2. SOURCE_OF_TRUTH.md is the index and authority on files. SCHEMA.md is database truth.
   HOW_THE_ENGINE_WORKS.md is engine truth. schema copy.txt is superseded — never cite it.
3. Current card facts come from the audit workbook (…20260313_v23_patchready.xlsx) plus
   verification outputs; dated live-issuer verification supersedes the workbook on conflict.
4. V1 is dead. Production reads only the V2 tables (card_products, earn_rates, card_caps,
   card_exclusions). Never emit or describe V1 paths.
5. Offer stacking and MCC routing are captured in data but NOT active in production.
   Never describe them as live features.
6. Older marketing/handoff docs are strategy and UX intent, not technical truth.
7. Never invent card facts — earn rates, caps, exclusions, fees, point values. Unknowns are
   flagged [VERIFY: issuer-verified data needed], never estimated.
8. Distinguish current build vs. current working data vs. roadmap. Be explicit about uncertainty.
9. Output is files, SQL deltas, prompts, or docs — never direct writes to Supabase or the app.
   Alex's lane (app, DB, App Store) and Mikayla's lane (social/Canva) are off-limits.
   **SUPERSEDED (Mike, 2026-07-29): database write authority is no longer restricted.** Mike's
   instruction: "We can do anything Alex can. This is our lane now." Direct writes to the Supabase
   database are authorised, on four standing conditions:

   (a) **Snapshot before the first write of a session**, for every table to be written —
       **and secure the snapshot in the same transaction.** A bare `CREATE TABLE AS` in
       `public` inherits default privileges and lands anon-readable, which breaks the 0051
       RLS-hardening posture. This happened on 2026-07-29: the
       `point_valuations_snapshot_20260729` table was created unsecured and Alex had to write
       migration `20260729205344_secure_point_valuations_snapshot_20260729` to close it.
       Required form:
       ```sql
       CREATE TABLE point_valuations_snapshot_<stamp> AS SELECT *, now() AS snapshot_taken_at FROM point_valuations;
       ALTER TABLE point_valuations_snapshot_<stamp> ENABLE ROW LEVEL SECURITY;
       REVOKE ALL ON point_valuations_snapshot_<stamp> FROM anon, authenticated;
       ```
       Enabling RLS with no policies denies all non-bypassing roles; the REVOKE removes the
       grant as well so a later permissive policy cannot silently reopen it.
   (b) **Every applied change is also cut to a dated delta file.** The file record must never lag
       the DB — the 2026-07-27 batch-1 CPP changes were applied with no delta files, and that is
       the failure this condition exists to prevent.
   (c) **Expire-then-insert on time-windowed fact tables** (`point_valuations`, `earn_rates`,
       `card_caps`, `card_exclusions`), never DELETE. Expire count ≠ expected → ROLLBACK.
   (d) **Guards in every transaction.** Assert the pre-state before mutating and the post-state
       after; fail closed rather than proceed on a surprise.

   (e) **Applying DDL via MCP requires writing the local migration file in the same turn.**
       MCP `apply_migration` records the migration in remote history under a generated
       timestamp version but writes no local file. A session that applies and does not commit
       leaves a migration applied remotely with nothing in `supabase/migrations/` — which then
       breaks `supabase db push` and `db reset` for everyone else. This happened with
       `20260727215042_verification_engine_p1_verify_schema` (applied 2026-07-27, no local
       file). Recover with `supabase db pull`.

   (f) **Multi-session discipline.** Mike runs concurrent sessions. Any session with write
       authority must therefore assume the database has moved since its context was built:
       re-read live state before writing, never trust a count carried in from a document, and
       run `pnpm verify:cpp` before and after a batch. The invariant suite is the only thing
       that sees across sessions — none of the agents can see each other.

   Rule 7 is unaffected: inventing card facts is still forbidden, and write authority is not
   permission to estimate. App build and App Store remain Alex's lane; social and Canva remain
   Mikayla's.

   **RESOLVED 2026-07-29: DDL is authorised, per-change.** Mike signed off migration 0056
   (`point_programs` uniqueness relaxation) explicitly after being shown the alternatives. The
   working rule: schema changes are in scope, but each one is proposed with its reasoning, its
   read-path impact and a rollback statement before it runs — not applied on Claude's own judgement
   the way row writes are. A wrong row value is recoverable from a snapshot; a wrong shape can break
   the running app.

   **Tooling note:** the Cowork session's permission layer gates DDL independently of this rule, so
   an authorised migration may still be blocked at execution. When that happens the migration is
   written to `mobile_app_codebase/supabase/migrations/` with a `STATUS: NOT YET APPLIED` header and
   run via `supabase db push`, the Supabase SQL editor, or Alex. Do not route around the gate with
   `execute_sql`.

   The earlier, narrower 2026-07-29 exception scoped to `point_valuations` only is superseded by
   this.
10. PIPELINE_AND_DECISIONS.md is append-only. Settled decisions stay settled; shelved items
    stay shelved until Mike reopens them.

    **CLARIFIED 2026-07-29.** As originally written this rule covered the whole file, which
    made routine header maintenance read as a violation and forced an agent to escalate a
    diff that served the rule's intent. Scope it precisely:

    (a) **The decisions section is append-only.** No existing decision entry may be
        rewritten, deleted, reordered or changed in meaning. This is the rule; everything
        else below is mechanics.
    (b) **The header and pipeline-reference sections are maintainable.** They hold pointers
        to current artefacts and versions, and a stale pointer is a defect. Correcting one
        is not a rule-10 event. The file's own preamble already said this — "the pipeline
        section is stable; the decisions section is append-only" — and that reading governs.
    (c) **Chronological backfill of RECOVERED decisions is permitted**, inserted at its true
        date position rather than at the end, provided the same commit adds an entry stating
        what was recovered and from where. A decision made in April and lost belongs in
        April. The 2026-07-16 docs-fork entry is the worked example.
    (d) **Genuinely new decisions append at the end**, below the marker. Never mid-log.
    (e) An insertion that is neither (c) nor (d) needs Mike's explicit sign-off.

    The audit property this preserves: any mid-log change must be self-declaring. If a diff
    inserts above the end marker without a recovery entry explaining it, treat that as a
    stop condition.
