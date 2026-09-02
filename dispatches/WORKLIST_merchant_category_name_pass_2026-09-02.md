# WORKLIST — merchant categories for the 45 placed entities still NULL (name pass)

**Date:** 2026-09-02 · **Lane:** review lane · **Owner:** Mike decides, lane applies · Last updated: 2026-09-02

> **APPLIED 2026-09-02 18:03 UTC.** Mike's ruling in chat: "approved" (all 39). Run `4b0ccfa5-41f1-4d6f-975f-5856e4e3eae7`
> (chat), 39 guarded UPDATEs each with a `verify.write_audit` row (`approved_by = 'mike'`), snapshot
> `snapshots.merchant_entities_snapshot_20260902_namepass`, record
> `deltas/2026-09-02__merchant_entities__category_name_pass_39_APPLIED.sql`. Guardrail `placed_null_category`
> 45 → 6 (the six skipped below); entities NULL overall 77 → 38, none of the remaining 32 has a place row.

**Why.** After today's merchant-category apply (run `99b6d975`), 77 `merchant_entities` still carry a NULL
`default_category_id`, 45 of them with place rows (`verify.merchant_graph_guardrail` → `placed_null_category`).
`recommend-card-v2` has no classifier fallback, so every tap on one of them scores base rates only. The
observation queue only fills from traffic (four proposals in two weeks), so these will not drain themselves.

**How this differs from the queue.** `verify.merchant_category_observations.source` is CHECK-constrained to the
two request paths — deliberately: a proposal there is a classifier's observation of a live place. These 39 are
a session's reading of the merchant NAME against the graph's own conventions (convenience → grocery as the
classifier does; individual hotels → travel; telecoms → recurring_bills; Costco → wholesale_club). They are
recommendations for Mike, not observations, so they are listed here rather than forced into the queue. On
approval the lane applies them exactly as Phase A of `PROMPT_merchant_category_apply.md` does — guarded
UPDATE (`default_category_id is not distinct from null`), one `verify.write_audit` row each with
`approved_by = 'mike'`, delta files — under a `verify.runs` row.

**Skipped on purpose (6 of 45)** — no honest category in the taxonomy or not enough in the name: Great Canadian
Oil Change, Nutrien Ag Solutions, Standard Motors, The Clay Place, Shell Touchless Carwash, Freebird Market
Bay Adelaide Centre.

| id | entity | proposed |
|---|---|---|
| 8f857d17 | CITGO | gas |
| 6dc07998 | Citgo Foodmart | gas |
| c220c4b0 | Delta Hotels London Armouries | travel |
| 49fc222a | Dairy Queen Grill & Chill | coffee_fastfood |
| cdb894b5 | Auntie Anne's Pretzels | coffee_fastfood |
| 93ea6a39 | QDOBA Mexican Eats | coffee_fastfood |
| 72a9f8ff | WingsUp! Unionville | coffee_fastfood |
| 4ebf0fd9 | Abica Coffee | coffee_fastfood |
| 495ac35f | Glenn's Cafe | coffee_fastfood |
| f2245251 | Covenant Cafe | coffee_fastfood |
| c8f667f2 | El Burrito Plazero | coffee_fastfood |
| b87aea9d | Boar's Head Cafe Concourse A Food Court | coffee_fastfood |
| cf5ca5c7 | The Grand Malabar Indian Cuisine | dining |
| 2d5fbdf8 | Kennedy's Restaurant & Catering | dining |
| 732098d0 | Ruby's Mediterranean Cuisine | dining |
| 76a368ce | Tangra Villa Hakka Chinese Restaurant (HALAL) | dining |
| 150e52ae | Ganesha Take out and catering | dining |
| f218855c | Earls Kitchen + Bar | dining |
| 92b6f069 | P.F. Chang's | dining |
| d159439c | Low Country | dining |
| 35765311 | SK Nigerian Catering Service | dining |
| f743f50a | Double Double Pizza | dining |
| a53cd0c9 | supermarcado el rancho | grocery |
| 64e66c9d | Noor Food Market & Butcher | grocery |
| b39d6ac1 | Pfenning's Organic & More | grocery |
| 4ed36d02 | Kwik Way Foods | grocery |
| 3df1e33c | Quick Trip Variety Store | grocery |
| d089ab90 | Hasty Market | grocery |
| f5c6cce9 | MC Convenience | grocery |
| 4d1a7161 | Dollarama | retail_shopping |
| d1592676 | Best Buy | retail_shopping |
| bd6b32bf | NAPA Auto Parts - NAPA Swift Current | retail_shopping |
| 34eeae5e | Bumper to Bumper - Great West Auto Electric Ltd. | retail_shopping |
| 48a3a256 | One Plant - Strathroy | retail_shopping |
| 28016688 | Amazon | retail_shopping |
| 4f8531a0 | Walmart + Parking | retail_shopping |
| 4e67329e | Costco Wholesale | wholesale_club |
| 6e6ed0cc | SaskTel | recurring_bills |
| ecf04f24 | VRCADE | entertainment |

**Mike's ruling (2026-09-02, chat):** approve all — applied, see the header.
