import { describe, expect, it } from "vitest";

import { formatMoney, formatNumber } from "@/components/common/money-text";
import {
  calcBottleTotal,
  calcUomTotal,
  formatQty,
  formatYmd,
  normalizeSearch,
  parseDecimal,
} from "@/components/count/count-utils";
import {
  formatDateTimeVn,
  formatDateVn,
} from "@/features/export/hub";
import { getRpcErrorMessage, rpcErrorFallback } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";

describe("formatMoney / formatNumber (vi-VN)", () => {
  it("tiền: 1.040.000 đ, chuỗi số cũng được, null/rỗng/không hợp lệ hiện dấu —", () => {
    expect(formatMoney(1040000)).toBe("1.040.000 đ");
    expect(formatMoney("100000")).toBe("100.000 đ");
    expect(formatMoney(0)).toBe("0 đ");
    expect(formatMoney(-50000)).toBe("-50.000 đ");
    expect(formatMoney(null)).toBe(vi.common.noData);
    expect(formatMoney(undefined)).toBe(vi.common.noData);
    expect(formatMoney("")).toBe(vi.common.noData);
    expect(formatMoney("abc")).toBe(vi.common.noData);
    expect(formatMoney(Number.NaN)).toBe(vi.common.noData);
  });

  it("số lượng: dấu chấm nghìn, dấu phẩy thập phân, tối đa 4 chữ số lẻ", () => {
    expect(formatNumber(1234567.5)).toBe("1.234.567,5");
    expect(formatNumber("10")).toBe("10");
    expect(formatNumber(2.55555)).toBe("2,5556");
    expect(formatNumber(null)).toBe(vi.common.noData);
    expect(formatNumber("")).toBe(vi.common.noData);
    expect(formatNumber("xyz")).toBe(vi.common.noData);
  });
});

describe("formatYmd / formatQty (đếm kho)", () => {
  it("yyyy-mm-dd → dd/mm/yyyy, không qua Date (tránh lệch múi giờ)", () => {
    expect(formatYmd("2026-11-13")).toBe("13/11/2026");
    expect(formatYmd(null)).toBe(vi.common.noData);
    expect(formatYmd("abc")).toBe("abc");
  });

  it("số lượng theo vi-VN", () => {
    expect(formatQty(10)).toBe("10");
    expect(formatQty(2.5)).toBe("2,5");
    expect(formatQty(0)).toBe("0");
  });
});

describe("parseDecimal / calcUomTotal / calcBottleTotal (R30)", () => {
  it("parseDecimal: '0' là số hợp lệ, chuỗi rỗng/không số là null", () => {
    expect(parseDecimal("0")).toBe(0);
    expect(parseDecimal("10.5")).toBe(10.5);
    expect(parseDecimal("")).toBeNull();
    expect(parseDecimal("-")).toBeNull();
    expect(parseDecimal("abc")).toBeNull();
  });

  it("calcUomTotal: tổng quy đổi, 0 hợp lệ, chưa nhập gì là null, thiếu hệ số là null", () => {
    expect(
      calcUomTotal([
        { qty: 2, factor: 3 },
        { qty: 1, factor: 0.5 },
      ]),
    ).toBe(6.5);
    expect(calcUomTotal([{ qty: 0, factor: 5 }])).toBe(0);
    expect(calcUomTotal([{ qty: null, factor: 5 }])).toBeNull();
    expect(calcUomTotal([{ qty: 2, factor: null }])).toBeNull();
    expect(calcUomTotal([])).toBeNull();
  });

  it("calcBottleTotal: chai nguyên + chai mở; gram mở nhỏ hơn bì là nhập sai", () => {
    const base = {
      tareG: 500,
      densityGml: 1,
      defaultFactor: 0.75,
      mlFactor: 0.001,
    };
    expect(
      calcBottleTotal({ ...base, fullBottles: 1, openGrams: null }),
    ).toEqual({ openMl: null, total: 0.75 });
    expect(
      calcBottleTotal({ ...base, fullBottles: 0, openGrams: 500 }),
    ).toEqual({ openMl: 0, total: 0 });
    expect(
      calcBottleTotal({ ...base, fullBottles: null, openGrams: null }),
    ).toEqual({ openMl: null, total: null });
    const bad = calcBottleTotal({ ...base, fullBottles: 0, openGrams: 400 });
    expect(bad.openMl).toBe(-100);
    expect(bad.total).toBeNull();
  });

  it("normalizeSearch bỏ dấu tiếng Việt để tìm không dấu (chữ đ giữ nguyên vì không tách được bằng NFD)", () => {
    expect(normalizeSearch("Bánh Bèo")).toBe("banh beo");
    expect(normalizeSearch("Ba chỉ nách")).toBe("ba chi nach");
    // "Đường" → đ + uong (dấu trên ư/ờ bị lược, riêng chữ đ không tách được)
    expect(normalizeSearch("Đường")).toBe("đ" + "uong");
  });
});

