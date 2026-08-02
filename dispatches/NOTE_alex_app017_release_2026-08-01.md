# NOTE for Alex — APP-017 mobile release (loyalty stacking Phase 1)

Last updated: 2026-08-02 (authored 2026-08-01 dispatch, landed post-merge)
From: Claude Code landing session (Mike supervising)
Re: EAS release that carries APP-017

## What landed

Loyalty stacking Phase 1 (DATA-018 / PKG-010 / API-013 / APP-017) is merged to
`main` in CardCoachv2 (merge commit `a8d8f02`, followed by QA-009 golden pack
merge `702407f`). Everything ships **dark** behind
`runtime_flags.loyalty_offer_stacking = false`. Both DATA-018 migrations are
applied to production Supabase and verified (flag false, 10 offers, 7 issuer
scopes, 3 exclusions).

## What this note asks of you

Cut the next mobile release from `main` including APP-017 (till-moment stack
UX + widened explanation union). **This release is the activation
precondition**: the founder flag-flip cannot happen until a build containing
APP-017 is live in the field. Version bump per your usual EAS profile —
nothing unusual needed.

Nothing server-side needs to move first: the recommend-card-v2 /
recommend-here-v2 changes are additive-safe and already deployed dark; old
app versions are unaffected.

## Suggested smoke before submitting

1. `pnpm -C apps/mobile test` — includes the new contract-adoption tests
   (`loyaltyStackingContracts.test.ts`, `loyaltyLinks.test.ts`).
2. The fixture-gated Maestro flow:
   `e2e/flows/journeys/loyalty_stacking/stack_badge.yaml`.

## Explicitly out of scope

- Do NOT touch `runtime_flags` — the flip is a founder decision, separate step.
- No schema or data work; DATA-018 is fully applied.
