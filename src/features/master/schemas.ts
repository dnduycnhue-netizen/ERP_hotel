import { z } from "zod";

export const itemSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, "Mã vật tư không được để trống")
    .max(50, "Mã vật tư tối đa 50 ký tự")
    .regex(
      /^[A-Za-z0-9_-]+$/,
      "Mã vật tư chỉ chứa chữ, số, gạch nối hoặc gạch dưới",
    ),
  name: z
    .string()
    .trim()
    .min(1, "Tên vật tư không được để trống")
    .max(200, "Tên vật tư tối đa 200 ký tự"),
  nameEn: z.string().trim().max(200).optional().nullable(),
  groupId: z.string().uuid("Vui lòng chọn nhóm hàng"),
  stockUom: z.string().trim().min(1, "Vui lòng chọn đơn vị tính kho"),
  recipeUom: z.string().trim().optional().nullable(),
  stockToRecipe: z.coerce
    .number()
    .positive("Hệ số quy đổi phải lớn hơn 0")
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
    .min(1, "Chọn ít nhất 1 kênh mua"),
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
    .min(1, "Tiền tố mã không được để trống")
    .max(20, "Tiền tố mã tối đa 20 ký tự")
    .regex(
      /^[A-Za-z0-9_-]+$/,
      "Tiền tố mã chỉ chứa chữ, số, gạch nối hoặc gạch dưới",
    ),
  name: z
    .string()
    .trim()
    .min(1, "Tên nhóm hàng không được để trống")
    .max(100, "Tên nhóm hàng tối đa 100 ký tự"),
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
    .min(1, "Mã ĐVT không được để trống")
    .max(20, "Mã ĐVT tối đa 20 ký tự")
    .regex(
      /^[a-z][a-z0-9_]*$/,
      "Mã ĐVT chỉ gồm chữ thường không dấu, số hoặc gạch dưới",
    ),
  nameVi: z
    .string()
    .trim()
    .min(1, "Tên hiển thị tiếng Việt không được để trống")
    .max(50, "Tên tiếng Việt tối đa 50 ký tự"),
});

export type UomSaveInput = z.infer<typeof uomSaveSchema>;

export const purchaseUnitSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  itemId: z.string().uuid(),
  uom: z.string().trim().min(1, "Chọn đơn vị mua"),
  factorToStock: z.coerce.number().positive("Hệ số quy đổi phải lớn hơn 0"),
  isDefault: z.boolean().default(false),
});

export type PurchaseUnitSaveInput = z.infer<typeof purchaseUnitSaveSchema>;

export const warehouseSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, "Mã kho không được để trống")
    .max(50, "Mã kho tối đa 50 ký tự")
    .regex(
      /^[A-Za-z0-9_-]+$/,
      "Mã kho chỉ chứa chữ, số, gạch nối hoặc gạch dưới",
    ),
  name: z
    .string()
    .trim()
    .min(1, "Tên kho không được để trống")
    .max(100, "Tên kho tối đa 100 ký tự"),
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
    .min(1, "Số phòng không được để trống")
    .max(20, "Số phòng tối đa 20 ký tự"),
  floor: z.string().trim().max(20).optional().nullable(),
  roomTypeId: z.string().uuid("Vui lòng chọn loại phòng"),
});

export type RoomSaveInput = z.infer<typeof roomSaveSchema>;

export const roomTypeSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, "Mã loại phòng không được để trống")
    .max(20, "Mã loại phòng tối đa 20 ký tự"),
  name: z
    .string()
    .trim()
    .min(1, "Tên loại phòng không được để trống")
    .max(100, "Tên loại phòng tối đa 100 ký tự"),
  maxGuests: z.coerce.number().int().positive().optional().nullable(),
});

export type RoomTypeSaveInput = z.infer<typeof roomTypeSaveSchema>;

export const outletSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, "Mã outlet không được để trống")
    .max(20, "Mã outlet tối đa 20 ký tự"),
  name: z
    .string()
    .trim()
    .min(1, "Tên outlet không được để trống")
    .max(100, "Tên outlet tối đa 100 ký tự"),
  outletTypeId: z.string().uuid("Vui lòng chọn loại outlet"),
  costCenterId: z.string().uuid().optional().nullable(),
});

export type OutletSaveInput = z.infer<typeof outletSaveSchema>;

