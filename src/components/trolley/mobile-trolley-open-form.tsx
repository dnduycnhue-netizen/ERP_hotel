"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { useOfflineSync } from "@/lib/offline/use-offline-sync";
import { enqueueOfflineJob } from "@/lib/offline/db";
import {
  clearTrolleyDraft,
  loadTrolleyDraft,
  saveTrolleyDraftCounts,
  trolleyOpenDraftKey,
} from "@/features/trolley/drafts";
import { openTrolleyShiftAction } from "@/features/trolley/actions";
import type { TrolleyParRow } from "@/features/trolley/queries";
import { listTrolleyParLevelsAction } from "@/features/trolley/actions";
import { TrolleyCountList } from "@/components/trolley/trolley-count-list";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";
import { useCan } from "@/lib/permissions/permissions-provider";
import type { TrolleyShiftName } from "@/features/trolley/schemas";

function todayVn(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

function countsToInput(
  values: Record<string, string>,
): Array<{ itemId: string; qty: number }> {
  return Object.entries(values)
    .map(([itemId, raw]) => ({ itemId, qty: Number(raw) }))
    .filter((c) => Number.isFinite(c.qty) && c.qty >= 0);
}

const SHIFT_OPTIONS: Array<{ value: TrolleyShiftName; label: string }> = [
  { value: "day", label: vi.trolley.shiftOptions.day },
  { value: "morning", label: vi.trolley.shiftOptions.morning },
  { value: "evening", label: vi.trolley.shiftOptions.evening },
];

/**
 * Form mở ca xe đẩy mobile (đếm mù đầu ca):
 * - Chọn xe đẩy → tải mức par của xe (chỉ để biết đếm món nào; KHÔNG
 *   hiện số par khi đếm — xem Q115).
 * - Chọn ca + ngày nghiệp vụ (mặc định hôm nay, giờ VN).
 * - Đếm từng món trên xe bằng NumPad; số đếm tự lưu nháp (Dexie) khi
 *   gõ — mất mạng/tải lại trang không mất.
 * - Online: gọi thẳng `trolley_shift_open` → chuyển vào ca vừa mở.
 *   Offline: xếp hàng kind `trolley_open` → báo "đã xếp hàng", ca hiện
 *   ở danh sách sau khi đồng bộ xong.
 */
export function MobileTrolleyOpenForm({
  propertyId,
  trolleyWarehouses,
}: {
  propertyId: string;
  trolleyWarehouses: Array<{ id: string; code: string; name: string }>;
}) {
  const router = useRouter();
  const { online } = useOfflineSync();
  const canOperate = useCan("hk.trolley.operate");
  const [trolleyWh, setTrolleyWh] = useState("");
  const [shift, setShift] = useState<TrolleyShiftName>("day");
  const [businessDate, setBusinessDate] = useState(todayVn());
  const [parItems, setParItems] = useState<TrolleyParRow[]>([]);
  const [parError, setParError] = useState<string | null>(null);
  const [values, setValues] = useState<Record<string, string>>({});
  const [draftLoaded, setDraftLoaded] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [queued, setQueued] = useState(false);
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Tải mức par khi đổi xe đẩy: setState chỉ nằm trong callback của
  // promise (không gọi đồng bộ trong effect — react-hooks/set-state-in-effect).
  useEffect(() => {
    if (!trolleyWh) {
      return;
    }
    let cancelled = false;
    void listTrolleyParLevelsAction(propertyId, trolleyWh).then((res) => {
      if (cancelled) {
        return;
      }
      if (res.ok) {
        setParItems(res.data);
        setParError(null);
        return;
      }
      setParItems([]);
      setParError(res.error);
    });
    return () => {
      cancelled = true;
    };
  }, [propertyId, trolleyWh]);

  /** Đổi xe đẩy: xóa số đếm/mức par cũ ngay (event handler). */
  function handleTrolleyChange(id: string): void {
    setTrolleyWh(id);
    setParItems([]);
    setParError(null);
    setValues({});
    setDraftLoaded(false);
  }

  /** Đổi ca/ngày: xóa số đếm cũ ngay (event handler). */
  function handleShiftChange(value: TrolleyShiftName): void {
    setShift(value);
    setValues({});
    setDraftLoaded(false);
  }

  function handleBusinessDateChange(value: string): void {
    setBusinessDate(value);
    setValues({});
    setDraftLoaded(false);
  }

  // Khôi phục nháp đếm dở (mở ca theo xe + ca + ngày).
  useEffect(() => {
    if (!trolleyWh) {
      return;
    }
    let cancelled = false;
    void loadTrolleyDraft(
      trolleyOpenDraftKey(propertyId, trolleyWh, shift, businessDate),
    ).then((draft) => {
      if (cancelled) {
        return;
      }
      if (draft) {
        const restored: Record<string, string> = {};
        for (const c of draft.counts) {
          restored[c.itemId] = c.qty;
        }
        setValues(restored);
      } else {
        setValues({});
      }
      setDraftLoaded(true);
    });
    return () => {
      cancelled = true;
    };
  }, [propertyId, trolleyWh, shift, businessDate]);

  // Tự lưu nháp (debounce 500ms) mỗi khi số đếm đổi.
  useEffect(() => {
    if (!trolleyWh || !draftLoaded) {
      return;
    }
    if (saveTimer.current) {
      clearTimeout(saveTimer.current);
    }
    saveTimer.current = setTimeout(() => {
      void saveTrolleyDraftCounts(
        trolleyOpenDraftKey(propertyId, trolleyWh, shift, businessDate),
        {
          propertyId,
          shiftId: null,
          trolleyWh,
          shift,
          businessDate,
          kind: "open",
        },
        Object.entries(values).map(([itemId, qty]) => ({ itemId, qty })),
        [],
      );
    }, 500);
    return () => {
      if (saveTimer.current) {
        clearTimeout(saveTimer.current);
      }
    };
  }, [values, propertyId, trolleyWh, shift, businessDate, draftLoaded]);

  const countedAll = parItems.every((item) => {
    const raw = values[item.item_id] ?? "";
    return raw !== "" && Number.isFinite(Number(raw)) && Number(raw) >= 0;
  });

  async function handleSubmit() {
    if (!canOperate || !trolleyWh || !countedAll || submitting) {
      return;
    }
    setSubmitting(true);
    setError(null);
    const input = {
      propertyId,
      trolleyWh,
      shift,
      businessDate,
      counts: countsToInput(values),
    };
    if (!online) {
      await enqueueOfflineJob({
        propertyId,
        grId: null,
        countId: null,
        kind: "trolley_open",
        clientUuid: null,
        payload: { kind: "trolley_open", input },
        createdAt: Date.now(),
      });
      await clearTrolleyDraft(
        trolleyOpenDraftKey(propertyId, trolleyWh, shift, businessDate),
      );
      setQueued(true);
      setSubmitting(false);
      return;
    }
    const res = await openTrolleyShiftAction(input);
    if (!res.ok) {
      setError(res.error);
      setSubmitting(false);
      return;
    }
    await clearTrolleyDraft(
      trolleyOpenDraftKey(propertyId, trolleyWh, shift, businessDate),
    );
    router.push(`/m/${propertyId}/trolley/${res.data.shift_id}`);
  }

  if (queued) {
    return (
      <div className="flex flex-col gap-4">
        <p className="rounded-xl border border-amber-300 bg-amber-50/60 p-4 text-base">
          {vi.trolley.queuedOpen}
        </p>
        <Button
          onClick={() => router.push(`/m/${propertyId}/trolley`)}
          className="min-h-11 w-full text-base"
        >
          {vi.trolley.backToList}
        </Button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold">{vi.trolley.openTitle}</h1>

      <label className="flex flex-col gap-1 text-base font-medium">
        {vi.trolley.trolleyWarehouse}
        <select
          value={trolleyWh}
          onChange={(e) => handleTrolleyChange(e.target.value)}
          className="min-h-11 rounded-md border bg-background px-3 py-2 text-base font-normal"
        >
          <option value="">{vi.common.selectPlaceholder}</option>
          {trolleyWarehouses.map((w) => (
            <option key={w.id} value={w.id}>
              {w.code} — {w.name}
            </option>
          ))}
        </select>
      </label>

      <div className="flex gap-3">
        <label className="flex flex-1 flex-col gap-1 text-base font-medium">
          {vi.trolley.shift}
          <select
            value={shift}
            onChange={(e) =>
              handleShiftChange(e.target.value as TrolleyShiftName)
            }
            className="min-h-11 rounded-md border bg-background px-3 py-2 text-base font-normal"
          >
            {SHIFT_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-1 flex-col gap-1 text-base font-medium">
          {vi.trolley.businessDate}
          <input
            type="date"
            value={businessDate}
            onChange={(e) => handleBusinessDateChange(e.target.value)}
            className="min-h-11 rounded-md border bg-background px-3 py-2 text-base font-normal"
          />
        </label>
      </div>

      {parError ? (
        <p className="rounded-xl border border-destructive/40 bg-destructive/5 p-3 text-base text-destructive">
          {parError}
        </p>
      ) : null}

      {trolleyWh && parItems.length === 0 && !parError ? (
        <p className="text-base text-muted-foreground">
          {vi.trolley.noParItems}
        </p>
      ) : null}

      {trolleyWh && parItems.length > 0 ? (
        <TrolleyCountList
          items={parItems.map((p) => ({
            itemId: p.item_id,
            code: p.item_code,
            name: p.item_name,
            stockUom: p.stock_uom,
          }))}
          values={values}
          onChange={(itemId, value) =>
            setValues((prev) => ({ ...prev, [itemId]: value }))
          }
          disabled={!draftLoaded}
        />
      ) : null}

      {!online ? (
        <p className="rounded-xl border border-amber-300 bg-amber-50/60 p-3 text-base">
          {vi.offline.offlineQueuedNote}
        </p>
      ) : null}

      {error ? (
        <p className="rounded-xl border border-destructive/40 bg-destructive/5 p-3 text-base text-destructive">
          {error}
        </p>
      ) : null}

      <Button
        onClick={handleSubmit}
        disabled={
          !canOperate ||
          !trolleyWh ||
          parItems.length === 0 ||
          !countedAll ||
          submitting
        }
        className={cn("min-h-11 w-full text-base", !online && "opacity-90")}
      >
        {submitting
          ? vi.common.submitting
          : online
            ? vi.trolley.openSubmit
            : vi.trolley.openSubmitOffline}
      </Button>
      {!countedAll && parItems.length > 0 ? (
        <p className="text-base text-muted-foreground">
          {vi.trolley.countAllRequired}
        </p>
      ) : null}
    </div>
  );
}
