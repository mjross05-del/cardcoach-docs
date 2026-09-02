# CardCoach Working Notes

**The only file that churns.** What's unresolved, who owns it, what unblocks it, what's
next. Update freely. When an item closes, **delete it** — closed items don't belong here.
Settled decisions move to `PIPELINE_AND_DECISIONS.md`; they don't live here.

Last updated: 2026-09-02 · Owner: Mike  (header date corrected 2026-07-04, housekeeping sweep 2 — was 2026-07-03, contradicting the 2026-07-04 dated updates within; prior correction 2026-07-03 — was 2026-06-02)

> For a future session: this is where you look to find what needs doing next. Don't
> re-propose items already listed here unless you have new information.

## Status index (added 2026-07-04, housekeeping sweep 2 — derived from the dated entries below; the entries stay authoritative)

- **#1** Scotia dry run — CLOSED 2026-07-04 (overtaken by the 2026-06-10 Scotia SQL handoff)
- **#2** Apply-delta helper script — not started; RESCOPED 2026-08-01 (input is now batch gated packages/parking rows, not Stage-3 JSON — script pipeline retired)
- **#3** French-language verification pass — not started (deferred post-V1); RESCOPED 2026-08-01 (vehicle is FR-CA passes inside the daily batches, not registry rows — registry retired)
- **#4** "Uncertain" registry entries (~10 landing-page rows) — CLOSED 2026-08-01 (retired with the registry; batch coverage-diff owns source discovery, per-card PDF paths accumulate in verify.issuer_notes)
- **#16** Blue Rewards tier successors (BMO) — CLOSED 2026-07-02
- **#5** Welcome-bonus data pipeline — design approved 2026-07-03; DB-side implementation pending
- **#8** Rogers cohort-differentiated rates — CLOSED 2026-07-04 (date-gated 2026-08-04 delta pre-staged; August confirmations remain; August-cycle fetcher/registry prep done 2026-07-05)
- **#9** PC Financial post-EQB — in progress (F2 post-close CMA, F3 standard-card income still open)
- **#10** Per-litre rate_unit enum — open, low priority (LANE CHANGE 2026-08-01: Mike's; pump case resolved by DATA-018 offers, enum only matters for catalog earn_rates)
- **#11** Legal review of affiliate disclosure — not started
- **#12** Commission-blind policy publication — not started
- **#13** Live-site hold-back claims — not started
- **#14** Point Valuations xlsx disposition — not started (LANE CHANGE 2026-08-01: Mike decides directly)
- **#15** File-for-Alex pack confirmation — not started (LANE CHANGE 2026-08-01: Mike decides directly)
- **#18** Email routing on cardcoach.ca — not started (Mike, ~10 min; gates the domain-flip push)
- **#19** Site git wiring / deploy-channel cutover — wiring DONE 2026-07-05; G3 domain move pending (was a duplicate #16, renumbered 2026-07-08)
- **#32** Airline brand block (3000-3299) still head-coded while hotel blocks are now enumerated — inconsistent after the 2026-08-26 ruling; ~300 mapping rows, ranking-affecting, gated work
- **#33** `doc_locations` sha256 + revision-date drift signal — RULED 2026-08-26, **not built**; all 37 existing entries still bare URLs
- **#34** Real FX gap **DIAGNOSED 2026-08-26** — 40 active cards NULL; **zero robots-blocked, zero never-attempted**. Mostly correct rule-7 withdrawals (clause states conversion mechanism, never a percentage); RBC 6 are #23a in-application InfoBox staleness; 10 live TD cards are the one block worth chasing
- **#36** Chrome lane's scope query (`wall_status='walled'`) matches **zero issuers** — its standing queue is empty by construction; last ran 2026-08-16 against a weekly charter, while #34/#23a queue real work for it
- **#37** **Privacy policy / Law 25 gap — CLOSED 2026-09-02** (review lane, F-15): `/privacy` now carries the full policy (collection list, providers, US storage, retention, named privacy contact, OPC/CAI routes), `/legal` has subscription terms, `/terms` 301s to `/legal`, and the app links both from the paywall and Settings. **Residue → #40** (receipt retention). Original entry kept for the record: FLAGGED 2026-08-27, deliberately deferred by Mike ("leave legal for now, flag it"). There is no privacy policy with a collection list: `site/privacy.html` is a plain-English summary with no enumerated collection list, no retention period and no Law 25 disclosures, and `/privacy` and `/legal` link to each other for the document neither contains. The site is English-only (`<html lang="en-CA">`, 25 flat files, no `/en/` or `/fr/`). `COMPLIANCE_statement_import_pack_2026-08-20.md` §0 calls this a launch blocker for statement import **in Quebec**, and `runtime_flags.statement_import` is now `enabled = true` — so the gate is currently the entitlement, not the flag. Not being worked; do not start it without Mike.
- **#38** **Paywall live but unsellable — OWNED BY MIKE, in progress 2026-08-27, progress expected within days.** `RUNBOOK_pro_go_live_2026-08-24.md` states the paywall is live and advertising a tier the app cannot sell; `public.user_entitlements` holds 50 granted rows and `react-native-purchases ^10.7.1` has shipped since 2026-08-21. **Do not pick this up** — it is actively being worked. Related: the `$3.99/$34.99` model vs `$4.99/$39.99` product config drift recorded in `REVENUE.md` §Pricing. **UPDATE 2026-09-02 (review lane):** the app no longer offers an upsell on a build that cannot sell (`useFeatureGate` checks the purchase layer), the RevenueCat webhook defers a grant that carries no expiry to `billing-sync` instead of granting open-ended Pro, the purchase confirmation waits for the entitlement to land, and the paywall/Settings link the Terms and Privacy pages (App Review 3.1.2). **UPDATE 2026-09-01:** paywall flags are now *false* (build 84), so nothing unsellable is advertised. RevenueCat is as far as it can go without credentials (entitlement `cardcoach_pro`, Play app, Play products `cardcoach_pro:monthly`/`:annual`, `default` offering; App Store app **blocked on the new team's `.p8` key**). Remaining gates are Mike's: **D-U-N-S → Apple Organization enrolment → Paid Apps/banking/W-8BEN-E**, **Google Payments merchant profile** (Play Subscriptions page locked without it), secrets/webhook/EAS. Then Alex transfers the app (TestFlight off, SIWA transfer ids — **11 Apple users**, 60-day window). Prices are now $7.99/$59.99/14-day. Runbook: `RUNBOOK_store_accounts_and_revenuecat_2026-09-01.md`.
- **#39** **AFF-001 beacon — CLOSED 2026-09-02**: `affiliate-click` v2 deployed with Origin/apikey/per-IP gates and the DB-side `affiliate_click_record` guard (60/min ceiling, 5 s per-card cooldown), site pushed by Mike, one live click confirmed as one row. Original entry: has a table but no function — OWNED BY MIKE, in progress 2026-08-27. `public.affiliate_clicks` was applied 2026-08-28 02:06 UTC (migration `20260828020603`), but the `affiliate-click` edge function is **not deployed** and the site changes are still unstaged in the site repo (`mjross05-del/cardcoach-site`). The order matters: if the **site** ships before the **function**, clicks post to nothing and silent zero-collection is indistinguishable from genuinely no clicks. Deploy the function first, or ship both together. **Do not pick this up** — actively being worked.
- **2026-09-02 REVIEW LANE — one lane now (all other runtimes retired 2026-09-02).** Findings and status: `REVIEW_full_2026-09-02.md`. Landed on monorepo `main` today (Mike to `git push`): SEC-001 (views `security_invoker`, API write grants revoked), CAPS-001 (engine reads `card_caps`), AFF-002 (guarded click recorder), SEC-002 (per-user rate limits on the four paid paths), billing/auth hardening, F-12 CI gates (Deno tests, bundle hash, i18n, N+1, migration ledger, disclosure), F-13 migration ledger (18 files reconstructed, 4 renamed), F-15 legal pages + app links, DATA-018 p2 fuel grades merged, `config.toml` import-map pin. Open items it leaves:
- **#40** **Receipt retention — CLOSED 2026-09-02.** Mike decided 90 days. RCPT-011 (migration `20260902163813`, applied): tenant `retention_days = 90`, pg_cron + pg_net enabled, `receipt.purge_expired(500)` nightly 03:10 UTC, `receipt-purge-worker` edge function (deployed v1) nightly 03:20 UTC deleting queued objects through the Storage API, authenticated by a Vault token both sides read. Proven end to end on a synthetic queue row. First deletions fall due 2026-11-24. Policy §2.4/§6 now state the fixed period. Watch: `receipt.storage_purge_queue` rows with `purged_at IS NULL` and rising `attempts` are the alert.
- **#41** **Edge deploy of today's changes — CLOSED 2026-09-02.** Mike ran the deploy at 16:31 UTC; 16 functions verified on their new versions (CAPS-001, SEC-002, the webhook fix and the fuel-grade scope are live), `config.toml` pins the import map so no `--import-map` flag was needed, and `receipt-purge-worker` v1 followed with RCPT-011.
- **#42** **Undeploy dead functions — CLOSED 2026-09-02 (one over-reach, corrected the same day).** Mike deleted `recommend-here` (v1), `recommend-card` (v1), `resolve-merchant-v1`, `import-spend-v1` and `health` on the lane's list. `health` and the v1 pair were right (`health` reported key generations to any signed-in caller; its source is removed from the repo). `import-spend-v1` (API-022, the write half of statement import, dark behind `statement_import_write`) and `resolve-merchant-v1` (API-018, server half of online-merchant identity awaiting its APP-022 client) are **not dead** — they are shipped-dark features with tests and config blocks, and the review's F-16 was wrong to list them. No user impact (nothing calls them today). **Both re-deployed by Mike the same day** (`import-spend-v1` v1 and `resolve-merchant-v1` v1 verified in the deployed list) — closed. `recommend-cards-stateless-v1` was never on the list: cardcoach.ca's /best-card calls it.
- **#43** **Retired lane's checkout — CLOSED 2026-09-02.** `~/dev/CardCoachv2` is back on `main` and `data-018/fuel-grade-scope` is deleted. Two edits the retired lane never committed were still sitting in the working trees afterwards — the 2026-08-24 Android-submit proof (#24d below, and 19 lines in `docs/app-store/RELEASE_android_1.x_HANDOFF.md` Step 2); the review lane carried both into the repos as written rather than leave them uncommitted.
- **#44** **CLOSED 2026-09-02** — the merchant-category batch ran (run `99b6d975`, Mike deciding in chat: Pioneer→gas, Holiday Inn Express Strathroy→travel, SOCO Cafe→coffee_fastfood applied with audits; Pioneer→grocery rejected) and the p3 backfill is applied (#27). Follow-on for Mike's ruling: `dispatches/WORKLIST_merchant_category_name_pass_2026-09-02.md` — 39 name-derived categories for the 45 placed entities still NULL (the queue's `source` CHECK admits only the two request paths, so these are listed for approval rather than forced into the queue). **Ruled and applied 2026-09-02 18:03 UTC:** Mike approved all 39 in chat; run `4b0ccfa5` (39 write_audit rows, snapshot `snapshots.merchant_entities_snapshot_20260902_namepass`, delta `deltas/2026-09-02__merchant_entities__category_name_pass_39_APPLIED.sql`). Guardrail `placed_null_category` 45 → 6 — the six with no honest category in the taxonomy; the other 32 NULL entities have no place row and never score. Found on the way: a second "Best Buy" entity (`d1592676`) beside `e4372aec` — chain binding, not category.
- **#45** **Company name in the app config — part CLOSED 2026-09-02.** The `apps/web` `/privacy` and `/terms` routes now `permanentRedirect` to `cardcoach.ca/privacy` and `cardcoach.ca/legal` and left the sitemap; the FalconView.ai policy text is gone from the repo. Still open, Mike's: `app.config.ts` `owner: "falconview"` (the Expo account that owns the EAS project — moving it is an account transfer, not a config edit) and the Sentry org `falcon-view-group` (crash data lands in an org Mike has no login for; the `ota:publish` sourcemap step depends on the same org).
- **#46** **Snapshots out of `public`; security advisor down to one toggle — DONE 2026-09-02** (review lane, F-18). SNAP-001 (`20260902172110`) created the unexposed `snapshots` schema and moved the 68 `*_snapshot_*` tables; SNAP-002 (`20260902173014`) took the three `*_night_2026_07_31` copies; SEC-003 (`20260902172821`) moved pg_net's extension record from `public` to `extensions` (not relocatable, so drop + create; the worker was proven alive with a live request afterwards) and pinned `search_path = public` on the six pre-existing functions the advisor flagged. Security advisor now: 0 ERROR; 1 WARN — `auth_leaked_password_protection`, a dashboard toggle for **Mike** (Authentication settings → password security; remediation: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection); 90 INFO `rls_enabled_no_policy`, all deliberate (service-role-only tables and the `snapshots`/`verify`/`receipt` schemas). Rule 9(a) now creates snapshots as `snapshots.<table>_<stamp>`. **Standing chore (Mike, monthly):** `select * from snapshots.v_retention_candidates;` → confirm no delta still needs the table → run each `drop_sql` by hand; the first candidates appear 2026-10-27. Also from to-do 19: the NUL byte in `_shared/scoring.ts` was a literal NUL used as a map-key separator (`${program}\0${unit}`, line 1744) — it made grep and diff treat the file as binary; rewritten as the `\u0000` escape (same key at runtime, text-safe file). `_shared/pii.ts` is unused by any function but carries its own tests, left in place.
- **#47** **CIBC Adapta modelled — DONE 2026-09-02 (DATA-023, Mike: "add condition type").** New `earn_rates.condition_type = 'auto_top_n'` with `condition_top_n` (N) and `condition_group` (the issuer category a row competes as when one CIBC category spans two of ours). Migration `20260902182121`; the 33 rows retyped from `mcc_defined`-with-no-MCC under run `7d3e0c1a` (audit `21096c42`, delta `deltas/2026-09-02__earn_rates__adapta_auto_top_n_APPLIED.sql`). The edge gate ranks the purchase's issuer category against the card's others from this month's `user_spend_snapshots`, purchase counted in; ties, no category, no N and callers without spend facts (the web ranking, the stateless catalog path, analyze-spend) fail closed. 17 Deno tests + 2 engine cases. **Live after Mike's next edge deploy.** Residue of #27: 2 active `mcc_defined` rows with no MCC list (Aeroplan VIP dining, Neo United travel), both withheld with reasons on file. Not modelled: Adapta's $40,000 annual bonus pool (a `card_caps` row, CAPS-001).
- **#48** **Wealthsimple onboarded (17th issuer) — DONE 2026-09-02, four follow-ups open.** Four `card_products` (Visa Infinite + open; Privilege `limited`; 1% `invitation_only`; 2% `closed` — all scoreable), four flat base rows, `verify.issuer_notes` seeded; deltas `2026-09-02__issuers_card_products__wealthsimple_onboarding.sql` + `2026-09-02__earn_rates__wealthsimple_p1.sql`; decision entry in PIPELINE_AND_DECISIONS. **(a) Mike, ~1 min:** add the token `Wealthsimple` to the Sunday Cowork task's `ISSUER_BATCH` — the batch cannot be edited from a cloud session; until it lands, Wealthsimple is verified by nobody. **(b) First Sunday run:** capture CHA-080426-WS, CHA-041026-WS1 and ACCTC-080426-WS as `verify.evidence` artifacts (onboarded without sha256 rows) and confirm the legacy 2% card's grandfathered fee box. **(c) Store/site copy:** the Play listing says "15 Canadian issuers" — 16 with tracked cards from today; bump at the next listing edit. Playbook post 15 (foreign-transaction fees, live since 2026-09-02) lists the catalogue's no-FX cards and says other issuers' no-fee cards "are not in our catalog yet" — Wealthsimple's three 0%-FX cards now belong in that list; re-render on its next edit. **(d) Pushes (Mike):** monorepo `main` (picker order, `apps/web` H29 filter, COWORK_SETUP rotation), site deploy repo `main` (`apply-links.js` +4, `best-card.js` gap-finder skips closed / invitation-only cards — the first scoreable non-offered cards in the catalogue), docs repo `main`. **(e) Unrelated find:** `ca_national_bank_mycredit_standard_mastercard` is the only active scoreable card with no active `base` earn row (two category rows; scalar `base_earn` 0.5) — a Saturday-batch item, not touched here. Status after the independent re-read: Visa Infinite + is `limited` (the "limited quantities" sentence covers both + and Privilege), see the addendum entry in PIPELINE_AND_DECISIONS and delta part 3.
- **#35** Document-currency follow-ups from the 2026-08-25 sweep — RBC hub dead (navigate fresh, do not guess), NationalBank FX box may be the FR artifact, 3 aged docs to check against their indexes, Neo corpus now checkable
- **#20** Web app v1 (free recommendation surface) — approved 2026-07-13 (D1); P1 pending keys
- **#23** merchant_list_only eligible lists — BACKFILLED PASS 1 + CHAIN BINDING FIX, 2026-08-02 (second live find: Google location-suffixed names minted orphan entities; 3 places re-pointed by delta, durable fix MERGED b13595f + migration applied to cloud (48 chains) + resolve-place v13 DEPLOYED with live 200s 2026-08-02; the "LAST STEP" recommend-here-v2 deploy happened long ago — v33 is live as of 2026-09-02) (108 pairs / 21 of 31 rows; delta `deltas/2026-08-02__earn_rate_eligible_merchants__backfill_p1.sql`). Was EMPTY in production — every list-gated earn row failed closed everywhere; found via Mike's live Superstore test. Remaining: 10 rows deliberately fail-closed (network/classifier-defined); PC list is officially NON-EXHAUSTIVE (Provigo/YIG/Dominion/T&T unnamed in any official text — Sunday batch watches for an official enumeration); local seed.sql parity not done; Sunday/Sunday+Monday batches now maintain these lists via gated proposals.
- **#22** Loyalty stacking Phase 1 — **ACTIVATED 2026-08-02** (flag flipped 13:41 UTC, delta `deltas/2026-08-02__runtime_flags__loyalty_offer_stacking_on.sql`; all three gates closed; rule 5 superseded-in-part). Remaining tail in section below: counsel review before QC GA, batch parking reviews now carry live-data weight. Phase 1.1 (member-earn display + attribution notice) DISPATCHED 2026-08-02 for an Opus 5 session: `dispatches/DISPATCH_member_earn_display_2026-08-02.md` (DATA-019/API-014/APP-018; #1 invariant: response-level optional fields only — no new explanation-item types while the current build is live).
- **#25** API-011 disclosure slices (`mcc_defined` suppression) — **Slice 1 SHIPPED 2026-08-14**: `recommend-card-v2` v21, commit `f1a7158`. Adds `conditionalNotApplied[]` per recommendation plus two success-log fields. Client rendering of the field landed in the app receipt 2026-08-16 (contracts + EN/FR; ships in 1.0.3); here-v2 does not emit it yet — that port is the natural Slice 2, decided by the same exported `earnRowPrices` predicate that prices the rows (settled: see the 2026-08-14 entry in `PIPELINE_AND_DECISIONS.md`). Ranking byte-identical — RCSS `topCardId`/`cardCount` matched the same-day pre-deploy baseline on live taps; Kelsey's had no same-day v20 tap to compare against, so that half is unmeasured rather than verified. Governing doc is `HANDOFF_mcc_gating_accuracy_strategy.md` §6, which is **not filed anywhere on the machine** — searched 2026-08-14 by filename and by content across `~/dev`, `~/Documents`, `~/Downloads`, `~/Desktop`; only the rising-tiers and cpp-valuation handoffs exist. Its slice list beyond Slice 1 and its D-series decisions are unrecorded, so recover it (or ask Mike) before running Slice 2+; file it at this repo's root next to `HANDOFF_engine_rising_tiers_2026-08-12.md`. Execution record for what actually shipped, explicitly not a substitute for the strategy: `dispatches/NOTE_mcc_gating_slice1_2026-08-14.md`. The `default_category_id` runtime write-back listed here is DONE (`86c6110`). **MERCHANT-PATH ASSUMPTION ACTIVATED 2026-08-14** — the core accuracy gap this program targeted is closed ahead of the missing strategy doc: commit `42d4dc0`, `recommend-card-v2` **v23** + `recommend-here-v2` **v22** (use those for drift checks), flag `merchant_mcc_assumption` flipped ON by delta the same day (see the PIPELINE decision entry of 2026-08-14; ordered test, NOT blanket fallback; flip-off = no-deploy rollback). **`mcc_includes` BACKFILL PASS 1 APPLIED 2026-08-14** (delta `deltas/2026-08-14__earn_rates__mcc_includes_backfill_p1.sql`, audited, rowcount-asserted 15): populated only rows whose MCCs were already evidenced ON the row — 5 tier-A (condition_text cites numerals: MBNA ×4, Costco gas/EV) + 10 tier-B (condition_text quotes verbatim network MCC class names; deterministic name→number lookup recorded per row; issuer batches spot-confirm on their next weekly pass — CIBC is Friday). Now **103/145 `mcc_defined` rows price** (80 mapping + 23 fallback), verified by post-apply recon. Includes CIBC dining `c0cfce4c` [5812,5813,5814] and grocery `f382d9d7` [5411], so **Kelsey's and RCSS now exercise the assumption** — expect `mccAssumptionAppliedIds` to carry those ids on the next taps. **Residue: 42 rows, verify lane** — all generic prose ("eligible dining purchases", "as classified by Visa MCC", "AUTO TOP-3", Amex classification language); assigning numbers there would invent card facts (rule 7 — see the 2026-08-14 evidence-tier decision entry). Biggest holders: CIBC Adapta auto-top-3 family (~16 rows incl. all fallback-category rows), BMO Eclipse family (~7), CIBC Aeroplan/Aventura "eligible X" rows (~9), Scotia Amex "as classified by Amex" (~5), Scotia Momentum recurring (2 — text defines by billing mechanism, not MCC; batch should reconsider their `condition_type`). Local seed.sql parity not done (same standing gap as #23). Recon repro: join live `earn_rates` (condition_type=`mcc_defined`, valid) against active `mcc_category_mappings` per category. Also still open: **D3 user-facing copy**, which gates all client rendering — the API now ships `categoryMccAssumption` + `mccAssumptionApplied[]`/`conditionalNotApplied[]` but nothing reaches users until D3; engine-contracts type additions (ride the D3-gated client commit); the `assumptions` response key stays occupied by `fuelAssumptions` (Slice 5 collision sidestepped via the distinct `categoryMccAssumption` key — Slice 5 itself unresolved); folding stateless onto the shared `_shared/categoryMccAssumption.ts` loader (parked, own commit + verify:api-011 run).
- **#26** Merchant category proposal queue — **code CLOSED 2026-08-14; the batch first ran 2026-09-02 (run `99b6d975`, #44).** All 10 request-path self-heal writes on `merchant_entities.default_category_id` are gone: `recommend-card-v2` ×1 (`86c6110`, v22), then `recommend-here-v2` ×6 and `resolve-place` ×3 (`cc445e2`, deployed v21 / v15). All three functions now write nothing to `merchant_entities`. Three of the nine were dead (the legacy-alias normalization branches: guard is `normalized !== stored`, all 344 non-null rows are canonical, `classifyPlace` only emits canonical slugs) and were deleted; the six that carried real signal — filling a null category, refining `dining` → `coffee_fastfood`/`food_delivery` — now record to `verify.merchant_category_observations` via `public.propose_merchant_category` (SECURITY DEFINER, service_role only; migrations `20260814193000` + `20260814200000`). Each call site still uses the classified category for its own request, so no response changed. Review surface: `verify.v_merchant_category_review`. Batch: `PROMPT_merchant_category_apply.md`. **THE OPEN RISK IS NOW THE OPPOSITE OF WHAT IT WAS.** The writes are gone but nothing drains the queue: the batch is unscheduled and has never executed, and the queue is still empty because no traffic has exercised the new path. `recommend-card-v2` has **no classifier fallback**, so every entity with a null `default_category_id` (113 at 2026-08-14) is scored base-rates-only on every tap until the first gated apply runs — a queue nobody drains is strictly worse than the self-heal was. **Lane exercised end-to-end on live traffic 2026-08-15**: Mike's Harvey's taps hit a Jan-22 hand-seed entity (NULL category) — proposal recorded (`fill_null → dining`, deduped ×2), Mike approved in chat, applied via manual Phase A with audit (delta `2026-08-14__merchant_entities__category_55388951.sql`); his ranking was base-rates-only until the apply, proving the drain-urgency live. **Batch SCHEDULED 2026-08-14**: local Claude Code scheduled task `merchant-category-apply`, Mondays 07:01 (runs when the app is open; fires on next launch otherwise — port the self-contained `PROMPT_merchant_category_apply.md` into the Cowork rotation beside the issuer batches if machine-independence is wanted). First run needs its Supabase MCP tool approvals — use "Run now" once to pre-approve, or the 7am run stalls silently on a permission prompt. Cross-check that it is running: `merchant_graph_guardrail`'s `placed_null_category` count should fall. Design note for anyone extending this: these rows **cannot** live in `verify.apply_queue` — `fact_check_id` is NOT NULL against `verify.fact_checks`, which requires `card_id`/`fact_key`, and a merchant-category proposal has neither (the `cc445e2` commit message claimed otherwise and is corrected by `e3b084f`). Why unattributed merchant-graph writes are expensive: `DESIGN_place_resolution_v1.md` §1.4; the old site catalogue is at that file's line 27.
- **#28** Neo Financial onboarding — landed 2026-08-16 (16th issuer, 9 cards, **7 scoreable**). FX CLOSED same day at 3% (not 2.5%) by run `25c45942`. Carrier point valuations applied PROVISIONALLY and are **unconfirmed — a deeper dive is owed**; Cathay FX + annual fee sourced from the Quebec disclosure for a card not sold in Quebec — **fetch the Except-Quebec twin**; 4 other carried [VERIFY] items. Section below.
- **#27** MCC gating data debt — **APPLIED 2026-09-02: 40 of the 76 rows** (BMO 11, CIBC 19, Scotiabank 10; run `f890f135`, three `write_audit` rows, `deltas/2026-09-02__earn_rates__mcc_backfill_p3_APPLIED.sql`). Source-clause checks closed against the issuers' own guides fetched that day: BMO and Scotiabank define categories as the network category (category-typical sets kept); CIBC names merchant classes, so its rows carry the narrower deterministic sets (grocery 5411; gas 5541/5542/5552; drug stores 5912; Dividend dining 5812/5813, transit 4111/4121; Aeroplan VIP travel = footnote 11's list). **Still empty, fail closed (35):** 33 CIBC Adapta auto-top-3 rows (pricing all 11 categories would over-credit — same class as the Tangerine choose-N precedent; needs a modelling decision, not MCCs), Aeroplan VIP dining (guide names no class), Neo United travel (airline-only clause; a partial set would price at hotels under the category-level assumption). Recon: 166 active `mcc_defined` rows, 128 price by mapping intersection. **Engine note:** `assumptionAdmitsMccDefinedRow` is set-intersection with the category's mapped MCCs, so today a narrower set prices exactly like the typical one — the narrow sets are recorded for the day merchants carry real MCCs. Original entry: **76** active `mcc_defined` rows with no `mcc_includes` fail closed and never price; **all 76 are live-suppressed on active, scoreable cards** (CIBC 53/10 cards, BMO 11/3, Scotia 11/3, Neo 1/1). Was 52 on 2026-08-16 — the debt grew while the approved backfill sat unshipped. **UNBLOCKED 2026-08-26:** Mike granted standing per-issuer approval, replacing the by-name-in-chat gate that stalled it; deltas regenerated against the current 64 fillable rows as `deltas/2026-08-26__earn_rates__mcc_backfill_p3{a,b,c}_*_PENDING_VERIFY.sql` (pass-2 files superseded). 12 rows remain in the 4 still-unmapped categories (transit_parking, e_games, ev_charging, hotels_motels — all CIBC) and need `mcc_category_mappings` first. Brand-block representation SETTLED 2026-08-26 (enumerate). Section below.

