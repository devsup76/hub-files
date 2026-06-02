# ☀️ Morning handoff — 2026-05-31 night → 06-01

Hi pawit. Per-merchant SMS is **built, deployed, and verified end-to-end** on the new backend
(send + STOP/opt-out). The pre-merge gate check caught real issues — most fixed, **two need you
to run one SQL block** (live DB), then I merge. Full detail: `docs/SMS_ARCHITECTURE.md`.

---

## 🔴 DO THIS FIRST — close two live security holes (~2 min)

The gate check + live attack tests found **two admin functions whose auth gate fails OPEN** for
unauthenticated callers (`(auth.jwt()->>'email') <> 'admin'` is NULL-unsafe: a caller with no email
claim slips past). Confirmed exploitable by **anon**:
- `admin_assign_sms_number` — an anon could reassign/hijack any merchant's SMS number.
- `generate_founding_codes` — an anon could mint **permanent zero-commission founding codes**. ← worst one.

Both are on the **new** backend (`pmnyhbhtkcfoozkinieo`). ⚠️ The founding one is also in `main`, so if
the **old Lovable Supabase is still serving woahh.app**, run this there too (Lovable SQL editor).

**Supabase → SQL Editor → New query → paste ALL of this → Run** (idempotent, no data changes):

```sql
-- 1. SMS: NULL-safe admin gate + revoke PUBLIC execute
CREATE OR REPLACE FUNCTION public.admin_assign_sms_number(p_org uuid, p_number text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_clean text; v_cap int;
BEGIN
  IF (auth.jwt() ->> 'email') IS DISTINCT FROM 'pawitsingh23@gmail.com' THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  v_clean := nullif(trim(p_number), '');
  IF v_clean IS NULL THEN RAISE EXCEPTION 'A phone number is required'; END IF;
  SELECT sms_monthly_cap INTO v_cap FROM public.organizations WHERE id = p_org;
  IF NOT FOUND THEN RAISE EXCEPTION 'Organization not found'; END IF;
  IF COALESCE(v_cap,0)=0 THEN RAISE EXCEPTION 'This organization is not on an SMS-enabled tier (Marketplace or higher)'; END IF;
  IF EXISTS (SELECT 1 FROM public.organizations WHERE sms_number=v_clean AND id<>p_org) THEN
    RAISE EXCEPTION 'That number is already assigned to another organization'; END IF;
  UPDATE public.organizations SET sms_number=v_clean WHERE id=p_org;
END; $$;
REVOKE EXECUTE ON FUNCTION public.admin_assign_sms_number(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_assign_sms_number(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.set_sms_consent(uuid, boolean) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.set_sms_consent(uuid, boolean) TO authenticated;

-- 2. Founding codes: same NULL-safe fix + revoke PUBLIC execute
CREATE OR REPLACE FUNCTION public.generate_founding_codes(p_count int, p_note text DEFAULT NULL)
RETURNS SETOF public.founding_access_codes
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE i int; v_code text; v_row public.founding_access_codes;
BEGIN
  IF (auth.jwt() ->> 'email') IS DISTINCT FROM 'pawitsingh23@gmail.com' THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF p_count IS NULL OR p_count < 1 OR p_count > 100 THEN
    RAISE EXCEPTION 'Count must be between 1 and 100'; END IF;
  FOR i IN 1..p_count LOOP
    LOOP
      v_code := 'WOAHH-' || upper(substr(md5(random()::text || clock_timestamp()::text),1,6));
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.founding_access_codes WHERE code=v_code);
    END LOOP;
    INSERT INTO public.founding_access_codes (code, note) VALUES (v_code, p_note) RETURNING * INTO v_row;
    RETURN NEXT v_row;
  END LOOP;
END; $$;
REVOKE EXECUTE ON FUNCTION public.generate_founding_codes(int, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.generate_founding_codes(int, text) TO authenticated;
```

Then tell me **"security SQL run"** and I'll re-run the anon attack tests to confirm both now return
"Not authorized", then proceed to the merge. ✅ **The overnight sweep finished — the SQL block above
already closes every confirmed live-exploitable hole.** Nothing more needs adding to it; the rest is
hardening (see "Security sweep" section at the bottom).

---

## ✅ Already done (no action needed)
- Per-merchant SMS **built + audit-fixed (14 findings) + deployed** to `pmnyhbhtkcfoozkinieo`.
- Secrets set: `CLICKSEND_USERNAME/API_KEY`, `WOAHH_SMS_NUMBER`, `SMS_WEBHOOK_SECRET`.
- **Verified end-to-end:** campaign send + STOP/opt-out (dedicated number `+61455725154`, ClickSend
  inbound rule `2327822` → `sms-webhook`; confirmation SMS logged; `sms_opted_out` flipped, scoped to merchant).
