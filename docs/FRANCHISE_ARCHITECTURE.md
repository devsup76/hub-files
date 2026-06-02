# Franchise / Multi-Location Architecture for woahh

> **Status: PLANNED — build later (post-onboarding). Not yet implemented.**
> Design approved 2026-06-02. Strictly additive (only ADD tables/columns/policies; never re-key or drop). Build in `repo/` when scheduled; deploy each DB stage before its dependent frontend. Every stage is independently shippable and dormant until a `franchise_id` is set.

## Context

woahh's pricing already advertises multi-location tiers ("up to 3 / 7 / unlimited locations"), but **no franchise or location concept exists in the product** — it's marketing copy only. We want brand owners to manage several restaurants together (combined insights, an org-switcher, per-location staff) and individually, with customer-facing brand unity (configurable shared loyalty, franchise-wide campaigns).

Hard requirement from the founder: **implement later, after real merchants are onboarded, with a strictly ADDITIVE migration — only add tables/columns/policies, never re-key or drop existing data.**

Investigation confirms this is achievable. Every one of ~30 tables is scoped by `organization_id`, and there is no existing franchise/location concept to conflict with — so a franchise layer sits **above** organizations. Each location stays its own `organizations` row. Standalone merchants (with `franchise_id = NULL`) are byte-for-byte unaffected. Crucially, the cross-merchant identity system we need for shared loyalty/campaigns **already exists** (`growthhub_profiles` + `merchant_connections` + `merge_customer_connections`) and is reused, not rebuilt.

### Decisions locked with founder
- **Control:** Read-only oversight first (franchise owner sees + drills into all locations; editing stays local). Central push-to-locations is a reserved later phase (`can_write` flag added but default false).
- **Loyalty:** Configurable per brand (each franchise chooses shared vs per-location; standalone untouched).
- **Campaigns:** Franchise-wide + per-location.
- **Staff:** Configurable per merchant — a **manager** can be franchise-wide or store-limited; **service/kitchen stay per-store** for now.

## Current state (the constraints to design around)

- `organizations.owner_id` is **`NOT NULL UNIQUE`** → one user owns exactly one org. (We do NOT relax this.)
- `staff_accounts.user_id` is **`UNIQUE`** → one user staffs exactly one org. (We do NOT relax this.)
- `current_org_id()` (SECURITY DEFINER, no `auth.users` join) returns **one** org; all RLS scopes to a single org via `organization_id = current_org_id()` or inline `EXISTS(staff_accounts/organizations ...)`.
- Frontend resolves the single org via `useOrg()` → `orgApi.getMine()`; **no org-switcher exists**. Per-org pages already pass an explicit `orgId` into `.eq("organization_id", orgId)` (see `Analytics.tsx`, `api.ts`).
- Lovable gotchas: `handle_new_user_org()` auto-creates an org on every `auth.users` insert (skips `kind='staff'`); SECURITY DEFINER funcs used in RLS must **not** join `auth.users`.

## Architecture: cross-org access by MEMBERSHIP, not OWNERSHIP

Keep `owner_id UNIQUE` and `staff_accounts.user_id UNIQUE` exactly as-is. A franchise owner/manager gains *visibility* into sibling locations through a new **`franchise_members`** overlay, and RLS gets **additional permissive (OR-combined, grant-only) policies** layered on top of existing single-org policies — never replacing them. Because existing rows have `franchise_id = NULL` and non-members match none of the new policies, standalone behavior is unchanged.

This sidesteps every blocker: no relaxed constraints, no change to `current_org_id()` semantics, no `auth.users` joins in new RLS helpers.

## Additive schema

### Merchant-side
```sql
CREATE TABLE public.franchise_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text UNIQUE,
  logo_url text,
  created_by uuid NOT NULL,
  tier text,                              -- optional franchise-level plan
  shared_loyalty_enabled boolean NOT NULL DEFAULT false,
  franchise_loyalty_config jsonb,         -- same shape as organizations.loyalty_config
  location_limit int,                     -- soft, checked only at add-location time (later)
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.organizations
  ADD COLUMN franchise_id uuid REFERENCES public.franchise_groups(id);  -- NULL = standalone (default)
CREATE INDEX idx_organizations_franchise_id ON public.organizations(franchise_id) WHERE franchise_id IS NOT NULL;

-- user <-> franchise overlay: grants cross-org reach WITHOUT ownership/staff rows
CREATE TABLE public.franchise_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  franchise_id uuid NOT NULL REFERENCES public.franchise_groups(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'franchise_owner'
       CHECK (role IN ('franchise_owner','franchise_admin','franchise_manager','franchise_viewer')),
  can_write boolean NOT NULL DEFAULT false,   -- reserved for central-management phase
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (franchise_id, user_id)
);
CREATE INDEX idx_franchise_members_user ON public.franchise_members(user_id) WHERE is_active;
```

