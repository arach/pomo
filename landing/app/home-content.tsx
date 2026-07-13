import React from "react";
import Image from "next/image";

const DOWNLOAD_URL =
  "https://github.com/arach/pomo/releases/latest/download/Pomo.dmg";
const GITHUB_URL = "https://github.com/arach/pomo";

// Inner var() fallback keeps text sans/mono even if next/font's variable ever fails to inject
// (otherwise an undefined custom property makes the whole declaration invalid → serif).
const sans = "var(--font-space-grotesk, ui-sans-serif), sans-serif";
const mono = "var(--font-jetbrains-mono, ui-monospace), monospace";

// Deterministic focus heatmap — 17 weeks × 7 days (matches the design's generator).
function buildHeatmap(): number[] {
  const cells: number[] = [];
  for (let w = 0; w < 17; w++) {
    for (let d = 0; d < 7; d++) {
      const seed = w * 7 + d;
      const weekday = d < 5;
      const base = weekday ? 0.55 : 0.18;
      const noise = (((Math.sin(seed * 12.9898) * 43758.5453) % 1) + 1) % 1;
      let op = base + noise * 0.5 - 0.18;
      if (w > 13 && weekday) op = Math.max(op, 0.72);
      if (w === 16 && d > 4) op = 0.08;
      op = Math.max(0.08, Math.min(1, op));
      cells.push(Number(op.toFixed(2)));
    }
  }
  return cells;
}

const AppleGlyph = ({ size = 15 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 384 512" fill="currentColor">
    <path d="M318.7 268.7c-.2-36.7 16.4-64.4 50-84.8-18.8-26.9-47.2-41.7-84.7-44.6-35.5-2.8-74.3 20.7-88.5 20.7-15 0-49.4-19.7-76.4-19.7C63.3 141.2 4 184.8 4 273.5q0 39.3 14.4 81.2c12.8 36.7 59 126.7 107.2 125.2 25.2-.6 43-17.9 75.8-17.9 31.8 0 48.3 17.9 76.4 17.9 48.6-.7 90.4-82.5 102.6-119.3-65.2-30.7-61.7-90-61.7-91.9zm-56.6-164.2c27.3-32.4 24.8-61.9 24-72.5-24.1 1.4-52 16.4-67.9 34.9-17.5 19.8-27.8 44.3-25.6 71.9 26.1 2 49.9-11.4 69.5-34.3z" />
  </svg>
);

const Mark = ({ size = 22, dim = false }: { size?: number; dim?: boolean }) => {
  const stroke = dim ? "#6b6055" : "#f2ece3";
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" style={{ display: "block" }}>
      <circle cx="12" cy="12.5" r="8.5" stroke={stroke} strokeWidth="1.4" opacity={dim ? 0.5 : 0.28} />
      <path d="M12 4 A8.5 8.5 0 0 1 20.5 12.5" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" fill="none" />
      <line x1="12" y1="2" x2="12" y2="5" stroke={stroke} strokeWidth="1.6" strokeLinecap="round" />
      <circle cx="12" cy="12.5" r="1.7" fill="var(--accent)" />
    </svg>
  );
};

const SectionLabel = ({ children }: { children: React.ReactNode }) => (
  <div
    style={{
      fontFamily: mono,
      fontSize: 11,
      letterSpacing: "0.2em",
      textTransform: "uppercase",
      color: "#7d7165",
      marginBottom: 14,
    }}
  >
    {children}
  </div>
);

/* ───────────────────────── nav ───────────────────────── */
function Nav() {
  const link = { color: "#9c8f7f", textDecoration: "none" } as const;
  return (
    <header style={{ position: "relative", zIndex: 5, borderBottom: "1px solid rgba(255,255,255,0.06)" }}>
      <div
        className="pomo-nav-inner"
        style={{
          maxWidth: 1180,
          margin: "0 auto",
          padding: "0 40px",
          height: 62,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          gap: 24,
        }}
      >
        <a href="#top" className="pomo-brand" style={{ display: "inline-flex", alignItems: "center", gap: 10, color: "#f2ece3", textDecoration: "none" }}>
          <Mark />
          <b style={{ fontFamily: mono, fontWeight: 600, fontSize: 14, letterSpacing: "0.16em" }}>POMO</b>
        </a>
        <nav className="pomo-nav-links" style={{ display: "flex", gap: 26, fontFamily: mono, fontSize: 12, letterSpacing: "0.04em" }}>
          <a href="#features" className="pomo-link" style={link}><span style={{ color: "#6b6055" }}>:</span>features</a>
          <a href="#iphone" className="pomo-link" style={link}><span style={{ color: "#6b6055" }}>:</span>iphone</a>
          <a href="#rituals" className="pomo-link" style={link}><span style={{ color: "#6b6055" }}>:</span>rituals</a>
          <a href="#cli" className="pomo-link" style={link}><span style={{ color: "#6b6055" }}>:</span>cli</a>
        </nav>
        <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
          <span className="pomo-nav-version" style={{ fontFamily: mono, fontSize: 11, color: "#6b6055", letterSpacing: "0.06em" }}>macOS · iPhone</span>
          <a
            href={DOWNLOAD_URL}
            className="pomo-btn-primary"
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 7,
              padding: "8px 15px",
              background: "var(--accent)",
              color: "#1a0f0c",
              fontFamily: mono,
              fontSize: 11,
              fontWeight: 600,
              letterSpacing: "0.08em",
              textTransform: "uppercase",
              borderRadius: 6,
              textDecoration: "none",
            }}
          >
            Download
          </a>
        </div>
      </div>
    </header>
  );
}

