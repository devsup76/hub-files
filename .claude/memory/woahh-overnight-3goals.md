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
2. **Website UI upgrade** — NEW branch `feat/marketing-home-redesign` off master. Home page too busy → split into sections/top-nav; home must capture fast. **3 state-of-the-art directions**, each showing **home + /eat marketplace + merchant dashboard** (3 judge-screens). Delivery = **non-destructive preview gallery** (live untouched). Orchestrate as generate→judge-panel→synthesize.
3. **Native merchant app** — NEW branch `feat/native-app-platform` off master. Plan + **execute a Capacitor scaffold** (founder chose this) wrapping the existing Vite/React PWA → App Store + Google Play; per-merchant white-label path (`capacitor://` seam in `resolveTenant`). Plan covers now→future, store submission, signing, push, OTA, tiering.

Crash-safe: `/workspaces` persists across container crashes (prior crash kept committed + untracked work); app-repo branch pushes are extra safety; docs-repo push may 401 (needs devsup76 PAT) — commit locally regardless.
