# Woahh — Restaurant Hardware Strategy
> Last updated: 2026-05-13
> Phase 1 is live. Phase 2 is planned but not yet scoped.

---

## Context

Woahh is a multi-tenant SaaS platform for small hospitality businesses. When a restaurant merchant joins Woahh, they need physical hardware to run their operation — a tablet to take and manage orders, a display in the kitchen to show the crew what's cooking, and optionally a card reader for in-person payments.

Rather than telling merchants to "go buy their own gear", Woahh supplies pre-configured hardware kits as part of the onboarding startup fee. Everything arrives in a box, turns on, and connects to their Woahh dashboard automatically. The goal is zero friction from sign-up to first order.

---

## Phase 1 — Off-the-Shelf Hardware, Woahh-Configured

Phase 1 uses commercially available consumer and prosumer devices — Android tablets, streaming sticks, and Stripe card readers. We don't manufacture anything. We select, bulk-purchase, configure, brand the packaging, and ship.

**Why this approach:**
- Fast to market — no manufacturing lead time
- Low minimum order quantities (no MOQ commitments)
- Proven, reliable devices with existing support ecosystems
- Merchants can replace broken units from any electronics retailer
- Allows us to validate the hardware model before investing in custom manufacturing

**Device philosophy:**
- Woahh provides Android tablets as the standard POS device — affordable, flexible, pre-configurable
- Merchants who already own an iPad or Android tablet can use their own device (Woahh is a PWA and runs in any modern browser)
- The software experience is identical regardless of device brand

---

## What Hardware a Restaurant Needs

### 1. POS Terminal (Required — every merchant)
The front-of-house tablet where the owner or staff manage incoming orders, view the menu, process walk-in sales, and access the full Woahh dashboard.

- **Device:** 10" Android tablet (e.g. Samsung Galaxy Tab A9, Lenovo Tab M10 Plus)
- **Why 10":** Large enough for comfortable use at a counter or mounted on a stand; small enough to move if needed
- **Mounted on:** Adjustable tablet desk stand with integrated cable routing so the cable doesn't hang loose
- **Merchant's own device:** Fully supported — just open Woahh in Chrome and log in

### 2. Kitchen Display System / KDS (Standard — Marketplace and above)
A screen in the kitchen showing active orders, items to prepare, and order status. Replaces printed dockets. Updates in real time as orders come in or are modified.

- **Device:** Android TV streaming stick (Amazon Fire TV Stick 4K Max, Xiaomi Mi Stick 4K, or Chromecast with Google TV)
- **Why a stick:** Plugs into any HDMI port on any TV the merchant already owns — no separate screen needed at Marketplace tier. The kitchen almost always has an existing TV or monitor.
- **Mounted on:** The merchant's existing kitchen TV or monitor
- **What it shows:** The Woahh KDS web page running full-screen — incoming orders, elapsed time, prep status, table/zone information, colour-coded by order type

### 3. Receipt Printer (Standard — all tiers)
Prints customer receipts and, optionally, kitchen order slips (for merchants who want a paper backup).

- **Device:** 58mm Bluetooth thermal receipt printer (e.g. MUNBYN, Rongta)
- **Why thermal:** No ink, fast, reliable, low running cost
- **Why Bluetooth:** Connects to the tablet wirelessly; no USB cable mess on the counter
- **Paper:** 58mm thermal roll — cheap, available at any stationery supplier

### 4. Card Reader — Stripe Terminal M2 (Included — all tiers)
For in-person card payments processed directly through Woahh/Stripe — no separate merchant account needed.

- **Device:** Stripe Terminal M2 Bluetooth card reader
- **Why Stripe:** Stripe Connect is already the payment backbone for Woahh's commission model. Using Stripe Terminal means card payments flow through the same system as online orders — unified reporting, unified payouts, unified dispute management.
- **Note:** Merchants who already have an EFTPOS terminal (CommBank, Tyro, Square) can continue using it. The Stripe Terminal is bundled for merchants who don't have one or want fully integrated reporting.

### 5. Kitchen Display Screen (Growth tier — included)
At Growth tier, Woahh includes the actual kitchen screen — not just the stick. Useful for merchants who don't have an existing TV in the kitchen or want a dedicated display.

- **Device:** 32" Full HD commercial-grade display (Kogan, entry commercial)
- **Mounted on:** VESA wall bracket included

### 6. Waiter / Floor Tablet (Growth tier — included)
A second smaller tablet for front-of-house staff to carry on the floor — view table status, send orders, mark tables as served.

- **Device:** 8" Android tablet on an adjustable stand
- **Use case:** Larger venues with table service, multi-room spaces, or rooftop areas

---

## Kit Tiers — Phase 1

### Solo Starter Kit — $699 startup fee

For single-operator cafés, takeaway shops, food trucks, small restaurants.

| Component | Purpose | Component Cost |
|---|---|---|
| 10" Android tablet | POS terminal | $175 |
| Stripe Terminal M2 | In-person card payments | $90 |
| Adjustable tablet desk stand | Counter mount | $30 |
| 58mm Bluetooth thermal receipt printer | Customer receipts | $100 |
| Cables, protective case, Woahh branded box | Setup + branding | $25 |
| **Component subtotal** | | **$420** |
| Packaging materials | | $22 |
| Shipping (AU metro, tracked) | | $14 |
| Configuration labour (pre-setup, test, pack) | | $45 |
| **True COGS (fully loaded)** | | **$501** |
| **Startup fee charged** | | **$699** |
| **Margin** | | **$198 (28%)** |

**What "pre-configured" means:** Before shipping, the Woahh team installs the Woahh PWA as the home screen app, pairs the Stripe Terminal M2 via Bluetooth, sets up auto-launch on boot, connects the receipt printer, and tests the full order flow end-to-end. Merchant opens the box, plugs in the tablet, and is live.

