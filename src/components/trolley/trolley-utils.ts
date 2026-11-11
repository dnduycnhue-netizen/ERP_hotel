/** Tên ca hiển thị (T-034, Q46). */
import { vi } from "@/i18n/vi";
export function shiftLabel(shift: string): string {
  switch (shift) {
    case "morning":
      return vi.trolley.shiftOptions.morning;
    case "evening":
      return vi.trolley.shiftOptions.evening;
    default:
      return vi.trolley.shiftOptions.day;
  }
}
