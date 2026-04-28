# GrowthHub — Non-Dev Implementations

> Operational, legal, hardware, and business decisions that need to happen outside the codebase.
> These inform product decisions and should be resolved before or alongside the features they support.
> Last updated: 2026-04-26

---

## Status Key
- `[ ]` Not started
- `[~]` In progress / being worked on
- `[x]` Done

---

## 1. Hardware Strategy

### 1.1 Tier-Based Hardware Bundles (Option A — Subsidised Lease)
**Status:** `[ ]`

**The model:**
Merchants receive a pre-configured hardware kit as part of their startup fee. They are on a subsidised lease — after 12 months of active subscription, they own the hardware outright. If they cancel before 12 months, hardware must be returned or they pay a buyout fee equal to the remaining lease value.

This removes the "go buy your own hardware" barrier while protecting GrowthHub's cash. You don't gift hardware — you extend the startup fee to cover a lease, which is a business cost recoverable through LTV.

---

### 1.2 Kit Contents by Tier

---

**Solo Starter Kit** — $699 startup fee

| Item | Purpose | Bulk Cost (AUD) |
|---|---|---|
| 1× 10" Android tablet (Lenovo Tab M10 / Samsung Tab A9) | POS desk terminal | $150–200 |
| 1× Stripe Terminal M2 card reader | In-person card payments | $90 |
| 1× Adjustable tablet desk stand with cable routing | Counter mount | $25–35 |
| 1× 58mm Bluetooth thermal receipt printer | Customer receipts | $80–120 |
| Cables, case, GH branded packaging | — | $20–30 |
| **Total hardware cost** | | **~$365–475** |
| **Startup fee charged** | | **$699** |
| **Hardware margin** | | **~$224–334** |

Pre-configured before shipping: GrowthHub PWA as home screen, Stripe Terminal paired, dashboard auto-launches on boot.

**Optional add-ons available at Solo tier:** see §1.3.

---

**Marketplace Business Kit** — $899 startup fee

Everything in Solo, plus:

| Item | Purpose | Bulk Cost (AUD) |
|---|---|---|
| 1× Android TV stick (Xiaomi Mi Stick 4K or Chromecast w/ Google TV) | Kitchen KDS — plugs into merchant's existing HDMI TV | $40–60 |
| 1× HDMI extension cable (0.3m) | Lets the stick sit flush behind the screen | $5–10 |
| **Additional cost** | | **~$45–70** |
| **Total hardware cost** | | **~$410–545** |
| **Startup fee charged** | | **$899** |
| **Hardware margin** | | **~$354–489** |

The TV stick comes pre-configured and plugs into a TV the merchant already has. If they don't have one, see §1.3 add-ons.

---

**Growth Pro Kit** — $1,399 startup fee

Everything in Marketplace (Solo desk tablet + kitchen TV stick), plus:

| Item | Purpose | Bulk Cost (AUD) |
|---|---|---|
| 1× 32" FHD TV (Kogan/entry-level commercial) | Kitchen KDS display — included so no sourcing needed | $150–180 |
| 1× TV wall-mount bracket (VESA 200×200) | Wall-mount for kitchen screen | $20–30 |
| 1× 8" Android tablet (entry model) | Waiter / floor display (portable, handheld) | $80–120 |
| 1× Adjustable tablet stand (counter/floor) | Waiter station mount | $25–35 |
| **Additional cost** | | **~$275–365** |
| **Total hardware cost** | | **~$685–910** |
| **Startup fee charged** | | **$1,399** |
| **Hardware margin** | | **~$489–714** |

Total Growth setup: **1 desk POS tablet + 1 Android TV stick + 1 32" kitchen display + 1 waiter tablet.** Everything is included — merchant unpacks the box, mounts the TV, and is live.

---

### 1.3 Optional Add-Ons

Available to any tier — added to the startup invoice or ordered separately. All items pre-configured before dispatch.

