# Woahh Scaling & Infrastructure Plan

> **Durable record** — kept in the repo so it survives container/memory resets.
> Last updated: 2026-06-07. Owner: pawit.
> Purpose: explain how traffic flows, what handles load, what it costs, and the
> concrete thresholds at which we turn a dial — for onboarding, ops, and investor due diligence.

## TL;DR

Woahh runs on a **serverless + managed** stack: **Cloudflare Pages** (static front-end on a
global CDN) + **Supabase** (Postgres, Auth, Realtime, Storage, Edge Functions). At our launch
target (**100 merchants / ~1,000 customers**) we use a fraction of a **$25/mo** Supabase Pro tier;
Cloudflare Pages is free. **We do not run our own servers and we do not use Kubernetes** — both
providers scale their layers for us. Our scaling path for years is "click a bigger Supabase compute
size, add read replicas, cache public reads at the edge" — all config changes, never a re-platform.

---

## How traffic flows

```
                    ┌─────────────────────────────────────┐
   Browser  ──────► │  CLOUDFLARE PAGES (global CDN edge)  │   ← static SPA
   (merchant or     │  HTML / JS / CSS bundle, manifest,   │     (React/Vite build)
    customer)       │  service worker, images              │
        │           └─────────────────────────────────────┘
        │
        │  XHR / websocket (data, auth, realtime)
        ▼
                    ┌─────────────────────────────────────┐
                    │  SUPABASE (ref pmnyhbhtkcfoozkinieo) │   ← all the real work
                    │  Postgres + RLS                      │
                    │  Auth                                │
                    │  Realtime (KDS, order tracking)      │
                    │  Storage (product images, logos)     │
                    │  Edge Functions / Deno (SMS, email,  │
                    │    courier, order-notify, …)         │
                    └─────────────────────────────────────┘
                              │
                              ▼
                external APIs: ClickSend (SMS), Resend (email),
                Stripe (payments), courier providers
```

- **Cloudflare Pages serves only static files.** The compiled React bundle and assets sit on
  Cloudflare's global CDN. Serving a flat file to 1,000 or 1,000,000 users is the canonical CDN
  problem — no per-user compute, no origin to fall over. This layer is effectively never our
  bottleneck.
- **Supabase does all the actual work.** Every order write, RLS-scoped query, auth login, realtime
  KDS update, and edge-function send lands here. This is the **only** layer where "load" is a real
  concept for us.

---

## Why no Kubernetes (and no servers we operate)

K8s exists to orchestrate **containers/servers you run yourself**. We deliberately chose a
serverless + managed stack so we never operate infrastructure:

- Cloudflare scales the static edge.
- Supabase scales Postgres / Auth / Realtime / Functions.

Adding K8s here would be operational burden solving a problem we don't have. Not on the roadmap at
any foreseeable scale for a small-AU-merchant SaaS.

---

## Capacity at launch target (100 merchants / ~1,000 customers)

This is a **small** workload for managed Postgres. Sizing it honestly:

| Resource | At target scale | Supabase Pro ($25/mo) includes |
|---|---|---|
| DB size | tens of MB → low GB | 8 GB |
| Concurrent realtime conns (KDS screens, `/order/:id` trackers) | a few hundred at peak | 500 (more via compute add-on) |
| DB queries/sec | low, bursty at meal times | a small instance does thousands/sec |
| Edge fn invocations (SMS/email/order-notify/courier) | a few thousand/day | 2M/mo |
| Auth users (MAU) | ~1,100 | 100,000 |
| Storage (images) | low GB | 100 GB |

Headroom is large in every row. No wall is close.

---

## Cost at this scale

| Item | Cost | Notes |
|---|---|---|
| Cloudflare Pages | **$0** | Free tier: unlimited bandwidth + requests; 500 builds/mo |
| Supabase | **~$25/mo** | Pro tier — daily backups, no auto-pause, higher realtime/connection ceilings |
| ClickSend (SMS) | per-message | scales with **usage**, not merchant count |
| Resend (email) | per-message / tier | scales with usage |
| Stripe | per-transaction | pass-through processing fees |

**Infra floor ≈ $25/mo.** Messaging/payments scale with volume, not tenant count. You'd want Pro
for any real business regardless of load (backups + no auto-pause), so $25/mo is not "extra" — it's
the baseline.

---

## The per-merchant subdomain platform doesn't change this

Planned `<slug>.woahh.app` storefronts (branch `feat/storefront-platform`) ride the **same static
bundle from the same CDN**. A wildcard `*.woahh.app` on Cloudflare Pages resolves the subdomain to a
slug → one org via the existing `get_public_storefront` RPC. **No new origin, no new infra, no
per-subdomain server.** Same scaling profile as today.

---

## Scaling path — turn dials, in order

We won't approach these until **thousands of merchants / tens of thousands of concurrent users**.
Each step is a config change, not a re-architecture:

1. **Vertical compute bump (first + biggest lever).** Increase the Supabase DB instance size →
   more CPU/RAM → more connections + QPS. One click. Good for a long way.
