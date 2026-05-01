# woahh.app Email Domain — Implementation Plan
> Generated 2026-04-30. All Lovable prompts are under 5000 chars. Do them in order.

---

## Manual Step A — Resend DNS setup (do this first, no code needed)

Woahh sends two **categories** of email, and they must go through separate subdomains:

| Subdomain | Used for | Why isolated |
|---|---|---|
| `mail.woahh.app` | Order confirms, reservation confirms, loyalty milestones, account recovery | Transactional — must always arrive. Protected from marketing reputation damage. |
| `campaigns.woahh.app` | Merchant promotional email campaigns | Marketing — higher spam risk. Damage here never bleeds into transactional. |

This is the same architecture used by Mailchimp, Klaviyo, Shopify, and every serious email platform.

**Add both domains in Resend (requires Pro plan, $20/mo — you'll need it for volume anyway):**

1. Resend dashboard → Domains → **Add Domain → `mail.woahh.app`**
   - Resend gives you 3 DNS records — add them at your registrar (SPF, DKIM, DMARC on this subdomain)
   - Click Verify

2. Resend dashboard → Domains → **Add Domain → `campaigns.woahh.app`**
   - Resend gives you another 3 DNS records — add them at your registrar
   - Click Verify

Each subdomain takes 5–30 min to verify. They have completely independent reputations.

> A merchant sends a spammy promo campaign → spam complaints hit `campaigns.woahh.app` only.
> Order confirmation emails from `mail.woahh.app` are unaffected and keep arriving cleanly.

---

## Manual Step B — Domain routing (no code needed)

To split `woahh.app` (customer) from `business.woahh.app` (merchant dashboard):

1. **Lovable project settings → Custom domains** — add both `woahh.app` AND `business.woahh.app`
2. Both point to the same Lovable app
3. **Prompt 6 below** adds the hostname check in App.tsx that routes between them
4. At your DNS registrar, point both to Lovable's servers (Lovable provides the IP/CNAME)

---

## PROMPT 0 — Fix all wrong domain references (do before Prompt 1)

> Paste into Lovable. Sweeps out `woahhapp.com` and `yoursaas.com.au` placeholder addresses.

```
Make the following string replacements across the codebase. These fix placeholder and incorrect domain references left over from scaffolding. No logic, imports, or structure should change — only the email address strings listed.

FILE: src/pages/SMSCampaigns.tsx
  Replace: support@yoursaas.com.au
  With:    support@woahh.app

FILE: src/pages/Terms.tsx
  Replace: legal@woahhapp.com
  With:    legal@woahh.app

FILE: src/pages/Privacy.tsx
  Replace: privacy@woahhapp.com
  With:    privacy@woahh.app

FILE: src/pages/Recover.tsx
  Replace: support@woahhapp.com
  With:    support@woahh.app

FILE: supabase/functions/order-notify/index.ts
  Replace: orders@woahhapp.com
  With:    orders@mail.woahh.app

  Replace: push@woahhapp.com
  With:    push@mail.woahh.app

FILE: supabase/functions/account-recover/index.ts
  Replace: support@woahhapp.com
  With:    support@mail.woahh.app

No other changes.
```

---

## Sender identity architecture

Every merchant that sends campaigns gets their own unique from address: `{slug}@campaigns.woahh.app`.

- Bella's Bistro → `bellas-bistro@campaigns.woahh.app`
- Mario's Pizza → `marios-pizza@campaigns.woahh.app`

This means:
- A customer who blocks `bellas-bistro@campaigns.woahh.app` only blocks Bella's emails, not Mario's
- The unsubscribe token in the email is already per-merchant (one `customers` row per org) — this makes the from address match that mental model
- Each merchant's sender reputation builds independently (Gmail tracks per address, not just per domain)
- Only one domain to verify in Resend: `campaigns.woahh.app`

**Phase 2 — custom sending domain per merchant (later feature):**
The `organizations.email_sending_domain` column already exists in the DB. When a merchant provides their own domain (e.g. `bellas.com.au`), the app can verify it in Resend and send from `hello@bellas.com.au`. The logic in `email-send` will be: `org.email_sending_domain ?? `${org.slug}@campaigns.woahh.app``. This is how Klaviyo and Mailchimp handle it. No schema change needed.

---

## PROMPT 1 — Fix `email-send` + `order-respond` sending domain

> Paste into Lovable. Uses per-merchant address on `campaigns.woahh.app` for marketing; `mail.woahh.app` for transactional.

```
Make the following changes to fix the email sending domain across two edge functions.

email-send handles merchant promotional campaigns (marketing). Each merchant uses their own address:
  {org.slug}@campaigns.woahh.app  (e.g. bellas-bistro@campaigns.woahh.app)
This isolates sender reputation and unsubscribes per merchant.

order-respond handles order confirmation/decline notifications (transactional) — uses mail.woahh.app.

FILE: supabase/functions/email-send/index.ts

1. Find the org select (the .select() call that fetches from "organizations"). Add slug and email_sending_domain to it:
   Change: .select("id, name, email_used_this_month, email_monthly_cap, email_topup_credits")
   To:     .select("id, name, slug, email_sending_domain, email_used_this_month, email_monthly_cap, email_topup_credits")

2. Find the from-address line (currently hardcoded to orders@woahh.app). Replace it with:
   const fromAddr = `${org.name} <${org.email_sending_domain ?? `${org.slug}@campaigns.woahh.app`}>`;

FILE: supabase/functions/order-respond/index.ts

1. Find the from-address line (currently uses email_sending_domain fallback to yoursaas.com.au). Replace it with:
   const fromAddr = `${org.name} <orders@mail.woahh.app>`;

2. Remove email_sending_domain from the org select in this file only (order notifications are transactional — no per-merchant address needed):
   Remove email_sending_domain from the .select() string.

3. Find the APP_URL fallback line. Change:
   FROM: "https://app.yoursaas.com.au"
   TO:   "https://woahh.app"

No other changes.
```

---

## PROMPT 2 — Create `src/lib/emailTemplates.ts`

> Paste into Lovable. Creates the template library used by the composer and transactional emails.

```
Create a new file src/lib/emailTemplates.ts.

Export the following types and constants:

export type TemplateId = 'promo' | 'loyalty' | 'reactivation' | 'custom';

export interface TemplateVars {
  orgName: string;
  primaryColor: string; // hex e.g. "#3B82F6"
  logoUrl?: string | null;
  headline: string;
  body: string;
  ctaText?: string;
  ctaUrl?: string;
}

export const TEMPLATE_META: Record<Exclude<TemplateId,'custom'>, {
  label: string;
  description: string;
  icon: string; // emoji
  defaultHeadline: string;
  defaultBody: string;
  defaultCtaText: string;
  defaultSubject: string;
}> = {
  promo: {
    label: "Promotion",
    description: "Announce a sale, discount or special offer",
    icon: "🎉",
    defaultHeadline: "🎉 A special offer for {{first_name}}",
    defaultBody: "We have an exclusive deal just for you. Tap below before it expires.",
    defaultCtaText: "Claim your offer",
    defaultSubject: "Exclusive offer — just for you",
  },
  loyalty: {
    label: "Loyalty update",
    description: "Celebrate a reward milestone or points balance",
    icon: "⭐",
    defaultHeadline: "You've earned a reward, {{first_name}}!",
    defaultBody: "Thank you for being a loyal customer. You've hit a new milestone — here's something special.",
    defaultCtaText: "View your rewards",
    defaultSubject: "You've earned a reward!",
  },
  reactivation: {
    label: "Win-back",
    description: "Re-engage customers who haven't ordered recently",
    icon: "👋",
    defaultHeadline: "We miss you, {{first_name}} 👋",
    defaultBody: "It's been a while! Come back and enjoy something special — we'd love to see you again.",
    defaultCtaText: "Order now",
    defaultSubject: "We miss you — come back for something special",
  },
};

export function getDefaultSubject(id: TemplateId): string {
  if (id === 'custom') return '';
  return TEMPLATE_META[id].defaultSubject;
}

Export a function buildEmailHtml(templateId: TemplateId, vars: TemplateVars): string that returns a full inline-styled HTML email (max-width 600px, table layout for email client compatibility, no CSS classes).

The function should NOT be called with templateId === 'custom' (caller handles that case with raw HTML).

For all three named templates the layout is the same structure, only the content differs:
- Header: a full-width block in `primaryColor` background. If logoUrl is provided, show <img src="{logoUrl}" height="48" alt="{orgName}">. Otherwise show the orgName in white bold text.
- Body: white background, padding 32px. Show headline in dark H1 (font-size 26px). Show body text in grey (color #555, line-height 1.6). If ctaText and ctaUrl are provided, show a CTA button styled with `primaryColor` background, white text, border-radius 6px.
- Footer: light grey (#f5f5f5) background, centered small text: "{orgName} · Sent via Woahh".

Use table-based layout (not divs) for maximum email client compatibility.
```

---

## PROMPT 3 — Template picker in `EmailCampaigns.tsx`

> Paste into Lovable. Replaces the raw HTML textarea with a template-based composer.

```
Update src/pages/dashboard/EmailCampaigns.tsx to add a template picker to the email composer.

Add imports:
import { TemplateId, TemplateVars, TEMPLATE_META, buildEmailHtml, getDefaultSubject } from "@/lib/emailTemplates";

Add a helper inside the component (after the useOrg call) to extract hex color from org settings:
function hslToHex(hsl?: string): string {
  if (!hsl) return "#3B82F6";
  const [h, s, l] = hsl.split(" ").map((v) => parseFloat(v));
  const ll = l / 100, a = (s / 100) * Math.min(ll, 1 - ll);
  const f = (n: number) => { const k = (n + h / 30) % 12; const c = ll - a * Math.max(Math.min(k - 3, 9 - k, 1), -1); return Math.round(255 * c).toString(16).padStart(2, "0"); };
  return `#${f(0)}${f(8)}${f(4)}`;
}

