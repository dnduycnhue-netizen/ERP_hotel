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
import type {
  OutletRow,
  OutletTypeRow,
  CostCenterRow,
} from "@/features/master/queries";
import {
  saveOutletAction,
  deleteOutletAction,
  saveOutletTypeAction,
} from "@/features/master/actions";

export function OutletsManager({
  propertyId,
  outlets,
  outletTypes,
  costCenters,
}: {
  propertyId: string;
  outlets: OutletRow[];
  outletTypes: OutletTypeRow[];
  costCenters: CostCenterRow[];
}) {
  const router = useRouter();
  const canManage = useCan("warehouse.manage");

  const [outletOpen, setOutletOpen] = useState(false);
  const [editingOutlet, setEditingOutlet] = useState<OutletRow | null>(null);
  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [outletTypeId, setOutletTypeId] = useState(outletTypes[0]?.id || "");
  const [costCenterId, setCostCenterId] = useState("");

  const [typeOpen, setTypeOpen] = useState(false);
  const [typeCode, setTypeCode] = useState("");
  const [typeName, setTypeName] = useState("");

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function startCreateOutlet() {
    setEditingOutlet(null);
    setCode("");
    setName("");
    setOutletTypeId(outletTypes[0]?.id || "");
    setCostCenterId("");
    setError(null);
    setOutletOpen(true);
  }

  function startEditOutlet(o: OutletRow) {
    setEditingOutlet(o);
    setCode(o.code);
    setName(o.name);
    setOutletTypeId(o.outlet_type_id);
    setCostCenterId(o.cost_center_id || "");
    setError(null);
    setOutletOpen(true);
  }

  async function handleSaveOutlet(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await saveOutletAction({
      id: editingOutlet?.id,
      propertyId,
      code,
      name,
      outletTypeId,
      costCenterId: costCenterId || null,
    });

    setSaving(false);
    if (res.ok) {
      setOutletOpen(false);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDeleteOutlet(o: OutletRow) {
    if (!confirm(vi.master.outlets.deleteConfirm)) return;
    setError(null);
    const res = await deleteOutletAction(propertyId, o.id);
    if (res.ok) {
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleSaveType(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await saveOutletTypeAction({
      propertyId,
      code: typeCode,
      name: typeName,
    });

    setSaving(false);
    if (res.ok) {
      setTypeOpen(false);
      setTypeCode("");
      setTypeName("");
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const columns: DataTableColumn<OutletRow>[] = [
    {
      key: "code",
      header: vi.master.outlets.code,
      cell: (row) => (
        <span className="font-mono font-bold text-xs">{row.code}</span>
      ),
    },
    {
      key: "name",
      header: vi.master.outlets.name,
      cell: (row) => <span className="font-medium">{row.name}</span>,
    },
    {
      key: "outlet_type",
      header: vi.master.outlets.outletType,
      cell: (row) => row.outlet_type_name || "—",
    },
    {
      key: "cost_center",
      header: vi.master.outlets.costCenter,
      cell: (row) => row.cost_center_name || "—",
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
              onClick={() => startEditOutlet(row)}
            >
              {vi.master.outlets.editOutlet}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
              onClick={() => handleDeleteOutlet(row)}
            >
              {vi.master.outlets.deleteOutlet}
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
        title={vi.master.outlets.title}
        description={vi.master.outlets.description}
        actions={
          canManage ? (
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setTypeOpen(true)}
              >
                + {vi.master.outlets.addOutletType}
              </Button>
              <Button
                size="sm"
                onClick={startCreateOutlet}
                disabled={outletTypes.length === 0}
              >
                + {vi.master.outlets.addOutlet}
              </Button>
            </div>
          ) : null
        }
      />

      <DataTable columns={columns} rows={outlets} />

      {/* Dialog thêm outlet */}
      {outletOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editingOutlet
                  ? vi.master.outlets.editOutlet
                  : vi.master.outlets.addOutlet}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setOutletOpen(false)}
              >
                ✕
              </Button>
            </div>

            <form onSubmit={handleSaveOutlet} className="mt-4 space-y-3">
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="outletCode"
                >
                  {vi.master.outlets.code} *
                </label>
                <input
                  id="outletCode"
                  required
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  placeholder="VD: KITCHEN, BAR, SPA"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm font-mono"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="outletName"
                >
                  {vi.master.outlets.name} *
                </label>
                <input
                  id="outletName"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="VD: Bếp chính, Quầy bar bể bơi"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="outletType"
                >
                  {vi.master.outlets.outletType} *
                </label>
                <select
                  id="outletType"
                  required
                  value={outletTypeId}
                  onChange={(e) => setOutletTypeId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  {outletTypes.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.code} - {t.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="costCenter"
                >
                  {vi.master.outlets.costCenter}
                </label>
                <select
                  id="costCenter"
                  value={costCenterId}
                  onChange={(e) => setCostCenterId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="">— Chưa gắn trung tâm chi phí —</option>
                  {costCenters.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.code} - {c.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setOutletOpen(false)}
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

      {/* Dialog thêm loại outlet */}
      {typeOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-sm rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {vi.master.outlets.addOutletType}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setTypeOpen(false)}
              >
                ✕
              </Button>
            </div>

            <form onSubmit={handleSaveType} className="mt-4 space-y-3">
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="outTypeCode"
                >
                  Mã loại outlet *
                </label>
                <input
                  id="outTypeCode"
                  required
                  value={typeCode}
                  onChange={(e) => setTypeCode(e.target.value)}
                  placeholder="VD: KITCHEN, BAR, REST"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm font-mono"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="outTypeName"
                >
                  Tên loại outlet *
                </label>
                <input
                  id="outTypeName"
                  required
                  value={typeName}
                  onChange={(e) => setTypeName(e.target.value)}
                  placeholder="VD: Bếp, Quầy Bar, Nhà hàng"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setTypeOpen(false)}
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