/* ───────────────────────── hero timer — the Pomo chronograph watchface ───────────────────────── */
function TimerWindow() {
  const cx = 120;
  const cy = 120;
  const ticks = Array.from({ length: 60 }, (_, i) => i);
  const renderTick = (i: number) => {
    const a = (i * 6 * Math.PI) / 180;
    const major = i % 5 === 0;
    const isTop = i === 0;
    const rOut = 112;
    const rIn = major ? 98 : 104;
    const sin = Math.sin(a);
    const cos = Math.cos(a);
    return (
      <line
        key={i}
        x1={(cx + rOut * sin).toFixed(2)}
        y1={(cy - rOut * cos).toFixed(2)}
        x2={(cx + rIn * sin).toFixed(2)}
        y2={(cy - rIn * cos).toFixed(2)}
        stroke={isTop ? "var(--accent)" : major ? "rgba(255,255,255,0.42)" : "rgba(255,255,255,0.15)"}
        strokeWidth={isTop ? 2.6 : major ? 2 : 1}
        strokeLinecap="round"
      />
    );
  };
  const ctrlBtn = (children: React.ReactNode, primary = false) => (
    <span
      aria-hidden="true"
      className={primary ? "pomo-ctrl-primary" : "pomo-ctrl"}
      style={{
        width: 40,
        height: 40,
        borderRadius: "50%",
        background: primary ? "var(--accent)" : "transparent",
        border: primary ? "none" : "1px solid rgba(255,255,255,0.14)",
        color: primary ? "#1a0f0c" : "#bcae9e",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        flex: "none",
        boxShadow: primary ? "0 8px 20px -10px var(--accent-glow)" : "none",
      }}
    >
      {children}
    </span>
  );

  return (
    <div style={{ position: "relative", width: 360, maxWidth: "100%" }}>
      <div
        style={{
          position: "absolute",
          inset: "-50px -36px -30px",
          background: "radial-gradient(58% 52% at 50% 42%, var(--accent-glow) 0%, transparent 70%)",
          filter: "blur(18px)",
          opacity: "var(--glow)" as unknown as number,
          zIndex: 0,
        }}
      />
      <div
        style={{
          position: "relative",
          zIndex: 1,
          borderRadius: 18,
          background: "linear-gradient(180deg,#201913 0%, #14100c 100%)",
          border: "1px solid rgba(255,255,255,0.1)",
          boxShadow: "0 34px 64px -22px rgba(0,0,0,0.7), inset 0 1px 0 rgba(255,255,255,0.06)",
          overflow: "hidden",
          padding: "26px 26px 22px",
          animation: "ringGlow 5s ease-in-out infinite",
        }}
      >
        {/* watchface */}
        <svg viewBox="0 0 240 240" style={{ width: "100%", height: "auto", display: "block" }}>
          <circle cx={cx} cy={cy} r="116" fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="1" />
          {ticks.map(renderTick)}
          {/* progress hand (full at 25:00 → points to 12) */}
          <line x1={cx} y1={cy} x2={cx} y2={cy - 84} stroke="var(--accent)" strokeWidth="2.6" strokeLinecap="round" />
          <circle cx={cx} cy={cy - 84} r="3.4" fill="var(--accent)" />
          <text x={cx} y="97" textAnchor="middle" fontFamily={mono} fontSize="11" letterSpacing="4" fill="#8a8076">FOCUS</text>
          <circle cx={cx} cy={cy} r="5" fill="var(--accent)" />
          <text x={cx} y="153" textAnchor="middle" fontFamily={mono} fontWeight="500" fontSize="30" fill="#f4eee6">25:00</text>
        </svg>

        {/* controls */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 12, marginTop: 22 }}>
          {ctrlBtn(
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7" /><polyline points="3 3 3 6 6 6" /></svg>
          )}
          {ctrlBtn(
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z" /></svg>,
            true
          )}
          {ctrlBtn(
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M5 5l9 7-9 7z" /><rect x="16" y="5" width="2.5" height="14" rx="0.6" /></svg>
          )}
          {ctrlBtn(
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M9 17V5l10-2v12" /><circle cx="6.5" cy="17.5" r="2.6" fill="currentColor" stroke="none" /><circle cx="16" cy="15.5" r="2.6" fill="currentColor" stroke="none" /></svg>
          )}
          {ctrlBtn(
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><rect x="3" y="6" width="18" height="12" rx="2" /><path d="M11 10l4 2-4 2z" fill="currentColor" stroke="none" /></svg>
          )}
        </div>
      </div>
    </div>
  );
}

