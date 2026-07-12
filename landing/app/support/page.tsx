import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Support — Pomo",
  description: "Get help with the Pomo focus timer for iPhone and Mac.",
};

const supportLinks = [
  {
    title: "Report a problem",
    body: "Open a GitHub issue with the device, OS version, and a short description of what happened.",
    href: "https://github.com/arach/pomo/issues/new/choose",
    label: "Open an issue",
  },
  {
    title: "Read the source",
    body: "Pomo is open source. You can inspect the code, follow development, or contribute a fix.",
    href: "https://github.com/arach/pomo",
    label: "View the repository",
  },
  {
    title: "Privacy",
    body: "Pomo stores timer settings and activity locally and does not require an account.",
    href: "/privacy",
    label: "Read the privacy policy",
  },
];

export default function SupportPage() {
  return (
    <main
      style={{
        minHeight: "100vh",
        background: "#17120f",
        color: "#f4eee6",
        padding: "72px 24px",
      }}
    >
      <article style={{ maxWidth: 720, margin: "0 auto" }}>
        <Link
          href="/"
          style={{
            color: "#eae434",
            fontFamily: "var(--font-jetbrains-mono), monospace",
            fontSize: 12,
            letterSpacing: "0.08em",
            textDecoration: "none",
          }}
        >
          ← POMO
        </Link>

        <p
          style={{
            margin: "54px 0 14px",
            color: "#7d7165",
            fontFamily: "var(--font-jetbrains-mono), monospace",
            fontSize: 11,
            letterSpacing: "0.18em",
            textTransform: "uppercase",
          }}
        >
          Support · Pomo 1.0
        </p>
        <h1 style={{ margin: 0, fontSize: "clamp(38px, 7vw, 62px)", fontWeight: 400, letterSpacing: "-0.035em" }}>
          How can we <span style={{ color: "#eae434" }}>help?</span>
        </h1>
        <p style={{ margin: "24px 0 48px", color: "#bcae9e", fontSize: 18, lineHeight: 1.7 }}>
          Pomo is a small, independent app. The public issue tracker is the quickest way to report a problem.
        </p>

        <div style={{ display: "grid", gap: 14 }}>
          {supportLinks.map((item) => (
            <section
              key={item.title}
              style={{
                padding: 24,
                border: "1px solid rgba(255,255,255,0.09)",
                borderRadius: 16,
                background: "#201913",
              }}
            >
              <h2 style={{ margin: "0 0 10px", fontSize: 18, fontWeight: 500 }}>{item.title}</h2>
              <p style={{ margin: "0 0 16px", color: "#bcae9e", lineHeight: 1.7 }}>{item.body}</p>
              <Link href={item.href} style={{ color: "#eae434", textDecoration: "none" }}>
                {item.label} →
              </Link>
            </section>
          ))}
        </div>
      </article>
    </main>
  );
}