| Add-On | What's Included | GH Cost | Charge | Margin |
|---|---|---|---|---|
| **Kitchen Display Bundle** | 32" FHD TV + TV wall-mount bracket (Solo/Marketplace: already have the stick) | $170–210 | $349 | ~$139–179 |
| **Customer-Facing Display** | 15.6" portable USB-C monitor, mounts behind POS tablet facing customer — shows live cart, total, thank-you screen | $80–110 | $199 | ~$89–119 |
| **Additional KDS Zone** | Extra Android TV stick, pre-configured for a second kitchen zone (grill, cold, pass) — plug into any TV | $40–60 | $99 | ~$39–59 |
| **Second Waiter Tablet** | Extra 8" tablet + stand, configured as waiter / floor display | $105–155 | $229 | ~$74–124 |
| **Damage Cover** | Monthly add-on; covers accidental screen damage (tablets + TV) | — | $7/mo | — |

**When to upsell each:**
- **Kitchen Display Bundle** → Solo or Marketplace merchants who don't already have a kitchen TV
- **Customer-Facing Display** → any counter-service or café that wants a professional checkout feel (common in coffee shops, fast food)
- **Additional KDS Zone** → busy restaurants with separate hot/cold/grill stations — each zone needs its own view
- **Second Waiter Tablet** → larger floor areas with multiple service sections

---

### 1.4 Full Cost & Revenue Breakdown

#### Per-item hardware cost (mid-point estimates)

```
Item                                      Solo    Marketplace    Growth
─────────────────────────────────────────────────────────────────────────
10" POS tablet                            $175        $175         $175
Stripe Terminal M2 card reader             $90         $90          $90
Tablet desk stand                          $30         $30          $30
58mm Bluetooth receipt printer            $100        $100         $100
Cables, case, GH branded packaging         $25         $25          $25
Android TV stick (kitchen KDS)              —          $50          $50
HDMI extension cable                        —           $8           $8
32" FHD TV (kitchen display)                —           —           $165
TV wall-mount bracket                       —           —            $25
8" tablet (waiter display)                  —           —           $100
Waiter tablet stand                         —           —            $30
─────────────────────────────────────────────────────────────────────────
TOTAL HARDWARE COST                       $420        $478         $798
STARTUP FEE CHARGED                       $699        $899        $1,399
HARDWARE MARGIN                           $279        $421          $601
HARDWARE MARGIN %                          40%         47%           43%
```

#### Startup fee with popular add-ons

```
Scenario                                          GH Cost    Charge    Margin
────────────────────────────────────────────────────────────────────────────────
Solo — base kit only                               $420       $699      $279
Solo + Kitchen Display Bundle                      $590       $1,048    $458
Solo + Kitchen Display + Customer-Facing Display   $685       $1,247    $562
Marketplace — base kit only                        $478       $899      $421
Marketplace + Kitchen Display Bundle               $648       $1,248    $600
Growth — base kit only (TV included)               $798       $1,399    $601
Growth + Customer-Facing Display                   $893       $1,598    $705
Growth + 2nd Waiter Tablet                         $928       $1,628    $700
Growth + Additional KDS Zone                       $848       $1,498    $650
```

#### 12-month merchant value per tier (base kit, no add-ons)

```
                  Startup    Monthly    12-mo Sub    Year-1 Total    Hardware Margin
                  ─────────────────────────────────────────────────────────────────
Solo              $699       $49/mo     $588         $1,287          $279
Marketplace       $899       $99/mo     $1,188       $2,087          $421
Growth            $1,399     $199/mo    $2,388       $3,787          $601
```

#### Fleet revenue model — 100 merchants (assumed split: 40 Solo / 35 Marketplace / 25 Growth)

```
Tier          Count    Startup Revenue    Annual Sub Revenue    Year-1 Revenue
────────────────────────────────────────────────────────────────────────────────
Solo             40       $27,960             $23,520             $51,480
Marketplace      35       $31,465             $41,580             $73,045
Growth           25       $34,975             $59,700             $94,675
────────────────────────────────────────────────────────────────────────────────
TOTAL           100       $94,400            $124,800            $219,200
```

