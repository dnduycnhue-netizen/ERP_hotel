import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";
import { vi } from "@/i18n/vi";
import { Geist } from "next/font/google";
import { cn } from "@/lib/utils";

const geist = Geist({ subsets: ["latin"], variable: "--font-sans" });

export const metadata: Metadata = {
  title: vi.appName,
  description: vi.appDescription,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  return (
    <html
      lang="vi"
      className={cn("h-full antialiased", "font-sans", geist.variable)}
    >
      <body className="min-h-full">{children}</body>
    </html>
  );
}
