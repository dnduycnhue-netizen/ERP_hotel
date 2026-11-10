import { createClient } from "npm:@supabase/supabase-js@2";

// Đặt lại mật khẩu cho một tài khoản khác bởi quản trị viên
// (nới lỏng admin-relax 10/11/2026 — app trước đây không có đường nào
// đặt lại mật khẩu cho người khác).
//
// - Chỉ người có quyền `admin.users.manage` cấp chuỗi mới gọi được.
//   JWT của người gọi được xác minh bằng anon key, quyền được kiểm tra qua
//   RPC `user_has_perm` bằng service role (đúng mẫu admin-create-user).
// - Quản trị có thể tự đặt mật khẩu tạm (`password`, tối thiểu 8 ký tự,
//   tiện cho tài khoản test) hoặc để trống để hệ thống sinh ngẫu nhiên.
//   Mật khẩu tạm trả về MỘT LẦN cho quản trị viên để bàn giao trực tiếp;
//   KHÔNG bao giờ ghi mật khẩu vào log.
// - Ghi audit_log lại việc đặt lại (ai đặt, cho ai, lúc nào).
// - Không đặt lại mật khẩu của chính mình qua đường này — quản trị tự đổi
//   mật khẩu của mình ở màn /settings/password.
// - Không gửi email thật, không dùng secret ngoài Supabase secrets.

type ResetPasswordRequest = {
  userId: string;
  password?: string;
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

function readResetPasswordRequest(value: unknown): ResetPasswordRequest | null {
  if (!isRecord(value)) return null;
  const userId = readString(value.userId);
  const password = readString(value.password);
  if (!UUID_PATTERN.test(userId)) return null;
  if (password !== "" && (password.length < 8 || password.length > 128)) {
    return null;
  }
  return {
    userId,
    password: password === "" ? undefined : password,
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
    return jsonResponse(503, { error: "admin_reset_password_unavailable" });
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

  const input = readResetPasswordRequest(body);
  if (!input) {
    return jsonResponse(400, { error: "invalid_reset_request" });
  }

  if (input.userId === callerId) {
    return jsonResponse(400, { error: "cannot_reset_own_password" });
  }

  const { data: target, error: targetError } = await supabase
    .from("profiles")
    .select("id")
    .eq("id", input.userId)
    .maybeSingle();
  if (targetError || !target) {
    return jsonResponse(404, { error: "user_not_found" });
  }

  const tempPassword = input.password ?? generateTempPassword();

  const { error: updateError } = await supabase.auth.admin.updateUserById(
    input.userId,
    { password: tempPassword },
  );
  if (updateError) {
    console.error("admin-reset-password failed.", {
      userId: input.userId,
      message: updateError.message,
    });
    return jsonResponse(502, { error: "reset_password_failed" });
  }

  const { error: auditError } = await supabase.from("audit_log").insert({
    table_name: "profiles",
    row_id: input.userId,
    action: "UPDATE",
    new_data: { event: "admin_password_reset" },
    actor: callerId,
    client_info: { source: "admin_reset_password" },
  });
  if (auditError) {
    // Đặt lại đã xong; chỉ ghi log lỗi audit, không báo thất bại.
    console.error("admin-reset-password could not write audit log.", {
      userId: input.userId,
      message: auditError.message,
    });
  }

  // Mật khẩu tạm chỉ trả về một lần — quản trị viên bàn giao trực tiếp
  // cho nhân viên qua kênh nội bộ, không gửi qua email.
  return jsonResponse(200, {
    ok: true,
    user_id: input.userId,
    temp_password: tempPassword,
  });
});
