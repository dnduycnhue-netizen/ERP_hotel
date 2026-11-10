"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { MoneyText } from "@/components/common/money-text";
import type { AdvanceRow } from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";

const STATUS_LABELS: Record<string, string> = {
  requested: vi.components.docStatus.requested,
  approved: vi.components.docStatus.approved,
  disbursed: vi.components.docStatus.disbursed,
  settling: vi.components.docStatus.settling,
  settled: vi.components.docStatus.settled,
  overdue: vi.components.docStatus.overdue,
};

/** Danh sách tạm ứng (T-041): lọc theo trạng thái, quá hạn tô đỏ. */
export function AdvanceList({
  propertyId,
  advances,
}: {
  propertyId: string;
  advances: AdvanceRow[];
}) {
  const [status, setStatus] = useState("");
  const filtered = useMemo(
    () =>
      status === "" ? advances : advances.filter((a) => a.status === status),
    [advances, status],
  );
  const statuses = [...new Set(advances.map((a) => a.status))];

  return (
    <div className="space-y-4">
      <label className="block max-w-xs text-sm">
        {vi.common.status}
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
        >
          <option value="">{vi.common.all}</option>
          {statuses.map((s) => (
            <option key={s} value={s}>
              {STATUS_LABELS[s] ?? s}
            </option>
          ))}
        </select>
      </label>
      {filtered.length === 0 ? (
        <p className="rounded-xl border bg-card p-4 text-sm text-muted-foreground">
          {vi.components.table.emptyDescription}
        </p>
      ) : (
        <div className="overflow-x-auto rounded-xl border bg-card">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-3 py-2">{vi.finance.advanceDocNo}</th>
                <th className="px-3 py-2">{vi.finance.employee}</th>
                <th className="px-3 py-2">{vi.finance.purpose}</th>
                <th className="px-3 py-2 text-right">
                  {vi.finance.totalAmount}
                </th>
                <th className="px-3 py-2">{vi.finance.dueSettle}</th>
                <th className="px-3 py-2">{vi.common.status}</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((a) => (
                <tr key={a.id} className="border-b last:border-0">
                  <td className="px-3 py-2">
                    <Link
                      href={`/${propertyId}/finance/advances/${a.id}`}
                      className="font-medium hover:underline"
                    >
                      {a.doc_no}
                    </Link>
                  </td>
                  <td className="px-3 py-2">
                    {a.employee_name ?? vi.common.noData}
                  </td>
                  <td className="px-3 py-2">{a.purpose}</td>
                  <td className="px-3 py-2 text-right">
                    <MoneyText amount={a.amount} />
                  </td>
                  <td className="px-3 py-2">
                    {a.due_settle_at ?? vi.common.noData}
                  </td>
                  <td
                    className={
                      a.status === "overdue"
                        ? "px-3 py-2 font-medium text-red-800"
                        : "px-3 py-2"
                    }
                  >
                    {STATUS_LABELS[a.status] ?? a.status}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
