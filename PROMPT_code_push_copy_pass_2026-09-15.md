# PROMPT — commit + push the 2026-09-15 "helps you decide" copy pass (code runtime)

Authored by the 2026-09-15 Cowork affiliate-applications session, on Mike's
instruction ("OK please fix this"). You are a Claude Code session on Mike's Mac.
Your job is exactly four things: clean one leftover lock folder, commit and push
the site deploy repo (this deploys cardcoach.ca), commit the monorepo copy of the
same edits, commit the docs repo, then verify live — and file a short report.
Nothing else.

## Context — what is already done (do NOT redo)

Mike's rule (2026-09-15): CardCoach **helps people decide** which card in their
wallet to use. It does not tell people what to use. The session reworded every
public line that said CardCoach "tells" people which card to use. The edits are
already in the working trees on disk; they are **not committed**.

| Where | Change |
|---|---|
| `site/index.html` | meta description + og:description → "CardCoach helps Canadians decide which credit card in their wallet to use for every purchase. Real math, no guessing, no bank login." |
| `site/support.html` | FAQ 1 answer → "CardCoach is a Canadian credit card app that helps you decide which card in your wallet to use for a purchase. You add the cards you carry, and CardCoach calculates what each one earns you — in real dollars — for each transaction." |
| `site/legal.html` | Terms §1 opening → "CardCoach helps you decide which of your own cards to use by showing what each would earn on a given purchase, …"; "Last updated" → September 15, 2026 |
| 9 Playbook posts (HTML **and** `post-NN-*.md` source) | CTA line: "CardCoach tells you which one …" → "CardCoach shows what each one earns …" (posts 01, 02, 03, 04, 05, 08, 09, 10, 14) |
| `site/sitemap.xml` | lastmod → 2026-09-15 for `/`, `/support`, `/legal` |
| `mobile_app_codebase/docs/app-store/app-store-submission-draft.md` | §1–§2 reworded (EN + FR-CA), new §2a Pro paragraph for 1.3.0 |
| `cardcoach-docs/PACKET_affiliate_applications_2026-09-15.md` (new) + `PACKET_affiliate_applications_2026-08-24.md` (superseded note) | affiliate applications record |

The session re-ran `render_v2.py` on a copy: the rendered post HTML is
byte-identical to the hand-edited files, so markdown and HTML are in sync and the
posts keep their existing dateModified (a CTA line is not an article edit).

Diff size, site deploy repo: 13 files, 17 insertions, 17 deletions.

## Guardrails

- Modify no files. Stage **only** the pathspecs listed below — both repos have
  unrelated uncommitted work that is not yours (the monorepo has ~38 dirty
  entries). Never `git add -A` or `git add .`.
- Never force-push. Non-fast-forward → `git fetch` + rebase; conflicts → STOP
  and report.
- Pushing the site deploy repo's `main` deploys cardcoach.ca (Workers Builds,
  ~1 min). If a push silently does not deploy, check the GitHub app "Cloudflare
  Workers and Pages" still has `cardcoach-site` in its repository list.
- If any verification fails, STOP at that step and report.

## Step 0 — clean up, check preconditions

```bash
rm -rf ~/dev/CardCoachv2/_to_delete/stale-git-locks-2026-09-15-copy-pass
ls ~/dev/CardCoachv2/card_coach_website/.cardcoach-site.git/*.lock 2>/dev/null   # expect: nothing
S="git --git-dir=$HOME/dev/CardCoachv2/card_coach_website/.cardcoach-site.git --work-tree=$HOME/dev/CardCoachv2/card_coach_website/site"
$S log --oneline -1          # expect: 82f3051 Serve 404.html for unknown URLs …
$S status --porcelain        # expect: exactly the 13 " M" files listed in Step 1
```

If the site HEAD is not `82f3051`, another lane has pushed: `$S fetch origin` and
rebase the commit from Step 1 onto `origin/main` before pushing.

## Step 1 — site deploy repo: commit + push (deploys)

