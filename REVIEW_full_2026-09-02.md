# CardCoach — Full Review, 2026-09-02

STATUS: CURRENT (written 2026-09-02). Shareable version: https://claude.ai/code/artifact/7156d7d5-040e-4f19-a954-2f322d0b41ee
Scope: mobile app · engine · edge functions · database · site · docs · ops.
Snapshot: `CardCoachv2@33d2171` (branch `fix/nowscreen-fr-i18n`, plus staged changes), `cardcoach-docs@d15748a` plus uncommitted changes, `receipt-core`, production project `hrzpznlpmxxrbtwskacu`, live cardcoach.ca, Cloudflare zone analytics.
Nothing was modified by this review: no file in any repo, no row in the database, no deploy.

## Verdict

The code is in better shape than feared. Every test suite passes when actually run (1,333 jest · 197 vitest · 693 Deno; `tsc` clean), edge-function authentication is uniformly correct, the engine fails closed everywhere it should. What slipped is around the code: one real security hole in the database, one engine blind spot (caps on 40 cards invisible to ranking), a revenue lane finished on 27 Aug and never shipped, and admin steps only Mike (and Alex) can do. Both revenue lines are at $0 and neither reason is technical.

## State of play (live, 2026-09-02)

| Figure | Value |
|---|---|
| Revenue to date | $0 both lines; `billing_events` 0 rows |
| Affiliate clicks tracked | 0 (beacon not deployed; 0 applications submitted) |
| Accounts / active | 85 accounts · 4 active in 7 d · 20 in 30 d (≈6–10 real users) |
| Site page views, 30 d | ~6.6k at the Cloudflare edge (bot-inclusive); human ≈ 110/mo per Web Analytics |
| Tests passing | 2,223 (1,333 jest · 197 vitest · 693 Deno) |
| Catalogue | 149 card_products · 124 scoreable · 16 issuers · all 124 verified ≤ 35 d |
| Unshipped | 18 commits off `main` (2 unpushed); 3 site files unpushed since 2026-08-12 |
| Docs repo | 6 days uncommitted incl. `PRICING_TIERS_2026-08-28.md` and `RUNBOOK_store_accounts_and_revenuecat_2026-09-01.md` |

## Findings register (ranked)

Severity: CRITICAL exploitable/revenue-blocking now · HIGH wrong answers, lost money or launch blocker · MEDIUM compounding debt · LOW hygiene. All items below were re-verified by the reviewer (query, probe, fetch, or test run) unless marked SUSPECTED.

### F-01 CRITICAL · database · anon key can UPDATE/DELETE catalogue rows through SECURITY DEFINER views
- 12 `public` views are SECURITY DEFINER (owner `postgres`, BYPASSRLS). Four are auto-updatable: `v_active_earn_rates`, `v_active_card_caps`, `v_active_merchant_domains`, `v_active_network_acceptance_rules`. All 12 carry INSERT/UPDATE/DELETE/TRUNCATE grants for `anon` and `authenticated`.
- Probe as `anon` (rolled back): UPDATE and DELETE through the views succeed; direct `UPDATE earn_rates` → `42501 permission denied`.
- Impact: one unauthenticated PostgREST DELETE with the public anon key (in every install and on the site) wipes active earn rates/caps/domains/acceptance rules.
- Fix (safe for the app — every base table behind the app-read views has a `canonical_read` policy; only `v_offer_scoped_merchants_from_groups` goes empty for anon, and only service-role paths read it):

```sql
DO $$ DECLARE v record; BEGIN
  FOR v IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
           WHERE n.nspname='public' AND c.relkind='v'
  LOOP EXECUTE format('ALTER VIEW public.%I SET (security_invoker = true)', v.relname); END LOOP;
END $$;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLES FROM anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.user_cards, public.transactions, public.user_preferences,
  public.user_card_overrides, public.user_custom_offers, public.user_loyalty_links TO authenticated;
GRANT UPDATE ON public.profiles TO authenticated;
GRANT INSERT ON public.card_requests TO authenticated;
GRANT INSERT ON public.newsletter_subscribers TO anon, authenticated;
```
  Cut as a dated migration in the same turn (rule 9e); re-run the security advisor; run `pnpm verify:auth-rls`; smoke the Now screen. Not applied — awaiting Mike's approval per the standing `public.*` rule.

