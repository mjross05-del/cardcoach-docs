# PROMPT — push + edge deploy for the 2026-09-07 build-56 `value_tie` fix (code runtime)

Authored by the 2026-09-07 Cowork session on Mike's instruction ("move forward
with stage 2 — the actual fix"). You are a Claude Code session on Mike's Mac.
Your job is exactly this: clean the sandbox's git artifacts, verify, deploy two
edge functions, push one repo, ship one web-app change — then file a short
report. Nothing else.

## Context — what is already done (do NOT redo)

**The bug.** The App Store is still serving iOS **build 56** (v1.1, contract of
2026-08-07). `runtime_flags.tie_disclosure` has been ON since 2026-08-16. When
two wallet cards tie on ranked cents, `recommend-card-v2` / `recommend-here-v2`
append a `value_tie` explanation item; build 56's `zExplanationItemV2` is a
closed `discriminatedUnion` that predates it, so `.parse()` throws
`invalid_union` and the Now screen shows "Something went wrong" while every
server log reads 200. Reported by Mikayla (wallet: Amex Aeroplan + PC Financial
Standard MC + Scene+ Standard Visa — the two standard cards tie at 1.0%).
Reproduced by running the live 2026-09-07 payload through the build-56 contract.

**The fix — committed locally** in `~/dev/CardCoachv2` as **`5a25742`** on
`main` (parent `d304ca8` = `origin/main`; also on branch
`fix/tie-disclosure-legacy-clients`):

- `supabase/functions/_shared/clientCapabilities.ts` (new): callers declare the
  explanation item types they can parse in an `x-cardcoach-caps` header; **no
  header = the legacy store client.**
- `recommend-card-v2` / `recommend-here-v2`: tie disclosure (payload AND the
  tie-aware comparator — they go together) is switched off per request for any
  caller that has not declared `value_tie`, whatever the runtime flag says.
- `_shared/cors.ts`: `x-cardcoach-caps` added to the allowed request headers.
- `packages/engine-contracts/src/explanationsV2.ts`: exports
  `EXPLANATION_ITEM_TYPES_V2` (derived from the union); `zExplanationSectionV2`
  now DROPS unknown-but-well-formed item types instead of failing the response.
  Vendored copy under `_shared/engine-contracts/` regenerated (identical).
- `apps/mobile/src/lib/tracing.ts`: sends `x-cardcoach-caps` on every edge call.
- Tests: `explanationsV2.test.ts` (contracts), `client_capabilities.test.ts`
  (deno) added; existing tie_disclosure / cors / stateless / api_014 suites pass.
  Contracts tsc+build, mobile tsc, deno check, jest tracing — all green in the
  sandbox. `packages/engine-contracts/dist/` was rebuilt in place.

**Web app change — NOT yet committed.** The web app parses the same contract
and renders ties, so after the deploy it would silently lose tie notes unless
it sends the header. Patched in the worktree at
`~/dev/CardCoachv2/.claude/worktrees/fervent-lederberg-3deff9/card_coach_web_app/src/data/supabaseData.ts`
(branch `claude/cardcoach-web-design-handoff-8b6b9f`, head `63bed8a`): imports
`zExplanationItemV2`, builds `CLIENT_CAPS_HEADER_VALUE` from `.options`, passes
`headers` to every `sb.functions.invoke`. `tsc --noEmit` clean. It reads the
header value off `.options` on purpose, so it compiles against the contract on
either side of `5a25742` — the web branch does NOT need a rebase for this.

**Runtime flag.** `tie_disclosure` stays **ON** (Mike chose the code fix over the
flag flip). After the deploy the flag is inert for build 56 (no header → no
`value_tie`) and live for build 85 and the web app (both send the header).

## Guardrails

- Modify no source files beyond committing the web-app change described above.
  Run no data SQL. Deploy ONLY the two functions named below —
  `recommend-cards-stateless-v1` never emits tie disclosure and must not be
  redeployed for this.
- Never force-push. Non-fast-forward → fetch + rebase; conflicts → STOP and
  report.
- Order matters: **functions first, web app second.** The web app's new header
  makes the browser preflight ask for `x-cardcoach-caps`; until the functions
  with the new CORS allowlist are live, that preflight would 403.
- If any verification fails, STOP at that step and report. Do not improvise.

## Step 0 — clean the sandbox's git artifacts, verify preconditions

The Cowork sandbox cannot unlink inside `.git`; it parked stale locks under
`_to_delete/stale-git-locks-2026-09-07-tie-fix/`.

```bash
cd ~/dev/CardCoachv2
find .git -maxdepth 3 -name '*.lock' -print -delete
rm -rf _to_delete/stale-git-locks-2026-09-07-tie-fix _to_delete/tie-fix-staging
git log --oneline -2                       # expect: 5a25742, d304ca8
git rev-parse --short origin/main          # expect: d304ca8
git status --porcelain -- mobile_app_codebase   # expect: empty
```

