"use client";

import { X } from "lucide-react";
import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { NumPad } from "@/components/common/num-pad";
import { recordCountLineAction } from "@/features/count/actions";
import type { CountItemDetail, CountSheetRow } from "@/features/count/queries";
import { vi } from "@/i18n/vi";
import { enqueueOfflineJob } from "@/lib/offline/db";
import { cn } from "@/lib/utils";
import {
  calcBottleTotal,
  calcUomTotal,
  formatQty,
  interpolate,
  parseDecimal,
} from "./count-utils";

type DetailEntry = { qty: number; uom: string };

/** Hệ số quy đổi 1 ĐVT mua về ĐVT lưu kho (1 nếu trùng ĐVT lưu kho). */
function factorFor(item: CountItemDetail, uom: string): number | null {
  if (uom === item.stock_uom) {
    return 1;
  }
  return (
    item.purchase_units.find((u) => u.uom === uom)?.factor_to_stock ?? null
  );
}

/** Đọc lại chi tiết đã ghi của chính mình (nếu có) để điền sẵn form. */
function parseMyDetail(detail: unknown): DetailEntry[] {
  if (!detail || typeof detail !== "object") {
    return [];
  }
  if (Array.isArray(detail)) {
    return detail
      .filter(
        (entry): entry is DetailEntry =>
          !!entry &&
          typeof entry === "object" &&
          typeof (entry as DetailEntry).qty === "number" &&
          typeof (entry as DetailEntry).uom === "string",
      )
      .map((entry) => ({ qty: entry.qty, uom: entry.uom }));
  }
  const entry = detail as DetailEntry;
  if (typeof entry.qty === "number" && typeof entry.uom === "string") {
    return [{ qty: entry.qty, uom: entry.uom }];
  }
  return [];
}

type UomRow = { qty: string; uom: string };

/**
 * Form ghi 1 dòng đếm (T-033, docs/06-UI-UX.md §3.2):
 * - Đếm theo đơn vị: nhiều dòng {số lượng, ĐVT} (mua theo quy cách khác
 *   nhau), tổng quy ra ĐVT lưu kho hiện ngay trên form.
 * - Cân chai: [chai nguyên tem] × hệ số mua mặc định + [gram chai mở]
 *   → ml = (gram − bì) ÷ tỉ trọng → quy ra ĐVT lưu kho; gửi server 1
 *   chi tiết duy nhất bằng ĐVT lưu kho.
 *
 * Chỉ hiện số của chính người đếm (my_counted_qty) — TUYỆT ĐỐI không hiện
 * số sổ / số lý thuyết / chênh lệch. Ghi lại ghi đè vòng của chính mình
 * (server). Mất mạng → xếp hàng Dexie, đồng bộ lại cùng clientUuid.
 */
