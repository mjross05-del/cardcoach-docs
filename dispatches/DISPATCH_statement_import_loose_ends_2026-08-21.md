# DISPATCH — Statement import: loose ends after the 2026-08-21 build

For: a coding runtime on `CardCoachv2/mobile_app_codebase`, or a fresh Cowork session.
Governing doc: `cardcoach-docs/DESIGN_statement_import_v1.md` — read §7a (Build status)
first; it is the accurate inventory of what exists. D1–D14 in §2 are **not yet signed off**,
so nothing here may change a decision, only implement one.

Rule 9(f) applies: the database and the tree have moved since the design doc's counts were
taken (2026-08-20). Re-read live state before any write.

---

## State on arrival

Landed and green: PKG-011 (`packages/engine/src/v2/statementReplay.ts`), API-020
(`resolve-descriptors-v1`), API-021 (`analyze-spend-v1`), DATA-022 p1–p3 (**not applied**),
APP-024 (parsers, services, two screens, 15 components), QA-011 (10-fixture corpus).
536 Deno + 183 vitest + 465 jest tests, 0 failures. Mobile typecheck and ESLint clean.

Inert by construction: `runtime_flags.statement_import` and `.statement_import_write` are
both seeded `false`; migrations carry `STATUS: NOT YET APPLIED`; the native picker and
text-recognition providers both return `null` in a release build.

---

## Lane A — the missing paper trail (do this first; it is small and everything else needs it)

The repo convention is one spec per ticket id under `docs/planning/specs/<ID>_<slug>.md`,
registered in `docs/planning/01_feature_inventory.md`. **This build shipped seven ticket
ids and zero spec files.** That is the gap that makes the rest undiscoverable.

Write, using `_template.md` and matching the density of `API-017_receipt_parse.md`:

- `PKG-011_statement_replay.md` — the replay, D5's zero-bucket rule, why it is not `cardValue.ts`
- `DATA-022_statement_import_schema.md` — the two flags, the entitlement key, `statement_imports`
- `API-020_resolve_descriptors.md` — descriptors in, categories out, no amounts
- `API-021_analyze_spend.md` — the counterfactual, D7/D8/D14
- `APP-024_statement_import_ui.md` — the flow, the gate, the D12 shared module
- `QA-011_statement_fixture_corpus.md` — the corpus and what each fixture pins

Then add the rows to `01_feature_inventory.md`. Do not renumber anything: API-020/021/022,
APP-024, DATA-022, PKG-011, QA-011 are taken as of 2026-08-21.

---

## Lane B — API-022 `import-spend-v1` (D10/D11), dark

Designed in §3.6 and §4, not built. `FLAG_STATEMENT_IMPORT_WRITE` exists in
`apps/mobile/src/billing/keys.ts` and nothing reads it.

Build it behind **both** `statement_import` and `statement_import_write`, in that order,
flag before entitlement, copying `analyze-spend-v1`'s handler shape exactly.

Binding constraints from D11 — none of these is negotiable:

- Only rows that resolved to a `merchant_entity` **with a place** are importable.
  `transactions.merchant_id` is `NOT NULL`, and `DESIGN_online_merchant_v1` D2 binds:
  the runtime never creates a merchant. Unresolved rows are analysed, not imported, and
  the response reports the count.
- `client_tx_id` is a deterministic **device-side** hash of
  `(cardProductId, date, amountCents, normalizedDescriptor)`, so
  `idx_transactions_user_client_tx` makes re-import idempotent and collides correctly with
  a row the user already recorded by hand.
- Every row carries `import_batch_id`; the batch row goes in `statement_imports`.
- `value_earned_cents` stays **NULL**. Its contract is "the engine's value at record time
  against real pre-purchase cap state"; a replayed value from a zero-based window is a
  different number and writing it there would quietly redefine the column for every reader.
- Undo is a second method on the same function:
  `DELETE FROM transactions WHERE user_id = auth.uid() AND import_batch_id = $1`.
  The snapshot trigger unwinds it correctly (it clamps with `GREATEST(0, ...)`).
- Bulk insert fires `maintain_user_spend_snapshots_trigger` once per row. Measure it. Do
  **not** disable the trigger in a request path — `0045` only does that inside a migration.

Tests: the structural no-write suite does not apply here (this function writes), so replace
it with an equally explicit one — assert the only tables written are `transactions` and
`statement_imports`, assert the entitlement uses the user client, and assert idempotency by
importing the same batch twice against a local stack.

**Then state plainly in the spec what flipping `statement_import_write` changes on shipped
surfaces:** imported rows enter `user-value-stats`' trailing window, so the monthly-gain
figure already on the Now screen moves. That is arguably correct and it is still a visible
change to a shipped number.

---

## Lane C — the 18 ESLint complexity warnings

`pnpm lint` is clean of errors; 18 warnings remain, all in the parsers:
`parseCsvStatement` (complexity 74, 248 lines), `parseOfxStatement` (42, 178),
`parseTextLinesStatement` (45, 148), `parseAmountCell` (31), `planPositional` (23),
`readDateAtStart` (21), `classifyDisposition` (17), plus four `max-lines` on files over 400.

These are `warn`, not `error`, and a CSV reader that sniffs delimiters and infers a sign
convention is legitimately branchy. But complexity 74 in the module whose coverage number
is shown to the user is worth reducing, and the corpus makes it safe: **every refactor must
leave all 131 parser tests passing unchanged.** If a test needs editing to accommodate a
refactor, the refactor is wrong.

