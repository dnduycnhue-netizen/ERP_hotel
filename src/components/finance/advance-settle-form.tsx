"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { X } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  CameraCapture,
  type CapturedPhoto,
} from "@/components/common/camera-capture";
import { MoneyText } from "@/components/common/money-text";
import { settleAdvanceAction } from "@/features/finance/actions";
import { uploadCapturedPhoto } from "@/features/attachments/upload-client";
import {
  buildSettleLines,
  canSubmitSettleLines,
  emptySettleFormLine,
  formatReceiptOption,
  sortReceiptsForAdvance,
  type SettleFormLine,
} from "@/features/finance/settle-lines";
import type { AdvanceRow } from "@/features/procurement/queries";
import type { ReceiptListRow } from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";

/** Loại chứng từ đính kèm cho ảnh biên lai quyết toán (T-016). */
const SETTLE_RECEIPT_DOC_TYPE = "advance_settlement";

/**
 * Quyết toán tạm ứng (T-041 + C12/Q74): nhập số tiền thực chi theo từng
 * khoản, có thể gắn phiếu nhận đã chốt (gr_id) và chụp ảnh biên lai
 * (receipt_photo_id) cho từng dòng. RPC `advance_settle` chỉ đối chiếu
 * GR khi có gr_id; gắn chứng từ là tùy chọn (chưa bắt buộc — xem Q74).
 */
