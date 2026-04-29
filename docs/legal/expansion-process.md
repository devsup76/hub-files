# Woahh — Legal & Financial Staffing Expansion Guide

> Who to hire (and when) to keep Woahh compliant as it grows.
> Written for a 3-person technical founding team with no formal legal or financial background.
>
> Last updated: 2026-04-29

---

## The Core Principle

A 3-person tech startup does not need an in-house lawyer or CFO. What you need is:

- **External specialists** engaged for specific deliverables (lawyers, accountants, consultants)
- **Accounting software** to automate financial hygiene
- **One generalist operations person** as your first non-tech hire who owns the compliance calendar and coordinates the external specialists

You are buying expertise, not headcount. Full-time hires only make sense when the volume of ongoing work justifies it.

---

## Stage 1 — Right Now (Before First Paying Customer)

These are engagements, not hires. Do all of these before launch.

### 1. Startup/Tech Commercial Lawyer (Law Firm Engagement)

**What they do for you:**
- Draft the Merchant Terms of Service (including embedded DPA, Acceptable Use Policy, SLA)
- Draft the Privacy Policy and Collection Notices
- Review everything for UCT (Unfair Contract Terms) compliance
- Advise on the fundraising law question (voluntary donation rate slider)
- Set up the Terms versioning process

**Cost:** One-time engagement of **$8,000–$18,000** AUD to produce the full document suite. After that, a light retainer of **$500–1,500/month** for ongoing questions and annual document reviews.

**Who to look for:** Law firms that specialise in tech startups and SaaS. In Australia: LegalVision, Lander & Rogers (tech practice), Maddocks, or Ignite Legal. Avoid general practitioners — you need someone who knows SaaS contracts and UCT cold.

**Do not use a legal template service** (LawDepot, etc.) for your Merchant Terms. The UCT regime and dual data controller/processor structure make your contracts non-standard enough that templates will leave dangerous gaps.

---

### 2. Charity Law Specialist (One-Off Consultation)

**What they do for you:**
- Clarify whether the voluntary donation rate slider constitutes fundraising under state laws
- Advise on the structure of the separate charitable entity when you're ready
- Confirm which charities have DGR status and how to document the relationship

**Cost:** A single 2-hour consultation plus a written advice memo — **$800–$2,500** AUD. One-time cost, not ongoing.

**Who to look for:** Moores (Melbourne, leading charity law firm in Australia), Hall & Wilcox, or Justice Connect's legal referral service. You specifically want someone who handles both ACNC registration and state fundraising permits.

---

### 3. Accountant / Tax Agent (External Firm)

**What they do for you:**
- GST registration and BAS lodgment (quarterly)
- Company income tax return (annual)
- Payroll tax advice when you hire employees
- Structure the charitable giving for tax purposes — Woahh's donations to DGR charities are tax-deductible business expenses that must be properly recorded
- Superannuation compliance setup

**Cost:** A small business accountant handling BAS plus annual tax return typically costs **$3,000–$6,000/year** at your stage.

**Who to look for:** A CPA or CA firm with SaaS startup clients — they will understand subscription revenue recognition, Stripe payouts, and the nuances of digital service GST. Ask your lawyer for a referral; they usually know each other.

**You also need accounting software immediately:** Set up **Xero** (~$70/month). It connects to your bank account, handles GST tracking automatically, and your accountant will expect to use it. Trying to do GST manually in a spreadsheet is how you make BAS errors.

---

### 4. AML/CTF Compliance Firm (Awareness-Only Now, Active from Phase 2)

**What they do for you:**
- Brief you now on what AUSTRAC registration for Phase 2 will require
- Prepare and file the registration when you're ready
- Draft the AML/CTF Program document
- Train staff when Phase 2 launches

**Cost for Phase 2 preparation:** **$5,000–$15,000** for the AML/CTF program document and AUSTRAC registration. Ongoing compliance management via a compliance-as-a-service provider runs **$2,000–$5,000/month**.

**Who to look for:** AML Shield, Comply Advantage Australia, Regulatory Compliance Associates. Engage them **6 months before you expect to launch Phase 2** — not when you're ready to build it.

---

## Stage 2 — Early Growth (~50–100 Merchants, $5k–$10k MRR)

At this point the volume of routine compliance tasks becomes real. You need someone who owns this internally so it does not fall between the cracks.

### 5. Operations & Compliance Coordinator (First Non-Tech Hire)

**This is the most important hire you will make from a compliance standpoint.** This person does not need to be a lawyer or accountant. They need to be:
- Highly organised and process-driven
- Comfortable reading legal documents and knowing which questions to escalate
- A strong communicator — they are the interface between your team and the external specialists
- Familiar with Australian business administration

**What this person owns:**
- The compliance calendar — BAS lodgment reminders, super payment dates, ASIC annual review, trade mark renewal, insurance renewal
- Data subject request handling — privacy access and correction requests have a 30-day response obligation
- Spam Act opt-out monitoring — reviewing that the unsubscribe webhooks are processing correctly
- Coordinating with the lawyer on merchant complaints, Terms updates, and review policy enforcement
- Coordinating with the accountant on BAS data, receipts, and year-end
- Keeping `legalities/` documents up to date
- Merchant onboarding checklist — ensuring each merchant accepts the current Terms version at sign-up
- Charity donation transfers — making the actual bank transfers monthly or quarterly, filing receipts against the `donation_ledger`

**Cost:** Part-time Operations Coordinator — **$35,000–$50,000/year**. Full-time — **$55,000–$75,000/year** depending on experience and location.

**When to hire:** When compliance tasks are regularly falling off the todo list because the tech team is too busy building. If BAS lodgment is late or unsubscribes have not been processed in two weeks — that is the signal.

