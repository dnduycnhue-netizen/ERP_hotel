"use client";

import { useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import type { ItemRow, MergeTargetRow } from "@/features/master/queries";
import {
  mergeItemAction,
  searchMergeTargetsAction,
} from "@/features/master/actions";

export function ItemMergeDialog({
  propertyId,
  item,
  open,
  onClose,
  onSuccess,
}: {
  propertyId: string;
  item: ItemRow;
  open: boolean;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const [search, setSearch] = useState("");
  const [targets, setTargets] = useState<MergeTargetRow[]>([]);
  const [searching, setSearching] = useState(true);
  const [selected, setSelected] = useState<MergeTargetRow | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [merged, setMerged] = useState<{
    into: string;
    count: number;
  } | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!open) return;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(async () => {
      const res = await searchMergeTargetsAction({ propertyId, search });
      setSearching(false);
      if (res.ok) {
        setTargets(res.data.targets);
      } else {
        setTargets([]);
      }
    }, 300);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [open, propertyId, search]);

  if (!open) return null;

  const uomMismatch =
    selected !== null && selected.stock_uom !== item.stock_uom;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!selected) return;
    if (
      !window.confirm(
        vi.master.items.mergeConfirm
          .replace("{from}", item.code)
          .replace("{into}", selected.code),
      )
    ) {
      return;
    }
    setSaving(true);
    setError(null);

    const res = await mergeItemAction({
      propertyId,
      fromId: item.id,
      intoId: selected.id,
    });
    setSaving(false);

    if (res.ok) {
      setMerged({ into: selected.code, count: res.data.moved_count });
      onSuccess();
    } else {
      setError(res.error);
    }
  }

  function handleClose() {
    setSearch("");
    setTargets([]);
    setSelected(null);
    setError(null);
    setMerged(null);
    onClose();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-xl border bg-background p-6 shadow-lg">
        <div className="flex items-center justify-between border-b pb-3">
          <h2 className="text-lg font-semibold">
            {vi.master.items.mergeTitle}
          </h2>
          <Button variant="ghost" size="sm" onClick={handleClose}>
            ✕
          </Button>
        </div>

        <p className="mt-3 text-sm text-muted-foreground">
          {vi.master.items.mergeDescription}
        </p>

        {merged ? (
          <div className="mt-4 space-y-4">
            <div className="rounded-md border border-emerald-500/20 bg-emerald-500/10 p-3 text-sm text-emerald-700">
              {vi.master.items.mergeSuccess
                .replace("{from}", item.code)
                .replace("{into}", merged.into)
                .replace("{count}", String(merged.count))}
            </div>
            <div className="flex justify-end">
              <Button onClick={handleClose}>{vi.common.close}</Button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="mt-4 space-y-4">
            {error ? (
              <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
                {error}
              </div>
            ) : null}

            <div>
              <span className="text-xs font-medium text-muted-foreground">
                {vi.master.items.mergeSource}
              </span>
              <div className="mt-1 rounded-md border bg-muted/50 px-3 py-2 text-sm">
                <span className="font-mono font-semibold">{item.code}</span>
                {" — "}
                {item.name} ({item.stock_uom})
              </div>
            </div>

            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="merge-target"
              >
                {vi.master.items.mergeTarget} *
              </label>
              <input
                id="merge-target"
                type="text"
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value);
                  setSelected(null);
                  setSearching(true);
                }}
                placeholder={vi.master.items.mergeTargetPlaceholder}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
              <div className="mt-2 max-h-48 space-y-1 overflow-y-auto">
                {searching ? (
                  <p className="px-2 py-1 text-sm text-muted-foreground">
                    {vi.common.loading}
                  </p>
                ) : targets.length === 0 ? (
                  <p className="px-2 py-1 text-sm text-muted-foreground">
                    {vi.master.items.mergeTargetEmpty}
                  </p>
                ) : (
                  targets.map((t) => (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => setSelected(t)}
                      className={`w-full rounded-md border px-3 py-2 text-left text-sm hover:bg-accent ${
                        selected?.id === t.id
                          ? "border-primary bg-primary/10"
                          : ""
                      }`}
                    >
                      <span className="font-mono font-semibold">{t.code}</span>
                      {" — "}
                      {t.name} ({t.stock_uom})
                    </button>
                  ))
                )}
              </div>
              {uomMismatch ? (
                <p className="mt-2 rounded-md border border-amber-500/30 bg-amber-500/10 p-2 text-xs text-amber-700">
                  {vi.master.items.mergeUomMismatch}
                </p>
              ) : null}
            </div>

            <div className="flex items-center justify-end gap-3 border-t pt-4">
              <Button type="button" variant="outline" onClick={handleClose}>
                {vi.common.cancel}
              </Button>
              <Button type="submit" disabled={saving || !selected}>
                {saving ? vi.common.loading : vi.master.items.mergeSubmit}
              </Button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