---

### Marketplace Business Kit — $899 startup fee

For restaurants wanting marketplace exposure, table management, and a kitchen display.

Everything in Solo, plus:

| Additional Component | Purpose | Component Cost |
|---|---|---|
| Android TV streaming stick (Fire Stick 4K Max or equivalent) | Kitchen Display System | $50 |
| HDMI extension cable (0.3m) | Lets the stick sit flush behind the merchant's kitchen TV | $8 |
| **Additional component cost** | | **$58** |
| **Component subtotal** | | **$478** |
| Packaging | | $22 |
| Shipping | | $14 |
| Config labour (includes KDS setup + test) | | $65 |
| **True COGS** | | **$579** |
| **Startup fee** | | **$899** |
| **Margin** | | **$320 (36%)** |

**Kitchen setup:** The streaming stick is pre-loaded with the Woahh KDS page as the default launch app. Merchant plugs it into their kitchen TV's HDMI port, connects to their WiFi, and the KDS appears automatically.

---

### Growth Pro Kit — $1,399 startup fee

For busy multi-staff restaurants, venues with separate kitchen zones, table service operations.

Everything in Marketplace, plus:

| Additional Component | Purpose | Component Cost |
|---|---|---|
| 32" Full HD display + VESA wall bracket | Dedicated kitchen KDS screen (for merchants without a kitchen TV) | $190 |
| 8" Android tablet | Waiter/floor tablet for table management | $100 |
| Adjustable stand (floor/counter) | Waiter station mounting | $30 |
| **Additional component cost** | | **$320** |
| **Component subtotal** | | **$798** |
| Packaging | | $25 |
| Shipping (heavier, bulkier box) | | $24 |
| Config labour (additional devices) | | $120 |
| **True COGS** | | **$967** |
| **Startup fee** | | **$1,399** |
| **Margin** | | **$432 (31%)** |

---

## Optional Add-Ons

Available to any tier — added to the startup invoice or purchased separately.

| Add-On | What's Included | Woahh Cost | Charge | Margin |
|---|---|---|---|---|
| Kitchen Display Bundle | 32" FHD TV + VESA wall mount (stick already included in Marketplace/Growth) | $190 | $349 | $159 |
| Customer-Facing Display | 15.6" portable USB-C monitor facing the customer — shows live cart, total, confirmation | $95 | $199 | $104 |
| Additional KDS Zone | Extra streaming stick, pre-configured for a second kitchen zone (grill, cold, pass) | $50 | $99 | $49 |
| Second Waiter Tablet | Extra 8" tablet + stand for larger floor areas | $130 | $229 | $99 |
| Damage Cover | Monthly add-on; covers accidental screen damage on tablets and kitchen TV | — | $9/mo | — |

---

## Founding Merchant Model (First 100 Merchants)

The first 100 merchants on Woahh receive hardware for free as part of the acquisition strategy:
- Merchants 1–50: Free hardware + free software + zero commission permanently
- Merchants 51–100: Free hardware + free software + full commission from day one

Hardware cost absorbed by Woahh for 100 merchants at blended average kit COGS (~$579): **~$57,900**

This is treated as a customer acquisition cost (CAC of ~$579/merchant) — justified by the testimonials, referrals, and social proof these founding merchants generate. Hardware self-funds from merchant 101+ via startup fees.

---

## Phase 2 — Woahh-Branded Hardware

Once the merchant base is large enough to justify manufacturing commitments, Phase 1 devices are replaced with hardware bearing the Woahh brand.

### Option A — White-Label Partnership
Partner with an established POS hardware manufacturer (e.g. Sunmi, PAX Technology, Ingenico) to produce Woahh-branded versions of their existing devices. Sunmi, for example, already manufactures Android-based POS terminals, handheld scanners, receipt printers, and kitchen displays used by major hospitality chains globally.

**What this looks like:**
- Woahh-branded Android POS terminal (all-in-one: screen + receipt printer + card reader in one unit)
- Woahh-branded kitchen display (purpose-built, no Android stick required)
- Minimum order quantities typically 500–2,000 units per SKU
- 6–12 month lead time from partnership agreement to first shipment
- Cost per unit drops 20–40% vs buying retail consumer devices in bulk

### Option B — Custom-Designed Hardware
Commission hardware engineered specifically for Woahh — custom form factor, custom UI chip, custom enclosure design. Full control over the experience but substantially higher R&D cost and timeline (2–3 years, $2M+ investment). Reserved for when Woahh has significant merchant scale and Series A/B funding.

**Decision:** Which path is taken will depend on merchant volume at the time of Phase 2 scoping. Both paths result in the same outcome for merchants — Woahh-branded hardware that is indistinguishable from enterprise POS systems like Square, Toast, or Lightspeed.

---

## Configuration & Logistics Process (Phase 1)

1. **Order placed** — merchant signs up and pays startup fee (or receives free founding kit)
2. **Kit picked** — correct tier components pulled from inventory
3. **Configuration** — tablet connected to PC; Woahh PWA installed as home screen; auto-launch on boot enabled; Stripe Terminal M2 paired via Bluetooth and linked to merchant's Stripe Connect account; receipt printer paired; KDS stick configured to merchant's org URL; all devices factory-reset tested
4. **Testing** — a test order is placed end-to-end through the merchant's actual account to confirm everything works before packing
5. **Packing** — devices placed in Woahh-branded box with quick-start guide, cable labels, and a personal welcome card
6. **Shipping** — tracked courier (StarTrack or AusPost Express) — merchant receives within 2–3 business days metro, 4–5 regional
7. **Onboarding call** — optional 15-minute video call to walk merchant through first login and setup; scheduled at booking time
