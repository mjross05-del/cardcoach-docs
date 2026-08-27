# PROMPT — Deploy the statement-import edge functions (2026-08-21)

For: Mike, in a Terminal with network and `supabase` CLI auth.
Project: `card_coach_advanced` — `hrzpznlpmxxrbtwskacu`.

**Why this is not already done.** DATA-022's schema is applied (via MCP, under rule 9).
The three edge functions are not, and could not be from the Cowork session: deploying them
needs the CLI, the desktop bridge VM has no network, and the MCP deploy tool requires the
whole import closure inlined — 49 files / 467 KB for `analyze-spend-v1` alone. This project
already deploys functions from a Terminal (`PROMPT_code_push_deploy_2026-08-16.md`); this
follows that.

**Everything below deploys DARK.** `runtime_flags.statement_import` and
`.statement_import_write` are both `false` in production right now. Deploying does not make
anything reachable — every one of these functions checks the flag before the entitlement and
refuses with `feature_disabled` while it is off. Nothing here needs a release, an App Store
review, or a client change.

---

## 0. Preconditions (already true — verify, don't redo)

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
supabase migration list --project-ref hrzpznlpmxxrbtwskacu | grep data_022
```

Expect four rows: `20260821034436` p0, `034519` p1, `034555` p2, `034611` p3.

The vendored engine bundle is current as of this session, but it is cheap to be sure —
a stale bundle is the failure mode where the function deploys and then 500s on a symbol
that exists in `packages/` and not in `supabase/functions/_shared/`:

```bash
pnpm engine:bundle
pnpm verify:engine-bundle
```

`verify:engine-bundle` reports **one** failure, `revenuecat-webhook` — a `string | null`
mismatch in `_shared/billing.ts`. It is pre-existing, it belongs to BILL-001's lane, and it
was failing before any of this work. It does not block these three.

---

## 1. Deploy

```bash
supabase functions deploy resolve-descriptors-v1 --project-ref hrzpznlpmxxrbtwskacu
supabase functions deploy analyze-spend-v1       --project-ref hrzpznlpmxxrbtwskacu
supabase functions deploy import-spend-v1        --project-ref hrzpznlpmxxrbtwskacu
```

All three are registered in `supabase/config.toml` with `verify_jwt = false`, matching every
other authed function here: they call `getUser()` internally and need the raw `Authorization`
header to build the RLS-scoped user client the entitlement check reads through.

`deno check` passes clean on all three as of this session, so a boot failure would mean the
bundle went stale between then and now.

---

## 2. Confirm they are live and refusing

```bash
supabase functions list --project-ref hrzpznlpmxxrbtwskacu | grep -E "resolve-descriptors|analyze-spend|import-spend"
```

Then prove the gate, which is the actual acceptance test — a deployed function that does
**not** refuse is the thing to catch:

```bash
curl -s -X POST \
  "https://hrzpznlpmxxrbtwskacu.supabase.co/functions/v1/analyze-spend-v1" \
  -H "Authorization: Bearer $YOUR_USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"schemaVersion":"v1","locale":"en","spend":[{"date":"2026-06-01","amountCents":1000,"categoryId":"grocery","onCardProductId":null}]}'
```

**Expected: HTTP 403 `{"error":"feature_disabled", ...}`.**

That is a pass. It means the function booted, resolved its imports, read the flag, and
refused — the whole chain, without exposing anything. A 500 means the bundle is stale; a
200 means a flag is on that should not be.

Repeat against `resolve-descriptors-v1` and `import-spend-v1`; `import-spend-v1` checks
`statement_import` first, so it also answers `feature_disabled` rather than `write_disabled`.

---

## 3. The verify scripts (needs Docker, not production)

`verify:data-022`, `verify:api-021` and `verify:api-022` **refuse to run against a non-local
Supabase host**, by design — they insert and delete rows in canonical tables, and
`scripts/_shared/supabaseFixtures.mjs` guards it. There is an `ALLOW_REMOTE_VERIFY_WRITES=1`
override. Do not use it against production; that is precisely what the guard is for.

Run them against a local stack:

```bash
pnpm supabase:start        # Docker
pnpm supabase:db-reset     # migrations + seed
pnpm verify:data-022
pnpm verify:api-021
pnpm verify:api-022
```

**None of the three has ever executed.** They are written and syntax-checked, nothing more.
Treat the first run as a test of the scripts as much as of the code — expect to fix the
scripts.

The DB half of `verify:data-022` was independently checked against production read-only on
2026-08-21, 15/15 PASS: catalogue row, tier resolution, catalogue→flag linkage, both flags
present and dark, RLS enabled *and* forced, exactly one policy, zero write grants to
anon/authenticated, `authenticated` can select, `ON DELETE CASCADE` for account-deletion
coverage, `import_batch_id` present/nullable/`SET NULL`, zero rows tagged, and the
transaction count unchanged at 103. That is the schema proven; it is not the script proven.

---

## 4. What NOT to do yet

- **Do not flip `statement_import`.** Extraction runs on device (D1), so the flag cannot
  precede an APP-024 build in the field — flipping it early advertises a screen nobody has.
  APP-024 is built but its native providers are Lane F, unshipped.
- **Do not flip `statement_import_write`.** §9.3's option (b) closed the structural blocker,
  but no import has ever run against a real statement. It back-dates rows into cap progress
  and `user-value-stats`.

Rollback for anything here is `supabase/rollback/data_022_down.sql`, and the no-deploy
rollback is the flags — which are already off.