```bash
$S add -- index.html support.html legal.html sitemap.xml \
  cash-back-vs-points.html category-caps-explained.html best-grocery-card-canada.html \
  scotia-momentum-vs-cibc-dividend.html best-gas-card-canada.html \
  per-litre-vs-percentage-gas-rewards-canada.html bmo-blue-rewards-standard-vs-world-elite.html \
  pc-optimum-loblaws-canada.html best-no-fee-credit-card-canada.html
$S status --porcelain   # expect: 13 "M " lines, nothing else staged
$S commit -m "Copy: CardCoach helps you decide, it doesn't tell you which card to use

Home meta/og description, Support FAQ 1, Terms §1 (last updated 2026-09-15),
and the CTA line of nine Playbook posts. Sitemap lastmod for /, /support, /legal.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WhDXR9WxZB2ra5D1qdWmc2"
$S push origin main
```

## Step 2 — monorepo: commit the same edits + the store copy (push per Mike's usual flow)

```bash
cd ~/dev/CardCoachv2
git add -- card_coach_website/site/index.html card_coach_website/site/support.html \
  card_coach_website/site/legal.html card_coach_website/site/sitemap.xml \
  card_coach_website/site/cash-back-vs-points.html card_coach_website/site/category-caps-explained.html \
  card_coach_website/site/best-grocery-card-canada.html card_coach_website/site/scotia-momentum-vs-cibc-dividend.html \
  card_coach_website/site/best-gas-card-canada.html card_coach_website/site/per-litre-vs-percentage-gas-rewards-canada.html \
  card_coach_website/site/bmo-blue-rewards-standard-vs-world-elite.html card_coach_website/site/pc-optimum-loblaws-canada.html \
  card_coach_website/site/best-no-fee-credit-card-canada.html \
  card_coach_business_docs/01_CORE/blog/post-01-cash-back-vs-points.md \
  card_coach_business_docs/01_CORE/blog/post-02-category-cap-explained.md \
  card_coach_business_docs/01_CORE/blog/post-03-best-grocery-card.md \
  card_coach_business_docs/01_CORE/blog/post-04-scotia-momentum-vs-cibc-dividend.md \
  card_coach_business_docs/01_CORE/blog/post-05-best-gas-card.md \
  card_coach_business_docs/01_CORE/blog/post-08-per-litre-vs-percentage.md \
  card_coach_business_docs/01_CORE/blog/post-09-bmo-blue-rewards.md \
  card_coach_business_docs/01_CORE/blog/post-10-loblaws-pc-financial.md \
  card_coach_business_docs/01_CORE/blog/post-14-no-fee-showdown.md \
  mobile_app_codebase/docs/app-store/app-store-submission-draft.md
git diff --cached --stat   # expect: 23 files
git commit -m "copy: CardCoach helps people decide which card to use (site, Playbook sources, App Store draft)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WhDXR9WxZB2ra5D1qdWmc2"
git push origin HEAD
```

## Step 3 — docs repo

```bash
cd ~/dev/cardcoach-docs
git add -- PACKET_affiliate_applications_2026-09-15.md PACKET_affiliate_applications_2026-08-24.md PROMPT_code_push_copy_pass_2026-09-15.md
git commit -m "docs: affiliate applications packet 2026-09-15 (supersedes 2026-08-24); copy-pass push prompt

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01WhDXR9WxZB2ra5D1qdWmc2"
git push origin HEAD
```

(`PROMPT_cowork_store_consoles_1.3.0-87_2026-09-14.md` was untracked before this
session and got one edited line in B5; leave it for Mike.)

## Step 4 — verify live (after the Workers Build finishes, ~1–2 min)

```bash
b="https://cardcoach.ca"; q="?cb=$(date +%s)"
curl -s "$b/$q"        | grep -c "helps Canadians decide"                       # expect 2
curl -s "$b/support$q" | grep -c "helps you decide which card in your wallet"   # expect 1
curl -s "$b/legal$q"   | grep -c "helps you decide which of your own cards"     # expect 1
for p in cash-back-vs-points category-caps-explained best-grocery-card-canada scotia-momentum-vs-cibc-dividend \
         best-gas-card-canada per-litre-vs-percentage-gas-rewards-canada bmo-blue-rewards-standard-vs-world-elite \
         pc-optimum-loblaws-canada best-no-fee-credit-card-canada support legal ""; do
  n=$(curl -s "$b/$p$q" | grep -c -i -E "CardCoach[^.<]{0,80}tells? (you|canadians)"); echo "/$p old-framing lines: $n"   # expect 0 each
done
```

## Report

Commit hashes for all three repos, the four verification results, and anything
that did not match an "expect".