### Customer-side (loyalty + campaigns)
```sql
-- Shared loyalty balance keyed on the cross-org identity (profile_id), NOT customer_id.
CREATE TABLE public.franchise_loyalty_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  franchise_id uuid NOT NULL REFERENCES public.franchise_groups(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  points_balance int NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
  milestone_spend_cents bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (franchise_id, profile_id)
);
-- Append-only audit + idempotency (prevents double-credit on retry/double-click).
CREATE TABLE public.franchise_loyalty_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES public.franchise_loyalty_accounts(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL REFERENCES public.organizations(id),
  delta_points int NOT NULL,
  delta_spend_cents bigint NOT NULL DEFAULT 0,
  reason text NOT NULL,                 -- earn_online|earn_instore|redeem|birthday|migration_seed
  order_id uuid,
  idempotency_key text UNIQUE,          -- 'order:'||order_id  or  'instore:'||code||':'||org
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Franchise-wide campaigns: nullable franchise_id; NULL = today's per-org campaign (unchanged).
ALTER TABLE public.sms_campaigns   ADD COLUMN franchise_id uuid REFERENCES public.franchise_groups(id);
ALTER TABLE public.email_campaigns ADD COLUMN franchise_id uuid REFERENCES public.franchise_groups(id);
```

## RLS pattern (additive, grant-only)

Helper (SECURITY DEFINER, `public`-only, **no `auth.users` join** — mirror `current_org_id()` in `20260529040000`):
```sql
CREATE FUNCTION public.franchise_org_ids() RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT o.id FROM public.organizations o
  JOIN public.franchise_members fm ON fm.franchise_id = o.franchise_id
  WHERE o.franchise_id IS NOT NULL AND fm.user_id = auth.uid() AND fm.is_active;
$$;
-- + franchise_org_ids_writable() (adds AND fm.can_write) reserved for the write phase.
```
Add one extra SELECT policy per reporting-relevant table (`orders`, `order_items`, `products`, `customers`, `reviews`, `sms_campaigns`, `email_campaigns`), applied table-by-table as insights need them:
```sql
CREATE POLICY "Franchise members read org orders" ON public.orders
FOR SELECT USING (organization_id IN (SELECT public.franchise_org_ids()));
```
Postgres OR-combines permissive policies, so this only *grants*; existing per-org policies and standalone merchants are untouched. Sibling-org listing for the switcher goes through a **masked** RPC (`my_franchise_orgs()` returning non-PII columns), mirroring the `get_member_org()` PII-masking pattern — so we avoid exposing owner PII on sibling rows.

## Frontend: org-switcher + franchise dashboard

Pivotal fact: dashboard reads don't depend on `current_org_id()` — pages consume `useOrg().id` and pass it explicitly. So the switcher = **client-side selection of which org `useOrg()` returns**, and the new read policies make cross-org reads succeed.
- `useActiveOrg` state in `localStorage` (`woahh.activeOrgId`), default = primary org from `getMine()`.
- Extend `useOrg()` to honor `activeOrgId` (fetch that org via the masked-by-id RPC). **Existing per-org pages need zero changes.**
- Switcher dropdown in `DashboardLayout.tsx`: lists locations from `my_franchise_orgs()` + a "Franchise view" sentinel. **Hidden entirely unless `my_franchise_orgs()` returns >1** → standalone users see today's UI exactly.
- New `src/pages/dashboard/FranchiseDashboard.tsx` (new route, additive): reuses the `Analytics.tsx` pattern but `.in("organization_id", ids)` for combined revenue/orders/top-products + a per-location comparison table. Heavy roll-ups via a `franchise_revenue_summary(from,to)` SECURITY DEFINER RPC.
- Franchise CRM roll-up: `franchise_customers(franchise_id)` RPC built on `merchant_connections` + `growthhub_profiles`, deduped by `profile_id`.

## Loyalty (configurable per brand)

