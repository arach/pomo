import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  metadataBase: new URL('https://pomo.arach.dev'),
  title: "Pomo - Minimalist Pomodoro Timer for macOS",
  description: "A beautifully crafted floating Pomodoro timer that lives in your menu bar. Focus on what matters with our distraction-free design.",
  keywords: "pomodoro, timer, productivity, focus, macos, desktop app, time management",
  authors: [{ name: "Pomo Team" }],
  openGraph: {
    title: "Pomo - Minimalist Pomodoro Timer for macOS",
    description: "A beautifully crafted floating Pomodoro timer that lives in your menu bar.",
    type: "website",
    locale: "en_US",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "Pomo - Minimalist Pomodoro Timer",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Pomo - Minimalist Pomodoro Timer for macOS",
    description: "A beautifully crafted floating Pomodoro timer that lives in your menu bar.",
    images: ["/og-image.png"],
  },
  robots: {
    index: true,
    follow: true,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={inter.className}>{children}</body>
    </html>
  );
}