"use client";

import { PackageX } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { CameraCapture } from "@/components/common/camera-capture";
import type { CapturedPhoto } from "@/components/common/camera-capture";
import { EmptyState } from "@/components/common/empty-state";
import { uploadCapturedPhoto } from "@/features/attachments/upload-client";
import {
  eligibleReturnLinesAction,
  postSupplierReturnAction,
} from "@/features/receiving/actions";
import type {
  EligibleReturnLineRow,
  ReceiptListRow,
} from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";
import { useOfflineSync } from "@/lib/offline/use-offline-sync";

type LineDraft = {
  line: EligibleReturnLineRow;
  qty: string;
  reason: string;
  photoIds: string[];
};

/**
 * Form tạo phiếu trả hàng NCC trên mobile (T-026).
 *
 * 1. Chọn phiếu nhận ĐÃ GHI SỔ (chỉ phiếu posted mới có hàng trong kho
 *    để trả — RPC `supplier_return_eligible_lines` kiểm tra).
 * 2. Nhập số lượng trả cho từng dòng (không vượt số còn trả được) +
 *    lý do (bắt buộc — RPC `supplier_return_post` kiểm tra).
 * 3. Ảnh bằng chứng từng dòng (tùy chọn, chụp bằng CameraCapture).
 *
 * Chỉ online: tạo phiếu trả là thao tác ghi sổ (return_out trừ kho),
 * không xếp hàng offline (T-025 chỉ xếp hàng ghi dòng/đếm lại/ghi sổ
 * phiếu nhận, không xếp hàng phiếu trả).
 */
