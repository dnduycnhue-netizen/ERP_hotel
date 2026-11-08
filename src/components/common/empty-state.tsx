import { Inbox, type LucideIcon } from "lucide-react";
import type { ReactNode } from "react";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

export function EmptyState({
  icon: Icon = Inbox,
  title = vi.components.emptyState.defaultTitle,
  description,
  action,
  className,
}: {
  icon?: LucideIcon;
  title?: string;
  description?: string;
  action?: ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center gap-2 px-6 py-12 text-center",
        className,
      )}
    >
      <Icon className="size-8 text-muted-foreground" aria-hidden />
      <p className="text-sm font-medium">{title}</p>
      {description ? (
        <p className="max-w-md text-sm text-muted-foreground">{description}</p>
      ) : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  );
}