/* ───────────────────────── hero ───────────────────────── */
function Hero() {
  const primaryBtn = {
    display: "inline-flex",
    alignItems: "center",
    gap: 9,
    padding: "13px 22px",
    background: "var(--accent)",
    color: "#1a0f0c",
    fontFamily: sans,
    fontSize: 15,
    fontWeight: 500,
    borderRadius: 9,
    textDecoration: "none",
    boxShadow: "0 8px 22px -8px var(--accent-glow)",
  } as const;

  return (
    <section id="top" style={{ position: "relative", zIndex: 3 }}>
      <div
        className="pomo-hero-grid"
        style={{
          maxWidth: 1180,
          margin: "0 auto",
          padding: "84px 40px 64px",
          display: "grid",
          gridTemplateColumns: "minmax(0,1fr) auto",
          gap: 72,
          alignItems: "center",
        }}
      >
        {/* left */}
        <div>
          <div style={{ display: "inline-flex", alignItems: "center", gap: 11, fontFamily: mono, fontSize: 11, letterSpacing: "0.2em", textTransform: "uppercase", color: "#7d7165" }}>
            <span style={{ width: 18, height: 1, background: "var(--accent)", display: "inline-block" }} />
            Focus timer · macOS + iPhone
          </div>
          <h1 style={{ fontFamily: sans, fontWeight: 400, fontSize: 38, lineHeight: 1.0, letterSpacing: "-0.02em", margin: "22px 0 0", color: "#f4eee6", textWrap: "balance" } as React.CSSProperties}>
            Twenty-five minutes,
            <br />
            <em style={{ fontStyle: "normal", color: "var(--accent)", fontWeight: 500 }}>focus mode</em>
          </h1>
          <p style={{ fontFamily: sans, fontWeight: 300, fontSize: 16.5, lineHeight: 1.65, color: "#bcae9e", maxWidth: "44ch", margin: "26px 0 0" }}>
            Pomo is a focus timer for Mac and iPhone. Add a note for the task, start the timer, and get back to work.
          </p>
          <div style={{ display: "flex", alignItems: "center", gap: 12, marginTop: 34, flexWrap: "wrap" }}>
            <a href={DOWNLOAD_URL} className="pomo-btn-primary" style={primaryBtn}>
              <AppleGlyph />
              Download for Mac
            </a>
            <a
              href="#iphone"
              className="pomo-btn-ghost"
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 8,
                padding: "13px 20px",
                background: "transparent",
                color: "#e7dccb",
                fontFamily: sans,
                fontSize: 15,
                fontWeight: 500,
                border: "1px solid rgba(255,255,255,0.14)",
                borderRadius: 9,
                textDecoration: "none",
              }}
            >
              See the iPhone app
            </a>
          </div>
          <div style={{ fontFamily: mono, fontSize: 11, letterSpacing: "0.05em", color: "#6b6055", marginTop: 20 }}>
            Free on Mac · iPhone 1.0 in preparation
          </div>
        </div>

        {/* right */}
        <TimerWindow />
      </div>

      {/* meta strip */}
      <MetaStrip />
    </section>
  );
}

function MetaStrip() {
  const items: [string, string][] = [
    ["Focus block", "25 min"],
    ["Short break", "5 min"],
    ["Global hotkey", "⌘⇧P"],
    ["Lives in", "Menu bar"],
  ];
  return (
    <div style={{ maxWidth: 1180, margin: "0 auto", padding: "0 40px" }}>
      <dl
        className="pomo-meta-grid"
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(4,1fr)",
          borderTop: "1px solid rgba(255,255,255,0.08)",
          borderBottom: "1px solid rgba(255,255,255,0.08)",
          margin: "8px 0 0",
          fontFamily: mono,
        }}
      >
        {items.map(([term, val], i) => (
          <div
            key={term}
            className="pomo-meta"
            style={{
              padding: "18px 0 18px 20px",
              borderRight: i < 3 ? "1px solid rgba(255,255,255,0.08)" : "none",
            }}
          >
            <dt style={{ fontSize: 10, letterSpacing: "0.14em", textTransform: "uppercase", color: "#6b6055", marginBottom: 6 }}>{term}</dt>
            <dd style={{ margin: 0, fontSize: 13, color: "#e7dccb", letterSpacing: "0.04em" }}>{val}</dd>
          </div>
        ))}
      </dl>
    </div>
  );
}

