# Woahh Pitch — Slide Structure & Setup Guide

## Slide Structure (13 slides)

| # | Title | Layout | Key Visual |
|---|-------|--------|------------|
| 1 | **Cover** | Dark (navy) full bleed | Large wordmark + orange accent strip |
| 2 | **The Problem** | Light, 2-column contrast | Big brands (dark card) vs small biz (light card) |
| 3 | **Cost of Status Quo** | Light, table | Formatted table with red total row |
| 4 | **The Solution** | Dark (navy) | 3 feature pillar cards |
| 5 | **Plans & Pricing** | Light, 4 plan cards | Growth tier highlighted as hero |
| 6 | **Unit Economics** | Light, chart + cards | Clustered bar: Revenue / Cost / Profit per tier |
| 7 | **The Giving Model** | Light, stat row + steps | 4 big stat blocks + 5-step process |
| 8 | **What's Built** | Light, 2-column status | Built (green) vs Remaining (amber) |
| 9 | **Growth Model** | Light, chart + milestones | Line chart: Revenue + Giving vs merchant count |
| 10 | **Why We Win** | Light, 4 moat cards | Icon + title + body for each moat |
| 11 | **Go To Market** | Light, timeline + info card | 3-phase vertical timeline + Brisbane reasons |
| 12 | **Who We're Looking For** | Light, 4 role cards | Co-founder roles with context |
| 13 | **Close** | Dark (navy) full bleed | Bold 3-line statement + open questions |

---

## Colour Palette

| Name | Hex | Usage |
|------|-----|-------|
| Orange | `#FF5C00` | Primary brand, CTAs, accents |
| Orange Light | `#FF8C42` | Subheadings on dark |
| Navy | `#0F172A` | Dark slides, headings |
| Navy Mid | `#1E293B` | Cards on dark bg |
| Slate | `#475569` | Body text |
| White | `#FFFFFF` | Light slide backgrounds |
| Off White | `#F8FAFC` | Slide backgrounds |
| Green | `#10B981` | Charity / positive metrics |
| Amber | `#F59E0B` | "Remaining to build" callouts |
| Red | `#EF4444` | Problem / cost callouts |

---

## Setup & Run

```bash
# 1. Install dependencies
npm install pptxgenjs react react-dom react-icons sharp

# 2. Generate the deck
node generate-pitch.js

# 3. Output
# → Woahh-CoFounder-Pitch.pptx
```

### Requirements
- Node.js 18+
- npm

### Dependencies
- `pptxgenjs` — PPTX generation
- `react` + `react-dom` + `react-icons` — icon rendering
- `sharp` — SVG → PNG rasterization for icons

---

## Files in This Folder

| File | Purpose |
|------|---------|
| `generate-pitch.js` | Main PPTX generation script |
| `SPEAKER-SCRIPT.md` | Word-for-word speaker notes per slide |
| `SLIDE-STRUCTURE.md` | This file |
| `pitch.md` | Full written pitch with ASCII UI mockups |

---

## Customisation Notes

- **Fonts**: Script uses Calibri (universally available). Swap `fontFace` values to use custom fonts if installed.
- **Logo**: Add `slide.addImage({ path: 'logo.png', ... })` calls on each slide once the name/logo is decided.
- **Charts**: All charts are native PptxGenJS charts (editable in PowerPoint). Slide 6 and 9 can be updated with real data by changing the `values` arrays.
- **Colours**: All colours are defined in the `C` object at the top of `generate-pitch.js` — change once, propagates everywhere.

---

## Slide 8 Note — Name Decision

The "What's Built" slide carries the co-founder hook:

> *"The app is fully functional right now. The single remaining non-technical decision is the name. The moment we decide — together — the domain goes live and email infrastructure follows the same day."*

This positions the name decision as the first thing we do together — not a gap to fill, but a concrete milestone that belongs to the partnership.

---

## Slide 12 Note — Co-Founder Framing

Slide 12 is titled **"Who We're Looking For"** (not "The Ask" or "What We Need"). The four cards describe co-founder roles/skills:

1. **Merchant Acquisition** — relationships in hospitality/retail; sales motion
2. **Operator Mindset** — repeatable process; the gap between 10 and 200 merchants is systems
3. **Market Expansion** — localisation, compliance, cross-border partnerships
4. **Brand & Consumer Audience** — building the /eat consumer side

The footer: *"We're not looking for someone to execute a plan. We're looking for someone who looks at this and sees what they'd change."*
