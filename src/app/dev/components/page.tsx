"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { ConfirmPostDialog } from "@/components/common/confirm-post-dialog";
import { DataTable } from "@/components/common/data-table";
import {
  DocStatusBadge,
  type DocStatus,
} from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { MoneyText } from "@/components/common/money-text";
import { PinDialog } from "@/components/common/pin-dialog";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";

const ALL_STATUSES: DocStatus[] = [
  "draft",
  "submitted",
  "pending",
  "approved",
  "rejected",
  "sent",
  "partially_received",
  "received",
  "closed",
  "cancelled",
  "posted",
  "reversed",
  "needs_recount",
  "matched",
  "on_hold",
  "partially_paid",
  "paid",
  "settled",
  "overdue",
  "requested",
  "disbursed",
  "settling",
  "in_transit",
  "issued",
  "locked",
];

type SampleOrder = {
  id: string;
  docNo: string;
  supplier: string;
  amount: number;
  status: DocStatus;
};

const SAMPLE_ORDERS: SampleOrder[] = [
  {
    id: "1",
    docNo: "PO-0001",
    supplier: "NCC Hải sản Phú Quốc",
    amount: 12500000,
    status: "submitted",
  },
  {
    id: "2",
    docNo: "PO-0002",
    supplier: "NCC Rau củ Đà Lạt",
    amount: 8300000,
    status: "approved",
  },
  {
    id: "3",
    docNo: "PO-0003",
    supplier: "NCC Thịt An Phước",
    amount: 27400000,
    status: "posted",
  },
  {
    id: "4",
    docNo: "PO-0004",
    supplier: "NCC Đồ khô Chợ Lớn",
    amount: 4920000,
    status: "rejected",
  },
  {
    id: "5",
    docNo: "PO-0005",
    supplier: "NCC Gạo ST25",
    amount: 15800000,
    status: "sent",
  },
];

const PAGE_SIZE = 3;
const RPC_SAMPLE_CODES = [
  "ERR_FORBIDDEN:po.approve",
  "ERR_SELF_GRANT",
  "ERR_LAST_ADMIN",
  "ERR_DOC_POSTED",
  "ERR_NEGATIVE_STOCK",
  "ERR_PIN_INVALID",
  "ERR_SOD_PO_CREATOR_APPROVER",
  "ERR_UNKNOWN_CODE",
];

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-xl border bg-card p-6 shadow-sm">
      <h2 className="text-lg font-semibold">{title}</h2>
      <div className="mt-4">{children}</div>
    </section>
  );
}

