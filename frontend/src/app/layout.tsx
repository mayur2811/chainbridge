/**
 * ============================================
 * ROOT LAYOUT - WRAPS ENTIRE APP
 * ============================================
 * 
 * 📚 WHAT THIS DOES:
 * - Sets up the HTML structure for all pages
 * - Applies fonts and global styles
 * - Wraps everything with Web3 Providers
 */

import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Providers } from "./providers";

// Google fonts for clean look
const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// Page metadata (appears in browser tab)
export const metadata: Metadata = {
  title: "ChainBridge | Cross-Chain Token Bridge",
  description: "Bridge tokens between Sepolia and Hoodi testnets securely",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`}
      >
        {/* 📚 Providers wrap everything - now wallet works on all pages! */}
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
