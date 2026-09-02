# RUNBOOK — Store accounts + RevenueCat: what is done, what is gated on Mike, what Alex does

**Date:** 2026-09-01 · **Owner:** Mike · **Lane:** revenue
**Companion to:** `RUNBOOK_pro_go_live_2026-08-24.md` (the why; still correct) and
`mobile_app_codebase/docs/runbooks/BILL-001_revenuecat_setup.md` (the original mechanics).
**Supersedes in part:** the *prices* and *trial length* in both — those documents say
$4.99 / $39.99 with a 7-day trial; the 2026-08-28 pricing decision (`PRICING_TIERS_2026-08-28.md`)
is **$7.99/mo, $59.99/yr, 14-day trial**. Product identifiers are unchanged on iOS and are
restructured on Android (§2).

Verified against the live dashboards and the production database on 2026-09-01, not remembered.

---

## 0. Where it stands tonight

| | State | Who unblocks it |
|---|---|---|
| RevenueCat project `CardCoach` (`proj58aeb9b3`) | exists (Mike created it 2026-09-01 ~23:03 UTC) | — |
| Entitlement `cardcoach_pro` | **exists**, matches `billing_tiers.provider_entitlement_id` exactly (checked in prod) | — |
| Play Store app config `com.cardcoach.mobile` (`appaa92a04c0d`) | **created**; no service-account JSON yet, so RevenueCat cannot validate Play purchases or import products | Mike (upload the JSON — §3.2) |
| Play products `cardcoach_pro:monthly`, `cardcoach_pro:annual` | **created** in RevenueCat, **attached** to `cardcoach_pro`. Store status "could not check" until the JSON is uploaded and the Play Console subscription exists | Mike (§3.2, §4) |
| Offering `default` | `$rc_monthly` + `$rc_annual`; each holds the Test Store product **and** the Play product. Auto-generated `$rc_lifetime` package **removed** — there is no lifetime decision and the paywall renders whatever the offering contains | — (iOS products slot in later) |
| App Store app config | **cannot be created.** RevenueCat requires the In-App Purchase `.p8` key, Key ID and Issuer ID at save time, and refused the form without them. That key must come from the **new** CardCoach team | Mike → Apple enrolment (§1) → then Claude/Mike (§3.1) |
| Secret REST key (`sk_…`), webhook auth secret, EAS env vars | **none created** — credential handling is left to Mike by design | Mike (§3.3) |
| Supabase | `billing_events` = **0 rows**; `billing_paywall`, `card_slot_limit`, `auto_location_gate` all **false** (flipped off for build 84; correct — nothing is advertised that cannot be sold) | — |
| Google Play merchant account | **does not exist.** Play Console → Monetize → Subscriptions shows "You need to set up a Google Payments merchant account". This blocks *creating* Play subscriptions at all | Mike (§4) |
| Apple: CardCoach Inc. Organization membership | **does not exist.** Not signed in to developer.apple.com in the browser; the only Apple team is Alex's Individual `AF887JD7ZG`, where `mike@card.coach` is Admin | Mike (§1) |

**Net:** every remaining step is gated on one of three things only Mike can do — enrol the
company with Apple, open a Google Payments merchant profile, and mint/paste secrets. The
RevenueCat side is otherwise as far as it can go.

---

## 1. Apple — enrol CARDCOACH INC. (Mike, ~1–2 weeks calendar)

Decision recorded 2026-09-01: **new Organization membership + app transfer from Alex.** Not an
in-place Individual→Organization migration (unpredictable timeline; see the 2026-08-24 runbook §1).

1. **D-U-N-S.** https://developer.apple.com/enroll/duns-lookup/ — search the exact legal name
   and registered address first; many Canadian corporations already have one. If not, request it
   there (free). D&B up to 5 business days + Apple 2 business days. **Start this first; it is
   the long pole.**
2. **Apple Account for the Account Holder.** Apple recommends an address on the organisation's
   domain with the person's legal name and 2FA on. Two viable choices:
   - `mike@card.coach` — the Apple ID Mike already has; it is only *Admin* on Alex's team, so it
     is free to become Account Holder of a new membership, and it already has 2FA. Fewer Apple IDs.
   - a new `mike@cardcoach.ca` Apple ID — cleaner brand match, one more identity to manage.
   Either is fine. What matters is that the *Account Holder* is Mike, not Alex.
