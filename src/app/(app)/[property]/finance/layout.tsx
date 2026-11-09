import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import {
  FinanceNav,
  type FinanceNavPerms,
} from "@/components/finance/finance-nav";
import { createClient } from "@/lib/supabase/server";

/**
 * Khu Tài chính (T-041): hóa đơn, công nợ, tạm ứng, đề nghị thanh toán,
 * bảng kê không hóa đơn. Chặn người không có quyền tài chính nào ở tầng
 * layout; từng mục trong nav chỉ hiện khi có quyền tương ứng.
 */
export default async function FinanceLayout({
  children,
  params,
}: Readonly<{
  children: ReactNode;
  params: Promise<{ property: string }>;
}>) {
  const { property: propertyId } = await params;
  const supabase = await createClient();

  const { data: myPerms } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });

  const perms = new Set(myPerms ?? []);
  const canInvoices =
    perms.has("invoice.manage") ||
    perms.has("invoice.approve") ||
    perms.has("ap.view") ||
    perms.has("payment.request") ||
    perms.has("payment.approve") ||
    perms.has("payment.mark_paid");
  const canPayables =
    perms.has("ap.view") ||
    perms.has("invoice.manage") ||
    perms.has("invoice.approve") ||
    perms.has("payment.request") ||
    perms.has("payment.approve") ||
    perms.has("payment.mark_paid");
  const canAdvances =
    perms.has("advance.settle") ||
    perms.has("advance.approve") ||
    perms.has("advance.disburse");
  const canPaymentRequests =
    perms.has("payment.request") ||
    perms.has("payment.approve") ||
    perms.has("payment.mark_paid");
  const canListings =
    perms.has("invoice.manage") ||
    perms.has("invoice.approve") ||
    perms.has("ap.view");

  if (
    !canInvoices &&
    !canPayables &&
    !canAdvances &&
    !canPaymentRequests &&
    !canListings
  ) {
    notFound();
  }

  const navPerms: FinanceNavPerms = {
    canInvoices,
    canPayables,
    canAdvances,
    canPaymentRequests,
    canListings,
  };

  return (
    <div className="space-y-6">
      <FinanceNav propertyId={propertyId} perms={navPerms} />
      {children}
    </div>
  );
}
