"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import type { UomRow } from "@/features/master/queries";
import { saveUomAction } from "@/features/master/actions";

export function UomsManager({
  propertyId,
  uoms,
}: {
  propertyId: string;
  uoms: UomRow[];
}) {
  const router = useRouter();
  const canManage = useCan("item.manage");

  const [open, setOpen] = useState(false);
  const [editingUom, setEditingUom] = useState<UomRow | null>(null);
  const [code, setCode] = useState("");
  const [nameVi, setNameVi] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function startCreate() {
    setEditingUom(null);
    setCode("");
    setNameVi("");
    setError(null);
    setOpen(true);
  }

  function startEdit(u: UomRow) {
    setEditingUom(u);
    setCode(u.code);
    setNameVi(u.name_vi);
    setError(null);
    setOpen(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await saveUomAction(propertyId, { code, nameVi });
    setSaving(false);
    if (res.ok) {
      setOpen(false);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const columns: DataTableColumn<UomRow>[] = [
    {
      key: "code",
      header: vi.master.uoms.code,
      cell: (row) => (
        <span className="font-mono font-bold text-xs">{row.code}</span>
      ),
    },
    {
      key: "name_vi",
      header: vi.master.uoms.nameVi,
      cell: (row) => <span className="font-medium">{row.name_vi}</span>,
    },
    {
      key: "actions",
      header: vi.common.actions,
      align: "right",
      cell: (row) =>
        canManage ? (
          <div className="flex items-center justify-end">
            <Button
              variant="outline"
              size="sm"
              className="text-xs h-7 px-2"
              onClick={() => startEdit(row)}
            >
              {vi.master.uoms.editUom}
            </Button>
          </div>
        ) : null,
    },
  ];

  return (
    <div className="space-y-4">
      {error ? (
        <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}

      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold">{vi.master.uoms.title}</h2>
          <p className="text-xs text-muted-foreground mt-0.5">
            {vi.master.uoms.description}
          </p>
        </div>
        {canManage ? (
          <Button size="sm" onClick={startCreate}>
            + {vi.master.uoms.addUom}
          </Button>
        ) : null}
      </div>

      <DataTable
        columns={columns}
        rows={uoms.map((u) => ({ ...u, id: u.code }))}
      />

      {open ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-sm rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editingUom ? vi.master.uoms.editUom : vi.master.uoms.addUom}
              </h3>
              <Button variant="ghost" size="sm" onClick={() => setOpen(false)}>
                ✕
              </Button>
            </div>

            <form onSubmit={handleSave} className="mt-4 space-y-3">
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="uomCode"
                >
                  {vi.master.uoms.code} *
                </label>
                <input
                  id="uomCode"
                  required
                  disabled={Boolean(editingUom)}
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  placeholder="VD: thung, hop, lon"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm font-mono disabled:opacity-60"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="uomName"
                >
                  {vi.master.uoms.nameVi} *
                </label>
                <input
                  id="uomName"
                  required
                  value={nameVi}
                  onChange={(e) => setNameVi(e.target.value)}
                  placeholder="VD: Thùng, Hộp, Lon"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setOpen(false)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={saving}>
                  {saving ? vi.common.loading : vi.common.save}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  );
}
