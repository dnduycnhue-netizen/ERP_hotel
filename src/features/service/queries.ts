import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import type { ServiceActionResult } from "./rpc";

/* ------------------------------------------------------------------ */
/* Mua dịch vụ — đọc trực tiếp `service_contracts` /                   */
/* `service_schedules` / `service_acceptances` / `purchase_orders`     */
/* (không có RPC list/get; RLS SELECT-only thực thi ở tầng dữ liệu).   */
/* `database.types.ts` chưa có các bảng này nên ép kiểu có chủ đích    */
/* tại đúng những chỗ đọc dưới đây (mẫu T-041).                        */
/*                                                                     */
/* LƯU Ý QUYỀN ĐỌC (policy SELECT của migration 350000):               */
/* service.contract.manage / service.accept / invoice.manage /         */
/* invoice.approve / ap.view / payment.request / payment.approve.      */
/* ------------------------------------------------------------------ */

export type BillingCycle = "monthly" | "quarterly" | "yearly" | "per_visit";
export type ContractStatus =
  "draft" | "active" | "suspended" | "expired" | "cancelled";
export type ScheduleStatus =
  "scheduled" | "performed" | "accepted" | "invoiced" | "paid" | "skipped";

/** 1 hợp đồng dịch vụ trong danh sách. */
export type ServiceContractRow = {
  id: string;
  org_id: string;
  property_id: string;
  supplier_id: string;
  supplier_name: string | null;
  supplier_code: string | null;
  expense_category_id: string;
  expense_category_name: string | null;
  cost_center_id: string;
  cost_center_name: string | null;
  title: string;
  start_date: string;
  end_date: string | null;
  billing_cycle: BillingCycle;
  amount_per_cycle: number;
  renew_notice_days: number;
  status: ContractStatus;
  created_by: string;
  created_at: string;
  updated_at: string;
};

/** 1 kỳ dịch vụ (kèm nghiệm thu nếu đã nghiệm thu). */
export type ServiceScheduleRow = {
  id: string;
  org_id: string;
  property_id: string;
  contract_id: string;
  contract_title: string | null;
  supplier_name: string | null;
  period_start: string;
  period_end: string;
  due_date: string;
  status: ScheduleStatus;
  created_at: string;
  acceptance: ServiceAcceptanceRow | null;
};

/** 1 lần nghiệm thu (theo kỳ hợp đồng hoặc theo PO lẻ). */
export type ServiceAcceptanceRow = {
  id: string;
  schedule_id: string | null;
  po_id: string | null;
  accepted_by: string;
  accepted_at: string;
  rating: number | null;
  note: string | null;
  photo_ids: string[];
};

/** Chi tiết 1 hợp đồng: hợp đồng + các kỳ (mỗi kỳ kèm nghiệm thu). */
export type ServiceContractDetail = {
  contract: ServiceContractRow;
  schedules: ServiceScheduleRow[];
};

/** 1 đơn mua dịch vụ (kind='service') kèm trạng thái nghiệm thu. */
export type ServicePoRow = {
  id: string;
  doc_no: string;
  supplier_id: string;
  supplier_name: string | null;
  total_amount: number;
  order_date: string;
  status: string;
  service_contract_id: string | null;
  contract_title: string | null;
  accepted: boolean;
  acceptance_kind: "po" | "schedule" | null;
};

/** Quyền dịch vụ của người gọi tại 1 property (qua RPC `my_permissions`). */
export type ServicePerms = {
  canManageContract: boolean;
  canAccept: boolean;
  canViewService: boolean;
};

type UntypedClient = SupabaseClient;

function untyped(supabase: SupabaseClient<Database>): UntypedClient {
  return supabase as unknown as UntypedClient;
}

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}

function toError(error: { message: string }): ServiceActionResult<never> {
  return {
    ok: false,
    error: getRpcErrorMessage(extractRpcCode(error.message)),
  };
}

/** Quyền dịch vụ của người gọi tại 1 property. */
export async function getServicePerms(
  propertyId: string,
): Promise<ServicePerms> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set(data ?? []);
  const canManageContract = perms.has("service.contract.manage");
  const canAccept = perms.has("service.accept");
  return {
    canManageContract,
    canAccept,
    canViewService:
      canManageContract ||
      canAccept ||
      perms.has("invoice.manage") ||
      perms.has("invoice.approve") ||
      perms.has("ap.view") ||
      perms.has("payment.request") ||
      perms.has("payment.approve"),
  };
}

const CONTRACT_COLUMNS =
  "id, org_id, property_id, supplier_id, expense_category_id, cost_center_id, title, start_date, end_date, billing_cycle, amount_per_cycle, renew_notice_days, status, created_by, created_at, updated_at";

type RawContractRow = Omit<
  ServiceContractRow,
  | "supplier_name"
  | "supplier_code"
  | "expense_category_name"
  | "cost_center_name"
