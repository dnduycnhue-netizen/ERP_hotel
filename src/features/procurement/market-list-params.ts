/**
 * Chuoi query cho danh sach lenh mua cho (C6) — ham thuan de test duoc
 * bang Vitest: chi giu tham so co gia tri, bo `page=1`, cat khoang trang
 * o tu khoa tim kiem.
 */
export function buildMarketListSearch(params: {
  search?: string;
  status?: string;
  page?: number;
}): string {
  const query = new URLSearchParams();
  const search = (params.search ?? "").trim();
  if (search) {
    query.set("search", search);
  }
  if (params.status) {
    query.set("status", params.status);
  }
  const page = params.page ?? 1;
  if (page > 1) {
    query.set("page", String(page));
  }
  const qs = query.toString();
  return qs ? `?${qs}` : "";
}
