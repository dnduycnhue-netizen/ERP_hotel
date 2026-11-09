"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { listCountersAction, openCountAction } from "@/features/count/actions";
import type { CountCounter } from "@/features/count/queries";
import type { WarehouseRow } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

/**
 * Mở đợt kiểm kê (T-033): chọn kho → tải người được đếm tại kho
 * (RPC `count_list_counters`, T-033) → chọn người đếm → mở đợt.
 * Kiểm kê tháng cần ≥2 người đếm độc lập (server kiểm SoD lúc mở).
 * Mở đợt cần mạng (không xếp hàng offline được — đợt phải tồn tại trên
 * server trước khi ghi dòng).
 */
export function CountOpenForm({
  propertyId,
  warehouses,
  afterOpenHref,
}: {
  propertyId: string;
  warehouses: WarehouseRow[];
  /** Đường dẫn sau khi mở xong, nhận countId (vd. `/m/${p}/count/${id}`). */
  afterOpenHref: (countId: string) => string;
}) {
  const router = useRouter();
  // Ngày nghiệp vụ theo Asia/Ho_Chi_Minh (AGENTS.md §3.8) — không dùng
  // toISOString (UTC) vì rạng sáng giờ VN vẫn là ngày hôm trước ở UTC.
  const today = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  const [warehouseId, setWarehouseId] = useState(warehouses[0]?.id ?? "");
  const [kind, setKind] = useState<"monthly_full" | "cycle">("monthly_full");
  const [businessDate, setBusinessDate] = useState(today);
  const [counters, setCounters] = useState<CountCounter[]>([]);
  const [countersLoading, setCountersLoading] = useState(true);
  const [countersError, setCountersError] = useState<string | null>(null);
  const [selected, setSelected] = useState<string[]>([]);
  const [opening, setOpening] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Tải người được đếm khi đổi kho: setState chỉ nằm trong callback của
  // promise (không gọi đồng bộ trong effect — react-hooks/set-state-in-effect).
  useEffect(() => {
    if (!warehouseId) {
      return;
    }
    let cancelled = false;
    void listCountersAction({ propertyId, warehouseId }).then((res) => {
      if (cancelled) {
        return;
      }
      setCountersLoading(false);
      if (!res.ok) {
        setCountersError(res.error);
        setCounters([]);
        return;
      }
      setCounters(res.data);
    });
    return () => {
      cancelled = true;
    };
  }, [propertyId, warehouseId]);

  function handleWarehouseChange(id: string): void {
    setWarehouseId(id);
    setSelected([]);
    setCounters([]);
    setCountersError(null);
    setCountersLoading(true);
  }

  const needsTwo = kind === "monthly_full";
  const valid =
    warehouseId !== "" &&
    businessDate !== "" &&
    selected.length >= (needsTwo ? 2 : 1) &&
    !countersLoading;

  function toggleCounter(id: string): void {
    setSelected((prev) =>
      prev.includes(id) ? prev.filter((c) => c !== id) : [...prev, id],
    );
  }

  async function handleOpen(): Promise<void> {
    if (!valid || opening) {
      return;
    }
    setOpening(true);
    setError(null);
    const res = await openCountAction({
      warehouseId,
      kind,
      businessDate,
      counterIds: selected,
      clientUuid: crypto.randomUUID(),
    });
    setOpening(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.push(afterOpenHref(res.data.id));
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold">{vi.count.openTitle}</h1>

      <label className="flex flex-col gap-1.5 text-sm font-medium">
        {vi.count.warehouse} *
        <select
          value={warehouseId}
          onChange={(event) => handleWarehouseChange(event.target.value)}
          disabled={opening}
          className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
        >
          {warehouses.map((w) => (
            <option key={w.id} value={w.id}>
              {w.name} ({w.code})
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1.5 text-sm font-medium">
        {vi.count.kind} *
        <select
          value={kind}
          onChange={(event) =>
            setKind(event.target.value as "monthly_full" | "cycle")
          }
          disabled={opening}
          className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
        >
          <option value="monthly_full">{vi.count.kinds.monthlyFull}</option>
          <option value="cycle">{vi.count.kinds.cycle}</option>
        </select>
      </label>

      <label className="flex flex-col gap-1.5 text-sm font-medium">
        {vi.count.businessDate} *
        <input
          type="date"
          value={businessDate}
          onChange={(event) => setBusinessDate(event.target.value)}
          disabled={opening}
          className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
        />
      </label>

      <div className="flex flex-col gap-2">
        <p className="text-sm font-medium">{vi.count.counters} *</p>
        <p className="text-xs text-muted-foreground">{vi.count.countersHint}</p>
        {countersLoading ? (
          <p className="text-sm text-muted-foreground">{vi.common.loading}</p>
        ) : countersError ? (
          <p role="alert" className="text-sm text-destructive">
            {countersError}
          </p>
        ) : counters.length === 0 ? (
          <p className="text-sm text-muted-foreground">{vi.count.noCounters}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {counters.map((c) => {
              const checked = selected.includes(c.id);
              return (
                <li key={c.id}>
                  <label
                    className={`flex cursor-pointer items-center gap-3 rounded-lg border p-3 text-sm font-medium ${
                      checked ? "border-ring bg-muted/50" : ""
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => toggleCounter(c.id)}
                      disabled={opening}
                      className="size-5 accent-primary"
                    />
                    <span>
                      {c.full_name}
                      <span className="block text-xs font-normal text-muted-foreground">
                        {c.employee_code}
                      </span>
                    </span>
                  </label>
                </li>
              );
            })}
          </ul>
        )}
        {needsTwo && selected.length > 0 && selected.length < 2 ? (
          <p className="text-sm text-destructive">{vi.count.minCounters}</p>
        ) : null}
      </div>

      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}

      <Button
        size="lg"
        className="h-14 text-base"
        disabled={!valid || opening}
        onClick={() => void handleOpen()}
      >
        {opening ? vi.count.opening : vi.count.openButton}
      </Button>
    </div>
  );
}
