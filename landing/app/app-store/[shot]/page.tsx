import type { Metadata } from "next";
import { notFound } from "next/navigation";
import {
  AppStorePromo,
  appStorePromos,
  type AppStorePromoKey,
} from "../../../components/app-store-promo";

export const dynamicParams = false;

export function generateStaticParams() {
  return Object.keys(appStorePromos).map((shot) => ({ shot }));
}

export const metadata: Metadata = {
  title: "Pomo App Store promotional screenshot",
  robots: { index: false, follow: false },
};

export default async function AppStorePromoPage({
  params,
}: {
  params: Promise<{ shot: string }>;
}) {
  const { shot } = await params;
  if (!(shot in appStorePromos)) notFound();

  return <AppStorePromo shot={shot as AppStorePromoKey} />;
}
