"use client";

import { InlineConfirmButton } from "@/components/common/inline-confirm-button";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  cancelBanquetAction,
  cancelBuffetSessionAction,
  closeBuffetSessionAction,
  completeBanquetAction,
  confirmBanquetAction,
  setRecipeActiveAction,
  startBanquetAction,
  voidDishSaleAction,
} from "@/features/restaurant/actions";
import { vi } from "@/i18n/vi";

/** Nút đổi trạng thái món (bật / tắt bán). */
export function ToggleDishButton({
  propertyId,
  recipeId,
  isActive,
}: {
  propertyId: string;
  recipeId: string;
  isActive: boolean;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleClick() {
    setPending(true);
    setError(null);
    const res = await setRecipeActiveAction({
      propertyId,
      recipeId,
      isActive: !isActive,
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
      <InlineConfirmButton
        variant="outline"
        label={vi.restaurant.voidSale}
        confirmText={vi.restaurant.saleVoidConfirm}
        onConfirm={handleClick}
        disabled={pending}
      />
      {error ? <span className="text-xs text-destructive">{error}</span> : null}
    </span>
  );
}

function StatusButton({
  label,
  confirmText,
  onAction,
}: {
  label: string;
  confirmText?: string;
  onAction: () => Promise<{ ok: boolean; error?: string }>;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleClick() {
    if (confirmText && !window.confirm(confirmText)) return;
    setPending(true);
    setError(null);
    const res = await onAction();
    setPending(false);
    if (!res.ok) {
      setError(res.error ?? vi.common.genericError);
      return;
    }
    router.refresh();
  }

  return (
    <span className="inline-flex flex-col items-start gap-1">
      <Button
        type="button"
        variant="outline"
        size="sm"
        disabled={pending}
        onClick={handleClick}
      >
        {label}
      </Button>
      {error ? <span className="text-xs text-destructive">{error}</span> : null}
    </span>
  );
}

/** Các nút đổi trạng thái tiệc. */
export function BanquetStatusButtons({
  propertyId,
  banquetId,
  status,
}: {
  propertyId: string;
  banquetId: string;
  status: string;
}) {
  if (status === "new") {
    return (
      <div className="flex flex-wrap gap-2">
        <StatusButton
          label={vi.restaurant.confirmBanquet}
          onAction={() => confirmBanquetAction({ propertyId, banquetId })}
        />
        <CancelBanquetButton propertyId={propertyId} banquetId={banquetId} />
      </div>
    );
  }
  if (status === "confirmed") {
    return (
      <div className="flex flex-wrap gap-2">
        <StatusButton
          label={vi.restaurant.startBanquet}
          onAction={() => startBanquetAction({ propertyId, banquetId })}
        />
        <CancelBanquetButton propertyId={propertyId} banquetId={banquetId} />
      </div>
    );
  }
  if (status === "in_progress") {
    return (
      <div className="flex flex-wrap gap-2">
        <StatusButton
          label={vi.restaurant.completeBanquet}
          onAction={() => completeBanquetAction({ propertyId, banquetId })}
        />
      </div>
    );
  }
  return null;
}

/** Hủy tiệc (cần nhập lý do). */
export function CancelBanquetButton({
  propertyId,
  banquetId,
}: {
  propertyId: string;
  banquetId: string;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleClick() {
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

  return (
    <span className="inline-flex flex-col items-start gap-1">
      <Button
        type="button"
        variant="outline"
        size="sm"
        disabled={pending}
        onClick={handleClick}
      >
        {vi.restaurant.cancelBanquet}
      </Button>
      {error ? <span className="text-xs text-destructive">{error}</span> : null}
    </span>
  );
}

/** Đóng phiên buffet (nhập số khách + giá / khách). */
export function CloseBuffetForm({
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
    <div className="space-y-2 rounded-lg border p-4">
      <h2 className="text-sm font-semibold">{vi.restaurant.closeSession}</h2>
      <p className="text-sm text-muted-foreground">
        {vi.restaurant.closeSessionHint}
      </p>
      <div className="flex flex-wrap items-end gap-3">
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.guestCount}</span>
          <input
            type="number"
            min={1}
            step={1}
            value={guestCount}
            onChange={(e) => setGuestCount(e.target.value)}
            className="h-9 w-32 rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.pricePerGuest}
          </span>
          <input
            type="number"
            min={0}
            step={1000}
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            className="h-9 w-40 rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <Button type="button" disabled={!canSubmit} onClick={handleSubmit}>
          {vi.restaurant.closeSession}
        </Button>
      </div>
      {error ? <p className="text-sm text-destructive">{error}</p> : null}
      {done ? <p className="text-sm text-green-700">{done}</p> : null}
    </div>
  );
}

/** Hủy phiên buffet (cần nhập lý do). */
export function CancelBuffetButton({
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
        size="sm"
        disabled={pending}
        onClick={handleClick}
      >
        {vi.restaurant.cancelSession}
      </Button>
      {error ? <span className="text-xs text-destructive">{error}</span> : null}
    </span>
  );
}

/** Hủy dòng bán tay ghi sai. */
export function VoidSaleButton({
  propertyId,
  saleId,
}: {
  propertyId: string;
  saleId: string;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleClick() {
    setPending(true);
    setError(null);
    const res = await voidDishSaleAction({ propertyId, saleId });
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
        size="sm"
        disabled={pending}
        onClick={handleClick}
      >
        {vi.restaurant.voidSale}
      </Button>
      {error ? <span className="text-xs text-destructive">{error}</span> : null}
    </span>
  );
}
