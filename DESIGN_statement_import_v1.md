# DESIGN — Statement Import & Counterfactual Earnings v1 (Pro)

Date: 2026-08-20 · Status: **D1–D14 SIGNED OFF (Mike, 2026-08-21). Schema APPLIED to
production; edge functions pending deploy; both gates DARK.** · Author: Cowork session (Claude)

**Sign-off, 2026-08-21.** Mike signed off D1–D14 as written, including the three that moved
during the build: D2's scope amendment (§D11), D11's descriptor-not-place-id resolution, and
§9.3's option (b). No decision was altered at sign-off; the amendments recorded in place
above are the decisions as signed.

**Applied to production 2026-08-21 03:44–03:46 UTC** on `card_coach_advanced`
(`hrzpznlpmxxrbtwskacu`), under rule 9: p0 snapshot (secured in-transaction), then p1, p2,
p3. Every migration's own post-condition block passed. 15/15 independent post-apply
assertions PASS. `runtime_flags.statement_import` and `.statement_import_write` are both
**false** — no shipped surface changed behaviour. Delta:
`deltas/2026-08-21__data_022__applied_to_prod.sql`. Advisor sweep after apply: zero lints
name `statement_imports`; the 12 ERROR / 7 WARN present are pre-existing and were confirmed
against the same project beforehand.

Feature ids: **PKG-011** (replay math) · **API-020** (descriptor resolution) · **API-021**
(spend analysis) · **API-022** (opt-in import, dark) · **DATA-022** (schema + gates) ·
**APP-024** (mobile surface) · **QA-011** (parser fixture corpus).

All code paths are relative to `CardCoachv2/mobile_app_codebase/` unless prefixed otherwise.
Current-state claims are cited `file:line` against the working tree at commit `67e7945`
(2026-08-20, branch `main`, dirty). Live-DB counts are from `card_coach_advanced`
(`hrzpznlpmxxrbtwskacu`), read 2026-08-20. Governing docs: `SOURCE_OF_TRUTH.md`,
`PROJECT_RULES.md` (rules 7 and 9), `HOW_THE_ENGINE_WORKS.md`, `BRAND.md`.
Companions: `DESIGN_online_merchant_v1.md` (this doc answers its open question 6),
`docs/planning/specs/API-017_receipt_parse.md`, `BILL-001_billing_and_tiers.md`.

---

## 0. What the feature is

A user hands CardCoach one or more credit-card statements. CardCoach reads them on the
phone, works out what that spending actually earned, replays the same spending against
every card in the catalogue, and answers one sentence:

> **You'd have earned $247 more with the Scotiabank Gold American Express.**

Four things make this different from anything shipped so far.

1. **It is the first backward-looking answer the product gives.** Every existing surface
   answers "which card, right now, at this till." This one answers "was I on the right
   card at all," which is the question that actually moves someone to apply for a card —
   and the only question a per-purchase recommendation can never answer, because the
   difference between two cards on one $40 grocery run is eleven cents.

2. **The number is a replay, not an estimate.** Real transactions, real dates, in order,
   against real caps and real rising tiers, on both sides of the comparison. A monthly
   average multiplied by an earn rate would be a different, easier, wrong feature —
   `_shared/cardValue.ts` already computes that shape and its own header lists the
   mechanics it drops (§1.5).

3. **The file never leaves the phone, and the server is never told both halves of the
   story.** Merchant names go up in one request with no amounts and no dates; amounts and
   dates go up in another with no merchant names (D2). CardCoach ends the session knowing
   neither what the user bought nor, in any joinable form, from whom.

4. **The most valuable answer is the one that earns us nothing.** If a card already in
   the user's wallet would have beaten the card they used, that is said first, above any
   card we could send them to apply for (D7).

**What this is not.** No bank login. No credential capture. No aggregator, no Plaid, no
Flinks, no scraping. `BRAND.md:26-31` lists "a bank-login or scraping product" under
*What CardCoach is NOT*, and a user-initiated file the user already possesses is on the
correct side of that line. Nothing in this design moves toward the other side, and any
future proposal that does needs a brand-level decision entry, not a spec.

---

## 1. Current state (verified 2026-08-20)

### 1.1 The engine can already do this; nothing calls it this way

`computeEarnMathV2` (`packages/engine/src/v2/earnMath.ts:1067`) takes **N cards and one
purchase** and returns per-card value with full cap, floor, pool and `window_bucket`
mechanics. `loadReferenceScoringContext` (`supabase/functions/_shared/scoring.ts:480`)
loads reference data for **an arbitrary list of card product ids**, and
`buildCatalogScoringContext` (`:996`) turns that into a wallet-less `ScoringContext`.

The seam is already documented in the code. `buildCatalogScoringContext` sets
`snapshots: []` and `annualSnapshots: []` (`:1017-1018`), and the stateless endpoint's
module docstring states the consequence plainly:

> *"Offers, preferences, pinned overrides, and spend snapshots are out of scope by design:
> with no spend history, cap consumption is computed as $0 spent / full cap remaining (the
> web page discloses that assumption)."*
> — `supabase/functions/recommend-cards-stateless-v1/index.ts`

`ScoringContext.snapshots` and `.annualSnapshots` are plain arrays. Feeding them a running
total as a statement is replayed is the entire technical trick of this feature, and it
needs no schema change and no engine change to the ranking path.

### 1.2 The 25-card ceiling is a wire choice, not an engine limit

`zRecommendCardsStatelessV1Request.cardProductIds` is `.min(1).max(25)`
(`packages/engine-contracts/src/recommendCardsStatelessV1.ts`). That bound exists because
the endpoint runs on the anon key behind a 10-req/min IP rate limiter
(`recommend-cards-stateless-v1/rateLimit.ts`). `computeEarnMathV2` accepts unbounded
`cards[]`; `loadReferenceScoringContext` accepts an arbitrary `cardProductIds: string[]`.

Live counts: **149 `card_products`, 108 scoreable, 41 `load_only`, 15 issuers.** Scoring
108 cards in one authenticated request is a different bargain from scoring 25 anonymously,
and this design takes it (§8).

### 1.3 The cap mechanics are the whole point, and they are dense

Live, active: **636 earn rates** (505 category rows), **74 rows carrying an inline cap**,
**7 floored rows**, **10 rows with `window_bucket = 'card'`**, **161 active `card_caps`
rows across 63 distinct `pool:` groups.**

These are precisely the mechanics that separate the top of the catalogue: RBC's rising
tiers, NBC's whole-card monthly windows, the big annual category caps. A comparison that
ignores them ranks a 10%-capped-at-$100 card above a 5% uncapped one and is worse than no
comparison at all — `earnMath.ts:825-853` already carries the cap-aware
primary-selection logic that exists to stop exactly that.

**CORRECTED 2026-08-21, during the build.** The `card_caps` pooling above is real data and
is **not in the scoring path.** `toEngineRate` (`_shared/scoring.ts:1159`) does not map
`cap_pool_id`, so `EngineEarnRateV2.capPoolId` is never populated from the database and
the 63 `pool:` groups never reach `computeEarnMathV2`. `card_caps` is read by
`cap-progress-v1` and the admin app, and by nothing else. Scoring caps come entirely from
`earn_rates.cap_monthly_cad` / `cap_annual_cad` / `floor_*`.

Consequence for this design: the replay supports `capPoolId` because the engine does — a
loader that starts populating it must not silently change one path and not the other — but
it does not synthesize pools, and no claim in this document rests on pooled caps being
priced. The original sentence naming "Scotia Momentum's pooled $25k tier" as a
differentiator was wrong on that point and is struck above. Whether the scoring path
*should* read `card_caps` is a real question and a separate ticket; it is not this one.

### 1.4 Category coverage is uneven, and three categories are dead

Active earn rates by category (top of the distribution): `grocery` 83, `travel` 65,
`gas` 64, `dining` 58, `transit_rideshare` 40, `recurring_bills` 39, `entertainment` 22,
`drugstore_pharmacy` 21, `streaming` 18, `ev_charging` 16, `food_delivery` 13.

Zero active rates: **`online_retail` 0, `telecom_internet` 0, `other` 0, `costco` 0,
`marriott_travel` 0**, plus the legacy aliases `drugstore`, `pharmacy`, `recurring`,
`transit`. `merchant_domains.category_override`'s own migration comment already warns:
*"Never online_retail: that category has zero earn rates and would silently score every
card at base."* The same trap applies here, and at statement scale it is worse: a
descriptor mapped to a dead category is indistinguishable in the output from a descriptor
that legitimately earns base everywhere.

Legacy aliases are live in the data (37 category rows against a canonical 28), so
`normalizeCategoryId` (`supabase/functions/resolve-place/classify.ts`) must run over every
category id this feature derives — including any hint read off a CSV.

### 1.5 The existing multi-transaction math is a deliberate fork, and cannot carry this

`_shared/cardValue.ts` (`computeValueByCard`) already aggregates many transactions to a
per-card dollar value, and it is what `card-value-stats` and `user-value-stats` serve. It
shares `combineEarnRates` with the engine and reimplements everything else. Its documented
divergences: caps applied at the **month-aggregate** level rather than per transaction;
**only `cap_monthly_cad`** — no annual caps, no floors, no pools, no `window_bucket`;
conditional rows fail closed; no offers, no FX, no explanations.

