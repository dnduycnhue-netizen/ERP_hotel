"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/common/empty-state";
import { MoneyText } from "@/components/common/money-text";
import type { RoomRow } from "@/features/master/queries";
import {
  requestCheckAction,
  type RequestCheckResult,
} from "@/features/minibar/actions";
import type {
  MinibarCheckRow,
  MinibarCheckStatus,
} from "@/features/minibar/queries";
import { vi } from "@/i18n/vi";

function statusLabel(status: MinibarCheckStatus): string {
  switch (status) {
    case "pending_charge":
      return vi.minibar.statuses.pendingCharge;
    case "charged":
      return vi.minibar.statuses.charged;
    case "waived":
      return vi.minibar.statuses.waived;
    case "late_charge":
      return vi.minibar.statuses.lateCharge;
    case "written_off":
      return vi.minibar.statuses.writtenOff;
  }
}

function triggerLabel(trigger: MinibarCheckRow["trigger"]): string {
  switch (trigger) {
    case "checkout":
      return vi.minibar.triggers.checkout;
    case "daily":
      return vi.minibar.triggers.daily;
    case "audit":
      return vi.minibar.triggers.audit;
  }
}

/**
 * Màn lễ tân — danh sách phòng + phiếu kiểm đang mở (T-035).
 * Lễ tân bấm "Yêu cầu kiểm" khi khách trả phòng; phòng đã có phiếu
 * đang mở thì hiện cảnh báo thay vì tạo phiếu mới (1 phiếu mở/phòng —
 * Q55). Phiếu đã kiểm xong hiện tổng tiền để lễ tân thu.
 */
