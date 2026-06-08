---
name: woahh-overnight-3goals
description: "Overnight autonomous session (2026-06-07): 3 industry-level goals on 3 branches — restaurant templates, website UI redesign, native app — with founder decisions and crash-recovery pointer"
metadata:
  type: project
---

**Overnight autonomous build launched 2026-06-07** (founder asleep ~10h, wants industry-level results by morning). Full live plan + status: `docs/OVERNIGHT_PLAN_2026-06-07.md` (the crash-recovery anchor — read it first).

**Founder decisions (before sleep):**
- **Authority = branches + previews ONLY.** No merge to main/master, no deploys, no live DB migrations. Review in the morning.
- Save progress continuously (commit + push branches; update the plan doc). Self-critique hard (adversarial agents + my own Playwright verify).
- Match orchestration to task: dependent build → pipeline workflow; divergent design → independent parallel agents + judge panel; research → fan-out + single-writer execution.

**3 goals, one at a time, 3 separate branches:**
1. **Restaurant storefront templates** — branch `feat/storefront-platform` (worktree `repo-audit`). The Theme-Shell framework (see [[woahh-storefront-platform]]). **✅ DONE (pending founder review) 2026-06-07.** 8 templates: 4 keepers (Aurora/Atelier/Noir/Harvest, customizable font/vibe) + 4 NEW bespoke completely-different layouts (**Kerb** food-truck, **Daily** cafe, **Maison** fine-dining, **Rush** QSR). Each functional across home+menu+checkout, desktop+mobile (headless-chromium verified). Commits `4f36ed8`→`68529ba`→`28afb96`→`44edaa6` (all pushed). Self-critique fixed: ThemeShell chrome theming, off-screen page-checkout (→full-screen takeover), preview-nav overlap, food heroes. **Preview-only** — NOT yet wired into the live `Shop.tsx`/picker (next integration after founder picks). Review: `/storefront-preview` (Cloudflare branch preview).
2. **Website UI upgrade** — branch `feat/marketing-home-redesign` off main (worktree `repo-home`). **✅ v2 ELEVATED 2026-06-08 (pending founder pick).** Founder feedback on v1: "looks good but elevate more — state-of-the-art / high IT industry grade, refine + build more." Now **6 directions** at top-tier-tech bar, each across **home + /eat marketplace + merchant dashboard**, non-destructive preview at `/home-preview`: **Momentum** (bold SaaS), **Warmth** (editorial/charity), **Clarity** (product-led, dark-native) — all REFINED with motion toolkits (IntersectionObserver staggered reveals, rAF count-ups, marquees, aurora/grain, 3D-tilt floating product mockups), bento, glass/depth, fluid clamp() type; + 3 NEW: **Nebula** (aurora gradient-mesh + glassmorphism), **Carbon** (developer-grade dark/mono/terminal — ⌘ command bar, `$ overview` console), **Lumen** (oversized-type bento, Awwwards energy). All reduced-motion + AA gated. Commits v1 `408b904`→`21c9f01`, review-fixes, v2 `3223c7f` + carbon count-up fix `5d56a81` (all pushed). Screenshot-verified all 18 screens; tsc clean, build green. Gotcha: local `vite preview` can serve stale dist (rebuild before serving); Cloudflare builds fresh.
3. **Native merchant app** — branch `feat/native-app-platform` off main (worktree `repo-native`). **✅ DONE 2026-06-07.** Decision-ready plan `docs/NATIVE_APP_PLATFORM.md` (Capacitor 8, phased PWA→single-app→white-label; Apple 4.2.6/4.3 trap + compliant Model A/Model C; IAP physical-goods exemption→keep Stripe; Capgo OTA) + committed Capacitor scaffold: `capacitor.config.ts`, `android/` project, `src/lib/native.ts` (isNativePlatform/nativeRedirectBase/forcedSlug), 10 auth/Stripe redirect sites migrated, SW gated web-only, forcedSlug seam, `scripts/build-merchant-app.mjs`. Verified tsc clean + build green + cap sync ok. Commits `eb61f2f`→`89f5ee0` (pushed). iOS needs a Mac; human store steps documented.

**ALL 3 GOALS COMPLETE + STAGED (branches+previews only, nothing merged/deployed). Morning-review guide in `docs/OVERNIGHT_PLAN_2026-06-07.md` ("MORNING REVIEW — START HERE").**

Crash-safe: `/workspaces` persists across container crashes (prior crash kept committed + untracked work); app-repo branch pushes are extra safety; docs-repo push may 401 (needs devsup76 PAT) — commit locally regardless.
