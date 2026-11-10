"use client";

import { useState } from "react";
import { NumPad } from "@/components/common/num-pad";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";
import { formatQty } from "@/components/count/count-utils";

export type TrolleyCountListItem = {
  itemId: string;
  code: string;
  name: string;
  stockUom: string;
};

function parseDecimal(value: string): number | null {
  if (value === "" || value === "-" || value === "." || value === "-.") {
    return null;
  }
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

/**
 * Danh sách đếm mù xe đẩy (màn xe đẩy mobile):
 * - Chỉ hiện mã/tên/ĐVT + số mình vừa đếm. TUYỆT ĐỐI không hiện mức par
 *   hay tồn lý thuyết khi đếm (đếm mù — xem Q109).
 * - Bấm 1 dòng để mở NumPad nhập số; số 0 được (xe hết hàng đó).
 * - Giá trị là chuỗi ("" = chưa đếm); component cha tự lưu nháp + nộp.
 */
export function TrolleyCountList({
  items,
  values,
  onChange,
  disabled = false,
}: {
  items: TrolleyCountListItem[];
  values: Record<string, string>;
  onChange: (itemId: string, value: string) => void;
  disabled?: boolean;
}) {
  const [activeItemId, setActiveItemId] = useState<string | null>(null);

  const counted = items.filter((item) => {
    const value = values[item.itemId] ?? "";
    return parseDecimal(value) !== null;
  }).length;

  return (
    <div className="flex flex-col gap-2">
      <p className="text-sm text-muted-foreground">
        {vi.trolley.countedProgress}: {counted}/{items.length}
      </p>
      <ul className="flex flex-col gap-2">
        {items.map((item) => {
          const value = values[item.itemId] ?? "";
          const countedQty = parseDecimal(value);
          const active = activeItemId === item.itemId;
          return (
            <li key={item.itemId} className="rounded-xl border bg-card">
              <button
                type="button"
                disabled={disabled}
                onClick={() => setActiveItemId(active ? null : item.itemId)}
                className="flex w-full items-start justify-between gap-3 p-4 text-left disabled:cursor-default"
              >
                <span>
                  <span className="block font-medium">
                    {item.code} — {item.name}
                  </span>
                  <span className="block text-sm text-muted-foreground">
                    {vi.inventory.stockUom}: {item.stockUom}
                    {countedQty !== null ? (
                      <>
                        {" · "}
                        {vi.trolley.countedQty}: {formatQty(countedQty)}{" "}
                        {item.stockUom}
                      </>
                    ) : null}
                  </span>
                </span>
                <span
                  className={cn(
                    "shrink-0 rounded px-2 py-0.5 text-xs font-medium",
                    countedQty !== null
                      ? "bg-green-100 text-green-800"
                      : "bg-muted text-muted-foreground",
                  )}
                >
                  {countedQty !== null
                    ? vi.trolley.counted
                    : vi.trolley.notCounted}
                </span>
              </button>
              {active && !disabled ? (
                <div className="border-t p-3">
                  <NumPad
                    value={value}
                    onChange={(next) => onChange(item.itemId, next)}
                  />
                </div>
              ) : null}
            </li>
          );
        })}
      </ul>
    </div>
  );
}
