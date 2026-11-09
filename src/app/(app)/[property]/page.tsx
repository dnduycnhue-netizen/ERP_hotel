import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { vi } from "@/i18n/vi";

type LegalEntityInfo = {
  code: string;
  name: string;
  costing_method: string;
  accounting_regime: string;
};

export default async function PropertyHome({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const supabase = await createClient();

  const { data: property, error: propError } = await supabase
    .from("properties")
    .select(
      "id, code, name, sod_profile, rooms_count, org_id, legal_entity:legal_entities(code, name, costing_method, accounting_regime)",
    )
    .eq("id", propertyId)
    .single();

  if (propError || !property) {
    notFound();
  }

  const [
    { count: itemsCount },
    { count: warehousesCount },
    { count: groupsCount },
    { count: rolesCount },
  ] = await Promise.all([
    supabase
      .from("items")
      .select("id", { count: "exact", head: true })
      .eq("org_id", property.org_id),
    supabase
      .from("warehouses")
      .select("id", { count: "exact", head: true })
      .eq("property_id", propertyId),
    supabase
      .from("item_groups")
      .select("id", { count: "exact", head: true })
      .eq("org_id", property.org_id),
    supabase
      .from("roles")
      .select("id", { count: "exact", head: true })
      .eq("org_id", property.org_id),
  ]);

  const le = property.legal_entity as unknown as LegalEntityInfo | null;

  return (
    <div className="space-y-8">
      {/* Hero Welcome Banner */}
      <section className="rounded-xl border bg-gradient-to-br from-card via-card to-muted/40 p-6 shadow-sm sm:p-8">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold tracking-wider text-primary uppercase">
                {vi.property.dashboard}
              </span>
              <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-xs font-medium text-emerald-600">
                ● Đang hoạt động
              </span>
            </div>
            <h1 className="mt-2 text-2xl font-bold tracking-tight text-foreground sm:text-3xl">
              {property.name}
            </h1>
            <p className="mt-1 text-xs text-muted-foreground">
              Mã khách sạn:{" "}
              <span className="font-mono font-semibold text-foreground">
                {property.code}
              </span>
              {" | "}
              Pháp nhân:{" "}
              <span className="font-semibold text-foreground">
                {le?.name ?? "—"}
              </span>{" "}
              ({le?.code}){" | "}
              Định giá:{" "}
              <span className="font-semibold text-foreground">
                {le?.costing_method === "fifo" ? "FIFO" : "Bình quân gia quyền"}
              </span>
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Link
              href={`/${propertyId}/master/items`}
              className="inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 text-xs font-medium text-primary-foreground shadow transition-colors hover:bg-primary/90"
            >
              Vào danh mục
            </Link>
            <Link
              href="/admin/users"
              className="inline-flex h-9 items-center justify-center rounded-md border border-input bg-background px-4 text-xs font-medium shadow-sm transition-colors hover:bg-accent hover:text-accent-foreground"
            >
              Phân quyền nhân viên
            </Link>
          </div>
        </div>
      </section>

      {/* KPI Stats Grid */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-xl border bg-card p-4 shadow-sm">
          <p className="text-xs font-medium text-muted-foreground">
            Mặt hàng danh mục
          </p>
          <p className="mt-2 text-2xl font-bold text-foreground">
            {itemsCount ?? 0}
          </p>
          <p className="mt-1 text-[11px] text-muted-foreground">
            Vật tư, nguyên liệu, amenities
          </p>
        </div>

        <div className="rounded-xl border bg-card p-4 shadow-sm">
          <p className="text-xs font-medium text-muted-foreground">
            Kho hoạt động
          </p>
          <p className="mt-2 text-2xl font-bold text-foreground">
            {warehousesCount ?? 0}
          </p>
          <p className="mt-1 text-[11px] text-muted-foreground">
            Kho tổng, trung chuyển, minibar
          </p>
        </div>

        <div className="rounded-xl border bg-card p-4 shadow-sm">
          <p className="text-xs font-medium text-muted-foreground">
            Nhóm hàng hóa
          </p>
          <p className="mt-2 text-2xl font-bold text-foreground">
            {groupsCount ?? 0}
          </p>
          <p className="mt-1 text-[11px] text-muted-foreground">
            Thực phẩm, đồ uống, đồ vải...
          </p>
        </div>

        <div className="rounded-xl border bg-card p-4 shadow-sm">
          <p className="text-xs font-medium text-muted-foreground">
            Vai trò hệ thống
          </p>
          <p className="mt-2 text-2xl font-bold text-foreground">
            {rolesCount ?? 0}
          </p>
          <p className="mt-1 text-[11px] text-muted-foreground">
            Sẵn sàng gán cho nhân viên
          </p>
        </div>
      </div>

      {/* Main Functional Modules Grid */}
      <div>
        <h2 className="text-base font-semibold tracking-tight text-foreground">
          Bảng điều khiển các phân hệ
        </h2>
        <p className="mt-0.5 text-xs text-muted-foreground">
          Truy cập nhanh các chức năng nghiệp vụ của khách sạn
        </p>

        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Link
            href={`/${propertyId}/master/items`}
            className="group flex flex-col justify-between rounded-xl border bg-card p-5 shadow-sm transition-all hover:border-primary/50 hover:shadow-md"
          >
            <div>
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-500/10 font-bold text-blue-600">
                📦
              </div>
              <h3 className="mt-3 font-semibold text-foreground group-hover:text-primary">
                Danh mục vật tư
              </h3>
              <p className="mt-1.5 text-xs leading-relaxed text-muted-foreground">
                Quản lý mã hàng, tên, quy cách đóng gói, quy đổi đơn vị tính kho
                - công thức, và cờ Key Items.
              </p>
            </div>
            <div className="mt-4 flex items-center text-xs font-medium text-primary">
              Truy cập ngay →
            </div>
          </Link>

          <Link
            href={`/${propertyId}/master/warehouses`}
            className="group flex flex-col justify-between rounded-xl border bg-card p-5 shadow-sm transition-all hover:border-primary/50 hover:shadow-md"
          >
            <div>
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-emerald-500/10 font-bold text-emerald-600">
                🏢
              </div>
              <h3 className="mt-3 font-semibold text-foreground group-hover:text-primary">
                Kho & Điểm dịch vụ
              </h3>
              <p className="mt-1.5 text-xs leading-relaxed text-muted-foreground">
                Cơ cấu kho tổng, kho trung chuyển, kho hủy, minibar phòng nghỉ,
                và các outlet điểm bán.
              </p>
            </div>
            <div className="mt-4 flex items-center text-xs font-medium text-primary">
              Truy cập ngay →
            </div>
          </Link>

          <Link
            href="/admin/users"
            className="group flex flex-col justify-between rounded-xl border bg-card p-5 shadow-sm transition-all hover:border-primary/50 hover:shadow-md"
          >
            <div>
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-purple-500/10 font-bold text-purple-600">
                👥
              </div>
              <h3 className="mt-3 font-semibold text-foreground group-hover:text-primary">
                Người dùng & Phân quyền
              </h3>
              <p className="mt-1.5 text-xs leading-relaxed text-muted-foreground">
                Cấp tài khoản nhân viên, gán vai trò có thời hạn theo kho/ca làm
                việc, và đặt mã PIN ký số.
              </p>
            </div>
            <div className="mt-4 flex items-center text-xs font-medium text-primary">
              Truy cập ngay →
            </div>
          </Link>

          <Link
            href="/admin/settings"
            className="group flex flex-col justify-between rounded-xl border bg-card p-5 shadow-sm transition-all hover:border-primary/50 hover:shadow-md"
          >
            <div>
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-amber-500/10 font-bold text-amber-600">
                ⚙️
              </div>
              <h3 className="mt-3 font-semibold text-foreground group-hover:text-primary">
                Cấu hình & Quy tắc duyệt
              </h3>
              <p className="mt-1.5 text-xs leading-relaxed text-muted-foreground">
                Thiết lập ngưỡng duyệt đơn mua hàng, dung sai nhận hàng, cảnh
                báo biến động giá và giờ im lặng.
              </p>
            </div>
            <div className="mt-4 flex items-center text-xs font-medium text-primary">
              Truy cập ngay →
            </div>
          </Link>
        </div>
      </div>

      {/* Architecture & Security Highlights */}
      <section className="rounded-xl border bg-card p-6 shadow-sm">
        <h3 className="text-sm font-semibold text-foreground">
          Bảo mật và toàn vẹn dữ liệu
        </h3>
        <div className="mt-3 grid grid-cols-1 gap-4 text-xs text-muted-foreground sm:grid-cols-3">
          <div className="flex items-start gap-2">
            <span className="font-bold text-emerald-600">✓</span>
            <div>
              <p className="font-medium text-foreground">Sổ cái kho bất biến</p>
              <p className="mt-0.5">
                Mọi dịch chuyển kho qua hàm RPC post, chặn sửa/xóa trực tiếp,
                sửa sai bằng bút toán đảo.
              </p>
            </div>
          </div>
          <div className="flex items-start gap-2">
            <span className="font-bold text-emerald-600">✓</span>
            <div>
              <p className="font-medium text-foreground">
                Row Level Security 100%
              </p>
              <p className="mt-0.5">
                Dữ liệu phân lập theo pháp nhân và khách sạn, áp dụng chính sách
                phân quyền động.
              </p>
            </div>
          </div>
          <div className="flex items-start gap-2">
            <span className="font-bold text-emerald-600">✓</span>
            <div>
              <p className="font-medium text-foreground">
                Hồ sơ kiểm soát bù trừ
              </p>
              <p className="mt-0.5">
                Khách sạn áp dụng hồ sơ{" "}
                {property.sod_profile === "with_cc"
                  ? "Có Cost Controller"
                  : "Không có Cost Controller"}
                .
              </p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