> & {
  supplier: { name: string; code: string } | null;
  expense_category: { name: string } | null;
  cost_center: { name: string } | null;
};

function toContractRow(raw: RawContractRow): ServiceContractRow {
  const { supplier, expense_category, cost_center, ...rest } = raw;
  return {
    ...rest,
    supplier_name: supplier?.name ?? null,
    supplier_code: supplier?.code ?? null,
    expense_category_name: expense_category?.name ?? null,
    cost_center_name: cost_center?.name ?? null,
  };
}

const CONTRACT_SELECT = `${CONTRACT_COLUMNS}, supplier:suppliers(name, code), expense_category:expense_categories(name), cost_center:cost_centers(name)`;

/** Danh sách hợp đồng dịch vụ của 1 property (mới tạo trước). */
export async function listServiceContracts(
  propertyId: string,
  opts: {
    status?: ContractStatus | null;
    supplierId?: string | null;
  } = {},
): Promise<ServiceActionResult<ServiceContractRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("service_contracts")
    .select(CONTRACT_SELECT)
    .eq("property_id", propertyId)
    .order("created_at", { ascending: false })
    .limit(100);
  if (opts.status) query = query.eq("status", opts.status);
  if (opts.supplierId) query = query.eq("supplier_id", opts.supplierId);
  const { data, error } = await query;
  if (error) return toError(error);
  return {
    ok: true,
    data: ((data ?? []) as unknown as RawContractRow[]).map(toContractRow),
  };
}

type RawAcceptanceRow = {
  id: string;
  schedule_id: string | null;
  po_id: string | null;
  accepted_by: string;
  accepted_at: string;
  rating: number | null;
  note: string | null;
  photo_ids: unknown;
};

function toAcceptanceRow(raw: RawAcceptanceRow): ServiceAcceptanceRow {
  return {
    id: raw.id,
    schedule_id: raw.schedule_id,
    po_id: raw.po_id,
    accepted_by: raw.accepted_by,
    accepted_at: raw.accepted_at,
    rating: raw.rating,
    note: raw.note,
    photo_ids: Array.isArray(raw.photo_ids) ? (raw.photo_ids as string[]) : [],
  };
}

const ACCEPTANCE_COLUMNS =
  "id, schedule_id, po_id, accepted_by, accepted_at, rating, note, photo_ids";

type RawScheduleRow = Omit<
  ServiceScheduleRow,
  "contract_title" | "supplier_name" | "acceptance"
> & {
  contract: {
    title: string;
    supplier: { name: string } | null;
  } | null;
};

function toScheduleRow(
  raw: RawScheduleRow,
  acceptance: ServiceAcceptanceRow | null,
): ServiceScheduleRow {
  const { contract, ...rest } = raw;
  return {
    ...rest,
    contract_title: contract?.title ?? null,
    supplier_name: contract?.supplier?.name ?? null,
    acceptance,
  };
}

const SCHEDULE_SELECT = `id, org_id, property_id, contract_id, period_start, period_end, due_date, status, created_at, contract:service_contracts(title, supplier:suppliers(name))`;

/** Nghiệm thu của 1 tập kỳ (map theo schedule_id). */
async function listAcceptancesBySchedule(
  scheduleIds: string[],
): Promise<Map<string, ServiceAcceptanceRow>> {
  const map = new Map<string, ServiceAcceptanceRow>();
  if (scheduleIds.length === 0) return map;
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("service_acceptances")
    .select(ACCEPTANCE_COLUMNS)
    .in("schedule_id", scheduleIds);
  if (error || !data) return map;
  for (const raw of data as unknown as RawAcceptanceRow[]) {
    if (raw.schedule_id) map.set(raw.schedule_id, toAcceptanceRow(raw));
  }
  return map;
}

/** 1 hợp đồng + toàn bộ kỳ của nó (mỗi kỳ kèm nghiệm thu nếu có). */
export async function getServiceContract(
  contractId: string,
): Promise<ServiceActionResult<ServiceContractDetail>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data, error } = await client
    .from("service_contracts")
    .select(CONTRACT_SELECT)
    .eq("id", contractId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: false, error: getRpcErrorMessage(null) };
  const contract = toContractRow(data as unknown as RawContractRow);

  const { data: schedData, error: schedError } = await client
    .from("service_schedules")
    .select(SCHEDULE_SELECT)
    .eq("contract_id", contractId)
    .order("period_start", { ascending: true });
  if (schedError) return toError(schedError);
  const rawSchedules = (schedData ?? []) as unknown as RawScheduleRow[];
  const acceptances = await listAcceptancesBySchedule(
    rawSchedules.map((s) => s.id),
  );
  return {
    ok: true,
    data: {
      contract,
      schedules: rawSchedules.map((s) =>
        toScheduleRow(s, acceptances.get(s.id) ?? null),
      ),
    },
  };
}

