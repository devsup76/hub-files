# Shop Architecture Plan
> Last updated: 2026-05-01

This document defines the full architecture for the Woahh "Shop" side — the retail merchant dashboard and the customer-facing retail marketplace — distinct from the existing "Eat" restaurant side.

---

## Summary of Decisions

| Area | Decision |
|---|---|
| Merchant dashboard URL | Keep `/dashboard/*` — same URL tree, swap sidebar + page content based on `business_type` |
| Customer retail marketplace URL | `/shop` repurposed as the retail marketplace (ShopMarketplace) |
| Individual retail store URL | `/shop/:slug` stays — routes to `RetailStorefront` for retail orgs only |
| Customer mode switch | Persistent top pill on `/eat` and `/shop` to switch between the two modes |
| Existing demo behaviour | `/shop` no-slug demo falls through to the marketplace; demo merchants keep `/demo` |

---

## 1. Route Changes (App.tsx)

### New customer-facing routes
```
/shop              →  ShopMarketplace.tsx   (retail merchant discovery)
/shop/:slug        →  ShopStorefront.tsx    (individual retail store — replaces current Shop.tsx→RetailStorefront path)
```

### Existing routes that stay
```
/eat               →  Marketplace.tsx       (restaurant discovery — unchanged)
/eat/:slug         →  MarketplaceProfile.tsx (restaurant profile — unchanged)
/order/:id         →  OrderStatus.tsx       (unchanged — works for both eat + shop orders)
/account           →  Account.tsx           (unified customer account — extended)
```

### How Shop.tsx changes
- `/shop` no longer routes to `Shop.tsx`. `Shop.tsx` is retired or merged.
- `/shop/:slug` routes to a new `ShopStorefront.tsx` (retail-only, no restaurant fallback).
- Restaurant storefronts live at `/eat/:slug` via `MarketplaceProfile.tsx`.

### Merchant dashboard — no URL changes
- `/dashboard/*` stays for all merchants.
- `DashboardLayout.tsx` detects `org.business_type` and renders either `AppSidebar` (restaurant) or `ShopSidebar` (retail).
- Restaurant-only routes (`/dashboard/tables`, `/dashboard/reservations`, `/dashboard/kitchen`, `/dashboard/kitchen-settings`) simply don't appear in the retail sidebar and redirect to overview if accessed directly.
- `/dashboard/menu` renders `Menu.tsx` for restaurants, `ShopInventory.tsx` for retail (component-level branch).
- `/dashboard/orders` renders `Orders.tsx` for restaurants, `ShopOrders.tsx` for retail (component-level branch).
- New retail-only route: `/dashboard/pos` → `ShopPOS.tsx`.

---

## 2. Retail Merchant Dashboard

### ShopSidebar.tsx (new)
A separate sidebar component, only rendered when `org.business_type === 'retail'`.

**Manage group:**
| Label | Path | Icon | Gate |
|---|---|---|---|
| Overview | /dashboard | LayoutDashboard | — |
| Analytics | /dashboard/analytics | BarChart3 | — |
| Orders | /dashboard/orders | ShoppingBag | — |
| Inventory | /dashboard/menu | Package | — |
| Point of Sale | /dashboard/pos | Scan | — |
| Loyalty & Rewards | /dashboard/loyalty | Heart | marketplace |
| Customers | /dashboard/customers | Users | marketplace |

**Configure group:**
| Label | Path | Icon | Gate |
|---|---|---|---|
| SMS Campaigns | /dashboard/sms | MessageSquare | marketplace |
| Email Campaigns | /dashboard/email | Mail | solo |
| Operations | /dashboard/operations | Settings | — |
| Notifications | /dashboard/notifications | Bell | marketplace |
| Promotions | /dashboard/promotions | TicketPercent | — |
| Promote | /dashboard/promote | Sparkles | solo |
| Your Impact | /dashboard/donate | Heart | — |
| Branding | /dashboard/branding | Palette | — |
| Staff Accounts | /dashboard/staff | Shield | — |
| Feedback | /dashboard/feedback | MessageSquarePlus | — |

Footer links: "View Store" (→ /shop/:slug) | "Marketplace" (→ /shop)

### ShopDashboardOverview.tsx (new)
Replaces `DashboardOverview` for retail merchants.