---

## #1 — Unblock the first real pipeline run (Scotia Momentum dry run)

- **Status:** CLOSED 2026-07-04 (Mike): overtaken by the 2026-06-10 Scotia SQL handoff.
- **Owner:** Mike + Alex
- **Blocker:** Alex needs to confirm the SQL file format he wants for approved deltas.
- **Next action:** Mike pings Alex to confirm the handoff format, then runs Stage 2 + Stage 3 for **Scotia Momentum Visa Infinite only**, produces a mock SQL delta, and walks through it with Alex.
- **Context:** Single-card dry run to prove the loop works end-to-end before committing to a monthly cadence. Scotia Momentum chosen because its earn structure is well-known, its Revolving Credit Agreement pattern is typical, and it's not mid-change. Low-stakes proof.
- **Also note:** `stage2_fetcher.py` is now recovered and compile-checked (it had been trapped inside `stage2_fetcher.pdf`). Before the run, `pip install requests pdfplumber beautifulsoup4`, then validate with `--dry-run`, then a one-issuer smoke test (`--issuer Amex`). It has never been executed against the live registry, so treat the first real run as a test of the script too, not just the data.

## #2 — Apply-delta helper script

- **Status:** not started — RESCOPED 2026-08-01 (script pipeline retired; the Stage-3-JSON framing is dead)
- **Owner:** Mike
- **Blocker:** None hard. Worth building once gated-package volume justifies it.
- **Next action:** ~100 lines that turn a batch **gated package / parking row** into the dated delta SQL file rule 10(b) requires (expire-then-insert, guards, snapshot preamble). The 2026-06-10 one-file-per-card handoff-format decision still applies to the output.
- **Context:** The daily batches classify structural changes as gated and record loyalty reverify results in verify.parking; applying them is manual SQL authoring today. The helper closes that gap in the new process.

