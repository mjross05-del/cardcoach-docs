-- Delta: card_products.fx_fee_percent 2.50 -> NULL for 15 cards with no citable source (RULE 7)
-- Applied: 2026-08-02 via Supabase MCP execute_sql, project hrzpznlpmxxrbtwskacu
-- Authorized: Mike, in-session ruling, Cowork FX-fee audit session 2026-08-02
--   (asked with three scope options; Mike chose "Tier 1 + the Amex cards")
--
-- WHY THESE 15
--   Rule 7: "Never invent card facts — earn rates, caps, exclusions, fees, point values.
--   Unknowns are flagged [VERIFY: issuer-verified data needed], never estimated."
--   STAGE3_PROMPT rule 6 says the same in the specific: "don't assume FX fee is 2.5% if the
--   source doesn't say so." These 15 rows held 2.50 with nothing citable behind it.
--
--   12 Amex Canada cards — 9 consumer AND 3 business (Aeroplan Business Reserve, Business Edge,
--     Marriott Bonvoy Business). NOTE: the dividing line inside the Amex lineup is NOT product
--     segment, it is whether the agreement STATES the commission. The 2026-07-27 dual-pass
--     confirmation was formally RETRACTED on 2026-07-28 (write_audit 03:50 UTC flipped 11
--     fact_checks to unverified/fail_closed): "quoted clause is NOT present in the cited
--     artifacts; correlated misread — both passes pattern-matched the known Amex commission
--     clause." For these cards the Cardmember Agreement defers the conversion commission to the
--     in-application information box, which is not publicly posted, and the v24 workbook cites
--     no FX-specific source for any Amex row. Business Edge joins the set on the same evidence:
--     its own verifier note reads "other Amex Canada cards state 2.5% but recording null rather
--     than assuming." Every fx fact_check for all 12 is unverified/fail_closed.
--   2 MBNA cards. The v24 workbook SELF-DECLARES the value an assumption — "FX fee assumed 2.5%
--     per MBNA disclosure PDF; verify" — and two independent live passes (2026-07-28, 2026-08-01)
--     found no public issuer-stated %: the amount lives only in the in-application Disclosure
--     Statement. Verifier verdict, verbatim: "Value null, not assumed."
--   1 BMO AIR MILES World Mastercard (application-closed legacy). Verifier: "Unstated -> null."
--     No FX source in the workbook for this row (the sibling World Elite cites the BMO PDF; this
--     one does not).
--
-- DELIBERATELY NOT NULLED (evidence exists; this is staleness, not absence)
--   Amex Business Gold Rewards + Business Platinum — their agreements do state it:
--     "which we increase by a single conversion commission of 2.5%" (confirmed, run c6f63ead).
--     This is exactly why the 2026-07-28 retraction excluded these two. Left at 2.50.
--     (These two are business cards, but so are 3 of the 12 nulled above — segment is not the
--     criterion; a stated clause is. See the correction note on the write_audit row.)
--   7 RBC cards (Avion Visa Platinum, British Airways VI, Rewards Visa Preferred, Rewards+ Visa,
--     Signature Rewards, WestJet RBC MC, More Rewards RBC Visa) — the workbook cites a specific
--     per-card RBC InfoBox PDF for each (avion_p.pdf, ba_platinum.pdf, gold_p.pdf,
--     rewards_plus.pdf, classic2.pdf, westjet_world.pdf, co-app disclosure PDF). The 2026-07-29
--     run failed to re-confirm only because the InfoBox sits inside the application flow and the
--     runbook's no-application rule forbids entering it. Evidence exists and was captured at load.
--   10 BMO cards — domain-wide bot wall confirmed 2026-07-28; workbook cites the BMO universal
--     "Important information about BMO Credit Cards" PDF fee table.
--   Both groups route to the re-verification queue, not to a data change.
--
-- SAFETY CHECKED BEFORE WRITING (null must not flatter a card)
--   Engine: fx_fee_percent is SELECTed in scoring.ts:345 and copied to display at :1220
--   (fxFeePercent: card?.fx_fee_percent ?? null) and never read again. It is absent from the
--   ranking key (scoring.ts:1749-1757). No `?? 0` / `|| 0` / coalesce(...,0) exists anywhere in
--   the repo, so NULL is never silently read as 0%.
--   Mobile UI: null renders "Unknown" / "FX fee info not available" (status "info"), distinct
--   from the 0% branch "No foreign transaction fees" (extract.ts:468-501). Web renders
--   "Not listed". So withdrawing the value reads as unknown, never as fee-free.
--
-- Pre-state guards (all asserted in the same DO block; any failure rolled the write back):
--   1. exactly 15 target ids at fx_fee_percent = 2.50
--   2. exactly 13 pre-existing NULLs
--   3. NO target carries a confirmed/changed fx_fee_percent fact_check
-- Post-state guards: exactly 15 rows updated; 28 total NULLs; all 15 targets NULL.
-- Snapshot: public.card_products_snapshot_fx_20260802 (114 rows, RLS enabled, anon+authenticated
--   revoked in the same statement per rule 9(a)).
-- Invariant suite: pnpm verify:cpp --cloud passed before and after.

update public.card_products
set fx_fee_percent = null
where fx_fee_percent = 2.50
  and id in (
    -- Amex Canada consumer (12) — retracted misread, agreement defers to in-application info box
    'ca_american_express_canada_aeroplan_amex_credit_amex',
    'ca_american_express_canada_aeroplan_business_reserve_amex_credit_amex',
    'ca_american_express_canada_aeroplan_reserve_amex_charge_amex',
    'ca_american_express_canada_business_edge_amex_credit_amex',
    'ca_american_express_canada_cobalt_amex_credit_amex',
    'ca_american_express_canada_gold_amex_charge_amex',
    'ca_american_express_canada_green_amex_charge_amex',
    'ca_american_express_canada_marriott_bonvoy_amex_credit_amex',
    'ca_american_express_canada_marriott_bonvoy_business_amex_credit_amex',
    'ca_american_express_canada_platinum_amex_charge_amex',
    'ca_american_express_canada_simplycash_amex_credit_amex',
    'ca_american_express_canada_simplycash_preferred_amex_credit_amex',
    -- MBNA (2) — workbook says "assumed ... verify"; % is not public
    'ca_mbna_canada_mbna_rewards_mastercard_world_elite_mastercard',
    'ca_mbna_canada_mbna_rewards_standard_mastercard',
    -- BMO (1) — closed legacy; "Unstated -> null"
    'ca_bmo_air_miles_mastercard_world_mastercard'
  )
returning id, display_name, fx_fee_percent;

-- Rollback (restores the pre-write values from the session snapshot):
-- update public.card_products cp
-- set fx_fee_percent = s.fx_fee_percent
-- from public.card_products_snapshot_fx_20260802 s
-- where s.id = cp.id
--   and cp.fx_fee_percent is null
--   and s.fx_fee_percent = 2.50;
