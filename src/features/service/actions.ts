"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callServiceRpc, type ServiceActionResult } from "./rpc";
import {
  contractSaveSchema,
  scheduleGenerateSchema,
  serviceAcceptSchema,
  type ContractSaveInput,
  type ScheduleGenerateInput,
  type ServiceAcceptInput,
} from "./schemas";

export type ContractSaveResult = {
  ok: boolean;
  id: string;
  status: string;
  title: string;
  billing_cycle: string;
  start_date: string;
  end_date: string | null;
};

export type ScheduleGenerateResult = {
  ok: boolean;
  month: string;
  generated: number;
  existing: number;
  skipped_per_visit: number;
};

export type ServiceAcceptResult = {
  ok: boolean;
  id: string;
  schedule_id?: string | null;
  po_id?: string | null;
  status: string;
  rating: number | null;
};

function validationError(
  issues: { message: string }[],
): ServiceActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? "Dữ liệu không hợp lệ." };
}

function contractsPath(propertyId: string): string {
  return `/${propertyId}/procurement/service-contracts`;
}

function contractDetailPath(propertyId: string, contractId: string): string {
  return `/${propertyId}/procurement/service-contracts/${contractId}`;
}

function schedulesPath(propertyId: string): string {
  return `/${propertyId}/procurement/service-contracts/schedules`;
}

/** Tạo / cập nhật hợp đồng dịch vụ (RPC `service_contract_save`). */
export async function saveContractAction(
  input: ContractSaveInput,
): Promise<ServiceActionResult<ContractSaveResult>> {
  const parsed = contractSaveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callServiceRpc<ContractSaveResult>(
    supabase,
    "service_contract_save",
    {
      p_property_id: parsed.data.propertyId,
      p_contract: {
        title: parsed.data.title,
        supplier_id: parsed.data.supplierId,
        expense_category_id: parsed.data.expenseCategoryId,
        cost_center_id: parsed.data.costCenterId,
        start_date: parsed.data.startDate,
        end_date: parsed.data.endDate ?? null,
        billing_cycle: parsed.data.billingCycle,
        amount_per_cycle: parsed.data.amountPerCycle,
        renew_notice_days: parsed.data.renewNoticeDays,
        status: parsed.data.status,
      },
      p_contract_id: parsed.data.contractId ?? null,
    },
  );
  if (res.ok) {
    revalidatePath(contractsPath(parsed.data.propertyId));
    revalidatePath(contractDetailPath(parsed.data.propertyId, res.data.id));
  }
  return res;
}

/** Sinh lịch kỳ cho 1 tháng (RPC `service_schedule_generate`). */
export async function generateSchedulesAction(
  input: ScheduleGenerateInput,
): Promise<ServiceActionResult<ScheduleGenerateResult>> {
  const parsed = scheduleGenerateSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callServiceRpc<ScheduleGenerateResult>(
    supabase,
    "service_schedule_generate",
    { p_month: parsed.data.month },
  );
  if (res.ok) {
    revalidatePath(schedulesPath(parsed.data.propertyId));
    revalidatePath(contractsPath(parsed.data.propertyId));
  }
  return res;
}

/**
 * Nghiệm thu kỳ hợp đồng hoặc PO dịch vụ lẻ (RPC `service_accept`).
 * `photos` là danh sách id attachment đã upload trước qua
 * `uploadCapturedPhoto` (docType `service_acceptance`).
 */
export async function acceptServiceAction(
  input: ServiceAcceptInput,
): Promise<ServiceActionResult<ServiceAcceptResult>> {
  const parsed = serviceAcceptSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callServiceRpc<ServiceAcceptResult>(
    supabase,
    "service_accept",
    {
      p_schedule_id: parsed.data.scheduleId ?? null,
      p_rating: parsed.data.rating ?? null,
      p_photos: parsed.data.photos,
      p_po_id: parsed.data.poId ?? null,
      p_note: parsed.data.note ?? null,
    },
  );
  if (res.ok) {
    revalidatePath(schedulesPath(parsed.data.propertyId));
    revalidatePath(contractsPath(parsed.data.propertyId));
  }
  return res;
}

export type {
  ContractStatus,
  BillingCycle,
  ScheduleStatus,
  ServiceAcceptanceRow,
  ServiceContractDetail,
  ServiceContractRow,
  ServicePerms,
  ServicePoRow,
  ServiceScheduleRow,
} from "./queries";
