# Overnight handoff — 2026-06-02 → morning review

Everything below is committed + pushed. **Nothing touched `main`/prod.** Review at your leisure.

## 1. Promo video — DONE (branch `marketing/woahh-promo-ad`, commit `bd6e14b`)
Open `repo-promo/marketing/woahh-promo.html` (Play with sound). ~53s, paced for a voiceover.
- **Recaptured on the live green/gold UI** — all screens current.
- **"Woahh does it all"** on the logo beat.
- **AI menu-import chatbot scene** (snap a photo → menu builds).
- **Order-journey scene** — service take-order → ticket flies → **live NEW ORDER card pops onto the kitchen kanban**.
- **9-stop dashboard tour** incl. Marketing, **Staff (with example team)**, Customers, Marketplace; gold-lit pills + count-ups.
- **Payoff:** 4 stat cards (4% / 0% founding / own customer / ~2% to charity) + "from $49/mo".
- **Investor cut:** `woahh-promo-vc.html` (or `?mode=vc`) — giving-flywheel ending.
- **Fixed:** the cropped frames (now exact 16:9, motion settles to full frame).
- **`VO-SCRIPT.md`** — timed voiceover script (restaurant + investor cuts), with ~3s headroom reserved for the Inventory beat.

## 2. VC pitch deck — DONE (docs repo, commit `1d42fdf`)
Open `docs/pitch/woahh-vc-deck.html` (← → to navigate, F = fullscreen). 17 slides, branded forest/gold.
- Cold-open stat → problem → why-now → solution → product → **"giving is the growth engine"** reframe → 3 moats → business model → unit economics → market bar-chart (Woahh + charity) → competition matrix → GTM flywheel → honest traction → **expansion (Eat → Shop → Book)** → ask → mission close (animated charity count-up).
- **Real numbers** from the locked model (3%+1%, $15k GMV base, $49/$89/$150, ~$345/merchant/mo, ~94% margin, M4/M12 milestones, $4.13M→$20.7M/yr to charity).
- **Expansion finale** = the "surprise": **Shop mode** (retail) + **Service/Book mode** (barbers, nail/beauty salons, fitness) on the same rails.
- `VC_PITCH_DECK.md` = content source-of-truth (added the expansion slide).
- **You fill the `[founder]` blanks:** TAM/SAM, team, ask amount, paying-merchant count, founding-offer duration.

## 3. Inventory mode — PENDING (timer set)
You said inventory mode lands in ~5h. A best-effort wake-up timer is set to look for an `inventory` branch (or it landing in `main`), capture screenshots, and add an **Inventory** beat to both the deck (slide reserved) and the video (VO headroom reserved between Menu and Marketing).
- **If the timer didn't fire** (session/container reset): manually re-trigger — `cd repo && git fetch && git branch -a | grep -i inventor`; if found, capture with the `/tmp/pwtest` harness (same pattern as `capture_extra.cjs`) and drop the shot into `repo-promo/marketing/shots/` + a deck slide.

## Open decisions still waiting on you
- Founding-offer **duration** (1yr vs lifetime).
- Real **1200×630 og-image** (social cards currently fall back to the logo).
- Deck `[founder]` blanks (above).
- Promo length ~53s — say if you want a ~35s social trim.
