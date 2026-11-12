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

/**
 * Chỉ lấy id của người dùng đã đăng nhập (từ JWT claims), hoặc `null`.
 *
 * Dùng ở những chỗ chỉ cần biết "ai đang gọi" (vd kiểm tra active, chọn
 * khách sạn) thay vì `getAuthenticatedUser()`: `getClaims()` xác thực JWT
 * tại chỗ, KHÔNG gọi sang máy chủ Auth (0 round-trip), trong khi
 * `getUser()` gọi `/auth/v1/user` mỗi lần — trên đường truyền xuyên vùng
 * (Vercel → Supabase ap-south-1) mỗi lần đó tốn 200–300ms. Token hết hạn
 * nhưng refresh token còn hiệu lực vẫn được làm mới qua `getSession()`
 * bên trong (xem @supabase/ssr: session initialization); token hỏng thì
 * trả `null` như `getUser()` lỗi — nơi gọi xử lý giống nhau.
 */
export async function getAuthenticatedUserId(
  supabase: SupabaseClient<Database>,
): Promise<string | null> {
  const { data, error } = await supabase.auth.getClaims();
  if (error || !data?.claims?.sub) {
    return null;
  }
  return data.claims.sub;
}

/**
 * Chỉ lấy email của người dùng đã đăng nhập (từ JWT claims), hoặc
 * `null` khi không có.
 *
 * Cùng mẫu với `getAuthenticatedUserId()`: `getClaims()` xác thực JWT
 * tại chỗ, KHÔNG gọi sang máy chủ Auth (0 round-trip) — dùng để hiện
 * email trong menu người dùng ở topbar (Q123) mà không tốn thêm một
 * lần `getUser()` mỗi request.
 */
export async function getAuthenticatedUserEmail(
  supabase: SupabaseClient<Database>,
): Promise<string | null> {
  const { data, error } = await supabase.auth.getClaims();
  if (error || !data?.claims?.email) {
    return null;
  }
  return data.claims.email;
}