`effective_loyalty(org)` resolver returns `mode = 'franchise'` only when the org's `franchise_groups.shared_loyalty_enabled` is true, else `'standalone'`. Route all point writes through new SECURITY DEFINER RPCs that branch on it:
- `award_loyalty(...)` — online earn (replaces the direct `customers.update` in `customerAccount.ts:awardPoints`).
- `apply_loyalty_delta(...)` — in-store earn/redeem (replaces `Loyalty.tsx:updatePoints`); authorized via `is_staff_of_org` like `validate_loyalty_code`.

Standalone branch = today's exact `customers.total_points` write (never consults franchise tables, since `franchise_id IS NULL`). Franchise branch = ledger insert (idempotent) + `franchise_loyalty_accounts.points_balance` update, keyed on `profile_id` so earn-at-A / redeem-at-B works. Turning a franchise on does a one-time additive **seed**: sum each location's per-customer `total_points` into a `migration_seed` ledger row per profile, leaving `customers.total_points` intact. `validate_loyalty_code` extended to also return the shared balance for the validator panel; the rotating in-store code stays minted per-location (scanned at a physical till) but displays the shared balance.

## Campaigns (franchise-wide + per-location)

`franchise_id IS NULL` = unchanged per-org campaign. When set (composer shows a "Send franchise-wide" toggle only to the franchise owner): audience resolves to **distinct profiles** across the franchise's orgs via `merchant_connections`, deduped by person, with audience predicates (lapsed/high-value/birthday) aggregated franchise-wide. **Consent stays per-location** (Spam Act): a profile is eligible only where they explicitly consented, and the message is **sent from that location's registered `sms_number` / email sender** so STOP/opt-out routing and `sms-webhook` semantics stay intact. A profile connected to several locations gets exactly one message from a deterministic "home location" (most recent order → earliest connection). Usage charged to the sending location's quota. Per-location `*_log` reporting unchanged (still keyed by `organization_id`). Main edge-function change is the audience resolver in `sms-send` / `email-send`.

## Staff model (configurable)

Keep `staff_accounts.user_id UNIQUE`. Map the founder's rules onto roles:
- **Service / kitchen:** per-store only → existing `staff_accounts` rows (no change).
- **Manager, store-limited:** existing `staff_accounts` manager row (no change).
- **Manager, franchise-wide:** a `franchise_members` row with `role='franchise_manager'` — cross-store reach via the membership overlay, manager-level effective permissions, **no** per-store staff rows (so the UNIQUE constraint is never hit). At "invite manager" time the owner picks "this location" (→ staff_accounts) vs "all locations" (→ franchise_members). Service/kitchen UI offers only "this location."
- Map franchise roles → effective dashboard permissions in `useRole.ts` (`franchise_owner/admin` → owner-ish read; `franchise_manager` → manager read) so existing permission gating keeps working.

## The one non-additive item (and how it's handled)

Creating a **pure franchise-admin** auth account (someone who should NOT own a flagship org) requires `handle_new_user_org()` to skip org creation — today it only skips `kind='staff'`. This is a **function update** (add a `kind='franchise'` skip branch), not data loss, and only matters for new franchise-admin accounts. Founders who also own a flagship location use the normal path. Everything else in the plan is pure ADD.

## Staged rollout (each stage additive + independently shippable)

1. **Schema only** — `franchise_groups`, `franchise_members`, `organizations.franchise_id` (NULL), indexes, RLS on the two new tables. Zero behavior change (all orgs `franchise_id NULL`).
2. **Read helpers + masked RPCs** — `franchise_org_ids()`, `my_franchise_orgs()`, `franchise_revenue_summary()`, `franchise_customers()`. No table policies yet.
3. **Additive READ policies** — add per-table SELECT policies for franchise members (deploy migrations *before* frontend).
4. **Frontend** — `useActiveOrg`, extend `useOrg()`, switcher in `DashboardLayout.tsx`, `FranchiseDashboard.tsx`, franchise CRM view. Hidden unless >1 location.
5. **Loyalty indirection (behavior-preserving)** — `effective_loyalty`, `award_loyalty`, `apply_loyalty_delta`; migrate the two client write paths. With all franchises off, behavior is identical.
6. **Shared loyalty** — loyalty account/ledger tables + config + one-time seed; flip `shared_loyalty_enabled` per franchise; Account hub + storefront + validator show shared balance.
7. **Franchise campaigns** — `franchise_id` on campaign tables + composer toggle + deduped/per-location-consent audience resolver in `sms-send`/`email-send`.
8. **Customer-facing polish** — Account hub brand grouping, "Part of <brand>" storefront badge, computed franchise rating rollup.
9. **(Later, opt-in) Central management** — `franchise_org_ids_writable()` + `can_write`-gated FOR ALL policies; audit `current_org_id()`-derived write RPCs first.
10. **(Later) Tier/billing** — bill the franchise via `franchise_groups.tier`; soft `location_limit` checked only at add-location time (never as an RLS deny).

