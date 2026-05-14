# Woahh — Retail Shop Hardware Strategy
> Last updated: 2026-05-13
> Phase 1 is live. Phase 2 is planned but not yet scoped.

---

## Context

Woahh Shop is the retail arm of the Woahh platform — serving small-to-medium independent retailers: grocery stores, bottle shops, boutiques, fashion outlets, gift shops, bakeries, delis, and butchers. When a retail merchant joins Woahh, they need physical hardware to run their store — a POS terminal to serve customers at the counter, a barcode scanner to ring up products, a receipt printer, and optionally a card reader and handheld PDT for stock management and click & collect picking.

Rather than telling merchants to "go buy your own gear", Woahh supplies pre-configured hardware kits as part of the onboarding startup fee. Everything arrives in a box, turns on, and connects to their Woahh dashboard automatically. The goal is zero friction from sign-up to first sale.

---

## The Three Retail Merchant Types

Woahh serves three distinct retail segments, each with different hardware demands:

### 1. Boutique / Fashion / Gift Shop
**Operations:** Counter sales only; small inventory of SKU-coded items; no weight selling; minimal C&C volume.
**Hardware priority:** Clean, fast counter POS. Barcode scan at checkout. Card payments. Receipts. No need for a PDT on day one.

### 2. Grocery Store / Bottle Shop
**Operations:** High item volume, many barcoded SKUs, regular stock deliveries, weight pricing (managed by merchant), click & collect is a major revenue channel. Cash payments common. Staff need to count stock and receive delivery manifests.
**Hardware priority:** POS + fixed scanner, PDT for stock count and C&C picking, label printer for price stickers, cash drawer for cash sales.

### 3. Bakery / Deli / Butcher
**Operations:** Mix of barcoded and non-barcoded items; date-sensitive stock (short shelf life); weight-based selling; label printing for product/price/date stickers is essential; moderate C&C.
**Hardware priority:** POS + fixed scanner, label printer (critical for food labelling compliance), PDT for stock and C&C picking.

---

## Weight-Based Selling

Woahh does not integrate with weighing scales. Weight selling is handled as follows:

- The customer orders a product (e.g. "500g of eye fillet") and provides their intended quantity
- The order is placed with the stated quantity
- When the merchant fulfils the order, they weigh the actual product on their own certified scale
- The merchant updates the line item quantity and price in Woahh before completing the order
- The customer is charged the corrected amount

**Why this approach:** Certified trade scales require dedicated hardware integrations (vendor APIs or serial port protocols) and compliance with Australian NMI regulations. This is out of scope for Phase 1. The merchant-adjusts flow matches how delis and butchers operate today — they weigh, stick a label, charge accordingly.

---

## Phase 1 — Off-the-Shelf Hardware, Woahh-Configured

Phase 1 uses commercially available consumer and prosumer devices. We don't manufacture anything. We select, bulk-purchase, configure, brand the packaging, and ship.

**Why this approach:**
- Fast to market — no manufacturing lead time
- Low minimum order quantities (no MOQ commitments)
- Proven, reliable devices with existing support ecosystems
- Merchants can replace broken units from any electronics or office supplier
- Allows us to validate the retail hardware model before investing in custom manufacturing

**Device philosophy:**
- Woahh provides Android tablets as the standard POS terminal — affordable, pre-configurable, and touchscreen-native
- Merchants who already own an iPad or Android tablet can use their own device (Woahh is a PWA and runs in any modern browser)
- The software experience is identical regardless of device brand

---

## What Hardware a Retail Merchant Needs

### 1. POS Terminal (Required — every merchant)
The counter tablet where the owner or staff manage sales, view inventory, process walk-in orders, and access the full Woahh dashboard.

- **Device:** 10" Android tablet (e.g. Samsung Galaxy Tab A9, Lenovo Tab M10 Plus)
- **Why 10":** Comfortable counter size; large enough to show the cart, product search, and payment flow; small enough to leave room for the scanner and printer
- **Mounted on:** Adjustable tablet desk stand with integrated cable routing
- **Merchant's own device:** Fully supported — just open Woahh in Chrome and log in

### 2. Fixed Barcode Scanner (Required — all tiers)
A counter-mounted scanner for ringing up barcoded products at the point of sale. The staff member passes items under the scanner or picks them up and scans them — same as any supermarket counter.