Replace the current bodyHtml composer state with these:
  const [templateId, setTemplateId] = useState<TemplateId>('promo');
  const [headline, setHeadline] = useState(TEMPLATE_META.promo.defaultHeadline);
  const [bodyText, setBodyText] = useState(TEMPLATE_META.promo.defaultBody);
  const [ctaText, setCtaText] = useState(TEMPLATE_META.promo.defaultCtaText);
  const [ctaUrl, setCtaUrl] = useState('');
  const [customHtml, setCustomHtml] = useState('');

When templateId changes (use a handler function), auto-fill headline/bodyText/ctaText from TEMPLATE_META[id] defaults and also auto-fill the subject field with getDefaultSubject(id) if the subject field is currently empty.

Update resetComposer to also reset templateId to 'promo' and reset all template fields.

Replace the "Body HTML" section in the Dialog with:

A) A label "Layout" followed by a 2×2 grid of cards (use a regular div grid, not a separate component). The 4 cards are the 3 named templates + a "Custom HTML" card (icon: <Code2 /> from lucide-react). Each card shows the emoji icon, label, and description. The selected card has a ring-1 ring-primary border and a slightly tinted background (bg-primary/5). Clicking a card sets the templateId.

B) Below the grid, when templateId !== 'custom', show:
   - Label "Headline" + Input (placeholder "{{first_name}} gets personalised") bound to headline
   - Label "Body text" + Textarea rows=4 bound to bodyText
   - A collapsible section "Button (optional)" using a simple toggle state. When open, show CTA Text Input and CTA URL Input.