## Risks & edge cases
- **Phantom-org trigger** — handle the `kind='franchise'` skip before creating franchise-admin accounts (see above).
- **`current_org_id()` single-org assumption** — safe for reads (pages pass explicit orgId); must be audited before any cross-org *write* (stage 9). Switcher must not rely on it for writes to non-owned locations.
- **Sibling-org PII** — switcher/CRM use masked SECURITY DEFINER RPCs, not a direct `organizations` SELECT policy.
- **Guest-only customers** (no profile) — appear per-location until signup; `merge_customer_connections` folds them in retroactively. Shared balance accrues once a profile exists. Matches today's post-order magic-link claim.
- **Double-credit** — `franchise_loyalty_ledger.idempotency_key` guards earns; the standalone branch can reuse the order-id guard for a correctness win.
- **Consent leakage** — never inferred across locations; sender of record is always a location the person opted into.
- **Demo mode** — `isDemoMode()` short-circuits many queries; hide franchise UI in demo.
- **Deploy ordering** — helpers/policies (stages 2–3) before frontend (stage 4); replicate `getMine()`'s missing-RPC defensiveness in the switcher.

## Verification
- **Additivity proof:** after stage 1–3 migrations on a copy of prod data, assert every existing `organizations.franchise_id IS NULL`, no existing policy/row changed, and a standalone merchant's dashboard + a `service`/`manager` staff login behave identically (browser smoke test + the test merchant `pawitsingh23+merchant@gmail.com`).
- **Franchise happy path (staging):** create a `franchise_groups` row, set `franchise_id` on 2 test orgs, add a `franchise_members` owner → switcher shows both + "Franchise view"; `FranchiseDashboard` shows combined + per-location numbers; drill into each location read-only.
- **Cross-org isolation:** a franchise owner of brand X gets **0 rows** from brand Y's orders via raw REST; a standalone merchant sees no switcher and no cross-org rows.
- **Shared loyalty:** with `shared_loyalty_enabled`, earn at location A (online) then redeem at B (in-store) → one `franchise_loyalty_accounts` balance moves; replay the same order id → no double credit (idempotency). With it off, points still land on `customers.total_points`.
- **Franchise campaign:** a person who is a customer at A and B, consented only at A, receives exactly one SMS from A's number; a STOP reply flips only A's `customers.sms_opted_out`.
- **Staff:** invite a franchise-wide manager (→ `franchise_members` `franchise_manager`) and a store-limited manager (→ `staff_accounts`); confirm reach differs and `staff_accounts.user_id UNIQUE` is never violated; service invite offers only "this location."

## Critical files
- `repo/supabase/migrations/20260529040000_fix_phantom_staff_orgs.sql` — `current_org_id()`/`my_org_id()` + the `handle_new_user_org()` skip pattern to extend (`kind='franchise'`).
- `repo/supabase/migrations/20260529080000_org_pii_isolation_for_staff.sql` — `get_member_org()` PII-masking pattern to mirror in `my_franchise_orgs()`/`franchise_customers()`.
- `repo/supabase/migrations/20260425120106_*.sql` — `growthhub_profiles` / `merchant_connections` / `merge_customer_connections` (reuse as the franchise identity foundation).
- `repo/supabase/migrations/20260531000000_sms_provisioning_and_consent.sql` + `repo/supabase/functions/sms-send/index.ts` — per-merchant number/consent; franchise-wide audience resolver.
- `repo/src/hooks/useOrg.ts`, `repo/src/services/api.ts` — switcher pivot + the explicit-orgId query pattern.
- `repo/src/pages/dashboard/Analytics.tsx` — pattern to generalize to `.in(...)` for `FranchiseDashboard.tsx`.
- `repo/src/pages/dashboard/Loyalty.tsx`, `repo/src/services/customerAccount.ts` — loyalty write paths to route through the new RPCs.
- `repo/src/hooks/useRole.ts` — map franchise roles → effective dashboard permissions.

> Note: build in `repo/` (Lovable-managed). All migrations are new, additive files — never edit existing migrations. Deploy DB stages before their dependent frontend.
