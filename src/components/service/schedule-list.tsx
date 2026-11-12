"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { AttachmentGallery } from "@/components/common/attachment-gallery";
import { generateSchedulesAction } from "@/features/service/actions";
import type {
  ServiceContractRow,
  ServicePoRow,
  ServiceScheduleRow,
} from "@/features/service/queries";
import { AcceptForm } from "./accept-form";
import { PoAcceptList } from "./po-accept-list";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

const SCHEDULE_STATUS_LABELS: Record<string, string> = {
  scheduled: vi.service.scheduleScheduled,
  performed: vi.service.schedulePerformed,
  accepted: vi.service.scheduleAccepted,
  invoiced: vi.service.scheduleInvoiced,
  paid: vi.service.schedulePaid,
  skipped: vi.service.scheduleSkipped,
};

type AcceptTarget =
  | { kind: "schedule"; schedule: ServiceScheduleRow }
  | { kind: "po"; po: ServicePoRow };

/**
 * Lịch kỳ dịch vụ theo tháng (T-042): chọn tháng + sinh lịch + nghiệm
 * thu từng kỳ + danh sách PO dịch vụ lẻ chờ nghiệm thu.
 */
export function ScheduleList({
  propertyId,
  month,
  schedules,
  pendingPos,
  contracts,
  canAccept,
}: {
  propertyId: string;
  month: string;
  schedules: ServiceScheduleRow[];
  pendingPos: ServicePoRow[];
  contracts: ServiceContractRow[];
  canAccept: boolean;
}) {
  const router = useRouter();
  const [monthValue, setMonthValue] = useState(month);
  const [contractId, setContractId] = useState("");
  const [generating, setGenerating] = useState(false);
  const [generateResult, setGenerateResult] = useState<string | null>(null);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [acceptTarget, setAcceptTarget] = useState<AcceptTarget | null>(null);

  const filtered = useMemo(
    () =>
      schedules.filter(
        (s) => contractId === "" || s.contract_id === contractId,
      ),
    [schedules, contractId],
  );

  function goToMonth(value: string) {
    setMonthValue(value);
    router.push(
      `/${propertyId}/procurement/service-contracts/schedules?month=${value}`,
    );
  }

  async function handleGenerate() {
    setGenerating(true);
    setGenerateResult(null);
    setGenerateError(null);
    const res = await generateSchedulesAction({
      propertyId,
      month: `${monthValue}-01`,
    });
    setGenerating(false);
    if (!res.ok) {
      setGenerateError(res.error);
      return;
    }
    setGenerateResult(
      vi.service.generateResult
        .replace("{generated}", String(res.data.generated))
        .replace("{existing}", String(res.data.existing))
        .replace("{skipped}", String(res.data.skipped_per_visit)),
    );
    router.refresh();
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end gap-3 rounded-lg border bg-card p-4">
        <label className="block text-sm">
          {vi.service.monthLabel}
          <input
            type="month"
            value={monthValue}
            onChange={(e) => goToMonth(e.target.value)}
            className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
        <label className="block text-sm">
          {vi.service.contractTitle}
          <select
            value={contractId}
            onChange={(e) => setContractId(e.target.value)}
            className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <option value="">{vi.common.all}</option>
            {contracts.map((c) => (
              <option key={c.id} value={c.id}>
                {c.title}
              </option>
            ))}
          </select>
        </label>
        <Button type="button" disabled={generating} onClick={handleGenerate}>
          {generating ? vi.service.generating : vi.service.generateButton}
        </Button>
      </div>

      {generateResult ? (
        <p className="text-sm font-medium text-green-800">{generateResult}</p>
      ) : null}
      {generateError ? (
        <p role="alert" className="text-sm font-medium text-red-800">
          {generateError}
        </p>
      ) : null}

      {acceptTarget ? (
        <AcceptForm
          propertyId={propertyId}
          scheduleId={
            acceptTarget.kind === "schedule" ? acceptTarget.schedule.id : null
          }
          poId={acceptTarget.kind === "po" ? acceptTarget.po.id : null}
          label={
            acceptTarget.kind === "schedule"
              ? `${acceptTarget.schedule.contract_title ?? vi.common.noData} · ${acceptTarget.schedule.period_start} → ${acceptTarget.schedule.period_end}`
              : `${acceptTarget.po.doc_no} · ${acceptTarget.po.supplier_name ?? vi.common.noData}`
          }
          onDone={() => {
            setAcceptTarget(null);
            router.refresh();
          }}
          onCancel={() => setAcceptTarget(null)}
        />
      ) : null}

      <div className="rounded-lg border bg-card p-4">
        <h2 className="font-medium">{vi.service.schedulesTitle}</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.service.schedulesHint}
        </p>
        {filtered.length === 0 ? (
          <p className="mt-3 text-sm text-muted-foreground">
            {vi.service.noSchedules}
          </p>
        ) : (
          <div className="mt-3 space-y-3">
            {filtered.map((s) => (
              <div key={s.id} className="rounded-lg border p-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="text-sm">
                    <span className="font-medium">
                      {s.contract_title ?? vi.common.noData}
                    </span>
                    <span className="text-muted-foreground">
                      {" · "}
                      {s.period_start} → {s.period_end}
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
                    {s.acceptance.note ? (
                      <p className="mt-1 text-sm">
                        {vi.service.note}: {s.acceptance.note}
                      </p>
                    ) : null}
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
                      onClick={() =>
                        setAcceptTarget({ kind: "schedule", schedule: s })
                      }
                    >
                      {vi.service.acceptButton}
                    </Button>
                  </div>
                ) : null}
              </div>
            ))}
          </div>
        )}
      </div>

      <PoAcceptList
        propertyId={propertyId}
        pos={pendingPos}
        canAccept={canAccept}
        onAcceptPo={(po) => setAcceptTarget({ kind: "po", po })}
      />
    </div>
  );
}
