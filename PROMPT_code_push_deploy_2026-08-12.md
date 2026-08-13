# PROMPT — push + edge deploy for the 2026-08-12 engine session (code runtime)

Authored by the 2026-08-12 Cowork engine session, on Mike's instruction. You
are a Claude Code session on Mike's machine. Your job is exactly four things:
clean stale git artifacts, push two repos, deploy three edge functions, and
verify — then file a short report. Nothing else.

**Read first if anything is unclear:** `~/dev/ENGINE_FLOORS_REPORT_2026-08-12.md`
(full narrative incl. ADDENDUM 2), `PROJECT_RULES.md` (rule 9 discipline).

## Context — what is already done (do NOT redo)

- Engine spend-window floors + `category_excludes` + `window_bucket` are
  implemented, tested (143/143, qa-005 goldens 8/8), and **committed locally**
  in `~/dev/CardCoachv2` (`bfd487e`, `c75f747`, `f61ca35`, on `main`).
- Both schema migrations (`20260812210310`, `20260812210325`) are **already
  applied to the remote DB**, and local migration files match remote history
  1:1 (five previously remote-only migrations were recovered as files in
  `c75f747`). **Do not run `supabase db push`** — there is nothing to push and
  nothing pending.
- All card-data remodels (RBC Cash Back standard 4-row rising tiers, RBC WE
  base-slot incremental, NBC Platinum/WE monthly tier windows) are **live in
  the DB** with deltas, secured snapshots, and write_audit bookkeeping. The
  verify apply queue is **empty**. **Do not touch `public.*` or `verify.*`.**
- `~/dev/cardcoach-docs` has four local commits on `main` (`3f06994`,
  `1fb1c17`, `32b5cc3`, plus the commit adding this prompt).
- The production edge functions still run the **old** engine. The DB rows were
  verified to price safely under it (flat 1% RBC std, capped 2% grocery,
  1.5%/1% RBC WE, top-rate NBC clipped by category-bucket cap). The deploy you
  perform is what activates full window semantics.

## Guardrails

- Modify no source files. Run no data SQL. Deploy ONLY the three functions
  named below (`cap-progress-v1`'s change is comment-only and rides the next
  natural deploy; nothing else changed).
- Never force-push. If a push is non-fast-forward, `git fetch` and `git rebase
  origin/main`; if the rebase conflicts, STOP and report — do not resolve
  conflicts yourself.
- If any verification fails, STOP at that step and write the report with what
  you saw. Do not improvise fixes.

## Step 0 — clean the sandbox's git artifacts, verify preconditions

The Cowork sandbox cannot `unlink` inside `.git`, so it left renamed lock
files and temp objects in both repos. Your machine can delete them:

```bash
for r in ~/dev/CardCoachv2 ~/dev/cardcoach-docs; do
  find $r/.git -maxdepth 3 \( -name '*.lock' -o -name '*.stale.*' -o -name 'tmp_obj_*' \) -delete
  git -C $r gc --quiet
done
```

(`*.lock` deletion is safe: no other git process is running; the locks are
leftovers, some possibly re-created by the sandbox's final status calls.)

Then verify:

```bash
git -C ~/dev/cardcoach-docs log --oneline -4   # expect: this prompt's commit, 32b5cc3, 1fb1c17, 3f06994
git -C ~/dev/CardCoachv2 log --oneline -3      # expect: f61ca35, c75f747, bfd487e
git -C ~/dev/cardcoach-docs status --porcelain # expect: empty
git -C ~/dev/CardCoachv2 status --porcelain    # expect: empty or only .fuse_hidden* (gitignored junk from the mount; ignore)
```

If the expected commits are absent, STOP and report.

## Step 1 — push cardcoach-docs

```bash
cd ~/dev/cardcoach-docs && git fetch origin && git push origin main
```

(Remote: `github.com/mjross05-del/cardcoach-docs`.)

## Step 2 — push CardCoachv2

```bash
cd ~/dev/CardCoachv2 && git fetch origin && git push origin main
```

(Remote: `github.com/redSTORMY-KNIGHT/CardCoachv2`. Non-fast-forward → rebase
per guardrails. Note WORKING_NOTES-class files live in the docs repo, so
conflicts here are unlikely; the likeliest divergence source is another
session's push.)

## Step 3 — pre-deploy baseline probe (capture, don't judge)

Capture ONE discriminating scenario before deploying, so post-deploy change is
provable. Build a `recommend-cards-stateless-v1` request per its contract
(`mobile_app_codebase/supabase/functions/_shared/engine-contracts/recommendCardsStatelessV1.ts`)
for: **card `ca_national_bank_rewards_mastercard_world_elite_mastercard`,
category `grocery`, amount 400000 cents ($4,000), no snapshots**. Save the
response (note `effectiveValueExactCents` or equivalent).

Why this scenario: the old engine prices the 5 pts/$ tier on the first $2,500
and drops the 2 pts/$ row (≈14,000 pts worth); the new engine adds the
after-tier stretch (≈15,500 pts worth). It is the cleanest single-call
discriminator — the RBC scenarios intentionally converge on snapshot-less
surfaces.

Also capture a **control**: RBC std, category `dining`, amount 10000 — this
must be IDENTICAL before and after (flat 1% both ways, by design).

## Step 4 — deploy the three functions

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
npx supabase functions deploy recommend-card-v2            --project-ref hrzpznlpmxxrbtwskacu
npx supabase functions deploy recommend-here-v2            --project-ref hrzpznlpmxxrbtwskacu
npx supabase functions deploy recommend-cards-stateless-v1 --project-ref hrzpznlpmxxrbtwskacu
```

Then `npx supabase functions list --project-ref hrzpznlpmxxrbtwskacu` and
confirm: versions bumped (recommend-card-v2 >19, recommend-here-v2 >19,
recommend-cards-stateless-v1 >7), all three still ACTIVE, `verify_jwt` still
**false** for all three (it was false before; the CLI takes it from
`supabase/config.toml` — if any flipped to true, redeploy with
`--no-verify-jwt`).

## Step 5 — post-deploy verification

1. Re-run both Step 3 probes.
   - NBC WE grocery $4,000: value **increased** vs baseline (≈ +1,500 pts ×
     the à-la-carte cpp). If unchanged → the deploy didn't take; check
     versions.
   - RBC std dining $100 control: **byte-identical** to baseline.
2. Hit the `health` function — 200.
3. Optional but recommended (your machine can, the sandbox couldn't):
   `pnpm --filter @cardcoach/engine test` (expect 143/143) and
   `pnpm verify:qa-005` (expect 8/8) from `mobile_app_codebase`.
4. Skim edge logs for the three functions for a minute of traffic — no new
   error classes.

## Step 6 — report and close

Append a dated run entry to `cardcoach-docs/WORKING_NOTES.md` (what pushed,
what deployed, probe numbers before/after, anything anomalous), commit it to
the docs repo, push. If everything passed, the entry should state: **window
semantics are live; every remodelled card (RBC std, RBC WE, NBC ×2) now prices
its true tier structure in production.**

## Failure protocol

Any STOP: write the WORKING_NOTES entry with the failing step, exact command,
and output; commit + push the docs repo if possible; leave everything else
untouched. The Cowork session's report has full rollback context (deltas
include rollback SQL; `earn_rates_snapshot_20260812` and
`card_products_snapshot_20260812` hold pre-states) — but rollback is Mike's
call, not yours.
