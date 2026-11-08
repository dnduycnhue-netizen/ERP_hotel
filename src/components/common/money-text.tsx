import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

/**
 * Chỉ hiển thị tiền — không cộng trừ tiền bằng JS (AGENTS.md quy tắc 7:
 * tiền tính trong Postgres bằng `numeric`). Nhận `number` hoặc chuỗi số
 * từ Postgres; giá trị rỗng/không hợp lệ hiện "—".
 */
export function formatMoney(
  amount: number | string | null | undefined,
): string {
  if (amount === null || amount === undefined || amount === "") {
    return vi.common.noData;
  }
  const value = typeof amount === "string" ? Number(amount) : amount;
  if (!Number.isFinite(value)) {
    return vi.common.noData;
  }
  const formatted = new Intl.NumberFormat("vi-VN", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(value);
  return `${formatted} ${vi.components.money.currencySuffix}`;
}

/** Định dạng số lượng/đơn giá theo `vi-VN` (1.234.567,5). */
export function formatNumber(
  value: number | string | null | undefined,
): string {
  if (value === null || value === undefined || value === "") {
    return vi.common.noData;
  }
  const parsed = typeof value === "string" ? Number(value) : value;
  if (!Number.isFinite(parsed)) {
    return vi.common.noData;
  }
  return new Intl.NumberFormat("vi-VN", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 4,
  }).format(parsed);
}

export function MoneyText({
  amount,
  className,
}: {
  amount: number | string | null | undefined;
  className?: string;
}) {
  const isNegative =
    amount !== null &&
    amount !== undefined &&
    amount !== "" &&
    Number(amount) < 0;
  return (
    <span
      className={cn(
        "tabular-nums whitespace-nowrap",
        isNegative && "text-destructive",
        className,
      )}
    >
      {formatMoney(amount)}
    </span>
  );
}