export function AdvanceSettleForm({
  propertyId,
  advance,
  postedReceipts,
}: {
  propertyId: string;
  advance: AdvanceRow;
  postedReceipts: ReceiptListRow[];
}) {
  const router = useRouter();
  const [lines, setLines] = useState<SettleFormLine[]>([emptySettleFormLine()]);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<{
    spent: number;
    refund: number;
    extra: number;
  } | null>(null);

  const sortedReceipts = useMemo(
    () => sortReceiptsForAdvance(postedReceipts, advance.po_id),
    [postedReceipts, advance.po_id],
  );
  const poReceipts = useMemo(
    () =>
      advance.po_id
        ? sortedReceipts.filter((r) => r.po_id === advance.po_id)
        : [],
    [sortedReceipts, advance.po_id],
  );
  const otherReceipts = useMemo(
    () =>
      advance.po_id
        ? sortedReceipts.filter((r) => r.po_id !== advance.po_id)
        : sortedReceipts,
    [sortedReceipts, advance.po_id],
  );

  const spent = useMemo(
    () =>
      lines.reduce((s, line) => {
        const n = Number(line.amount);
        return s + (Number.isFinite(n) && n > 0 ? n : 0);
      }, 0),
    [lines],
  );
  const refund = Math.max(0, advance.amount - spent);
  const extra = Math.max(0, spent - advance.amount);

  const canSubmit = canSubmitSettleLines(lines, pending);

  function updateLine(index: number, patch: Partial<SettleFormLine>) {
    setLines((prev) =>
      prev.map((line, i) => (i === index ? { ...line, ...patch } : line)),
    );
  }

  async function handleCaptured(index: number, photo: CapturedPhoto) {
    const previewUrl = URL.createObjectURL(photo.blob);
    updateLine(index, { uploading: true });
    setError(null);
    const res = await uploadCapturedPhoto({
      propertyId,
      docType: SETTLE_RECEIPT_DOC_TYPE,
      docId: advance.id,
      photo,
    });
    if (!res.ok) {
      URL.revokeObjectURL(previewUrl);
      updateLine(index, { uploading: false });
      setError(res.error);
      return;
    }
    updateLine(index, {
      uploading: false,
      photoId: res.data.id,
      photoPreviewUrl: previewUrl,
    });
  }

  function removePhoto(index: number) {
    setLines((prev) =>
      prev.map((line, i) => {
        if (i !== index) return line;
        if (line.photoPreviewUrl) {
          URL.revokeObjectURL(line.photoPreviewUrl);
        }
        return { ...line, photoId: null, photoPreviewUrl: null };
      }),
    );
  }

  async function handleSubmit() {
    setPending(true);
    setError(null);
    setResult(null);
    const res = await settleAdvanceAction({
      propertyId,
      advanceId: advance.id,
      lines: buildSettleLines(lines),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setResult({
      spent: res.data.spent,
      refund: res.data.refund_amount,
      extra: res.data.extra_pay_amount,
    });
    router.refresh();
  }

  return (
    <div className="rounded-lg border bg-card p-4">
      <h2 className="font-medium">{vi.finance.settleTitle}</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        {vi.finance.settleHint}
      </p>
      <div className="mt-3 space-y-4">
        {lines.map((line, i) => (
          <div key={i} className="space-y-2 rounded-md border p-3">
            <div className="flex items-center gap-2">
              <label className="block flex-1 text-sm">
                {vi.finance.actualAmount} {i + 1}
                <input
                  type="number"
                  inputMode="decimal"
                  min="0"
                  step="0.01"
                  value={line.amount}
                  onChange={(e) => updateLine(i, { amount: e.target.value })}
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
            <div>
              <label className="block text-sm">
                {vi.finance.settleGrLabel}
                {sortedReceipts.length > 0 ? (
                  <select
                    value={line.grId ?? ""}
                    onChange={(e) =>
                      updateLine(i, { grId: e.target.value || null })
                    }
                    className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                  >
                    <option value="">{vi.finance.settleGrNone}</option>
                    {poReceipts.length > 0 ? (
                      <optgroup label={vi.finance.settleGrOfPo}>
                        {poReceipts.map((r) => (
                          <option key={r.id} value={r.id}>
                            {formatReceiptOption(r)}
                          </option>
                        ))}
                      </optgroup>
                    ) : null}
                    {otherReceipts.length > 0 ? (
                      <optgroup
                        label={
                          poReceipts.length > 0
                            ? vi.finance.settleGrOthers
                            : vi.finance.settleGrLabel
                        }
                      >
                        {otherReceipts.map((r) => (
                          <option key={r.id} value={r.id}>
                            {formatReceiptOption(r)}
                          </option>
                        ))}
                      </optgroup>
                    ) : null}
                  </select>
                ) : (
                  <span className="mt-1 block text-sm text-muted-foreground">
                    {vi.finance.settleGrEmpty}
                  </span>
                )}
              </label>
              <p className="mt-1 text-xs text-muted-foreground">
                {vi.finance.settleGrHint}
              </p>
            </div>
            <div>
              <p className="text-sm font-medium">
                {vi.finance.settlePhotoLabel}
              </p>
              <p className="mt-1 text-xs text-muted-foreground">
                {vi.finance.settlePhotoHint}
              </p>
              <div className="mt-2">
                {line.photoId && line.photoPreviewUrl ? (
                  <div className="relative inline-block">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={line.photoPreviewUrl}
                      alt={vi.finance.settlePhotoLabel}
                      className="h-20 w-20 rounded-md border object-cover"
                    />
                    <button
                      type="button"
                      aria-label={vi.finance.settlePhotoRemove}
                      onClick={() => removePhoto(i)}
                      className="absolute -right-1 -top-1 rounded-full bg-destructive p-0.5 text-destructive-foreground"
                    >
                      <X className="size-3" aria-hidden />
                    </button>
                  </div>
                ) : (
                  <CameraCapture
                    onCaptured={(photo) => handleCaptured(i, photo)}
                    disabled={line.uploading || pending}
                  />
                )}
              </div>
              {line.uploading ? (
                <p className="mt-2 text-sm text-muted-foreground">
                  {vi.finance.settlePhotoUploading}
                </p>
              ) : null}
            </div>
          </div>
        ))}
      </div>
      <Button
        type="button"
        variant="outline"
        size="sm"
        className="mt-2"
        onClick={() => setLines((prev) => [...prev, emptySettleFormLine()])}
      >
        + {vi.finance.actualAmount}
      </Button>
      <div className="mt-4 space-y-1 text-sm">
        <p>
          {vi.finance.spentTotal}: <MoneyText amount={spent} />
        </p>
        <p>
          {vi.finance.refundAmount}: <MoneyText amount={refund} />
        </p>
        <p>
          {vi.finance.extraPayAmount}: <MoneyText amount={extra} />
        </p>
      </div>
      <Button
        type="button"
        className="mt-4"
        disabled={!canSubmit}
        onClick={handleSubmit}
      >
        {pending ? vi.finance.settling : vi.finance.settleButton}
      </Button>
      {result ? (
        <p className="mt-3 text-sm font-medium text-green-800">
          {vi.finance.settledMessage}
        </p>
      ) : null}
      {error ? (
        <p className="mt-3 text-sm font-medium text-red-800">{error}</p>
      ) : null}
    </div>
  );
}