**Hardware COGS from that cohort: ~$55,700 (startup fees cover it all with ~$38,700 margin)**

> Infrastructure costs (Supabase, Resend, Clicksend, Lovable) at 100 merchants ≈ $2,500–3,500/mo — see BUSINESS_STRATEGY.md for full infra cost model.

---

### 1.5 Kitchen Display Screen — How It Works

**The problem with a tablet in a kitchen:**
An 8" tablet on a bracket is fine for a small café counter but falls short in a real commercial kitchen — cooks move around, there's steam and heat, and the screen needs to be readable from 2–3 metres away. Industry standard (McDonald's, Toast KDS, Square KDS) uses a **large wall-mounted display**, typically 24"–43".

**The solution: Android TV stick + any HDMI screen**
GrowthHub's `/dashboard/kitchen` route is a webpage. Any screen with a browser can become a KDS. An Android TV stick (~$40–60 bulk) plugs into the HDMI port of whatever TV or monitor the merchant already has on the wall — or a cheap one they source themselves. The stick runs **Fully Kiosk Browser for Android TV** (same $7 USD one-time licence), locked to the kitchen URL.

**This approach is:**
- Cheaper than bundling a dedicated tablet ($40–60 vs $80–120)
- Better visibility — orders displayed at 32"–55" are readable from across the kitchen
- Zero friction — most kitchens already have a TV, or budget TVs are $150–250 at Kmart/Kogan
- Still upgradeable — merchant can move to a bigger screen without changing anything in the system

**Pre-configuration (done before shipping):**
1. Factory-reset the TV stick and sign in with a fresh Google account (created per-device)
2. Sideload **Fully Kiosk Browser for Android TV** (APK install via ADB or Google Play)
3. Set start URL: `https://app.growerr.com/dashboard/kitchen`
4. Enable auto-start on boot, auto-reload on crash, screen-always-on
5. Lock device — disable home button, notifications, and all other apps

**Merchant setup (2 minutes):**
1. Kit arrives — TV stick is ready to go
2. Plug into kitchen TV's HDMI port, plug USB-C power into TV's USB port or wall
3. Log in once with GrowthHub credentials
4. Done — orders appear in real time from that point on

**The kitchen screen never needs to be touched again.** New orders appear and update automatically via Supabase Realtime.

**Multiple kitchen zones (large restaurants):**
High-volume kitchens split by station (hot, cold, grill, expeditor). Each zone just needs one more TV stick + a screen. This is the optional add-on path (§1.3) — merchants buy extra sticks as needed. The cost per additional zone is ~$40–60 (stick only, they use their own screens).

---

### 1.6 Waiter / Floor Display — How It Works

The waiter tablet (Growth kit) is an 8" Android tablet — portable, so waiters can carry it to the pass or leave it at a floor station. It shows the same `/dashboard/kitchen` view or the future `/dashboard/waiter` route (to be built — shows only "Ready" status orders with table numbers in large format so floor staff know what to run without crowding the kitchen screen).

Setup is identical to other displays — Fully Kiosk Browser, auto-launch, kiosk lock. Because it's a standard tablet (not a TV stick), it also works as a secondary POS for busy services.

**Use cases:**
- Restaurant: waiter checks which tables' food is ready for pickup from the pass
- Retail: counter staff see which click-and-collect orders are packed and ready to hand over
- Busy service: can double as a secondary order-taking terminal if needed

---

### 1.7 Receipt Printer — How It Works

**Short-term (already working):** The POS WalkInOrderDialog already has a `window.print()` approach that opens a styled print dialog. Any Bluetooth or USB printer the merchant connects to their tablet can print from this.

**Better long-term approach:** Source **Epson TM-m30III** or **Star Micronics mPOP** — both have JavaScript/Web SDKs that allow direct printing from the browser without a print dialog. Epson ePOS SDK is free and well-documented. At bulk pricing these are ~$120–180 AUD.

The WalkInOrderDialog receipt HTML is already designed for 80mm thermal output (monospaced font, narrow layout).

---

