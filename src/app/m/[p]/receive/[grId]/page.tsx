import Link from "next/link";
import { ErrorState } from "@/components/common/error-state";
import { MobileReceiveWorkspace } from "@/components/receiving/mobile-receive-workspace";
import { getReceipt, getReceivingTask } from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";

/**
 * Màn hình ghi từng dòng của 1 phiếu nhận nháp (T-024).
 * Người nhận chỉ xem được phiếu nháp của chính mình (RPC `receiving_get_receipt`
 * chặn phiếu đã post / của người khác) — phiếu đã ghi sổ thì chỉ hiện trạng
 * thái và đường về danh sách (M04: không cho xem lại phiếu cũ sau khi post).
 */
export default async function MobileReceiveWorkspacePage({
  params,
}: {
  params: Promise<{ p: string; grId: string }>;
}) {
  const { p: propertyId, grId } = await params;

  const receiptRes = await getReceipt(grId);
  if (!receiptRes.ok) {
    return <ErrorState description={receiptRes.error} />;
  }
  const receipt = receiptRes.data;

  if (receipt.status !== "draft") {
    const statusLabel =
      receipt.status === "posted"
        ? vi.receiving.statusPosted
        : receipt.status === "reversed"
          ? vi.receiving.statusReversed
          : receipt.status;
    return (
      <div className="flex flex-col gap-4">
        <h1 className="text-xl font-semibold">
          {vi.receiving.receiptTitle} {receipt.doc_no}
        </h1>
        <p className="rounded-lg border bg-card p-4 text-sm leading-6">
          {statusLabel} — {vi.receiving.postConfirmNote}
        </p>
        <Link
          href={`/m/${propertyId}/receive`}
          className="text-sm font-medium text-primary underline-offset-4 hover:underline"
        >
          {vi.receiving.backToTasks}
        </Link>
      </div>
    );
  }

  if (!receipt.po_id) {
    return <ErrorState description={vi.errors.pageDescription} />;
  }

  const taskRes = await getReceivingTask(receipt.po_id);
  if (!taskRes.ok) {
    return <ErrorState description={taskRes.error} />;
  }

  return (
    <MobileReceiveWorkspace
      receipt={receipt}
      task={taskRes.data}
      propertyId={propertyId}
    />
  );
}