export function FrontdeskCheckList({
  propertyId,
  rooms,
  openChecks,
  doneToday,
  canRequestCheck,
}: {
  propertyId: string;
  rooms: RoomRow[];
  openChecks: MinibarCheckRow[];
  doneToday: MinibarCheckRow[];
  canRequestCheck: boolean;
}) {
  const router = useRouter();
  const [requestingRoomId, setRequestingRoomId] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  /** Loại kiểm đã chọn cho từng phòng (mặc định trả phòng — C7). */
  const [triggerByRoom, setTriggerByRoom] = useState<
    Record<string, MinibarCheckRow["trigger"]>
  >({});

  const openByRoom = new Map(openChecks.map((c) => [c.room_id, c]));

  async function handleRequest(roomId: string) {
    setRequestingRoomId(roomId);
    setMessage(null);
    setError(null);
    const res = await requestCheckAction({
      propertyId,
      roomId,
      trigger: triggerByRoom[roomId] ?? "checkout",
    });
    setRequestingRoomId(null);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    const data: RequestCheckResult = res.data;
    setMessage(
      data.existing ? vi.minibar.requestExisting : vi.minibar.requestSuccess,
    );
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-8">
      {openChecks.length > 0 ? (
        <p className="flex items-start gap-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <span>
            {vi.minibar.pendingHandoverWarning}{" "}
            {openChecks.map((c) => c.room_no).join(", ")}
          </span>
        </p>
      ) : null}
      <section className="space-y-3">
        <h2 className="text-lg font-semibold">{vi.minibar.roomsTitle}</h2>
        {message ? (
          <p className="rounded-md border border-green-200 bg-green-50 px-3 py-2 text-sm text-green-800">
            {message}
          </p>
        ) : null}
        {error ? (
          <p className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
            {error}
          </p>
        ) : null}
        {rooms.length === 0 ? (
          <EmptyState title={vi.minibar.roomsEmpty} />
        ) : (
          <ul className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {rooms.map((room) => {
              const open = openByRoom.get(room.id);
              return (
                <li key={room.id} className="rounded-lg border bg-card p-4">
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-medium">
                      {vi.minibar.roomNo} {room.room_no}
                    </span>
                    <span className="text-sm text-muted-foreground">
                      {room.floor ? `${vi.minibar.floor} ${room.floor}` : ""}
                      {room.room_type_name ? ` · ${room.room_type_name}` : ""}
                    </span>
                  </div>
                  {open ? (
                    <div className="mt-3 space-y-2">
                      <p className="flex items-start gap-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
                        <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
                        <span>{vi.minibar.openCheckWarning}</span>
                      </p>
                      <Link
                        href={`/${propertyId}/frontdesk/minibar/${open.id}`}
                        className="text-sm font-medium text-primary underline"
                      >
                        {open.doc_no} — {statusLabel(open.status)}
                        {open.checked_by ? (
                          <>
                            {" · "}
                            <MoneyText amount={open.total_amount} />
                          </>
                        ) : (
                          ""
                        )}
                      </Link>
                    </div>
                  ) : canRequestCheck ? (
                    <div className="mt-3 flex flex-wrap items-center gap-2">
                      <select
                        aria-label={vi.minibar.trigger}
                        value={triggerByRoom[room.id] ?? "checkout"}
                        onChange={(e) =>
                          setTriggerByRoom((prev) => ({
                            ...prev,
                            [room.id]: e.target
                              .value as MinibarCheckRow["trigger"],
                          }))
                        }
                        className="h-9 rounded-md border bg-background px-2 text-sm"
                      >
                        <option value="checkout">
                          {vi.minibar.triggers.checkout}
                        </option>
                        <option value="daily">
                          {vi.minibar.triggers.daily}
                        </option>
                        <option value="audit">
                          {vi.minibar.triggers.audit}
                        </option>
                      </select>
                      <Button
                        type="button"
                        size="sm"
                        disabled={requestingRoomId === room.id}
                        onClick={() => handleRequest(room.id)}
                      >
                        {requestingRoomId === room.id
                          ? vi.minibar.requesting
                          : vi.minibar.requestCheckButton}
                      </Button>
                    </div>
                  ) : null}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">{vi.minibar.checksTitle}</h2>
        {openChecks.length === 0 ? (
          <EmptyState title={vi.minibar.checksEmpty} />
        ) : (
          <ul className="flex flex-col gap-2">
            {openChecks.map((check) => (
              <li key={check.id}>
                <Link
                  href={`/${propertyId}/frontdesk/minibar/${check.id}`}
                  className="flex flex-wrap items-center justify-between gap-2 rounded-lg border bg-card p-4 hover:bg-muted/50"
                >
                  <span>
                    <span className="block font-medium">
                      {vi.minibar.roomNo} {check.room_no} · {check.doc_no}
                    </span>
                    <span className="block text-sm text-muted-foreground">
                      {triggerLabel(check.trigger)} ·{" "}
                      {statusLabel(check.status)}
                      {check.is_loss ? ` · ${vi.minibar.isLoss}` : ""}
                    </span>
                  </span>
                  <span className="font-medium">
                    <MoneyText amount={check.total_amount} />
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>

      {doneToday.length > 0 ? (
        <section className="space-y-3">
          <h2 className="text-lg font-semibold">
            {vi.minibar.statuses.charged} / {vi.minibar.statuses.waived} /{" "}
            {vi.minibar.statuses.lateCharge} — {vi.common.today}
          </h2>
          <ul className="flex flex-col gap-2">
            {doneToday.map((check) => (
              <li key={check.id}>
                <Link
                  href={`/${propertyId}/frontdesk/minibar/${check.id}`}
                  className="flex flex-wrap items-center justify-between gap-2 rounded-lg border bg-card p-4 hover:bg-muted/50"
                >
                  <span>
                    <span className="block font-medium">
                      {vi.minibar.roomNo} {check.room_no} · {check.doc_no}
                    </span>
                    <span className="block text-sm text-muted-foreground">
                      {statusLabel(check.status)}
                      {check.folio_no
                        ? ` · ${vi.minibar.folioNo} ${check.folio_no}`
                        : ""}
                    </span>
                  </span>
                  <span className="font-medium">
                    <MoneyText amount={check.total_amount} />
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </div>
  );
}
