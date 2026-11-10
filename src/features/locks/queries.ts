import "server-only";

import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";
import { isValidYearMonth, monthRange } from "./date-utils";
import { callLocksRpc, type LockActionResult } from "./rpc";

/* ------------------------------------------------------------------ */
/* Man khoa ngay / khoa ky (C1) — doc truc tiep cac bang da co trong  */
/* `database.types.ts` (`warehouses`, `day_locks`,                     */
/* `accounting_periods`, `properties`) + RPC chi doc                   */
/* `period_close_check` (C1). Khong dung bang `stock_counts` o day     */
/* (chua co trong types): trang thai dong bang nam trong ket qua cua   */
/* `period_close_check`.                                               */
/* ------------------------------------------------------------------ */

/** 1 kho cua property (RLS `warehouses` chi tra kho user duoc thay). */
export type LockWarehouse = {
  id: string;
  property_id: string;
  code: string;
  name: string;
  kind: string;
};

/** 1 dong khoa ngay (`day_locks`). */
export type DayLockRow = {
  id: string;
  warehouse_id: string;
  business_date: string;
  shift: string | null;
  locked_by: string;
  locked_at: string;
};

/** 1 ky ke toan (`accounting_periods`). */
export type AccountingPeriodRow = {
  id: string;
  legal_entity_id: string;
  year: number;
  month: number;
  status: string;
  closed_by: string | null;
  closed_at: string | null;
};

/** 1 kho thieu dot monthly_full da khoa trong thang. */
export type MissingCount = {
  warehouse_id: string;
  warehouse_name: string;
  property_id: string;
};

/** 1 kho dang dong bang kiem dem (co dot monthly_full dang mo). */
export type FrozenWarehouse = {
  warehouse_id: string;
  warehouse_name: string;
  property_id: string;
  count_id: string;
  count_doc_no: string;
  count_status: string;
};

/** Ket qua RPC `period_close_check` (C1). */
export type PeriodCloseCheck = {
  ok: boolean;
  already_closed: boolean;
  count_blocked: boolean;
  missing_counts: MissingCount[];
  po_blocked: boolean;
  po_count: number;
  advance_blocked: boolean;
  advance_count: number;
  frozen_warehouses: FrozenWarehouse[];
};

export type LocksOverview = {
  propertyId: string;
  propertyName: string;
  entityId: string;
  year: number;
  month: number;
  warehouses: LockWarehouse[];
  locks: DayLockRow[];
  periods: AccountingPeriodRow[];
  check: PeriodCloseCheck;
  permissions: string[];
};

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}

function toError<T>(error: { message: string }): LockActionResult<T> {
  return {
    ok: false,
    error: getRpcErrorMessage(extractRpcCode(error.message)),
  };
}

/**
 * Du lieu cho man `/[property]/inventory/locks` cua 1 thang.
 * RLS tu gioi han: kho chi kho user duoc thay, khoa ngay chi property
 * cua user, ky chi phap nhan cua property user thuoc.
 */
export async function getLocksOverview(input: {
  propertyId: string;
  year: number;
  month: number;
}): Promise<LockActionResult<LocksOverview>> {
  const { propertyId, year, month } = input;
  if (!isValidYearMonth(year, month)) {
    return { ok: false, error: vi.locks.invalidMonth };
  }
  const supabase = await createClient();
  const { first, last } = monthRange(year, month);

  const { data: property, error: propertyError } = await supabase
    .from("properties")
    .select("legal_entity_id, name")
    .eq("id", propertyId)
    .maybeSingle();
  if (propertyError || !property) {
    return { ok: false, error: getRpcErrorMessage(null) };
  }

  const { data: warehouses, error: warehousesError } = await supabase
    .from("warehouses")
    .select("id, property_id, code, name, kind")
    .eq("property_id", propertyId)
    .order("code", { ascending: true });
  if (warehousesError) {
    return toError(warehousesError);
  }

  const { data: locks, error: locksError } = await supabase
    .from("day_locks")
    .select("id, warehouse_id, business_date, shift, locked_by, locked_at")
    .eq("property_id", propertyId)
    .gte("business_date", first)
    .lte("business_date", last)
    .order("business_date", { ascending: true });
  if (locksError) {
    return toError(locksError);
  }

  const { data: periods, error: periodsError } = await supabase
    .from("accounting_periods")
    .select("id, legal_entity_id, year, month, status, closed_by, closed_at")
    .eq("legal_entity_id", property.legal_entity_id)
    .order("year", { ascending: false })
    .order("month", { ascending: false })
    .limit(13);
  if (periodsError) {
    return toError(periodsError);
  }

  const { data: myPerms, error: permsError } = await supabase.rpc(
    "my_permissions",
    { p_property: propertyId },
  );
  if (permsError) {
    return toError(permsError);
  }

  const check = await callLocksRpc<PeriodCloseCheck>(
    supabase,
    "period_close_check",
    {
      p_entity_id: property.legal_entity_id,
      p_year: year,
      p_month: month,
    },
  );
  if (!check.ok) {
    return { ok: false, error: check.error };
  }

  return {
    ok: true,
    data: {
      propertyId,
      propertyName: property.name,
      entityId: property.legal_entity_id,
      year,
      month,
      warehouses: (warehouses ?? []) as LockWarehouse[],
      locks: (locks ?? []) as DayLockRow[],
      periods: (periods ?? []) as AccountingPeriodRow[],
      check: check.data,
      permissions: myPerms ?? [],
    },
  };
}
