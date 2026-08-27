# CardCoach Pro — the go-live sequence

**Date:** 2026-08-24 · **Owner:** Mike · **Lane:** revenue
**Supersedes nothing.** `docs/runbooks/BILL-001_revenuecat_setup.md` remains
correct for everything it covers. This document exists because BILL-001 starts
at step 2 — "App Store Connect and Play Console" — and assumes the accounts are
already able to take money. They are not, and the reasons are structural.

---

## 0. Where this actually stands

Verified against production on 2026-08-24, not remembered.

**Further along than the runbook suggests:**

| | |
|---|---|
| Schema, catalogue, tiers, ledger | applied 2026-08-18 ✅ |
| `revenuecat-webhook` + `billing-sync` edge functions | **deployed** ✅ |
| `billing_paywall` | **already TRUE** (step 7a done) ✅ |
| `ambient_widget` / `receipt_scanner` / `statement_import` | true (7b done) ✅ |
| `online_merchant` entitlement | correctly hidden (`is_active = false`) ✅ |
| Paywall + 8 Pro surfaces, design pass, 4 device rounds | shipped ✅ |
| `react-native-purchases ^10.7.1` | in dependencies ✅ |

**And yet the app cannot take a single dollar:**

| | |
|---|---|
| `billing_events` row count | **0** — no webhook has ever fired, not even a test |
| `CARDCOACH_REVENUECAT_IOS_KEY` / `_ANDROID_KEY` in EAS | **absent in all three environments** |
| RevenueCat project | does not exist |
| Store subscription products | do not exist |
| Apple Paid Applications Agreement | almost certainly never signed — the app has always been free |

**So the paywall is currently live and advertising a tier the app cannot sell.**
Anyone who taps Pro gets the "not on sale" card. That is graceful, but it is not
free — it is a live promise with nothing behind it.

`pnpm verify:bill-002` now reports this as a single verdict — CAN SELL /
CANNOT SELL / UNKNOWN — so it cannot go unnoticed for a week again.

---

## 1. STOP — the account structure comes first

**Do not create store products on the current Apple account.**

The iOS app is published under Apple Team **`AF887JD7ZG` — Alex Renold
Francois, Individual**. The Play Console account is an **organization** account
under `mike@card.coach`.

Apple pays **the enrolled party**. Apple's banking documentation instructs you
to enter *"the bank account number of the legal entity or individual enrolled in
the Apple Developer Program,"* and publishes **no mechanism to nominate a
corporation as payee** on an Individual account. The US tax form would be a
**W-8BEN in Alex's personal name**, not a W-8BEN-E for the company.

Consequence, stated plainly: **turn on subscriptions today and 100% of iOS
revenue is paid personally to a 24% shareholder**, documented to him for tax,
while the company that owns the product receives nothing directly. Unwinding
that afterwards is a shareholder-benefit and appropriation question for a
Canadian accountant, not a bookkeeping correction.

Two related facts:

- **Only the Account Holder** can sign the Paid Apps Agreement, set banking, or
  transfer the app. That is Alex. The 76% holder has no Apple-level authority.
  Admin and Finance roles cannot substitute.
- Apple's agreement status list includes **Disabled** — *"your app is removed
  from the App Store until you provide the required information."* This is a
  live-app risk, not just paperwork.

### Nothing technically blocks fixing it

Each suspected blocker was checked and none applies:

- **Auto-renewable subscriptions do not block an app transfer.** Apple documents
  a specific procedure for it (an app-specific shared secret handed to the
  recipient).
- **The widget's App Group does not block it.** That restriction is Mac-only.
  On iOS the group is simply re-registered to the recipient afterwards.
- **Sign in with Apple does not block it** — but it is the real engineering cost
  (see below).

### Why before, not after

Transferring while the app is still free avoids all of:

1. the shared-secret handoff for existing subscribers;
2. the IAP status gate — transfers are blocked whenever a subscription product
   sits in Waiting for Review or In Review;
3. the "Pending App Transfer" freeze on pricing and IAP editing, which lands
   exactly when you would be tuning a subscription launch;
4. a split revenue year needing to be unwound between a corporation and a
   shareholder;
5. a larger Sign in with Apple user migration.

### The one item that costs engineering time

**Sign in with Apple identifiers are team-scoped.** Every existing user must be
migrated through Apple's `transfer_sub` flow, and the receiving team has a
**hard 60-day window** after accepting the transfer to exchange transfer
identifiers for its own. Miss it and those users lose their accounts. The app
uses `expo-apple-authentication`, so this is real work, and it only grows.