---

### 6. Bookkeeper (Part-Time or Virtual)

A bookkeeper does the monthly reconciliation that your accountant is too expensive to perform:
- Reconcile transactions in Xero
- Categorise expenses
- Prepare BAS data for the accountant to review and lodge
- Manage accounts receivable (Stripe payouts) and payable (Supabase, Resend, Clicksend invoices)
- Payroll processing once you have employees

**Cost:** A virtual bookkeeper in Australia typically costs **$500–$1,500/month** for a startup at 50–100 merchants. Most work across multiple clients.

**This role can be delayed** if you are disciplined with Xero and your accountant handles BAS at a reasonable cost. Hire when Xero reconciliation starts taking more than a few hours a month.

---

## Stage 3 — Scaling (100–500 Merchants)

### 7. HR Consultant or Platform (When You Have 5+ Employees)

Australian employment law is complex enough that compliance errors are costly. You need either:

- **Employment Hero** (SaaS platform, $10–$25/employee/month) — handles contracts, Modern Award compliance, leave tracking, onboarding, and offboarding. This is software, not a person — it removes the need for a person at this stage.
- **Plus** an HR consultant on a project basis for: employment contract drafting, performance management advice, and termination guidance. Budget **$200–$350/hour** for a specialist HR consultant when needed.

You do **not** need a full-time HR person until you have 15–20 employees.

---

### 8. Finance Manager (When Revenue is $500k–$1M+ ARR)

At this point an accountant reviewing your books quarterly is no longer sufficient. A Finance Manager (not a CFO — that comes later):
- Manages Xero and the bookkeeper
- Produces monthly P&L and cash flow reports for the founders
- Manages the accountant relationship
- Manages super, BAS, and payroll tax obligations
- Coordinates AUSTRAC compliance if Phase 2 is live
- Tracks charitable giving and produces the figures for the `/impact` page
- Handles subscription billing data integrity — ensuring Stripe MRR matches Xero revenue

**Cost:** A Finance Manager in Australia earns **$90,000–$130,000/year**. For a bootstrapped startup, consider a **fractional CFO** first (~$2,000–$5,000/month part-time) before committing to a full-time hire.

---

## Stage 4 — Phase 2 Specific (Stripe Connect + AUSTRAC Registration)

### 9. AML/CTF Compliance Officer (Required by Law for Phase 2)

The *Anti-Money Laundering and Counter-Terrorism Financing Act* requires that a registered reporting entity appoints a named **AML/CTF Compliance Officer**. This must be a real person — it cannot be outsourced entirely, though the support function around them can be.

Practically, this can be:
- The Finance Manager once trained and certified in AML/CTF compliance
- A dedicated Compliance Manager hire
- An outsourced compliance officer from a compliance-as-a-service firm who acts as your named officer (legally permissible and common for smaller entities)

**Cost if outsourced:** Compliance-as-a-service firms charge **$3,000–$8,000/month** to act as your named compliance officer and manage the AUSTRAC program. Worth considering until you have in-house volume to justify a hire.

**Cost if in-house:** A dedicated Compliance Manager earns **$100,000–$140,000/year** in Australia.

---

## Summary Table

| Who | Type | When | Approximate Cost |
|---|---|---|---|
| Startup/tech commercial lawyer | External firm | Before first paying customer | $10–18k setup + $500–1,500/month retainer |
| Charity law specialist | External, one-off | Before marketing the giving feature | $800–2,500 one-off |
| Accountant / Tax Agent | External firm | Before first invoice | $3–6k/year |
| AML/CTF compliance firm (awareness) | External firm | 6 months before Phase 2 | $5–15k for registration + program |
| Xero | Software tool | Immediately | ~$70/month |
| Employment Hero | Software tool | First employee hire | $10–25/employee/month |
| Operations & Compliance Coordinator | First non-tech hire | ~50 merchants or when compliance tasks are slipping | $55–75k/year full-time |
| Bookkeeper | Part-time/virtual | ~50–100 merchants | $500–1,500/month |
| HR consultant | Project-based external | As needed with employees | $200–350/hour |
| Finance Manager / Fractional CFO | Fractional then full-time | ~$500k ARR | $2–5k/month fractional, $90–130k/year full-time |
| AML/CTF Compliance Officer | Outsourced or in-house | Phase 2 launch | $3–8k/month outsourced, $100–140k/year in-house |

---

## The Real Sequence for a 3-Person Startup

1. **This week:** Engage a lawyer and accountant. Set up Xero. These are not optional.
2. **Before launch:** Lawyer produces the full document suite. Charity specialist clears the giving question. Accountant registers ABN and GST.
3. **At ~50 merchants:** Hire the Operations Coordinator. This person prevents everything else from slipping.
4. **Ongoing:** The Operations Coordinator owns the compliance calendar. External specialists execute when triggered. Founders review and sign.
5. **At ~$500k ARR:** Bring in a fractional CFO. Start AUSTRAC preparation for Phase 2.
6. **Phase 2 launch:** AUSTRAC registration complete, compliance officer named, AML program active.

---

## Why the Operations Coordinator is the Most Important Hire

At 3 people, compliance obligations are currently not being carried by anyone — they are silently falling through the gap between building product and running the business. The tech founders should not be managing BAS deadlines, processing privacy requests, or chasing charity receipts.

One organised, process-driven non-technical person eliminates that gap entirely. They do not need legal or financial qualifications — they need to know who to call and when, and to make sure the calendar never slips. That person costs less than a junior developer and protects the company from six-figure penalty exposure.

---

*Revisit this document whenever the team grows, a new funding stage begins, or a new product phase (Phase 2 / Phase 3) moves from planning to active development.*