**Widget layout:**
- Today's revenue (GMV) — large number card
- Orders pending fulfillment — split: Pickup ready / Shipping to pack / Delivery en-route
- Low stock alerts — list of products below reorder threshold (configurable in inventory)
- Top 5 products today — bar chart (name + units sold)
- Fulfillment breakdown — donut: in-store / pickup / delivery / shipping
- Recent orders — last 10 with status badge
- Quick actions: New Sale (→ POS), Add Product, View Orders

### ShopOrders.tsx (new)
Replaces `Orders.tsx` for retail merchants. Fulfillment-focused, no kanban/kitchen view.

**Three-column layout (tabs):**
1. **Pickup Queue** — orders awaiting pickup; sorted by time placed; one-click "Ready for pickup" → triggers customer notification
2. **Shipping** — orders to be packed + dispatched; show shipping label button (future: integrated with AusPost/CouriersPlease); status: Packing → Shipped → Delivered
3. **Delivery** — courier-dispatched orders; same courier tracking as existing `Orders.tsx`

**Order card shows:** customer name, items summary, order time, fulfilment type badge, total

**Actions per card:**
- Confirm (awaiting_confirmation)
- Ready (preparing → ready)
- Decline (with reason)
- Print label (shipping — future)

**In-store orders** (POS-generated): appear in a fourth tab "In-Store" — read-only record, no action needed.

### ShopInventory.tsx (new)
Replaces `Menu.tsx` for retail merchants. Full product catalogue management.

**Columns:** Product name | Category | SKU/Barcode | Price | Stock | Status | Actions

**Product form (add/edit sheet):**
- Name, description, images (multi)
- Category (with manage categories)
- SKU field + Barcode field (EAN/UPC)
- Price type: Fixed | Per kg/100g | Per unit
- If per-weight: unit label (kg / 100g / litre / each) + price-per-unit
- Sale price + date window
- Stock: quantity on hand + low-stock threshold
- Variants (size, colour, etc.) — each variant has its own price + stock
- Tags (organic, gluten-free, local, etc.)
- Supplier field (for cost tracking)
- Visibility: active / hidden / sold out

**Category management:**
- Drag-to-reorder
- Bulk mark category as seasonal (LTO window)

**Bulk actions:**
- CSV import (name, sku, price, stock, category)
- Export stock report
- Mark selected as sold out

### ShopPOS.tsx (new)
In-store point of sale. New route: `/dashboard/pos`.

**Layout:** Full-width, two-panel.

**Left panel — Cart:**
- Line items with qty +/−
- Apply promo code
- Loyalty points redemption (marketplace tier)
- Subtotal / discount / total
- Payment: Cash | Card (intent: Stripe Terminal future) | Split
- Tender cash → shows change due
- Complete sale button

**Right panel — Product search:**
- Search bar (name or SKU/barcode)
- Barcode scanner input (keyboard wedge — just an input that receives scan events)
- Category filter chips
- Product grid: image, name, price, stock badge
- Click product → adds to cart; weight items prompt for quantity

**Post-sale:**
- Prints/emails receipt (uses existing email-send edge function)
- Auto-creates order record with `fulfillment_type = 'in_store_pickup'`, `status = 'completed'`
- Awards loyalty points if customer ID provided

---

## 3. Customer-Facing Shop Marketplace

### ShopMarketplace.tsx (new) — `/shop`
Mirror of `Marketplace.tsx` but for retail merchants.

**Filters:**
- Category: All | Grocery | Bakery | Butcher | Bottle Shop | Health & Wellness | Specialty Food | General Retail | Other
- Fulfillment: All | Delivery | Click & Collect | In-Store
- Distance (if location permitted)
- Impact Partners (donation badge toggle)

**Merchant card shows:** Cover image | Business name | Category tags | Rating | Impact badge | Fulfillment tags | Distance

**Sort modes:** Featured | Rating | Distance | Newest

**"Eat / Shop" toggle pill** at top of page — persists via localStorage. Clicking "Eat" goes to `/eat`, clicking "Shop" stays on `/shop`. Same pill added to `/eat`.

### ShopStorefront.tsx (new) — `/shop/:slug`
Public-facing retail store. Based on existing `RetailStorefront.tsx` but with richer features from SHOP_RESEARCH.md.

**Header:** Store logo, name, tagline, fulfillment badges, rating, hours (from settings), Impact badge if applicable.

