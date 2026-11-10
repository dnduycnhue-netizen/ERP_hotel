"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { reconcileAction } from "@/features/minibar/actions";
import type { MinibarReconcileResult } from "@/features/minibar/queries";
import { vi } from "@/i18n/vi";

/**
 * Đối soát minibar 1 ngày — văn phòng (T-035).
 * Tổng ghi nhận = đã thu + đã miễn + thu muộn; phiếu chờ thu tồn từ
 * ngày trước vẫn tính vào lệch (Q52). Lệch ≠ 0 → hệ thống tạo cảnh
 * báo MINIBAR_MISMATCH (dedupe theo ngày).
 */
export function OfficeReconcilePanel({
  propertyId,
}: {
  propertyId: string;
}) {
  const today = new Date().toISOString().slice(0, 10);
  const [date, setDate] = useState(today);
  const [pending, setPending] = useState(false);
  const [result, setResult] = useState<MinibarReconcileResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleReconcile() {
    setPending(true);
    setError(null);
    setResult(null);
    const res = await reconcileAction({ propertyId, date });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setResult(res.data);
  }

  const rows: Array<{ label: string; value: number }> = result
    ? [
        { label: vi.minibar.recorded, value: Number(result.recorded) },
        { label: vi.minibar.charged, value: Number(result.charged) },
        { label: vi.minibar.waived, value: Number(result.waived) },
        { label: vi.minibar.lateCharge, value: Number(result.late_charge) },
        {
          label: vi.minibar.pendingToday,
          value: Number(result.pending_today),
        },
        {
          label: vi.minibar.pendingStale,
          value: Number(result.pending_stale),
        },
      ]
    : [];

  return (
    <div className="rounded-xl border bg-card p-4">
      <h2 className="font-medium">{vi.minibar.reconcileTitle}</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        {vi.minibar.reconcileHint}
      </p>
      <div className="mt-3 flex flex-wrap items-end gap-3">
        <label className="block text-sm">
          {vi.minibar.businessDate}
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="mt-1 rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <Button
          type="button"
          disabled={pending || date === ""}
          onClick={handleReconcile}
        >
          {pending ? vi.minibar.reconciling : vi.minibar.reconcileButton}
        </Button>
      </div>
      {error ? (
        <p className="mt-3 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
          {error}
        </p>
      ) : null}
      {result ? (
        <div className="mt-4">
          <table className="w-full text-sm">
            <tbody>
              {rows.map((row) => (
                <tr key={row.label} className="border-b last:border-0">
                  <td className="py-2 pr-2 text-muted-foreground">
                    {row.label}
                  </td>
                  <td className="py-2 text-right font-medium">
                    <MoneyText amount={row.value} />
                  </td>
                </tr>
              ))}
              <tr>
                <td className="py-2 pr-2 font-semibold">{vi.minibar.diff}</td>
                <td className="py-2 text-right font-semibold">
                  <MoneyText amount={Number(result.diff)} />
                </td>
              </tr>
            </tbody>
          </table>
          <p
            className={`mt-3 rounded-md border px-3 py-2 text-sm ${
              Number(result.diff) === 0
                ? "border-green-200 bg-green-50 text-green-800"
                : "border-red-200 bg-red-50 text-red-800"
            }`}
          >
            {Number(result.diff) === 0
              ? vi.minibar.diffOk
              : vi.minibar.diffMismatch}
          </p>
          {Number(result.diff) !== 0 && result.alert_id ? (
            <p className="mt-2 text-sm text-muted-foreground">
              {vi.minibar.diff} {formatNumber(result.diff)}
            </p>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
