"use client";

import { awaitingReweigh } from "@/components/receiving/reweigh";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { ConfirmPostDialog } from "@/components/common/confirm-post-dialog";
import { PinDialog } from "@/components/common/pin-dialog";
import {
  getReceivingLineAction,
  postReceivingAction,
} from "@/features/receiving/actions";
import type {
  ReceiptLineRow,
  ReceiptRow,
  ReceivingTaskDetail,
} from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";
import { enqueueOfflineJob } from "@/lib/offline/db";
import { useOfflineSync } from "@/lib/offline/use-offline-sync";
import { useCan } from "@/lib/permissions/permissions-provider";
import {
  MobileLineForm,
  formatQty,
  type QueuedRecordSummary,
} from "./mobile-line-form";

function interpolate(
  template: string,
  values: Record<string, string | number>,
): string {
  return Object.entries(values).reduce(
    (text, [key, value]) => text.replace(`{${key}}`, String(value)),
    template,
  );
}

function qcBadgeClass(status: string): string {
  if (status === "pass") {
    return "border-green-200 bg-green-50 text-green-800";
  }
  if (status === "fail") {
    return "border-red-200 bg-red-50 text-red-800";
  }
  return "border-amber-200 bg-amber-50 text-amber-800";
}

function qcLabel(status: string): string {
  if (status === "pass") {
    return vi.receiving.qcPass;
  }
  if (status === "fail") {
    return vi.receiving.qcFail;
  }
  return vi.receiving.qcConditional;
}

/**
 * Không gian ghi nhận của 1 phiếu nháp (T-024): từng dòng PO hiện tên hàng
 * + đặc tả + yêu cầu QC (mù — không số lượng PO, không giá), form ghi dòng,
 * rồi ghi sổ bằng PIN.
 *
 * Ghi sổ chỉ bật khi đã ghi ít nhất 1 dòng và không còn dòng nào đang chờ
 * cân lại (server cũng chặn post khi còn dòng `needs_reweigh`).
 */
