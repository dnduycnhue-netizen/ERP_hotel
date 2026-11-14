/**
 * Dòng nhận còn phải CÂN LẠI chỉ khi lệch ngoài dung sai ở lần cân 1.
 * Sau lần cân 2 server vẫn giữ `needs_reweigh = true` để đánh dấu lệch (báo cáo
 * "số lần cân lại") nhưng không còn yêu cầu cân nữa và cho ghi sổ khi
 * `weigh_count = 2` (C2-N1: UI coi cờ này là "còn cân lại" nên khóa ghi sổ vĩnh viễn).
 */
export function awaitingReweigh(
  line: { needs_reweigh: boolean; weigh_count: number } | null | undefined,
): boolean {
  return !!line && line.needs_reweigh && line.weigh_count < 2;
}
