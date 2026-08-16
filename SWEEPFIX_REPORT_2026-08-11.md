# CardCoach Sweep-Fix Run — Report

Run: 2026-08-11 · Input: Pre-Launch Full Sweep 2026-08-10 · Owner: Mike · Runtime: CoWork
Outcome: 7 of 9 items closed (F1 F2 F3 F4 F5 F6 F9) · F7 NO-CHANGE by its own §5 rule (mechanism not worker-based; dashboard rule specified below) · F8 SKIPPED (CONFIG OFF).
Zero DB writes · zero deletions · DNS untouched (MX/SPF/DKIM/DMARC/TXT/AAAA `100::` verified present and unmodified) · site fixes deployed and live-verified · doc fixes are local commits awaiting Mike's push · no STOP-EVERYTHING condition met.

## Fix ledger

| ID | Target | Result | Hash-or-Evidence |
|---|---|---|---|
| F1 | cardcoach-site — serve exclusions | CLOSED, live | `e18bd17` · build `5ecf9fc2` success |
| F2 | cardcoach-site — `legal.html` disclaimer | CLOSED, live | `6f3a6d6` · build success 03:11:47Z |
| F3 | CardCoachv2 — APPLY_CHECKLIST + DELTAS_INDEX | CLOSED, local commits | `99b259b` · `4c8c8f6` |
| F4 | cardcoach-docs — WORKING_NOTES | CLOSED, local commit | `95070da` |
| F5 | CardCoachv2 — 5 governance snapshots | CLOSED, local commits | `c2744b7` `e2dd084` `696b0f5` `7c95eab` `9045523` |
| F6 | Workers `divine-brook-e823` + `broad-leaf-7294` | CLOSED — disabled, reversible | API `enabled:false` ×2 · both URLs dead |
| F7 | www.card.coach dead-end | NO-CHANGE → MANUAL (F7.5) | zone ruleset evidence, §F7 below |
| F8 | Heading-order normalization | SKIPPED | CONFIG `HEADING_FIX: OFF` |
| F9 | ALEX_HANDOFF_2026-08-11.md | FILED | `2308bb4` (cardcoach-docs root) |

## Preflight record

- HEADs at run start: cardcoach-site `6d7dc58` = sweep expectation · CardCoachv2 `f0f26e5` = expectation · cardcoach-docs local mount `5ec44b3` = expectation. cardcoach-docs GitHub remote sits at `9752d1c`, which is a direct ancestor of `5ec44b3` — the mount is 7 commits ahead of origin, one lineage, no divergence. All doc targets re-read at current HEAD; every finding reproduced live before its fix ran.
- GitHub connector was absent at session start. Mike supplied a fine-grained PAT mid-run (scope: mjross05-del/cardcoach-site + cardcoach-docs, 1-day expiry). CardCoachv2 (redSTORMY-KNIGHT) is outside token scope (403 verified) — its commits are local-only by design. Revoke the token now that the run is done.
- Locate-first (§0.4): `APPLY_CHECKLIST.md`/`DELTAS_INDEX.md` exist only in CardCoachv2 `01_CORE/data/deltas/` (a prunable `.claude` worktree copy is the same repo, not a second writable copy). WORKING_NOTES canonical = cardcoach-docs root; the CardCoachv2 same-named files are "MOVED 2026-07-16" tombstones pointing at it. No single-writable-copy violations.
- Cloudflare auth confirmed (workers_list: exactly the 3 expected workers).
- Mount quirk (recorded, worked around): the sandbox mount of `~/dev` permits `rename()` but blocks `unlink()` inside `.git`, so git's lock/tmp cleanup fails. Stale locks were moved (not deleted) into `.git/stale-sweepfix-locks/` in both repos; commits were then made with per-commit lock hygiene. All landed commits verified in `git log`; both worktrees verified clean against their new HEADs (cardcoach-docs shows only Mike's pre-existing WIP — see F4).

## Per-item verification evidence

