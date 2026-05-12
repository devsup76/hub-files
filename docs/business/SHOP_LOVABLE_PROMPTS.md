# Shop Side — Lovable Prompts
> Status: Ready to execute in order. Each prompt is ≤5,000 chars.
> Last updated: 2026-05-09

Run these in sequence — later prompts depend on earlier ones.
Mark each ✅ when done in Lovable.

---

## Prompt 1 — DB Migration: retail product + org fields
> Status: ✅ Done — gaps fixed by Prompt 1b below

```
Create a new Supabase migration file:
supabase/migrations/20260509000000_retail_product_fields.sql

Add these columns to the products table (use ADD COLUMN IF NOT EXISTS for each):
- barcode text
- sku text
- price_unit text not null default 'each'
- cost_price_cents integer
- reorder_threshold integer
- supplier text
- variants jsonb not null default '[]'::jsonb

The price_unit column stores one of: 'each', 'kg', '100g', 'litre'.
The variants column stores an array of objects: [{id, label, sku, price_cents, stock}].

Add these columns to the organizations table (use ADD COLUMN IF NOT EXISTS):
- reorder_threshold_default integer not null default 5
- pos_enabled boolean not null default false

No new RLS policies needed — existing product and organization policies cover these columns.

After writing the migration, update the TypeScript types in
src/integrations/supabase/types.ts to include all new columns on the Products
row type and the Organization/organizations row type.
```

---

## Prompt 1b — DB Migration: constraints + indexes (run after Prompt 1)
> Status: ✅ Done (migration correct) — type narrowing fixed by Prompt 1c below

```
Create a new Supabase migration file:
supabase/migrations/20260509000001_retail_product_constraints.sql

This migration hardens the products table columns added in the previous migration.

1. Add a CHECK constraint on price_unit to enforce the allowed set:
ALTER TABLE public.products
  ADD CONSTRAINT products_price_unit_check
  CHECK (price_unit IN ('each', 'kg', '100g', 'litre'));

2. Add partial unique indexes on barcode and sku scoped per organization.
   Partial (WHERE column IS NOT NULL) so two NULL values don't conflict —
   only real values must be unique.

CREATE UNIQUE INDEX IF NOT EXISTS idx_products_org_barcode
  ON public.products (organization_id, barcode)
  WHERE barcode IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_products_org_sku
  ON public.products (organization_id, sku)
  WHERE sku IS NOT NULL;

3. Add lookup performance indexes used by the POS barcode scanner:
   (The unique indexes above already cover this — no additional plain index needed.)

After writing the migration, update the TypeScript types in
src/integrations/supabase/types.ts:
- Change price_unit from `string` to `'each' | 'kg' | '100g' | 'litre'`
  on the Row, Insert, and Update types for products.
- Change variants from `Json` to
  `Array<{ id: string; label: string; sku: string | null; price_cents: number; stock: number }>`
  on the Row, Insert, and Update types for products.
```

---

## Prompt 2 — marketplaceApi: business_type filter
> Status: ✅ Done — bug fixed by Prompt 2b below

```
In src/services/api.ts, update the marketplace API to support filtering by business_type.

1. Find the function that fetches marketplace-listed organisations for the /eat page
   (likely marketplaceApi.getAll or similar). Add an optional parameter to its
   filters/options argument: business_type?: 'restaurant' | 'retail'

2. When business_type is provided, add .eq('business_type', business_type) to the
   Supabase query so only orgs of that type are returned.

3. In Marketplace.tsx, pass business_type: 'restaurant' to the getAll call. This
   ensures the /eat page never shows retail shops.

4. Update the MarketplaceFilters TypeScript type (if it exists in api.ts) to include
   the optional business_type field.

Do not change any other logic in Marketplace.tsx — only the API call argument.
```

---

## Prompt 2b — Fix demo.ts listMarketplace business_type filter
> Status: ✅ Done (logic correct) — type cast fixed by Prompt 1c below

```
In src/lib/demo.ts, fix the listMarketplace() method to respect the business_type
filter that was added to MarketplaceFilters.

Find the listMarketplace method (around line 960). Inside the .filter() callback,
add a business_type check alongside the existing search and cuisine checks:

  if (
    filters.business_type &&
    o.business_type !== filters.business_type
  ) return false;

This ensures that when /eat calls listMarketplace({ business_type: 'restaurant' }),
only restaurant orgs are returned in demo mode. When the retail marketplace at /shop
calls listMarketplace({ business_type: 'retail' }), it correctly returns nothing
(since all demo seed orgs are restaurants) rather than returning all demo orgs.

No other changes. Do not touch any other method or file.
```

