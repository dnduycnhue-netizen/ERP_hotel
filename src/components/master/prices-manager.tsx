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
import type {
  PriceAgreementRow,
  PriceAgreementLineRow,
  CeilingPriceRow,
  SupplierRow,
  ItemRow,
  UomRow,
} from "@/features/master/queries";
import {
  savePriceAgreementAction,
  deletePriceAgreementAction,
  savePriceAgreementLineAction,
  deletePriceAgreementLineAction,
  saveCeilingPriceAction,
  deleteCeilingPriceAction,
  listPriceAgreementLinesAction,
} from "@/features/master/actions";

function agreementStatusLabel(status: string): string {
  switch (status) {
    case "draft":
      return vi.master.prices.statusDraft;
    case "active":
      return vi.master.prices.statusActive;
    case "expired":
      return vi.master.prices.statusExpired;
    case "cancelled":
      return vi.master.prices.statusCancelled;
    default:
      return status;
  }
}

function fmtDate(value: string): string {
  return new Date(value).toLocaleDateString("vi-VN");
}

export function PricesManager({
  propertyId,
  suppliers,
  items,
  uoms,
  agreements,
  ceilings,
}: {
  propertyId: string;
  suppliers: SupplierRow[];
  items: ItemRow[];
  uoms: UomRow[];
  agreements: PriceAgreementRow[];
  ceilings: CeilingPriceRow[];
}) {
  const router = useRouter();
  const canManageAgreements = useCan("price.agreement.manage");
  const canManageCeilings = useCan("price.ceiling.manage");

  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // Hop dong khung
  const [agreementOpen, setAgreementOpen] = useState(false);
  const [editingAgreement, setEditingAgreement] =
    useState<PriceAgreementRow | null>(null);
  const [agreementSupplierId, setAgreementSupplierId] = useState("");
  const [agreementValidFrom, setAgreementValidFrom] = useState("");
  const [agreementValidTo, setAgreementValidTo] = useState("");
  const [agreementStatus, setAgreementStatus] = useState<
    "draft" | "active" | "expired" | "cancelled"
  >("draft");
  const [agreementSaving, setAgreementSaving] = useState(false);

  // Dong gia cua hop dong dang mo
  const [openAgreement, setOpenAgreement] = useState<PriceAgreementRow | null>(
    null,
  );
  const [lines, setLines] = useState<PriceAgreementLineRow[]>([]);
  const [linesLoading, setLinesLoading] = useState(false);
  const [lineOpen, setLineOpen] = useState(false);
  const [editingLine, setEditingLine] = useState<PriceAgreementLineRow | null>(
    null,
  );
  const [lineItemId, setLineItemId] = useState("");
  const [lineUom, setLineUom] = useState("");
  const [lineUnitPrice, setLineUnitPrice] = useState("");
  const [lineWarnPct, setLineWarnPct] = useState("");
  const [lineLockPct, setLineLockPct] = useState("");
  const [lineSaving, setLineSaving] = useState(false);

  // Gia tran
  const [ceilingOpen, setCeilingOpen] = useState(false);
  const [editingCeiling, setEditingCeiling] = useState<CeilingPriceRow | null>(
    null,
  );
  const [ceilingScope, setCeilingScope] = useState<"chain" | "property">(
    "property",
  );
  const [ceilingItemId, setCeilingItemId] = useState("");
  const [ceilingUom, setCeilingUom] = useState("");
  const [ceilingPrice, setCeilingPrice] = useState("");
  const [ceilingValidFrom, setCeilingValidFrom] = useState("");
  const [ceilingValidTo, setCeilingValidTo] = useState("");
  const [ceilingSaving, setCeilingSaving] = useState(false);

  function startCreateAgreement() {
    setEditingAgreement(null);
    setAgreementSupplierId("");
    setAgreementValidFrom("");
    setAgreementValidTo("");
    setAgreementStatus("draft");
    setError(null);
    setAgreementOpen(true);
  }

  function startEditAgreement(a: PriceAgreementRow) {
    setEditingAgreement(a);
    setAgreementSupplierId(a.supplier_id);
    setAgreementValidFrom(a.valid_from);
    setAgreementValidTo(a.valid_to);
    setAgreementStatus(
      a.status as "draft" | "active" | "expired" | "cancelled",
    );
    setError(null);
    setAgreementOpen(true);
  }

  async function handleSaveAgreement(e: React.FormEvent) {
    e.preventDefault();
    setAgreementSaving(true);
    setError(null);
    const res = await savePriceAgreementAction({
      id: editingAgreement?.id,
      propertyId,
      supplierId: agreementSupplierId,
      validFrom: agreementValidFrom,
      validTo: agreementValidTo,
      status: agreementStatus,
    });
    setAgreementSaving(false);
    if (res.ok) {
      setAgreementOpen(false);
      setNotice(vi.master.prices.savedSuccess);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDeleteAgreement(a: PriceAgreementRow) {
    if (!confirm(vi.master.prices.deleteAgreementConfirm)) return;
    setError(null);
    const res = await deletePriceAgreementAction(propertyId, a.id);
    if (res.ok) {
      if (openAgreement?.id === a.id) setOpenAgreement(null);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function openLines(a: PriceAgreementRow) {
    setOpenAgreement(a);
    setLinesLoading(true);
    const rows = await listPriceAgreementLinesAction(a.id);
    setLines(rows);
    setLinesLoading(false);
  }

  function startCreateLine() {
    setEditingLine(null);
    setLineItemId("");
    setLineUom("");
    setLineUnitPrice("");
    setLineWarnPct("");
    setLineLockPct("");
    setError(null);
    setLineOpen(true);
  }

  function startEditLine(l: PriceAgreementLineRow) {
    setEditingLine(l);
    setLineItemId(l.item_id);
    setLineUom(l.uom);
    setLineUnitPrice(String(l.unit_price));
    setLineWarnPct(l.warn_pct === null ? "" : String(l.warn_pct));
    setLineLockPct(l.lock_pct === null ? "" : String(l.lock_pct));
    setError(null);
    setLineOpen(true);
  }

  async function handleSaveLine(e: React.FormEvent) {
    e.preventDefault();
    if (!openAgreement) return;
    setLineSaving(true);
    setError(null);
    const res = await savePriceAgreementLineAction({
      id: editingLine?.id,
      propertyId,
      agreementId: openAgreement.id,
      itemId: lineItemId,
      uom: lineUom,
      unitPrice: Number(lineUnitPrice),
      warnPct: lineWarnPct === "" ? null : Number(lineWarnPct),
      lockPct: lineLockPct === "" ? null : Number(lineLockPct),
    });
    setLineSaving(false);
    if (res.ok) {
      setLineOpen(false);
      setNotice(vi.master.prices.savedSuccess);
      const rows = await listPriceAgreementLinesAction(openAgreement.id);
      setLines(rows);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDeleteLine(l: PriceAgreementLineRow) {
    if (!confirm(vi.master.prices.deleteLine)) return;
    setError(null);
    const res = await deletePriceAgreementLineAction(propertyId, l.id);
    if (res.ok && openAgreement) {
      const rows = await listPriceAgreementLinesAction(openAgreement.id);
      setLines(rows);
      router.refresh();
    } else if (!res.ok) {
      setError(res.error);
    }
  }

  function startCreateCeiling() {
    setEditingCeiling(null);
    setCeilingScope("property");
    setCeilingItemId("");
    setCeilingUom("");
    setCeilingPrice("");
    setCeilingValidFrom("");
    setCeilingValidTo("");
    setError(null);
    setCeilingOpen(true);
  }

  function startEditCeiling(c: CeilingPriceRow) {
    setEditingCeiling(c);
    setCeilingScope(c.property_id ? "property" : "chain");
    setCeilingItemId(c.item_id);
    setCeilingUom(c.uom);
    setCeilingPrice(String(c.price));
    setCeilingValidFrom(c.valid_from);
    setCeilingValidTo(c.valid_to);
    setError(null);
    setCeilingOpen(true);
  }

  async function handleSaveCeiling(e: React.FormEvent) {
    e.preventDefault();
    setCeilingSaving(true);
    setError(null);
    const res = await saveCeilingPriceAction({
      id: editingCeiling?.id,
      propertyId,
      propertyScopeId: ceilingScope === "property" ? propertyId : null,
      itemId: ceilingItemId,
      uom: ceilingUom,
      price: Number(ceilingPrice),
      validFrom: ceilingValidFrom,
      validTo: ceilingValidTo,
    });
    setCeilingSaving(false);
    if (res.ok) {
      setCeilingOpen(false);
      setNotice(vi.master.prices.savedSuccess);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDeleteCeiling(c: CeilingPriceRow) {
    if (!confirm(vi.master.prices.deleteCeilingConfirm)) return;
    setError(null);
    const res = await deleteCeilingPriceAction(propertyId, c.id);
    if (res.ok) {
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const agreementColumns: DataTableColumn<PriceAgreementRow>[] = [
    {
      key: "supplier",
      header: vi.master.prices.supplier,
      cell: (row) => (
        <span className="font-medium">
          {row.supplier_code ? `${row.supplier_code} · ` : ""}
          {row.supplier_name ?? row.supplier_id}
        </span>
      ),
    },
    {
      key: "valid",
      header: `${vi.master.prices.validFrom} → ${vi.master.prices.validTo}`,
      cell: (row) => `${fmtDate(row.valid_from)} → ${fmtDate(row.valid_to)}`,
    },
    {
      key: "status",
      header: vi.master.prices.status,
      cell: (row) => agreementStatusLabel(row.status),
    },
    {
      key: "actions",
      header: vi.common.actions,
      align: "right",
      cell: (row) => (
        <div className="flex items-center justify-end gap-1">
          <Button
            variant="outline"
            size="sm"
            className="text-xs h-7 px-2"
            onClick={() => openLines(row)}
          >
            {vi.master.prices.linesTitle}
          </Button>
          {canManageAgreements ? (
            <>
              <Button
                variant="outline"
                size="sm"
                className="text-xs h-7 px-2"
                onClick={() => startEditAgreement(row)}
              >
                {vi.master.prices.editAgreement}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
                onClick={() => handleDeleteAgreement(row)}
              >
                {vi.master.prices.deleteAgreement}
              </Button>
            </>
          ) : null}
        </div>
      ),
    },
  ];

  const ceilingColumns: DataTableColumn<CeilingPriceRow>[] = [
    {
      key: "item",
      header: vi.master.prices.item,
      cell: (row) => (
        <span className="font-medium">
          {row.item_code ? `${row.item_code} · ` : ""}
          {row.item_name ?? row.item_id}
        </span>
      ),
    },
    {
      key: "uom",
      header: vi.master.prices.uom,
      cell: (row) => row.uom,
    },
    {
      key: "price",
      header: vi.master.prices.price,
      align: "right",
      cell: (row) => row.price.toLocaleString("vi-VN"),
    },
    {
      key: "scope",
      header: vi.master.prices.scope,
      cell: (row) =>
        row.property_id
          ? vi.master.prices.scopeProperty
          : vi.master.prices.scopeChain,
    },
    {
      key: "valid",
      header: `${vi.master.prices.validFrom} → ${vi.master.prices.validTo}`,
      cell: (row) => `${fmtDate(row.valid_from)} → ${fmtDate(row.valid_to)}`,
    },
    {
      key: "actions",
      header: vi.common.actions,
      align: "right",
      cell: (row) =>
        canManageCeilings ? (
          <div className="flex items-center justify-end gap-1">
            <Button
              variant="outline"
              size="sm"
              className="text-xs h-7 px-2"
              onClick={() => startEditCeiling(row)}
            >
              {vi.master.prices.editCeiling}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
              onClick={() => handleDeleteCeiling(row)}
            >
              {vi.master.prices.deleteCeiling}
            </Button>
          </div>
        ) : null,
    },
  ];

  return (
    <div className="space-y-8">
      {error ? (
        <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}
      {notice ? (
        <div className="rounded-md border border-emerald-500/20 bg-emerald-500/10 p-3 text-sm text-emerald-700">
          {notice}
        </div>
      ) : null}

      <div className="space-y-4">
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <div>
            <h2 className="text-lg font-semibold">
              {vi.master.prices.agreementsTitle}
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {vi.master.prices.overlapNote}
            </p>
          </div>
          {canManageAgreements ? (
            <Button size="sm" onClick={startCreateAgreement}>
              + {vi.master.prices.addAgreement}
            </Button>
          ) : null}
        </div>

        <DataTable columns={agreementColumns} rows={agreements} />

        {openAgreement ? (
          <div className="rounded-xl border p-4 space-y-3">
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-sm">
                {vi.master.prices.linesTitle} —{" "}
                {openAgreement.supplier_code ?? openAgreement.supplier_id} ·{" "}
                {fmtDate(openAgreement.valid_from)} →{" "}
                {fmtDate(openAgreement.valid_to)}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setOpenAgreement(null)}
              >
                ✕
              </Button>
            </div>
            {linesLoading ? (
              <p className="text-sm text-muted-foreground">
                {vi.common.loading}
              </p>
            ) : (
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left text-xs text-muted-foreground">
                    <th className="py-2 pr-2">{vi.master.prices.item}</th>
                    <th className="py-2 pr-2">{vi.master.prices.uom}</th>
                    <th className="py-2 pr-2 text-right">
                      {vi.master.prices.unitPrice}
                    </th>
                    <th className="py-2 pr-2 text-right">
                      {vi.master.prices.warnPct}
                    </th>
                    <th className="py-2 pr-2 text-right">
                      {vi.master.prices.lockPct}
                    </th>
                    <th className="py-2 text-right">{vi.common.actions}</th>
                  </tr>
                </thead>
                <tbody>
                  {lines.map((l) => (
                    <tr key={l.id} className="border-b last:border-0">
                      <td className="py-2 pr-2">
                        {l.item_code ? `${l.item_code} · ` : ""}
                        {l.item_name ?? l.item_id}
                      </td>
                      <td className="py-2 pr-2">{l.uom}</td>
                      <td className="py-2 pr-2 text-right">
                        {l.unit_price.toLocaleString("vi-VN")}
                      </td>
                      <td className="py-2 pr-2 text-right">
                        {l.warn_pct ?? "—"}
                      </td>
                      <td className="py-2 pr-2 text-right">
                        {l.lock_pct ?? "—"}
                      </td>
                      <td className="py-2 text-right">
                        {canManageAgreements ? (
                          <div className="flex justify-end gap-1">
                            <Button
                              variant="outline"
                              size="sm"
                              className="text-xs h-7 px-2"
                              onClick={() => startEditLine(l)}
                            >
                              {vi.master.prices.editLine}
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
                              onClick={() => handleDeleteLine(l)}
                            >
                              {vi.master.prices.deleteLine}
                            </Button>
                          </div>
                        ) : null}
                      </td>
                    </tr>
                  ))}
                  {lines.length === 0 ? (
                    <tr>
                      <td
                        colSpan={6}
                        className="py-3 text-center text-muted-foreground"
                      >
                        {vi.common.noData}
                      </td>
                    </tr>
                  ) : null}
                </tbody>
              </table>
            )}
            {canManageAgreements ? (
              <Button size="sm" onClick={startCreateLine}>
                + {vi.master.prices.addLine}
              </Button>
            ) : null}
          </div>
        ) : null}
      </div>

      <div className="space-y-4">
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <div>
            <h2 className="text-lg font-semibold">
              {vi.master.prices.ceilingsTitle}
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {vi.master.prices.description}
            </p>
          </div>
          {canManageCeilings ? (
            <Button size="sm" onClick={startCreateCeiling}>
              + {vi.master.prices.addCeiling}
            </Button>
          ) : null}
        </div>

        <DataTable columns={ceilingColumns} rows={ceilings} />
      </div>

      {agreementOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editingAgreement
                  ? vi.master.prices.editAgreement
                  : vi.master.prices.addAgreement}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setAgreementOpen(false)}
              >
                ✕
              </Button>
            </div>
            <form onSubmit={handleSaveAgreement} className="mt-4 space-y-3">
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.prices.supplier} *
                </label>
                <select
                  required
                  value={agreementSupplierId}
                  onChange={(e) => setAgreementSupplierId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="">— {vi.master.prices.supplier} —</option>
                  {suppliers.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.code} - {s.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.validFrom} *
                  </label>
                  <input
                    type="date"
                    required
                    value={agreementValidFrom}
                    onChange={(e) => setAgreementValidFrom(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.validTo} *
                  </label>
                  <input
                    type="date"
                    required
                    value={agreementValidTo}
                    onChange={(e) => setAgreementValidTo(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.prices.status} *
                </label>
                <select
                  required
                  value={agreementStatus}
                  onChange={(e) =>
                    setAgreementStatus(
                      e.target.value as
                        "draft" | "active" | "expired" | "cancelled",
                    )
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="draft">{vi.master.prices.statusDraft}</option>
                  <option value="active">
                    {vi.master.prices.statusActive}
                  </option>
                  <option value="expired">
                    {vi.master.prices.statusExpired}
                  </option>
                  <option value="cancelled">
                    {vi.master.prices.statusCancelled}
                  </option>
                </select>
              </div>
              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setAgreementOpen(false)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={agreementSaving}>
                  {agreementSaving ? vi.common.loading : vi.common.save}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {lineOpen && openAgreement ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editingLine
                  ? vi.master.prices.editLine
                  : vi.master.prices.addLine}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setLineOpen(false)}
              >
                ✕
              </Button>
            </div>
            <form onSubmit={handleSaveLine} className="mt-4 space-y-3">
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.prices.item} *
                </label>
                <select
                  required
                  value={lineItemId}
                  onChange={(e) => setLineItemId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="">— {vi.master.prices.item} —</option>
                  {items.map((i) => (
                    <option key={i.id} value={i.id}>
                      {i.code} - {i.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.uom} *
                  </label>
                  <select
                    required
                    value={lineUom}
                    onChange={(e) => setLineUom(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  >
                    <option value="">— {vi.master.prices.uom} —</option>
                    {uoms.map((u) => (
                      <option key={u.code} value={u.code}>
                        {u.code} - {u.name_vi}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.unitPrice} *
                  </label>
                  <input
                    type="number"
                    min={0}
                    step="0.01"
                    required
                    value={lineUnitPrice}
                    onChange={(e) => setLineUnitPrice(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.warnPct}
                  </label>
                  <input
                    type="number"
                    min={0}
                    max={100}
                    step="0.01"
                    value={lineWarnPct}
                    onChange={(e) => setLineWarnPct(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.lockPct}
                  </label>
                  <input
                    type="number"
                    min={0}
                    max={100}
                    step="0.01"
                    value={lineLockPct}
                    onChange={(e) => setLineLockPct(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
              </div>
              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setLineOpen(false)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={lineSaving}>
                  {lineSaving ? vi.common.loading : vi.common.save}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {ceilingOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editingCeiling
                  ? vi.master.prices.editCeiling
                  : vi.master.prices.addCeiling}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setCeilingOpen(false)}
              >
                ✕
              </Button>
            </div>
            <form onSubmit={handleSaveCeiling} className="mt-4 space-y-3">
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.prices.scope} *
                </label>
                <select
                  required
                  value={ceilingScope}
                  onChange={(e) =>
                    setCeilingScope(e.target.value as "chain" | "property")
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="property">
                    {vi.master.prices.scopeProperty}
                  </option>
                  <option value="chain">{vi.master.prices.scopeChain}</option>
                </select>
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.prices.item} *
                </label>
                <select
                  required
                  value={ceilingItemId}
                  onChange={(e) => setCeilingItemId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="">— {vi.master.prices.item} —</option>
                  {items.map((i) => (
                    <option key={i.id} value={i.id}>
                      {i.code} - {i.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.uom} *
                  </label>
                  <select
                    required
                    value={ceilingUom}
                    onChange={(e) => setCeilingUom(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  >
                    <option value="">— {vi.master.prices.uom} —</option>
                    {uoms.map((u) => (
                      <option key={u.code} value={u.code}>
                        {u.code} - {u.name_vi}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.price} *
                  </label>
                  <input
                    type="number"
                    min={0}
                    step="0.01"
                    required
                    value={ceilingPrice}
                    onChange={(e) => setCeilingPrice(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.validFrom} *
                  </label>
                  <input
                    type="date"
                    required
                    value={ceilingValidFrom}
                    onChange={(e) => setCeilingValidFrom(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.prices.validTo} *
                  </label>
                  <input
                    type="date"
                    required
                    value={ceilingValidTo}
                    onChange={(e) => setCeilingValidTo(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
              </div>
              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setCeilingOpen(false)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={ceilingSaving}>
                  {ceilingSaving ? vi.common.loading : vi.common.save}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  );
}
