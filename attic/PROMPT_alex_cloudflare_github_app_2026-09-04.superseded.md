# PROMPT — Let Cloudflare Pages build from `redSTORMY-KNIGHT/CardCoachv2`

**Date:** 2026-09-04 · **Written by:** Mike (via Claude) · **For:** Alex, to paste into his Claude
**Why:** the app.cardcoach.ca web app deploys through Cloudflare Pages from the `CardCoachv2` repo. Cloudflare reads
a repo through the "Cloudflare Workers and Pages" GitHub App, and GitHub only lets the **owner of a personal
account** install an app on that account's repositories. `CardCoachv2` is owned by `redSTORMY-KNIGHT`, so Mike's
login (`mjross05-del`, a collaborator) cannot do it — checked 2026-09-04: `…/CardCoachv2/settings` returns 404 for
that login, and the Cloudflare picker only shows mjross05-del's own repos.

Everything between the two `=====` rules is the prompt. It is a five-minute, read-only-on-your-side change: nothing
about the repo, branches, collaborators or code is touched, and Alex needs no Cloudflare account.

=====================================================================================================

You are helping Alex Francois grant Cloudflare read access to one GitHub repository he owns, so that Mike Ross
(co-founder) can deploy the CardCoach web app from it. Do exactly this, confirm each screen before moving on, and
do not change anything else on the account.

## Facts

| | Value |
|---|---|
| GitHub account that owns the repo | `redSTORMY-KNIGHT` (Alex's personal GitHub account) |
| Repository | `redSTORMY-KNIGHT/CardCoachv2` (private) |
| App to install | **Cloudflare Workers and Pages** (publisher: Cloudflare) |
| Access to grant | **Only this one repository**, not "All repositories" |
| Who connects it afterwards | Mike, from his Cloudflare account — Alex does nothing on Cloudflare |

## Steps

1. Make sure the browser is signed into GitHub as **redSTORMY-KNIGHT** (top-right avatar → the username). If it
   shows a different account, sign out and back in as redSTORMY-KNIGHT first.
2. Open **https://github.com/apps/cloudflare-workers-and-pages/installations/new**
3. If GitHub asks where to install, pick **redSTORMY-KNIGHT** (the personal account, not an organization).
4. On the permissions page choose **Only select repositories**, open the repository picker and select
   **CardCoachv2**. Leave the requested permissions as they are (they are the app's standard read access plus
   deployment statuses — no write access to code).
5. Click **Install** (or **Install & Authorize**). GitHub may ask for the account password or a 2FA code — that is
   Alex's to enter.
6. If step 2 instead shows a page saying the app is *already installed*, click **Configure**, add **CardCoachv2**
   under "Repository access", and **Save**.

## Verify before handing back

- **https://github.com/settings/installations** (as redSTORMY-KNIGHT) lists *Cloudflare Workers and Pages*, and its
  Configure page shows **CardCoachv2** under repository access.
- **https://github.com/redSTORMY-KNIGHT/CardCoachv2/settings/installations** lists the same app.

## Do not

- Do not select "All repositories".
- Do not change collaborators, branch protection, default branch, visibility, or anything under the repo settings.
- Do not create a Cloudflare account or accept any Cloudflare invitation — none is needed.

## Hand-back to Mike

Reply with two lines: the GitHub account the app was installed on (should read `redSTORMY-KNIGHT`), and the
repositories it can access (should read `CardCoachv2` only). Mike will then finish the Cloudflare side; the
project name there will be `cardcoach-app` and the site `app.cardcoach.ca`.

=====================================================================================================
