import { z } from "zod";

/**
 * Payload cua RPC property_dashboard_overview (C10, Q125): dung nhung gi
 * trang tong quan dang hien — thong tin KS + phap nhan + 4 count. Khong
 * co chung tu gan day / tom tat canh bao vi trang hien khong hien 2 muc do.
 */
export const dashboardOverviewSchema = z.object({
  ok: z.literal(true),
  property: z.object({
    id: z.string().uuid(),
    code: z.string(),
    name: z.string(),
    sod_profile: z.string(),
    rooms_count: z.number().int().nonnegative(),
    org_id: z.string().uuid(),
    legal_entity: z
      .object({
        code: z.string(),
        name: z.string(),
        costing_method: z.string(),
        accounting_regime: z.string(),
      })
      .nullable(),
  }),
  counts: z.object({
    items: z.number().int().nonnegative(),
    warehouses: z.number().int().nonnegative(),
    item_groups: z.number().int().nonnegative(),
    roles: z.number().int().nonnegative(),
  }),
});

export type DashboardOverview = z.infer<typeof dashboardOverviewSchema>;

/** Parse + chuan hoa payload jsonb tu RPC; nem ZodError neu sai hop dong. */
export function parseDashboardOverview(value: unknown): DashboardOverview {
  return dashboardOverviewSchema.parse(value);
}
