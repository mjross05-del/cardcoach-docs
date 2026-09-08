# PROMPT — commit + push the verify engine v2 cutover (code runtime)

Authored by the 2026-09-07/08 Cowork session on Mike's instruction ("good to go
ahead"). You are a Claude Code session on Mike's Mac. Your job is exactly this:
confirm that the files the Cowork session wrote into two repos match what is
already live in production, run the repo gates, commit, push, run the post-push
checks, and file a short report. Nothing else.

## Context — what is already done (do NOT redo)

**What shipped.** The eight self-contained Cowork batch prompts, the daily
apply-loop task, the chrome lane, the monthly retention task and the DATA-018
one-shot were replaced by one database-driven engine. Decision record:
`~/dev/cardcoach-docs/PIPELINE_AND_DECISIONS.md`, entry of 2026-09-08. Design:
`DESIGN_verify_engine_v2_2026-09-07.md` (same folder). Operations:
`card_coach_business_docs/01_CORE/verification-engine/RUNBOOK_verify_engine_v2.md`.

**Production is already on it.** Applied 2026-09-08 01:04–01:13 UTC through the
MCP `apply_migration` tool (rule 9(e): the tool records its own version, so the
files carry the recorded versions, not the authoring time):

| recorded version | name | md5 of the file (= `md5(array_to_string(statements, E'\n'))` in prod) |
|---|---|---|
| `20260907175034` | `guardrail_001_exempt_global_offer_card_id_prefixes` (Mike's GUARDRAIL-1 ruling of 2026-09-07 — was applied from chat with no repo file; reconstructed from `supabase_migrations.schema_migrations`) | `124063a4ef3ba8f57accbb85b58c3e52` |
| `20260908010442` | `verify_engine_v2_p1_registry_and_queue` | `e41d164794c8e878ac1bfbf22c8d05d0` |
| `20260908010931` | `verify_engine_v2_p2_runner_api` | `350e062d1b20b389ff5de4c677fc1a77` |
| `20260908011244` | `verify_engine_v2_p3_seed_and_backfill` | `ea1086b9ee8e382381aff6be89e76c5a` |
| `20260908011333` | `verify_engine_v2_p4_doc_watch_plumbing` | `3d0d20116658e0774f1e83500881f4fc` |

Edge function `verify-doc-watch` is deployed at **v2** (MCP deploy, `verify_jwt=false`,
import map `deno.json`), byte-identical to the repo file
(`supabase/functions/verify-doc-watch/index.ts`, sha256
`7eeca9d4ef8253b639b1135dcfd0310179efebd6a670efb7849a5215ec182be1`; `deno check`
clean under Deno 2.9). It was proven live: wrong token → 401; right token → idle;
after the first `verify.plan()` two real sweeps ran — TDBank 28/28 sources
fetched, 0 changed (all 11 stored PDF hashes matched the live documents) and
SimpliiFinancial 6/6 with one PDF baselined into Storage + `verify.evidence`.
Four pg_cron jobs are active (`verify_plan_daily` 08:30 UTC, `verify_reap_hourly`,
`verify_doc_watch_sweep_a/b` 08:35–09:55 UTC every 5 min). The Vault secret
`verify_doc_watch_token` exists and never leaves the database.

**What the Cowork session wrote to disk (uncommitted, both repos):**

`~/dev/CardCoachv2` (monorepo):
- `mobile_app_codebase/supabase/migrations/` — the five files above.
- `mobile_app_codebase/supabase/APPLIED_MIGRATIONS.txt` — five lines appended.
- `mobile_app_codebase/supabase/functions/verify-doc-watch/index.ts` — new.
- `mobile_app_codebase/supabase/config.toml` — `[functions.verify-doc-watch]` block appended.
- `card_coach_business_docs/01_CORE/verification-engine/RUNBOOK_verify_engine_v2.md`,
  `PROMPT_engine_runner_cloud.md`, `PROMPT_engine_runner_chrome.md` — new.

`~/dev/cardcoach-docs`:
- `DESIGN_verify_engine_v2_2026-09-07.md` — new; this file — new.
- `PIPELINE_AND_DECISIONS.md` — one entry appended (2026-09-08).
- `WORKING_NOTES.md` — status-index line + section **#49** added; header date bumped.

Also sitting untracked in the monorepo from before this work and NOT part of it
(leave alone unless Mike says otherwise): `SKILL_cardcoach_apply_loop.md` in the
same business-docs folder, the `deltas/2026-09-02` + `2026-09-05` folders, the
`model_v3/*.py` files, the zip, `card_coach_website/main`, `main`, and the
`design_handoff_cardcoach_web 2/` folder.

## Guardrails

- Modify no source files. Run no data SQL (read-only checks only, listed below).
  Do not run `supabase db push`, `db reset` or `migration repair` — production
  already holds these versions; the repo is being brought level with it.
- Do not redeploy `verify-doc-watch` unless Step 2 shows a mismatch.
- Never force-push. Non-fast-forward → fetch + rebase; conflicts → STOP and report.
- If any verification fails, STOP at that step and report. Do not improvise.

## Step 0 — clean the sandbox's leftovers, verify preconditions

The Cowork sandbox cannot unlink inside `.git`; it parked the stale `index.lock`
of both repos under `~/dev/_to_delete/stale-git-locks-2026-09-08-engine-v2/`, and
its doc-splicing helpers under `~/dev/_to_delete/engine_v2_snippets_2026-09-08/`.
Both folders are disposable.

```bash
cd ~/dev
rm -rf _to_delete/stale-git-locks-2026-09-08-engine-v2 _to_delete/engine_v2_snippets_2026-09-08
for r in CardCoachv2 cardcoach-docs; do find $r/.git -maxdepth 3 -name '*.lock' -print -delete; done   # expect: nothing printed

cd ~/dev/CardCoachv2
git rev-parse --short HEAD origin/main             # expect: 07201aa twice (or newer, but equal to each other)
git status --porcelain | grep -E 'supabase/(migrations|functions/verify-doc-watch|APPLIED_MIGRATIONS|config.toml)|verification-engine/(RUNBOOK_verify_engine_v2|PROMPT_engine_runner)'
# expect: exactly 5 untracked migrations, 1 untracked function dir, M APPLIED_MIGRATIONS.txt, M config.toml, 3 untracked business docs

cd ~/dev/cardcoach-docs
git rev-parse --short HEAD origin/main             # expect: 286e9b4 twice (or newer, equal)
git status --porcelain | grep -E 'DESIGN_verify_engine_v2|PROMPT_deploy_verify_engine_v2|PIPELINE_AND_DECISIONS|WORKING_NOTES'
# expect: 2 untracked, 2 modified
```

## Step 1 — the files are the ones production recorded

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase/supabase
for f in migrations/20260907175034_* migrations/20260908010442_* migrations/20260908010931_* migrations/20260908011244_* migrations/20260908011333_*; do
  echo "$(md5 -q "$f")  $f"
done
# expect, in order: 124063a4ef3ba8f57accbb85b58c3e52  e41d164794c8e878ac1bfbf22c8d05d0  350e062d1b20b389ff5de4c677fc1a77  ea1086b9ee8e382381aff6be89e76c5a  3d0d20116658e0774f1e83500881f4fc
tail -5 APPLIED_MIGRATIONS.txt                     # expect: the five "<version> <name>" lines from the table above, in that order
shasum -a 256 functions/verify-doc-watch/index.ts  # expect: 7eeca9d4ef8253b639b1135dcfd0310179efebd6a670efb7849a5215ec182be1
tail -6 config.toml                                # expect: the [functions.verify-doc-watch] block, verify_jwt = false

cd ~/dev/CardCoachv2/mobile_app_codebase
pnpm verify:migration-history                      # expect: "passed: every applied migration has a matching file", pending 0
pnpm verify:edge-imports                           # expect: verify-doc-watch/index.ts among the checked entrypoints, no violations (deno check runs here)
```

If a hash differs, STOP: the file on disk is not what production recorded, and
the fix is to regenerate it from `supabase_migrations.schema_migrations`, not to
edit it.

## Step 2 — production is live on the same bytes

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
npx supabase functions list --project-ref hrzpznlpmxxrbtwskacu | grep -E 'verify-doc-watch|receipt-purge-worker'
# expect: verify-doc-watch  ACTIVE  version 2  verify_jwt false   (receipt-purge-worker v1 alongside, unchanged)

curl -s -o /dev/null -w '%{http_code}\n' -X POST 'https://hrzpznlpmxxrbtwskacu.supabase.co/functions/v1/verify-doc-watch' \
  -H 'apikey: sb_publishable_o8DLtdGmTy4DM4kR8FmOVQ_vKp0EH7Z' -H 'Content-Type: application/json' -d '{}'
# expect: 401  (no x-verify-token → the function refuses; that IS the proof it is live and gated)
```

Only if the list shows a version other than 2, or the function is missing, deploy
from the repo — the same command family the tie-fix used:
`npx supabase functions deploy verify-doc-watch --project-ref hrzpznlpmxxrbtwskacu`
(config.toml pins the import map and `verify_jwt = false`), then re-run the curl.

## Step 3 — commit and push the monorepo

```bash
cd ~/dev/CardCoachv2
git add mobile_app_codebase/supabase/migrations/20260907175034_guardrail_001_exempt_global_offer_card_id_prefixes.sql \
        mobile_app_codebase/supabase/migrations/20260908010442_verify_engine_v2_p1_registry_and_queue.sql \
        mobile_app_codebase/supabase/migrations/20260908010931_verify_engine_v2_p2_runner_api.sql \
        mobile_app_codebase/supabase/migrations/20260908011244_verify_engine_v2_p3_seed_and_backfill.sql \
        mobile_app_codebase/supabase/migrations/20260908011333_verify_engine_v2_p4_doc_watch_plumbing.sql \
        mobile_app_codebase/supabase/APPLIED_MIGRATIONS.txt \
        mobile_app_codebase/supabase/functions/verify-doc-watch/index.ts \
        mobile_app_codebase/supabase/config.toml \
        card_coach_business_docs/01_CORE/verification-engine/RUNBOOK_verify_engine_v2.md \
        card_coach_business_docs/01_CORE/verification-engine/PROMPT_engine_runner_cloud.md \
        card_coach_business_docs/01_CORE/verification-engine/PROMPT_engine_runner_chrome.md
git status --porcelain | grep '^[AM]'              # expect: exactly the 11 paths above staged, nothing else staged
git commit -m "verify engine v2: DB-driven verification engine (registry, fact contract, work queue, runner API, doc-watch); migrations under their recorded versions + ledger; verify-doc-watch edge function (deployed v2); GUARDRAIL-1 file reconstructed from production"
git fetch origin
git merge-base --is-ancestor origin/main main && echo fast-forward-ok || echo "NOT FF — rebase, re-run Step 1, then push"
git push origin main
```

## Step 4 — commit and push the docs repo

```bash
cd ~/dev/cardcoach-docs
git add DESIGN_verify_engine_v2_2026-09-07.md PROMPT_deploy_verify_engine_v2_2026-09-07.md PIPELINE_AND_DECISIONS.md WORKING_NOTES.md
git commit -m "docs: verify engine v2 — design record, decision entry (2026-09-08), WORKING_NOTES #49, deploy prompt"
git fetch origin && git merge-base --is-ancestor origin/main main && git push origin main
```

## Step 5 — ★ Mike's step, optional today: Cloudflare Browser Run secrets

Without these the doc-watch skips client-rendered pages (its result shows them
as `skipped`) and the cloud runner renders through the Cloudflare connector
instead; nothing breaks. If Mike hands you a Cloudflare API token with
**Browser Rendering: Edit** on account `c8f2911db35005faefbb206f61591394`:

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
npx supabase secrets set CF_ACCOUNT_ID=c8f2911db35005faefbb206f61591394 CF_BROWSER_RUN_TOKEN='<token from Mike, never written to a file>' --project-ref hrzpznlpmxxrbtwskacu
npx supabase secrets list --project-ref hrzpznlpmxxrbtwskacu | grep -E 'CF_ACCOUNT_ID|CF_BROWSER_RUN_TOKEN'   # expect: both names listed (digests only)
```

No redeploy is needed — secrets are read at request time. Workers Free allows
10 browser-minutes/day (≈60 renders); Workers Paid removes the ceiling.

## Step 6 — post-push checks (Supabase MCP `execute_sql` if attached; otherwise hand the SQL to Mike)

```sql
select * from verify.v_engine_dashboard;
-- expect: active_cards 152, targets_active 1551, sources_active 396, sources_hash_baselined ≥ 134,
--         awaiting_mike 0, approved_unapplied 0, last_doc_watch today
select check_name, value from verify.v_engine_health;
-- expect: every count 0 except issuers_overdue (small, shrinking as the cloud runner starts);
--         gated_guardrail_rows and write_audit_unattributed MUST be 0
select jobname, schedule, active from cron.job where jobname like 'verify_%' order by jobname;
-- expect: 4 rows, all active
select issuer_token, state, result->>'fetched' as fetched, result->>'changed' as changed, result->>'failed' as failed
  from verify.work_items where kind = 'doc_watch' and due_at::date = current_date order by issuer_token;
-- expect (after 09:55 UTC): 16 rows, state done; before that, the ones the morning sweep has reached so far
select kind, count(*) from verify.work_items where state = 'queued' group by kind;
-- expect: verify_issuer / loyalty_reverify / housekeeping kinds waiting for the cloud runner's first session
```

## Step 7 — report

Append to `~/dev/cardcoach-docs/WORKING_NOTES.md` under **#49**: the two push
SHAs, the gate results, the function version seen in Step 2, whether the secrets
were set, and the dashboard numbers from Step 6. Commit that as
`docs: WORKING_NOTES #49 — engine v2 repos pushed` and push. Leave #49 open —
it closes when Mike has done the ★ items listed there (secrets, legacy tasks retired,
chrome prompt swapped) and the cloud task's first digest has been read.
