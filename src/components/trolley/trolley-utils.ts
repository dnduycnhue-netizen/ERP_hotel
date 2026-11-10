/** Tên ca hiển thị (T-034, Q46). */
export function shiftLabel(shift: string): string {
  switch (shift) {
    case "morning":
      return "Ca sáng";
    case "evening":
      return "Ca tối";
    default:
      return "Ca ngày";
  }
}
