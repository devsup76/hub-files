# Woahh — Additional Legal Obligations: Retail/Grocery & Events Expansion

> Covers obligations **beyond** what is already documented in `legalities.md`.
> Read this alongside that document, not instead of it.
>
> Last updated: 2026-04-29

---

## Payment Flow Confirmation

Before diving into verticals, the user has confirmed: **money flows directly from customer to merchant/organiser via their own Stripe account. Woahh never holds or touches transaction funds.** This is the correct structure and eliminates the largest class of additional obligations (AFSL, AUSTRAC, trust accounting). All analysis below assumes this model holds.

Woahh charges a separate platform/booking fee — that fee is Woahh's revenue, subject to GST, and is the only money Woahh ever receives.

---

## Part A — Grocery & Retail Expansion

### A.1 Country of Origin Labelling

The *Competition and Consumer (Country of Origin Representations) Code 2017* under the ACL requires mandatory country of origin labelling on most food sold at retail in Australia. This applies to:
- Fresh food (fruit, vegetables, meat, seafood, dairy)
- Processed food with Australian content claims

**Who is responsible:** The merchant (grocery/retailer) is legally responsible for labelling compliance. However, if Woahh's platform displays product listings without country of origin information and this results in a customer being misled, Woahh could be exposed to ACL s18 (misleading conduct) liability.

**What Woahh must do:**
- Merchant Terms must require grocery merchants to include accurate country of origin information in all product listings
- The product listing interface should include a country of origin field (not mandatory to enforce but strongly recommended)
- Do not pre-populate or suggest country of origin — leave it entirely to the merchant

### A.2 Allergen Labelling and Disclosure

The *Australia New Zealand Food Standards Code* (Standard 1.2.3) mandates that packaged food disclose the presence of the 14 major allergens: gluten, crustacea, eggs, fish, milk, tree nuts, peanuts, sesame seeds, soybeans, lupin, molluscs, bee products, and royal jelly.

**Who is responsible:** The merchant/food producer is legally responsible.

**What Woahh must do:**
- Merchant Terms must require accurate allergen disclosure in product listings
- The product listing interface should include an allergen field
- Add a platform-level disclaimer on the storefront: "Allergen information is provided by the merchant. Contact the merchant directly to verify allergen information before purchasing."
- Do not allow merchants to claim "allergen-free" or "nut-free" without verification processes the merchant controls

**Why this matters for Woahh:** If a customer has an allergic reaction and Woahh's platform displayed inaccurate allergen information provided by the merchant, Woahh could face a claim. A platform-level disclaimer and a requirement in the Merchant Terms shifts that liability clearly to the merchant.

### A.3 Unit Pricing

The *Trade Practices (Industry Codes — Unit Pricing) Code 2009* requires certain retailers to display unit pricing (price per 100g, per litre, etc.) so customers can compare value. This applies to:
- Supermarkets and grocery retailers with a floor area over 1,000m²

Most small independent grocers on Woahh will be below the threshold. However, if a larger grocery chain signs up, they may have unit pricing obligations. Woahh's Merchant Terms should require merchants to comply with all applicable pricing display laws.

### A.4 Consumer Guarantees on Goods (Different From Services)

The *Australian Consumer Law* treats goods and services differently. For goods purchased through Woahh's platform (groceries, retail products):

**Automatic consumer guarantees for goods include:**
- Acceptable quality (safe, durable, free from defects, acceptable in appearance)
- Fit for any disclosed purpose
- Matching description
- Matching sample or demonstration model
- Repairs and spare parts available (less relevant for grocery)
- Title passes to the buyer

**Perishable goods are not exempt** from consumer guarantees — a customer who receives rotten produce has a valid claim against the merchant.

**Woahh's platform must:**
- Not display product images or descriptions that are materially different from what the merchant actually supplies (contributing to "not matching description")
- Merchant Terms must prohibit misleading product listings
- Have a clear process for customers to report and resolve goods that do not meet consumer guarantees

### A.5 Substitution Policy (Click and Collect / Delivery)

When a grocery item is out of stock and a merchant substitutes it, this can be a consumer law issue if the customer did not consent. The customer paid for item A and received item B — this is arguably a breach of the "matching description" guarantee.

**Woahh must ensure:**
- The checkout flow or order confirmation clearly states the merchant's substitution policy before payment
- Customers have the option to decline substitutions
- Merchant Terms require merchants to display their substitution policy

### A.6 Food Safety During Delivery