### Recommended sequence

1. **Check whether the company already has a D-U-N-S number** — many Canadian
   corporations do. If not, request it now: Apple says up to **5 business days**
   from D&B plus **2 business days** for Apple, and acknowledges a two-week
   tail. It is free and costs nothing to start in parallel.
2. **Choose a path.** Migrating the existing Individual membership to an
   Organization membership in place avoids app transfer entirely — no Sign in
   with Apple migration, no shared secret, no provisioning rebuild — but Apple
   publishes **no timeline** for it and developer reports describe accounts
   locked mid-migration for weeks. A **new Organization account plus an app
   transfer** is more work but far more predictable. If the launch date matters,
   take the transfer path.
3. **Pre-clear the housekeeping** before initiating a transfer: turn TestFlight
   off and clear Test Information for every localization, remove Xcode Cloud
   data, ungroup Sign in with Apple apps, and confirm nothing is in review.
4. **Then** sign the Paid Apps Agreement on the organization account.

> **This is a decision, not a task.** It trades roughly two weeks of calendar
> against a revenue-ownership problem that gets more expensive every month it
> runs. It is worth an explicit conversation with Alex before anything else in
> this document happens.

---

## 2. Make the account able to take money

BILL-001 skips this entirely and it is a hard gate: **no subscription can be
sold until the Paid Applications Agreement is *Active*.** Apple: *"This
agreement must be active in order for you to submit or update paid apps and
In-App Purchases."*

Signed is not the same as active. Three steps, and the agreement sits at
**"Pending User Info"** until all three are done:

| Step | Detail | Role required |
|---|---|---|
| Paid Apps Agreement | Business → Agreements → View and Agree. **Cannot be undone.** | **Account Holder only** |
| Banking | One primary account. *"Payments to multiple or split bank accounts aren't supported."* Name must match the enrolled entity exactly. | Account Holder / Admin / Finance |
| Tax | *"All developers must complete a US tax form."* Canadian corporation → **W-8BEN-E**. Apple's questionnaire routes you. | Account Holder / Admin / Finance |

**Confirm the status reads "Active", not "Pending User Info", before continuing.**

Google Play has its own equivalent — a merchant profile and payments profile —
but Android subscriptions are downstream of a **production** Play release, and
the app is on the internal track today. Treat Android as a second phase.

---

## 3. iOS store products

Per BILL-001 §2 — identifiers must match RevenueCat exactly:

- `cardcoach_pro_monthly` — $4.99/month
- `cardcoach_pro_annual` — $39.99/year

Add a **7-day free trial** as an introductory offer on both. The paywall reads
`introPrice` from the store and switches its CTA to "Start free trial" by
itself. Prices are never hardcoded anywhere in the repo — the paywall renders
`priceString` exactly as the store supplies it.

Apple also requires a privacy policy URL and a terms/EULA link, and that the app
offers **Restore purchases** — it does, in the paywall and in Settings.

---

## 4. RevenueCat

1. Create the project; add the iOS app (Android later).
2. Import both products from App Store Connect.
3. **Create ONE entitlement with the identifier `cardcoach_pro`.** This string
   must match `billing_tiers.provider_entitlement_id` exactly — it is the one
   value that has to agree across two systems. `verify:bill-002` asserts the
   client and server halves agree; the dashboard half is on you. Get it wrong
   and purchases succeed and grant nothing, with the webhook recording
   `outcome = 'unknown_tier'`.
4. Create the current offering with `$rc_monthly` and `$rc_annual` packages.
5. Collect three keys: iOS **public** (`appl_...`), Android **public**
   (`goog_...`), and a **secret** REST key (`sk_...`).

---

## 5. Secrets

**Edge functions** — never in the repo:

```bash
supabase secrets set REVENUECAT_WEBHOOK_SECRET="$(openssl rand -hex 32)"
supabase secrets set REVENUECAT_API_KEY="sk_..."
supabase secrets set REVENUECAT_ALLOW_SANDBOX=1   # UNSET BEFORE GENERAL AVAILABILITY
```

**Mobile build** — the two PUBLIC keys, in the EAS build environment:

```
CARDCOACH_REVENUECAT_IOS_KEY=appl_...
CARDCOACH_REVENUECAT_ANDROID_KEY=goog_...
```

