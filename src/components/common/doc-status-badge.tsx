import {
  AlertTriangle,
  Ban,
  CheckCheck,
  CheckCircle2,
  CircleDashed,
  CircleHelp,
  Clock,
  FileCheck,
  FileX2,
  Lock,
  PackageCheck,
  Send,
  Undo2,
  Wallet,
  type LucideIcon,
} from "lucide-react";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

/**
 * Trạng thái chứng từ dùng trong toàn hệ thống (docs/03-DATA-MODEL.md).
 * Màu theo docs/06-UI-UX.md mục 1: nháp xám, chờ duyệt vàng,
 * đã duyệt xanh dương, đã ghi sổ xanh lá, từ chối/đảo/hủy đỏ.
 * Không dùng màu làm tín hiệu duy nhất — luôn có icon + chữ kèm theo.
 */
export type DocStatus =
  | "draft"
  | "submitted"
  | "pending"
  | "approved"
  | "rejected"
  | "converted"
  | "sent"
  | "partially_received"
  | "received"
  | "closed"
  | "cancelled"
  | "posted"
  | "reversed"
  | "needs_recount"
  | "matched"
  | "on_hold"
  | "partially_paid"
  | "paid"
  | "settled"
  | "overdue"
  | "requested"
  | "disbursed"
  | "settling"
  | "in_transit"
  | "issued"
  | "locked"
  | "open"
  | "counting"
  | "recount"
  | "adjusted";

type DocStatusMeta = {
  label: string;
  className: string;
  Icon: LucideIcon;
};

const STATUS_META: Record<DocStatus, DocStatusMeta> = {
  draft: {
    label: vi.components.docStatus.draft,
    className: "bg-muted text-muted-foreground",
    Icon: CircleDashed,
  },
  submitted: {
    label: vi.components.docStatus.submitted,
    className:
      "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200",
    Icon: Clock,
  },
  pending: {
    label: vi.components.docStatus.pending,
    className:
      "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200",
    Icon: Clock,
  },
  approved: {
    label: vi.components.docStatus.approved,
    className:
      "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200",
    Icon: CheckCircle2,
  },
  rejected: {
    label: vi.components.docStatus.rejected,
    className: "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200",
    Icon: FileX2,
  },
  converted: {
    label: vi.components.docStatus.converted,
    className:
      "bg-teal-100 text-teal-800 dark:bg-teal-900/40 dark:text-teal-200",
    Icon: PackageCheck,
  },
  sent: {
    label: vi.components.docStatus.sent,
    className:
      "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200",
    Icon: Send,
  },
  partially_received: {
    label: vi.components.docStatus.partiallyReceived,
    className:
      "bg-teal-100 text-teal-800 dark:bg-teal-900/40 dark:text-teal-200",
    Icon: PackageCheck,
  },
  received: {
    label: vi.components.docStatus.received,
    className:
      "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
    Icon: PackageCheck,
  },
  closed: {
    label: vi.components.docStatus.closed,
    className: "bg-muted text-muted-foreground",
    Icon: Lock,
  },
  cancelled: {
    label: vi.components.docStatus.cancelled,
    className: "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200",
    Icon: Ban,
  },
  posted: {
    label: vi.components.docStatus.posted,
    className:
      "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
    Icon: FileCheck,
  },
  reversed: {
    label: vi.components.docStatus.reversed,
    className: "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200",
    Icon: Undo2,
  },
  needs_recount: {
    label: vi.components.docStatus.needsRecount,
    className:
      "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200",
    Icon: AlertTriangle,
  },
  matched: {
    label: vi.components.docStatus.matched,
    className:
      "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
    Icon: CheckCheck,
  },
  on_hold: {
    label: vi.components.docStatus.onHold,
    className:
      "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200",
    Icon: AlertTriangle,
  },
  partially_paid: {
    label: vi.components.docStatus.partiallyPaid,
    className:
      "bg-teal-100 text-teal-800 dark:bg-teal-900/40 dark:text-teal-200",
    Icon: Wallet,
  },
  paid: {
    label: vi.components.docStatus.paid,
    className:
      "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
    Icon: CheckCheck,
  },
  settled: {
    label: vi.components.docStatus.settled,
    className:
      "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
    Icon: CheckCheck,
  },
  overdue: {
    label: vi.components.docStatus.overdue,
    className: "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200",
    Icon: AlertTriangle,
  },
  requested: {
    label: vi.components.docStatus.requested,
    className:
      "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200",
    Icon: Send,
  },
  disbursed: {
    label: vi.components.docStatus.disbursed,
    className:
      "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
    Icon: Wallet,
  },
  settling: {
    label: vi.components.docStatus.settling,
    className:
      "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200",
    Icon: Clock,
  },
  in_transit: {
    label: vi.components.docStatus.inTransit,
    className:
      "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200",
    Icon: Send,
  },
  issued: {
    label: vi.components.docStatus.issued,
    className:
      "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
    Icon: PackageCheck,
  },
  locked: {
    label: vi.components.docStatus.locked,
    className: "bg-muted text-muted-foreground",
    Icon: Lock,
  },
  open: {
    label: vi.components.docStatus.open,
    className:
      "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200",
    Icon: CircleDashed,
  },
  counting: {
    label: vi.components.docStatus.counting,
    className:
      "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200",
    Icon: Clock,
  },
  recount: {
    label: vi.components.docStatus.recount,
    className:
      "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200",
    Icon: AlertTriangle,
  },
  adjusted: {
    label: vi.components.docStatus.adjusted,
    className:
      "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200",
    Icon: FileCheck,
  },
};

const UNKNOWN_META: DocStatusMeta = {
  label: vi.components.docStatus.unknown,
  className: "bg-muted text-muted-foreground",
  Icon: CircleHelp,
};

/** Nhãn tiếng Việt của 1 mã trạng thái (dùng cho chip lọc...). */
export function getDocStatusLabel(status: string): string {
  return (
    (STATUS_META as Record<string, DocStatusMeta>)[status]?.label ??
    UNKNOWN_META.label
  );
}

/** Huy hiệu trạng thái chứng từ. Nhận mọi chuỗi trạng thái; mã lạ hiện huy hiệu xám "Không rõ trạng thái". */
export function DocStatusBadge({
  status,
  className,
}: {
  status: string;
  className?: string;
}) {
  const meta =
    (STATUS_META as Record<string, DocStatusMeta>)[status] ?? UNKNOWN_META;
  const { Icon } = meta;
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium whitespace-nowrap",
        meta.className,
        className,
      )}
    >
      <Icon className="size-3.5" aria-hidden />
      {meta.label}
    </span>
  );
}
