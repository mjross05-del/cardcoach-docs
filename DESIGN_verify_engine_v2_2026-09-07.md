# DESIGN — Verification Engine v2 ("the engine")

Date: 2026-09-07 · Author: engine lane (Claude, Cowork cloud session) · For: Mike · Status: **LIVE in production since 2026-09-08 01:13 UTC** — migrations `20260908010442` / `20260908010931` / `20260908011244` / `20260908011333` applied via MCP with byte-identical files in the repo; `verify-doc-watch` deployed v1 and proven on a real sweep (TDBank, 28 sources, 40 s, 11 stored PDF hashes all matched the live documents); `verify.plan()` ran once by hand and runs daily from pg_cron. Remaining cutover steps are Mike's (§9, ★).

Supersedes the operating model in `COWORK_SETUP.md` (eight Cowork-local batch prompts + a separate apply-loop task + a chrome lane with prose state). It does not supersede any decision in `PIPELINE_AND_DECISIONS.md`: every ruling there is carried forward, most of them now as rows or constraints rather than prompt text (§4).

---

## 1. What Mike asked for, and what the record said was wrong

Ask (2026-09-07): take the verify-batch daily prompts and make them "more tied to the database and less prone to failure … an engine that gives CardCoach its competitive advantage … merged into one entity."

What the ledgers and docs show (measured on 2026-09-07, 89 runs, 1,936 fact checks, 152 active cards):

| Symptom | Evidence |
|---|---|
| The prompts were the program | 8 hand-copied Cowork prompts editable only on Mike's Mac; ISSUER_BATCH hardcoded; render.js and the prompts disagreed for a week; the apply-loop SKILL mirror is out of sync with its running copy; the chrome lane's scope query (`wall_status='walled'`) matched zero issuers for two weeks |
| Learned state was prose | `issuer_notes.quirks` up to 25.6 KB per issuer; `doc_locations` in five different JSON shapes; the 2026-09-01 Scotiabank split-brain |
| Coverage was far shallower than "always current" | fees fresh (14 d) on 118/152 cards, FX on 75, **earn rates on 49 — 65 cards never had an earn rate verified, 145 never had a cap verified** |
| Budget burned on known dead ends | 236 `fx_fee_percent` unverified rows across 72 cards (RBC/MBNA info-box facts re-failed weekly; CIBC student fees re-failed four runs running) |
| Free-text vocabulary | 33 fact_key spellings, 35 parking topics, `TD`/`TDBank`/`td-bank`, `runs.issuer_batch` carrying `<merchant-graph>`, `[OPS]` |
| Laptop dependency and a fragile sandbox | batches fire only when the Mac is awake; every run re-bootstraps Playwright through the 45 s cap |
| Invisible to users | no `last_verified_at` anywhere in `public.*` |

## 2. Principles

1. **The database is the program.** Rules, schedules, vocabulary, sources, learned state and the fact contract are rows, CHECKs, triggers and functions. Runners call functions; they never write ledgers directly and never carry rules in their prompt.
2. **Work is claimed, not assigned.** One queue (`verify.work_items`) with leases. A missed day stays due; a dead run loses only time.
3. **Mechanical before intelligent.** Fetching, hashing and change detection run daily in an edge function with no LLM. The LLM spends budget only on changed documents, stale facts and missing coverage.
4. **Every fact has a target.** The fact contract is materialized (`verify.fact_targets`) with per-target state. "Unverified" becomes a state with a re-check trigger, not a weekly re-failure.
5. **Evidence-first is a constraint.** `verify.record_fact` refuses a money fact without two artifacts (or two passes) and a grep-guarded clause; evidence rows must exist and be fresh.
6. **Apply is mechanical.** `verify.apply_item` executes Mike-approved SQL under snapshot-first + old-value guards + write_audit, with a dry-run mode. Auto-class scalars are written by `verify.apply_auto_fact` from the fact row itself — no runner-authored SQL.
7. **Freshness is a product.** `public.card_verification` (one row per card) is maintained by the engine and readable by the app.

## 3. Architecture

```
                 08:30 UTC pg_cron ─► verify.plan()  ──► verify.work_items (queue, leases)
                                                          ▲            │
  08:35–09:55 pg_cron ─► verify-doc-watch (edge fn) ──────┘            │ claim_work()
      fetch · sha256 · Storage · record_evidence/record_source_fetch    ▼
                                                    10:30 UTC cloud runner (Claude scheduled task)
                                                    work_brief() ─► fetch/render/extract ─► record_evidence()
                                                                                         ─► record_fact()  ─► auto: apply_auto_fact()
                                                                                                           ─► gated: apply_queue (staged)
                                                    draft_proposals ─► set_proposal() + apply_item(dry_run)
                                                    Mike (any chat) ─► verify.decide()
                                                    apply_approved  ─► apply_item()  ─► snapshots.* + write_audit + public.*
                                                    close_run()     ─► digest from the ledgers
  weekly, Mike present ─► chrome-lane runner: claim_work('chrome_capture') for what the cloud could not reach
  every write to fact_targets ─► public.card_verification (product surface)
```