### F1 — repo internals no longer served (N1)
Reproduced pre-fix: `/.git/HEAD` and `/wrangler.jsonc` returned file content (binary/JSONC payloads). Root cause confirmed deeper than the sweep knew: `wrangler.jsonc` is not in `main` at all — it lives only on the bot branch `cloudflare/workers-autoconfig` (commit `1feb6b3`); Workers Builds (build command empty, deploy `npx wrangler deploy`, root `/`) injects equivalent config at build time with `assets.directory="."`, which uploaded the checkout including `.git/` and the injected config file. `.assetsignore` at repo root is therefore the correct and sufficient mechanism.
Change: `.assetsignore` with exactly `.git`, `.gitignore`, `wrangler.jsonc`, `.assetsignore` (no other non-site files exist at root; full tracked-file listing reviewed). Commit `e18bd17`, pushed 03:09Z, build `5ecf9fc2-cc68-4d08-8828-90b59fa24b32` success.
Verify (post-fix): `/.git/HEAD`, `/.git/config`, `/.git/logs/HEAD`, `/.gitignore`, `/wrangler.jsonc` all return no content (404-class). Note: the first post-fix re-fetch of the two URLs fetched earlier in the session still showed stale bodies — fetch-tool cache, disproven with cache-busted queries (`?cb=e18bd17`), which return dead; never-before-fetched exclusion paths return dead without cache-busting.
Regression: `/` · `/styles.css` (text/css, full stylesheet) · `/scripts.js` (text/javascript, full body) · `/cash-back-vs-points` (full article) · `/best-card` (full tool page) — all 200 with correct content-types and non-trivial bodies.

### F2 — template disclaimer removed (N2)
Reproduced pre-fix: live `/legal` displayed "This is a template. Please have your legal team review and finalize before publishing." Change: removed the disclaimer `<p>` together with its sole-purpose wrapper `<div>` (border-top divider whose entire content was that sentence) — diff is exactly −3 lines, nothing else touched. "Last updated: March 2026" left as is. Commit `6f3a6d6`, build success 03:11:47Z.
Verify: live `/legal` (cache-busted) — sentence gone; all seven sections, contact link, and footer unchanged. No replacement text added. Broader Terms-content question remains with Mike (shelved, untouched).

### F3 — delta governance stop-note + status reconciliation (N3 doc side)
Reproduced: both files still presented the 18 card-lane files as a pending queue (`dormant-handoff` / DATE-GATED statuses). Changes, factual annotations only:
1. `APPLY_CHECKLIST.md` — dispatch-verbatim ⛔ STOP paragraph prepended as line 1 (`99b259b`).
2. `DELTAS_INDEX.md` — card-lane table only: 17 rows → `superseded-live (2026-08-10 sweep)` (includes the formerly DATE-GATED tiered-caps row), Fido closure row → `not-applied — live state NULL (2026-08-10 sweep)` (`4c8c8f6`). CPP-lane table untouched.
Verify: re-read at new HEAD — stop-note present; counts grep 17/1; worktree clean.

### F4 — WORKING_NOTES corrections + run entry (B5)
Reproduced at current HEAD: item #19 still said "new Cloudflare Pages project" / "old direct-upload Pages project" (line 200). Changes (one commit, `95070da`): #19 next-action rewritten to the Worker model mirroring SOURCE_OF_TRUTH lines 61–63 (cardcoach-site Worker serving static assets; push-to-`main` auto-deploy via Workers Builds; not classic Pages); dated 2026-08-11 run entry inserted above the new-items footer listing F-IDs, hashes, F6 containment, and the F7 outcome.
WIP preservation: Mike's uncommitted #23/#24 additions (8,199 chars) were held out of the commit and deterministically restored afterward — post-commit worktree diff vs new HEAD is exactly 22 insertions, 0 deletions, starting at `## #23 — FX fee audit follow-ups`. Nothing of Mike's was committed, lost, or reordered. Backup of the pre-run dirty file: sha256 `9ef1a402b91b8798…` (session copy).

