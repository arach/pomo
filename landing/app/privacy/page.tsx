import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy Policy — Pomo",
  description: "How Pomo handles timer settings, session history, Photo face images, and website analytics.",
};

const sections = [
  {
    title: "The Pomo app",
    body: "Pomo does not require an account and does not include advertising or analytics SDKs. Timer settings, session intentions, activity history, and any image you choose for the Photo face are stored locally on your device. The app does not send that information to us or to third parties.",
  },
  {
    title: "Notifications",
    body: "If you enable notifications, Pomo asks iOS for permission and schedules timer-completion notifications locally on your device. Pomo does not use a remote push-notification service.",
  },
  {
    title: "Website analytics",
    body: "The Pomo website uses Google Analytics to understand aggregate site traffic. That website measurement is separate from the Pomo app. You can limit or block it using your browser’s privacy controls.",
  },
  {
    title: "Your choices",
    body: "You can clear your Pomo activity history from Settings at any time. Removing the app also removes its locally stored data, subject to your device backup settings.",
  },
  {
    title: "Contact",
    body: "For privacy questions, open an issue in the public Pomo repository at github.com/arach/pomo.",
  },
];

export default function PrivacyPage() {
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
          Privacy policy · July 12, 2026
        </p>
        <h1 style={{ margin: 0, fontSize: "clamp(38px, 7vw, 62px)", fontWeight: 400, letterSpacing: "-0.035em" }}>
          Focus stays <span style={{ color: "#eae434" }}>yours.</span>
        </h1>
        <p style={{ margin: "24px 0 48px", color: "#bcae9e", fontSize: 18, lineHeight: 1.7 }}>
          Pomo is designed to work without collecting your personal data.
        </p>

        <div style={{ display: "grid", gap: 14 }}>
          {sections.map((section) => (
            <section
              key={section.title}
              style={{
                padding: 24,
                border: "1px solid rgba(255,255,255,0.09)",
                borderRadius: 16,
                background: "#201913",
              }}
            >
              <h2 style={{ margin: "0 0 10px", fontSize: 18, fontWeight: 500 }}>{section.title}</h2>
              <p style={{ margin: 0, color: "#bcae9e", lineHeight: 1.7 }}>{section.body}</p>
            </section>
          ))}
        </div>
      </article>
    </main>
  );
}
