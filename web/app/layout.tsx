import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "方寸｜把家，装进秩序里",
  description: "方寸是为家庭而生的物品管理与生活提醒 app。",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
