import { describe, expect, it } from "vitest";
import { briefNeedsAttention, parseDailyBrief } from "@/lib/report/daily-brief";

describe("parseDailyBrief", () => {
  it("reads a full payload", () => {
    const brief = parseDailyBrief({
      date: "2026-11-13",
      purchase_yesterday: 1500000,
      waste_yesterday: "20000.5",
      red_alerts_unacked: 2,
      ap_due_7d: 0,
      advances_overdue: { count: 1, amount: 500000 },
      red_alerts_24h: [
        { id: "a1", title: "Lệch minibar", created_at: "2026-11-13T01:00:00Z" },
        { id: 5, title: "bad row" },
      ],
      contracts_expiring: [{}, {}],
      schedules_unaccepted: [{}],
    });
    expect(brief.purchaseYesterday).toBe(1500000);
    expect(brief.wasteYesterday).toBe(20000.5);
    expect(brief.redAlerts24h).toEqual([
      { id: "a1", title: "Lệch minibar", createdAt: "2026-11-13T01:00:00Z" },
    ]);
    expect(brief.contractsExpiring).toBe(2);
    expect(brief.schedulesUnaccepted).toBe(1);
    expect(brief.advancesOverdueAmount).toBe(500000);
  });

  it("survives malformed input", () => {
    const brief = parseDailyBrief(null);
    expect(brief.purchaseYesterday).toBeNull();
    expect(brief.redAlertsUnacked).toBe(0);
    expect(brief.redAlerts24h).toEqual([]);
    expect(briefNeedsAttention(brief)).toBe(false);
  });

  it("flags attention only when something needs action", () => {
    expect(briefNeedsAttention(parseDailyBrief({ red_alerts_unacked: 1 }))).toBe(true);
    expect(briefNeedsAttention(parseDailyBrief({ purchase_yesterday: 100 }))).toBe(false);
  });
});
