# CardCoach Affiliate Wire — Session Report

Run: 2026-08-11 · Owner: Mike · Runtime: Cowork
Scope: /how-we-make-money disclosure page + affiliate plumbing on /best-card (gap-finder module + apply-link registry). Blog untouched by design — BLOG_OPERATIONS gate #4 (commission-blind posts, no affiliate links in blog content) stands unchanged.
Decisions honoured (Mike, in-chat 2026-08-11): gap-finder module · direct issuer links until network approvals · /how-we-make-money framing.

## What shipped (working tree only — NOTHING committed, NOTHING deployed)

| # | Change | Files |
|---|--------|-------|
| 1 | **/how-we-make-money** — trust page + formal affiliate disclosure. Hero, three pillars (commission-blind engine · marked-every-time · Playbook stays clean), plain-words model prose, reviewer-citable disclosure block, contact, standard download + footer. Standard head set (canonical, OG, twitter summary, JSON-LD Org/WebSite/WebPage, en-CA, color-scheme pin). | `site/how-we-make-money.html` (new) |
| 2 | **Footer link sitewide** — "How we make money" added to Company column on all 25 pages (after Terms of Use). Footer md5: 24 pages identical; `delete-account.html` was already the pre-existing outlier and carries the same link. | all `site/*.html` |
| 3 | **Sitemap** — 23 → 24 URLs; new entry after /legal, lastmod 2026-08-11. | `site/sitemap.xml` |
| 4 | **apply-links.js** — THE one registry for outbound card links. Generated from live `export_cards` joined to reverify registry `product_page` URLs (Reverify Script copy, 736 rows). 96 of 129 active cards linked; 33 without product_page rows (student/USD/niche variants — generator prints the list). Every entry today: `network:"direct", sponsored:false`. Flipping an entry to a tracking URL + `sponsored:true` auto-renders the Sponsored badge, `rel="sponsored"`, and the sponsored disclosure line. Regenerator: `outputs/affwire/gen_registry.py`. | `site/apply-links.js` (new) |
| 5 | **Gap-finder on /best-card** — after the wallet answer renders, a second pass ranks every scoreable card NOT in the wallet (same category, same amount) and shows up to 3 that beat the user's winner, each with value, why-line, and registry link. If nothing beats the wallet: "Nothing to pitch here — … your wallet already beats every other card we track." Fails silent (module stays hidden on any error). Disclosure line under the module links /how-we-make-money and switches copy automatically when any shown link is sponsored. | `site/best-card.js` (+~90 lines), `site/best-card.html` (gap section + script tag), `site/best-card.css` (gap styles) |

## Engine facts established this session (probe evidence)

- Recommendations carry `cardProductId` (verified live).
- `recommend-cards-stateless-v1` validates `cardProductIds` at **max 25** (HTTP 400 above; error body captured). Gap-finder chunks at 25, merges client-side, sorts by `effectiveValueCents`; all-or-nothing so the "wallet already wins" claim is only made over the full catalog.
- Live simulation (grocery, $100, 87 scoreable candidates): 4 chunks, **0.95 s total**, 87 ranked; top 3 all resolve to registry links (Cobalt / BMO CashBack WE / Scotia Gold Amex).

## Verification ledger

- `node --check` clean: best-card.js, apply-links.js.
- Banned-language scan (BRAND §07) on all new copy: zero hits (optimize-stem / AI / algorithmic / WARNING / revolutionary). Zero exclamation marks in visible text. No 🍁, no ⛔.
- JSON-LD parses; meta description 124 chars; all internal hrefs resolve; zero `.html` internal hrefs; sitemap well-formed XML, 24/24 ↔ files.
- Footer-link presence: 25/25 pages.

## Git handoff (read before committing — the local checkout is BEHIND origin)

`card_coach_website/.cardcoach-site.git` sits at `6d7dc58`, but origin has two newer commits pushed via API during the 2026-08-11 sweep-fix: `e18bd17` (.assetsignore) and `6f3a6d6` (legal.html disclaimer removal). **legal.html is modified both remotely and locally** (footer insert) — non-overlapping regions, so stash-pull-pop merges cleanly:

```
cd ~/dev/CardCoachv2
git --git-dir=card_coach_website/.cardcoach-site.git --work-tree=card_coach_website/site stash
git --git-dir=card_coach_website/.cardcoach-site.git --work-tree=card_coach_website/site pull
git --git-dir=card_coach_website/.cardcoach-site.git --work-tree=card_coach_website/site stash pop
git --git-dir=card_coach_website/.cardcoach-site.git --work-tree=card_coach_website/site add -A
git --git-dir=card_coach_website/.cardcoach-site.git --work-tree=card_coach_website/site status   # review
git --git-dir=card_coach_website/.cardcoach-site.git --work-tree=card_coach_website/site commit
git --git-dir=card_coach_website/.cardcoach-site.git --work-tree=card_coach_website/site push     # = PRODUCTION DEPLOY
```

Push deploys to cardcoach.ca via Workers Builds. Outer CardCoachv2 repo also tracks `site/` — commit there per your normal cadence. Docs sync (WORKING_NOTES entry, if wanted) left to you — your uncommitted #23/#24 WIP is untouched.

## Next steps (affiliate lane)

1. Deploy the above, phone-check /how-we-make-money + a /best-card run with a thin wallet (gap module should appear).
2. Apply: Fintel Connect + CJ (Amex Canada) + FlexOffers, same week — cite live iOS app, 10-post fact-checked blog, disclosure page.
3. Per approval: edit the card's entry in `apply-links.js` (url → tracking link, network, `sponsored:true`). One file, no other changes.
4. Parked: outbound-click measurement (a `/go/<slug>` Worker route would make clicks visible in CF analytics); the 33 registry gaps; in-app gap-finder parity for iOS/Android.

## DEPLOYED 2026-08-11 (supersedes the handoff section above — Mike authorized push in-session)

- Commits: `4760574` (affiliate wire, 29 files, +447) · `05f0836` (merge of origin/main sweep fixes, built via plumbing) — **pushed, origin/main = `05f0836`**, Workers Builds auto-deployed.
- Live-verified (cache-busted): /how-we-make-money 200 · /apply-links.js 200 with 96 direct entries · /best-card carries gap section + registry script · /legal has NO template disclaimer AND the footer link (merge correct both ways) · sitemap 24/24 with new page · homepage footer link live · `/.git/HEAD` still 404 (.assetsignore intact).
- Mount-quirk record: the sandbox FUSE mount grew a **ghost dentry for `.cardcoach-site.git/index.lock`** — the name stats as ENOENT but git's O_EXCL create gets EEXIST, and a create-then-rename refresh re-poisons it. Worked around by building the merge with `GIT_INDEX_FILE=/tmp` plumbing (read-tree → add → write-tree → commit-tree -p -p → update-ref) and healing the real index with a `cp` (no unlink). **On the Mac this is likely a plain leftover file: `rm ~/dev/CardCoachv2/card_coach_website/.cardcoach-site.git/index.lock` if git ever complains there.**
- Debris for Mike (~1 min, from the Mac): `rm -rf .cardcoach-site.git/stale-affwire-locks` and `rm -f site/.fuse_hidden*` in `card_coach_website/` — same class as sweep-fix item 7.
- Token hygiene: askpass shim deleted, zero token references in git config. **REVOKE the PAT now** — the run is done with it.
- DB writes: none. DNS: untouched.
