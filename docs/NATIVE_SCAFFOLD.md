# Native scaffold — how to run it

The committed Capacitor scaffold on `feat/native-app-platform`. It wraps the
existing Vite/React `dist/` bundle into a native app — no UI rewrite. This is the
"execute" half of `docs/NATIVE_APP_PLATFORM.md`; read that plan for the *why*
(§3 architecture, §4 white-label compliance, §6 build pipeline, §10 deliverable list).

---

## What's committed

| Path | What |
|---|---|
| `capacitor.config.ts` | Capacitor config (`appId: com.woahh.app`, `appName: Woahh`, `webDir: "dist"`, SplashScreen/StatusBar/Keyboard plugin config). Env-switched per-merchant overrides (`CAP_APP_ID`/`CAP_APP_NAME`) + opt-in dev live-reload (`CAP_SERVER_URL`). |
| `android/` | Native Android Gradle project (added via `npx cap add android`). Build outputs (`build/`, `.gradle/`, copied web assets, generated config) are gitignored. |
| `src/lib/native.ts` | `isNativePlatform()`, `nativeRedirectBase()`, `forcedSlug()` — web-safe seams; return today's web values on web. |
| `scripts/build-merchant-app.mjs` | Per-merchant white-label build starter (Model C). |
| `merchants/example.json` | Sample merchant build-input config. |
| npm scripts | `cap:sync`, `cap:android`, `build:merchant`. |

iOS (`ios/`) is **not committed** — it requires a Mac + Xcode 26 (see below).

---

## Run it locally

```bash
npm install                 # installs deps incl. Capacitor 8
npm run build               # builds the web bundle to dist/
npx cap sync android        # copies dist/ + plugins into android/
# (equivalently: npm run cap:sync)
```

### Open / run the Android app

Needs the **Android SDK + Android Studio** (NOT available in this container — see
"What works here" below):

```bash
npx cap open android        # opens Android Studio → Run on emulator/device
# or: npm run cap:android   (build + sync + open)
```

### Dev live-reload (optional)

Point the native WebView at your local Vite dev server (do NOT ship this):

```bash
CAP_SERVER_URL=http://<your-LAN-ip>:8080 npx cap sync android
npm run dev -- --host
```

Remove `CAP_SERVER_URL` and re-sync before any release build.

---

## Per-merchant white-label build (Model C)

One engine → one signed binary per merchant. Edit/copy `merchants/example.json`,
then:

```bash
npm run build:merchant -- merchants/example.json
# or a single platform:
node scripts/build-merchant-app.mjs merchants/example.json --platform android
```

It injects the five build inputs (`docs/NATIVE_APP_PLATFORM.md` §6.1):
`VITE_FORCED_SLUG` (boots straight into the merchant storefront via the
`forcedSlug()` seam wired into `App.tsx`'s root route), `CAP_APP_ID` / `CAP_APP_NAME`
(read by `capacitor.config.ts`), the native redirect base, and (optionally) per-merchant
icons/splash via `@capacitor/assets`. It then runs `vite build` + `cap sync` and prints
the next `cap open` / fastlane signing + submission steps.

**Compliance reminder:** per-merchant apps must be published under the **merchant's
own** Apple/Play developer account, with unique listing copy — never under Woahh's
account (Apple 4.2.6 + 4.3 / Google Repetitive-Content). See plan §4.

---

## Code seams added (web behaviour unchanged)

`src/lib/native.ts` returns today's web values on the web, so these are
behaviour-preserving on the web app:

- **`nativeRedirectBase()`** replaces `window.location.origin` in the ~10 auth /
  magic-link / Stripe `return_url` sites. On web it returns `window.location.origin`
  (identical to before); in a native WebView it returns the real HTTPS base
  (`VITE_NATIVE_REDIRECT_BASE`, default `https://woahh.app`) because
  `capacitor://localhost` can't be an email/Stripe redirect target.
  - Migrated: `CardPayment.tsx` (Stripe 3DS return), `Auth.tsx` (×2 owner signup +
    resend), `CustomerForm.tsx` (×2 magic link + reset), `useCustomerAuth.ts`
    (×3 magic link, signup redirect, password reset), `Account.tsx` (magic link),
    `PostPurchaseModal.tsx` (×2 account-from-order).
  - **Deliberately left:** `Tables.tsx:76` builds a **dine-in QR-code URL** (a link
    a customer *scans*, not an auth/Stripe redirect) — not in scope for the native
    redirect seam. (If a native dashboard build ever generates these, switch it to a
    fixed `https://woahh.app` base.)
- **`forcedSlug()`** is read once in `App.tsx`; when set (per-merchant native build),
  the root `/` route renders `<Shop forcedSlug=…>` instead of the marketing
  `<Storefront/>`. Null on web → unchanged.
- **Service worker** registration in `main.tsx` is gated to web only
  (`!isNativePlatform()`) — Capacitor serves its own bundle and uses native push.

---

## What works in this container vs needs a Mac / Android Studio

| Step | This Linux container | Needs |
|---|---|---|
| `npm install` (Capacitor 8) | ✅ | — |
| `npm run build` (web bundle) | ✅ | — |
| `npx cap add android` | ✅ (scaffolds the Gradle project) | — |
| `npx cap sync android` | ✅ | — |
| Build an APK/AAB (`./gradlew`, `cap open android`) | ❌ | **Android SDK + JDK + Android Studio** (not installed here) |
| `npx cap add ios` / `cap sync ios` | ⚠️ scaffolds on Linux (Capacitor 8 uses SwiftPM), but the result is **not committed / not buildable here** | **Mac + Xcode 26** to build, sign, run |
| Build/sign/submit iOS | ❌ | **Mac + Xcode 26** — no Linux path exists |
| Native push (APNs/FCM) | ❌ (not in scaffold) | Firebase project + APNs `.p8` (plan §3.5) |
| Code signing + store submission | ❌ | Apple Developer ($99/yr) / Play Console ($25), fastlane (plan §7) |

**iOS:** to add it, on a Mac run `npx cap add ios` then `npx cap open ios`. The
scaffold deliberately omits `ios/` so the repo never carries an unbuildable, unverified
Xcode project.

---

## OTA note

Native binaries are heavy to rebuild/resubmit per merchant, but all merchant apps
share the **same web bundle**, so one OTA push services the whole fleet (maintenance is
sublinear). Plan to integrate **Capgo** (`@capgo/capacitor-updater`, open-source,
encrypted channels, staged rollout, auto-rollback) — NOT bundled in this scaffold
(avoid Ionic Appflow, closing). **Allowed via OTA:** HTML/CSS/JS (UI/copy/bug fixes).
**Not allowed:** native/plugin changes or new features (Apple 2.5.2) — those need a
rebuild + resubmit. See plan §6.4.

---

## Not in the scaffold (deliberately deferred — see plan)

Push/FCM plugins, Stripe Terminal / Tap-to-Pay, deep-link association files
(`apple-app-site-association`, `assetlinks.json`), Android hardware-back→router
wiring, `@capacitor/preferences`-backed session store, fastlane lanes, and the
`merchant_app_builds` table + dashboard credential-collection flow. These are
listed in `docs/NATIVE_APP_PLATFORM.md` §3.2 / §6 / §9.
