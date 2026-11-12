"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import type { RoomTypeRow } from "@/features/master/queries";
import {
  deleteStandardAction,
  saveStandardAction,
} from "@/features/housekeeping/actions";
import type {
  RoomSetupStandardRow,
  StandardItemRow,
} from "@/features/housekeeping/queries";
import type { RoomCleanType } from "@/features/housekeeping/schemas";

const CLEAN_TYPES: RoomCleanType[] = ["checkout", "stayover", "vip", "child"];

function cleanTypeLabel(cleanType: RoomCleanType): string {
  return vi.housekeeping.cleanTypes[cleanType];
}

/**
 * Quản lý tiêu chuẩn setup phòng (C7): thêm/sửa/xóa/xem định mức vật
 * tư theo loại phòng × loại dọn (bảng `room_setup_standards`, 310000).
 * Ghi qua RPC `room_setup_standard_set` (upsert, có sẵn) /
 * `room_setup_standard_delete` (mới, C7) — bảng chỉ có RLS SELECT-only
 * nên không ghi trực tiếp được.
 *
 * Sửa: chỉ sửa được số lượng + cờ theo khách. Đổi khóa (loại phòng /
 * loại dọn / món hàng / theo khách) = upsert 1 dòng mới theo unique
 * (room_type_id, clean_type, item_id, per_guest), nên phải xóa dòng cũ
 * rồi tạo mới — form khóa các ô chọn khi sửa và ghi chú rõ.
 */
