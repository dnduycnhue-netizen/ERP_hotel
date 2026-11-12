"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import type { RoomRow } from "@/features/master/queries";
import { refillAction } from "@/features/minibar/actions";
import type { MinibarItemRow } from "@/features/minibar/queries";
import { vi } from "@/i18n/vi";

/**
 * Bổ sung minibar hàng loạt theo tầng (T-035).
 * Chọn tầng + món + số lượng → bổ sung cùng số lượng cho mọi phòng
 * của tầng (mỗi phòng 1 lần gọi `minibar_refill`, báo kết quả từng
 * phòng). Bổ sung là chuyển kho minibar tổng → kho phòng, không phải
 * bán nên không đổi tổng tồn (xem Q54).
 */
export function OfficeRefillForm({
  propertyId,
  rooms,
  items,
}: {
  propertyId: string;
  rooms: RoomRow[];
  items: MinibarItemRow[];
}) {
  const router = useRouter();
  const floors = useMemo(() => {
    const set = new Set<string>();
    for (const r of rooms) {
      if (r.floor) set.add(r.floor);
    }
    return [...set].sort((a, b) => a.localeCompare(b));
  }, [rooms]);
  const [floor, setFloor] = useState("");
  const [itemId, setItemId] = useState("");
  const [qty, setQty] = useState("");
  const [pending, setPending] = useState(false);
  const [results, setResults] = useState<
    Array<{ roomNo: string; ok: boolean; message: string }>
  >([]);

  const floorRooms = rooms.filter((r) => r.floor === floor);
  const qtyNum = Number(qty);
  const canSubmit =
    !pending &&
    floor !== "" &&
    itemId !== "" &&
    Number.isFinite(qtyNum) &&
    qtyNum > 0 &&
    floorRooms.length > 0;

  async function handleSubmit() {
    setPending(true);
    setResults([]);
    const out: Array<{ roomNo: string; ok: boolean; message: string }> = [];
    for (const room of floorRooms) {
      const res = await refillAction({
        propertyId,
        roomId: room.id,
        lines: [{ itemId, qty: qtyNum }],
      });
      out.push({
        roomNo: room.room_no,
        ok: res.ok,
        message: res.ok ? vi.minibar.refillSuccess : res.error,
      });
    }
    setResults(out);
    setPending(false);
    router.refresh();
  }

  return (
    <div className="rounded-lg border bg-card p-4">
      <h2 className="font-medium">{vi.minibar.refillByFloor}</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        {vi.minibar.refillHint}
      </p>
      <div className="mt-3 grid gap-3 sm:grid-cols-3">
        <label className="block text-sm">
          {vi.minibar.floor}
          <select
            value={floor}
            onChange={(e) => setFloor(e.target.value)}
            className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <option value="">{vi.common.all}</option>
            {floors.map((f) => (
              <option key={f} value={f}>
                {vi.minibar.floor} {f} (
                {rooms.filter((r) => r.floor === f).length}{" "}
                {vi.minibar.roomNo.toLowerCase()})
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm">
          {vi.minibar.itemName}
          <select
            value={itemId}
            onChange={(e) => setItemId(e.target.value)}
            className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
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
          {vi.minibar.qty}
          <input
            type="number"
            inputMode="decimal"
            min="0"
            step="0.01"
            value={qty}
            onChange={(e) => setQty(e.target.value)}
            className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
      </div>
      <Button
        type="button"
        className="mt-3"
        disabled={!canSubmit}
        onClick={handleSubmit}
      >
        {pending ? vi.minibar.refilling : vi.minibar.refillButton}
      </Button>
      {results.length > 0 ? (
        <ul className="mt-3 space-y-1 text-sm">
          {results.map((r) => (
            <li
              key={r.roomNo}
              className={r.ok ? "text-green-800" : "text-red-800"}
            >
              {vi.minibar.roomNo} {r.roomNo}: {r.message}
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}