/**
 * Danh sách kỳ dịch vụ của 1 property.
 * `month` dạng "YYYY-MM": lọc kỳ giao với tháng đó (kỳ quý/năm cũng hiện
 * khi giao tháng). Không truyền `month` thì trả 100 kỳ gần nhất.
 */
export async function listServiceSchedules(
  propertyId: string,
  opts: {
    month?: string | null;
    contractId?: string | null;
    status?: ScheduleStatus | null;
  } = {},
): Promise<ServiceActionResult<ServiceScheduleRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("service_schedules")
    .select(SCHEDULE_SELECT)
    .eq("property_id", propertyId)
    .order("period_start", { ascending: false })
    .limit(100);
  if (opts.contractId) query = query.eq("contract_id", opts.contractId);
  if (opts.status) query = query.eq("status", opts.status);
  if (opts.month) {
    const [y, m] = opts.month.split("-").map(Number);
    const monthStart = `${opts.month}-01`;
    const monthEnd = new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
    query = query.lte("period_start", monthEnd).gte("period_end", monthStart);
  }
  const { data, error } = await query;
  if (error) return toError(error);
  const rawSchedules = (data ?? []) as unknown as RawScheduleRow[];
  const acceptances = await listAcceptancesBySchedule(
    rawSchedules.map((s) => s.id),
  );
  return {
    ok: true,
    data: rawSchedules.map((s) =>
      toScheduleRow(s, acceptances.get(s.id) ?? null),
    ),
  };
}

/**
 * Đơn mua dịch vụ (kind='service') đã đặt hàng, kèm trạng thái nghiệm thu.
 * `accepted` = có nghiệm thu trực tiếp theo PO, hoặc có nghiệm thu theo
 * kỳ của hợp đồng mà PO trỏ tới (xấp xỉ theo `_service_po_accepted` ở
 * tầng DB — ở đây không có `invoice_date` nên dùng "có kỳ accepted nào
 * của hợp đồng" làm điều kiện hiển thị; RPC vẫn kiểm tra lại chính xác
 * khi khớp/thanh toán).
 */
export async function listServicePos(
  propertyId: string,
  opts: { onlyPending?: boolean } = {},
): Promise<ServiceActionResult<ServicePoRow[]>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data, error } = await client
    .from("purchase_orders")
    .select(
      "id, doc_no, supplier_id, total_amount, order_date, status, service_contract_id, supplier:suppliers(name), contract:service_contracts(title)",
    )
    .eq("property_id", propertyId)
    .eq("kind", "service")
    .in("status", ["approved", "sent", "partially_received", "received"])
    .order("order_date", { ascending: false })
    .limit(100);
  if (error) return toError(error);
  const rawPos = (data ?? []) as unknown as Array<{
    id: string;
    doc_no: string;
    supplier_id: string;
    total_amount: number;
    order_date: string;
    status: string;
    service_contract_id: string | null;
    supplier: { name: string } | null;
    contract: { title: string } | null;
  }>;
  if (rawPos.length === 0) return { ok: true, data: [] };

  const poIds = rawPos.map((p) => p.id);
  const { data: accData } = await client
    .from("service_acceptances")
    .select("po_id, schedule_id")
    .in("po_id", poIds);
  const acceptedByPo = new Set(
    ((accData ?? []) as unknown as Array<{ po_id: string | null }>)
      .map((a) => a.po_id)
      .filter((x): x is string => x !== null),
  );

  const contractIds = rawPos
    .map((p) => p.service_contract_id)
    .filter((x): x is string => x !== null);
  const acceptedContractIds = new Set<string>();
  if (contractIds.length > 0) {
    const { data: schedData } = await client
      .from("service_schedules")
      .select("contract_id")
      .in("contract_id", contractIds)
      .eq("status", "accepted");
    const acceptedSchedContracts = new Set(
      ((schedData ?? []) as unknown as Array<{ contract_id: string }>).map(
        (s) => s.contract_id,
      ),
    );
    for (const c of contractIds) {
      if (acceptedSchedContracts.has(c)) acceptedContractIds.add(c);
    }
  }

  const rows: ServicePoRow[] = rawPos.map((p) => {
    const byPo = acceptedByPo.has(p.id);
    const bySchedule =
      p.service_contract_id !== null &&
      acceptedContractIds.has(p.service_contract_id);
    return {
      id: p.id,
      doc_no: p.doc_no,
      supplier_id: p.supplier_id,
      supplier_name: p.supplier?.name ?? null,
      total_amount: Number(p.total_amount),
      order_date: p.order_date,
      status: p.status,
      service_contract_id: p.service_contract_id,
      contract_title: p.contract?.title ?? null,
      accepted: byPo || bySchedule,
      acceptance_kind: byPo ? "po" : bySchedule ? "schedule" : null,
    };
  });
  return {
    ok: true,
    data: opts.onlyPending ? rows.filter((r) => !r.accepted) : rows,
  };
}