export function StandardsManager({
  propertyId,
  standards,
  roomTypes,
  items,
  canManage,
}: {
  propertyId: string;
  standards: RoomSetupStandardRow[];
  roomTypes: RoomTypeRow[];
  items: StandardItemRow[];
  canManage: boolean;
}) {
  const router = useRouter();

  const [filterRoomType, setFilterRoomType] = useState("");
  const [filterCleanType, setFilterCleanType] = useState("");

  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<RoomSetupStandardRow | null>(null);
  const [roomTypeId, setRoomTypeId] = useState(roomTypes[0]?.id ?? "");
  const [cleanType, setCleanType] = useState<RoomCleanType>("checkout");
  const [itemId, setItemId] = useState(items[0]?.id ?? "");
  const [qty, setQty] = useState("1");
  const [perGuest, setPerGuest] = useState(false);

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const filtered = useMemo(
    () =>
      standards.filter(
        (s) =>
          (filterRoomType === "" || s.room_type_id === filterRoomType) &&
          (filterCleanType === "" || s.clean_type === filterCleanType),
      ),
    [standards, filterRoomType, filterCleanType],
  );

  function startCreate() {
    setEditing(null);
    setRoomTypeId(roomTypes[0]?.id ?? "");
    setCleanType("checkout");
    setItemId(items[0]?.id ?? "");
    setQty("1");
    setPerGuest(false);
    setError(null);
    setFormOpen(true);
  }

  function startEdit(row: RoomSetupStandardRow) {
    setEditing(row);
    setRoomTypeId(row.room_type_id);
    setCleanType(row.clean_type);
    setItemId(row.item_id);
    setQty(String(row.qty));
    setPerGuest(row.per_guest);
    setError(null);
    setFormOpen(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await saveStandardAction({
      propertyId,
      roomTypeId,
      cleanType,
      itemId,
      qty: Number(qty),
      perGuest,
    });

    setSaving(false);
    if (res.ok) {
      setFormOpen(false);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDelete(row: RoomSetupStandardRow) {
    if (!confirm(vi.housekeeping.deleteConfirm)) return;
    setError(null);
    const res = await deleteStandardAction({
      propertyId,
      standardId: row.id,
    });
    if (res.ok) {
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const columns: DataTableColumn<RoomSetupStandardRow>[] = [
    {
      key: "room_type",
      header: vi.housekeeping.roomType,
      cell: (row) =>
        row.room_type_name ?? row.room_type_code ?? row.room_type_id,
    },
    {
      key: "clean_type",
      header: vi.housekeeping.cleanType,
      cell: (row) => cleanTypeLabel(row.clean_type),
    },
    {
      key: "item_code",
      header: vi.minibar.itemCode,
      cell: (row) => row.item_code ?? "—",
    },
    {
      key: "item_name",
      header: vi.minibar.itemName,
      cell: (row) => row.item_name ?? "—",
    },
    {
      key: "qty",
      header: vi.housekeeping.qty,
      align: "right",
      cell: (row) => `${row.qty}${row.stock_uom ? ` ${row.stock_uom}` : ""}`,
    },
    {
      key: "per_guest",
      header: vi.housekeeping.perGuest,
      align: "center",
      cell: (row) => (row.per_guest ? "✓" : "—"),
    },
    {
      key: "actions",
      header: vi.common.actions,
      align: "right",
      cell: (row) =>
        canManage ? (
          <div className="flex items-center justify-end gap-1">
            <Button
              variant="outline"
              size="sm"
              className="h-7 px-2 text-xs"
              onClick={() => startEdit(row)}
            >
              {vi.housekeeping.editStandard}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="h-7 px-2 text-xs text-destructive hover:bg-destructive/10"
              onClick={() => handleDelete(row)}
            >
              {vi.common.remove}
            </Button>
          </div>
        ) : null,
    },
  ];

  return (
    <div className="space-y-4">
      {error ? (
        <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}

      <PageHeader
        title={vi.housekeeping.standardsTitle}
        description={vi.housekeeping.standardsDescription}
        actions={
          canManage ? (
            <Button
              size="sm"
              onClick={startCreate}
              disabled={roomTypes.length === 0 || items.length === 0}
            >
              + {vi.housekeeping.addStandard}
            </Button>
          ) : null
        }
      />

      <div className="flex flex-wrap items-end gap-3">
        <div>
          <label
            className="text-xs font-medium text-muted-foreground"
            htmlFor="filterRoomType"
          >
            {vi.housekeeping.roomType}
          </label>
          <select
            id="filterRoomType"
            value={filterRoomType}
            onChange={(e) => setFilterRoomType(e.target.value)}
            className="mt-1 h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <option value="">{vi.housekeeping.allRoomTypes}</option>
            {roomTypes.map((rt) => (
              <option key={rt.id} value={rt.id}>
                {rt.name} ({rt.code})
              </option>
            ))}
          </select>
        </div>
        <div>
          <label
            className="text-xs font-medium text-muted-foreground"
            htmlFor="filterCleanType"
          >
            {vi.housekeeping.cleanType}
          </label>
          <select
            id="filterCleanType"
            value={filterCleanType}
            onChange={(e) => setFilterCleanType(e.target.value)}
            className="mt-1 h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <option value="">{vi.housekeeping.allCleanTypes}</option>
            {CLEAN_TYPES.map((ct) => (
              <option key={ct} value={ct}>
                {cleanTypeLabel(ct)}
              </option>
            ))}
          </select>
        </div>
      </div>

      <DataTable
        columns={columns}
        rows={filtered}
        emptyTitle={vi.housekeeping.standardsEmpty}
      />

      {formOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-sm rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editing
                  ? vi.housekeeping.editStandard
                  : vi.housekeeping.addStandard}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setFormOpen(false)}
              >
                ✕
              </Button>
            </div>

            <form onSubmit={handleSave} className="mt-4 space-y-3">
              {editing ? (
                <p className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
                  {vi.housekeeping.editKeyHint}
                </p>
              ) : null}

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="roomTypeId"
                >
                  {vi.housekeeping.roomType} *
                </label>
                <select
                  id="roomTypeId"
                  required
                  disabled={editing !== null}
                  value={roomTypeId}
                  onChange={(e) => setRoomTypeId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm disabled:opacity-60"
                >
                  {roomTypes.map((rt) => (
                    <option key={rt.id} value={rt.id}>
                      {rt.name} ({rt.code})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="cleanType"
                >
                  {vi.housekeeping.cleanType} *
                </label>
                <select
                  id="cleanType"
                  required
                  disabled={editing !== null}
                  value={cleanType}
                  onChange={(e) =>
                    setCleanType(e.target.value as RoomCleanType)
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm disabled:opacity-60"
                >
                  {CLEAN_TYPES.map((ct) => (
                    <option key={ct} value={ct}>
                      {cleanTypeLabel(ct)}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="itemId"
                >
                  {vi.housekeeping.item} *
                </label>
                <select
                  id="itemId"
                  required
                  disabled={editing !== null}
                  value={itemId}
                  onChange={(e) => setItemId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm disabled:opacity-60"
                >
                  {items.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.code} — {item.name} ({item.stock_uom})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="qty"
                >
                  {vi.housekeeping.qty} *
                </label>
                <input
                  id="qty"
                  required
                  type="number"
                  min="0"
                  step="0.0001"
                  value={qty}
                  onChange={(e) => setQty(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div className="flex items-start gap-2">
                <input
                  id="perGuest"
                  type="checkbox"
                  disabled={editing !== null}
                  checked={perGuest}
                  onChange={(e) => setPerGuest(e.target.checked)}
                  className="mt-1"
                />
                <label
                  className="text-sm text-muted-foreground"
                  htmlFor="perGuest"
                >
                  {vi.housekeeping.perGuest} — {vi.housekeeping.perGuestHint}
                </label>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => setFormOpen(false)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" size="sm" disabled={saving}>
                  {saving ? vi.housekeeping.saving : vi.common.save}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  );
}
