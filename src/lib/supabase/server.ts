import { createServerClient } from "@supabase/ssr";
import type { SupabaseClient, User } from "@supabase/supabase-js";
import { cookies } from "next/headers";
import type { Database } from "@/lib/database.types";
import { getSupabaseConfig } from "./env";

export async function createClient() {
  const { url, publishableKey } = getSupabaseConfig();
  const cookieStore = await cookies();

  return createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options);
          });
        } catch {
          // Server Components cannot write cookies; proxy.ts refreshes sessions.
        }
      },
    },
  });
}

/**
 * Người dùng đã đăng nhập, hoặc `null` khi không có phiên hợp lệ.
 *
 * Mọi lỗi của `getUser()` (phiên hết hạn, token hỏng, lỗi mạng thoáng qua)
 * đều coi là "chưa đăng nhập": nơi gọi chuyển về /login (hoặc hiện form
 * đăng nhập) thay vì ném lỗi 500 toàn site. Trước đây code chỉ tha lỗi
 * `AuthSessionMissingError`, nên trình duyệt giữ cookie phiên hết hạn là
 * sập 500 mọi trang kể cả /login.
 */
export async function getAuthenticatedUser(
  supabase: SupabaseClient<Database>,
): Promise<User | null> {
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) {
    return null;
  }
  return data.user;
}