/* ───────────────────────── features ───────────────────────── */
function Features() {
  const card = {
    background: "#211a15",
    border: "1px solid rgba(255,255,255,0.07)",
    borderRadius: 13,
    padding: 24,
    display: "flex",
    flexDirection: "column",
  } as React.CSSProperties;
  const eyebrow = { fontFamily: mono, fontSize: 10, letterSpacing: "0.14em", textTransform: "uppercase", color: "var(--accent)", margin: "18px 0 9px" } as React.CSSProperties;
  const title = { fontFamily: sans, fontSize: 18, fontWeight: 400, color: "#f2ece3", margin: "0 0 8px" } as React.CSSProperties;
  const body = { fontFamily: sans, fontWeight: 300, fontSize: 14.5, lineHeight: 1.6, color: "#a89b8b", margin: 0 } as React.CSSProperties;

  return (
    <section id="features" style={{ position: "relative", zIndex: 3 }}>
      <div style={{ maxWidth: 1180, margin: "0 auto", padding: "80px 40px 20px" }}>
        <SectionLabel>§ What it does</SectionLabel>
        <h2 style={{ fontFamily: sans, fontWeight: 300, fontSize: "clamp(34px,3.6vw,48px)", lineHeight: 1.05, letterSpacing: "-0.02em", color: "#f4eee6", margin: "0 0 44px" }}>
          Small surface. The whole technique.
        </h2>
        <div className="pomo-feature-grid" style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 18 }}>
          {/* menu bar */}
          <div className="pomo-card" style={card}>
            <div style={{ height: 104, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <div style={{ width: "100%", background: "#0f0c0a", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 8, height: 32, display: "flex", alignItems: "center", padding: "0 11px", gap: 13, fontFamily: mono, fontSize: 11, color: "#5e554b" }}>
                <span>File</span><span>Edit</span><span>View</span>
                <div style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 13 }}>
                  <span style={{ opacity: 0.7 }}>􀙇</span><span style={{ opacity: 0.7 }}>􀊫</span>
                  <span style={{ display: "inline-flex", alignItems: "center", gap: 6, color: "#f2ece3" }}>
                    <span style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--accent)" }} />18:42
                  </span>
                </div>
              </div>
            </div>
            <div style={eyebrow}>01 · Menu bar</div>
            <h3 style={title}>Visible in the menu bar</h3>
            <p style={body}>The time remaining sits in your menu bar. Click to start, pause, or skip — never a window in the way.</p>
          </div>

          {/* cycles */}
          <div className="pomo-card" style={card}>
            <div style={{ height: 104, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
              <div style={{ display: "flex", gap: 13, alignItems: "center" }}>
                <span style={{ width: 15, height: 15, borderRadius: "50%", background: "var(--accent)" }} />
                <span style={{ width: 15, height: 15, borderRadius: "50%", background: "var(--accent)" }} />
                <span style={{ width: 15, height: 15, borderRadius: "50%", background: "var(--accent)" }} />
                <span style={{ width: 15, height: 15, borderRadius: "50%", border: "1.5px solid #6b6055" }} />
                <span style={{ width: 5, height: 5, borderRadius: "50%", background: "#4a423a" }} />
                <span style={{ width: 22, height: 15, borderRadius: 7, background: "var(--accent-soft)", border: "1px solid var(--accent)" }} />
              </div>
              <div style={{ fontFamily: mono, fontSize: 10.5, letterSpacing: "0.1em", color: "#7d7165" }}>25 · 5 · 25 · 5 · 25 · 5 · 25 · 15</div>
            </div>
            <div style={eyebrow}>02 · Cycles</div>
            <h3 style={title}>Four sessions, then a real break</h3>
            <p style={body}>Pomo runs the classic rhythm and counts the cycle — short breaks between, a long one to finish — so you don&apos;t have to.</p>
          </div>

          {/* task */}
          <div className="pomo-card" style={card}>
            <div style={{ height: 104, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <div style={{ width: "100%", background: "#17110d", border: "1px solid rgba(255,255,255,0.1)", borderRadius: 9, padding: "13px 14px", display: "flex", alignItems: "center", gap: 10 }}>
                <span style={{ width: 7, height: 7, borderRadius: "50%", background: "var(--accent)", flex: "none" }} />
                <span style={{ fontFamily: sans, fontSize: 18, color: "#e7dccb", flex: 1 }}>Writing the launch post</span>
                <span style={{ width: 2, height: 20, background: "var(--accent)", animation: "pomoPulse 1.1s ease-in-out infinite", flex: "none" }} />
              </div>
            </div>
            <div style={eyebrow}>03 · Intent</div>
            <h3 style={title}>Name what you&apos;re doing</h3>
            <p style={body}>Add a task before the session starts. It stays visible while the timer is running.</p>
          </div>
        </div>
      </div>
    </section>
  );
}

type SegmentKind = "build" | "write" | "study" | "design";

function SegmentGlyph({ kind }: { kind: SegmentKind }) {
  const shared = {
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.6,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };

  return (
    <svg viewBox="0 0 64 64" aria-hidden="true" focusable="false">
      <path d="M8 17h48v34H8z" {...shared} opacity=".45" />
      <path d="M8 25h48M15 21h.1M20 21h.1" {...shared} opacity=".65" />
      {kind === "build" && (
        <>
          <path d="m25 33-6 5 6 5M39 33l6 5-6 5M35 31l-6 14" {...shared} />
          <circle cx="49" cy="17" r="3" fill="var(--accent)" stroke="none" />
        </>
      )}
      {kind === "write" && (
        <>
          <path d="M20 31h23M20 37h18M20 43h13" {...shared} />
          <path d="M45 30v15" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" />
          <path d="m40 13 4 4-7 7-5 1 1-5z" {...shared} />
        </>
      )}
      {kind === "study" && (
        <>
          <path d="M16 33c6-2 11-1 16 3 5-4 10-5 16-3v14c-6-2-11-1-16 3-5-4-10-5-16-3zM32 36v14" {...shared} />
          <path d="M21 29h7M36 29h7" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" />
          <circle cx="49" cy="17" r="3" fill="#70b7ff" stroke="none" />
        </>
      )}
      {kind === "design" && (
        <>
          <circle cx="22" cy="39" r="4" {...shared} />
          <circle cx="43" cy="34" r="4" {...shared} />
          <circle cx="39" cy="46" r="4" {...shared} />
          <path d="m25 37 14-2M41 38l-1 4M25 42l10 3" {...shared} />
          <path d="M18 29h29" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" />
          <path d="M22 27v4M28 27v4M34 27v4M40 27v4" {...shared} opacity=".7" />
        </>
      )}
    </svg>
  );
}

function Screenshots() {
  const shots = [
    {
      src: "/marketing/iphone-focus.png",
      index: "01",
      label: "Intent",
      title: "Focus on the task.",
      caption: "Add a note and start the timer.",
    },
    {
      src: "/marketing/iphone-photo-v2.png",
      index: "02",
      label: "Personal",
      title: "Use your own photo.",
      caption: "Choose it in Settings. Change it anytime.",
    },
    {
      src: "/marketing/iphone-activity.png",
      index: "03",
      label: "Momentum",
      title: "Review your activity.",
      caption: "See sessions, focus time, and streaks.",
    },
    {
      src: "/marketing/iphone-settings.png",
      index: "04",
      label: "Rhythm",
      title: "Adjust the timer.",
      caption: "Set focus, break, and planning lengths.",
    },
  ];

  const segments: { kind: SegmentKind; label: string; title: string; intent: string; body: string; metric: string }[] = [
    {
      kind: "build",
      label: "Build",
      title: "Work through a build.",
      intent: "Resolve the sync edge case",
      body: "Keep debugging, design, and compile work inside a timed session.",
      metric: "25:00 / build",
    },
    {
      kind: "write",
      label: "Write",
      title: "Draft without editing.",
      intent: "Finish the opening scene",
      body: "Give the blank page a beginning and an end before polishing either.",
      metric: "1 scene / block",
    },
    {
      kind: "study",
      label: "Study",
      title: "Study a chapter.",
      intent: "Review cellular respiration",
      body: "Alternate deliberate study with real breaks that protect recall.",
      metric: "4 blocks / set",
    },
    {
      kind: "design",
      label: "Design",
      title: "Choose a direction.",
      intent: "Choose the onboarding direction",
      body: "Separate open-ended exploration from the focused pass that ships.",
      metric: "1 direction / block",
    },
  ];

  return (
    <>
      <section id="iphone" className="pomo-iphone-section">
        <div className="pomo-section-shell">
          <div className="pomo-showcase-heading">
            <div>
              <SectionLabel>§ Pomo for iPhone · current screens</SectionLabel>
              <h2>Pomo for iPhone.</h2>
            </div>
            <p>
              The iPhone app includes task notes, eight timer faces—including one for your own photos—adjustable sessions, and activity history stored on the device.
            </p>
          </div>

          <div className="pomo-phone-deck" aria-label="Pomo for iPhone screenshot campaign" tabIndex={0}>
            <div className="pomo-deck-grid" aria-hidden="true" />
            {shots.map((shot) => (
              <figure key={shot.index} className="pomo-phone-frame">
                <div className="pomo-phone-meta">
                  <span>{shot.index}</span>
                  <span>{shot.label}</span>
                </div>
                <Image
                  src={shot.src}
                  width={1320}
                  height={2868}
                  sizes="(max-width: 720px) 70vw, (max-width: 1100px) 34vw, 244px"
                  alt={`Pomo for iPhone — ${shot.title}`}
                  className="pomo-phone-image"
                  priority={shot.index === "01"}
                />
                <figcaption>
                  <strong>{shot.title}</strong>
                  <span>{shot.caption}</span>
                </figcaption>
              </figure>
            ))}
          </div>

          <div className="pomo-campaign-footer">
            <span>Real product UI · iPhone 16 Pro Max · no device mockup</span>
            <span>Charcoal / warm white / signal yellow</span>
          </div>
        </div>
      </section>

      <section id="rituals" className="pomo-segments-section">
        <div className="pomo-section-shell">
          <div className="pomo-segment-heading">
            <div>
              <SectionLabel>§ Examples</SectionLabel>
              <h2>For focused work.</h2>
            </div>
            <p>A few ways to use a timed session during the day.</p>
          </div>

          <div className="pomo-segment-grid">
            {segments.map((segment, index) => (
              <article className="pomo-segment-card" key={segment.kind}>
                <div className="pomo-segment-topline">
                  <span>0{index + 1}</span>
                  <span>{segment.metric}</span>
                </div>
                <div className={`pomo-segment-icon is-${segment.kind}`}>
                  <SegmentGlyph kind={segment.kind} />
                </div>
                <div className="pomo-segment-label">{segment.label}</div>
                <h3>{segment.title}</h3>
                <div className="pomo-segment-intent"><i />{segment.intent}</div>
                <p>{segment.body}</p>
              </article>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}

/* ───────────────────────── CLI / terminal ───────────────────────── */
function CliSection() {
  const cliHighlights = [
    "Live ANSI terminal UI with 13 layout templates",
    "12 color themes — layout and palette are independent",
    "`pomo status --json` for scripts and agents",
    "`npx @arach/pomo install` to fetch the latest Mac app",
  ];
  const eyebrow = { fontFamily: mono, fontSize: 10, letterSpacing: "0.14em", textTransform: "uppercase", color: "var(--accent)", marginBottom: 12 } as React.CSSProperties;
  const featTitle = { fontFamily: sans, fontWeight: 300, fontSize: "clamp(24px,2.4vw,32px)", lineHeight: 1.1, letterSpacing: "-0.01em", color: "#f4eee6", margin: "0 0 14px" } as React.CSSProperties;
  const featBody = { fontFamily: sans, fontWeight: 300, fontSize: 15, lineHeight: 1.6, color: "#a89b8b", margin: "0 0 18px", maxWidth: "42ch" } as React.CSSProperties;
  const featCard = { background: "#211a15", border: "1px solid rgba(255,255,255,0.07)", borderRadius: 16, padding: "30px 34px" } as React.CSSProperties;

  return (
    <section id="cli" style={{ position: "relative", zIndex: 3 }}>
      <div style={{ maxWidth: 1180, margin: "0 auto", padding: "20px 40px 60px" }}>
        <div className="pomo-panel pomo-two-column-panel" style={{ ...featCard, display: "grid", gridTemplateColumns: "minmax(0,1.05fr) minmax(0,0.95fr)", gap: 40, alignItems: "center" }}>
          <div>
            <div style={eyebrow}>Shell · npm · agents</div>
            <h3 style={featTitle}>Same timer, from the terminal.</h3>
            <p style={featBody}>
              <code style={{ fontFamily: mono, fontSize: 13, color: "#e7dccb" }}>@arach/pomo</code> drives the installed Mac app over <code style={{ fontFamily: mono, fontSize: 13, color: "#e7dccb" }}>pomo://</code> URLs, reads live JSON state, and opens a full-screen ANSI panel when you want a keyboard-first view.
            </p>
            <div
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 10,
                padding: "12px 14px",
                borderRadius: 9,
                background: "#17110d",
                border: "1px solid rgba(255,255,255,0.1)",
                fontFamily: mono,
                fontSize: 12,
                color: "#e7dccb",
                marginBottom: 20,
              }}
            >
              <span style={{ color: "#6b6055" }}>$</span>
              npx @arach/pomo
            </div>
            <ul style={{ listStyle: "none", margin: 0, padding: 0, display: "flex", flexDirection: "column", gap: 10 }}>
              {cliHighlights.map((item) => (
                <li key={item} style={{ display: "flex", gap: 10, alignItems: "flex-start" }}>
                  <span style={{ fontFamily: mono, color: "var(--accent)", fontSize: 13, lineHeight: 1.5 }}>→</span>
                  <span style={{ fontFamily: sans, fontWeight: 300, fontSize: 14, lineHeight: 1.5, color: "#bcae9e" }}>{item}</span>
                </li>
              ))}
            </ul>
            <div style={{ marginTop: 22, display: "flex", gap: 12, flexWrap: "wrap" }}>
              <a
                href="https://www.npmjs.com/package/@arach/pomo"
                className="pomo-link"
                style={{ fontFamily: mono, fontSize: 11, letterSpacing: "0.08em", textTransform: "uppercase", color: "var(--accent)", textDecoration: "none" }}
              >
                npm package
              </a>
              <a
                href={GITHUB_URL}
                className="pomo-link"
                style={{ fontFamily: mono, fontSize: 11, letterSpacing: "0.08em", textTransform: "uppercase", color: "#9c8f7f", textDecoration: "none" }}
              >
                view source
              </a>
            </div>
          </div>
          <div style={{ display: "flex", justifyContent: "center" }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/pomo-tui.png"
              alt="Pomo terminal UI — Sheet template"
              className="pomo-photo"
              style={{ width: "100%", maxWidth: 520, objectFit: "contain", borderRadius: 12, border: "1px solid rgba(255,255,255,0.08)", boxShadow: "0 24px 48px -28px rgba(0,0,0,0.75)" }}
            />
          </div>
        </div>
      </div>
    </section>
  );
}

/* ───────────────────────── rhythm + pro tips ───────────────────────── */
function Rhythm() {
  const tips = [
    "During breaks, step away from the screen completely.",
    "Use the long break for movement, water, or a snack.",
    "Finish early? Review your work until the timer ends.",
  ];
  return (
    <section id="rhythm" style={{ position: "relative", zIndex: 3 }}>
      <div style={{ maxWidth: 1180, margin: "0 auto", padding: "60px 40px" }}>
        <div style={{ border: "1px solid rgba(255,255,255,0.08)", borderRadius: 14, background: "#1d1611", padding: "30px 32px" }}>
          <div style={{ fontFamily: mono, fontSize: 11, letterSpacing: "0.2em", textTransform: "uppercase", color: "#7d7165", marginBottom: 22 }}>
            § The rhythm · one full cycle
          </div>
          <div style={{ display: "flex", alignItems: "stretch", gap: 10, flexWrap: "wrap" }}>
            <div className="pomo-beat" style={{ flex: 1, minWidth: 96, background: "var(--accent-soft)", border: "1px solid var(--accent)", borderRadius: 9, padding: "16px 14px" }}>
              <div style={{ fontFamily: mono, fontSize: 22, color: "#f4eee6", letterSpacing: "0.01em" }}>25:00</div>
              <div style={{ fontFamily: mono, fontSize: 10, letterSpacing: "0.16em", textTransform: "uppercase", color: "var(--accent)", marginTop: 6 }}>Focus</div>
            </div>
            <div style={{ display: "flex", alignItems: "center", color: "#5e554b", fontFamily: mono }}>→</div>
            <div className="pomo-beat" style={{ flex: 0.7, minWidth: 80, background: "#17110d", border: "1px solid rgba(255,255,255,0.1)", borderRadius: 9, padding: "16px 14px" }}>
              <div style={{ fontFamily: mono, fontSize: 22, color: "#cabba8", letterSpacing: "0.01em" }}>05:00</div>
              <div style={{ fontFamily: mono, fontSize: 10, letterSpacing: "0.16em", textTransform: "uppercase", color: "#7d7165", marginTop: 6 }}>Break</div>
            </div>
            <div style={{ display: "flex", alignItems: "center", color: "#5e554b", fontFamily: mono, fontSize: 11, letterSpacing: "0.1em" }}>×4 →</div>
            <div className="pomo-beat" style={{ flex: 1.1, minWidth: 110, background: "#17110d", border: "1px dashed var(--accent)", borderRadius: 9, padding: "16px 14px" }}>
              <div style={{ fontFamily: mono, fontSize: 22, color: "#f4eee6", letterSpacing: "0.01em" }}>15:00</div>
              <div style={{ fontFamily: mono, fontSize: 10, letterSpacing: "0.16em", textTransform: "uppercase", color: "var(--accent)", marginTop: 6 }}>Long break</div>
            </div>
          </div>

          {/* pro tips — brought from the previous landing page */}
          <div className="pomo-tip-grid" style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 14, marginTop: 22, borderTop: "1px solid rgba(255,255,255,0.08)", paddingTop: 22 }}>
            {tips.map((tip, i) => (
              <div key={i} style={{ display: "flex", gap: 10, alignItems: "flex-start" }}>
                <span style={{ fontFamily: mono, color: "var(--accent)", fontSize: 13, lineHeight: 1.5 }}>→</span>
                <span style={{ fontFamily: sans, fontWeight: 300, fontSize: 13.5, lineHeight: 1.55, color: "#a89b8b" }}>{tip}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

/* ───────────────────────── origin / Francesco Cirillo (brought from previous site) ───────────────────────── */
function Origin() {
  return (
    <section id="origin" style={{ position: "relative", zIndex: 3 }}>
      <div
        className="pomo-origin-grid"
        style={{
          maxWidth: 1180,
          margin: "0 auto",
          padding: "40px 40px 60px",
          display: "grid",
          gridTemplateColumns: "minmax(0,1fr) minmax(0,1.1fr)",
          gap: 48,
          alignItems: "center",
        }}
      >
        <div>
          <SectionLabel>§ Where it comes from</SectionLabel>
          <h2 style={{ fontFamily: sans, fontWeight: 300, fontSize: "clamp(30px,3.2vw,44px)", lineHeight: 1.05, letterSpacing: "-0.02em", color: "#f4eee6", margin: "0 0 18px" }}>
            One technique,
            <br />
            <em style={{ fontStyle: "normal", fontWeight: 500, color: "var(--accent)" }}>since the &apos;80s.</em>
          </h2>
          <blockquote style={{ margin: "0 0 24px", fontFamily: sans, fontWeight: 300, fontStyle: "italic", fontSize: 16, lineHeight: 1.62, color: "#bcae9e", maxWidth: "42ch" }}>
            “The Pomodoro Technique is a time management method that can be used for any task. The aim is to use time as a valuable ally to accomplish what we want to do the way we want to do it.”
          </blockquote>
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: "50%", background: "var(--accent-soft)", border: "1px solid var(--accent)", display: "flex", alignItems: "center", justifyContent: "center", fontFamily: mono, fontSize: 12, fontWeight: 600, color: "var(--accent)" }}>FC</div>
            <div>
              <div style={{ fontFamily: sans, fontSize: 14, color: "#f2ece3" }}>Francesco Cirillo</div>
              <div style={{ fontFamily: mono, fontSize: 11, color: "#7d7165", letterSpacing: "0.04em" }}>Creator of the Pomodoro Technique</div>
            </div>
          </div>
        </div>

        <div style={{ position: "relative", borderRadius: 14, overflow: "hidden", border: "1px solid rgba(255,255,255,0.08)", background: "#17110d", aspectRatio: "16 / 9" }}>
          <iframe
            style={{ position: "absolute", inset: 0, width: "100%", height: "100%", border: 0 }}
            src="https://www.youtube.com/embed/dnt2lTdcn8g"
            title="Francesco Cirillo — Introduction to the Pomodoro Technique"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
          />
        </div>
      </div>
    </section>
  );
}

/* ───────────────────────── stats / heatmap ───────────────────────── */
function Stats() {
  const cells = buildHeatmap();
  const legend = [0.14, 0.4, 0.7, 1];
  const rows: [string, string, boolean][] = [
    ["Sessions this week", "23", false],
    ["Time focused", "9h 35m", false],
    ["Current streak", "5 days", true],
  ];
  return (
    <section
      id="stats"
      style={{
        position: "relative",
        zIndex: 3,
        background: "#1c1510",
        borderTop: "1px solid rgba(255,255,255,0.06)",
        borderBottom: "1px solid rgba(255,255,255,0.06)",
      }}
    >
      <div
        className="pomo-stats-grid"
        style={{
          maxWidth: 1180,
          margin: "0 auto",
          padding: "78px 40px",
          display: "grid",
          gridTemplateColumns: "minmax(0,0.85fr) minmax(0,1.15fr)",
          gap: 64,
          alignItems: "center",
        }}
      >
        <div>
          <SectionLabel>§ The tally</SectionLabel>
          <h2 style={{ fontFamily: sans, fontWeight: 300, fontSize: "clamp(34px,3.6vw,50px)", lineHeight: 1.04, letterSpacing: "-0.02em", color: "#f4eee6", margin: "0 0 18px" }}>
            It keeps score,
            <br />
            <em style={{ fontStyle: "normal", fontWeight: 500, color: "var(--accent)" }}>quietly.</em>
          </h2>
          <p style={{ fontFamily: sans, fontWeight: 300, fontSize: 15.5, lineHeight: 1.62, color: "#a89b8b", maxWidth: "38ch", margin: "0 0 30px" }}>
            Every finished session is logged. No dashboards to check, no guilt — just a quiet record of the days you showed up.
          </p>
          <div style={{ borderTop: "1px solid rgba(255,255,255,0.08)" }}>
            {rows.map(([label, val, accent], i) => (
              <div
                key={label}
                className="pomo-row"
                style={{
                  display: "flex",
                  alignItems: "baseline",
                  justifyContent: "space-between",
                  padding: "15px 0",
                  borderBottom: i < rows.length - 1 ? "1px solid rgba(255,255,255,0.08)" : "none",
                }}
              >
                <span style={{ fontFamily: mono, fontSize: 11, letterSpacing: "0.12em", textTransform: "uppercase", color: "#7d7165" }}>{label}</span>
                <span style={{ fontFamily: sans, fontWeight: 300, fontSize: 38, lineHeight: 1, color: accent ? "var(--accent)" : "#f4eee6" }}>{val}</span>
              </div>
            ))}
          </div>
        </div>

        {/* heatmap */}
        <div style={{ background: "#17110d", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 14, padding: "26px 28px" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16, fontFamily: mono, fontSize: 10.5, letterSpacing: "0.12em", textTransform: "uppercase", color: "#7d7165" }}>
            <span>Last 17 weeks</span>
            <span style={{ display: "inline-flex", alignItems: "center", gap: 7 }}>
              less
              {legend.map((op) => (
                <span key={op} style={{ width: 10, height: 10, borderRadius: 2, background: "var(--accent)", opacity: op }} />
              ))}
              more
            </span>
          </div>
          <div style={{ display: "grid", gridTemplateRows: "repeat(7,1fr)", gridAutoFlow: "column", gap: 4 }}>
            {cells.map((op, i) => (
              <div key={i} className="pomo-cell" style={{ aspectRatio: "1", borderRadius: 2, background: "var(--accent)", opacity: op }} />
            ))}
          </div>
          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 12, fontFamily: mono, fontSize: 10, letterSpacing: "0.1em", textTransform: "uppercase", color: "#5e554b" }}>
            <span>Feb</span><span>Mar</span><span>Apr</span><span>May</span>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ───────────────────────── download / cta ───────────────────────── */
function DownloadCTA() {
  return (
    <section id="download" style={{ position: "relative", zIndex: 3 }}>
      <div style={{ maxWidth: 1180, margin: "0 auto", padding: "96px 40px", textAlign: "center", position: "relative" }}>
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: "radial-gradient(46% 60% at 50% 38%, var(--accent-glow) 0%, transparent 70%)",
            opacity: "calc(var(--glow) * 0.6)" as unknown as number,
            filter: "blur(20px)",
            pointerEvents: "none",
          }}
        />
        <div style={{ position: "relative" }}>
          <Mark size={44} />
          <h2 style={{ fontFamily: sans, fontWeight: 300, fontSize: "clamp(40px,5vw,68px)", lineHeight: 1.02, letterSpacing: "-0.02em", color: "#f4eee6", margin: "8px 0 0" }}>
            Start your first session.
          </h2>
          <p style={{ fontFamily: sans, fontWeight: 300, fontSize: 16, lineHeight: 1.6, color: "#bcae9e", maxWidth: "40ch", margin: "20px auto 0" }}>
            Download Pomo, pick a task, and give the next twenty-five minutes somewhere to go.
          </p>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 12, marginTop: 34, flexWrap: "wrap" }}>
            <a
              href={DOWNLOAD_URL}
              className="pomo-btn-primary"
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 9,
                padding: "14px 24px",
                background: "var(--accent)",
                color: "#1a0f0c",
                fontFamily: sans,
                fontSize: 15,
                fontWeight: 500,
                borderRadius: 10,
                textDecoration: "none",
                boxShadow: "0 10px 26px -10px var(--accent-glow)",
              }}
            >
              <AppleGlyph />
              Download for Mac
            </a>
            <a
              href={GITHUB_URL}
              className="pomo-btn-ghost"
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 8,
                padding: "14px 22px",
                background: "transparent",
                color: "#e7dccb",
                fontFamily: sans,
                fontSize: 15,
                fontWeight: 500,
                border: "1px solid rgba(255,255,255,0.14)",
                borderRadius: 10,
                textDecoration: "none",
              }}
            >
              View source
            </a>
            <span style={{ fontFamily: mono, fontSize: 11, letterSpacing: "0.06em", color: "#6b6055" }}>v0.2.8 · macOS 13+</span>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ───────────────────────── footer ───────────────────────── */