---

## Prompt 1c — TypeScript type hardening (no migration needed)
> Status: [ ] Not started

```
Two type-safety fixes. No migration needed — DB is already correct.

FIX 1 — src/integrations/supabase/types.ts
Find the products Row, Insert, and Update types. Change price_unit from the
generic `string` type to the strict union literal on all three:

  Row:    price_unit: 'each' | 'kg' | '100g' | 'litre'
  Insert: price_unit?: 'each' | 'kg' | '100g' | 'litre'
  Update: price_unit?: 'each' | 'kg' | '100g' | 'litre'

Also change variants from the generic Json type to a typed array on all three:

  Row:    variants: Array<{ id: string; label: string; sku: string | null; price_cents: number; stock: number }>
  Insert: variants?: Array<{ id: string; label: string; sku: string | null; price_cents: number; stock: number }>
  Update: variants?: Array<{ id: string; label: string; sku: string | null; price_cents: number; stock: number }>

FIX 2 — src/lib/demo.ts
In the listMarketplace() method, find this line:
  (o as any).business_type !== filters.business_type

Replace the cast with a direct property access — the `o` variable is already
typed as MarketplaceOrg which has business_type on it:
  o.business_type !== filters.business_type

The `as any` cast was unnecessary and suppresses TypeScript checking. Remove it.

No other changes to either file.
```

---

## Prompt 3 — ShopSidebar.tsx (new component)
> Status: ✅ Done — permission gap fixed by Prompt 3b below

```
Create src/components/dashboard/ShopSidebar.tsx.

This is a retail-specific sidebar that mirrors the structure and styles of AppSidebar.tsx
but with different nav items. Use the same Sidebar, SidebarContent, SidebarHeader,
SidebarFooter, SidebarMenu, SidebarMenuButton components from shadcn/ui. Use the same
locked-item logic (lock icon + tooltip if below minTier), isActive check, tier pill
render, and sign-out behaviour as AppSidebar.tsx.

MANAGE GROUP nav items:
- Overview         /dashboard          LayoutDashboard icon  end=true
- Analytics        /dashboard/analytics  BarChart3 icon
- Orders           /dashboard/orders   ShoppingBag icon
- Inventory        /dashboard/menu     Package icon
- Point of Sale    /dashboard/pos      Scan icon
- Loyalty & Rewards /dashboard/loyalty Heart icon  minTier=marketplace
- Customers        /dashboard/customers Users icon  minTier=marketplace

CONFIGURE GROUP nav items:
- SMS Campaigns    /dashboard/sms         MessageSquare  minTier=marketplace
- Email Campaigns  /dashboard/email       Mail           minTier=solo
- Operations       /dashboard/operations  Settings
- Notifications    /dashboard/notifications Bell         minTier=marketplace
- Promotions       /dashboard/promotions  TicketPercent
- Promote          /dashboard/promote     Sparkles       minTier=solo
- Your Impact      /dashboard/donate      Heart
- Branding         /dashboard/branding    Palette
- Staff Accounts   /dashboard/staff       Shield
- Feedback         /dashboard/feedback    MessageSquarePlus

HEADER: Woahh. logo with Store icon (instead of UtensilsCrossed).
Store info card shows org name and a link to /shop/[org.subdomain_slug] (not /eat).

FOOTER links:
- "View Store" (ShoppingBag icon) → /shop/[org.subdomain_slug]
- "Marketplace" (Globe icon) → /shop

Locked-item tooltip text: "Available on [Tier] plan — Upgrade"
```

---

## Prompt 3b — Fix POS permission + DashboardLayout race condition
> Status: ✅ Done

