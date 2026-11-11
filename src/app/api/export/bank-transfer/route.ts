import { createHash } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";
import {
  buildBankTransferWorkbook,
  isBankTransferPayload,
  parseBankTransferIds,
} from "@/features/export/bankTransfer";
import { callJsonRpc } from "@/features/export/rpc";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";

/**
 * CONTRACT (C3) cho workstream C4 — man /{property}/finance/export:
 *
 * GET /api/export/bank-transfer?ids=<uuid>,<uuid>,...
 * - Query param duy nhat: `ids` — danh sach id cua payment_requests,
 *   phan tach bang dau phay, toi da 200 id, khong trung (id trung duoc
 *   loai bo). Khong co param theo ky: ke toan xuat dung cac de nghi da
 *   duyet muon tra dot nay.
 * - 400 khi thieu/sai `ids`; khi co de nghi chua 'approved' (chua duyet
 *   / da tra / da huy); khi NCC chua co tai khoan ngan hang ACTIVE
 *   (ma ERR_BANK_ACCOUNT_MISSING, detail = cac so de nghi).
 * - 401 khi chua dang nhap (proxy.ts khong redirect /api/* ve /login).
 * - 403 khi thieu quyen `export.accounting` va `payment.mark_paid`.
 * - 200 tra file .xlsx: Content-Type
 *   application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,
 *   ten file `chuyen-khoan-<yyyy-mm-dd>.xlsx` (ngay xuat, gio VN).
 *   Cot: So de nghi | Han tra | Ma NCC | Ten NCC | Ngan hang |
 *   So tai khoan | Ten tai khoan | So tien | Noi dung | Ghi chu.
 *   Tien la so Excel that. Cot Ghi chu ghi "Da xuat truoc day:
 *   <ngay gio>" neu de nghi da co trong `export_batches` (xuat lai
 *   khong bi chan — file cu co the bi mat — nhung duoc danh dau).
 * - Moi lan xuat thanh cong ghi 1 dong `export_batches` cho MOI de
 *   nghi (kind='bank-transfer', ref_type='payment_request',
 *   ref_id=<request id>, file_hash=sha256 hex cua file — cac dong
 *   cung file co chung hash) va danh dau
 *   `payment_requests.export_status='exported'`.
 * URL va query param nay KHONG doi sau khi C3 ban giao.
 *
 * Route handler dung request.nextUrl nen mac dinh dynamic (khong dung
 * `dynamic = "force-dynamic"` — khong tuong thich voi cacheComponents).
 */

export async function GET(request: NextRequest): Promise<NextResponse> {
  const parsed = parseBankTransferIds(request.nextUrl.searchParams);
  if (!parsed.ok) {
    return NextResponse.json({ error: vi.export.invalidIds }, { status: 400 });
  }

  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (!user) {
    return NextResponse.json(
      { error: vi.export.unauthorized },
      { status: 401 },
    );
  }

  const result = await callJsonRpc(supabase, "export_bank_transfer", {
    p_payment_request_ids: parsed.ids,
  });
  if (!result.ok) {
    if (result.sqlstate === "42501") {
      return NextResponse.json(
        { error: getRpcErrorMessage(result.code), code: result.code },
        { status: 403 },
      );
    }
    if (result.code === "ERR_BANK_ACCOUNT_MISSING") {
      return NextResponse.json(
        {
          error: vi.export.bankAccountMissing,
          code: result.code,
          detail: result.detail,
        },
        { status: 400 },
      );
    }
    if (result.sqlstate === "22023" || result.code === "ERR_INVALID_STATUS") {
      return NextResponse.json(
        {
          error: getRpcErrorMessage(result.code),
          code: result.code,
          detail: result.detail,
        },
        { status: 400 },
      );
    }
    return NextResponse.json(
      { error: vi.export.exportFailed, code: result.code },
      { status: 500 },
    );
  }
  if (!isBankTransferPayload(result.data)) {
    return NextResponse.json(
      { error: vi.export.exportFailed },
      { status: 500 },
    );
  }

  const buffer = buildBankTransferWorkbook(result.data);

  // Ghi log xuat TRUOC khi tra file: file khong bao gio duoc tra ma
  // khong co dong export_batches (chong xuat trung, M09).
  const fileHash = createHash("sha256").update(buffer).digest("hex");
  const recordResult = await callJsonRpc(supabase, "export_batch_record", {
    p_kind: "bank-transfer",
    p_ref_type: "payment_request",
    p_ref_ids: parsed.ids,
    p_file_hash: fileHash,
    p_note: null,
  });
  if (!recordResult.ok) {
    return NextResponse.json(
      { error: vi.export.exportRecordFailed, code: recordResult.code },
      { status: 500 },
    );
  }

  const today = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
  const filename = `chuyen-khoan-${today}.xlsx`;
  return new NextResponse(new Uint8Array(buffer), {
    headers: {
      "Content-Type":
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Cache-Control": "no-store",
    },
  });
}
