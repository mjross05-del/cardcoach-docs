# Affiliate network applications — submission packet

**Date:** 2026-08-24 · **Owner:** Mike · **Lane:** revenue
**Status:** ready to submit once the four pre-flight items below are done.

The affiliate links have been live since 2026-08-11. What is missing is not
plumbing — it is a commercial relationship. Every one of the 126 outbound links
in `apply-links.js` is `network:"direct", sponsored:false`, which means the
traffic already flowing to issuers earns nothing. This packet exists to close
that in the smallest number of moves.

---

## 1. What to do, in order

| # | Action | Who | Blocking? | Effort |
|---|---|---|---|---|
| 1 | Fix the four pre-flight items in §2 | Mike | **Yes — do not apply first** | ~1–2 h |
| 2 | Apply to **Fintel Connect** | Mike | — | ~30 min |
| 3 | Apply to **CJ Affiliate** | Mike | — | ~30 min |
| 4 | On Fintel approval, apply to **each issuer program separately** | Mike | — | ~10 min each |
| 5 | Per approval: flip that card's entry in `apply-links.js` | Claude/Mike | — | minutes |

**Apply Tuesday–Friday, not Monday.** That is Fintel Connect's own published
advice — affiliate managers clear a weekend backlog on Mondays.

**FlexOffers is deprioritised.** Three of their public directory categories were
sampled — credit cards, financial services, and the Canada archive — and none
carried a Canadian card issuer. US subprime cards and Canadian retail. Their
published decline reasons also include *"Traffic sources with low rankings may
not be approved,"* which is the criterion CardCoach is weakest against today.
Apply later for option value, not now.

---

## 2. Pre-flight — four things to fix before submitting

These are not polish. Items 1 and 2 are the ones a bank's compliance reviewer
checks, and item 3 is the one that fails a legitimacy check outright.

### 2.1 Per-page disclosure — DONE IN CODE, awaiting deploy

Ad Standards Canada's *Influencer Marketing Disclosure Guidelines* (2025-10-08)
say two things that the 2026-08-11 build got wrong:

> *"Disclosure should appear on every page and post where links are presented.
> Having disclosure in your bio only is not sufficient."*

> Disclosure must appear *"before a URL (clickable or non-clickable)."*

`/how-we-make-money` is necessary and **explicitly not sufficient on its own**.
The gap-finder on `/best-card` rendered its disclosure line *below* the card
rows, i.e. after the links. That is now fixed — the disclosure renders above the
first outbound link — and `verify_disclosure_position.mjs` fails the build if it
ever moves back.

Also confirmed: the site uses **no `#ad` tag anywhere**, which matters because
the same guidelines say *"When sharing affiliate content, do not use #ad."*

### 2.2 A professional email on the domain

Fintel Connect's own approval guidance is blunt: *"If you're signing up to a new
affiliate program with your Yahoo or Hotmail email, it sets off an immediate
warning sign."* Apply from **`mike@card.coach`** (already in use for Play
Console) or `hello@cardcoach.ca`, never a personal address.

Have a **phone number that answers**, with a professional voicemail. Fintel:
*"A lot of programs will want to have a quick conversation with you before they
approve your affiliate application."* FlexOffers requires **SMS verification** and
will not waive it.

### 2.3 Resolve the legal-entity name — DO THIS FIRST

`how-we-make-money.html` publishes JSON-LD claiming
`"legalName": "CardCoach Inc."`. Everything else on record says the operating
entity is **Warm Logic**. One of those is wrong.

This matters more than it looks. CJ's published vetting standard is *"identity
verification, business legitimacy checks,"* and every network requires a legal
entity name that matches banking and tax documentation. A site whose structured
data names a different company than the application is a straightforward
legitimacy failure.

**Action:** confirm the correct registered name, then make the site, the
application, and the banking details agree. If `CardCoach Inc.` does not exist,
the JSON-LD is a false statement of corporate identity and should be corrected
regardless of the affiliate lane.

### 2.4 Do not claim a live Android app

Android is on the **internal testing track only** (1.0.3 / versionCode 5,
2026-08-17). Networks register each promotional property separately and a
reviewer will open the link. Claim exactly this:

> **iOS — live on the App Store** (`apps.apple.com/ca/app/cardcoach/id6757937693`)
> **Android — in internal testing, production release pending**

---

## 3. The application answers — copy from here

Same facts every network asks for, verified against the live database on
2026-08-24 rather than remembered.

**Property**
- Primary site: `https://cardcoach.ca`
- Vertical: Canadian consumer credit cards — rewards optimisation
- Audience: Canada, English + French (fr-CA), consumers who already hold cards
- Business model: free consumer tool; revenue from card referrals and a paid
  mobile tier
- Legal entity: *(see §2.3 — resolve before submitting)*
- Country of operation: Canada · Payment currency: CAD

**Scale — verified 2026-08-24**

| | |
|---|---|
| Active cards in catalogue | **148** |
| Scoreable cards (full engine coverage) | **108** |
| Issuers covered | **15** |
| Individual earn-rate rows maintained | **700** |
| Points programs with maintained valuations | **28** |
| Live site pages | **25** |
| Long-form fact-checked articles | **14** |
| Cards with an outbound issuer link today | **126** (was 96 when this packet was written; AFF-002 added 30 on 2026-08-24, verified 2026-08-27) |

**Traffic.** State it honestly and do not estimate. None of the three networks
publishes a traffic minimum; all three publish content and legitimacy criteria,
which is where CardCoach is strong. If asked for numbers, give the real ones and
lead with the catalogue and the app.