```
Two fixes. No migration needed.

FIX 1 — src/hooks/useRole.ts
The PERMISSIONS matrix is missing a "pos" key. Point of Sale must be accessible
to service staff (shop floor till operators) but not to kitchen staff.

In the PERMISSIONS object, add "pos" to the following role sets:
  owner:   add "pos" (already has full access, add alongside other keys)
  manager: add "pos"
  service: add "pos"
  kitchen: do NOT add "pos" (kitchen staff have no reason to touch the till)

Also add "notifications" as an explicit permission key to the owner and manager
sets (currently notifications uses "operations" as an alias, which works but is
semantically incorrect — "notifications" is a separate page from "operations").

FIX 2 — src/components/dashboard/ShopSidebar.tsx
Change the Point of Sale nav item's perm from "menu" to "pos":

  { title: "Point of Sale", url: "/dashboard/pos", icon: Scan, perm: "pos" }

This ensures service staff see POS in their sidebar (they are the till operators)
but cannot access Inventory (which remains perm: "menu", manager/owner only).

FIX 3 — src/pages/dashboard/DashboardLayout.tsx
In the useEffect that redirects retail merchants away from restaurant-only paths,
add an early return guard so the redirect only fires once the org has loaded.
The org being undefined means isRetail is false, which could let a retail merchant
briefly render a restaurant-only page before the org fetch resolves.

Find the useEffect and add this as the first line inside it:
  if (!org) return;

Also add "org" to the useEffect dependency array.

No other changes to any file.
```

---

## Prompt 4 — DashboardLayout: swap sidebar for retail
> Status: ✅ Done — race condition fixed by Prompt 3b above

```
Update src/pages/dashboard/DashboardLayout.tsx.

1. Import ShopSidebar from '@/components/dashboard/ShopSidebar'.

2. The component already loads the org via useOrg(). Add a conditional:
   if (org?.business_type === 'retail') render <ShopSidebar /> in place of <AppSidebar />.
   While org is still loading, keep rendering <AppSidebar /> as the fallback
   (it will swap once the org loads — this avoids a blank sidebar flash).

3. Add a route guard for restaurant-only paths. Inside DashboardLayout, after org
   loads, if org.business_type === 'retail' and the current pathname matches any of:
     /dashboard/tables
     /dashboard/reservations
     /dashboard/kitchen
     /dashboard/kitchen-settings
   then redirect to /dashboard using useNavigate (replace: true).

Do not change the layout shell, SidebarProvider, SidebarTrigger, main content area,
or any existing AppSidebar behaviour.
```

---

## Prompt 5 — ShopDashboardOverview.tsx (new page)
> Status: ✅ Done — three issues fixed by Prompt 5b below

```
Create src/pages/dashboard/ShopDashboardOverview.tsx — the home screen for retail
merchant dashboards.

DATA: Fetch today's orders and all products for the current org using useQuery.
Today = dates where created_at >= start of current calendar day (local time).

LAYOUT (responsive grid, gap-4):

ROW 1 — three stat cards (1/3 width each):
- "Today's Revenue": sum of total_cents from today's orders with status IN
  (preparing, ready, completed). Display as currency.
- "Orders Pending": count of orders with status IN (pending, awaiting_confirmation).
- "Low Stock Items": count of products where stock <= coalesce(reorder_threshold,
  org.reorder_threshold_default). Show 0 if none.

ROW 2 — two cards side by side:
- "Fulfillment Mix" (donut chart, Recharts PieChart): count of today's orders
  grouped by fulfillment_type. Labels: Pickup / Delivery / Shipping / In-Store.
  Use chart colour tokens from the existing Analytics.tsx for consistency.
- "Top Products Today" (horizontal bar chart, Recharts BarChart): top 5 products
  by units sold today. Parse product names + quantities from order line_items JSONB.
  Product name on Y-axis (truncate at 20 chars), units sold on X-axis.

ROW 3 — full width card "Recent Orders":
Table columns: # | Customer | Items | Fulfillment | Total | Status | When
Show last 10 orders (all statuses). Status badges use same colours as Orders.tsx.
"When" column: relative time (e.g. "8 min ago").

ROW 4 — Quick Actions row (three buttons, left-aligned):
- "New Sale" (primary, ShoppingCart icon) → navigate to /dashboard/pos
- "Add Product" (outline, Plus icon) → navigate to /dashboard/menu?new=1
- "View All Orders" (outline, ArrowRight icon) → navigate to /dashboard/orders

Update App.tsx /dashboard index route:
Import ShopDashboardOverview with lazy(). In the route element, use a wrapper
component that reads org.business_type and renders ShopDashboardOverview for
'retail', DashboardOverview for everything else.
```

---

## Prompt 5b — Fix overview scalability + label + colour issues
> Status: [ ] Not started

