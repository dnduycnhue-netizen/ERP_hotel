import { redirect } from "next/navigation";
import { MobileEmptyState } from "@/components/mobile/mobile-page-states";
import { vi } from "@/i18n/vi";
import {
  listAccessibleProperties,
  selectedPropertyCookie,
} from "@/lib/supabase/access";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";
import { cookies } from "next/headers";

/**
 * Trang gốc màn hình hiện trường `/m` (W1).
 *
 * Chưa đăng nhập → /login. Có 1 khách sạn → vào thẳng màn nhận hàng
 * của khách sạn đó (luồng 1 tay thường dùng). Có nhiều khách sạn →
 * hiện danh sách chọn (mỗi dòng là link lớn ≥ 44px, chữ 16px); ưu
 * tiên khách sạn đã chọn trước đó (cookie `selected_property_id`
 * như trang chủ văn phòng). Không có khách sạn nào → trạng thái rỗng.
 */
export default async function MobileHomePage() {
  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (!user) {
    redirect("/login");
  }

  const properties = await listAccessibleProperties(supabase);

  if (properties.length === 0) {
    return (
      <main className="mx-auto flex min-h-screen max-w-2xl items-center justify-center px-4 py-6 text-base">
        <MobileEmptyState
          title={vi.mobile.chooseProperty}
          description={vi.mobile.noAccessibleProperty}
        />
      </main>
    );
  }

  if (properties.length === 1) {
    redirect(`/m/${properties[0].id}/receive`);
  }

  const cookieStore = await cookies();
  const preferredPropertyId = cookieStore.get(selectedPropertyCookie)?.value;
  const preferred = properties.find(({ id }) => id === preferredPropertyId);
  if (preferred) {
    redirect(`/m/${preferred.id}/receive`);
  }

  return (
    <main className="mx-auto min-h-screen max-w-2xl px-4 py-6 text-base">
      <h1 className="text-lg font-semibold">{vi.mobile.chooseProperty}</h1>
      <p className="mt-1 text-sm text-muted-foreground">
        {vi.mobile.choosePropertyHint}
      </p>
      <ul className="mt-4 flex flex-col gap-3">
        {properties.map((property) => (
          <li key={property.id}>
            <a
              href={`/m/${property.id}/receive`}
              className="flex min-h-11 items-center rounded-xl border bg-card px-4 py-3 text-base font-medium shadow-sm transition-colors hover:bg-muted"
            >
              {property.name}
            </a>
          </li>
        ))}
      </ul>
    </main>
  );
}
