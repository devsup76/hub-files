# OVERNIGHT PLAN — 2026-06-11

> Build-ready implementation plan for tonight, distilled from the read-only analyses in TASK 1 (BATCH 1) + TASK 2 (BATCH 2).
> Single branch: **`feat/overnight-fixes-2026-06-11`**. Branches + Cloudflare previews only — **no merge / no deploy** without founder sign-off.
> HELD (NOT in scope tonight): **#1** (nicer onboarding + ABN-gated payments) and **#8** (subdomain DNS/go-live). Several items stub the #1 ABN gate and the #8 subdomain so they don't block.
>
> Two storefront render paths recur throughout:
> - **DEFAULT** = `src/pages/storefront/RestaurantStorefront.tsx` (+ `RetailStorefront.tsx`)
> - **BESPOKE** = `src/components/storefront/PublishedStorefront.tsx` (bridge) → pure UI `src/components/storefront/screens/Checkout.tsx`, contracts `src/components/storefront/chrome/contracts.ts`
>
> **Cross-cutting invariant:** the `payOnline` predicate lives in exactly TWO places — `RestaurantStorefront.tsx:616-620` and `PublishedStorefront.tsx:405` (mirrored to UI via `world.onlineCardEnabled` `:237-254` / `Checkout.tsx:1028`). Any change to who-can-pay-online MUST update both together so the bridge gate and the UI panel never diverge.
>
> Run `tsc --noEmit && vite build` after each item.

---

## RECOMMENDED IMPLEMENTATION ORDER (single branch — minimizes conflicts)

Conflict hot-spots: `Checkout.tsx`, `RestaurantStorefront.tsx`, `PublishedStorefront.tsx`, `Operations.tsx`, `settings.ts`, `storefrontConfig.ts`, `AppSidebar.tsx`. Sequence to land the widest-surface items first:

