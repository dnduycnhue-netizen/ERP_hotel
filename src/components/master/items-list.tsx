"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import type {
  ItemRow,
  ItemGroupRow,
  UomRow,
  PurchaseUnitRow,
} from "@/features/master/queries";
import {
  deleteItemAction,
  listPurchaseUnitsAction,
} from "@/features/master/actions";
import { ItemFormDialog } from "./item-form-dialog";
import { PurchaseUnitsDialog } from "./purchase-units-dialog";
import { TempItemCreateDialog } from "./temp-item-create-dialog";
import { ItemMergeDialog } from "./item-merge-dialog";

/** Nhãn badge mã tạm: quá 72h thì báo hết hạn, còn lại hiện số giờ tuổi. */
function tempBadgeText(row: ItemRow): string | null {
  if (!row.is_temp) return null;
  if (!row.temp_created_at) return vi.master.items.tempBadge;
  const ageHours = Math.floor(
    (Date.now() - new Date(row.temp_created_at).getTime()) / 3_600_000,
  );
  if (ageHours >= 72) return vi.master.items.tempExpired;
  return vi.master.items.tempAgeHours.replace("{hours}", String(ageHours));
}

export function ItemsList({
  propertyId,
  initialItems,
  total,
  groups,
  uoms,
  currentSearch = "",
  currentGroupId = "",
  currentFilter = "all",
  currentPage = 1,
  pageSize = 20,
}: {
  propertyId: string;
  initialItems: ItemRow[];
  total: number;
  groups: ItemGroupRow[];
  uoms: UomRow[];
  currentSearch?: string;
  currentGroupId?: string;
  currentFilter?: "all" | "key" | "temp" | "missing_conv";
  currentPage?: number;
  pageSize?: number;
}) {
  const router = useRouter();
  const canManage = useCan("item.manage");
  const canCreateTemp = useCan("item.temp.create");
  const canMerge = useCan("item.temp.normalize");

  const [formOpen, setFormOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<ItemRow | null>(null);

  const [tempCreateOpen, setTempCreateOpen] = useState(false);
  const [mergeOpen, setMergeOpen] = useState(false);
  const [mergingItem, setMergingItem] = useState<ItemRow | null>(null);

  const [unitsOpen, setUnitsOpen] = useState(false);
  const [activeItemForUnits, setActiveItemForUnits] = useState<ItemRow | null>(
    null,
  );
  const [itemUnits, setItemUnits] = useState<PurchaseUnitRow[]>([]);

  const [search, setSearch] = useState(currentSearch);
  const [selectedGroup, setSelectedGroup] = useState(currentGroupId);
  const [filter, setFilter] = useState<"all" | "key" | "temp" | "missing_conv">(
    currentFilter,
  );

  const [error, setError] = useState<string | null>(null);

  function applyFilters(newParams: {
    s?: string;
    g?: string;
    f?: "all" | "key" | "temp" | "missing_conv";
    p?: number;
  }) {
    const s = newParams.s !== undefined ? newParams.s : search;
    const g = newParams.g !== undefined ? newParams.g : selectedGroup;
    const f = newParams.f !== undefined ? newParams.f : filter;
    const p = newParams.p !== undefined ? newParams.p : 1;

    const query = new URLSearchParams();
    if (s.trim()) query.set("search", s.trim());
    if (g) query.set("group", g);
    if (f !== "all") query.set("filter", f);
    if (p > 1) query.set("page", String(p));

    router.push(`/${propertyId}/master/items?${query.toString()}`);
  }

  async function openPurchaseUnits(item: ItemRow) {
    setActiveItemForUnits(item);
    const units = await listPurchaseUnitsAction(item.id);
    setItemUnits(units);
    setUnitsOpen(true);
  }

  async function refreshPurchaseUnits() {
    if (!activeItemForUnits) return;
    const units = await listPurchaseUnitsAction(activeItemForUnits.id);
    setItemUnits(units);
  }

  async function handleDelete(item: ItemRow) {
    if (!confirm(vi.master.items.deleteConfirm)) return;
    setError(null);
    const res = await deleteItemAction(propertyId, item.id);
    if (res.ok) {
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const columns: DataTableColumn<ItemRow>[] = [
    {
      key: "code",
      header: vi.master.items.code,
      cell: (row) => (
        <span className="font-mono font-medium text-xs">{row.code}</span>
      ),
    },
    {
      key: "name",
      header: vi.master.items.name,
      cell: (row) => (
        <div>
          <div className="flex items-center gap-2">
            <span className="font-medium text-foreground">{row.name}</span>
            {row.is_key_item ? (
              <span className="rounded bg-amber-500/10 px-1.5 py-0.5 text-[10px] font-semibold text-amber-600">
                {vi.master.items.keyItemBadge}
              </span>
            ) : null}
            {row.is_temp ? (
              <span className="rounded bg-destructive/10 px-1.5 py-0.5 text-[10px] font-semibold text-destructive">
                {tempBadgeText(row)}
              </span>
            ) : null}
          </div>
          {row.name_en ? (
            <span className="text-xs text-muted-foreground block">
              {row.name_en}
            </span>
          ) : null}
        </div>
      ),
    },
    {
      key: "group",
      header: vi.master.items.group,
      cell: (row) => row.group_name || "—",
    },
    {
      key: "stock_uom",
      header: vi.master.items.stockUom,
      cell: (row) => (
        <span className="font-semibold text-xs">{row.stock_uom}</span>
      ),
    },
    {
      key: "conversion",
      header: vi.master.items.recipeUomHeader,
      cell: (row) =>
        row.recipe_uom ? (
          <span className="text-xs">
            1 {row.stock_uom} = {row.stock_to_recipe ?? "—"} {row.recipe_uom}
          </span>
        ) : (
          <span className="text-xs text-muted-foreground">—</span>
        ),
    },
    {
      key: "allowed_channels",
      header: vi.master.items.allowedChannels,
      cell: (row) => (
        <span className="text-xs">
          {row.allowed_channels
            .map((c) =>
              c === "contract"
                ? vi.master.items.channelContractShort
                : vi.master.items.channelMarket,
            )
            .join(", ")}
        </span>
      ),
    },
    {
      key: "status",
      header: vi.master.items.status,
      cell: (row) => (
        <span
          className={`rounded-full px-2 py-0.5 text-[11px] font-medium ${
            row.status === "active"
              ? "bg-emerald-500/10 text-emerald-600"
              : "bg-muted text-muted-foreground"
          }`}
        >
          {row.status === "active"
            ? vi.master.items.statusActive
            : row.status === "merged"
              ? vi.master.items.tempMerged
              : vi.master.items.statusInactive}
        </span>
      ),
    },
    {
      key: "actions",
      header: vi.common.actions,
      align: "right",
      cell: (row) => (
        <div className="flex items-center justify-end gap-1">
          <Button
            variant="ghost"
            size="sm"
            className="text-xs h-7 px-2"
            onClick={() => openPurchaseUnits(row)}
          >
            {vi.master.items.purchaseUomHeader}
          </Button>
          {row.is_temp && row.status === "active" && canMerge ? (
            <Button
              variant="outline"
              size="sm"
              className="text-xs h-7 px-2"
              onClick={() => {
                setMergingItem(row);
                setMergeOpen(true);
              }}
            >
              {vi.master.items.merge}
            </Button>
          ) : null}
          {canManage ? (
            <>
              <Button
                variant="outline"
                size="sm"
                className="text-xs h-7 px-2"
                onClick={() => {
                  setEditingItem(row);
                  setFormOpen(true);
                }}
              >
                {vi.master.items.editItem}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
                onClick={() => handleDelete(row)}
              >
                {vi.master.items.deleteItem}
              </Button>
            </>
          ) : null}
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-4">
      <PageHeader
        title={vi.master.items.title}
        description={vi.master.items.description}
      />
      {error ? (
        <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}

      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-wrap items-center gap-2">
          {/* Quick filter pills */}
          <button
            type="button"
            onClick={() => {
              setFilter("all");
              applyFilters({ f: "all", p: 1 });
            }}
            className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
              filter === "all"
                ? "bg-foreground text-background"
                : "bg-muted text-muted-foreground hover:bg-muted/80"
            }`}
          >
            {vi.common.all} ({total})
          </button>
          <button
            type="button"
            onClick={() => {
              setFilter("key");
              applyFilters({ f: "key", p: 1 });
            }}
            className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
              filter === "key"
                ? "bg-amber-600 text-white"
                : "bg-amber-500/10 text-amber-700 hover:bg-amber-500/20"
            }`}
          >
            {vi.master.items.keyItemFilterButton}
          </button>
          <button
            type="button"
            onClick={() => {
              setFilter("temp");
              applyFilters({ f: "temp", p: 1 });
            }}
            className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
              filter === "temp"
                ? "bg-destructive text-white"
                : "bg-destructive/10 text-destructive hover:bg-destructive/20"
            }`}
          >
            {vi.master.items.tempBadge}
          </button>
          <button
            type="button"
            onClick={() => {
              setFilter("missing_conv");
              applyFilters({ f: "missing_conv", p: 1 });
            }}
            className={`rounded-full px-3 py-1 text-xs font-medium transition-colors ${
              filter === "missing_conv"
                ? "bg-indigo-600 text-white"
                : "bg-indigo-500/10 text-indigo-700 hover:bg-indigo-500/20"
            }`}
          >
            {vi.master.items.filterMissingConversion}
          </button>
        </div>

        <div className="flex gap-2">
          {canCreateTemp ? (
            <Button
              variant="outline"
              size="sm"
              onClick={() => setTempCreateOpen(true)}
            >
              + {vi.master.items.createTemp}
            </Button>
          ) : null}
          {canManage ? (
            <Button
              size="sm"
              onClick={() => {
                setEditingItem(null);
                setFormOpen(true);
              }}
            >
              + {vi.master.items.addItem}
            </Button>
          ) : null}
        </div>
      </div>

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search
            className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
            aria-hidden
          />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") applyFilters({ s: search, p: 1 });
            }}
            placeholder={vi.master.items.searchPlaceholder}
            aria-label={vi.master.items.searchPlaceholder}
            className="h-9 w-full rounded-md border bg-background pr-3 pl-9 text-sm outline-none placeholder:text-muted-foreground focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </div>
        <div className="w-full sm:w-64">
          <select
            value={selectedGroup}
            onChange={(e) => {
              setSelectedGroup(e.target.value);
              applyFilters({ g: e.target.value, p: 1 });
            }}
            aria-label={vi.master.items.filterAllGroups}
            className="h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <option value="">{vi.master.items.filterAllGroups}</option>
            {groups.map((g) => (
              <option key={g.id} value={g.id}>
                {g.code_prefix} - {g.name}
              </option>
            ))}
          </select>
        </div>
        <Button
          variant="outline"
          size="lg"
          onClick={() => applyFilters({ s: search, g: selectedGroup, p: 1 })}
        >
          {vi.common.search}
        </Button>
      </div>

      <DataTable
        columns={columns}
        rows={initialItems}
        emptyTitle={vi.master.items.emptyList}
        pagination={{
          page: currentPage,
          pageSize,
          total,
          onPageChange: (p) => applyFilters({ p }),
        }}
      />

      {formOpen ? (
        <ItemFormDialog
          propertyId={propertyId}
          item={editingItem}
          groups={groups}
          uoms={uoms}
          open={formOpen}
          onClose={() => {
            setFormOpen(false);
            setEditingItem(null);
          }}
          onSuccess={() => {
            setFormOpen(false);
            setEditingItem(null);
            router.refresh();
          }}
        />
      ) : null}

      {tempCreateOpen ? (
        <TempItemCreateDialog
          propertyId={propertyId}
          groups={groups}
          uoms={uoms}
          open={tempCreateOpen}
          onClose={() => setTempCreateOpen(false)}
          onSuccess={() => router.refresh()}
        />
      ) : null}

      {mergeOpen && mergingItem ? (
        <ItemMergeDialog
          propertyId={propertyId}
          item={mergingItem}
          open={mergeOpen}
          onClose={() => {
            setMergeOpen(false);
            setMergingItem(null);
          }}
          onSuccess={() => router.refresh()}
        />
      ) : null}

      {unitsOpen && activeItemForUnits ? (
        <PurchaseUnitsDialog
          propertyId={propertyId}
          item={activeItemForUnits}
          uoms={uoms}
          units={itemUnits}
          open={unitsOpen}
          onClose={() => {
            setUnitsOpen(false);
            setActiveItemForUnits(null);
          }}
          onRefresh={refreshPurchaseUnits}
        />
      ) : null}
    </div>
  );
}
