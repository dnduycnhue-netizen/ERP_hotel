"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import type { ApprovalStepRow } from "@/features/procurement/queries";

export type DecideResult = { ok: boolean; error?: string };

/**
 * Timeline duyệt dùng chung cho PR/PO (T-021): liệt kê các bước theo
 * `approval_timeline` (T-020), hiển thị người duyệt, nhận xét, ủy quyền.
 * Nút Duyệt/Từ chối chỉ hiện ở bước pending thấp nhất và chỉ khi người
 * dùng có quyền của bước đó (`useCan(step.required_perm)` — kiểm tra
 * quyền, không so sánh tên vai trò, AGENTS.md quy tắc 10). SoD (người
 * tạo không duyệt) và ủy quyền do RPC kiểm tra ở server; nếu bị chặn,
 * lỗi tiếng Việt từ server hiện ngay trong khung này.
 * `readOnly` (Q73): màn chi tiết đề nghị thanh toán đã có nút duyệt
 * riêng nên chỉ hiện timeline, không hiện nút duyệt ở đây.
 */
export function ApprovalTimeline({
  steps,
  onDecide,
  readOnly = false,
}: {
  steps: ApprovalStepRow[];
  onDecide?: (
    decision: "approved" | "rejected",
    comment: string | null,
  ) => Promise<DecideResult>;
  readOnly?: boolean;
}) {
  const router = useRouter();
  const currentStep = steps.find((s) => s.decision === "pending") ?? null;
  const canDecideCurrent = useCan(currentStep?.required_perm ?? "");

  const [decideMode, setDecideMode] = useState<"approved" | "rejected" | null>(
    null,
  );
  const [comment, setComment] = useState("");
  const [deciding, setDeciding] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function handleDecide(e: React.FormEvent) {
    e.preventDefault();
    if (!decideMode || !onDecide) return;
    if (decideMode === "rejected" && !comment.trim()) {
      setError(vi.procurement.approval.commentRequiredForReject);
      return;
    }
    setDeciding(true);
    setError(null);
    const res = await onDecide(
      decideMode,
      comment.trim() ? comment.trim() : null,
    );
    setDeciding(false);
    if (res.ok) {
      setDecideMode(null);
      setComment("");
      setNotice(
        decideMode === "approved"
          ? vi.procurement.form.approvedSuccess
          : vi.procurement.form.rejectedSuccess,
      );
      router.refresh();
    } else {
      setError(res.error ?? vi.common.errorOccurred);
    }
  }

  return (
    <div className="rounded-lg border p-4 space-y-3">
      <h3 className="font-semibold text-sm">
        {vi.procurement.approval.title} · {vi.procurement.approval.steps}
      </h3>

      {error ? (
        <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}
      {notice ? (
        <div className="rounded-md border border-emerald-500/20 bg-emerald-500/10 p-3 text-sm text-emerald-700">
          {notice}
        </div>
      ) : null}

      {steps.length === 0 ? (
        <p className="text-sm text-muted-foreground">{vi.common.noData}</p>
      ) : (
        <ol className="space-y-3">
          {steps.map((step) => {
            const isCurrent = currentStep?.id === step.id;
            return (
              <li key={step.id} className="flex gap-3">
                <span
                  className={
                    step.decision === "approved"
                      ? "flex size-7 shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-800"
                      : step.decision === "rejected"
                        ? "flex size-7 shrink-0 items-center justify-center rounded-full bg-red-100 text-xs font-bold text-red-800"
                        : isCurrent
                          ? "flex size-7 shrink-0 items-center justify-center rounded-full bg-amber-100 text-xs font-bold text-amber-800"
                          : "flex size-7 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-bold text-muted-foreground"
                  }
                >
                  {step.step}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium">
                    {step.approver_role_name ?? step.required_perm}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {step.decision === "pending"
                      ? vi.procurement.approval.pending
                      : step.decision === "approved"
                        ? vi.procurement.approval.approved
                        : vi.procurement.approval.rejected}
                    {step.decided_by_name ? ` · ${step.decided_by_name}` : ""}
                    {step.decided_at
                      ? ` · ${new Date(step.decided_at).toLocaleString("vi-VN")}`
                      : ""}
                  </p>
                  {step.delegated_from_name ? (
                    <p className="text-xs text-muted-foreground">
                      {vi.procurement.approval.delegatedFrom}{" "}
                      {step.delegated_from_name}
                    </p>
                  ) : null}
                  {step.comment ? (
                    <p className="mt-1 text-sm rounded-md bg-muted px-2 py-1">
                      {step.comment}
                    </p>
                  ) : null}
                  {isCurrent && canDecideCurrent && !readOnly ? (
                    <div className="mt-2 flex gap-2">
                      <Button
                        size="sm"
                        className="h-8 text-xs"
                        onClick={() => {
                          setDecideMode("approved");
                          setError(null);
                        }}
                      >
                        {vi.procurement.approval.approve}
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-8 text-xs text-destructive hover:bg-destructive/10"
                        onClick={() => {
                          setDecideMode("rejected");
                          setError(null);
                        }}
                      >
                        {vi.procurement.approval.reject}
                      </Button>
                    </div>
                  ) : null}
                </div>
              </li>
            );
          })}
        </ol>
      )}

      {decideMode ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {decideMode === "approved"
                  ? vi.procurement.approval.approve
                  : vi.procurement.approval.reject}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setDecideMode(null)}
              >
                ✕
              </Button>
            </div>
            <form onSubmit={handleDecide} className="mt-4 space-y-3">
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.approval.comment}
                  {decideMode === "rejected" ? " *" : ""}
                </label>
                <textarea
                  required={decideMode === "rejected"}
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  placeholder={
                    decideMode === "rejected"
                      ? vi.procurement.approval.commentRequiredForReject
                      : vi.procurement.approval.comment
                  }
                  className="mt-1 min-h-20 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
              </div>
              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setDecideMode(null)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={deciding}>
                  {deciding ? vi.common.loading : vi.common.confirm}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  );
}