export default function DevComponentsPage() {
  const [page, setPage] = useState(1);
  const [tableError, setTableError] = useState<string | null>(null);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [confirmDone, setConfirmDone] = useState(false);
  const [pinOpen, setPinOpen] = useState(false);
  const [pinDone, setPinDone] = useState(false);

  const pagedRows = SAMPLE_ORDERS.slice(
    (page - 1) * PAGE_SIZE,
    page * PAGE_SIZE,
  );

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-4xl flex-col gap-6 px-4 py-10">
      <header>
        <h1 className="text-2xl font-semibold">{vi.dev.componentsTitle}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.dev.componentsDescription}
        </p>
      </header>

      <Section title={vi.dev.docStatusTitle}>
        <div className="flex flex-wrap gap-2">
          {ALL_STATUSES.map((status) => (
            <DocStatusBadge key={status} status={status} />
          ))}
          <DocStatusBadge status="trang_thai_la" />
        </div>
      </Section>

      <Section title={vi.dev.moneyTitle}>
        <dl className="space-y-2 text-sm">
          <div className="flex gap-4">
            <dt className="w-40 text-muted-foreground">Số dương</dt>
            <dd>
              <MoneyText amount={12500000} />
            </dd>
          </div>
          <div className="flex gap-4">
            <dt className="w-40 text-muted-foreground">Số âm</dt>
            <dd>
              <MoneyText amount={-250000} />
            </dd>
          </div>
          <div className="flex gap-4">
            <dt className="w-40 text-muted-foreground">Chuỗi từ Postgres</dt>
            <dd>
              <MoneyText amount="8325000.50" />
            </dd>
          </div>
          <div className="flex gap-4">
            <dt className="w-40 text-muted-foreground">Không có số</dt>
            <dd>
              <MoneyText amount={null} />
            </dd>
          </div>
        </dl>
      </Section>

      <Section title={vi.dev.tableTitle}>
        <h3 className="mb-2 text-sm font-medium">{vi.dev.tableWithData}</h3>
        <DataTable<SampleOrder>
          columns={[
            { key: "docNo", header: "Số chứng từ" },
            { key: "supplier", header: "Nhà cung cấp" },
            {
              key: "amount",
              header: "Tổng tiền",
              align: "right",
              cell: (row) => <MoneyText amount={row.amount} />,
            },
            {
              key: "status",
              header: "Trạng thái",
              cell: (row) => <DocStatusBadge status={row.status} />,
            },
          ]}
          rows={pagedRows}
          pagination={{
            page,
            pageSize: PAGE_SIZE,
            total: SAMPLE_ORDERS.length,
            onPageChange: setPage,
          }}
        />

        <h3 className="mt-8 mb-2 text-sm font-medium">{vi.dev.tableEmpty}</h3>
        <DataTable<SampleOrder>
          columns={[
            { key: "docNo", header: "Số chứng từ" },
            { key: "supplier", header: "Nhà cung cấp" },
          ]}
          rows={[]}
        />

        <h3 className="mt-8 mb-2 text-sm font-medium">{vi.dev.tableLoading}</h3>
        <DataTable<SampleOrder>
          columns={[
            { key: "docNo", header: "Số chứng từ" },
            { key: "supplier", header: "Nhà cung cấp" },
          ]}
          rows={[]}
          loading
        />

        <h3 className="mt-8 mb-2 text-sm font-medium">{vi.dev.tableError}</h3>
        <DataTable<SampleOrder>
          columns={[
            { key: "docNo", header: "Số chứng từ" },
            { key: "supplier", header: "Nhà cung cấp" },
          ]}
          rows={[]}
          error={tableError ?? "Không thể tải dữ liệu. Vui lòng thử lại."}
          onRetry={() => setTableError(null)}
        />
        <Button
          variant="outline"
          size="sm"
          className="mt-2"
          onClick={() => setTableError("Lỗi kết nối cơ sở dữ liệu (bản demo).")}
        >
          Giả lập lỗi tải lại
        </Button>
      </Section>

      <Section title={vi.dev.emptyTitle}>
        <EmptyState
          title="Chưa có phiếu nhập kho"
          description="Khi có phiếu nhập kho mới, danh sách sẽ hiện ở đây."
          action={<Button size="sm">Tạo phiếu nhập kho</Button>}
        />
      </Section>

      <Section title={vi.dev.errorTitle}>
        <ErrorState onRetry={() => window.location.reload()} />
      </Section>

      <Section title={vi.dev.confirmPostTitle}>
        <Button onClick={() => setConfirmOpen(true)}>
          {vi.dev.confirmPostOpen}
        </Button>
        {confirmDone ? (
          <p className="mt-2 text-sm text-green-700">
            {vi.dev.confirmPostDone}
          </p>
        ) : null}
        <ConfirmPostDialog
          open={confirmOpen}
          onOpenChange={setConfirmOpen}
          docNo="GR-0007"
          onConfirm={() => {
            setConfirmOpen(false);
            setConfirmDone(true);
          }}
        />
      </Section>

      <Section title={vi.dev.pinTitle}>
        <Button onClick={() => setPinOpen(true)}>{vi.dev.pinOpen}</Button>
        {pinDone ? (
          <p className="mt-2 text-sm text-green-700">{vi.dev.pinDone}</p>
        ) : null}
        <PinDialog
          open={pinOpen}
          onOpenChange={setPinOpen}
          onSubmit={() => {
            setPinOpen(false);
            setPinDone(true);
          }}
        />
      </Section>

      <Section title={vi.dev.rpcErrorsTitle}>
        <dl className="space-y-2 text-sm">
          {RPC_SAMPLE_CODES.map((code) => (
            <div
              key={code}
              className="flex flex-col gap-0.5 sm:flex-row sm:gap-4"
            >
              <dt className="w-72 shrink-0 font-mono text-xs">{code}</dt>
              <dd className="text-muted-foreground">
                {getRpcErrorMessage(code)}
              </dd>
            </div>
          ))}
        </dl>
      </Section>
    </main>
  );
}
