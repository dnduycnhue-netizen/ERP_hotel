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
import type { ItemGroupRow } from "@/features/master/queries";
import type { ItemGroupSaveInput } from "@/features/master/schemas";
import {
  saveItemGroupAction,
  deleteItemGroupAction,
} from "@/features/master/actions";

const groupKinds = [
  { value: "food", label: vi.master.itemGroups.kindLabels.food },
  { value: "beverage", label: vi.master.itemGroups.kindLabels.beverage },
  { value: "amenity", label: vi.master.itemGroups.kindLabels.amenity },
  {
    value: "complimentary",
    label: vi.master.itemGroups.kindLabels.complimentary,
  },
  { value: "collateral", label: vi.master.itemGroups.kindLabels.collateral },
  { value: "linen", label: vi.master.itemGroups.kindLabels.linen },
  { value: "chemical", label: vi.master.itemGroups.kindLabels.chemical },
  { value: "tool", label: vi.master.itemGroups.kindLabels.tool },
  { value: "minibar", label: vi.master.itemGroups.kindLabels.minibar },
  { value: "engineering", label: vi.master.itemGroups.kindLabels.engineering },
  { value: "ccdc", label: vi.master.itemGroups.kindLabels.ccdc },
  { value: "other", label: vi.master.itemGroups.kindLabels.other },
];

export function ItemGroupsManager({
  propertyId,
  groups,
}: {
  propertyId: string;
  groups: ItemGroupRow[];
}) {
  const router = useRouter();
  const canManage = useCan("item.manage");

  const [open, setOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<ItemGroupRow | null>(null);
  const [codePrefix, setCodePrefix] = useState("");
  const [name, setName] = useState("");
  const [kind, setKind] = useState<ItemGroupSaveInput["kind"]>("food");
  const [parentId, setParentId] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function startCreate() {
    setEditingGroup(null);
    setCodePrefix("");
    setName("");
    setKind("food");
    setParentId("");
    setError(null);
    setOpen(true);
  }

  function startEdit(g: ItemGroupRow) {
    setEditingGroup(g);
    setCodePrefix(g.code_prefix);
    setName(g.name);
    setKind(g.kind as ItemGroupSaveInput["kind"]);
    setParentId(g.parent_id || "");
    setError(null);
    setOpen(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await saveItemGroupAction({
      id: editingGroup?.id,
      propertyId,
      codePrefix,
      name,
      kind,
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

  async function handleDelete(g: ItemGroupRow) {
    if (!confirm(vi.master.itemGroups.deleteConfirm)) return;
    setError(null);
    const res = await deleteItemGroupAction(propertyId, g.id);
    if (res.ok) {
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const columns: DataTableColumn<ItemGroupRow>[] = [
    {
      key: "code_prefix",
      header: vi.master.itemGroups.codePrefix,
      cell: (row) => (
        <span className="font-mono font-bold text-xs">{row.code_prefix}</span>
      ),
    },
    {
      key: "name",
      header: vi.master.itemGroups.name,
      cell: (row) => <span className="font-medium">{row.name}</span>,
    },
    {
      key: "kind",
      header: vi.master.itemGroups.kind,
      cell: (row) => {
        const found = groupKinds.find((k) => k.value === row.kind);
        return <span className="text-xs">{found?.label ?? row.kind}</span>;
      },
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
              {vi.master.itemGroups.editGroup}
            </Button>
            <Button
              variant="ghost"
              size="sm"
              className="text-xs h-7 px-2 text-destructive hover:bg-destructive/10"
              onClick={() => handleDelete(row)}
            >
              {vi.master.itemGroups.deleteGroup}
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
        title={vi.master.itemGroups.title}
        description={vi.master.itemGroups.description}
        actions={
          canManage ? (
            <Button size="sm" onClick={startCreate}>
              + {vi.master.itemGroups.addGroup}
            </Button>
          ) : null
        }
      />

      <DataTable columns={columns} rows={groups} />

      {open ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {editingGroup
                  ? vi.master.itemGroups.editGroup
                  : vi.master.itemGroups.addGroup}
              </h3>
              <Button variant="ghost" size="sm" onClick={() => setOpen(false)}>
                ✕
              </Button>
            </div>

            <form onSubmit={handleSave} className="mt-4 space-y-3">
              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="codePrefix"
                >
                  {vi.master.itemGroups.codePrefix} *
                </label>
                <input
                  id="codePrefix"
                  required
                  value={codePrefix}
                  onChange={(e) => setCodePrefix(e.target.value)}
                  placeholder="VD: TP, DU, AMN"
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="groupName"
                >
                  {vi.master.itemGroups.name} *
                </label>
                <input
                  id="groupName"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder={vi.master.itemGroups.examplePlaceholder}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>

              <div>
                <label
                  className="text-xs font-medium text-muted-foreground"
                  htmlFor="kind"
                >
                  {vi.master.itemGroups.kind} *
                </label>
                <select
                  id="kind"
                  required
                  value={kind}
                  onChange={(e) =>
                    setKind(e.target.value as ItemGroupSaveInput["kind"])
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  {groupKinds.map((k) => (
                    <option key={k.value} value={k.value}>
                      {k.label}
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