When grocery or food products are delivered, the merchant is responsible for maintaining food safety (temperature control for perishables, proper packaging). The *Food Standards Code* Standard 3.2.2 covers food safety practices including temperature control during delivery.

If Woahh's delivery integration (Uber Direct, etc.) is used for grocery/perishable delivery:
- Merchant Terms must require merchants to comply with food safety laws during delivery
- Woahh should disclaim liability for food safety failures that occur during the delivery leg
- The platform cannot be used to deliver items that are temperature-sensitive without the merchant having appropriate packaging and logistics in place

### A.7 Age-Restricted Goods (Alcohol, Tobacco, Vaping Products, Certain Medications)

This is one of the highest-risk areas for a grocery expansion. The following goods are age-restricted in Australia and have specific online/delivery rules:

**Alcohol:**
- Each state has different liquor licensing laws for online sales and delivery
- NSW: Liquor Act 2007 — online alcohol sales require a packaged liquor licence; delivery requires specific delivery conditions
- VIC: Liquor Control Reform Act 1998 — similar requirements; direct-to-consumer delivery requires liquor licence conditions
- QLD: Liquor Act 1992 — retail liquor licence required; delivery restrictions apply
- Age verification is required at point of delivery (not just at checkout)
- Woahh's checkout must include an age confirmation step for alcohol orders
- The delivery driver (via Uber Direct or equivalent) must also verify age at the door — Woahh's Merchant Terms must require merchants to communicate this to their delivery provider

**Tobacco and Vaping:**
- Sale of tobacco and vaping products to under-18s is prohibited Australia-wide
- Online sales of tobacco vary by state — some states restrict or prohibit tobacco delivery entirely
- Vaping products (nicotine): heavily restricted; nicotine vaping products require a prescription under the *Therapeutic Goods Act 1989* for consumer purchase (as of current law)
- **Recommendation:** Do not permit nicotine vaping product sales through Woahh without specific legal advice — the regulatory landscape is rapidly changing and exposure is high

**Medications and Therapeutic Goods:**
- Prescription medications cannot be sold online without AHPRA-registered pharmacy compliance
- Schedule 2 and 3 (pharmacist-only) medicines have specific dispensing rules
- **Recommendation:** Prohibit pharmacy-only or prescription items from Woahh product listings unless the merchant is a registered pharmacy operating compliantly

**What Woahh must do:**
- Add an age verification checkbox at checkout for any order containing age-restricted items (minimum: "I confirm I am 18 years of age or older")
- Merchant Terms must require merchants selling age-restricted goods to hold all applicable licences
- Merchant Terms must prohibit listing nicotine vaping products and prescription medications unless the merchant is licensed to sell them
- Add a prohibited/restricted products list to the Acceptable Use Policy

### A.8 Weights and Measures

The *National Measurement Act 1960* and state trade measurement laws require that goods sold by weight or volume are accurately measured and the measurement is disclosed. This applies to:
- Meat sold per kilogram
- Deli items
- Bulk produce

**What Woahh must do:**
- Product listings that include weight/volume must reflect accurate measurements
- Merchant Terms must require compliance with trade measurement laws
- Woahh should not auto-calculate prices by weight — leave this to the merchant's system to ensure accuracy

---

## Part B — Event Booking Platform Expansion

This is the most legally complex expansion. Events involve time-bound services, significant sums paid in advance, and a raft of state-based laws that do not exist in the food/retail context.

### B.1 Consumer Guarantees for Events (ACL — Critical)

A ticket to an event is the purchase of a **service**. Under the ACL, that service must be:
- Provided with due care and skill
- Fit for the purpose
- Delivered within a reasonable time
- As described

**If an event is cancelled:** The consumer is entitled to a **full refund** of the ticket price. This is a statutory right — no terms and conditions can override it. The refund obligation falls on the event organiser (who received the money directly). However, Woahh's platform fee may also be refundable if the service (booking facilitation) was not ultimately delivered in a meaningful way.

**If an event is postponed:** Consumer rights are less clear, but:
- If the new date is not reasonably acceptable to the customer, they likely have a refund right
- ACCC guidance from COVID-era event cancellations is instructive: a postponement does not automatically extinguish refund rights

**What Woahh must do:**
- Event organiser Terms must require organisers to have a clear, ACL-compliant cancellation and refund policy
- This policy must be displayed to customers before ticket purchase (not buried in fine print)
- Woahh's platform must display the organiser's refund policy on the event listing page
- Woahh's own platform fee policy on cancellation must be stated (does Woahh refund its fee if an event is cancelled? Recommended: yes — the failure is the organiser's, not the customer's)

