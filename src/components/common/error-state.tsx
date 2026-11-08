import { TriangleAlert } from "lucide-react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

export function ErrorState({
  title = vi.components.errorState.defaultTitle,
  description = vi.components.errorState.defaultDescription,
  onRetry,
  className,
}: {
  title?: string;
  description?: string;
  onRetry?: () => void;
  className?: string;
}) {
  return (
    <div
      role="alert"
      className={cn(
        "flex flex-col items-center justify-center gap-2 px-6 py-12 text-center",
        className,
      )}
    >
      <TriangleAlert className="size-8 text-destructive" aria-hidden />
      <p className="text-sm font-medium">{title}</p>
      <p className="max-w-md text-sm text-muted-foreground">{description}</p>
      {onRetry ? (
        <Button variant="outline" size="sm" onClick={onRetry} className="mt-2">
          {vi.common.tryAgain}
        </Button>
      ) : null}
    </div>
  );
}
