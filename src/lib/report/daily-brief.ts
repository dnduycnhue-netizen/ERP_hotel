/**
 * Đọc payload `RPT_DAILY_BRIEF` (bản tin 8h) cho khối "Sáng nay" ở trang
 * tổng quan. Chỉ để hiển thị — tiền do Postgres tính (AGENTS.md quy tắc 7);
 * thiếu/lệch kiểu thì trả null/0 thay vì làm sập trang.
 */
export type BriefAlert = {
  id: string;
  title: string;
  createdAt: string | null;
};

export type DailyBrief = {
  date: string | null;
  purchaseYesterday: number | null;
  wasteYesterday: number | null;
  redAlertsUnacked: number;
  apDue7d: number | null;
  advancesOverdueCount: number;
  advancesOverdueAmount: number | null;
  redAlerts24h: BriefAlert[];
  contractsExpiring: number;
  schedulesUnaccepted: number;
};

function num(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function arr(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function rec(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

export function parseDailyBrief(payload: unknown): DailyBrief {
  const p = rec(payload);
  const advances = rec(p.advances_overdue);
  return {
    date: typeof p.date === "string" ? p.date : null,
    purchaseYesterday: num(p.purchase_yesterday),
    wasteYesterday: num(p.waste_yesterday),
    redAlertsUnacked: num(p.red_alerts_unacked) ?? 0,
    apDue7d: num(p.ap_due_7d),
    advancesOverdueCount: num(advances.count) ?? 0,
    advancesOverdueAmount: num(advances.amount),
    redAlerts24h: arr(p.red_alerts_24h).flatMap((item): BriefAlert[] => {
      const a = rec(item);
      return typeof a.id === "string" && typeof a.title === "string"
        ? [
            {
              id: a.id,
              title: a.title,
              createdAt: typeof a.created_at === "string" ? a.created_at : null,
            },
          ]
        : [];
    }),
    contractsExpiring: arr(p.contracts_expiring).length,
    schedulesUnaccepted: arr(p.schedules_unaccepted).length,
  };
}

/** Có điều gì cần chú ý sáng nay không (để tô màu khối). */
export function briefNeedsAttention(brief: DailyBrief): boolean {
  return (
    brief.redAlertsUnacked > 0 ||
    brief.advancesOverdueCount > 0 ||
    brief.contractsExpiring > 0 ||
    brief.schedulesUnaccepted > 0
  );
}