Against §1.3 that is not a small gap. Reusing it for a headline dollar figure would
produce a number that disagrees with the ranking engine on the exact cards the feature
exists to surface. **PKG-011 is a new module in `packages/engine`, driving
`computeEarnMathV2` — the same math the ranking uses — not a third fork.** Whether
`cardValue.ts` should later be retired onto PKG-011 is a follow-up (§9.4), not this doc.

### 1.6 Merchant resolution exists, is name-based, and will not cover a statement

`_shared/merchantIdentity.ts` gives one canonical `normalizeMerchantName` (unicode-
preserving) and one pure `findChainEntityMatch` (word-boundary prefix against curated
`is_chain` entities, longest wins, category-conflict guard). `parse-receipt` uses exactly
this pair and nothing else.

Live: **567 `merchant_entities`, 48 flagged `is_chain`, 46 aliases, 583
`merchant_entity_places`, 72 entities with a NULL `default_category_id`.**

48 curated chains is enough for the head of a Canadian statement — the grocery banners,
the coffee chains, the gas brands — and nothing like enough for the tail. Statement
descriptors are also materially dirtier than Google place names: processor prefixes
(`SQ *`, `TST*`, `SP `, `PAYPAL *`), embedded store numbers, trailing city and province,
truncation at 22 or 25 characters. Normalizing those is new work (§6.1) and the coverage
it reaches is a number this feature must **show the user**, not hide (D4).

### 1.7 `merchant_list_only` and `mcc_defined` rows will not price here

Live: **55 active `merchant_list_only` rows** and **168 active `mcc_defined` rows.**
`earnRowPrices` (`_shared/scoring.ts:1293`) fails closed on both unless a merchant entity
(list) or an active `CategoryMccAssumption` (MCC) is supplied. Under D2 this design
deliberately does not carry merchant identity into the scoring request, so both classes
stay unpriced. WORKING_NOTES #27 separately records 52 `mcc_defined` rows with no
`mcc_includes` that already fail closed everywhere.

This is an **under-count**, and under-counting is the safe direction — but it must be
stated, not absorbed (D9).

### 1.8 The gating primitive exists and is applied; adding a key is two INSERTs

`_shared/entitlements.ts` declares five keys (`ENTITLEMENT_RECEIPT_SCANNER`,
`_ONLINE_MERCHANT`, `_AMBIENT_WIDGET`, `_UNLIMITED_CARDS`, `_AUTO_LOCATION`) plus
`ALL_ENTITLEMENT_KEYS`, and carries the standing instruction in caps:

> *"ONE FILE, ONE DESIGN, TWO KEYS. Neither lane rewrites this file; add keys only."*

Client side, `apps/mobile/src/billing/keys.ts:87` holds the matching `FEATURE_GATES` map
with its `launch` / `restrict` modes, resolved in `src/hooks/useFeatureGate.ts:78`.
Live `entitlement_catalog` holds all five keys, `is_active = true`.

Live `runtime_flags`: `loyalty_offer_stacking` **true**, `merchant_mcc_assumption`
**true**, `tie_disclosure` **true**, `online_merchant_resolution` **true**; `receipt_scanner`,
`ambient_widget`, `card_slot_limit`, `auto_location_gate`, `billing_paywall`,
`network_acceptance` all **false**.

### 1.9 There is no file picker, no camera, and no OCR provider anywhere in the app

Grep across `apps/mobile/src/` for `DocumentPicker|ImagePicker|FileSystem|FormData|multipart|storage.from`
returns **zero hits**. `expo-document-picker`, `expo-file-system`, `expo-camera` and
`expo-image-picker` are absent from `apps/mobile/package.json`. Declared permissions
(`app.config.ts:164`) are location only.

The OCR seam exists with nothing behind it — `src/services/receiptOcr.ts:75`:

```ts
function resolveNativeProvider(): ReceiptOcrProvider | null {
  // No native provider is wired yet. This returns null rather than throwing so
  // that availability is a question the UI can ask cheaply.
  return null;
}
```

APP-021 is already waiting on that module. Adding it is a fingerprint change and cannot
reach existing installs over EAS Update (`app.config.ts:138`), which puts this feature on
the same native release train — 1.0.4 at the earliest, never the in-flight 1.0.3.

### 1.10 There is no Supabase Storage bucket, and that was a decision

No `storage.buckets` insert, no `storage.objects` policy, no `supabase.storage.from(...)`
call exists in any migration, edge function or app file. `apps/mobile/src/services/supabaseStorage.ts`
is a SecureStore session adapter and unrelated. API-017 D1 records why:

> *"the receipt image is never uploaded and never persisted (no Supabase Storage bucket is
> introduced by this spec). Rationale: strongest privacy posture for a Canadian fintech,
> zero per-scan cost, and no new custodial obligation."*

D1 below keeps that property. This design introduces no bucket.

### 1.11 There is no prior art for any of this

A search of `cardcoach-docs/*.md`, `deltas/`, `dispatches/`, `proposals/` and
`docs/planning/` finds **no prior mention** of statement upload, statement import, CSV
import of user transactions, counterfactual card comparison, or a forgone-rewards figure.
Every "statement" hit is a SQL statement or an issuer disclosure; every "CSV" hit is the
retired `card_sources_seed_enriched.csv`.

Two adjacent things do exist and both bind:

- **REVENUE.md:109** models a **"Gap view rate: 30%"** — the surface where a user is shown
  a card they do not hold — as the top web-affiliate funnel. This feature *is* that surface.
- **`DESIGN_online_merchant_v1.md:696-698`, open question 6:** *"**Recommending a card the
  user doesn't hold.** The online moment is the strongest affiliate surface in the product
  — and also the one where 'commission-blind' is most load-bearing. Out of scope here; do
  not let it drift in without its own decision entry."* D7 and D8 are that entry.

---

## 2. Decisions for sign-off

### D1 — Extraction runs on device. The file never crosses the wire.

The phone opens the statement, extracts rows, and discards the file. No upload, no bucket,
no server-side parse of a user document. **Pre-decided by Mike, 2026-08-20.**

**Why this is the whole privacy posture and not a preference.** API-017 chose it for the
receipt image and said so in the app's own copy — `ReceiptCaptureScreen` renders
`receipt-privacy-note`: *"The photo stays on your phone. It is never uploaded or saved."*
A statement is a strictly heavier data class than a receipt: it carries an account number,
a credit limit, a balance, and a full month of behaviour. Uploading one after publishing
that sentence about a receipt would be a posture the product cannot explain.

**Cost, stated honestly.** PDF text extraction and OCR both have to run in the app, which
means the native text-recognition module APP-021 is already waiting on (D12), a document
picker, and the 1.0.4 native train. Server-side parsing would have been faster to build
and more robust across issuer formats. That trade is accepted.

**Rejected for v1:** server parse in memory with nothing persisted. It is defensible and it
is still a user document crossing the wire, which forces new privacy copy, a Law 25 review
of a new collection purpose, and a sentence about statements that does not match the
sentence already shipped about receipts.

---

### D2 — Two calls, and the server is never told both halves.

Resolution and scoring are separate endpoints, and the merchant list and the spend series
never appear in the same request.

- **API-020 `resolve-descriptors-v1`** receives *distinct normalized descriptors only* —
  no amounts, no dates, no ordering — and returns `descriptor → categoryId`.
- **API-021 `analyze-spend-v1`** receives *dated amounts with a category id* — no merchant
  names, no descriptors, no merchant entity ids — and returns the ranking.

The device holds the join and performs it locally.

**Why the token would defeat it.** An opaque `merchantEntityId` on the pass-2 rows would
restore the join exactly — a UUID the server can resolve to a name is a name. So pass 2
carries `categoryId` and nothing else, and the merchant-scoped earn rows that would have
needed identity simply do not price (D9). That is a real capability cost paid for a real
property: neither request, and neither log line, contains "who this person paid, when, and
how much."

**Why not one call.** One call is simpler and it is the entire personal-finance data class
in one POST body. The split costs one endpoint and one round trip and buys a sentence the
product can defend in public. BRAND.md's claim to be "more privacy-conscious than
bank-login-heavy products" is otherwise decorative here.

**Neither endpoint writes.** Enforced the way API-017 enforces it: a structural test that
reads the source and asserts no `.insert(` / `.update(` / `.upsert(` / `.delete(` / `.rpc(`
appears, plus an empirical row-count sweep across the fixture corpus
(`scripts/verify_api_017.mjs` is the template).

---

### D3 — The baseline is the engine, not the statement's rewards line.

"What you actually earned" is computed by replaying the user's spend on the card it was
actually charged to, through the same function that computes the counterfactual. It is not
read off the statement.

**Why both sides must be one function.** `DESIGN_online_merchant_v1.md:625` established
the pattern for a disclosure sitting next to a ranking — compute it by re-scoring the same
in-memory context and diffing, so it cannot drift. Here it is stronger: if the baseline
came from parsed statement text and the alternative came from the engine, every parser bug
and every issuer rounding quirk would land in the headline as a reward difference. Both
sides through `replaySpend()` means the diff isolates exactly one variable — the card.