**Product browse:**
- Sidebar category nav (desktop) / horizontal scroll chips (mobile)
- Product grid: image, name, price (or price/kg), stock status, add-to-cart
- Weight items: show price/kg label; qty input accepts decimals (e.g. 0.350 for 350g)
- Out-of-stock items shown greyed with "Notify me" button (stores email → future notify flow)
- Sale prices with original price strikethrough + sale badge

**Cart (slide-over sheet):**
- Line items with qty +/−
- Fulfillment selector (Delivery / Click & Collect / Shipping — based on what merchant has enabled)
- Delivery address (if delivery)
- Promo code input
- Order notes
- Customer auth prompt (same magic link flow as eat side)
- Checkout → Stripe payment

**Eat/Shop pill** in header links back to `/eat`.

---

## 4. Account Page Updates

`Account.tsx` already shows order history. Add a type badge (`eat` / `shop`) on each order card in the Orders tab. No structural changes needed at MVP.

Future: "My Shops" tab showing loyalty balances per retail merchant (mirrors existing per-restaurant loyalty tab).

---

## 5. DB Changes Required

### New columns on `organizations`
```sql
-- already exists: business_type (restaurant | retail)
-- add:
reorder_threshold_default integer default 5;   -- for low-stock alerts
pos_enabled boolean default false;             -- unlock POS feature
```

### New columns on `products`
```sql
barcode text;                                  -- EAN/UPC for scanner
sku text;                                      -- internal SKU
price_unit text default 'each';               -- 'each' | 'kg' | '100g' | 'litre'
cost_price_cents integer;                      -- supplier cost (internal)
reorder_threshold integer;                     -- override per-product; null = org default
supplier text;
variants jsonb default '[]'::jsonb;            -- [{label, sku, price_cents, stock}]
```

### `organizations` marketplace filter
The existing `marketplace_visible` flag is reused. The existing `cuisine_tags` column is reused for retail categories (just different allowed values). No new column needed.

### `marketplaceApi` filter
Add `business_type` filter to `marketplaceApi.getAll()` so `/eat` fetches restaurants and `/shop` fetches retail merchants.

---

## 6. Lovable Prompt Plan

Respect the 5,000 character limit. Split by logical unit. Order matters — DB migrations first.

### Prompt 1 — DB migration: product fields for retail
```
Migration: add barcode, sku, price_unit, cost_price_cents, reorder_threshold, supplier, variants
columns to products. Add reorder_threshold_default and pos_enabled to organizations.
price_unit default 'each'. variants default empty array.
```

### Prompt 2 — marketplaceApi: business_type filter
```
Update marketplaceApi.getAll() in services/api.ts to accept an optional business_type
filter ('restaurant' | 'retail'). Marketplace.tsx passes business_type='restaurant'.
New ShopMarketplace.tsx will pass business_type='retail'.
```

### Prompt 3 — ShopSidebar.tsx (new component)
```
Create src/components/dashboard/ShopSidebar.tsx — retail-specific sidebar with nav items
as specified in architecture doc. Mirrors AppSidebar structure/styles. Footer links to
/shop/:slug and /shop.
```

### Prompt 4 — DashboardLayout.tsx: detect business_type, swap sidebar
```
In DashboardLayout.tsx, fetch org (already available via useOrg). If org.business_type
=== 'retail', render ShopSidebar instead of AppSidebar. Guard restaurant-only routes
(/dashboard/tables, /dashboard/reservations, /dashboard/kitchen,
/dashboard/kitchen-settings) to redirect retail merchants to /dashboard.
```

### Prompt 5 — ShopDashboardOverview.tsx (new page)
```
Create src/pages/dashboard/ShopDashboardOverview.tsx with retail-specific overview
widgets: today GMV, pending orders by fulfillment type, low-stock alerts list,
top 5 products bar chart, recent orders list, quick action buttons.
Wire into /dashboard index route with business_type branch.
```

### Prompt 6 — ShopInventory.tsx (new page)
```
Create src/pages/dashboard/ShopInventory.tsx with product table columns:
name, category, sku/barcode, price (with unit), stock, status.
Product form sheet: all new fields (barcode, sku, price_unit, cost_price, reorder_threshold,
supplier, variants). Bulk actions: CSV import, export, mark sold out.
Wire to /dashboard/menu with business_type branch.
```

### Prompt 7 — ShopOrders.tsx (new page)
```
Create src/pages/dashboard/ShopOrders.tsx with three-tab layout:
Pickup Queue | Shipping | Delivery. Order cards with confirm/ready/decline actions.
In-store orders tab (read-only). Wire to /dashboard/orders with business_type branch.
```

