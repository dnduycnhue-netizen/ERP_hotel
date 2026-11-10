"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import { saveNoInvoiceListingAction } from "@/features/finance/actions";
import { vi } from "@/i18n/vi";

/** Ngày hôm nay theo giờ Việt Nam (YYYY-MM-DD) — phía client. */
function todayVnClient(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

/** Nhập bảng kê mua hàng không hóa đơn (T-041). */
export function NoInvoiceForm({ propertyId }: { propertyId: string }) {
  const router = useRouter();
  const [sellerName, setSellerName] = useState("");
  const [sellerAddress, setSellerAddress] = useState("");
  const [sellerIdNo, setSellerIdNo] = useState("");
  const [purchaseDate, setPurchaseDate] = useState(todayVnClient());
  const [lines, setLines] = useState<
    Array<{ itemDesc: string; qty: string; unitPrice: string }>
  >([{ itemDesc: "", qty: "", unitPrice: "" }]);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const total = useMemo(
    () =>
      lines.reduce((s, l) => {
        const qty = Number(l.qty);
        const price = Number(l.unitPrice);
        if (!Number.isFinite(qty) || !Number.isFinite(price)) return s;
        return s + qty * price;
      }, 0),
    [lines],
  );

  const canSubmit =
    !pending &&
    sellerName.trim() !== "" &&
    purchaseDate !== "" &&
    lines.length > 0 &&
    lines.every(
      (l) =>
        l.itemDesc.trim() !== "" &&
        Number(l.qty) > 0 &&
        Number(l.unitPrice) >= 0,
    );

  function setLine(
    index: number,
    patch: Partial<{ itemDesc: string; qty: string; unitPrice: string }>,
  ) {
    setLines((prev) =>
      prev.map((l, i) => (i === index ? { ...l, ...patch } : l)),
    );
  }

  async function handleSubmit() {
    setPending(true);
    setError(null);
    const res = await saveNoInvoiceListingAction({
      propertyId,
      listing: {
        sellerName: sellerName.trim(),
        purchaseDate,
        poId: null,
        grId: null,
        sellerAddress: sellerAddress.trim() || null,
        sellerIdNo: sellerIdNo.trim() || null,
      },
      lines: lines.map((l) => ({
        itemDesc: l.itemDesc.trim(),
        qty: Number(l.qty),
        unitPrice: Number(l.unitPrice),
      })),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.refresh();
  }

  return (
    <div className="rounded-lg border bg-card p-4">
      <h2 className="font-medium">{vi.finance.newListing}</h2>
      <div className="mt-3 grid gap-3 sm:grid-cols-2">
        <label className="block text-sm">
          {vi.finance.sellerName}
          <input
            value={sellerName}
            onChange={(e) => setSellerName(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.finance.purchaseDate}
          <input
            type="date"
            value={purchaseDate}
            onChange={(e) => setPurchaseDate(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.finance.sellerAddress}
          <input
            value={sellerAddress}
            onChange={(e) => setSellerAddress(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.finance.sellerIdNo}
          <input
            value={sellerIdNo}
            onChange={(e) => setSellerIdNo(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
      </div>
      <div className="mt-4 space-y-2">
        {lines.map((l, i) => (
          <div key={i} className="grid gap-2 sm:grid-cols-[2fr_1fr_1fr_auto]">
            <label className="block text-sm">
              {vi.finance.itemDesc}
              <input
                value={l.itemDesc}
                onChange={(e) => setLine(i, { itemDesc: e.target.value })}
                className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
              />
            </label>
            <label className="block text-sm">
              {vi.finance.invoiceQty}
              <input
                type="number"
                inputMode="decimal"
                min="0"
                step="0.0001"
                value={l.qty}
                onChange={(e) => setLine(i, { qty: e.target.value })}
                className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
              />
            </label>
            <label className="block text-sm">
              {vi.finance.unitPrice}
              <input
                type="number"
                inputMode="decimal"
                min="0"
                step="0.01"
                value={l.unitPrice}
                onChange={(e) => setLine(i, { unitPrice: e.target.value })}
                className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
              />
            </label>
            {lines.length > 1 ? (
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="mt-5"
                onClick={() =>
                  setLines((prev) => prev.filter((_, j) => j !== i))
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
        onClick={() =>
          setLines((prev) => [
            ...prev,
            { itemDesc: "", qty: "", unitPrice: "" },
          ])
        }
      >
        + {vi.finance.itemDesc}
      </Button>
      <p className="mt-3 text-right text-sm">
        {vi.finance.totalAmount}:{" "}
        <MoneyText amount={total} className="font-semibold" />
      </p>
      <Button
        type="button"
        className="mt-3"
        disabled={!canSubmit}
        onClick={handleSubmit}
      >
        {pending ? vi.common.loading : vi.common.save}
      </Button>
      {error ? (
        <p className="mt-3 text-sm font-medium text-red-800">{error}</p>
      ) : null}
    </div>
  );
}
