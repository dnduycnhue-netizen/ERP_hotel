"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { refreshStockCardAction } from "@/features/report/actions";
import { vi } from "@/i18n/vi";

/** Nút làm mới số liệu thẻ kho ngay (không chờ 07:35 hôm sau). */
export function RefreshStockCardButton({ propertyId }: { propertyId: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleClick() {
    setBusy(true);
    setError(null);
    const res = await refreshStockCardAction(propertyId);
    setBusy(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-1">
      <Button
        type="button"
        variant="outline"
        size="sm"
        disabled={busy}
        onClick={() => void handleClick()}
      >
        {busy ? vi.reports.refreshing : vi.reports.refreshStockCard}
      </Button>
      {error ? (
        <p role="alert" className="text-xs text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  );
}
