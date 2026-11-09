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
import type { ExpenseCategoryRow } from "@/features/master/queries";
import {
  saveExpenseCategoryAction,
  deleteExpenseCategoryAction,
} from "@/features/master/actions";

const usaliDepartments = [
  "Rooms",
  "F&B Food",
  "F&B Beverage",
  "Other Operated Departments",
  "Administrative & General",
  "Information & Telecommunications",
  "Sales & Marketing",
  "Property Operation & Maintenance",
  "Utilities",
  "Management Fees",
  "Non-Operating Income & Expenses",
];

export function ExpenseCategoriesManager({
  propertyId,
  categories,
}: {
  propertyId: string;
  categories: ExpenseCategoryRow[];
}) {
  const router = useRouter();
  const canManage = useCan("item.manage");

  const [open, setOpen] = useState(false);
  const [editingCategory, setEditingCategory] =
    useState<ExpenseCategoryRow | null>(null);
  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [usaliLine, setUsaliLine] = useState("");
  const [parentId, setParentId] = useState("");

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function startCreate() {
    setEditingCategory(null);
    setCode("");
    setName("");
    setUsaliLine("");
    setParentId("");
    setError(null);
    setOpen(true);
  }

  function startEdit(c: ExpenseCategoryRow) {
    setEditingCategory(c);
    setCode(c.code);
    setName(c.name);
    setUsaliLine(c.usali_line || "");
    setParentId(c.parent_id || "");
    setError(null);
    setOpen(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await saveExpenseCategoryAction({
      id: editingCategory?.id,
      propertyId,
      code,
      name,
      usaliLine: usaliLine || null,
      parentId: parentId || null,
    });

    setSaving(false);
    if (res.ok) {
      setOpen(false);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDelete(c: ExpenseCategoryRow) {
    if (!confirm(vi.master.expenseCategories.deleteConfirm)) return;
    setError(null);
    const res = await deleteExpenseCategoryAction(propertyId, c.id);
    if (res.ok) {
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const columns: DataTableColumn<ExpenseCategoryRow>[] = [
    {
      key: "code",
      header: vi.master.expenseCategories.code,
      cell: (row) => (
        <span className="font-mono font-bold text-xs">{row.code}</span>
      ),
    },
    {
      key: "name",
      header: vi.master.expenseCategories.name,
      cell: (row) => <span className="font-medium">{row.name}</span>,
    },
    {
      key: "usali_line",
      header: vi.master.expenseCategories.usaliLine,
      cell: (row) =>
        row.usali_line ? (
          <span className="text-xs">{row.usali_line}</span>
        ) : (
          "—"
        ),
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
              {vi.master.expenseCategories.editCategory}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
              onClick={() => handleDelete(row)}
            >
              {vi.master.expenseCategories.deleteCategory}
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
          <h2 className="text-lg font-semibold">
            {vi.master.expenseCategories.title}
          </h2>
          <p className="text-xs text-muted-foreground mt-0.5">
            {vi.master.expenseCategories.description}
          </p>
        </div>
        {canManage ? (
          <Button size="sm" onClick={startCreate}>
            + {vi.master.expenseCategories.addCategory}
          </Button>
        ) : null}
      </div>

      <DataTable columns={columns} rows={categories} />

      {open ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editingCategory
                  ? vi.master.expenseCategories.editCategory
                  : vi.master.expenseCategories.addCategory}
              </h3>
              <Button variant="ghost" size="sm" onClick={() => setOpen(false)}>
                ✕
              </Button>
            </div>

            <form onSubmit={handleSave} className="mt-4 space-y-3">
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="expCode"
                >
                  {vi.master.expenseCategories.code} *
                </label>
                <input
                  id="expCode"
                  required
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  placeholder="VD: EXP_FOOD, EXP_LINEN, EXP_ENERGY"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm font-mono"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="expName"
                >
                  {vi.master.expenseCategories.name} *
                </label>
                <input
                  id="expName"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="VD: Chi phí thực phẩm, Chi phí đồ giặt"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="usaliLine"
                >
                  {vi.master.expenseCategories.usaliLine}
                </label>
                <select
                  id="usaliLine"
                  value={usaliLine}
                  onChange={(e) => setUsaliLine(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="">— Chưa phân nhóm USALI —</option>
                  {usaliDepartments.map((dept) => (
                    <option key={dept} value={dept}>
                      {dept}
                    </option>
                  ))}
                </select>
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
