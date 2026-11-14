"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { CameraCapture } from "@/components/common/camera-capture";
import type { CapturedPhoto } from "@/components/common/camera-capture";
import { uploadCapturedPhoto } from "@/features/attachments/upload-client";
import {
  docLineQtyAction,
  docOpAction,
  saveDocDraftAction,
} from "@/features/inventory/doc-actions";
import type { DocKind } from "@/features/inventory/doc-schemas";
import { vi } from "@/i18n/vi";
import { useCan } from "@/lib/permissions/permissions-provider";

export type DocActionLine = {
  id: string;
  itemId: string;
  itemName: string;
  qtyStock: number;
  /** Đã xuất (phiếu lĩnh) / đã chuyển (điều chuyển). */
  doneOutQty: number;
  receivedQty: number;
  note: string | null;
};

export type DocActionDoc = {
  id: string;
  status: string;
  businessDate: string;
  note: string | null;
  /** Hủy hàng. */
  warehouseId?: string;
  reasonCode?: string;
  photoIds?: string[];
};

type PendingOp = "cancel" | "reject" | "reverse";
type QtyMode = "requisition_issue" | "requisition_receive" | "transfer_send" | "transfer_receive";

const A = vi.inventory.doc.actions;

/**
 * Thanh thao tác trên trang chi tiết chứng từ kho (B-4). Quyền kiểm bằng
 * `useCan` (quy tắc 10); RPC kiểm lại ở server. Hủy/từ chối/đảo dùng ô nhập
 * lý do ngay trên trang (không dùng hộp thoại confirm của trình duyệt).
 */