The `sk_...` key must never reach a build.

---

## 6. Prove the webhook — do not skip this

`billing_events` has **zero rows**, which means the deployed webhook has never
been exercised even once. RevenueCat → Integrations → Webhooks:

- URL: `https://hrzpznlpmxxrbtwskacu.supabase.co/functions/v1/revenuecat-webhook`
- Authorization header: the exact `REVENUECAT_WEBHOOK_SECRET` value.
- **Send a test event.** Expect `200 {"ok":true,"outcome":"noop"}` and a row in
  `billing_events` with `event_type = 'TEST'`.

If Supabase's gateway returns 401 before the function runs, append
`?apikey=<publishable key>`.

`verify:bill-002` fails until this row exists. That is deliberate — it is the
cheapest possible proof that the integration is real.

---

## 7. A store build is required — measured, not assumed

**The RevenueCat key cannot reach existing installs over EAS Update.**

The open question was whether setting the key moves the runtime fingerprint.
Answered from the installed source rather than argued:

- `@expo/fingerprint@0.15.4` deletes `extra` from the config hash **only** when
  `SourceSkips.ExpoConfigExtraSection` (4096) is set.
- `DEFAULT_SOURCE_SKIPS === 512` (`PackageJsonAndroidAndIosScriptsIfNotContainRun`).
- `apps/mobile/fingerprint.config.js` sets `extraSources` only, no `sourceSkips`.

So `extra` is hashed. Today `revenueCatIosKey` is `undefined` and
`JSON.stringify` drops the key entirely; setting it adds a field, the evaluated
config changes, the fingerprint moves, and **build 82 is stranded**.

`verify:bill-002` re-derives this on every run, so if a future config adds
`ExpoConfigExtraSection` the release assumption gets re-examined rather than
silently inverting.

```bash
cd apps/mobile
pnpm install
eas build --profile production --platform ios
```

Submit and get approved with `billing_paywall` still true — review sees a
working free app and a Pro screen that explains the tier and offers Restore.
Store-product approval and app approval move on different clocks; keeping them
decoupled is deliberate.

---

## 8. Order of operations, end to end

```
0. Decide the Apple account structure          ← THE GATE. Everything waits.
1. D-U-N-S (parallel, free, ~7 business days)
2. Transfer / migrate while the app is free
3. Paid Apps Agreement → Active (banking + W-8BEN-E)
4. App Store Connect subscription products + 7-day trial
5. RevenueCat project, products, entitlement `cardcoach_pro`, offering
6. Supabase secrets; RevenueCat webhook test event → billing_events row
7. EAS env keys → NEW STORE BUILD (no OTA path) → TestFlight
8. Sandbox purchase: verify all six keys granted, outcome = 'granted'
9. pnpm verify:bill-002 → must read CAN SELL
10. Submit to App Store
11. supabase secrets unset REVENUECAT_ALLOW_SANDBOX
12. LAST: flip card_slot_limit and auto_location_gate (BILL-001 §7c)
```

Steps 11 and 12 matter. Sandbox purchases cost nothing and repeat freely — left
enabled, they hand out Pro to anyone with a sandbox account and it looks like
ordinary traffic. And 7c takes away two features that are free today, so it must
come after there is something to buy and after the build that renders the upsell
is in the field.

---

## 9. Rollback

No deploy needed for anything short of a schema problem:

```sql
UPDATE public.runtime_flags SET enabled = false
WHERE key IN ('billing_paywall', 'card_slot_limit', 'auto_location_gate');
```

Existing subscribers keep their grants, which is correct — they paid.

**Consider doing this now.** While the chain is broken, the paywall is a live
promise the app cannot keep. Turning it off costs nothing, is reversible in one
statement, and removes the only user-visible symptom of the current state.

---

## 10. Open items

- **The Apple account decision** — §1. Blocks everything.
- **`useSafeAreaInsets().top` inside the Pro sheets** — still open from the
  pro-lane handoff, and the one thing that needs a person's eyes. The check
  needs no new build: open the Paywall on the phone and look at the X. ~16pt
  below the sheet's rounded edge is correct; ~75pt with an empty band above the
  first content means the inset is being applied where it should not be.
- **Android** — needs a production Play release before subscriptions are
  possible. The organization account means no closed-testing gate applies.
- **fr-CA Pro copy** — written by the pro lane, parity passes, quality
  unreviewed by a locale owner.
