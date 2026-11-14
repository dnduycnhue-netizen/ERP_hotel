"use client";

import { X } from "lucide-react";
import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import {
  CameraCapture,
  type CapturedPhoto,
} from "@/components/common/camera-capture";
import { NumPad } from "@/components/common/num-pad";
import { uploadCapturedPhoto } from "@/features/attachments/upload-client";
import {
  getReceivingLineAction,
  overrideReceivingLineAction,
  recordReceivingLineAction,
} from "@/features/receiving/actions";
import type {
  ReceiptLineRow,
  ReceivingTaskLineRow,
} from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";
import { enqueueOfflineJob, type QueuedPhoto } from "@/lib/offline/db";
import { useCan } from "@/lib/permissions/permissions-provider";
import { cn } from "@/lib/utils";

export function formatQty(value: number): string {
  return new Intl.NumberFormat("vi-VN", {
    maximumFractionDigits: 4,
  }).format(value);
}

/** Tóm tắt dòng đã xếp hàng chờ đồng bộ (T-025) — workspace hiện thẻ chờ. */
export type QueuedRecordSummary = {
  poLineId: string;
  netQty: number;
  uom: string;
  weighCount: number;
  photoCount: number;
};

type QcStatus = "pass" | "fail" | "conditional";
type ActiveField = "gross" | "tare" | "temp";

type FormPhoto = {
  localId: string;
  attachmentId: string | null;
  url: string;
  /** Anh chup luc offline — chua tai len, nam trong job dong bo (T-025). */
  pending: CapturedPhoto | null;
};

/** Checklist QC trong `qc_templates` là mảng tự do: chuỗi, hoặc object có label/text/title/name. */
function parseChecklist(template: unknown): string[] {
  if (!Array.isArray(template)) {
    return [];
  }
  const labels: string[] = [];
  for (const item of template) {
    if (typeof item === "string" && item.trim()) {
      labels.push(item);
      continue;
    }
    if (item && typeof item === "object") {
      const obj = item as Record<string, unknown>;
      for (const key of ["label", "text", "title", "name"]) {
        if (typeof obj[key] === "string" && (obj[key] as string).trim()) {
          labels.push(obj[key] as string);
          break;
        }
      }
    }
  }
  return labels;
}

