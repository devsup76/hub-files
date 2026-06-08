# Native App Platform — Capacitor (decision-ready plan)

> Status: decision-ready, 2026-06-07. Branch `feat/native-app-platform` (worktree `repo-native`).
> Founder decision: **Capacitor scaffold + plan** — wrap the existing Vite/React PWA, do not rewrite.
> Pairs with the **Storefront Platform** section in `CLAUDE.md` (per-merchant `<slug>.woahh.app` + dynamic-manifest PWA, branch `feat/storefront-platform`) and the POS / Tap-to-Pay plan (`docs/POS_TERMINAL_PLAN.md`).
> Honesty notes baked in: iOS builds need a Mac + Xcode; Apple Tap-to-Pay distribution entitlement has a ~1–2 week lead; `tenant.ts`/`pwaManifest.ts` from `feat/storefront-platform` are **NOT** in this worktree (the per-merchant seam is built here, not assumed).

---

## 1. TL;DR / recommendation

- **Ship now (Phase 0, $0 marginal):** polish the **per-merchant installable PWA** (Add-to-Home-Screen on each `<slug>.woahh.app`) — every merchant on every tier gets a branded, installable "app" today with no store overhead.
- **Phase 1 (single Woahh Capacitor app):** wrap the existing `dist/` build with **Capacitor 8** into **one** consumer "Woahh" app (the `/eat` marketplace as the discovery surface). This is the **only** model that scales to N merchants from one developer account without store rejection — it is Apple's explicitly-blessed "picker"/aggregator pattern.
- **Phase 2 (per-merchant white-label, Growth+):** offer true standalone native apps via **one white-label Capacitor engine** built per-merchant in CI (inject appId/name/icons/splash/forced-slug → build → sign → submit) and **published under the MERCHANT's own developer account**, kept current with **OTA web-bundle updates** so the fleet updates without resubmission.
- **Never build:** a fleet of per-merchant apps under **Woahh's** own developer account — that is a textbook Apple 4.2.6 + 4.3 / Google Repetitive-Content violation with whole-account-ban exposure.
- **Payments stay on Stripe** — restaurant orders are physical goods, exempt from Apple/Google in-app-purchase (IAP); keep merchant SaaS billing out of the consumer native binary to avoid triggering IAP.

---

## 2. Why Capacitor (vs RN/Expo rewrite vs PWA-only / TWA)

Our stack today: **Vite 5 + React 18.3 SPA**, single-origin, already a PWA (service worker `public/sw.js`, `public/manifest.json`, Web Push/VAPID). Verified in this worktree: `vite.config.ts` sets no `outDir`/`base` (defaults `dist/` + `base:"/"`); `src/App.tsx` uses `<BrowserRouter>`; build script is `vite build`.

| Option | Verdict | Why |
|---|---|---|
| **Capacitor 8** | ✅ **Chosen** | Wraps the **existing `dist/` bundle as-is** (`webDir:"dist"`) — zero UI rewrite, one codebase serves web + iOS + Android. Framework-agnostic; the React/Vite app is unchanged. Full native plugin access (push, deep links, haptics, Tap-to-Pay path later). OTA-updatable. Lowest cost to reuse 100% of current product. |
| **React Native / Expo rewrite** | ❌ | Full rewrite of every screen (no DOM, different component model, different navigation, different forms). Throws away the shadcn/Radix/Tailwind UI, React Query data layer, and ~all `src/pages/*`. Months of work for parity we already have. Only justified if we needed deep native UI performance we don't. |
| **PWA-only** | ✅ keep, ⚠️ insufficient alone | Already done; great for Phase 0 and ~80% of "app on home screen." But **not in the App Store / Play search**, weaker iOS push reliability, no Tap-to-Pay, founder explicitly wants store listings. Keep it as the default tier; native is the premium upgrade. |
| **TWA (Trusted Web Activity, Android-only)** | ❌ | Android-only, no iOS, thin value over PWA, and a bare URL wrapper risks Google Minimum-Functionality rejection. Capacitor gives us both platforms + real native plugins for the same effort. |

**Bottom line:** Capacitor is the only option that reuses the entire existing product and reaches both stores. Capacitor 8 baseline (current as of 2026-06): Node 22+, iOS deployment target 15.0 / **Xcode 26+** (SPM projects by default), Android `minSdk 24` / `compile/targetSdk 36`. If the toolchain isn't on Xcode 26 yet, **Capacitor 7 + 7.x plugins is a fine fallback** (same architecture).

