# CardCoach Pre-Launch Full Sweep — Report

Run: 2026-08-10 (executed 2026-08-11 01:41 UTC) · Owner: Mike · Runtime: CoWork
Ground truth: live URLs · live Supabase `hrzpznlpmxxrbtwskacu` · live Cloudflare (zones cardcoach.ca, card.coach) · repo HEADs.
Preflight: cardcoach-site build HEAD `6d7dc58` (deployed, no drift) · CardCoachv2 HEAD `f0f26e5` · cardcoach-docs HEAD `5ec44b3` · Supabase reachable · `https://cardcoach.ca` → 200. Connectors Supabase / Cloudflare / GitHub-via-Cloudflare-Builds all authed. No STOP-EVERYTHING condition met (site up; verify schema anon-denied; evidence bucket private; only the intended publishable key in page source).

---

## VERDICT — AMBER for "ready for first users"

The product is effectively already launched (iOS app live at App Store id6757937693; the site is live marketing plus a working best-card tool), user/verify data surfaces are locked down, and public claims are defensible. Three things hold it below GREEN:

1. **`.git/` and `wrangler.jsonc` are served publicly** at cardcoach.ca (assets directory = repo root). No secrets are exposed, but full source and git history are reconstructable. Close before any promotion.
2. **The live Terms of Use page still displays** "This is a template. Please have your legal team review and finalize before publishing." — first-visitor-visible.
3. **The governance premise is stale**: the live DB already contains the end-states of the "write-frozen / 18 dormant" card-lane deltas, and the loyalty-stacking flag is ON — so two of the biggest register assumptions no longer describe reality.

None is a user-data breach or a site outage. First users can already download and use the app.

---

## Table 1 — NET-NEW findings

| ID | Surface | Finding | Class |
|---|---|---|---|
| N1 | S1/S3 | `.git/` (HEAD, index, logs, config) + `wrangler.jsonc` + `.gitignore` served 200 — assets dir is `"."` | B |
| N2 | S1 | Live `/legal` Terms shows published text: "This is a template. Please have your legal team review and finalize before publishing." | B |
| N3 | S2 | Live DB already reflects the "dormant/write-frozen" card-lane delta end-states; re-applying files would double-insert | C-Alex |
| N4 | S2/S4 | `runtime_flags.loyalty_offer_stacking = true` (since 2026-08-02) while canonical docs still say stacking "is not wired into the V2 production path" | C-Alex |
| N5 | S2 | Fido `application_status = NULL` — deviates from discontinued-card convention (its closure delta never took) | C-Alex |
| N6 | S1/S3 | "Pre-launch waitlist" premise is stale: no `<form>` on any page, no `FORM_ENDPOINT` in scripts.js, `cardcoach-waitlist` worker returns 404; CTAs are App-Store downloads | (info) |
| N7 | S2 | 3 anon-executable `SECURITY DEFINER` functions callable via RPC (`handle_new_user`, `handle_user_email_updated`, `maintain_user_spend_snapshots`) + 7 definer views (advisor ERROR/WARN) | C-Alex |
| N8 | S3 | Two stray workers (`divine-brook-e823`, `broad-leaf-7294`, created 2026-04-23) still serve a CardCoach copy on `*.workers.dev` (no custom domain) | C-Mike |
| N9 | S2 | 15 active earn-rate predicate groups share (card, category, basis, condition_type); none identical, but National Bank dining/grocery pairs warrant a double-count glance | C-Alex |
| N10 | S1 | Heading-order skips (h2→h4) on most pages; minor a11y | B (opt) |

`en-CA` lang, Poppins/Literata/IBM Plex Mono fonts, 9-token palette, single beacon per page, JSON-LD valid, favicon/OG/Twitter present, `[CAP_POOL]` stripped in the tool, zero exclamation marks / no "optimize" / no "AI-powered" / no "WARNING" / English-only: all pass, not findings.

---

## Table 2 — Register reconciliation

