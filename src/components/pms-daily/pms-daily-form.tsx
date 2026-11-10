"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { upsertPmsDailyAction } from "@/features/pms-daily/actions";
import type { PmsDailyStatsRow } from "@/features/pms-daily/queries";
import { vi } from "@/i18n/vi";

type FieldKey =
  | "roomsAvailable"
  | "roomsSold"
  | "guests"
  | "breakfastPax"
  | "extraBeds"
  | "checkouts";

const FIELD_KEYS: FieldKey[] = [
  "roomsAvailable",
  "roomsSold",
  "guests",
  "breakfastPax",
  "extraBeds",
  "checkouts",
];

function initialValues(
  initial: PmsDailyStatsRow | null,
): Record<FieldKey, string> {
  return {
    roomsAvailable: initial ? String(initial.rooms_available) : "",
    roomsSold: initial ? String(initial.rooms_sold) : "",
    guests: initial ? String(initial.guests) : "",
    breakfastPax: initial ? String(initial.breakfast_pax) : "",
    extraBeds: initial ? String(initial.extra_beds) : "",
    checkouts: initial ? String(initial.checkouts) : "",
  };
}

/**
 * Form nhập số liệu vận hành ngày (T-036).
 * Ngày đã có số liệu thì hiện giá trị cũ; lưu lại sẽ cập nhật dòng đó
 * (không tạo dòng trùng) và ghi nhật ký sửa.
 */
export function PmsDailyForm({
  propertyId,
  businessDate,
  initial,
  canEnter,
  isFuture,
}: {
  propertyId: string;
  businessDate: string;
  initial: PmsDailyStatsRow | null;
  canEnter: boolean;
  isFuture: boolean;
}) {
  const [values, setValues] = useState<Record<FieldKey, string>>(() =>
    initialValues(initial),
  );
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const disabled = pending || !canEnter || isFuture;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setMessage(null);
    const nums = {} as Record<FieldKey, number>;
    for (const key of FIELD_KEYS) {
      const raw = values[key].trim();
      if (raw === "") {
        setError(vi.pmsDaily.fillAll);
        return;
      }
      const n = Number(raw);
      if (!Number.isInteger(n) || n < 0) {
        setError(vi.pmsDaily.fillAll);
        return;
      }
      nums[key] = n;
    }
    setPending(true);
    const res = await upsertPmsDailyAction({
      propertyId,
      businessDate,
      roomsAvailable: nums.roomsAvailable,
      roomsSold: nums.roomsSold,
      guests: nums.guests,
      breakfastPax: nums.breakfastPax,
      extraBeds: nums.extraBeds,
      checkouts: nums.checkouts,
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setMessage(
      res.data.is_new ? vi.pmsDaily.savedNew : vi.pmsDaily.savedUpdated,
    );
  }

  return (
    <form onSubmit={onSubmit} className="space-y-4">
      {initial ? (
        <p className="text-sm text-muted-foreground">
          {vi.pmsDaily.alreadyEntered}
        </p>
      ) : (
        <p className="text-sm text-muted-foreground">
          {vi.pmsDaily.notEnteredYet}
        </p>
      )}
      {isFuture && (
        <p className="text-sm text-destructive">{vi.pmsDaily.futureDate}</p>
      )}
      {!canEnter && (
        <p className="text-sm text-destructive">{vi.pmsDaily.noPermission}</p>
      )}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {FIELD_KEYS.map((key) => (
          <label key={key} className="block text-sm">
            {vi.pmsDaily.fields[key]}
            <input
              type="number"
              inputMode="numeric"
              min="0"
              step="1"
              value={values[key]}
              disabled={disabled}
              onChange={(e) =>
                setValues((v) => ({ ...v, [key]: e.target.value }))
              }
              className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
            />
          </label>
        ))}
      </div>
      {error && <p className="text-sm text-destructive">{error}</p>}
      {message && <p className="text-sm text-green-700">{message}</p>}
      <Button type="submit" disabled={disabled}>
        {pending ? vi.pmsDaily.saving : vi.pmsDaily.saveButton}
      </Button>
    </form>
  );
}