C) When templateId === 'custom', show the original mono Textarea (rows=8) bound to customHtml with the existing placeholder and hint text.

Update canSend:
  const canSend = subject.trim().length > 0
    && (templateId === 'custom' ? customHtml.trim().length > 0 : headline.trim().length > 0)
    && (scheduleMode === 'now' || scheduledAt.length > 0)
    && !send.isPending;

In the send mutation, compute finalHtml before the insert:
  const primaryColor = hslToHex((org?.settings as any)?.branding?.primary_hsl);
  const finalHtml = templateId === 'custom'
    ? customHtml.trim()
    : buildEmailHtml(templateId, {
        orgName: org?.name ?? '',
        primaryColor,
        logoUrl: org?.logo_url,
        headline,
        body: bodyText,
        ctaText: ctaText || undefined,
        ctaUrl: ctaUrl || undefined,
      });

Use finalHtml as the body_html value in both the Supabase insert and demoStore().createEmailCampaign().

Import Code2 from lucide-react.
```

---

## PROMPT 4 — Create `send-transactional-email` edge function

> Paste into Lovable. `reservation-confirm` is already calling this function — we're fulfilling that existing call.

```
Create supabase/functions/send-transactional-email/index.ts.

This function is already being called by reservation-confirm. It receives POST requests with:
{
  templateName: string,           // e.g. "reservation-confirmation"
  recipientEmail: string,
  idempotencyKey: string,
  organization_id?: string,       // org to send from (used for branding)
  templateData: Record<string, unknown>
}

Setup:
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const APP_URL = Deno.env.get("APP_URL") ?? "https://woahh.app";

No auth check — callers pass the service role key as Bearer token. Verify the Bearer token matches SERVICE_KEY before proceeding.

Fetch org branding if organization_id is provided:
  SELECT name, logo_url, settings FROM organizations WHERE id = organization_id

Extract primaryColor from settings?.branding?.primary_hsl (convert HSL to hex inline — same formula as in emailTemplates.ts).

Use orgName and orgLogo for the email header.

From address: `${orgName} <orders@mail.woahh.app>`
(Transactional email — all go through mail.woahh.app regardless of merchant slug)

Supported templateName values and their HTML output:

"reservation-confirmation": Subject `Your reservation at ${orgName} is confirmed`
  HTML body: Show a clean confirmation card with: customer name greeting, orgName, formatted date/time (templateData.when), party size (templateData.partySize), status badge (Confirmed or Pending). Add a "Cancel reservation" link styled as a secondary button pointing to templateData.cancelUrl. Grey footer with "Sent via Woahh".

