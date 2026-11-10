"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { AttachmentGallery } from "@/components/common/attachment-gallery";
import { MoneyText } from "@/components/common/money-text";
import type { ServiceContractDetail } from "@/features/service/queries";
import { daysLeft } from "@/features/service/dates";
import type { ServiceScheduleRow } from "@/features/service/queries";
import { AcceptForm } from "./accept-form";
import { PageHeader } from "@/components/shell/page-header";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

const STATUS_LABELS: Record<string, string> = {
  draft: vi.service.statusDraft,
  active: vi.service.statusActive,
  suspended: vi.service.statusSuspended,
  expired: vi.service.statusExpired,
  cancelled: vi.service.statusCancelled,
};

const CYCLE_LABELS: Record<string, string> = {
  monthly: vi.service.cycleMonthly,
  quarterly: vi.service.cycleQuarterly,
  yearly: vi.service.cycleYearly,
  per_visit: vi.service.cyclePerVisit,
};

const SCHEDULE_STATUS_LABELS: Record<string, string> = {
  scheduled: vi.service.scheduleScheduled,
  performed: vi.service.schedulePerformed,
  accepted: vi.service.scheduleAccepted,
  invoiced: vi.service.scheduleInvoiced,
  paid: vi.service.schedulePaid,
  skipped: vi.service.scheduleSkipped,
};

/**
 * Chi tiết hợp đồng dịch vụ (T-042): thông tin hợp đồng + lịch các kỳ
 * + nghiệm thu từng kỳ. Banner gia hạn hiện khi hợp đồng sắp hết hạn
 * trong `renew_notice_days` (05 §9).
 */
export function ContractDetail({
  propertyId,
  detail,
  canManageContract,
  canAccept,
}: {
  propertyId: string;
  detail: ServiceContractDetail;
  canManageContract: boolean;
  canAccept: boolean;
}) {
  const [acceptSchedule, setAcceptSchedule] =
    useState<ServiceScheduleRow | null>(null);
  const { contract, schedules } = detail;

  const remaining =
    contract.status === "active" && contract.end_date
      ? daysLeft(contract.end_date)
      : null;
  const renewalSoon =
    remaining !== null &&
    remaining >= 0 &&
    remaining <= contract.renew_notice_days;
  const renewalOverdue = remaining !== null && remaining < 0;

  return (
    <div className="space-y-6">
      <div className="rounded-lg border bg-card p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <PageHeader
              title={contract.title}
              description={
                <>
                  {contract.supplier_name ?? vi.common.noData} ·{" "}
                  {contract.expense_category_name ?? vi.common.noData} ·{" "}
                  {contract.cost_center_name ?? vi.common.noData}
                </>
              }
            />
            <p className="mt-1 text-sm text-muted-foreground">
              {CYCLE_LABELS[contract.billing_cycle] ?? contract.billing_cycle} ·{" "}
              <MoneyText amount={contract.amount_per_cycle} /> /{" "}
              {vi.service.billingCycle.toLowerCase()} · {contract.start_date} →{" "}
              {contract.end_date ?? vi.service.noEndDate}
            </p>
          </div>
          <div className="flex items-center gap-2">
            <span
              className={cn(
                "rounded-full px-2 py-0.5 text-xs font-medium",
                contract.status === "active" && "bg-green-100 text-green-800",
                contract.status === "draft" && "bg-slate-100 text-slate-700",
                contract.status === "suspended" &&
                  "bg-amber-100 text-amber-800",
                contract.status === "expired" && "bg-red-100 text-red-800",
                contract.status === "cancelled" &&
                  "bg-slate-100 text-slate-500",
              )}
            >
              {STATUS_LABELS[contract.status] ?? contract.status}
            </span>
            {canManageContract ? (
              <Link
                href={`/${propertyId}/procurement/service-contracts/${contract.id}/edit`}
              >
                <Button type="button" variant="outline" size="sm">
                  {vi.service.editContract}
                </Button>
              </Link>
            ) : null}
          </div>
        </div>
        {renewalSoon ? (
          <p className="mt-3 rounded-md bg-amber-50 p-3 text-sm font-medium text-amber-800">
            {vi.service.renewalSoon.replace("{days}", String(remaining))}
          </p>
        ) : null}
        {renewalOverdue ? (
          <p className="mt-3 rounded-md bg-red-50 p-3 text-sm font-medium text-red-800">
            {vi.service.renewalOverdue.replace("{days}", String(-remaining))}
          </p>
        ) : null}
      </div>

      <div className="rounded-lg border bg-card p-4">
        <h2 className="font-medium">{vi.service.schedulesTitle}</h2>
        {schedules.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.service.noSchedules}
          </p>
        ) : (
          <div className="mt-3 space-y-3">
            {schedules.map((s) => (
              <div key={s.id} className="rounded-lg border p-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="text-sm">
                    <span className="font-medium">
                      {s.period_start} → {s.period_end}
                    </span>
                    <span className="text-muted-foreground">
                      {" · "}
                      {vi.service.dueDateColumn}: {s.due_date}
                    </span>
                  </div>
                  <span
                    className={cn(
                      "rounded-full px-2 py-0.5 text-xs font-medium",
                      s.status === "accepted" && "bg-green-100 text-green-800",
                      (s.status === "scheduled" || s.status === "performed") &&
                        "bg-amber-100 text-amber-800",
                      s.status === "skipped" && "bg-slate-100 text-slate-500",
                      (s.status === "invoiced" || s.status === "paid") &&
                        "bg-blue-100 text-blue-800",
                    )}
                  >
                    {SCHEDULE_STATUS_LABELS[s.status] ?? s.status}
                  </span>
                </div>
                {s.acceptance ? (
                  <div className="mt-2 text-sm">
                    <p className="text-muted-foreground">
                      {vi.service.acceptedAt}:{" "}
                      {new Date(s.acceptance.accepted_at).toLocaleString(
                        "vi-VN",
                        { timeZone: "Asia/Ho_Chi_Minh" },
                      )}
                      {s.acceptance.rating !== null
                        ? ` · ★ ${s.acceptance.rating}/5`
                        : ""}
                      {s.acceptance.photo_ids.length > 0
                        ? ` · ${s.acceptance.photo_ids.length} ảnh`
                        : ""}
                    </p>
                    {s.acceptance.photo_ids.length > 0 ? (
                      <div className="mt-2">
                        <AttachmentGallery
                          propertyId={propertyId}
                          docType="service_acceptance"
                          docId={s.id}
                        />
                      </div>
                    ) : null}
                  </div>
                ) : (s.status === "scheduled" || s.status === "performed") &&
                  canAccept ? (
                  <div className="mt-2">
                    <Button
                      type="button"
                      size="sm"
                      onClick={() => setAcceptSchedule(s)}
                    >
                      {vi.service.acceptButton}
                    </Button>
                  </div>
                ) : null}
                {acceptSchedule?.id === s.id ? (
                  <div className="mt-3">
                    <AcceptForm
                      propertyId={propertyId}
                      scheduleId={s.id}
                      label={`${contract.title} · ${s.period_start} → ${s.period_end}`}
                      onDone={() => setAcceptSchedule(null)}
                      onCancel={() => setAcceptSchedule(null)}
                    />
                  </div>
                ) : null}
              </div>
            ))}
          </div>
        )}
        <p className="mt-3 text-sm text-muted-foreground">
          {vi.service.schedulesHint}
        </p>
      </div>
    </div>
  );
}