**What this costs, and it must be disclosed.** The number is *"what our engine says these
two cards would earn"*, not *"what your issuer paid you."* Those differ: welcome bonuses,
targeted promotions, issuer rounding, points posted outside the statement window. The
result screen says so in one line, and §5.3 fixes the wording.

**Consequence:** the card each statement belongs to must be identified. Pre-filled from a
last-4 match against the wallet where the statement carries one; otherwise the user picks
it, from the catalogue rather than only from their wallet, so a statement for a card they
have not added still analyses.

---

### D4 — Spend is partitioned into three buckets, and coverage is shown as a number.

Every parsed row lands in exactly one bucket:

| Bucket | What it is | How it prices |
|---|---|---|
| `priced` | resolved to a live category slug | full category rates, both sides |
| `base_only` | no category resolved, or a category with zero active rates (§1.4) | base rate only, both sides |
| `excluded` | payments, refunds, interest, annual fee, cash advance, balance transfer, any non-positive amount | removed entirely, both sides |

The response carries `coverage.categorizedShare`, and the UI states it:

> *We matched 78% of your spending to a category. The rest is counted at each card's base
> rate, on both cards.*

**Why disclosure rather than a silent best effort.** `base_only` is base-versus-base, so it
barely moves the *diff* — but it shrinks it, and a user comparing our number to their own
arithmetic deserves to know why. WORKING_NOTES #26 already records that an unresolved
merchant scores base-rates-only on the live path; at statement scale that stops being an
edge case and becomes a systematic understatement of the headline.

**Why dead categories go to `base_only` rather than staying mapped.** `online_retail`,
`telecom_internet` and `other` carry zero active rates (§1.4). Mapping to them produces
base-rate scoring while *reporting* the spend as categorized, which is the one outcome
worse than admitting the miss. A category with no active rates is treated as no category,
and the fact is a warning on the response, not a silent behaviour.

---

### D5 — Caps and floors are replayed chronologically, per card, from zero at the window open.

Transactions are sorted by date and replayed one at a time. After each, the running
monthly, annual and pool buckets for every card are incremented, and the next transaction
prices against the updated state. Every candidate card starts the window at zero spend.

**Why zero and not the user's real snapshots.** For a card the user does not hold, no other
starting state exists. For the card they do hold, using their real `user_spend_snapshots`
would price the baseline against a different starting position from every alternative and
make the diff meaningless. Symmetric-from-zero is the only comparison that isolates the card.

**The D2 assumed-prior interaction is load-bearing.** `earnMath.ts:349-403` treats an
*absent* bucket as best-case — prior spend assumed at the start of the highest-rate
windowed row's window — while a bucket that *exists with zero spend* is real data, so
floors are genuinely unmet. Replay must therefore **materialize every bucket at zero
before the first transaction**, or a floored card silently prices at its terminal rate for
the whole window. This is the single easiest way to get this feature wrong, it inflates
exactly the premium cards, and PKG-011 pins it with a dedicated golden fixture (§7.1).

**Cost:** O(transactions) calls to `computeEarnMathV2`, each over 108 cards. §8 sizes it.

---

### D6 — The headline is net of a pro-rated annual fee. The 12-month figure is a labelled projection.

- **Headline:** the observed window. Gross reward difference minus
  `(annual_fee_native × days_in_window / 365)` for each side. This is a fact about the
  user's own data and involves no assumption about future behaviour.
- **Secondary:** a 12-month figure, produced by replaying the observed window repeatedly
  until 12 months are covered, and labelled *"if your spending stays about the same."*

**Why replay rather than multiply.** Annual caps and rising-tier floors do not scale. A
3-month window times four overshoots every annual cap and understates every rising tier.
Repeat-window replay gets the cap arithmetic right; multiplying by four gets it wrong in
whichever direction happens to favour the bigger card.

**Why the fee is not optional.** A comparison that reports gross uplift and mentions the
fee below the fold recommends a $150 card for a $60 gain. `card-value-stats` already
established the convention — `netCents = valueEarnedCents - annualFeeCents` — and this is
the same convention over a stated window.

**Windows shorter than 30 days are refused**, with a message asking for a full statement.
A two-week window pro-rates a fee to $12 and reports a $9 uplift as a win.

---

### D7 — The card the user already holds is answered first.

API-021 computes two answers and the UI renders them in this order:

1. **Better card in your wallet** — the best card among the user's own, when it beats what
   they actually used. Rendered above the fold.
2. **Better card you don't have** — the best of the remaining catalogue.

When (1) exists, it leads. When it does not, the response says so explicitly
(`walletAlternative: null` with a reason) rather than omitting the section, and the UI
renders *"You used the best card you have."*

**Why the order is the decision.** (1) is the answer that makes CardCoach no money, and
(2) lands on the modelled affiliate gap view (REVENUE.md:109). Computing both and putting
the free one first is the operational form of commission-blindness — a policy that only
exists at the data layer is invisible to the user at exactly the moment they are being
shown a card to apply for.

It is also, in practice, the better product. "You already own the card that would have
earned you $180 more — you just weren't using it for groceries" is a sharper insight than
any acquisition pitch, and it is one no affiliate-funded comparison site will ever write.

---

### D8 — Ranking reads value. Nothing else is in the read path.

The sort key is `netValueExactCents` descending, then annual fee ascending with NULL last
("unknown is not zero", per `_shared/tieDisclosure.ts`), then `cardProductId.localeCompare`.
No affiliate, commission, partner or payout column is read, and none exists in the tables
this feature queries.

Availability filters candidates and never orders them: `is_active`,
`scoring_status = 'scoreable'`, `application_status IN ('open','limited')`, and
`availability_scope` / `available_provinces` when the user's province is known. A card that
cannot be applied for is not a recommendation; a card that pays us more is not a better one.

This answers `DESIGN_online_merchant_v1.md` open question 6 for both surfaces, and
REVENUE.md:205-210 already binds the general case: *"This rule contains no affiliate,
commission, or partner input, and none may be added to it… Any future proposal to alter
within-tie ordering must be evaluated against this section and recorded here."*

**Verification, not just policy:** `scripts/verify_api_021.mjs` asserts the response
ordering is a pure function of `netValueExactCents` by re-sorting the returned array and
requiring identity, and a structural test asserts no affiliate-named column appears in any
`.select()` in the function's source.

---

### D9 — What this does not price, it says out loud.

Not priced, and listed on the response as `assumptions[]`:

