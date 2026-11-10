import { z } from "zod";

/**
 * Tự đổi mật khẩu của chính mình. Mật khẩu mới tối thiểu 8 ký tự (theo
 * chỉ thị admin-relax 10/11/2026). Lưu ý: màn đặt mật khẩu lần đầu
 * (auth)/set-password hiện yêu cầu tối thiểu 12 ký tự — chưa thống nhất,
 * xem Q123.
 */
export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1, "Vui lòng nhập mật khẩu hiện tại."),
    newPassword: z
      .string()
      .min(8, "Mật khẩu mới phải có ít nhất 8 ký tự.")
      .max(128, "Mật khẩu mới tối đa 128 ký tự."),
    confirmPassword: z.string().min(1, "Vui lòng nhập lại mật khẩu mới."),
  })
  .refine((value) => value.newPassword === value.confirmPassword, {
    message: "Mật khẩu nhập lại không khớp.",
    path: ["confirmPassword"],
  })
  .refine((value) => value.newPassword !== value.currentPassword, {
    message: "Mật khẩu mới phải khác mật khẩu hiện tại.",
    path: ["newPassword"],
  });

export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;
