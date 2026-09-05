# CardCoach web app — finish report (app.cardcoach.ca)

Lane: finish the web app from the design handoff. Branch `claude/cardcoach-web-design-handoff-8b6b9f`
(worktree `.claude/worktrees/fervent-lederberg-3deff9`), app in `card_coach_web_app/`.
Session 2026-09-04 → 2026-09-05. Live at **https://app.cardcoach.ca**.

Facts below come from the consoles, the database and the browser, not from memory.
Every guardrail held: no keys committed, `card_coach_website/` and the `cardcoach-site` deploy
repo untouched, no merge to main, Mike typed the one card number and ran every git push.

## 1. What is configured, and where

| Area | State | Where |
|---|---|---|
| Supabase auth | Redirect URLs added 2026-09-04: `https://app.cardcoach.ca/auth/callback`, `/reset-password`, and the `http://localhost:5180` pair. Site URL unchanged. Google provider: existing client, verified live (below). Apple: **off on the web** — the provider needs a Services ID + client-secret JWT on the same Apple team as `com.cardcoach.mobile`, which waits for the app transfer to team `QPH8ZPWJFN`; the button is hidden behind `VITE_AUTH_APPLE_WEB`. "Confirm email" not changed. Clients use the `sb_publishable_…` key; the legacy anon JWT is disabled on the project. | Supabase → Authentication → URL Configuration / Providers |
| Supabase edge-function secrets (new 2026-09-05) | `CORS_ALLOWED_ORIGINS = https://app.cardcoach.ca,http://localhost:5180,http://127.0.0.1:5180,http://localhost:3000,http://127.0.0.1:3000` and `REVENUECAT_ALLOW_SANDBOX = 1`. Before: 5 custom secrets (GOOGLE_PLACES_API_KEY, RECEIPT_ANTHROPIC_API_KEY, RECEIPT_ENGINE_API_KEY, REVENUECAT_WEBHOOK_SECRET, REVENUECAT_API_KEY), neither of these. | Supabase → Edge Functions → Secrets |
| RevenueCat Web Billing | App "CardCoach (Web)" `appd10e6c7db5` (CAD, tax off) on the new Stripe account `acct_1UC5lPHDaUSvBTOn` (CardCoach Inc., **unverified → test mode only**). Products `cardcoach_pro_annual` CA$59.99/yr and `cardcoach_pro_monthly` CA$7.99/mo, **14-day trial on both** (Mike's call, matching Play), attached to entitlement `cardcoach_pro`, in offering `default` as `$rc_annual` / `$rc_monthly`. Webhook covers the Web Billing app; `sourceForStore("RC_BILLING") → rc_billing`. | RevenueCat project `proj58aeb9b3` |
| Web app runtime config | `.env` (gitignored): `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` (publishable key), `VITE_REVENUECAT_WEB_KEY` = **sandbox** `rcb_sb_…` key, `VITE_AUTH_REDIRECT_ORIGIN` (set to `https://app.cardcoach.ca` at build time), `VITE_CARDCOACH_DEMO` empty, `VITE_AUTH_APPLE_WEB` unset. | `card_coach_web_app/.env`, `.env.example` |
| Cloudflare Pages | Project `cardcoach-app`, **static deploy repo** `mjross05-del/cardcoach-app` (built `dist/`, no build command, `_redirects` → `/index.html 200`), custom domain `app.cardcoach.ca` CNAME → `cardcoach-app.pages.dev` (approved). Separate from the marketing project. Not git-connected to `CardCoachv2` because that repo is owned by Alex's personal GitHub and Mike is a collaborator — prompt for Alex to transfer it: `cardcoach-docs/PROMPT_alex_transfer_cardcoachv2_repo_2026-09-04.md`. | Cloudflare → Workers & Pages → cardcoach-app |
| Deploy repo state | `mjross05-del/cardcoach-app` main = `697ea93` "Release: f3909a7 — …" (Mike pushed). Release recipe in its README and in the web app README. | `~/dev/cardcoach-app` |
| Feature branch | 10 commits on top of `6b9d128`; **4 not yet pushed** (`89e23c0`, `e551779`, `f3909a7`, `5fad06c`). Nothing merged to main. | worktree |

## 2. Verified on the live site (test account `mjross05test@gmail.com`, then Mike's Google account)

- **Email sign-in / sign-out**: works; `/sign-in` renders with Google + email only (Apple hidden). **Google sign-in**: Mike signed in → landed on `/auth/callback` → his existing phone account `mike@card.coach` (provider `google`, created 2026-08-08), Settings shows "Sign in with: Google", his real wallet (CIBC Dividend Visa Infinite top pick, $4.00 per $100) and comped Pro.
- **Wallet**: add-card panel → 3 cards added → 3 rows in `user_cards` with the right `card_product_id`s; rate lines match `export_card_earnings`.
- **Now**: store search (Google Places), resolve-place, `recommend-card-v2` — the screen shows exactly what the endpoint returns: rank 1 MBNA Rewards World Elite $5.00 (base 1 pt/$ + grocery 4 pts/$, 1¢/pt), rank 2 Platinum Plus $2.00, rank 3 Amazon.ca $1.00, warnings none. Cap tracker matches `cap-progress-v1` after the fix (Grocery $235 of $50,000). Store detection → Automatic detects a store from browser location ("Ricco Foods Cash and Carry · Detected", via `recommend-here-v2`).
- **History**: totals, by-card bar and the purchase detail match `transactions` cents-for-cents; "Record again" and "Delete this purchase" work and the totals update; the receipt-sourced row shows "from a receipt"; Export CSV present.
- **Settings**: email, provider, language, valuation tier, currency, store detection, theme (light/dark/system verified), reminders "Phone only"; Free state "You're on Free · See Pro · from $5.00 a month", Pro state "You're on Pro · yearly · Renews …" with a Manage subscription link.
- **Paywall gates**: History "Add a statement" → paywall led by *Statement analysis*; "Scan a receipt" → led by *Receipt scanning*; Settings "See Pro" → led by *Finds the store for you*. Prices render RevenueCat's `priceString` (CA$59.99 / CA$7.99, "Includes a free trial", "2 weeks free, then…").
- **Sandbox purchase** (Mike typed the Stripe test card): RevenueCat checkout ("Try free for 2 weeks · $0 due today") → webhook `INITIAL_PURCHASE` RC_BILLING SANDBOX → outcome **granted**, 5 keys; `billing_subscriptions` = pro / `cardcoach_pro_annual` / trialing → after the sandbox `RENEWAL` (sandbox runs 5-minute trials and 1-hour years) status **active**, `will_renew` true; `v_active_user_entitlements` holds `unlimited_cards, auto_location, receipt_scanner, statement_import, ambient_widget` with `source = rc_billing`. UI flipped to Pro without a reload. `INVOICE_ISSUANCE` events are `noop / ignored_event_type` — fine.
- **Pro features**: receipt scan (synthetic Metro JPEG) → `parse-receipt` 200 in 66 s → Metro / $71.89 / date proposed, recorded; statement analysis (62-day, 94-row CSV) → parsed in the browser (92 purchases), `resolve-descriptors-v1` + `analyze-spend-v1` 200 → "$124.48 more with the Amex Cobalt over 2 months", 78% categorised.
- **Accessibility**: Lighthouse a11y 96–97 on all five routes on the production build (fixture mode, identical DOM); on live, axe-core 4.10 (WCAG 2.1 AA + best-practice) reports **zero violations** on `/history` and `/settings` and only the known tangerine-CTA contrast on `/sign-in`, `/now`, `/wallet` (brand decision; `#C44F27` would pass 4.7:1). Live Lighthouse itself could not run: the container's egress proxy resets headless Chromium.
- **Design parity**: text-run positions/sizes/weights/colours within 2 px of `design/CardCoach Web App.dc.html` at 1440×900, light and dark (commit `e03edab`). Live screenshots taken at 1412×840 light and dark for Now / Wallet / History / Settings (saved by the Chrome extension under `/tmp/claude-chrome-screenshots-TyO93k/screenshot-1788570244600-1.jpg` … `-6.jpg`).
- **Console / network**: no app console errors or unhandled rejections on any route; every Supabase REST and function call 200 after the CORS fix; the only console noise is a third-party extension's `MaxListenersExceededWarning`.
- **Gate**: `npm run typecheck && npm run build && npm run verify:brand` passes on the final tree.

## 3. Fixed during the live pass (each its own commit on the branch)

1. **`CORS_ALLOWED_ORIGINS` was unset → every edge function refused the browser** (preflight 403 `origin_not_allowed`; store search, recommendation, cap progress, billing-sync, record, receipt, statements all dead from the web app; the phone never noticed because native requests carry no `Origin`). Fixed as a secret, no redeploy needed; preflights now 200 with `access-control-allow-origin: https://app.cardcoach.ca`. Documented in the README.
2. **Recording a purchase from Now returned 500** (`e551779`): the app sent resolve-place's `merchantId` — a `merchant_entities` id — and `record-transaction` wrote it to `transactions.merchant_id` (FK 23503). Now sends only `merchantPlaceId`, like the phone; `merchantId` only for History's "Record again".
3. **Cap tracker showed the wrong cap** (`89e23c0`): took `caps[0]`, so a Metro run showed the Dining cap "No data yet" while `cap-progress-v1` had $100 of grocery spend. Now picks the cap for the category the engine paid a bonus in; hidden when no cap applies.
4. **"Record again" defaulted to tomorrow's date** (`f3909a7`): UTC slice of `occurred_at`; then refused as a future date. Now the local day.
5. README Deploy section rewritten to match reality (`5fad06c`).

## 4. Open items (yours)

- **Push the branch**: from the worktree, `git push origin claude/cardcoach-web-design-handoff-8b6b9f` (4 commits). No merge to main was done.
- **`billing-sync` mislabels every sync (server bug, pre-existing, all platforms)** — needs your OK to touch an edge function. `_shared/revenuecat.ts` `fetchSubscriberEntitlements` reads `store` from `subscriber.entitlements[key]`, but RevenueCat only puts `store` under `subscriber.subscriptions[product_identifier]` (verified on the live subscriber: entitlement has `product_identifier`, no `store`; subscription has `store: "rc_billing"`). Result: `sourceForStore(null)` → `"app_store"` for every sync, and `billing_subscriptions.store` is written `null` over the webhook's `RC_BILLING`. Entitlement *effect* is unaffected (any source unlocks), attribution is wrong. One-line fix: `store: body.subscriber?.subscriptions?.[value?.product_identifier ?? ""]?.store ?? null`. The duplicate grants you'll see in `v_active_user_entitlements` for the test account (`rc_billing` + `app_store` per key) are this bug.
- **Before selling for real**: verify the Stripe business (`acct_1UC5lPHDaUSvBTOn`) → RevenueCat production `rcb_` key → rebuild + release; **remove `REVENUECAT_ALLOW_SANDBOX`** from the secrets; flip `billing_paywall`, `card_slot_limit` (and `auto_location_gate` if intended) — all OFF today, so live shows no 3-card cap, no "Continue with Pro", no Pro nudge, and the free-tier gates were verified in fixture mode only. Note the web shows the Pro upsell anyway because `canPurchase` is true with the sandbox key — a Free user on the web today can start a **sandbox** subscription that grants real Pro while `REVENUECAT_ALLOW_SANDBOX=1` is set.
- **Apple web sign-in** after the app transfer: create a Services ID on team `QPH8ZPWJFN`, generate the client-secret JWT, fill Supabase Apple provider (Client IDs + secret — not Team ID / Key ID / .p8), set `VITE_AUTH_APPLE_WEB=1`, rebuild.
- **Alex transfer prompt** outstanding (`PROMPT_alex_transfer_cardcoachv2_repo_2026-09-04.md`); after it lands, switch Pages to git-connected and retire the deploy repo (steps in the README).
- **Test data left in place** on `mjross05test@gmail.com`: 3 cards, 3 transactions, an active sandbox subscription. Delete the account from Settings when done, or leave it as the web smoke account.
- Small things seen on Mike's real account: cap label casing comes from the server (`grocery (Annual)` for the CIBC cap vs `Grocery (Annual)` for MBNA — `card_caps` data, not the app); "takes over at 10×" for a PC Optimum points card is the rate label convention, arguably confusing next to "%" cards.

## 5. README contradictions found and resolved

- "anon key" → the project's legacy anon JWT is disabled; the client key is `sb_publishable_…` (README updated 2026-09-04).
- Apple provider "Team ID / Key ID / .p8" → Supabase's Apple provider takes Client IDs + a client-secret JWT (README updated).
- "Deploy… Not done in this pass by design", git-connected Pages → deployed via static deploy repo; why, and the recipe (README updated 2026-09-05).
- Nothing in the README or handoff mentioned `CORS_ALLOWED_ORIGINS`; it does now.

## 6. Side finding — marketing site drift (RESOLVED 2026-09-05, corrected)

First reading, later corrected: I reported `card_coach_website/site/` as missing ten files
that the deploy repo had. That was the deploy repo's stale index, not the work tree — the
files were tracked in both. The real drift was one commit: the deploy repo's `main`
(`8c631f7`, "Home step 2 is now 'Tell us where you're shopping'", `index.html` + `styles.css`)
had never been ported back into the monorepo copy, so an edit made from the monorepo and
pushed would have regressed the live home page.

Resolved when Mike lifted the no-site-edits rule for this lane: `6ab1d74` ports `8c631f7`
into `card_coach_website/site/`; `130e6b9` mirrors the new deploy-repo commit `8899aa3`
("Point the site at the web app"); the deploy repo's work tree and index on the Mac now
match its `main`. After Mike pushes, all three (deploy repo, live site, monorepo copy) are
identical.

## 7. Site → web app (added 2026-09-05)

Nothing on cardcoach.ca linked to app.cardcoach.ca (nav "Sign in" went to the finder; "Try
it on the web" scrolled to the home-page finder; "Start free trial" went to `/#download`,
App Store only). Deploy-repo commit `8899aa3` — nav **Sign in** → `app.cardcoach.ca/sign-in`
on all 32 pages and in `render_v2.py` (blog template); hero **Use it on the web** →
`app.cardcoach.ca/`; download band pill "iPhone and web today" + a third badge "Use it in your
browser · app.cardcoach.ca"; `/pro` **Start free trial** ×2 → `app.cardcoach.ca/pro`. Web app
`37836b7` adds `/pro` (opens the paywall over Settings, sign-in first if needed; the return
path survives the Google round trip via sessionStorage, in-app paths only). Verified in fixture
mode: signed-in, email sign-in and Google paths all land on `/settings` with the paywall open.
Release `4badf38` in the deploy repo carries it.

## 8. Production billing (2026-09-05, later)

Stripe `acct_1UC5lPHDaUSvBTOn` activated by Mike (session filled only the products/services
description). RevenueCat app installed on the **live** Stripe account (Mike's OK), which is
what makes RevenueCat issue the production Web Billing key; verified with the live key that
offerings and products (CA$59.99/yr, CA$7.99/mo, 2-week trials) resolve. `.env` now carries the
production `rcb_` key; `REVENUECAT_ALLOW_SANDBOX` deleted from the edge-function secrets;
`billing-sync` v10 deployed through the Supabase connector (the CLI is not on Mike's Mac) with
the store-lookup fix (`33b3e70`) and the sandbox refusal (`91c0bb2`). Runtime flags
`billing_paywall` / `card_slot_limit` deliberately still off until the keyed phone builds ship.