describe("formatDateVn / formatDateTimeVn (xuất Excel, giờ VN)", () => {
  it("yyyy-mm-dd → dd/mm/yyyy; chuỗi lạ giữ nguyên; null → null", () => {
    expect(formatDateVn("2026-11-13")).toBe("13/11/2026");
    expect(formatDateVn(null)).toBeNull();
    expect(formatDateVn("xyz")).toBe("xyz");
  });

  it("timestamptz ISO → dd/mm/yyyy HH:mm theo Asia/Ho_Chi_Minh", () => {
    expect(formatDateTimeVn("2026-11-13T10:30:00Z")).toBe("13/11/2026 17:30");
    expect(formatDateTimeVn(null)).toBeNull();
    expect(formatDateTimeVn("khong-phai-ngay")).toBe("khong-phai-ngay");
  });
});

describe("getRpcErrorMessage (mã lỗi → câu tiếng Việt)", () => {
  it("ERR_SOD_COUNT_INDEPENDENT có câu riêng (không rơi vào câu SoD chung)", () => {
    expect(getRpcErrorMessage("ERR_SOD_COUNT_INDEPENDENT")).toContain(
      "người đếm độc lập",
    );
    expect(getRpcErrorMessage("ERR_SOD_COUNT_INDEPENDENT")).not.toBe(
      "Thao tác vi phạm quy tắc tách biệt nhiệm vụ: người thực hiện bước trước không được thực hiện bước này.",
    );
  });

  it("ERR_COUNT_INDEPENDENT (mã cũ) vẫn có câu riêng", () => {
    expect(getRpcErrorMessage("ERR_COUNT_INDEPENDENT")).toContain(
      "người đếm độc lập",
    );
  });

  it("mã SoD chưa có câu riêng dùng câu SoD chung, không lộ mã kỹ thuật", () => {
    expect(getRpcErrorMessage("ERR_SOD_KHONG_TON_TAI")).toContain(
      "tách biệt nhiệm vụ",
    );
    expect(getRpcErrorMessage("ERR_SOD_KHONG_TON_TAI")).not.toContain(
      "ERR_SOD_KHONG_TON_TAI",
    );
  });

  it("ERR_FORBIDDEN kèm mã quyền thiếu để UI báo rõ", () => {
    expect(getRpcErrorMessage("ERR_FORBIDDEN:po.approve")).toContain(
      "po.approve",
    );
    expect(getRpcErrorMessage("ERR_FORBIDDEN:receiving.post")).toContain(
      "receiving.post",
    );
  });

  it("mã lạ/null dùng câu chung, không lộ mã", () => {
    expect(getRpcErrorMessage("ERR_KHONG_TON_TAI")).toBe(rpcErrorFallback);
    expect(getRpcErrorMessage(null)).toBe(rpcErrorFallback);
    expect(getRpcErrorMessage(undefined)).toBe(rpcErrorFallback);
  });

  it("mọi mã ERR_* trong docs/09-API-RPC.md đều có câu riêng (trừ câu SoD chung)", () => {
    const docCodes = [
      "ERR_ADVANCE_OVERDUE",
      "ERR_ADVANCE_OVERDUE_BLOCK",
      "ERR_ALREADY_IMPORTED",
      "ERR_BANQUET_HALL_CONFLICT",
      "ERR_CONFIG_APPROVER",
      "ERR_CONFIG_INVALID",
      "ERR_CONFIG_ITEM_GROUP",
      "ERR_CONFIG_SCOPE",
      "ERR_COUNT_ALREADY_OPEN",
      "ERR_COUNT_FREEZE",
      "ERR_COUNT_INCOMPLETE",
      "ERR_COUNT_NOT_LOCKED",
      "ERR_DAY_LOCKED",
      "ERR_DOC_POSTED",
      "ERR_ESTIMATE_REQUIRED",
      "ERR_FORBIDDEN",
      "ERR_IMMUTABLE_LEDGER",
      "ERR_INVALID_PIN",
      "ERR_INVALID_STATUS",
      "ERR_INVALID_VALUE",
      "ERR_LAST_ADMIN",
      "ERR_LOCK_NOT_FOUND",
      "ERR_MODULE_DISABLED",
      "ERR_NEGATIVE_STOCK",
      "ERR_OVER_CEILING_NO_REASON",
      "ERR_PERIOD_ALREADY_CLOSED",
      "ERR_PERIOD_CLOSED",
      "ERR_PHOTO_REQUIRED",
      "ERR_PIN_INVALID",
      "ERR_POS_IMPORT_REQUIRED",
      "ERR_PO_UNRESOLVED",
      "ERR_PRICE_NOT_SET",
      "ERR_REASON_CODE_INVALID",
      "ERR_REASON_REQUIRED",
      "ERR_SELF_GRANT",
      "ERR_SERVICE_NOT_ACCEPTED",
      "ERR_SOD_COUNT_INDEPENDENT",
      "ERR_SYSTEM_ROLE",
      "ERR_TEMP_ITEM_EXPIRED",
      "ERR_UOM_UNKNOWN",
    ];
    for (const code of docCodes) {
      expect(getRpcErrorMessage(code)).not.toBe(rpcErrorFallback);
    }
  });
});