---

## Data coverage gaps

### #3 — French-language verification pass
- **Status:** not started — RESCOPED 2026-08-01 (registry retired; "324 blank FR-CA rows" no longer the unit of work)
- **Owner:** Mike
- **Blocker:** None — scope only. Deferred to post-V1 per the 2026-04-22 decision.
- **Next action:** When V1 stabilizes, add an FR-CA leg to the daily batch prompts (fetch each issuer's FR pages alongside EN, diff the facts, record divergences as gated) — or run one dedicated FR sweep session per issuer, batch-style, ~3 hours total.
- **Context:** Quebec is a distinct launch channel, not a translation target. FR pages diverge from EN (Desjardins Bonidollars classification, National Bank product tier names). Needs its own review.
- **Watch:** reconcile the "French in V1" wording with the Operating Model — French is a V1 *market* commitment; French *source reverification* is the deferred piece. Say it once, in one place.

### #4 — "Uncertain" registry entries — ~10 landing-page rows
- **Status:** CLOSED 2026-08-01 — retired with the registry (script pipeline retirement, PIPELINE_AND_DECISIONS 2026-08-01 entry).
- **Context kept for the record:** CIBC Aeroplan benefits guides, MBNA Mastercard Benefits, and Rogers per-card benefits guides were landing-page-only registry rows. The need survives in the new form: batches resolving a direct per-card PDF record it in verify.issuer_notes for that issuer, which every future run reads first.

### #16 — Blue Rewards tier successors (BMO)
- **Status:** CLOSED 2026-07-02
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** None — no remaining BMO capture items. BMO's only standing item is the manual monthly fetch (bot block), noted in the infrastructure section.
- **Context:** **World Elite RESOLVED** — captured + delta filed (`2026-07-02__bmo__blue-rewards-world-elite.sql`); **fee + income resolved 2026-07-02** (product page captured: fee $150 waived yr 1 with chequing rebate; income $80K/$150K — fee delta filed). **World tier RESOLVED as no-successor** — closure delta filed (`2026-07-02__bmo__air-miles-world-closure.sql`): application_status closed, earn rows expired without replacement.

### #5 — Welcome bonus data pipeline
- **Status:** design approved (Mike, 2026-07-03 — PROPOSAL_welcome_bonus_schema_2026-07-03, all seven open questions resolved)
- **Owner:** Mike
- **Blocker:** None — flagged as a "significant gap" in data governance.
- **Next action:** DB-side implementation sits documented until picked up; capture flow may begin populating offer records as drafts once tables exist.
- **Context:** Welcome bonuses drive applications, and therefore affiliate revenue. Currently not in the verified dataset at all. Separate from the monthly loop but shares source material.
- **Example data for the schema decision (verified 2026-07-02, note-only):** PCF no-fee stream — 50,000 pts on $100 qualifying spend at named banners within 60 days, apply by 2026-07-31. PCF Insiders — 50,000 pts after $3,000 in 3 months + $120 first-year credit. Standard PC Mastercard: 20,000-point special offer (Silver product chart, seen 2026-07-02) — distinct from the 50K stream offer. All time-bounded and offer-specific — supports the separate-table option. Welcome bonuses remain outside the verified dataset.
- **Example #5 (added 2026-07-03):** Scotia Gold Amex offer rollover caught live 2026-07-03: page still displayed the 45K offer (window ended 2026-07-01) while the current offer is 50K (2026-07-02 → 2026-11-01, two-instalment structure). Proof case for offer-reverification cadence faster than the monthly loop.
- **Example #6 (added 2026-07-04, Rogers gate-3):** Rogers limited-time +1% cash back at eligible Rogers-POS/Clover small-business merchants (compare_cards fn14) — note-only, outside verified dataset; another time-bounded, merchant-scoped offer shape for the schema.
- **Example #7 (added 2026-07-05, Blue Rewards):** "Card Offers" targeted-offer layer — targeted, opt-in, time/quantity-limited (Blue Rewards Program Agreement, bluerewards.ca/en/terms.html, captured 2026-07-05). Offer-pile, note-only.

---

## Point valuation (CPP) verification

- **PC Optimum (verified 2026-07-02):** redemption floor 10,000 pts = $10 (0.1¢/pt), issuer-stated on the earning-rates legal page — input for the `point_programs` dataset.
- **Blue Rewards expiry [VERIFY] — CLOSED 2026-07-05:** 24-month Member-Account inactivity clause LIVE-VERIFIED (Program Agreement, bluerewards.ca/en/terms.html, captured 2026-07-05; Quebec notice/cure variant). Ledgered in post-06 + BLOG_OPERATIONS 2026-07-05. The gap lived in post-09 FLAG-4 / post-06 pre-draft inventory — no numbered item existed here; closure recorded so the trail resolves.

*(#6 Air Miles CPP and #7 More Rewards CPP closed and deleted 2026-07-31 — both resolved
2026-07-29: `airmiles-points` retired, `more-rewards-points` verified. Trail:
PIPELINE_AND_DECISIONS 2026-07-29 entry + `HANDOFF_cpp_valuation_lane_2026-07-29.md` in
CardCoachv2.)*

---

## Material issuer changes to watch

### #8 — Rogers rewards — cohort-differentiated rates
- **Status:** CLOSED 2026-07-04 — Stage-3 completed from the 2026-07-02 snapshots (supplied in `01_CORE/CardCoach/Reverify Script/snapshots/`)
- **Owner:** Mike (data)
- **Blocker:** None.
- **Next action:** GATE-3 RIDER APPLIED 2026-07-04 — **Aug-4 watch RESOLVED AHEAD OF SCHEDULE** (notification.pdf captured: amounts $16K/$26K/$61K + verbatim amended clause text in hand; WL explicitly uncapped). Remaining actions: (1) apply the pre-staged `2026-08-04__rogers__tiered-caps.sql` on/after Aug 4 (date-gated, APPLY_CHECKLIST §0); (2) August fetch confirms live pages match the notice (and whether the issuer fixes the WE amended-s.4 typo); (3) capture the per-card Rewards T&C docs referenced in notification.pdf (registry rows note this). Resolved at gate-3: fee table (WL $495/$95 AU; $0 all others incl. Fido — Disclosure 02/2026), WL conditional earn (1.5%/2% definitive) + no-cap + 0% FX + redemption-bonus participation, Red World full spec (net-new: fee $0, income $50K/$80K page-confirmed, 1%/2% USD/2% subscriber, Aug-4 $26K) + registry rows added, Fido application_status → closed (delta filed), Platinum closed noted. **WL income remains the sole Rogers [VERIFY].** **August-cycle prep DONE 2026-07-05:** registry + fetcher synced into `Reverify Script/` — the August Stage-2 run now fetches the current 98-card / 717-line world (20 Rogers rows incl. Red World; PC Silver + Blue Rewards URL fixes live); Jun-10 versions archived at `99_ARCHIVE/registry-versions/`; redundant snapshot copies removed (canonical `snapshots/` is the sole set).
- **Context:** **Decision settled 2026-06-10** (new-cardholder Feb 26, 2026 representation; Fido `scoring_status = load_only`) — applied 2026-07-04. Representation rule applied: earn_rates stores unconditional rates; subscriber uplift + verbatim qualifying-service definition (FAQ version, incl. Comwave) live in condition_text; account_bundle rows expired. NEW at 2026-07-02: both Red support pages pre-announce annual limits on subscriber-uplift rates effective 2026-08-04, amounts not stated.

### #9 — PC Financial post-EQB acquisition
- **Status:** in progress — watching for CMA publication
- **Owner:** Mike
- **Blocker:** New post-close Cardholder Agreement not yet published/captured (F2).
- **Next action:** Watch for the post-close CMA URL; capture it and the hosted 07/2026 Disclosure Summary URL, and pin down the standard card's own income threshold (F3 — [VERIFY: issuer-verified data needed]).
- **Context:** Close confirmed 2026-07-01. Post-close Disclosure Summary (07/2026, references EQ Bank) verified in hand. **Full four-tier reverification completed 2026-07-02** — see BLOG_OPERATIONS.md log and `01_CORE/data/deltas/2026-07-02/`. **F1 RESOLVED 2026-07-02: pc-silver-mastercard = standard card's new product page, no product or rate change; registry updated.** Remaining scope: F2 (post-close CMA URL — watching) and F3 (standard-card income threshold). The June 2025 CMA in the registry is confirmed pre-close/stale.

---

## Infrastructure / tooling

### #10 — Per-litre `rate_unit` enum extension
- **Status:** open, low priority — LANE CHANGE 2026-08-01: Mike's (Alex stepped back; "awaiting Alex" no longer a blocker state). Pump-case pressure is OFF: DATA-018 gives per-litre facts a canonical `offers` home (b0ff0005/6/7), so the enum now only matters for card-catalog `earn_rates` representation.
- **Owner:** Mike
- **Blocker:** None — priority only.
- **Next action:** Fold into a future earn_rates schema pass if catalog-side per-litre representation is ever wanted; otherwise leave — the offers home covers the till moment.
- **Context:** Canadian Tire (cents/litre) and PC Financial (points/litre) gas rewards are captured but parked. Unblocks when the enum gains `cents_per_litre` and `points_per_litre`.
- **Update 2026-07-02:** PCF gas rates now fully verified and waiting on the enum — World ≥30 pts/L; Insiders ≥50 pts/L (+20 bonus pts/L in months with ≥150L at Esso/Mobil → 70), loyalty-inclusive, price-dependent. Strengthens the case when Mike raises this with Alex.

### BMO Stage-2 fetch is manual until further notice
- **Note (2026-07-02):** bmo.com bot protection resets the fetcher's connections (confirmed 2026-07-02: script fails, browser loads fine). Monthly loop for BMO = manual browser capture of the 13 registry URLs, Stage-3 from captures.

### Capture methods
- **Note (2026-07-05):** bluerewards.ca blocks HTML save — capture via print-to-PDF (method of record for the 2026-07-05 Program Agreement capture).

### Open schema questions (for Alex — consolidates the 2026-07-02 delta audit notes)
- From the PCF deltas: no income-eligibility columns on `card_products`; no documented `source_url` column on `earn_rates`; no `Unsupported_Benefits` table in SCHEMA.md; Joe Fresh category mapping unresolved.
- Appended 2026-07-02 (late, BMO passes): `categories` enum may lack `alcohol` and `gas_ev` (needed by Blue Rewards accelerators); `point_programs` needs a `blue_rewards` entry; eclipse VI shows a fifth 5x tile "Takeout & food delivery" with no workbook row (cap/category [VERIFY: issuer-verified data needed]); eclipse VI eligibility offers an income OR $15,000-annual-spend alternative — first spend-based eligibility seen, representation open.
- Appended 2026-07-02 (close): partner cap differs by tier (standard $500 vs WE $1,000 combined per statement cycle) — scorer must key partner caps per card, not per program.

### Blue Rewards banking bundle (note-only)
- **Note (2026-07-02):** 500 bonus pts/month with WE card + Blue Rewards Chequing (landing page fn16); debit earn 1 pt/$2. Bundle/offer-stacking territory: captured-not-active.

---

## Revenue / trust (shares stakeholders with the pipeline, not blocked by it)

### #11 — Legal review of affiliate disclosure copy (EN + FR)
- **Status:** not started
- **Owner:** Mike
- **Blocker:** Needs external Canadian financial-services-literate legal counsel.
- **Next action:** Identify and engage counsel for bilingual disclosure review.
- **Context:** This is the highest-leverage unblocking decision in the broader revenue work — and it's been cold since well before this cleanup. Affiliate revenue is the primary V1 path and it can't activate without this. Listed here because it shares the pipeline's trust posture.

### #12 — External publication of the commission-blind integrity policy
- **Status:** not started
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** Decide whether to publish the commission-blind architecture externally (blog, about page, partner docs). Marketing/brand call, not a data call.
- **Context:** The architecture is defensible and trust-building. Parked here because it's tied to this pipeline's credibility.

---

## Live-site compliance (flagged, needs legal before copy changes)

### #13 — Resolve hold-back claims currently live on the site
- **Status:** not started
- **Owner:** Mike
- **Blocker:** Likely needs the same legal review as #11.
- **Next action:** Reconcile what's published against the "holding back until cleared" list — "we don't sell your data" wording, any fabricated testimonial, the draft legal note on the Terms page, and any FAQ marketing a deferred Pro tier as imminent.
- **Context:** Surfaced in a prior audit. Grouped here so it isn't lost; specifics should be confirmed against the live site before editing, and most changes wait on legal.

### #17 — Waitlist endpoint — CLOSED (waitlist retired 2026-07-27; entry removed 2026-09-02)
## Folder / data housekeeping

### #14 — Point Valuations xlsx disposition
- **Status:** not started — LANE CHANGE 2026-08-01: Mike decides directly (Alex stepped back; no answer to await).
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** Determine from the DB itself whether `CardCoach Point Valuations v1.3 2026-03-14.xlsx` (in `00_COWORK/_TRIAGE/`) feeds anything: `point_valuations` is tiered + evidence-governed since 0038/0034 and the 2026-07-31 master valuation index superseded workbook values — near-certainly archive. Verify no script references the file, then archive.
- **Context:** Surfaced in the 2026-07-02 folder reorg; the only remaining data file whose currency can't be determined from the folder itself.

### #15 — File-for-Alex pack confirmation
- **Status:** not started — LANE CHANGE 2026-08-01: Mike decides directly (Alex stepped back).
- **Owner:** Mike
- **Blocker:** None.
- **Next action:** The `…v1.4_ONEFILE_ALEXTESTED.pdf` acquisition pack (in `00_COWORK/_TRIAGE/File for Alex/`) is a Jan-2026 handoff artifact from a handoff era that's fully archived; archive the folder on Mike's own review.
- **Context:** Jan 2026 handoff artifacts; everything else from the handoff era is archived.

### #19 — Site git wiring / deploy-channel cutover *(renumbered from a duplicate #16, 2026-07-08 — Blue Rewards keeps #16; it's cited by post-09's ledger)*
- **Status:** git wiring DONE (2026-07-05) — pending Mike's G3 domain move.
- **Owner:** Mike (G3 next).
- **Blocker:** None on wiring. Retirement of the old channel waits on the domain move.
- **Next action:** Mike does G3 (point the domain at the `cardcoach-site` Worker serving static assets — push-to-`main` auto-deploy via Cloudflare Workers Builds; not classic Cloudflare Pages). The old direct-upload deploy channel retires **+7 days after the domain move** (grace window; keep it live until then as fallback).
- **2026-07-08 note:** canonical flipped (see PIPELINE_AND_DECISIONS 2026-07-08) — G3's target domain is now **cardcoach.ca**, with card.coach getting the reverse 301 (path + query preserved). Repo-side cutover is done in the worktree, uncommitted; the Cloudflare-side move is unchanged in scope, just pointed at the other domain.
- **Context:** `01_CORE/site/` is now a git working tree pushed to `github.com/mjross05-del/cardcoach-site` (first commit `b0bd3d6`, 56 deployables + `.gitignore`). Deploy is now push-to-`main` → Cloudflare auto-deploy; drag-and-drop retired. Convention logged in LAUNCH_TRACKER + BLOG_OPERATIONS.

### #18 — Email routing on cardcoach.ca (gates the domain-flip push)
- **Status:** **DONE — live-tested 2026-08-11** (Mike sent a real message to hello@cardcoach.ca; it arrived in the mike@card.coach inbox). Cloudflare Email Routing on cardcoach.ca is Enabled (MX route1/2/3.mx.cloudflare.net + SPF live in DNS), rule `hello@cardcoach.ca → mike@card.coach` Active, destination Verified. Was configured ~2026-07-16 (26 days before the check) — this entry had gone stale. Remaining nicety only: a send-as/reply-from for hello@ (optional, separate). hello@ is safe to publish everywhere (deletion page, Play listing contact).
- **Owner:** Mike.
- **Blocker:** None — ~10 min in the Cloudflare dashboard.
- **Next action:** Cloudflare Email Routing on cardcoach.ca: create hello@cardcoach.ca → forward to Mike's inbox (Cloudflare writes the MX records). **Must exist before the domain-flip commit is pushed** — otherwise the live site publishes a dead contact address. Keep hello@card.coach receiving as a legacy forward (it's on the currently-live site; the web 301 does not carry mail). Send-as for replies from the new address = separate, optional, later.
- **Context:** Follows the 2026-07-08 canonical-domain flip (PIPELINE_AND_DECISIONS 2026-07-08 ×2). All 58 site occurrences flipped in the worktree, uncommitted.

