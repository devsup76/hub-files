# Merchant Onboarding & Go-Live RUNBOOK

> Operational, decision-ready. For onboarding the **first 1-5 merchants** onto a bespoke storefront at `<name>.woahh.app`.
> Last updated: 2026-06-07. Scope: woahh storefront-platform go-live.
> Source of truth for branches/migrations: this repo + `feat/storefront-platform`.

---

## 1. TL;DR — first 1-5 merchants

**Concierge onboarding, pilot on a single custom subdomain.** You (the founder) do the setup; the merchant just hands over their menu, logo, and colours.

1. **Once:** run the 3 pending migrations + regen types, merge `feat/storefront-platform` → `main` (Cloudflare rebuilds prod), allow `https://*.woahh.app/**` in Supabase Auth (§2).
2. **Per merchant:** create/confirm their org, import their menu, set logo/colours in Branding, pick a template in the picker, publish (§3).
3. **Give them their address:** add `<name>.woahh.app` as a Cloudflare DNS CNAME + Pages custom domain, then run the guarded `UPDATE` to set their `subdomain_slug` (§4).
4. **Verify:** `<name>.woahh.app` shows their storefront with their template + live menu; apex unchanged (§5).

For 1-5 merchants, use a **single `<name>.woahh.app` custom domain per merchant** (simplest, covered by Universal SSL). Move to a `*.woahh.app` wildcard only when you scale past a handful (§2, optional).

**Hard gate:** do **not** take real cards until C1 (server-side order-total validation) is fixed — the order RPC currently trusts the client total. Pilot with pay-at-venue / dine-in or test cards only (§6).

---

## 2. One-time platform setup (do once)

### 2a. Run the 3 pending migrations on the LIVE DB (in this exact order)

Owner runs these in the Supabase SQL editor (project `pmnyhbhtkcfoozkinieo`), in order:

1. `20260603010000_storefront_config.sql` — `storefront_config` table + `get_public_storefront_config` RPC.
2. `20260603020000_guard_subdomain_slug.sql` — `guard_subdomain_slug` trigger (rejects reserved slugs like `mail`/`admin`/`www`; auto-suffixes on insert).
3. `20260607010000_storefront_template_variants.sql` — template-variant support.

### 2b. Regenerate types

After the migrations apply, regenerate `src/integrations/supabase/types.ts` and commit it:

```
npx supabase gen types typescript --project-id pmnyhbhtkcfoozkinieo > src/integrations/supabase/types.ts
```

### 2c. Merge `feat/storefront-platform` → `main`

Merging triggers a Cloudflare rebuild of prod from `main`. After it deploys, verify apex (`woahh.app`) is unchanged before doing anything subdomain-related. (A branch push only builds a Cloudflare *preview* — the custom subdomain cannot be tested on a preview; see §6.)

### 2d. Supabase Auth redirect allow-list

In Supabase → Auth → URL Configuration, add the storefront origins so customer magic-links / auth redirects resolve:

- **Pilot (per-host):** add each `https://<name>.woahh.app/**` you go live with.
- **Scale:** add `https://*.woahh.app/**` once and stop maintaining the list.

### 2e. (Optional) Wildcard DNS vs single-host

| Approach | When | What you do |
|---|---|---|
| **Single-host (recommended for pilot)** | 1-5 merchants | One CNAME + one Pages custom domain per merchant (`<name>.woahh.app`). Universal SSL covers it (one wildcard level = single-label slugs). |
| **Wildcard** | scaling past a handful | Add a `*.woahh.app` CNAME → the `woahh-app` Pages project + add `*.woahh.app` as a Pages custom domain. Universal SSL covers one level only, so **single-label slugs only** (`name.woahh.app`, never `a.b.woahh.app`). |

---

## 3. Per-merchant onboarding (concierge)

The storefront reads the merchant's **live** menu, hours, and branding from their normal dashboard automatically — you only set the template-specific choices in the picker.

1. **Create / confirm the org.** Merchant signs up (restaurant), or you confirm their existing org. Confirm tier is **solo** or higher (the storefront picker is solo-tier-gated).
2. **Menu in.** Either run **AI menu import** (chatbot in the dashboard) from their existing menu/photo, or enter products manually in **Menu**. Set hours in **Operations**. These feed the storefront live.
3. **Branding.** In **Branding**, upload their logo and set their colours (HSL). This is the merchant-palette layer the storefront theme uses.
4. **Pick a template.** Go to `/business/dashboard/storefront` (the picker). Choose one of the curated restaurant templates, then set the template-specific bits: **logo, colours, hero copy**. (This writes their `storefront_config`.)
5. **Publish.** Set the config to published (`is_published = true`) in the picker. Until it's published, the public storefront falls back to the default layout — unconfigured/unpublished merchants render exactly as today.

