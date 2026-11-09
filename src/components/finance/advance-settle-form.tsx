"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import { settleAdvanceAction } from "@/features/finance/actions";
import type { AdvanceRow } from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";

/**
 * Quyết toán tạm ứng (T-041): nhập số tiền thực chi theo từng khoản.
 * Hiển thị trước số hoàn lại / trả thêm so với số tạm ứng; gửi qua RPC
 * `advance_settle` (quyết toán là cuối cùng, không sửa lại được).
 * Liên kết phiếu nhận (gr_id) chưa nhập ở màn này — RPC chấp nhận
 * dòng không kèm GR; đối chiếu GR làm ở bước kiểm tra sau (xem Q74).
 */
export function AdvanceSettleForm({
  propertyId,
  advance,
}: {
  propertyId: string;
  advance: AdvanceRow;
}) {
  const router = useRouter();
  const [amounts, setAmounts] = useState<string[]>([""]);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<{
    spent: number;
    refund: number;
    extra: number;
  } | null>(null);

  const spent = useMemo(
    () =>
      amounts.reduce((s, v) => {
        const n = Number(v);
        return s + (Number.isFinite(n) && n > 0 ? n : 0);
      }, 0),
    [amounts],
  );
  const refund = Math.max(0, advance.amount - spent);
  const extra = Math.max(0, spent - advance.amount);

  const canSubmit =
    !pending && amounts.length > 0 && amounts.every((v) => Number(v) > 0);

  function setAmount(index: number, value: string) {
    setAmounts((prev) => prev.map((v, i) => (i === index ? value : v)));
  }

  async function handleSubmit() {
    setPending(true);
    setError(null);
    setResult(null);
    const res = await settleAdvanceAction({
      propertyId,
      advanceId: advance.id,
      lines: amounts.map((a) => ({ amount: Number(a) })),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setResult({
      spent: res.data.spent,
      refund: res.data.refund_amount,
      extra: res.data.extra_pay_amount,
    });
    router.refresh();
  }

  return (
    <div className="rounded-xl border bg-card p-4">
      <h2 className="font-medium">{vi.finance.settleTitle}</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        {vi.finance.settleHint}
      </p>
      <div className="mt-3 space-y-2">
        {amounts.map((amount, i) => (
          <div key={i} className="flex items-center gap-2">
            <label className="block flex-1 text-sm">
              {vi.finance.actualAmount} {i + 1}
              <input
                type="number"
                inputMode="decimal"
                min="0"
                step="0.01"
                value={amount}
                onChange={(e) => setAmount(i, e.target.value)}
                className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
              />
            </label>
            {amounts.length > 1 ? (
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="mt-5"
                onClick={() =>
                  setAmounts((prev) => prev.filter((_, j) => j !== i))
                }
              >
                {vi.common.cancel}
              </Button>
            ) : null}
          </div>
        ))}
      </div>
      <Button
        type="button"
        variant="outline"
        size="sm"
        className="mt-2"
        onClick={() => setAmounts((prev) => [...prev, ""])}
      >
        + {vi.finance.actualAmount}
      </Button>
      <div className="mt-4 space-y-1 text-sm">
        <p>
          {vi.finance.spentTotal}: <MoneyText amount={spent} />
        </p>
        <p>
          {vi.finance.refundAmount}: <MoneyText amount={refund} />
        </p>
        <p>
          {vi.finance.extraPayAmount}: <MoneyText amount={extra} />
        </p>
      </div>
      <Button
        type="button"
        className="mt-4"
        disabled={!canSubmit}
        onClick={handleSubmit}
      >
        {pending ? vi.finance.settling : vi.finance.settleButton}
      </Button>
      {result ? (
        <p className="mt-3 text-sm font-medium text-green-800">
          {vi.finance.settledMessage}
        </p>
      ) : null}
      {error ? (
        <p className="mt-3 text-sm font-medium text-red-800">{error}</p>
      ) : null}
    </div>
  );
}