## Step 1 — verify locally before deploy

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
pnpm build:contracts
node scripts/bundle_engine.mjs && git status --short -- supabase/functions/_shared   # expect: nothing
pnpm --filter @cardcoach/engine-contracts test          # expect: explanationsV2.test.ts among the passes
pnpm test:supabase                                      # expect: 0 failed (client_capabilities.test.ts included)
pnpm --filter @cardcoach/mobile test -- src/lib/__tests__/tracing.test.ts   # expect: 8 passed
```

If `bundle_engine.mjs` produces a diff, stop — the vendored copy has drifted.

## Step 2 — deploy the two functions

```bash
cd ~/dev/CardCoachv2/mobile_app_codebase
for fn in recommend-card-v2 recommend-here-v2; do
  npx supabase functions deploy "$fn" --project-ref hrzpznlpmxxrbtwskacu || break
done
npx supabase functions list --project-ref hrzpznlpmxxrbtwskacu | grep -E 'recommend-(card|here)-v2'
# expect: recommend-card-v2 version 39 (was 38), recommend-here-v2 version 40 (was 39); both verify_jwt false as before
```

The CLI bundles the `_shared` tree and preserves each function's existing
`verify_jwt` (both are `false` — the functions authenticate the user JWT
themselves). Do not use the MCP deploy tool for these: 50+ relative imports.

## Step 3 — post-deploy verification (no user JWT needed)

```bash
# 1) CORS now admits the capability header (this is what the web app's preflight sends):
curl -s -o /dev/null -w '%{http_code}\n' -X OPTIONS \
  'https://hrzpznlpmxxrbtwskacu.supabase.co/functions/v1/recommend-card-v2' \
  -H 'Origin: https://app.cardcoach.ca' -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: authorization,apikey,content-type,x-cardcoach-caps'
# expect: 204 (or 200), and:
curl -s -D - -o /dev/null -X OPTIONS \
  'https://hrzpznlpmxxrbtwskacu.supabase.co/functions/v1/recommend-card-v2' \
  -H 'Origin: https://app.cardcoach.ca' -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: x-cardcoach-caps' | grep -i 'access-control-allow-headers'
# expect: the list includes x-cardcoach-caps

# 2) The stateless surface is byte-stable (never redeployed, never emits ties):
curl -s -X POST 'https://hrzpznlpmxxrbtwskacu.supabase.co/functions/v1/recommend-cards-stateless-v1' \
  -H 'apikey: sb_publishable_o8DLtdGmTy4DM4kR8FmOVQ_vKp0EH7Z' -H 'Content-Type: application/json' \
  -d '{"schemaVersion":"v1","cardProductIds":["ca_pc_financial_pc_financial_standard_mastercard","ca_scotiabank_scene_plus_standard_visa","ca_american_express_canada_aeroplan_amex_credit_amex"],"amountCents":5000,"channel":"in_store","locale":"en","merchantPlaceId":"f69a0983-b795-44ec-8a77-c748bed2f76f"}' \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print([(r["rank"], r["cardProductId"], r["effectiveValueCents"]) for r in d["recommendations"]])'
# expect: Amex Aeroplan 150, then the two standard cards at 50 each (a genuine tie — the exact case build 56 chokes on)
```

3) The real proof is a legacy client: ask Mikayla to retry the same search on
build 56, or run the App Store build yourself with a wallet of two no-fee 1%
cards. Expect a recommendation, not "Something went wrong". Server-side, the
function log line for that request still reads `recommend_card_v2_success`
(it always did — the change is what the response contains).

## Step 4 — push the monorepo

```bash
cd ~/dev/CardCoachv2
git fetch origin
git merge-base --is-ancestor origin/main main && echo fast-forward-ok || echo "NOT FF — rebase, then re-run Step 1"
git push origin main
git push origin fix/tie-disclosure-legacy-clients   # optional, keeps the branch for the record
```

## Step 5 — ship the web app (only after Step 2 succeeded)

```bash
cd ~/dev/CardCoachv2/.claude/worktrees/fervent-lederberg-3deff9
git status --porcelain            # expect: exactly card_coach_web_app/src/data/supabaseData.ts modified
git diff --stat
git add card_coach_web_app/src/data/supabaseData.ts
git commit -m "web app: declare explanation-item capabilities (x-cardcoach-caps) so tie notes survive the 2026-09-07 server gate"
git push origin claude/cardcoach-web-design-handoff-8b6b9f
cd card_coach_web_app && npm run build     # tsc + vite build; expect clean
```

Then release the built `dist/` to the `mjross05-del/cardcoach-app` deploy repo
exactly per that repo's README recipe and push. Verify live: sign in at
https://app.cardcoach.ca with a wallet that ties (two 1% cards) — the tie note
under the selected card should still render, and DevTools → Network shows
`x-cardcoach-caps` on the `recommend-card-v2` request with a 200 response.

## Step 6 — report

Append to `~/dev/cardcoach-docs/WORKING_NOTES.md` under **#38** (the entry the
Cowork session opened): deployed versions, push SHAs (monorepo main, web
branch, deploy repo), the CORS check result, and whether Mikayla confirmed.
Then close #38 by deleting it if everything is green — the decision record is
already in `PIPELINE_AND_DECISIONS.md` (2026-09-07).