**Promotion plan** — Fintel explicitly asks for this. Suggested wording:

> CardCoach is a rewards-optimisation tool, not a comparison site. A user enters
> the cards they already hold; the engine ranks them for a specific purchase
> using issuer-verified earn rates, category caps, and maintained points
> valuations. Referral placement occurs in one surface only: after the user has
> their answer, a "Beyond your wallet" module shows up to three cards they do
> not hold that would have earned more on that exact purchase, with the value
> difference stated. Because the recommendation is generated before any
> commercial consideration is applied, the traffic is intent-qualified — the
> user has already seen a quantified reason to want the card. Editorial content
> carries no affiliate links at all, by policy.

**Compliance posture** — lead with this; it is the strongest part of the
application:
- Public disclosure page at `/how-we-make-money`, linked from all 25 pages.
- Per-placement disclosure above the first outbound link, per Ad Standards
  Canada (2025-10-08), enforced by an automated gate in CI.
- `rel="sponsored"` and a visible "Sponsored" marker on every paid link,
  rendered automatically from the link registry so a paid link cannot appear
  unmarked.
- Rankings are commission-blind and the engine has no commission field —
  this is architectural, not a policy promise.
- Editorial separation: no affiliate links in blog content.

---

## 4. Fintel Connect — the priority

**The only one of the three with real Canadian card inventory.** Verified from
Fintel's own brand-directory pages:

| Issuer | Card program | Published rate |
|---|---|---|
| **Scotiabank** | Yes | **$110–175 CAD per approved card** |
| **RBC** | Yes | not published — "ask us" |
| **Tangerine** | Yes | not published |
| **Neo Financial** | Yes | not published |
| **Simplii** | Cash Back Visa, limited launch | not published |
| BMO | banking/mortgage only, **no card** | $100 CAD banking |

Not publicly listed: TD, Amex Canada, MBNA, CIBC retail cards, PC Financial,
Rogers Bank, Desjardins, National Bank, Canadian Tire. Absence from the public
directory is not proof of absence from the platform.

**Sign up:** `https://app.fintelconnect.com/user-info` · publishers@fintelconnect.com

**Two-stage approval.** Network first (Fintel's terms §1.1: approval *"in its
sole and absolute discretion"*), then **each issuer separately** — every brand
page carries its own "Apply to Promote". Joining Fintel does not get you RBC.
Budget for two rounds.

**Have ready:** legal entity name and address, Canadian tax number, business
phone, PayPal details.

**Choose PayPal for payouts.** The thresholds are not close:
PayPal **CAD $25** · cheque **CAD $75** · wire **CAD $500**. Paid on the 12th
business day monthly, and only after Fintel receives from the merchant.

**One risk to know about.** Fintel sells its bank clients a monitoring product
("Fintel Check") that scans publisher content for compliance and accuracy
against issuer source data. A 148-card catalogue with a stale annual fee or an
expired welcome offer is the most plausible way to get flagged *after* approval.
The verification engine already built for this is the mitigation — run a
freshness pass over the highest-traffic cards before the first bank program goes
live.

---

## 5. CJ Affiliate — for Amex Canada

**Sign up:** `https://signup.cj.com/member/signup/publisher/`

Essentially a one-advertiser play: **American Express Canada**. Evidence is
strong but indirect — a scraped CJ advertiser profile naming CJ and a dedicated
`cjamex@cj.com` contact — and the same source lists a payout range of
*"Sale: 0,00 CAD – 400,00 CAD"*. **Treat that number as unverified.** No other
Canadian issuer could be confirmed on CJ; the advertiser directory is
login-gated.

**Register all properties.** CJ's "Promotional Properties" system gives each
site/app its own PID and exists, in CJ's words, because *"publishers are looking
to monetize apps, browser extensions, social platforms, and more."* Register
`cardcoach.ca` and the iOS app as separate properties. Add Android after it
reaches production, not before.

**Tax:** as a Canadian entity, the **W-8BEN-E** path (or a Certificate of No US
Activities), not the W-9.

**Also two-stage** — network approval, then "Join Program" per advertiser.

---

## 6. After approval — the flip

One file, one line per card, nothing else changes:

```js
"ca_scotiabank_momentum_visa_infinite_visa": {
  "name": "Scotia Momentum Visa Infinite + Card",
  "url": "<the network's tracking link, byte for byte>",
  "network": "fintel",
  "sponsored": true
},
```

That automatically produces the "Sponsored" badge, `rel="sponsored"`, and the
paid-disclosure copy on `/best-card`. Then deploy the site (human action) and
verify on the live page.

**Do not wrap the tracking link.** Fintel's terms §5.2(h) prohibit *"making
unauthorized changes to any tracking links."* Click measurement is handled by a
beacon that leaves the `href` untouched — see `AFF-001` in the migration and the
`affiliate-click` edge function. This is why the parked `/go/<slug>` redirect
idea was not built.

---

## 7. What could not be verified

Stated rather than estimated:

- **No network publishes a traffic minimum.** Verified absence from published
  material — not evidence of what reviewers apply informally.
- **No approval SLA from Fintel or CJ.** FlexOffers publishes 1–2 business days;
  the other two publish nothing. Do not plan around a date.
- **Amex Canada on CJ** — strong circumstantial evidence, not confirmed by CJ or
  Amex directly.
- **The "$0–400 CAD" Amex payout** — a scraped figure. Do not model on it.
- **Rates for RBC, Tangerine, Neo, Simplii** — not published. Scotiabank's
  $110–175 CAD is the only published Canadian card CPA found anywhere.
- **Whether a live app improves approval odds** — not stated by any network.
