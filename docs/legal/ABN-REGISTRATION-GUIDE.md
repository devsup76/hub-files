# ABN + Business Name Setup — Woahh
> Written for: Pawit Singh — Founding Member
> Last updated: 2026-05-14

---

## Your Situation

You already have a personal ABN from a previous sole trader venture. You do **not** apply for a new one — one person gets one ABN as a sole trader, tied to your TFN. You reuse the same ABN and attach the business name "Woahh" to it.

The two things to do:

1. **Confirm your existing ABN is active** — 2 minutes
2. **Register the business name "Woahh" with ASIC** — 10 minutes, ~$98

That's it. Once ASIC processes the business name registration, "Woahh" is automatically linked to your ABN in the public register. No other steps needed to connect them.

---

## Step 1 — Confirm Your ABN is Active

Go to **abn.business.gov.au** and search your name or ABN number.

- **Active** → proceed to Step 2
- **Cancelled** → you need to reactivate it. Go to **abr.business.gov.au**, log in with your **myGovID** app, and select "Update ABN record" → reactivate. Then proceed to Step 2.

While you are here, also check whether **GST is registered** against your ABN.

**During the free test phase — do not register for GST yet.** GST registration is only legally required once your turnover reaches $75,000/year. With no revenue coming in, there is no obligation and no benefit that outweighs the quarterly BAS paperwork.

**Register for GST when** one of these happens:
- You are about to start charging merchants (subscriptions go live), or
- You can see turnover approaching $75k/year

To register when the time comes: myGov → ATO → Manage tax registrations → Add GST, start date that day, quarterly reporting.

---

## Step 2 — Register the Business Name "Woahh" with ASIC

**URL:** https://connectonline.asic.gov.au

### 2a — Create an ASIC Connect account

1. Go to **connectonline.asic.gov.au**
2. Click **Register** and create an account if you don't have one
3. Verify your identity with a current driver's licence or passport
4. Log in

### 2b — Check "Woahh" is available

1. Click **Search → Business Names**
2. Search: `Woahh`
3. If available, proceed
4. If taken, consider `Woahh Australia` or `Woahh Platform` — then proceed

### 2c — Start the registration

1. Click **Start a new form**
2. Select **Register a business name** (form BN1)
3. Business name: `Woahh`
4. Click Next

### 2d — Business name holder

Select **Individual** and enter:

| Field | Value |
|---|---|
| Given name | `Pawit` |
| Family name | `Singh` |
| Date of birth | [your DOB] |

### 2e — Link your ABN

Enter your existing ABN. ASIC verifies it automatically against the ABR.

### 2f — Address

| Field | Value |
|---|---|
| Street | `19 Sigwell Street` |
| Suburb | `Yarrabilba` |
| State | `QLD` |
| Postcode | `4207` |

### 2g — Registration period

| Option | Cost |
|---|---|
| 1 year | ~$42 |
| 3 years | ~$98 ✓ recommended |

Choose **3 years** — cheaper per year and one less thing to track. The only reason to pick 1 year is if you plan to incorporate as a Pty Ltd very soon, at which point you'd transfer the business name to the company anyway.

### 2h — Pay and submit

Pay by card. You will immediately receive:
- ASIC reference number
- Business name registration certificate (download and save to `docs/legal/`)

The business name appears on the ASIC public register within 1–2 business days. Your ABN lookup at abn.business.gov.au will automatically show **Woahh** against your record — no separate step needed.

---

## Step 3 — Update Your Subscriptions

Once you have your ABN confirmed and business name registered, update billing on everything to the business name and ABN. This lets you claim GST credits on every invoice.

| Service | Where to update |
|---|---|
| Supabase | Dashboard → Settings → Billing → Billing details |
| Lovable | Settings → Billing |
| Resend | Settings → Billing |
| Clicksend | Account → Billing |
| Stripe | Dashboard → Settings → Business details |
| Domain registrar | Update registrant ABN to yours — required for `woahh.com.au` |

For each one, the billing name should be: **Woahh** and include your ABN in the tax/business number field.

---

## What's Next After This

These are the next items before your first merchant goes live, in order:

| Priority | Action |
|---|---|
| 1 | **Sign the Co-Founders Agreement** (`docs/legal/founders-agreement.md`) — get Siddarth and Adithya to sign before they contribute anything |
| 2 | **Basic Privacy Policy + Terms of Service** — publish before any merchant signs up. Use Termly (termly.io) or iubenda to generate a starter version in 30 minutes. Upgrade to lawyer-drafted versions before going beyond the founding cohort. |
| 3 | **Stripe Connect Express** — set up under your ABN, apply for Connect platform access. This is what allows merchants to connect their own Stripe accounts to Woahh. |
| 4 | **Pty Ltd incorporation** — before your first paying merchant (see below) |

---

## When You Incorporate as a Pty Ltd

The sole trader structure handles the founding/testing phase. When you incorporate, the Pty Ltd becomes a completely separate legal entity with its own ABN and ACN.

### What the company gets

| Item | Detail |
|---|---|
| **ACN** (Australian Company Number) | Issued automatically by ASIC at incorporation — 9 digits. The company's permanent unique identifier. |
| **New company ABN** | Registered separately after incorporation at abr.business.gov.au — linked to the ACN. Completely different number from your personal sole trader ABN. |

Your personal sole trader ABN stays with you as an individual. Once the company is fully set up, cancel your sole trader ABN through myGov → ATO → Manage registrations.

### What to update when you incorporate

| Item | What to do |
|---|---|
| **Business name "Woahh"** | Transfer from your personal ABN to the company ABN in ASIC Connect — no re-registration fee |
| **GST** | Re-register under the company ABN. Lodge your final sole trader BAS first, then start fresh under the company. |
| **All subscriptions** | Update billing to company name + new company ABN |
| **Stripe** | Update business entity — may require re-verification (ACN, company ABN, director details) |
| **`woahh.com.au`** | Update registrant ABN to the company ABN through your domain registrar |
| **Business bank account** | Open a new account in the company name — banks require the ACN and company ABN |

### Merchant agreements

Any merchant agreements or supplier terms you signed as **Pawit Singh trading as Woahh** are between you personally and the other party — not the company. These need to be **novated** to the company when you incorporate: all parties agree in writing to substitute the company in your place. For early founding merchant agreements this is usually a short email or a one-page deed. Your lawyer handles anything more significant.

### When to incorporate

| Trigger | Reason |
|---|---|
| About to invoice a first paying merchant | Liability protection — a company limits your personal exposure |
| Co-founders need to formally hold shares | Shares only exist inside a company structure |
| External investor interest | Investors put money into companies, not sole traders |
| Accountant recommends it | Usually around $100k+ revenue when the 25% company tax rate beats your personal marginal rate |

**Cost:** ~$576 ASIC registration fee + ~$500–$1,000 if you use an accountant or lawyer to set it up. Budget half a day of admin to update all subscriptions and accounts afterward.

---

## Quick Reference

| Item | Sole Trader (now) | Pty Ltd (later) |
|---|---|---|
| ABN | Your existing personal ABN | New company ABN |
| ACN | Does not exist | Issued at incorporation |
| GST | Registered under personal ABN | Re-registered under company ABN |
| Business name "Woahh" | Held by you personally | Transferred to the company |
| Trading identity | Pawit Singh trading as Woahh | Woahh Pty Ltd |
| Personal liability | Unlimited | Limited to company assets |
