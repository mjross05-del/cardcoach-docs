CardCoach Reverification — Decisions Log
Append-only. Every decision that shaped the pipeline, with the reasoning behind it. Settled
decisions stay settled. If something gets revisited, add a new entry that references and
supersedes the old one — don’t rewrite history.
The purpose of this file is to prevent re-litigating decisions that have already been worked
through. If a future session proposes something that contradicts an entry here, the burden
is on that proposal to explain why the original reasoning no longer applies.
Format
Each entry follows this shape:
### YYYY-MM-DD — <short title>
**Decision:** <what was decided, one sentence>
**Why:** <the reasoning>
**Alternatives considered:** <what else was on the table and why it lost>
**Implications:** <what this means for future work>
**Supersedes:** <entry reference, if applicable>
Architecture
2026-04-16 — V2 tables are the only production path
Decision: The pipeline writes exclusively to card_products , earn_rates , card_caps ,
card_exclusions . The legacy V1 cards and card_earn_rates tables are not touched.
Why: Alex confirmed on 2026-04-16 that no production code path reads from V1.
Maintaining dual writes would double the work with zero benefit. Alternatives considered:
Dual-write to both V1 and V2 “just in case.” Rejected as over-engineering for a known-dead
path. Implications: The Stage 3 extraction prompt has a hard rule against emitting V1
writes. If V1 ever comes back, this is a material architecture change, not a config flip.
2026-04-16 — card_caps uses expire-then-insert, never delete-and-replace
Decision: When a cap changes, the pipeline emits an UPDATE … SET valid_to = now() for
the current row, then INSERT for the new row. Never DELETE . Why: The card_caps
schema has valid_from / valid_to versioning columns and an active view that filters by
validity. Deleting rows destroys audit history. The March 14 seed used delete-and-replace
by mistake — Alex agreed on 2026-04-16 that expire-then-insert is correct. Alternatives
considered: Delete-and-replace (simpler SQL, lossy). Rejected. Implications: Same
pattern applies to earn_rates when rates change. The Stage 3 prompt enforces this as a
non-negotiable rule.
2026-04-16 — MCC-based routing is captured in data, not enforced at
runtime
Decision: The pipeline continues to capture mcc_includes / mcc_excludes accurately from
issuer clauses, even though the current payment vendor does not expose MCC codes in
transaction data. Why: Alex confirmed the vendor gap on 2026-04-16. Data integrity
should be maintained independently of runtime routing. When the vendor gap closes or is
replaced, accurate MCC data will already exist — no retroactive data backfill needed.
Alternatives considered: Drop MCC columns entirely until runtime support exists. Rejected
as short-sighted. Implications: MCC fields in earn_rates stay live. Separate conversation
needed on how runtime routing will eventually work.
2026-04-22 — Per-litre earn rates are blocked, parked in
Unsupported_Benefits
Decision: Rows with rate_unit = cents_per_litre or points_per_litre are not forced
into the current enum. They route to an Unsupported_Benefits holding table with a
“rate_unit not yet supported” flag. Why: The current earn_rates.rate_unit check
constraint allows only points_per_dollar , cents_per_dollar , percent_cashback . Forcing
per-litre rates into cents_per_dollar would produce incorrect recommendations.
Engineering (Alex) owns the enum extension. Alternatives considered: (1) Compute an
approximate CAD-equivalent — rejected because gas prices fluctuate and this would create
a moving-target conversion. (2) Drop per-litre rows entirely — rejected because the data is
real and useful once the enum extends. Implications: Canadian Tire and PC Financial gas
rows are currently blocked. Unblocks when Alex extends the enum.
Scope
2026-04-22 — Canada-only, no international expansion in V1
Decision: Every record must carry Canada applicability evidence. Non-Canadian products
are rejected outright. Why: CardCoach is a Canada-first product. Quebec is treated as a
distinct launch channel but still Canadian. Expanding scope before the Canadian data is
rock-solid dilutes the core promise. Alternatives considered: None serious — this is
product-level strategy. Implications: US-issued Amex cards, international co-brands, etc.
are out of scope even if an issuer publishes their terms on the same legal landing page.
2026-04-22 — V1 does not include French-language source reverification
Decision: The 324 fr-CA rows in the registry stay blank for V1. French reverification is a
dedicated future pass, not a translation of the English run. Why: Quebec is a distinct launch
channel for CardCoach, not just a translation target. Issuer French pages sometimes lag or
diverge from English (Desjardins Bonidollars, National Bank product tiers). A superficial
French pass would create false confidence. Alternatives considered: (1) Auto-swap /enca/ → /fr-ca/ and verify — rejected because the hit rate is maybe 60% and unverified
rows are worse than no rows. (2) Skip French entirely — rejected because Quebec is a
priority market. Implications: French reverification is tracked as an open item with its own
plan. When it ships, expect to reuse the same Stage 2 + Stage 3 machinery.
2026-04-22 — Commission-blind posture is architectural, not policy
Decision: The reverification pipeline reads issuer pages only. It does not touch affiliate
URLs, commission data, or anything downstream of monetization. Why: The commissionblind recommendation engine is a foundational product promise. Enforcing it at the datalayer level (not just as a policy) means no single mistake can corrupt the recommendation.
This pipeline stays on the “data integrity” side of that wall. Alternatives considered: None
— this is a foundational constraint. Implications: The affiliate_links table and any
CPA/network infrastructure is out of scope for this pipeline. Period.
Operational
2026-04-22 — Runs locally on Mike’s laptop, not on Supabase or a VM
Decision: Stage 2 is a Python script Mike runs manually. No cron, no server, no Supabase
Edge Function. Why: (1) Simplest path to a working pipeline. (2) Keeps Alex out of this
workstream — Mike owns data, Alex owns the app. (3) At ~300 URLs per run and ~10-
minute runtime, automation isn’t a bottleneck. Alternatives considered: (1) Supabase Edge
Function + pg_cron — rejected because the 400s execution limit is tight for PDF-heavy
fetches and it drags Alex in. (2) Small VM (Railway/Fly/Render) — rejected for now because it
adds cost and infrastructure for no operational benefit at current scale. Implications: If
Mike’s laptop is off, no run happens. Acceptable at current scale. Revisit if/when the pipeline
grows to a point where always-on matters.
2026-04-22 — Text-based change detection, no hashing
Decision: Stage 2 compares normalized text snapshots directly. No SHA hashes stored.
Why: At ~300 URLs per run, text comparison takes milliseconds per file. Hashing is a
computational optimization that pays off at 10,000+ URLs, not here. Removing hashes
simplifies the code, simplifies the schema (no hash columns), and reduces one surface area
for silent bugs. Alternatives considered: Hash-based change detection (faster at scale,
more audit-proof). Rejected as premature optimization. Implications: If the registry ever
grows past a few thousand URLs, revisit. Until then, simpler is better.
2026-04-22 — No database for Stage 2 outputs
Decision: Snapshots live on disk as .txt files. Change reports are .md files. No SQL
database for the fetcher’s state. Why: Disk is cheap, text files are debuggable with any
editor, and the whole system can be moved or deleted without touching Supabase. Adding a
database adds deploy complexity and a dependency on Alex’s infra. Alternatives
considered: Store snapshots in Supabase ( source_snapshots table was sketched in the
DDL). Deferred, not rejected — the table is still in the DDL as a commented-out future
option. Implications: Audit trail is only as permanent as the file system. If these artifacts
matter for compliance long-term, adding Supabase storage is a viable Stage 2.5 upgrade.
2026-04-22 — One previous snapshot kept, not full history
Decision: When a snapshot changes, Stage 2 saves the previous version as .prev.txt .
Older versions are overwritten. Why: Full history is nice to have but not needed for the
current use case. Stage 3 only needs “what’s the current state vs. last month” — older
snapshots don’t contribute. Alternatives considered: Keep every snapshot ever fetched.
Rejected because 400 URLs × 12 months × multi-MB PDFs adds up fast, and nothing in
Stage 3 uses the older versions. Implications: If you need to answer “what did this URL say
6 months ago?”, that information is gone. Add --archive-all-snapshots flag if this ever
matters.
Documentation
2026-04-22 — Three docs, not five
Decision: The pipeline is documented in exactly three markdown files — PIPELINE.md ,
DECISIONS.md , OPEN_ITEMS.md . No separate overview, runbook, or stakeholder brief docs
at the markdown layer. Why: More files means more drift. The existing stage2_README.md
already serves as the operational runbook and should not be duplicated. The stakeholderfacing one-pager is a PDF and doesn’t need a markdown twin. Alternatives considered:
Five files (Overview, Decisions, Open Items, Runbook, Stakeholder Brief) — rejected
because of overlap and maintenance burden. Two files (combined decisions+open) —
rejected because append-only history and churning status have incompatible editing
patterns. Implications: PIPELINE.md is the single “start here” doc. DECISIONS.md is
append-only. OPEN_ITEMS.md is the only file that churns regularly.