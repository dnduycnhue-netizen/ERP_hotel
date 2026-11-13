import { ToggleLeft } from "lucide-react";
import { EmptyState } from "@/components/common/empty-state";
import { vi } from "@/i18n/vi";

/** Hiện thay cho khu chức năng khi module bị tắt ở khách sạn (Q254). */
export function ModuleDisabled({ name }: { name: string }) {
  return (
    <EmptyState
      icon={ToggleLeft}
      title={`${vi.admin.modules.disabledTitle}: ${name}`}
      description={vi.admin.modules.disabledDescription}
    />
  );
}
