"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { saveBanquetHallAction } from "@/features/restaurant/actions";
import type { BanquetHallRow } from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

/**
 * Quản lý danh mục sảnh (C11, Q170b): tạo / sửa sảnh + bảng danh sách.
 * Sảnh dùng khi đặt tiệc (chọn trong form tiệc); tên trùng (không phân
 * biệt hoa/thường) với sảnh đang dùng thì RPC chặn.
 */
export function HallManager({
  propertyId,
  halls,
  canManage,
}: {
  propertyId: string;
  halls: BanquetHallRow[];
  canManage: boolean;
}) {
  const router = useRouter();
  const [editingId, setEditingId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [capacity, setCapacity] = useState("");
  const [isActive, setIsActive] = useState(true);
  const [notes, setNotes] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  function startCreate() {
    setEditingId(null);
    setName("");
    setCapacity("");
    setIsActive(true);
    setNotes("");
    setError(null);
    setDone(null);
  }

  function startEdit(hall: BanquetHallRow) {
    setEditingId(hall.id);
    setName(hall.name);
    setCapacity(hall.capacity !== null ? String(hall.capacity) : "");
    setIsActive(hall.is_active);
    setNotes(hall.notes ?? "");
    setError(null);
    setDone(null);
  }

  const canSubmit =
    !pending &&
    name.trim() !== "" &&
    (capacity === "" ||
      (Number(capacity) > 0 && Number.isInteger(Number(capacity))));

  async function handleSubmit() {
    setPending(true);
    setError(null);
    setDone(null);
    const res = await saveBanquetHallAction({
      propertyId,
      id: editingId ?? undefined,
      name: name.trim(),
      capacity: capacity === "" ? undefined : Number(capacity),
      isActive,
      notes: notes.trim() || undefined,
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setDone(vi.restaurant.hallSaved);
    startCreate();
    router.refresh();
  }

  return (
    <div className="space-y-6">
      {canManage ? (
        <div className="space-y-4 rounded-lg border p-4">
          <h2 className="text-sm font-semibold">
            {editingId ? vi.restaurant.editHall : vi.restaurant.newHall}
          </h2>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="space-y-1 text-sm">
              <span className="block font-medium">
                {vi.restaurant.hallName} *
              </span>
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Sảnh A"
                className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
              />
            </label>
            <label className="space-y-1 text-sm">
              <span className="block font-medium">
                {vi.restaurant.hallCapacity}
              </span>
              <input
                type="number"
                min={1}
                step={1}
                value={capacity}
                onChange={(e) => setCapacity(e.target.value)}
                className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
              />
            </label>
          </div>
          <label className="block space-y-1 text-sm">
            <span className="block font-medium">{vi.restaurant.notes}</span>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={2}
              className="w-full rounded-lg border border-border bg-background px-2.5 py-2"
            />
          </label>
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
              className="size-4"
            />
            {vi.restaurant.hallActive}
          </label>
          {error ? <p className="text-sm text-destructive">{error}</p> : null}
          {done ? <p className="text-sm text-green-700">{done}</p> : null}
          <div className="flex gap-2">
            <Button type="button" disabled={!canSubmit} onClick={handleSubmit}>
              {vi.restaurant.save}
            </Button>
            {editingId ? (
              <Button type="button" variant="outline" onClick={startCreate}>
                {vi.restaurant.cancel}
              </Button>
            ) : null}
          </div>
        </div>
      ) : null}

      {halls.length === 0 ? (
        <p className="text-sm text-muted-foreground">{vi.restaurant.noHalls}</p>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50 text-left">
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.hallName}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.hallCapacity}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.hallActive}
                </th>
                <th className="px-3 py-2 font-medium">{vi.restaurant.notes}</th>
                {canManage ? (
                  <th className="px-3 py-2 font-medium">{vi.common.actions}</th>
                ) : null}
              </tr>
            </thead>
            <tbody>
              {halls.map((h) => (
                <tr key={h.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium">{h.name}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {h.capacity ?? "—"}
                  </td>
                  <td className="px-3 py-2">
                    {h.is_active
                      ? vi.restaurant.active
                      : vi.restaurant.inactive}
                  </td>
                  <td className="px-3 py-2">{h.notes ?? "—"}</td>
                  {canManage ? (
                    <td className="px-3 py-2">
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={() => startEdit(h)}
                      >
                        {vi.restaurant.editHall}
                      </Button>
                    </td>
                  ) : null}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