3. **Enrol** at https://developer.apple.com/register/ → Organization. Needs: legal entity name
   (CARDCOACH INC., exactly as registered — no trade names), D-U-N-S, headquarters address (no PO
   box), a phone number, a working public website on the org's domain (cardcoach.ca qualifies),
   and confirmation of legal binding authority. US$99/yr. Apple may phone to verify.
4. **Do NOT create an app record for `com.cardcoach.mobile` in the new account.** Bundle IDs are
   unique across App Store Connect; a pre-existing record with that ID would block Alex's
   transfer. The transfer brings the record, the reviews, and the ratings with it.
   (Registering the *identifier* `com.cardcoach.mobile` in Certificates, Identifiers & Profiles
   is also unnecessary — it moves with the app.)
5. Once the membership is active: **Business → Agreements → Paid Apps → agree** (Account Holder
   only, irreversible), then **Banking** (CardCoach Inc.'s account, name must match the entity)
   and **Tax → W-8BEN-E**. Status must read **Active**, not "Pending User Info", before any
   subscription can be sold. Do this *before* accepting the transfer if possible — a transfer
   requires both parties to have accepted the latest agreements.

## 2. The transfer (Alex initiates, Mike accepts)

**Alex's pre-flight on `AF887JD7ZG` (all required by Apple's transfer criteria):**
- The app has a released version ✅; confirm **no version** is in Waiting for Review / In Review
  / Pending Developer Release / Processing at the moment of transfer.
- **TestFlight: turn it off** — remove all builds and testers, and clear every Test Information
  field in every localization. (Build 84 testers lose TestFlight access until Mike re-invites
  them from the new team. Tell them.)