```
Three fixes to src/pages/dashboard/ShopDashboardOverview.tsx and
src/services/api.ts. No migration needed.

FIX 1 — src/services/api.ts
Extend orderApi.list() to accept an optional second argument for server-side
filtering. Existing callers pass no second argument and behaviour is unchanged.

Change the signature from:
  async list(orgId: string): Promise<...>
to:
  async list(orgId: string, opts?: { from?: string; limit?: number }): Promise<...>

In the Supabase query, apply:
  - If opts.from is provided: .gte("created_at", opts.from)
  - If opts.limit is provided: .limit(opts.limit)  (before the existing .order())
  - If neither is provided: query is identical to current behaviour

Also update the demo branch: if opts.limit is set, slice the result array to
that length. If opts.from is set, filter by created_at >= opts.from.

FIX 2 — src/pages/dashboard/ShopDashboardOverview.tsx
Replace the single orders query with two separate queries:

Query A — today's orders only (for revenue, fulfillment mix, top products):
  queryKey: ["orders-today", orgId]
  queryFn: () => orderApi.list(orgId!, { from: new Date().setHours(0,0,0,0)
    converted to ISO string })
  Use this for: todayOrders, revenueToday, fulfillmentData, topProductsData

Query B — recent orders only (for the Recent Orders table):
  queryKey: ["orders-recent", orgId]
  queryFn: () => orderApi.list(orgId!, { limit: 10 })
  Use this for: recentOrders (no longer needs the .sort().slice(0,10) step
  since the server returns them already ordered by created_at desc and limited)

Remove the old single "orders" query. Update all downstream useMemo calls to
reference todayOrders (from Query A) or recentOrders (from Query B).
Also update pendingCount to use Query B (recent 10) OR add a third
Query C: queryKey: ["orders-pending", orgId], queryFn: () =>
orderApi.list(orgId!, { from: new Date().setHours(0,0,0,0) ISO })
and filter for pending/awaiting_confirmation statuses client-side on that result.

FIX 3 — src/pages/dashboard/ShopDashboardOverview.tsx
Replace the FULFILLMENT_LABELS map and chart colours with the same semantic
map used in Analytics.tsx for visual consistency across the dashboard.

Replace FULFILLMENT_LABELS with:
  const FULFILLMENT_LABELS: Record<string, string> = {
    pickup: "Pickup",
    delivery: "Delivery",
    shipping: "Shipping",
    in_store_pickup: "In-Store",
    dine_in: "Dine-In",
  };

Replace the positional CHART_COLORS array with a semantic map keyed by
fulfillment_type (same values as Analytics.tsx):
  const FULFILLMENT_COLORS: Record<string, string> = {
    delivery: "#6366f1",
    pickup: "#f59e0b",
    in_store_pickup: "#10b981",
    dine_in: "#f97316",
    shipping: "#06b6d4",
  };

In the PieChart, change the Cell fill from:
  fill={CHART_COLORS[i % CHART_COLORS.length]}
to look up by fulfillment_type key:
  fill={FULFILLMENT_COLORS[fulfillmentData[i]?.key ?? ""] ?? "#94a3b8"}

Update fulfillmentData to carry the raw key alongside the display name:
  return Object.entries(counts).map(([k, v]) => ({
    key: k,
    name: FULFILLMENT_LABELS[k] ?? k,
    value: v,
  }));
```

---

## Prompt 6a — ShopInventory: image upload + table + product form
> Status: [ ] Not started

```
Create src/pages/dashboard/ShopInventory.tsx — inventory management for retail merchants.

WIRING: Lazy-import ShopInventory in App.tsx. In the /dashboard/menu route element,
branch: org.business_type === 'retail' → ShopInventory, else → existing Menu.

Add productApi.uploadImage to src/services/api.ts inside the productApi object:
  async uploadImage(orgId: string, file: File): Promise<string> {
    const ext = file.name.split('.').pop() ?? 'jpg';
    const path = `${orgId}/products/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
    const { error } = await supabase.storage
      .from('product-images').upload(path, file, { upsert: false, contentType: file.type });
    if (error) throw error;
    return supabase.storage.from('product-images').getPublicUrl(path).data.publicUrl;
  }
Demo mode: return a placeholder picsum URL without uploading.

INVENTORY TABLE — columns: Checkbox | Thumb | Name | Category | SKU | Price | Stock | Status | Actions
- Checkbox header = Select All. Individual row checkboxes.
- Thumb: 40×40 rounded, image_url or grey Package icon placeholder.
- Name: click → opens edit Sheet.
- Price: variants present → "from $X.XX"; otherwise "$X.XX / [unit]" (unit blank for 'each').
  Active sale → amber "SALE" badge (sale_price set AND today within sale window).
- Stock: variants present → sum of variant stocks + "N variants" chip.
  No variants → click-to-edit inline: number becomes a 4-rem input, save on Enter/blur
  via productApi.update, show micro-spinner while saving, revert on Escape.