### F5 — SUPERSEDED banners (B3)
Reproduced: all five April-2026 snapshots in `01_CORE/CardCoach/governance/` began with original content, no banner. Change: dispatch-verbatim one-line banner + blank line prepended to each; bodies untouched; one commit per file (`c2744b7` Master_Context_Pack · `e2dd084` Whats_Live · `696b0f5` Decisions_Addendum · `7c95eab` Operating_Model · `9045523` File_Index). Verify: re-read — each file's line 1 is the banner; worktree clean.

### F6 — stray worker containment (N8), CONFIG `archive_and_disable`
Reproduced pre-fix: both `https://divine-brook-e823.mjross05.workers.dev/` and `https://broad-leaf-7294.mjross05.workers.dev/` served a full April-era CardCoach site copy (old testimonial block, `.html` links, `hello@card.coach` contact on divine-brook).
Preconditions verified: account custom-domain list contains only cardcoach-site attachments (card.coach, cardcoach.ca, www.cardcoach.ca); worker routes on both zones: empty. Neither stray has any custom domain or route.
Archive: both are assets-only Workers — script content endpoints return 204/empty and `bindings: []` (settings JSON in appendix). There is no script source to archive; the "code" of these workers is their static asset store, which disabling does not touch. Reversal is one call per worker: POST `.../workers/scripts/{name}/subdomain` `{"enabled": true}`.
Disable: POST `{"enabled": false}` → 200/success for both; GET re-check confirms `enabled:false, previews_enabled:false`.
Verify: both workers.dev URLs now return no content (dead; cache-busted). divine-brook needed ~2 minutes of propagation before going dark; confirmed dead on re-check. Nothing deleted; `delete` branch not run (CONFIG unchanged).

### F7 — www.card.coach (#11): mechanism found, no change made
Finding: the apex `card.coach` → `cardcoach.ca` 301 is NOT worker-based. It is a zone Single Redirect ruleset on card.coach — phase `http_request_dynamic_redirect`, rule "card.coach to cardcoach.ca canonical redirect", expression `true` (catch-all), 301 to `concat("https://cardcoach.ca", http.request.uri.path)`, `preserve_query_string: true`. The cardcoach-site custom domain on the apex never actually answers; the redirect phase runs first. `www.card.coach` dead-ends purely because it has no DNS record (dig: no A/AAAA; authoritative zone record list confirms).
Per dispatch F7.5 (redirect-rules mechanism = dashboard-scoped): no change made. The precise fix for Mike, dashboard, ~1 minute: card.coach zone → DNS → add record `AAAA` name `www` content `100::` proxied (mirroring the apex convention). The existing catch-all rule then 301s www with path+query preserved, and `getcardcoach.ca` chains through: getcardcoach.ca (registrar 301, Squarespace IPs 198.185.159.x/198.49.23.x) → www.card.coach → cardcoach.ca. The two-hop chain becomes functional; the one-hop ideal (repoint the registrar forward directly to `https://cardcoach.ca/`) stays on Mike's manual list.
Regression (unchanged behavior confirmed): `https://card.coach/blog?utm_test=sweepfix` → 301 → `https://cardcoach.ca/blog?utm_test=sweepfix` (path + query preserved).

### F9 — Alex handoff
`ALEX_HANDOFF_2026-08-11.md` created at cardcoach-docs root (beside WORKING_NOTES), commit `2308bb4`. Contents from the sweep's ALEX PACKET: per-file dormant-delta posture with do-not-run rationale and the Fido exception · N4 stacking-flag-vs-engine question including the `appliedOffers: []` observation and the docs-stay-unedited condition · N5 Fido `application_status` NULL · N7 advisor items (3 anon-callable SECURITY DEFINER functions, 7 definer views, leaked-password protection off) · N9 National Bank predicate pairs · snapshot-table housekeeping. Self-contained; no Mike action items inside. `HOW_THE_ENGINE_WORKS.md` / `PIPELINE_AND_DECISIONS.md` stacking language untouched, per dispatch.

