# Schema Drift Reconciliation — 2026-06-10

> Source of truth for the repo↔live schema divergence found on `feat/storefront-platform` (worktree `repo-audit`) against the live DB `pmnyhbhtkcfoozkinieo`.
> Built from three independent analyses (forward-drift / function-blast-radius / reverse-drift) cross-checked against the snapshots `docs/schema/LIVE_SCHEMA_2026-06-10.txt` (516 cols / 40 tables) and `docs/schema/LIVE_FUNCTIONS_2026-06-10.txt` (73 functions). Read-only; no migration has been run as part of writing this.

---

## 1. Executive summary

**The drift.** The repo's migration history (103 migrations) is **not** a faithful description of the live database. Three migrations add columns that were **never applied to prod**, and at least three live objects exist with **no migration backing them at all**. The two directions:

- **Forward drift (repo ahead of live)** — three columns the repo creates that live LACKS: `orders.receipt_token`, `organizations.phone_otp_attempts`, `account_recovery_log.ip`.
- **Reverse drift (live ahead of repo)** — objects in prod with no migration anywhere: `orders.loyalty_awarded` + three functions `award_order_loyalty_points`, `adjust_loyalty_points`, `rls_auto_enable`.

**Why this is the top structural risk on a money path.** PostgreSQL resolves column references inside `CREATE OR REPLACE FUNCTION` bodies **at call time, not at apply time**. So a migration that re-creates an RPC referencing a missing column **applies cleanly and silently**, then throws `42703 undefined_column` the first time a real user calls it. Two of the drifted columns are masked/referenced inside customer-facing, anon-granted RPCs that sit directly on the order and storefront paths — meaning the drift surfaces as a hard error on every storefront page load and every `/order/:id` tracker poll, on the exact surfaces that take money. The mirror risk: a `supabase db reset` / "rebuild from migrations" would **silently destroy** the reverse-drift loyalty objects, which grant points/credit — also money-adjacent.

**What already broke.** Migration `20260609060000_rpc_mask_square_and_counters.sql` re-created `get_public_storefront`, `get_member_org`, and `get_order_by_id` faithfully from the *repo's* expected schema — which still believed `phone_otp_attempts` and `receipt_token` existed. It applied cleanly and then 42703'd live: every storefront load (`get_public_storefront`, anon), the staff dashboard org resolver (`get_member_org`), and the public order tracker (`get_order_by_id`, anon). This was patched by the trailing hotfix `20260610070000_fix_drifted_rpc_columns.sql` (sorts last → authoritative), which re-creates all three RPCs against the **actual live schema**. **But the hotfix only touched the 3 RPCs.** Two edge functions — `owner-verify` and `account-recover` — still reference drifted columns and remain broken against live (see §2).

The `organizations.slug` "drift" raised during triage is a **false positive**: no migration ever adds `organizations.slug`; live has `subdomain_slug` (snapshot line 244) and all code uses `subdomain_slug`.

---

## 2. Full drift table

### Forward drift (repo creates → live lacks)

| # | Drifted column | Added by (NEVER applied to live) | On live? | Blast radius — DB functions / edge fns that 42703 | Anon-facing? |
|---|---|---|---|---|---|
| D1 | `orders.receipt_token` (uuid) | `20260601093000_harden_order_customer_and_receipts.sql:9-10` (`ADD COLUMN IF NOT EXISTS`, backfill, NOT NULL, unique index) | ❌ absent (snapshot lines 204-240) | **`get_order_by_id`** `WHERE receipt_token = p_id` — `20260609060000:199`, `20260610060000_remask_get_order_by_id.sql:44`. Now re-pointed to `WHERE id = p_id` by hotfix `20260610070000:143-149`. No edge fn references it. Frontend reads it with `?? order.id` fallback (`RestaurantStorefront.tsx:639`, `RetailStorefront.tsx:299`, `PublishedStorefront.tsx:437`) → **frontend safe**. | **YES** — public `/order/:id` tracker, polled every 5s |
| D2 | `organizations.phone_otp_attempts` (int) | `20260602101000_owner_otp_attempts.sql:11-12` (`ADD COLUMN IF NOT EXISTS … DEFAULT 0`) | ❌ absent (live has only `phone_otp_hash`/`phone_otp_expires_at`, snapshot 288-289) | **`get_public_storefront`** `r.phone_otp_attempts := NULL` (`20260609060000:91`), **`get_member_org`** same mask, staff branch (`:162`) — both fixed by hotfix `20260610070000:62,118`. **`owner-verify/index.ts` — NOT FIXED:** `.select(…phone_otp_attempts)` line 68 + `.update({…phone_otp_attempts})` lines 105/167/183 + reads 150/166. The `.select` at line 68 runs **before any action branch** → both `send_otp` and `verify_otp` 42703 on live. | **YES** (storefront/tracker); `owner-verify` is owner-only but on the onboarding compliance gate |
| D3 | `account_recovery_log.ip` (text) | `20260602101500_recovery_log_ip.sql:11` (`ADD COLUMN IF NOT EXISTS` + index) | ❌ absent (live table has only id/org_id/email/action/attempted_at/success, snapshot 1-6) | No DB function references it. **`account-recover/index.ts` — NOT FIXED:** `.eq("ip", clientIp)` line 64 (per-IP rate-limit SELECT, runs before branching) + `.insert({… ip})` lines 86/98/117/138 → both `lookup` and `verify` actions 42703 on live. | **YES** — public password-recovery (security-questions) endpoint |

