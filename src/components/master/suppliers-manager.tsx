"use client";

import { useMemo, useState } from "react";
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
  SupplierRow,
  SupplierBankAccountRow,
  AssessmentWarning,
} from "@/features/master/queries";
import type { SupplierSaveInput } from "@/features/master/schemas";
import {
  saveSupplierAction,
  deleteSupplierAction,
  submitSupplierAction,
  approveSupplierAction,
  setSupplierStatusAction,
  requestBankAccountAction,
  approveBankAccountAction,
  listSupplierBankAccountsAction,
} from "@/features/master/actions";

const supplierKinds = [
  { value: "company", label: vi.master.suppliers.kindCompany },
  { value: "household", label: vi.master.suppliers.kindHousehold },
  { value: "individual_no_invoice", label: vi.master.suppliers.kindIndividual },
];

function statusLabel(status: string): string {
  switch (status) {
    case "pending":
      return vi.master.suppliers.statusPending;
    case "active":
      return vi.master.suppliers.statusActive;
    case "suspended":
      return vi.master.suppliers.statusSuspended;
    case "banned":
      return vi.master.suppliers.statusBanned;
    default:
      return status;
  }
}

function bankStatusLabel(status: string): string {
  switch (status) {
    case "pending":
      return vi.master.suppliers.bankStatusPending;
    case "active":
      return vi.master.suppliers.bankStatusActive;
    case "revoked":
      return vi.master.suppliers.bankStatusRevoked;
    default:
      return status;
  }
}

type DecisionMode = "approve" | "reject" | "suspend" | "ban" | "reactivate";