## Archive appendix (F6)

Worker metadata at containment time (full settings responses):

```json
divine-brook-e823: {"created_on":"2026-04-23T21:14:26.900289Z","modified_on":"2026-04-23T21:14:37.648431Z",
  "settings":{"placement":{},"compatibility_date":"2026-04-23","compatibility_flags":[],"usage_model":"standard",
  "tags":[],"tail_consumers":[],"logpush":false,"annotations":{"workers/triggered_by":"upload"},"bindings":[]}}
broad-leaf-7294:  {"created_on":"2026-04-23T13:08:16.147653Z","modified_on":"2026-04-23T13:08:20.964809Z",
  "settings":{"placement":{},"compatibility_date":"2026-04-23","compatibility_flags":[],"usage_model":"standard",
  "tags":[],"tail_consumers":[],"logpush":false,"annotations":{"workers/triggered_by":"upload"},"bindings":[]}}
```

Script source: none exists — `GET /workers/scripts/{name}` and `/content/v2` both return 204 with empty body for both workers; `bindings` empty (not Workers-Sites/KV). These are assets-only uploads (April 2026 direct upload); their full content is the static asset store, retained untouched with the disabled workers. Pre-disable page snapshots (both served the April-era site copy: old testimonial pull-quote, `.html`-suffixed nav links, dead store badges, divine-brook footer contact `hello@card.coach`, broad-leaf `hello@cardcoach.ca`) are preserved in this session's fetch log. Restore command (either worker): `POST /accounts/c8f2911db35005faefbb206f61591394/workers/scripts/<name>/subdomain {"enabled": true}`.

## Mike-manual checklist (§3 + run additions)

1. Revoke the GitHub PAT used this run (fine-grained, created today, 1-day expiry) — the run is done with it.
2. Push docs when ready. cardcoach-docs: `git push` publishes 9 commits (your 7 unpushed + `2308bb4` + `95070da`) — deliberately not pushed by this run since 7 of them are your unpublished work. CardCoachv2: push `99b259b`…`9045523` (7 commits) with credentials that can write to redSTORMY-KNIGHT/CardCoachv2. Alex cannot see `ALEX_HANDOFF_2026-08-11.md` until the cardcoach-docs push happens.
3. www.card.coach: add the proxied `www` AAAA `100::` record on the card.coach zone (dashboard, per §F7). Optional afterwards: repoint the getcardcoach.ca registrar forward straight to `https://cardcoach.ca/`.
4. GSC: confirm sitemap submission + request indexing for live posts (login-walled; TXT verification already in place).
5. `hello@cardcoach.ca` live delivery test (routing rule enabled; delivery untested).
6. App Store listing visual confirmation (UNSWEPT in the sweep).
7. Repo debris cleanup, ~1 minute: the sandbox mount could not delete git lock/tmp files, so they were renamed aside. Run `rm -rf .git/stale-sweepfix-locks` in both `~/dev/CardCoachv2` and `~/dev/cardcoach-docs` (~50 inert files total; git never reads them).
8. Terms/Privacy content work beyond F2's one-sentence removal: with you and counsel (shelved, untouched).

## CHAT SYNC

- Files changed: cardcoach-site `.assetsignore` (new) + `legal.html` (pushed, deployed) · CardCoachv2 `APPLY_CHECKLIST.md`, `DELTAS_INDEX.md`, 5 governance snapshots (local) · cardcoach-docs `WORKING_NOTES.md`, `ALEX_HANDOFF_2026-08-11.md` (new) (local).
- Commits: `e18bd17` `6f3a6d6` (cardcoach-site, pushed) · `99b259b` `4c8c8f6` `c2744b7` `e2dd084` `696b0f5` `7c95eab` `9045523` (CardCoachv2, local) · `2308bb4` `95070da` (cardcoach-docs, local).
- Project sync required: Y — WORKING_NOTES, DELTAS_INDEX, APPLY_CHECKLIST touched → sync canonical docs; open a fresh Project chat for the updated index.
