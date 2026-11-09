"use client";

import { useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import {
  searchItemsAction,
  type ItemSearchResult,
} from "@/features/procurement/actions";

export type PickedItem = {
  id: string;
  code: string;
  name: string;
  stockUom: string;
};

/**
 * Ô tìm vật tư dùng chung cho form PR/PO (T-021): gõ tên/mã để tìm
 * (debounce 300ms, tối đa 10 kết quả), chọn để điền ĐVT lưu kho.
 * Khi đã chọn thì hiện chip vật tư kèm nút gỡ để quay về nhập mô tả
 * tự do.
 */
export function ItemPicker({
  propertyId,
  picked,
  onPick,
  onClear,
}: {
  propertyId: string;
  picked: PickedItem | null;
  onPick: (item: ItemSearchResult) => void;
  onClear: () => void;
}) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<ItemSearchResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [open, setOpen] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return () => {
      if (timer.current) clearTimeout(timer.current);
    };
  }, []);

  function handleQuery(value: string) {
    setQuery(value);
    setOpen(true);
    if (timer.current) clearTimeout(timer.current);
    if (!value.trim()) {
      setResults([]);
      setSearching(false);
      return;
    }
    setSearching(true);
    timer.current = setTimeout(async () => {
      const res = await searchItemsAction({
        propertyId,
        search: value.trim(),
      });
      setSearching(false);
      if (res.ok) setResults(res.data);
    }, 300);
  }

  if (picked) {
    return (
      <div className="flex items-center gap-2 rounded-md border bg-muted/40 px-3 py-2 text-sm">
        <span className="font-mono text-xs font-bold">{picked.code}</span>
        <span className="min-w-0 flex-1 truncate">{picked.name}</span>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-6 px-2 text-xs"
          onClick={() => {
            onClear();
            setQuery("");
          }}
        >
          ✕
        </Button>
      </div>
    );
  }

  return (
    <div className="relative">
      <input
        value={query}
        onChange={(e) => handleQuery(e.target.value)}
        onFocus={() => setOpen(true)}
        onBlur={() => {
          // Đợi click chọn kết quả trước khi đóng.
          setTimeout(() => setOpen(false), 150);
        }}
        placeholder={vi.procurement.form.itemSearchPlaceholder}
        className="h-9 w-full rounded-md border bg-background px-3 text-sm"
      />
      {open && query.trim() ? (
        <div className="absolute z-20 mt-1 w-full rounded-md border bg-background shadow-lg max-h-56 overflow-y-auto">
          {searching ? (
            <p className="px-3 py-2 text-sm text-muted-foreground">
              {vi.common.loading}
            </p>
          ) : results.length === 0 ? (
            <p className="px-3 py-2 text-sm text-muted-foreground">
              {vi.common.noData}
            </p>
          ) : (
            results.map((item) => (
              <button
                key={item.id}
                type="button"
                className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-muted"
                onMouseDown={(e) => {
                  e.preventDefault();
                  onPick(item);
                  setQuery("");
                  setResults([]);
                  setOpen(false);
                }}
              >
                <span className="font-mono text-xs font-bold">{item.code}</span>
                <span className="min-w-0 flex-1 truncate">{item.name}</span>
                <span className="text-xs text-muted-foreground">
                  {item.stockUom}
                </span>
              </button>
            ))
          )}
        </div>
      ) : null}
    </div>
  );
}
