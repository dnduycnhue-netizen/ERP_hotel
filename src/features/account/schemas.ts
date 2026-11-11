import { z } from "zod";
import { vi } from "@/i18n/vi";

/**
 * Tự đổi mật khẩu của chính mình. Mật khẩu mới tối thiểu 12 ký tự
 * (thống nhất 12 ở mọi nơi — tự phê duyệt 10/11/2026, xem Q132).
 */
export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1, vi.password.enterCurrentPassword),
    newPassword: z
      .string()
      .min(12, vi.password.passwordTooShort)
      .max(128, vi.password.tooLong),
    confirmPassword: z.string().min(1, vi.password.enterNewPasswordAgain),
  })
  .refine((value) => value.newPassword === value.confirmPassword, {
    message: vi.password.passwordMismatch,
    path: ["confirmPassword"],
  })
  .refine((value) => value.newPassword !== value.currentPassword, {
    message: vi.password.mustDiffer,
    path: ["newPassword"],
  });

export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;
