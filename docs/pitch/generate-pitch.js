// GrowthHub Co-Founder Pitch Deck
// Run: node generate-pitch.js
// Requires: npm install pptxgenjs react react-dom react-icons sharp

const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");

// ─── ICONS ────────────────────────────────────────────────────────────────────
const {
  FaRocket, FaStore, FaChartLine, FaHeart, FaCheckCircle,
  FaMapMarkerAlt, FaDollarSign, FaUsers, FaLock, FaBolt
} = require("react-icons/fa");

async function iconToBase64Png(IconComponent, color = "#FFFFFF", size = 256) {
  const svg = ReactDOMServer.renderToStaticMarkup(
    React.createElement(IconComponent, { color, size: String(size) })
  );
  const pngBuffer = await sharp(Buffer.from(svg)).png().toBuffer();
  return "image/png;base64," + pngBuffer.toString("base64");
}

// ─── PALETTE ──────────────────────────────────────────────────────────────────
const C = {
  orange:     "FF5C00",  // Primary brand — bold energy
  orangeLight:"FF8C42",  // Secondary orange
  navy:       "0F172A",  // Dark text / dark slides
  navyMid:    "1E293B",  // Card backgrounds on dark
  slate:      "475569",  // Subtext
  white:      "FFFFFF",
  offWhite:   "F8FAFC",
  green:      "10B981",  // Positive / charity
  greenLight: "D1FAE5",
  amber:      "F59E0B",
  amberLight: "FEF3C7",
  red:        "EF4444",
  border:     "E2E8F0",
};

// ─── HELPERS ──────────────────────────────────────────────────────────────────
function makeShadow() {
  return { type: "outer", blur: 10, offset: 3, angle: 135, color: "000000", opacity: 0.10 };
}

function card(slide, x, y, w, h, fillColor = C.white) {
  slide.addShape("rect", {
    x, y, w, h,
    fill: { color: fillColor },
    line: { color: C.border, pt: 0.5 },
    shadow: makeShadow(),
  });
}

function statBlock(slide, x, y, w, number, label, numColor = C.orange) {
  card(slide, x, y, w, 1.3);
  slide.addText(number, {
    x: x + 0.15, y: y + 0.10, w: w - 0.3, h: 0.7,
    fontSize: 34, bold: true, color: numColor, align: "center", margin: 0,
  });
  slide.addText(label, {
    x: x + 0.10, y: y + 0.80, w: w - 0.2, h: 0.42,
    fontSize: 10, color: C.slate, align: "center", margin: 0,
  });
}

function sectionTag(slide, label, color = C.orange) {
  slide.addShape("rect", { x: 0.5, y: 0.22, w: 1.6, h: 0.28, fill: { color: color }, line: { color: color } });
  slide.addText(label.toUpperCase(), {
    x: 0.5, y: 0.22, w: 1.6, h: 0.28,
    fontSize: 8, bold: true, color: C.white, align: "center", valign: "middle", margin: 0,
  });
}