- **Xcode Cloud:** remove all Xcode Cloud data (Settings). Probably none — EAS builds.
- **Sign in with Apple:** if the app is in a *group* of SIWA apps, ungroup it. Then Alex
  generates **transfer identifiers** for existing users (Apple's REST endpoint) and hands them to
  Mike. The receiving team has **60 days after the transfer** to exchange them for its own `sub`
  values or those users lose their accounts. `expo-apple-authentication` users only — **11
  accounts** as of 2026-09-01 (`auth.users` where `raw_app_meta_data->>'provider' = 'apple'`;
  69 email, 5 Google). Small, but each loses sign-in if the window is missed. Schedule the
  migration inside it.
- **Subscriptions:** none exist yet, so **no app-specific shared secret handoff is needed** —
  this is exactly why the transfer happens *before* products are created.
- **App Group `group.com.cardcoach.mobile`** (widget): re-register on the new team afterwards.
  Not a blocker on iOS.
- Initiate: App Store Connect → the app → App Information → **Transfer App** → enter the
  recipient's **Team ID** and the recipient Account Holder's **Apple Account email**. Alex must be
  Account Holder (he is).

**Mike accepts** (Account Holder role, within 60 days of the request). Then, on the new team:
- Generate a **new App Store Server / In-App Purchase key** and give it to RevenueCat (§3.1).
- Recreate **APNs** if push is ever added (not today). Re-register the **App Group**.
- **EAS:** `apps/mobile/app.config.ts` → `ios.appleTeamId` changes from `AF887JD7ZG` to the new
  Team ID; `eas.json` `submit.production.ios.ascAppId` **stays `6757937693`** (the app record
  keeps its ID). Run `eas credentials` to generate a distribution certificate + provisioning
  profiles on the new team, and add `mike@…` as the ASC API key / app-specific-password user for
  `eas submit`. The **widget extension target** needs its own profile on the new team too.
- **Sign in with Apple:** the Service ID transfers with the app unless removed; Supabase Auth's
  Apple provider is configured with a client ID and key from Alex's team — regenerate the **Sign
  in with Apple key** on the new team and update Supabase → Auth → Providers → Apple, then run the
  `transfer_sub` migration inside the 60-day window.

## 3. RevenueCat — what remains (requires §1 first for iOS)

### 3.1 App Store app (after the transfer)
App Store Connect → **Users and Access → Integrations → In-App Purchase → Generate**. Download
the `SubscriptionKey_XXXXXXXXXX.p8` (one download only — keep it), note the **Key ID** and the
**Issuer ID**. RevenueCat → Apps → **New app configuration → App Store**: name
`CardCoach (App Store)`, bundle ID `com.cardcoach.mobile`, upload the `.p8`, Key ID, Issuer ID
→ Save. Then **Products → CardCoach (App Store) → Import** once §5's products exist in ASC, and
attach both to `cardcoach_pro`, and add them to `default` → `$rc_monthly` / `$rc_annual`.

Also on that page: **App Store Server Notifications** URL — copy RevenueCat's URL into ASC →
the app → App Information → App Store Server Notifications (Production *and* Sandbox, Version 2).

### 3.2 Play Store app (now — Mike has the JSON)
RevenueCat → Apps → **CardCoach (Play Store)** → Service Account Credentials JSON → upload the
Play service-account key created 2026-08-24 (the same one meant for `eas submit`), Save. That
service account needs, in Play Console → Users and permissions: **View financial data**, **Manage
orders and subscriptions**, and (for import) **View app information**. Then enable **Google
developer notifications** on the same page (RevenueCat gives a Pub/Sub topic; paste it into Play
Console → Monetize → Monetization setup → Real-time developer notifications). Product "Store
status" turns green once the Play subscription in §4 exists.

### 3.3 Secrets (Mike, from his own shell — Claude does not handle credentials)
```bash
# RevenueCat → API keys → New secret API key (label: supabase-billing) → sk_...
cd ~/dev/CardCoachv2/mobile_app_codebase
supabase secrets set --project-ref hrzpznlpmxxrbtwskacu \
  REVENUECAT_API_KEY="sk_..." \
  REVENUECAT_WEBHOOK_SECRET="$(openssl rand -hex 32)" \
  REVENUECAT_ALLOW_SANDBOX=1          # UNSET BEFORE GA (RUNBOOK_pro_go_live §8)
supabase secrets list --project-ref hrzpznlpmxxrbtwskacu   # copy the WEBHOOK_SECRET value

# RevenueCat → Integrations → Webhooks → Add new configuration
#   URL: https://hrzpznlpmxxrbtwskacu.supabase.co/functions/v1/revenuecat-webhook
#   Authorization header: <the exact REVENUECAT_WEBHOOK_SECRET value>
#   Environment: Production + Sandbox; all event types
#   → Send test event → expect 200 {"ok":true,"outcome":"noop"} and a TEST row:
#     select event_type, outcome from public.billing_events order by received_at desc limit 1;

# Public SDK keys → EAS (RevenueCat → API keys → SDK API keys; the Play one exists now,
# the App Store one appears after §3.1)
eas env:create --environment production --name CARDCOACH_REVENUECAT_ANDROID_KEY --value goog_... --visibility plaintext
eas env:create --environment production --name CARDCOACH_REVENUECAT_IOS_KEY     --value appl_... --visibility plaintext
# repeat for preview/development if those profiles need a paywall that can sell
```
`verify:bill-002` fails until the TEST row exists — that is deliberate.

### 3.4 Deliberately not done
- **RevenueCat Paywalls** (the visual editor): not used. The app ships its own paywall that
  renders the `default` offering's packages; `billing.paywall.legal` carries the disclosure.
- **Sandbox testing access** left at *Anybody* (project settings). Tighten to allowed App User
  IDs, or rely on `REVENUECAT_ALLOW_SANDBOX` being unset, before GA.
- **Collaborators:** none added. Alex does not need RevenueCat access for the transfer.

## 4. Google Play — merchant account, then the subscription (Mike)

1. Play Console → **Set up a merchant account** (from the Subscriptions page). Google Payments
   profile for **CardCoach Inc.** — business details, address, bank, tax. Mike only.
2. Monetize with Play → Products → **Subscriptions → Create subscription**:
   - Product ID **`cardcoach_pro`**, name "CardCoach Pro".
   - Base plan **`monthly`** — auto-renewing, 1 month, CAD **$7.99**; **Offer** `intro-trial-14d`
     type Free trial, 14 days, eligibility "new customer acquisition".
   - Base plan **`annual`** — auto-renewing, 1 year, CAD **$59.99**; same 14-day free-trial offer.
   - Mark both base plans **backwards compatible** (RevenueCat's products were created with
     that flag on; it only matters for legacy billing-library clients, but keep them consistent).
   - Activate both base plans and both offers.
   - Other-country prices: let Play auto-convert from CAD; the app renders `priceString`.
3. Why one subscription with two base plans rather than two subscriptions: it is Google's current
   model (upgrade/downgrade between plans is native), and RevenueCat's Play identifiers are
   `subscriptionId:basePlanId` by construction. The webhook grants by **entitlement id**, never by
   product id (`_shared/revenuecat.ts` only *records* `product_id` in `billing_events`), so the
   iOS/Android identifier asymmetry is harmless. The RevenueCat products already reflect this.
4. Android subscriptions are only purchasable from a **production** Play release. The app is on
   the internal track; that is a separate lane.

## 5. App Store Connect — the subscription (after §1 + §2)

The app → **Subscriptions → Create Subscription Group** "CardCoach Pro" (reference name; users see
the localized display name). In the group:
- **`cardcoach_pro_monthly`** — 1 month, CAD **$7.99** (price-tier equivalent), display name
  "CardCoach Pro Monthly"; **Introductory Offer**: Free, 14 days, all countries.
- **`cardcoach_pro_annual`** — 1 year, CAD **$59.99**, "CardCoach Pro Annual"; same 14-day free
  intro offer.
- Group **ranking**: annual level 1, monthly level 2 (so annual→monthly is a downgrade).
- Localizations en-CA + fr-CA; review screenshot of the paywall; **Privacy Policy URL** and
  **Terms of Use (EULA)** on the app record. `https://cardcoach.ca/privacy` resolves (it is a
  short privacy overview, not a full policy — worth a legal-grade rewrite before selling).
  **`https://cardcoach.ca/terms` returns 404** — Apple requires a Terms of Use link for
  auto-renewable subscriptions. Either publish a terms page or leave the custom EULA field empty
  so Apple's standard EULA applies, and reference the same in the paywall's legal footer.
- Status must be **Ready to Submit**; they are submitted with the next binary. Product IDs here
  must match what RevenueCat imports (§3.1) — these are the two strings BILL-001 fixed.

## 6. Order of operations, restated with today's state

```
DONE   RevenueCat: project, entitlement, Play app, Play products, default offering
NOW    Mike: D-U-N-S lookup/request                      (long pole, free, ~7 business days)
NOW    Mike: Google Payments merchant profile             (unblocks §4)
NOW    Mike: upload Play service-account JSON to RC      (§3.2)  → Claude can then import/verify
NOW    Mike: secrets + webhook + test event + EAS keys   (§3.3)  → billing_events gets its TEST row
THEN   Mike: Play subscription cardcoach_pro / monthly / annual + 14-day trial (§4)
THEN   Mike: Apple Organization enrolment → Paid Apps + banking + W-8BEN-E → Active (§1)
THEN   Alex: TestFlight off, SIWA transfer ids, Transfer App → Mike accepts (§2)
THEN   Mike/Claude: ASC In-App Purchase key → RC App Store app; ASC subscription group (§3.1, §5)
THEN   new store build (react-native-purchases key moves the fingerprint — no OTA path),
       sandbox purchase, verify:bill-002 = CAN SELL, submit, unset ALLOW_SANDBOX,
       flip billing_paywall, LAST flip card_slot_limit + auto_location_gate (pro_go_live §7–8)
```

## 7. Open items surfaced today
- **`cardcoach.ca/terms` is a 404** and the privacy page is an overview, not a policy. Both are
  App Review inputs for a subscription app.
- **11 Sign-in-with-Apple users** to migrate within 60 days of the transfer.
- **Sentry** still under `falcon-view-group` (WORKING_NOTES 2026-08-28) — same class of problem
  as the Apple team; not addressed here.
- **Expo account 2FA is off** (same note). It holds both stores' signing credentials and is
  about to hold the RevenueCat public keys. Turn it on.
- The two runbooks this document leans on still print $4.99 / $39.99 / 7 days. They are
  append-only records; read prices from `PRICING_TIERS_2026-08-28.md` and this file.
