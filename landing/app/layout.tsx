import type React from "react"
import type { Metadata } from "next"
import { Inter, IBM_Plex_Mono, Pixelify_Sans } from "next/font/google"
import "./globals.css"

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-inter",
})

const ibmPlexMono = IBM_Plex_Mono({
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
  display: "swap",
  variable: "--font-ibm-plex-mono",
})

const pixelifySans = Pixelify_Sans({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-pixelify-sans",
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
    <html lang="en" className={`${inter.variable} ${ibmPlexMono.variable} ${pixelifySans.variable}`}>
      <body>{children}</body>
    </html>
  )
}