| Item | Status | Evidence |
|---|---|---|
| #1 www dead-ends | RESOLVED | `www.cardcoach.ca` → 301 → apex; worker custom-domain + AAAA `100::` present |
| #2 18 dormant deltas / write freeze | CHANGED (stale) | Live DB holds the end-states (fees 150/139, Blue Rewards rename+program+valuation, Rogers net-new card, Rogers 2026-08-04 tiered caps live, PCF fees 0); 72 migrations through 2026-08-02 |
| #3 stacking blocked; b0ff0008 void→b; b0ff0004 30v60; unwired in V2 | CHANGED | Flag ON; 10 offers issuer_confirmed 0.90–0.97; b0ff0008 live+corrected (CT-retail-only), not voided; b0ff0004 still records the 30-vs-60-day Journie conflict |
| #4 valuation lane ×4 | RESOLVED (mostly) | Marriott realistic 0.90 (conf med-high); Avion all tiers med-high; Aeroplan aggressive 3.00 / conservative 1.20; amex-mr aggressive 3.00 |
| #5 GSC property + sitemap | CHANGED | `google-site-verification` TXT present (2026-08-07); `/sitemap.xml` live + in robots.txt; console *submission* unverifiable → Mike |
| #6 Dusk/Copper keep-or-drop | CONFIRMED open | `--dusk #8B93A1`, `--copper #C4875C` still defined |
| #7 Canva brand kit fix | CONFIRMED pending | one brand kit present `[SHELVED-ADJACENT]` |
| #8 `[VERIFY]` flags, count unknown | RESOLVED | 3 total: earn `ca_rbc_moi_standard_visa`, `ca_rbc_us_dollar_visa_gold_visa`; valuation `aeroplan-points`. All descriptive notes, no unverified public number |
| #9 PCF $60K income never public | CONFIRMED clean | `$60K`/`60,000` income absent from all visible text |
| #10 PCF per-litre member totals note-only | CONFIRMED clean | Loblaw-banner point earns shown (permitted); no Esso/Mobil per-litre member totals printed |
| #11 getcardcoach.ca redirect/DNS | CHANGED (worse) | DNS at Google Domains (not Squarespace); 301 → `https://www.card.coach/` which does **not** resolve → dead-ends |

---

## Finding detail

### N1 — `.git/` and repo config served publicly  (build)
Root cause: `wrangler.jsonc` → `"assets": { "directory": "." }` publishes the repo root.
Evidence (all HTTP 200 on cardcoach.ca): `/.git/HEAD` (41 b, = deployed commit `6d7dc58`), `/.git/index` (5426 b), `/.git/logs/HEAD` (212 b), `/.git/config` (remote `github.com/mjross05-del/cardcoach-site.git`, no embedded creds), `/.gitignore`, `/wrangler.jsonc`. No `.env`/`.dev.vars`/service key found; the only key in JS is the intended `sb_publishable_…` anon key. Impact: full source + history of the marketing repo is cloneable; low secret value but a standard misconfiguration to close before promotion.
Proposed action: restrict the assets directory to a `site/`-only subfolder, or add an `.assetsignore` excluding `.git`, `.gitignore`, `wrangler.jsonc`. See Class B diff.

### N2 — Terms page ships a template disclaimer  (build)
`https://cardcoach.ca/legal`, final line, visible: "This is a template. Please have your legal team review and finalize before publishing." Also "Last updated: March 2026." First-visitor-visible on a trust page. Distinct from the shelved counsel-engagement item — this is a concrete copy defect. Proposed: remove the line and ship reviewed Terms (counsel timing is Mike/legal). Class B.

### N3 — Write-freeze premise is stale  (data)
The card-lane delta end-states are already live: BMO Blue Rewards WE fee 150 and CashBack WE 139 (both correction deltas); `blue_rewards` point program + 3 valuations; `ca_rogers_red_world_mastercard` net-new card present; Rogers 2026-08-04 tiered caps live (Red $16k / World $26k / World Elite $61k, `valid_from 2026-08-04`); PCF fees 0; PCF World net-new present. 72 migrations applied through 2026-08-02. The 18 delta files use guarded `UPDATE`s (now no-ops) but **unguarded `INSERT`s** — re-applying would create duplicate `earn_rates`/`card_caps`. Exception: the Fido closure delta did not take (N5). Reconciliation, not an assumption that either side is authoritative: live introspection is ground truth here (§1.4). Zero writes were made. Full drift table in the Alex packet.

