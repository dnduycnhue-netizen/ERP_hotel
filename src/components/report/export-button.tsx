"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";

/**
 * Nút "Xuất Excel": tải file bằng fetch rồi lưu, KHÔNG điều hướng tab hiện tại
 * (B-46). Lỗi từ API (chưa khóa sổ, thiếu quyền...) hiện ngay dưới nút.
 */
export function ExportButton({ href }: { href: string }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleClick() {
    setBusy(true);
    setError(null);
    try {
      const res = await fetch(href, { credentials: "same-origin" });
      if (!res.ok) {
        let message: string = vi.reports.exportFailed;
        try {
          const body = (await res.json()) as { error?: string };
          if (body.error) message = body.error;
        } catch {
          // giữ thông báo mặc định
        }
        setError(message);
        return;
      }
      const blob = await res.blob();
      const disposition = res.headers.get("Content-Disposition") ?? "";
      const match = disposition.match(/filename="([^"]+)"/);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = match?.[1] ?? "bao-cao.xlsx";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    } catch {
      setError(vi.reports.exportFailed);
    } finally {
      setBusy(false);
    }
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
        {busy ? vi.reports.exporting : vi.reports.exportExcel}
      </Button>
      {error ? (
        <p role="alert" className="text-xs text-destructive">
          {error}
        </p>
      ) : null}
    </div>
  );
}
