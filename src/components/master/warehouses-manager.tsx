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
import { PageHeader } from "@/components/shell/page-header";
import type { WarehouseRow, OutletRow } from "@/features/master/queries";
import type { WarehouseSaveInput } from "@/features/master/schemas";
import {
  saveWarehouseAction,
  deleteWarehouseAction,
} from "@/features/master/actions";

const warehouseKinds = [
  { value: "main", label: "Kho tổng (Main)" },
  { value: "outlet", label: "Kho điểm bán (Outlet)" },
  { value: "floor", label: "Kho tầng (Floor)" },
  { value: "trolley", label: "Xe đẩy buồng phòng (Trolley)" },
  { value: "minibar_main", label: "Kho minibar tổng (Minibar Main)" },
  { value: "transit", label: "Kho trung chuyển (Transit)" },
  { value: "quarantine", label: "Kho cách ly / Chờ xử lý (Quarantine)" },
  { value: "disposal", label: "Kho chờ hủy (Disposal)" },
];

export function WarehousesManager({
  propertyId,
  warehouses,
  outlets,
}: {
  propertyId: string;
  warehouses: WarehouseRow[];
  outlets: OutletRow[];
}) {
  const router = useRouter();
  const canManage = useCan("warehouse.manage");

  const [open, setOpen] = useState(false);
  const [editingWarehouse, setEditingWarehouse] = useState<WarehouseRow | null>(
    null,
  );
  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [kind, setKind] = useState<WarehouseSaveInput["kind"]>("main");
  const [outletId, setOutletId] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function startCreate() {
    setEditingWarehouse(null);
    setCode("");
    setName("");
    setKind("main");
    setOutletId("");
    setError(null);
    setOpen(true);
  }

  function startEdit(w: WarehouseRow) {
    setEditingWarehouse(w);
    setCode(w.code);
    setName(w.name);
    setKind(w.kind as WarehouseSaveInput["kind"]);
    setOutletId(w.outlet_id || "");
    setError(null);
    setOpen(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    // Validate: outlet_id required for outlet, floor, trolley
    if (["outlet", "floor", "trolley"].includes(kind) && !outletId) {
      setError("Loại kho này bắt buộc phải gắn với một Outlet phụ trách.");
      setSaving(false);
      return;
    }

    const res = await saveWarehouseAction({
      id: editingWarehouse?.id,
      propertyId,
      code,
      name,
      kind,
      outletId: outletId || null,
    });

    setSaving(false);
    if (res.ok) {
      setOpen(false);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDelete(w: WarehouseRow) {
    if (!confirm(vi.master.warehouses.deleteConfirm)) return;
    setError(null);
    const res = await deleteWarehouseAction(propertyId, w.id);
    if (res.ok) {
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const columns: DataTableColumn<WarehouseRow>[] = [
    {
      key: "code",
      header: vi.master.warehouses.code,
      cell: (row) => (
        <span className="font-mono font-bold text-xs">{row.code}</span>
      ),
    },
    {
      key: "name",
      header: vi.master.warehouses.name,
      cell: (row) => <span className="font-medium">{row.name}</span>,
    },
    {
      key: "kind",
      header: vi.master.warehouses.kind,
      cell: (row) => {
        const found = warehouseKinds.find((k) => k.value === row.kind);
        return <span className="text-xs">{found?.label ?? row.kind}</span>;
      },
    },
    {
      key: "outlet",
      header: vi.master.warehouses.outlet,
      cell: (row) => row.outlet_name || "—",
    },
    {
      key: "actions",
      header: vi.common.actions,
      align: "right",
      cell: (row) =>
        canManage ? (
          <div className="flex items-center justify-end gap-1">
            <Button
              variant="outline"
              size="sm"
              className="text-xs h-7 px-2"
              onClick={() => startEdit(row)}
            >
              {vi.master.warehouses.editWarehouse}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
              onClick={() => handleDelete(row)}
            >
              {vi.master.warehouses.deleteWarehouse}
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

      <PageHeader
        title={vi.master.warehouses.title}
        description={vi.master.warehouses.description}
        actions={
          canManage ? (
            <Button size="sm" onClick={startCreate}>
              + {vi.master.warehouses.addWarehouse}
            </Button>
          ) : null
        }
      />

      <DataTable columns={columns} rows={warehouses} />

      {open ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editingWarehouse
                  ? vi.master.warehouses.editWarehouse
                  : vi.master.warehouses.addWarehouse}
              </h3>
              <Button variant="ghost" size="sm" onClick={() => setOpen(false)}>
                ✕
              </Button>
            </div>

            <form onSubmit={handleSave} className="mt-4 space-y-3">
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="whCode"
                >
                  {vi.master.warehouses.code} *
                </label>
                <input
                  id="whCode"
                  required
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  placeholder="VD: KHO_TONG, KHO_BEP"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="whName"
                >
                  {vi.master.warehouses.name} *
                </label>
                <input
                  id="whName"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="VD: Kho tổng khách sạn, Kho bếp chính"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="whKind"
                >
                  {vi.master.warehouses.kind} *
                </label>
                <select
                  id="whKind"
                  required
                  value={kind}
                  onChange={(e) =>
                    setKind(e.target.value as WarehouseSaveInput["kind"])
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  {warehouseKinds.map((k) => (
                    <option key={k.value} value={k.value}>
                      {k.label}
                    </option>
                  ))}
                </select>
              </div>

              {["outlet", "floor", "trolley"].includes(kind) ? (
                <div>
                  <label
                    className="text-xs font-medium text-muted-foreground"
                    htmlFor="whOutlet"
                  >
                    {vi.master.warehouses.outlet} *
                  </label>
                  <select
                    id="whOutlet"
                    required
                    value={outletId}
                    onChange={(e) => setOutletId(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  >
                    <option value="">— Chọn Outlet phụ trách —</option>
                    {outlets.map((o) => (
                      <option key={o.id} value={o.id}>
                        {o.code} - {o.name}
                      </option>
                    ))}
                  </select>
                </div>
              ) : null}

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
