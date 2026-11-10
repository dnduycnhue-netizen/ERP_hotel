import { createClient } from "npm:@supabase/supabase-js@2";

// T-005: Tạo tài khoản người dùng bởi quản trị viên (docs/09-API-RPC.md mục 9).
//
// - Chỉ người có quyền `admin.users.manage` cấp chuỗi mới gọi được.
//   JWT của người gọi được xác minh bằng anon key, quyền được kiểm tra qua
//   RPC `user_has_perm` bằng service role.
// - Tạo user KHÔNG cần email thật: nếu không truyền email, hệ thống sinh
//   địa chỉ nội bộ `<ma_nv>@erp.internal` (không gửi mail đi đâu cả).
// - Mật khẩu tạm: quản trị có thể tự đặt (`password`, tối thiểu 8 ký tự,
//   tiện cho tài khoản test) hoặc để trống để hệ thống sinh ngẫu nhiên.
//   Mật khẩu tạm trả về MỘT LẦN cho quản trị viên để bàn giao trực tiếp
//   cho nhân viên; nhân viên đổi mật khẩu sau lần đăng nhập đầu (màn
//   /settings/password).
// - Không gửi email thật, không dùng secret ngoài Supabase secrets.
// - Vai trò ban đầu (nếu truyền) được kiểm tra trước khi tạo user để
//   tránh tạo dở tài khoản. Nhận nhiều vai trò cùng lúc (`roles` — mỗi
//   vai trò kèm phạm vi riêng); `roleId` cũ vẫn được chấp nhận để tương
//   thích ngược. Mọi vai trò đang hoạt động đều gán được, kể cả
//   sys_admin/owner (nới lỏng admin-relax 10/11/2026).

type RoleAssignmentInput = {
  roleId: string;
  propertyId?: string;
  outletIds?: string[];
  warehouseIds?: string[];
};

type CreateUserRequest = {
  employeeCode: string;
  fullName: string;
  email?: string;
  phone?: string;
  password?: string;
  roleId?: string;
  propertyId?: string;
  outletIds?: string[];
  warehouseIds?: string[];
  roles?: RoleAssignmentInput[];
  validTo?: string;
};

const INTERNAL_EMAIL_DOMAIN = "erp.internal";
const EMPLOYEE_CODE_PATTERN = /^[A-Z0-9_-]{2,20}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function readUuidArray(value: unknown): string[] | null {
  if (value === undefined || value === null) return null;
  if (!Array.isArray(value)) return null;
  const ids = value.filter(
    (item): item is string =>
      typeof item === "string" &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        item,
      ),
  );
  return ids.length === value.length ? ids : null;
}

function readRoleAssignments(value: unknown): RoleAssignmentInput[] | null {
  if (value === undefined || value === null) return null;
  if (!Array.isArray(value)) return null;
  const uuidPattern =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const assignments: RoleAssignmentInput[] = [];
  for (const item of value) {
    if (!isRecord(item)) return null;
    const roleId = readString(item.roleId);
    const propertyId = readString(item.propertyId);
    const outletIds = readUuidArray(item.outletIds);
    const warehouseIds = readUuidArray(item.warehouseIds);
    if (!uuidPattern.test(roleId)) return null;
    if (propertyId !== "" && !uuidPattern.test(propertyId)) return null;
    if (outletIds === null || warehouseIds === null) return null;
    assignments.push({
      roleId,
      propertyId: propertyId === "" ? undefined : propertyId,
      outletIds: outletIds ?? undefined,
      warehouseIds: warehouseIds ?? undefined,
    });
  }
  return assignments;
}

function readCreateUserRequest(value: unknown): CreateUserRequest | null {
  if (!isRecord(value)) return null;

  const employeeCode = readString(value.employeeCode).toUpperCase();
  const fullName = readString(value.fullName);
  const email = readString(value.email).toLowerCase();
  const phone = readString(value.phone);
  const password = readString(value.password);
  const roleId = readString(value.roleId);
  const propertyId = readString(value.propertyId);
  const outletIds = readUuidArray(value.outletIds);
  const warehouseIds = readUuidArray(value.warehouseIds);
  const roles = readRoleAssignments(value.roles);
  const validTo = readString(value.validTo);

  if (!EMPLOYEE_CODE_PATTERN.test(employeeCode) || fullName.length === 0) {
    return null;
  }
  if (email !== "" && !EMAIL_PATTERN.test(email)) return null;
  if (password !== "" && (password.length < 8 || password.length > 128)) {
    return null;
  }
  if (outletIds === null || warehouseIds === null) return null;
  if (
    (roleId !== "" &&
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        roleId,
      )) ||
    (propertyId !== "" &&
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        propertyId,
      ))
  ) {
    return null;
  }
  if (roles === null && value.roles !== undefined && value.roles !== null) {
    return null;
  }
  if (validTo !== "" && Number.isNaN(Date.parse(validTo))) return null;

  return {
    employeeCode,
    fullName,
    email: email === "" ? undefined : email,
    phone: phone === "" ? undefined : phone,
    password: password === "" ? undefined : password,
    roleId: roleId === "" ? undefined : roleId,
    propertyId: propertyId === "" ? undefined : propertyId,
    outletIds: outletIds ?? undefined,
    warehouseIds: warehouseIds ?? undefined,
    roles: roles ?? undefined,
    validTo: validTo === "" ? undefined : validTo,
  };
}

