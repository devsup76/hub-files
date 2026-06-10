---
name: woahh-financial-model
description: "woahh's LOCKED financial model (2026-06-02): 3% merchant + 1% customer = 4% gross online, $15k GMV base, Solo $49/Marketplace $89/Growth $150 — use these everywhere; old 4-6%/$50k/$199 numbers are dead"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5488fec5-c083-48fd-a411-06e380d8cc03
---

**LOCKED financial model (2026-06-02) — single source of truth: `docs/business/BUSINESS_STRATEGY.md`.**
Use these numbers in ALL docs/landing/code; the older 4%/6%-gross, $50k GMV, $199 Growth, 2.5%/0.15%/"20% of revenue" charity framings are **dead** — do not reintroduce.

- **Commission:** 3% merchant + 1% customer = **4% gross online** (3% in-person, no customer fee). Split half/half → **online 2% woahh / 2% charity; in-person 1.5%/1.5%**. Stripe fees are **merchant-borne** (woahh's commission is clean). Founding merchants = 0% commission (still pay subs); each forgoes ~$300/mo net.
- **GMV base:** **$15,000/merchant/month** (online/through-woahh; rises 3–4× once POS captures full in-store GMV — the key upside lever).
- **Subscriptions (marketed prices):** Solo **$49**, Marketplace **$89**, Growth **$150**, Enterprise custom. Each split **50/50** with charity ($24.50/$44.50/$75 to charity).
- **Charity headline:** ~2% of every online order + 50% of every subscription. (The 0.1% GMV `voluntary_donation_rate_bp` default is a SEPARATE voluntary floor, not the headline.)
- **Per merchant/mo:** commission net $300 + sub-half $44.50 = **$344.50 to woahh**, and **$344.50 to charity** (equal by design). Growth tier specifically ≈ $375 to woahh ($75 sub-half + $300).
- **Scale:** 1,000 merchants → ~$344.5k/mo woahh (~$4.13M ARR) + ~$4.13M/yr charity; 5,000 → ~$1.72M/mo (~$20.7M/yr) each.
- **Margins/break-even:** ~94% contribution margin **pre-payroll**; break-even ~60–110 merchants; net margin ~60–82% at scale after a lean team. (The old "97–99% net margin" ignored payroll.)
- **$30 online order:** customer pays $30.30; merchant commission $0.90; woahh net $0.60; charity $0.60; merchant keeps $28.28. **$80k/mo merchant:** woahh cost $2,489/mo ($29,868/yr), saves ~$258k/yr vs Uber Eats, ~$1,644.50/mo to charity. **LTV ~$8–12k**, CAC <$400.

**Reconciled to this model + committed/pushed 2026-06-02:** `BUSINESS_STRATEGY.md` (hub-files `871a57a`), `VC_PITCH_DECK.md` + `POSITIONING_BRIEF.md` (`96da867`), `pitch.md`+`SPEAKER-SCRIPT.md`+`RESTAURANT_PITCH.md` (`d483dea`); app landing `MoneyFlowCard.tsx` + `Storefront.tsx` + `Donate.tsx` (business-growth-hub main `654691c`, Cloudflare prod). SPEAKER-SCRIPT had a totally divergent giving model (20%-of-revenue/$10-$40 fixed/0.15%) — replaced. `$50k/month restaurant` left ONLY as problem-framing (their total revenue / what they pay aggregators), never as woahh ARPU. Related: [[woahh-pitch-and-franchise-planning]].