- Status: green "Active" / amber "Low Stock" (stock ≤ reorder_threshold ?? org default) /
  red "Sold Out" (stock = 0).
- Column headers Name, Price, Stock are sortable — click toggles asc/desc, shows ↑↓ arrow.
- Filter bar: Search (name or SKU) | Category | Status | Price Type.
- Pagination: 25/page. Footer: "X–Y of Z products" + Prev / Next.
- When ≥1 checked: floating bulk bar — "Mark sold out" | "Export selected" |
  "Delete selected" (confirm dialog: "Delete N products? Cannot be undone.").

PRODUCT SHEET — SheetContent size="lg", opened for add and edit.

SECTION Basic Info:
- Name (required), Description (textarea 3 rows).
- Image upload zone: dashed border, Package icon, "Click to upload or drag & drop",
  "PNG or JPG · max 5 MB". On file: validate size, call productApi.uploadImage,
  show spinner, render 120×120 rounded preview. "Remove" clears image_url.
  Single image only — stored in image_url.
- Category select (menu_categories ordered by sort_order).
  "Manage categories" button → Dialog (not nested Sheet):
  drag-to-reorder list, inline double-click rename, delete with confirmation,
  "Add category" input at bottom. Retail categories store name + sort_order ONLY —
  no LTO window, no discount_percent fields.
- SKU, Barcode (tooltip: "EAN-13 / UPC-A — used by POS barcode scanner").
- Visibility switch: Active / Hidden.

SECTION Pricing:
- Price type: 4-button segment — Per unit | Per kg | Per 100g | Per litre.
  Weight types: show callout "Customers enter estimated quantity at checkout."
- Price (number, step 0.01, required). Label adapts to price type.
- Sale price + Sale start + Sale end DatePickers (show only when sale price filled).
  Validate: end > start.
- Cost price (number, labelled "Internal only — not shown to customers").
  Save as cost_price_cents = Math.round(value * 100).

SECTION Stock:
- Stock on hand (integer, min 0, required).
- Low stock threshold (integer, optional, placeholder "Default: N" from org setting).
- Supplier (text).

SECTION Tags (multi-select chips, stored in products.tags[]):
Organic | Local | Gluten-free | Vegan | Halal | Nut-free | Dairy-free |
Kosher | Preservative-free | Australian Made | Frozen | Refrigerated

SECTION Variants (Collapsible, closed by default):
Trigger shows "Product variants" + badge with count if variants exist.
Info note: "Each variant has its own price and stock. Base stock is ignored when variants exist."
Table: Label | SKU | Price ($) | Stock | Remove.
"+ Add variant" appends row pre-filled with base price. On remove: confirm if stock > 0.
Stored in product.variants JSONB as [{id: crypto.randomUUID(), label, sku, price_cents, stock}].
```

---

## Prompt 6b — ShopInventory: CSV import + export
> Status: [ ] Not started

```
Add CSV import and export to the existing ShopInventory.tsx created in Prompt 6a.
Do not re-create the file — only add the two features described below.

TOOLBAR: Add two buttons to the top of the inventory page (left of the search bar):
- "Import" button (Upload icon)
- "Export" button (Download icon)

CSV IMPORT — "Import" button opens a Dialog with three steps:

STEP 1 — Upload:
Drag-and-drop zone or click to select. Accept .csv files only.
Show file name + size once selected. "Clear" button to reset.
"Next" button enabled only when a file is selected.

STEP 2 — Preview:
Parse the CSV client-side (use a simple split-by-line/comma parser or papaparse if
already in the project). Expected columns (case-insensitive): name, sku, barcode,
price, price_unit, stock, category.
Render a preview table showing all parsed rows. For each row:
- If SKU column is blank/missing: highlight row amber, add "Skipped" badge in a
  Status column, tooltip "SKU required for import".
- Otherwise: show green "Ready" badge.
Summary line above table: "N products ready to import · M rows skipped (missing SKU)".
"Back" and "Import N products" buttons. Import button disabled if N = 0.

STEP 3 — Importing:
Show a progress indicator. Process rows sequentially:
- For each ready row: check if a product with that SKU already exists for this org.
  - Exists → update: title, price, stock_quantity, barcode, price_unit.
  - Not found → insert new product.
- Category field: match to menu_categories by name (case-insensitive).
  If no match found, create a new category with that name for the org.
