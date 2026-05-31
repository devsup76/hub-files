#!/usr/bin/env bash
# One-shot: set SMS secrets + deploy the SMS edge functions to the new Supabase
# project (ref pmnyhbhtkcfoozkinieo). No secrets are hardcoded — pass them via env.
#
# Usage:
#   SUPABASE_ACCESS_TOKEN=sbp_xxx \
#   CLICKSEND_USERNAME=adminwoahhapp@proton.me \
#   CLICKSEND_API_KEY=xxxxxxxx \
#   WOAHH_SMS_NUMBER=+61xxxxxxxxx \
#   SMS_WEBHOOK_SECRET=xxxx \
#   bash scripts/sms-deploy.sh
#
# Requires: npx (supabase CLI is fetched on demand). Run from repo root.
set -euo pipefail

REF="pmnyhbhtkcfoozkinieo"
REPO="/workspaces/GrowthHub/repo"

req() { [ -n "${!1:-}" ] || { echo "Missing required env: $1" >&2; exit 1; }; }
req SUPABASE_ACCESS_TOKEN
req CLICKSEND_USERNAME
req CLICKSEND_API_KEY
req WOAHH_SMS_NUMBER
req SMS_WEBHOOK_SECRET

export SUPABASE_ACCESS_TOKEN
cd "$REPO"

echo "== Setting edge-function secrets on $REF =="
npx --yes supabase@latest secrets set \
  CLICKSEND_USERNAME="$CLICKSEND_USERNAME" \
  CLICKSEND_API_KEY="$CLICKSEND_API_KEY" \
  WOAHH_SMS_NUMBER="$WOAHH_SMS_NUMBER" \
  SMS_WEBHOOK_SECRET="$SMS_WEBHOOK_SECRET" \
  --project-ref "$REF"

echo "== Deploying SMS edge functions =="
for fn in sms-send sms-webhook reservation-confirm reservation-remind owner-verify; do
  echo "-- deploy $fn --"
  npx --yes supabase@latest functions deploy "$fn" --project-ref "$REF"
done

echo
echo "== DONE. Configure these ClickSend webhook URLs (Dashboard -> SMS -> Settings): =="
echo "   Delivery receipts + Inbound SMS ->"
echo "   https://$REF.supabase.co/functions/v1/sms-webhook?secret=$SMS_WEBHOOK_SECRET"
echo
echo "Next: assign the per-merchant number to the test org, then send a test campaign."
echo "  SQL (run in Supabase SQL editor as the owner, or via AdminSmsNumbers UI):"
echo "  select admin_assign_sms_number('<TEST_ORG_UUID>', '$WOAHH_SMS_NUMBER');"