### N4 — Stacking flag ON vs docs say unwired  (build/data tension)
`runtime_flags.loyalty_offer_stacking = true`, note "ACTIVATED 2026-08-02 by Mike," migrations `data_018_loyalty_stacking_phase1/seed` + `data_019_member_earn_rates` applied. Canonical `HOW_THE_ENGINE_WORKS.md` and `PIPELINE_AND_DECISIONS.md` still state `solveOfferStack` "is not wired into the V2 production path." A grocery-category call to `recommend-cards-stateless-v1` returned `appliedOffers: []` (no loyalty context to trigger one), so production offer application could not be confirmed from the public tool. Either the docs are stale or the flag is ahead of the engine — Alex to confirm whether the live edge function actually applies offers, and reconcile the doc line.

### N7 — Anon-executable definer functions  (data)
Supabase security advisor: `handle_new_user`, `handle_user_email_updated`, `maintain_user_spend_snapshots` are `SECURITY DEFINER` and executable by `anon`/`authenticated` via `/rest/v1/rpc/…`. They are trigger functions not meant for direct call; revoke `EXECUTE` or switch to `SECURITY INVOKER`. Plus 7 `SECURITY DEFINER` views (the `export_*`/`v_active_*` read surface — intended public read, but the linter flags the definer bypass) and leaked-password protection disabled on Auth. All read-only to observe; routed to Alex.

### Positives worth recording
Site 200 across 23 crawled URLs, on-brand 404, HSTS + `X-Content-Type-Options` + `Referrer-Policy` + CSP `frame-ancestors 'none'` present, SSL `full`, Always-Use-HTTPS on. card.coach 301→apex preserves path+query on root, blog+query, and deep path. Email routing `hello@cardcoach.ca → mike@card.coach` enabled; MX→Cloudflare, SPF + DKIM intact; apex AAAA `100::` untouched (read-only, not modified). Best-card tool: category-only calls disclose the MCC assumption, strip `[CAP_POOL]` markers, and show "Can't rank yet" for load-only cards rather than guessing. Spot-checked 3 cards' live numbers against the engine (TD Cash Back grocery 3%, PCF Insiders 40 pts/$ Loblaw-only correctly scored at base for generic grocery, BMO Blue Rewards) — all consistent. Verify freshness is current (89 of 113 active cards verified, oldest 2026-07-31, none stale > 14 days).

---

## S6 — Open lenses

**Adversarial first user.** Tried to force a wrong/stale answer via the best-card tool: category-only grocery ranked TD Cash Back (3%) > BMO Blue Rewards (1.34¢) > PCF Insiders (1.00) — correct, because Insiders' 40 pts/$ is Loblaw-banner-only and the engine fell back to base for generic grocery. Load-only cards degrade gracefully. MCC assumption is disclosed. No wrong answer produced.

**Skeptical journalist — hardest claim to defend.** The site-wide "issuer-verified" badge against the fact that 24 active cards (11 of them scoreable + open) have no row in `verify.v_card_freshness` with a `last_verified_at`. The claim holds for the verified majority and is backed by 770 fact-checks + a private evidence bucket, but a reporter could screenshot a specific live card that has never been verification-logged. Second-hardest: "we leave it out rather than get it wrong" — true (18 active cards carry zero active earn rows and are load-only/unranked), but 6 are `application_status='closed'` yet `is_active=true`, which reads oddly without the convention explained.

**Day-one drill (50 users tomorrow), by likelihood × damage.** (1) `.git`/source exposure discoverable by any curious visitor; (2) the "template" disclaimer on the live Terms page; (3) anyone who shares `getcardcoach.ca` lands on a dead host; (4) "Last updated March 2026" Terms + Privacy read as unfinished. The iOS app is the actual product; none of these break the app.

