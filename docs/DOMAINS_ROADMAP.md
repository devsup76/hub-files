# Domains roadmap — three tiers (decision captured 2026-06-08, build later)

All three sit on ONE foundation: a host→org resolver. `name.woahh.app` (subdomain) is
already coded (`src/lib/tenant.ts` parses `*.woahh.app`). Custom domains add a
`organizations.custom_domain` mapping + an anon `get_org_by_host(host)` RPC + a
`resolveTenant` extension (host isn't predictable → DB lookup). The merchant
dashboard/login always stays on `woahh.app/business`; a domain only serves the public
storefront.

## Tier 1 — `name.woahh.app` (free, default) — BUILT (infra pending)
- Wildcard `*.woahh.app` → Cloudflare Pages; Universal SSL covers one level (single-label slugs).
- Zero cost. Instant. See `docs/MERCHANT_ONBOARDING_RUNBOOK.md`.

## Tier 2 — "Buy a domain through us" (managed, premium) — NOT built
- We register the domain via **Cloudflare Registrar API** (at-cost) → lands in our CF →
  add as a Pages custom domain → auto TLS → same host→org lookup. Zero merchant DNS.
- **Like Shopify/Squarespace domains.** Recurring revenue + lock-in (by convenience).
- Must-handle: **auto-renew tied to billing** (expiry = site dark = the #1 risk),
  **portability** (set merchant as registrant / allow transfer-out — don't hold hostage),
  **trademark/abuse T&Cs**, per-domain cost tracking in the add-on price.

## Tier 3 — "Bring your own domain" (BYOD) — NOT built
- Merchant points their domain at us. Small: `custom_domain` column + `get_org_by_host`
  RPC + `resolveTenant` extension + a Pages custom domain (manual now).
- **At scale: Cloudflare for SaaS (Custom Hostnames API)** — per-domain auto-certs,
  onboard via API (the Shopify/Webflow pattern). Has a per-hostname cost → price the add-on to cover it.
- Wrinkles: apex needs ALIAS/CNAME-flattening or www+redirect; domain-ownership verification.

## Build seam (shared by Tier 2 + 3)
1. `organizations.custom_domain` (+ optional `custom_domains` table) + unique index.
2. anon `get_org_by_host(host)` SECURITY DEFINER RPC (mirrors `get_public_storefront`).
3. `resolveTenant`: non-apex/non-`*.woahh.app` host → RPC → slug/org.
4. Supabase Auth redirect allow-list includes custom domains.
5. Dashboard "Connect / buy a domain" wizard (entitlement-gated) + (Tier 3) Cloudflare-for-SaaS onboarding; (Tier 2) Cloudflare Registrar API + auto-renew billing.

## Pricing posture
- Tier 1 free (default). Tier 2 + Tier 3 = paid add-on (Growth/Enterprise or flat monthly),
  priced to cover CF-for-SaaS / registrar costs with margin. **Build after first-merchant launch.**