export function SuppliersManager({
  propertyId,
  suppliers,
}: {
  propertyId: string;
  suppliers: SupplierRow[];
}) {
  const router = useRouter();
  const canManage = useCan("supplier.manage");
  const canApprove = useCan("supplier.approve");
  const canRequestBank = useCan("supplier.bank.request");
  const canApproveBank = useCan("supplier.bank.approve");

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // Form NCC
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<SupplierRow | null>(null);
  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [taxCode, setTaxCode] = useState("");
  const [kind, setKind] = useState<SupplierSaveInput["kind"]>("company");
  const [phone, setPhone] = useState("");
  const [address, setAddress] = useState("");
  const [paymentTermsDays, setPaymentTermsDays] = useState("");
  const [foodSafetyCertUntil, setFoodSafetyCertUntil] = useState("");
  const [saving, setSaving] = useState(false);

  // Tham dinh + quyet dinh
  const [warnings, setWarnings] = useState<AssessmentWarning[] | null>(null);
  const [warningsFor, setWarningsFor] = useState<string | null>(null);
  const [decision, setDecision] = useState<{
    supplier: SupplierRow;
    mode: DecisionMode;
  } | null>(null);
  const [reason, setReason] = useState("");
  const [deciding, setDeciding] = useState(false);

  // Tai khoan ngan hang
  const [bankSupplier, setBankSupplier] = useState<SupplierRow | null>(null);
  const [bankAccounts, setBankAccounts] = useState<SupplierBankAccountRow[]>(
    [],
  );
  const [bankLoading, setBankLoading] = useState(false);
  const [bankName, setBankName] = useState("");
  const [accountNo, setAccountNo] = useState("");
  const [accountName, setAccountName] = useState("");
  const [bankSaving, setBankSaving] = useState(false);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    return suppliers.filter((s) => {
      if (statusFilter && s.status !== statusFilter) return false;
      if (!term) return true;
      return (
        s.code.toLowerCase().includes(term) ||
        s.name.toLowerCase().includes(term) ||
        (s.phone ?? "").toLowerCase().includes(term)
      );
    });
  }, [suppliers, search, statusFilter]);

  function startCreate() {
    setEditing(null);
    setCode("");
    setName("");
    setTaxCode("");
    setKind("company");
    setPhone("");
    setAddress("");
    setPaymentTermsDays("");
    setFoodSafetyCertUntil("");
    setError(null);
    setOpen(true);
  }

  function startEdit(s: SupplierRow) {
    setEditing(s);
    setCode(s.code);
    setName(s.name);
    setTaxCode(s.tax_code ?? "");
    setKind(s.kind as SupplierSaveInput["kind"]);
    setPhone(s.phone ?? "");
    setAddress(s.address ?? "");
    setPaymentTermsDays(
      s.payment_terms_days === null ? "" : String(s.payment_terms_days),
    );
    setFoodSafetyCertUntil(s.food_safety_cert_until ?? "");
    setError(null);
    setOpen(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    const res = await saveSupplierAction({
      id: editing?.id,
      propertyId,
      code,
      name,
      taxCode: taxCode || null,
      kind,
      phone: phone || null,
      address: address || null,
      paymentTermsDays:
        paymentTermsDays === "" ? null : Number(paymentTermsDays),
      foodSafetyCertUntil: foodSafetyCertUntil || null,
    });
    setSaving(false);
    if (res.ok) {
      setOpen(false);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDelete(s: SupplierRow) {
    if (!confirm(vi.master.suppliers.deleteConfirm)) return;
    setError(null);
    const res = await deleteSupplierAction(propertyId, s.id);
    if (res.ok) {
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleAssess(s: SupplierRow) {
    setError(null);
    setNotice(null);
    const res = await submitSupplierAction(propertyId, s.id);
    if (res.ok) {
      setWarnings(res.data.warnings);
      setWarningsFor(s.code);
      setNotice(vi.master.suppliers.submittedSuccess);
    } else {
      setError(res.error);
    }
  }

  function startDecision(s: SupplierRow, mode: DecisionMode) {
    setDecision({ supplier: s, mode });
    setReason("");
    setError(null);
  }

  async function handleDecision(e: React.FormEvent) {
    e.preventDefault();
    if (!decision) return;
    setDeciding(true);
    setError(null);
    const { supplier, mode } = decision;

    let res: { ok: boolean; error?: string };
    if (mode === "approve" || mode === "reject") {
      res = await approveSupplierAction({
        propertyId,
        supplierId: supplier.id,
        approved: mode === "approve",
        reason: reason || null,
      });
    } else {
      const status =
        mode === "suspend" ? "suspended" : mode === "ban" ? "banned" : "active";
      res = await setSupplierStatusAction({
        propertyId,
        supplierId: supplier.id,
        status,
        reason,
      });
    }
    setDeciding(false);
    if (res.ok) {
      setDecision(null);
      setNotice(
        mode === "approve"
          ? vi.master.suppliers.approvedSuccess
          : mode === "reject"
            ? vi.master.suppliers.rejectedSuccess
            : vi.master.suppliers.statusChangedSuccess,
      );
      router.refresh();
    } else {
      setError(res.error ?? "Đã xảy ra lỗi.");
    }
  }

  async function openBankPanel(s: SupplierRow) {
    setBankSupplier(s);
    setBankName("");
    setAccountNo("");
    setAccountName("");
    setError(null);
    setBankLoading(true);
    const rows = await listSupplierBankAccountsAction(s.id);
    setBankAccounts(rows);
    setBankLoading(false);
  }

  async function handleBankRequest(e: React.FormEvent) {
    e.preventDefault();
    if (!bankSupplier) return;
    setBankSaving(true);
    setError(null);
    const res = await requestBankAccountAction({
      propertyId,
      supplierId: bankSupplier.id,
      bankName,
      accountNo,
      accountName,
    });
    setBankSaving(false);
    if (res.ok) {
      setNotice(vi.master.suppliers.bankRequestedSuccess);
      setBankName("");
      setAccountNo("");
      setAccountName("");
      const rows = await listSupplierBankAccountsAction(bankSupplier.id);
      setBankAccounts(rows);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleBankDecision(
    account: SupplierBankAccountRow,
    approved: boolean,
  ) {
    let reasonText = "";
    if (!approved) {
      reasonText = window.prompt(vi.master.suppliers.reason) ?? "";
      if (!reasonText.trim()) return;
    }
    setError(null);
    const res = await approveBankAccountAction({
      propertyId,
      bankAccountId: account.id,
      approved,
      reason: reasonText || null,
    });
    if (res.ok) {
      setNotice(
        approved
          ? vi.master.suppliers.bankApprovedSuccess
          : vi.master.suppliers.bankRejectedSuccess,
      );
      if (bankSupplier) {
        const rows = await listSupplierBankAccountsAction(bankSupplier.id);
        setBankAccounts(rows);
      }
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const columns: DataTableColumn<SupplierRow>[] = [
    {
      key: "code",
      header: vi.master.suppliers.code,
      cell: (row) => (
        <span className="font-mono font-bold text-xs">{row.code}</span>
      ),
    },
    {
      key: "name",
      header: vi.master.suppliers.name,
      cell: (row) => <span className="font-medium">{row.name}</span>,
    },
    {
      key: "kind",
      header: vi.master.suppliers.kind,
      cell: (row) =>
        supplierKinds.find((k) => k.value === row.kind)?.label ?? row.kind,
    },
    {
      key: "phone",
      header: vi.master.suppliers.phone,
      cell: (row) => row.phone || "—",
    },
    {
      key: "status",
      header: vi.master.suppliers.status,
      cell: (row) => statusLabel(row.status),
    },
    {
      key: "bank_changed_at",
      header: vi.master.suppliers.bankChangedAt,
      cell: (row) =>
        row.bank_changed_at
          ? new Date(row.bank_changed_at).toLocaleDateString("vi-VN")
          : "—",
    },
    {
      key: "actions",
      header: vi.common.actions,
      align: "right",
      cell: (row) => (
        <div className="flex items-center justify-end gap-1 flex-wrap">
          <Button
            variant="outline"
            size="sm"
            className="text-xs h-7 px-2"
            onClick={() => openBankPanel(row)}
          >
            {vi.master.suppliers.bankAccounts}
          </Button>
          {row.status === "pending" && canManage ? (
            <Button
              variant="outline"
              size="sm"
              className="text-xs h-7 px-2"
              onClick={() => handleAssess(row)}
            >
              {vi.master.suppliers.assess}
            </Button>
          ) : null}
          {row.status === "pending" && canApprove ? (
            <>
              <Button
                variant="outline"
                size="sm"
                className="text-xs h-7 px-2"
                onClick={() => startDecision(row, "approve")}
              >
                {vi.master.suppliers.approve}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
                onClick={() => startDecision(row, "reject")}
              >
                {vi.master.suppliers.reject}
              </Button>
            </>
          ) : null}
          {row.status === "active" && canManage ? (
            <>
              <Button
                variant="outline"
                size="sm"
                className="text-xs h-7 px-2"
                onClick={() => startDecision(row, "suspend")}
              >
                {vi.master.suppliers.suspend}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
                onClick={() => startDecision(row, "ban")}
              >
                {vi.master.suppliers.ban}
              </Button>
            </>
          ) : null}
          {row.status === "suspended" && canManage ? (
            <Button
              variant="outline"
              size="sm"
              className="text-xs h-7 px-2"
              onClick={() => startDecision(row, "reactivate")}
            >
              {vi.master.suppliers.reactivate}
            </Button>
          ) : null}
          {canManage ? (
            <>
              <Button
                variant="outline"
                size="sm"
                className="text-xs h-7 px-2"
                onClick={() => startEdit(row)}
              >
                {vi.master.suppliers.editSupplier}
              </Button>
              {row.status === "pending" ? (
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
                  onClick={() => handleDelete(row)}
                >
                  {vi.master.suppliers.deleteSupplier}
                </Button>
              ) : null}
            </>
          ) : null}
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-4">
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

      <PageHeader
        title={vi.master.suppliers.title}
        description={vi.master.suppliers.description}
        actions={
          canManage ? (
            <Button size="sm" onClick={startCreate}>
              + {vi.master.suppliers.addSupplier}
            </Button>
          ) : null
        }
      />

      <div className="flex gap-2 flex-wrap">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder={vi.master.suppliers.searchPlaceholder}
          className="h-9 flex-1 min-w-52 rounded-md border bg-background px-3 text-sm"
        />
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="h-9 rounded-md border bg-background px-3 text-sm"
        >
          <option value="">{vi.master.suppliers.filterAllStatuses}</option>
          <option value="pending">{vi.master.suppliers.statusPending}</option>
          <option value="active">{vi.master.suppliers.statusActive}</option>
          <option value="suspended">
            {vi.master.suppliers.statusSuspended}
          </option>
          <option value="banned">{vi.master.suppliers.statusBanned}</option>
        </select>
      </div>

      {warnings && warningsFor ? (
        <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-3 text-sm">
          <p className="font-medium">
            {vi.master.suppliers.warningsTitle} ({warningsFor})
          </p>
          {warnings.length === 0 ? (
            <p className="text-muted-foreground mt-1">
              {vi.master.suppliers.noWarnings}
            </p>
          ) : (
            <ul className="list-disc pl-5 mt-1 space-y-0.5">
              {warnings.map((w) => (
                <li key={w.code}>{w.message}</li>
              ))}
            </ul>
          )}
        </div>
      ) : null}

      <DataTable columns={columns} rows={filtered} />

      {bankSupplier ? (
        <div className="rounded-lg border p-4 space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="font-semibold text-sm">
              {vi.master.suppliers.bankAccounts} — {bankSupplier.code} ·{" "}
              {bankSupplier.name}
            </h3>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setBankSupplier(null)}
            >
              ✕
            </Button>
          </div>
          <p className="text-xs text-muted-foreground">
            {vi.master.suppliers.bankChangeNote}
          </p>
          {bankLoading ? (
            <p className="text-sm text-muted-foreground">{vi.common.loading}</p>
          ) : (
            <table className="w-full text-sm">
              <thead className="bg-muted/40 text-left">
                <tr>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.suppliers.bankName}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.suppliers.accountNo}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.suppliers.accountName}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.suppliers.status}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.common.actions}
                  </th>
                </tr>
              </thead>
              <tbody>
                {bankAccounts.map((a) => (
                  <tr key={a.id} className="border-t hover:bg-muted/40">
                    <td className="py-3 pr-3 align-middle">{a.bank_name}</td>
                    <td className="py-3 pr-3 font-mono text-xs align-middle">
                      {a.account_no}
                    </td>
                    <td className="py-3 pr-3 align-middle">{a.account_name}</td>
                    <td className="py-3 pr-3 align-middle">
                      {bankStatusLabel(a.status)}
                    </td>
                    <td className="py-3 pr-3 text-right align-middle">
                      {a.status === "pending" && canApproveBank ? (
                        <div className="flex justify-end gap-1">
                          <Button
                            variant="outline"
                            size="sm"
                            className="text-xs h-7 px-2"
                            onClick={() => handleBankDecision(a, true)}
                          >
                            {vi.master.suppliers.approveBank}
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
                            onClick={() => handleBankDecision(a, false)}
                          >
                            {vi.master.suppliers.rejectBank}
                          </Button>
                        </div>
                      ) : null}
                    </td>
                  </tr>
                ))}
                {bankAccounts.length === 0 ? (
                  <tr>
                    <td
                      colSpan={5}
                      className="py-3 text-center text-muted-foreground"
                    >
                      {vi.common.noData}
                    </td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          )}
          {canRequestBank ? (
            <form
              onSubmit={handleBankRequest}
              className="flex gap-2 flex-wrap items-end border-t pt-3"
            >
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.suppliers.bankName} *
                </label>
                <input
                  required
                  value={bankName}
                  onChange={(e) => setBankName(e.target.value)}
                  className="mt-1 h-9 w-44 rounded-md border bg-background px-3 text-sm"
                />
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.suppliers.accountNo} *
                </label>
                <input
                  required
                  value={accountNo}
                  onChange={(e) => setAccountNo(e.target.value)}
                  className="mt-1 h-9 w-44 rounded-md border bg-background px-3 text-sm"
                />
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.suppliers.accountName} *
                </label>
                <input
                  required
                  value={accountName}
                  onChange={(e) => setAccountName(e.target.value)}
                  className="mt-1 h-9 w-56 rounded-md border bg-background px-3 text-sm"
                />
              </div>
              <Button type="submit" size="sm" disabled={bankSaving}>
                {bankSaving
                  ? vi.common.loading
                  : vi.master.suppliers.addBankAccount}
              </Button>
            </form>
          ) : null}
        </div>
      ) : null}

      {open ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-lg rounded-xl border bg-background p-6 shadow-lg max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editing
                  ? vi.master.suppliers.editSupplier
                  : vi.master.suppliers.addSupplier}
              </h3>
              <Button variant="ghost" size="sm" onClick={() => setOpen(false)}>
                ✕
              </Button>
            </div>

            <form onSubmit={handleSave} className="mt-4 space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.suppliers.code} *
                  </label>
                  <input
                    required
                    value={code}
                    onChange={(e) => setCode(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.suppliers.kind} *
                  </label>
                  <select
                    required
                    value={kind}
                    onChange={(e) =>
                      setKind(e.target.value as SupplierSaveInput["kind"])
                    }
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  >
                    {supplierKinds.map((k) => (
                      <option key={k.value} value={k.value}>
                        {k.label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.suppliers.name} *
                </label>
                <input
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.suppliers.taxCode}
                  </label>
                  <input
                    value={taxCode}
                    onChange={(e) => setTaxCode(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.suppliers.phone}
                  </label>
                  <input
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.suppliers.address}
                </label>
                <input
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.suppliers.paymentTermsDays}
                  </label>
                  <input
                    type="number"
                    min={0}
                    value={paymentTermsDays}
                    onChange={(e) => setPaymentTermsDays(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">
                    {vi.master.suppliers.foodSafetyCertUntil}
                  </label>
                  <input
                    type="date"
                    value={foodSafetyCertUntil}
                    onChange={(e) => setFoodSafetyCertUntil(e.target.value)}
                    className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                  />
                </div>
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

      {decision ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {decision.supplier.code} · {decision.supplier.name}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setDecision(null)}
              >
                ✕
              </Button>
            </div>
            <form onSubmit={handleDecision} className="mt-4 space-y-3">
              <p className="text-sm text-muted-foreground">
                {decision.mode === "approve"
                  ? vi.master.suppliers.approve
                  : decision.mode === "reject"
                    ? vi.master.suppliers.reject
                    : decision.mode === "suspend"
                      ? vi.master.suppliers.suspend
                      : decision.mode === "ban"
                        ? vi.master.suppliers.ban
                        : vi.master.suppliers.reactivate}
              </p>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.master.suppliers.reason}
                  {decision.mode === "approve" ? "" : " *"}
                </label>
                <textarea
                  required={decision.mode !== "approve"}
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder={vi.master.suppliers.reasonPlaceholder}
                  className="mt-1 min-h-20 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
              </div>
              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setDecision(null)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={deciding}>
                  {deciding ? vi.common.loading : vi.common.save}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  );
}
