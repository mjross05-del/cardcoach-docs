# PROMPT — Transfer `CardCoachv2` from redSTORMY-KNIGHT to mjross05-del

**Date:** 2026-09-04 · **Written by:** Mike (via Claude) · **For:** Alex, to paste into his Claude
**Why:** app.cardcoach.ca ships from a static deploy repo (`mjross05-del/cardcoach-app`) for now, because the
monorepo is owned by Alex's personal GitHub account and only the owner can install GitHub Apps (Cloudflare Pages)
on it — checked 2026-09-04: `…/CardCoachv2/settings` 404s for mjross05-del and the Cloudflare picker only lists
mjross05-del's own repos. Transferring the repo to Mike fixes the root cause: Cloudflare Pages can then build
straight from the monorepo and no future integration waits on Alex's account. A CardCoach Inc. GitHub organization
can come later — Mike can move the repo there himself once he owns it.
Supersedes `attic/PROMPT_alex_cloudflare_github_app_2026-09-04.superseded.md`. The Alex-facing copy (same body,
no header) was delivered to Mike as `CardCoach_transfer_CardCoachv2_repo_for_Alex.md`.

**After Mike accepts:** update remotes (`git remote set-url origin https://github.com/mjross05-del/CardCoachv2.git`
in every clone and worktree, including `.claude/worktrees/*`), grant the Cloudflare Workers and Pages app access to
CardCoachv2, switch the `cardcoach-app` Pages project to git-connected (root `card_coach_web_app`, build
`npm run build`, output `dist`, NODE_VERSION 22, the four `VITE_*` env vars), and retire the deploy repo.

=====================================================================================================

You are helping Alex Francois transfer one GitHub repository he owns to Mike Ross (co-founder), so that the
CardCoach company's deployments and integrations (Cloudflare Pages for app.cardcoach.ca, CI, future GitHub Apps)
can be set up by Mike without depending on Alex's personal account each time. Do exactly the steps below, confirm
each screen before moving to the next, and change nothing else.

## Facts

| | Value |
|---|---|
| Repository to transfer | `redSTORMY-KNIGHT/CardCoachv2` (private) |
| Current owner | `redSTORMY-KNIGHT` — Alex's personal GitHub account |
| New owner | `mjross05-del` — Mike's personal GitHub account (already a collaborator on the repo) |
| What transfers with it | All branches, commits, issues, pull requests, wiki, releases, stars, watchers, webhooks and deploy keys. GitHub keeps a redirect from the old URL, so existing clones and links keep working. |
| What Alex keeps | Read/write access as a collaborator (verify in the last step; re-add if needed). |
| Cost | None. |

## Steps

1. Make sure the browser is signed into GitHub as **redSTORMY-KNIGHT** (top-right avatar → username). If it shows
   another account, sign out and back in as redSTORMY-KNIGHT.
2. Open **https://github.com/redSTORMY-KNIGHT/CardCoachv2/settings** (the repository's Settings tab; only the owner
   sees it).
3. Scroll to the **Danger Zone** at the bottom and click **Transfer ownership** (the button labelled "Transfer").
4. In the dialog:
   - **Select the new owner:** choose *Specify an organization or username* and enter **mjross05-del**.
   - **Type the repository name to confirm:** `redSTORMY-KNIGHT/CardCoachv2` (copy the exact string the dialog shows).
   - Click **I understand, transfer this repository.**
5. GitHub may ask for the account password or a 2FA code — that is Alex's to enter.
6. GitHub now emails **Mike** to accept the transfer. Tell Mike it's been sent; the transfer completes when he
   accepts (he has 24 hours).

## After Mike accepts

- Update the remote in Alex's local clone so it stops relying on the redirect:
  `git remote set-url origin https://github.com/mjross05-del/CardCoachv2.git`
- Check **https://github.com/mjross05-del/CardCoachv2/settings/access** shows Alex (redSTORMY-KNIGHT) as a
  collaborator. If the transfer dropped him, Mike re-adds him with *Write* access — one click on Mike's side.

## Do not

- Do not transfer to any account other than `mjross05-del`.
- Do not archive, rename, delete, or change the visibility of the repository.
- Do not change branch protection, collaborators, or default branch — none of that is needed.

## Hand-back to Mike

Reply with one line: "Transfer of CardCoachv2 to mjross05-del sent on <date>". Mike accepts the email, updates his
own remotes, and takes it from there.

=====================================================================================================