### F-02 CRITICAL · revenue · affiliate lane complete in the repo, absent from production
- Site deploy repo `card_coach_website/.cardcoach-site.git` (→ `mjross05-del/cardcoach-site`, Cloudflare auto-deploys `main`): HEAD `1b8468f` 2026-08-12; `apply-links.js`, `best-card.js`, `best-card.css` modified, never committed.
- Live `apply-links.js` is the 11 Aug registry (~96 entries, no Neo/gap-fill); working tree has 126 incl. 30 gap-fill (all 9 Neo, 2 RBC). Live `best-card.js` has no `affiliate-click` beacon and the disclosure is appended after the link loop (working tree passes `verify_disclosure_position.mjs` 9/9; production fails it).
- `affiliate-click` function: source committed (`bf4e32b`), not deployed. `public.affiliate_clicks` exists, 0 rows.
- Zero affiliate applications submitted (Fintel, CJ, Milesopedia). All 126 links are `network:"direct", sponsored:false`.
- Fix: harden then deploy `affiliate-click` (F-11) FIRST, then commit+push the three site files (WORKING_NOTES #39 ordering), click once, confirm one row; submit applications; each approval is a one-line edit in `apply-links.js`.

### F-03 CRITICAL · revenue · Pro cannot be sold; every gate is admin, not code
- Flags `billing_paywall`, `card_slot_limit`, `auto_location_gate` = false (correct). `billing_events` 0; `user_entitlements` 55 rows all `source='manual'`.
- RevenueCat: project + entitlement `cardcoach_pro` + Play products + `default` offering exist; no App Store app (needs new team's IAP .p8), no service-account JSON, no secret key. Production has no `REVENUECAT_API_KEY`/`REVENUECAT_WEBHOOK_SECRET` → webhook and `billing-sync` both 500; a real purchase today grants nothing, unrecoverably after the 72 h retry window.
- iOS app on Alex's Individual team `AF887JD7ZG`; no CardCoach Inc. Apple Organization; no D-U-N-S. No Google Payments merchant profile; `eas.json` Android track = `internal`.
- Gate chain: D-U-N-S → Apple enrolment → Paid Apps/banking/W-8BEN-E → Alex transfers (TestFlight off, SIWA transfer ids for 11 Apple users, 60-day window) → IAP key → ASC subscription group; parallel: Google merchant profile → Play subscription → production track; then a new store build (fingerprint changes; no OTA). `RUNBOOK_store_accounts_and_revenuecat_2026-09-01.md` is correct and uncommitted (F-14).
- Also blocking App Review for a subscription app: `/terms` 404, no privacy policy, no tappable Terms/Privacy in the paywall (F-15).

### F-04 HIGH · engine · 161 caps on 40 cards invisible to ranking
- Live: 161 active `card_caps` rows across 40 cards; 74 active `earn_rates` rows across 28 cards carry inline caps; overlap of (card, category) pairs with a cap on both sides: 0.
- `_shared/scoring.ts:617` selects only `cap_monthly_cad, cap_annual_cad` from `earn_rates`; the only reader of `card_caps` is `cap-progress-v1`.
- Examples with no engine-visible cap: `ca_scotiabank_momentum_visa_infinite_visa` $25,000/yr grocery/gas/recurring/transit/food delivery; `ca_cibc_dividend_visa_infinite_visa` $20,000/yr per category + $50,000 combined; all BMO Air Miles billing-cycle caps.
- `HOW_THE_ENGINE_WORKS.md:423` claims V2 uses `card_caps`; it does not.
- Fix: merge `v_active_card_caps` into `loadReferenceScoringContext` (cap_basis `spend_cad`; periods calendar_year/billing_cycle/calendar_month; `category_id IS NULL` = combined cap via the cap-pool path). Add a capped-card golden fixture to QA-005.

### F-05 HIGH · billing · `auto_location` entitlement has no server-side enforcement
- `recommend-here-v2/index.ts`: zero `hasEntitlement`/`isRuntimeFlagEnabled` calls (parse-receipt, analyze-spend-v1, import-spend-v1, resolve-descriptors-v1 all gate). Only gate is client-side (`NowScreen.tsx:1050`; `useFeatureGate.ts:91` restrict-mode fails open on a failed flags read).
- Fix: copy the two-gate pattern from `parse-receipt` into `recommend-here-v2`, keyed on `auto_location_gate` (~15 lines; no-op until the flag flips).

### F-06 HIGH · billing · two paywall seams
- `useFeatureGate.ts:109` `showUpsell = reason==="not_entitled" && paywallLive` never checks purchase availability; `PaywallScreen.tsx:162` `sellable = paywallLive && canPurchase && options.length>0` → with the flag on and no RevenueCat key, five surfaces dead-end on "Pro isn't on sale yet" (the August failure; `verify_bill_002` exists for it and CI does not run it).
- `PaywallScreen.tsx:120,179-197` confirms "Pro is unlocked" on the falling edge of `entitlementsLoading` or a 500 ms timer without checking any entitlement key arrived; `sync()` swallows billing-sync failures. Test at `PaywallScreen.test.tsx:382` asserts timing, not outcome.
- Fix: `showUpsell = … && isAvailable()`; require `ALL_ENTITLEMENT_KEYS.some(k => keys.has(k))` before confirming, else a "still being set up" state.

### F-07 HIGH · auth · background-resume logouts
- `config.toml:42-43` `jwt_expiry = 900`, `enable_refresh_token_rotation = true`; zero occurrences of `startAutoRefresh`/`stopAutoRefresh`; `AuthContext.tsx:69-71` force-signs-out on "refresh token"/"invalid" errors.
- Fix: the documented six-line `AppState` block after `createClient` in `services/supabase.ts`.

### F-08 HIGH · auth · signup passes no `emailRedirectTo`
- `AuthContext.tsx:203` `signUp({ email, password })`; password reset at `:287` passes `redirectTo`. Lines 211-221 write `profiles.display_name` before a session exists.
- SUSPECTED impact depends on the production "Confirm email" setting (dashboard; not in repo). If on: phone-only signups cannot complete (69 of 85 accounts are email).
- Fix: check the setting; add `options.emailRedirectTo: getSocialAuthRedirectUrl()`; confirm `cardcoach://auth/callback` is allowlisted.

### F-09 HIGH · billing · webhook grants Pro forever on null expiry
- `revenuecat-webhook/index.ts:342` guards TRANSFER against null `expiresAt`; the ordinary grant at `:398` passes it through (`:417` logs `expires … ?? "never"`).
- Fix: allow null expiry only for `NON_RENEWING_PURCHASE`; otherwise 500 (reprocessable) or bounded fallback. Also: `REVENUECAT_ALLOW_SANDBOX=1` is the runbook default and sandbox grants are indistinguishable from paid in `user_entitlements` — write `source='sandbox'` or make the unset a blocking checklist item.

### F-10 HIGH · edge · no rate limit on Places paths or the paid receipt path
- Limiter grep: `search-places` 0, `resolve-place` 0, `recommend-here-v2` 0 (Nearby Search Pro on every call, no cache), `parse-receipt` 0 (8 MB base64/call; idempotency over exact bytes); `resolve-descriptors-v1` has one (7 hits).
- `recommend-cards-stateless-v1` keys its limiter on the FIRST `X-Forwarded-For` entry (client-controlled); it also has no caller.
- No record that the GCP quota cap / budget alert from `FINDINGS_places_autolocation_2026-08-25.md` §5 was done (SUSPECTED).
- Fix: reuse the ~25-line per-user limiter; last XFF hop or `cf-connecting-ip`; undeploy the stateless function; GCP daily quota + budget alert.

### F-11 HIGH · edge · `affiliate-click` is an unauthenticated service-role writer (fix before deploying)
- `affiliate-click/index.ts:136` inserts with `getSecretKey()`; `config.toml:166-167` `verify_jwt=false`; `_shared/cors.ts:85-88` passes requests with no Origin. `card_id` is any 200-char string; no limiter.
- Fix: require the publishable `apikey` header; validate `card_id` against `card_products`; per-IP limiter on the last XFF hop.

### F-12 HIGH · CI · no edge function is tested; the engine-sync gate checks nothing
- `ci.yml` runs lint, typecheck, `pnpm test` (workspace only — `supabase/functions` is not a workspace, so 693 Deno tests never run), boundaries, `verify:edge-imports` (exits 0 with `[SKIP] deno not found` — reproduced), `verify:qa-005`, `verify:sheet-layout`.
- `verify_engine_bundle.mjs` checks existence + typecheck, never content parity; `check_n_plus_one.mjs` always exits 0 and skips `_shared/`; `verify:i18n-parity`, `verify:bill-001/002`, `verify_disclosure_position.mjs` are in no workflow; jest coverage thresholds never evaluated (no `--coverage`); 26 Maestro flows only on `workflow_dispatch`.
- Fix: Deno setup + `pnpm test:supabase`; SHA-256 per-file check in the bundle verifier; fail edge-imports without Deno; add i18n parity, bill-001, disclosure-position; n+1 non-zero exit; `test:coverage`.

### F-13 HIGH · database · `supabase db push`/`db reset` broken since 2026-08-11
- 17 migrations in the live history with no file in `mobile_app_codebase/supabase/migrations/`: 6 `verify_*` (MCP-applied), 10 `rcpt_*` (receipt-core). Version-stamp mismatches: `region_001/002/003` (repo `20260827200500/210000/210500` vs DB `20260827200534`, `20260828020212`, `20260828020234`) and `add_user_selected_condition_type` (repo `20260901234500` vs DB `20260902020412`).
- Fix: `supabase migration repair` (or rename), `db pull` the 17, commit, prove `pnpm supabase:db-reset`; CI diff of `migration list` vs directory.

### F-14 HIGH · process · the record and the code sit on one laptop
- `cardcoach-docs`: last commit `d15748a` 2026-08-27; modified `PIPELINE_AND_DECISIONS.md`, `WORKING_NOTES.md`, `REVENUE.md`, `SOURCE_OF_TRUTH.md`, `DESIGN_online_merchant_v1.md`, `PACKET_affiliate_applications_2026-08-24.md`; untracked `PRICING_TIERS_2026-08-28.md`, `RUNBOOK_store_accounts_and_revenuecat_2026-09-01.md`, `deltas/2026-08-28__tester_allowlist__cardcoach_ca_owner_address.sql`.
- `CardCoachv2`: `fix/nowscreen-fr-i18n` 18 ahead of `main` (AFF-001/002, REGION-1, FR Now-screen fix, store listing), 2 unpushed; `fix/engine-condition-gating` one further; the `user_selected` engine gate staged but uncommitted in the working tree beside two staged legal .docx files; 21 local branches, 3 prunable worktrees, six author identities.
- `receipt-core`: 23 commits, no remote.
- Fix: commit/push docs; commit the engine change on its branch; merge to `main` and push; contracts out of the repo; remote for receipt-core. Rule: a session ends with a push; one lane per worktree.

### F-15 HIGH · site · would fail an affiliate reviewer and App Review
- No privacy policy: `/privacy` → "full Privacy Policy" → `/legal`; `/legal` → "See our Privacy Policy" → `/privacy`. No collection list, retention, or privacy officer (Law 25). A real policy exists unused at `apps/web/src/app/privacy/page.tsx` and names the operator "FalconView.ai".
- `/terms` → 404 (verified). `/legal` dated March 2026; no subscription/auto-renew/trial/cancel/refund clauses. Paywall has no tappable Terms/Privacy links (Apple 3.1.2).
- Disclosure below the links on `/best-card`; `/how-we-make-money` says CardCoach "participates in affiliate programs" (none); footers say "EN + FR" on an English-only site; `support.html` teases Pro; one dead apply link (MBNA World Elite 404); seven links to benefits PDFs.
- Fix: render the apps/web policy to static HTML (operator corrected, privacy-officer contact); subscriptions section in `/legal`; publish `/terms`; paywall links; fix copy; repoint eight links; wire `verify_disclosure_position.mjs` into CI.

### F-16 MEDIUM · edge · five deployed functions have no source in the repo; three dead
- No source in repo: `recommend-here` v1, `recommend-card` v1 (29 Jan, Alex's machine; both `verify_jwt=true`), `receipt-recommend-v1`, `evidence-upload`, `receipt-parse-v1` (paid receipt engine; key handling lives in receipt-core). Dead with source: `resolve-merchant-v1`, `recommend-cards-stateless-v1`, `import-spend-v1`. `health` reveals key generations to any signed-in user.
- `parse-receipt:111`, `resolve-descriptors-v1:253`, `resolve-merchant-v1:87` read `SUPABASE_SERVICE_ROLE_KEY` directly, bypassing `getSecretKey()` → disabling the leaked legacy key would 500 the paid receipt feature.
- Fix: undeploy the dead ones; switch the three to `getSecretKey()`; bring receipt-core's function under the same review/CI.

### F-17 MEDIUM · data · known debt that changes answers; the queue meant to fix it has never run
- 75 active `mcc_defined` rows with no `mcc_includes` fail closed (17 scoreable cards); p3 backfill deltas still `PENDING_VERIFY` and each is a single transaction whose closing assertion fails if any row is withheld.
- 79 `merchant_entities` with NULL `default_category_id` → base-rate-only scoring; 5 rows in `verify.merchant_category_observations`; the Monday batch has never executed. `REPORT_autolocation_optimization_2026-08-25.md:182` claims "self-heal is armed" — code only records proposals.
- 28 active cards NULL `fx_fee_percent` (fail-closed, correct tiebreak); 21 of 68 active point valuations not source-verified in 60+ days (oldest 2026-03-19).
- Engine details (latent): `valid_to` inclusive (`gte`) at `scoring.ts:621,859,889` vs exclusive in views; null `cents_per_point` zeroes a card silently; offer valuation mixes category-slot rate with base-slot unit (`scoring.ts:2289-2296`); UTC month boundaries; four hand-maintained condition-gating whitelists; stale D9 gate test (`api_021_analyze_spend_units.test.ts:545`).
- `recommend-here-v2:760-800`: four awaited loaders per candidate in a loop (30–45 sequential queries per Now request); duplicate merchant-group query.

### F-18 MEDIUM · database · ~50 snapshot tables in `public` + a second product's schema, no retention
- Rule 9(a) snapshots (~50, all RLS-enabled/no-policy) in the API-exposed schema; only guidance "drop stays Mike-only". Ten `rcpt_*` receipt-core migrations in the consumer app's production project. Advisor: 6 functions with mutable `search_path`; leaked-password protection off; 31 `auth_rls_initplan` warnings (irrelevant at this scale).
- Fix: snapshots to a `snapshots` schema, 90-day retention unless cited by `write_audit`; enable leaked-password protection; decide where receipt-core lives.

### F-19 MEDIUM · docs · the documents a new session is told to trust are wrong
- `SOURCE_OF_TRUTH.md`: says stacking/MCC routing not live (stacking live since 2026-08-02; MCC assumption flag on since 08-14); says Alex stepped back (he is Apple Account Holder and must initiate the transfer); lists `README.md`, `stage2_fetcher.py`, `card_sources_seed_enriched.csv` as on disk (none are); "43 migrations"; header 2026-08-01 with 08-28 content; "Warm Logic brand" vs CardCoach Inc.
- Prices $4.99/$39.99/7-day in `RUNBOOK_pro_go_live_2026-08-24.md:161`, `docs/runbooks/BILL-001_revenuecat_setup.md:49`, `docs/planning/specs/BILL-001_billing_and_tiers.md:29`; `REVENUE.md:136-138` self-contradicts; `DESIGN_online_merchant_v1.md:203,360` prices the withdrawn ladder.
- `app.config.ts:71` and `WORKING_NOTES:270` say build 84 both platforms; 85 shipped 2026-08-27. `LAUNCH_TRACKER.md` nine weeks stale.
- WORKING_NOTES closed-but-open: #17 waitlist (retired 07-27), #21 www redirect (301 live), #23 "LAST STEP deploy recommend-here-v2" (v30 deployed), #24d Android key (done 08-24). Open-but-closed: `REVENUE.md` §5 "pre-flight closed".
- Three company names in production surfaces: Warm Logic (docs), CardCoach Inc. (legal), FalconView (`apps/web` privacy page, `app.config.ts:53 owner:"falconview"`, Sentry org `falcon-view-group`).
- ~420 markdown files vs a stated budget of nine; the two most dangerous stale claims carry no supersession banner.

### F-20 MEDIUM · ops · single points of failure
- Expo account 2FA off (holds both stores' signing credentials). Sentry under `falcon-view-group` (no login). Apple Account Holder = Alex. Local Play service-account JSON still on disk after EAS upload. `.env.cloud` at the monorepo root holds a live service-role key (gitignored/untracked, but on disk where agents read). Legacy anon/service keys leaked in git history once (`_shared/supabaseKeys.ts`).

### F-21 MEDIUM · strategy · six technical lanes shipped since 08-16; neither revenue blocker moved
- receipt-core (B2B receipt API, 555 tests, 10 prod migrations, no customer), statement import, widget, online merchant (`is_active=false`), region dimension, Scotiabank/Shell stack. `REVENUE.md:125-130`: "both revenue streams are at zero… and neither reason is technical." Revenue model v3's cheapest actions (two affiliate applications) not sent.

### F-22 MEDIUM · tests · health good, gaps specific
- Full jest: 1,333 pass, 2 fail in `entryRegistersWidget.test.ts` which passes 4/4 alone (order-dependent flake). No `.skip/.only`. Gaps: `EntitlementsContext` untested; no test asserts any handler 401s without a JWT; no engine-copy hash test; `apps/web` has no test script; QA-005 has no condition/floor/window/cap-pool fixture.

### F-23 MEDIUM · mobile · silent-failure seams
- `app.config.ts:429-444` + `services/supabase.ts:27`: a production build with no Supabase env ships with `createClient("","")`; same shape for the Sentry DSN. `ota:publish` hardcoded to `--branch preview` with a broken sourcemap step. `services/api.ts` `searchPlaces/resolvePlace/recordTransaction/deleteAccount` bypass `instrumentedCall`. `App.tsx:149,164` discards font-load errors; `location.ts:211` discards Android `canAskAgain`; `withTimeout` leaks timers; no offline detection.

### F-24 LOW · apps/web · not deployed, cannot earn, SEO hazard if deployed carelessly
- Builds clean; `productData.ts:192` `applyUrl: null`; `serverRanking.ts` omits `earn_rate_type` (RBC WE base reads 1.0 not 1.5) and skips `earnRowPrices`; null annual fee renders $0 in three components; `site.ts:5` defaults canonical/sitemap host to cardcoach.ca. "Web-first is structurally necessary" appears nowhere in the corpus.

### F-25 LOW · edge · one-sweep items
- NUL byte at `scoring.ts:1699`; `_shared/pii.ts` unused; `hasEntitlement` has no defence-in-depth `user_id` filter (billing-sync does); unbounded `query`/`placeId`; one global CORS list; `RECEIPT_ENGINE_API_KEY` undocumented; `0056` and a 07-31 migration headers say NOT YET APPLIED; stale ENT-001 duplicate in `.agent_scratchpad`.

### F-26 LOW · site · housekeeping
- 26 `.fuse_hidden*` copies in `site/`; sitemap `lastmod` all 07-08; "Android coming soon" on seven pages; a third divergent `best-card.*` copy under `card_coach_business_docs/01_CORE/Web App/`; two executed personal contracts staged into the code repo.

## Prioritized to-do (sequenced toward the first dollar)

"you" = credentials/legal identity only Mike can do; "session" = hand to a Claude lane with this document as the brief.

### Day one (~6 h of work, ~30 min of it Mike's)
1. **Close the database write hole** — approve/apply F-01 migration; re-run advisor; smoke Now screen. (you approve · session · 30 min · F-01)
2. **Push the record and the code** — commit+push cardcoach-docs; commit engine change on its branch; merge `fix/nowscreen-fr-i18n` → `main`, push; contracts out of the repo; remote for receipt-core. (session · 45 min · F-14)
3. **Ship the affiliate lane, function first** — harden + deploy `affiliate-click`; commit+push the three site files; click once, confirm one row; fix MBNA 404 + four copy claims. (session · 2 h · F-02 F-11 F-15)
4. **Start the two long poles** — D-U-N-S request; Google Payments merchant profile. (you · 30 min · F-03)
5. **Expo 2FA on; check Supabase "Confirm email"** (you · 10 min · F-20 F-08)
6. **Tell Alex what the transfer needs** — TestFlight off, SIWA transfer ids (11 users), Transfer App to the new Team ID. (you · 15 min · F-03)

### This week
7. **Submit affiliate applications** — Fintel (Tue–Fri, mike@cardcoach.ca, CardCoach Inc., PayPal), per-issuer on approval (Scotiabank first), CJ (Amex), Milesopedia. Re-probe catalogue counts that morning. (you; session drafts · 2 h · F-02)
8. **Real privacy policy + subscription terms + `/terms` + paywall links** (session; you review · half day · F-15)
9. **Engine sees the caps** — merge `v_active_card_caps`; capped-card golden fixture. (session · 1 day · F-04)
10. **Billing/auth hardening bundle** — server auto_location gate; showUpsell guard; verified unlock; AppState refresh; signup redirect; webhook null-expiry; `getSecretKey()` ×3. (session · 1 day · F-05–F-09, F-16)
11. **Rate limits + GCP backstop** — limiter ×4; last-hop XFF; undeploy stateless + v1 pair; GCP quota + budget alert. (session; you for GCP · half day · F-10 F-16)
12. **CI tests what ships** — Deno + `test:supabase`; engine hash check; fail edge-imports without Deno; i18n parity, bill-001, disclosure-position; coverage; n+1 exit. Then RC secrets + webhook test event so `verify:bill-002` can be informational in CI. (session; you for secrets · half day · F-12 F-03)
13. **Repair migration history; prove `db reset`**; CI diff of `migration list` vs directory. (session · 2 h · F-13)
14. **Rewrite `SOURCE_OF_TRUTH.md`; delete the two false claims** (line 130; self-heal paragraph); `RELEASES.md`; price banners; archive `LAUNCH_TRACKER.md`. (session · 2 h · F-19)

### Weeks two–three
15. **Apple** — enrol; Paid Apps + banking + W-8BEN-E; Alex transfers, Mike accepts; new IAP key → RC App Store app → ASC subscription group ($7.99/$59.99, 14-day intro); migrate 11 SIWA users inside 60 days; regenerate SIWA key in Supabase Auth. (you · Alex · session for config · calendar-bound · F-03)
16. **Google** — `cardcoach_pro` with `monthly`/`annual` base plans + 14-day trial offer; service-account JSON to RC; `eas.json` → production track; promote. (you · session · F-03)
17. **Go-live build** — new store build with RC keys; sandbox purchase both platforms; one `billing_events` row; `verify:bill-002` = CAN SELL; unset `REVENUECAT_ALLOW_SANDBOX`; flip `billing_paywall`; flip `card_slot_limit` + `auto_location_gate` LAST and only after item 10. (session; you flip · 1 day · F-03 F-05 F-06)
18. **Drain data debt** — merchant-category batch run + scheduled in Cowork rotation; MCC p3 split per row and applied; TD FX values; 21 stale valuations. (session · 2 days · F-17)
19. **Housekeeping sweep** — snapshots schema + retention; leaked-password protection; Sentry org; secrets out of repo dir; local Play JSON deleted; branches/worktrees pruned; NUL byte, pii.ts, OTA script, font error. (session · 1 day · F-18 F-20 F-23 F-25)

### Parked until a dollar exists
receipt-core productization (and whether its schema stays in this project), online-merchant resolution, statement-import write path, further region/stacking lanes beyond what is queued, `apps/web`.

The honest constraint: at ~110 human visits/month, `REVENUE.md`'s model needs ~22%/month compounding traffic growth for two years to break even on affiliate alone. Everything above is necessary; none of it is sufficient. Once item 3 lands, `affiliate_clicks` replaces four guessed model inputs with measurement.

## What is solid (do not re-litigate)
- Edge-function auth uniform and correct; no body-supplied identity; service-role writes only after verified identity.
- Entitlement model cannot be self-granted (revoked write grants, FORCE RLS, `security_invoker` view, DB trigger for the card cap, no client access to `tester_allowlist`).
- RevenueCat webhook: constant-time compare before body read, fails closed without secret, claim-before-grant idempotency with lease, correct event mapping.
- Engine fails closed on unknown conditions, unproven regions, null FX, missing valuations; deterministic sort; cap/floor arithmetic verified.
- No hardcoded prices; i18n 968/968 keys; verification pipeline current (124/124 ≤ 35 d; 880 confirmed / 73 changed in 30 d).
- 2,223 passing tests, no skipped/focused tests, structural invariant tests.

## Working rules
1. One lane, one worktree, one branch; `git pull --ff-only && git status` first.
2. A session ends with a push (code and docs).
3. CI is the gate, not the runbook — every "we verified X" names the CI step.
4. Database changes leave a file in the same turn; snapshots leave the API-exposed schema.
5. New lanes answer "does this move a tracked click or a sellable tier?" first.

## Method
Snapshot copied to a clean container; five specialised reviewers (mobile, engine, edge, web, docs-vs-reality) ran in parallel; every claim re-checked: read-only SQL on production plus one permission probe as `anon` in a rolled-back transaction, deployed function list + 24 h logs, security/performance advisors, live GETs on cardcoach.ca, Cloudflare zone analytics, the three git repos on Mike's machine, and full test runs (`pnpm install --frozen-lockfile`, `tsc`, jest, vitest, Deno). Not verifiable from here: production "Confirm email" setting (F-08); existing GCP quota cap (F-10); `receipt-parse-v1` key handling in receipt-core (F-16). Dropped: a reviewer claim that receipt-core had no git history (snapshot artifact; it has 23 commits and no remote).


---

## Status at the end of the review lane — 2026-09-02 (appended by the lane)

All other runtimes were retired on 2026-09-02; this lane took over the DATA-018 branch and landed it. Everything below marked **landed** is on monorepo `main` and in this docs repo, both pushed by Mike on 2026-09-02; the edge functions were deployed the same afternoon (16:31 UTC). Table last updated 2026-09-02 evening.

| Finding | Status |
|---|---|
| F-01 anon writes through views | **Closed in production.** SEC-001 applied 14:51 UTC; views `security_invoker`, write grants revoked and re-granted only where enumerated; verified with a rolled-back `anon` probe. |
| F-02 affiliate lane absent from production | **Closed.** `affiliate-click` v2 deployed with gates; DB guard AFF-002; site pushed; one live click = one row. |
| F-03 Pro cannot be sold | **Open — Mike's chain.** D-U-N-S `203843635` in hand → Apple Organization enrolment → Paid Apps/banking/W-8BEN-E; Google Payments merchant profile; RevenueCat secrets; go-live build. Code-side seams closed (F-05/06/09). |
| F-04 caps invisible to ranking | **Landed** (CAPS-001; 16 tests). Live after the edge deploy. |
| F-05 auto_location not enforced server-side | **Landed** (recommend-here-v2 gate behind `auto_location_gate`). |
| F-06 paywall seams | **Landed** (purchase-layer check in `useFeatureGate`; confirmation waits for the entitlement). |
| F-07 background-resume logouts | **Landed** (AppState-driven token refresh). |
| F-08 signup `emailRedirectTo` | **Landed**; the production "Confirm email" setting is still Mike's to check. |
| F-09 webhook grants forever | **Landed** (grant without expiry deferred to `billing-sync`). |
| F-10 no rate limits | **Landed** (SEC-002 per-user budgets, DB-backed; last-hop XFF). GCP quota cap + budget alert remain Mike's. |
| F-11 affiliate-click unauthenticated writer | **Closed in production.** |
| F-12 CI tests nothing that ships | **Landed** (Deno tests, bundle hash, i18n, N+1, migration ledger, disclosure gate). |
| F-13 migration history | **Landed** (18 reconstructed, 4 renamed, ledger + gate; 128/128). `db reset` not yet proven locally — needs Docker on Mike's machine. |
| F-14 record and code on one laptop | **Partly closed.** Both repos pushed 2026-09-02; receipt-core still has no remote (Mike). |
| F-15 legal surfaces | **Landed** (policy, terms, `/terms`, paywall + Settings links). Residue closed: receipt retention is 90 days (RCPT-011). |
| F-16 dead/unsourced functions | **Corrected and closed.** `recommend-cards-stateless-v1` is live (cardcoach.ca's /best-card calls it) — not dead. Undeployed by Mike: `recommend-here` v1, `recommend-card` v1, `health`. `resolve-merchant-v1` and `import-spend-v1` were wrongly listed (shipped-dark features with tests and config blocks) and are re-deployed. The three functions reading the raw service key now use `getSecretKey()`. |
| F-17 data debt | **Closed.** Merchant-category batch ran (run `99b6d975`: 3 applied, 1 rejected, Mike deciding live); the 39-row name pass applied on Mike's approval (run `4b0ccfa5`; guardrail 45 → 6); MCC p3 applied (run `f890f135`: 40 rows). CIBC Adapta modelled as `auto_top_n` (DATA-023, run `7d3e0c1a`). Left in the verify queue, with reasons: Aeroplan VIP dining and Neo United travel (2 rows), TD FX values, the 21 stale valuations. |
| F-18 snapshots / receipt schema / retention | **Landed.** Retention 90 days (RCPT-011; first deletions 2026-11-24). `snapshots` schema with a retention view (SNAP-001/002: 71 tables moved, `public` down to 70 tables). pg_net relocated and six search_paths pinned (SEC-003). Security advisor: one WARN left, leaked-password protection — a dashboard toggle (Mike). |
| F-19 docs wrong | **Landed** (this commit): SOURCE_OF_TRUTH top block + corrections, HOW_THE_ENGINE_WORKS, autolocation self-heal correction, price banners ×5, LAUNCH_TRACKER archived, WORKING_NOTES closed/opened, PROJECT_RULES 9(e), PIPELINE entry. |
| F-20 single points of failure | **Open — Mike** (Expo 2FA; second admin; receipt-core remote). |
| F-21 revenue blockers | **Open — Mike's chain** (F-03) plus affiliate applications. |
| F-22 test gaps | **Partly closed** (caps, rate limits, fuel grades, legal links added; 1,347 jest + 726 Deno green). |
| F-23 mobile silent-failure seams | **Partly closed** (purchase-pending copy, refresh; the font gate now reports a failed load and renders instead of spinning forever). Unchanged: `createClient("","")` on a missing env, the four uninstrumented `api.ts` calls, Android `canAskAgain`, `withTimeout` timers, no offline detection. |
| F-24 apps/web | **Landed.** `/privacy` and `/terms` redirect to the site's policy and terms and left the sitemap; the FalconView.ai policy text is gone. Nothing deployed — correct. |
| F-25 edge one-sweep items | **Partly closed** (secret-key reads; XFF). |
| F-26 site housekeeping | **Partly closed** (sitemap lastmod, MBNA link, GM links, EN+FR footer, support teaser, how-we-make-money copy). |

To-do list: items 1, 2, 3, 8, 9, 10, 11 (code half), 12, 13, 14, 18 (lane half), 19 done — 19's leaked-password toggle, Sentry org, local secrets/Play JSON and branch pruning are Mike's, on his machine; 4, 5, 6, 7, 15, 16, 17 are Mike's chain.