function generateTempPassword(): string {
  const alphabet =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%";
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
    console.error("Supabase Edge Function environment is incomplete.");
    return jsonResponse(503, { error: "admin_create_user_unavailable" });
  }

  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  const anonClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: callerData, error: callerError } =
    await anonClient.auth.getUser(token);
  if (callerError || !callerData.user) {
    return jsonResponse(401, { error: "unauthorized" });
  }
  const callerId = callerData.user.id;

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: canManage, error: permError } = await supabase.rpc(
    "user_has_perm",
    {
      p_user_id: callerId,
      p_property: null,
      p_perm: "admin.users.manage",
    },
  );
  if (permError || canManage !== true) {
    return jsonResponse(403, { error: "forbidden_admin_users_manage" });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const input = readCreateUserRequest(body);
  if (!input) {
    return jsonResponse(400, { error: "invalid_create_user_request" });
  }

  // Gộp vai trò: `roles` mới ưu tiên; nếu không có thì dùng `roleId` cũ.
  const assignments: RoleAssignmentInput[] =
    input.roles ??
    (input.roleId
      ? [
          {
            roleId: input.roleId,
            propertyId: input.propertyId,
            outletIds: input.outletIds,
            warehouseIds: input.warehouseIds,
          },
        ]
      : []);

  // Kiểm tra vai trò/khách sạn trước khi tạo user để tránh tạo dở.
  // Mọi vai trò đang hoạt động đều gán được (kể cả sys_admin/owner).
  for (const assignment of assignments) {
    const { data: role, error: roleError } = await supabase
      .from("roles")
      .select("id, org_id, active")
      .eq("id", assignment.roleId)
      .maybeSingle();
    if (roleError || !role || !role.active) {
      return jsonResponse(400, { error: "invalid_role" });
    }
    if (assignment.propertyId) {
      const { data: property, error: propertyError } = await supabase
        .from("properties")
        .select("id, org_id")
        .eq("id", assignment.propertyId)
        .maybeSingle();
      if (propertyError || !property || property.org_id !== role.org_id) {
        return jsonResponse(400, { error: "invalid_property_for_role" });
      }
    }
  }

  const { data: existingCode } = await supabase
    .from("profiles")
    .select("id")
    .eq("employee_code", input.employeeCode)
    .maybeSingle();
  if (existingCode) {
    return jsonResponse(409, { error: "employee_code_exists" });
  }

  const loginEmail =
    input.email ??
    `${input.employeeCode.toLowerCase()}@${INTERNAL_EMAIL_DOMAIN}`;
  // Quản trị tự đặt mật khẩu tạm (tiện cho tài khoản test) hoặc để hệ
  // thống sinh ngẫu nhiên khi bỏ trống.
  const tempPassword = input.password ?? generateTempPassword();

  const { data: created, error: createError } =
    await supabase.auth.admin.createUser({
      email: loginEmail,
      password: tempPassword,
      email_confirm: true,
      user_metadata: {
        employee_code: input.employeeCode,
        full_name: input.fullName,
      },
    });

  if (createError || !created.user) {
    const message = createError?.message ?? "No user returned.";
    console.error("admin-create-user failed.", {
      code: createError?.code,
      status: createError?.status,
      message,
    });
    if (
      createError?.code === "email_exists" ||
      message.toLowerCase().includes("already been registered")
    ) {
      return jsonResponse(409, { error: "email_exists" });
    }
    return jsonResponse(502, { error: "create_user_failed" });
  }

  const userId = created.user.id;

  const { error: profileError } = await supabase
    .from("profiles")
    .update({
      employee_code: input.employeeCode,
      full_name: input.fullName,
      phone: input.phone ?? null,
    })
    .eq("id", userId);
  if (profileError) {
    console.error("admin-create-user could not update the profile.", {
      userId,
      message: profileError.message,
    });
    await supabase.auth.admin.deleteUser(userId);
    return jsonResponse(502, { error: "create_user_failed" });
  }

  for (const assignment of assignments) {
    const { error: assignError } = await supabase
      .from("user_property_roles")
      .insert({
        user_id: userId,
        role_id: assignment.roleId,
        property_id: assignment.propertyId ?? null,
        outlet_ids: assignment.outletIds ?? null,
        warehouse_ids: assignment.warehouseIds ?? null,
        valid_to: input.validTo ?? null,
        granted_by: callerId,
      });
    if (assignError) {
      console.error("admin-create-user could not assign the role.", {
        userId,
        roleId: assignment.roleId,
        message: assignError.message,
      });
      await supabase.auth.admin.deleteUser(userId);
      return jsonResponse(502, { error: "assign_role_failed" });
    }
  }

  // Mật khẩu tạm chỉ trả về một lần — quản trị viên bàn giao trực tiếp
  // cho nhân viên qua kênh nội bộ, không gửi qua email.
  return jsonResponse(201, {
    ok: true,
    user_id: userId,
    login_email: loginEmail,
    temp_password: tempPassword,
    employee_code: input.employeeCode,
  });
});
