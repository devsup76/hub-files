# Woahh — Australian Legal Compliance Checklist

> Covers everything required before launch and on an ongoing basis. Organised by law/obligation area.
>
> **This is not legal advice** — have an Australian commercial lawyer review your specific documents before launch.
>
> Last updated: 2026-04-29

---

## Table of Contents

1. [Business Formation](#1-business-formation)
2. [Tax Registration](#2-tax-registration)
3. [Intellectual Property](#3-intellectual-property)
4. [Insurance](#4-insurance)
5. [Privacy Act 1988](#5-privacy-act-1988-cth)
6. [Spam Act 2003](#6-spam-act-2003-cth)
7. [Australian Consumer Law](#7-australian-consumer-law-acl)
8. [Electronic Transactions](#8-electronic-transactions)
9. [Financial Services Law](#9-financial-services-law)
10. [Charitable Giving Compliance](#10-charitable-giving-compliance)
11. [Online Marketplace Obligations](#11-online-marketplace-obligations)
12. [Data Security](#12-data-security)
13. [Employment Law](#13-employment-law)
14. [Accessibility](#14-accessibility)
15. [Legal Documents Checklist](#15-legal-documents-checklist)
16. [Ongoing Compliance Calendar](#16-ongoing-compliance-calendar)
17. [Phase-Specific Flags](#17-phase-specific-flags)
18. [Critical Path Before First Paying Customer](#18-critical-path-before-first-paying-customer)

---

## 1. Business Formation

### 1.1 Company Registration (ASIC)

**What:** Incorporate as a Proprietary Limited company (Pty Ltd) under the *Corporations Act 2001 (Cth)*.

**Requirements:**
- At least one director who ordinarily resides in Australia
- A registered office in Australia (can be your accountant or lawyer's office)
- ASIC registration fee (~$576 for 1 year, or $1,373 for 3 years as of 2025)
- You will receive an **ACN (Australian Company Number)** — 9-digit unique identifier

**ABN:** Register for an **Australian Business Number** via the ATO (free, via ABR portal). Required for tax invoices, GST, and most business dealings.

**Business Name:** If trading as "Woahh" and it differs from the registered company name, you must register the business name with ASIC (~$42/year). Check availability first at ASIC's business name register.

**Action items:**
- [ ] Incorporate Pty Ltd via ASIC Connect or a company registration service
- [ ] Register ABN via abn.business.gov.au
- [ ] Register business name "Woahh" with ASIC
- [ ] Register `woahh.com.au` via a registrar (requires ABN/ACN — auDA policy)

---

## 2. Tax Registration

### 2.1 GST (Goods and Services Tax)

- 10% GST applies to all subscription fees (Solo $49, Marketplace $99, Growth $199)
- Must register for GST if annual turnover is expected to exceed **$75,000** — realistic even at 100 merchants ($9,500/month = $114k/year)
- Register at the same time as ABN registration (tick the GST box)
- Lodge **Business Activity Statements (BAS)** quarterly (or monthly if preferred) reporting GST collected and paid

**GST on subscriptions — important nuance:**
- Subscriptions to Australian businesses: standard 10% GST applies
- If you have overseas merchants in future: "B2B" supplies to GST-registered overseas entities may be GST-free under the exported services rules

### 2.2 PAYG Withholding

Register once you hire employees. Required to withhold tax from employee wages and remit to the ATO on a quarterly or monthly schedule.

### 2.3 Payroll Tax

State-based. Only applies once your payroll exceeds state thresholds (e.g., $1.2M/year in NSW, $700k/year in VIC). Not an immediate concern for a small team but know which state you're operating from — thresholds vary significantly between states.

### 2.4 Records Retention

Under the *Tax Administration Act 1953*, business and GST records must be kept for a minimum of **5 years**.

**Action items:**
- [ ] Register for GST (tick box during ABN registration)
- [ ] Set up BAS lodgment schedule (quarterly recommended at launch)
- [ ] Register for PAYG Withholding when first employee is hired
- [ ] Confirm which state your payroll obligations fall under
- [ ] Set up a 5-year document retention policy from day one

---

## 3. Intellectual Property

### 3.1 Trade Mark Registration (IP Australia)

Register "Woahh" as a trade mark in at least:
- **Class 35:** Advertising, business management, SaaS
- **Class 42:** Technology/software services, web hosting
- **Class 38:** Telecommunications services (relevant to SMS features)

Cost: ~$250 per class per application. The process takes 7–13 months but protection is backdated to the filing date. Search for conflicts first at trademarks.ipaustralia.gov.au. Also consider registering the logo as a device mark separately.

### 3.2 Domain Names

- `.com.au` requires a matching registered business name, company name, or trade mark — register ABN/company first
- Register `.com`, `.com.au`, `.app`, and `.io` defensively
- Register common misspellings (e.g., woahh, growth-hub)

### 3.3 Copyright

Automatically applies to code, content, and design under the *Copyright Act 1968* — no registration needed in Australia. However, ensure all employment and contractor agreements include an **IP assignment clause** so Woahh owns all code written by team members and contractors.

**Action items:**
- [ ] File trade mark application for "Woahh" (Classes 35, 42, 38) at IP Australia
- [ ] Register woahh.com.au, .com, and defensive variants
- [ ] Add IP assignment clauses to all employment and contractor agreements
- [ ] Check existing code contributions by contractors for IP ownership gaps

---

## 4. Insurance

Not legally required in most cases but strongly recommended before taking on paying customers:

| Insurance type | Why you need it |
|---|---|
| **Professional Indemnity** | If Woahh causes a merchant financial loss (e.g., order system outage, missed reservations) — covers legal costs and damages |
| **Cyber Liability** | Data breach coverage — covers notification costs, forensics, customer claims, regulatory defence |
| **Public Liability** | If someone is harmed in connection with the business (standard even for pure SaaS) |
| **Directors & Officers (D&O)** | Protects directors personally from claims arising from management decisions |
| **Business Interruption** | If infrastructure (Supabase, Resend, Clicksend) fails and you cannot operate |

**Action items:**
- [ ] Get quotes from BizCover, Aon, or a specialist tech insurer before accepting the first paying merchant

---

## 5. Privacy Act 1988 (Cth)

### 5.1 Applicability

The Act applies to entities with annual turnover exceeding **$3 million**, OR that trade in personal information, OR that handle sensitive information. Woahh stores customer data (names, emails, order histories, dietary preferences, addresses, birthdays, loyalty balances) on behalf of thousands of merchants, and trades in personal information as part of its core CRM offering. **Treat this as applicable from day one regardless of revenue.**

### 5.2 Woahh's Dual Role

Woahh operates in two roles simultaneously:
- **Data Controller** — for its own data (merchant email, payment info, usage data)
- **Data Processor** — on behalf of merchants for their customers' data (end-customer names, emails, orders, preferences, birthdays)

This dual role requires separate legal instruments covering both sides.

### 5.3 The 13 Australian Privacy Principles (APPs)

| APP | Obligation | What this means for Woahh |
|---|---|---|
| APP 1 | Open and transparent management | Publish a clear, accessible Privacy Policy — update it whenever practices change |
| APP 2 | Anonymity/pseudonymity | Where practicable, let users interact without identifying themselves — the public `/eat` marketplace already does this |
| APP 3 | Collection of solicited info | Only collect what is reasonably necessary — the birthday field, dietary prefs, and saved addresses all need justification in the Privacy Policy |
| APP 4 | Unsolicited information | If personal info is received that was not requested, either destroy it or treat it as collected under APP 3 |
| APP 5 | Notification of collection | At the point of collection, tell people: who you are, what you're collecting, why, who you'll disclose to, and how they can access or correct it. This **collection notice** is required on every sign-up form, checkout, and account creation flow |
| APP 6 | Use and disclosure | Cannot use data beyond the purpose for which it was collected without consent. Merchant customer data cannot be used by Woahh for its own marketing |
| APP 7 | Direct marketing | Individuals must be able to easily opt out of direct marketing. Merchant customers must be able to opt out of both merchant marketing and any Woahh platform communications |
| APP 8 | Cross-border disclosure | **Critical.** Supabase (US), Resend (US), Clicksend (AU but US infrastructure), Stripe (US), Uber Direct — all overseas recipients. Must either take reasonable steps to ensure they uphold Australian privacy standards (via DPAs) or get explicit consent |
| APP 9 | Government identifiers | Do not use TFN, Medicare, or driver licence numbers as system identifiers |
| APP 10 | Data quality | Maintain accuracy of personal information — provide mechanisms for customers to update their records |
| APP 11 | Security | Protect personal information from misuse, loss, and unauthorised access — Supabase RLS, encryption at rest, access controls, and employee access restrictions are all required |
| APP 12 | Access | Individuals can request access to their personal information — must respond within **30 days** |
| APP 13 | Correction | Must correct inaccurate or out-of-date information on request |

### 5.4 Notifiable Data Breaches (NDB) Scheme

If Woahh has an eligible data breach (unauthorised access to personal information that is likely to cause serious harm to individuals):
1. Notify the **OAIC (Office of the Australian Information Commissioner)** as soon as practicable
2. Notify **affected individuals**
3. A 30-day assessment window applies from the time you become aware of a suspected breach
4. Penalties for failure to notify: up to **$50 million** (corporate) under the 2022 amendments

A written **Data Breach Response Plan** must exist before Woahh takes any customer data.

### 5.5 Privacy Act Reforms — 2024 Amendments

The *Privacy and Other Legislation Amendment Act 2024* introduced:
- Statutory tort for serious invasions of privacy — individuals can now sue Woahh directly
- Enhanced transparency requirements
- New children's privacy protections
- Stronger direct marketing opt-out obligations
- Data protection impact assessments (DPIAs) for high-risk processing activities

Review current OAIC guidance on the amendments before launch.

### 5.6 Cross-Border Data Flows (APP 8)

All third-party services that touch personal data are overseas and each requires a Data Processing Agreement (DPA):

| Service | Data it handles | DPA required |
|---|---|---|
| Supabase (US) | All customer, merchant, and order data | Yes |
| Resend (US) | Customer email addresses and email content | Yes |
| Clicksend (AU/US) | Customer phone numbers and SMS content | Yes |
| Stripe (US) | Merchant billing information | Yes |
| Uber Direct (US) | Customer delivery addresses, order data | Yes |

**Action items:**
- [ ] Draft and publish a **Privacy Policy** covering all 13 APPs — publicly accessible before launch
- [ ] Draft separate **Collection Notices** for: merchant sign-up, customer checkout, customer account creation, and `/eat` marketplace browsing
- [ ] Execute **DPAs** with Supabase, Resend, Clicksend, Stripe, and Uber Direct
- [ ] Draft a **Merchant DPA** — merchants (as data controllers) must have a DPA with Woahh (as data processor) for their customers' data. Embed this in the Merchant Terms of Service
- [ ] Write a **Data Breach Response Plan** covering: detection, assessment, containment, OAIC notification, individual notification, and post-incident review
- [ ] Build a **Data Subject Request process** — access and correction requests must be responded to within 30 days
- [ ] Document a **data retention policy** — how long customer data is kept after a merchant churns or closes their account
- [ ] Conduct a **Data Protection Impact Assessment (DPIA)** for the CRM, loyalty, and SMS/email campaign features
- [ ] Add a **Sub-processor List** as an appendix to the Privacy Policy

---

## 6. Spam Act 2003 (Cth)

This is one of the highest-risk areas for Woahh. The core product includes tools to send commercial messages to end-customers at scale on behalf of merchants.

### 6.1 Scope

Applies to **commercial electronic messages** sent to Australian accounts, including:
- Email
- SMS and MMS
- Instant messaging

Does **not** apply to voice calls (those are governed by the *Do Not Call Register Act 2006*). Push notifications fall into a grey area — treat them as covered if the content is commercial.

**Critical distinction:** Transactional messages (order confirmations, delivery notifications, reservation confirmations) are **not** commercial messages and are not subject to the consent requirement. Marketing messages (promotional campaigns, "we miss you" reactivation, loyalty point reminders) are commercial messages and require consent.

### 6.2 The Three Mandatory Requirements

Every commercial message sent through Woahh's infrastructure must satisfy all three:

**1. Consent**

Either:
- **Express consent:** The recipient explicitly agreed to receive commercial messages from this sender (e.g., checked "Yes, I'd like marketing emails from Bella's Bistro" at checkout)
- **Inferred consent:** Based on an existing business relationship (e.g., a customer who placed an order within the last 6 months) OR conspicuous publication of an electronic address

The consent record must be kept — who consented, when, and how. Woahh's platform must facilitate consent collection and storage.

**2. Identification**

Every commercial message must clearly identify the sender. For merchant campaigns, the merchant's trading name and contact details must appear in the message — not Woahh's identity. Woahh's infrastructure sends on behalf of the merchant; the merchant's name must be visible to the recipient.

**3. Unsubscribe Mechanism**

- Every commercial message must contain a **functional unsubscribe mechanism**
- The mechanism must remain functional for **at least 30 days** after the message is sent
- Opt-out requests must be **actioned within 5 working days** (ideally instantly via webhook)
- Cannot charge for unsubscribing
- Cannot require the person to log in to unsubscribe
- Cannot ask for more than an email address or phone number to process the opt-out

The existing `email-webhook` and `sms-webhook` edge functions and the `/unsubscribe/:token` page address this. Verify that:
1. The token-based unsubscribe does not require login
2. Opt-out is processed automatically and immediately via webhook
3. The unsubscribe link appears in **every** campaign email without exception
4. SMS campaigns include "Reply STOP to unsubscribe" in the message body

### 6.3 Woahh's Liability as a Platform

The Spam Act creates liability for **facilitators** as well as senders. Woahh can be held liable if it:
- Provides address lists to merchants who use them to spam
- Sends or authorises the sending of spam on behalf of merchants
- Is involved in address harvesting

Platform-level obligations:
- Merchant Terms of Service must **expressly prohibit** sending spam through Woahh
- A confirmation step in the campaign send flow requiring merchants to confirm recipient consent (a checkbox is the minimum — stored records are better)
- A complaints and abuse reporting mechanism for customers who receive spam via Woahh-powered campaigns

### 6.4 ACMA Enforcement

The Australian Communications and Media Authority (ACMA) enforces the Spam Act. Penalties for a body corporate:
- Up to **$2.86 million per day** for repeated or serious contraventions
- Individual infringement notices per breach
- ACMA pursues platforms, not just individual senders

### 6.5 SMS Sender ID Registration

From 2024, ACMA has been implementing an **SMS Sender ID Registry** to prevent SMS phishing. Businesses using alphanumeric Sender IDs (e.g., "BellasBistro" instead of a phone number) must register those IDs through their carrier or SMS provider (Clicksend in this case). Woahh should:
- Inform merchants of this requirement during SMS onboarding
- Surface Sender ID registration in the Operations settings
- Default to Clicksend's compliant Sender ID system or numeric numbers until merchant registration is confirmed

**Action items:**
- [ ] Add consent collection fields to the customer checkout and account creation flows — store: what consent was given, when, and how (express vs. inferred)
- [ ] Add consent data to the `customers` table (already has `sms_opt_out` and email opt-out — add consent source and timestamp)
- [ ] Add a consent confirmation checkbox to the SMS and email campaign send flow: "I confirm my recipients have consented to receive this message"
- [ ] Enforce inclusion of "Reply STOP to unsubscribe" in the SMS campaign message composer
- [ ] Ensure every email campaign template includes a visible unsubscribe link — no exceptions
- [ ] Confirm the `/unsubscribe/:token` page processes the opt-out without requiring login
- [ ] Add explicit Spam Act prohibition to Merchant Terms of Service
- [ ] Build a campaign abuse/complaints reporting mechanism
- [ ] Investigate Clicksend's Sender ID registration process and surface it in Operations settings

---

## 7. Australian Consumer Law (ACL)

*Competition and Consumer Act 2010 (Cth), Schedule 2*

### 7.1 Misleading or Deceptive Conduct (s18 ACL)

The most broadly applied consumer protection provision in Australia. It is **strict liability** — intent does not matter, only whether conduct was objectively misleading.

Woahh's marketing copy has specific risk areas:

| Claim | Risk | Mitigation |
|---|---|---|
| "Zero commission marketplace" | If any charge tied to marketplace sales is ever added, this claim is at risk | Be precise: "No per-order commission on /eat marketplace orders" — document it in Terms |
| "Keep every dollar" | Stripe's processing fees still apply — these are the merchant's fees, not Woahh's, but could still mislead someone unfamiliar with how Stripe works | Clarify: "Keep every dollar Woahh would otherwise take" — Stripe fees always applied regardless of Woahh |
| "0.1% of GMV donated to charity" | Must actually happen, must be accurate, must be verifiable | The public `/impact` page and transparent `donation_ledger` are the right response — maintain records and publish charity receipts |
| Competitor comparisons (Square 2.6–2.9%, Uber Eats 25–30%) | The comparison must be accurate at time of publication | Review regularly; add "as of [date]" or "rates may vary" to all published comparisons |
| "Impact Partner" badge on merchant storefronts | Implies genuine impact — if the donation calculation is wrong or delayed, this becomes misleading | Automated real-time calculation via database triggers (already implemented) is the right approach |
| Free trial claims | Must be clear what happens at end of trial and when billing starts | Explicit pre-trial disclosure: what tier activates, what the price will be, how to cancel, and when billing begins |

### 7.2 Unfair Contract Terms (UCT) Regime

From November 2023, it is now **illegal** (not just void) to include an unfair term in a standard form contract with a small business (under $10M turnover or under 20 employees — which describes most Woahh merchants). Civil penalties apply.

Terms that are presumptively unfair in a SaaS merchant agreement:
- Allowing Woahh to unilaterally change the service without notice or a right for the merchant to exit
- Broad disclaimer clauses excluding Woahh from all liability regardless of fault
- Automatic renewal clauses without clear prior notice
- Right to terminate without cause and without refund for prepaid periods
- Preventing the merchant from cancelling with reasonable notice
- Unilateral price increase clauses without an opt-out right
- Very broad intellectual property assignment clauses

**Action items:**
- [ ] Have a commercial lawyer review the Merchant Terms of Service specifically for UCT compliance before launch
- [ ] Include: clear termination provisions with notice periods, refund policy for unused prepaid periods, notification period before changes take effect, and an opt-out right on price changes

### 7.3 Subscription Trap Protections

The ACCC has made subscription traps a priority enforcement area:
- **Free trial:** Must clearly disclose that the trial will convert to a paid subscription, the price, and the exact date billing will start
- Even with "no credit card required at trial start," when the trial expires there must be clear notice before any billing begins
- **Easy cancellation:** Must be at least as easy to cancel as it was to sign up — a cancel button in account settings is the minimum; hiding cancellation behind a support ticket workflow is a UCT risk
- **Pre-billing notice:** Best practice is an automated email 7 days before trial expiry with the price and a cancel link
- **Refund for billing errors:** Must refund if charged after a confirmed cancellation

### 7.4 Consumer Guarantees (s60–67 ACL)

Subscription services carry implied guarantees that they will be:
- Provided with due care and skill
- Fit for the purpose as described
- Supplied within a reasonable time

If a Woahh outage prevents a merchant from taking orders during a dinner service, the merchant may have a claim for consequential losses. A limitation of liability clause in the Terms will apply, but it cannot be so broad as to constitute an unfair term.

**Action items:**
- [ ] Define an SLA (uptime commitment) in the Terms — even 99.5% uptime with a service credit remedy is better than silence
- [ ] State the refund policy clearly in the Terms
- [ ] Build an automated email notification 7 days before trial expiry with price and cancel link

---

## 8. Electronic Transactions

### 8.1 Electronic Transactions Act 1999 (Cth)

Clickthrough Terms of Service (checkbox "I agree") are legally binding contracts in Australia under this Act. Requirements for enforceability:
- The full Terms must be accessible **before** the user accepts them
- The acceptance mechanism must be deliberate — pre-ticked checkboxes are not valid consent
- You must keep a record of what version of Terms the user agreed to and when
- Terms must remain accessible post-sign-up (link in the dashboard footer is sufficient)

**Action items:**
- [ ] Version the Terms of Service — when Terms change, existing users must be notified and given an opportunity to accept the new Terms or exit
- [ ] Log the Terms version number and acceptance timestamp in the `organizations` table at sign-up

---

## 9. Financial Services Law

### 9.1 AFSL (Australian Financial Services Licence)

**Phase 1 (Stripe Standard):** Stripe holds its own AFSL covering payment processing for platforms operating under Stripe Standard. Woahh is not a financial services provider under this model. No AFSL required.

**Phase 2 (Stripe Connect Express):** When merchant payment flows are routed through Woahh, Woahh potentially becomes a financial services provider. Stripe Connect platforms may benefit from Stripe's AFSL coverage under a provider exemption, but this requires explicit written confirmation from Stripe Australia. **Obtain this in writing before moving to Phase 2.**

### 9.2 AUSTRAC (Anti-Money Laundering and Counter-Terrorism Financing Act 2006)

**Phase 1:** Not required. Merchants own their Stripe relationship and Woahh touches no payment flows.

**Phase 2 (Stripe Connect):** When Woahh takes a 0.3% platform fee on every transaction, AUSTRAC registration as a **remittance dealer or payment facilitator** will almost certainly be required. This involves:
- Registering with AUSTRAC
- Appointing an AML/CTF Compliance Officer
- Developing a written AML/CTF Program document
- Ongoing monitoring and suspicious matter reporting (SMRs)
- Annual compliance reporting to AUSTRAC
- Staff AML/CTF training

**Phase 3 (Crypto/USDC donations):** Exchanging fiat to USDC and sending to charity wallets via a smart contract makes Woahh a **Digital Currency Exchange (DCE) provider** under the AML/CTF Act. This triggers:
- AUSTRAC registration as a DCE — **mandatory before the first crypto transaction, not after**
- Full AML/CTF program applicable to DCE providers
- KYC (Know Your Customer) verification of charity wallet owners
- Transaction reporting obligations above certain thresholds

**Do not implement Phase 3 without engaging a specialist AML/CTF compliance firm and registering with AUSTRAC first.**

### 9.3 Loyalty Points — Financial Products Consideration

Loyalty points redeemable for discounts can, in some structures, constitute a financial product under the *Corporations Act 2001*. To stay clearly outside financial product territory:
- Do not allow loyalty points to be transferred between customers
- Do not allow loyalty point redemption for cash refunds
- Do not allow points to be sold or traded
- Points must expire on clear, disclosed terms

**Action items:**
- [ ] Get written confirmation from Stripe Australia about AFSL coverage under Stripe Standard before launch
- [ ] Before Phase 2: engage AML Shield, Comply Advantage, or equivalent — 3–6 months lead time for AUSTRAC registration
- [ ] Before Phase 3: engage a specialist crypto/AML lawyer — this is a significant compliance undertaking
- [ ] Add loyalty program terms: clearly state how points are earned, redeemed, expiry conditions, that points have no cash value, and that points are not transferable
- [ ] Confirm at the application level that points cannot be redeemed for cash

---

## 10. Charitable Giving Compliance

### 10.1 Marketing Representations — ACL

Every claim Woahh makes about charitable giving is subject to ACL s18 (misleading conduct):
- "Your orders contributed $X to charity" on the merchant dashboard
- "0.1% of GMV donated" in all marketing materials
- Totals and breakdowns on the public `/impact` page
- The "Impact Partner" badge on merchant storefronts

These claims create legal liability if inaccurate. The `donation_ledger` table, public `/impact` page, and transparent ledger structure are the right approach. Ensure:
- The donation calculation is automated and matches what is displayed in real time
- Donations are actually made — every ledger entry must correspond to a real financial transfer to a real charity
- Charity receipts are obtained and published on the `/impact` page

### 10.2 Fundraising Laws — State by State

Fundraising laws in Australia are state-based and inconsistent. The key question is whether Woahh is legally "fundraising" when it donates 0.1% of GMV from its own revenue.

**If Woahh donates purely from its own revenue:** Generally not "fundraising" — it is a business donation. No permits typically required.

**The grey area:** The voluntary donation rate slider in `Donate.tsx`, combined with the "Impact Partner" badge displayed to end-customers, may be interpreted as Woahh facilitating public fundraising on behalf of merchants. This is the grey zone in:

| State | Law | Risk level |
|---|---|---|
| NSW | Charitable Fundraising Act 1991 | High — requires authority to fundraise if soliciting donations from the public |
| VIC | Fundraising Act 1998 | High — requires registration with Consumer Affairs Victoria |
| QLD | Collections Act 1966 | High — requires sanction from the Office of Fair Trading |
| WA | Charitable Collections Act 1946 | Medium — requires a fundraising licence |
| SA | Collections for Charitable Purposes Act 1939 | Medium — requires registration |
| TAS | Collections for Charity Act 2011 | Lower — specific exemptions may apply |
| ACT | Charitable Collections Act 2003 | Medium |
| NT | No equivalent legislation | Lower |

**Safest structural approach** (consistent with what the strategy document outlines): Woahh retains the GMV donation amounts within the company P&L and transfers them to registered charities on a fixed schedule. Woahh is donating its own money — not collecting donations from anyone. The voluntary merchant contribution rate slider needs specific legal review.

### 10.3 Only Donate to DGR-Status Charities

Only donate to charities with **DGR (Deductible Gift Recipient) status** from the ATO:
- Relevant for the tax deductibility of Woahh's donations as a business expense
- Lends credibility to the giving claims
- Check DGR status at the ATO's ABN Lookup tool before sending any donation

### 10.4 Separate Charitable Entity (When Ready)

When setting up a separate charitable entity:
- Register as a **Company Limited by Guarantee** or **Charitable Trust**
- Register with **ACNC** (Australian Charities and Not-for-profits Commission)
- Apply to ATO for **DGR endorsement** if donors should receive tax deductions
- ACNC requires annual financial reporting and compliance with governance standards

**Action items:**
- [ ] Engage a charity law specialist before launch to confirm whether the voluntary donation rate slider triggers state fundraising registration requirements
- [ ] If it does: register in each relevant state before launch, or simplify the model to purely Woahh-funded donations to avoid the issue
- [ ] Only donate to charities with confirmed DGR status
- [ ] Retain and publish charity receipts for all donations (already planned in the strategy — implement it)
- [ ] Implement the public GitHub issue tracker for donation concerns before the `/impact` page goes live
- [ ] Keep all financial records of charity transfers for at least 5 years

---

## 11. Online Marketplace Obligations

### 11.1 Sponsored Listings Must Be Labelled (Promote.tsx)

The `/eat` marketplace shows sponsored listings. Under ACCC guidelines and the AANA Code of Ethics, **sponsored content must be clearly labelled as advertising**. Users browsing the marketplace must be able to distinguish:
- Organic search results
- Paid/sponsored placements

Failure to label sponsored content is misleading conduct under ACL s18. This is the same requirement that applies to Google Search results and social media paid posts.

**Action items:**
- [ ] Ensure sponsored listings on `/eat` display a visible "Sponsored" or "Ad" label
- [ ] The label must be clear and prominent — not in small print or a muted colour

### 11.2 Reviews and Ratings

The `reviews` table drives `organizations.marketplace_rating`. Under ACCC guidelines on fake or misleading reviews:
- Reviews must be genuine customer reviews
- Merchants cannot be incentivised to produce reviews in a way that inflates ratings (e.g., "leave a 5-star review and receive 50 bonus loyalty points" is problematic — tying rewards to "leaving a review" not "leaving a 5-star review" is the safe version)
- Merchants cannot delete negative reviews (they can respond but not remove)
- If Woahh moderates reviews, the moderation policy must be publicly disclosed

**Action items:**
- [ ] Add a review authenticity policy to the Terms of Service
- [ ] Remove the technical ability for merchants to delete customer reviews (flag for Woahh moderation only)
- [ ] If loyalty rewards are tied to reviews, ensure they reward the act of reviewing — not the star rating

### 11.3 Liquor Sales

If restaurants on the platform sell alcohol via the order flow:
- Merchants are solely responsible for their own liquor licence compliance
- Woahh as the facilitating platform may have age verification obligations
- Add an "I am 18 or over" confirmation checkbox to the checkout flow for orders containing alcohol
- Include in Merchant Terms: merchants selling alcohol are responsible for age verification compliance under applicable state liquor laws

### 11.4 Food Safety

Food safety compliance under the *Food Standards Australia New Zealand Act 1991* and state food safety laws is the merchant's responsibility entirely. The Merchant Terms of Service must explicitly state this and require merchants to comply with all applicable food handling and labelling laws.

---

## 12. Data Security

### 12.1 Security Obligations Under the Privacy Act (APP 11)

Woahh must take "reasonable steps" to protect personal information. At this data sensitivity level, "reasonable steps" means:
- Encryption at rest and in transit — verify Supabase encryption settings are active
- Row Level Security on all customer and order tables (already implemented — verify no bypasses exist)
- Employee access controls — log who can query production data and when
- Regular security dependency updates and patch management
- Penetration testing before launch (or immediately after) — specifically the authentication flows and Supabase RLS policies
- Documented key management for encrypted credentials

### 12.2 PCI DSS

Woahh does not process cards directly, so PCI DSS scope is minimal — likely **SAQ A** (the simplest self-assessment questionnaire). However:
- Never log, store, or transmit raw card numbers or CVVs anywhere in Woahh's system
- Confirm no card data ever touches Woahh's servers or database
- Complete an annual SAQ A self-assessment

### 12.3 Courier Credentials Security

The `courier_credentials` table stores merchant Uber Direct API keys. These are highly sensitive and must be protected:
- Row-level encryption of the API key values (not just transport encryption)
- Strict RLS: merchants can only access their own credentials — no cross-tenant access
- Audit log of when credentials are accessed or used
- A documented key rotation process for when credentials are compromised

**Action items:**
- [ ] Verify Supabase encryption at rest is active on all tables containing personal data
- [ ] Review all RLS policies for correctness — a policy gap is a data breach
- [ ] Define which team members have production database access and log that access
- [ ] Schedule a penetration test before or shortly after launch
- [ ] Complete SAQ A self-assessment annually
- [ ] Confirm `courier_credentials` values are encrypted at the row level and document the key management process

---

## 13. Employment Law

### 13.1 Employee vs. Contractor Classification

Following the High Court decisions in *CFMMEU v Personnel Contracting* [2022] and *ZG Operations v Jamsek* [2022], the test for employment vs. contractor is now a **totality of the contract terms** test. If Woahh uses freelancers or contractors, review their contracts carefully. Misclassification results in liability for:
- Unpaid superannuation
- Leave entitlements
- PAYG withholding obligations
- Workers' compensation

### 13.2 Superannuation

- Currently **11.5% Superannuation Guarantee** (rising to **12% from 1 July 2025**)
- Payable for all employees and some contractors
- Must be paid into a compliant super fund by the quarterly due dates: 28 January, 28 April, 28 July, 28 October
- SuperStream compliance required for electronic super contributions

### 13.3 Fair Work Act 2009

- National Employment Standards (NES) apply to all employees — minimum notice periods, leave entitlements, etc.
- Use employment contracts that comply with the relevant Modern Award — likely the *Professional Employees Award 2020* for software developers and tech workers
- Casual employees with a regular pattern of work acquire casual conversion rights after 12 months

### 13.4 Workers' Compensation

State-based. Required from the day you hire your first employee. Register with the workers' compensation authority in your operating state before hiring.

**Action items:**
- [ ] Review all contractor agreements against the High Court employment test before signing
- [ ] Register for workers' compensation insurance before hiring the first employee
- [ ] Set up SuperStream-compliant payroll from day one
- [ ] Confirm all employment contracts reference the correct Modern Award

---

## 14. Accessibility

### 14.1 Disability Discrimination Act 1992 (Cth)

The DDA prohibits discrimination in the provision of goods and services. For a web application, public-facing pages must be reasonably accessible to people with disabilities. The ACCC and Australian Human Rights Commission have both taken action against businesses with inaccessible websites.

Best practice standard: **WCAG 2.1 Level AA** for all public-facing pages:
- `/eat` marketplace
- Merchant storefronts
- Customer order flow
- Customer account portal
- `/impact` page

Key requirements: sufficient colour contrast, full keyboard navigation, screen reader compatibility, and meaningful alt text on all images.

**Action items:**
- [ ] Run automated accessibility audit (Axe, Lighthouse) on all public-facing pages before launch
- [ ] Address any critical WCAG 2.1 AA violations — colour contrast, keyboard navigation, screen reader compatibility, alt text
- [ ] Document your accessibility statement on a public `/accessibility` page

---

## 15. Legal Documents Checklist

All of the following must be drafted, reviewed by an Australian commercial lawyer, and published before launch:

| Document | Who it governs | Where published |
|---|---|---|
| **Merchant Terms of Service** | Woahh ↔ merchants | Shown at signup, linked in dashboard footer |
| **Merchant Data Processing Agreement** (can be embedded in ToS) | Woahh as processor of merchant customer data | Embedded in or linked from Merchant ToS |
| **Consumer/Customer Privacy Policy** | End customers using storefronts and `/eat` | Footer of all public pages |
| **Merchant Privacy Policy** | Merchant personal data held by Woahh | Signup flow and dashboard footer |
| **Cookie Policy** | Any website visitor | Site footer and cookie consent banner |
| **Acceptable Use Policy** | Merchants — prohibits spam, illegal activity, false reviews | Linked from Merchant ToS |
| **Refund and Cancellation Policy** | Merchants | Linked from Merchant ToS |
| **Loyalty Program Terms** | End customers | Customer account creation and `/account` page |
| **Charitable Giving Disclosure** | Public | `/impact` page and Terms of Service |
| **Sub-processor List** | Transparency on who processes personal data | Privacy Policy appendix |
| **SLA (Service Level Agreement)** | Merchants | Merchant ToS or linked separately |
| **Review Policy** | Merchants and customers | Merchant ToS and `/eat` marketplace footer |

---

## 16. Ongoing Compliance Calendar

| Frequency | Obligation |
|---|---|
| **Monthly** | If lodging BAS monthly: prepare and lodge. Review SMS/email opt-out processing rates. Process any pending data access or correction requests (30-day deadline). Check OAIC and ACMA for regulatory updates. |
| **Quarterly** | Lodge BAS. Pay superannuation by due dates (28 Jan, 28 Apr, 28 Jul, 28 Oct). Make charity donation transfers and record in `donation_ledger` with receipts. Review marketing claims for accuracy (competitor pricing changes). |
| **Annually** | Company income tax return. ASIC annual review fee. Business name renewal. Trade mark renewal (10-year cycle — diarise ahead). Privacy Policy and Terms of Service review. PCI DSS SAQ-A self-assessment. Cyber insurance renewal. Accessibility audit of public pages. |
| **On trigger** | Eligible data breach → notify OAIC + affected individuals within 30 days. Price or Terms change → notify existing merchants 30 days in advance with opt-out right. New sub-processor added → update Sub-processor List and notify merchants. Australian Privacy Act regulatory update → review OAIC guidance within 30 days of update. |

---

## 17. Phase-Specific Flags

### Before Phase 2 (Stripe Connect + 0.3% platform fee)

- [ ] Engage an AUSTRAC compliance firm (AML Shield, Comply Advantage, or equivalent) — allow 3–6 months lead time before the feature launches
- [ ] Obtain written confirmation from Stripe Australia confirming AFSL coverage under Stripe Connect
- [ ] Draft an AML/CTF Program document
- [ ] Appoint an AML/CTF Compliance Officer
- [ ] Register with AUSTRAC before processing the first Stripe Connect transaction

### Before Phase 3 (Crypto/USDC on-chain donations)

- [ ] Register with AUSTRAC as a **Digital Currency Exchange provider** — **this must happen before the first crypto transaction, not after**
- [ ] Engage a specialist crypto/AML lawyer — this is a significant compliance and operational undertaking
- [ ] Confirm partner charities can legally accept crypto donations in Australia and have the capability to do so (The Giving Block or equivalent)
- [ ] Review ATO guidance on GST treatment of crypto-to-fiat conversions at the charity end
- [ ] Capital gains tax planning for any crypto held on the balance sheet between conversion and transfer
- [ ] Legal review of the smart contract code before deployment — contract bugs are irreversible

---

## 18. Critical Path Before First Paying Customer

These are the absolute must-haves, in priority order:

| Priority | Action | Why |
|---|---|---|
| 1 | Register Pty Ltd + ABN + GST | Cannot legally invoice or accept payment without these |
| 2 | Publish Privacy Policy + Collection Notices | Cannot lawfully collect any personal data without these — Privacy Act breach from day zero otherwise |
| 3 | Execute DPAs with Supabase, Resend, Clicksend, Stripe | Required by APP 8 before any personal data flows to overseas services |
| 4 | Draft and publish Merchant Terms of Service (including embedded DPA and AUP) | Legal foundation for every merchant relationship — required before first signup |
| 5 | Write Data Breach Response Plan | Required by the Privacy Act before handling personal data |
| 6 | Spam Act compliance in the product | Consent collection at checkout, unsubscribe in every message, instant opt-out processing — required before any commercial message is sent |
| 7 | Get Professional Indemnity + Cyber Liability insurance | Before first paying merchant — one data breach or outage claim can be existential at early stage |
| 8 | Charity legal review | Confirm whether voluntary donation rate slider triggers state fundraising registration before marketing the giving feature |
| 9 | Label sponsored listings on `/eat` as "Sponsored" | Required before the marketplace goes live — unlabelled paid placement is misleading conduct under ACL |
| 10 | ACL-compliant free trial disclosure | Before any free trial begins: clearly state what tier activates, what it will cost, when billing starts, and how to cancel |

---

*This document reflects Australian law as of April 2026. The Privacy Act reforms, UCT regime expansion, and ACMA Sender ID rules are all recent and evolving — schedule a review with an Australian commercial lawyer every 6 months, and monitor OAIC, ACCC, and ACMA guidance pages for updates.*

*US, UK, EU, and other jurisdictions to be added as separate sections once Australian compliance is in place.*