---

## 4. Give them `<name>.woahh.app`

Do these for each pilot merchant. Pick `<name>` = a single-label slug (lowercase, no dots).

1. **Cloudflare DNS.** Add a CNAME record: `<name>` → the `woahh-app` Pages project hostname (e.g. `woahh-app.pages.dev`), proxied (orange cloud).
2. **Pages custom domain.** In the `woahh-app` Pages project → Custom domains → add `<name>.woahh.app`. Wait for it to go active.
3. **TLS note.** Universal SSL covers **one** wildcard level, so a single-label `<name>.woahh.app` is covered automatically. Multi-label slugs are not — keep slugs single-label.
4. **Set the slug (guarded column UPDATE).** In the Supabase SQL editor, run the literal statement (no dedicated RPC needed for one merchant — the `guard_subdomain_slug` trigger validates it):

   ```sql
   UPDATE public.organizations
   SET subdomain_slug = 'name'
   WHERE id = '<ORG_UUID>';
   ```

   **Reserved-name caveat:** the `guard_subdomain_slug` trigger **rejects** reserved/system slugs (`mail`, `admin`, `www`, and the rest of the reserved set) and malformed slugs. If the UPDATE errors, the chosen name is reserved or invalid — pick another single-label slug. (On INSERT the trigger auto-suffixes so signup never breaks; on UPDATE it rejects, so an explicit set must use a clean name.)
5. **Supabase Auth.** If you went single-host (§2d), add `https://<name>.woahh.app/**` to the Auth redirect allow-list now. (Skip if you already added `https://*.woahh.app/**`.)

---

## 5. Verify checklist

Open `<name>.woahh.app` in a fresh browser and confirm:

- [ ] `<name>.woahh.app/` boots **their** storefront (their picked template + branding), not the marketing landing.
- [ ] The menu shown is their **live** menu (add/edit a product in Menu → it appears, via realtime/refresh).
- [ ] `<name>.woahh.app/business` and `<name>.woahh.app/eat` **redirect to apex** (`woahh.app/...`) — the ApexOnly guard.
- [ ] Apex `woahh.app` is **unchanged** — marketing landing, `/eat` marketplace, `/business/*` dashboard all behave exactly as before.
- [ ] **Install the PWA** from `<name>.woahh.app` → it installs as **their** brand (name/icon from their org), not "Woahh". (Apex still installs as "Woahh" from the static manifest.)
- [ ] A test order flows through to the merchant's Orders/KDS (using pay-at-venue / dine-in or a test card — NOT a real card; see §6).

---

## 6. Known limits / order of operations

- **Custom subdomain can't be tested on a branch preview.** `<name>.woahh.app` resolution + the per-merchant manifest only work on **prod** (apex). You must **merge `feat/storefront-platform` → `main`** and let Cloudflare rebuild before any subdomain works. A Cloudflare *preview* (branch push) won't carry the custom domain.
- **C1 hold — no real cards yet.** The order RPC (`create_order_with_inventory`, migration `20260601093000`) inserts the **client-supplied** `p_total` as `orders.total_amount` and does **not** recompute the total from product prices × quantity, nor consume/apply the promo server-side (despite the `api.ts` comment). A client can post a $0.01 total for a real cart, and `stripe-payment-intent` charges that stored amount. **Do not take real cards until C1's server-side total recompute lands.** Pilot with pay-at-venue, dine-in, or Stripe test cards only.
- **Still preview-only / pending integration.** The bespoke `ThemeShell`/home stack is proven in `StorefrontPreview.tsx` but the **live** `PublishedStorefront` still renders the older section renderer — switching it over (and pointing the picker at all 8 curated restaurant templates with bespoke previews) is integration work on `feat/storefront-platform`, not yet on `main`. Confirm this is merged before relying on a bespoke template in prod.
- **Order of operations:** migrations (§2a) → types regen (§2b) → merge to main (§2c) → Auth allow-list (§2d) → per-merchant onboarding (§3) → DNS + Pages domain + slug UPDATE (§4) → verify (§5). Don't set a `subdomain_slug` before the guard trigger migration is applied.
