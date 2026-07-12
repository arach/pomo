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
  title: "Pomo — Focus timer for Mac and iPhone",
  description:
    "Name the work, start the clock, and keep momentum visible with a focused timer for Mac and iPhone.",
  keywords: "pomodoro, timer, productivity, focus, macos, iphone, deep work, study, writing",
  authors: [{ name: "Arach" }],
  openGraph: {
    title: "Pomo for Mac and iPhone",
    description: "A focus timer with task notes, adjustable sessions, timer faces, and private activity history.",
    type: "website",
    locale: "en_US",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "Four views of the Pomo focus timer for iPhone",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Pomo — Focus timer for Mac and iPhone",
    description: "A focus timer with task notes, adjustable sessions, and private activity history.",
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