### 1.7 Supplier Strategy

**Tablets (desk POS + waiter display):**
- **Lenovo Business Direct** or **Samsung Business** for bulk purchasing — negotiable pricing at 20+ units
- Alternatively: Alibaba OEM Android tablets (10" 4GB/64GB) from verified manufacturers at ~$80–100 AUD/unit at 50+ MOQ — higher risk, lower cost
- Start with Samsung/Lenovo for first 20 merchants (quality control), move to OEM at scale

**Android TV sticks (kitchen KDS):**
- **Xiaomi Mi Stick 4K** — ~$40–50 AUD bulk; full Android, supports APK sideloading, reliable
- **Chromecast with Google TV (HD)** — ~$50–60 AUD; easiest Google Play access, well-supported
- Avoid Amazon Fire TV Sticks — Fire OS is locked down; sideloading is possible but fiddly
- At 50+ units, approach Xiaomi Australia or a local electronics distributor for bulk pricing

**Kitchen screens (optional add-on):**
- **Kogan Australia** — 32" FHD TVs ~$149–179 AUD; no smart TV needed (the stick provides the smarts)
- **Samsung Business** or **LG Commercial** — better durability for kitchen environments; ~$200–350 for 32"
- Avoid sourcing screens in bulk upfront — stock on demand as merchants order the add-on

**Card readers:**
- Source directly through **Stripe's hardware programme** — bulk pricing available once you have merchant volume
- Stripe Terminal M2 is the recommended starting point (USB-C, works everywhere)

**Printers:**
- **Star Micronics** has an Australian distributor and a reseller programme
- **Epson** similar — both offer bulk pricing with reseller agreements

**Packaging:**
- Branded unboxing experience: GrowthHub-branded outer box, welcome card, QR code setup guide
- Can be done with a local packaging supplier at ~$15–25 per kit (adds perceived value significantly)

---

### 1.8 Logistics & Returns

**Shipping:**
- Use Australia Post Business or Sendle for domestic (cheaper than AusPost at volume)
- StarTrack for time-sensitive replacements

**Returns / damage:**
- 12-month hardware warranty covered by GrowthHub (sourced from supplier warranty)
- If merchant cancels subscription before 12 months: 14-day window to return hardware in working condition, or pay buyout fee
- Buyout fee = (12 - months_active) × (kit_cost / 12) — prorate the remaining lease
- Screen damage not covered under warranty (accidental damage gap — can offer optional $5/mo damage cover later)

**Remote management (MDM):**
- Scale 0–50 merchants: manual pre-configuration before shipping, no MDM needed
- Scale 50+ merchants: implement **Headwind MDM** (open source, self-hosted) or **ManageEngine MDM** (~$2/device/month) — allows remote wipe, app updates, crash monitoring

---

### 1.9 Pilot Plan

Before investing in bulk inventory:
1. Pilot with 5–10 early merchants using retail-purchased hardware (full cost, no margin — this is R&D)
2. Validate: does the setup guide work? Do tablets hold up in a kitchen environment? Which printer works best?
3. After 10 successful installs, approach Lenovo/Samsung for bulk pricing
4. Lock in your first bulk order (20–50 units) once pricing and kit are finalised

---

## 2. Legal & Compliance

### 2.1 Privacy Policy & Terms of Service
**Status:** `[ ]`

**What needs to happen:**
- Draft two documents: a **Merchant Terms of Service** (the contract between GrowthHub and business owners) and a **Customer Privacy Policy** (the notice for end consumers)
- Merchant ToS must cover: subscription fees, platform fee disclosure (0.3% GMV), donation model, data processing, hardware lease terms (once active), acceptable use, suspension/termination rights
- Customer Privacy Policy must cover: what data is collected, how it is used, who it is shared with (Supabase/Stripe/Resend/Clicksend), how long it is retained, and how to exercise rights
- Get both reviewed by an Australian commercial lawyer familiar with SaaS — budget ~$1,500–3,000 AUD for initial drafting
- Once drafted, a dev task in `features-to-add.md` will wire them into the app (`/privacy`, `/terms` routes and acceptance gate at signup)

**Watch out for:**
- Australian Privacy Act 1988 + Australian Privacy Principles (APPs) apply once annual turnover exceeds $3M or if you handle health information — design as if you already comply
- If you have EU/UK customers, GDPR applies regardless of where GrowthHub is incorporated — include lawful basis for each processing activity

---

### 2.2 Merchant Agreement & Onboarding Acceptance
**Status:** `[ ]`

**What needs to happen:**
- The Merchant ToS (2.1 above) must include an explicit acceptance mechanic at signup — a dev task will add a checkbox + `tos_accepted_at` + `tos_version` to the DB
- The agreement must explicitly disclose:
  - The GrowthHub platform fee (0.15% of GMV to charity, 0.15% to GrowthHub)
  - The voluntary donation feature and how to opt out / adjust the rate
  - Subscription caps (SMS/email limits per tier)
  - Hardware lease terms if applicable
  - That GrowthHub can suspend the account for policy violations
- Version the document — when terms change, re-acceptance must be triggered (dev task handles the gate)

---

### 2.3 Australian Consumer Law & GST
**Status:** `[ ]`

**What needs to happen:**
- All prices shown to customers in the Shop/Storefront must be GST-inclusive — this is a legal requirement under Australian Consumer Law for B2C sales
- GrowthHub should provide guidance (in the Operations settings or a help article) reminding merchants of this obligation — it is the merchant's responsibility, not GrowthHub's, but GrowthHub facilitating non-compliant pricing creates reputational risk
- The POS receipt needs to show a GST breakdown (GST = total ÷ 11) and the merchant's ABN — this requires adding an `abn` field to organisations (dev task 3.7 in features-to-add.md)
- Register GrowthHub for GST if annual turnover exceeds or is expected to exceed $75,000 AUD

**Watch out for:**
- Subscription fees GrowthHub charges to merchants are also subject to GST — include GST in pricing or clearly state prices are ex-GST
- Hardware sales are also subject to GST

---

### 2.4 PCI DSS Compliance
**Status:** `[ ]`

**What needs to happen:**
- Confirm GrowthHub's scope: because all card data is handled by Stripe Elements (iframed) and Stripe Terminal (end-to-end encrypted), GrowthHub qualifies for **SAQ-A** (the simplest compliance tier — self-assessment only, no penetration testing required)
- Complete the annual **SAQ-A self-assessment questionnaire** — it takes ~2 hours and is free at pcisecuritystandards.org
- If Stripe Terminal is introduced, scope moves to **SAQ-B-IP** — still self-assessment but with more questions about network security
- Document the Stripe integration in the merchant-facing security page ("How we protect your customers' card data")
- Never log or store raw card numbers, CVCs, or expiry dates anywhere in logs, analytics, or error tracking

---

### 2.5 SMS / Email Marketing Compliance
**Status:** `[~]` Partially done

**What's already implemented:** opt-out tracking, unsubscribe page, webhook-based auto-opt-out on bounce.

**What still needs to happen operationally:**
- Every marketing SMS must contain the sender name and "Reply STOP to unsubscribe" — verify the Clicksend template includes this, and add it to the merchant-facing campaign guide
- Every marketing email must include the merchant's **physical business address** in the footer (required by Australian Spam Act 2003 and CAN-SPAM) — this requires merchants to enter their address in Operations (dev task), and the `email-send` edge function to inject it into email footers
- Create a help article / onboarding checklist that tells merchants: "You must only send to customers who have opted in — buying email lists or adding unverified contacts is a violation of our terms and may result in account suspension"
- Establish a process for handling spam complaints escalated by Clicksend/Resend to GrowthHub's account — complaints above a threshold (0.1% for email) need intervention

---

### 2.6 GDPR / Privacy Rights
**Status:** `[ ]`

**What needs to happen (operationally, before the dev tasks):**
- Appoint a point of contact for privacy requests (can be a founder email like `privacy@growerr.com`)
- Define a data retention policy: how long are orders kept? Customer profiles? Logs? The standard for financial records in AU is 7 years — document this formally
- Draft a process for handling Subject Access Requests (SARs): timeline (30 days under GDPR/Privacy Act), what gets included in the export, who approves deletions
- The dev task (data download + anonymise flow) implements the technical mechanism — this item covers the process and policy that wraps it

---

### 2.7 Age Verification (Alcohol / Restricted Items)
**Status:** `[ ]`

**What needs to happen:**
- GrowthHub's Merchant Terms must explicitly state that merchants selling age-restricted goods are responsible for compliance with their liquor licence conditions
- GrowthHub should not (and legally cannot) guarantee age verification beyond a self-declaration checkbox — make this limitation clear in the terms
- If a merchant is selling alcohol for delivery, they need a **liquor licence with a delivery endorsement** in their state — GrowthHub should require merchants to confirm this during onboarding for alcohol categories
- The dev task adds a product-level flag and a checkout self-declaration modal — this item is the legal wrapper around that feature

---

### 2.8 Business Insurance
**Status:** `[ ]`

**What needs to happen:**
- **Public liability insurance** — covers claims from merchants or customers arising from GrowthHub's platform (e.g. a bug causes an order to be incorrectly processed)
- **Professional indemnity insurance** — covers claims from merchants for financial loss arising from platform errors, missed orders, data issues
- **Cyber liability insurance** — covers data breach notification costs, regulatory fines, incident response (especially relevant given customer PII and payment data)
- Get quotes from: Aon, BizCover, or Elders Insurance (all offer tech/SaaS specific policies in AU)
- Budget estimate: ~$3,000–6,000 AUD/year for a startup-stage policy combining all three

---

### 2.9 Company Structure & Co-Founder Agreement
**Status:** `[~]` In progress

- Co-founders agreement drafted and available at `docs/legal/founders-agreement.md`
- Ensure agreement covers: IP assignment (all code built by founders or contractors belongs to the company), vesting schedule, decision-making authority, what happens if a founder leaves
- Register the company as a Pty Ltd if not already done — required before accepting merchant payments, hiring, or raising investment
- Open a business bank account separate from personal accounts before any merchant revenue flows

---

## 3. Operations & Growth

### 3.1 Merchant Onboarding Process
**Status:** `[ ]`

**What needs to happen:**
- Define the onboarding journey: signup → ToS acceptance → business type selection → first product added → first order received
- Build a welcome email sequence (3–5 emails over 2 weeks) triggered by signup — covers: setting up the menu, enabling loyalty, running a first campaign, setting up the kitchen display
- Create a help centre (Notion or GitBook) with articles for each core feature — this reduces support load significantly
- Hardware kit: define the pre-configuration checklist so any team member can set up a device before shipping

---

### 3.2 Support Infrastructure
**Status:** `[ ]`

**What needs to happen:**
- Set up a support email (`support@growerr.com`) with a ticketing system — Intercom, Freshdesk, or even a well-managed Gmail at early stage
- Define SLAs: critical issues (orders not processing, payment failures) → 2 hour response; general queries → 24 hours
- The Feedback page (now built in the dashboard) feeds into GrowthHub's internal backlog — establish a triage process for acting on it
- Build a status page (statuspage.io or a simple hosted page) — proactively communicating downtime builds merchant trust

---

### 3.3 Supplier & Partnership Agreements
**Status:** `[ ]`

**Agreements needed before going live:**
- **Stripe** — standard merchant agreement (already exists through Stripe account), but ensure `stripe.com/au` terms cover your use case for marketplace payments and Terminal
- **Clicksend** — review their terms on sender ID provisioning, bulk pricing, and what happens when you exceed volume
- **Resend** — review domain verification requirements and sending limits per account vs per domain
- **Supabase** — review data residency options; by default Supabase may host in us-east-1 — for Australian customer data, consider requesting an AU region project
- **Hardware suppliers** — get written quotes and bulk pricing agreements before committing to merchant hardware offers

---