### Reverse drift (live has → repo never creates)

| # | Live object | Type | Evidence | Risk |
|---|---|---|---|---|
| R1 | `orders.loyalty_awarded` (boolean) | column | live snapshot line 234; zero hits across all `migrations/*.sql` + `src/**` + `functions/**` | A `db reset`/rebuild-from-migrations **drops it silently**; loyalty award path is money-adjacent |
| R2 | `award_order_loyalty_points(p_order_id uuid)` | function | `LIVE_FUNCTIONS_2026-06-10.txt:8`; absent from every migration | Hand-created in SQL editor (or stale Lovable migration). Rebuild loses it → callers 42883 |
| R3 | `adjust_loyalty_points(p_customer_id, p_points_delta, p_spend_cents_delta)` | function | `LIVE_FUNCTIONS_2026-06-10.txt:2`; absent from every migration | Same as R2 |
| R4 | `rls_auto_enable()` | function | `LIVE_FUNCTIONS_2026-06-10.txt:54`; absent from every migration | Same; security-relevant (auto-enables RLS) |

**Otherwise clean.** Every other live column on `organizations` (66), `customers` (25), `orders` (37 — only `loyalty_awarded` is orphan) traces to a migration. All three new tables (`square_connections` 11 cols, `payment_refunds` 12 cols, `promo_codes` 11 cols) and `orders.refund_*`/`square_*` are present on live. The six critical money functions (`create_order_with_inventory`, `claim_order_for_response`, `get_gmv_analytics`, `record_order_refund`, `set_refund_status`, plus the 3 patched RPCs) were spot-checked column-by-column and reference **only live-present columns** — they survived solely because their columns happened to be applied, which is exactly what the safety gate (§4) must stop relying on.

---

## 3. Reconciliation decision per drifted object

Three dispositions: **BACKFILL** (additive `ALTER TABLE … ADD COLUMN IF NOT EXISTS` into live — for columns that *should* exist per the design), **RE-BASELINE** (accept live as truth, strip the reference from repo/functions — what the hotfix did for the 3 RPCs), **CAPTURE** (reverse drift — write a migration so the repo can faithfully rebuild prod), **IGNORE** (cosmetic).

### D1 `orders.receipt_token` → **RE-BASELINE** (decision already taken; finalize it)

- **Decision: re-baseline, do NOT backfill.** The hotfix already re-pointed `get_order_by_id` to look up by `orders.id` (the order UUID *is* the public tracker token on this DB), and the frontend already falls back to `order.id`. The receipt-token design (a separate unguessable token distinct from the row UUID) was never deployed and the system works without it.
- **Justification.** Backfilling now would require re-introducing the NOT-NULL + unique-index migration and re-wiring `get_order_by_id` back to `receipt_token` — net new surface for zero current benefit, since `order.id` is already a v4 UUID (unguessable) serving as the token. Re-baselining is lower-risk and matches what's live.
- **Repo cleanup required:** correct the misleading comment in `create_order_with_inventory` (`20260608020000_c1_server_side_order_total.sql:48` "receipt_token via the orders default") — the INSERT column list does NOT include `receipt_token`, so it runs fine, but the comment implies a column that isn't there. Optionally mark `20260601093000` and `20260609060000`/`20260610060000` as superseded by the hotfix in a header comment.