---

## 3. Architecture — how Capacitor wraps the build

### 3.1 The wrap
- **`webDir: "dist"`** in `capacitor.config.ts` (Vite default; we set no custom `outDir`). Build flow: `vite build` → `npx cap sync` → `npx cap run ios|android`.
- **Keep `base: "/"`** (do NOT switch to `base:"./"`). Capacitor serves the bundle at the WebView origin **root** (`capacitor://localhost` on iOS, `https://localhost` on Android), so absolute `/assets/...` paths resolve correctly. `base:"./"` is unnecessary and can interact badly with the SPA router.
- **`<BrowserRouter>` is fine** in the WebView — the app loads at origin root, history navigation works in-process. No HashRouter switch needed.
- **Dev live-reload (optional):** set `server.url` to the LAN Vite dev server (`server:{ url:"http://192.168.x.x:5173", cleartext:true }`) + `npm run dev -- --host`; **remove `server.url` for production** or the app phones home to your laptop.

### 3.2 Plugins needed
Official `@capacitor/*` (Capacitor-8 compatible) unless noted:
- **`@capacitor/app`** — lifecycle, **`appUrlOpen`** (deep links) + `getLaunchUrl()`, and the **Android hardware back button** (must be wired to the router: `navigate(-1)` / exit-on-root — out of the box Android back minimizes the app).
- **`@capacitor/push-notifications`** — **native push (APNs on iOS / FCM on Android)**. See §3.5 — this **replaces** Web Push/VAPID in native; the plugin has no web impl.
- **deep links / universal links** — handled by `@capacitor/app` `appUrlOpen` + host-served association files: **iOS** `apple-app-site-association` at `/.well-known/` + Associated Domains entitlement; **Android** `assetlinks.json` at `/.well-known/` + `android:autoVerify` intent filters. Hosted on `woahh.app` (and per-merchant subdomains). Route the opened URL through React Router.
- **`@capacitor/status-bar`**, **`@capacitor/splash-screen`**, **`@capacitor/keyboard`** (cart/checkout forms), **`@capacitor/haptics`** (add-to-cart / order confirm), **`@capacitor/network`** (offline detection), **`@capacitor/share`** (share storefront/product), **`@capacitor/browser`** (in-app SFSafariViewController / Chrome Custom Tabs — **use for Stripe Connect onboarding / hosted flows / any OAuth** so cookies + return work).
- **Hardening (optional):** `@capacitor/preferences` (eviction-proof session store), `@capacitor/device`, `@capacitor/dialog`, `@capacitor/toast`.

### 3.3 Session / storage in a WebView
- `src/integrations/supabase/client.ts` uses `storage: window.localStorage` (business key `woahh-business-auth`, customer key `woahh-customer-auth`, `persistSession`, `autoRefreshToken`). **localStorage persists across launches in WKWebView + Android WebView because Capacitor pins a stable origin** — sessions survive. This is the Capacitor↔Supabase happy path; no swap strictly required.
- **Caveat:** the OS can evict WKWebView localStorage under storage pressure (rare). For bullet-proof sessions, back the Supabase `storage` adapter with `@capacitor/preferences`. Optional, not a v1 blocker.

### 3.4 What breaks at a `capacitor://` origin (and fixes)
The highest-risk area: **every externally-bound URL is built from `window.location.origin`**, which in native is `capacitor://localhost` / `https://localhost`, not `https://woahh.app`. Confirmed sites in this worktree:

