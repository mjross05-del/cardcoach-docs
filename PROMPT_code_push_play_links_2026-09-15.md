# PROMPT — finish the 2026-09-15 Google Play links on the Mac (code runtime)

Authored by the 2026-09-15 Cowork "Play links" session, on Mike's instruction
("connect the Play store links on the CardCoach site to our play store listing";
then "run in terminal I approve" — computer use can only click in Terminal, so the
site change went out through GitHub's upload page in Mike's Chrome instead, with his OK).
You are a Claude Code session on Mike's Mac. Your job is exactly five things: clear
two leftover lock folders, line the local site repo up with GitHub (no push), push the
monorepo and docs repos, re-check the live site, close WORKING_NOTES #50 — and file a
short report. Nothing else.

## Context — what is already done (do NOT redo)

**The site change is LIVE** on cardcoach.ca since 2026-09-15 ~19:25 ET as GitHub commit
`4c4b4e68dea5f0d4ff915c353453ee3a8180b612` on `cardcoach-site` main (parent `cd3c330`),
and was verified live (tagged links on `/`, `/how`, `/about`; no "soon" badges anywhere
in the sitemap; sitemap lastmod; badge clicks land on the listing).

| Repo | Local state | What is left |
|---|---|---|
| cardcoach-site — git-dir `~/dev/CardCoachv2/card_coach_website/.cardcoach-site.git`, work tree `…/card_coach_website/site` | `main` = `0875e05` (parent `cd3c330`): the same five files, byte-identical to GitHub's `4c4b4e6` — same tree `014b9420c37411a53a0f88d849c953138ba00c43`, different commit id | move local `main` onto `origin/main` — **do not push** |
| CardCoachv2 monorepo | `main` = `85401af` (parent `d96b635`): the same five files under `card_coach_website/site/` | push (fast-forward) |
| cardcoach-docs | `main` = `docs: Google Play links …` (parent `cdf905a`): this prompt, PIPELINE_AND_DECISIONS entry 2026-09-15, WORKING_NOTES #50 | push, then Step 5 |

The badge href, per page (`utm_content` = `home` | `how` | `about`):

```
https://play.google.com/store/apps/details?id=com.cardcoach.mobile&referrer=utm_source%3Dcardcoach.ca%26utm_medium%3Dwebsite%26utm_campaign%3Ddownload_band%26utm_content%3Dhome
```

## Guardrails

- Modify no files except the WORKING_NOTES #50 removal in Step 5. Stage nothing
  else — all three repos have unrelated uncommitted work that is not yours. Never
  `git add -A` or `git add .`.
- Never force-push, and never push the site repo from this prompt (it would be
  rejected anyway: `0875e05` is not a descendant of `4c4b4e6`).
- If a ref is not what an "expect" says, STOP and report — do not rebase inside the
  site's shared work tree.
- If any verification fails, STOP at that step and report.

## Step 0 — clean up, check preconditions

```bash
rm -rf ~/dev/CardCoachv2/_to_delete/stale-git-locks-2026-09-15-play-links \
       ~/dev/cardcoach-docs/attic/stale-git-locks-2026-09-15-play-links
ls ~/dev/CardCoachv2/.git/*.lock ~/dev/CardCoachv2/card_coach_website/.cardcoach-site.git/*.lock \
   ~/dev/cardcoach-docs/.git/*.lock 2>/dev/null          # expect: nothing
S="git --git-dir=$HOME/dev/CardCoachv2/card_coach_website/.cardcoach-site.git --work-tree=$HOME/dev/CardCoachv2/card_coach_website/site"
$S log --oneline -2       # expect: 0875e05 Google Play is live: …  /  cd3c330 Copy: …
$S status --porcelain     # expect: nothing
git -C ~/dev/CardCoachv2 log --oneline -2      # expect: 85401af site: Google Play badges …  /  d96b635 copy: …
git -C ~/dev/CardCoachv2 status --porcelain -- card_coach_website/site   # expect: nothing
git -C ~/dev/cardcoach-docs log --oneline -2   # expect: docs: Google Play links …  /  cdf905a docs: …
```

## Step 1 — site deploy repo: line local main up with GitHub (NO push)

```bash
$S fetch origin
$S rev-parse origin/main                         # expect: 4c4b4e68dea5f0d4ff915c353453ee3a8180b612
$S rev-parse 'origin/main^{tree}' 'main^{tree}'  # expect: 014b9420c37411a53a0f88d849c953138ba00c43 twice
$S update-ref -m "align with GitHub 4c4b4e6 (same tree as 0875e05)" refs/heads/main \
  4c4b4e68dea5f0d4ff915c353453ee3a8180b612 0875e0542c7ca5bbc0a6e696e3c667b04e0619c5
$S status -sb | head -1   # expect: ## main...origin/main  (nothing ahead or behind)
$S status --porcelain     # expect: nothing (the work tree already matches)
```

## Step 2 — monorepo: push

```bash
git -C ~/dev/CardCoachv2 fetch origin
git -C ~/dev/CardCoachv2 rev-parse --short origin/main   # expect: d96b635 — anything else: STOP
git -C ~/dev/CardCoachv2 push origin main
```

## Step 3 — docs repo: push

```bash
git -C ~/dev/cardcoach-docs fetch origin
git -C ~/dev/cardcoach-docs rev-parse --short origin/main   # expect: cdf905a — anything else: STOP
git -C ~/dev/cardcoach-docs push origin main
```

## Step 4 — re-check live (quick; it was verified at deploy time)

```bash
b="https://cardcoach.ca"; q="?cb=$(date +%s)"
curl -s "$b/$q"      | grep -c 'utm_content%3Dhome"'      # expect 1
curl -s "$b/how$q"   | grep -c 'utm_content%3Dhow"'       # expect 1
curl -s "$b/about$q" | grep -c 'utm_content%3Dabout"'     # expect 1
for p in "" how about; do echo "/$p soon-badges: $(curl -s "$b/$p$q" | grep -c 'Google Play · soon')"; done   # expect 0 each
```

## Step 5 — close WORKING_NOTES #50

In `~/dev/cardcoach-docs/WORKING_NOTES.md`, delete the `**#50**` status-index line and
the whole `## #50 — …` section (closed items don't live there). Then:

```bash
git -C ~/dev/cardcoach-docs add -- WORKING_NOTES.md
git -C ~/dev/cardcoach-docs diff --cached --stat   # expect: 1 file, deletions only
git -C ~/dev/cardcoach-docs commit -m "docs: WORKING_NOTES — #50 closed (Google Play links live; Mac repos aligned and pushed)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01K1SYPTEP7RyQRUuuJLmZkd"
git -C ~/dev/cardcoach-docs push origin main
```

## Report

The site ref move (old → new), the pushed ranges for the monorepo and docs, every
Step 4 result, the Step 5 commit hash, and anything that did not match an "expect".
