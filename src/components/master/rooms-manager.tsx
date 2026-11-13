"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import { BulkImportDialog } from "@/components/master/bulk-import-dialog";
import { useCan } from "@/lib/permissions/permissions-provider";
import type { BulkRow } from "@/lib/master/bulk-import";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import type { RoomRow, RoomTypeRow } from "@/features/master/queries";
import {
  saveRoomAction,
  deleteRoomAction,
  saveRoomTypeAction,
} from "@/features/master/actions";

export function RoomsManager({
  propertyId,
  rooms,
  roomTypes,
}: {
  propertyId: string;
  rooms: RoomRow[];
  roomTypes: RoomTypeRow[];
}) {
  const router = useRouter();
  const canManage = useCan("room.manage");

  const [roomOpen, setRoomOpen] = useState(false);
  const [editingRoom, setEditingRoom] = useState<RoomRow | null>(null);
  const [roomNo, setRoomNo] = useState("");
  const [floor, setFloor] = useState("");
  const [roomTypeId, setRoomTypeId] = useState(roomTypes[0]?.id || "");

  const [typeOpen, setTypeOpen] = useState(false);
  const [typeCode, setTypeCode] = useState("");
  const [typeName, setTypeName] = useState("");
  const [maxGuests, setMaxGuests] = useState("2");

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [bulkKind, setBulkKind] = useState<"rooms" | "room_types" | null>(
    null,
  );

  function startCreateRoom() {
    setEditingRoom(null);
    setRoomNo("");
    setFloor("");
    setRoomTypeId(roomTypes[0]?.id || "");
    setError(null);
    setRoomOpen(true);
  }

  function startEditRoom(r: RoomRow) {
    setEditingRoom(r);
    setRoomNo(r.room_no);
    setFloor(r.floor || "");
    setRoomTypeId(r.room_type_id);
    setError(null);
    setRoomOpen(true);
  }

  async function handleSaveRoom(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await saveRoomAction({
      id: editingRoom?.id,
      propertyId,
      roomNo,
      floor: floor || null,
      roomTypeId,
    });

    setSaving(false);
    if (res.ok) {
      setRoomOpen(false);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDeleteRoom(r: RoomRow) {
    if (!confirm(vi.master.rooms.deleteConfirm)) return;
    setError(null);
    const res = await deleteRoomAction(propertyId, r.id);
    if (res.ok) {
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleSaveType(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await saveRoomTypeAction({
      propertyId,
      code: typeCode,
      name: typeName,
      maxGuests: maxGuests ? Number(maxGuests) : null,
    });

    setSaving(false);
    if (res.ok) {
      setTypeOpen(false);
      setTypeCode("");
      setTypeName("");
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const columns: DataTableColumn<RoomRow>[] = [
    {
      key: "room_no",
      header: vi.master.rooms.roomNo,
      cell: (row) => (
        <span className="font-mono font-bold text-xs">{row.room_no}</span>
      ),
    },
    {
      key: "floor",
      header: vi.master.rooms.floor,
      cell: (row) => (row.floor ? vi.master.rooms.floorLabel.replace("{floor}", String(row.floor)) : "—"),
    },
    {
      key: "room_type",
      header: vi.master.rooms.roomType,
      cell: (row) => row.room_type_name || "—",
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
              className="text-xs h-7 px-2"
              onClick={() => startEditRoom(row)}
            >
              {vi.master.rooms.editRoom}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
              onClick={() => handleDeleteRoom(row)}
            >
              {vi.master.rooms.deleteRoom}
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
        title={vi.master.rooms.title}
        description={vi.master.rooms.description}
        actions={
          canManage ? (
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setBulkKind("room_types")}
              >
                {vi.master.rooms.bulkImportRoomTypes}
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setBulkKind("rooms")}
              >
                {vi.master.rooms.bulkImportRooms}
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setTypeOpen(true)}
              >
                + {vi.master.rooms.addRoomType}
              </Button>
              <Button
                size="sm"
                onClick={startCreateRoom}
                disabled={roomTypes.length === 0}
              >
                + {vi.master.rooms.addRoom}
              </Button>
            </div>
          ) : null
        }
      />

      <DataTable columns={columns} rows={rooms} />

      {bulkKind ? (
        <BulkImportDialog
          kind={bulkKind}
          lookups={
            bulkKind === "rooms"
              ? {
                  roomTypes: roomTypes.map((rt) => ({
                    code: rt.code,
                    id: rt.id,
                  })),
                  existingRoomNos: rooms.map((r) => r.room_no),
                }
              : {
                  existingRoomTypeCodes: roomTypes.map((rt) => rt.code),
                }
          }
          saveRow={async (row: BulkRow) => {
            const res =
              bulkKind === "rooms"
                ? await saveRoomAction({
                    propertyId,
                    roomNo: row.values.room_no,
                    floor: row.values.floor || null,
                    roomTypeId: String(row.resolved.roomTypeId),
                  })
                : await saveRoomTypeAction({
                    propertyId,
                    code: row.values.code,
                    name: row.values.name,
                    maxGuests:
                      typeof row.resolved.maxGuests === "number"
                        ? row.resolved.maxGuests
                        : null,
                  });
            return res.ok ? { ok: true } : { ok: false, error: res.error };
          }}
          onClose={() => setBulkKind(null)}
          onDone={() => {
            setBulkKind(null);
            router.refresh();
          }}
        />
      ) : null}

      {/* Dialog thêm phòng */}
      {roomOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-sm rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editingRoom
                  ? vi.master.rooms.editRoom
                  : vi.master.rooms.addRoom}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setRoomOpen(false)}
              >
                ✕
              </Button>
            </div>

            <form onSubmit={handleSaveRoom} className="mt-4 space-y-3">
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="roomNo"
                >
                  {vi.master.rooms.roomNo} *
                </label>
                <input
                  id="roomNo"
                  required
                  value={roomNo}
                  onChange={(e) => setRoomNo(e.target.value)}
                  placeholder={`${vi.common.examplePrefix} 101, 201, 305`}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="floor"
                >
                  {vi.master.rooms.floor}
                </label>
                <input
                  id="floor"
                  value={floor}
                  onChange={(e) => setFloor(e.target.value)}
                  placeholder={`${vi.common.examplePrefix} 1, 2, 3`}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="roomType"
                >
                  {vi.master.rooms.roomType} *
                </label>
                <select
                  id="roomType"
                  required
                  value={roomTypeId}
                  onChange={(e) => setRoomTypeId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  {roomTypes.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.code} - {t.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setRoomOpen(false)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={saving}>
                  {saving ? vi.common.loading : vi.common.save}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {/* Dialog thêm loại phòng */}
      {typeOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-sm rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">{vi.master.rooms.addRoomType}</h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setTypeOpen(false)}
              >
                ✕
              </Button>
            </div>

            <form onSubmit={handleSaveType} className="mt-4 space-y-3">
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="typeCode"
                >
                  {vi.master.roomTypes.codeLabel}
                </label>
                <input
                  id="typeCode"
                  required
                  value={typeCode}
                  onChange={(e) => setTypeCode(e.target.value)}
                  placeholder={`${vi.common.examplePrefix} STD, DLX, SUI`}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm font-mono"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="typeName"
                >
                  {vi.master.roomTypes.nameLabel}
                </label>
                <input
                  id="typeName"
                  required
                  value={typeName}
                  onChange={(e) => setTypeName(e.target.value)}
                  placeholder={`${vi.common.examplePrefix} Standard, Deluxe, Suite`}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="maxGuests"
                >
                  {vi.master.rooms.maxGuests}
                </label>
                <input
                  id="maxGuests"
                  type="number"
                  min="1"
                  value={maxGuests}
                  onChange={(e) => setMaxGuests(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setTypeOpen(false)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={saving}>
                  {saving ? vi.common.loading : vi.common.save}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  );
}