export function StockDocActions({
  kind,
  propertyId,
  doc,
  lines,
}: {
  kind: DocKind;
  propertyId: string;
  doc: DocActionDoc;
  lines: DocActionLine[];
}) {
  const router = useRouter();
  const canWastePropose = useCan("waste.propose");
  const canWasteApprove = useCan("waste.approve");
  const canWasteApproveLarge = useCan("waste.approve.large");
  const canReqCreate = useCan("requisition.create");
  const canReqApprove = useCan("requisition.approve");
  const canReqIssue = useCan("requisition.issue");
  const canReqReceive = useCan("requisition.receive");
  const canTrSend = useCan("transfer.send");
  const canTrReceive = useCan("transfer.receive");
  const canIssuePost = useCan("purpose_issue.post");
  const canIssueReverse = useCan("purpose_issue.reverse");

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [pendingOp, setPendingOp] = useState<PendingOp | null>(null);
  const [reason, setReason] = useState("");
  const [qtyMode, setQtyMode] = useState<QtyMode | null>(null);
  const [qtys, setQtys] = useState<Record<string, string>>({});
  const [discrepancy, setDiscrepancy] = useState("");

  const s = doc.status;
  const flags = {
    submit:
      (kind === "waste" && s === "draft" && canWastePropose) ||
      (kind === "requisition" && s === "draft" && canReqCreate),
    decide:
      (kind === "waste" &&
        s === "submitted" &&
        (canWasteApprove || canWasteApproveLarge)) ||
      (kind === "requisition" && s === "submitted" && canReqApprove),
    cancel:
      (kind === "waste" && s === "draft" && canWastePropose) ||
      (kind === "requisition" && s === "draft" && canReqCreate) ||
      (kind === "transfer" && s === "draft" && canTrSend) ||
      (kind === "purpose_issue" && s === "draft" && canIssuePost),
    post: kind === "purpose_issue" && s === "draft" && canIssuePost,
    reverse: kind === "purpose_issue" && s === "posted" && canIssueReverse,
    issue:
      kind === "requisition" &&
      (s === "approved" || s === "issued") &&
      canReqIssue,
    reqReceive:
      kind === "requisition" &&
      (s === "issued" || s === "partially_received") &&
      canReqReceive,
    send: kind === "transfer" && s === "draft" && canTrSend,
    trReceive:
      kind === "transfer" &&
      (s === "in_transit" || s === "partially_received") &&
      canTrReceive,
    photo: kind === "waste" && s === "draft" && canWastePropose,
  };

  function remaining(line: DocActionLine, mode: QtyMode): number {
    const v =
      mode === "requisition_issue" || mode === "transfer_send"
        ? line.qtyStock - line.doneOutQty
        : line.doneOutQty - line.receivedQty;
    return Math.max(0, Math.round(v * 10000) / 10000);
  }

  function openQty(mode: QtyMode) {
    setError(null);
    setNotice(null);
    setPendingOp(null);
    setQtyMode(mode);
    setQtys(
      Object.fromEntries(lines.map((l) => [l.id, String(remaining(l, mode))])),
    );
  }

  async function run(fn: () => Promise<{ ok: boolean; error?: string }>) {
    setBusy(true);
    setError(null);
    setNotice(null);
    const res = await fn();
    setBusy(false);
    if (!res.ok) {
      setError(res.error ?? vi.common.invalidData);
      return;
    }
    setNotice(A.done);
    setPendingOp(null);
    setQtyMode(null);
    setReason("");
    router.refresh();
  }

  const op = (o: "submit" | "approve" | "reject" | "cancel" | "post" | "reverse", r?: string) =>
    run(() =>
      docOpAction({ kind, op: o, propertyId, id: doc.id, reason: r ?? null }),
    );

  async function handlePhoto(photo: CapturedPhoto) {
    setBusy(true);
    setError(null);
    const up = await uploadCapturedPhoto({
      propertyId,
      docType: "waste",
      docId: doc.id,
      photo,
    });
    if (!up.ok) {
      setBusy(false);
      setError(up.error);
      return;
    }
    const res = await saveDocDraftAction({
      kind: "waste",
      propertyId,
      id: doc.id,
      businessDate: doc.businessDate,
      note: doc.note,
      warehouseId: doc.warehouseId ?? null,
      reasonCode: (doc.reasonCode ?? null) as never,
      photoIds: [...(doc.photoIds ?? []), up.data.id],
      lines: lines.map((l) => ({
        itemId: l.itemId,
        qty: l.qtyStock,
        note: l.note,
      })),
    });
    setBusy(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setNotice(A.done);
    router.refresh();
  }

  const anyAction =
    flags.submit ||
    flags.decide ||
    flags.cancel ||
    flags.post ||
    flags.reverse ||
    flags.issue ||
    flags.reqReceive ||
    flags.send ||
    flags.trReceive ||
    flags.photo;
  if (!anyAction) {
    return null;
  }

  const photoCount = doc.photoIds?.length ?? 0;

  return (
    <div className="flex flex-col gap-3 rounded-lg border bg-card p-4">
      {error ? (
        <div
          role="alert"
          className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive"
        >
          {error}
        </div>
      ) : null}
      {notice ? (
        <p role="status" className="text-sm text-emerald-700">
          {notice}
        </p>
      ) : null}

      {flags.photo ? (
        <div className="flex flex-col gap-2">
          <p className="text-sm text-muted-foreground">
            {A.photosCount.replace("{count}", String(photoCount))}
            {photoCount === 0 ? ` — ${A.photoNeeded}` : ""}
          </p>
          <CameraCapture onCaptured={handlePhoto} disabled={busy} />
        </div>
      ) : null}

      <div className="flex flex-wrap gap-2">
        {flags.submit ? (
          <Button disabled={busy} onClick={() => void op("submit")}>
            {A.submit}
          </Button>
        ) : null}
        {flags.post ? (
          <Button disabled={busy} onClick={() => void op("post")}>
            {A.post}
          </Button>
        ) : null}
        {flags.decide ? (
          <>
            <Button disabled={busy} onClick={() => void op("approve")}>
              {A.approve}
            </Button>
            <Button
              variant="outline"
              disabled={busy}
              onClick={() => setPendingOp("reject")}
            >
              {A.reject}
            </Button>
          </>
        ) : null}
        {flags.issue ? (
          <Button disabled={busy} onClick={() => openQty("requisition_issue")}>
            {A.issue}
          </Button>
        ) : null}
        {flags.reqReceive ? (
          <Button disabled={busy} onClick={() => openQty("requisition_receive")}>
            {A.receive}
          </Button>
        ) : null}
        {flags.send ? (
          <Button disabled={busy} onClick={() => openQty("transfer_send")}>
            {A.send}
          </Button>
        ) : null}
        {flags.trReceive ? (
          <Button disabled={busy} onClick={() => openQty("transfer_receive")}>
            {A.receive}
          </Button>
        ) : null}
        {flags.reverse ? (
          <Button
            variant="outline"
            disabled={busy}
            onClick={() => setPendingOp("reverse")}
          >
            {A.reverse}
          </Button>
        ) : null}
        {flags.cancel ? (
          <Button
            variant="outline"
            disabled={busy}
            onClick={() => setPendingOp("cancel")}
          >
            {A.cancel}
          </Button>
        ) : null}
      </div>

      {pendingOp ? (
        <div className="flex flex-col gap-2 rounded-md border p-3">
          <label className="flex flex-col gap-1 text-sm font-medium">
            {A.reasonLabel} *
            <input
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder={A.reasonPlaceholder}
              maxLength={500}
              className="h-9 w-full rounded-md border bg-background px-3 text-sm"
            />
          </label>
          <div className="flex gap-2">
            <Button
              size="sm"
              disabled={busy || !reason.trim()}
              onClick={() => void op(pendingOp, reason.trim())}
            >
              {A.confirm}
            </Button>
            <Button
              size="sm"
              variant="ghost"
              disabled={busy}
              onClick={() => {
                setPendingOp(null);
                setReason("");
              }}
            >
              {A.dismiss}
            </Button>
          </div>
        </div>
      ) : null}

      {qtyMode ? (
        <div className="flex flex-col gap-2 rounded-md border p-3">
          <table className="w-full text-sm">
            <tbody>
              {lines.map((l) => (
                <tr key={l.id} className="border-t first:border-t-0">
                  <td className="py-2 pr-2">{l.itemName}</td>
                  <td className="py-2 text-right">
                    <label className="sr-only" htmlFor={`qty-${l.id}`}>
                      {A.actualQty}
                    </label>
                    <input
                      id={`qty-${l.id}`}
                      type="number"
                      inputMode="decimal"
                      step="any"
                      min="0"
                      value={qtys[l.id] ?? ""}
                      onChange={(e) =>
                        setQtys((prev) => ({ ...prev, [l.id]: e.target.value }))
                      }
                      className="h-9 w-28 rounded-md border bg-background px-3 text-right text-sm"
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {qtyMode === "requisition_receive" ? (
            <label className="flex flex-col gap-1 text-sm font-medium">
              {A.discrepancyNote}
              <input
                value={discrepancy}
                onChange={(e) => setDiscrepancy(e.target.value)}
                maxLength={500}
                className="h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </label>
          ) : null}
          <div className="flex gap-2">
            <Button
              size="sm"
              disabled={busy}
              onClick={() =>
                void run(() =>
                  docLineQtyAction({
                    kind: qtyMode,
                    id: doc.id,
                    note: discrepancy.trim() || null,
                    lines: lines.map((l) => ({
                      lineId: l.id,
                      qtyStock: Number(qtys[l.id] ?? 0) || 0,
                    })),
                  }),
                )
              }
            >
              {A.confirm}
            </Button>
            <Button
              size="sm"
              variant="ghost"
              disabled={busy}
              onClick={() => setQtyMode(null)}
            >
              {A.dismiss}
            </Button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
