# COMPLIANCE — Statement import & counterfactual earnings (APP-024 / API-020 / API-021 / API-022)

Date: 2026-08-20 · Status: **DRAFT COPY, NOT PUBLISHED** · Template: `COMPLIANCE_loyalty_stacking_pack_2026-08-01.md` §3

Covers DESIGN_statement_import_v1 §5.4. Nothing here has been deployed — the site's deploy
repo is a production push and is human action only (`card_coach_website/README.md`).

---

## 0. The finding that comes first: there is no collection list to add to

§5.4 says *"the privacy policy's collection list must name this, with purpose and deletion
path… Both the `/en/` and `/fr/` policy pages need it."* Checked against the live tree
2026-08-20. Three of those four assumptions are wrong, and this is a pre-existing gap that
statement import merely surfaces:

1. **There is no privacy policy with a collection list.** `site/privacy.html` is a
   five-block plain-English summary ("We never ask for your bank login", "We don't sell your
   data"). It has no enumeration of what is collected, no stated purposes, no retention
   period, and no Law 25 disclosures.
2. **`/privacy` and `/legal` point at each other for it.** `privacy.html:99` offers *"Want
   the legal version? Read our full Privacy Policy →"* linking to `/legal`. `legal.html` is
   **Terms of Use**, and its §3 says *"See our Privacy Policy for full details on data
   handling"*, linking back to `/privacy`. The full policy is referenced twice and exists
   nowhere.
3. **There are no `/en/` and `/fr/` pages.** The site is 25 flat English HTML files.
   `privacy.html:2` is `<html lang="en-CA">`. There is no French page anywhere on the site
   and no `hreflang`. BRAND.md:199-204 specifies the bilingual architecture as a
   requirement; it has not been built.

**Consequence.** The copy below cannot be "added to the collection list", because there is
no list. It is drafted so it can be dropped in the moment a policy page exists, and in the
meantime the smaller change in §3 — which corrects a claim that statement import would make
false — should land regardless.

**This is a launch blocker for the feature in Quebec, not a nice-to-have.** Law 25 requires
the collection of personal information to be disclosed with its purposes. A statement is the
heaviest data class this product has touched. It should not be enabled for Quebec users
before a real policy page exists in French.

---

## 1. Law 25 — the collection-list entry (English)

> **Credit card statements you choose to analyse.** When you use statement analysis,
> CardCoach reads the statement **on your phone**. The file itself is never uploaded, never
> stored, and is discarded when you close the screen. Two things leave your device, in
> separate requests that are never joined: a list of merchant names with no amounts and no
> dates, so we can work out what category each purchase belongs to; and a list of amounts
> and dates with those categories attached and no merchant names, so we can calculate what a
> different card would have earned. Neither request tells us who you paid, when, and how
> much.
>
> **Why we collect it.** To answer one question you asked us: whether the card you used was
> the best card you already had, or whether a different card would have earned you more on
> spending you have already done.
>
> **No data is pulled from your bank.** CardCoach has no connection to your accounts and
> never asks for banking credentials. Statement analysis works on a file you already have
> and choose to give us.
>
> **If you choose to save an import.** Analysis alone keeps nothing. If you separately
> choose to save the results, the purchases are stored the same way as purchases you log by
> hand, tagged to that import. You can undo a saved import at any time, which deletes every
> purchase it added.
>
> **Deleting it.** Deleting your account removes everything, including saved imports, through
> the same deletion path as the rest of your data — see [Delete your account](/delete-account).

**Retention:** analysis retains nothing. A saved import retains the transaction rows plus a
summary row holding counts, totals and a date range — deliberately not the file, the
merchant names, the account number, or the statement descriptors.

**Deletion path, technically:** `delete-account` edge function cascade (covers
`statement_imports` via `ON DELETE CASCADE` on `user_id`; DATA-022 p4 adds it to the
function's explicit table list and `verify_data_022.mjs` asserts it appears there), plus
D11's per-batch undo, which is a delete by `import_batch_id`.

---

## 2. Law 25 — the collection-list entry (French, rewritten for a Quebec reader)

Per BRAND.md:199-204 — legal pages need separate French legal copy, **rewritten, not
translated**, because Quebec is a distinct market. This is drafted rather than machine
translated, and still needs human review by a French-first reader before it is published.

> **Les relevés de carte de crédit que vous choisissez d'analyser.** L'analyse se fait
> **sur votre appareil**. Le fichier n'est jamais téléversé ni conservé : il est supprimé dès
> que vous quittez l'écran. Deux éléments seulement sortent de votre appareil, dans des
> requêtes distinctes qui ne sont jamais réunies : d'une part les noms de commerçants, sans
> montants ni dates, pour déterminer la catégorie de chaque achat ; d'autre part les montants
> et les dates accompagnés de ces catégories, sans aucun nom de commerçant, pour calculer ce
> qu'une autre carte vous aurait rapporté. Aucune de ces deux requêtes ne révèle à qui vous
> avez payé, quand, et combien.
>
> **La raison de cette collecte.** Répondre à la question que vous nous posez : la carte que
> vous avez utilisée était-elle la meilleure que vous déteniez déjà, ou une autre carte
> vous aurait-elle rapporté davantage sur des achats que vous avez déjà faits ?
>
> **Aucune donnée n'est tirée de votre institution financière.** CardCoach n'a aucun lien
> avec vos comptes et ne demande jamais vos identifiants bancaires. L'analyse porte sur un
> relevé que vous possédez déjà et que vous choisissez de nous soumettre.
>
> **Si vous choisissez de conserver une analyse.** L'analyse seule ne conserve rien. Si vous
> décidez séparément d'enregistrer les résultats, les achats sont conservés de la même
> manière que ceux que vous inscrivez à la main, en étant rattachés à cette importation.
> Vous pouvez annuler une importation enregistrée à tout moment ; tous les achats qu'elle a
> ajoutés sont alors supprimés.
>
> **La suppression.** La suppression de votre compte efface l'ensemble de vos données, y
> compris les importations enregistrées, par le même mécanisme que le reste — voir
> [Supprimer votre compte](/delete-account).

*Terminology notes for the reviewer:* "relevé" (not "état de compte") is the usual Quebec
term for a credit-card statement; "téléversé" rather than the anglicism "uploadé";
"institution financière" rather than "banque" because it covers caisses populaires, which
matters in Quebec.

---

## 3. A claim on the live site that statement import makes false

This one is independent of the missing policy page and should be fixed whenever the feature
ships, because it is a factual claim on a shipped marketing page.

`site/privacy.html`, the fifth block, currently reads:

> **We use the minimum data needed** — CardCoach asks for what it needs to give you a
> recommendation — your cards and the purchase context. **That's it.**

"That's it" stops being true once a statement's worth of merchant names, amounts and dates
can reach the server. Proposed replacement, which keeps the block's voice:

> **We use the minimum data needed** — CardCoach asks for what it needs to answer the
> question you asked: your cards and the purchase in front of you. If you choose to analyse
> a statement, it is read on your phone and the file never leaves it.

The two neighbouring blocks were checked and remain accurate:

- *"We never ask for your bank login"* — still true, and more pointedly so. Statement import
  is the alternative to a bank login, not a step toward one.
- *"We don't track your purchases automatically"* — still true. Every import is user-
  initiated, and analysis persists nothing unless the user separately chooses to save it.

---

## 4. Quebec pre-activation checklist (this feature)

1. **Charter of the French Language (Bill 96).** APP-024's in-app strings ship in en/fr and
   `pnpm verify:i18n-parity` passes (checked 2026-08-20: `[QA-002] i18n parity OK (en/fr)`).
   The **website** copy is the gap, not the app copy. Any App Store listing text that
   mentions statement analysis needs a French version too.
2. **Law 25 (privacy).** §1 and §2 above. **Blocked on there being a policy page to put them
   on** (§0). Statement data is personal information of a heavier class than anything the
   product has collected before; the disclosure is not optional.
3. **Consumer protection (CPA).** The headline is a counterfactual projection, not a promise.
   DESIGN §9.1's recommendation — forward-looking gain framing, *"you could earn +$247"* —
   is also the CPA-safe framing, because it is conditional on its face. A loss framing
   ("you lost $247") asserts a realised harm and should not ship for that reason as well as
   the brand one. Whatever ships must keep the conditional verb.
4. **Accuracy disclosure.** D4's coverage figure and D9's "what this does not price" belong
   on the result screen, not only in the policy — a number derived from 60% of a statement
   should say so where the number is shown.

---

## 5. Where each artefact goes

| Item | Destination | Status |
|---|---|---|
| §1 EN collection entry | a privacy policy page that does not yet exist | **blocked** (§0) |
| §2 FR collection entry | ditto, French | **blocked** (§0), and needs French-first human review |
| §3 privacy.html correction | `card_coach_website/site/privacy.html` | ready; deploy is a human push |
| Bilingual site architecture | BRAND.md:199-204 | **not built** — own ticket, precedes Quebec launch |
| A real privacy policy | new page | **not built** — own ticket, precedes Quebec launch |

Nothing in this pack has been applied to the site. The deploy repo is pushed by hand
(`git --git-dir=card_coach_website/.cardcoach-site.git …`), and pushing deploys to
production.