function parseDecimal(value: string): number | null {
  if (value === "" || value === "-" || value === "." || value === "-.") {
    return null;
  }
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

/**
 * Form ghi 1 dòng nhận hàng (T-024, docs/06-UI-UX.md §3.1):
 * NumPad lớn cho Tổng cân / Bì (Thực nhận tự tính), chụp ảnh trong app,
 * checklist QC dạng nút chạm, nhiệt độ, số lô / hạn dùng, cân lại lần 2
 * khi server trả `needs_reweigh`, duyệt vượt PO khi bị chặn trần.
 *
 * Không hiện số lượng PO / đơn giá ở bất kỳ đâu — mù ở tầng dữ liệu.
 * Ảnh tải lên trước khi ghi dòng (lấy `photo_ids` đưa vào record).
 */
export function MobileLineForm({
  line,
  grId,
  propertyId,
  stored,
  canPerform,
  onRecorded,
  onQueued,
}: {
  line: ReceivingTaskLineRow;
  grId: string;
  propertyId: string;
  /** Dòng đã lưu trên server (null = chưa ghi). */
  stored: ReceiptLineRow | null;
  canPerform: boolean;
  onRecorded: (line: ReceiptLineRow) => void;
  /** Ghi dòng lúc offline: xếp hàng chờ đồng bộ thay vì gọi server. */
  onQueued: (summary: QueuedRecordSummary) => void;
}) {
  const canOverride = useCan("receiving.override_over_po");
  const checklistItems = useMemo(
    () => parseChecklist(line.qc_template),
    [line.qc_template],
  );

  const [activeField, setActiveField] = useState<ActiveField>("gross");
  const [gross, setGross] = useState("");
  const [tare, setTare] = useState("");
  const [temp, setTemp] = useState("");
  const [qcStatus, setQcStatus] = useState<QcStatus>("pass");
  const [checked, setChecked] = useState<string[]>([]);
  const [lot, setLot] = useState("");
  const [expiry, setExpiry] = useState("");
  const [failReason, setFailReason] = useState("");
  const [photos, setPhotos] = useState<FormPhoto[]>([]);
  // Phương án 2 khi không có camera: tích xác nhận + lý do (Q274, quyết định Duy).
  const [noCamera, setNoCamera] = useState(false);
  const [noCameraReason, setNoCameraReason] = useState("");
  const [uploading, setUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [overrideReason, setOverrideReason] = useState("");
  const [overriding, setOverriding] = useState(false);
  const [overrideError, setOverrideError] = useState<string | null>(null);
  const [overrideQueued, setOverrideQueued] = useState(false);
  const [shortWarning, setShortWarning] = useState(false);

  const isReweigh = stored?.needs_reweigh === true;
  const isOverPo =
    stored !== null && !stored.needs_reweigh && stored.over_po_qty_stock > 0;

  const grossNum = parseDecimal(gross);
  const tareNum = parseDecimal(tare) ?? 0;
  const tempNum = parseDecimal(temp);
  const netNum = grossNum !== null ? grossNum - tareNum : null;

  const valid =
    canPerform &&
    grossNum !== null &&
    grossNum > 0 &&
    tareNum >= 0 &&
    (grossNum === null || tareNum <= grossNum) &&
    (!line.photo_required ||
      photos.length > 0 ||
      (noCamera && noCameraReason.trim() !== "")) &&
    (!line.track_lot || (lot.trim() !== "" && expiry !== "")) &&
    (qcStatus !== "fail" || failReason.trim() !== "");

  // Chỉ gửi lý do miễn ảnh khi thực sự không có ảnh nào.
  const waivedReason =
    line.photo_required && photos.length === 0 && noCamera
      ? noCameraReason.trim() || null
      : null;

  async function handleCaptured(photo: CapturedPhoto) {
    // Offline (T-025): giữ blob trên máy, tải lên lúc đồng bộ cùng job ghi
    // dòng — không chặn người dùng chụp tiếp khi mất mạng.
    if (!navigator.onLine) {
      const url = URL.createObjectURL(photo.blob);
      setPhotos((prev) => [
        ...prev,
        {
          localId: crypto.randomUUID(),
          attachmentId: null,
          url,
          pending: photo,
        },
      ]);
      return;
    }
    setUploading(true);
    setError(null);
    const res = await uploadCapturedPhoto({
      propertyId,
      docType: "receiving",
      docId: grId,
      photo,
    });
    setUploading(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    const url = URL.createObjectURL(photo.blob);
    setPhotos((prev) => [
      ...prev,
      {
        localId: crypto.randomUUID(),
        attachmentId: res.data.id,
        url,
        pending: null,
      },
    ]);
  }

  /** Tải các ảnh còn chờ (chụp lúc offline) trước khi ghi dòng online. */
  async function uploadPendingPhotos(): Promise<string[] | null> {
    const uploadedIds: string[] = [];
    for (const photo of photos) {
      if (photo.attachmentId) {
        uploadedIds.push(photo.attachmentId);
        continue;
      }
      if (!photo.pending) {
        continue;
      }
      const res = await uploadCapturedPhoto({
        propertyId,
        docType: "receiving",
        docId: grId,
        photo: photo.pending,
      });
      if (!res.ok) {
        setError(res.error);
        return null;
      }
      uploadedIds.push(res.data.id);
      const attachmentId = res.data.id;
      const localId = photo.localId;
      setPhotos((prev) =>
        prev.map((item) =>
          item.localId === localId
            ? { ...item, attachmentId, pending: null }
            : item,
        ),
      );
    }
    return uploadedIds;
  }

  async function handleSubmit() {
    if (!valid || grossNum === null || submitting) {
      return;
    }
    setSubmitting(true);
    setError(null);
    const qcPayload = {
      status: qcStatus,
      checklist: checked,
      temperature_c: tempNum,
      reason: failReason.trim() || null,
    };
    // Offline (T-025): xếp hàng chờ đồng bộ với clientUuid cố định —
    // gửi lại cùng key, server (T-023) trả về dòng đã ghi thay vì tạo
    // trùng. Cân lại lần 2 cũng dùng key mới, giống gọi online.
    if (!navigator.onLine) {
      const clientUuid = crypto.randomUUID();
      const queuedPhotos: QueuedPhoto[] = photos.map((photo) => ({
        blob: photo.pending ? photo.pending.blob : null,
        sha256: photo.pending ? photo.pending.sha256 : "",
        width: photo.pending ? photo.pending.width : 0,
        height: photo.pending ? photo.pending.height : 0,
        deviceTime: photo.pending ? photo.pending.deviceTime : "",
        attachmentId: photo.attachmentId,
      }));
      try {
        await enqueueOfflineJob({
          propertyId,
          grId,
          countId: null,
          kind: "record",
          clientUuid,
          payload: {
            kind: "record",
            input: {
              grId,
              poLineId: line.po_line_id,
              itemId: line.item_id,
              gross: grossNum,
              tare: tareNum,
              uom: line.uom,
              qc: qcPayload,
              lot: lot.trim() || null,
              expiry: expiry || null,
              photoIds: [],
              photoWaivedReason: waivedReason,
              clientUuid,
            },
            photos: queuedPhotos,
          },
          createdAt: Date.now(),
        });
      } catch {
        setSubmitting(false);
        setError(vi.offline.queueUnavailable);
        return;
      }
      setSubmitting(false);
      onQueued({
        poLineId: line.po_line_id,
        netQty: grossNum - tareNum,
        uom: line.uom,
        weighCount: isReweigh ? 2 : 1,
        photoCount: photos.length,
      });
      return;
    }
    const photoIds = await uploadPendingPhotos();
    if (photoIds === null) {
      setSubmitting(false);
      return;
    }
    const res = await recordReceivingLineAction({
      grId,
      poLineId: line.po_line_id,
      itemId: line.item_id,
      gross: grossNum,
      tare: tareNum,
      uom: line.uom,
      qc: qcPayload,
      lot: lot.trim() || null,
      expiry: expiry || null,
      photoIds,
      photoWaivedReason: waivedReason,
      clientUuid: crypto.randomUUID(),
    });
    if (!res.ok) {
      setSubmitting(false);
      setError(res.error);
      return;
    }
    setShortWarning(res.data.short_shelf_life_warning);
    // Doc lai dong vua ghi: so chap nhan / vuot PO theo don vi luu kho
    // (response cua record khong du de ket luan khi don vi nhap khac
    // don vi luu kho). Moi lan goi dung client_uuid moi — goi lai cung
    // client_uuid se bi RPC tra ve dong cu (idempotency).
    const refreshed = await getReceivingLineAction(grId, line.po_line_id);
    setSubmitting(false);
    if (!refreshed.ok || !refreshed.data) {
      setError(refreshed.ok ? vi.errors.pageDescription : refreshed.error);
      return;
    }
    const storedLine = refreshed.data;
    if (storedLine.needs_reweigh) {
      // Can lan 1 lech dung sai: xoa so da nhap de can lai lan 2.
      setGross("");
      setTare("");
    }
    onRecorded(storedLine);
  }

  async function handleOverride() {
    if (!stored || overriding || overrideReason.trim() === "") {
      return;
    }
    // Offline (T-025): xếp hàng duyệt vượt — gr_line_id đã có trên server
    // vì dòng này ghi online trước đó; gửi lại không tạo trùng (RPC chỉ
    // cập nhật dòng, over_po về 0).
    if (!navigator.onLine) {
      setOverriding(true);
      setOverrideError(null);
      try {
        await enqueueOfflineJob({
          propertyId,
          grId,
          countId: null,
          kind: "override",
          clientUuid: null,
          payload: {
            kind: "override",
            input: { grLineId: stored.id, reason: overrideReason.trim() },
          },
          createdAt: Date.now(),
        });
      } catch {
        setOverriding(false);
        setOverrideError(vi.offline.queueUnavailable);
        return;
      }
      setOverriding(false);
      setOverrideQueued(true);
      return;
    }
    setOverriding(true);
    setOverrideError(null);
    const res = await overrideReceivingLineAction({
      grLineId: stored.id,
      reason: overrideReason.trim(),
    });
    if (!res.ok) {
      setOverriding(false);
      setOverrideError(res.error);
      return;
    }
    const refreshed = await getReceivingLineAction(grId, line.po_line_id);
    setOverriding(false);
    if (!refreshed.ok || !refreshed.data) {
      setOverrideError(
        refreshed.ok ? vi.errors.pageDescription : refreshed.error,
      );
      return;
    }
    onRecorded(refreshed.data);
  }

  function toggleChecklist(label: string) {
    setChecked((prev) =>
      prev.includes(label)
        ? prev.filter((item) => item !== label)
        : [...prev, label],
    );
  }

  function fieldBox(field: ActiveField, label: string, display: string) {
    const active = activeField === field;
    return (
      <button
        type="button"
        onClick={() => setActiveField(field)}
        disabled={submitting}
        className={cn(
          "flex min-h-16 flex-col items-start justify-center rounded-lg border bg-background px-3 text-left",
          active && "border-ring ring-2 ring-ring/50",
        )}
        aria-pressed={active}
      >
        <span className="text-xs text-muted-foreground">{label}</span>
        <span className="text-xl font-semibold tabular-nums">
          {display === "" ? "—" : display}
        </span>
      </button>
    );
  }

  // --- Che do duyet vuot PO: dong da ghi, bi chan tran, cho duyet. ---
  if (isOverPo && stored) {
    if (overrideQueued) {
      return (
        <div className="flex flex-col gap-3">
          <p role="status" className="text-sm font-medium text-amber-700">
            {vi.offline.queuedOverride}
          </p>
          <p className="text-sm text-muted-foreground">
            {vi.offline.queuedRecordHint}
          </p>
        </div>
      );
    }
    return (
      <div className="flex flex-col gap-3">
        <p role="alert" className="text-sm font-medium text-amber-700">
          {vi.receiving.overPoTitle}
        </p>
        <p className="text-sm leading-6">
          {vi.receiving.netQty}: {formatQty(stored.net_qty)} {stored.uom} (
          {formatQty(stored.net_qty_stock)} {vi.receiving.stockUnitNote}) ·{" "}
          {vi.receiving.acceptedQty}: {formatQty(stored.accepted_qty_stock)}{" "}
          {vi.receiving.stockUnitNote} · {vi.receiving.overPoQty}:{" "}
          {formatQty(stored.over_po_qty_stock)} {vi.receiving.stockUnitNote}
        </p>
        <p className="text-sm text-muted-foreground">
          {vi.receiving.overPoHint}
        </p>
        {canOverride ? (
          <>
            <label className="flex flex-col gap-1.5 text-sm font-medium">
              {vi.receiving.overrideReasonLabel}
              <textarea
                value={overrideReason}
                onChange={(event) => setOverrideReason(event.target.value)}
                placeholder={vi.receiving.overrideReasonPlaceholder}
                rows={2}
                disabled={overriding}
                className="rounded-lg border bg-background px-3 py-2 text-base outline-none focus:border-ring"
              />
            </label>
            {overrideError ? (
              <p role="alert" className="text-sm text-destructive">
                {overrideError}
              </p>
            ) : null}
            <Button
              size="lg"
              className="h-14 text-base"
              disabled={overriding || overrideReason.trim() === ""}
              onClick={() => void handleOverride()}
            >
              {overriding ? vi.common.loading : vi.receiving.overrideSubmit}
            </Button>
          </>
        ) : (
          <p className="text-sm text-muted-foreground">
            {vi.receiving.overPoHint}
          </p>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      {isReweigh && stored ? (
        <div
          role="alert"
          className="rounded-lg border border-amber-200 bg-amber-50 p-3"
        >
          <p className="text-sm font-medium text-amber-800">
            {vi.receiving.needsReweigh} — {vi.receiving.reweighTitle}
          </p>
          <p className="mt-1 text-sm text-amber-700">
            {vi.receiving.reweighHint}
          </p>
          <p className="mt-1 text-sm text-amber-700">
            {vi.receiving.weigh1Summary}: {vi.receiving.grossQty}{" "}
            {formatQty(stored.gross_qty)}, {vi.receiving.tareQty}{" "}
            {formatQty(stored.tare_qty)}
          </p>
        </div>
      ) : null}

      {shortWarning ? (
        <p role="alert" className="text-sm text-amber-700">
          {vi.receiving.shortShelfLifeWarning}
        </p>
      ) : null}

      <div className="grid grid-cols-3 gap-2">
        {fieldBox("gross", vi.receiving.grossQty, gross)}
        {fieldBox("tare", vi.receiving.tareQty, tare)}
        <div className="flex min-h-16 flex-col items-start justify-center rounded-lg border bg-muted/50 px-3">
          <span className="text-xs text-muted-foreground">
            {vi.receiving.netQty}
          </span>
          <span className="text-xl font-semibold tabular-nums">
            {netNum === null || netNum < 0
              ? "—"
              : `${formatQty(netNum)} ${line.uom}`}
          </span>
        </div>
      </div>
      <p className="text-xs text-muted-foreground">{vi.receiving.netHint}</p>
      {grossNum !== null && tareNum > grossNum ? (
        <p role="alert" className="text-sm text-destructive">
          {vi.receiving.tareExceedsGross}
        </p>
      ) : null}

      <NumPad
        value={
          activeField === "gross" ? gross : activeField === "tare" ? tare : temp
        }
        onChange={(next) => {
          if (activeField === "gross") {
            setGross(next);
          } else if (activeField === "tare") {
            setTare(next);
          } else {
            setTemp(next);
          }
        }}
        allowNegative={activeField === "temp"}
        disabled={submitting}
        label={
          activeField === "gross"
            ? vi.receiving.grossQty
            : activeField === "tare"
              ? vi.receiving.tareQty
              : vi.receiving.temperature
        }
      />

      <div className="flex flex-col gap-2">
        <p className="text-sm font-medium">
          {vi.receiving.photoRequired}
          {line.photo_required ? " *" : ""}
        </p>
        {photos.length > 0 ? (
          <div className="flex flex-wrap gap-2">
            {photos.map((photo) => (
              <span key={photo.localId} className="relative">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={photo.url}
                  alt={vi.receiving.photoTaken}
                  className="h-20 w-20 rounded-md border object-cover"
                />
                {photo.pending ? (
                  <span className="absolute inset-x-0 bottom-0 rounded-b-md bg-amber-600/90 px-1 py-0.5 text-center text-[10px] font-medium text-white">
                    {vi.offline.photoPending}
                  </span>
                ) : null}
                <button
                  type="button"
                  onClick={() => {
                    URL.revokeObjectURL(photo.url);
                    setPhotos((prev) =>
                      prev.filter((item) => item.localId !== photo.localId),
                    );
                  }}
                  disabled={submitting}
                  className="absolute -top-1.5 -right-1.5 rounded-full border bg-background p-0.5"
                  aria-label={vi.common.close}
                >
                  <X className="size-3.5" aria-hidden />
                </button>
              </span>
            ))}
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">
            {line.photo_required
              ? vi.receiving.photoMissing
              : vi.receiving.photoHint}
          </p>
        )}
        {uploading ? (
          <p className="text-sm text-muted-foreground">
            {vi.receiving.photoUploading}
          </p>
        ) : null}
        <CameraCapture
          onCaptured={(photo) => void handleCaptured(photo)}
          disabled={submitting || uploading}
        />
        {line.photo_required && photos.length === 0 ? (
          <div className="flex flex-col gap-2 rounded-md border border-dashed p-3">
            <label className="flex min-h-11 items-center gap-3 text-sm">
              <input
                type="checkbox"
                checked={noCamera}
                onChange={(e) => setNoCamera(e.target.checked)}
                disabled={submitting}
                className="size-5 accent-primary"
              />
              {vi.receiving.noCameraConfirm}
            </label>
            {noCamera ? (
              <input
                value={noCameraReason}
                onChange={(e) => setNoCameraReason(e.target.value)}
                disabled={submitting}
                maxLength={300}
                placeholder={vi.receiving.noCameraReasonPlaceholder}
                aria-label={vi.receiving.noCameraReasonPlaceholder}
                className="h-11 w-full rounded-md border bg-background px-3 text-base"
              />
            ) : null}
          </div>
        ) : null}
      </div>

      <div className="flex flex-col gap-2">
        <p className="text-sm font-medium">{vi.receiving.qcStatus}</p>
        <div className="grid grid-cols-3 gap-2">
          {(
            [
              ["pass", vi.receiving.qcPass],
              ["fail", vi.receiving.qcFail],
              ["conditional", vi.receiving.qcConditional],
            ] as const
          ).map(([status, label]) => (
            <Button
              key={status}
              type="button"
              variant={qcStatus === status ? "default" : "outline"}
              disabled={submitting}
              onClick={() => setQcStatus(status)}
              className="h-12 text-base"
              aria-pressed={qcStatus === status}
            >
              {label}
            </Button>
          ))}
        </div>
        {qcStatus === "fail" ? (
          <p className="text-sm text-muted-foreground">
            {vi.receiving.qcFailHint}
          </p>
        ) : null}
        {qcStatus !== "pass" ? (
          <label className="flex flex-col gap-1.5 text-sm font-medium">
            {vi.receiving.qcReasonLabel}
            {qcStatus === "fail" ? " *" : ""}
            <textarea
              value={failReason}
              onChange={(event) => setFailReason(event.target.value)}
              placeholder={vi.receiving.qcReasonPlaceholder}
              rows={2}
              disabled={submitting}
              className="rounded-lg border bg-background px-3 py-2 text-base outline-none focus:border-ring"
            />
          </label>
        ) : null}
        {checklistItems.length > 0 ? (
          <div className="flex flex-col gap-2">
            <p className="text-sm font-medium">
              {vi.receiving.qcChecklistTitle}
            </p>
            <div className="flex flex-wrap gap-2">
              {checklistItems.map((label) => {
                const isChecked = checked.includes(label);
                return (
                  <button
                    key={label}
                    type="button"
                    disabled={submitting}
                    onClick={() => toggleChecklist(label)}
                    aria-pressed={isChecked}
                    className={cn(
                      "rounded-full border px-3 py-2 text-sm",
                      isChecked
                        ? "border-primary bg-primary text-primary-foreground"
                        : "bg-background",
                    )}
                  >
                    {label}
                  </button>
                );
              })}
            </div>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">
            {vi.receiving.noTemplate}
          </p>
        )}
      </div>

      <div className="grid grid-cols-2 gap-2">
        <button
          type="button"
          onClick={() => setActiveField("temp")}
          disabled={submitting}
          className={cn(
            "flex min-h-14 flex-col items-start justify-center rounded-lg border bg-background px-3 text-left",
            activeField === "temp" && "border-ring ring-2 ring-ring/50",
          )}
          aria-pressed={activeField === "temp"}
        >
          <span className="text-xs text-muted-foreground">
            {vi.receiving.temperature}
          </span>
          <span className="text-base font-semibold tabular-nums">
            {temp === "" ? "—" : `${temp} °C`}
          </span>
        </button>
        <p className="flex items-center text-xs text-muted-foreground">
          {vi.receiving.temperatureHint}
        </p>
      </div>

      {line.track_lot ? (
        <div className="flex flex-col gap-2">
          <p className="text-sm font-medium">{vi.receiving.lotHint}</p>
          <label className="flex flex-col gap-1.5 text-sm font-medium">
            {vi.receiving.lotNo} *
            <input
              value={lot}
              onChange={(event) => setLot(event.target.value)}
              disabled={submitting}
              maxLength={100}
              className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
            />
          </label>
          <label className="flex flex-col gap-1.5 text-sm font-medium">
            {vi.receiving.expiryDate} *
            <input
              type="date"
              value={expiry}
              onChange={(event) => setExpiry(event.target.value)}
              disabled={submitting}
              className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
            />
          </label>
        </div>
      ) : null}

      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      {!canPerform ? (
        <p className="text-sm text-muted-foreground">
          {vi.receiving.noPerformPermission}
        </p>
      ) : null}
      <Button
        size="lg"
        className="h-14 text-base"
        disabled={!valid || submitting || uploading}
        onClick={() => void handleSubmit()}
      >
        {submitting
          ? vi.common.loading
          : isReweigh
            ? vi.receiving.reweigh
            : vi.receiving.recordLine}
      </Button>
    </div>
  );
}
