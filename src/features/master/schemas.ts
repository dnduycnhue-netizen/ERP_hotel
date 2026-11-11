import { z } from "zod";
import { vi } from "@/i18n/vi";

export const itemSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, vi.master.itemCodeRequired)
    .max(50, vi.master.itemCodeMax50)
    .regex(/^[A-Za-z0-9_-]+$/, vi.master.itemCodeFormat),
  name: z
    .string()
    .trim()
    .min(1, vi.master.itemNameRequired)
    .max(200, vi.master.itemNameMax200),
  nameEn: z.string().trim().max(200).optional().nullable(),
  groupId: z.string().uuid(vi.master.selectItemGroup),
  stockUom: z.string().trim().min(1, vi.master.selectStockUom),
  recipeUom: z.string().trim().optional().nullable(),
  stockToRecipe: z.coerce
    .number()
    .positive(vi.master.conversionFactorPositive)
    .optional()
    .nullable(),
  isKeyItem: z.boolean().default(false),
  abcClass: z.enum(["A", "B", "C"]).optional().nullable(),
  trackLot: z.boolean().default(false),
  shelfLifeDays: z.coerce.number().int().positive().optional().nullable(),
  storageCondition: z.string().trim().max(100).optional().nullable(),
  vatRate: z.coerce.number().min(0).max(100).optional().nullable(),
  allowedChannels: z
    .array(z.enum(["contract", "market"]))
    .min(1, vi.master.selectAtLeastOneChannel),
  tareG: z.coerce.number().min(0).optional().nullable(),
  densityGMl: z.coerce.number().positive().optional().nullable(),
  status: z.enum(["active", "inactive"]).default("active"),
});

export type ItemSaveInput = z.infer<typeof itemSaveSchema>;

export const itemGroupSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  codePrefix: z
    .string()
    .trim()
    .min(1, vi.master.codePrefixRequired)
    .max(20, vi.master.codePrefixMax20)
    .regex(/^[A-Za-z0-9_-]+$/, vi.master.codePrefixFormat),
  name: z
    .string()
    .trim()
    .min(1, vi.master.itemGroupNameRequired)
    .max(100, vi.master.itemGroupNameMax100),
  kind: z.enum([
    "food",
    "beverage",
    "amenity",
    "complimentary",
    "collateral",
    "linen",
    "loan",
    "chemical",
    "tool",
    "minibar",
    "engineering",
    "ccdc",
    "other",
  ]),
  parentId: z.string().uuid().optional().nullable(),
});

export type ItemGroupSaveInput = z.infer<typeof itemGroupSaveSchema>;

export const uomSaveSchema = z.object({
  code: z
    .string()
    .trim()
    .min(1, vi.master.uomCodeRequired)
    .max(20, vi.master.uomCodeMax20)
    .regex(/^[a-z][a-z0-9_]*$/, vi.master.uomCodeFormat),
  nameVi: z
    .string()
    .trim()
    .min(1, vi.master.vietnameseDisplayNameRequired)
    .max(50, vi.master.vietnameseNameMax50),
});

export type UomSaveInput = z.infer<typeof uomSaveSchema>;

export const purchaseUnitSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  itemId: z.string().uuid(),
  uom: z.string().trim().min(1, vi.master.selectPurchaseUnit),
  factorToStock: z.coerce.number().positive(vi.master.conversionFactorPositive),
  isDefault: z.boolean().default(false),
});

export type PurchaseUnitSaveInput = z.infer<typeof purchaseUnitSaveSchema>;

export const warehouseSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, vi.master.warehouseCodeRequired)
    .max(50, vi.master.warehouseCodeMax50)
    .regex(/^[A-Za-z0-9_-]+$/, vi.master.warehouseCodeFormat),
  name: z
    .string()
    .trim()
    .min(1, vi.master.warehouseNameRequired)
    .max(100, vi.master.warehouseNameMax100),
  kind: z.enum([
    "main",
    "outlet",
    "floor",
    "trolley",
    "minibar_main",
    "minibar_room",
    "transit",
    "quarantine",
    "disposal",
  ]),
  outletId: z.string().uuid().optional().nullable(),
});

export type WarehouseSaveInput = z.infer<typeof warehouseSaveSchema>;

