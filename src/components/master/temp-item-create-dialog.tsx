"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import type { ItemGroupRow, UomRow } from "@/features/master/queries";
import { createTempItemAction } from "@/features/master/actions";

export function TempItemCreateDialog({
  propertyId,
  groups,
  uoms,
  open,
  onClose,
  onSuccess,
}: {
  propertyId: string;
  groups: ItemGroupRow[];
  uoms: UomRow[];
  open: boolean;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const [name, setName] = useState("");
  const [groupId, setGroupId] = useState(groups[0]?.id || "");
  const [stockUom, setStockUom] = useState(uoms[0]?.code || "kg");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [createdCode, setCreatedCode] = useState<string | null>(null);

  if (!open) return null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await createTempItemAction({
      propertyId,
      name,
      groupId,
      stockUom,
    });
    setSaving(false);

    if (res.ok) {
      setCreatedCode(res.data.code);
      onSuccess();
    } else {
      setError(res.error);
    }
  }

  function handleClose() {
    setName("");
    setGroupId(groups[0]?.id || "");
    setStockUom(uoms[0]?.code || "kg");
    setError(null);
    setCreatedCode(null);
    onClose();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-xl border bg-background p-6 shadow-lg">
        <div className="flex items-center justify-between border-b pb-3">
          <h2 className="text-lg font-semibold">
            {vi.master.items.createTempTitle}
          </h2>
          <Button variant="ghost" size="sm" onClick={handleClose}>
            ✕
          </Button>
        </div>

        <p className="mt-3 text-sm text-muted-foreground">
          {vi.master.items.createTempDescription}
        </p>

        {createdCode ? (
          <div className="mt-4 space-y-4">
            <div className="rounded-md border border-emerald-500/20 bg-emerald-500/10 p-3 text-sm text-emerald-700">
              {vi.master.items.createTempSuccess.replace("{code}", createdCode)}
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
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="temp-name"
              >
                {vi.master.items.name} *
              </label>
              <input
                id="temp-name"
                type="text"
                required
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder={vi.master.tempItem.examplePlaceholder}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>

            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="temp-group"
                >
                  {vi.master.items.group} *
                </label>
                <select
                  id="temp-group"
                  required
                  value={groupId}
                  onChange={(e) => setGroupId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  {groups.map((g) => (
                    <option key={g.id} value={g.id}>
                      {g.code_prefix} - {g.name}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="temp-uom"
                >
                  {vi.master.items.stockUom} *
                </label>
                <select
                  id="temp-uom"
                  required
                  value={stockUom}
                  onChange={(e) => setStockUom(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  {uoms.map((u) => (
                    <option key={u.code} value={u.code}>
                      {u.code} ({u.name_vi})
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 border-t pt-4">
              <Button type="button" variant="outline" onClick={handleClose}>
                {vi.common.cancel}
              </Button>
              <Button type="submit" disabled={saving}>
                {saving ? vi.common.loading : vi.master.items.createTempSubmit}
              </Button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
