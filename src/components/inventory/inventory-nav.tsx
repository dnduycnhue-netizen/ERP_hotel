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
  const canCountOpen = useCan("count.open");
  const canCountPerform = useCan("count.perform");
  const canCountViewVariance = useCan("count.view_variance");
  const canCountLock = useCan("count.lock");
  const canCountAdjustApprove = useCan("count.adjust.approve");
  const canDayLock = useCan("day.lock");
  const canDayUnlock = useCan("day.unlock");
  const canPeriodClose = useCan("period.close");
  const canPeriodReopen = useCan("period.reopen");

  const canRequisition =
    canRequisitionCreate ||
    canRequisitionApprove ||
    canRequisitionIssue ||
    canRequisitionReceive;
  const canTransfer = canTransferSend || canTransferReceive;
  const canIssue = canPurposeIssuePost || canPurposeIssueReverse;
  const canWaste = canWastePropose || canWasteApprove || canWasteApproveLarge;
  const canStock = canStockQty || canStockValue;
  const canCount =
    canCountOpen ||
    canCountPerform ||
    canCountViewVariance ||
    canCountLock ||
    canCountAdjustApprove;
  const canLocks =
    canDayLock || canDayUnlock || canPeriodClose || canPeriodReopen;

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
  if (canCount) {
    links.push({
      href: `/${propertyId}/inventory/counts`,
      label: vi.inventory.nav.counts,
    });
  }
  if (canLocks) {
    links.push({
      href: `/${propertyId}/inventory/locks`,
      label: vi.inventory.nav.locks,
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
    <nav className="mb-6 flex gap-1 overflow-x-auto border-b">
      {links.map((link) => {
        const isActive = pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "shrink-0 border-b-2 px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors outline-none focus-visible:ring-2 focus-visible:ring-brand/40",
              isActive
                ? "border-brand text-brand"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
          >
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