Runtimes: **cloud** (Claude scheduled task, no laptop; plain HTTP works for every issuer; rendering via Cloudflare Browser Run over plain HTTPS — verified 2026-09-07 for RBC, Amex, Canadian Tire, Neo **and BMO**, which was chrome-only since July), **edge** (Supabase function on pg_cron), **chrome** (Mike's browser, only for what fails), **chat** (Mike's review sessions through `verify.decide`).

## 4. Schema (all additive; nothing dropped or narrowed)

New in `verify`: `issuers` (+ `issuer_aliases`) — token ↔ `issuers.id`, lane, render mode, cadence · `fact_keys` (+ `fact_key_aliases`) — controlled vocabulary · `parking_topics` (+ aliases) · `sources` — the document registry (replaces `doc_locations`) · `fact_targets` — the contract · `schedules` · `work_items` · `run_events` · `rules` · `issuer_learnings` · `apply_snapshots` · `allowed_target_tables`.
New in `public`: `card_verification` (RLS on, SELECT for anon/authenticated, engine-maintained).
Added columns: `runs.kind/runner/heartbeat_at/work_item_ids`; `evidence.source_id/bytes/content_type/http_status`; `fact_checks.subject_kind/fact_key_raw/grep_guarded/work_item_id`; `parking.topic_raw`; `apply_queue.dry_run/work_item_id`; `apply_sessions.run_id`; `issuer_notes.quirks_archive`.
Widened CHECKs: `runs.runtime` (+cloud, edge), `apply_sessions.runtime` (+cloud), `evidence.channel` (+http_html, browser_run).
Triggers: fact_key normalization + vocabulary enforcement + card existence (new rows only); parking topic normalization; run issuer-token normalization; append-only DELETE block on the five ledgers.
Views: `v_fact_checks_normalized`, `v_coverage_gaps`, `v_freshness_by_issuer`, `v_next_work`, `v_engine_health`, `v_engine_dashboard`; `gated_state_guardrail` replaced column-compatibly (malformed_card_id now only for card subjects).

Where the old rulings went: grep guard, dual confirmation, evidence-before-assertion → `record_fact` checks · cpp never auto → `record_fact` (downgrade + warn) · Rulings 1–4 (hash baseline, hash × revision date, null-by-nature, HTML never diffed) → `record_source_fetch` + `sources.hash_applicable/revision_date_basis` · §10 "not a wall" → `fact_targets.status = sourcing_gap` after 3 consecutive unverified with a hash-change re-check trigger · 3 access failures → `sources.status = unreachable` → chrome lane by `plan()` · one queue row per fact_check → staged inside `record_fact` · rule 9(a) snapshots → `ensure_snapshot*` (in `snapshots`, RLS on, API roles revoked) · SKILL rules 1/3/5/6/9 → `apply_item`, `decide`, `validate_proposal_sql`, DELETE triggers · dedupe 20 h → cadence in `schedules` + `dedupe_key`.

## 5. The runner API (what a runtime calls)

`plan()` · `open_run(runtime, kind, issuer_batch, runner)` · `heartbeat(run)` · `claim_work(owner, kinds[], max, lease, run)` · `work_brief(item)` · `record_evidence(...)` · `record_fact(...)` · `record_parking(...)` · `mark_sourcing_gap(...)` · `upsert_source(...)` · `mark_source(...)` · `record_source_fetch(...)` · `learn(...)` · `note_quirk(...)` · `update_issuer_notes(...)` · `complete_work / fail_work / block_work` · `close_run(run, status, reason)` → digest · `stage_gated(run)` · `set_proposal(queue, sql, rollback, tables, notes)` · `set_needs_input(queue, question)` · `decide(queue, approved|rejected, 'mike', note)` · `open_apply_session(runtime)` · `apply_item(queue, session, dry_run)` · `mark_already_applied(...)` · `close_apply_session(...)` · `sync_fact_targets()` · `refresh_card_verification(card)`.

All SECURITY DEFINER, `search_path = ''`, EXECUTE granted to service_role only. The Supabase MCP `execute_sql` (postgres role) and the edge function (service key through four public RPC wrappers) are the two callers.

## 6. What the backfill established (from production data, 2026-09-07)

- Registry: 16 active issuers + HSBC off; 26 aliases.
- Sources: **396** registered (128 from `doc_locations` across five JSON shapes, the rest from URLs the runs actually fetched, 14 loyalty-stack offer sources); 133 already hash-baselined.
- Contract: **1,551 active fact targets** (+15 permanent load-only); history mapped through the alias table so 224 are fresh today, 854 have never been verified, and **31 sourcing gaps were identified automatically** (Amex FX ×13, RBC ×6, MBNA ×6, CIBC student fees ×5, TD ×1) — the runner will stop re-failing them.
- Product surface: 123 cards `partially_verified`, 30 `unverified`, 0 `issuer_verified` — the honest baseline the engine now drives up.
- `runs.kind` backfilled (66 verify, 18 ops, 5 chrome); historic issuer tokens normalized (`TD`→`TDBank`, `rbc`→`RBC`).