function Footer() {
  const link = { color: "#9c8f7f", textDecoration: "none" } as const;
  return (
    <footer style={{ position: "relative", zIndex: 3, borderTop: "1px solid rgba(255,255,255,0.07)", background: "#120e0c" }}>
      <div
        style={{
          maxWidth: 1180,
          margin: "0 auto",
          padding: "26px 40px",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          gap: 24,
          flexWrap: "wrap",
          fontFamily: mono,
          fontSize: 11,
          letterSpacing: "0.05em",
          color: "#6b6055",
        }}
      >
        <div style={{ display: "inline-flex", alignItems: "center", gap: 9 }}>
          <Mark size={16} dim />
          pomo.arach.dev
        </div>
        <div style={{ display: "flex", gap: 22 }}>
          <a href="#features" className="pomo-link" style={link}>features</a>
          <a href="#cli" className="pomo-link" style={link}>cli</a>
          <a href="#stats" className="pomo-link" style={link}>stats</a>
          <a href={GITHUB_URL} className="pomo-link" style={link}>github</a>
        </div>
        <div>open source · MIT · part of the arach workshop</div>
      </div>
    </footer>
  );
}

/* ───────────────────────── page ───────────────────────── */
export default function HomeContent() {
  const rootStyle = {
    "--accent": "#eae434",
    "--accent-deep": "rgb(164,160,36)",
    "--accent-soft": "rgba(234,228,52,0.16)",
    "--accent-glow": "rgba(234,228,52,0.42)",
    "--grain": 1,
    "--glow": 1,
    position: "relative",
    background: "#17120f",
    color: "#f2ece3",
    fontFamily: sans,
    minHeight: "100vh",
    WebkitFontSmoothing: "antialiased",
    overflow: "hidden",
  } as React.CSSProperties;

  return (
    <div style={rootStyle}>
      {/* grain overlay */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          pointerEvents: "none",
          zIndex: 2,
          backgroundImage: "radial-gradient(rgba(255,255,255,0.05) 0.5px, transparent 0.6px)",
          backgroundSize: "4px 4px",
          opacity: "var(--grain)" as unknown as number,
        }}
      />
      <Nav />
      <Hero />
      <Features />
      <Screenshots />
      <CliSection />
      <Rhythm />
      <Origin />
      <Stats />
      <DownloadCTA />
      <Footer />
    </div>
  );
}