### #20 — Web app v1 (free recommendation surface)
*(Recovered 2026-07-16 from the 2026-07-13 session — the original append never landed on
disk.)*
- **Status:** approved 2026-07-13 (D1) — P0 done; P1 dispatch ready, pending keys
- **Owner:** Mike (design + build) · Alex (Annex A answers + URL/anon-key handoff only)
- **Blocker:** Supabase URL + anon key (P1); Annex A contract answers (P3)
- **Next action:** Send the Alex ping (item 0 = keys). On key receipt, run
  `P1_DISPATCH_web_data_spike.md` in Claude Code → output `01_CORE/webapp/DATA_CONTRACT.md`.
- **Context:** Proposal + phase plan: `PROPOSAL_web_app_v1_2026-07-13.md` (both files to be
  re-exported from the 2026-07-13 session or re-materialized — neither landed on disk).
  Decision logged in PIPELINE_AND_DECISIONS 2026-07-13. Web is read/invoke only — Supabase
  writes stay Alex's lane. CTA target (waitlist Worker) live and allowlisted; tag
  `source: "best-card"`.

### #21 — www.cardcoach.ca — CLOSED (301 to the apex verified 2026-09-02; entry removed)
## #23 — FX fee audit follow-ups (audit + engine fix landed 2026-08-02)

- **What landed 2026-08-02 (Cowork FX audit session):** full audit of `fx_fee_percent` across all 114 `card_products`. No unapplied corrections were found — all 9 prior verification corrections had landed, Scotiabank's 4 zero-FX cards match the issuer footnote's exclusion list exactly, and the USD-billed convention (Mike, 2026-07-29) is applied consistently across all 4 USD cards. **15 unsourced `2.50` values withdrawn to NULL** under rule 7 (12 Amex — 9 consumer + 3 business; 2 MBNA; 1 BMO AIR MILES World). Inside the Amex lineup the criterion is a stated clause, not product segment: Business Gold Rewards and Business Platinum keep 2.50 because their agreements say "a single conversion commission of 2.5%". Snapshot `card_products_snapshot_fx_20260802`; delta `deltas/2026-08-02__card_products__fx_fee_unsourced_to_null.sql`; `verify:cpp` green before and after. Distribution now 81 × 2.50 / 5 × 0.00 / **28 NULL**.
- **Owner:** Mike.
- **OPEN #23a — re-verification queue, 17 cards.** Not nulled because evidence exists and the failure was procedural, not evidentiary: **7 RBC** cards whose workbook rows cite a specific per-card InfoBox PDF (`avion_p.pdf`, `ba_platinum.pdf`, `gold_p.pdf`, `rewards_plus.pdf`, `classic2.pdf`, `westjet_world.pdf`, More Rewards co-app disclosure) that the 2026-07-29 run could not re-fetch because the InfoBox sits inside the application flow and the runbook forbids entering it; and **10 BMO** cards behind a confirmed domain-wide bot wall, covered by the BMO universal "Important information about BMO Credit Cards" PDF. Both need a pass allowed to read captured InfoBox/PDF artifacts. **This is staleness, not absence — do not null these.**
- **OPEN #23b — 11 cards never live-checked for FX.** The 7 CIBC + 3 Desjardins + RBC U.S. Dollar Visa Gold rows inserted by gated Mike-approved writes (2026-07-29 → 08-01). Provenance is in `verify.write_audit`, but they have never been through the verify pipeline, so they carry no `fact_checks` row and are invisible to the freshness view.
- **#23c — API-015: CLOSED 2026-08-02.** Engine is FX-aware (`netValueExactCents` = reward − FX cost; NULL never read as 0 or defaulted to 2.5) **and now wired end to end**. Mike ruled the currency comes from **explicit user selection**, not merchant-country inference. `spendCurrency` (optional ISO 4217) added to all **five** request schemas — the three shared contracts plus the private duplicates inlined in `recommend-card-v2` and `recommend-here-v2`, which don't import the contracts and would have silently stripped it — and threaded into all 4 `scoreWalletForPurchase` call sites including the stateless shadow re-score. Client: new `SpendCurrencyFooter` (8 curated currencies, ephemeral state like `tierOverride`, added to `buildRankingsRequestKey` or the fetch never re-triggers), en/fr keys. Deno 256/256, mobile `tsc` clean, INFRA-004 green. Spec: `mobile_app_codebase/docs/planning/specs/API-015_fx_aware_scoring.md`.
- **OPEN #23f — travel mode (future product feature, flagged by Mike 2026-08-02).** Detect or let the user declare a trip, then default the purchase currency for its duration so the picker becomes a correction rather than a per-purchase chore. Purely a client-side question of *what populates* `spendCurrency` — contract and scoring already support it. Pairs naturally with a pre-trip "cards to bring" view, since that view's ranking input is now the same one.
- **OPEN #23g — API-015 follow-ups.** (i) Mobile shows `fxFeePercent` but not `fxCostCents` or the fee-not-confirmed warning, so selecting USD changes the ranking without showing the cost line that explains it — highest-value next step. (ii) `record-transaction` takes no currency, so a recorded foreign purchase's `valueEarnedCents` is FX-free while the recommendation that preceded it was not; the two will disagree until wired. (iii) `packages/engine-contracts/dist/` is committed build output that goes stale — mobile types resolve through it while jest maps to `src`, so a src-only edit passes tests and breaks Metro. Rebuilt this session; standing trap.
- **NOTE — mobile test suites cannot run in the Cowork Linux sandbox.** All 57 jest suites fail to *start* (0 tests executed): `node_modules` is macOS-installed, so `@babel/runtime` is unreadable across the mount and vitest hits the same wall via `@rollup/rollup-linux-x64-gnu`. Not a code problem, and not fixable from the sandbox without rewriting your `node_modules` from a foreign platform — **run `pnpm test` on the laptop before merging API-015.** Deno suites run fine, which is why the new coverage went there.
- **OPEN #23d — web renders a null annual fee as `$0`.** `apps/web` `cards/[id]/page.tsx:145` and `CardDirectory.tsx:28` both do `formatCad(card.annualFeeCad ?? 0)`, presenting a paid card as free. The repo's own contract forbids this at `productTypes.ts:36`. Unrelated to FX, found alongside it. Small fix, real user-facing wrongness.
- **OPEN #23e — git hygiene, needs Mike.** The API-015 `scoring.ts` edits were made at 11:41 while a concurrent session committed `77a3056` at 11:43 on branch `feat/member-earn-display`; that commit swept them in under an unrelated message ("DATA-019/API-014/APP-018: membership-earn display + attribution notice"). Nothing is pushed, so it is cleanly fixable. Left alone deliberately rather than rewriting another session's history mid-flight. The remaining API-015 files (both `recommendCardV2.ts` copies, the test, the spec) are still uncommitted. This is rule 9(f) multi-session discipline biting in the file lane rather than the DB lane.

