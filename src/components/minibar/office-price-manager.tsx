"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import { priceSetAction } from "@/features/minibar/actions";
import type {
  MinibarItemRow,
  MinibarPriceRow,
} from "@/features/minibar/queries";
import { vi } from "@/i18n/vi";

/**
 * Bảng giá minibar — văn phòng (T-035).
 * Xem giá theo mốc hiệu lực + đặt giá mới (upsert theo mốc
 * `valid_from`). Giá dùng để tính tiền lúc buồng phòng kiểm — món
 * chưa có giá sẽ lỗi `ERR_PRICE_NOT_SET` khi kiểm.
 */
export function OfficePriceManager({
  propertyId,
  items,
  prices,
}: {
  propertyId: string;
  items: MinibarItemRow[];
  prices: MinibarPriceRow[];
}) {
  const router = useRouter();
  const today = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
  const [itemId, setItemId] = useState("");
  const [price, setPrice] = useState("");
  const [validFrom, setValidFrom] = useState(today);
  const [validTo, setValidTo] = useState("");
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const priceNum = Number(price);
  const canSubmit =
    !pending &&
    itemId !== "" &&
    Number.isFinite(priceNum) &&
    priceNum > 0 &&
    validFrom !== "";

  async function handleSubmit() {
    setPending(true);
    setMessage(null);
    setError(null);
    const res = await priceSetAction({
      propertyId,
      itemId,
      price: priceNum,
      validFrom,
      validTo: validTo === "" ? null : validTo,
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setMessage(vi.minibar.priceSetSuccess);
    router.refresh();
  }

  return (
    <div className="rounded-lg border bg-card p-4">
      <h2 className="font-medium">{vi.minibar.priceListTitle}</h2>
      {message ? (
        <p className="mt-3 rounded-md border border-green-200 bg-green-50 px-3 py-2 text-sm text-green-800">
          {message}
        </p>
      ) : null}
      {error ? (
        <p className="mt-3 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
          {error}
        </p>
      ) : null}
      <div className="mt-3 grid gap-3 sm:grid-cols-4">
        <label className="block text-sm">
          {vi.minibar.itemName}
          <select
            value={itemId}
            onChange={(e) => setItemId(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          >
            <option value="">{vi.minibar.selectItem}</option>
            {items.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name} ({item.code})
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm">
          {vi.minibar.price}
          <input
            type="number"
            inputMode="decimal"
            min="0"
            step="1000"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.minibar.validFrom}
          <input
            type="date"
            value={validFrom}
            onChange={(e) => setValidFrom(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.minibar.validTo}
          <input
            type="date"
            value={validTo}
            onChange={(e) => setValidTo(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
      </div>
      <Button
        type="button"
        className="mt-3"
        disabled={!canSubmit}
        onClick={handleSubmit}
      >
        {pending ? vi.minibar.priceSetting : vi.minibar.priceSetButton}
      </Button>

      {prices.length === 0 ? (
        <p className="mt-4 text-sm text-muted-foreground">
          {vi.minibar.priceEmpty}
        </p>
      ) : (
        <table className="mt-4 w-full text-sm">
          <thead className="bg-muted/40 text-left">
            <tr>
              <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                {vi.minibar.itemName}
              </th>
              <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                {vi.minibar.price}
              </th>
              <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                {vi.minibar.validFrom}
              </th>
              <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                {vi.minibar.validTo}
              </th>
            </tr>
          </thead>
          <tbody>
            {prices.map((row) => (
              <tr key={row.id} className="border-t hover:bg-muted/40">
                <td className="py-3 pr-3 align-middle">
                  {row.item_name ?? vi.minibar.itemNameHidden}
                  {row.item_code ? (
                    <span className="block text-xs text-muted-foreground">
                      {row.item_code}
                    </span>
                  ) : null}
                </td>
                <td className="py-3 pr-3 text-right align-middle">
                  <MoneyText amount={row.price} />
                </td>
                <td className="py-3 pr-3 align-middle">{row.valid_from}</td>
                <td className="py-3 pr-3 align-middle">
                  {row.valid_to ?? vi.common.noData}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
