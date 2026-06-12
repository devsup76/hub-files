-- =============================================================================
-- SQUARE SANDBOX GO-LIVE — run AFTER the 7 edge functions are deployed.
-- Two steps: seed test-bistro's per-org Square connection, then flip the flags.
-- SQL-editor runs as postgres (auth.uid() NULL) so the H-6 owner-immutability
-- trigger correctly allows these writes.
-- =============================================================================

-- 1) Seed the per-org Square connection for test-bistro (sandbox-direct mode).
--    REPLACE <SANDBOX_ACCESS_TOKEN> with the same sandbox token you already put
--    in the edge secrets (Developer Dashboard → your app → Sandbox → Access token).
--    Sandbox direct tokens don't expire, so refresh_token is unused (same value)
--    and expires_at is far-future. locations stays [] — square-payment falls back
--    to a live ListLocations call with this token and caches the result.
INSERT INTO public.square_connections
  (org_id, access_token, refresh_token, expires_at, merchant_id, locations, default_location_id, scopes)
VALUES (
  '35cf67fb-bd48-45ec-8032-32debbca84b1',          -- test-bistro org
  '<SANDBOX_ACCESS_TOKEN>',
  '<SANDBOX_ACCESS_TOKEN>',
  now() + interval '10 years',
  'sandbox-direct',
  '[]'::jsonb,
  NULL,
  'PAYMENTS_WRITE PAYMENTS_READ ORDERS_WRITE MERCHANT_PROFILE_READ'
)
ON CONFLICT (org_id) DO UPDATE
  SET access_token = EXCLUDED.access_token,
      refresh_token = EXCLUDED.refresh_token,
      expires_at   = EXCLUDED.expires_at,
      updated_at   = now();

-- 2) Flip test-bistro to Square + enable online card capture.
--    NOTE: jsonb_set does NOT create the intermediate 'payments' key on an empty
--    settings object (create_missing only applies to the final path element), so
--    we merge the payments object explicitly.
UPDATE public.organizations
SET payment_provider     = 'square',
    square_payment_ready = true,
    settings = jsonb_set(
      coalesce(settings, '{}'::jsonb),
      '{payments}',
      coalesce(settings->'payments', '{}'::jsonb) || '{"online_card_enabled": true}'::jsonb,
      true
    )
WHERE id = '35cf67fb-bd48-45ec-8032-32debbca84b1';

-- Verify:
SELECT payment_provider, square_payment_ready,
       settings->'payments'->>'online_card_enabled' AS online_card_enabled,
       (SELECT count(*) FROM public.square_connections
         WHERE org_id = '35cf67fb-bd48-45ec-8032-32debbca84b1') AS connection_seeded
FROM public.organizations
WHERE id = '35cf67fb-bd48-45ec-8032-32debbca84b1';

-- =============================================================================
-- TO REVERT after testing (back to Stripe, cards off):
-- UPDATE public.organizations
-- SET payment_provider='stripe', square_payment_ready=false,
--     settings = jsonb_set(settings,'{payments,online_card_enabled}','false')
-- WHERE id='35cf67fb-bd48-45ec-8032-32debbca84b1';
-- DELETE FROM public.square_connections WHERE org_id='35cf67fb-bd48-45ec-8032-32debbca84b1';
-- =============================================================================