Extract by responsibility, not by line count: delimiter sniffing, header role assignment,
sign inference, and row emission are four separable passes over `parseCsvStatement`.

---

## Lane D — chain curation (§6.2). Highest product leverage of anything here.

48 curated `is_chain` entities against 567 `merchant_entities`. Coverage of the descriptor
resolver is the number the user is shown (D4), and every chain added lifts it for every
future statement. The head of a Canadian credit-card statement is a bounded, reviewable
list: grocery banners, pharmacy chains, coffee and fast food, gas brands, telcos, the
big-box retailers.

This is ordinary DATA-lane work under rule 9 — snapshot first and secure it in the same
transaction, dated delta in `cardcoach-docs/deltas/`, expire-then-insert never DELETE,
guards asserting pre- and post-state. **Propose the list as a delta file for Mike's review;
do not apply it.** Rule 7 binds: `default_category_id` on a new chain is a category
assignment, not a card fact, but it still must be defensible from the merchant's actual
business, not guessed from the name.

---

## Lane E — Law 25 privacy copy (§5.4)

The privacy policy's collection list must name this feature, with purpose and deletion
path, on **both** `/en/` and `/fr/` (`CardCoachv2/card_coach_website/site/`). Per
`BRAND.md:199-204` the French is rewritten for a Quebec reader, not translated.

Three sentences of substance, and one of them is already true and worth stating plainly:
**no data is pulled from banks; the user hands us a file they already have.** The deletion
path is the existing `delete-account` cascade plus D11's per-batch undo.

Template: `COMPLIANCE_loyalty_stacking_pack_2026-08-01.md:35`.

---

## Lane F — the 1.0.4 native pass. **Do not start this on `main`.**

`apps/mobile/app.config.ts` uses `runtimeVersion.policy: "fingerprint"`, so adding a native
module changes the fingerprint and the result cannot reach existing installs over EAS
Update. **1.0.3 is in flight and is JS-only** (`PLAN_release_push_1.0.3_2026-08-16.md`);
anything here lands on 1.0.4 or later, on a branch.

One native change unlocks two Pro features, which is the whole point of D12:

1. **Text recognition** — implement `resolveNativeProvider()` in
   `apps/mobile/src/services/textRecognition.ts`. APP-021's receipt scanner has been
   blocked on exactly this since 2026-08-16; statement import consumes the same seam.
2. **Document picker** — implement `resolveNativeProvider()` in
   `apps/mobile/src/services/statementPicker.ts`. The five-point install checklist is in
   that file's header: the dependency, the `__mocks__` entry, the `moduleNameMapper` line,
   the InfoPlist strings in `apps/mobile/locales/{en,fr}.json`, and the Android manifest.
3. **PDF text extraction.** Cross-platform and awkward; the fixture corpus already pins
   what `parseTextLinesStatement` expects to receive, so build against that contract.

A missing `__mocks__` entry or `moduleNameMapper` line breaks **every** jest test that
transitively imports the module, not just the new ones. Add both in the same commit as the
dependency.

---

## Lane G — needs Mike, not a runtime

- **Sign off D1–D14** (§2). Nothing ships until this happens.
- **§9.2, the free teaser.** Is the headline figure free with the breakdown behind Pro, or
  is the whole screen Pro? One boolean and one branch, and it should be answered before the
  screens are treated as final.
- **§9.1, the colour.** The recommendation is sage with forward-looking gain framing
  ("you could earn +$247"), not a loss. Loss framing tests better and should not ship.
- **Apply DATA-022 p1–p3** under rule 9's four standing conditions.
- **§9.3** — relaxing `transactions.merchant_id` to nullable, which is the honest fix Lane B
  works around. Its own DATA ticket, its own read-path analysis.
- **§9.4** — retiring `_shared/cardValue.ts` onto PKG-011. Once the replay is trusted,
  `card-value-stats` and `user-value-stats` are running a weaker fork of it and will
  disagree with this feature on the same wallet. Real work with a visible consequence: the
  shipped monthly-gain number moves. Deserves its own decision entry.

---

## Two things a reviewer should look at hardest

- **D5's zero-bucket materialization** in `statementReplay.ts`. If it is wrong, every
  rising-tier card is inflated for the whole window, it fails silently, and it fails in the
  direction that flatters premium cards. Read its golden test first — it pins the
  difference against the same purchase priced with no snapshots.
- **`_shared/statementDescriptors.ts` and its device twin.** Held byte-identical by a test.
  Both are lookbehind-free because Hermes can throw on a lookbehind at module load — an
  import-time crash in a release build, not a parse failure. The rewrite was
  differential-fuzzed against the originals over 401,301 strings with zero mismatches.
  Any edit to one must land on the other in the same commit.

---

## Verification, per house discipline

`pnpm verify:data-022` and `pnpm verify:api-021` were written in the same session and
**have never been executed** — that container had no Supabase client and no local stack.
Until they run against a live stack, treat them as written, not as passing. Run them before
trusting anything in Lane B.

Full gate: `pnpm typecheck && pnpm lint && pnpm test && pnpm verify:i18n-parity &&
pnpm verify:engine-bundle && pnpm engine:bundle` before any edge deploy.

*Note: `pnpm verify:engine-bundle` currently reports `revenuecat-webhook` failing
`deno check` (a `string | null` mismatch in `_shared/billing.ts`). Pre-existing, unrelated,
and confirmed against the pre-change tree — do not "fix" it as part of this lane without
checking who owns it.*