| Concern | File:line (verified) | Breakage | Fix |
|---|---|---|---|
| Stripe `return_url` (3DS) | `src/components/checkout/CardPayment.tsx:54` | 3DS-required cards try to return to `capacitor://localhost/order/...` → broken (no-3DS works today via `redirect:"if_required"`) | pass a real `https://woahh.app/order/...` (or deep link back) |
| Owner signup/login email | `src/pages/Auth.tsx:285`, `:373` | confirmation link points at webview origin → unopenable | use real apex base |
| Customer magic link / reset / OTP | `src/hooks/useCustomerAuth.ts:142,156,181`; `src/components/auth/CustomerForm.tsx:44,62`; `src/pages/Account.tsx:199`; `src/components/storefront/PostPurchaseModal.tsx:53,54` | auth completion redirects to webview origin → broken | use real apex base |
| Web Push | `src/pages/OrderStatus.tsx` (`Notification.requestPermission` + `pushManager.subscribe`) | Web Push API unavailable in WKWebView, unreliable in Android WebView | swap to native push (§3.5) |
| CSP `public/_headers` | `public/_headers` | Cloudflare CSP does **not** apply to the local bundle — but outbound calls still work (CORS is server-enforced by Supabase/Stripe) | set CSP via `<meta>` if desired; allow `capacitor://`/`https://localhost` in server allow-lists |
| `public/_redirects` SPA fallback | `public/_redirects` | Cloudflare-only; Capacitor serves `index.html` for unknown paths automatically | no action |
| Service worker | `src/main.tsx:32` (`navigator.serviceWorker.register("/sw.js")`) | redundant in a WebView; SW network-first navigate handler can interfere | **gate registration to web-only** (skip when `Capacitor.isNativePlatform()`) |

**Single most important code change:** introduce a `nativeRedirectBase()` helper returning `https://woahh.app` when `Capacitor.isNativePlatform()`, and replace the ~10 `window.location.origin` redirect sites above. Emails/Stripe then point at the real site, which can deep-link back into the app.

**Server allow-lists (must do):** add `capacitor://localhost` (iOS) + `https://localhost` (Android) to the **Supabase Auth Redirect-URL allow-list**, and verify `Origin`-based CORS in the Stripe edge functions (`stripe-payment-intent`, `stripe-connect-onboard`) + order endpoints.

### 3.5 Native push (not Web Push)
Web Push (VAPID, RFC 8291) and native push are **different transports**. `@capacitor/push-notifications` registers with the OS: **APNs token on iOS, FCM token on Android** (not a `PushSubscription`). Prereqs: `android/app/google-services.json`, an **APNs Auth Key (.p8)** uploaded to Firebase + Push capability in Xcode. **Recommended:** the community **`@capacitor-firebase/messaging`** (Capawesome) for one API across iOS/Android/web + foreground handling — lets us keep the VAPID web path and add FCM/APNs natively.

**Backend impact:** `push_subscriptions` + the `order-notify` edge function need a **second send path**: keep VAPID/Web Push for browser PWA, add an FCM/APNs path (store token type alongside the VAPID sub; send via FCM HTTP v1 / Firebase Admin for native installs). **Hard prerequisite:** provision a Firebase project + APNs .p8 key.

### 3.6 The per-merchant FORCED-SLUG seam
There is **no tenant seam in this worktree** (`src/lib/tenant.ts`, `pwaManifest.ts`, `StorefrontRenderer` are absent — they live on `feat/storefront-platform`). In a WebView the host is `localhost`, so **subdomain resolution does not apply**; a per-merchant native build is distinguished by a **compile-time constant**.

- **Seam:** read a build-time **`VITE_FORCED_SLUG`** (+ `VITE_NATIVE_TARGET=customer|merchant`) once, in `src/App.tsx` (or a tiny `src/lib/nativeTenant.ts`). The root route today is `src/App.tsx:108` (`<Route path="/" element={<Storefront/>}/>`).
  - **target=customer + slug set:** root `/` renders the merchant's storefront (`Shop` already takes a slug param via `/shop/:slug`) instead of the marketing `<Storefront/>`; hide `/eat` + marketing.
  - **target=merchant + slug set:** root `/` → `Navigate` to `/business/dashboard`; the org resolves from the logged-in owner session (no slug needed) — so a dashboard build mostly just needs the redirect + the §3.4 auth-redirect fix.
- **No PWA-manifest work needed for native:** the native app icon/name come from `capacitor.config` + native asset catalogs, not `manifest.json`. The dynamic `pwaManifest.ts` path is web-only.

---

## 4. The white-label problem + the compliant model

Woahh is, by definition, a "template / app-generation service." Apple and Google both have rules aimed squarely at that.

