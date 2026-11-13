import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import {
  ApprovalInbox,
  type PendingApprovalItem,
} from "@/components/procurement/approval-inbox";
import {
  listApprovalSteps,
  listPos,
  listPrs,
} from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

/**
 * Hộp thư chờ tôi duyệt (T-021): gom PR/PO đang `submitted`, lấy
 * timeline từng chứng từ, giữ lại chứng từ có bước pending mà người
 * dùng hiện tại có quyền duyệt. Loại chứng từ do chính mình tạo vì
 * SoD chặn người tạo duyệt (server vẫn kiểm tra lại khi quyết).
 */
export default async function ProcurementApprovalsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const supabase = await createClient();

  const [
    {
      data: { user },
    },
    { data: myPerms },
  ] = await Promise.all([
    supabase.auth.getUser(),
    supabase.rpc("my_permissions", { p_property: propertyId }),
  ]);
  const myPermSet = new Set(myPerms ?? []);

  // Người không có quyền duyệt nào: hiện trạng thái rỗng thay vì lỗi quyền
  // của các RPC danh sách (Muse, demo 13/11: uat.chef thấy "không có quyền").
  const canApproveAny = ["pr.approve", "po.approve", "po.approve.over_ceiling"].some(
    (code) => myPermSet.has(code),
  );
  if (!canApproveAny) {
    return (
      <EmptyState
        title={vi.procurement.inbox.noApproveRightTitle}
        description={vi.procurement.inbox.noApproveRightDescription}
      />
    );
  }

  const [prsRes, posRes] = await Promise.all([
    listPrs(propertyId, { status: "submitted", pageSize: 20 }),
    listPos(propertyId, { status: "submitted", pageSize: 20 }),
  ]);

  if (!prsRes.ok) {
    return <ErrorState description={prsRes.error} />;
  }
  if (!posRes.ok) {
    return <ErrorState description={posRes.error} />;
  }

  const docs = [
    ...prsRes.data.rows.map((row) => ({
      docType: "pr" as const,
      docId: row.id,
      docNo: row.doc_no,
      kind: row.kind,
      supplierName: null,
      totalAmount: null,
      createdAt: row.created_at,
      createdBy: row.created_by,
    })),
    ...posRes.data.rows.map((row) => ({
      docType: "po" as const,
      docId: row.id,
      docNo: row.doc_no,
      kind: row.kind,
      supplierName: row.supplier_name,
      totalAmount: row.total_amount,
      createdAt: row.created_at,
      createdBy: row.created_by,
    })),
  ];

  const pendingDocs = docs.filter((doc) => doc.createdBy !== user?.id);

  const items = (
    await Promise.all(
      pendingDocs.map(async (doc) => {
        const stepsRes = await listApprovalSteps(
          propertyId,
          doc.docType,
          doc.docId,
        );
        if (!stepsRes.ok) return null;
        const step = stepsRes.data.find(
          (s) => s.decision === "pending" && myPermSet.has(s.required_perm),
        );
        if (!step) return null;
        const item: PendingApprovalItem = {
          docType: doc.docType,
          docId: doc.docId,
          docNo: doc.docNo,
          kind: doc.kind,
          supplierName: doc.supplierName,
          totalAmount: doc.totalAmount,
          createdAt: doc.createdAt,
          step,
        };
        return item;
      }),
    )
  ).filter((item): item is PendingApprovalItem => item !== null);

  return <ApprovalInbox propertyId={propertyId} items={items} />;
}
