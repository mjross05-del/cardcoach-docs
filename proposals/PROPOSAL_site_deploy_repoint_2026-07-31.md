# PROPOSAL — Repoint the cardcoach.ca deploy from cardcoach-site to CardCoachv2

Status: PROPOSED 2026-07-31 (overnight session) — awaiting Mike's ruling
Last updated: 2026-07-31

## Context (verified live tonight, 2026-07-31 ~22:20 ET)

- The site is served by Cloudflare Worker **`cardcoach-site`** (account worker,
  created 2026-07-05 — the launch date), deployed by **Workers Builds** on push to
  `github.com/mjross05-del/cardcoach-site`. Last build: tonight 21:38 ET, commit
  `bba4df5` (best-card merchant-search fix) — Mike's push just before the overnight
  session began.
- The deploy repo contains **only static assets plus `.gitignore` — no wrangler
  config**. All build/deploy settings (build command, deploy command, root dir,
  branch rules) live in the Cloudflare dashboard, so they must be read from the
  dashboard at execution time; nothing tonight could inspect them via API.
- As of tonight, the same 59-file tree is committed in CardCoachv2 at
  `card_coach_website/site/` (commit `b87aa22`, currently on branch
  `feat/api-011-category-mcc-assumption`), which Mike has ruled the canonical home.
  The local deploy working copy survives: its git-dir is at
  `card_coach_website/.cardcoach-site.git` (see `card_coach_website/README.md`).

## Preconditions (order matters)

1. **The site tree must be on CardCoachv2 `main`.** It currently sits on
   `feat/api-011-category-mcc-assumption` (a strict superset of main). Merge or
   fast-forward main first; repointing production at a feature branch is not an
   option worth taking.
2. The Cloudflare GitHub App needs access to the `CardCoachv2` repository
   (Settings → GitHub App integration → repository access).

## The repoint (all steps are Cloudflare-dashboard work — Mike's hands)

1. **Record current settings** — Workers & Pages → `cardcoach-site` → Settings →
   Build: screenshot/copy the connected repo, production branch, build command,
   deploy command, root directory, and non-production branch behaviour. This is
   the rollback reference.
2. Disconnect the `cardcoach-site` repo from the worker's build configuration.
3. Connect `CardCoachv2` with:
   - **Root directory:** `card_coach_website/site`
   - **Production branch:** `main`
   - **Build/deploy commands:** same as recorded in step 1 (static-assets deploy).
   - **Build watch paths:** restrict to `card_coach_website/site/**` if offered.
     CardCoachv2 is a high-traffic monorepo — without a watch-path filter, every
     app/DB push rebuilds and redeploys the site. If watch paths are not
     available for Workers Builds on this plan, note the redeploy-per-push cost
     before proceeding; it may argue for keeping the mirror arrangement instead.
   - **Non-production branch previews:** off, or preview-only — never deploy
     production from feature branches.
4. Push a trivial change under `card_coach_website/site/` on main; confirm build
   triggers, deploys, and cardcoach.ca serves it. Confirm an app-only push does
   NOT trigger (watch-path check).

## Rollback

Reconnect `cardcoach-site` (repo untouched, still current as of `bba4df5`) with
the step-1 recorded settings. The worker itself is never deleted or recreated,
so DNS/routes are not in play at any point.

## Afterwards (only once the repoint is verified)

- **Archive `cardcoach-site` on GitHub** (Settings → Archive). Do not delete —
  it is the deploy history back to launch.
- Retire the interim double-repo arrangement: delete
  `card_coach_website/.cardcoach-site.git` and the README's deploy-mechanics
  section; deploys henceforth are pushes to CardCoachv2 main.
- Update `card_coach_website/README.md` and append the outcome to
  `PIPELINE_AND_DECISIONS.md`.

## Interim state (until Mike executes this)

Deploys continue exactly as before: commit in `card_coach_website/site/`, then
push the mirror via the detached git-dir (commands in
`card_coach_website/README.md`). The one hazard: edits made in CardCoachv2 but
not pushed to the mirror do not deploy — the README carries the caution.
