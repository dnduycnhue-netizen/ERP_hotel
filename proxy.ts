import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { getSupabaseConfig } from "@/lib/supabase/env";

export async function proxy(request: NextRequest) {
  const { url, publishableKey } = getSupabaseConfig();
  let response = NextResponse.next({ request });

  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value);
        });

        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
        Object.entries(headers).forEach(([name, value]) => {
          response.headers.set(name, value);
        });
      },
    },
  });

  // Lấy claims để biết đã đăng nhập chưa. Phiên hết hạn/hỏng (refresh
  // token không dùng được) làm getClaims() trả lỗi — coi như chưa đăng
  // nhập và để logic chuyển hướng bên dưới đưa về /login, thay vì ném
  // lỗi gây 500 toàn site (kể cả trang /login).
  const { data } = await supabase.auth.getClaims();

  const pathname = request.nextUrl.pathname;
  if (
    !data?.claims &&
    pathname !== "/login" &&
    pathname !== "/offline" &&
    pathname !== "/auth/callback" &&
    !pathname.startsWith("/api/")
  ) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
