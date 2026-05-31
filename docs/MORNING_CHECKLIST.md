# ☀️ Good morning — Woahh migration, pick up here

Everything that could be done safely overnight is done. This is your start-of-day checklist, in plain English, in the order we'll do it. Just tell me **"let's continue"** and I'll drive each step (explaining first, as agreed).

---

## ✅ What I finished while you slept (no surprises, nothing pushed live)

1. **Confirmed the app builds against your new database** — ran the production build twice; it succeeded both times. The built site has your **new** Supabase project baked in and **zero** trace of the old Lovable one. This is the big one: it means Cloudflare will build fine.
2. **Set both Resend secrets** (the new sending key + the webhook signing secret) — email sending *and* open/click tracking are wired to the new backend.
3. **Set up web push** (notification keys) — the "🔔 notify me" feature will work.
4. **Fixed two small asset bugs** (local file edits, not yet committed):
   - App icon path in `manifest.json` (was pointing at a missing file → fixed)
   - `sitemap.xml` had the wrong domain (`woahhapp.com` → `woahh.app`)

**Nothing was committed or pushed, and your live Lovable site is untouched.** All changes are local and reversible.

---

## 🔜 What we do this morning (in order)

### Step A — ClickSend (the last secret) — *needs you*
This is the only thing left for SMS to work on the new backend. Have these two ready to paste:
- **`CLICKSEND_USERNAME`** — your ClickSend login (usually your email)
- **`CLICKSEND_API_KEY`** — ClickSend dashboard → *Account → API Credentials*

*(If you'd rather not paste them in chat, I'll give you a one-line command to set them yourself.)*

### Step B — Commit everything — *I do it, you approve*
I'll commit the migration changes (new database config + Cloudflare files + tonight's fixes) to your `main` branch and push. I'll show you exactly what's in the commit first.

### Step C — Cloudflare Pages — *you click, I guide*
This is the actual "leave Lovable" moment. You own the domain already; we just need to create the website host. I've written the exact click-by-click below (**Cloudflare Setup** section). Takes ~10 minutes.

### Step D — Point your webhooks at the new backend — *you click, I give exact URLs*
So delivery/open tracking (Resend) and SMS replies (ClickSend) flow to the new project instead of Lovable.

### Step E — Test, then flip the domain — *together*
We verify everything works on a Cloudflare preview URL **first**, then switch `woahh.app` over. If anything's wrong, we flip back instantly (your Lovable site stays alive as the safety net until we're happy).

### Step F — Security cleanup — *you, quick*
- Rotate your **GitHub token** (it's sitting in plaintext in the repo config)
- Rotate the **Resend keys** you pasted in chat last night
- Revoke the **Supabase access token** you gave me, once we're fully done

---

## 📋 Cloudflare Pages setup (the exact steps for Step C)

> You'll do these in the Cloudflare dashboard. I can't click for you, but here are the precise values.

1. **Cloudflare Dashboard → Workers & Pages → Create → Pages → Connect to Git.**
2. Pick the repo **`devsup76/business-growth-hub`**, branch **`main`**.
3. **Build settings:**
   - Framework preset: **None** (or "Vite" if offered)
   - **Build command:** `npm run build`
   - **Build output directory:** `dist`
4. **Environment variables** (Settings → Environment variables → Production) — add these 4:

   | Name | Value |
   |---|---|
   | `VITE_SUPABASE_URL` | `https://pmnyhbhtkcfoozkinieo.supabase.co` |
   | `VITE_SUPABASE_PROJECT_ID` | `pmnyhbhtkcfoozkinieo` |
   | `VITE_SUPABASE_PUBLISHABLE_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBtbnloYmh0a2Nmb296a2luaWVvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxMzY0NzQsImV4cCI6MjA5NTcxMjQ3NH0.vzTSsUJEYZl8VzXrtdxeeobEHGnP2gwkhDmkgZiP7rY` |
   | `VITE_STRIPE_PUBLISHABLE_KEY` | *(only if you want Stripe — we're deferring billing, so optional/skip)* |

   Also add: `NODE_VERSION` = `20`
5. **Deploy.** Cloudflare gives you a preview URL like `business-growth-hub.pages.dev`. **Test on that first.**
6. **Custom domain** (only after the preview works): Pages project → Custom domains → add `woahh.app` (and `www.woahh.app` → redirect to apex). This is the DNS cutover = the moment you're off Lovable.

The `_headers` (security + content policy) and `_redirects` (so deep links work) files are already in your repo and ship automatically — nothing to configure for those.

---

## 📊 Migration status at a glance

| Piece | Status |
|---|---|
| New Supabase DB (schema, cron, storage, vault) | ✅ Done |
| All 21 backend functions deployed | ✅ Done |
| App points at new DB | ✅ Done (committing in Step B) |
| Email (send + tracking) | ✅ Done |
| Web push notifications | ✅ Done |
| Production build verified | ✅ Done |
| SMS (ClickSend) | 🔜 Step A — needs your keys |
| Commit + push | 🔜 Step B |
| Cloudflare Pages host | 🔜 Step C |
| Webhooks repointed | 🔜 Step D |
| Domain cutover (off Lovable) | 🔜 Step E |
| Security cleanup | 🔜 Step F |

Full technical detail is in **`docs/MIGRATION_OFF_LOVABLE.md`** if you want it.

— Claude