### 4.1 The rejection rules (cited)
- **Apple 4.2 — Minimum Functionality:** a bare WebView wrapper that just frames the website is rejected. The native build must add real value (push, Tap-to-Pay, QR/camera, offline, deep links). [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Apple 4.2.6 — commercialized templates (the white-label rule), verbatim:** *"Apps created from a commercialized template or app generation service will be rejected unless they are submitted directly by the provider of the app's content. These services should not submit apps on behalf of their clients… Another acceptable option … is to create a single binary to host all client content in an aggregated or 'picker' model, for example as a restaurant finder app with separate customized entries or pages for each client restaurant."* [Apple](https://developer.apple.com/app-store/review/guidelines/)
- **Apple 4.3 — Spam:** *"Don't create multiple Bundle IDs of the same app… consider submitting a single app… Spamming the store may lead to your removal from the Apple Developer Program."* Many near-identical per-merchant apps from one account = textbook 4.3, with **whole-account-ban** exposure. [Apple](https://developer.apple.com/app-store/review/guidelines/)
- **Google Play — Repetitive Content / Spam:** *"We don't allow apps that merely provide the same experience as other apps already on Google Play"*; flags "multiple apps with highly similar functionality" and recommends "a single app that aggregates all the content." [Google Play Spam policy](https://support.google.com/googleplay/android-developer/answer/9899034)
- **Google — White Label Best Practices (eff. 2025-02-10):** recommends a **decentralized account model** — *"policy issues with one app can negatively impact all other apps within the same account… can result in an account ban, removing all associated apps"* — and **unique store listings** per app (unique description/icons/graphics/screenshots). [Google white-label best practices](https://support.google.com/googleplay/android-developer/answer/15884185)

### 4.2 Why naive per-merchant apps get rejected
Publishing N merchant-branded apps from **Woahh's own** Apple/Play accounts, sharing one template/binary, hits 4.2.6 ("not submitted by the content provider") **+** 4.3 / Repetitive Content **+** account-ban blast radius (one violation can wipe every merchant app). This is the trap — do not build it.

### 4.3 The compliant model (recommended)
- **Launch — Model A: one aggregated "Woahh" app.** The `/eat` marketplace **is** Apple's named "restaurant finder app with separate entries per restaurant." Compliant by construction: one bundle ID, one listing, one maintenance burden. Make it non-trivial (push, QR, offline) to clear 4.2.
- **Premium — Model C: one white-label engine, published under the MERCHANT's own developer account.** 4.2.6's first clause is the green light ("submitted directly by the provider of the app's content"). The merchant is the content provider; Woahh "offers tools." Each app carries the merchant's real brand/menu/listing, so content is genuinely distinct. Decentralized accounts isolate violations (Google's stated reason).
- **Reject — Model B:** per-merchant fleet under Woahh's account (4.2.6 + 4.3 + ban risk + linear unbounded cost).
- **(Niche) Apple Custom/Unlisted apps** via Apple Business Manager — for bespoke/internal distribution, not public consumer storefronts.

---

## 5. Payments

- **Restaurant orders = physical goods → exempt from IAP. Keep Stripe.** Apple **3.1.3(e)** verbatim: *"If your app enables people to purchase physical goods or services that will be consumed outside of the app, you must use purchase methods other than in-app purchase to collect those payments, such as Apple Pay or traditional credit card entry."* Apple's own examples of physical goods include **food delivery**. [Apple](https://developer.apple.com/app-store/review/guidelines/) So order payments keep the existing **Stripe Connect / Apple Pay / card** flow — **no 15–30% Apple cut**. Google Play has the parallel physical-goods carve-out (Play Billing only mandatory for in-app *digital* content).
- **Watch-out — keep merchant SaaS billing out of the consumer native binary.** Merchant subscription tiers (Solo/Marketplace/Growth) are digital SaaS sold B2B; today there is **no in-app subscription purchase UI** (Stripe Billing not started). If a *digital* upgrade were ever sold *inside* a native app to an end user, Apple **3.1.1** would force IAP. Mitigation: keep subscription upgrades **web-only**, never in the native binary.

---

## 6. Per-merchant build pipeline (Model C mechanics)

One git repo / one engine, per-merchant **build inputs**, automated CI → one signed binary per merchant.

### 6.1 The five injected inputs
1. **App identity** — `appId` (bundle ID, e.g. `app.woahh.<slug>` or the merchant's own reverse-DNS), `appName`, version.
2. **Forced slug** — `VITE_FORCED_SLUG` (+ `VITE_NATIVE_TARGET`) → boots straight into the merchant's storefront via the §3.6 seam. Same `get_public_storefront` data path; isolation unchanged.
3. **Icons + splash** — per-merchant iOS/Android icon sets + splash, generated from `organizations.logo_url`/branding (same source the PWA uses).
4. **Theme/manifest** — name/theme color from org branding, baked at build time.
5. **Signing + listing creds** — the **merchant's** App Store Connect API key + Play service account (binary lands in *their* account).

### 6.2 How Capacitor consumes them
- `capacitor.config.ts` can **export a config switched on `process.env`** at build time (appId, deep-link scheme, icons, splash differ per build).
- **`@capacitor/assets`** generates platform icon/splash sets from per-appId source folders.
- Off-the-shelf helper `capacitor-white-label` (npm) customizes appId/name/version/package/splash/icon as a building block.

### 6.3 The CI job (parameterized by `MERCHANT_SLUG`)
1. Pull merchant build inputs (`organizations` + a new `merchant_app_builds` table / branding).
2. Generate `tenant.config.ts` (forced slug) + `capacitor.config` overrides + run `@capacitor/assets`.
3. `vite build` → `npx cap sync`.
4. **fastlane** — iOS `gym` → `pilot`/`upload_to_app_store`; Android `gradle` → `supply`. Auth via **App Store Connect API Key** (stable for multi-client; merchant grants an API key with App Manager/Admin role) + Play service account.
5. Submit to each store under the merchant's account.

**Tooling options:** Codemagic's turnkey **white-label flow** (REST-API-triggered builds with per-client env-var groups that set values + sign + publish), **or** roll-your-own GitHub Actions + fastlane. (Capgo also sells a one-time CI setup ~$2,600 if outsourced.)

### 6.4 OTA live-updates (update the fleet without resubmission)
The economic linchpin: native binaries are heavy to rebuild/resubmit per merchant, but **all merchant apps share the same web bundle**, so one OTA push services the whole fleet — making per-merchant maintenance **sublinear**.
- **Allowed:** updating **HTML/CSS/JS** (UI fixes, copy, storefront tweaks, bug fixes). **Not allowed via OTA:** native/plugin changes or anything that "introduces or changes features/functionality" (Apple **2.5.2** / DPLA) — those need a rebuild + resubmit.
- **Tool: Capgo** (`@capgo/capacitor-updater`, open-source) — differential, end-to-end-encrypted channels, staged rollouts, auto-rollback. **Avoid Ionic Appflow** (closed to new customers early 2025; full sunset 2027-12-31). Alternative: Capawesome Cloud.
- **Pricing (Capgo):** Solo $12/mo → Maker $33 → Team $83 → Enterprise $208+ (one shared channel covers all merchant apps; cost is roughly fleet-flat, not per-merchant).

### 6.5 Avoiding 4.3 even in Model C
Distinct publisher is necessary but not sufficient. Each app must be **genuinely differentiated**: merchant's own brand/menu/content, **unique store listing** (description/icons/screenshots — Google requires this). Lean on merchant-chosen templates (the `StorefrontRenderer` + curated-templates work on `feat/storefront-platform`) so the chrome isn't identical.

---

## 7. Store accounts, signing & submission checklist

| Item | Apple | Google |
|---|---|---|
| Program / fee | Apple Developer Program — **$99 USD/yr (recurring)** | Play Console — **$25 USD one-time** |
| Console | App Store Connect | Play Console |
| Signing | Certificates + provisioning profiles; entitlements declared in the profile; Apple-managed code signing | **Play App Signing** (Google holds signing key; you keep an upload key) |
| White-label team access | Invite Woahh as **App Manager** in the merchant's App Store Connect | Add Woahh as a user/role in the merchant's Play Console |
| New-account note | Individual vs Organization (org needs D-U-N-S); 2FA required | Identity verification (D-U-N-S for orgs) required |

**Submission checklist (per app):**
- Provisioning: bundle ID registered; capabilities enabled (Push, Associated Domains; later Tap-to-Pay entitlement); APNs .p8 in Firebase.
- **Privacy:** Apple **App Privacy "nutrition labels"** (data collected: account/email, payment via Stripe, usage, location if used) + Google Play **Data Safety** form. Privacy policy URL (`/privacy`).
- **Assets:** app icon, iOS screenshots (per device class), Android phone/tablet screenshots + feature graphic, unique per-merchant listing copy.
- **Clear 4.2:** demonstrate native value (push, QR/camera, offline cart, deep links) so it's not "just a website."
- Deep-link association files live + verifying (`apple-app-site-association`, `assetlinks.json`).
- TestFlight (iOS) / internal testing (Android) pass before production review.

**Honest blocker:** iOS builds + the first submission **require a Mac + Xcode 26** (or a Mac CI runner / Codemagic mac builders). There is no Linux path to an iOS binary.

---

## 8. Tiering + cost

Map to existing `org_tier` (`free_trial | solo | marketplace | growth | enterprise`):

| Tier | App offering |
|---|---|
| free_trial / solo | Listing in the **one Woahh app** (Model A) + **installable PWA** on `<slug>.woahh.app` |
| marketplace | Same + featured placement + branded PWA |
| **growth** | **+ Standalone native app (Model C)** — merchant's own iOS+Android listing, OTA-maintained — headline add-on |
| enterprise | Native app included; priority build queue, custom bundle ID, optional Woahh-managed merchant accounts |

**Per-merchant cost / effort (Model C):**
- Store fees: **$99/yr Apple + $25 once Google per merchant** (merchant-borne under decentralized accounts).
- Build/submit: automated CI (~minutes compute) + occasional manual rejection-fix labor.
- OTA: one shared channel (~$12–$249/mo **total**, not per merchant).
- **Ongoing maintenance:** shared engine upkeep + per-app: account renewals, store-policy resubmissions (SDK/Xcode minimums force periodic native rebuilds — the irreducible floor), review rejections. Industry maintenance runs $50–$500+/app/mo; amortizing one engine targets the low end.
- **Price anchor:** Bopple (direct AU competitor) charges **$99/mo** white-label web, **$399/mo** for the web+iOS+Android bundle — our native add-on ceiling/reference.

**Model A cost:** $99/yr Apple + $25 once Google **total** for the whole platform.

---

## 9. Phased roadmap

**Phase 0 — NOW (PWA install polish, $0 store overhead):**
- Add an explicit **"Install app / Add to Home Screen"** path on each `<slug>.woahh.app` storefront (`beforeinstallprompt` on Android/desktop, iOS A2HS hint), per-merchant 192/512 maskable icons (the pending `pwaManifest.ts` item on `feat/storefront-platform`). Every merchant gets an installable branded app today.

**Phase 1 — single Woahh Capacitor app / pilot:**
- Scaffold Capacitor (this branch): `capacitor.config.ts` (`webDir:"dist"`, keep `base:"/"`), add `android/` (+ `ios/` on a Mac), core plugins.
- Land the **pre-build code changes** (verified sites): `nativeRedirectBase()` replacing the ~10 `window.location.origin` redirects; gate `/sw.js` to web-only (`src/main.tsx:32`); Android back-button → router; swap Web Push → native push (`OrderStatus.tsx`); add `VITE_FORCED_SLUG` seam in `src/App.tsx`.
- Provision Firebase + APNs .p8; add `capacitor://localhost` + `https://localhost` to Supabase redirect allow-list; verify Stripe edge-fn CORS.
- Ship **one** "Woahh" consumer app (Model A, the `/eat` aggregator). Pilot via TestFlight / internal track.

**Phase 2 — per-merchant white-label pipeline (Growth+):**
- Build the CI engine (§6): forced-slug injection, `@capacitor/assets`, fastlane + App Store Connect API Key, `merchant_app_builds` table + dashboard flow to collect merchant store credentials.
- Integrate **Capgo OTA** (encrypted channel + staged rollout).
- Pilot Model C with 2–3 Growth merchants **under their own developer accounts**; require unique listing copy/screenshots; document the rejection-fix loop. Then productize as a self-serve Growth/Enterprise add-on.

**Future — Tap to Pay (separate native track):**
- AU is supported via Stripe Terminal; **Tap to Pay is NOT supported on Capacitor** (needs the Terminal iOS/React-Native SDK → a native/RN shell, not the WebView build). Requires **two Apple entitlements** (`com.apple.developer.proximity-reader.payment.acceptance`): development (~1–2 days) + **distribution (~1–2 weeks Apple review)**. iPhone XS+ / iOS 16.4+ (18.0+ for the merchant-education overlay). Preserves the in-person 4% → 2%/2% charity split via `application_fee_amount`. Start AU entitlement requests early. See `docs/POS_TERMINAL_PLAN.md`.

---

## 10. What the committed scaffold in THIS branch provides

Scaffolded + verified on `feat/native-app-platform` (2026-06-07). Capacitor **8.4.0**
(plugins `@capacitor/app@8.1.0`, `status-bar@8.0.2`, `splash-screen@8.0.1`,
`keyboard@8.0.3`, `network@8.0.1`; CLI as devDep — all version-pinned). The web app is
**behaviour-unchanged**: web `npm run build` is green, `tsc -p tsconfig.app.json --noEmit`
shows only the 8 known pre-existing errors, and every native seam returns today's web
value on the web. See `docs/NATIVE_SCAFFOLD.md` for the run guide.

### Files added
- **`capacitor.config.ts`** — `appId: com.woahh.app`, `appName: Woahh`, `webDir: "dist"`
  (keeps Vite default `base: "/"`); SplashScreen + StatusBar (forest-green `#1e3d2f`) +
  Keyboard plugin config. **Per-merchant override hook:** reads `CAP_APP_ID` / `CAP_APP_NAME`
  from env at build time (so the pipeline produces a per-merchant bundle without editing
  the file). **Opt-in dev live-reload:** a `server` block appears only if `CAP_SERVER_URL`
  is set (off by default — never in a release build).
- **`android/`** — full native Gradle project (`npx cap add android`, succeeded). Build
  outputs (`build/`, `.gradle/`, copied `assets/public`, generated `capacitor.config.json`/
  `capacitor.plugins.json`/`config.xml`, `local.properties`, cordova-plugins) are gitignored
  (both the generated `android/.gitignore` + explicit root `.gitignore` rules); ~53 source
  files are tracked.
- **`src/lib/native.ts`** — `isNativePlatform()` (SSR/web-safe wrapper, try/catch),
  `nativeRedirectBase()` (web: `window.location.origin`; native: `VITE_NATIVE_REDIRECT_BASE`
  || `https://woahh.app`), `forcedSlug()` (`VITE_FORCED_SLUG` or null).
- **`scripts/build-merchant-app.mjs`** — Model C per-merchant build starter: validates a
  merchant JSON, injects `VITE_FORCED_SLUG`/`VITE_NATIVE_TARGET`/`VITE_NATIVE_REDIRECT_BASE`
  + `CAP_APP_ID`/`CAP_APP_NAME`, runs `vite build` → `cap sync`, optionally `@capacitor/assets`
  for icons, prints next `cap open`/fastlane signing+submission steps.
- **`merchants/example.json`** — sample build-input config (slug, appId, appName, color, icon).
- **`docs/NATIVE_SCAFFOLD.md`** — run guide (local, per-merchant build, container-vs-Mac matrix, OTA note).

### npm scripts added
- `cap:sync` → `npm run build && cap sync`
- `cap:android` → `npm run build && cap sync android && cap open android`
- `build:merchant` → `node scripts/build-merchant-app.mjs`

### Code seams wired (all web-behaviour-preserving)
- **`nativeRedirectBase()`** replaces `window.location.origin` in the **10 auth /
  magic-link / Stripe `return_url`** sites: `CardPayment.tsx` (×1), `Auth.tsx` (×2),
  `CustomerForm.tsx` (×2), `useCustomerAuth.ts` (×3), `Account.tsx` (×1),
  `PostPurchaseModal.tsx` (×2). **Left as-is:** `Tables.tsx:76` (a dine-in **QR-code**
  URL, not an auth/Stripe redirect).
- **`forcedSlug()`** read once in `src/App.tsx`; root `/` renders `<Shop forcedSlug=…>`
  when set (per-merchant native build), else the marketing `<Storefront/>` (null on web).
  `src/pages/Shop.tsx` gained an optional `forcedSlug` prop (falls back to the URL `:slug`).
- **Service worker** registration in `src/main.tsx` gated to web only (`!isNativePlatform()`).

### What's left (not in this scaffold)
- **iOS** — `ios/` is intentionally NOT committed. On a Mac: `npx cap add ios` then
  `npx cap open ios` (Xcode 26+). No Linux path to an iOS binary.
- **Native build/run** — APK/AAB needs Android SDK + Android Studio (not in this container);
  iOS needs Mac + Xcode.
- **Native push (FCM/APNs)** — Firebase project + APNs `.p8`; `@capacitor-firebase/messaging`
  + a second send path in `order-notify` (§3.5).
- **Signing + store submission** — Apple Developer ($99/yr) / Play Console ($25), fastlane
  lanes, App Store Connect API key / Play service account (§6.3, §7).
- **OTA** — Capgo integration (§6.4). **Deep links** — association files + `appUrlOpen`
  routing + Android hardware-back → router (§3.2). **Tap to Pay** — separate native track (§9).