### D2 `organizations.phone_otp_attempts` → **BACKFILL** (the column SHOULD exist)

- **Decision: backfill into live.** Unlike `receipt_token`, this column is **functionally required**: it is the per-org OTP brute-force counter that `owner-verify` uses to enforce `MAX_OTP_ATTEMPTS` (lines 150/166). Re-baselining would mean stripping the rate-limit out of `owner-verify`, which **weakens** the onboarding-compliance security gate. The right reconciliation is to apply the additive column that was simply never run.
- **Justification.** `20260602101000` is already idempotent (`ADD COLUMN IF NOT EXISTS … DEFAULT 0`) and additive — safe to apply to live now. Once applied, both the (already-hotfixed) RPCs and the **un-fixed `owner-verify` edge fn** stop 42703'ing, and the brute-force counter works as designed. This is the cleaner fix than mutilating the edge function.
- **Order note:** the RPC masks for this column were already removed by the hotfix (they set it to NULL anyway), so backfilling the column is harmless to the RPCs and *restores* `owner-verify`.

### D3 `account_recovery_log.ip` → **BACKFILL** (the column SHOULD exist)

- **Decision: backfill into live.** `account-recover` uses `ip` for a per-IP rate limit (line 64) and forensic logging (4 inserts). This is a real abuse-prevention control on a **public** endpoint; re-baselining would remove per-IP throttling from password recovery — a security regression.
- **Justification.** `20260602101500` is additive (`ADD COLUMN IF NOT EXISTS` + index) and was simply never applied. Applying it restores both the `lookup` and `verify` actions (currently fully broken on live) and the abuse control. Backfill is strictly safer than stripping the throttle.

### R1–R4 reverse drift → **CAPTURE** (write the missing migrations)

- **Decision: capture into the repo.** `orders.loyalty_awarded` + `award_order_loyalty_points` + `adjust_loyalty_points` + `rls_auto_enable` exist in prod but cannot be reproduced from migrations. Add idempotent capture migrations (`ADD COLUMN IF NOT EXISTS` for the column; `pg_get_functiondef` dumps wrapped in `CREATE OR REPLACE FUNCTION` for the three functions).
- **Justification.** Until captured, the migration history is **not** a faithful source of truth — any future `db reset` or fresh-environment rebuild silently loses a money-adjacent loyalty path and an RLS helper. This is the inverse of the forward-drift bug and is the one remaining way the same class of incident recurs. Capture is additive and risk-free (the objects already exist live, so re-applying definitions is a no-op there).

### `organizations.slug` → **IGNORE** (not a drift)

- Not a real drift — no migration adds it; live has `subdomain_slug` and all code uses `subdomain_slug`. Nothing to do. (Any bare `organizations.slug` reference would be a code bug to fix, not a missing migration — none exist.)

---

## 4. Safety gate going forward

There is currently **no `.github/workflows/`, no smoke test, no `db diff` gate, no schema-snapshot compare** anywhere in the repo. The root cause — `CREATE OR REPLACE FUNCTION` deferring column resolution to call time — needs a gate that actually **calls** the RPCs against a freshly-migrated DB. Four layers, in priority order:

### Gate 1 — Post-migration RPC smoke test (catches the `42703`-at-runtime class directly)

After `supabase db reset` on a CI shadow DB (or against staging), **call every public RPC once** and assert none returns SQLSTATE `42703` (undefined_column) / `42P01` (undefined_table). The assertion is **not** "did it return data" — it is "did it raise a missing-column/table error" — because a drifted RPC applies cleanly and only errors on the first real call. Cover all anon/authenticated-granted RPCs (`get_public_storefront`, `get_public_menu`, `get_public_storefront_config`, `get_public_ingredient_shortages`, `get_order_by_id`, `get_member_org`, `get_gmv_analytics`, `get_reservation_by_token`, the customer-invite set, …) plus the service-role money RPCs (`record_order_refund`, `set_refund_status`, `claim_order_for_response`). This single test would have failed the build the moment `20260609060000` referenced `phone_otp_attempts`/`receipt_token`. Script in §5.

### Gate 2 — Schema-snapshot compare (catches drift in BOTH directions)

