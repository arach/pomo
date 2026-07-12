import Image from "next/image";

export const appStorePromos = {
  focus: {
    order: "01",
    label: "Focus timer",
    title: "Focus on the task.",
    description: "Add a note and start the timer.",
    src: "/marketing/iphone-focus.png",
    accent: "#eae434",
  },
  faces: {
    order: "02",
    label: "Timer faces",
    title: "Choose a timer face.",
    description: "Dial, Terminal, and Blueprint are included.",
    src: "/marketing/iphone-blueprint.png",
    accent: "#70b7ff",
  },
  activity: {
    order: "03",
    label: "Activity",
    title: "Review your activity.",
    description: "See sessions, focus time, and streaks.",
    src: "/marketing/iphone-activity.png",
    accent: "#5ed69a",
  },
  settings: {
    order: "04",
    label: "Settings",
    title: "Adjust the timer.",
    description: "Set focus, break, and planning lengths.",
    src: "/marketing/iphone-settings.png",
    accent: "#f2a65a",
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
          <span className="app-store-wordmark"><i />POMO</span>
          <span>{promo.order} / 04</span>
        </div>
        <div className="app-store-rule" />
        <div className="app-store-label">{promo.label}</div>
        <h1>{promo.title}</h1>
        <p>{promo.description}</p>
      </header>

      <div className="app-store-device" aria-label={`Pomo for iPhone — ${promo.title}`}>
        <div className="app-store-device-label" aria-hidden="true">
          <span>iPhone · 6.9 inch</span>
          <span>UI / 1:1</span>
        </div>
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

    </main>
  );
}
