"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import {
  confirmChargeAction,
  decideWaiveAction,
  markLateChargeAction,
  requestWaiveAction,
  writeOffAction,
} from "@/features/minibar/actions";
import type {
  MinibarCheckDetail,
  MinibarCheckStatus,
  MinibarPerms,
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

/**
 * Chi tiết phiếu kiểm minibar — lễ tân (T-035).
 * Xem kết quả kiểm (số thiếu + tiền theo bảng giá) rồi: Đã thu + folio,
 * Đề nghị miễn (chờ gm duyệt), chuyển thu muộn, hoặc xóa sổ (gm).
 * Tên hàng có thể trống khi tài khoản không có `item.view` (Q60) —
 * số thiếu/đơn giá/thành tiền vẫn hiện đầy đủ vì nằm trên dòng phiếu.
 */
export function FrontdeskCheckDetail({
  propertyId,
  detail,
  perms,
}: {
  propertyId: string;
  detail: MinibarCheckDetail;
  perms: MinibarPerms;
}) {
  const router = useRouter();
  const { check, lines } = detail;
  const [folioNo, setFolioNo] = useState("");
  const [waiveReason, setWaiveReason] = useState("");
  const [waiveNote, setWaiveNote] = useState("");
  const [lateNote, setLateNote] = useState("");
  const [writeOffReason, setWriteOffReason] = useState("");
  const [pending, setPending] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const isOpen =
    check.status === "pending_charge" || check.status === "late_charge";
  const isChecked = check.checked_by !== null;
  const waiveRequested = check.waive_requested_by !== null;

  async function run(
    key: string,
    fn: () => Promise<{ ok: boolean; error?: string }>,
    success: string,
  ) {
    setPending(key);
    setMessage(null);
    setError(null);
    const res = await fn();
    setPending(null);
    if (!res.ok) {
      setError(res.error ?? vi.errors.pageDescription);
      return;
    }
    setMessage(success);
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold">
          {vi.minibar.detailTitle} — {vi.minibar.roomNo} {check.room_no}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {check.doc_no} · {check.business_date} · {statusLabel(check.status)}
          {check.is_loss ? ` · ${vi.minibar.isLoss}` : ""}
        </p>
        {check.is_loss ? (
          <p className="mt-3 flex items-start gap-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
            <span>{vi.minibar.lossNote}</span>
          </p>
        ) : null}
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
      </div>

      <section className="rounded-xl border bg-card p-4">
        <h2 className="font-medium">{vi.minibar.checksTitle}</h2>
        {!isChecked ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.minibar.noLinesYet}
          </p>
        ) : lines.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.minibar.linesEmpty}
          </p>
        ) : (
          <table className="mt-3 w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="py-2 pr-2 font-medium">{vi.minibar.itemName}</th>
                <th className="py-2 pr-2 text-right font-medium">
                  {vi.minibar.missingQty}
                </th>
                <th className="py-2 pr-2 text-right font-medium">
                  {vi.minibar.unitPrice}
                </th>
                <th className="py-2 text-right font-medium">
                  {vi.minibar.amount}
                </th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line) => (
                <tr key={line.id} className="border-b last:border-0">
                  <td className="py-2 pr-2">
                    {line.item_name ?? vi.minibar.itemNameHidden}
                    {line.item_code ? (
                      <span className="block text-xs text-muted-foreground">
                        {line.item_code}
                      </span>
                    ) : null}
                    {line.near_expiry ? (
                      <span className="mt-1 inline-block rounded bg-amber-100 px-1.5 py-0.5 text-xs text-amber-900">
                        {vi.minibar.nearExpiry}
                      </span>
                    ) : null}
                  </td>
                  <td className="py-2 pr-2 text-right tabular-nums">
                    {formatNumber(line.missing_qty)} {line.stock_uom ?? ""}
                  </td>
                  <td className="py-2 pr-2 text-right">
                    <MoneyText amount={line.unit_price} />
                  </td>
                  <td className="py-2 text-right font-medium">
                    <MoneyText amount={line.amount} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <p className="mt-3 flex items-center justify-between border-t pt-3 font-semibold">
          <span>{vi.minibar.totalAmount}</span>
          <MoneyText amount={check.total_amount} />
        </p>
        {check.folio_no ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.minibar.folioNo}: {check.folio_no}
          </p>
        ) : null}
        {check.waive_reason ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.minibar.waiveReason}: {check.waive_reason}
          </p>
        ) : null}
      </section>

      {isOpen && isChecked ? (
        <section className="grid gap-4 md:grid-cols-2">
          {perms.canConfirmCharge ? (
            <div className="rounded-xl border bg-card p-4">
              <h2 className="font-medium">{vi.minibar.chargeButton}</h2>
              <label className="mt-3 block text-sm">
                {vi.minibar.folioNo}
                <input
                  type="text"
                  value={folioNo}
                  onChange={(e) => setFolioNo(e.target.value)}
                  placeholder={vi.minibar.folioPlaceholder}
                  className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
              </label>
              <Button
                type="button"
                className="mt-3"
                disabled={pending !== null || folioNo.trim() === ""}
                onClick={() =>
                  run(
                    "charge",
                    () =>
                      confirmChargeAction({
                        propertyId,
                        checkId: check.id,
                        folioNo: folioNo.trim(),
                      }),
                    vi.minibar.chargeSuccess,
                  )
                }
              >
                {pending === "charge"
                  ? vi.minibar.charging
                  : vi.minibar.chargeButton}
              </Button>
            </div>
          ) : null}

          {perms.canConfirmCharge ? (
            <div className="rounded-xl border bg-card p-4">
              <h2 className="font-medium">{vi.minibar.markLateButton}</h2>
              <label className="mt-3 block text-sm">
                {vi.minibar.lateNote}
                <input
                  type="text"
                  value={lateNote}
                  onChange={(e) => setLateNote(e.target.value)}
                  className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
              </label>
              <Button
                type="button"
                variant="outline"
                className="mt-3"
                disabled={pending !== null}
                onClick={() =>
                  run(
                    "late",
                    () =>
                      markLateChargeAction({
                        propertyId,
                        checkId: check.id,
                        note: lateNote.trim() === "" ? null : lateNote.trim(),
                      }),
                    vi.minibar.markLateSuccess,
                  )
                }
              >
                {pending === "late"
                  ? vi.minibar.markingLate
                  : vi.minibar.markLateButton}
              </Button>
            </div>
          ) : null}

          {perms.canWaiveRequest && !waiveRequested ? (
            <div className="rounded-xl border bg-card p-4">
              <h2 className="font-medium">{vi.minibar.waiveButton}</h2>
              <label className="mt-3 block text-sm">
                {vi.minibar.waiveReason}
                <input
                  type="text"
                  value={waiveReason}
                  onChange={(e) => setWaiveReason(e.target.value)}
                  className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
              </label>
              <Button
                type="button"
                variant="outline"
                className="mt-3"
                disabled={pending !== null || waiveReason.trim() === ""}
                onClick={() =>
                  run(
                    "waive-request",
                    () =>
                      requestWaiveAction({
                        propertyId,
                        checkId: check.id,
                        reason: waiveReason.trim(),
                      }),
                    vi.minibar.waiveRequestSuccess,
                  )
                }
              >
                {pending === "waive-request"
                  ? vi.minibar.waiving
                  : vi.minibar.waiveButton}
              </Button>
            </div>
          ) : null}

          {waiveRequested && perms.canWaiveApprove ? (
            <div className="rounded-xl border bg-card p-4">
              <h2 className="font-medium">{vi.minibar.waiveRequested}</h2>
              <p className="mt-2 text-sm text-muted-foreground">
                {vi.minibar.waiveReason}: {check.waive_reason}
              </p>
              <label className="mt-3 block text-sm">
                {vi.common.note}
                <input
                  type="text"
                  value={waiveNote}
                  onChange={(e) => setWaiveNote(e.target.value)}
                  className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
              </label>
              <div className="mt-3 flex gap-2">
                <Button
                  type="button"
                  disabled={pending !== null}
                  onClick={() =>
                    run(
                      "waive-approve",
                      () =>
                        decideWaiveAction({
                          propertyId,
                          checkId: check.id,
                          decision: "approved",
                          note:
                            waiveNote.trim() === "" ? null : waiveNote.trim(),
                        }),
                      vi.minibar.waiveDecisionSuccess,
                    )
                  }
                >
                  {pending === "waive-approve"
                    ? vi.minibar.decidingWaive
                    : vi.minibar.waiveApproveButton}
                </Button>
                <Button
                  type="button"
                  variant="outline"
                  disabled={pending !== null}
                  onClick={() =>
                    run(
                      "waive-reject",
                      () =>
                        decideWaiveAction({
                          propertyId,
                          checkId: check.id,
                          decision: "rejected",
                          note:
                            waiveNote.trim() === "" ? null : waiveNote.trim(),
                        }),
                      vi.minibar.waiveDecisionSuccess,
                    )
                  }
                >
                  {pending === "waive-reject"
                    ? vi.minibar.decidingWaive
                    : vi.minibar.waiveRejectButton}
                </Button>
              </div>
            </div>
          ) : null}

          {perms.canWaiveApprove ? (
            <div className="rounded-xl border bg-card p-4">
              <h2 className="font-medium">{vi.minibar.writeOffButton}</h2>
              <label className="mt-3 block text-sm">
                {vi.minibar.writeOffReason}
                <input
                  type="text"
                  value={writeOffReason}
                  onChange={(e) => setWriteOffReason(e.target.value)}
                  className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
              </label>
              <Button
                type="button"
                variant="destructive"
                className="mt-3"
                disabled={pending !== null || writeOffReason.trim() === ""}
                onClick={() =>
                  run(
                    "write-off",
                    () =>
                      writeOffAction({
                        propertyId,
                        checkId: check.id,
                        reason: writeOffReason.trim(),
                      }),
                    vi.minibar.writeOffSuccess,
                  )
                }
              >
                {pending === "write-off"
                  ? vi.minibar.writingOff
                  : vi.minibar.writeOffButton}
              </Button>
            </div>
          ) : null}
        </section>
      ) : null}
    </div>
  );
}