**Unowned issues (most dangerous class).** `.git` exposure sits between the site (Mike) and infra (Alex) lanes; the dead `getcardcoach.ca` redirect and the live "template" Terms line have no clear current owner. All three are assigned in the packets below so none falls through.

**UNSWEPT — silence is not clearance.** iOS app internals and real-device rendering; App Store listing state (apps.apple.com and the iTunes lookup returned empty to server fetch, and the Chrome extension is not connected, so the listing was not visually confirmed); email *deliverability* (routing config verified, live delivery not tested); `recommend-cards-stateless-v1` internals beyond black-box behaviour; `verify` schema row contents (anon-denied, correctly); whether the sitemap was *submitted* in the GSC console (login-walled).

---

## Class A — governance-doc corrections executed

**None executed this run.** Rationale (dispatch §7, "Unsure → Class B"): the canonical pipeline/engine docs in `cardcoach-docs` (`PIPELINE_AND_DECISIONS.md`, `HOW_THE_ENGINE_WORKS.md`) are clean on the V1/V2 and stacking axis — they state V2-only / V1-dead / no-coexistence and "stacking not wired into the V2 production path" explicitly (the latter matches the dispatch's own §1.9/§9.3 ground truth, so it is not a defect to change; the ON flag is the anomaly, routed to Alex). Two real drift hits remain and are proposed as Class B rather than auto-committed:

- `cardcoach-docs/WORKING_NOTES.md:200` (open item #19) still describes the deploy as a "Cloudflare Pages project" and "old direct-upload Pages project," which `SOURCE_OF_TRUTH.md` (lines 61–63) already supersedes ("a Cloudflare Worker serving static assets — not classic Cloudflare Pages"). On the §6.b list, but inside a dated open-item narrative and already contradicted by the authoritative doc — downgraded to Class B (B5) under §7's "ambiguous → Class B."
- The `card_coach_business_docs/01_CORE/CardCoach/governance/` hits (Cloudflare Pages, card.coach-primary, Outfit, zip-upload) live only in the superseded **April-2026 handoff snapshots** (`Master_Context_Pack.md`, `Whats_Live.md`, `Decisions_Addendum.md`, `Operating_Model.md`, `File_Index.md`) — dated point-in-time records, not the live governance set; rewriting them is not "restoring settled facts."

Zero repo writes were made.

---

## Class B — proposed only (per-item "Apply" required)

**B1 — cardcoach-site: stop serving repo internals (N1).** Add `.assetsignore` at repo root:
```
.git
.gitignore
wrangler.jsonc
```
Rationale: `assets.directory="."` currently publishes `.git/` and config. Alternative: move site files under `site/` and set `"directory": "site"`. One file, no rebuild logic change.

**B2 — cardcoach-site `legal.html` (N2).** Delete the trailing line "This is a template. Please have your legal team review and finalize before publishing." and replace the placeholder Terms with counsel-reviewed copy. Rationale: visible template disclaimer on a trust page.

**B3 — governance handoff snapshots (Class-A-downgraded).** In `card_coach_business_docs/01_CORE/CardCoach/governance/{Master_Context_Pack,Whats_Live,Decisions_Addendum,Operating_Model,File_Index}.md`, add a one-line "SUPERSEDED — historical April-2026 snapshot; see cardcoach-docs for current truth" banner rather than editing the dated bodies. Rationale: prevents a fresh reader treating "Cloudflare Pages / card.coach-primary / Outfit / zip-upload" as current, without destroying the record.

**B4 (optional) — heading order (N10).** Normalize h2→h4 jumps to sequential levels across templates.

**B5 — cardcoach-docs `WORKING_NOTES.md:200` (Class-A-downgraded).** Correct the item-#19 "Cloudflare Pages project" / "old direct-upload Pages project" wording to the Worker model (`cardcoach-site` Worker serving static assets, push-to-`main` auto-deploy), matching `SOURCE_OF_TRUTH.md`. One line; on the §6.b list but downgraded per §7 ambiguity.

No edits made; awaiting per-item approval.

---

## Class C — hand-off packets

### ALEX PACKET (DB / engine)

- **Dormant-delta drift (N3).** Live DB already holds the card-lane end-states. Applying the 18 files now: guarded `UPDATE`s no-op; **unguarded `INSERT`s duplicate rows**. Do not run as-is. Per-file posture:
  - `2026-07-02/*` (BMO Blue Rewards ×4, PCF ×4, closures): end-states LIVE — inserts would duplicate `earn_rates`/`card_exclusions`.
  - `2026-07-03/bmo point-programs`: `blue_rewards` program + valuation LIVE — re-insert would duplicate.
  - `2026-07-04/rogers ×6`: red-world net-new card LIVE; **Fido closure NOT applied** (status NULL, see below).
  - `2026-08-04/rogers tiered-caps` (was date-gated): caps LIVE (`valid_from 2026-08-04`) — do not re-apply.
  - Reference `APPLY_CHECKLIST.md`; treat the folder as an executed-then-filed record, not a pending queue, and reconcile `DELTAS_INDEX.md` status column.
- **Fido (N5).** `ca_rogers_bank_fido_standard_mastercard.application_status = NULL`; closure delta predicate (`WHERE application_status='limited'`) never matched. Decide target state per the settled Rogers/Fido representation convention.
- **Stacking flag vs engine (N4).** Confirm whether `recommend-cards-stateless-v1` actually applies `loyalty_stack` offers in production with the flag ON; if yes, correct the docs; if no, the flag is ahead of the engine.
- **Advisor items (N7).** Revoke `EXECUTE` or switch to `SECURITY INVOKER` on the 3 anon-callable definer functions; review the 7 definer views; enable leaked-password protection.
- **Earn-rate collisions (N9).** 15 active (card, category, basis, condition_type) groups; verify the National Bank dining/grocery 0.6667 pairs aren't double-counted.
- Snapshot/backup tables (`*_snapshot_*`, `*_night_*`) carry RLS-enabled-no-policy lints and `point_valuations_snapshot_20260729` is an unattributed drop-candidate — housekeeping only.

### MIKE MANUAL (dashboard-scoped)

- **`.git` exposure (N1)** — apply B1 in the cardcoach-site repo (assets ignore or `site/` subfolder), then redeploy and reconfirm `/.git/HEAD` returns 404.
- **getcardcoach.ca (N2/#11)** — it 301s to `https://www.card.coach/`, which has no DNS and dead-ends. Repoint the Squarespace/Google-Domains forward to `https://cardcoach.ca/` (or add a `www.card.coach` record). DNS is at Google Domains, not Squarespace.
- **GSC (#5)** — property TXT verification is in place; confirm the sitemap is *submitted* and request indexing for live posts at `https://cardcoach.ca/sitemap.xml`.
- **`hello@` delivery test** — routing rule is enabled; send a real test to `hello@cardcoach.ca` and confirm receipt at `mike@card.coach`.
- **Stray workers (N8)** — decide whether to delete `divine-brook-e823` / `broad-leaf-7294` (old `*.workers.dev` copies).
- **No waitlist test needed (N6)** — the waitlist funnel described in the dispatch no longer exists; the site uses App-Store-download CTAs and a `newsletter_subscribers` table (0 rows, insert-only) with no live form.

### DEFERRED

- Queued Code-surface reconciliation errand (attic diffs, WORKING_NOTES heading audit, July-13 artifact search): not run per dispatch; this sweep does not change its priority.
- Shelved `[SHELVED-ADJACENT]`: counsel engagement, affiliate-disclosure review, CDBA copy, site holdbacks, Dusk/Copper decision, Canva brand-kit fix — observed only, no action.

---

## CHAT SYNC

- Files changed: none. Commits: none. Repo writes: 0. DB writes: 0. DNS: untouched.
- Project sync required: **Y** — `DELTAS_INDEX.md`/`APPLY_CHECKLIST.md` status columns should be reconciled to live DB state (N3), the stacking-flag-vs-engine question resolved (N4), and `WORKING_NOTES.md:200` Pages wording corrected (B5); B1/B2 pending approval.