| Not priced | Why | Direction of error |
|---|---|---|
| `merchant_list_only` rows (55 active) | needs merchant identity, withheld by D2 | under-counts |
| `mcc_defined` rows (168 active) | no MCC on a statement line; `merchant_mcc_assumption` is a per-purchase device | under-counts |
| Loyalty offer stacking | requires merchant identity and a linked programme | under-counts |
| Card benefits | already `includedInValue: false` engine-wide | neutral |
| **Welcome bonuses** | not built anywhere (WORKING_NOTES #5) | **under-counts, heavily, in year one** |
| FX on foreign-currency lines | no authoritative rate; `scoring.ts:1975` refuses conversion | line excluded (D4) |

**The welcome bonus is the one that matters.** A $150 first-year gain from earn rates is
routinely dwarfed by a 60,000-point welcome offer, so the figure this feature shows can be
badly wrong *in the user's favour* about a card's first year. Every one of these errs
toward under-claiming, which is the correct direction under rule 7 — but silence about the
welcome bonus specifically would be misleading, and the result screen names it:

> *This compares earn rates only. It doesn't include welcome bonuses, which can be worth
> more than a year of earnings.*

---

### D10 — Analyse-only is the default. Import is a second, separately gated action.

The analysis path writes nothing. Importing parsed rows into `transactions` is a distinct,
explicitly confirmed action behind its **own** runtime flag, `statement_import_write`,
seeded false and shipped dark. **Mike asked for both, 2026-08-20; this is how both ship
without the second one putting the first at risk.**

**Why the second flag.** `transactions` feeds `maintain_user_spend_snapshots_trigger`,
which feeds cap progress, which feeds every subsequent recommendation, and it feeds
`user-value-stats`, which is the monthly-gain number already on the Now screen. A bad
parse writing there is a data-corruption event on shipped surfaces, not a bad screen.
Analyse-only is API-017's posture and it is the right posture until real statements have
been through the parser. One flag flip enables import, and one flips it back with no
deploy.

**Stated consequence of flipping it:** imported rows enter `user-value-stats`' trailing
window, so the shipped monthly-gain figure moves. That is arguably correct — they are real
purchases — but it is a visible change to a shipped number and it is what the flag is for.

---

### D11 — Import is deduped, batch-tagged, reversible, and only takes rows that resolved.

When `statement_import_write` is on and the user confirms:

- Only rows that resolved to a `merchant_entity` **with a place** are importable.
  `transactions.merchant_id` is `NOT NULL` and D2 of `DESIGN_online_merchant_v1.md` binds:
  *"The runtime never creates an online merchant."* Unresolved rows are analysed and not
  imported; the UI states the count.
- `client_tx_id` is set to a deterministic device-side hash of
  `(cardProductId, date, amountCents, normalizedDescriptor)`, so
  `idx_transactions_user_client_tx` makes re-import idempotent and collides correctly with
  a row the user already recorded by hand.
- Every row carries `import_batch_id`, and `statement_imports` holds the batch. Undo is one
  delete by batch id, which the snapshot trigger unwinds correctly (it clamps subtraction
  with `GREATEST(0, ...)`).
- `value_earned_cents` is left **NULL**. Its contract is "the engine's value at record time
  against real pre-purchase cap state"; a replayed value computed from a zero-based window
  (D5) is a different number, and writing it into that column would quietly redefine the
  column for every reader.

**Rejected:** relaxing `merchant_id` to nullable. It is the honest long-term fix and it
touches `record-transaction`, the history screen and the snapshot trigger. Filed as §9.3.

**REOPENED 2026-08-21.** A measurement taken while building API-022 shows this workaround
bounds the import path to ~9% of the merchant graph (60 `merchants` rows against 567
entities — see §9.3). D11 stands as written for the read path, which is unaffected, but
the write path behind `statement_import_write` should not be enabled until §9.3 is
decided. This is now a precondition of that flag, not a follow-up to it.

**RESOLVED 2026-08-21 (Mike's call, option (b) below). Kept in full because the
contradiction is the interesting part and a future reader needs to see why the contract
changed.** D2 and D11 were asking for opposite things, and the write path was unreachable
from the client. Verified on disk before the fix:

| Fact | Evidence |
|---|---|
| API-022 requires a place id on every row | `statementImportV1.ts:393` — `merchantPlaceId: z.string().uuid()`, not optional |
| API-020 never returns one | zero references to `merchant_entity_places`, `placeId` or `merchantPlaceId` in `resolve-descriptors-v1/index.ts` |
| The device has never heard of one | zero references across `apps/mobile/src/statements/`, `analyzeSpend.ts`, `resolveDescriptors.ts`, `components/statements/` |

So APP-024 cannot construct a valid commit request. This is not an oversight in API-022 —
it is D2 and D11 asking for opposite things, and the contract faithfully encoding both.

**The resolution, and it is cleaner than it looks: D2 is a property of the ANALYSIS path
and cannot bind the import path.** D2 exists so that CardCoach never holds "who this person
paid, when, and how much" for spending the user only wanted analysed. Import is the user
explicitly asking us to *persist that exact join* into `transactions`. The privacy property
D2 protects is not weakened by import; it is the thing the user is opting into. A design
that refuses to carry merchant identity into a write whose whole purpose is to store
merchant identity is not being careful, it is being incoherent.

Two ways to close it, and the choice is Mike's:

**(a) API-020 gains an import-scoped variant** that returns `merchantPlaceId` alongside the
category, callable only on the import confirm step. Keeps the analysis request shape
untouched and makes the scope boundary explicit in the contract. More surface.

**(b) API-022 takes descriptors and re-resolves server-side.** Simpler, fewer moving parts,
and no new exposure — the descriptor, amount and date it receives are precisely the tuple
it is about to write to `transactions` one line later. Recommended.

**Done 2026-08-21: (b).** `zImportSpendRowV1.merchantPlaceId` became
`normalizedDescriptor`, and `import-spend-v1/resolveForImport.ts` re-resolves it read-only
through five tables. 588 Deno tests green.

**D2 is hereby amended in scope, and this is the sentence that governs:** *D2 binds the
ANALYSIS path. `resolve-descriptors-v1` and `analyze-spend-v1` must never be able to hold
the join, and no entity id or place id may appear on either contract. The IMPORT path is
the user consenting to persist that join into `transactions`, and may carry merchant
identity — but only the descriptor the device already sent, never a token that would let
the analysis path acquire one.* A unit test asserts `merchantPlaceId` and
`merchantEntityId` are absent from the import row, so the two paths cannot converge by
accident.

**§9.3 is now closed too (option (b), 2026-08-21), so `statement_import_write` has no
remaining structural blocker.** D11's "importable" rule is amended to read: *a row is
importable when its descriptor resolves to a merchant entity that has a CURATED PLACE.* The
`merchants` row is materialised if it does not exist, because it is a cache of the place,
not a fact about it. What remains before the flag flips is ordinary release work — the
migrations applied, the function deployed, and `verify:api-022` actually run.

---

### D12 — One text-recognition provider serves APP-021 and APP-024.

`src/services/receiptOcr.ts` is generalized to `src/services/textRecognition.ts`, keeping
the existing provider interface verbatim, and both the receipt capture flow and statement
import consume it. **Pre-decided in substance by Mike choosing scanned-PDF support,
2026-08-20.**

```ts
export interface TextRecognitionProvider {
  readonly id: string;
  isAvailable(): boolean;
  requestPermission(): Promise<boolean>;
  recognizeText(uri: string): Promise<string[]>;
}
```

**Why one module.** Two native OCR integrations against two provider seams is two sets of
`__mocks__` entries, two `moduleNameMapper` lines, two permission strings per locale and
two things to break on an Expo upgrade — for one capability. APP-021 is already blocked on
this module; consolidating means the work unblocks both features and neither ships a
half-wired second copy.

**Ordering:** APP-024 does not land before APP-021's provider does. The rename is a
mechanical change to a file with no production implementation behind it today
(`resolveNativeProvider()` returns `null`), so it is cheap now and expensive later.

---

### D13 — A sixth key, in launch mode. `_shared/entitlements.ts` gains a constant and nothing else.

- `ENTITLEMENT_STATEMENT_IMPORT = "statement_import"`, appended to `ALL_ENTITLEMENT_KEYS`.
- `entitlement_catalog` row + `billing_tier_entitlements` grant to the existing
  `cardcoach_pro` tier — two INSERTs, per BILL-001's stated extension point.
- `runtime_flags.statement_import`, seeded **false** (launch mode: false ⇒ invisible to
  everyone), plus `statement_import_write`, seeded false (D10).
- Client: one entry in `FEATURE_GATES` (`apps/mobile/src/billing/keys.ts`), `mode: "launch"`.

Nothing in `_shared/entitlements.ts` is rewritten. The file's own instruction — *"ONE FILE,
ONE DESIGN, TWO KEYS. Neither lane rewrites this file; add keys only."* — exists because
two lanes converged on it in August and the second would have silently redefined the
first's paywall. This lane adds a constant to the list and touches nothing else.

`entitlement_catalog.runtime_flag_key` points at `statement_import`, not the write flag:
the catalogue names the feature the user is buying.

---

### D14 — A card whose annual fee cannot be stated in CAD is never the headline.

Live: **98 scoreable cards with a known CAD fee, 1 with a USD fee, 9 with no fee recorded.**
`scoring.ts:1975` refuses currency conversion because no exchange rate is authoritative.

Such a card is scored, ranked on gross value, and returned with `feeStateable: false` and a
warning — but it cannot occupy the headline slot, because the headline is a net figure and
its fee term is unknown. This follows the tie-disclosure convention already in the codebase:
NULL fee sorts last, unknown is not zero.

---

## 3. Contract draft

### 3.1 Accepted formats (device side, APP-024)

| Format | Path | Notes |
|---|---|---|
| CSV / TSV | pure JS | every big-5 issuer exports it; header sniffing, bilingual column names |
| OFX / QFX | pure JS | SGML-ish; `<STMTTRN>` blocks |
| PDF with a text layer | pure JS extraction | the common case for a downloaded statement |
| PDF / image, scanned | `TextRecognitionProvider` (D12) | lowest confidence; coverage disclosed |

Refused with a clear message, never guessed at: encrypted PDFs, files over 10 MB, files
producing zero candidate rows, and windows under 30 days (D6).

### 3.2 API-020 `resolve-descriptors-v1` — request

```ts
export const zResolveDescriptorsV1Request = z.object({
  schemaVersion: z.literal("v1"),
  locale: z.enum(["en", "fr"]),
  // Distinct, device-normalized, digit-stripped. No amounts. No dates. No order.
  descriptors: z.array(z.string().min(1).max(120)).min(1).max(500),
});
```

### 3.3 API-020 — response

```ts
export const zDescriptorResolutionV1 = z.object({
  descriptor: z.string(),                       // echoed verbatim; the device joins locally
  categoryId: z.string().nullable(),            // canonical slug, normalizeCategoryId applied
  displayName: z.string().nullable(),
  match: z.enum(["exact", "alias", "chain", "domain", "none"]),
  confidence: z.enum(["high", "medium", "low"]),
  /** True when the category resolved but carries zero active earn rates (§1.4). */
  categoryInert: z.boolean(),
});

export const zResolveDescriptorsV1Response = z.object({
  schemaVersion: z.literal("v1"),
  requestId: z.string(),
  resolutions: z.array(zDescriptorResolutionV1),
  warnings: z.array(z.string()),
  computedAt: z.string(),
});
```

### 3.4 API-021 `analyze-spend-v1` — request

```ts
export const zAnalyzeSpendV1Request = z.object({
  schemaVersion: z.literal("v1"),
  locale: z.enum(["en", "fr"]),
  valuationTier: ValuationTierSchema.optional(),   // falls back to user_preferences
  // No descriptors. No merchant ids. No names.
  spend: z.array(z.object({
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    amountCents: z.number().int().positive(),
    categoryId: z.string().min(1).max(64).nullable(),
    /** The card this was actually charged to. Null = unattributed. */
    onCardProductId: z.string().min(1).max(128).nullable(),
  })).min(1).max(4000),
  /** Sum of rows the device excluded (D4), for the coverage figure only. */
  excludedSpendCents: z.number().int().nonnegative().default(0),
  candidateScope: z.enum(["wallet", "catalogue", "both"]).default("both"),
  maxResults: z.number().int().min(1).max(10).default(5),
  /** Filters candidates by availability_scope; never orders them (D8). */
  provinceCode: z.string().length(2).optional(),
  includeProjection: z.boolean().default(true),
});
```

### 3.5 API-021 — response

**REVISED 2026-08-21.** The draft below was written before the contract was implemented,
and the shipped `packages/engine-contracts/src/statementImportV1.ts` differs from it in
six places. **The shipped contract governs**; this block is kept as the design intent.
The differences: `window.months` is an integer, not fractional (the fee pro-rate uses
`days`, so a fractional month was a field nothing read); `capLimitedCents` is
`capLimitedSpendCents`; `capNotes.scope` has no `"card"` value because the replay never
emits one; `display.productFamily` was added; `walletAlternativeReason` gained `no_wallet`;
and `assumptions` gained `uncategorized_priced_at_base` and
`projection_assumes_same_spending`. `zCounterfactualCardV1` also drops the draft's
`valueExactCents` — the unrounded figure is a ranking key, not a wire field, and putting it
on the wire invites a client to re-derive a number the server already decided.

```ts
export const zCounterfactualCardV1 = z.object({
  cardProductId: z.string(),
  rank: z.number().int().positive(),
  held: z.boolean(),                              // already in the user's wallet
  display: z.object({
    cardName: z.string(), issuerName: z.string(),
    networkId: z.string().nullable(), tierNormalized: z.string().nullable(),
    annualFeeNative: z.number().nullable(),
    annualFeeCurrency: z.string().nullable(),
    feeStateable: z.boolean(),                    // D14
  }),
  valueCents: z.number().int().nonnegative(),     // gross, over the window
  valueExactCents: z.number().nonnegative(),
  annualFeeProratedCents: z.number().int().nullable(),
  netValueCents: z.number().int().nullable(),
  upliftCents: z.number().int(),                  // net vs baseline; may be negative
  byCategory: z.array(z.object({
    categoryId: z.string().nullable(),
    spendCents: z.number().int().nonnegative(),
    valueCents: z.number().int().nonnegative(),
    upliftCents: z.number().int(),
    capLimitedCents: z.number().int().nonnegative(),
  })),
  capNotes: z.array(z.object({
    categoryId: z.string().nullable(),
    scope: z.enum(["category", "pool", "card"]),
    period: z.enum(["monthly", "annual"]),
    overCapSpendCents: z.number().int().nonnegative(),
  })),
  warnings: z.array(z.string()),
});

export const zAnalyzeSpendV1Response = z.object({
  schemaVersion: z.literal("v1"),
  requestId: z.string(),
  window: z.object({
    start: z.string(), end: z.string(),
    days: z.number().int().positive(),
    months: z.number(),                            // fractional, for the fee pro-rate
  }),
  coverage: z.object({
    totalSpendCents: z.number().int().nonnegative(),
    pricedSpendCents: z.number().int().nonnegative(),
    baseOnlySpendCents: z.number().int().nonnegative(),
    excludedSpendCents: z.number().int().nonnegative(),
    categorizedShare: z.number().min(0).max(1),
    byCategory: z.array(z.object({
      categoryId: z.string().nullable(),
      spendCents: z.number().int().nonnegative(),
      share: z.number().min(0).max(1),
    })),
  }),
  baseline: z.object({
    kind: z.literal("as_spent"),
    valueCents: z.number().int().nonnegative(),
    annualFeeProratedCents: z.number().int().nullable(),
    netValueCents: z.number().int().nullable(),
    perCard: z.array(z.object({
      cardProductId: z.string(), cardName: z.string(),
      spendCents: z.number().int().nonnegative(),
      valueCents: z.number().int().nonnegative(),
    })),
  }),
  /** D7: rendered first. Null with a reason when they already used their best card. */
  walletAlternative: zCounterfactualCardV1.nullable(),
  walletAlternativeReason: z.enum(["none_better", "single_card_wallet", "not_requested"]).optional(),
  catalogueAlternatives: z.array(zCounterfactualCardV1),
  projection: z.object({
    months: z.literal(12),
    method: z.literal("repeat_window"),
    baselineNetValueCents: z.number().int().nullable(),
    alternatives: z.array(z.object({
      cardProductId: z.string(),
      netValueCents: z.number().int().nullable(),
      upliftCents: z.number().int(),
    })),
  }).nullable(),
  /** D9. Stable ids the client renders from its own locale catalogue. */
  assumptions: z.array(z.enum([
    "merchant_list_rows_not_priced",
    "mcc_defined_rows_not_priced",
    "offers_not_priced",
    "benefits_not_included",
    "welcome_bonus_not_included",
    "engine_value_not_issuer_statement",
    "caps_replayed_from_window_open",
    "fee_prorated_to_window",
  ])),
  warnings: z.array(z.string()),
  valuationTier: ValuationTierSchema,
  asOfDate: z.string(),
  computedAt: z.string(),
});
```

### 3.6 API-022 `import-spend-v1` (dark behind `statement_import_write`)

Request carries the importable subset with a resolved `merchantPlaceId` per row, a
device-computed `clientTxId`, and an `idempotencyKey` for the batch. Response returns
`{ batchId, inserted, skippedDuplicate, skippedUnresolved }`. Undo is
`DELETE FROM transactions WHERE user_id = auth.uid() AND import_batch_id = $1`, exposed as
a second method on the same function.

### 3.7 What does not change

`recommend-card-v2`, `recommend-here-v2` and `recommend-cards-stateless-v1` are untouched.
No new explanation item type; `explanation_v2` is not widened (this feature does not emit
`StructuredExplanationV2` at all — its breakdown is `byCategory`, a different shape for a
different question). `packages/engine`'s existing exports are unchanged; PKG-011 is
additive.

---

## 4. Schema proposal (DATA-022)

Four parts, four migration files, per the `online_merchant_p1..p4` precedent.

### 4.1 p1 — the entitlement key and the flags

```sql
INSERT INTO public.entitlement_catalog
  (entitlement_key, label, description, feature_ids, runtime_flag_key, is_active)
VALUES ('statement_import', 'Statement analysis',
        'Upload a statement and see what a different card would have earned.',
        ARRAY['API-020','API-021','APP-024'], 'statement_import', true)
ON CONFLICT (entitlement_key) DO NOTHING;

INSERT INTO public.billing_tier_entitlements (tier_key, entitlement_key)
VALUES ('cardcoach_pro', 'statement_import')
ON CONFLICT DO NOTHING;

INSERT INTO public.runtime_flags (key, enabled, note) VALUES
  ('statement_import', false,
   'API-020/API-021/APP-024 statement analysis. Global gate; per-user access also requires '
   'the statement_import entitlement. New feature, so false = dark. Flip only after a store '
   'build ships — the flow needs the native text-recognition module and cannot reach '
   'existing installs over EAS Update.'),
  ('statement_import_write', false,
   'DESIGN D10: opt-in import of parsed statement rows into transactions. Names the CHANGE: '
   'false = analyse-only, which is the shipping behaviour. Flipping true makes imported rows '
   'visible to the snapshot trigger and therefore to cap progress and user-value-stats.')
ON CONFLICT (key) DO NOTHING;
```

- **Read-path impact:** none while both flags are false. `entitlement_catalog` gains a row
  the paywall renders on next launch; add it to `PITCH_ORDER` in
  `apps/mobile/src/billing/useProFeatures.ts` to control placement.
- **Rollback:** `supabase/rollback/data_022_down.sql` — delete the three rows by key.
- **Guard discipline:** post-condition assertion that exactly one catalogue row and two
  flag rows exist and both flags are false.

### 4.2 p2 — the import batch (dark)

```sql
CREATE TABLE IF NOT EXISTS public.statement_imports (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_kind   text NOT NULL CHECK (source_kind IN ('csv','ofx','pdf_text','pdf_ocr')),
  window_start  date NOT NULL,
  window_end    date NOT NULL,
  row_count     integer NOT NULL CHECK (row_count >= 0),
  imported_at   timestamptz NOT NULL DEFAULT now(),
  reverted_at   timestamptz,
  CONSTRAINT statement_imports_window CHECK (window_end >= window_start)
);
-- Deliberately absent: the file, the descriptors, the account number, any merchant name.
```

RLS follows the ENT-001 server-owned / read-own pattern: `ENABLE` + `FORCE`, a
`select_own` policy, `REVOKE INSERT, UPDATE, DELETE FROM anon, authenticated`,
`GRANT SELECT TO authenticated`, and no `DEFAULT auth.uid()` — the client never inserts here.

### 4.3 p3 — the batch tag on transactions

```sql
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS import_batch_id uuid
    REFERENCES public.statement_imports(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_import_batch
  ON public.transactions(import_batch_id) WHERE import_batch_id IS NOT NULL;
```

- **Read-path impact:** additive and nullable. Every existing reader ignores it; every
  existing row has NULL. No trigger reads it.
- **Rollback:** `ALTER TABLE public.transactions DROP COLUMN IF EXISTS import_batch_id;`

### 4.4 p4 — account deletion

`supabase/functions/delete-account/index.ts` must cover `statement_imports`. The
`ON DELETE CASCADE` on `user_id` handles it at the database level; the function's explicit
table list is updated so the two do not drift, and `verify_data_022.mjs` asserts the table
appears in that list. ENT-001 invariant 7 and BILL-001 invariant 11 both require this.

---

## 5. Privacy

A statement is the heaviest data class this product has touched. This section is
first-class rather than a paragraph inside §8 for that reason.

### 5.1 What is collected, and where it goes

| Datum | Leaves the device? | Persisted? |
|---|---|---|
| The statement file | **No** (D1) | Never |
| Account number, credit limit, balance, payment due | **No** — stripped at parse, never in any payload | Never |
| Merchant descriptors | Yes, to API-020 — distinct set only, digits stripped, no amounts, no dates | **No** — API-020 writes nothing |
| Dated amounts + category ids | Yes, to API-021 — no merchant names | **No** — API-021 writes nothing |
| Card last-4 | Only for the local wallet match; never sent | Never |
| Imported rows (D10, dark) | Yes, on explicit confirmation | Yes, in `transactions`, reversible by batch |

The device strips any token matching a card-number or account-number shape before a
descriptor enters a payload, and strips trailing digit runs from descriptors regardless
(`TIM HORTONS #1234` → `tim hortons`), which is both a privacy measure and better for
chain matching.

### 5.2 Logging

Same discipline as `parse-receipt`, which ends its success log with
`// Deliberately NOT logged: any receipt text, any amount, any last-4.` Neither API-020 nor
API-021 logs a descriptor, an amount, a date, a category distribution, or a card id.
Logged: request id, row count, duration, coverage share as a rounded percentage, and the
error code on failure. `_shared/pii.ts` applies.

### 5.3 What the user is told, and where

Before the picker opens, on the same surface as the file choice — not buried in a settings
page:

> **Your statement stays on your phone.**
> We read it here, on this device. The file is never uploaded and never saved. To work out
> what each purchase earns, we send store names on their own, and amounts on their own —
> never together.

On the result screen, immediately under the figure:

> Based on CardCoach's earn-rate data, not the rewards printed on your statement. Doesn't
> include welcome bonuses.

Voice check against `BRAND.md`: no banned words, no "AI", no exclamation marks, leads with
the answer, and the Checkout Test passes — you could say all of it out loud.

### 5.4 Law 25

`COMPLIANCE_loyalty_stacking_pack_2026-08-01.md:35` is the template: the privacy policy's
collection list must name this, with purpose and deletion path. Two sentences to add, and
one that is already true and worth stating: **no data is pulled from banks; the user hands
us a file they already have.** The deletion path is the existing `delete-account` cascade
plus per-batch undo (D11). Both the `/en/` and `/fr/` policy pages need it, rewritten
rather than translated per `BRAND.md:199-204`.

---

## 6. The data work (this is the real cost)

### 6.1 Descriptor normalization — new, and the feature lives or dies on it

`normalizeMerchantName` handles Google place names. Statement descriptors need a stage in
front of it, all of it pure and fixture-tested:

- strip processor prefixes: `SQ *`, `TST*`, `SP `, `PAYPAL *`, `PP*`, `AMZN Mktp CA*`,
  `EBAY O*`, `WWW.`, `IC*`, `POS `, `PURCHASE `, `ACHAT `
- strip trailing store/reference numbers and terminal ids
- strip a trailing city + province token pair against a Canadian province list
- collapse the truncation artefacts issuers produce at 22 and 25 characters
- then hand the remainder to the canonical `normalizeMerchantName`

Then: exact `normalized_name` → `merchant_entity_aliases` → `findChainEntityMatch` against
the 48 curated chains → `merchant_domains` for the online ones (141 rows from DATA-020) →
`none`.

### 6.2 Chain curation is the highest-leverage data lane here

48 curated chains against 567 entities. Every chain added lifts coverage across every
future statement, and coverage is the number this feature shows the user (D4). The obvious
gaps for a Canadian statement — the grocery banners, the pharmacy chains, the coffee and
fast-food brands, the gas brands, the telcos — are a bounded, reviewable list.

This is ordinary DATA-lane work under rule 9: a dated delta, expire-then-insert, guards,
and a `verify` run. It is also the single thing most likely to make v1 feel good or feel
broken, and it should start before the code does.

**CORRECTED 2026-08-21.** The paragraph above is wrong in one important way, found while
drafting the delta: **`is_chain` is not this feature's flag.** It has four readers and two
of them are LIVE in production today —

| | |
|---|---|
| `resolve-place/index.ts:532` | **LIVE** — `matchChainEntity` |
| `recommend-here-v2/index.ts:300` | **LIVE** — `matchChainEntity` |
| `resolve-descriptors-v1/index.ts` | dark (API-020, flag off) |
| `_shared/receiptProposal.ts` | dark (API-017, flag off) |

So flipping a brand to `is_chain = true` changes what the shipped app resolves on the very
next request. It is not a change that waits for `statement_import`.

The direction is favourable — `matchChainEntity` runs only on an exact-match miss, the
path that would otherwise mint a per-location entity ("Tim Hortons Stanley Park") that no
eligible-merchant list and no offer scope references, which is the 2026-08-02 defect the
flag exists to fix. But "favourable direction" is not "no read-path impact", and this
document said the latter. Chain curation needs its own review against the live resolvers,
not sign-off as a sub-task of this feature.

A proposed p1 covering 32 head-of-statement Canadian brands is drafted at
`deltas/2026-08-20__merchant_entities__chain_curation_p1_PROPOSED.sql`, marked NOT APPLIED.

**And a defect underneath the curation, found 2026-08-21.** `merchant_entities.normalized_name`
carries two incompatible conventions. Measured on `hrzpznlpmxxrbtwskacu`:

| | |
|---|---|
| space-separated rows | 530 |
| underscore-joined rows | **37** |
| cross-style duplicate brands | **10** |
| …of those, with conflicting `default_category_id` | **7** |
| underscore rows flagged `is_chain` | **0** |

`normalizeMerchantName` strips `_` as punctuation and emits the space form, so the 37
underscore rows can never be hit by an exact match — and none of them is a curated chain,
which is consistent with them being the dead half of each pair. Ten brands therefore exist
twice with only one reachable, and seven of those pairs disagree about the category.

This suppresses the coverage figure D4 shows the user independently of how many chains are
curated, and adding chains on top of a split key set makes the duplication worse rather
than better. It should be resolved before, or with, the p1 delta — not after.

*(An earlier report put these at 372 / 19; the figures above are the re-measured ones.)*

### 6.3 The observation lane, not the self-heal lane

Unresolved descriptors are **not** written back as new entities. WORKING_NOTES #26 records
that the self-heal writes were removed for good reason, and D2 of
`DESIGN_online_merchant_v1.md` binds: the runtime never creates a merchant.

The right lane already exists: `public.propose_merchant_category(uuid, text, text, text, text)`
into `verify.merchant_category_observations`, `SECURITY DEFINER`, service-role only. A
future slice may record an anonymized, frequency-only observation there — *"this normalized
string appeared and did not resolve"*, with no user id and no amount — to drive curation.
**Out of scope for v1**, because a queue nobody drains is worse than no queue, and because
it needs its own privacy read.

### 6.4 The CSV category hint

Some issuer CSV exports carry the issuer's own category column. Where present it is used as
a **secondary** signal, mapped through a small curated table, never inventing a mapping, and
never overriding a confident entity match. Rule 7 applies: an unmapped issuer category
resolves to `null`, not to a guess.

---

## 7. Rollout

1. **PKG-011** — `packages/engine/src/v2/statementReplay.ts` + contracts + vitest suite +
   QA-011 golden fixtures. Pure math, no I/O, no dependency on anything unbuilt. Ships
   inert: nothing imports it.
2. **DATA-022 p1–p4** — migrations, flags seeded false, rollback files, `verify_data_022.mjs`.
   Read-path impact none.
3. **API-020 + API-021** — edge functions, Deno tests, structural no-write tests,
   `verify_api_021.mjs`. Refuse every caller while `statement_import` is false; the
   entitlement check refuses again behind it.
4. **D12 rename** — `receiptOcr.ts` → `textRecognition.ts`, provider interface unchanged,
   APP-021 call sites updated. Mechanical, no behaviour change.
5. **APP-024** — picker, parsers, screens, en/fr strings, gate. Rendered only when flag and
   entitlement both resolve true, so it is invisible in production throughout.
6. **Native module** — text recognition + document picker, `__mocks__` + `moduleNameMapper`
   entries, InfoPlist strings in `apps/mobile/locales/{en,fr}.json`, Android manifest.
   **Fingerprint change: 1.0.4, not the in-flight 1.0.3.**
7. **Flip `statement_import` true** — after a store build ships on both platforms and a
   production probe is green. **Kill switch: flip it false, no deploy.**
8. **Later, separately: flip `statement_import_write`** — after real statements have been
   through the parser and the coverage figure is known.

**Verification, per house discipline:** `pnpm verify:data-022` (catalogue/flag/tier parity,
`delete-account` coverage), `pnpm verify:api-021` (no-write sweep, D8 ordering identity,
replay-vs-`recommend-cards-stateless-v1` agreement on a single-transaction window),
`pnpm verify:qa-011` (parser fixture corpus), `pnpm verify:i18n-parity`,
`pnpm verify:engine-bundle`, and `pnpm engine:bundle` before any edge deploy. All wired
into `scripts/verify_all.mjs`.

**Suggested slice ids, following the current numbering** (highest today: API-019, APP-023,
DATA-021, PKG-010, QA-010): **PKG-011, DATA-022, API-020, API-021, API-022, APP-024, QA-011.**

**Collisions to watch.** APP-021's native module (same train, same file — D12 resolves it).
BILL-001's paywall (add to `PITCH_ORDER`, do not advertise before APP-024 ships — the same
warning BILL-001 already carries about `online_merchant_resolution`). AND-001's Play
closed-testing gate is still open and this feature is on both platforms. Rule 9(f):
re-read live state before any write; this doc's counts are from 2026-08-20 and will move.

---

## 7a. Build status — 2026-08-21

Built in one session at Mike's direction ("you are now head of the design and
implementation"). Everything below is **inert in production**: both runtime flags are
seeded `false`, the migrations carry `STATUS: NOT YET APPLIED`, and the mobile entry point
renders nothing until a flag and an entitlement both resolve true.

### Landed

| Slice | State | Verification actually run |
|---|---|---|
| **PKG-011** `packages/engine/src/v2/statementReplay.ts` | Done | 40 vitest tests; full engine suite **183 passing**, including the 89 pre-existing earn-math tests unchanged |
| **PKG-011** `spendBucketForRow` + `toEngineRate` exports | Done | additive; no behaviour change, pinned by the existing suites |
| **Contract** `packages/engine-contracts/src/statementImportV1.ts` | Done | round-tripped in the Deno suite |
| **API-020** `resolve-descriptors-v1` + `_shared/statementDescriptors.ts` | Done | 74 Deno tests |
| **API-021** `analyze-spend-v1` + `ranking.ts` + `rateLimit.ts` | Done | 59 + 13 Deno tests; `deno check` clean |
| **DATA-022** p1–p3 + rollback + `verify_data_022.mjs` | Written, **not applied** | applied and rolled back twice against a throwaway Postgres 16 cluster; every post-condition assertion fires; assertions negative-controlled |
| **APP-024** parsers, services, picker seam, two screens, 15 components | Done | 131 parser tests + 275 service tests + 59 component tests |
| **QA-011** statement fixture corpus | Done | 10 synthetic bilingual statements, each with a hand-derived `.expected.json` |
| **D12** `receiptOcr.ts` → `textRecognition.ts` | Done | `receiptOcr.ts` kept as a re-export shim; APP-021's call sites unchanged |

Totals: **536 Deno tests, 183 vitest tests, 465 jest tests, 0 failures.** i18n parity holds
at 882 keys per locale.

### Two defects found during the build, and fixed

**D14 was implemented as a tie-break and did not hold.** `netExact` carries a card's GROSS
value when its fee cannot be stated in CAD, and the comparator sorted on `netExact` first —
so a card with no recorded fee could beat a real card's net and ship as the headline with
`netValueCents: null` underneath it. Live, 9 scoreable cards carry no recorded fee and 1
carries a USD fee, so this was reachable, not theoretical. Fixed by making D14 a **hard
partition** ahead of value — the same shape API-019 gives network acceptance, for the same
reason: the two groups are not comparable on the primary key. `canHeadline()` additionally
guards both headline slots, because D14 is a property of the slot and not only of the sort.
The comparator was extracted to `analyze-spend-v1/ranking.ts` so D8 and D14 are now tested
as behaviour rather than as a substring of the handler's source.

**A legitimate request answered `500 internal`.** `candidateScope: 'wallet'` with an empty
wallet and no attributed rows produced an empty candidate set, which the handler treated as
a failure. Nothing had failed; there was simply nothing to compare. It now answers 200 with
`walletAlternativeReason: 'no_wallet'` — a value the enum already carried.

Also closed: an unbounded `onCardProductId` fan-out (a malformed client could force ~100
reference round trips; now capped at 25 distinct cards), the missing D14 warning text, and
a `upliftCents` contract comment that described net-vs-net semantics the code does not
always have.

### Not built, deliberately

- **API-022 `import-spend-v1`** (D10/D11). Designed, flagged, and not written. `FLAG_STATEMENT_IMPORT_WRITE` exists and nothing reads it. The analysis path writes nothing, which is the whole point of shipping the read path first.
- **The native modules.** `resolveNativeProvider()` returns `null` in both the text-recognition and document-picker seams, so in a release build the entry point renders nothing and the screen opens in `unavailable`. The install checklist is in `statementPicker.ts`'s header. Fingerprint change: **1.0.4, not the in-flight 1.0.3.**
- **§9.2, the free-teaser question.** Unanswered, so the whole result screen sits behind the single gate. One boolean and one branch when it is answered.

### Before this ships

1. Sign off D1–D14 (§2). Nothing below waits on anything else.
2. Apply DATA-022 p1–p3 under rule 9 — snapshot, dated delta, guards, local migration file in the same turn.
3. `pnpm engine:bundle`, then deploy `resolve-descriptors-v1` and `analyze-spend-v1`.
4. Run `pnpm verify:data-022` and `pnpm verify:api-021` against a live stack. **Neither has ever been executed** — this container has no Supabase client and no local stack. Until they run, treat them as written, not as passing.
5. Land APP-021's text-recognition provider, then the document picker (D12 ordering).
6. §5.4 Law 25 copy on the `/en/` and `/fr/` privacy pages.
7. Store build on both platforms, production probe, then flip `statement_import`.
8. Later and separately: `statement_import_write`.

### Two things a reviewer should look at hardest

- **The D5 zero-bucket materialization** in `statementReplay.ts`. If it is wrong, every rising-tier card is inflated for the whole window, it fails silently, and it fails in the direction that flatters premium cards. It has a dedicated golden test that pins the difference against the same purchase priced with no snapshots — read that test first.
- **`_shared/statementDescriptors.ts` and its device twin.** Coverage of this module is the number the user is shown (D4), and the two copies are held byte-identical by a test. Both are lookbehind-free because Hermes can throw on a lookbehind at module load, which would be an import-time crash in a release build rather than a parse failure. The rewrite was differential-fuzzed against the originals over 401,301 strings with zero mismatches.

---

## 8. Cost

**Compute. MEASURED 2026-08-21**, replacing this section's original 1–3 s estimate.
Benchmarked against 108 synthetic cards carrying 6 earn rates each, a realistic mix of
capped, floored and points-valued rows:

| Rows | Cards | Wall clock |
|---|---|---|
| 150 | 108 | 216 ms |
| 500 | 108 | 226 ms |
| 1,500 | 108 | 566 ms |
| 150 × 4 passes (the D6 projection) | 108 | 283 ms |

Comfortably inside budget, and roughly an order of magnitude faster than estimated. The
4,000-row contract ceiling extrapolates to ~1.5 s. One reference-context load per request,
not per transaction — the `recommend-here-v2` shape.

**One structural finding worth recording.** PostgREST caps a response at `max_rows`
(1000, `supabase/config.toml`). 108 scoreable cards carry 636 active earn rates, so a
whole-catalogue `loadReferenceScoringContext` call sits at 64% of that ceiling today and
would **silently truncate — not error —** as the catalogue grows. This feature is the first
caller to ask for the whole catalogue at once, so it is the first to hit it. API-021 loads
in chunks of 40 cards and merges the reference maps. The underlying loader is unchanged and
still has no `.limit()`; every other caller passes 25 ids or a wallet, so none of them is
near the ceiling. Flagged rather than fixed in place, because changing a loader on three
shipped ranking paths is not this ticket.

**Marginal cost per analysis: zero.** No OCR API, no LLM, no storage, no third-party call.
Parsing is on-device (D1); the server does arithmetic over data it already holds. Margin is
unaffected by usage, the same property `DESIGN_online_merchant_v1.md §7` records.

**Build.** The expensive parts are not the endpoints. In rough order: the parser corpus
(§6.1, QA-011) and the chain curation (§6.2), then the native module (D12, shared with
APP-021), then the result screen, then the two endpoints, then PKG-011 — which is the most
delicate but also the most contained, because it is pure and golden-testable.

**Revenue.** None attributed. REVENUE.md:161-163 is explicit that the paid tier carries no
conversion or churn assumption and that *"any revenue attributed to it would be invented,
which rule 7 forbids."* That holds here. What can be said without inventing anything:
REVENUE.md:109 already models the gap view at a 30% view rate, three times the insights
view — the surface is modelled, the price of this feature on it is not.

---

## 9. Open questions

1. **The colour of the number.** Sage `#3CB58C` (dark: `#4CC79A`) is the earned-value
   colour; red is banned as an action colour; copper is Pro-tier only. A *forgone* figure
   has no precedent. **Recommendation:** frame it forward — *"you could earn +$247"* — and
   render it sage. Gain framing is on-voice ("Encouraging"), avoids the colour problem
   entirely, and is more honest about what the number is: a projection of a better choice,
   not a debt. The loss framing tests better and I would not ship it.

2. **Free teaser.** Mike chose Pro on both platforms, and the paywall now has something
   concrete to show. Whether the *headline figure alone* is free — analysis runs, the number
   renders, the per-card breakdown and the wallet answer are Pro — is a conversion question
   this doc cannot answer. It costs one boolean in API-021's projection and one branch in
   the UI. Worth a decision before APP-024's screens are final, not before.

3. **`transactions.merchant_id NOT NULL`.** D11 works around it by importing only resolved
   rows. The honest fix is to relax it and let a categorized-but-unattributed transaction
   exist. Touches `record-transaction`, the history screen and the snapshot trigger; needs
   its own DATA ticket and its own read-path analysis.

   **ESCALATED 2026-08-21, on a measurement taken while building API-022.** This is not a
   refinement. It is the thing that decides whether the import path works at all.

   D11's rule reads "only rows that resolved to a merchant entity **with a place**." Because
   the runtime may not create a `merchants` row (`DESIGN_online_merchant_v1` D2), the
   operative rule is narrower: only rows whose place **already has** a `merchants` row —
   i.e. places someone has already visited through the app. Read on
   `hrzpznlpmxxrbtwskacu`, 2026-08-21:

   | | |
   |---|---|
   | `merchant_entities` | 567 |
   | `merchant_entity_places` | 583 |
   | `merchants` rows | **60** |
   | entities reachable from a `merchants` row | **52** |

   So roughly **9% of the merchant graph is importable today**, and the rest of a statement
   lands in `skippedUnresolved` no matter how well API-020 resolved it. The number will
   grow with usage, but it grows from 60 — and a user's first import is exactly when it is
   smallest.

   **DECIDED 2026-08-21 (Mike): option (b).** Built, 589 Deno tests green.

   The three options were: (a) relax `merchant_id` to nullable; (b) let the import path
   mint `merchants` rows from *already curated* places; (c) leave it.

   **(b) won on a measurement I had not taken when this section was first written.**

   | | |
   |---|---|
   | `merchant_entities` total | 567 |
   | …with a curated **place** | **502** |
   | …with a `merchants` row | **52** |

   The merchant graph is 89% curated. What was missing was not curation — it was rows in
   a *lazily-populated cache*. `merchants` is keyed on `place_id` and only gets a row when
   somebody actually taps a card at that place; `record-transaction/index.ts:292` already
   mints one on the manual path, from exactly three fields: the curated place, the entity's
   display name, and the entity's default category.

   **So D2 never bound this.** D2 protects the CURATED graph — `merchant_entities` and
   `merchant_entity_places` — and those remain absolutely unwritable from any request path.
   `merchants` is a downstream projection of them. My earlier framing of (b) as "narrower
   than D2 forbids" was too tentative: it is not a narrowing of D2, it is outside its scope,
   and the manual path has been doing it since the beginning.

   **The bound that makes it safe:** a mint is only ever attempted for a place that ALREADY
   EXISTS in `merchant_entity_places`. A bad parse cannot create a place or an entity. The
   worst it can do is materialise a row for a real curated place nobody has visited yet —
   which the first visit would have created anyway.

   **Why (a) lost.** Two readers break, and one breaks silently:
   `set_transaction_category_id` derives the category via `SELECT category_id FROM merchants
   WHERE id = NEW.merchant_id`, so a null merchant yields a null category and **the row never
   reaches `user_spend_snapshots`** — an imported transaction that does not move your caps is
   worse than one you did not import. `fetchHistoryPage` (`api.ts:972`) would also render it
   nameless. Fixing both means passing an explicit `category_id` on import, which breaks
   API-017's "no second category authority" precedent. Schema change, trigger change, client
   change, for a worse outcome than (b).

   **What this actually buys, and it is the real argument:** (b) moves the bottleneck from a
   table nobody curates to a table you are already curating. After it, what limits import is
   descriptor resolution — chain curation and the `normalized_name` split (§6.2) — which is
   precisely the work already in flight. Before it, those improvements were capped at 9%
   however good they got.

   **Conditions attached, both implemented:** mint only from an existing place, never create
   one; and log `merchantsMinted` per batch so a spike is visible (a count near the distinct
   descriptor count means resolution is matching things it should not, and the table is being
   inflated as a symptom).

   **Fenced by test, not by convention.** `merchants` is now in API-022's writable set, but
   invariant 1b asserts it is INSERT-only, written from `mintMissingMerchants` alone, with no
   write anywhere earlier in that module, and with the inserted `place_id` taken from a
   `PendingMint` rather than from anything on the request. The four curated tables stay
   absolutely unwritable.

   Nothing about the ANALYSIS path is affected — it never touches `merchants`. This bounds
   the write path only, which is why shipping the read path first (D10) was the right call
   and looks better in hindsight than it did when written.

4. **Retiring `cardValue.ts` onto PKG-011.** Once the replay exists and is golden-tested,
   `card-value-stats` and `user-value-stats` are running a weaker fork of it (§1.5) and
   will disagree with this feature on the same wallet. Reconciling them is real work with a
   visible consequence — the shipped monthly-gain number would move — and it deserves its
   own decision entry rather than riding in on this one.

5. **Multi-card statements and the consolidation question.** The design handles per-row card
   attribution, so *"if all of this had gone on one card"* falls out for free. Whether that
   is the headline for a multi-card upload, or a second panel under it, is a UX call best
   made against a real result screen.

6. **Web.** Mike scoped v1 to iOS + Android. The web app already renders a
   `ProductRecommendationTool` and an `assumedSpendProfile`, and a statement analyser there
   would land on the modelled affiliate funnel with a real number instead of an assumed
   profile. It also puts D7 and D8 under their hardest test. Deferred, deliberately, and
   worth revisiting once the Pro tier has conversion data.

---

## Appendix A — verification log

| Claim | Check |
|---|---|
| 149 card_products, 108 scoreable, 41 load_only, 15 issuers | `select count(*) … from card_products` on `hrzpznlpmxxrbtwskacu`, 2026-08-20 |
| 636 active earn rates, 505 category rows | `select count(*) from v_active_earn_rates [where basis='category']` |
| 74 rows with an inline cap, 7 floored, 10 `window_bucket='card'` | `v_active_earn_rates` predicate counts, same read |
| 161 active card_caps across 63 `pool:` groups | `select count(*), count(distinct condition) from v_active_card_caps where condition like 'pool:%'` |
| 55 `merchant_list_only`, 168 `mcc_defined` active rows | `v_active_earn_rates` grouped by `condition_type` |
| 567 merchant_entities, 48 is_chain, 46 aliases, 72 NULL category | `select count(*) from merchant_entities …` |
| `online_retail`, `telecom_internet`, `other`, `costco` carry 0 active rates | `categories LEFT JOIN v_active_earn_rates` grouped, same read |
| 98 CAD fees known, 1 USD, 9 unrecorded (scoreable only) | `card_products` predicate counts |
| Ten runtime_flags, four true | `select key, enabled from runtime_flags` |
| Five entitlement_catalog keys, all active | `select entitlement_key, is_active from entitlement_catalog` |
| No storage bucket anywhere | `grep -rn "storage.buckets\|storage.objects\|storage.from(" supabase/ apps/` → 0 |
| No file picker / camera / FS module in the app | `grep -rn "DocumentPicker\|ImagePicker\|FileSystem\|FormData\|multipart" apps/mobile/src/` → 0 |
| `resolveNativeProvider()` returns null | `apps/mobile/src/services/receiptOcr.ts:75` |
| `buildCatalogScoringContext` zeroes snapshots | `supabase/functions/_shared/scoring.ts:1017-1018` |
| Stateless cardProductIds capped at 25 | `packages/engine-contracts/src/recommendCardsStatelessV1.ts` |
| `cardValue.ts` drops annual caps, floors, pools, window_bucket | `supabase/functions/_shared/cardValue.ts` header + `combineSlot` |
| "add keys only" instruction | `supabase/functions/_shared/entitlements.ts`, header block |
| No prior mention of statement/CSV import or counterfactuals | `grep -rin "statement upload\|statement import\|counterfactual\|forgone"` across `cardcoach-docs/` and `docs/planning/` → 0 |
| Commit under review | `67e7945` — *"engine: regenerate vendored contracts bundle — networkAcceptance (API-019) + resolveMerchantV1 (API-018)"* |

---

*This document is the design. Nothing in §7 starts until D1–D14 are signed off, except
step 1 (PKG-011), which is pure math behind no gate and whose correctness is independent
of every decision above except D5.*