export const outletTypeSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, "Mã loại outlet không được để trống")
    .max(20, "Mã loại outlet tối đa 20 ký tự"),
  name: z
    .string()
    .trim()
    .min(1, "Tên loại outlet không được để trống")
    .max(100, "Tên loại outlet tối đa 100 ký tự"),
});

export type OutletTypeSaveInput = z.infer<typeof outletTypeSaveSchema>;

export const expenseCategorySaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, "Mã khoản mục không được để trống")
    .max(50, "Mã khoản mục tối đa 50 ký tự"),
  name: z
    .string()
    .trim()
    .min(1, "Tên khoản mục không được để trống")
    .max(100, "Tên khoản mục tối đa 100 ký tự"),
  usaliLine: z.string().trim().max(100).optional().nullable(),
  parentId: z.string().uuid().optional().nullable(),
});

export type ExpenseCategorySaveInput = z.infer<
  typeof expenseCategorySaveSchema
>;

export const supplierSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  code: z
    .string()
    .trim()
    .min(1, "Mã NCC không được để trống")
    .max(50, "Mã NCC tối đa 50 ký tự")
    .regex(/^[A-Za-z0-9_-]+$/, "Mã NCC chỉ chứa chữ, số, gạch nối hoặc gạch dưới"),
  name: z
    .string()
    .trim()
    .min(1, "Tên nhà cung cấp không được để trống")
    .max(200, "Tên NCC tối đa 200 ký tự"),
  taxCode: z.string().trim().max(30).optional().nullable(),
  kind: z.enum(["company", "household", "individual_no_invoice"]),
  phone: z.string().trim().max(50).optional().nullable(),
  address: z.string().trim().max(300).optional().nullable(),
  paymentTermsDays: z.coerce.number().int().min(0).optional().nullable(),
  foodSafetyCertUntil: z.string().trim().optional().nullable(),
});

export type SupplierSaveInput = z.infer<typeof supplierSaveSchema>;

export const bankAccountRequestSchema = z.object({
  propertyId: z.string().uuid(),
  supplierId: z.string().uuid("Vui lòng chọn nhà cung cấp"),
  bankName: z.string().trim().min(1, "Tên ngân hàng không được để trống").max(100),
  accountNo: z.string().trim().min(1, "Số tài khoản không được để trống").max(50),
  accountName: z.string().trim().min(1, "Tên chủ tài khoản không được để trống").max(100),
});

export type BankAccountRequestInput = z.infer<typeof bankAccountRequestSchema>;

export const priceAgreementSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  supplierId: z.string().uuid("Vui lòng chọn nhà cung cấp"),
  validFrom: z.string().min(1, "Chọn ngày bắt đầu hiệu lực"),
  validTo: z.string().min(1, "Chọn ngày kết thúc hiệu lực"),
  status: z.enum(["draft", "active", "expired", "cancelled"]).default("draft"),
});

export type PriceAgreementSaveInput = z.infer<typeof priceAgreementSaveSchema>;

export const priceAgreementLineSaveSchema = z.object({
  propertyId: z.string().uuid(),
  agreementId: z.string().uuid(),
  itemId: z.string().uuid("Chọn vật tư"),
  uom: z.string().trim().min(1, "Chọn đơn vị tính"),
  unitPrice: z.coerce.number().min(0, "Đơn giá không được âm"),
  warnPct: z.coerce.number().min(0).max(100).optional().nullable(),
  lockPct: z.coerce.number().min(0).max(100).optional().nullable(),
});

export type PriceAgreementLineSaveInput = z.infer<typeof priceAgreementLineSaveSchema>;

export const ceilingPriceSaveSchema = z.object({
  id: z.string().uuid().optional(),
  propertyId: z.string().uuid(),
  isPropertySpecific: z.boolean().default(false),
  itemId: z.string().uuid("Chọn vật tư"),
  uom: z.string().trim().min(1, "Chọn đơn vị tính"),
  price: z.coerce.number().min(0, "Đơn giá trần không được âm"),
  validFrom: z.string().min(1, "Chọn ngày bắt đầu"),
  validTo: z.string().min(1, "Chọn ngày kết thúc"),
});

export type CeilingPriceSaveInput = z.infer<typeof ceilingPriceSaveSchema>;
