# DISPATCH — Recover three verify-lane migrations applied with no local file

For: the runtime that owns the verify / apply-loop lane.
Raised by: the statement-import session, 2026-08-21, after these blocked a clean
`supabase db reset`.

---

## What happened

Three migrations were applied to production on **2026-08-21 at 02:48–02:49 UTC** and **no
local file was written**:

| Remote version | Name |
|---|---|
| `20260821024803` | `verify_apply_queue_convention_ruling_origin` |
| `20260821024854` | `verify_queue_views_surface_unlinked_rows` |
| `20260821024922` | `verify_write_audit_linkage_status` |

Confirm with:

```bash
supabase migration list --project-ref hrzpznlpmxxrbtwskacu | grep 2026082102
ls ~/dev/CardCoachv2/mobile_app_codebase/supabase/migrations/20260821*
```

The first lists three rows. The second lists only the four `data_022_*` files from the
statement-import lane. That gap is the defect.

This is **PROJECT_RULES rule 9(e)** verbatim:

> *"Applying DDL via MCP requires writing the local migration file in the same turn. MCP
> `apply_migration` records the migration in remote history under a generated timestamp
> version but writes no local file. A session that applies and does not commit leaves a
> migration applied remotely with nothing in `supabase/migrations/` — which then breaks
> `supabase db push` and `db reset` for everyone else."*

## Why it matters now

Local and production have diverged. Anyone who resets gets a database missing three
verify-schema changes, and `db push` will try to reconcile a history it cannot see. It also
means the `verify.*` behaviour those migrations added is untested against a clean replay.

## The task

Recover the three files — **and trim each one to its actual delta.**

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
supabase db pull --project-ref hrzpznlpmxxrbtwskacu
```

**The trimming is the part that matters, and it is where this went wrong last time.** On
2026-08-11 the same recovery was performed on this same schema, and the pull emitted the
*entire* `verify` schema instead of the delta. The resulting file re-declared six tables
that `20260727215042_verification_engine_p1_verify_schema.sql` had already created, with no
`IF NOT EXISTS`. That broke `supabase db reset` at:

```
ERROR: relation "runs" already exists (SQLSTATE 42P07)
```

and it stayed broken for **ten days**, which is why nobody noticed these three files were
missing — the reset that would have surfaced them could not run.

The statement-import session repaired the two 2026-08-11 files in passing (added
`IF NOT EXISTS` to 8 tables and 8 indexes; made 4 views `CREATE OR REPLACE`). Read the
banner at the top of
`supabase/migrations/20260811025239_create_verify_apply_loop_tables.sql` before you start —
it is the same trap you are walking back into.

So, for each of the three:

1. Keep only the statements that are genuinely new in that migration. If the pull emits a
   whole-schema dump, delete everything the earlier migrations already created.
2. Make every remaining `CREATE` idempotent — `IF NOT EXISTS` for tables and indexes,
   `CREATE OR REPLACE` for views, `DROP POLICY IF EXISTS` before `CREATE POLICY`.
3. Give each a house header: title + date, `STATUS: APPLIED 2026-08-21 <time> UTC via MCP
   apply_migration (recovered by db pull <date>)`, `Why now`, `What this does NOT do`,
   `Read-path impact`, `Rollback`.
4. Name each file at its **remote version**, not a fresh timestamp — `20260821024803_…`,
   `20260821024854_…`, `20260821024922_…`. A new timestamp would make the remote history
   and the local directory disagree in the other direction.

## Acceptance

```bash
pnpm supabase:db-reset
```

must complete. That is the whole test, and it is a test nothing in this repo has passed
since 2026-08-11.

Be aware the reset surfaces unrelated breakage as it goes — every migration written after
2026-08-11 has never been replayed cleanly. One already found and fixed by the
statement-import session: `20260817020859_data_020_online_merchant_catalogue_seed.sql`
inserted `merchant_entities` rows referencing eleven categories that no migration creates
(`categories` is populated by `seed.sql`, which runs *after* migrations), so it passed on
apply against a live database and failed on replay. Expect more of that shape and fix them
where you find them.

## Do not

- Do not re-apply these three to production. They are already there; this is a **local
  file recovery only**.
- Do not renumber them.
- Do not "fix" the divergence by dropping the remote rows.

## Related, not yours

`pnpm verify:engine-bundle` reports one failure, `revenuecat-webhook` — a `string | null`
mismatch in `_shared/billing.ts`. Pre-existing, BILL-001's lane, unrelated to this and to
the statement-import work. Leave it.
