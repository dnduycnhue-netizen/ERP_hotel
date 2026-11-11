import type { ReactNode } from "react";
import { Suspense } from "react";
import { connection } from "next/server";
import { redirect } from "next/navigation";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { createClient, getAuthenticatedUserId } from "@/lib/supabase/server";
import { signOut } from "../(auth)/login/actions";
import AppLoading from "./loading";

export default function AppLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <Suspense fallback={<AppLoading />}>
      <AuthenticatedApp>{children}</AuthenticatedApp>
    </Suspense>
  );
}

async function AuthenticatedApp({
  children,
}: Readonly<{ children: ReactNode }>) {
  // Buộc render theo request (Next 16 Cache Components): mọi trang con đều
  // đọc session Supabase (getClaims/getUser dùng Date.now() khi nạp
  // session) nên không được prerender tĩnh — lỗi `Date.now()` ngày
  // 11/11/2026 ở /admin/organizations, /finance/export, /admin/roles,
  // pms-daily đều do thiếu dòng này.
  await connection();
  const supabase = await createClient();
  // Chỉ cần id để kiểm tra active — dùng getClaims() tại chỗ (0
  // round-trip) thay vì getUser() gọi sang máy chủ Auth mỗi request.
  const userId = await getAuthenticatedUserId(supabase);
  if (!userId) {
    redirect("/login");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("active")
    .eq("id", userId)
    .maybeSingle();

  if (profileError) {
    console.error("Unable to verify the current profile.", profileError);
    throw profileError;
  }

  if (!profile?.active) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-muted/40 px-4 py-10">
        <section className="w-full max-w-lg rounded-xl border bg-card p-6 shadow-sm sm:p-8">
          <h1 className="text-xl font-semibold">
            {vi.auth.accountUnavailable}
          </h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            {vi.auth.accountUnavailableDescription}
          </p>
          <form action={signOut} className="mt-6">
            <Button type="submit">{vi.auth.signOut}</Button>
          </form>
        </section>
      </main>
    );
  }

  return children;
}