- **Device:** Bluetooth or USB 1D/2D barcode scanner (e.g. Inateck BCST-70, Tera HW0002, or equivalent)
- **Why fixed vs handheld:** Counter-mounted scanners are faster at checkout — both hands free to bag, no need to point and aim. A separate handheld PDT handles the warehouse and stockroom work.
- **Connects to:** Bluetooth to the POS tablet (or USB-A via the tablet's USB-C hub)
- **What it scans:** EAN-13, EAN-8, QR, Code128, UPC-A — all standard retail barcodes

### 3. PDT — Portable Data Terminal (Standard and Pro tiers)
An Android-based handheld scanner device for warehouse and stockroom tasks. This is the same class of device used by Coles, Woolworths, and Dan Murphy's staff for stock counting, receiving deliveries, and picking click & collect orders.

- **Device:** Android PDT with built-in laser scanner (e.g. Chainway C60, Honeywell EDA51, or Zebra TC21)
- **Why a PDT over a phone + clip-on scanner:** PDTs are purpose-built for sustained scanning — the trigger, scanner angle, and battery are designed for 8-hour shift use. Consumer phones with Bluetooth scanners are uncomfortable and unreliable for high-volume stock work.
- **Connects to:** Woahh's mobile-optimised dashboard (PWA, full-screen Chrome) via WiFi; no special app install required
- **Pre-configured workflows available on the PDT:**

  | Workflow | What it does |
  |---|---|
  | **Stock Count** | Scan items shelf-by-shelf; Woahh records the count against each product; prints a variance report showing expected vs actual |
  | **Pick Mode** | When a C&C or delivery order is received, the PDT shows the pick list; staff scan each item to confirm they've picked it; order auto-marks as ready when all items confirmed |
  | **Receive Stock** | Scan incoming delivery items against a purchase order or expected manifest; Woahh auto-adds received quantities to stock |
  | **Price/Stock Lookup** | Scan any product barcode to instantly see: product name, selling price, stock on hand, location in store — useful for customer enquiries or staff training |

### 4. Receipt Printer (Required — all tiers)
Prints customer receipts and optionally C&C order slips and label-sized pick tickets.

- **Device:** 58mm Bluetooth thermal receipt printer (e.g. MUNBYN ITPP941B, Rongta RPP300)
- **Why thermal:** No ink, fast, reliable, low running cost
- **Why Bluetooth:** Connects to the tablet wirelessly; no USB cable mess on the counter
- **Paper:** 58mm thermal roll — cheap, available at any stationery supplier
- **Cash drawer port:** The receipt printer includes an RJ11 port that drives a connected cash drawer — no separate driver or USB needed

### 5. Label Printer (Standard and Pro tiers; add-on for Solo)
For printing price stickers, product labels, date labels, and click & collect order bag labels.

- **Device:** 58mm direct thermal label printer (e.g. MUNBYN ITLP941, Zebra ZD220)
- **Why label printing matters for retail:** Bakeries, delis, and butchers require product/date labels on packaged items (a food safety obligation). Grocery stores need to reprint price labels when prices change. C&C operations benefit from a printed order label on each bag at pick time.
- **Connects to:** Bluetooth to the POS tablet; labels designed in Woahh's label builder
- **Label stock:** 58mm × 40mm direct thermal self-adhesive rolls — standard retail label size

### 6. Cash Drawer (Standard and Pro tiers; add-on for Solo)
For merchants who accept cash payments alongside card.

- **Device:** RJ11-connected cash drawer (e.g. APG Vasario, EC Line EC-CD-5005)
- **Connects to:** Receipt printer's RJ11 kick port — opens automatically when a cash sale is finalised in Woahh POS
- **Why RJ11 and not USB:** Standard retail practice; no driver installation; works with any receipt printer that has a kick port (all printers in the Woahh kit do)

### 7. Card Reader — Stripe Terminal M2 (Included — all tiers)
For in-person card payments processed directly through Woahh/Stripe — no separate merchant account needed.

- **Device:** Stripe Terminal M2 Bluetooth card reader
- **Why Stripe:** Stripe Connect is already the payment backbone for Woahh's commission model. Using Stripe Terminal means in-store card payments flow through the same system as online orders — unified reporting, unified payouts, unified dispute management.
- **Note:** Merchants who already have an EFTPOS terminal (CommBank, Tyro, Square) can continue using it alongside Woahh. The Stripe Terminal is bundled for merchants who don't have one or want fully integrated reporting.

### 8. Customer-Facing Display (Pro tier; add-on for others)
A screen facing the customer at the counter showing their live cart, item prices, running total, and order confirmation.

- **Device:** 15.6" portable USB-C monitor (e.g. ASUS ZenScreen MB16ACV or equivalent)
- **Connects to:** USB-C from the POS tablet; no separate power supply needed; mirrors the customer cart view from Woahh POS
- **Why:** Increases customer trust and order accuracy; reduces disputes; standard in all major retail environments

---

## Kit Tiers — Phase 1

### Retail Solo Kit — $799 startup fee

For boutique stores, fashion retailers, gift shops, small independent shops with straightforward counter operations.

| Component | Purpose | Component Cost |
|---|---|---|
| 10" Android tablet | POS terminal | $175 |
| Bluetooth fixed barcode scanner | Product scanning at counter | $55 |
| Stripe Terminal M2 | In-person card payments | $90 |
| Adjustable tablet desk stand | Counter mount | $30 |
| 58mm Bluetooth thermal receipt printer | Customer receipts | $100 |
| Cables, protective case, Woahh branded box | Setup + branding | $25 |
| **Component subtotal** | | **$475** |
| Packaging materials | | $22 |
| Shipping (AU metro, tracked) | | $14 |
| Configuration labour (pre-setup, test, pack) | | $55 |
| **True COGS (fully loaded)** | | **$566** |
| **Startup fee charged** | | **$799** |
| **Margin** | | **$233 (29%)** |

**Who this is for:** A boutique clothing store, gift shop, or small independent retailer who sells barcoded products from a single counter. No click & collect picking workflow, no stock receiving complexity, no food labelling requirements.

**What "pre-configured" means:** Woahh team installs the Woahh PWA as the home screen app, pairs the Stripe Terminal M2 via Bluetooth, pairs the barcode scanner, connects the receipt printer, sets up auto-launch on boot, and tests a full sale end-to-end. Merchant opens the box, plugs in the tablet, and is live.

---

### Retail Standard Kit — $1,299 startup fee

For grocery stores, bottle shops, delis, bakeries, and butchers — merchants with stock management needs, click & collect workflows, and food labelling requirements.

Everything in Solo, plus:

| Additional Component | Purpose | Component Cost |
|---|---|---|
| Android PDT (Chainway C60 or equivalent) | Stock count, C&C picking, receive stock, price lookup | $280 |
| 58mm direct thermal label printer | Price labels, product labels, C&C bag labels, food date labels | $95 |
| Cash drawer (RJ11 kick port) | Cash payment management | $80 |
| **Additional component cost** | | **$455** |
| **Component subtotal** | | **$930** |
| Packaging | | $25 |
| Shipping (heavier box) | | $18 |
| Config labour (PDT setup, label templates, cash drawer test) | | $95 |
| **True COGS** | | **$1,068** |
| **Startup fee** | | **$1,299** |
| **Margin** | | **$231 (18%)** |

**Who this is for:** A bottle shop running regular deliveries and a busy click & collect service, or a deli printing daily price/date labels and managing short-shelf-life stock. The PDT is the key addition — it enables staff to run stocktakes, receive deliveries, and pick C&C orders with a scanner in hand, exactly as they would at any major grocery chain.

**PDT setup:** Woahh PWA pre-loaded in full-screen Chrome as the default app; Pick Mode, Stock Count, and Receive Stock shortcuts on the home screen. The PDT connects to the merchant's store WiFi and is linked to their org before shipping.

**Label templates:** Three pre-built label templates are configured before shipping — product price label (name + price + barcode), C&C bag label (order number + customer name + items summary), and food date label (product name + packed date + use-by date). Merchant customises templates from the Woahh Inventory settings.

---

### Retail Pro Kit — $1,899 startup fee

For higher-volume retailers with multiple staff, heavy click & collect operations, or large floor areas — grocery stores, bottle shops, and larger independent retailers.

Everything in Standard, plus:

| Additional Component | Purpose | Component Cost |
|---|---|---|
| 15.6" portable USB-C customer-facing display | Live cart + total shown to customer at counter | $95 |
| Second Android PDT | Enables two pickers running simultaneously for high C&C volume | $280 |
| **Additional component cost** | | **$375** |
| **Component subtotal** | | **$1,305** |
| Packaging | | $30 |
| Shipping (larger, heavier box) | | $24 |
| Config labour (second PDT setup, display test) | | $135 |
| **True COGS** | | **$1,494** |
| **Startup fee** | | **$1,899** |
| **Margin** | | **$405 (21%)** |

**Who this is for:** A busy bottle shop or grocery store where one PDT creates a picking bottleneck during peak click & collect windows. Two PDTs mean two staff can pick simultaneously. The customer display builds trust at the counter and is standard in any store doing more than ~$500k annual revenue.

---

## Optional Add-Ons

Available to any tier — added to the startup invoice or purchased separately.

| Add-On | What's Included | Woahh Cost | Charge | Margin |
|---|---|---|---|---|
| PDT Bundle | Android PDT + pre-configured for store's org + case | $280 | $499 | $219 |
| Label Printer Bundle | 58mm thermal label printer + 3 pre-built label templates | $95 | $179 | $84 |
| Cash Drawer | RJ11 cash drawer wired to existing receipt printer | $80 | $149 | $69 |
| Customer-Facing Display | 15.6" portable USB-C monitor facing customer | $95 | $199 | $104 |
| Second Fixed Scanner | Extra Bluetooth counter scanner for a second checkout point | $55 | $99 | $44 |
| Damage Cover | Monthly add-on; covers accidental screen damage on tablets and PDTs | — | $9/mo | — |

---

## Founding Merchant Model (First 100 Merchants — platform-wide)

The first 100 merchants across both Woahh (restaurant) and Woahh Shop (retail) receive hardware for free as part of the acquisition strategy:
- Merchants 1–50: Free hardware + free software + zero commission permanently
- Merchants 51–100: Free hardware + free software + full commission from day one

For retail, the blended average kit COGS is approximately **$800** (weighted toward Standard tier for grocery/deli merchants). Hardware cost absorbed across the founding retail cohort is treated as customer acquisition cost — justified by the testimonials, referrals, and social proof these founding merchants generate. Hardware self-funds from merchant 101+ via startup fees.

---

## Hardware by Merchant Type — Summary

| Merchant Type | Tablet | Fixed Scanner | PDT | Label Printer | Cash Drawer | Stripe Terminal | Customer Display |
|---|---|---|---|---|---|---|---|
| Boutique / Fashion / Gift | ✅ | ✅ | ❌ | ❌ | Optional | ✅ | Optional |
| Grocery / Bottle Shop | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | Pro tier |
| Bakery / Deli / Butcher | ✅ | ✅ | ✅ | ✅ | Optional | ✅ | Optional |

**Recommended kit by type:**
- Boutique / Fashion / Gift → **Retail Solo Kit**
- Grocery / Bottle Shop → **Retail Standard or Pro Kit**
- Bakery / Deli / Butcher → **Retail Standard Kit**

---

## Phase 2 — Woahh-Branded Hardware

Once the merchant base is large enough to justify manufacturing commitments, Phase 1 devices are replaced with hardware bearing the Woahh brand.

### Option A — White-Label Partnership
Partner with an established retail POS hardware manufacturer (e.g. Sunmi, PAX Technology, Chainway) to produce Woahh-branded versions of their existing devices. Sunmi and Chainway already manufacture Android-based POS terminals, handheld PDTs, receipt printers, and label printers used by major retail chains globally.

**What this looks like:**
- Woahh-branded Android POS terminal (all-in-one: screen + receipt printer + card reader + scanner in one unit)
- Woahh-branded PDT (purpose-built, ergonomic, Woahh OS skin)
- Woahh-branded label printer (compact, wireless, integrated label design)
- Minimum order quantities typically 500–2,000 units per SKU
- 6–12 month lead time from partnership agreement to first shipment
- Cost per unit drops 20–40% vs buying retail consumer devices in bulk

### Option B — Custom-Designed Hardware
Commission hardware engineered specifically for Woahh — custom form factor, custom UI chip, custom enclosure design. Full control over the experience but substantially higher R&D cost and timeline (2–3 years, $2M+ investment). Reserved for when Woahh has significant merchant scale and Series A/B funding.

**Decision:** Which path is taken will depend on merchant volume at the time of Phase 2 scoping. Both paths result in the same outcome for merchants — Woahh-branded hardware indistinguishable from enterprise retail systems like Square for Retail, Lightspeed, or Cin7.

---

## Configuration & Logistics Process (Phase 1)

1. **Order placed** — merchant signs up and pays startup fee (or receives free founding kit)
2. **Kit picked** — correct tier components pulled from inventory
3. **Configuration:**
   - Tablet: Woahh PWA installed as home screen; auto-launch on boot; Stripe Terminal M2 paired and linked to merchant's Stripe Connect account; receipt printer paired
   - Fixed scanner: paired to tablet via Bluetooth; scanned barcode input registered in Woahh POS test product
   - PDT (Standard/Pro): Woahh PWA full-screen Chrome set as default; Pick Mode, Stock Count, Receive Stock, and Price Lookup shortcuts pinned to home screen; org URL pre-loaded; WiFi pre-auth placeholder note included (merchant sets their SSID/password on first boot)
   - Label printer (Standard/Pro): paired to tablet; three default label templates pre-loaded in Woahh settings (price label, C&C bag label, food date label)
   - Cash drawer (Standard/Pro): RJ11 connected to receipt printer kick port; test kick triggered from Woahh POS
   - Customer display (Pro): USB-C connected to tablet; customer cart view set as the mirror display
4. **Testing:** A test sale is completed end-to-end through the merchant's actual account — scan a test barcode, add to cart, process a card payment, print receipt, kick cash drawer, print a label. Everything confirmed before packing.
5. **Packing:** All devices placed in Woahh-branded box with quick-start guide, cable labels, a label paper starter roll, and a personal welcome card
6. **Shipping:** Tracked courier (StarTrack or AusPost Express) — merchant receives within 2–3 business days metro, 4–5 regional
7. **Onboarding call:** Optional 20-minute video call to walk the merchant through first login, product catalogue import (CSV), and their first sale; scheduled at booking time
