import Link from "next/link";
import { redirect } from "next/navigation";
import { ChangePasswordForm } from "@/components/settings/change-password-form";
import { vi } from "@/i18n/vi";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";

/**
 * Màn tự đổi mật khẩu của chính mình (admin-relax 10/11/2026 — app trước
 * đây chưa có màn đổi mật khẩu). Trang độc lập theo mẫu /offline: chỉ
 * dùng root layout, không sửa layout khu vực. proxy.ts đã chặn người
 * chưa đăng nhập; kiểm tra lại ở đây để chắc chắn.
 * Trang đọc session qua cookies() nên không thể prerender tĩnh (Next 16
 * Cache Components): opt-out như admin/layout.tsx.
 */
export const instant = false;
export default async function ChangePasswordPage() {
  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (!user) {
    redirect("/login");
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-muted/40 px-4 py-10">
      <section className="w-full max-w-md rounded-xl border bg-card p-6 shadow-sm sm:p-8">
        <p className="text-sm font-semibold text-primary">{vi.appName}</p>
        <h1 className="mt-3 text-2xl font-semibold">
          {vi.password.changePasswordTitle}
        </h1>
        <div className="mt-6">
          <ChangePasswordForm />
        </div>
        <p className="mt-6 text-center text-sm">
          <Link href="/" className="text-primary hover:underline">
            {vi.common.back}
          </Link>
        </p>
      </section>
    </main>
  );
}