export function MobileNewReturnForm({
  propertyId,
  postedReceipts,
}: {
  propertyId: string;
  postedReceipts: ReceiptListRow[];
}) {
  const router = useRouter();
  const { online } = useOfflineSync();
  const [grId, setGrId] = useState("");
  const [grDocNo, setGrDocNo] = useState("");
  const [loadingLines, setLoadingLines] = useState(false);
  const [drafts, setDrafts] = useState<LineDraft[] | null>(null);
  const [uploadingLine, setUploadingLine] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleChooseReceipt(nextGrId: string) {
    setGrId(nextGrId);
    setDrafts(null);
    setError(null);
    if (!nextGrId) {
      setGrDocNo("");
      return;
    }
    const receipt = postedReceipts.find((r) => r.id === nextGrId);
    setGrDocNo(receipt?.doc_no ?? "");
    setLoadingLines(true);
    const res = await eligibleReturnLinesAction({ grId: nextGrId });
    setLoadingLines(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setDrafts(
      res.data.lines.map((line) => ({
        line,
        qty: "",
        reason: "",
        photoIds: [],
      })),
    );
  }

  function updateDraft(grLineId: string, patch: Partial<LineDraft>) {
    setDrafts(
      (prev) =>
        prev?.map((d) =>
          d.line.gr_line_id === grLineId ? { ...d, ...patch } : d,
        ) ?? null,
    );
  }

  async function handleCaptured(grLineId: string, photo: CapturedPhoto) {
    setUploadingLine(grLineId);
    setError(null);
    const res = await uploadCapturedPhoto({
      propertyId,
      docType: "receiving",
      docId: grId,
      lineId: grLineId,
      photo,
    });
    setUploadingLine(null);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setDrafts(
      (prev) =>
        prev?.map((d) =>
          d.line.gr_line_id === grLineId
            ? { ...d, photoIds: [...d.photoIds, res.data.id] }
            : d,
        ) ?? null,
    );
  }

  const selectedDrafts = (drafts ?? []).filter((d) => {
    const qty = Number(d.qty);
    return Number.isFinite(qty) && qty > 0;
  });
  const canSubmit =
    online &&
    selectedDrafts.length > 0 &&
    selectedDrafts.every(
      (d) =>
        Number(d.qty) <= d.line.returnable_qty_stock && d.reason.trim() !== "",
    );

  async function handleSubmit() {
    if (!canSubmit || submitting) {
      return;
    }
    setSubmitting(true);
    setError(null);
    const res = await postSupplierReturnAction({
      grId,
      lines: selectedDrafts.map((d) => ({
        grLineId: d.line.gr_line_id,
        qtyStock: Number(d.qty),
        reason: d.reason.trim(),
        photoIds: d.photoIds,
      })),
    });
    setSubmitting(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.push(`/m/${propertyId}/receive/returns/${res.data.id}`);
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold">{vi.receiving.newReturnTitle}</h1>
      <p className="text-sm text-muted-foreground">
        {vi.receiving.chooseReceiptHint}
      </p>

      {!online ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
          {vi.offline.startNeedsOnline}
        </p>
      ) : null}

      <label className="flex flex-col gap-1.5 text-sm font-medium">
        {vi.receiving.chooseReceiptTitle}
        <select
          value={grId}
          onChange={(event) => void handleChooseReceipt(event.target.value)}
          disabled={submitting || !online}
          className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
        >
          <option value="">{vi.common.noData}</option>
          {postedReceipts.map((r) => (
            <option key={r.id} value={r.id}>
              {r.doc_no} · {r.supplier_name}
            </option>
          ))}
        </select>
      </label>

      {postedReceipts.length === 0 ? (
        <EmptyState
          icon={PackageX}
          title={vi.receiving.chooseReceiptTitle}
          description={vi.receiving.noPostedReceipts}
        />
      ) : null}

      {loadingLines ? (
        <p className="text-sm text-muted-foreground">{vi.common.loading}</p>
      ) : null}

      {drafts !== null && drafts.length === 0 ? (
        <EmptyState
          icon={PackageX}
          title={grDocNo}
          description={vi.receiving.returnsEmpty}
        />
      ) : null}

      {drafts !== null && drafts.length > 0 ? (
        <ul className="flex flex-col gap-3">
          {drafts.map((draft) => {
            const qty = Number(draft.qty);
            const overQty =
              Number.isFinite(qty) && qty > draft.line.returnable_qty_stock;
            return (
              <li
                key={draft.line.gr_line_id}
                className="rounded-xl border bg-card p-4 shadow-sm"
              >
                <p className="font-medium">{draft.line.item_name}</p>
                <p className="text-sm text-muted-foreground">
                  {vi.receiving.acceptedQtyShort}:{" "}
                  {draft.line.accepted_qty_stock} ·{" "}
                  {vi.receiving.returnedQtyShort}:{" "}
                  {draft.line.returned_qty_stock} · {vi.receiving.returnableQty}
                  : {draft.line.returnable_qty_stock} {draft.line.uom}
                </p>
                <div className="mt-3 flex flex-col gap-3">
                  <label className="flex flex-col gap-1.5 text-sm font-medium">
                    {vi.receiving.qtyToReturn} ({draft.line.uom})
                    <input
                      type="number"
                      inputMode="decimal"
                      min={0}
                      step="any"
                      value={draft.qty}
                      onChange={(event) =>
                        updateDraft(draft.line.gr_line_id, {
                          qty: event.target.value,
                        })
                      }
                      disabled={submitting}
                      className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
                    />
                    {overQty ? (
                      <span className="text-xs font-normal text-destructive">
                        {vi.receiving.qtyExceedsReturnable}
                      </span>
                    ) : null}
                  </label>
                  <label className="flex flex-col gap-1.5 text-sm font-medium">
                    {vi.receiving.returnReason}
                    <input
                      type="text"
                      value={draft.reason}
                      onChange={(event) =>
                        updateDraft(draft.line.gr_line_id, {
                          reason: event.target.value,
                        })
                      }
                      disabled={submitting}
                      className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
                    />
                  </label>
                  <div className="flex flex-col gap-2">
                    <p className="text-sm font-medium">
                      {vi.receiving.photoHint} ({draft.photoIds.length})
                    </p>
                    <CameraCapture
                      onCaptured={(photo) =>
                        void handleCaptured(draft.line.gr_line_id, photo)
                      }
                      disabled={
                        submitting || uploadingLine === draft.line.gr_line_id
                      }
                    />
                    {uploadingLine === draft.line.gr_line_id ? (
                      <p className="text-sm text-muted-foreground">
                        {vi.receiving.photoUploading}
                      </p>
                    ) : null}
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
      ) : null}

      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}

      {drafts !== null && drafts.length > 0 ? (
        <Button
          disabled={!canSubmit || submitting}
          onClick={() => void handleSubmit()}
          className="h-12 text-base"
        >
          {submitting ? vi.common.loading : vi.receiving.returnTitle}
        </Button>
      ) : null}
    </div>
  );
}
