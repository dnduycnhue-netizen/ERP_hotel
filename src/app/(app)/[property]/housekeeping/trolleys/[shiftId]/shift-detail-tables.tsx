"use client";

import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import type {
  TrolleyConsumptionRow,
  TrolleyCountLine,
} from "@/features/trolley/queries";
import { vi } from "@/i18n/vi";

type CountRow = TrolleyCountLine & { id: string };
type ConsumptionRow = TrolleyConsumptionRow & { id: string };

const countColumns: DataTableColumn<CountRow>[] = [
  {
    key: "item_code",
    header: vi.minibar.itemCode,
    cell: (row) => row.item_code,
  },
  {
    key: "item_name",
    header: vi.minibar.itemName,
    cell: (row) => row.item_name,
  },
  {
    key: "qty",
    header: vi.trolley.countedQty,
    align: "right",
    cell: (row) => `${row.qty}${row.stock_uom ? ` ${row.stock_uom}` : ""}`,
  },
];

const consumptionColumns: DataTableColumn<ConsumptionRow>[] = [
  {
    key: "item_code",
    header: vi.minibar.itemCode,
    cell: (row) => row.item_code,
  },
  {
    key: "item_name",
    header: vi.minibar.itemName,
    cell: (row) => row.item_name,
  },
  {
    key: "opening_qty",
    header: vi.trolley.openingQty,
    align: "right",
    cell: (row) => row.opening_qty,
  },
  {
    key: "received_qty",
    header: vi.trolley.receivedQty,
    align: "right",
    cell: (row) => row.received_qty,
  },
  {
    key: "closing_qty",
    header: vi.trolley.closingQty,
    align: "right",
    cell: (row) => row.closing_qty,
  },
  {
    key: "consumed_qty",
    header: vi.trolley.consumedQty,
    align: "right",
    cell: (row) => row.consumed_qty,
  },
];

/**
 * Bảng số đếm đầu/cuối ca + bảng tiêu hao (Q203): cột `cell` là hàm
 * nên phải định nghĩa ở phía client — trang server chỉ được truyền dữ
 * liệu thuần (rows) sang. Truyền hàm từ Server Component sang Client
 * Component làm React nổ lỗi serialize ("Functions cannot be passed
 * directly to Client Components") và trang sập hoàn toàn.
 */
export function ShiftCountTable({ rows }: { rows: CountRow[] }) {
  return (
    <DataTable
      columns={countColumns}
      rows={rows}
      emptyTitle={vi.trolley.shiftsEmpty}
    />
  );
}

export function ShiftConsumptionTable({ rows }: { rows: ConsumptionRow[] }) {
  return (
    <DataTable
      columns={consumptionColumns}
      rows={rows}
      emptyTitle={vi.trolley.shiftsEmpty}
    />
  );
}