function slideTitle(slide, title, sub = "") {
  slide.addText(title, {
    x: 0.5, y: 0.62, w: 9, h: 0.7,
    fontSize: 30, bold: true, color: C.navy, align: "left", margin: 0,
  });
  if (sub) {
    slide.addText(sub, {
      x: 0.5, y: 1.32, w: 9, h: 0.35,
      fontSize: 13, color: C.slate, align: "left", margin: 0,
    });
  }
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
async function buildDeck() {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_16x9"; // 10" × 5.625"
  pres.title = "GrowthHub — Co-Founder Pitch";
  pres.author = "GrowthHub";

  // Pre-render icons
  const iconRocket    = await iconToBase64Png(FaRocket,       "#" + C.white);
  const iconStore     = await iconToBase64Png(FaStore,        "#" + C.orange);
  const iconChart     = await iconToBase64Png(FaChartLine,    "#" + C.green);
  const iconHeart     = await iconToBase64Png(FaHeart,        "#" + C.green);
  const iconCheck     = await iconToBase64Png(FaCheckCircle,  "#" + C.green);
  const iconCheckOrg  = await iconToBase64Png(FaCheckCircle,  "#" + C.orange);
  const iconPin       = await iconToBase64Png(FaMapMarkerAlt, "#" + C.orange);
  const iconDollar    = await iconToBase64Png(FaDollarSign,   "#" + C.orange);
  const iconUsers     = await iconToBase64Png(FaUsers,        "#" + C.orange);
  const iconLock      = await iconToBase64Png(FaLock,         "#" + C.orange);
  const iconBolt      = await iconToBase64Png(FaBolt,         "#" + C.white);

  // ── SLIDE 1: COVER ────────────────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.navy };

    // Orange accent strip left
    s.addShape("rect", { x: 0, y: 0, w: 0.08, h: 5.625, fill: { color: C.orange }, line: { color: C.orange } });

    s.addText("GrowthHub", {
      x: 0.5, y: 1.3, w: 9, h: 1.1,
      fontSize: 60, bold: true, color: C.white, align: "left", margin: 0,
    });
    s.addText("The complete digital stack for small business.", {
      x: 0.5, y: 2.55, w: 8, h: 0.5,
      fontSize: 18, color: C.orangeLight, align: "left", margin: 0,
    });
    s.addText("$49/mo · No transaction fees · Built for Brisbane, scaling globally.", {
      x: 0.5, y: 3.15, w: 8, h: 0.4,
      fontSize: 13, color: "94A3B8", align: "left", margin: 0,
    });
    s.addImage({ data: iconRocket, x: 8.8, y: 3.8, w: 0.7, h: 0.7 });
    s.addText("Co-Founder Pitch · 2026", {
      x: 0.5, y: 5.1, w: 4, h: 0.3,
      fontSize: 10, color: "475569", align: "left", margin: 0,
    });
  }

  // ── SLIDE 2: THE PROBLEM ───────────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "The Problem");
    slideTitle(s, "Small businesses are losing a war they don't know they're in.");

    // Two column contrast
    // Left: Big brands
    s.addShape("rect", { x: 0.5, y: 1.85, w: 4.1, h: 3.3, fill: { color: C.navy }, line: { color: C.navy } });
    s.addText("Big Brands", { x: 0.6, y: 1.95, w: 3.9, h: 0.35, fontSize: 12, bold: true, color: C.orangeLight, margin: 0 });
    const bigBrandFeatures = ["Own branded app", "Full customer CRM", "Push notifications", "Loyalty programs", "Re-engagement campaigns", "Own every email"];
    bigBrandFeatures.forEach((f, i) => {
      s.addImage({ data: iconCheck, x: 0.65, y: 2.4 + i * 0.38, w: 0.22, h: 0.22 });
      s.addText(f, { x: 0.95, y: 2.36 + i * 0.38, w: 3.4, h: 0.3, fontSize: 11, color: C.white, margin: 0 });
    });

    // Right: Small biz
    s.addShape("rect", { x: 5.0, y: 1.85, w: 4.4, h: 3.3, fill: { color: C.white }, line: { color: C.border, pt: 1 } });
    s.addText("Small Businesses", { x: 5.1, y: 1.95, w: 4.2, h: 0.35, fontSize: 12, bold: true, color: C.red, margin: 0 });
    const sbPain = ["Square terminal + Facebook page", "No customer data ownership", "Can't send a birthday reward", "Paying 25–30% to DoorDash", "$50K+ for a custom app", "Losing customers every week"];
    sbPain.forEach((f, i) => {
      s.addText("✕", { x: 5.1, y: 2.36 + i * 0.38, w: 0.28, h: 0.3, fontSize: 12, bold: true, color: C.red, margin: 0 });
      s.addText(f, { x: 5.42, y: 2.36 + i * 0.38, w: 3.8, h: 0.3, fontSize: 11, color: C.slate, margin: 0 });
    });
  }

  // ── SLIDE 3: COST OF STATUS QUO ───────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "The Cost");
    slideTitle(s, "What it costs a $50K/mo restaurant just to exist digitally.", "Before they pay rent, wages, or food.");

    // Table
    const tableRows = [
      [
        { text: "Provider",      options: { bold: true, color: C.white, fill: { color: C.navy } } },
        { text: "What They Get", options: { bold: true, color: C.white, fill: { color: C.navy } } },
        { text: "Monthly Cost",  options: { bold: true, color: C.white, fill: { color: C.navy } } },
      ],
      ["Square for Restaurants Plus",   "POS, basic ordering, loyalty",           "$165/mo"],
      ["Square transaction fees",       "2.6% + 10¢ per swipe",                   "~$1,310/mo"],
      ["Uber Eats / DoorDash",          "Discovery + delivery (25–30% per order)", "~$3,750–4,500/mo"],
      ["Agency website",                "Static page, no ordering",               "$100–300/mo hosting"],
      ["Custom branded app",            "App Store presence",                     "$50K–150K build cost"],
      [
        { text: "TOTAL",         options: { bold: true, color: C.navy } },
        { text: "",              options: {} },
        { text: "$5,000–6,000+/mo", options: { bold: true, color: C.red } },
      ],
    ];
    s.addTable(tableRows, {
      x: 0.5, y: 1.75, w: 9, h: 3.5,
      border: { pt: 0.5, color: C.border },
      colW: [3.2, 3.8, 2.0],
      fontFace: "Calibri",
      fontSize: 11,
      align: "left",
      valign: "middle",
      rowH: 0.42,
    });
  }

  // ── SLIDE 4: THE SOLUTION ──────────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.navy };

    // Orange accent
    s.addShape("rect", { x: 0, y: 0, w: 10, h: 0.08, fill: { color: C.orange }, line: { color: C.orange } });

    s.addText("GrowthHub gives every small business", {
      x: 0.5, y: 0.4, w: 9, h: 0.55, fontSize: 22, color: "94A3B8", align: "left", margin: 0,
    });
    s.addText("the same tech stack as Dominos.", {
      x: 0.5, y: 0.95, w: 9, h: 0.65, fontSize: 30, bold: true, color: C.white, align: "left", margin: 0,
    });
    s.addText("For less than $10 a day.", {
      x: 0.5, y: 1.6, w: 9, h: 0.5, fontSize: 22, bold: true, color: C.orange, align: "left", margin: 0,
    });

    // 3 feature pillars
    const pillars = [
      { icon: iconStore,  title: "Full Stack Presence",    body: "Branded storefront, orders, KDS, tables, reservations — one platform." },
      { icon: iconUsers,  title: "Own Your Customers",     body: "CRM, loyalty engine, SMS & email campaigns. Your data, forever." },
      { icon: iconHeart,  title: "Zero Commission",        body: "Flat monthly fee. No % on orders. Keep every dollar you earn." },
    ];
    pillars.forEach((p, i) => {
      const x = 0.5 + i * 3.2;
      s.addShape("rect", { x, y: 2.4, w: 3.0, h: 2.9, fill: { color: C.navyMid }, line: { color: "334155" } });
      s.addImage({ data: p.icon, x: x + 0.2, y: 2.55, w: 0.45, h: 0.45 });
      s.addText(p.title, { x: x + 0.1, y: 3.1, w: 2.8, h: 0.4, fontSize: 13, bold: true, color: C.white, align: "left", margin: 0 });
      s.addText(p.body,  { x: x + 0.1, y: 3.55, w: 2.8, h: 1.1, fontSize: 10.5, color: "94A3B8", align: "left", margin: 0 });
    });
  }

  // ── SLIDE 5: PLANS & PRICING ───────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "Pricing");
    slideTitle(s, "Four tiers. One flat fee. 60-day free trial on every plan.");

    const plans = [
      { name: "Solo",        price: "$49",   color: C.slate,   features: ["Orders + Kitchen Display", "Storefront", "Tables + Reservations", "2,000 emails/mo", "1 location", "$10/mo charity"] },
      { name: "Marketplace", price: "$99",   color: C.orange,  features: ["Everything in Solo", "CRM + Loyalty", "700 SMS/mo", "15,000 emails/mo", "Up to 3 locations", "$25/mo charity"] },
      { name: "Growth",      price: "$199",  color: C.navy,    features: ["Everything in Marketplace", "1,000 SMS/mo", "50,000 emails/mo", "Custom domain + PWA", "Priority placement", "$40/mo charity"] },
      { name: "Enterprise",  price: "Custom",color: "6B7280",  features: ["Unlimited everything", "2,500 SMS/mo", "100,000 emails/mo", "Dedicated support", "Multi-location", "Negotiated charity"] },
    ];

    plans.forEach((p, i) => {
      const x = 0.3 + i * 2.38;
      const isHighlight = i === 2; // Growth is hero plan
      s.addShape("rect", {
        x, y: 1.75, w: 2.25, h: 3.6,
        fill: { color: isHighlight ? C.navy : C.white },
        line: { color: isHighlight ? C.orange : C.border, pt: isHighlight ? 2 : 0.5 },
        shadow: makeShadow(),
      });
      if (isHighlight) {
        s.addShape("rect", { x, y: 1.75, w: 2.25, h: 0.32, fill: { color: C.orange }, line: { color: C.orange } });
        s.addText("MOST POPULAR", { x, y: 1.75, w: 2.25, h: 0.32, fontSize: 8, bold: true, color: C.white, align: "center", valign: "middle", margin: 0 });
      }
      const yStart = isHighlight ? 2.15 : 1.85;
      s.addText(p.name, { x: x + 0.1, y: yStart, w: 2.05, h: 0.32, fontSize: 13, bold: true, color: isHighlight ? C.white : C.navy, margin: 0 });
      s.addText(p.price, { x: x + 0.1, y: yStart + 0.35, w: 2.05, h: 0.45, fontSize: 22, bold: true, color: isHighlight ? C.orange : p.color, margin: 0 });
      if (p.price !== "Custom") s.addText("/mo", { x: x + 0.1, y: yStart + 0.8, w: 2.05, h: 0.25, fontSize: 10, color: isHighlight ? "94A3B8" : C.slate, margin: 0 });

      p.features.forEach((f, fi) => {
        s.addImage({ data: isHighlight ? iconCheck : iconCheckOrg, x: x + 0.12, y: yStart + 1.15 + fi * 0.36, w: 0.18, h: 0.18 });
        s.addText(f, { x: x + 0.38, y: yStart + 1.11 + fi * 0.36, w: 1.8, h: 0.28, fontSize: 9.5, color: isHighlight ? "CBD5E1" : C.slate, margin: 0 });
      });
    });
  }

  // ── SLIDE 6: UNIT ECONOMICS ────────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "Unit Economics");
    slideTitle(s, "Gross margins of 76–81%. Profitable from merchant #1.");

    // Chart: Revenue vs Cost vs Profit by tier
    s.addChart(pres.charts.BAR, [
      { name: "Revenue (incl. transaction fees)", labels: ["Solo $49", "Marketplace $99", "Growth $199"], values: [61, 126, 259] },
      { name: "Cost to Serve",                    labels: ["Solo $49", "Marketplace $99", "Growth $199"], values: [11, 30, 50] },
      { name: "Gross Profit",                     labels: ["Solo $49", "Marketplace $99", "Growth $199"], values: [50, 96, 209] },
    ], {
      x: 0.5, y: 1.75, w: 5.8, h: 3.5,
      barDir: "col",
      barGrouping: "clustered",
      chartColors: [C.orange, C.red, C.green],
      chartArea: { fill: { color: C.white }, roundedCorners: false },
      catAxisLabelColor: C.slate,
      valAxisLabelColor: C.slate,
      valGridLine: { color: C.border, size: 0.5 },
      catGridLine: { style: "none" },
      showValue: true,
      dataLabelColor: "1E293B",
      dataLabelFontSize: 9,
      showLegend: true,
      legendPos: "b",
      legendFontSize: 10,
    });

    // Margin callout cards
    const margins = [
      { tier: "Solo",        margin: "~81%", rev: "$61",  cost: "$11" },
      { tier: "Marketplace", margin: "~76%", rev: "$126", cost: "$30" },
      { tier: "Growth",      margin: "~81%", rev: "$259", cost: "$50" },
    ];
    margins.forEach((m, i) => {
      card(s, 6.6, 1.75 + i * 1.18, 3.1, 1.05);
      s.addText(m.tier, { x: 6.75, y: 1.82 + i * 1.18, w: 2.8, h: 0.28, fontSize: 11, bold: true, color: C.navy, margin: 0 });
      s.addText(`Margin: ${m.margin}`, { x: 6.75, y: 2.08 + i * 1.18, w: 1.4, h: 0.28, fontSize: 13, bold: true, color: C.green, margin: 0 });
      s.addText(`Rev ${m.rev} · Cost ${m.cost}`, { x: 6.75, y: 2.37 + i * 1.18, w: 2.8, h: 0.25, fontSize: 9, color: C.slate, margin: 0 });
    });
  }

  // ── SLIDE 7: THE GIVING MODEL ──────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "Mission", C.green);
    slideTitle(s, "20% of revenue goes to charity. Automatically. Verifiably.", "No competitor is within an order of magnitude.");

    // Big stat row
    const giveStats = [
      { n: "$10–40",    l: "Monthly donation\nper merchant" },
      { n: "0.15%",     l: "Of every transaction\nto charity" },
      { n: "~20%",      l: "Of total revenue\ndonated" },
      { n: "$1M+/yr",   l: "At 5,000 merchants\n+ $20K avg GMV" },
    ];
    giveStats.forEach((g, i) => {
      statBlock(s, 0.4 + i * 2.32, 1.75, 2.1, g.n, g.l, C.green);
    });

    // How it works
    s.addShape("rect", { x: 0.5, y: 3.25, w: 9, h: 2.05, fill: { color: C.white }, line: { color: C.border } });
    s.addText("How It Works", { x: 0.65, y: 3.35, w: 4, h: 0.35, fontSize: 12, bold: true, color: C.navy, margin: 0 });

    const steps = [
      "Merchant processes an order through GrowthHub",
      "0.15% is routed directly to a verified charitable cause",
      "GrowthHub retains 0.15% net",
      "Merchant's storefront displays an Impact Partner badge",
      "All giving is publicly verifiable via transparency portal",
    ];
    steps.forEach((st, i) => {
      s.addShape("oval", { x: 0.6, y: 3.78 + i * 0.27, w: 0.22, h: 0.22, fill: { color: C.green }, line: { color: C.green } });
      s.addText(String(i + 1), { x: 0.6, y: 3.78 + i * 0.27, w: 0.22, h: 0.22, fontSize: 9, bold: true, color: C.white, align: "center", valign: "middle", margin: 0 });
      s.addText(st, { x: 0.9, y: 3.76 + i * 0.27, w: 8.4, h: 0.26, fontSize: 10.5, color: C.slate, margin: 0 });
    });
  }

  // ── SLIDE 8: WHAT'S BUILT ──────────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "Product Status");
    slideTitle(s, "80% built. Live. Demonstrable today.", "The app is fully functional. Once we agree on a name, the domain and emails follow.");

    const built = [
      "Order management (kanban + real-time)",
      "Kitchen display system",
      "Products & menu catalog",
      "Public storefront (restaurant + retail)",
      "Customer CRM",
      "Loyalty & rewards engine",
      "SMS campaigns (delivery tracking + opt-out)",
      "Email campaigns (open/click tracking)",
    ];
    const builtCol2 = [
      "Promo codes",
      "Table management + QR zones",
      "Reservations management",
      "Uber Direct delivery integration",
      "Multi-tenant data isolation",
      "Demo mode (full seeded data)",
      "Public customer portal",
      "Owner auth system",
    ];
    const remaining = [
      "Public /eat marketplace UI (API + DB done)",
      "Stripe billing integration",
      "Public impact/transparency portal",
      "Reservation booking widget (public-facing)",
      "Advanced analytics dashboard",
    ];

    // Built — left column
    s.addShape("rect", { x: 0.5, y: 1.75, w: 4.4, h: 3.55, fill: { color: C.white }, line: { color: C.border } });
    s.addText("✅  Already Live", { x: 0.65, y: 1.82, w: 4.0, h: 0.32, fontSize: 11, bold: true, color: C.green, margin: 0 });
    built.forEach((f, i) => {
      s.addText(`· ${f}`, { x: 0.7, y: 2.22 + i * 0.29, w: 2.0, h: 0.27, fontSize: 9.5, color: C.slate, margin: 0 });
    });
    builtCol2.forEach((f, i) => {
      s.addText(`· ${f}`, { x: 2.75, y: 2.22 + i * 0.29, w: 2.05, h: 0.27, fontSize: 9.5, color: C.slate, margin: 0 });
    });

    // Remaining — right column
    s.addShape("rect", { x: 5.2, y: 1.75, w: 4.3, h: 3.55, fill: { color: C.amberLight }, line: { color: C.amber, pt: 1 } });
    s.addText("🔧  Remaining to Build", { x: 5.35, y: 1.82, w: 4.0, h: 0.32, fontSize: 11, bold: true, color: C.amber, margin: 0 });
    remaining.forEach((f, i) => {
      s.addImage({ data: iconBolt, x: 5.38, y: 2.25 + i * 0.52, w: 0.22, h: 0.22 });
      s.addText(f, { x: 5.68, y: 2.22 + i * 0.52, w: 3.65, h: 0.42, fontSize: 10, color: C.navyMid, margin: 0 });
    });

    s.addText("One decision separates us from launch: choosing the name — together. That's not a gap. That's a first decision for partners.", {
      x: 0.5, y: 5.32, w: 9, h: 0.25,
      fontSize: 9.5, italic: true, color: C.slate, align: "center", margin: 0,
    });
  }

  // ── SLIDE 9: GROWTH MODEL ──────────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "Growth Model");
    slideTitle(s, "Profitable at 100 merchants. Meaningful at 1,000. Transformative at 5,000.");

    s.addChart(pres.charts.LINE, [
      { name: "Monthly Revenue ($)",    labels: ["100", "250", "500", "1,000", "2,500", "5,000"], values: [14900, 37250, 74500, 149000, 372500, 745000] },
      { name: "Annual Charitable Giving ($)", labels: ["100", "250", "500", "1,000", "2,500", "5,000"], values: [29800, 74500, 149000, 298000, 745000, 1490000] },
    ], {
      x: 0.5, y: 1.75, w: 6.2, h: 3.5,
      chartColors: [C.orange, C.green],
      chartArea: { fill: { color: C.white } },
      catAxisLabelColor: C.slate,
      valAxisLabelColor: C.slate,
      valGridLine: { color: C.border, size: 0.5 },
      catGridLine: { style: "none" },
      lineSize: 3,
      lineSmooth: true,
      showLegend: true,
      legendPos: "b",
      legendFontSize: 10,
      catAxisTitle: "Merchant Count",
      showCatAxisTitle: true,
    });

    // Milestone cards
    const milestones = [
      { merchants: "100",   rev: "$14,900/mo",  give: "$30K/yr",   note: "Profitable from day one" },
      { merchants: "1,000", rev: "$149,000/mo", give: "$298K/yr",  note: "East Coast expansion story" },
      { merchants: "5,000", rev: "$745,000/mo", give: "$1.49M/yr", note: "National brand + global expansion" },
    ];
    milestones.forEach((m, i) => {
      card(s, 7.0, 1.75 + i * 1.2, 2.85, 1.05);
      s.addText(`${m.merchants} merchants`, { x: 7.12, y: 1.83 + i * 1.2, w: 2.6, h: 0.28, fontSize: 10, bold: true, color: C.navy, margin: 0 });
      s.addText(m.rev, { x: 7.12, y: 2.1 + i * 1.2, w: 2.6, h: 0.27, fontSize: 12, bold: true, color: C.orange, margin: 0 });
      s.addText(`${m.give} to charity`, { x: 7.12, y: 2.38 + i * 1.2, w: 2.6, h: 0.22, fontSize: 9.5, color: C.green, margin: 0 });
      s.addText(m.note, { x: 7.12, y: 2.6 + i * 1.2, w: 2.6, h: 0.25, fontSize: 9, italic: true, color: C.slate, margin: 0 });
    });
  }

  // ── SLIDE 10: WHY WE WIN ───────────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "Competitive Moat");
    slideTitle(s, "No competitor does both axes.", "Square/Toast = operations only. Uber Eats/DoorDash = discovery at 30%. We do both.");

    const moats = [
      { icon: iconBolt,   title: "Full stack in one subscription",  body: "Storefront + marketplace + CRM + loyalty + delivery. No other single product covers this." },
      { icon: iconHeart,  title: "Mission drives acquisition",      body: "Word of mouth from the giving model is worth more than Google ads. Mission-aligned merchants recruit each other." },
      { icon: iconLock,   title: "Structurally low churn",          body: "CRM data, loyalty history, brand domain — all live in GrowthHub. Switching cost is the customer relationship itself." },
      { icon: iconChart,  title: "Network effects via /eat",        body: "More merchants → better consumer directory → more customers → more valuable for merchants. A flywheel that competitors can't easily replicate." },
    ];

    moats.forEach((m, i) => {
      const col = i % 2;
      const row = Math.floor(i / 2);
      const x = 0.5 + col * 4.8;
      const y = 1.75 + row * 1.8;
      card(s, x, y, 4.5, 1.65);
      s.addImage({ data: m.icon, x: x + 0.2, y: y + 0.25, w: 0.38, h: 0.38 });
      s.addText(m.title, { x: x + 0.7, y: y + 0.2, w: 3.65, h: 0.35, fontSize: 12, bold: true, color: C.navy, margin: 0 });
      s.addText(m.body,  { x: x + 0.7, y: y + 0.58, w: 3.65, h: 0.9,  fontSize: 10.5, color: C.slate, margin: 0 });
    });
  }

  // ── SLIDE 11: GO TO MARKET — BRISBANE ─────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "Go To Market");
    slideTitle(s, "Start with Brisbane. Build the name. Then the world.", "Dense independent scene. Close enough to manage. Big enough to matter.");

    // Phase timeline
    const phases = [
      { phase: "Phase 1",  title: "Brisbane Launch",       detail: "200 merchants · $4M GMV · local press + case studies", color: C.orange },
      { phase: "Phase 2",  title: "East Coast Expansion",  detail: "Sydney + Melbourne · 1,000+ merchants · Series A", color: C.navy },
      { phase: "Phase 3",  title: "National + /eat Launch",detail: "5,000 merchants · consumer-facing marketplace · $1M/yr to charity", color: C.green },
    ];

    phases.forEach((p, i) => {
      const y = 1.9 + i * 1.18;
      s.addShape("rect", { x: 0.5, y, w: 0.06, h: 1.0, fill: { color: p.color }, line: { color: p.color } });
      s.addShape("oval",  { x: 0.35, y: y + 0.37, w: 0.32, h: 0.32, fill: { color: p.color }, line: { color: p.color } });
      s.addText(p.phase,  { x: 0.75, y: y + 0.05, w: 1.4, h: 0.28, fontSize: 10, bold: true, color: p.color, margin: 0 });
      s.addText(p.title,  { x: 0.75, y: y + 0.33, w: 4.0, h: 0.35, fontSize: 15, bold: true, color: C.navy, margin: 0 });
      s.addText(p.detail, { x: 0.75, y: y + 0.68, w: 8.7, h: 0.28, fontSize: 11, color: C.slate, margin: 0 });
    });

    // Brisbane stat highlights
    card(s, 5.5, 1.9, 4.0, 3.4);
    s.addImage({ data: iconPin, x: 5.65, y: 2.05, w: 0.35, h: 0.35 });
    s.addText("Why Brisbane?", { x: 6.1, y: 2.05, w: 3.2, h: 0.35, fontSize: 13, bold: true, color: C.navy, margin: 0 });

    const whyBne = [
      "Dense independent hospitality + retail scene",
      "Underserved by enterprise software",
      "Direct relationship management at launch",
      "Strong proof points before scaling",
      "Tight-knit small business community",
      "200 merchants = $4M+ GMV proof",
    ];
    whyBne.forEach((w, i) => {
      s.addImage({ data: iconCheckOrg, x: 5.65, y: 2.52 + i * 0.37, w: 0.2, h: 0.2 });
      s.addText(w, { x: 5.95, y: 2.49 + i * 0.37, w: 3.4, h: 0.3, fontSize: 10, color: C.slate, margin: 0 });
    });
  }

  // ── SLIDE 12: WHAT WE NEED ─────────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.offWhite };
    sectionTag(s, "The Partnership");
    slideTitle(s, "We're not looking for someone to execute a plan.", "We're looking for someone who sees what they'd change — and wants to build it.");

    const needs = [
      { icon: iconUsers,  title: "Merchant Acquisition",  body: "Relationships in hospitality or retail, or the ability to build a sales motion from scratch. The product sells itself — we need the first conversations started." },
      { icon: iconBolt,   title: "Operator Mindset",      body: "Turning a working product into a repeatable process. The gap between 10 merchants and 200 is systems, not code." },
      { icon: iconPin,    title: "Market Expansion",      body: "Localisation, legal, compliance, cross-border partnerships. If you've scaled into new markets, you know what breaks first." },
      { icon: iconChart,  title: "Brand & Consumer Side", body: "Build the /eat consumer audience. The merchant story is compelling — the consumer brand needs to be created." },
    ];

    needs.forEach((n, i) => {
      const col = i % 2, row = Math.floor(i / 2);
      const x = 0.5 + col * 4.8;
      const y = 1.8 + row * 1.8;
      card(s, x, y, 4.5, 1.65);
      s.addImage({ data: n.icon, x: x + 0.2, y: y + 0.25, w: 0.38, h: 0.38 });
      s.addText(n.title, { x: x + 0.7, y: y + 0.2, w: 3.65, h: 0.35, fontSize: 12, bold: true, color: C.navy, margin: 0 });
      s.addText(n.body,  { x: x + 0.7, y: y + 0.6, w: 3.65, h: 0.9,  fontSize: 10.5, color: C.slate, margin: 0 });
    });

    s.addText("We're not looking for someone to execute a plan. We're looking for someone who looks at this and sees what they'd change.", {
      x: 0.5, y: 5.3, w: 9, h: 0.25,
      fontSize: 10, italic: true, color: C.slate, align: "center", margin: 0,
    });
  }

  // ── SLIDE 13: CLOSE ────────────────────────────────────────────────────────
  {
    const s = pres.addSlide();
    s.background = { color: C.navy };

    s.addShape("rect", { x: 0, y: 0, w: 0.08, h: 5.625, fill: { color: C.orange }, line: { color: C.orange } });

    s.addText("We have the product.", { x: 0.5, y: 0.6,  w: 9, h: 0.55, fontSize: 24, color: "94A3B8", align: "left", margin: 0 });
    s.addText("We have the model.",   { x: 0.5, y: 1.15, w: 9, h: 0.55, fontSize: 24, color: "94A3B8", align: "left", margin: 0 });
    s.addText("We have the mission.", { x: 0.5, y: 1.7,  w: 9, h: 0.55, fontSize: 24, bold: true, color: C.white, align: "left", margin: 0 });

    s.addShape("rect", { x: 0.5, y: 2.5, w: 9, h: 0.03, fill: { color: "1E293B" }, line: { color: "1E293B" } });

    s.addText("What do you think?\nWhat would you change?\nWhat do you bring to this?", {
      x: 0.5, y: 2.7, w: 7, h: 1.2,
      fontSize: 20, bold: true, color: C.orange, align: "left", margin: 0,
    });

    s.addText("GrowthHub — Built for the people who built the neighbourhood.", {
      x: 0.5, y: 4.4, w: 9, h: 0.35,
      fontSize: 13, italic: true, color: "475569", align: "left", margin: 0,
    });

    s.addImage({ data: iconHeart, x: 8.8, y: 4.3, w: 0.55, h: 0.55 });
  }

  // ── OUTPUT ────────────────────────────────────────────────────────────────
  const outPath = "GrowthHub-CoFounder-Pitch.pptx";
  await pres.writeFile({ fileName: outPath });
  console.log(`✅  Deck written to: ${outPath}`);
}

buildDeck().catch(console.error);