"loyalty-milestone": Subject `You've earned a reward at ${orgName}! ⭐`
  HTML body: Congratulations headline using templateData.name, loyalty points earned (templateData.points), milestone description (templateData.milestone). CTA button "View your rewards" pointing to templateData.rewardsUrl. Footer same.

For any unknown templateName, return json({ error: "Unknown template" }, 400).

Send via:
  POST https://api.resend.com/emails (single email)
  Headers: Authorization Bearer RESEND_API_KEY

Log the result to email_log (organization_id, email_address, subject, email_type = templateName, status = "sent"/"failed", provider_message_id, sent_at).

Return json({ ok: true }) on success, json({ error }) on failure.

Use inline styles only in all HTML. Keep function under 180 lines.
```

---

## PROMPT 5 — Update `reservation-confirm` to pass `organization_id`

> Paste into Lovable. Small update so the new `send-transactional-email` function can apply org branding.

```
Update supabase/functions/reservation-confirm/index.ts.

The function calls send-transactional-email at around line 136. Update the JSON body being sent to include organization_id:

Find the existing fetch call to `${SUPABASE_URL}/functions/v1/send-transactional-email` and update its body to add `organization_id: org?.id` alongside the existing templateName, recipientEmail, idempotencyKey, and templateData fields.

Also add `email_used_this_month` to the organizations select on line 90 (add it to the existing select string), so the send-transactional-email function can check email caps if needed.

No other changes to this file.
```

---

## PROMPT 6 — Domain-based routing in `App.tsx`

> Paste into Lovable. Routes `woahh.app` to customer pages and `business.woahh.app` to the dashboard.

```
Update src/App.tsx to add hostname-based routing.

Near the top of the main App component, add:
  const hostname = typeof window !== 'undefined' ? window.location.hostname : 'localhost';
  const isMerchantHost = hostname === 'business.woahh.app' || hostname === 'localhost' || hostname.endsWith('.lovable.app') || hostname.endsWith('.lovableproject.com');

Wrap all dashboard and auth routes in a conditional so they only render on the merchant host:
  {isMerchantHost && <Route path="/auth" element={<Auth />} />}
  {isMerchantHost && <Route path="/dashboard/*" element={...} />}
  (and any other owner-only routes like /staff-login, /onboarding, etc.)

Add a catch-all that redirects dashboard URLs from the customer domain to the merchant domain:
  {!isMerchantHost && (
    <Route path="/dashboard/*" element={<Navigate to={() => { window.location.href = `https://business.woahh.app${window.location.pathname}${window.location.search}`; return null; }} replace />} />
  )}

Leave all public routes (/, /eat, /eat/:slug, /shop/:slug, /order/:id, /account, /impact, /unsubscribe/:token, /book/:slug, /cancel-reservation/:token, /storefront/:slug, /menu/:slug) available on both hosts — do not gate these.

The effect: visiting woahh.app/dashboard redirects to business.woahh.app/dashboard. Visiting business.woahh.app/shop/bellas still works (public routes load everywhere).
```

---

## Summary — what each prompt builds

| Prompt | What it does | Files changed |
|---|---|---|
| 0 | Fix all `woahhapp.com` + `yoursaas.com.au` references | `SMSCampaigns`, `Terms`, `Privacy`, `Recover`, `order-notify`, `account-recover` |
| 1 | `email-send` → `{slug}@campaigns.woahh.app` per merchant; `order-respond` → `mail.woahh.app` | `email-send`, `order-respond` |
| 2 | Pre-built email template library | `src/lib/emailTemplates.ts` (new) |
| 3 | Template picker UI in campaign composer | `src/pages/dashboard/EmailCampaigns.tsx` |
| 4 | Transactional email edge function (reservation + loyalty) | `send-transactional-email` (new) |
| 5 | Wire organization branding into reservation emails | `reservation-confirm` |
| 6 | Domain routing: customer vs merchant host | `src/App.tsx` |

**After all 7 prompts (0–6):**
- Transactional emails (order confirms, reservations, loyalty, account recovery) send from `Bella's Bistro <orders@mail.woahh.app>` — protected reputation
- Marketing campaign emails send from `Bella's Bistro <bellas-bistro@campaigns.woahh.app>` — per-merchant address; unsubscribing/blocking one merchant doesn't affect others; spam complaints isolated per merchant
- Merchants pick from 3 pre-built layouts (Promo, Loyalty, Win-back) or write custom HTML
- Templates auto-apply the merchant's brand color and logo
- Reservation confirmation emails actually work (were calling a missing function)
- `woahh.app` is the customer-facing entry point; `business.woahh.app` is the merchant dashboard