### B.2 Ticket Scalping Laws (State by State)

Australia has some of the most aggressive anti-scalping laws in the world. These laws restrict reselling tickets above face value for certain events:

| State | Law | Key Restriction |
|---|---|---|
| NSW | Major Events Act 2009; Ticket Scalping Act 2012 | Prohibits resale above 10% above face value for declared major events; applies to tickets for events at venues over 5,000 cap |
| QLD | Fair Trading (Ticket Scalping) Amendment Act 2014; Major Sports Facilities Act | Resale restricted for events at major facilities |
| VIC | Major Sporting Events Act 2009; Major Events Act 2009 | Declared major events — resale capped, harvesting tools prohibited |
| SA | Prices Act 1948 | Scalping offence for declared events |
| WA, TAS, ACT, NT | Less prescriptive, general fair trading laws apply | General ACL protections |

**Woahh's obligations:**
- The platform must not facilitate resale above face value for events that fall under these laws
- Acceptable Use Policy must explicitly prohibit scalping through the platform
- If Woahh adds any secondary market/resale functionality in future, it must be geofenced and price-capped to comply with each state's rules
- Consider whether the platform itself needs to register as a "ticket seller" under any state legislation — this depends on how Woahh facilitates the sale

### B.3 Holding Advance Ticket Proceeds (Trust/Float Risk)

The user confirmed money goes directly from customer to organiser. This is the correct approach and eliminates most exposure. However, confirm that Stripe's payment flow in the event context does not create any holding period where Woahh intermediates funds even temporarily (e.g., Stripe Connect holds in a platform account before sweeping to the organiser). If it does, trust accounting or AFSL issues arise.

**Do not add:**
- A "Woahh holds your ticket funds until the event" model — this is trust accounting territory
- Any float, escrow, or holding structure for event proceeds without legal advice and potentially AFSL authorisation

### B.4 Ticket Insurance (Do Not Offer Without AFSL)

Ticketek and Humanitix offer "ticket protection" or "event cancellation insurance." **Do not offer this without an Australian Financial Services Licence.** Insurance products — including event cancellation insurance — are regulated financial products under the *Corporations Act 2001* and require an AFSL to sell or arrange. Offering ticket insurance without an AFSL is a criminal offence.

If Woahh wants to offer this in future: partner with a licensed insurer who holds the AFSL and refer customers to them rather than selling directly through the platform.

### B.5 Event Organiser Public Liability Insurance

Event organisers are responsible for public liability at their events. A patron injured at a venue can sue the organiser. Woahh is not the organiser, but:

**Woahh's Merchant Terms must require event organisers to:**
- Hold adequate public liability insurance (minimum $10M is industry standard for public events)
- Hold all applicable venue, council, and government permits for their event
- Comply with venue capacity limits (relevant to fire safety and licensing laws)
- Obtain responsible service of alcohol authorisation if alcohol is sold at the event

Woahh should consider requiring organisers to provide evidence of public liability insurance before their event listing goes live.

### B.6 Working With Children Requirements