export function MobileReceiveWorkspace({
  receipt,
  task,
  propertyId,
}: {
  receipt: ReceiptRow;
  task: ReceivingTaskDetail;
  propertyId: string;
}) {
  const router = useRouter();
  const canPerform = useCan("receiving.perform");
  const canPost = useCan("receiving.post");
  const [lines, setLines] = useState<ReceiptLineRow[]>(receipt.lines);
  const linesRef = useRef(lines);
  const lineElementsRef = useRef(new Map<string, HTMLLIElement>());
  useEffect(() => {
    linesRef.current = lines;
  }, [lines]);
  const [queuedRecords, setQueuedRecords] = useState<
    Record<string, QueuedRecordSummary>
  >({});
  const [queuedPost, setQueuedPost] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [pinOpen, setPinOpen] = useState(false);
  const [noPhotoPost, setNoPhotoPost] = useState(false);
  const [noPhotoPostReason, setNoPhotoPostReason] = useState("");
  const [pinError, setPinError] = useState<string | null>(null);
  const [posting, setPosting] = useState(false);

  function handleRecorded(line: ReceiptLineRow) {
    setLines((prev) => {
      const next = prev.filter((item) => item.po_line_id !== line.po_line_id);
      return [...next, line];
    });
    setQueuedRecords((prev) => {
      if (!line.po_line_id) {
        return prev;
      }
      const next = { ...prev };
      delete next[line.po_line_id];
      return next;
    });
  }

  function handleQueued(summary: QueuedRecordSummary) {
    setQueuedRecords((prev) => ({ ...prev, [summary.poLineId]: summary }));
  }

  // Dong bo offline (T-025): job ghi dong xong thi doc lai dong tren
  // server de cap nhat UI; job ghi so xong thi ve danh sach.
  useOfflineSync({
    onRecordSynced: ({ grId, poLineId }) => {
      if (grId !== receipt.id) {
        return;
      }
      void (async () => {
        const refreshed = await getReceivingLineAction(grId, poLineId);
        if (refreshed.ok && refreshed.data) {
          handleRecorded(refreshed.data);
        }
        setQueuedRecords((prev) => {
          const next = { ...prev };
          delete next[poLineId];
          return next;
        });
      })();
    },
    onOverrideSynced: ({ grId, grLineId }) => {
      if (grId !== receipt.id) {
        return;
      }
      void (async () => {
        const poLineId = linesRef.current.find(
          (line) => line.id === grLineId,
        )?.po_line_id;
        if (!poLineId) {
          return;
        }
        const refreshed = await getReceivingLineAction(grId, poLineId);
        if (refreshed.ok && refreshed.data) {
          handleRecorded(refreshed.data);
        }
      })();
    },
    onPostSynced: (grId) => {
      if (grId !== receipt.id) {
        return;
      }
      setQueuedPost(false);
      router.push(`/m/${propertyId}/receive?posted=1`);
    },
  });

  const storedByPoLine = useMemo(() => {
    const map = new Map<string, ReceiptLineRow>();
    for (const line of lines) {
      if (line.po_line_id) {
        map.set(line.po_line_id, line);
      }
    }
    return map;
  }, [lines]);

  const recordedCount = task.lines.filter((line) =>
    storedByPoLine.has(line.po_line_id),
  ).length;
  const needsReweighCount = task.lines.filter(
    (line) => awaitingReweigh(storedByPoLine.get(line.po_line_id)),
  ).length;
  const queuedCount = Object.keys(queuedRecords).length;
  // Dong cho dong bo cung tinh la da ghi (server se kiem tra lai luc
  // dong bo; neu can can lai thi job post se loi va banner bao loi).
  const canPostNow = recordedCount + queuedCount > 0 && needsReweighCount === 0;

  /** Dòng còn việc phải làm: chưa ghi, hoặc cần cân lại / duyệt vượt. */
  function lineNeedsAction(poLineId: string): boolean {
    if (queuedRecords[poLineId]) {
      return false;
    }
    const stored = storedByPoLine.get(poLineId);
    if (!stored) {
      return true;
    }
    return awaitingReweigh(stored) || stored.over_po_qty_stock > 0;
  }

  const nextActionLine = task.lines.find((line) =>
    lineNeedsAction(line.po_line_id),
  );
  const progressPct =
    task.lines.length === 0 ? 0 : (recordedCount / task.lines.length) * 100;

  function scrollToNextAction() {
    if (!nextActionLine) {
      return;
    }
    lineElementsRef.current
      .get(nextActionLine.po_line_id)
      ?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  // Chỉ gửi lý do khi người dùng tích xác nhận "không có camera" lúc ghi sổ (Q278).
  const postWaivedReason =
    noPhotoPost && noPhotoPostReason.trim() !== ""
      ? noPhotoPostReason.trim()
      : null;

  async function handlePinSubmit(pin: string) {
    // Offline (T-025): xep hang ghi so — PIN luu trong job tren may cho
    // toi khi dong bo xong (xoa ngay sau khi gui); xem Q23.
    if (!navigator.onLine) {
      setPosting(true);
      setPinError(null);
      try {
        await enqueueOfflineJob({
          propertyId,
          grId: receipt.id,
          countId: null,
          kind: "post",
          clientUuid: null,
          payload: {
            kind: "post",
            input: {
              grId: receipt.id,
              pin,
              photoWaivedReason: postWaivedReason,
            },
          },
          createdAt: Date.now(),
        });
      } catch {
        setPosting(false);
        setPinError(vi.offline.queueUnavailable);
        return;
      }
      setPosting(false);
      setPinOpen(false);
      setQueuedPost(true);
      return;
    }
    setPosting(true);
    setPinError(null);
    const res = await postReceivingAction({
      grId: receipt.id,
      pin,
      photoWaivedReason: postWaivedReason,
    });
    setPosting(false);
    if (!res.ok) {
      setPinError(res.error);
      return;
    }
    setPinOpen(false);
    router.push(`/m/${propertyId}/receive?posted=1`);
  }

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-xl font-semibold">
          {vi.receiving.receiptTitle} {receipt.doc_no}
        </h1>
        <p className="mt-1 text-base text-muted-foreground">
          {task.doc_no} · {task.supplier_name}
        </p>
        <div
          role="progressbar"
          aria-valuenow={recordedCount}
          aria-valuemin={0}
          aria-valuemax={task.lines.length}
          aria-label={interpolate(vi.receiving.recordedProgress, {
            done: recordedCount,
            total: task.lines.length,
          })}
          className="mt-3 h-2.5 overflow-hidden rounded-full bg-muted"
        >
          <div
            className="h-full rounded-full bg-brand transition-all"
            style={{ width: `${progressPct}%` }}
          />
        </div>
        <p className="mt-2 text-base font-medium">
          {interpolate(vi.receiving.recordedProgress, {
            done: recordedCount,
            total: task.lines.length,
          })}
          {queuedCount > 0
            ? ` · ${interpolate(vi.receiving.queuedLinesCount, { count: queuedCount })}`
            : ""}
        </p>
        {nextActionLine ? (
          <Button
            type="button"
            variant="outline"
            onClick={scrollToNextAction}
            className="mt-3 min-h-11 w-full text-base"
          >
            {vi.receiving.nextUnrecorded}
          </Button>
        ) : null}
      </div>

      <ul className="flex flex-col gap-4">
        {task.lines.map((line) => {
          const stored = storedByPoLine.get(line.po_line_id) ?? null;
          const queued = queuedRecords[line.po_line_id] ?? null;
          // Dong vuot PO chua duyet thi hien form duyet thay vi ban tom
          // tat (T-025 — sua loi T-024: form duyet vuot trong
          // MobileLineForm khong bao gio hien vi workspace chi hien
          // tom tat khi dong da ghi).
          const needsOverride =
            stored !== null &&
            !awaitingReweigh(stored) &&
            stored.over_po_qty_stock > 0;
          const isRecorded =
            stored !== null && !awaitingReweigh(stored) && !needsOverride;
          return (
            <li
              key={line.po_line_id}
              ref={(el) => {
                if (el) {
                  lineElementsRef.current.set(line.po_line_id, el);
                } else {
                  lineElementsRef.current.delete(line.po_line_id);
                }
              }}
              className="scroll-mt-24 rounded-xl border bg-card p-4 shadow-sm"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-base font-semibold">{line.item_name}</p>
                  {line.spec ? (
                    <p className="mt-0.5 text-base text-muted-foreground">
                      {vi.receiving.spec}: {line.spec}
                    </p>
                  ) : null}
                  <p className="mt-0.5 text-base text-muted-foreground">
                    {line.uom}
                    {line.track_lot ? ` · ${vi.receiving.lotNo}` : ""}
                    {line.photo_required
                      ? ` · ${vi.receiving.photoRequired}`
                      : ""}
                  </p>
                </div>
                {isRecorded && stored ? (
                  <span
                    className={`shrink-0 rounded-full border px-2 py-0.5 text-xs font-medium ${qcBadgeClass(stored.qc_status)}`}
                  >
                    {qcLabel(stored.qc_status)}
                  </span>
                ) : null}
              </div>

              {queued ? (
                <div className="mt-3 flex flex-col gap-1 border-t border-amber-200 bg-amber-50 p-3 text-sm">
                  <p role="status" className="font-medium text-amber-800">
                    {vi.offline.queuedRecord}
                    {queued.weighCount > 1 ? ` — ${vi.receiving.reweigh}` : ""}
                  </p>
                  <p className="text-amber-700">
                    {vi.receiving.netQty}: {formatQty(queued.netQty)}{" "}
                    {queued.uom} · {vi.receiving.photoTaken}:{" "}
                    {queued.photoCount}
                  </p>
                  <p className="text-amber-700">
                    {vi.offline.queuedRecordHint}
                  </p>
                </div>
              ) : isRecorded && stored ? (
                <div className="mt-3 flex flex-col gap-1 border-t pt-3 text-sm">
                  <p>
                    {vi.receiving.netQty}: {formatQty(stored.net_qty)}{" "}
                    {stored.uom} ({vi.receiving.grossQty}{" "}
                    {formatQty(stored.gross_qty)}, {vi.receiving.tareQty}{" "}
                    {formatQty(stored.tare_qty)})
                  </p>
                  <p className="text-muted-foreground">
                    {vi.receiving.weighCount}: {stored.weigh_count}
                  </p>
                  <p className="text-muted-foreground">
                    {vi.receiving.photoTaken}: {stored.photo_ids.length}
                  </p>
                </div>
              ) : (
                <div className="mt-3">
                  <MobileLineForm
                    line={line}
                    grId={receipt.id}
                    propertyId={propertyId}
                    stored={stored}
                    canPerform={canPerform}
                    onRecorded={handleRecorded}
                    onQueued={handleQueued}
                  />
                </div>
              )}
            </li>
          );
        })}
      </ul>

      {/* Thanh hành động dính đáy: luôn thấy nút Ghi sổ + tiến độ mà không
          cần cuộn hết danh sách. Sau khi gộp với shell của W1 (bottom tab
          cố định), shell cần chừa khoảng trống phía dưới — xem Q180. */}
      <div className="sticky bottom-[calc(3.5rem+env(safe-area-inset-bottom))] z-10 -mx-4 flex flex-col gap-2 border-t bg-background/95 px-4 pt-3 pb-[max(1rem,env(safe-area-inset-bottom))] backdrop-blur">
        <p className="text-base font-medium" aria-live="polite">
          {interpolate(vi.receiving.recordedProgress, {
            done: recordedCount,
            total: task.lines.length,
          })}
          {queuedCount > 0
            ? ` · ${interpolate(vi.receiving.queuedLinesCount, { count: queuedCount })}`
            : ""}
        </p>
        {needsReweighCount > 0 ? (
          <p role="alert" className="text-sm text-amber-700">
            {vi.receiving.reweighHint}
          </p>
        ) : recordedCount === task.lines.length ? (
          <p className="text-sm text-muted-foreground">
            {vi.receiving.allLinesDone}
          </p>
        ) : (
          <p className="text-sm text-muted-foreground">
            {vi.receiving.pendingLinesHint}
          </p>
        )}
        {!canPost ? (
          <p className="text-sm text-muted-foreground">
            {vi.receiving.noPostPermission}
          </p>
        ) : null}
        {queuedPost ? (
          <p role="status" className="text-sm font-medium text-amber-700">
            {vi.offline.queuedPost}
          </p>
        ) : null}
        <div className="flex flex-col gap-2 rounded-md border border-dashed p-3">
          <label className="flex min-h-11 items-center gap-3 text-sm">
            <input
              type="checkbox"
              checked={noPhotoPost}
              onChange={(e) => setNoPhotoPost(e.target.checked)}
              disabled={posting || queuedPost}
              className="size-5 accent-primary"
            />
            {vi.receiving.noCameraPostConfirm}
          </label>
          {noPhotoPost ? (
            <input
              value={noPhotoPostReason}
              onChange={(e) => setNoPhotoPostReason(e.target.value)}
              disabled={posting || queuedPost}
              maxLength={300}
              placeholder={vi.receiving.noCameraReasonPlaceholder}
              aria-label={vi.receiving.noCameraReasonPlaceholder}
              className="h-11 w-full rounded-md border bg-background px-3 text-base"
            />
          ) : null}
        </div>
        <Button
          size="lg"
          className="h-14 w-full text-base"
          disabled={!canPost || !canPostNow || posting || queuedPost}
          onClick={() => {
            setConfirmOpen(true);
          }}
        >
          {vi.receiving.post}
        </Button>
        <Link
          href={`/m/${propertyId}/receive`}
          className="min-h-11 text-center text-base font-medium text-primary underline-offset-4 hover:underline"
        >
          {vi.receiving.backToTasks}
        </Link>
      </div>

      <ConfirmPostDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title={vi.receiving.pinTitle}
        docNo={receipt.doc_no}
        consequences={[
          vi.components.confirmPost.defaultConsequence,
          vi.receiving.postConfirmNote,
        ]}
        confirmLabel={vi.components.confirmPost.confirmAction}
        onConfirm={() => {
          setConfirmOpen(false);
          setPinError(null);
          setPinOpen(true);
        }}
      />
      <PinDialog
        open={pinOpen}
        onOpenChange={setPinOpen}
        title={vi.receiving.pinTitle}
        description={vi.receiving.pinHint}
        length={6}
        minLength={4}
        error={pinError}
        submitting={posting}
        onSubmit={(pin) => void handlePinSubmit(pin)}
      />
    </div>
  );
}