export function MobileCountLineForm({
  line,
  item,
  countId,
  propertyId,
  canPerform,
  onSaved,
  onQueued,
  onClose,
}: {
  line: CountSheetRow;
  item: CountItemDetail;
  countId: string;
  propertyId: string;
  canPerform: boolean;
  onSaved: () => void;
  /** Ghi dòng lúc offline: xếp hàng chờ đồng bộ thay vì gọi server. */
  onQueued: () => void;
  onClose: () => void;
}) {
  const canBottle =
    item.tare_g !== null && item.density_g_ml !== null && item.density_g_ml > 0;
  const defaultUnit = item.purchase_units.find((u) => u.is_default) ?? null;
  const mlFactor =
    item.stock_uom === "ml"
      ? 1
      : (item.purchase_units.find((u) => u.uom === "ml")?.factor_to_stock ??
        null);

  const initialRows = useMemo(() => {
    const detail = parseMyDetail(line.my_count_detail);
    if (detail.length > 0) {
      return detail.map((entry) => ({
        qty: String(entry.qty),
        uom: entry.uom,
      }));
    }
    if (line.my_counted_qty !== null && line.my_counted_qty !== undefined) {
      return [{ qty: String(line.my_counted_qty), uom: item.stock_uom }];
    }
    return [{ qty: "", uom: item.stock_uom }];
  }, [line.my_count_detail, line.my_counted_qty, item.stock_uom]);

  const [mode, setMode] = useState<"uom" | "bottle">("uom");
  const [rows, setRows] = useState<UomRow[]>(initialRows);
  const [fullBottles, setFullBottles] = useState("");
  const [openGrams, setOpenGrams] = useState("");
  const [activeField, setActiveField] = useState<string>("row:0");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState<{
    countedQty: number;
    round: number;
  } | null>(null);
  const [queued, setQueued] = useState(false);

  const uomTotal = useMemo(
    () =>
      calcUomTotal(
        rows.map((row) => ({
          qty: parseDecimal(row.qty),
          factor: factorFor(item, row.uom),
        })),
      ),
    [rows, item],
  );

  const bottleCalc = useMemo(
    () =>
      calcBottleTotal({
        fullBottles: parseDecimal(fullBottles),
        openGrams: parseDecimal(openGrams),
        tareG: item.tare_g ?? 0,
        densityGml: item.density_g_ml ?? 0,
        defaultFactor: defaultUnit?.factor_to_stock ?? null,
        mlFactor,
      }),
    [fullBottles, openGrams, item, defaultUnit, mlFactor],
  );

  const total = mode === "uom" ? uomTotal : bottleCalc.total;
  // R30: tổng 0 là giá trị hợp lệ (đếm hết hàng); chỉ null (chưa nhập gì
  // hoặc nhập sai) mới không cho lưu.
  const valid = total !== null;

  function updateActiveField(value: string): void {
    if (activeField === "bottle:full") {
      setFullBottles(value);
      return;
    }
    if (activeField === "bottle:open") {
      setOpenGrams(value);
      return;
    }
    const match = activeField.match(/^row:(\d+)$/);
    if (!match) {
      return;
    }
    const index = Number(match[1]);
    setRows((prev) =>
      prev.map((row, i) => (i === index ? { ...row, qty: value } : row)),
    );
  }

  function activeValue(): string {
    if (activeField === "bottle:full") return fullBottles;
    if (activeField === "bottle:open") return openGrams;
    const match = activeField.match(/^row:(\d+)$/);
    if (!match) return "";
    return rows[Number(match[1])]?.qty ?? "";
  }

  async function handleSave(): Promise<void> {
    if (!valid || total === null || saving) {
      return;
    }
    setSaving(true);
    setError(null);
    const clientUuid = crypto.randomUUID();
    const detail =
      mode === "uom"
        ? rows.length > 1
          ? rows
              .map((row) => ({
                // R30: dòng chưa nhập (qty null) thì bỏ; dòng nhập 0 thì GIỮ
                // (hết hàng là giá trị hợp lệ, không được lọc như trước).
                qty: parseDecimal(row.qty),
                uom: row.uom,
              }))
              .filter(
                (entry): entry is { qty: number; uom: string } =>
                  entry.qty !== null,
              )
          : { qty: total, uom: rows[0]?.uom ?? item.stock_uom }
        : { qty: total, uom: item.stock_uom };
    const input = {
      countId,
      itemId: line.item_id,
      detail,
      bottleWeightG: null,
      clientUuid,
    };
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      try {
        await enqueueOfflineJob({
          propertyId,
          grId: null,
          countId,
          kind: "count_record",
          clientUuid,
          payload: { kind: "count_record", input },
          createdAt: Date.now(),
        });
      } catch {
        setSaving(false);
        setError(vi.offline.queueUnavailable);
        return;
      }
      setSaving(false);
      setQueued(true);
      onQueued();
      return;
    }
    const res = await recordCountLineAction(input);
    setSaving(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setSaved({ countedQty: res.data.counted_qty, round: res.data.round });
    onSaved();
  }

  if (saved) {
    return (
      <div className="flex flex-col gap-3 rounded-xl border bg-card p-4">
        <p className="text-sm font-medium">{vi.count.savedCount}</p>
        <p className="text-sm text-muted-foreground">
          {vi.count.countedQty}: {formatQty(saved.countedQty)} {item.stock_uom}{" "}
          · {interpolate(vi.count.round, { round: saved.round })}
        </p>
        <Button onClick={onClose}>{vi.common.close}</Button>
      </div>
    );
  }

  if (queued) {
    return (
      <div className="flex flex-col gap-3 rounded-xl border bg-card p-4">
        <p className="text-sm font-medium">{vi.count.queuedCount}</p>
        <Button onClick={onClose}>{vi.common.close}</Button>
      </div>
    );
  }

  const uomOptions = [
    item.stock_uom,
    ...item.purchase_units
      .map((u) => u.uom)
      .filter((uom) => uom !== item.stock_uom),
  ];

  return (
    <div className="flex flex-col gap-4 rounded-xl border bg-card p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="font-medium">
            {item.code} — {item.name}
          </p>
          <p className="text-sm text-muted-foreground">
            {vi.inventory.stockUom}: {item.stock_uom}
            {line.has_counted && line.my_counted_qty !== null ? (
              <>
                {" · "}
                {vi.count.lineCounted}: {formatQty(line.my_counted_qty)}{" "}
                {item.stock_uom}
              </>
            ) : null}
          </p>
        </div>
        <Button
          variant="ghost"
          size="sm"
          onClick={onClose}
          aria-label={vi.common.close}
          className="min-h-11 min-w-11"
        >
          <X className="size-4" />
        </Button>
      </div>

      {canBottle ? (
        <div className="flex gap-2" role="tablist">
          <Button
            variant={mode === "uom" ? "default" : "outline"}
            size="sm"
            onClick={() => setMode("uom")}
            className="min-h-11"
          >
            {vi.count.uomMode}
          </Button>
          <Button
            variant={mode === "bottle" ? "default" : "outline"}
            size="sm"
            onClick={() => setMode("bottle")}
            className="min-h-11"
          >
            {vi.count.bottleMode}
          </Button>
        </div>
      ) : null}

      {mode === "uom" ? (
        <div className="flex flex-col gap-3">
          {rows.map((row, index) => (
            <div key={index} className="flex gap-2">
              <button
                type="button"
                onClick={() => setActiveField(`row:${index}`)}
                aria-pressed={activeField === `row:${index}`}
                className={cn(
                  "h-14 flex-1 rounded-lg border bg-background px-3 text-left text-lg font-semibold tabular-nums outline-none",
                  activeField === `row:${index}` &&
                    "border-ring ring-2 ring-ring/50",
                )}
              >
                {row.qty === "" ? "—" : row.qty}
              </button>
              <select
                value={row.uom}
                onChange={(event) =>
                  setRows((prev) =>
                    prev.map((r, i) =>
                      i === index ? { ...r, uom: event.target.value } : r,
                    ),
                  )
                }
                disabled={saving}
                aria-label={vi.inventory.uom}
                className="h-14 w-28 rounded-lg border bg-background px-2 text-base outline-none focus:border-ring"
              >
                {uomOptions.map((uom) => (
                  <option key={uom} value={uom}>
                    {uom}
                  </option>
                ))}
              </select>
              {rows.length > 1 ? (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() =>
                    setRows((prev) => prev.filter((_, i) => i !== index))
                  }
                  aria-label={vi.count.removeRow}
                  className="min-h-11 min-w-11"
                >
                  <X className="size-4" />
                </Button>
              ) : null}
            </div>
          ))}
          <Button
            variant="outline"
            size="sm"
            onClick={() =>
              setRows((prev) => [...prev, { qty: "", uom: item.stock_uom }])
            }
            className="min-h-11"
          >
            {vi.count.addRow}
          </Button>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          <p className="text-xs text-muted-foreground">
            {vi.count.bottleUnitHint}
          </p>
          {defaultUnit ? (
            <button
              type="button"
              onClick={() => setActiveField("bottle:full")}
              aria-pressed={activeField === "bottle:full"}
              className={cn(
                "flex h-14 flex-col items-start justify-center rounded-lg border bg-background px-3 outline-none",
                activeField === "bottle:full" &&
                  "border-ring ring-2 ring-ring/50",
              )}
            >
              <span className="text-xs text-muted-foreground">
                {vi.count.fullBottles} ({defaultUnit.uom})
              </span>
              <span className="text-lg font-semibold tabular-nums">
                {fullBottles === "" ? "—" : fullBottles}
              </span>
            </button>
          ) : null}
          <button
            type="button"
            onClick={() => setActiveField("bottle:open")}
            aria-pressed={activeField === "bottle:open"}
            className={cn(
              "flex h-14 flex-col items-start justify-center rounded-lg border bg-background px-3 outline-none",
              activeField === "bottle:open" &&
                "border-ring ring-2 ring-ring/50",
            )}
          >
            <span className="text-xs text-muted-foreground">
              {vi.count.openBottleGrams}
            </span>
            <span className="text-lg font-semibold tabular-nums">
              {openGrams === "" ? "—" : `${openGrams} g`}
            </span>
          </button>
          {bottleCalc.openMl !== null ? (
            <p className="text-sm text-muted-foreground">
              {vi.count.openBottleMl}: {formatQty(bottleCalc.openMl)} ml
            </p>
          ) : null}
        </div>
      )}

      <p className="text-base font-semibold tabular-nums">
        {interpolate(vi.count.totalInStockUom, { uom: item.stock_uom })}:{" "}
        {total === null ? "—" : formatQty(total)}
      </p>

      {total === 0 ? (
        <p className="text-sm text-muted-foreground">
          {vi.count.zeroCountHint}
        </p>
      ) : null}

      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      {!canPerform ? (
        <p className="text-sm text-muted-foreground">{vi.count.notCounter}</p>
      ) : null}

      <NumPad value={activeValue()} onChange={updateActiveField} />

      <Button
        size="lg"
        className="h-14 text-base"
        disabled={!valid || saving || !canPerform}
        onClick={() => void handleSave()}
      >
        {saving ? vi.count.saving : vi.count.saveCount}
      </Button>
    </div>
  );
}
