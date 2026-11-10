"use server";

import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";
import { changePasswordSchema, type ChangePasswordInput } from "./schemas";

export type ChangePasswordResult = { ok: boolean; error?: string };

/**
 * Người dùng tự đổi mật khẩu của mình: xác minh mật khẩu hiện tại bằng
 * signInWithPassword rồi updateUser({ password }) cho user đang đăng nhập.
 * Phiên hiện tại vẫn giữ nguyên sau khi đổi (updateUser không đăng xuất
 * phiên hiện tại). Mật khẩu không bao giờ ghi log.
 */
export async function changeOwnPasswordAction(
  input: ChangePasswordInput,
): Promise<ChangePasswordResult> {
  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (!user || !user.email) {
    return { ok: false, error: getRpcErrorMessage(null) };
  }
  const parsed = changePasswordSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? getRpcErrorMessage(null),
    };
  }
  const { error: verifyError } = await supabase.auth.signInWithPassword({
    email: user.email,
    password: parsed.data.currentPassword,
  });
  if (verifyError) {
    return { ok: false, error: vi.password.currentPasswordWrong };
  }
  const { error: updateError } = await supabase.auth.updateUser({
    password: parsed.data.newPassword,
  });
  if (updateError) {
    return { ok: false, error: getRpcErrorMessage(null) };
  }
  return { ok: true };
}