- price_unit: validate against ('each','kg','100g','litre'). Default 'each' if invalid/blank.
- price: parse as float, store as products.price (dollars, not cents — matches existing schema).
- stock: parse as integer, store as stock_quantity.
On complete: close dialog, refresh product list, toast:
  "Import complete — N products updated/added · M rows skipped."

CSV EXPORT — "Export" button:
Fetch all org products (use existing products query, no separate fetch needed).
Build CSV string with headers:
  name, sku, barcode, price, price_unit, stock, status, category, supplier, cost_price
- status: derive from stock vs threshold (Active / Low Stock / Sold Out).
- category: look up category name from menu_categories by category_id.
- cost_price: cost_price_cents / 100, formatted to 2dp (blank if null).
Trigger browser download via a Blob URL.
Filename: "inventory-[org.subdomain_slug]-[YYYY-MM-DD].csv"
```

---

## Prompt 7 — ShopOrders.tsx (new page)
> Status: [ ] Not started

```
Create src/pages/dashboard/ShopOrders.tsx — order management for retail merchants.
Wire to /dashboard/orders: when org.business_type === 'retail', render ShopOrders;
otherwise render the existing Orders component. Use lazy() for ShopOrders.

Subscribe to Realtime order updates on mount (same pattern as existing Orders.tsx).

LAYOUT: Page title "Orders" + four tabs at top: Pickup | Shipping | Delivery | In-Store.

ORDER CARD (shared component):
Shows: order number, customer name, items summary (first 2 items + "& N more"),
relative time ("12 min ago"), total formatted as currency, fulfillment type badge,
status badge. Status badge colours match existing Orders.tsx.

PICKUP TAB
Filter: fulfillment_type IN ('pickup') AND status NOT IN ('completed','declined').
Group orders into three columns or stacked sections:
  Awaiting Confirmation → Preparing → Ready for Pickup
Actions:
  - Awaiting Confirmation: Confirm button (→ pending) | Decline button (opens reason dialog)
  - Preparing: "Mark Ready" button (→ ready) — sends customer notification
  - Ready: "Complete" button (→ completed)

SHIPPING TAB
Filter: fulfillment_type = 'shipping' AND status NOT IN ('declined').
Group: To Pack (pending/awaiting_confirmation/preparing) | Shipped (ready) | Delivered (completed).
Show customer's shipping address below item summary.
Actions: Confirm | Mark Packed (→ preparing) | Mark Shipped (→ ready) | Mark Delivered (→ completed).
Decline available on any non-completed card.

DELIVERY TAB
Filter: fulfillment_type = 'delivery' AND status NOT IN ('completed','declined').
Identical to the delivery section of existing Orders.tsx: show courier status badge,
tracking URL link, driver name/eta if available. Actions: Confirm | Decline.
Courier handles status progression after dispatch.

IN-STORE TAB
Filter: fulfillment_type = 'in_store_pickup' (POS sales). Read-only list of completed sales.
No action buttons. Shows payment method badge (Cash / Card / Split) if present in order metadata.

Each tab: show empty state with icon + message if no orders match.
No kanban view, no KDS link, no kitchen columns.
```

---

## Prompt 8 — ShopPOS.tsx (new page)
> Status: [ ] Not started

```
Create src/pages/dashboard/ShopPOS.tsx — in-store point of sale for retail merchants.
Add route /dashboard/pos to App.tsx inside the existing DashboardLayout (lazy loaded).

TWO-PANEL LAYOUT (flex-row, full viewport height minus top nav):

LEFT PANEL — Cart (w-1/3, border-r, flex-col):
  Cart items list (flex-1, scrollable): each row has product image (24px), name,
  qty stepper (−/+), unit price with unit label, line total. Weight items show
  quantity with decimal (e.g. "0.350 kg"). Remove item button (X).

  Below cart:
  - "Apply promo code" input + Apply button (same validation as storefront promo logic).
    Shows discount line if valid.
  - Customer field: search input, searches customers by name/email/phone using existing
    Supabase customers table. Shows matched customer name + loyalty points balance
    (marketplace tier only). If below marketplace tier, hide loyalty section entirely.
  - Loyalty: "Redeem [X] points" toggle (only if customer identified and tier ≥ marketplace).

  Payment section (mt-auto, border-t, pt-4):
  - Three segmented buttons: Cash | Card | Split
  - Cash: shows "Amount tendered ($)" number input. Below it: "Change due: $X.XX"
    calculated in real time as (tendered - total). Shows red if tendered < total.
  - Card: shows label "Card collected via EFTPOS terminal" (no Stripe charge).
  - Split: shows "Cash portion ($)" input. Remainder shown as "Card: $X.XX".
  - "Complete Sale" button (full-width, primary). Disabled if cart is empty or
    cash tendered < total.

