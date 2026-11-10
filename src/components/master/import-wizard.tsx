"use client";

import { useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import {
  parseWorkbook,
  getSheetGrid,
  detectHeaderRow,
  cellToString,
  extractCodeFromCombined,
  downloadResultReport,
  type ParsedWorkbook,
} from "@/lib/import/xlsx";
import type { WorkBook } from "xlsx";
import type { ItemGroupRow, UomRow } from "@/features/master/queries";
import type {
  ImportBatchDetail,
  ImportBatchListItem,
  ImportMapping,
  ImportRow,
} from "@/features/master/import-schemas";
import {
  createImportBatchAction,
  resolveImportRowAction,
  commitImportBatchAction,
  discardImportBatchAction,
  saveImportMappingAction,
  addUomAliasAction,
} from "@/features/master/import-actions";

// --- Anh xa tieu de cot -> truong (so sanh sau khi bo dau + lower) ---------
function normHeader(h: string): string {
  return h
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
}

const ITEM_FIELD_LABELS: { field: string; label: string; aliases: string[] }[] =
  [
    {
      field: "code",
      label: vi.master.import.fieldCode,
      aliases: ["ma", "manvl", "manvl2", "mavattu", "ma vat tu"],
    },
    {
      field: "name",
      label: vi.master.import.fieldName,
      aliases: ["ten", "sanpham", "tenvattu", "san pham", "ten vat tu"],
    },
    {
      field: "code_and_name",
      label: vi.master.import.fieldCodeAndName,
      aliases: ["mavaten", "mavaten nvl", "ma va ten"],
    },
    {
      field: "group_raw",
      label: vi.master.import.fieldGroupRaw,
      aliases: ["loai", "nhom", "loainvl", "nhomhang"],
    },
    {
      field: "stock_uom_raw",
      label: vi.master.import.fieldStockUom,
      aliases: ["dvt", "donvi", "donvitinh", "don vi", "dvt kho"],
    },
    {
      field: "factor_raw",
      label: vi.master.import.fieldFactor,
      aliases: [
        "heso",
        "hesoquidoi",
        "he so",
        "he so qui doi",
        "hesokhocongthuc",
        "he so kho cong thuc",
      ],
    },
    {
      field: "recipe_uom_raw",
      label: vi.master.import.fieldRecipeUom,
      aliases: [
        "dvtquidoi",
        "dvt qui doi",
        "donviquidoi",
        "dvtcongthuc",
        "dvt cong thuc",
      ],
    },
    {
      field: "cost_group",
      label: vi.master.import.fieldCostGroup,
      aliases: ["nhomcp", "nhom cp", "nhomchiphi"],
    },
    {
      field: "legacy_code",
      label: vi.master.import.fieldLegacyCode,
      aliases: [
        "mabravo",
        "ma bravo",
        "macu",
        "ma cu",
        "macubravo",
        "ma cu bravo",
      ],
    },
    {
      field: "name_en",
      label: vi.master.import.fieldNameEn,
      aliases: ["tenen", "ten tieng anh"],
    },
    {
      field: "key_item",
      label: vi.master.import.fieldKeyItem,
      aliases: ["keyitem", "key item", "hangchuluc", "hang chu luc"],
    },
    {
      field: "vat",
      label: vi.master.import.fieldVat,
      aliases: ["vat", "vatrate", "thuevat", "thue vat"],
    },
    {
      field: "expiry_days",
      label: vi.master.import.fieldExpiryDays,
      aliases: [
        "handung",
        "han dung",
        "handungngay",
        "han dung ngay",
        "expiry",
        "shelf life",
      ],
    },
    {
      field: "purchase_uom_raw",
      label: vi.master.import.fieldPurchaseUom,
      aliases: ["dvtmua", "dvt mua"],
    },
    {
      field: "purchase_factor_raw",
      label: vi.master.import.fieldPurchaseFactor,
      aliases: ["hesomuakho", "he so mua kho"],
    },
  ];

const SUPPLIER_FIELD_LABELS: {
  field: string;
  label: string;
  aliases: string[];
}[] = [
  {
    field: "code",
    label: vi.master.import.fieldCode,
    aliases: ["ma", "mancc", "ma ncc"],
  },
  {
    field: "name",
    label: vi.master.import.fieldName,
    aliases: ["ten", "tenncc", "ten ncc"],
  },
  {
    field: "tax_code",
    label: vi.master.import.fieldTaxCode,
    aliases: ["mst", "masothue", "ma so thue"],
  },
  {
    field: "kind_raw",
    label: vi.master.import.fieldKind,
    aliases: ["loai", "loaincc", "loai ncc"],
  },
  {
    field: "phone",
    label: vi.master.import.fieldPhone,
    aliases: ["dienthoai", "sdt", "dien thoai"],
  },
  {
    field: "address",
    label: vi.master.import.fieldAddress,
    aliases: ["diachi", "dia chi"],
  },
  {
    field: "payment_terms_days",
    label: vi.master.import.fieldPaymentTerms,
    aliases: ["hanthanhtoan", "han thanh toan", "hanthanhtoanngay"],
  },
  {
    field: "bank_name",
    label: vi.master.import.fieldBankName,
    aliases: ["nganhang", "ngan hang"],
  },
  {
    field: "account_no",
    label: vi.master.import.fieldAccountNo,
    aliases: ["sotk", "sotaikhoan", "so tk", "so tai khoan"],
  },
  {
    field: "account_name",
    label: vi.master.import.fieldAccountName,
    aliases: ["chutk", "chutaikhoan", "chu tk", "chu tai khoan"],
  },
];

function suggestColumn(
  fieldAliases: string[],
  headers: (string | null)[],
): number | null {
  for (let i = 0; i < headers.length; i++) {
    const h = headers[i];
    if (!h) continue;
    const n = normHeader(h);
    if (fieldAliases.some((a) => normHeader(a) === n)) return i;
  }
  return null;
}

function issueLabel(code: string): string {
  switch (code) {
    case "DUP_CODE":
      return vi.master.import.issueDupCode;
    case "NEAR_DUP_NAME":
      return vi.master.import.issueNearDupName;
    case "NO_CODE":
      return vi.master.import.issueNoCode;
    case "NO_FACTOR":
      return vi.master.import.issueNoFactor;
    case "UNKNOWN_UOM":
      return vi.master.import.issueUnknownUom;
    case "UNKNOWN_GROUP":
      return vi.master.import.issueUnknownGroup;
    case "EMPTY_NAME":
      return vi.master.import.issueEmptyName;
    case "EXISTING":
      return vi.master.import.issueExisting;
    case "INVALID_FACTOR":
      return vi.master.import.issueInvalidFactor;
    case "INVALID_VALUE":
      return vi.master.import.issueInvalidValue;
    case "GROUP_KIND_MISMATCH":
      return vi.master.import.issueGroupKindMismatch;
    case "TAX_CODE_DUP":
      return vi.master.import.issueTaxCodeDup;
    case "BANK_ACCOUNT_DUP":
      return vi.master.import.issueBankAccountDup;
    default:
      return code;
  }
}

function statusLabel(status: string): string {
  switch (status) {
    case "ok":
      return vi.master.import.statusOk;
    case "warning":
      return vi.master.import.statusWarning;
    case "error":
      return vi.master.import.statusError;
    case "skipped":
      return vi.master.import.statusSkipped;
    case "merged":
      return vi.master.import.statusMerged;
    case "committed":
      return vi.master.import.statusCommitted;
    default:
      return status;
  }
}

type FixState = {
  newCode: string;
  factor: string;
  groupId: string;
  uom: string;
  alias: string;
  aliasUom: string;
};

const emptyFix: FixState = {
  newCode: "",
  factor: "",
  groupId: "",
  uom: "",
  alias: "",
  aliasUom: "",
};

export function ImportWizard({
  propertyId,
  groups,
  uoms,
  mappings,
  batches,
  initialBatch,
}: {
  propertyId: string;
  groups: ItemGroupRow[];
  uoms: UomRow[];
  mappings: ImportMapping[];
  batches: ImportBatchListItem[];
  initialBatch: ImportBatchDetail | null;
}) {
  const router = useRouter();
  const canImport = useCan("item.import");
  const canManageUom = useCan("item.manage");

  const [kind, setKind] = useState<"items" | "suppliers">("items");
  const [fileName, setFileName] = useState("");
  const workbookRef = useRef<WorkBook | null>(null);
  const [parsed, setParsed] = useState<ParsedWorkbook | null>(null);
  const [sheetName, setSheetName] = useState("");
  const [grid, setGrid] = useState<unknown[][]>([]);
  const [headerRow, setHeaderRow] = useState(0);
  const [columnMap, setColumnMap] = useState<Record<string, number | null>>({});
  const [groupMap, setGroupMap] = useState<Record<string, string>>({});
  const [mappingName, setMappingName] = useState("");
  const [saveMappingChecked, setSaveMappingChecked] = useState(true);
  const [selectedMappingId, setSelectedMappingId] = useState<string>("");
  const [batch, setBatch] = useState<ImportBatchDetail | null>(initialBatch);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [filter, setFilter] = useState<"all" | "error" | "warning" | "ok">(
    "all",
  );
  const [issueFilter, setIssueFilter] = useState<string>("");
  const [page, setPage] = useState(1);
  const [fix, setFix] = useState<Record<string, FixState>>({});
  const [commitResult, setCommitResult] = useState<{
    created: number;
    skipped: number;
    merged: number;
  } | null>(null);

  const fields = kind === "items" ? ITEM_FIELD_LABELS : SUPPLIER_FIELD_LABELS;
  const headers: (string | null)[] =
    grid[headerRow] !== undefined
      ? (grid[headerRow] as unknown[]).map((h) =>
          h === null || h === undefined ? null : String(h),
        )
      : [];

  const distinctGroups = useMemo(() => {
    if (kind !== "items" || grid.length === 0) return [];
    const col = columnMap["group_raw"];
    if (col === null || col === undefined) return [];
    const values = new Map<string, number>();
    for (let i = headerRow + 1; i < grid.length; i++) {
      const v = cellToString((grid[i] ?? [])[col]);
      if (v) values.set(v, (values.get(v) ?? 0) + 1);
    }
    return [...values.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([value, count]) => ({ value, count }));
  }, [kind, grid, headerRow, columnMap]);

  function defaultGroupFor(raw: string): string {
    if (/ccdc/i.test(raw)) {
      return groups.find((g) => g.kind === "ccdc")?.id ?? "";
    }
    return groups.find((g) => g.kind === "food")?.id ?? groups[0]?.id ?? "";
  }

  async function handleFile(file: File): Promise<void> {
    setError(null);
    setNotice(null);
    setCommitResult(null);
    setBatch(null);
    const buffer = await file.arrayBuffer();
    try {
      const pw = parseWorkbook(buffer);
      workbookRef.current = pw.workbook;
      setParsed(pw);
      setFileName(file.name);
      const first = pw.sheets[0];
      if (first) {
        selectSheet(first.name, pw.workbook);
      }
    } catch {
      setError("Không đọc được file Excel. Hãy chọn file .xlsx hợp lệ.");
    }
  }

  function selectSheet(name: string, wb?: WorkBook): void {
    const workbook = wb ?? workbookRef.current;
    if (!workbook) return;
    setSheetName(name);
    const g = getSheetGrid(workbook, name);
    setGrid(g);
    const hr = detectHeaderRow(g);
    setHeaderRow(hr);
    const hs: (string | null)[] = (g[hr] ?? []).map((h) =>
      h === null || h === undefined ? null : String(h),
    );
    const next: Record<string, number | null> = {};
    for (const f of fields) {
      next[f.field] = suggestColumn(f.aliases, hs);
    }
    setColumnMap(next);
    setGroupMap({});
    setSelectedMappingId("");
  }

  function applyMapping(m: ImportMapping): void {
    setSelectedMappingId(m.id);
    const next: Record<string, number | null> = {};
    for (const f of fields) {
      const entry = (m.column_map[f.field] ?? null) as {
        col?: number;
      } | null;
      next[f.field] = entry && typeof entry.col === "number" ? entry.col : null;
    }
    setColumnMap(next);
    const gm: Record<string, string> = {};
    for (const [k, v] of Object.entries(m.group_map)) {
      if (typeof v === "string") gm[k] = v;
    }
    setGroupMap(gm);
    setMappingName(m.name);
  }

  function buildRawRows(): Record<string, unknown>[] {
    const rows: Record<string, unknown>[] = [];
    const codeAndNameCol = columnMap["code_and_name"];
    for (let i = headerRow + 1; i < grid.length; i++) {
      const excelRow = grid[i] ?? [];
      const raw: Record<string, unknown> = { sheet_row: i + 1 };
      let hasValue = false;
      for (const f of fields) {
        if (f.field === "code_and_name") continue;
        const col = columnMap[f.field];
        if (col === null || col === undefined) continue;
        const value = excelRow[col] ?? null;
        raw[f.field] = value;
        if (
          value !== null &&
          value !== undefined &&
          String(value).trim() !== ""
        ) {
          hasValue = true;
        }
      }
      // Khoi phuc ma tu cot "Ma va ten" khi cot Ma trong.
      const codeValue = cellToString(raw["code"]);
      if (
        !codeValue &&
        codeAndNameCol !== null &&
        codeAndNameCol !== undefined
      ) {
        const combined = excelRow[codeAndNameCol] ?? null;
        const { code, rest } = extractCodeFromCombined(combined);
        if (code) {
          raw["code"] = code;
          hasValue = true;
          if (!cellToString(raw["name"])) raw["name"] = rest;
        }
      }
      if (hasValue) rows.push(raw);
    }
    return rows;
  }

  async function handleCreateBatch(): Promise<void> {
    setError(null);
    setNotice(null);
    setCommitResult(null);
    if (!workbookRef.current) {
      setError("Hãy chọn file Excel trước.");
      return;
    }
    const rows = buildRawRows();
    if (rows.length === 0) {
      setError("File không có dòng dữ liệu nào sau dòng tiêu đề.");
      return;
    }
    setBusy(true);
    try {
      let mappingId: string | null = selectedMappingId || null;
      const finalGroupMap: Record<string, string> = {};
      for (const g of distinctGroups) {
        const picked = groupMap[g.value] ?? defaultGroupFor(g.value);
        if (picked) finalGroupMap[g.value] = picked;
      }
      if (saveMappingChecked && !mappingId) {
        const colMap: Record<string, unknown> = {};
        for (const f of fields) {
          const col = columnMap[f.field];
          if (col !== null && col !== undefined) {
            colMap[f.field] = {
              col,
              header: headers[col] ?? "",
            };
          }
        }
        const saved = await saveImportMappingAction({
          propertyId,
          kind,
          name:
            mappingName.trim() ||
            `${kind === "items" ? "Vật tư" : "NCC"} ${fileName}`,
          columnMap: colMap,
          groupMap: finalGroupMap,
        });
        if (!saved.ok) {
          setError(saved.error);
          return;
        }
        mappingId = saved.data.mapping_id;
      }
      const created = await createImportBatchAction({
        propertyId,
        kind,
        fileName,
        mappingId,
        rows,
      });
      if (!created.ok) {
        setError(created.error);
        return;
      }
      router.push(
        `/${propertyId}/master/import?batch=${created.data.batch_id}`,
      );
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  async function handleResolve(row: ImportRow, action: string): Promise<void> {
    const f = fix[row.id] ?? emptyFix;
    const resolution: Record<string, unknown> = { action };
    if (action === "split" || action === "set_code") {
      resolution["new_code"] = f.newCode.trim();
    }
    if (action === "set_factor") {
      resolution["factor"] = Number(f.factor);
    }
    if (action === "set_group") {
      resolution["group_id"] = f.groupId;
    }
    if (action === "set_uom") {
      resolution["stock_uom"] = f.uom.trim();
    }
    if (action === "merge") {
      const target = row.issues.find(
        (i) => i.code === "NEAR_DUP_NAME" || i.code === "DUP_CODE",
      );
      if (target?.existing_id) {
        resolution["target_id"] = target.existing_id;
        resolution["target_code"] = target.existing_code ?? "";
      }
    }
    setBusy(true);
    try {
      const res = await resolveImportRowAction({
        batchId: batch?.batch.id ?? "",
        rowId: row.id,
        resolution,
      });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setNotice("Đã áp dụng. Kiểm tra lại xong.");
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  async function handleCommit(): Promise<void> {
    if (!batch) return;
    setError(null);
    setBusy(true);
    try {
      const res = await commitImportBatchAction({ batchId: batch.batch.id });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setCommitResult(res.data);
      setNotice(vi.master.import.commitSuccess);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  async function handleDiscard(): Promise<void> {
    if (!batch) return;
    setBusy(true);
    try {
      const res = await discardImportBatchAction({ batchId: batch.batch.id });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setBatch(null);
      router.push(`/${propertyId}/master/import`);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  async function handleAddAlias(row: ImportRow): Promise<void> {
    const f = fix[row.id] ?? emptyFix;
    if (!f.alias.trim() || !f.aliasUom) {
      setError("Nhập biến thể và chọn đơn vị chuẩn.");
      return;
    }
    setBusy(true);
    try {
      const res = await addUomAliasAction({
        propertyId,
        alias: f.alias.trim(),
        uomCode: f.aliasUom,
      });
      if (!res.ok) {
        setError(res.error);
        return;
      }
      setNotice(
        `Đã thêm biến thể ${res.data.alias} → ${res.data.uom_code}. Đang kiểm tra lại…`,
      );
      const re = await resolveImportRowAction({
        batchId: batch?.batch.id ?? "",
        rowId: row.id,
        resolution: { action: "keep" },
      });
      if (!re.ok) setError(re.error);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  const filteredRows = useMemo(() => {
    if (!batch) return [];
    let rows = batch.rows;
    if (filter === "error") rows = rows.filter((r) => r.status === "error");
    else if (filter === "warning")
      rows = rows.filter((r) => r.status === "warning");
    else if (filter === "ok") rows = rows.filter((r) => r.status === "ok");
    if (issueFilter) {
      rows = rows.filter((r) => r.issues.some((i) => i.code === issueFilter));
    }
    return rows;
  }, [batch, filter, issueFilter]);

  const pageSize = 25;
  const pageCount = Math.max(1, Math.ceil(filteredRows.length / pageSize));
  const pageRows = filteredRows.slice((page - 1) * pageSize, page * pageSize);

  const issueCodes = useMemo(() => {
    if (!batch) return [];
    const codes = new Map<string, number>();
    for (const r of batch.rows) {
      for (const i of r.issues) codes.set(i.code, (codes.get(i.code) ?? 0) + 1);
    }
    return [...codes.entries()].sort((a, b) => b[1] - a[1]);
  }, [batch]);

  if (!canImport && !batch) {
    return (
      <div className="rounded-md border p-4 text-sm text-muted-foreground">
        {vi.master.import.noPermission}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={vi.master.import.title}
        description={vi.master.import.description}
      />

      {error && (
        <div className="rounded-md border border-destructive bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      )}
      {notice && (
        <div className="rounded-md border bg-muted p-3 text-sm">{notice}</div>
      )}

      {/* Buoc 1: tai file + anh xa */}
      <section className="space-y-4 rounded-md border p-4">
        <h2 className="font-medium">{vi.master.import.stepUpload}</h2>
        <div className="flex flex-wrap gap-2">
          <Button
            variant={kind === "items" ? "default" : "outline"}
            onClick={() => {
              setKind("items");
              setParsed(null);
              setGrid([]);
              setBatch(null);
            }}
          >
            {vi.master.import.kindItems}
          </Button>
          <Button
            variant={kind === "suppliers" ? "default" : "outline"}
            onClick={() => {
              setKind("suppliers");
              setParsed(null);
              setGrid([]);
              setBatch(null);
            }}
          >
            {vi.master.import.kindSuppliers}
          </Button>
          <a
            className="inline-flex items-center rounded-md border px-3 py-1.5 text-sm"
            href={
              kind === "items"
                ? "/templates/mau_vat_tu.xlsx"
                : "/templates/mau_ncc.xlsx"
            }
          >
            {kind === "items"
              ? vi.master.import.downloadTemplateItems
              : vi.master.import.downloadTemplateSuppliers}
          </a>
        </div>
        <p className="text-sm text-muted-foreground">
          {vi.master.import.fileHint}
        </p>
        <input
          type="file"
          accept=".xlsx,.xls"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) void handleFile(file);
          }}
        />
        {parsed && (
          <div className="space-y-3">
            <div className="flex flex-wrap gap-3">
              <label className="text-sm">
                {vi.master.import.sheet}{" "}
                <select
                  className="rounded-md border px-2 py-1"
                  value={sheetName}
                  onChange={(e) => selectSheet(e.target.value)}
                >
                  {parsed.sheets.map((s) => (
                    <option key={s.name} value={s.name}>
                      {s.name} ({s.rowCount})
                    </option>
                  ))}
                </select>
              </label>
              <label className="text-sm">
                {vi.master.import.headerRow}{" "}
                <input
                  type="number"
                  min={1}
                  className="w-20 rounded-md border px-2 py-1"
                  value={headerRow + 1}
                  onChange={(e) => {
                    const v = Math.max(1, Number(e.target.value) || 1);
                    setHeaderRow(v - 1);
                  }}
                />
              </label>
              {mappings.filter((m) => m.kind === kind).length > 0 && (
                <label className="text-sm">
                  {vi.master.import.mappingSaved}{" "}
                  <select
                    className="rounded-md border px-2 py-1"
                    value={selectedMappingId}
                    onChange={(e) => {
                      const m = mappings.find((x) => x.id === e.target.value);
                      if (m) applyMapping(m);
                      else setSelectedMappingId("");
                    }}
                  >
                    <option value="">—</option>
                    {mappings
                      .filter((m) => m.kind === kind)
                      .map((m) => (
                        <option key={m.id} value={m.id}>
                          {m.name}
                        </option>
                      ))}
                  </select>
                </label>
              )}
            </div>

            <div>
              <h3 className="mb-2 text-sm font-medium">
                {vi.master.import.mapping}
              </h3>
              <div className="grid gap-2 md:grid-cols-2">
                {fields.map((f) => (
                  <label
                    key={f.field}
                    className="flex items-center gap-2 text-sm"
                  >
                    <span className="w-40 shrink-0">{f.label}</span>
                    <select
                      className="flex-1 rounded-md border px-2 py-1"
                      value={
                        columnMap[f.field] === null ||
                        columnMap[f.field] === undefined
                          ? ""
                          : String(columnMap[f.field])
                      }
                      onChange={(e) =>
                        setColumnMap((prev) => ({
                          ...prev,
                          [f.field]:
                            e.target.value === ""
                              ? null
                              : Number(e.target.value),
                        }))
                      }
                    >
                      <option value="">{vi.master.import.notMapped}</option>
                      {headers.map((h, i) => (
                        <option key={i} value={i}>
                          {String.fromCharCode(65 + (i % 26))}
                          {i >= 26 ? Math.floor(i / 26) : ""} — {h ?? ""}
                        </option>
                      ))}
                    </select>
                  </label>
                ))}
              </div>
            </div>

            {kind === "items" && distinctGroups.length > 0 && (
              <div>
                <h3 className="mb-2 text-sm font-medium">
                  {vi.master.import.groupMapping}
                </h3>
                <p className="mb-2 text-sm text-muted-foreground">
                  {vi.master.import.groupMappingHint}
                </p>
                <div className="grid gap-2 md:grid-cols-2">
                  {distinctGroups.map((g) => (
                    <label
                      key={g.value}
                      className="flex items-center gap-2 text-sm"
                    >
                      <span className="w-40 shrink-0">
                        {g.value} ({g.count})
                      </span>
                      <select
                        className="flex-1 rounded-md border px-2 py-1"
                        value={groupMap[g.value] ?? defaultGroupFor(g.value)}
                        onChange={(e) =>
                          setGroupMap((prev) => ({
                            ...prev,
                            [g.value]: e.target.value,
                          }))
                        }
                      >
                        <option value="">
                          {vi.master.import.unmappedGroup}
                        </option>
                        {groups.map((gr) => (
                          <option key={gr.id} value={gr.id}>
                            {gr.name} ({gr.code_prefix} · {gr.kind})
                          </option>
                        ))}
                      </select>
                    </label>
                  ))}
                </div>
              </div>
            )}

            <div className="flex flex-wrap items-center gap-3">
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={saveMappingChecked}
                  onChange={(e) => setSaveMappingChecked(e.target.checked)}
                />
                {vi.master.import.saveMapping}
              </label>
              {saveMappingChecked && (
                <input
                  className="rounded-md border px-2 py-1 text-sm"
                  placeholder={vi.master.import.mappingName}
                  value={mappingName}
                  onChange={(e) => setMappingName(e.target.value)}
                />
              )}
              <Button
                onClick={() => void handleCreateBatch()}
                disabled={busy || !canImport}
              >
                {busy
                  ? vi.master.import.creating
                  : vi.master.import.createBatch}
              </Button>
            </div>
          </div>
        )}
      </section>

      {/* Buoc 2 + 3: tom tat + xem truoc loi */}
      {batch && (
        <section className="space-y-4 rounded-md border p-4">
          <h2 className="font-medium">
            {vi.master.import.stepClean} · {vi.master.import.stepReview}
          </h2>
          <div className="text-sm">
            <span className="font-medium">{batch.batch.file_name}</span>{" "}
            <span className="text-muted-foreground">
              (
              {batch.batch.kind === "items"
                ? vi.master.import.kindItems
                : vi.master.import.kindSuppliers}
              ) — {statusLabel(batch.batch.status)}
            </span>
          </div>
          <div className="flex flex-wrap gap-4 text-sm">
            <span>
              {vi.master.import.summaryTotal}: <b>{batch.batch.counts.total}</b>
            </span>
            <span>
              {vi.master.import.summaryOk}: <b>{batch.batch.counts.ok}</b>
            </span>
            <span>
              {vi.master.import.summaryWarnings}:{" "}
              <b>{batch.batch.counts.warnings}</b>
            </span>
            <span>
              {vi.master.import.summaryErrors}:{" "}
              <b>{batch.batch.counts.errors}</b>
            </span>
            <span>
              {vi.master.import.summarySkippedBlank}:{" "}
              <b>{batch.batch.counts.skipped_blank}</b>
            </span>
          </div>

          <div className="flex flex-wrap gap-2">
            {(
              [
                ["all", vi.master.import.filterAll],
                ["error", vi.master.import.filterErrors],
                ["warning", vi.master.import.filterWarnings],
                ["ok", vi.master.import.filterOk],
              ] as const
            ).map(([key, label]) => (
              <Button
                key={key}
                size="sm"
                variant={filter === key ? "default" : "outline"}
                onClick={() => {
                  setFilter(key);
                  setPage(1);
                }}
              >
                {label}
              </Button>
            ))}
            <select
              className="rounded-md border px-2 py-1 text-sm"
              value={issueFilter}
              onChange={(e) => {
                setIssueFilter(e.target.value);
                setPage(1);
              }}
            >
              <option value="">—</option>
              {issueCodes.map(([code, n]) => (
                <option key={code} value={code}>
                  {issueLabel(code)} ({n})
                </option>
              ))}
            </select>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full min-w-[900px] text-sm">
              <thead className="bg-muted/40 text-left">
                <tr>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.import.colRow}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.import.colCode}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.import.colName}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.import.colUom}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.import.colFactor}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.import.colStatus}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.import.colIssues}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.master.import.colAction}
                  </th>
                </tr>
              </thead>
              <tbody>
                {pageRows.map((row) => (
                  <ImportRowFix
                    key={row.id}
                    row={row}
                    groups={groups}
                    uoms={uoms}
                    canImport={canImport}
                    canManageUom={canManageUom}
                    busy={busy}
                    fix={fix[row.id] ?? emptyFix}
                    setFix={(next) =>
                      setFix((prev) => ({ ...prev, [row.id]: next }))
                    }
                    onResolve={handleResolve}
                    onAddAlias={handleAddAlias}
                  />
                ))}
              </tbody>
            </table>
          </div>
          {pageCount > 1 && (
            <div className="flex items-center gap-2 text-sm">
              <Button
                size="sm"
                variant="outline"
                disabled={page <= 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
              >
                ←
              </Button>
              <span>
                {page} / {pageCount}
              </span>
              <Button
                size="sm"
                variant="outline"
                disabled={page >= pageCount}
                onClick={() => setPage((p) => Math.min(pageCount, p + 1))}
              >
                →
              </Button>
            </div>
          )}

          {/* Buoc 4: xac nhan */}
          <div className="space-y-2 border-t pt-4">
            <h3 className="font-medium">{vi.master.import.stepConfirm}</h3>
            <p className="text-sm text-muted-foreground">
              {vi.master.import.commitConfirm}
            </p>
            {batch.batch.counts.errors > 0 && (
              <p className="text-sm text-destructive">
                {vi.master.import.needFixErrors}
              </p>
            )}
            <div className="flex flex-wrap gap-2">
              <Button
                onClick={() => void handleCommit()}
                disabled={
                  busy || !canImport || batch.batch.status !== "validated"
                }
              >
                {busy ? vi.master.import.committing : vi.master.import.commit}
              </Button>
              <Button
                variant="outline"
                onClick={() => void handleDiscard()}
                disabled={busy || batch.batch.status === "committed"}
              >
                {vi.master.import.discard}
              </Button>
              {commitResult && batch.batch.status === "committed" && (
                <Button
                  variant="outline"
                  onClick={() =>
                    downloadResultReport(
                      `ket-qua-import-${batch.batch.file_name.replace(/\.xlsx?$/i, "")}.xlsx`,
                      commitResult,
                      batch.rows.map((r) => ({
                        rowNo: r.row_no,
                        code:
                          r.target_code ??
                          (typeof r.normalized_data["code"] === "string"
                            ? (r.normalized_data["code"] as string)
                            : ""),
                        name:
                          typeof r.normalized_data["name"] === "string"
                            ? (r.normalized_data["name"] as string)
                            : "",
                        status: statusLabel(r.status),
                        issues: r.issues.map((i) => i.message).join("; "),
                      })),
                    )
                  }
                >
                  {vi.master.import.downloadReport}
                </Button>
              )}
            </div>
            {commitResult && (
              <p className="text-sm">
                {vi.master.import.summaryCreated}: <b>{commitResult.created}</b>{" "}
                · {vi.master.import.summarySkipped}:{" "}
                <b>{commitResult.skipped}</b> · {vi.master.import.summaryMerged}
                : <b>{commitResult.merged}</b>
              </p>
            )}
          </div>
        </section>
      )}

      {/* Lich su batch */}
      <section className="rounded-md border p-4">
        <h2 className="mb-3 font-medium">{vi.master.import.batchesTitle}</h2>
        {batches.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.master.import.noBatch}
          </p>
        ) : (
          <ul className="space-y-2 text-sm">
            {batches.map((b) => (
              <li key={b.id} className="flex flex-wrap items-center gap-2">
                <button
                  className="font-medium underline underline-offset-2"
                  onClick={() => {
                    router.push(`/${propertyId}/master/import?batch=${b.id}`);
                    router.refresh();
                  }}
                >
                  {b.file_name}
                </button>
                <span className="text-muted-foreground">
                  {statusLabel(b.status)} · {b.counts.total} dòng ·{" "}
                  {b.counts.errors} lỗi ·{" "}
                  {new Date(b.created_at).toLocaleString("vi-VN")}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function ImportRowFix({
  row,
  groups,
  uoms,
  canImport,
  canManageUom,
  busy,
  fix,
  setFix,
  onResolve,
  onAddAlias,
}: {
  row: ImportRow;
  groups: ItemGroupRow[];
  uoms: UomRow[];
  canImport: boolean;
  canManageUom: boolean;
  busy: boolean;
  fix: FixState;
  setFix: (next: FixState) => void;
  onResolve: (row: ImportRow, action: string) => Promise<void>;
  onAddAlias: (row: ImportRow) => Promise<void>;
}) {
  const norm = row.normalized_data;
  const firstError = row.issues.find((i) => i.severity === "error");
  const code = typeof norm["code"] === "string" ? (norm["code"] as string) : "";
  const name = typeof norm["name"] === "string" ? (norm["name"] as string) : "";
  const stockUom =
    typeof norm["stock_uom"] === "string" ? (norm["stock_uom"] as string) : "";
  const factor =
    typeof norm["stock_to_recipe"] === "number"
      ? String(norm["stock_to_recipe"])
      : "";

  return (
    <tr className="border-t align-top hover:bg-muted/40">
      <td className="py-3 pr-3 align-middle">{row.row_no}</td>
      <td className="py-3 pr-3 font-mono text-xs align-middle">
        {code || "—"}
      </td>
      <td className="py-3 pr-3 align-middle">{name || "—"}</td>
      <td className="py-3 pr-3 align-middle">{stockUom || "—"}</td>
      <td className="py-3 pr-3 align-middle">{factor || "—"}</td>
      <td className="py-3 pr-3 align-middle">{statusLabel(row.status)}</td>
      <td className="py-3 pr-3 align-middle">
        <ul className="space-y-1">
          {row.issues.map((issue, idx) => (
            <li key={idx} className="text-xs">
              <b>{issueLabel(issue.code)}</b>
              {issue.severity === "warning" ? " (cảnh báo)" : ""}:{" "}
              {issue.message}
            </li>
          ))}
          {row.issues.length === 0 && (
            <li className="text-xs text-muted-foreground">—</li>
          )}
        </ul>
        {row.issues.some((i) => i.code === "NO_CODE") && (
          <p className="mt-1 text-xs text-muted-foreground">
            {vi.master.import.autoGeneratedCode}
          </p>
        )}
        {row.issues.some((i) => i.code === "EXISTING") && (
          <p className="mt-1 text-xs text-muted-foreground">
            {vi.master.import.existingWillSkip}
          </p>
        )}
      </td>
      <td className="py-3 pr-3 align-middle">
        {row.status !== "committed" &&
          row.status !== "skipped" &&
          row.status !== "merged" && (
            <div className="flex flex-col gap-1">
              {firstError?.code === "DUP_CODE" && (
                <>
                  <div className="flex gap-1">
                    <input
                      className="w-28 rounded-md border px-2 py-1 text-xs"
                      placeholder={vi.master.import.newCodePlaceholder}
                      value={fix.newCode}
                      onChange={(e) =>
                        setFix({ ...fix, newCode: e.target.value })
                      }
                    />
                    <Button
                      size="sm"
                      disabled={busy || !canImport || !fix.newCode.trim()}
                      onClick={() => void onResolve(row, "split")}
                    >
                      {vi.master.import.actionSplit}
                    </Button>
                  </div>
                  {firstError && row.issues.some((i) => i.existing_id) && (
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={busy || !canImport}
                      onClick={() => void onResolve(row, "merge")}
                    >
                      {vi.master.import.actionMerge}
                    </Button>
                  )}
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={busy || !canImport}
                    onClick={() => void onResolve(row, "skip")}
                  >
                    {vi.master.import.actionSkip}
                  </Button>
                </>
              )}
              {firstError?.code === "NEAR_DUP_NAME" && (
                <>
                  {row.issues.some((i) => i.existing_id) && (
                    <Button
                      size="sm"
                      disabled={busy || !canImport}
                      onClick={() => void onResolve(row, "merge")}
                    >
                      {vi.master.import.actionMerge}
                    </Button>
                  )}
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={busy || !canImport}
                    onClick={() => void onResolve(row, "keep")}
                  >
                    {vi.master.import.actionKeep}
                  </Button>
                </>
              )}
              {firstError?.code === "NO_FACTOR" && (
                <div className="flex gap-1">
                  <input
                    className="w-24 rounded-md border px-2 py-1 text-xs"
                    placeholder={vi.master.import.factorPlaceholder}
                    value={fix.factor}
                    onChange={(e) => setFix({ ...fix, factor: e.target.value })}
                  />
                  <Button
                    size="sm"
                    disabled={busy || !canImport || !fix.factor.trim()}
                    onClick={() => void onResolve(row, "set_factor")}
                  >
                    {vi.master.import.applyFix}
                  </Button>
                </div>
              )}
              {firstError?.code === "UNKNOWN_GROUP" && (
                <div className="flex gap-1">
                  <select
                    className="rounded-md border px-2 py-1 text-xs"
                    value={fix.groupId}
                    onChange={(e) =>
                      setFix({ ...fix, groupId: e.target.value })
                    }
                  >
                    <option value="">—</option>
                    {groups.map((g) => (
                      <option key={g.id} value={g.id}>
                        {g.name} ({g.code_prefix})
                      </option>
                    ))}
                  </select>
                  <Button
                    size="sm"
                    disabled={busy || !canImport || !fix.groupId}
                    onClick={() => void onResolve(row, "set_group")}
                  >
                    {vi.master.import.applyFix}
                  </Button>
                </div>
              )}
              {firstError?.code === "UNKNOWN_UOM" && (
                <>
                  <div className="flex gap-1">
                    <select
                      className="rounded-md border px-2 py-1 text-xs"
                      value={fix.uom}
                      onChange={(e) => setFix({ ...fix, uom: e.target.value })}
                    >
                      <option value="">—</option>
                      {uoms.map((u) => (
                        <option key={u.code} value={u.code}>
                          {u.code} — {u.name_vi}
                        </option>
                      ))}
                    </select>
                    <Button
                      size="sm"
                      disabled={busy || !canImport || !fix.uom}
                      onClick={() => void onResolve(row, "set_uom")}
                    >
                      {vi.master.import.applyFix}
                    </Button>
                  </div>
                  {canManageUom && (
                    <div className="flex gap-1">
                      <input
                        className="w-24 rounded-md border px-2 py-1 text-xs"
                        placeholder={vi.master.import.aliasPlaceholder}
                        value={fix.alias}
                        onChange={(e) =>
                          setFix({ ...fix, alias: e.target.value })
                        }
                      />
                      <select
                        className="rounded-md border px-2 py-1 text-xs"
                        value={fix.aliasUom}
                        onChange={(e) =>
                          setFix({ ...fix, aliasUom: e.target.value })
                        }
                      >
                        <option value="">—</option>
                        {uoms.map((u) => (
                          <option key={u.code} value={u.code}>
                            {u.code}
                          </option>
                        ))}
                      </select>
                      <Button
                        size="sm"
                        variant="outline"
                        disabled={busy || !fix.alias.trim() || !fix.aliasUom}
                        onClick={() => void onAddAlias(row)}
                      >
                        {vi.master.import.addAlias}
                      </Button>
                    </div>
                  )}
                </>
              )}
              {firstError?.code === "INVALID_FACTOR" && (
                <div className="flex gap-1">
                  <input
                    className="w-24 rounded-md border px-2 py-1 text-xs"
                    placeholder={vi.master.import.factorPlaceholder}
                    value={fix.factor}
                    onChange={(e) => setFix({ ...fix, factor: e.target.value })}
                  />
                  <Button
                    size="sm"
                    disabled={busy || !canImport || !fix.factor.trim()}
                    onClick={() => void onResolve(row, "set_factor")}
                  >
                    {vi.master.import.applyFix}
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={busy || !canImport}
                    onClick={() => void onResolve(row, "keep")}
                  >
                    {vi.master.import.actionKeep}
                  </Button>
                </div>
              )}
              {firstError?.code === "EMPTY_NAME" && (
                <Button
                  size="sm"
                  variant="outline"
                  disabled={busy || !canImport}
                  onClick={() => void onResolve(row, "skip")}
                >
                  {vi.master.import.actionSkip}
                </Button>
              )}
              {firstError?.code === "INVALID_VALUE" && (
                <Button
                  size="sm"
                  variant="outline"
                  disabled={busy || !canImport}
                  onClick={() => void onResolve(row, "skip")}
                >
                  {vi.master.import.actionSkip}
                </Button>
              )}
              {!firstError && row.status === "warning" && (
                <Button
                  size="sm"
                  variant="outline"
                  disabled={busy || !canImport}
                  onClick={() => void onResolve(row, "keep")}
                >
                  {vi.master.import.actionKeep}
                </Button>
              )}
            </div>
          )}
      </td>
    </tr>
  );
}
