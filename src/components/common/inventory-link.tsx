"use client";

import Link from "next/link";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link tới khu vực kho (T-031).
 * Kiểm tra quyền bằng `useCan` theo Rule 10 của AGENTS.md.
 */
export function InventoryLink({ propertyId }: { propertyId: string }) {
  // Mỗi useCan phải gọi vô điều kiện (không OR trực tiếp trên lời gọi
  // hook — ESLint react-hooks/rules-of-hooks bắt lỗi này).
  const canRequisitionCreate = useCan("requisition.create");
  const canRequisitionApprove = useCan("requisition.approve");
  const canRequisitionIssue = useCan("requisition.issue");
  const canRequisitionReceive = useCan("requisition.receive");
  const canTransferSend = useCan("transfer.send");
  const canTransferReceive = useCan("transfer.receive");
  const canPurposeIssuePost = useCan("purpose_issue.post");
  const canPurposeIssueReverse = useCan("purpose_issue.reverse");
  const canWastePropose = useCan("waste.propose");
  const canWasteApprove = useCan("waste.approve");
  const canWasteApproveLarge = useCan("waste.approve.large");
  const canStockQty = useCan("stock.view_qty");
  const canStockValue = useCan("stock.view_value");

  const canRequisition =
    canRequisitionCreate ||
    canRequisitionApprove ||
    canRequisitionIssue ||
    canRequisitionReceive;
  const canTransfer = canTransferSend || canTransferReceive;
  const canIssue = canPurposeIssuePost || canPurposeIssueReverse;
  const canWaste = canWastePropose || canWasteApprove || canWasteApproveLarge;
  const canStock = canStockQty || canStockValue;

  if (!canRequisition && !canTransfer && !canIssue && !canWaste && !canStock) {
    return null;
  }
  return (
    <Link
      href={`/${propertyId}/inventory/requisitions`}
      className="text-sm font-medium text-foreground/80 hover:text-foreground hover:underline"
    >
      {vi.inventory.title}
    </Link>
  );
}
