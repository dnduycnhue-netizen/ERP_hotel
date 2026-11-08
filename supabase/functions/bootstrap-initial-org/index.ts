import { createClient } from "npm:@supabase/supabase-js@2";

type BootstrapAccount = {
  email: string;
  fullName: string;
};

type BootstrapRequest = {
  orgName: string;
  legalEntityCode: string;
  legalEntityName: string;
  propertyCode: string;
  propertyName: string;
  admins: [BootstrapAccount, BootstrapAccount];
  testUser: BootstrapAccount;
};

type CreatedUser = {
  id: string;
};

const appUrl = "https://erphotel.vercel.app";

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readAccount(value: unknown): BootstrapAccount | null {
  if (!isRecord(value)) return null;

  const email =
    typeof value.email === "string" ? value.email.trim().toLowerCase() : "";
  const fullName =
    typeof value.fullName === "string" ? value.fullName.trim() : "";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || fullName.length === 0) {
    return null;
  }

  return { email, fullName };
}

function readBootstrapRequest(value: unknown): BootstrapRequest | null {
  if (
    !isRecord(value) ||
    !Array.isArray(value.admins) ||
    value.admins.length !== 2
  ) {
    return null;
  }

  const orgName = typeof value.orgName === "string" ? value.orgName.trim() : "";
  const legalEntityCode =
    typeof value.legalEntityCode === "string"
      ? value.legalEntityCode.trim().toUpperCase()
      : "";
  const legalEntityName =
    typeof value.legalEntityName === "string"
      ? value.legalEntityName.trim()
      : "";
  const propertyCode =
    typeof value.propertyCode === "string"
      ? value.propertyCode.trim().toUpperCase()
      : "";
  const propertyName =
    typeof value.propertyName === "string" ? value.propertyName.trim() : "";
  const adminOne = readAccount(value.admins[0]);
  const adminTwo = readAccount(value.admins[1]);
  const testUser = readAccount(value.testUser);

  if (
    !orgName ||
    !/^[A-Z0-9_-]{2,20}$/.test(legalEntityCode) ||
    !legalEntityName ||
    !/^[A-Z0-9_-]{2,20}$/.test(propertyCode) ||
    !propertyName ||
    !adminOne ||
    !adminTwo ||
    !testUser
  ) {
    return null;
  }

  const uniqueEmails = new Set([
    adminOne.email,
    adminTwo.email,
    testUser.email,
  ]);
  if (uniqueEmails.size !== 3) return null;

  return {
    orgName,
    legalEntityCode,
    legalEntityName,
    propertyCode,
    propertyName,
    admins: [adminOne, adminTwo],
    testUser,
  };
}

function tokenMatches(expected: string, actual: string): boolean {
  const encoder = new TextEncoder();
  const expectedBytes = encoder.encode(expected);
  const actualBytes = encoder.encode(actual);
  let difference = expectedBytes.length ^ actualBytes.length;
  const length = Math.max(expectedBytes.length, actualBytes.length);

  for (let index = 0; index < length; index += 1) {
    difference |= (expectedBytes[index] ?? 0) ^ (actualBytes[index] ?? 0);
  }

  return difference === 0;
}

async function removeCreatedUsers(
  supabase: ReturnType<typeof createClient>,
  users: CreatedUser[],
) {
  for (const user of users.reverse()) {
    const { error } = await supabase.auth.admin.deleteUser(user.id);
    if (error) {
      console.error("Bootstrap rollback could not delete an invited user.", {
        userId: user.id,
        message: error.message,
      });
    }
  }
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  const bootstrapToken = Deno.env.get("BOOTSTRAP_TOKEN");
  if (!bootstrapToken) {
    return jsonResponse(410, { error: "bootstrap_unavailable" });
  }

  const suppliedToken = request.headers.get("x-bootstrap-token") ?? "";
  if (!tokenMatches(bootstrapToken, suppliedToken)) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const input = readBootstrapRequest(body);
  if (!input) {
    return jsonResponse(400, { error: "invalid_bootstrap_request" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Supabase Edge Function environment is incomplete.");
    return jsonResponse(503, { error: "bootstrap_unavailable" });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { count: organizationCount, error: organizationError } = await supabase
    .from("organizations")
    .select("id", { count: "exact", head: true });

  if (organizationError || organizationCount === null) {
    console.error("Bootstrap could not verify the organization state.", {
      message: organizationError?.message,
    });
    return jsonResponse(503, { error: "bootstrap_state_unavailable" });
  }
  if (organizationCount > 0) {
    return jsonResponse(409, { error: "bootstrap_already_initialized" });
  }

  const { data: userList, error: userListError } =
    await supabase.auth.admin.listUsers({ page: 1, perPage: 1 });
  if (userListError) {
    console.error("Bootstrap could not verify the Auth state.", {
      message: userListError.message,
    });
    return jsonResponse(503, { error: "bootstrap_state_unavailable" });
  }
  if (userList.users.length > 0) {
    return jsonResponse(409, { error: "bootstrap_already_initialized" });
  }

  const createdUsers: CreatedUser[] = [];
  const accounts = [...input.admins, input.testUser];

  for (const account of accounts) {
    const { data, error } = await supabase.auth.admin.inviteUserByEmail(
      account.email,
      {
        data: { full_name: account.fullName },
        redirectTo: `${appUrl}/auth/callback`,
      },
    );

    if (error || !data.user) {
      await removeCreatedUsers(supabase, createdUsers);
      console.error("Bootstrap invitation failed.", {
        message: error?.message ?? "No user returned.",
      });
      return jsonResponse(502, { error: "invitation_failed" });
    }

    createdUsers.push({ id: data.user.id });
  }

  const { data: bootstrapResult, error: bootstrapError } = await supabase.rpc(
    "bootstrap_initial_org",
    {
      p_org_name: input.orgName,
      p_legal_entity_code: input.legalEntityCode,
      p_legal_entity_name: input.legalEntityName,
      p_property_code: input.propertyCode,
      p_property_name: input.propertyName,
      p_admin_one: createdUsers[0].id,
      p_admin_two: createdUsers[1].id,
      p_test_user: createdUsers[2].id,
    },
  );

  if (bootstrapError) {
    await removeCreatedUsers(supabase, createdUsers);
    console.error("Bootstrap organization transaction failed.", {
      code: bootstrapError.code,
      message: bootstrapError.message,
    });
    return jsonResponse(500, { error: "bootstrap_failed" });
  }

  return jsonResponse(201, {
    ok: true,
    result: bootstrapResult,
    invitationsSent: createdUsers.length,
  });
});
