"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  cancelBanquetAction,
  cancelBuffetSessionAction,
  closeBuffetSessionAction,
  completeBanquetAction,
  confirmBanquetAction,
  startBanquetAction,
} from "@/features/restaurant/actions";
import { vi } from "@/i18n/vi";

/**
 * Đóng phiên buffet — mobile (W4). Ghi qua RPC `buffet_session_close`
 * (kiểm quyền `restaurant.buffet.manage` ở server; doanh thu
 * = số khách × giá / khách do Postgres tính, trả về trong kết quả).
 */
export function MobileBuffetCloseForm({
  propertyId,
  sessionId,
  defaultGuestCount,
  defaultPricePerGuest,
}: {
  propertyId: string;
  sessionId: string;
  defaultGuestCount: number;
  defaultPricePerGuest: number | null;
}) {
  const router = useRouter();
  const [guestCount, setGuestCount] = useState(String(defaultGuestCount || ""));
  const [price, setPrice] = useState(
    defaultPricePerGuest !== null ? String(defaultPricePerGuest) : "",
  );
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  const canSubmit =
    !pending &&
    guestCount !== "" &&
    Number(guestCount) > 0 &&
    Number.isInteger(Number(guestCount)) &&
    price !== "" &&
    Number(price) >= 0;

  async function handleSubmit() {
    setPending(true);
    setError(null);
    setDone(null);
    const res = await closeBuffetSessionAction({
      propertyId,
      sessionId,
      guestCount: Number(guestCount),
      pricePerGuest: Number(price),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setDone(vi.restaurant.sessionClosed);
    router.refresh();
  }

  return (
    <div className="space-y-3 rounded-xl border bg-card p-4">
      <h2 className="text-base font-semibold">{vi.restaurant.closeSession}</h2>
      <p className="text-base text-muted-foreground">
        {vi.restaurant.closeSessionHint}
      </p>
      <label className="block text-base">
        {vi.restaurant.guestCount}
        <input
          type="number"
          inputMode="numeric"
          min={1}
          step={1}
          value={guestCount}
          onChange={(e) => setGuestCount(e.target.value)}
          className="mt-1 min-h-11 w-full rounded-md border bg-background px-3 py-2 text-base"
        />
      </label>
      <label className="block text-base">
        {vi.restaurant.pricePerGuest}
        <input
          type="number"
          inputMode="decimal"
          min={0}
          step={1000}
          value={price}
          onChange={(e) => setPrice(e.target.value)}
          className="mt-1 min-h-11 w-full rounded-md border bg-background px-3 py-2 text-base"
        />
      </label>
      <Button
        type="button"
        size="lg"
        className="min-h-11 w-full text-base"
        disabled={!canSubmit}
        onClick={handleSubmit}
      >
        {vi.restaurant.closeSession}
      </Button>
      {error ? <p className="text-base text-destructive">{error}</p> : null}
      {done ? <p className="text-base text-green-700">{done}</p> : null}
    </div>
  );
}

/** Hủy phiên buffet (cần nhập lý do) — mobile. */
export function MobileBuffetCancelButton({
  propertyId,
  sessionId,
}: {
  propertyId: string;
  sessionId: string;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleClick() {
    const reason = window.prompt(vi.restaurant.cancelReason);
    if (!reason || reason.trim() === "") return;
    setPending(true);
    setError(null);
    const res = await cancelBuffetSessionAction({
      propertyId,
      sessionId,
      reason: reason.trim(),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.refresh();
  }

  return (
    <span className="inline-flex flex-col items-start gap-1">
      <Button
        type="button"
        variant="outline"
        className="min-h-11 text-base"
        disabled={pending}
        onClick={handleClick}
      >
        {vi.restaurant.cancelSession}
      </Button>
      {error ? (
        <span className="text-base text-destructive">{error}</span>
      ) : null}
    </span>
  );
}

/** Các nút đổi trạng thái tiệc — mobile (nút ≥ 44px, theo trạng thái). */
export function MobileBanquetStatusButtons({
  propertyId,
  banquetId,
  status,
}: {
  propertyId: string;
  banquetId: string;
  status: string;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(
    fn: (input: {
      propertyId: string;
      banquetId: string;
    }) => Promise<{ ok: boolean; error?: string }>,
  ) {
    setPending(true);
    setError(null);
    const res = await fn({ propertyId, banquetId });
    setPending(false);
    if (!res.ok) {
      setError(res.error ?? vi.common.genericError);
      return;
    }
    router.refresh();
  }

  async function handleCancel() {
    const reason = window.prompt(vi.restaurant.cancelReason);
    if (!reason || reason.trim() === "") return;
    setPending(true);
    setError(null);
    const res = await cancelBanquetAction({
      propertyId,
      banquetId,
      reason: reason.trim(),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.refresh();
  }

  const buttons: Array<{ label: string; action: () => void }> = [];
  if (status === "new") {
    buttons.push({
      label: vi.restaurant.confirmBanquet,
      action: () => void run(confirmBanquetAction),
    });
    buttons.push({ label: vi.restaurant.cancelBanquet, action: handleCancel });
  } else if (status === "confirmed") {
    buttons.push({
      label: vi.restaurant.startBanquet,
      action: () => void run(startBanquetAction),
    });
    buttons.push({ label: vi.restaurant.cancelBanquet, action: handleCancel });
  } else if (status === "in_progress") {
    buttons.push({
      label: vi.restaurant.completeBanquet,
      action: () => void run(completeBanquetAction),
    });
  }
  if (buttons.length === 0) return null;

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap gap-2">
        {buttons.map((b) => (
          <Button
            key={b.label}
            type="button"
            variant="outline"
            className="min-h-11 text-base"
            disabled={pending}
            onClick={b.action}
          >
            {b.label}
          </Button>
        ))}
      </div>
      {error ? <p className="text-base text-destructive">{error}</p> : null}
    </div>
  );
}