- Migration `20260531000000` applied to the live DB (then the security fix above re-hardens it).
- Branch **`feat/per-merchant-sms`** pushed (now complete — includes the previously-untracked
  `_shared/sms.ts` + the migration; `main` would have broken without them).
- Persistent memory (Option 2 devcontainer hook) + all docs updated.

## ⏭️ The merge (after you run the security SQL)
1. You run the SQL above → tell me.
2. I re-test (anon blocked) → **merge `feat/per-merchant-sms` → `main`** (fast-forward + push). The
   CI workflow isn't on the remote, so the merge does NOT auto-deploy — code only.
3. A second branch (`fix/admin-gate-null-safety`, for the founding migration as tracked code) is
   ready to merge too.

## 📋 Productionising (later, not blocking the merge)
- Each real merchant needs its own dedicated ClickSend number → assign via **AdminSmsNumbers**
  (`/business/dashboard/admin/sms`, now routed). `admin_assign_sms_number` + the ClickSend inbound-rule
  API call can be scripted per merchant.
- Enable GitOps: add `.github/workflows/supabase-deploy.yml` to the remote (needs a `workflow`-scoped
  GitHub PAT) so `supabase/` changes auto-deploy on merge.
- Cellcast is ~½ ClickSend's per-SMS cost — drop-in via the `SMS_PROVIDER` flag when volume grows.

## 🔒 Rotate today (keys exposed in chat during setup)
- ClickSend API key · both GitHub PATs (in the git remote URLs) · the Supabase tokens (`sbp_` + `sb_secret_`).

## 🧹 Test-state notes
- Test Bistro (`35cf67fb…`) `sms_number = +61455725154`; your mobile customer is opted-out (STOP test).
- Test-merchant password was set to the documented `WoahhTest2026!`.

## Security sweep — results (run `wf_2a109cbd-20e`, 3 agents, triaged)

**Bottom line: the only new live-exploitable bug was `generate_founding_codes` — already in the SQL
block above. The morning SQL closes every confirmed hole.** The rest is hardening / defense-in-depth.

**Confirmed false positives (no action):**
- `sms_log` RLS — has a proper org-scoped `SELECT` policy (`organization_id = current_org_id()`); no cross-tenant read. Edge-fn writes use service-role by design.
- `sms-send` bearer compare — exact `===`, not bypassable.
- "Missing `REVOKE FROM PUBLIC`" on `unsubscribe_email_by_token`, `redeem_founding_code`, `release_founding_code`, `accept/decline_customer_invite`, `create_public_reservation`, `get_order_by_id`, `cancel_reservation_by_token`, `get_reservation_by_token`, `create_order_with_inventory`, `get_public_storefront/menu`, `get_customer_invite` — these are **intentionally anon-callable** (token/flag-gated public RPCs), so PUBLIC ≈ anon. No escalation; defense-in-depth only.

> **UPDATE 2026-06-02:** backlog #1–#3 below are now **implemented** on branch
> `security/sms-hardening-backlog` (off `origin/main`) — not yet pushed/deployed/applied to the live DB.
> Details + remaining deploy steps in `docs/SMS_ARCHITECTURE.md` → "Hardening #1–#3 IMPLEMENTED". #4 still open.

**Real hardening backlog (NOT live-exploitable — review when convenient, does NOT block the merge), prioritised:**
1. **`owner-verify` OTP brute-force** — the owner phone OTP (6-digit) has no attempt counter / lockout. Add one mirroring `staff-pin-login` (5 attempts → 15-min cooldown). *Highest priority of the backlog.*
2. **`reservation-remind:59`** — uses `auth.includes(SERVICE_KEY)` (substring) vs `=== SERVICE_KEY` everywhere else; fails open only if `SERVICE_KEY` were empty (never in prod). 1-line fix to match the others.
3. **`sms-webhook` hardening** — make the secret gate fail-CLOSED when `SMS_WEBHOOK_SECRET` is unset (it's set now, so enforced); guard against empty/NULL inbound `to` before the org lookup; drop the raw-payload `console.log` at line 62 (logs phone + message body = PII).
4. **Defense-in-depth** — add explicit `REVOKE EXECUTE … FROM PUBLIC` then re-`GRANT … TO anon` on the public token RPCs above. Harmless, low priority.

> These are all edge-function/SQL changes I did **not** apply overnight (to keep the verified, deployed
> state intact for your review). Say the word in the morning and I'll implement #1–#3 on the branch + redeploy + test.