2. **Connection pooling (Supavisor).** Already how serverless connects; tune transaction-mode
   pooling so many short queries share few Postgres connections. Matters once edge-function /
   concurrent query counts climb.
3. **Read replicas.** When heavy *reads* (marketplace browsing, storefront/menu fetches via the
   anon `get_public_*` RPCs) dominate, route them to replicas; keep the primary for writes.
4. **Edge-cache public reads.** The anon storefront/menu/shortage RPCs are cacheable — let
   Cloudflare cache those responses so popular storefronts barely touch Supabase.
5. **Offload heavy/async work.** Large campaign sends already batch through edge functions +
   pg_cron (`dispatch_scheduled_campaigns`, `auto_decline_stale_orders`); that pattern keeps spikes
   off the synchronous request path. Extend it as send volumes grow.

Only *far* beyond that (serious multi-region platform) would dedicated infra or sharding enter the
conversation — by which point there's revenue and an ops hire to support it.

---

## Concrete watch-thresholds (when to act)

Rough triggers to monitor in the Supabase dashboard. Numbers are conservative starting points —
adjust against observed headroom.

| Signal | Watch threshold | Action |
|---|---|---|
| Concurrent realtime connections | sustained > ~400 (near the 500 Pro ceiling) | Add compute (raises realtime ceiling); audit for leaked/duplicate subscriptions |
| DB CPU | sustained > ~70% at peak | Vertical compute bump (step 1) |
| Postgres connection saturation | pooler near max / connection errors | Tune Supavisor transaction-mode pooling (step 2) |
| Read latency on public storefront/menu RPCs | p95 climbing under marketplace traffic | Edge-cache public reads (step 4); then read replica (step 3) |
| Edge fn invocations | approaching plan limit (2M/mo) or timeouts under campaign bursts | Confirm batching via pg_cron; raise plan / split heavy jobs (step 5) |
| DB size | approaching 8 GB (Pro) | Bump compute/storage; archive old logs (`sms_log`, `email_log`, `order_notification_log`) |

> Heavy log tables (`sms_log`, `email_log`, `order_notification_log`, `donation_ledger`) are the most
> likely first growers. A periodic archive/rollup job is the cheap fix long before storage is a
> concern.

---

## AI features — compute & scaling

Our AI features (menu copilot / vision extraction, edit-menu-with-AI, campaign copy, decline
reasons, AI inventory assistant) **do not run AI compute on our infrastructure.** They call the
**Anthropic Claude API** (Claude Sonnet 4.6) from our Supabase edge functions. The model runs on
Anthropic's servers — we never host a GPU, never run a model, never orchestrate inference. It's the
same managed-service pattern as the rest of the stack: someone else owns the heavy compute, we make
API calls.

So "will AI compute/power/performance scale?" → **yes, and it's not our compute to scale.** What we
actually manage for AI is three things, none of which are infrastructure:

| Concern | Reality | What we do |
|---|---|---|
| **Compute / GPUs** | Anthropic's problem, not ours | Nothing — managed API |
| **Cost** | Per-token, per-call — scales with *usage*, not merchant count | Budget per feature; cache where possible |
| **Rate limits** | API has request/token-per-minute caps (per org/key) | Queue + retry; raise limits as we grow |
| **Latency** | Per-call (seconds for vision/long gens) | Run async in edge functions; SSE streaming for the edit-menu flow so the UI feels live |

Why this is fine at 100 merchants / 1,000 customers:

- **AI calls are occasional, not per-request.** A merchant imports a menu *once*, asks the copilot
  to draft a campaign now and then, generates a decline reason occasionally. This is a trickle of
  calls per merchant per day — nowhere near rate limits.
- **No fan-out per customer.** Customers don't trigger AI; AI is a merchant-side authoring tool. So
  the 1,000 customers add **zero** AI load. AI volume tracks merchant *actions*, which is small.
- **Cost scales linearly and predictably.** Each call is a known token cost; total spend grows with
  how much merchants use AI, not with raw traffic. Budgetable per feature.

When AI *does* warrant attention (well past launch scale):

1. **Rate limits before compute.** If concurrent AI usage ever bumps the API's per-minute caps,
   the fix is requesting higher limits from Anthropic and/or queuing calls — not buying hardware.
2. **Cost controls.** Cache repeated extractions, cap tokens per call, gate the heaviest features
   (vision import) by tier. All app-level dials.
3. **Async everything heavy.** Long generations already run server-side in edge functions; keep the
   UI responsive with streaming/optimistic states rather than blocking on the model.

Bottom line on AI: it adds a **per-call API cost** and a rate-limit ceiling to watch — but **no
compute, no servers, no GPUs, and no scaling work on our side.** It rides the same "managed service,
turn a dial" model as everything else.

> **Note:** Anthropic API keys for the AI edge functions must be set as Supabase function secrets
> and rotated on the usual schedule — see the key-rotation items in the handoff docs.

## Bottom line

At 100 merchants / 1,000 customers: **stay on Cloudflare + Supabase, ~$25/mo, load handled with
large headroom, no Kubernetes, no re-platform.** Scaling for the foreseeable future is dial-turning
on managed services — exactly what this stack was chosen to deliver.
