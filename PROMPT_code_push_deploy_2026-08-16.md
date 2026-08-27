# PROMPT — push + edge deploy for the 2026-08-16 tie-disclosure session (code runtime)

Authored by the 2026-08-16 Cowork session (API-016 + APP-020), on Mike's
instruction. You are a Claude Code session on Mike's machine. Your job is
exactly four things: clean the sandbox's git artifacts, push one repo,
deploy two edge functions, and verify — then file a short report. Nothing
else.

**Read first if anything is unclear:**
`mobile_app_codebase/docs/planning/specs/API-016_tie_disclosure.md`,
`mobile_app_codebase/.agent_scratchpad/API-016_APP-020_execution_log.md`.

## Context — what is already done (do NOT redo)

- API-016 (tie detection in ranking) + APP-020 (tie display) are implemented,
  tested (deno 283/283, jest 601/601, `pnpm verify:api-016` and
  `pnpm verify:ui` both exit 0), and **committed locally** in
  `~/dev/CardCoachv2` as `67cab22` on branch
  `feat/api016-app020-tie-disclosure` (branched from `675b7b7` on main).
- The flag migration is **already applied to the remote DB** as
  `20260816185557_tie_disclosure_flag` (via the session's Supabase
  connector), and the local migration file matches remote history 1:1.
  **Do not run `supabase db push`.** The flag row exists and is
  **enabled = false** — verified live:
  loyalty_offer_stacking true · merchant_mcc_assumption true ·
  tie_disclosure **false**.
- Production functions still run the old code (recommend-card-v2 v23,
  recommend-here-v2 v22). The deploy below is DARK: with the flag false the
  new code's comparator is byte-identical to the old one and no tie fields
  are emitted. Nothing user-visible changes until the flag flips (which is
  NOT part of this run — preconditions in the migration file header).
- A pre-deploy baseline of recommend-cards-stateless-v1 was captured by the
  session (deterministic across a double probe) for the parity check below.
- The only drift between the deployed v23/v22 bundles and the repo was
  scoring.ts — i.e. the repo is exactly production plus this changeset.

## Guardrails

- Modify no source files. Run no data SQL. Deploy ONLY the two functions
  named below. recommend-cards-stateless-v1 must NOT be redeployed (API-016
  D3: it stays byte-identical by not shipping).
- Never force-push. Non-fast-forward → fetch + rebase; conflicts → STOP and
  report.
- If any verification fails, STOP at that step and report. Do not improvise.

## Step 0 — clean the sandbox's git artifacts, verify preconditions

The Cowork sandbox cannot unlink inside `.git`; it left renamed stale locks
and temp objects:

```bash
find ~/dev/CardCoachv2/.git -maxdepth 3 \( -name '*.lock' -o -name '*.stale.*' -o -name 'tmp_obj_*' \) -delete
git -C ~/dev/CardCoachv2 gc --quiet
git -C ~/dev/CardCoachv2 log --oneline -2   # expect: 67cab22, 675b7b7
git -C ~/dev/CardCoachv2 status --porcelain # expect: only untracked "Brand kit app mockup.zip" and design_handoff_cardcoach_rebrand/ (Mike's drops — leave them)
```

## Step 1 — merge or fast-forward per Mike's word, then push

Ask Mike (or check the task he gave you): merge
`feat/api016-app020-tie-disclosure` into `main` and push, or push the branch
for review. Default if unspecified: push the **branch** only.

```bash
cd ~/dev/CardCoachv2 && git fetch origin && git push origin feat/api016-app020-tie-disclosure
```

## Step 2 — verify locally before deploy

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase && pnpm verify:api-016   # must exit 0
```

## Step 3 — deploy the two functions (dark)

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
supabase functions deploy recommend-card-v2 --project-ref hrzpznlpmxxrbtwskacu
supabase functions deploy recommend-here-v2 --project-ref hrzpznlpmxxrbtwskacu
```

Expect versions v24 and v23 respectively. verify_jwt stays false for both
(config.toml; they auth in-code).

## Step 4 — post-deploy verification

1. **Stateless parity (invariant 8):** POST the exact baseline request to
   recommend-cards-stateless-v1 with the publishable key —

   ```json
   {"schemaVersion":"v1","cardProductIds":["ca_scotiabank_passport_visa_infinite_visa","ca_amex_cobalt_amex"],"amountCents":10000,"categoryId":"grocery","channel":"in_store","locale":"en"}
   ```

   The response minus `requestId`/`computedAt` must equal the session's
   pre-deploy baseline (ask the session report, or re-derive: stateless was
   NOT redeployed, so any difference means shared-state drift — STOP).
2. **Authed flag-off parity:** from Mike's signed-in app or a captured JWT,
   one recommend-card-v2 call for a known context — response must contain NO
   `tie` field and NO `value_tie` item, and rankings must match pre-deploy
   for the same wallet/context.
3. `supabase functions list --project-ref hrzpznlpmxxrbtwskacu` — both
   ACTIVE at the new versions.

## Step 5 — report

Versions deployed, parity results, push result, anything skipped. The flag
flip is a SEPARATE later action gated on the APP-020 app release; its delta
template is `cardcoach-docs/deltas/2026-08-XX__runtime_flags__tie_disclosure_on_TEMPLATE.sql`.
