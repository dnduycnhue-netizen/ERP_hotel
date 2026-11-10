import fs from "node:fs";
import path from "node:path";

/**
 * Trang thai luong ghi (PR -> PO -> nhan hang -> hoa don -> thanh toan)
 * truyen giua cac file spec tang ghi. Luu o .auth/ (gitignored).
 * Neu file chua co (spec truoc skip/fail) thi spec sau skip ro ly do.
 */

export type FlowState = {
  tag: string;
  prId: string;
  poId: string;
  supplierName: string;
  expectedDate: string;
  grId?: string;
  invoiceId?: string;
  paymentRequestId?: string;
};

const STATE_FILE = path.join(__dirname, "..", ".auth", "flow-state.json");

export function saveFlowState(state: FlowState): void {
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

export function readFlowState(): FlowState | null {
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, "utf-8")) as FlowState;
  } catch {
    return null;
  }
}

export function flowTag(): string {
  const now = new Date();
  const pad = (n: number): string => String(n).padStart(2, "0");
  return (
    `T047-${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}` +
    `-${pad(now.getHours())}${pad(now.getMinutes())}`
  );
}

/** Ngay hien tai theo Asia/Ho_Chi_Minh (yyyy-mm-dd) — PO hen nhan hom nay. */
export function todayVn(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}