export const roomSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  roomNo: z
    .string()
    .trim()
    .min(1, vi.master.roomNumberRequired)
    .max(20, vi.master.roomNumberMax20),
  floor: z.string().trim().max(20).optional().nullable(),
  roomTypeId: z.string().uuid(vi.master.selectRoomType),
});

export type RoomSaveInput = z.infer<typeof roomSaveSchema>;

export const roomTypeSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, vi.master.roomTypeCodeRequired)
    .max(20, vi.master.roomTypeCodeMax20),
  name: z
    .string()
    .trim()
    .min(1, vi.master.roomTypeNameRequired)
    .max(100, vi.master.roomTypeNameMax100),
  maxGuests: z.coerce.number().int().positive().optional().nullable(),
});

export type RoomTypeSaveInput = z.infer<typeof roomTypeSaveSchema>;

export const outletSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, vi.master.outletCodeRequired)
    .max(20, vi.master.outletCodeMax20),
  name: z
    .string()
    .trim()
    .min(1, vi.master.outletNameRequired)
    .max(100, vi.master.outletNameMax100),
  outletTypeId: z.string().uuid(vi.master.selectOutletType),
  costCenterId: z.string().uuid().optional().nullable(),
});

export type OutletSaveInput = z.infer<typeof outletSaveSchema>;

export const outletTypeSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, vi.master.outletTypeCodeRequired)
    .max(20, vi.master.outletTypeCodeMax20),
  name: z
    .string()
    .trim()
    .min(1, vi.master.outletTypeNameRequired)
    .max(100, vi.master.outletTypeNameMax100),
});

export type OutletTypeSaveInput = z.infer<typeof outletTypeSaveSchema>;

export const expenseCategorySaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, vi.master.expenseCategoryCodeRequired)
    .max(50, vi.master.expenseCategoryCodeMax50),
  name: z
    .string()
    .trim()
    .min(1, vi.master.expenseCategoryNameRequired)
    .max(100, vi.master.expenseCategoryNameMax100),
  usaliLine: z.string().trim().max(100).optional().nullable(),
  parentId: z.string().uuid().optional().nullable(),
});

export type ExpenseCategorySaveInput = z.infer<
  typeof expenseCategorySaveSchema
>;

// ---------------------------------------------------------------------------
// T-013: Nha cung cap + doi STK + hop dong khung + gia tran
// ---------------------------------------------------------------------------

export const supplierSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, vi.master.supplierCodeRequired)
    .max(50, vi.master.supplierCodeMax50)
    .regex(/^[A-Za-z0-9_-]+$/, vi.master.supplierCodeFormat),
  name: z
    .string()
    .trim()
    .min(1, vi.master.supplierNameRequired)
    .max(200, vi.master.supplierNameMax200),
  taxCode: z.string().trim().max(30).optional().nullable(),
  kind: z.enum(["company", "household", "individual_no_invoice"]),
  phone: z.string().trim().max(30).optional().nullable(),
  address: z.string().trim().max(500).optional().nullable(),
  paymentTermsDays: z.coerce
    .number()
    .int()
    .min(0, vi.master.paymentDaysNonNegative)
    .optional()
    .nullable(),
  foodSafetyCertUntil: z.string().trim().optional().nullable(),
});

export type SupplierSaveInput = z.infer<typeof supplierSaveSchema>;

export const supplierDecisionSchema = z.object({
  propertyId: z.string().uuid(),
  supplierId: z.string().uuid(),
  approved: z.boolean(),
  reason: z.string().trim().max(500).optional().nullable(),
});

export type SupplierDecisionInput = z.infer<typeof supplierDecisionSchema>;

export const supplierSetStatusSchema = z.object({
  propertyId: z.string().uuid(),
  supplierId: z.string().uuid(),
  status: z.enum(["suspended", "banned", "active"]),
  reason: z
    .string()
    .trim()
    .min(1, vi.master.enterReasonForAction)
    .max(500, vi.master.reasonMax500),
});

export type SupplierSetStatusInput = z.infer<typeof supplierSetStatusSchema>;

