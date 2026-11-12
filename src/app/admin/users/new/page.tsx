import { notFound } from "next/navigation";
import { CreateUserForm } from "@/components/admin/create-user-form";
import { PageHeader } from "@/components/shell/page-header";
import { hasChainPerm, listRoles } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { listAccessibleProperties } from "@/lib/supabase/access";
import { createClient } from "@/lib/supabase/server";

/** Tạo tài khoản mới trong 1 bước (mẫu vai trò + mật khẩu tạm). */
export default async function CreateUserPage() {
  const supabase = await createClient();
  const canManage = await hasChainPerm(supabase, "admin.users.manage");
  if (!canManage) {
    notFound();
  }
  const [roles, properties] = await Promise.all([
    listRoles(supabase),
    listAccessibleProperties(supabase),
  ]);

  return (
    <div className="space-y-6">
      <PageHeader
        title={vi.admin.createUserTitle}
        description={vi.admin.createUserDescription}
      />
      <div className="max-w-2xl rounded-lg border bg-card p-6">
        <CreateUserForm
          roles={roles.filter((role) => role.active)}
          properties={properties}
        />
      </div>
    </div>
  );
}
