# Fixes for woahh app — punch list (2026-06-10)

> **Single source of truth for fixes/polish.** Rewritten 2026-06-10 from the founder's list.
> The old 2026-06-02 punch list is in git history; everything from it that was still open is
> carried over in the "Carried-over backlog" section at the bottom.
> Work the numbered list top-to-bottom unless the founder reorders.

## The list

- [ ] **1. Nicer onboarding checklist — and no payments until ABN verified.** Rework the OnboardingChecklist into a clearer, nicer flow; hard-gate payment acceptance (online card + pay-at-venue config) until the merchant's ABN is verified.
- [ ] **2. "Get set up" section auto-clears done steps.** Each setup step disappears (or collapses as ✓ done) once completed, so the section only ever shows what's left.
- [ ] **3. Test the in-store validation code.** End-to-end test of the rotating 6-digit in-person loyalty codes (earn + redeem; customer Account "In-Store" tab ↔ dashboard Loyalty validator).
- [ ] **4. Declutter the sidebar.** Current dashboard sidebar is overcrowded — group/collapse into a more convenient nav.
- [ ] **5. Obvious "setting up & domain" checklist.** A prominent checklist that walks the merchant through setup including their `<slug>.woahh.app` domain/storefront go-live.
- [ ] **6. Disable delivery everywhere, temporarily.** Hide/disable delivery across storefront, checkout, dashboard, KDS, marketing copy (keep courier code dormant behind a feature flag — carries over old TODO 6.1).
- [ ] **7. Storefront only viewable live once the merchant publishes.** Unpublished storefronts must not be publicly reachable.
- [ ] **8. On publish, put it on the `<slug>.woahh.app` domain.** Publishing is what activates the merchant's subdomain.
- [ ] **9. Limit storefront changes.** Rate-limit / restrict how much the merchant can fiddle with the storefront (template/branding churn) so they can't endlessly play with the web presence.
- [ ] **10. Fix checkout timings — show proper live timings.** Pickup/prep time shown at checkout must be real and live, not placeholder.
- [ ] **11. One checkbox at checkout for Terms + marketing.** Combine the Terms-accept and marketing opt-in into a single checkbox. ⚠️ Compliance note: Spam Act consent should be express/freely given — bundling marketing into the mandatory Terms tick is risky; recommend one *required* Terms checkbox with clearly-worded marketing consent line, or confirm wording against `docs/legal/legalities.md` §6 before shipping.
- [ ] **12. Fix phone UI for a better experience.** ⏸ ON HOLD until the whole new UI lands — quick wins only if trivial.
- [ ] **13. Pay at venue or pay online — merchant-configurable.** Merchant setting that controls which payment options the customer sees at checkout.
- [ ] **14. Fix the order money flow for the contributor/charity section.** Order → commission → charity split must flow correctly into the donation ledger / impact totals (per the locked 3%+1%=4% → 2%/2% model).
- [ ] **15. Checkout offers customer account before guest.** Flip the order: sign-in/create-account is the primary path, guest checkout secondary. *(Founder item 16.)*
- [ ] **16. Smarter automatic usernames.** Auto-generated usernames get numeric suffixes (e.g. `priya`, `priya2`, `priya17`) instead of failing or producing ugly handles. *(Founder item 17.)*
- [ ] **17. QR codes accessible without enabling dine-in.** A merchant should be able to generate/use QR codes even when dine-in is off. *(Founder item 18.)*

> Original founder list skipped #15, so items 16–18 are renumbered 15–17 here.

**When this list is done → check back with the founder before starting anything else.**

## Carried-over backlog (still open from the old list, verified 2026-06-10)

Not part of the active list above — pick up after it, or when a hard gate forces one.

- **[6.2] Founding launch promo** — free subscription (1 yr / lifetime OPEN) + temporary zero commission for first N sign-ups; reconcile wording with existing founding terms; backend enforcement + sign-up code gating (old `-1.2`) still missing.
- **[6.4] Restrict customer PII to owner + manager** — drop the `"Staff view customers"` RLS policy (client already gates; verify `current_org_id()` no longer covers staff for this).
- **[6.6] Storefront platform — finish + ship** — wildcard `*.woahh.app` DNS/TLS + Pages custom domain (human step), template-picker dashboard page, per-merchant PWA icons. Items 5/7/8/9 above bite into this.
- **[3.1] Hard separation of merchant vs customer auth identities** — routing split is done; DB-level separation pending.
- **[4.2] In-person checkout: attach/invite customer for loyalty** at point of service.
- **[4.3] Receipts: print + PDF + in-person** — email receipt for online orders is DONE; the rest pending (KDS/docket print button follow-up lives here too).
- **[4.4] Installable PWA for the merchant dashboard/KDS** — install prompt + offline shell.
- **[5.1] Storefront mobile checkout polish** — floating cart bar + slide-up sheet (overlaps item 12's hold).
- **[6.3] UI uplift — residual polish** (most shipped 2026-06-02 with the green/gold theme; rebrand-preview decision pending).
- **[6.5] Franchise / multi-location layer** — designed (`docs/FRANCHISE_ARCHITECTURE.md`), build post-onboarding.
- **[sec] `cost_price_cents` out of staff-readable `products`** — gate before enabling retail.
- **[sec] Reviews RLS edge-case audit** — SELECT/UPDATE policy consistency.
- **[sms] Per-merchant SMS productionise** — buy per-merchant ClickSend numbers + shared OTP number; assign via AdminSmsNumbers; consider Cellcast at volume.
- **[pos] POS & in-person payments** — Stripe Terminal Phase 1 / Square Terminal; long-lead blockers (Tap to Pay entitlement, AFSL confirmation, AU Square account + PAAF PDS/FSG).
- **[ops] Rotate exposed keys** — ClickSend, GitHub PATs, Supabase `sbp_`/`sb_secret_`, Anthropic, Resend `re_`/`whsec_` (full list in `docs/SMS_ARCHITECTURE.md` "Remaining").