RIGHT PANEL — Product Browser (flex-1):
  Search input (auto-focus on mount, magnifier icon, searches name + SKU).
  Barcode input (below search, labelled "Scan barcode — press Enter or scan"):
    plain text input. On Enter (or when input reaches 8+ chars and contains only
    digits), look up product by barcode field and add 1 unit to cart. Clear input after.
  Category filter chips (horizontal scroll, gap-2): "All" + each category name.
  Product grid (grid-cols-2 md:grid-cols-3, gap-3):
    Each card: image (aspect-square, object-cover), name, price with unit, stock badge.
    Click card → adds 1 unit to cart. If price_unit !== 'each', open a small dialog:
    "Enter weight / quantity" with decimal input, unit label shown, calculated price preview
    (e.g. "0.500 kg × $4.50/kg = $2.25"). Confirm → adds to cart with that quantity.
    Out-of-stock products (stock=0): shown greyed, no click action.

POST-SALE (on Complete Sale click):
  1. Insert order row: status='completed', fulfillment_type='in_store_pickup',
     dine_in=false. Add payment_method to order metadata JSONB
     ('cash' | 'card' | 'split'). Line items built from cart state.
  2. If customer identified: award loyalty points using existing loyalty logic.
  3. Show receipt dialog: order number, items list, subtotal, discount, total, payment
     method, change given (if cash). "Print" button (window.print() with receipt styles).
     "Email receipt" button (invokes email-send edge function with a simple receipt body).
  4. Close dialog → reset cart, customer, promo to empty state.
```

---

## Prompt 9 — ShopMarketplace.tsx (new page)
> Status: [ ] Not started

```
Create src/pages/ShopMarketplace.tsx — public retail marketplace at /shop.
Update App.tsx: change the /shop route (currently pointing to the old Shop component)
to ShopMarketplace. The /shop/:slug route will be updated in the next prompt.

Fetch retail orgs using marketplaceApi.getAll({ business_type: 'retail' }) (added in Prompt 2).
Reuse the same distance calculation helper and geolocation logic from Marketplace.tsx.

PAGE STRUCTURE:

HEADER section:
- Page title: "Shop Local"
- Subtitle: "Discover independent stores near you. Order direct, support local."
- Eat/Shop mode pill (pill container, two side-by-side rounded buttons):
    [🍽 Eat] [🛍 Shop]  ← Shop is active/highlighted
  Clicking "Eat" navigates to /eat and saves 'eat' to localStorage key 'woahh_mode'.
  On mount: read localStorage 'woahh_mode'. If value is 'eat', redirect to /eat.

FILTERS row (below header):
- Search input (searches org name and tagline)
- Category select: All | Grocery & Supermarket | Bakery & Patisserie | Butcher & Deli |
  Bottle Shop & Wine | Health & Wellness | Specialty Food | Pharmacy | Gift & Homewares |
  General Retail
- Fulfillment filter: All | Delivery | Click & Collect | In-Store
- Sort: Featured | Highest Rated | Nearest
- "Impact Partners" toggle chip (filters orgs where total_donations_cents > 0)

MERCHANT CARDS (same Card style as Marketplace.tsx):
- Cover image (marketplace_cover, aspect-video, object-cover)
- Business name (font-semibold)
- Category tags from cuisine_tags array (badge chips)
- Star rating (★ X.X) + review count
- DonationBadge component if total_donations_cents > 0
- Fulfillment badges (Truck icon = delivery, PackageCheck = click & collect, Store = in-store)
- Distance label if geolocation available
- Sponsored badge if org has active promotion record
- Click → navigate to /shop/[subdomain_slug]

Empty state: "No shops listed yet. Know a great local store? Tell them about Woahh."
Page meta title: "Shop Local — Woahh" (use updateMeta helper).
```

---

## Prompt 10 — ShopStorefront.tsx (new page)
> Status: [ ] Not started

```
Create src/pages/ShopStorefront.tsx — public-facing retail store at /shop/:slug.
Update App.tsx: change /shop/:slug from the old Shop component to ShopStorefront.

Fetch org by slug using orgApi.getBySlug(slug). If org.business_type !== 'retail',
redirect to /eat/:slug. If trial expired (use isTrialExpired helper), show StorePausedScreen.