1. **#6 — delivery feature flag** (FIRST; widest surface: new `featureFlags.ts` + `settings.ts`/`Operations.tsx`/both storefronts/`Checkout.tsx`/KDS/marketplace)
2. **#13 — pay-at-venue vs pay-online merchant setting** (touches the same payOnline gate on both paths + `settings.ts` + `Operations.tsx`; do right after #6)
3. **#15 — checkout offers account creation BEFORE guest** (touches `Checkout.tsx` ContactStep + `RestaurantStorefront.tsx` checkout dialog — same files as #6/#13, so sequence to avoid self-conflict)
4. **#10 — real live prep/pickup timings** (new `kitchen` prep fields in `settings.ts` + `useStorefrontSettings.ts` + both checkout paths + `contracts.ts world.eta`)
5. **#7 — unpublished storefronts not publicly reachable** (DB migration + `Shop.tsx` + `storefrontConfig.ts` + new `StorefrontComingSoon.tsx`; isolated)
6. **#9 — churn rate-limit on template/branding publish** (DB migration + `StorefrontTemplates.tsx` + `storefrontConfig.ts`; do after #7 — shares `storefrontConfig.ts`)
7. **#16 — smarter auto usernames** (new RPC migration + `Auth.tsx`; signup-only, isolated)
8. **#17 — QR codes usable without dine-in** (`Tables.tsx` only; isolated)
9. **#5 — go-live "setting up & domain" checklist** (new `GoLiveChecklist.tsx` + `DashboardOverview.tsx`; reads #7 publish state — do after #7)
10. **#2 — onboarding checklist auto-collapses done steps** (`OnboardingChecklist.tsx`; coordinate with HELD #1 — #2 is the safe independent subset; can fold into #5's `Step` mechanic)
11. **EXTRA A — "View as customer" owner toggle** (`useIsOwnerPreviewing.ts` + `CustomerHeaderMenu.tsx`; reads same gate as #13 — do after #13)
12. **EXTRA B — scope demo flag off real storefronts** (`Shop.tsx` guards; coordinate with #7 which also edits `Shop.tsx` — do right after #7)
13. **#4 — declutter sidebar** (LAST; `AppSidebar.tsx` only, fully isolated; reflects any route added by #5)

> Note: items 5–13 reorder vs. raw batch order to keep `Shop.tsx` (#7+EXTRA B) and `storefrontConfig.ts` (#7+#9) edits adjacent, and to land the payOnline-touching items (#6, #13, EXTRA A) before the UI-reordering ones.

---

## CHECKLIST

### [ ] #6 — Disable delivery everywhere behind a feature flag — RISK: LOW

Courier code stays in the tree; gates make it unreachable. Re-enable = one env var + rebuild. **No central client flag module exists today** (only server-side `RESERVATION_SMS_ENABLED` pattern). Create one.

- [ ] **NEW `src/lib/featureFlags.ts`** — export `DELIVERY_ENABLED = String(import.meta.env.VITE_DELIVERY_ENABLED ?? "").toLowerCase() === "true"`. Default OFF (env unset → false). Re-enable via Cloudflare Pages build env `VITE_DELIVERY_ENABLED=true`.
- [ ] **`src/components/storefront/PublishedStorefront.tsx:186-210`** — in `merchantFulfillment`, change line ~191 to `if (DELIVERY_ENABLED && f.delivery?.enabled) enabled.push("delivery");`. Removes delivery from `world.enabledFulfillments`; Checkout `FulfillmentStep` (`Checkout.tsx:757`) auto-follows.
- [ ] **`src/pages/storefront/RestaurantStorefront.tsx:244`** — `if (DELIVERY_ENABLED && fulfillment.delivery?.enabled) list.push("delivery");`. Pre-menu gate (`:763`) + submit validation (`:507`) + disabled tile (`:768`) all key off `enabledFulfillments`, so they follow.
- [ ] **`src/components/storefront/screens/Checkout.tsx:739/757`** — for preview/demo (no `enabledFulfillments`), also filter the static `FULFILLMENTS` array: `.filter((m) => m.id !== "delivery" || DELIVERY_ENABLED)`.
- [ ] **`src/pages/dashboard/Operations.tsx:275-292` (Delivery Switch), `:294-411` (delivery config block), `:486` (`DeliveryIntegrationCard`)** — wrap each in `{DELIVERY_ENABLED && (...)}`. Leave `settings.fulfillment.delivery` shape (`settings.ts:112-127`) UNTOUCHED so re-enable restores prior config.
- [ ] **KDS / Orders (`src/pages/dashboard/KitchenDisplay.tsx`, `src/pages/dashboard/Orders.tsx`)** — DO NOT gate the render/color path (in-flight delivery orders placed before flip must still display). Only gate a delivery *filter chip* if one exists (grep `fulfillmentFilter === 'delivery'`).
- [ ] **`src/pages/Storefront.tsx`** — marketing already says delivery is "On the way"/"Soon" (`:362-377,450,458`). No change required; confirm no live "delivery available now" claim (none found).
- [ ] **`src/pages/Marketplace.tsx:277-278`, `src/pages/MarketplaceProfile.tsx:135,345,362`** — gate the delivery-affordance read: `const deliveryEnabled = DELIVERY_ENABLED && !!o.settings?.fulfillment?.delivery?.enabled;`.
- **Verify:** grep `"delivery"` across the tree; each surface is either gated or intentionally render-only (KDS). No data deleted, no schema change, no courier code removed.

### [ ] #13 — Merchant-configurable pay-at-venue vs pay-online — RISK: MEDIUM

Adds an explicit offer-mode switch on top of `online_card_enabled` (which stays the hard server safety gate). `pay_mode` only WIDENS options when `online_card_enabled` is already true.

- [ ] **`src/services/settings.ts:55-67`** — extend `PaymentSettings`: `pay_mode?: "venue" | "online" | "both";` (default `"venue"`).
- [ ] **`src/services/settings.ts:197`** — `payments: { online_card_enabled: false, pay_mode: "venue" }`.
- [ ] **`src/pages/storefront/RestaurantStorefront.tsx:613-620`** — `const payMode = mergedSettings.payments?.pay_mode ?? "venue"; const onlineCardEnabled = mergedSettings.payments?.online_card_enabled === true && payMode !== "venue";`. Add `const showOnlinePay = onlineCardEnabled && !isOwnerPreviewing && fulfillmentChoice !== "dine_in";`.
- [ ] **`src/pages/storefront/RestaurantStorefront.tsx:1510-1537` (wallet/card buttons) + `:1740-1744` (card-footer button label)** — gate on `showOnlinePay`. When venue-only, render a single "Place order — pay at venue" CTA, suppress card/wallet buttons.
- [ ] **`src/components/storefront/PublishedStorefront.tsx:237-238`** — AND `pay_mode !== "venue"` into the `onlineCardEnabled` computation (single source feeds `world` mirror `:254` + bridge `payOnline` `:405`). Pure `Checkout.tsx:1028-1030` (`paysByCardOnline`) auto-follows — no screen change. No contract change (`onlineCardEnabled` already on `StorefrontWorld`, `contracts.ts:152`). Treat `both` and `online` identically on the offer side.
- [ ] **`src/pages/dashboard/Operations.tsx`** — add a "Payments" section (no existing dashboard control for `online_card_enabled`; it's flipped manually / by Square auto-enable). 3-way control: Pay at venue only / Pay online (card) / Both. **STUB the #1 ABN gate:** disable the online/both options unless `org.abn_verified === true` (so this toggle can't enable online card before ABN, even though #1 is HELD).
- **Invariant:** add the `pay_mode !== "venue"` AND-clause in BOTH predicate spots (`RestaurantStorefront.tsx:613`, `PublishedStorefront.tsx:237`). Preserve: dine-in always venue; owner-preview never charges; default `pay_mode="venue"` = existing merchants unchanged.

### [ ] #15 — Checkout offers account creation BEFORE guest (flip order) — RISK: LOW–MEDIUM

UI reordering ONLY. Guest must stay reachable (founder asked "offer before", NOT "force"). Preserve the guest-checkout compliance design (anon session at place-order, `recordConsentAndGetCustomerId`) — the bridge `PublishedStorefront.tsx:283-473` is untouched.

- [ ] **BESPOKE — `src/components/storefront/screens/Checkout.tsx` ContactStep (`:879-1016`)** — replace the small guest line + `SignInLink` (`:904-912`) with an account-first panel: prominent card "Save your details & earn rewards" + primary button "Sign in or create account" → `requestAuth()` (already threaded `:882-887,1248,1549,1705,1841`; `CustomerAuthDialog` mounted `:1983-1989`). Add `const [guestMode, setGuestMode] = useState(false);`; when not signed in and `!guestMode`, show only the account CTA + a secondary "Continue as guest" button that sets `guestMode=true` and reveals the name/phone/email fields. When signed-in non-anonymous, skip the CTA. `contactValid` (`:365`) unchanged.
- [ ] **DEFAULT — `src/pages/storefront/RestaurantStorefront.tsx:1489-1507`** — before line 1510 (above payment buttons) when `isGuest` (`:157`), insert a prominent "Sign in or create an account" button → `setCheckoutStep("auth")` (`CustomerAuthDialog` wired `:1304-1310`) + a secondary "Continue as guest". Change `DialogDescription` (`:1492-1493`) from "No account needed" to lead with the account benefit, guest as fallback.
- **Reuse** existing `isGuest`/`customerSignedIn` anonymous-vs-real distinction (`Checkout.tsx:1916-1919`, `RestaurantStorefront.tsx:148-157`) — do NOT re-derive. Verify `PostPurchaseModal` nudge (`Checkout.tsx:1929-1931`) still fires only for guests.
- **Staged:** ship Path 1 (bespoke — first Square merchant "Test Pizza" uses it) first; Path 2 (default) lower priority.

### [ ] #10 — Real live prep/pickup timings (not placeholder) — RISK: MEDIUM

Biggest correctness gap. Timings are hardcoded (`30`/`15` + busy buffer); BESPOKE slots are fully fake. **No `prep_minutes` setting exists anywhere.** Default values 15/30 preserve current displayed numbers → unconfigured merchants unchanged.

- [ ] **`src/services/settings.ts`** — add to `kitchen`: `pickup_prep_minutes?: number;` (default 15), `delivery_prep_minutes?: number;` (default 30). Add defaults in `defaultSettings.kitchen` (`:132`).
- [ ] **`src/hooks/useStorefrontSettings.ts:99-136`** — compute + return `pickupEta = (settings.kitchen?.pickup_prep_minutes ?? 15) + busyBufferMinutes` and `deliveryEta = (settings.kitchen?.delivery_prep_minutes ?? 30) + busyBufferMinutes` (keeps the live busy-buffer add).
- [ ] **DEFAULT — `src/pages/storefront/RestaurantStorefront.tsx:395,763,764,913,915`** — replace the `30`/`15` literals with `deliveryEta`/`pickupEta`. The `etaMinutes` pill (`:1092`) then reflects real config + live busy buffer.
- [ ] **BESPOKE contract — `src/components/storefront/chrome/contracts.ts:133-192`** — add optional `eta?: { pickupMinutes: number; deliveryMinutes: number }` to `StorefrontWorld`.
- [ ] **BESPOKE bridge — `src/components/storefront/PublishedStorefront.tsx:186-274`** — populate `world.eta` from `useStorefrontSettings` (alongside `merchantFulfillment` `:186-209`).
- [ ] **BESPOKE UI — `src/components/storefront/screens/Checkout.tsx:153,824-843`** — replace static `TIME_SLOTS` "Ready by" rendering with a real estimate: "Ready in ~N min" from `world.eta` + `flow.form.fulfillment`, or generate live clock slots from `Date.now() + prep` rounded to next 15 min. Preview/demo (no `world.eta`) falls back to current static showcase. DO NOT reintroduce a clock into `orderNumberFor` (`:21,104-115`) — order number must stay deterministic.
- **Editor UI:** surface the prep fields in `src/pages/dashboard/KitchenSettings.tsx` (already manages kitchen/busy) or Operations.
- **Stretch (out of scope):** load-aware ETA from open-orders queue depth.

### [ ] #7 — Unpublished storefronts must NOT be publicly reachable — RISK: MEDIUM

Most security-relevant. Today `get_public_storefront(slug)` (`20260529131000_public_storefront_read_rpcs.sql:28-57`) returns the org for ANY slug with NO publish gate; `get_public_menu` (`:66`) likewise → a logged-out visitor gets a full storefront for an unpublished merchant. (`get_public_storefront_config` already gates on `is_published`.) Use **Option A:** publish = go-live; gate the two RPCs on a published `storefront_config` row.

- [ ] **NEW migration `supabase/migrations/2026061100xxxx_gate_public_storefront_on_publish.sql`** — redefine `get_public_storefront`: `JOIN public.storefront_config c ON c.organization_id = o.id AND c.is_published = true` (keep existing PII null-out `:47-53`, `RETURN NULL` if `NOT FOUND`). Add the same join guard to `get_public_menu` on its org_id. Idempotent; append to `docs/FOUNDER_RUN_THESE.sql`; regen `types.ts`.
- [ ] **`src/pages/Shop.tsx`** — after the loading guard (`:110`), before the trial-expired check (`:113`): `if (slug && !isDemoMode() && !org) return <StorefrontComingSoon slug={slug} />;`. Distinguish "unpublished/not-found" (`isLoading===false && org==null`) from "loading".
- [ ] **NEW `src/components/storefront/StorefrontComingSoon.tsx`** — friendly "This store isn't open yet" + Woahh branding + link to `/eat` (apex). Set `<meta name="robots" content="noindex">` via `src/lib/seo.ts`. (Static SPA can't return real 404; noindex + clear copy is correct UX.)
- **Owner preview unaffected:** owners preview via dashboard `StorefrontTemplates` live preview (`:681`) + `/storefront-preview` — neither uses the public RPC. Do NOT repurpose `useIsOwnerPreviewing` for data access.
- **Test matrix:** (1) published → loads; (2) unpublished → coming-soon, no menu fetch; (3) owner dashboard preview works; (4) `/order/:id` tracker (uses `get_order_by_id`) unaffected; (5) `/eat` uses `marketplace_organizations` view gated by `marketplace_visible` (independent — confirm a merchant needs both to appear in discovery).
- **Coordinate with HELD #8:** #7's publish-gate is the prerequisite for subdomain go-live; land the flag now, #8 wires DNS later.

### [ ] #9 — Rate-limit storefront template + branding churn — RISK: LOW

Stop endless republishing. Publish path = `storefrontConfigApi.upsert` (`StorefrontTemplates.tsx:340`). DB authoritative so a hand-rolled REST write can't bypass.

- [ ] **NEW migration (extend `validate_storefront_config` trigger, `20260603010000_storefront_config.sql:47-125`)** — `ALTER TABLE storefront_config ADD COLUMN IF NOT EXISTS publish_count_today int NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS publish_window_start timestamptz;`. In trigger, on `NEW.is_published`: reset window if NULL or `< now() - interval '24 hours'` else increment; `RAISE EXCEPTION 'storefront publish limit reached — try again later'` past **10/day**. Idempotent; append to `docs/FOUNDER_RUN_THESE.sql`; regen `types.ts`.
- [ ] **`src/pages/dashboard/StorefrontTemplates.tsx:342` (`publish.onSuccess`)** — start a 30–60s cooldown disabling the Publish button ("you can update again in Ns"). `publish.onError` (`:350`) already toasts the RAISE message — leave it.
- **Don't** rate-limit live preview (`editedConfig` useMemo `:264` is cheap) or draft-saving (only publish exists today). `Branding.tsx` logo churn = lower priority; optional client throttle only.
- **Risk:** cap too low frustrates setup; 10/day is generous.

### [ ] #16 — Smarter auto usernames (priya, priya2, priya17) — RISK: LOW–MEDIUM

Applies to OWNER signup only (`src/pages/Auth.tsx`); customers use magic-link. Today the field starts empty with a live `username_is_taken` check (`:236-240`); a taken name blocks signup (`:263,543`) with no suggestion.

- [ ] **NEW migration `next_available_username(_base text)`** — SECURITY DEFINER, model on `username_is_taken` (`20260420022440_...sql:27-50`). Slugify `_base` to `^[a-z0-9._-]{3,30}$`; if free return it; else append `2,3,…` until free (cap ~100, then `base + random 4 digits`). `GRANT EXECUTE TO anon, authenticated`.
- [ ] **`src/pages/Auth.tsx`** — `useEffect` keyed on `businessName` (near `:230-242`), guarded by a "user hasn't manually edited username" flag: derive base from business name (mirror `usernameRegex` `:32`), call RPC to prefill a unique suggestion. When live check reports `taken` (`:239`), offer one-click "Use `priyaN` instead".
- [ ] **`src/pages/Auth.tsx:310-311` (client upsert into `usernames`)** — wrap in try/catch that re-derives via the RPC + retries on unique-violation (RACE CAVEAT below).
- **CAVEAT (correctness):** username persists two ways — client upsert (`:310`) + auth trigger `handle_new_user_org` (`20260609010000:68-72`) which SILENTLY skips on malformed/duplicate. Two racing signups on the same suggestion → one insert fails. RPC reduces but doesn't eliminate this; the conflict-retry on `:310` is the minimal fix. (Cleaner alt: move username assignment fully into the trigger via `next_available_username` — coordinate with anon-guard migration `20260609010000`; more invasive, defer.)
- Storefront paths: NONE touched.

### [ ] #17 — QR codes usable without dine-in enabled — RISK: LOW

Today the whole QR surface is gated behind `dineIn.enabled` (`Tables.tsx:349,355-357`) and the venue URL is dine-in by construction (`?dine=1`, `:74-77`). Intent: a QR that just takes customers to the storefront to order (pickup/delivery) even with dine-in off.

- [ ] **`src/pages/dashboard/Tables.tsx:349`** — pull the QR `<Tabs>`/`<TabsContent>` OUT from under the `{dineIn.enabled && (...)}` guard so the QR tab is always available. Tables tab + dine-in switches stay dine-in-gated.
- [ ] **`src/pages/dashboard/Tables.tsx:74-77`** — make `venueUrl` conditional: `const base = \`${window.location.origin}/shop/${org.subdomain_slug}\`; const venueUrl = dineIn.enabled ? \`${base}?dine=1\` : base;`. (Prefer `https://${slug}.woahh.app` once #8 ships — HELD; keep `/shop/:slug` now.)
- [ ] **`src/pages/dashboard/Tables.tsx:660-663`** — make QR copy mode-aware: dine-in on → table messaging; off → "Scan to order online".
- [ ] **Discoverability** — page title is "Dine-In Tables" (`:290`). Minimal: always show the QR tab (relabel its sub-area "Storefront QR"); keep one page.
- **Storefront side:** no change required — a bare storefront URL (no `?dine=1`) selects the first enabled fulfillment (`RestaurantStorefront.tsx:256`). Verify nothing assumes `?dine=1` is present.
- No DB/RPC/edge change.

### [ ] #5 — Prominent "Setting up & domain" go-live checklist — RISK: LOW

Operational go-live checklist (menu / hours / publish / payments / domain), DISTINCT from the compliance `OnboardingChecklist`. Additive, read-only derivations, no schema change.

- [ ] **NEW `src/components/dashboard/GoLiveChecklist.tsx`** — model on `OnboardingChecklist.tsx` (reuse `Step` `:31-46` + `Progress` bar). Steps, each deriving `done` from real data + linking to the page:
  - Add your menu — `productApi.list(org.id).length > 0` → `/business/dashboard/menu`
  - Set hours & fulfillment — `settings.fulfillment` has ≥1 enabled method → `/business/dashboard/operations`
  - Choose & publish storefront — `storefrontConfigApi.getMine().is_published === true` → `/business/dashboard/storefront`
  - Configure payments — `online_card_enabled` OR a pay-at-venue choice (ties to #13) + (post-#1) ABN verified → `/business/dashboard/operations`
  - Storefront live at `<slug>.woahh.app` — once publish done; via `tenantUrl(org.subdomain_slug)` (`tenant.ts:98`) with copy + "View live". **Gate the literal `<slug>.woahh.app` behind `VITE_SUBDOMAINS_LIVE`** (wildcard DNS is HELD #8); otherwise show the `apexUrl(/shop/${slug})` path so the checklist never advertises a dead URL.
- [ ] **`src/pages/dashboard/DashboardOverview.tsx:74`** — render `GoLiveChecklist` directly below (or above) `OnboardingChecklist`. Show prominently while incomplete; collapse when all done (derive "all go-live done" in-component — no migration / no DB column).
- **Coordinate** publish-step + domain-row with #7's publish flag. The `Step` `done`/`line-through` mechanic also satisfies #2.

### [ ] #2 — Onboarding checklist auto-collapses/clears completed steps — RISK: LOW

`OnboardingChecklist.tsx`: 5 steps always render full (`:65`); completed ones strike-through but keep full height (`:31-46`). The whole card only vanishes when all done + `onboarding_completed_at` set. Data plumbing already exists (server-derived booleans `:59-63`, `qc.invalidateQueries(["org"])` after each mutation). Pure render restructure.

- [ ] **`src/components/dashboard/OnboardingChecklist.tsx:31-46` (`<Step>`)** — when `done`, render a compact one-line variant (`py-1.5`, hide `desc`; children already hidden by `!done && children` `:43`).
- [ ] **`src/components/dashboard/OnboardingChecklist.tsx:65,151`** — surface incomplete steps first; collapse completed ones into a single "✓ N of 5 done" disclosure; keep the progress bar (`:151`) as the at-a-glance.
- **Coordinate with HELD #1** (also reworks this checklist) — #2 is the safe independent subset; don't let it conflict. No schema change. Can be folded into #5's `Step` work.

### [ ] EXTRA A — "View as customer" owner toggle — RISK: MEDIUM (re-enables real charge)

`useIsOwnerPreviewing(orgId)` (`:12-17`) returns true whenever the signed-in user owns the viewed org, driving the owner-preview card suppression on both paths. No way today for an owner to exercise the real card flow except incognito.

- [ ] **`src/hooks/useIsOwnerPreviewing.ts:12-17`** — add a tab-scoped sessionStorage override: if `sessionStorage.getItem("woahh-view-as-customer") === "1"` return `false`. Use a tiny `useViewAsCustomer()` hook with a custom event (mirror `woahh:demo-toggled`, `demo.ts:2016-2018`) so toggling re-renders. **sessionStorage, NOT localStorage** (tab-scoped, auto-clears on close, can't leak across tabs/customers).
- [ ] **UI toggle — `src/components/storefront/CustomerHeaderMenu.tsx`** (single home covering BOTH render paths; already conditionally renders owner/demo affordances) — render when `isOwnerPreviewing`: "View as a customer (test card flow)" sets the flag + toasts a warning a real charge can occur. Surface a persistent "Viewing as customer — real charges enabled" badge + easy exit.
- **Consistency invariant:** the flag must be read in the SAME place `isOwnerPreviewing` is consumed so the bridge gate (`PublishedStorefront.tsx:405`, `RestaurantStorefront.tsx:619`) and the UI panel choice stay consistent. Do after #13 (shares the gate).

### [ ] EXTRA B — Scope demo flag so it can't leak into a real merchant storefront — RISK: LOW–MEDIUM

Real leak: `isDemoMode()` reads a single global key `lumen.demo.active` (`demo.ts:25,2007-2010`). `Shop.tsx` short-circuits to the demo org (Bella's Bistro) whenever demo is on — EVEN with a real slug (`:41-42,45-47,57-63`). So an owner/customer with the global flag set who opens a real storefront gets demo data.

- [ ] **`src/pages/Shop.tsx`** — add `const onTenantHost = !!getTenantSlug();` (already imported `:13`); define `const demoActive = isDemoMode() && !forcedSlug && !onTenantHost;` and use `demoActive` everywhere `isDemoMode()` is currently used in this file (`:41,42,45,46,47,57,60,103,137`). Strongest: when a `slug`/`forcedSlug` is present, ALWAYS fetch the real org (`orgApi.getBySlug`); fall back to `demoStore().getOrg()` only when there's NO slug at all.
- [ ] **Optional hardening** — in `Shop.tsx`, `disableDemo()` when a real org resolves on a tenant host (mirrors `AuthProvider.tsx:58-59`). Do NOT rip out the global flag (`/demo` showcase + `DemoBanner` depend on it).
- **Verify intended demo surfaces still work:** bare `/shop` (no slug) showcase; `/eat/:slug` previews (`getMarketplaceBySlug` / `DemoRestaurantPreview`). Keep `demoMarketOrg` for `/eat` preview seeds but NOT for the public `/shop/:slug` order path. **Coordinate with #7** (also edits `Shop.tsx`) — do right after #7.

### [ ] #4 — Declutter the sidebar (grouped/collapsible nav) — RISK: LOW–MEDIUM

`AppSidebar.tsx:63-101` builds a flat 2-group nav (~20 items; "Configure" alone has 11). Render loop `:187-248`. Regroup into ~5 collapsible sections (visible-by-default drops from ~20 to ~6-8). Fully isolated to one file — do LAST.

- [ ] **`src/components/dashboard/AppSidebar.tsx:63-101` (`navFor`)** — return an array of group objects `{ key, label, icon, defaultOpen, items }[]`. Proposed: **Run** (Overview, Orders, Menu, KDS — expanded), **Front desk** (Tables, Reservations — restaurant only), **Customers** (Customers, Loyalty — collapsed), **Marketing** (SMS, Email, Promotions, Promote, Impact — collapsed), **Storefront & brand** (Storefront, Branding — collapsed), **Settings** (Operations, KDS Settings, Notifications, Staff, Analytics, Feedback — collapsed). Apply `minTier`/`perm`/`business_type` filtering (`:112-116`) PER GROUP; omit a group entirely if all its items filter out (e.g. Front desk for retail).
- [ ] **`src/components/dashboard/AppSidebar.tsx:187-248` (render loop)** — replace `(["main","config"]).map` with `groups.map`, wrapping each `SidebarGroupContent` in a `Collapsible`+`CollapsibleTrigger` (`SidebarGroupLabel` = trigger w/ chevron), `defaultOpen` from group. Persist open state to `localStorage` (`woahh:sidebar:<groupKey>`). Auto-expand the group containing the active route (`isActive` `:123-124`) on mount. Keep icon-collapsed mode flat w/ tooltips (`:105`). Locked-item render (`:200-223`) reused unchanged.
- **VERIFY** `@/components/ui/collapsible` exists (`grep -r "ui/collapsible" src` before building); if absent, add the shadcn Radix `Collapsible` wrapper.
- **Risks:** (a) breaking role/tier/business-type filtering — keep `can(role, perm)`/`hasFeatureAccess` identical, just relocated; (b) icon-collapsed regressing — test both states; (c) route in a collapsed group — auto-expand covers it.
- **Staged lighter cut:** regroup into 5-6 labeled non-collapsible `SidebarGroup`s first (pure `navFor` data restructure); add collapse as follow-up.

---

## CROSS-CUTTING NOTES

- **No new RLS surface** introduced by any item. #7 tightens an existing RPC; #9 hardens an existing trigger.
- **Migrations needed (idempotent, run in Supabase SQL editor `pmnyhbhtkcfoozkinieo`, then regen `types.ts`; append to `docs/FOUNDER_RUN_THESE.sql`):** #7 (gate `get_public_storefront`/`get_public_menu`), #9 (publish-rate columns + trigger), #16 (`next_available_username` RPC).
- **#11 (Terms + marketing consent) — EXPLICITLY NOT IMPLEMENTED AS A SINGLE BUNDLED CHECKBOX.** Per `docs/legal/legalities.md` §6.2/§8 bundling marketing into mandatory Terms = invalid consent. Code already correct: one REQUIRED Terms + separate pre-unchecked email opt-in + separate pre-unchecked SMS opt-in (BESPOKE `Checkout.tsx:977-1013,140-150,365-374`; DEFAULT `RestaurantStorefront.tsx:1658-1700,1597-1614,1560-1577`). Optional polish only: (1) decide whether to drop the `isGuest` gate on the DEFAULT email opt-in (`RestaurantStorefront.tsx:1597`) so returning customers can opt in too; (2) add a Privacy link to bespoke Terms label (`Checkout.tsx:985-994`); (3) **VERIFY** `upsert_my_consent` stamps `email_consent_at`/`sms_consent_at` with source — grep `supabase/migrations` before shipping (legalities §6 requires recording what/when/how). Not a tonight blocker; track separately.
- **First-merchant (Test Pizza) critical path:** uses BESPOKE `PublishedStorefront` with a published config → #7 Option A is safe (published). Test #6-A, #13 (PublishedStorefront predicate), #15 Path 1, and #10 (bespoke ETA) most carefully — they're on Test Pizza's checkout.
- **Files with multi-item overlap (sequence per recommended order):** `Checkout.tsx` (#6-C, #15, #10), `RestaurantStorefront.tsx` (#6-B, #13, #15, #10), `PublishedStorefront.tsx` (#6-A, #13, #10), `Shop.tsx` (#7, EXTRA B), `storefrontConfig.ts` (#7, #9), `Operations.tsx` (#6-D, #13, #5 reads), `settings.ts` (#6 reads shape, #13 + #10 add fields), `AppSidebar.tsx` (#4 only).
