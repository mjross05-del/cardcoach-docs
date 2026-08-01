# AMENDMENTS — master valuation index, before StagedSQL write

**Cut:** 2026-07-31 ~22:30 ET · **From:** Mike, relayed verbatim by the D3 snapshot session ·
**Applies to:** `cardcoach_master_valuation_index_2026-07-31_v1.xlsx` (sheets DecisionLog,
MasterIndex/Changes, StagedSQL) · **Status:** MUST land before the staged write executes.

Relay context: at 22:18 the workbook was lock-held by sandbox `blissful-clever-brown`
(`.~lock` file), so the relaying session did not edit the workbook itself. Same content was
sent to the "Overnight dispatch unblock" session via session message at ~22:30.

---

Mike's four amendments, verbatim:

1. Harmonize the bank-floor fallbacks to verify-to-page. NBC's fallback is "anchor to
   whatever the page states"; TD, BMO, and Scene+ are binary verify-or-keep. All four should
   re-anchor to the exact rate the issuer page states — the research figures
   (0.25 / 0.33 / 0.40 / ~0.70) are approximations from the framework, and the Scene+ 0.70 in
   particular was flagged approximate. The page is truth, not the workbook cell.

2. Add event-driven refresh triggers to the governance entry. The SLA ladder is
   scheduled-only. Add: award-chart change, transfer-ratio change, statement-credit rate
   change, program merger/closure → immediate re-valuation regardless of SLA. This was
   strategy recommendation 5 and it's absent from the DecisionLog draft.

3. Avion realistic basis note. The 2.00 schedule floor assumes band-optimal fares; mid-band
   redemptions yield less. Add one line to the basis note so the number is defensible on
   challenge. Value unchanged.

4. Marriott third source — directed search, not open-ended. Candidates in priority order:
   Frugal Flyer's hotel loyalty points article (CAD figure existed in the framework
   research), Rewards Canada, thepointcalculator.com/ca. If none yields a CAD figure,
   Marriott stays held at current values — correct outcome.

---

Relaying session's routing notes (not Mike's words):

- §2b applies to amendment 4: a figure counts only if read on the publisher's own page and
  recorded with that URL and access date. This file is not a source.
- `REPORT_cpp_session3_findings_2026-07-31.md` line 111 cites
  `frugalflyer.ca/blog/how-much-are-frequent-flyer-miles-worth/` (CAD Avios figure,
  dual-confirmed) — the hotel-loyalty sibling article is candidate #1. Verify on the page.
- Once the amendments are applied and the write lands, this file has served its purpose —
  fold it into the night report and delete, per dispatch-file convention.
