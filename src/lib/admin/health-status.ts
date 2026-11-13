/**
 * Tong hop trang thai suc khoe he thong (man /admin/health, M-05).
 * Ham thuan — test duoc bang Vitest, khong phu thuoc React/Next.
 *
 * Nguong "Can xem" (theo dac ta M-05):
 *  - tac vu dinh ky loi trong 7 ngay > 0,
 *  - thong bao ket qua 1 gio > 0,
 *  - canh bao do chua xac nhan > 0.
 * Vuot bat ky nguong nao -> `ok: false` + danh sach ly do.
 */

export type HealthIssue = "cron" | "notifications" | "alerts";

export type HealthSummaryInput = {
  /** Tong so lan tac vu dinh ky loi trong 7 ngay. */
  cronFailed7dTotal: number;
  /** So thong bao ket qua 1 gio. */
  notificationsStuck: number;
  /** So canh bao do chua xac nhan. */
  alertsRed: number;
};

export type HealthSummary = {
  ok: boolean;
  issues: HealthIssue[];
};

export function summarizeHealth(input: HealthSummaryInput): HealthSummary {
  const issues: HealthIssue[] = [];
  if (input.cronFailed7dTotal > 0) {
    issues.push("cron");
  }
  if (input.notificationsStuck > 0) {
    issues.push("notifications");
  }
  if (input.alertsRed > 0) {
    issues.push("alerts");
  }
  return { ok: issues.length === 0, issues };
}
