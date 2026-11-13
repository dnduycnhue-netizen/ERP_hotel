"use client";

import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";

/** Nut tai lai du lieu man /admin/health (goi router.refresh). */
export function HealthRefreshButton({ label }: { label: string }) {
  const router = useRouter();
  return (
    <Button variant="outline" onClick={() => router.refresh()}>
      {label}
    </Button>
  );
}
