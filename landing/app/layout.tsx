import type React from "react"
import type { Metadata } from "next"
import Script from "next/script"
import { Space_Grotesk, JetBrains_Mono } from "next/font/google"
import "./globals.css"

const spaceGrotesk = Space_Grotesk({
  weight: ["300", "400", "500", "600", "700"],
  subsets: ["latin"],
  display: "swap",
  variable: "--font-space-grotesk",
})

const jetbrainsMono = JetBrains_Mono({
  weight: ["300", "400", "500", "600"],
  subsets: ["latin"],
  display: "swap",
  variable: "--font-jetbrains-mono",
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
    <html lang="en" className={`${spaceGrotesk.variable} ${jetbrainsMono.variable}`}>
      <body>
        {children}
        <Script
          src="https://www.googletagmanager.com/gtag/js?id=G-GSHDZPFRZG"
          strategy="afterInteractive"
        />
        <Script id="google-analytics" strategy="afterInteractive">
          {`window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', 'G-GSHDZPFRZG');`}
        </Script>
      </body>
    </html>
  )
}