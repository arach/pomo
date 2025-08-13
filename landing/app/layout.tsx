import type React from "react"
import type { Metadata } from "next"
import { Inter, Space_Grotesk } from "next/font/google"
import "./globals.css"

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
  weight: ["300", "400", "500", "600", "700"],
})

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-space-grotesk",
  display: "swap",
  weight: ["400", "500", "600", "700"],
})

export const metadata: Metadata = {
  metadataBase: new URL("https://pomo.arach.dev"),
  title: "Pomo - Minimalist Pomodoro Timer for macOS",
  description:
    "A beautifully crafted floating Pomodoro timer that lives in your menu bar. Focus on what matters with our distraction-free design.",
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
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${spaceGrotesk.variable}`}>
      <body>{children}</body>
    </html>
  )
}