Keep `docs/LIVE_SCHEMA_*.txt` + `docs/LIVE_FUNCTIONS_*.txt` as the canonical live baseline (regenerated read-only on a cadence). On every PR touching `supabase/migrations/`, dump the shadow DB schema in the same format and `diff` against the committed snapshot; fail/warn-and-ack on any delta:
- **repo-ahead lines** (e.g. a new `ADD COLUMN`) → "is this actually applied to live? if not, functions referencing it will 42703."
- **live-ahead lines** (e.g. `orders.loyalty_awarded`, the 3 loyalty/RLS functions) → "prod has objects the repo can't rebuild → a `db reset` destroys them." This is the reverse-drift detector.

`supabase db diff --linked --schema public` is the off-the-shelf version; the snapshot-format diff is the zero-infra fallback.

### Gate 3 — Verify-against-live rule for any migration touching an existing function

PR-checklist + lint: any migration with `CREATE OR REPLACE FUNCTION` for a function **already in `LIVE_FUNCTIONS`** that projects a wide row (`RETURNS <table>` / `SETOF <table>`) or references `<table>.<column>` must list every column it touches and confirm each exists in `LIVE_SCHEMA_*.txt`. This is the exact failure the masking migrations hit — they re-created RPCs from the repo's expected schema without checking the columns were on **live**. Longer-term, move the full-row-projection RPCs (`get_public_storefront`, `get_member_org`, `get_order_by_id`, `get_public_menu`) to **explicit allowlist column projection** (the deferred IMP-1 fix) so a `RETURNS public.<table>` can never re-bind to a drifted shape.

### Gate 4 — Capture reverse drift before the next rebuild

Treat the migration history as authoritative only after R1–R4 are captured (see §3). Until then, never run `db reset` against prod.

---

## 5. Immediate action plan

### Step 1 — One safe "align" migration (the clear backfills + reverse-drift capture)

`20260610080000_align_schema_drift.sql` — a single idempotent, additive migration. **No drops, no NOT-NULL, no data backfill beyond defaults.**

```sql
-- 20260610080000_align_schema_drift.sql
-- Reconcile repo↔live drift (see docs/schema/SCHEMA_DRIFT_RECONCILIATION.md). Idempotent + additive.

-- D2: OTP brute-force counter that owner-verify requires (decision: BACKFILL)
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS phone_otp_attempts integer NOT NULL DEFAULT 0;

-- D3: per-IP throttle/forensics for account-recover (decision: BACKFILL)
ALTER TABLE public.account_recovery_log
  ADD COLUMN IF NOT EXISTS ip text;
CREATE INDEX IF NOT EXISTS account_recovery_log_ip_idx
  ON public.account_recovery_log (ip, attempted_at);

-- R1: capture reverse-drift column so a rebuild can't drop it (decision: CAPTURE)
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS loyalty_awarded boolean;

-- R2–R4: capture reverse-drift functions. Replace each body below with the live
--        pg_get_functiondef() output BEFORE running (do NOT invent the bodies):
--   SELECT pg_get_functiondef('public.award_order_loyalty_points(uuid)'::regprocedure);
--   SELECT pg_get_functiondef('public.adjust_loyalty_points(uuid,integer,integer)'::regprocedure);
--   SELECT pg_get_functiondef('public.rls_auto_enable()'::regprocedure);
-- Paste each as CREATE OR REPLACE FUNCTION ... (no-op on live, authoritative for rebuilds).
```

> **D1 (`receipt_token`) is intentionally NOT in this migration** — it's RE-BASELINE: the hotfix `20260610070000` already aligned `get_order_by_id` to `orders.id`. No DB change needed; only the misleading comment cleanup in `20260608020000:48`.

### Step 2 — Add the smoke-test script (`scripts/rpc-smoke.ts`)

Runs in CI after `supabase db reset` on a shadow DB. Fails the build on any drift-class error.

