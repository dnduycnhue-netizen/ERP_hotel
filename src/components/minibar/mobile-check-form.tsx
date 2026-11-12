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
import { enqueueOfflineJob } from "@/lib/offline/db";
import { useOfflineSync } from "@/lib/offline/use-offline-sync";
import { cn } from "@/lib/utils";

/** Giá đang hiệu lực hôm nay của 1 món (valid_from mới nhất, còn hạn). */
function priceToday(prices: MinibarPriceRow[], itemId: string): number | null {
  const today = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
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

function parseQty(raw: string): number {
  if (raw === "") return 0;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : 0;
}

/**
 * Lưới món kiểm minibar — mobile buồng phòng (T-035, W3).
 * Toàn bộ món nhóm minibar hiện thành danh sách, nhập số thiếu từng
 * món bằng stepper lớn (+ / −, nút ≥ 44px) thay vì thêm dòng + chọn
 * món — bấm nhanh bằng một tay. Số thiếu mặc định 0 (không thiếu);
 * chỉ dòng có số thiếu > 0 mới nộp. Tiền tạm tính theo bảng giá tại
 * ngày kiểm. Gửi 1 lần với `client_uuid` cố định — gửi lại cùng UUID
 * không ghi trùng (mẫu T-023/T-025).
 *
 * Phân quyền giá: bảng giá đọc được qua RLS `minibar_price_list`
 * (người có `minibar.check` được đọc — xem Q187). Người không đọc
 * được giá thì dòng hiện "Chưa có giá" và không nộp được (giữ đúng
 * phân quyền hiện có, không bịa mã quyền mới).
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
  const { online } = useOfflineSync({
    onMinibarSubmitSynced: ({ checkId }) => {
      if (checkId === check.id) {
        router.refresh();
      }
    },
  });
  const [qtyByItem, setQtyByItem] = useState<Record<string, string>>({});
  const [nearExpiryByItem, setNearExpiryByItem] = useState<
    Record<string, boolean>
  >({});
  const [clientUuid] = useState(() => crypto.randomUUID());
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const missingLines = useMemo(
    () =>
      items
        .map((item) => ({
          item,
          qty: parseQty(qtyByItem[item.id] ?? ""),
        }))
        .filter((l) => l.qty > 0),
    [items, qtyByItem],
  );

  const estimatedTotal = useMemo(() => {
    let total = 0;
    let missingPrice = false;
    for (const line of missingLines) {
      const price = priceToday(prices, line.item.id);
      if (price === null) {
        missingPrice = true;
        continue;
      }
      total += line.qty * price;
    }
    return { total, missingPrice };
  }, [missingLines, prices]);

  function setQty(itemId: string, raw: string) {
    const n = Number(raw);
    if (raw !== "" && (!Number.isFinite(n) || n < 0)) return;
    setQtyByItem((prev) => ({ ...prev, [itemId]: raw }));
  }

  function stepQty(itemId: string, delta: number) {
    setQtyByItem((prev) => {
      const current = parseQty(prev[itemId] ?? "");
      const next = Math.max(0, current + delta);
      return { ...prev, [itemId]: next === 0 ? "" : String(next) };
    });
  }

  const canSubmit =
    !pending && missingLines.length > 0 && !estimatedTotal.missingPrice;

  async function handleSubmit() {
    setPending(true);
    setMessage(null);
    setError(null);
    const input = {
      propertyId,
      checkId: check.id,
      lines: missingLines.map((l) => ({
        itemId: l.item.id,
        missingQty: l.qty,
        nearExpiry: nearExpiryByItem[l.item.id] ?? false,
      })),
      clientUuid,
    };
    if (!online) {
      // Q152: mất mạng thì xếp hàng; cùng clientUuid nên gửi lại không ghi trùng.
      try {
        await enqueueOfflineJob({
          propertyId,
          grId: null,
          countId: null,
          kind: "minibar_submit",
          clientUuid,
          payload: { kind: "minibar_submit", input },
          createdAt: Date.now(),
        });
        setMessage(vi.offline.queuedMinibar);
      } catch {
        setError(vi.offline.queueUnavailable);
      }
      setPending(false);
      return;
    }
    const res = await submitCheckAction(input);
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
        <p className="mt-1 text-base text-muted-foreground">
          {check.doc_no} · {vi.minibar.triggers[check.trigger]}
        </p>
        <p className="mt-2 text-base text-muted-foreground">
          {vi.minibar.submitHint}
        </p>
        {items.length > 0 ? (
          <p className="mt-2 text-base font-medium">
            {vi.minibar.enteredMissing}: {missingLines.length}/{items.length}
          </p>
        ) : null}
      </div>

      {message ? (
        <p className="rounded-md border border-green-200 bg-green-50 px-3 py-2 text-base text-green-800">
          {message}
        </p>
      ) : null}
      {error ? (
        <p className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-base text-red-800">
          {error}
        </p>
      ) : null}

      {items.length === 0 ? (
        <p className="rounded-xl border bg-card p-4 text-base text-muted-foreground">
          {vi.minibar.itemsEmpty}
        </p>
      ) : (
        <div className="flex flex-col gap-3">
          {items.map((item) => {
            const raw = qtyByItem[item.id] ?? "";
            const qty = parseQty(raw);
            const price = priceToday(prices, item.id);
            const lineTotal = price !== null && qty > 0 ? qty * price : null;
            return (
              <div
                key={item.id}
                className={cn(
                  "rounded-xl border bg-card p-4",
                  qty > 0 && "border-[#7B68EE]",
                )}
              >
                <p className="text-base font-medium">
                  {item.name} ({item.code})
                </p>
                <p className="text-base text-muted-foreground">
                  {item.stock_uom}
                  {price !== null ? (
                    <>
                      {" · "}
                      {vi.minibar.unitPrice}: {formatNumber(price)}
                    </>
                  ) : (
                    <>
                      {" · "}
                      {vi.minibar.noPrice}
                    </>
                  )}
                  {lineTotal !== null ? (
                    <>
                      {" · "}
                      <MoneyText amount={lineTotal} />
                    </>
                  ) : null}
                </p>

                <div className="mt-3 flex items-center gap-3">
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => stepQty(item.id, -1)}
                    disabled={qty <= 0}
                    className="size-11 min-h-11 min-w-11 shrink-0 text-xl font-semibold"
                    aria-label={`${vi.minibar.stepperDecrease} ${item.name}`}
                  >
                    −
                  </Button>
                  <input
                    type="number"
                    inputMode="decimal"
                    min="0"
                    step="1"
                    value={raw}
                    onChange={(e) => setQty(item.id, e.target.value)}
                    aria-label={`${vi.minibar.missingQty} ${item.name}`}
                    className="min-h-11 w-20 rounded-md border bg-background px-2 py-2 text-center text-lg font-semibold"
                  />
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => stepQty(item.id, 1)}
                    className="size-11 min-h-11 min-w-11 shrink-0 text-xl font-semibold"
                    aria-label={`${vi.minibar.stepperIncrease} ${item.name}`}
                  >
                    +
                  </Button>
                  <span className="text-base text-muted-foreground">
                    {vi.minibar.missingQty}
                  </span>
                </div>

                {qty > 0 ? (
                  <label className="mt-3 flex min-h-11 items-center gap-2 text-base">
                    <input
                      type="checkbox"
                      checked={nearExpiryByItem[item.id] ?? false}
                      onChange={(e) =>
                        setNearExpiryByItem((prev) => ({
                          ...prev,
                          [item.id]: e.target.checked,
                        }))
                      }
                      className="h-5 w-5"
                    />
                    {vi.minibar.nearExpiry}
                  </label>
                ) : null}
              </div>
            );
          })}
        </div>
      )}

      <p className="flex min-h-11 items-center justify-between rounded-xl border bg-card p-4 text-base font-semibold">
        <span>{vi.minibar.estimatedTotal}</span>
        <MoneyText amount={estimatedTotal.total} />
      </p>
      {estimatedTotal.missingPrice ? (
        <p className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-base text-amber-900">
          {vi.minibar.noPrice}
        </p>
      ) : null}
      {missingLines.length === 0 && items.length > 0 ? (
        <p className="text-base text-muted-foreground">
          {vi.minibar.noMissingYet}
        </p>
      ) : null}

      <Button
        type="button"
        size="lg"
        disabled={!canSubmit}
        onClick={handleSubmit}
        className="min-h-11 w-full text-base"
      >
        {pending ? vi.minibar.submitting : vi.minibar.submitCheckButton}
      </Button>
    </div>
  );
}