## #24 — Android launch lane (AND-001, dispatched 2026-08-07)

- **Status:** engineering lane landed 2026-08-07 (commit `6e17176` in CardCoachv2, + `43eb7eb` deletion page). Spec: `mobile_app_codebase/docs/planning/specs/AND-001_android_launch.md`. Runbook: `mobile_app_codebase/docs/app-store/RELEASE_android_1.x_HANDOFF.md`. Audit: `mobile_app_codebase/docs/dev_notes/AND-001_android_adaptation_audit_2026-08-07.md`.
- **What landed:** INFRA-005 Android build lane (EAS-managed keystore, dev APK green `e69a0c14`; **production AAB green: EAS `45bc2cfa`, 1.0.2 versionCode 4, commit `5f96fb3`** — third attempt, after fixing six corrupt CardVisual placeholder PNGs that AAPT2 rejects and the expo/expo#25188 locales lint tripwire, both release-only failures the dev APK masked); AUTH-006 Google sign-in code + tests (provider config pending, below); APP-019 adaptation audit + fixes (3 blockers: keypad-modal safe area, Android-13+ POST_NOTIFICATIONS never requested, back traps); QA-010 Android preflights + device matrix; REL-001 docs + `cardcoach.ca/delete-account` page.
- **#24a — RESOLVED 2026-08-07:** Play Console account exists — **organization account, mike@card.coach, identity verified** (Mike, confirmed in session). **No closed-testing gate** — the 12-tester × 14-day clock does not apply; production access comes with standard app review. This removes the schedule-critical path from AND-001 §Sequencing; remaining gates are engineering-free: provider config (#24b), site deploy + #18, forms, listing assets.
- **#24b — RESOLVED 2026-08-25 (it was never open):** Console audit found the Google side already fully configured: OAuth consent screen for `cardcoach-auth` **In production / External**; Supabase Auth → Providers → Google **enabled** with client ID `638080256275-j8qme1ga1b6aua8b2dggev8c34ka9igs.apps.googleusercontent.com` and secret populated; `cardcoach://auth/callback` present in the redirect allowlist. A live `GET /auth/v1/authorize?provider=google` completed the round trip and minted a session — which also proves the client's authorized redirect URI is right, since Google will not issue a code to an unregistered one. Three of the four build-84 testers already hold Google-provider accounts in `auth.users`. **This item was carried as the gating Android blocker for weeks and was simply stale**; it never blocked anything.
- **NEW #24e — RESOLVED 2026-08-25 (the real Android auth gap):** Android's *Apple* button could never work. `signInWithSocialProvider("apple")` uses native `signInWithIdToken` on iOS (validated against the bundle ID `com.cardcoach.mobile` in Supabase's Apple Client IDs list — correct), but falls through to web `signInWithOAuth` everywhere else, where Supabase sends that same bundle ID to Apple as a web `client_id`. Apple needs a **Services ID**, so the Android button was a guaranteed `invalid_client`. Fixed by hiding it: `AuthChoiceScreen.renderAppleButton()` returns `null` off iOS and Android now shows `screens.auth.choice.appleUnavailable` (copy rewritten to name a working route). Guarded by `src/screens/auth/__tests__/AuthChoiceScreen.test.tsx`. Restoring it needs a Services ID + secret JWT, not a config tweak — procedure in the handoff §Step 1b.
- **NEW #24f — OPEN, cosmetic:** Supabase *Site URL* is still `http://localhost:3000`. Not a tester blocker (email confirmation is off — every `auth.users` row has `confirmation_sent_at = null`; and `resetPasswordForEmail` passes an explicit `redirectTo`), but it is the `{{ .SiteURL }}` value in the email templates. Move it to `https://cardcoach.ca` with the site deploy (#18).
- **OPEN #24c — device pass:** Google+Apple+email round-trip, notifications (13+ prompt at Settings toggle, reminder from background), edge-to-edge matrix (Pixel / One UI 3-button / low-end; both locales+themes) — matrix table in the audit doc. Maestro-on-emulator needs a machine with Android tooling (this one has none).
- **#24d — CLOSED 2026-09-02** (build 85 reached Play internal testing 2026-08-27 through `eas submit`; the record below stands as the procedure). Original: **OPEN #24d — `eas submit` for Android (decision REVERSED 2026-08-24, Mike):** the 2026-08-17 call was to keep the org's secure-by-default `iam.managed.disableServiceAccountKeyCreation` and hand-upload AABs (that is how 1.0.3 shipped to internal on 2026-08-17). Mike reversed it 2026-08-24 — Android submits go through `eas submit`, same as iOS. Route taken (executed 2026-08-24): org policy **stays Enforced at the org node**, with a **project-level override on `cardcoach-auth` only** — effective status there is now **Not enforced**. (Chose the project override over the tag-condition scheme: one project to exempt, so tags add artifacts without adding scope control.) Org **card.coach** = `334345136383`; only the managed constraint was Active, the legacy `iam.disableServiceAccountKeyCreation` was already Inactive. Prereq discovered en route: *Organization Administrator* does **not** carry org-policy permissions — **Organization Policy Administrator** (`roles/orgpolicy.policyAdmin`) was granted to `mike@card.coach` and kept (Mike's call). Also done: **Google Play Android Developer API enabled** in `cardcoach-auth`; SA `cardcoach-eas-submit@...` confirmed Enabled with **no keys** (OAuth client `101810339480901084629`). Key goes to **EAS credentials**, not a local file — `serviceAccountKeyPath` removed from `apps/mobile/eas.json` 2026-08-24 so submits work from any machine/CI exactly as the iOS ASC key already does. Play Console no longer requires a linked GCP project; the SA is authorized by inviting `cardcoach-eas-submit@cardcoach-auth.iam.gserviceaccount.com` under *Users and permissions* with five release permissions scoped to CardCoach, and needs **zero Cloud IAM roles**. Full procedure: `mobile_app_codebase/docs/app-store/RELEASE_android_1.x_HANDOFF.md` **Step 2** (rewritten 2026-08-24). **Console side COMPLETE 2026-08-24.** Key minted (ID `cd256d1030a34947e5e9277c935724d65ea5d55c`, Active, no expiry) — downloaded as `cardcoach-auth-cd256d1030a3.json`, **sitting in `~/Downloads` and needing to be moved to `~/secrets/` (chmod 600)**. Play Console: SA listed under Users and permissions, status **Active/Never expires**, **8 app permissions on CardCoach only** — no account-level, no Admin, no financial data; production-release included so `track` can flip later. Play developer account ID `7249847285144860060`. Key uploaded to **EAS credentials** and **PIPELINE PROVEN 2026-08-24**: `eas submit -p android --latest --profile production` authenticated and was rejected by Google only on *"You've already submitted this version"* — `--latest` resolved to 1.0.3/versionCode 5, the 08-17 manual upload. Auth + Play permissions + eas.json all confirmed. Remaining: nothing configural — the next Android build submits for real, preferably `eas build -p android --profile production --auto-submit` (one command, build→internal track). Trap to avoid: the Google error tells you to bump `expo.android.versionCode` in app.json — **do not**; `appVersionSource: remote` + `autoIncrement` assigns it server-side (next = 6), and hand-setting it breaks AND-001 invariant #8. Also still un-exercised: the `changesNotSentForReview` failure mode, which the versionCode rejection short-circuited. Automation note for future sessions: the Cloud Console service-account *details* page and Play Console both need **~30 s** to bootstrap and look dead before then — earlier attempts failed purely on impatience, not on a real block. Watch for *"Changes cannot be sent for review automatically"* on first submit → `changesNotSentForReview: true`, then back to `false`.
- **Note:** deletion page **LIVE 2026-08-07** (`cardcoach.ca/delete-account`, cardcoach-site `519fe63`, Mike-ordered deploy). **#18 verified DONE 2026-08-11** — hello@cardcoach.ca receives (→ mike@card.coach), so nothing email-side gates Play submission anymore; use hello@cardcoach.ca as the listing contact.

- **BUILD 84 — 2026-08-25.** The Android lane is no longer behind: `feat/pro-tier-and-statement-import` now carries marketing **1.3.0** with build number **84 pinned on BOTH platforms**, built from one commit (invariant #8, first time since 1.0.3). Spec + run sheet: `SPEC_build_84_2026-08-25.md`, `RUNBOOK_build_84_2026-08-25.md`.
  - **The unpushed `e63c9951` lineage is resolved, and not the way RELEASE_1.2.0 predicted.** The commit is gone from every reflog, object store and bundle in `~/dev` — but the **five-patch series it was built from was in `_to_delete/cowork-android-lane/android-patches.tgz` the whole time**. All five are reconciled onto the branch (`a46e35f`, `fc5fd65`, `ad3dab1`, `742cc55`, `b812781`); `_to_delete/cowork-android-lane/MERGED_2026-08-25.md` maps each patch to its commit so nobody re-applies them. iOS 83 / Android vc6 are superseded, not chased.
  - **Three Android defects that were shipping, now fixed:** every receipt capture on **Android 7–9** failed with `ERR_USER_REJECTED_PERMISSIONS` (`expo-image-picker` needs `WRITE_EXTERNAL_STORAGE` beside `CAMERA` on API ≤ 28, and a blocked permission is auto-denied) → `plugins/withCameraManifest.js`; the **French widget picker was English** (`@expo/config-plugins` chains same-type mods last-registered-FIRST, so our strings plugin ran *before* the library it depends on); and the **widget could never draw at all** — `registerWidgetTaskHandler` was called nowhere, and `requestWidgetUpdate` was called with no `renderWidget`, so every snapshot write threw instead of redrawing.
  - **iOS widget likewise never worked**, for an unrelated reason: the `ExtensionStorage` pod needs iOS 16.4 and the app targeted 15.5, so autolinking skipped it silently. Floor raised (drops iOS 15.x — release-note item). **Gate before submitting: `node scripts/verify_widget_native.mjs <ios-build-id>`, which checks the finished IPA. If it fails, do not submit.**
  - **Testers are comped**: `tester_allowlist` + an `auth.users` trigger, 5 accounts × 5 keys, expiring 2026-11-23 (ENT-002). The 2026-08-21 manual grant had vanished because it went to a user id that no longer exists and `user_id` is ON DELETE CASCADE — an allowlist keyed on EMAIL survives a delete-and-recreate, which a hand-typed INSERT cannot.
  - `billing_paywall` and `statement_import_write` are **false** (delta `2026-08-25__runtime_flags__build84_prep.sql`). Build 84 needs no RevenueCat project, no store products and no Apple account transfer — comps are a database grant.
  - **`.github/workflows/ci.yml:30` pins `node-version: 22`, floating, and `verify:sheet-layout` has been CRASHING rather than verifying on Node 22.23.x.** CI has been red on every push and nobody read it. The crash is fixed on the branch; **pin `22.16.0` to match the eas.json build image.**
  - #24c below is still open; #24d closed 2026-09-02 (build 85 shipped via `eas submit`). (#24b was closed 2026-08-25 — it had already been done; see above.)

## 2026-08-11 — Pre-launch sweep fixes (run entry)

- Sweep 2026-08-10 findings executed 2026-08-11 (approved dispatch), zero DB writes.
- Site: `.assetsignore` excludes repo internals — `/.git/*`, `/.gitignore`, `/wrangler.jsonc` now 404 (cardcoach-site `e18bd17`); Terms template disclaimer removed from `legal.html` (cardcoach-site `6f3a6d6`). Both deployed via Workers Builds, live-verified.
- Delta governance (CardCoachv2): APPLY_CHECKLIST top stop-note `99b259b` — the 18 card-lane delta files are superseded by live DB state, do not execute; DELTAS_INDEX card-lane statuses reconciled `4c8c8f6` (17 `superseded-live (2026-08-10 sweep)`, Fido closure `not-applied — live state NULL`).
- April-2026 governance snapshots bannered SUPERSEDED (CardCoachv2 `c2744b7` / `e2dd084` / `696b0f5` / `7c95eab` / `9045523`); bodies unedited.
- Alex handoff filed: `ALEX_HANDOFF_2026-08-11.md` (`2308bb4`; renamed `DB_ENGINE_WORKLIST_2026-08-11.md`, worklist run) — dormant-delta drift, Fido NULL, stacking-flag-vs-engine (N4), advisor items, earn-rate pairs, snapshot housekeeping. Engine docs stay unedited until Alex answers N4.
- Stray workers `divine-brook-e823` + `broad-leaf-7294`: workers.dev subdomains disabled, API-confirmed (archive-and-disable; assets-only workers — no script to archive; reversible via re-enable).
- www.card.coach dead-end: no change made — the apex 301 is a card.coach zone Single Redirect rule (catch-all expression, not worker-based), so the fix is dashboard-scoped: add a proxied `www` DNS record on the card.coach zone; the existing rule then covers www. Registrar-side getcardcoach.ca repoint stays on Mike's manual list.
## 2026-08-11 — DB/engine worklist run (run entry)

- Worklist executed per Mike's dispatch (no Alex lane; items are ours). File: `DB_ENGINE_WORKLIST_2026-08-11.md` (renamed from ALEX_HANDOFF this run) — per-item ledger appended there. verify.runs `a261a243-d361-4f53-82d3-9b66f9318ed2`; zero card-fact writes; write freeze formally lifted per dispatch standing-state note.
- Item 1 provenance: card-lane end-states live-confirmed; produced out-of-band from the repo catalog canon (seed.sql) ~2026-07-27–29 — no migrations, no write_audit rows. Full note in DELTAS_INDEX.
- Item 2 Fido: W1 blocked, no write — the card row is absent from live card_products entirely (not a NULL status; absent from the 07-31/08-02 snapshots, no orphans). Decision D-D: insert-as-closed from the delta files, or accept absence.
- Item 3 stacking: engine is flag-gated and wired via the shared scorer; authed v2 endpoints load offers (includeOffers defaults true); stateless-v1 opts out (includeOffers false, no loyalty inputs) so its appliedOffers is [] by design — the sweep probe could never show stacking. Doc-correction gates not met → HOW_THE_ENGINE_WORKS / PIPELINE_AND_DECISIONS untouched; decision D-A: flag posture + where to re-gate the doc fix (authed-path probe).
- Item 4a: trigger-function EXECUTE revoked (migration `harden_trigger_function_execute`); advisor lints cleared; anon RPC probes 404; engine probe unchanged. write_audit `728310dc`.
- Item 4b: 9 definer views reviewed — accepted by design 2026-08-11 (catalog-only read surface; +2 since sweep via the 2026-08-11 verify_apply_loop migrations, concurrent session). Item 4c: leaked-password protection = D-B, dashboard toggle, Mike.
- Item 5 earn-rate groups: no defect — engine picks the single best priced row (never sums); all 15 groups condition-differentiated; NB pairs additionally unreachable (all 3 NB cards load_only). Observation: 'other'-type condition variants can win selection when their condition cannot hold (Amex 3x portal row in-store; MBNA Prime rows) — overstatement class, with Mike; nothing expired.
- Item 6: `point_valuations_snapshot_20260729` attributed via table COMMENT (ad-hoc 2026-07-29 prod copy; secured by 20260729205344); retained, drop stays Mike-only. write_audit `9487dc68`.
- **Decisions resolved (Mike, 2026-08-11):** D-A — flag stays ON; authed-path verification passed (deployed v2 bundles carry the flag-gated path, no opt-out; live traffic confirmed); engine docs corrected, dated (HOW_THE_ENGINE_WORKS ×5, PIPELINE_AND_DECISIONS decision line). D-D — accept absence; both Fido delta files marked not-applicable in DELTAS_INDEX. D-B — approved; dashboard-only toggle with Mike.
- **§2 closure (stacking dispatch, 2026-08-11):** production offer application proven by live probe — recommend-card-v2 applied `b0ff0008` at exactly 1.2 percent (120¢ on $100; final 270 = 100 base + 50 category + 120 offer) for a linked probe user at a Canadian Tire place; pre-link the same offer surfaced as a linkage nudge at 120¢. TestFlight last-mile closed. Probe user retained + marked (probe-20260811@cardcoach.ca). Engine docs' evidence clauses upgraded to the transcript: STACKING_CLOSURE_REPORT_2026-08-11.md.
## 2026-08-11 — Verify batch: unlogged active cards (run 98d0bc59)

- Coverage 33 → 26 unlogged actives (live recount; the sweep's 24 was stale). Logged 7: Desjardins Bonus + Flexi, NB Syncro, RBC Rewards+ / Signature / Visa Preferred (closed-legacy baselines via lineup evidence), TD Business Select Rate. 23 facts: 22 confirmed, 1 changed-gated, 0 unverified, 0 auto-writes.
- Gated pending ×1: Desjardins Bonus $3,600 combined dining+pre-auth annual cap missing from card_caps (proposed SQL in fact_check 59fc3176; approve via RUNBOOK_gated_apply).
- BMO ×11 → chrome-lane queue (walled; list in VERIFY_REPORT_2026-08-11.md). Dedupe-deferred ×15: CIBC 7 + Scotiabank 7 + Amex Business Edge 1 (runs f63bfbd1 / 9a4de2ba <20h; next rotation slots).
- 6b classifications: Flexi, Syncro, TD BSR = base_earn 0 by design, permanently load_only, never re-fetch earn structure.
- 6c: Desjardins 8/8 clean. NB lineup carries mycredit/MC1/Edition/Allure/ECHO/Escapade/Ovation Gold/PB1859 beyond the DB's 4 — deliberate-scope question flagged for Mike, not proposed (precedent: 08-08 run proposed only Syncro).
- Riders: R1 SPEC stacking line corrected (CardCoachv2, local); R2 FK observation appended to worklist ledger.

## 2026-08-12 — Engine window semantics: push + edge deploy (run entry)

Executed on Mike's machine from `dispatches/` prompt `6e60c32` (the Cowork engine session could not reach GitHub or the deploy channel). Local clock 2026-08-12 evening; **DB/UTC had already rolled to 2026-08-13**, which is why the RBC-std rows carry `valid_from = 2026-08-13` and the interim rows `valid_to = 2026-08-12` — expire-then-insert is correct, the rows are live now, not pre-dated.

**Git.** Stale sandbox artifacts swept from both `.git` dirs (renamed `*.stale.N` locks + orphaned `tmp_obj_*`; no bare `*.lock` survived, no git process was running) then `git gc`. Both pushes were clean fast-forwards, no rebase, no force.
- `cardcoach-docs` `be235a3..6e60c32` — 5 commits, one more than the prompt listed: `b070acf` (merchant-graph DML is audit-class) had also never been pushed.
- `CardCoachv2` `cbf25b7..f61ca35` — 15 commits, 12 more than the prompt listed: the whole 08-10/08-11 docs+site backlog had been stranded locally by the sandbox's lack of GitHub reach. 59 files, +2965/−412.

**Deploy.** `recommend-card-v2` 19→**20**, `recommend-here-v2` 19→**20**, `recommend-cards-stateless-v1` 7→**8**. All three ACTIVE, `verify_jwt` still **false** (no `--no-verify-jwt` needed), and all three `ezbr_sha256` bundle digests changed — new code demonstrably shipped. `cap-progress-v1` left at v11 as instructed.

**Probes (stateless-v1, all HTTP 200; effectiveValueCents pre → post).** Every scoreable card's top-line value is **unchanged**, which is the designed outcome, not a failed deploy — see the discriminator note below.

| scenario | pre | post |
|---|---|---|
| RBC std · grocery $100 | 200¢ (2.0/$) | 200¢ (2.0/$) |
| RBC std · grocery $4,000 | 8000¢ (2.0/$) | 8000¢ (2.0/$) |
| RBC std · grocery $10,000 | 16000¢ (1.6/$) | 16000¢ (1.6/$) |
| RBC std · dining $100 *(control)* | 100¢ (1.0/$) | 100¢ (1.0/$) |
| RBC std · dining $10,000 | 10000¢ | 10000¢ |
| RBC std · no context $100 | 100¢ | 100¢ |
| RBC WE · grocery $4,000 | 6000¢ (1.5/$) | 6000¢ (1.5/$) |
| RBC WE · dining $100 | 150¢ (1.5/$) | 150¢ (1.5/$) |
| NBC WE · grocery $4,000 | unrankable `load_only` | unrankable `load_only` |
| rank pair · grocery $4,000 | std #1 8000¢, WE #2 6000¢ | unchanged ordering |

Six of ten responses are byte-identical modulo `requestId`/`computedAt`. The control held exactly.

**ANOMALY 1 — the prompt's discriminator does not exist.** NBC WE grocery $4,000 cannot be priced by any scoring endpoint: **both NBC cards are `scoring_status = 'load_only'`** (`ca_national_bank_rewards_mastercard_world_elite_mastercard`, `..._platinum_mastercard`), so stateless-v1 returns them in `unrankable`, and the authed v2 paths never rank them either. Consequence to be explicit about: **the NBC tier-window remodel is live in the data but dormant in production pricing** — it will start paying only if/when those cards become scoreable. This matches the 2026-08-11 worklist finding that NB cards are load_only; it was simply not carried into the deploy prompt. Nothing to fix here, but the ADDENDUM-2 claim that all four remodelled cards now price their true structure in production is **true only for the two RBC cards**.

**ANOMALY 2 (benign, and the actual proof) — the change is in attribution, not in totals.** With NBC unavailable, the discriminator is `category_excludes` on RBC std grocery, visible in `breakdown`:

| RBC std grocery | pre | post |
|---|---|---|
| $4,000 | baseEarn 1.0/$ = 4000¢ + categoryBonus 4000¢ | baseEarn **0** = **0¢** + categoryBonus **8000¢** |
| $10,000 | baseEarn 1.0/$ = 10000¢ + categoryBonus 6000¢, capAdj −4000¢ | baseEarn **0** = **0¢** + categoryBonus **16000¢**, capAdj **−8000¢** |

The base slot now pays **nothing** on grocery (its rows carry `category_excludes = {grocery}`) and the grocery slot carries the card's whole 2%→1% schedule itself — exactly the §3 target modelling. Totals are identical because A2 keeps the nominal primary at the highest total, so the category bonus absorbs what base used to contribute. This is the new engine running.

Why nothing else moved: on snapshot-less surfaces (stateless-v1 always sends no snapshots) generalized D2 sets the assumed prior to the *start of the highest-rate windowed row's window* — $6,000 for RBC std's base 1% row (rising pair → terminal rate) and $0 for its grocery 2% row (falling pair → headline rate) — which reproduces the old engine's numbers on both slots. RBC WE carries no floors or buckets at all. So every scoreable card converges by construction, and no snapshot-less probe can move a total. The floors bite only on authed, snapshot-bearing paths.

**Other verification.** `health` 200 `{"status":"healthy"}`, database check pass. Engine suite **143/143**. Goldens `verify:qa-005` **8/8**. Edge logs for all three functions across the full 24h window: `info`/`log` only — **no error or warn class** before or after. Caveat: `recommend-card-v2` and `recommend-here-v2` have had **zero invocations since the deploy** (authenticated endpoints, no live traffic in the window), so they are shipped and healthy-by-artifact but not yet exercised by real traffic.

**ANOMALY 3 — CLI/keychain, for the next session.** `npx supabase` installed a fresh **2.114.0** at a new npx cache path; the macOS Keychain item "Supabase CLI" (created 2026-07-29) does not grant that binary, so `npx supabase …` hangs indefinitely on an invisible authorization prompt with stdin closed. Fix used: invoke the already-authorized **2.110.0** binary directly at `~/.npm/_npx/7960735060baecd3/node_modules/@supabase/cli-darwin-x64/bin/supabase` — same CLI, deploys identically. Alternative is to export `SUPABASE_ACCESS_TOKEN`. Do not assume `npx supabase` works unattended on this machine.

**Not done / untouched:** no source files modified, no data SQL run (reads only, to diagnose the discriminator), no `db push`, `public.*` and `verify.*` untouched, apply queue still empty.
---

## #27 — MCC gating data debt: 76 mcc_defined rows with no MCC list (found 2026-08-16, resized 2026-08-26)

- **What:** `earnRowPrices` admits an `mcc_defined` row only when its `mcc_includes` intersects the category assumption; a null/empty list fails closed and the row NEVER prices — the card silently earns base everywhere. Surfaced by the iOS/Android "different results" investigation (CIBC Aeroplan Visa at $1.33/$100 base-only at RCSS; its 1 pt/$ grocery row carries no MCCs). **Was 52 active rows / 12 cards on 2026-08-16; 76 rows / 17 cards as of 2026-08-26, all live-suppressed on active scoreable cards.** **Current shape (read live 2026-08-26): 64 fillable, 12 blocked.** The 12 sit in the four still-unmapped categories — `transit_parking` 3, `e_games` 3, `ev_charging` 3, `hotels_motels` 3, all CIBC — and need `mcc_category_mappings` rows first. `recurring_bills` has since been mapped and is no longer among them. The 2026-08-16 worklist (`DB_MCC_SWEEP_WORKLIST_2026-08-16.md`, 42 fillable / 10 blocked) is superseded by the regenerated pass-3 deltas; keep it for its per-row source-clause reasoning only.
- **Adjacent:** PC Financial Mastercard (standard) grocery row is `merchant_list_only` at 10 pts/$ == its base — a no-op as modeled; re-verify the real Loblaw-banner rate. Also: Android carousel showed 2 cards for a 3-card wallet (2026-08-16 09:04, mike@card.coach) — recheck on the current wallet; if it repeats, ticket as client/API drop.
- **Client side (landed 2026-08-16):** the app now renders `conditionalNotApplied` ("bonus not counted — couldn't verify it applies at this store") in the Why This Card receipt, so suppression is visible instead of reading as "no bonus". recommend-here-v2 does NOT emit the field yet — porting the disclosure to it is the natural Slice 2.
- **Owner:** verify/apply loop (rule 9 discipline). **Both policy calls are made** — backfill-not-fail-open (2026-08-16) and enumerate-brand-blocks (2026-08-26). Nothing here is waiting on Mike; it is waiting on source-clause checks.
- **Brand-code blocks: SETTLED 2026-08-26 — enumerate the range.** Mike ruled that a brand block
  named as a range in issuer terms is written out in full, not represented by a head code and not
  given a new schema type. Applied the same day: both Tangerine Money-Back `hotels_motels` rows
  `{7011}` → `{3500..3828, 7011}` (330 codes) per program terms §7, through the gated path
  (`apply_queue` 867c3106, `origin='convention_ruling'`, write_audit 37ec79ef). Changes no pricing
  today — `hotels_motels` has zero `mcc_category_mappings` rows, so there is nothing to intersect.
  **Consequence still open:** this is the first enumerated brand block, and it makes the existing
  `travel` mapping inconsistent — that represents the 3000-3299 airline block by its head code
  (MCC 3000 + 3009 specifically). Bringing airlines into line means ~300 more integers. Not done
  here, deliberately not left implicit. Reasoning in `PIPELINE_AND_DECISIONS.md` 2026-08-26.
- **Engine fail-open is NOT open.** It was ruled out 2026-08-16 (backfill via verify lane;
  fail-closed on empty `mcc_includes` retained) and re-affirmed 2026-08-26. Do not re-propose it.

## #32 — The airline brand block now contradicts the enumerate ruling (2026-08-26)

- **Status:** OPEN, created by a ruling rather than found in the wild.
- **What:** Mike ruled 2026-08-26 that MCC brand blocks are **enumerated**, and both Tangerine
  Money-Back `hotels_motels` rows were written out to `{3500..3828, 7011}`. But
  `mcc_category_mappings` still represents `travel` with **MCC 3000 "Airlines"** — the head of the
  3000-3299 airline brand block — plus **3009 "Air Canada"** specifically. Five rows standing in
  for three hundred. The schema now holds both conventions at once.
- **Why it matters:** a merchant on an airline brand code other than 3000/3009 does not match
  `travel`, so travel bonuses under-price on exactly the transactions people notice. Enumerating
  3000-3299 is ~300 rows in `mcc_category_mappings`, and per the 2026-08-14 decision, mapping
  changes are **ranking-affecting in both directions** — this is gated-delta work with a pre-flip
  recon, not a bulk insert.
- **Next action:** decide scope (full 3000-3299, or only the carriers that appear in Canadian
  acquiring) and run it through the verify/apply loop.

## #33 — `doc_locations` drift signal is ruled but not built (2026-08-26)

- **Status:** OPEN — implementation debt created the day the decision was made.
- **What:** Mike ruled 2026-08-26 that every `verify.issuer_notes.doc_locations` entry carries a
  **sha256** and an **issuer revision date** beside the URL. `RUNBOOK_verify_batch.md` v1.5 §3.2
  and §9.1 now instruct runs to write and check them. **Nothing has migrated the existing entries** —
  all 37 URLs across the 7 issuers that record any still hold a bare URL, so the first run to cite
  one has nothing to compare against and must populate as it goes.
- **The trap this creates, stated in the RUNBOOK and repeated here:** a stale sha256 is worse than
  no sha256. A run that cites an entry either refreshes both fields or marks them unverified for
  that run. Watch the first two or three runs for entries that acquire a hash and then never
  change it.
- **Next action:** either a one-off population pass (fetch each of the 37, record hash + stated
  revision date) or let the weekly rotation fill them in as it cites them. The one-off is cleaner —
  it gives every entry a baseline on the same day.

## #34 — The real FX gap: DIAGNOSED 2026-08-26 — zero cards are robots-blocked

- **Status:** the diagnosis the 2026-08-26 robots ruling needed before anyone could size it.
  **Done this session, not filed.** What remains is one issuer's re-verification, already tracked
  as #23a.
- **The answer: the robots ruling closes Tangerine and unblocks Neo, and diagnoses to ZERO
  additional cards.** 40 of 148 active cards still have `fx_fee_percent` NULL (Amex 13, TD 12,
  MBNA 6, RBC 6, Scotia 2, BMO 1). Of those 40: **none is robots-blocked. None was never
  attempted** — every one has a `fact_checks` row.
- **What they actually are:**
  - **Deliberate rule-7 withdrawals — the largest group, and they are CORRECT as NULL.** Two
    sweeps pulled unsourced `2.50` values: **2026-08-02** (15 cards — 12 Amex, 2 MBNA, 1 BMO
    AIR MILES World, per #23) and a second on **2026-08-16 17:51 UTC** (Mike-approved, audited in
    `verify.write_audit`) covering TD, Amex business, RBC More Rewards, Scotia GM and Tangerine WE.
    The pattern in both: the cited clause describes the *conversion mechanism* ("we will convert it
    to Canadian currency at an exchange rate determined by the payment network") and **never states
    a percentage**. The 2.50 had been pattern-matched, not read — the same correlated dual-pass
    misread that produced the 2026-07-27 Amex error corrected on 07-28. These stay NULL until an
    issuer document actually states a rate.
  - **RBC 6 — staleness, not absence (#23a).** Evidence exists: per-card InfoBox PDFs
    (`avion_p.pdf`, `gold_p.pdf`, `rewards_plus.pdf`, …) that sit **inside the application flow**.
    The blocker is the standing no-application-flow rule, **not robots** — so the 2026-08-26 ruling
    does not touch them. This is the Friday chrome lane's existing "in-application FX boxes" job.
    **Do not null these.**
  - **Scotia 2 (GM cards)** — pass disagreement plus no reachable public product page (several
    probed paths 404). A lineup/URL problem a normal run can fix, not an FX-publication problem.
  - **BMO 1** — application-closed legacy card behind BMO's domain-wide bot wall. Chrome lane.
  - **2 USD-billed cards** (TD U.S. Dollar Visa, RBC U.S. Dollar Visa Gold) are NULL by the
    USD-billed convention (Mike, 2026-07-29), not by failure.
- **Consequence for how the ruling is described:** it must never be quoted as a 41-card fix. It
  fixed one card and opened one issuer's document corpus. Say that.
- **The one thing worth acting on:** **10 of TD's 12 NULLs are `scoreable` and
  `application_status='open'`** — live cards whose FX cost the engine cannot price. That is the
  largest single block of live FX blindness in the catalogue and it is not blocked on anything
  except a document that states a rate.

## #35 — Document-currency follow-ups carried from the 2026-08-25 sweep

- **Status:** OPEN, no ruling needed — these are next-run instructions, recorded so they are not lost.
- **RBC `documentation_hub` is DEAD.** `/credit-cards/documentation.html` 404s and so does
  `/credit-cards/agreements-and-documents.html`. The `/credit-cards/documentation/pdf/` prefix
  beneath it still serves files (`suncor-terms-personal.pdf` confirmed 200), so only the index page
  is gone. **The next RBC run navigates fresh from `https://www.rbcroyalbank.com/credit-cards/`
  (200) and replaces the value. Do not guess a replacement URL** — that is the exact habit that
  produced the Tangerine drift.
- **NationalBank `fx_information_box_pdf` may be the wrong language.** Recorded as the EN FX
  information box, but the PDF's source file is `1689_PPO_form_27972_FR_v2.indd` — an **FR**
  artifact. Its `doc_locations` note also says form 27972-012 dated 2026-02-10 while the file's
  ModDate is 2026-03-13. Worth one run's attention; may be nothing.
- **Three aged documents, currency unconfirmed.** Canadian Tire `we_summary_2022_linked_live`
  (created 2022-06-27), NationalBank `rewards_plan_rules` (2025-02-18), RBC `petro_terms_personal`
  (2025-01-08). **Old is not automatically wrong** — check each against its issuer's index, do not
  replace on age alone.
- **Neo's whole legal corpus is now checkable** (2026-08-26 robots ruling). Its cardholder agreement
  and rewards policy are dated June 2025 against a 2026-06-01 disclosure, so newer revisions may
  exist. Next Neo run confirms each against Neo's own index per §3.2 — not by filename pattern.

## #36 — The chrome lane's standing queue is empty by construction (found 2026-08-26)

- **Status:** OPEN, a one-line defect with a real cost. Found while sizing the alternative to the
  robots ruling; survives that ruling because #34 shows RBC's 6 FX cards need this lane.
- **What:** `RUNBOOK_chrome_lane.md` §Scope selects
  `SELECT issuer FROM verify.issuer_notes WHERE wall_status = 'walled'`. **No issuer has
  `wall_status = 'walled'` today.** BMO is `open`, Neo and PCFinancial are `js_shell`. The three
  issuers that actually want this lane carry `chrome_assisted` in **`preferred_channels`**, not in
  `wall_status`. So the lane's standing queue returns zero rows and it runs only on ad-hoc RUN SYNC
  handoffs.
- **Consistent with the evidence:** 4 `chrome_lane` runs in `verify.runs`, most recent
  **2026-08-16** — against a charter that says weekly, Fri 5 p.m.
- **Why it matters now:** the lane's published charter already names its four jobs — BMO coverage,
  RBC tier thresholds, **in-application FX boxes**, Blue Rewards/AIR MILES watch. #34 shows RBC's
  6 NULL FX cards and BMO's 1 are exactly job three, and #23a's 17-card re-verification queue is
  jobs one and two. The work is queued in the docs and invisible to the selector.
- **Next action:** widen the scope query to
  `wall_status = 'walled' OR 'chrome_assisted' = ANY(preferred_channels)`, or set `wall_status`
  honestly on BMO/Neo/PCFinancial — one or the other, not both. Then confirm the Friday slot is
  actually scheduled rather than assumed.

*Add new open items above this line. Close = delete. Settled = move to the decisions log.*

---

## #22 — Loyalty stacking Phase 1: activation gates (landed dark 2026-08-01)

- **Status (updated 2026-08-01 evening):** branch `feat/loyalty-offers-phase1` at `cbf2739`. **Gate 1 CLOSED** — WS-1 executed same-day; all 7 editorial offers now issuer_confirmed 0.95–0.97 (see `dispatches/REPORT_WS1_results_2026-08-01.md`; RBC↔Triangle corrected to CT-retail-only, Moi CPP 0.8¢/pt captured, excluded-co-brand scope added). **Gate 2 code-complete** — APP-017 landed via concurrent runtime (`cbf2739`), needs local suite re-run + a shipped build. Mike's first `db reset` failure (FK ordering, migrations-before-seed-data) fixed in `89facba`. Flag still **false**; rule 5 still holds.
- **Owner:** Mike — all of it (LANE CHANGE 2026-08-01: Alex stepped back for the time being; build + release are Mike's, in progress).
- **Gate 3 — founder flag flip** + rule 5 update, after the APP-017 TestFlight build is on the circle's devices. Mike's ruling 2026-08-01: audience is TestFlight-only, his circle — adoption is a non-issue; flip when the circle has updated. The adoption bar becomes real at GA (and the COMPLIANCE pack's counsel gate applies before QC GA).
- **Before merge:** re-run `pnpm supabase:db-reset` (now expected green) + `pnpm verify:loyalty-p1` + `pnpm test` + `pnpm test:supabase`; then full `pnpm verify`.
- **WS-5 freshness: WIRED 2026-08-01** into the daily scheduled verify batches (wed-rbc, fri-cibc, sun-ct-pcf, mon-scotiabank + chrome lane) — parking-lane only, OFFERS_PROMOTION OFF preserved, sections no-op until the branch merges; fuel-price check first Wednesday monthly; see `dispatches/DISPATCH_WS5_offer_freshness_ops_2026-08-01.md` (now the record of what was wired). Journie 30-vs-60-day conflict + Sunoco/2030 sunset + Scene+/Shell + Blue Rewards watches all live in those prompts.
- **QA-009: DONE 2026-08-01** — 30-scenario golden pack built + independently verified on branch `feat/qa-009-golden-pack` (commit `12f47fe`; suite 199/199; merge via the merge dispatch, step 6).
- **WS-7: DRAFTED 2026-08-01** — `COMPLIANCE_loyalty_stacking_pack_2026-08-01.md` (string review, trademark attribution EN/FR, Quebec/Law 25 checklist). NEEDS COUNSEL SIGN-OFF before flag flip; one APP-017 follow-up: in-app attribution notice screen.
- **Merge/push/cloud-apply prompt ready:** `dispatches/DISPATCH_MERGE_AND_CLOUD_APPLY_2026-08-01.md` — paste into Claude Code on the laptop.

## #28 — Neo Financial onboarding: carried [VERIFY] items (landed 2026-08-16)

Neo Financial is live as the 16th issuer — 9 `card_products`, 26 `earn_rates`, 2
`card_exclusions`, `verify.issuer_notes` seeded, added to the **Sunday** batch rotation.
Seven of nine score today. Settled reasoning is in `PIPELINE_AND_DECISIONS.md` (2026-08-16);
what remains open is here.

**MCC schedule — READ AND APPLIED 2026-08-16.** Both Neo disclosures and the 4-page MCC
schedule are now on disk. Neo publishes per-plan lists: Gas 5541/5542/5552, Grocery 5411,
Dine 5811-5814, Recurring 4812/4814/4899/4900/5815-5818/5968/6300/7997, Shop ~90 retail codes.
Delta `2026-08-16__earn_rates__neo_mcc_schedule_p2.sql`; Neo is now 31 earn_rates.

**It caught a defect I shipped this morning.** MCC 5814 (Fast Food Restaurants) maps to
`coffee_fastfood`, **not** `dining`. The United dining row I loaded carried all four Dine codes
on category `dining`, so under the merchant MCC assumption it could never fire at a fast-food
merchant — the category-vs-mapping intersection fails. Split into `dining` {5811,5812,5813} +
`coffee_fastfood` {5814}. **Any issuer whose dining enumeration includes 5814 has the same
trap** — worth a sweep.

**Gas/EV shared-pool concern retired.** All three Neo gas codes map to `gas`, 5552 included, so
EV spend accumulates in the gas bucket rather than a second one. The double-cap risk I raised at
onboarding is inert. The `ev_charging` rows are redundant on the merchant path.

**Both blockers CLOSED 2026-08-16 on Mike's call.** Delta
`2026-08-16__categories_mcc_mappings__retail_shopping_and_recurring.sql`.
**ALL NINE NEO CARDS NOW SCORE.**

1. **`retail_shopping` created.** 79 of Neo's 94 Shop MCCs had no existing mapping and were
   claimed. The other 15 were deliberately left alone — `mcc_category_mappings` is
   `UNIQUE(mcc, valid_from)`, so claiming an already-mapped code *moves* it and revokes pricing
   from whoever relied on it: 5200/5211/5231/5251/5261 stay `home_improvement`,
   5399/5964-5969 stay `online_retail`, 5816-5818 stay `streaming`. Neo Shop resolves on 79/94;
   a holder earns base rate at the other 15. Under-crediting one issuer beats silently
   de-crediting five. Both Shop & Dine plans went `load_only` → `scoreable` (2% $500/mo World,
   3% $1,000/mo World Elite).

2. **`recurring_bills` mapped — after defusing a live regression.** The pre-flip recon found
   **Scotia Momentum Visa Infinite (4%) and Scotiabank Momentum Visa (2%)**, both live and
   scoreable, typed `mcc_defined` with `mcc_includes` NULL. They priced *only* because the
   category had no mappings; the first mapping would have made them match nothing and go dark
   silently. Re-typed both to `preauthorized_only` in the same transaction — which is what
   Scotia's other two Momentum rows and every other issuer's recurring row already use, and what
   #25 had already flagged. Then mapped the 5 free codes: 4814 telecom, 4899 cable, 4900
   utilities, 6300 insurance, 7997 clubs. (5815-5818 and 5968 left with streaming/online_retail.)
   **Net: Scotia ×4 unchanged, MBNA ×2 and Neo ×2 now price, zero regressions** — verified
   against every recurring row in the catalogue.

**Rule 9(a) miss, declared:** the `retail_shopping` step wrote `mcc_category_mappings` without
snapshotting that table first. Snapshot taken immediately after, before the recurring step. The
Shop write is purely additive and reversible by `valid_from`; recorded rather than quietly fixed.

**Left deliberately unchanged:** `condition_type` on the gas/grocery/ev rows. Neo's cashback is
genuinely MCC-defined so `mcc_defined` would be the truthful value, but flipping it makes those
rows fail closed on the stateless path — a live scoring change across three scoreable cards.
That is a decision, not a backfill.

**FX percent — CLOSED 2026-08-16, same day, by verify run `25c45942` (chrome_lane).**
**Neo charges 3%, not the Canadian-standard 2.5%.** Applied 19:11:59Z, Mike-approved, 9/9,
sourced to the Quebec Disclosure Statement & Fee Schedule (effective 2026-06-01) captured as
real bytes — the first artifact in the project with a true byte hash. Leaving this NULL rather
than assuming 2.5 was load-bearing: the assumption would have been wrong on all nine cards.
The stale `[VERIFY]` notes this file and `source_metadata` carried have been cleared.

**But Cathay's FX is sourced from the wrong jurisdiction.** I read that disclosure directly.
It confirms four fees by name — Neo Mastercard $0, Neo World $0, Neo World Elite $149, United
Neo World Elite $89, all matching the DB. **Cathay appears nowhere in it.** Its 3.00 rests on
the document's blanket *"and co-branded Card Accounts and Cards"* wording — in a **Quebec**
disclosure, for a card that is **not sold in Quebec**. Cathay's $180 annual fee is likewise
absent from any Tier 1 document. Both are closed by the chaser that is already open: fetch the
**Except-Quebec twin**. Until then Cathay's FX and annual fee are the two weakest facts in the
Neo set, and neither should be re-derived from the QC document.

**Also found in that disclosure, no schema home:** authorized-user annual fees — Neo Mastercard
$0, Neo World $0, **Neo World Elite $49 per authorized user**. `card_products` has no column
for it; parked in `verify.issuer_notes`. And a QC APR carve-out (19.99–24.50% vs the national
19.99–29.99%), also unmodelled.

**Point valuations — PROVISIONAL and UNCONFIRMED, and the deeper dive is owed.**
RESOLVED-FOR-NOW 2026-08-16 on Mike's ruling: use the two matching figures, mark them
unconfirmed. United MileagePlus **1.6 CAD** and Asia Miles **1.5 CAD** are live on the
`realistic` tier; both carrier cards moved `load_only` → `scoreable`; the
`default_cents_per_point = 0` placeholders are gone. Delta
`2026-08-16__point_valuations__neo_carrier_provisional.sql`.

**These rows are not rule-compliant and must not be cited as issuer-verified.** Tier 2
condition 2 needs three independent sources; there are two (Prince of Travel, Milesopedia),
they report identical figures, neither cites the other, and neither discloses a method or
says whether its CAD figure is native or converted. Stored honestly: `source_tier` NULL
(**not** `tier2` — the constraint `pv_tier2_needs_three_sources` enforces the rule at the
database and would have rejected the claim), `confidence='low'`, `source_count=2`, four
`point_valuation_sources` evidence rows attached. Only the `realistic` tier exists;
conservative and aggressive are absent because two identical points give no basis for a
spread, so users on those tiers fall back to realistic with a warning.

**What the dive needs to produce:** a third genuinely independent CAD-denominated source,
*or* a worked-redemption band in the Aeroplan style, *or* a governance amendment admitting a
two-source case. If none lands, revert both cards to `load_only` and expire the rows
(`valid_to`, never DELETE). Already checked and empty — don't start here: NerdWallet Canada,
Ratehub, The Points Standard, Rewards Canada, Points Nerd, creditcardgenius, MoneySense,
Loonie Tree. Already excluded with reasons: Frugal Flyer (FX-derived and self-contradictory)
and every USD publisher (§2a forbids converting).

**Recurring-bills bonus does not price yet — found on the post-apply probe.** Both Gas &
Grocery plans carry a `recurring_bills` row (2% on World, 4% on World Elite) with
`condition_type='mcc_defined'` and no `mcc_includes`, so both fail closed and pay base rate.
That is correct tier-C behaviour per the 2026-08-14 decision, not a defect — but it means
the **MCC schedule now unblocks three things, not two**: both Shop & Dine plans *and* both
recurring-bills rows. Neo's footnote 1 says recurring payments are "earned on the MCC
categories, which can be found here", pointing at the same PDF. United's grocery and dining
rows are fine — `mcc_includes` populated and mapped, so they price on the authed merchant
path (they read as base-rate-only on the stateless web path, which has no merchant; expected).
United's 1.25x flights row and Cathay's 4x row stay fail-closed by design: the first is a
Star Alliance airline-MCC enumeration we don't have, the second needs its
`earn_rate_eligible_merchants` entry.

**Gas/EV shared pool — a real modelling gap, not a Neo quirk.** Neo treats "gas &
electric vehicle charging" as ONE category with ONE shared monthly limit ($500 on Neo
Mastercard, $1,000 on World and World Elite). `earn_rates` has no shared-pool column, so
`gas` and `ev_charging` each carry the full inline cap and a user splitting spend across
both over-earns in the model. Flagged in-row on all six affected rows. BMO's
gas/EV rows have the same shape and may have the same latent issue — worth a look.

**Two small ones.** The Amazon half of "Purchases on Amazon and wholesale are not eligible
for retail shopping cashback" is merchant-level and has no row (the wholesale half is a
`card_exclusions` row on `wholesale_club`). And the Cathay 4x row is
`condition_type='merchant_list_only'` with no `earn_rate_eligible_merchants` entry for
cathaypacific.com/ca yet — same class of gap as #23, and it fails closed until filled.

**Watch item:** Neo publishes separate Quebec disclosures and QC-specific APRs, and Cathay
is not sold in Quebec at all (already modelled: `availability_scope='regional'`, QC excluded
from `available_provinces`). The Sunday batch should watch for QC carve-outs on the other eight.

## #37 — card.coach → cardcoach.ca identity migration (executed 2026-08-28)

**Status: Workspace and DNS side DONE 2026-08-28.** Decision record and full implications:
`PIPELINE_AND_DECISIONS.md`, entry of 2026-08-28. Supersedes the mail half of #18.

**What is true now.** Workspace primary domain is **cardcoach.ca**. Mike is
**`mike@cardcoach.ca`**; `mike@card.coach` is an alias and still delivers. Same for
`marketing@`, `mikayla@`, `welcome@`. `hello@cardcoach.ca` and `support@cardcoach.ca` are real
Workspace aliases on Mike's account — they **send** now, which they could not before.
`hello@card.coach` exists for the first time (it never did; mail to it was bouncing).
Both domains are DKIM-signed; `card.coach` had no DKIM at all before this.

**#18 is superseded.** That note recorded `hello@cardcoach.ca` as a Cloudflare Email Routing
forward into `mike@card.coach`, live-tested 2026-08-11, with "a send-as/reply-from for hello@"
carried as an optional nicety. Cloudflare Email Routing on `cardcoach.ca` is now **disabled** and
its records are gone — the address is served by Google. Do not re-enable it; it would fight the MX.

**Correction to the release/handoff docs, which are dated records and were left as written.**
Anywhere the following say `mike@card.coach`, read `mike@cardcoach.ca` — it is the same Google
account, renamed, so nothing about the underlying access changed:
- `mobile_app_codebase/docs/app-store/RELEASE_android_1.x_HANDOFF.md` (header + Step 2 org-policy prerequisite)
- `mobile_app_codebase/docs/app-store/RELEASE_1.0.3_HANDOFF.md` (Play Console account line)
- `mobile_app_codebase/docs/app-store/RELEASE_1.2.0_PREMIUM_TESTFLIGHT.md` (`eas whoami`)
- `mobile_app_codebase/docs/dev_notes/BILL-002_pro_surfaces_design_pass_2026-08-22.md` (`eas whoami`)
- this file, #24a / #24d (Play Console account, `roles/orgpolicy.policyAdmin` grantee)

**`tester_allowlist`.** `mike@cardcoach.ca` was ADDED alongside the existing `mike@card.coach`
row rather than replacing it — Mike's call; purely additive, both accounts comp. Delta:
`deltas/2026-08-28__tester_allowlist__cardcoach_ca_owner_address.sql`. The `auth.users` row for
`mike@card.coach` (`1d79eb69-…`) was **not** touched; that in-app account still signs in on the
old address, which still receives.

**Third-party logins — CLOSED 2026-08-28.** Resolved as follows:
- **Expo/EAS — DONE.** `mike@cardcoach.ca`, verified. `eas whoami` reports the new address; same
  account, so the `cardcoach` / `falconview` ownership and project credentials are unchanged.
- **Supabase — DONE.** Both the auth email and the *username* (it used the email as display name).
  Note for anyone repeating this: Supabase requires confirming from BOTH addresses, and Gmail's
  link scanner consumes the one-time token before a human can click it — the confirm link has to
  be opened directly rather than clicked from inside the Gmail UI, or it returns `otp_expired`.
- **Cloudflare, GitHub — N/A.** Both are on `mjross05@gmail.com`; they were never on card.coach.
- **Sentry, RevenueCat, Squarespace — N/A.** Mike has no account on the first two, and Squarespace
  is no longer used. **Follow-up worth having:** the mobile app still reports to Sentry under
  `SENTRY_ORG=falcon-view-group` / `SENTRY_PROJECT=react-native-card-coach`, so CardCoach crash
  data lands in an org Mike has no login for. Not an email problem; an access problem.
- **Apple — DELIBERATELY LEFT (Mike's call 2026-08-28).** Mike *is* on the team: Apple Account
  `mike@card.coach`, role **Admin**, All Apps. Alex (`alexfrancoisfl@gmail.com`) is Account Holder,
  and the team is his Individual account (`AF887JD7ZG`). That column is an **Apple ID**, which App
  Store Connect cannot edit — it changes only at appleid.apple.com and carries devices, purchases
  and 2FA with it. Ruled not worth the risk mid-release-cycle when `mike@card.coach` receives
  indefinitely anyway. Revisit after the Android submit lands, if ever.

**Unrelated but found while in there: the Expo account has 2FA disabled.** That account holds the
signing credentials for both stores.
