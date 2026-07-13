import Image from "next/image";

export const appStorePromos = {
  timer: {
    order: "01",
    label: "Timer",
    title: "Set an intention.",
    description: "Name the task. Start the timer.",
    detail: "Focus · 25 min",
    src: "/marketing/iphone-timer-v2.png",
    accent: "#eae434",
  },
  faces: {
    order: "02",
    label: "Faces",
    title: "Choose your face.",
    description: "Seven distinct faces, ready in Settings.",
    detail: "7 included",
    src: "/marketing/iphone-faces-v2.png",
    accent: "#c39aff",
  },
  immersive: {
    order: "03",
    label: "Focus view",
    title: "Just the timer.",
    description: "Tap the face for a quieter view.",
    detail: "Tap to return",
    src: "/marketing/iphone-immersive-v2.png",
    accent: "#55e8f5",
  },
  duration: {
    order: "04",
    label: "Session length",
    title: "Set the time.",
    description: "Use a preset or choose it precisely.",
    detail: "Minutes · seconds",
    src: "/marketing/iphone-duration-v2.png",
    accent: "#f2a65a",
  },
  activity: {
    order: "05",
    label: "Activity",
    title: "See your rhythm.",
    description: "Sessions, focus time, and streaks.",
    detail: "Private · on device",
    src: "/marketing/iphone-activity-v2.png",
    accent: "#5ed69a",
  },
} as const;

export type AppStorePromoKey = keyof typeof appStorePromos;

export function AppStorePromo({ shot }: { shot: AppStorePromoKey }) {
  const promo = appStorePromos[shot];

  return (
    <main
      className={`app-store-artboard is-${shot}`}
      style={{ "--promo-accent": promo.accent } as React.CSSProperties}
    >
      <div className="app-store-grid" aria-hidden="true" />

      <header className="app-store-copy">
        <div className="app-store-meta">
          <span className="app-store-wordmark"><i /><em>POMO</em><b>for iPhone</b></span>
          <span>{promo.order} — 05</span>
        </div>
        <div className="app-store-label">{promo.label}</div>
        <h1>{promo.title}</h1>
        <p>{promo.description}</p>
      </header>

      <div className="app-store-stage" aria-label={`Pomo for iPhone — ${promo.title}`}>
        <div className="app-store-orbit" aria-hidden="true" />
        <div className="app-store-detail" aria-hidden="true"><i />{promo.detail}</div>
        <div className="app-store-device">
        <div className="app-store-device-frame">
          <Image
            src={promo.src}
            width={1320}
            height={2868}
            sizes="980px"
            alt={`Pomo for iPhone showing ${promo.label.toLowerCase()}`}
            priority
          />
        </div>
        </div>
      </div>

    </main>
  );
}