For events that involve children as participants or that are primarily attended by children (school holiday shows, children's entertainment, etc.):
- Event staff must hold a valid Working With Children Check (WWCC) or equivalent in their state
- This is a mandatory legal requirement, not a best practice

**Woahh's obligations:** Merchant Terms must require event organisers to comply with all applicable WWCC laws. Woahh does not need to verify checks itself, but must not knowingly facilitate an event that is obviously non-compliant.

### B.7 Cooling-Off Periods for Event Tickets

Unlike some consumer contracts, there is **no automatic cooling-off period** for event tickets in Australia. Once purchased, the ticket is generally non-refundable unless:
- The event is cancelled or significantly altered (ACL consumer guarantees)
- The organiser's stated refund policy allows it
- The ticket was purchased via unsolicited selling (rare for online ticketing)

This is the industry norm and is consistent with Ticketek and Humanitix's models. Woahh must display the "no general cooling-off" position clearly before purchase alongside the organiser's specific policy.

### B.8 Misleading Event Descriptions (ACL s18)

Event listings that misrepresent the event expose both the organiser and Woahh to ACL s18 liability. Specific risks:

- "Special guest" or "headline act" that cancels and is not replaced — potentially misleading if customers can show the act was material to their purchase
- Venue details that are wrong (wrong suburb, capacity misrepresented)
- Ticket category misrepresentation (sold as "front row" but not front row)
- Event date errors

**What Woahh must do:**
- Organiser Terms must prohibit misleading event descriptions and make the organiser responsible for all listing accuracy
- Woahh should have a flagging/complaints mechanism for event listing errors
- Woahh's platform should not algorithmically generate or auto-fill any event descriptions — leave all content to the organiser

### B.9 Charitable and Not-For-Profit Events

Many events are fundraisers (charity galas, community events, school fundraisers). If Woahh facilitates ticket sales for a charitable fundraising event, state-based fundraising laws come back into play (as discussed in `legalities.md` Section 7).

**Key issue:** If Woahh's platform is used to sell tickets where proceeds go to a charity, Woahh may be considered a "fundraising platform." This potentially requires Woahh to be registered as a fundraiser in each applicable state — or at minimum, the event organiser must hold the appropriate state fundraising authority.

**Woahh's Terms must:** require event organisers running charity events to hold all applicable state fundraising registrations and authorities before using the platform.

### B.10 State Entertainment and Public Event Permits

Large public events often require permits from local councils or state governments. These vary significantly:
- Council approval for outdoor events using public space
- Police notification for events over certain attendance thresholds (varies by state)
- Noise permits
- Food safety permits for events serving food
- Traffic management plans for large events

None of these are Woahh's responsibility — they fall on the event organiser. However, Merchant Terms must make clear that the organiser is responsible for all such permits, and Woahh reserves the right to remove listings for events that lack required approvals.

---

## Part C — Shared Additional Obligations (Both Verticals)

### C.1 Product and Event Liability Chain

For both groceries and events, the liability chain when something goes wrong is:

```
Customer → Merchant/Organiser (primary liability)
         → Woahh (secondary, if platform contributed to the harm or misrepresentation)
```

Woahh minimises its position in this chain by:
1. Not touching money (already done)
2. Merchant Terms that require compliance and assign responsibility to the merchant
3. Platform-level disclaimers (allergen info provided by merchant, event details provided by organiser, etc.)
4. Not generating, editing, or endorsing any product or event content

### C.2 Expanded Acceptable Use Policy

The current Acceptable Use Policy covers spam and illegal activity. For the new verticals it must be expanded to prohibit:
- Listing of prescription medications, nicotine vaping products, or other regulated therapeutic goods (unless licensed)
- Alcohol listings without a valid liquor licence
- Tobacco listings in states that restrict online tobacco sales
- Ticket resale above face value for events covered by state anti-scalping laws
- Charity event listings without applicable state fundraising registrations
- Event listings that misrepresent headline acts, venue, date, or ticket category
- Food listings without required allergen and country of origin information

### C.3 Expanded Privacy Obligations

**Grocery:** Customer order history includes food preferences, dietary restrictions, and potentially health-related information (e.g., gluten-free, diabetic-appropriate items). This may constitute **sensitive health information** under the Privacy Act, which has a higher protection standard than ordinary personal information. Collection, use, and storage of dietary preference data must be explicitly addressed in the Privacy Policy.

**Events:** Event attendees may include information about religious observances (e.g., a church event), political activity (fundraiser for a candidate), or sexual orientation (Pride events). This is **sensitive information** under the Privacy Act. Woahh's role is to process this data on behalf of the organiser — the DPA framework already covers this, but the Privacy Policy must acknowledge that event-related sensitive information may be processed.

### C.4 Accessibility for Event Listings

Beyond general WCAG 2.1 AA compliance (already in `legalities.md`), event booking has a specific accessibility dimension:
- Events must disclose whether the venue is wheelchair accessible, has hearing loops, provides auslan interpreters, etc.
- Failure to disclose accessibility features can constitute disability discrimination under the *Disability Discrimination Act 1992*
- The event listing interface should include an accessibility features field
- Merchant Terms should require accurate disclosure of venue accessibility

### C.5 GST on Event Tickets and Booking Fees

- Event tickets sold by a GST-registered organiser include 10% GST — the organiser accounts for this
- Woahh's booking/platform fee is also subject to 10% GST — Woahh accounts for this
- If an event is for a registered charity and qualifies as a "fund-raising event" under ATO rules, the ticket sale may be GST-free — this is complex and the organiser should get their own tax advice
- Refunds: when a ticket is refunded, both the organiser and Woahh must issue a tax adjustment note (the GST equivalent of a credit note) — the platform must support this

### C.6 Dispute Resolution and Chargebacks

Both verticals generate a significantly higher volume of disputes than restaurant orders:
- Grocery: substitutions, missing items, damaged goods, perishables
- Events: cancelled events, misrepresented events, double-charged tickets

Since money goes directly to the merchant/organiser via their own Stripe account, chargebacks hit the merchant/organiser directly. However, Woahh's Merchant Terms must:
- Require merchants to respond to and resolve legitimate customer complaints within a defined timeframe (e.g., 5 business days)
- Give Woahh the right to suspend a merchant's listing if they have a pattern of unresolved disputes
- Require event organisers to process ACL-mandated refunds within a defined timeframe after cancellation

---

## Part D — What the "Money Goes Direct" Model Means Legally

This decision eliminates the most burdensome obligations but creates one responsibility gap worth documenting:

**What is eliminated:**
- AFSL obligations (Woahh is not providing a financial service)
- AUSTRAC obligations (Woahh is not handling payment flows)
- Trust accounting (Woahh never holds funds)
- Chargeback and dispute liability (the merchant's Stripe account bears this)
- Refund intermediation obligations

**The one gap — Organiser insolvency / merchant refusal to refund:**
When an event organiser cancels an event and refuses or is unable to refund tickets (e.g., they've already spent the money and go insolvent), the customer's recourse is against the organiser — not Woahh. Woahh is not legally obligated to cover these refunds. However:
- The customer will associate the loss with Woahh's platform
- ACCC has historically pressured platforms to step in for consumers even when not legally required
- Consider whether Woahh wants a voluntary "buyer protection" policy for events (funded by a small event risk fee) — this is a commercial decision, not a legal one

**Woahh's booking/platform fee:**
If an event is cancelled and Woahh refunds its own platform fee (recommended), this is straightforward. If Woahh does not refund it, there is a credible ACL consumer guarantee argument that the booking service was not ultimately provided. **Recommend: refund the platform fee on any event cancellation.**

---

## Summary — Net New Obligations by Vertical

### Grocery/Retail (beyond what's in legalities.md)

| Obligation | Who it falls on | Woahh's role |
|---|---|---|
| Country of origin labelling | Merchant | Require in Terms; provide listing field |
| Allergen disclosure | Merchant | Require in Terms; add storefront disclaimer |
| Unit pricing | Merchant (large stores only) | Require in Terms |
| Consumer guarantees on goods | Merchant | Support via dispute process |
| Substitution policy disclosure | Merchant | Surface in checkout flow |
| Food safety during delivery | Merchant | Require in Terms |
| Age verification for alcohol/tobacco | Merchant (primary) + Woahh (checkout) | Add checkout age confirmation step |
| Prohibition on regulated goods | Merchant | Add to Acceptable Use Policy |
| Weights and measures accuracy | Merchant | Require in Terms |
| Sensitive dietary data (Privacy Act) | Woahh as processor | Update Privacy Policy |

### Events (beyond what's in legalities.md)

| Obligation | Who it falls on | Woahh's role |
|---|---|---|
| ACL cancellation refund rights | Organiser (primary) | Display policy pre-purchase; refund platform fee on cancellation |
| Anti-scalping compliance | Organiser + Woahh (platform) | Prohibit in AUP; no secondary market without price cap |
| No ticket insurance without AFSL | Woahh | Do not offer — refer to licensed insurer only |
| Public liability insurance | Organiser | Require in Terms; consider requiring evidence before listing |
| Working With Children compliance | Organiser | Require in Terms for applicable events |
| State event/entertainment permits | Organiser | Require in Terms; right to remove non-compliant listings |
| Misleading event descriptions | Organiser (primary) + Woahh | Do not auto-generate content; complaints mechanism required |
| Charity event fundraising registrations | Organiser | Require in Terms |
| Accessible venue disclosure | Organiser | Add listing field; require accurate disclosure |
| GST adjustments on refunds | Woahh (for its fee) + Organiser | Support tax adjustment notes in platform |
| Sensitive event attendance data (Privacy Act) | Woahh as processor | Update Privacy Policy |
| Organiser insolvency risk | Organiser (customer's recourse) | Consider voluntary platform fee refund policy |

---

*This document was prepared on 26 April 2026. Legal requirements in the events and grocery sectors evolve frequently — the anti-scalping laws in particular have been amended multiple times in recent years. Review annually and whenever a new state is entered as a primary market.*
