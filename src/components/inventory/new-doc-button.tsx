"use client";

import Link from "next/link";
import { Plus } from "lucide-react";
import { buttonVariants } from "@/components/ui/button";
import { useCan } from "@/lib/permissions/permissions-provider";

/** Nút "Lập phiếu" trên danh sách chứng từ kho; ẩn khi thiếu quyền tạo. */
export function NewDocButton({
  href,
  label,
  permission,
}: {
  href: string;
  label: string;
  permission: string;
}) {
  const can = useCan(permission);
  if (!can) {
    return null;
  }
  return (
    <Link href={href} className={buttonVariants({ size: "sm" })}>
      <Plus className="size-4" aria-hidden />
      {label}
    </Link>
  );
}