export const supplierBankRequestSchema = z.object({
  propertyId: z.string().uuid(),
  supplierId: z.string().uuid(),
  bankName: z
    .string()
    .trim()
    .min(1, vi.master.bankNameRequired)
    .max(100, vi.master.bankNameMax100),
  accountNo: z
    .string()
    .trim()
    .min(1, vi.master.bankAccountNumberRequired)
    .max(50, vi.master.bankAccountNumberMax50),
  accountName: z
    .string()
    .trim()
    .min(1, vi.master.bankAccountHolderRequired)
    .max(200, vi.master.bankAccountHolderMax200),
});

export type SupplierBankRequestInput = z.infer<
  typeof supplierBankRequestSchema
>;

export const supplierBankDecisionSchema = z.object({
  propertyId: z.string().uuid(),
  bankAccountId: z.string().uuid(),
  approved: z.boolean(),
  reason: z.string().trim().max(500).optional().nullable(),
});

export type SupplierBankDecisionInput = z.infer<
  typeof supplierBankDecisionSchema
>;

export const priceAgreementSaveSchema = z
  .object({
    id: z.string().uuid().optional(),
    propertyId: z.string().uuid(),
    supplierId: z.string().uuid(vi.master.selectSupplier),
    validFrom: z
      .string()
      .trim()
      .regex(/^\d{4}-\d{2}-\d{2}$/, vi.master.startDateInvalidFormat),
    validTo: z
      .string()
      .trim()
      .regex(/^\d{4}-\d{2}-\d{2}$/, vi.master.endDateInvalidFormat),
    status: z
      .enum(["draft", "active", "expired", "cancelled"])
      .default("draft"),
  })
  .refine((v) => v.validTo >= v.validFrom, {
    message: vi.service.endBeforeStart,
    path: ["validTo"],
  });

export type PriceAgreementSaveInput = z.infer<typeof priceAgreementSaveSchema>;

export const priceAgreementLineSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  agreementId: z.string().uuid(),
  itemId: z.string().uuid(vi.master.selectItem),
  uom: z.string().trim().min(1, vi.master.selectUom),
  unitPrice: z.coerce.number().min(0, vi.master.unitPriceNonNegative),
  warnPct: z.coerce.number().min(0).max(100).optional().nullable(),
  lockPct: z.coerce.number().min(0).max(100).optional().nullable(),
});

export type PriceAgreementLineSaveInput = z.infer<
  typeof priceAgreementLineSaveSchema
>;

export const ceilingPriceSaveSchema = z
  .object({
    id: z.string().uuid().optional(),
    propertyId: z.string().uuid(),
    // propertyScopeId null = gia tran cap chuoi; co gia tri = gia tran cap khach san.
    propertyScopeId: z.string().uuid().optional().nullable(),
    itemId: z.string().uuid(vi.master.selectItem),
    uom: z.string().trim().min(1, vi.master.selectUom),
    price: z.coerce.number().min(0, vi.master.ceilingPriceNonNegative),
    validFrom: z
      .string()
      .trim()
      .regex(/^\d{4}-\d{2}-\d{2}$/, vi.master.startDateInvalidFormat),
    validTo: z
      .string()
      .trim()
      .regex(/^\d{4}-\d{2}-\d{2}$/, vi.master.endDateInvalidFormat),
  })
  .refine((v) => v.validTo >= v.validFrom, {
    message: vi.service.endBeforeStart,
    path: ["validTo"],
  });

export type CeilingPriceSaveInput = z.infer<typeof ceilingPriceSaveSchema>;

// ---------------------------------------------------------------------------
// T-015: Ma tam + gop ma
// ---------------------------------------------------------------------------

export const tempItemCreateSchema = z.object({
  propertyId: z.string().uuid(),
  name: z
    .string()
    .trim()
    .min(1, vi.master.itemNameRequired)
    .max(200, vi.master.itemNameMax200),
  groupId: z.string().uuid(vi.master.selectItemGroup),
  stockUom: z.string().trim().min(1, vi.master.selectStockUom),
});

export type TempItemCreateInput = z.infer<typeof tempItemCreateSchema>;

export const itemMergeSchema = z.object({
  propertyId: z.string().uuid(),
  fromId: z.string().uuid(),
  intoId: z.string().uuid(),
});

export type ItemMergeInput = z.infer<typeof itemMergeSchema>;

export const mergeTargetSearchSchema = z.object({
  propertyId: z.string().uuid(),
  search: z.string().trim().max(100),
});

export type MergeTargetSearchInput = z.infer<typeof mergeTargetSearchSchema>;
