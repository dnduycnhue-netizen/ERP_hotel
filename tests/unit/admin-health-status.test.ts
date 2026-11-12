import { summarizeHealth } from "@/lib/admin/health-status";
import { describe, expect, it } from "vitest";

describe("summarizeHealth (man /admin/health)", () => {
  it("tat ca chi so bang 0 -> On", () => {
    expect(
      summarizeHealth({
        cronFailed7dTotal: 0,
        notificationsStuck: 0,
        alertsRed: 0,
      }),
    ).toEqual({ ok: true, issues: [] });
  });

  it("cron loi > 0 -> Can xem, ly do cron", () => {
    expect(
      summarizeHealth({
        cronFailed7dTotal: 2,
        notificationsStuck: 0,
        alertsRed: 0,
      }),
    ).toEqual({ ok: false, issues: ["cron"] });
  });

  it("thong bao ket > 0 -> Can xem, ly do notifications", () => {
    expect(
      summarizeHealth({
        cronFailed7dTotal: 0,
        notificationsStuck: 3,
        alertsRed: 0,
      }),
    ).toEqual({ ok: false, issues: ["notifications"] });
  });

  it("canh bao do > 0 -> Can xem, ly do alerts", () => {
    expect(
      summarizeHealth({
        cronFailed7dTotal: 0,
        notificationsStuck: 0,
        alertsRed: 9,
      }),
    ).toEqual({ ok: false, issues: ["alerts"] });
  });

  it("nhieu nguong vuot cung luc -> liet ke du ly do theo thu tu", () => {
    expect(
      summarizeHealth({
        cronFailed7dTotal: 1,
        notificationsStuck: 2,
        alertsRed: 1,
      }),
    ).toEqual({
      ok: false,
      issues: ["cron", "notifications", "alerts"],
    });
  });

  it("canh bao vang / thong bao loi khong tinh vao trang thai chung", () => {
    // Chi 3 nguong trong dac ta M-05 moi anh huong den trang thai.
    // Ham nay chi nhan 3 so do — gia tri khac khong co cua truyen vao.
    expect(
      summarizeHealth({
        cronFailed7dTotal: 0,
        notificationsStuck: 0,
        alertsRed: 0,
      }).ok,
    ).toBe(true);
  });
});
