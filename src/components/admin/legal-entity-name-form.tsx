"use client";

import { useState, useTransition } from "react";
import { Pencil } from "lucide-react";
import { Button } from "@/components/ui/button";
import { updateLegalEntityNameAction } from "@/features/admin/actions";
import { vi } from "@/i18n/vi";

/**
 * Sửa tên pháp nhân ngay tại trang chi tiết tổ chức (Q209). Trang cha đã
 * chặn 404 khi người xem không có quyền admin.org.manage nên ở đây không
 * kiểm tra lại. Sau khi lưu, server action revalidate trang chi tiết nên
 * tên mới hiện ngay; component được remount theo key tên ở trang cha để
 * state input đồng bộ với tên mới.
 */
export function LegalEntityNameForm({
  orgId,
  legalEntityId,
  currentName,
}: {
  orgId: string;
  legalEntityId: string;
  currentName: string;
}) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(currentName);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const openEditor = () => {
    setName(currentName);
    setError(null);
    setEditing(true);
  };

  const save = () => {
    setError(null);
    startTransition(async () => {
      const result = await updateLegalEntityNameAction({
        orgId,
        legalEntityId,
        name,
      });
      if (result.ok) {
        setEditing(false);
      } else {
        setError(result.error);
      }
    });
  };

  if (!editing) {
    return (
      <div className="flex items-center justify-between gap-2">
        <span>{currentName}</span>
        <button
          type="button"
          onClick={openEditor}
          aria-label={vi.admin.legalNameEdit}
          title={vi.admin.legalNameEdit}
          className="shrink-0 rounded-md p-1 text-muted-foreground outline-none hover:bg-accent hover:text-foreground focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          <Pencil className="size-3.5" aria-hidden />
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <label className="sr-only" htmlFor="legal-entity-name">
        {vi.admin.legalName}
      </label>
      <input
        id="legal-entity-name"
        value={name}
        onChange={(event) => setName(event.target.value)}
        maxLength={200}
        disabled={pending}
        className="h-8 w-full rounded-md border bg-background px-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
      />
      {error ? (
        <p role="alert" className="text-xs text-destructive">
          {error}
        </p>
      ) : null}
      <div className="flex gap-2">
        <Button type="button" size="sm" disabled={pending} onClick={save}>
          {pending ? vi.common.submitting : vi.common.save}
        </Button>
        <Button
          type="button"
          size="sm"
          variant="outline"
          disabled={pending}
          onClick={() => {
            setError(null);
            setEditing(false);
          }}
        >
          {vi.common.cancel}
        </Button>
      </div>
    </div>
  );
}
