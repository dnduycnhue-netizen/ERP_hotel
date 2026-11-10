"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { submitCheckAction } from "@/features/minibar/actions";
import type {
  MinibarCheckRow,
  MinibarItemRow,
  MinibarPriceRow,
} from "@/features/minibar/queries";
import { vi } from "@/i18n/vi";

type LineDraft = {
  itemId: string;
  missingQty: string;
  nearExpiry: boolean;
};

/** Giá đang hiệu lực hôm nay của 1 món (valid_from mới nhất, còn hạn). */
function priceToday(prices: MinibarPriceRow[], itemId: string): number | null {
  const today = new Date().toISOString().slice(0, 10);
  const valid = prices
    .filter(
      (p) =>
        p.item_id === itemId &&
        p.valid_from <= today &&
        (p.valid_to === null || p.valid_to >= today),
    )
    .sort((a, b) => (a.valid_from < b.valid_from ? 1 : -1));
  return valid.length > 0 ? Number(valid[0].price) : null;
}

/**
 * Lưới món kiểm minibar — mobile buồng phòng (T-035).
 * Nhập số thiếu từng món + cờ sắp hết hạn; tiền tạm tính theo bảng
 * giá tại ngày kiểm. Gửi 1 lần với `client_uuid` cố định — gửi lại
 * cùng UUID không ghi trùng (mẫu T-023/T-025).
 */
export function MobileCheckForm({
  propertyId,
  check,
  items,
  prices,
}: {
  propertyId: string;
  check: MinibarCheckRow;
  items: MinibarItemRow[];
  prices: MinibarPriceRow[];
}) {
  const router = useRouter();
  const [lines, setLines] = useState<LineDraft[]>([
    { itemId: "", missingQty: "", nearExpiry: false },
  ]);
  const [clientUuid] = useState(() => crypto.randomUUID());
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const usedItemIds = new Set(lines.map((l) => l.itemId).filter(Boolean));

  const estimatedTotal = useMemo(() => {
    let total = 0;
    let missingPrice = false;
    for (const line of lines) {
      const qty = Number(line.missingQty);
      if (!line.itemId || !Number.isFinite(qty) || qty <= 0) continue;
      const price = priceToday(prices, line.itemId);
      if (price === null) {
        missingPrice = true;
        continue;
      }
      total += qty * price;
    }
    return { total, missingPrice };
  }, [lines, prices]);

  function updateLine(index: number, patch: Partial<LineDraft>) {
    setLines((prev) =>
      prev.map((l, i) => (i === index ? { ...l, ...patch } : l)),
    );
  }

  function addLine() {
    setLines((prev) => [
      ...prev,
      { itemId: "", missingQty: "", nearExpiry: false },
    ]);
  }

  function removeLine(index: number) {
    setLines((prev) => prev.filter((_, i) => i !== index));
  }

  const validLines = lines.filter(
    (l) =>
      l.itemId !== "" &&
      Number.isFinite(Number(l.missingQty)) &&
      Number(l.missingQty) > 0,
  );
  const canSubmit =
    !pending && validLines.length > 0 && !estimatedTotal.missingPrice;

  async function handleSubmit() {
    setPending(true);
    setMessage(null);
    setError(null);
    const res = await submitCheckAction({
      propertyId,
      checkId: check.id,
      lines: validLines.map((l) => ({
        itemId: l.itemId,
        missingQty: Number(l.missingQty),
        nearExpiry: l.nearExpiry,
      })),
      clientUuid,
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setMessage(
      res.data.duplicate
        ? vi.minibar.submitDuplicate
        : vi.minibar.submitSuccess,
    );
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-xl font-semibold">
          {vi.minibar.mobileTitle} — {vi.minibar.roomNo} {check.room_no}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {check.doc_no} · {vi.minibar.triggers[check.trigger]}
        </p>
        <p className="mt-2 text-sm text-muted-foreground">
          {vi.minibar.submitHint}
        </p>
      </div>

      {message ? (
        <p className="rounded-md border border-green-200 bg-green-50 px-3 py-2 text-sm text-green-800">
          {message}
        </p>
      ) : null}
      {error ? (
        <p className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
          {error}
        </p>
      ) : null}

      <div className="flex flex-col gap-3">
        {lines.map((line, index) => {
          const price =
            line.itemId !== "" ? priceToday(prices, line.itemId) : null;
          const qty = Number(line.missingQty);
          const lineTotal =
            price !== null && Number.isFinite(qty) && qty > 0
              ? qty * price
              : null;
          return (
            <div key={index} className="rounded-xl border bg-card p-4">
              <label className="block text-sm">
                {vi.minibar.itemName}
                <select
                  value={line.itemId}
                  onChange={(e) =>
                    updateLine(index, { itemId: e.target.value })
                  }
                  className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                >
                  <option value="">{vi.minibar.selectItem}</option>
                  {items
                    .filter(
                      (item) =>
                        item.id === line.itemId || !usedItemIds.has(item.id),
                    )
                    .map((item) => (
                      <option key={item.id} value={item.id}>
                        {item.name} ({item.code}) — {item.stock_uom}
                      </option>
                    ))}
                </select>
              </label>
              <div className="mt-3 grid grid-cols-2 gap-3">
                <label className="block text-sm">
                  {vi.minibar.missingQty}
                  <input
                    type="number"
                    inputMode="decimal"
                    min="0"
                    step="0.01"
                    value={line.missingQty}
                    onChange={(e) =>
                      updateLine(index, { missingQty: e.target.value })
                    }
                    className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                  />
                </label>
                <div className="flex items-end pb-1">
                  <label className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      checked={line.nearExpiry}
                      onChange={(e) =>
                        updateLine(index, { nearExpiry: e.target.checked })
                      }
                      className="h-4 w-4"
                    />
                    {vi.minibar.nearExpiry}
                  </label>
                </div>
              </div>
              <p className="mt-2 text-sm text-muted-foreground">
                {price === null && line.itemId !== ""
                  ? vi.minibar.noPrice
                  : price !== null
                    ? `${vi.minibar.unitPrice}: ${formatNumber(price)}`
                    : ""}
                {lineTotal !== null ? (
                  <>
                    {" · "}
                    <MoneyText amount={lineTotal} />
                  </>
                ) : null}
              </p>
              {lines.length > 1 ? (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="mt-2"
                  onClick={() => removeLine(index)}
                >
                  {vi.common.close}
                </Button>
              ) : null}
            </div>
          );
        })}
      </div>

      <Button type="button" variant="outline" onClick={addLine}>
        {vi.minibar.addItem}
      </Button>

      <p className="flex items-center justify-between rounded-xl border bg-card p-4 font-semibold">
        <span>{vi.minibar.estimatedTotal}</span>
        <MoneyText amount={estimatedTotal.total} />
      </p>
      {estimatedTotal.missingPrice ? (
        <p className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
          {vi.minibar.noPrice}
        </p>
      ) : null}

      <Button
        type="button"
        size="lg"
        disabled={!canSubmit}
        onClick={handleSubmit}
      >
        {pending ? vi.minibar.submitting : vi.minibar.submitCheckButton}
      </Button>
    </div>
  );
}
