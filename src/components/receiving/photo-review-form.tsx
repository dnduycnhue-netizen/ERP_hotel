"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { reviewPhotosAction } from "@/features/receiving/actions";
import { vi } from "@/i18n/vi";

/**
 * Form hậu kiểm ảnh của 1 phiếu nhận (C2) — duyệt theo phiếu, không
 * duyệt từng ảnh. Từ chối bắt buộc có lý do; duyệt xong làm mới trang
 * để hiện trạng thái + người/giờ hậu kiểm.
 */
export function PhotoReviewForm({ grId }: { grId: string }) {
  const strings = vi.receiving;
  const router = useRouter();
  const [reason, setReason] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  async function handleDecision(decision: "approved" | "rejected") {
    if (submitting) {
      return;
    }
    if (decision === "rejected" && !reason.trim()) {
      setError(strings.photoReviewReasonRequired);
      return;
    }
    setSubmitting(true);
    setError(null);
    const res = await reviewPhotosAction({
      grId,
      decision,
      reason: decision === "rejected" ? reason.trim() : null,
    });
    setSubmitting(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setDone(
      decision === "approved"
        ? strings.photoReviewApproveSuccess
        : strings.photoReviewRejectSuccess,
    );
    router.refresh();
  }

  if (done) {
    return (
      <p role="status" className="text-sm font-medium text-green-700">
        {done}
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">{strings.photoReviewHint}</p>
      <div>
        <label
          htmlFor="photo-review-reason"
          className="mb-1 block text-sm font-medium"
        >
          {strings.photoReviewReason}
        </label>
        <textarea
          id="photo-review-reason"
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          placeholder={strings.photoReviewReasonPlaceholder}
          rows={3}
          className="w-full rounded-lg border bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
        />
      </div>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      <div className="flex flex-wrap gap-2">
        <Button
          type="button"
          disabled={submitting}
          onClick={() => handleDecision("approved")}
        >
          {strings.photoReviewApprove}
        </Button>
        <Button
          type="button"
          variant="destructive"
          disabled={submitting}
          onClick={() => handleDecision("rejected")}
        >
          {strings.photoReviewReject}
        </Button>
      </div>
    </div>
  );
}