```ts
// scripts/rpc-smoke.ts — assert no public RPC raises 42703/42P01 against a freshly-migrated DB.
const NIL = "00000000-0000-0000-0000-000000000000";
const PROBES: Array<[string, Record<string, unknown>, "anon"|"auth"|"service"]> = [
  ["get_public_storefront",           { p_slug: "__smoke__" }, "anon"],
  ["get_public_menu",                 { p_org_id: NIL },        "anon"],
  ["get_public_storefront_config",    { p_slug: "__smoke__" }, "anon"],
  ["get_public_ingredient_shortages", { p_org_id: NIL },        "anon"],
  ["get_order_by_id",                 { p_id: NIL },            "anon"],
  ["get_reservation_by_token",        { p_token: NIL },         "anon"],
  ["get_member_org",                  {},                       "auth"],
  ["get_gmv_analytics",               { p_days: 7 },            "auth"],
  ["record_order_refund", { p_order_id: NIL, p_provider: "stripe",
      p_provider_refund_id: "smoke", p_amount_cents: 1 },       "service"],
  ["set_refund_status", { p_provider: "stripe",
      p_provider_refund_id: "smoke", p_status: "failed" },      "service"],
  ["claim_order_for_response", { p_order_id: NIL, p_action: "confirm" }, "service"],
  // …extend to ALL anon/authenticated-granted RPCs from the GRANT scan.
];

let failed = false;
for (const [fn, args, role] of PROBES) {
  const { error } = await clientFor(role).rpc(fn, args);
  // "no rows / not found / business-rule" errors are FINE. Schema-drift errors are NOT.
  if (error && (error.code === "42703" || error.code === "42P01" ||
      /column .* does not exist|relation .* does not exist/i.test(error.message))) {
    console.error(`SCHEMA DRIFT: ${fn} -> ${error.code} ${error.message}`);
    failed = true;
  }
}
process.exit(failed ? 1 : 0);
```

### Step 3 — Order of operations

1. **Apply the align migration** (`20260610080000_align_schema_drift.sql`) to live in the Supabase SQL editor — *after* pasting the three real `pg_get_functiondef` bodies into R2–R4. (Backfilling D2/D3 unblocks the two still-broken edge functions immediately.)
2. **Redeploy `owner-verify` + `account-recover`** edge functions — no code change needed (the columns they expect now exist); just confirm they no longer 42703 (test `send_otp`/`verify_otp` and `lookup`/`verify`).
3. **Confirm the hotfix `20260610070000` is the last-applied definition** of `get_public_storefront` / `get_member_org` / `get_order_by_id` on live (it sorts last; verify via `pg_get_functiondef` that none reference `phone_otp_attempts`/`receipt_token`). If an older masking migration was applied *after* the hotfix, re-run the hotfix.
4. **Regenerate `types.ts`** + re-snapshot `docs/schema/LIVE_SCHEMA_2026-06-10.txt` / `LIVE_FUNCTIONS_2026-06-10.txt` to reflect the now-aligned schema.
5. **Land the smoke test + snapshot-diff gate** in CI (Gates 1 & 2) so the next drift fails the build, not prod.
6. **Cleanup** the misleading `receipt_token` comment in `20260608020000:48`.

---

## Appendix — key file:line references

- Forward-drift adds (never applied): `20260601093000_harden_order_customer_and_receipts.sql:9-10` (D1); `20260602101000_owner_otp_attempts.sql:11-12` (D2); `20260602101500_recovery_log_ip.sql:11` (D3).
- Broke-in-prod refs: `20260609060000_rpc_mask_square_and_counters.sql:91,162,199`; `20260610060000_remask_get_order_by_id.sql:44`.
- Authoritative hotfix (sorts last): `20260610070000_fix_drifted_rpc_columns.sql:62,118,143-149`.
- Still-broken edge fns: `supabase/functions/owner-verify/index.ts:68,105,150,166-167,183` (D2); `supabase/functions/account-recover/index.ts:64,86,98,117,138` (D3).
- Reverse-drift objects: `docs/schema/LIVE_SCHEMA_2026-06-10.txt:234` (`orders.loyalty_awarded`); `docs/schema/LIVE_FUNCTIONS_2026-06-10.txt:2,8,54` (`adjust_loyalty_points`, `award_order_loyalty_points`, `rls_auto_enable`).
- Money functions verified clean: `20260608020000_c1_server_side_order_total.sql` (+ comment fix at `:48`); `20260609040000_respond_to_order_claim.sql:50`; `20260610040000_gmv_analytics_rpc.sql:88`; `20260610050000_order_refunds.sql:79-98,137,287`.
- Missing tooling confirmed: no `.github/workflows/`, no smoke/diff scripts in `repo-audit`.