### Prompt 8 — ShopPOS.tsx (new page)
```
Create src/pages/dashboard/ShopPOS.tsx with two-panel layout: cart (left) +
product search/barcode (right). Barcode scanner input, category chips, product grid.
Payment: Cash / Card / Split. Change due calculator for cash. Post-sale: creates
completed order + awards loyalty. New route /dashboard/pos added to App.tsx.
```

### Prompt 9 — ShopMarketplace.tsx (new page)
```
Create src/pages/ShopMarketplace.tsx at /shop — retail merchant discovery page.
Mirrors Marketplace.tsx structure. Filters: category (grocery/bakery/butcher etc.),
fulfillment, distance, impact badge. Sort: featured/rating/distance.
Eat/Shop toggle pill at top. Update App.tsx route /shop to this new component.
```

### Prompt 10 — ShopStorefront.tsx (new page)
```
Create src/pages/ShopStorefront.tsx at /shop/:slug. Retail-only store page.
Product browse with category nav, weight-based pricing display (price/kg label),
stock status. Cart sheet with fulfillment selector, promo code, customer auth.
Checkout → Stripe. Update App.tsx /shop/:slug to ShopStorefront. Retire Shop.tsx.
```

### Prompt 11 — Eat/Shop mode pill on /eat
```
Add Eat/Shop toggle pill to Marketplace.tsx header area. Clicking Shop navigates
to /shop. Persist selection to localStorage key 'woahh_mode'. Mirror the same
pill on ShopMarketplace.tsx.
```

---

## 7. Feature Parity Checklist vs Restaurant Side

| Feature | Restaurant | Retail MVP | Retail Phase 2 |
|---|---|---|---|
| Order management | ✅ Kanban/KDS | ✅ Pickup/Ship/Delivery tabs | ✅ Batch fulfilment |
| Product catalog | ✅ Menu + combos | ✅ Inventory + variants | ✅ Bundles, kits |
| POS | ❌ | ✅ ShopPOS | ✅ Stripe Terminal |
| Tables | ✅ | ❌ N/A | ❌ |
| Reservations | ✅ | ❌ N/A | ❌ |
| KDS | ✅ | ❌ N/A | ❌ |
| Loyalty | ✅ | ✅ Shared | ✅ |
| CRM | ✅ | ✅ Shared | ✅ |
| SMS campaigns | ✅ | ✅ Shared | ✅ |
| Email campaigns | ✅ | ✅ Shared | ✅ |
| Branding | ✅ | ✅ Shared | ✅ |
| Staff accounts | ✅ | ✅ Shared | ✅ |
| Marketplace | ✅ /eat | ✅ /shop | ✅ |
| Sponsored listings | ✅ | ✅ Shared Promote | ✅ |
| Impact/donations | ✅ | ✅ Shared | ✅ |
| Weight-based pricing | ❌ | ✅ | ✅ |
| Barcode/SKU | ❌ | ✅ | ✅ |
| CSV import | ❌ | ✅ | ✅ |
| Low-stock alerts | ❌ | ✅ | ✅ |
| Shipping labels | ❌ | ❌ | ✅ AusPost/CouriersPlease |
| Age verification (liquor) | ❌ | ❌ | ✅ |
| Scales integration | ❌ | ❌ | ✅ USB/Bluetooth |

---

## 8. Open Questions (resolve before Prompt 6+)

1. **Variants** — do retail product variants (size/colour) share stock or track independently? 
   → Recommend: each variant has its own `stock` field in the JSONB. Independent tracking.

2. **Weight items in cart** — do customers enter exact weight or does the merchant weigh and adjust?
   → MVP: customer enters approximate quantity (e.g. 0.5 kg), merchant adjusts before final charge. Phase 2: pre-weigh + price adjustment flow.

3. **POS payment** — cash and "card present" (future Stripe Terminal). For MVP, "Card" just records the payment method without charging through Stripe (assume EFTPOS terminal already present).
   → Confirm: POS card = mark as paid externally. Stripe Terminal integration = Phase 2.

4. **Shop marketplace URL** — `/shop` is currently the storefront router for all org types. Repurposing it as the retail marketplace means individual stores must be reached via `/shop/:slug`. This is clean but confirm the current `/shop` no-slug demo is no longer needed.
   → Current `/shop` without slug shows demo restaurant — this can be removed (demo lives at `/demo`).