STORE HEADER:
- Full-width cover image (200px height, object-cover, fallback gradient)
- Logo overlay bottom-left of cover (if org has logo)
- Store name (text-2xl font-bold), tagline
- Fulfillment badges: show only modes the org has enabled in settings
- Star rating + review count (if org has reviews)
- DonationBadge if total_donations_cents > 0
- Today's hours (from org settings.hours, show "Open until X" or "Closed today")
- Eat/Shop pill top-right: [🍽 Eat] [🛍 Shop ●] — Eat links to /eat, Shop stays

TWO-COLUMN LAYOUT (sidebar + products):
Left: Category nav (desktop sidebar / mobile horizontal chip scroll).
Right: Product grid.

PRODUCT CARD:
- Image (aspect-square, object-cover, rounded-md)
- Name, short description (1 line truncate)
- Price: if price_unit='each' → "$X.XX"; otherwise → "$X.XX / kg" (or /100g, /litre)
- Sale price: show sale price prominent, original price crossed out, "Sale" badge
- Stock=0: greyed card, "Out of stock" badge, no add button
- Add to cart button / qty stepper if already in cart
- Weight items: on Add, open a quantity dialog — decimal number input, unit label,
  live price preview ("0.500 kg × $4.50 = $2.25"). Customer enters estimated weight.
  A note: "Final charge may vary slightly based on actual weight."

CART (slide-over Sheet, sticky floating button shows item count):
- Line items with qty +/− (weight items show decimal qty + unit)
- Fulfillment selector (radio): only show options org has enabled.
  Delivery → show address input. Shipping → show address input. Click & Collect / In-Store → no address.
- Promo code input + Apply button
- Order notes textarea
- Customer auth: if not signed in, show CustomerAuthDialog (existing component, magic-link flow)
- Totals: subtotal, delivery fee (0 if pickup/in-store), service fee (2% online), total
- "Place Order" → insert order into Supabase → redirect to /order/:id
  Use existing order creation pattern from RestaurantStorefront.

Use existing useCustomerAuth hook and PostPurchaseModal component (shown after order placed).
Set page meta: "[Store name] — Shop on Woahh".
```

---

## Prompt 11 — Eat/Shop mode pill on /eat
> Status: [ ] Not started

```
Small change — only modify src/pages/Marketplace.tsx.

1. In the Marketplace.tsx header area (near the page title or search bar), add an
   Eat/Shop mode pill:

   [🍽 Eat ●] [🛍 Shop]

   Pill container: inline-flex items-center gap-1 bg-muted rounded-full p-1.
   Each button: rounded-full px-3 py-1 text-sm font-medium transition-colors.
   Active style (Eat, current page): bg-background text-foreground shadow-sm.
   Inactive style (Shop): text-muted-foreground hover:text-foreground.

2. Clicking "Shop" → navigate('/shop') and save 'shop' to localStorage key 'woahh_mode'.
   Clicking "Eat" → save 'eat' to localStorage (already on this page, no navigation).

3. On Marketplace.tsx mount, read localStorage key 'woahh_mode'.
   If value is 'shop', call navigate('/shop', { replace: true }) immediately.
   This means if a customer last chose Shop mode, /eat auto-redirects them to /shop.

That is the only change. Do not modify any other component.
```

---

## Execution Notes

- Prompts 1 and 2 have no UI — run them together or back-to-back.
- Prompts 3 and 4 must run in order (4 imports 3).
- Prompts 5, 6, 7, 8 can be run after 4 is complete; order between them doesn't matter.
- Prompts 9, 10, 11 are all customer-facing; 10 must run after 9 (App.tsx route change).
- After Prompt 10, retire/delete the old Shop.tsx if it is no longer referenced.

## Open Questions (resolve before running Prompt 6+)

These were deferred during drafting — answer before sending Prompt 6:

1. **Variant stock**: confirmed approach is each variant tracks stock independently (in the variants JSONB array). ✅ Already written this way in Prompt 6.
2. **Weight items**: confirmed approach is customer enters estimated weight, merchant adjusts final charge if needed. ✅ Already written this way in Prompts 6 and 10.
3. **POS card payment**: confirmed approach is "card collected via EFTPOS terminal" — no Stripe charge at MVP. Stripe Terminal = Phase 2. ✅ Already written this way in Prompt 8.
4. **No-slug /shop demo**: confirmed /shop without a slug becomes the retail marketplace. The demo restaurant stays at /demo. ✅ Already written this way in Prompt 9.

All four open questions have been answered with the recommended approach and baked into the prompts. No blockers.