## 7. Operating model after cutover

| When (UTC) | What | Who |
|---|---|---|
| 08:30 daily | `verify.plan()` — sync contract, reap leases, schedule due work, change-driven work, chrome routing | pg_cron |
| 08:35–09:55 every 5 min | `verify-doc-watch` — one issuer per call: fetch, hash, Storage, record | edge function |
| 10:30 daily (06:30 ET) | cloud runner — housekeeping (stage, draft + dry-run, apply approved, retention) then ≤3 issuer-scale items | Claude scheduled task `cardcoach-verify-engine` |
| any time | review: `select * from verify.v_review_packet` → `select verify.decide(id, 'approved', 'mike', note)`; dry-run results on each row | Mike |
| weekly, Mike present | chrome-lane runner — only `chrome_capture` items (unreachable sources) | Cowork + Chrome |
| 1st of month | `retention_review` work item (replaces the separate monthly task) | cloud runner |
| 2027-05-01 | DATA-018 Shell/Scene+ promo recheck as a `loyalty_reverify` work item (replaces the one-shot task) | cloud runner |

Cadence, not calendar: each issuer is due 7 days after its last completed verification, preferring its old weekday; a missed day self-heals the next morning. Documents that change re-open only the cards that cited them (priority 20, ahead of the weekly items).

## 8. What is deliberately different from v1

- **Auto-class writes are restricted to `card_products` scalars** (fee, FX, base_earn). Earn-row and cap changes are gated in v2 (history: 11 gated vs 1 auto earn change) — fewer unattended writes to the tables the ranking engine reads.
- **`display_name` changes are gated** (a rename usually signals a conversion).
- **BMO and Neo move to the cloud lane** (Browser Run renders them). PDFs behind BMO's wall remain chrome-lane chasers; the engine routes them there automatically after three failed fetches.
- **`issuer_notes.doc_locations` is frozen** as history; `verify.sources` is canonical. `quirks` stays readable in every brief but grows only through `note_quirk` (bounded, archived, never lost) and structured facts go to `issuer_learnings`.
- **Digests are generated** by `close_run` from the ledgers; counts can no longer disagree with the tables.

## 9. Cutover plan (Mike's decisions marked ★)

1. **DONE 2026-09-08 01:04–01:13 UTC** — migrations p1–p4 applied to production via MCP (`apply_migration`) as `20260908010442_verify_engine_v2_p1_registry_and_queue`, `20260908010931_verify_engine_v2_p2_runner_api`, `20260908011244_verify_engine_v2_p3_seed_and_backfill`, `20260908011333_verify_engine_v2_p4_doc_watch_plumbing`; files written under those versions + `APPLIED_MIGRATIONS.txt` (rule 9(e)); ★ commit + push per `PROMPT_deploy_verify_engine_v2_2026-09-07.md`.
2. **DONE 2026-09-08 01:18 UTC** — `verify-doc-watch` deployed v1 via MCP (verify_jwt off, token-authenticated like receipt-purge-worker); wrong token → 401, right token → idle, then a real sweep after `plan()`: TDBank 28/28 fetched, 0 changed, 0 failed. ★ Set `CF_ACCOUNT_ID` + `CF_BROWSER_RUN_TOKEN` as function secrets (Cloudflare API token with Browser Rendering: Edit) — until then the doc-watch skips rendered pages (`skipped` count in its result) and the runner renders through the connector. Note the Workers Free plan allows 10 browser-minutes/day; ~60 renders/day fits, Workers Paid ($5/mo) removes the ceiling.
3. **DONE 2026-09-08 01:35 UTC** — cloud scheduled task `cardcoach-verify-engine` created and enabled (`trig_01GsH2snaKFFjrXL8A9YJjdj`, 10:30 UTC daily, prompt = `PROMPT_engine_runner_cloud.md`). ★ Read its first digest.
4. ★ Pause/delete the 8 Cowork batch tasks and the `cardcoach-apply-loop` task the same day (running both would double-verify and the legacy prompts now hit the vocabulary trigger on any new spelling). Retire the monthly retention task and the 2027-05-01 DATA-018 task (both are work items now).
5. Keep the chrome-lane task but replace its prompt with `PROMPT_engine_runner_chrome.md`.
6. Follow-on (separate lane): app + web read `public.card_verification` to show "Issuer-verified N days ago".

Rollback: each migration file ends with its rollback block; nothing in `public.*` other than the new `card_verification` table is touched.
