"use client";

import { CheckCircle2, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { CameraCapture } from "@/components/common/camera-capture";
import type { CapturedPhoto } from "@/components/common/camera-capture";
import { EmptyState } from "@/components/common/empty-state";
import { uploadCapturedPhoto } from "@/features/attachments/upload-client";
import {
  cancelSupplierReturnAction,
  confirmSupplierReturnAction,
} from "@/features/receiving/actions";
import type { SupplierReturnDetail } from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";
import { useCan } from "@/lib/permissions/permissions-provider";

/** Số tiền hiển thị — chỉ gọi khi server đã trả giá (co po.view_price). */
function formatMoney(value: number | null): string {
  if (value === null) {
    return vi.common.noData;
  }
  return value.toLocaleString("vi-VN");
}

function statusLabel(status: SupplierReturnDetail["status"]): string {
  if (status === "posted") {
    return vi.receiving.returnPosted;
  }
  if (status === "cancelled") {
    return vi.components.docStatus.cancelled;
  }
  return vi.receiving.returnRecorded;
}

/**
 * Chi tiết phiếu trả hàng NCC trên mobile (T-026).
 *
 * - Phiếu `recorded` (QC fail hoặc trả tay): xác nhận NCC đã lấy hàng
 *   (cần ảnh chữ ký người giao HOẶC ảnh lúc giao — RPC kiểm tra) hoặc hủy.
 * - Chữ ký chụp bằng CameraCapture, tải lên bucket `evidence` với
 *   docType `receiving` rồi truyền đường dẫn vào RPC confirm (Q22:
 *   chưa có màn ký tay, ảnh chữ ký giấy là bước đệm).
 * - Chỉ online: xác nhận/hủy là thao tác ghi sổ, không xếp hàng offline.
 */
export function MobileReturnDetail({
  detail,
  propertyId,
}: {
  detail: SupplierReturnDetail;
  propertyId: string;
}) {
  const router = useRouter();
  const canReturn = useCan("supplier_return.post");
  const [signature, setSignature] = useState<{
    id: string;
    path: string;
    url: string;
  } | null>(null);
  const [uploading, setUploading] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [cancelReason, setCancelReason] = useState("");
  const [showCancel, setShowCancel] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  const isRecorded = detail.status === "recorded";

  async function handleCaptured(photo: CapturedPhoto) {
    setUploading(true);
    setError(null);
    const res = await uploadCapturedPhoto({
      propertyId,
      docType: "receiving",
      docId: detail.id,
      photo,
    });
    setUploading(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setSignature({
      id: res.data.id,
      path: res.data.path,
      url: URL.createObjectURL(photo.blob),
    });
  }

  async function handleConfirm() {
    if (!signature || confirming) {
      return;
    }
    setConfirming(true);
    setError(null);
    const res = await confirmSupplierReturnAction({
      returnId: detail.id,
      supplierSignaturePath: signature.path,
      photoIds: [signature.id],
    });
    setConfirming(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setDone(vi.receiving.confirmReturnSuccess);
    router.refresh();
  }

  async function handleCancel() {
    if (!cancelReason.trim() || cancelling) {
      return;
    }
    setCancelling(true);
    setError(null);
    const res = await cancelSupplierReturnAction({
      returnId: detail.id,
      reason: cancelReason.trim(),
    });
    setCancelling(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setDone(vi.receiving.cancelReturnSuccess);
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold">
        {vi.receiving.returnDetailTitle}
      </h1>

      {done ? (
        <p
          role="status"
          className="flex items-start gap-2 rounded-lg border border-green-200 bg-green-50 p-3 text-sm text-green-800"
        >
          <CheckCircle2 className="mt-0.5 size-4 shrink-0" aria-hidden />
          {done}
        </p>
      ) : null}

      <section className="rounded-xl border bg-card p-4 shadow-sm">
        <dl className="flex flex-col gap-2 text-sm">
          <div className="flex justify-between gap-3">
            <dt className="text-muted-foreground">
              {vi.receiving.returnDocNo}
            </dt>
            <dd className="font-semibold">{detail.doc_no}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-muted-foreground">{vi.common.status}</dt>
            <dd className="font-medium">{statusLabel(detail.status)}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-muted-foreground">
              {vi.receiving.returnGrDocNo}
            </dt>
            <dd>{detail.gr_doc_no ?? vi.common.noData}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-muted-foreground">
              {vi.receiving.returnPoDocNo}
            </dt>
            <dd>{detail.po_doc_no ?? vi.common.noData}</dd>
          </div>
          <div className="flex justify-between gap-3">
            <dt className="text-muted-foreground">{vi.receiving.supplier}</dt>
            <dd>{detail.supplier_name}</dd>
          </div>
          {detail.total_amount !== null ? (
            <div className="flex justify-between gap-3">
              <dt className="text-muted-foreground">
                {vi.receiving.totalAmount}
              </dt>
              <dd className="font-semibold">
                {formatMoney(detail.total_amount)}
              </dd>
            </div>
          ) : null}
          {detail.cancel_reason ? (
            <div className="flex justify-between gap-3">
              <dt className="text-muted-foreground">
                {vi.receiving.cancelReturnReason}
              </dt>
              <dd>{detail.cancel_reason}</dd>
            </div>
          ) : null}
        </dl>
      </section>

      <section className="rounded-xl border bg-card p-4 shadow-sm">
        <h2 className="font-semibold">{vi.receiving.returnLinesTitle}</h2>
        {detail.lines.length === 0 ? (
          <EmptyState
            icon={X}
            title={vi.receiving.returnLinesTitle}
            description={vi.receiving.returnsEmpty}
          />
        ) : (
          <ul className="mt-3 flex flex-col gap-3">
            {detail.lines.map((line) => (
              <li
                key={line.id}
                className="border-t pt-3 first:border-t-0 first:pt-0"
              >
                <p className="font-medium">{line.item_name}</p>
                <p className="text-sm text-muted-foreground">
                  {vi.receiving.returnQty}: {line.qty_stock}
                  {line.unit_cost !== null
                    ? ` · ${formatMoney(line.unit_cost)}`
                    : ""}
                  {line.line_amount !== null
                    ? ` · ${formatMoney(line.line_amount)}`
                    : ""}
                </p>
                {line.reason ? (
                  <p className="text-sm text-muted-foreground">
                    {vi.receiving.returnReason}: {line.reason}
                  </p>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </section>

      {isRecorded && canReturn ? (
        <section className="flex flex-col gap-4 rounded-xl border bg-card p-4 shadow-sm">
          <h2 className="font-semibold">{vi.receiving.confirmReturnTitle}</h2>
          <p className="text-sm text-muted-foreground">
            {vi.receiving.confirmReturnHint}
          </p>

          {signature ? (
            <div className="relative">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={signature.url}
                alt={vi.receiving.signaturePhoto}
                className="max-h-48 w-full rounded-lg border object-cover"
              />
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="mt-2"
                disabled={confirming}
                onClick={() => setSignature(null)}
              >
                {vi.receiving.retakePhoto}
              </Button>
            </div>
          ) : (
            <>
              <p className="text-sm text-muted-foreground">
                {vi.receiving.signaturePhotoHint}
              </p>
              <CameraCapture
                onCaptured={(photo) => void handleCaptured(photo)}
                disabled={uploading || confirming}
              />
            </>
          )}
          {uploading ? (
            <p className="text-sm text-muted-foreground">
              {vi.receiving.photoUploading}
            </p>
          ) : null}

          {error ? (
            <p role="alert" className="text-sm text-destructive">
              {error}
            </p>
          ) : null}

          <Button
            disabled={!signature || confirming || uploading}
            onClick={() => void handleConfirm()}
            className="h-12 text-base"
          >
            {confirming ? vi.common.loading : vi.receiving.confirmReturn}
          </Button>

          {showCancel ? (
            <div className="flex flex-col gap-2 border-t pt-4">
              <label className="flex flex-col gap-1.5 text-sm font-medium">
                {vi.receiving.cancelReturnReason}
                <input
                  type="text"
                  value={cancelReason}
                  onChange={(event) => setCancelReason(event.target.value)}
                  disabled={cancelling}
                  className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
                />
              </label>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  disabled={cancelling}
                  onClick={() => setShowCancel(false)}
                  className="h-12 flex-1 text-base"
                >
                  {vi.common.back}
                </Button>
                <Button
                  variant="destructive"
                  disabled={!cancelReason.trim() || cancelling}
                  onClick={() => void handleCancel()}
                  className="h-12 flex-1 text-base"
                >
                  {cancelling ? vi.common.loading : vi.receiving.cancelReturn}
                </Button>
              </div>
            </div>
          ) : (
            <Button
              variant="outline"
              disabled={confirming}
              onClick={() => setShowCancel(true)}
              className="h-12 text-base"
            >
              {vi.receiving.cancelReturnTitle}
            </Button>
          )}
        </section>
      ) : null}

      {isRecorded && !canReturn ? (
        <p className="text-sm text-muted-foreground">
          {vi.receiving.noReturnPermission}
        </p>
      ) : null}
    </div>
  );
}
