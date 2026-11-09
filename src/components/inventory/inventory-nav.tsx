"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useCan } from "@/lib/permissions/permissions-provider";
import { cn } from "@/lib/utils";
import { vi } from "@/i18n/vi";

/** Tab điều hướng khu kho (T-031): ẩn tab mà user không có quyền xem. */
export function InventoryNav({ propertyId }: { propertyId: string }) {
  const pathname = usePathname();

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

  const links: { href: string; label: string }[] = [];
  if (canRequisition) {
    links.push({
      href: `/${propertyId}/inventory/requisitions`,
      label: vi.inventory.nav.requisitions,
    });
  }
  if (canTransfer) {
    links.push({
      href: `/${propertyId}/inventory/transfers`,
      label: vi.inventory.nav.transfers,
    });
  }
  if (canIssue) {
    links.push({
      href: `/${propertyId}/inventory/issues`,
      label: vi.inventory.nav.issues,
    });
  }
  if (canWaste) {
    links.push({
      href: `/${propertyId}/inventory/waste`,
      label: vi.inventory.nav.waste,
    });
  }
  if (canStock) {
    links.push({
      href: `/${propertyId}/inventory/stock`,
      label: vi.inventory.nav.stock,
    });
  }

  if (links.length === 0) {
    return null;
  }

  return (
    <nav className="mb-6 flex flex-wrap gap-2 border-b pb-3">
      {links.map((link) => {
        const isActive = pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            className={cn(
              "rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
              isActive
                ? "bg-primary text-primary-foreground shadow-sm"
                : "text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
